import SecLang.Bytes

/-!
# Transformations (`spec/07-transformations.md`)

Executable reference definitions over byte arrays. Reference semantics: ModSecurity v2
`apache2/msc_util.c` and `apache2/re_tfns.c` (`v2/master`, 2026-09), which is what the
unit-tier corpus expects, except where a definition's docstring names another reference or
a deliberate deviation (`normalisePathWin`, `sqlHexDecode`, `utf8toUnicode`, `cmdLine`,
`base64DecodeExt`).
-/
namespace SecLang

/-- `lowercase`: ASCII `A`–`Z` to `a`–`z`, other bytes unchanged. -/
def lowercase (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity b.size
  for x in b do
    out := out.push (if 65 ≤ x && x ≤ 90 then x + 32 else x)
  return out

#guard (lowercase ⟨#[0x54, 0x65, 0x00, 0x43, 0xC4]⟩).data == #[0x74, 0x65, 0x00, 0x63, 0xC4]
#guard (lowercase ⟨#[]⟩).data == #[]

/-- `hexEncode`: each byte as two lowercase hexadecimal digits. -/
def hexEncode (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity (2 * b.size)
  for x in b do
    out := (out.push (hexDigit (x / 16))).push (hexDigit (x % 16))
  return out

#guard (hexEncode ⟨#[0x54, 0x00, 0xFF]⟩).data == #[0x35, 0x34, 0x30, 0x30, 0x66, 0x66]
#guard (hexEncode ⟨#[]⟩).data == #[]

/-- The byte for a `%uXXXX` escape: the mapping table when it has an entry, otherwise the
low byte, folded from full-width ASCII (`FF01`–`FF5E`) to ASCII.
Source: `msc_util.c` `urldecode_uni_nonstrict_inplace_ex`. -/
def uniByte (map : Nat → Option UInt8) (h2 h3 h4 h5 : UInt8) : UInt8 :=
  match map (h2.toNat * 4096 + h3.toNat * 256 + h4.toNat * 16 + h5.toNat) with
  | some m => m
  | none =>
    let low := h4 * 16 + h5
    if h2 == 15 && h3 == 15 && 0 < low && low < 0x5F then low + 0x20 else low

/-- `urlDecodeUni` with a `SecUnicodeMapFile` table (`map code = none` for no entry). -/
def urlDecodeUniWith (map : Nat → Option UInt8) (b : ByteArray) : ByteArray :=
  go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c == '+'.toUInt8 then go (i + 1) (out.push ' '.toUInt8)
      else if c != '%'.toUInt8 then go (i + 1) (out.push c)
      else
        let u := byteAt b (i + 1)
        if u == some 'u'.toUInt8 || u == some 'U'.toUInt8 then
          match hexAt b (i + 2), hexAt b (i + 3), hexAt b (i + 4), hexAt b (i + 5) with
          | some h2, some h3, some h4, some h5 => go (i + 6) (out.push (uniByte map h2 h3 h4 h5))
          | _, _, _, _ => go (i + 2) ((out.push c).push (u.getD 0))   -- "%u" kept verbatim
        else
          match hexAt b (i + 1), hexAt b (i + 2) with
          | some h1, some h2 => go (i + 3) (out.push (h1 * 16 + h2))
          | _, _ => go (i + 1) (out.push c)                           -- "%" kept verbatim
    else out
  termination_by b.size - i

/-- `urlDecodeUni` without a mapping table (the engines' default). -/
def urlDecodeUni : ByteArray → ByteArray := urlDecodeUniWith fun _ => none

#guard (urlDecodeUni ⟨"Test+Case".toUTF8.data⟩).data == "Test Case".toUTF8.data
#guard (urlDecodeUni ⟨"%41%ff%u0042".toUTF8.data⟩).data == #[0x41, 0xFF, 0x42]
#guard (urlDecodeUni ⟨"%uff01%uff5e%uff00%uff7f".toUTF8.data⟩).data == #[0x21, 0x7E, 0x00, 0x7F]
#guard (urlDecodeUni ⟨"%u1141".toUTF8.data⟩).data == #[0x41]
#guard (urlDecodeUni ⟨"%u00%u0020".toUTF8.data⟩).data == "%u00 ".toUTF8.data
#guard (urlDecodeUni ⟨"%0g%20%%%".toUTF8.data⟩).data == "%0g %%%".toUTF8.data
#guard (urlDecodeUniWith (fun c => if c == 0x1141 then some 0x5A else none) ⟨"%u1141".toUTF8.data⟩).data == #[0x5A]

/-- The byte for a CSS escape of `j` (1–6) hexadecimal digits starting at `p`: the last two
digits, folded from full-width ASCII when the escape is `ffXX`, `0ffXX` or `00ffXX`.
Source: `msc_util.c` `css_decode_inplace`. -/
def cssByte (b : ByteArray) (p j : Nat) : UInt8 :=
  let d := fun k => (hexAt b (p + k)).getD 0
  if j == 1 then d 0
  else
    let low := d (j - 2) * 16 + d (j - 1)
    let fullWidth := j == 4 || (j == 5 && d 0 == 0) || (j == 6 && d 0 == 0 && d 1 == 0)
    if fullWidth && d (j - 3) == 15 && d (j - 4) == 15 && 0 < low && low < 0x5F then low + 0x20
    else low

/-- `cssDecode`: CSS 2.x escapes. -/
def cssDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c != '\\'.toUInt8 then go (i + 1) (out.push c)
      else match byteAt b (i + 1) with
        | none => out                                    -- trailing backslash: dropped
        | some n =>
          let j := takeWhile b isHex (i + 1) 6
          if j == 0 then
            if n == '\n'.toUInt8 then go (i + 2) out     -- escaped newline: dropped
            else go (i + 2) (out.push n)                 -- escaped byte: itself
          else
            let ws := if (byteAt b (i + 1 + j)).any isSpace then 1 else 0
            go (i + 1 + j + ws) (out.push (cssByte b (i + 1) j))
    else out
  termination_by b.size - i

#guard (cssDecode ⟨"\\a\\b\\n\\?\\12\\123\\1234\\ff01\\ff5e".toUTF8.data⟩).data
  == #[0x0A, 0x0B, 0x6E, 0x3F, 0x12, 0x23, 0x34, 0x21, 0x7E]
#guard (cssDecode ⟨"\\1A\\1 A\\1234567\\123456 7\\1x\\1 x".toUTF8.data⟩).data
  == #[0x1A, 0x01, 0x41, 0x56, 0x37, 0x56, 0x37, 0x01, 0x78, 0x01, 0x78]
#guard (cssDecode ⟨"\\\n\\\u0000  s\\".toUTF8.data⟩).data == #[0x00, 0x20, 0x20, 0x73]
#guard (cssDecode ⟨"\\  x".toUTF8.data⟩).data == #[0x20, 0x20, 0x78]
#guard (cssDecode ⟨"\\0ff21\\00ff21\\1ff21".toUTF8.data⟩).data == #[0x41, 0x41, 0x21]

/-- Value of a standard Base64 alphabet byte (RFC 4648 §4). -/
def b64Val (b : UInt8) : Option UInt8 :=
  if 65 ≤ b && b ≤ 90 then some (b - 65)        -- A-Z
  else if 97 ≤ b && b ≤ 122 then some (b - 71)  -- a-z
  else if 48 ≤ b && b ≤ 57 then some (b + 4)    -- 0-9
  else if b == '+'.toUInt8 then some 62
  else if b == '/'.toUInt8 then some 63
  else none

/-- Sextets of the longest alphabet-only prefix. Decoding stops at the first other byte:
padding, NUL (`spec/07#base64decode`), or anything else. For input outside the alphabet
the spec is silent and this is the ModSecurity v2 reading (`apr_base64_decode`); Coraza
agrees except that it skips CR and LF, and libmodsecurity rejects the whole input. -/
def b64Sextets (b : ByteArray) : Array UInt8 := Id.run do
  let mut out := #[]
  for x in b do
    match b64Val x with
    | some v => out := out.push v
    | none => return out
  return out

/-- Bytes of a sextet sequence: full quanta give three bytes; a trailing two or three
sextets give one or two; a trailing single sextet gives nothing (`apr_base64_decode`). -/
def b64Emit (s : Array UInt8) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity (s.size / 4 * 3 + 2)
  let mut i := 0
  while i + 4 ≤ s.size do
    out := out.push (s[i]! <<< 2 ||| s[i + 1]! >>> 4)
    out := out.push (s[i + 1]! <<< 4 ||| s[i + 2]! >>> 2)
    out := out.push (s[i + 2]! <<< 6 ||| s[i + 3]!)
    i := i + 4
  if i + 2 ≤ s.size then out := out.push (s[i]! <<< 2 ||| s[i + 1]! >>> 4)
  if i + 3 ≤ s.size then out := out.push (s[i + 1]! <<< 4 ||| s[i + 2]! >>> 2)
  return out

/-- `base64Decode`. -/
def base64Decode (b : ByteArray) : ByteArray := b64Emit (b64Sextets b)

#guard (base64Decode ⟨"VGVzdENhc2U=".toUTF8.data⟩).data == "TestCase".toUTF8.data
#guard (base64Decode ⟨"VGVzdENhc2Ux".toUTF8.data⟩).data == "TestCase1".toUTF8.data
#guard (base64Decode ⟨"VGVzdABDYXNl".toUTF8.data⟩).data == #[0x54, 0x65, 0x73, 0x74, 0x00, 0x43, 0x61, 0x73, 0x65]
#guard (base64Decode ⟨"VGVzdENhc2U".toUTF8.data⟩).data == "TestCase".toUTF8.data
#guard (base64Decode ⟨"VGVzdENhc2UxV".toUTF8.data⟩).data == "TestCase1".toUTF8.data
#guard (base64Decode ⟨"VGVz*dENh".toUTF8.data⟩).data == "Tes".toUTF8.data
#guard (base64Decode ⟨#[0x56, 0x47, 0x56, 0x7A, 0x00, 0x64]⟩).data == "Tes".toUTF8.data
#guard (base64Decode ⟨#[]⟩).data == #[]

/-- `uppercase`: ASCII `a`–`z` to `A`–`Z`. libmodsecurity `upper_case.cc`; absent from v2. -/
def uppercase : ByteArray → ByteArray := mapBytes fun x => if 97 ≤ x && x ≤ 122 then x - 32 else x

/-- `removeNulls`. re_tfns.c `msre_fn_removeNulls_execute`. -/
def removeNulls : ByteArray → ByteArray := filterBytes (· != 0)

/-- `replaceNulls`: NUL to space. re_tfns.c `msre_fn_replaceNulls_execute`. -/
def replaceNulls : ByteArray → ByteArray := mapBytes fun x => if x == 0 then 32 else x

/-- Whitespace for the whitespace transformations: C `isspace` or the NBSP byte `0xA0`. -/
def isWs (x : UInt8) : Bool := isSpace x || x == 0xA0

/-- `removeWhitespace`. re_tfns.c `msre_fn_removeWhitespace_execute`. -/
def removeWhitespace : ByteArray → ByteArray := filterBytes (!isWs ·)

/-- `trimLeft`: drop leading `isspace` bytes. re_tfns.c `msre_fn_trimLeft_execute`. -/
def trimLeft (b : ByteArray) : ByteArray :=
  let n := takeWhile b isSpace 0 b.size
  b.extract n b.size

/-- `trimRight`: drop trailing `isspace` bytes. re_tfns.c `msre_fn_trimRight_execute`. -/
def trimRight (b : ByteArray) : ByteArray := go b.size
where
  go : Nat → ByteArray
    | 0 => .empty
    | k + 1 => if (byteAt b k).any isSpace then go k else b.extract 0 (k + 1)

/-- `trim`. re_tfns.c `msre_fn_trim_execute`. -/
def trim (b : ByteArray) : ByteArray := trimRight (trimLeft b)

/-- `length`: the byte count as a decimal string. re_tfns.c `msre_fn_length_execute`. -/
def length (b : ByteArray) : ByteArray := (toString b.size).toUTF8

/-- `true` when `x` has an odd number of one bits (all eight). re_tfns.c
`msre_fn_parityEven7bit_execute`: `x ^= x >> 4; x &= 0xf; (0x6996 >> x) & 1`. -/
def oddParity (x : UInt8) : Bool :=
  let n := (x ^^^ (x >>> 4)) &&& 0xF
  ((0x6996 : UInt32) >>> n.toUInt32) &&& 1 == 1

/-- `parityEven7bit`: set bit 7 when the eight-bit parity is odd, clear it otherwise. A byte
whose bit 7 is already set therefore keeps odd parity (v2 and v3 behaviour, `spec/07`). -/
def parityEven7bit : ByteArray → ByteArray :=
  mapBytes fun x => if oddParity x then x ||| 0x80 else x &&& 0x7F

/-- `parityOdd7bit`: the complement rule of `parityEven7bit`. -/
def parityOdd7bit : ByteArray → ByteArray :=
  mapBytes fun x => if oddParity x then x &&& 0x7F else x ||| 0x80

/-- `parityZero7bit`: clear bit 7. re_tfns.c `msre_fn_parityZero7bit_execute`. -/
def parityZero7bit : ByteArray → ByteArray := mapBytes (· &&& 0x7F)

#guard (uppercase ⟨"Test\u0000Case 1".toUTF8.data⟩).data == "TEST\u0000CASE 1".toUTF8.data
#guard (removeNulls ⟨#[0, 0x54, 0, 0, 0x43, 0]⟩).data == #[0x54, 0x43]
#guard (replaceNulls ⟨#[0, 0x54, 0]⟩).data == #[0x20, 0x54, 0x20]
#guard (removeWhitespace ⟨#[0x20, 0x54, 9, 10, 11, 12, 13, 0xA0, 0x43, 0]⟩).data == #[0x54, 0x43, 0]
#guard (trimLeft ⟨" \t  T \u0000 C \t\r\n ".toUTF8.data⟩).data == "T \u0000 C \t\r\n ".toUTF8.data
#guard (trimRight ⟨" \t  T \u0000 C \t\r\n ".toUTF8.data⟩).data == " \t  T \u0000 C".toUTF8.data
#guard (trim ⟨" \t  T \u0000 C \t\r\n ".toUTF8.data⟩).data == "T \u0000 C".toUTF8.data
#guard (trim ⟨"   ".toUTF8.data⟩).data == #[]
#guard (length ⟨"Test\u0000Case".toUTF8.data⟩).data == "9".toUTF8.data
#guard (length ⟨#[]⟩).data == "0".toUTF8.data
#guard (parityEven7bit ⟨"abc0".toUTF8.data⟩).data == #[0xE1, 0xE2, 0x63, 0x30]
#guard (parityOdd7bit ⟨"abc0".toUTF8.data⟩).data == #[0x61, 0x62, 0xE3, 0xB0]
#guard (parityZero7bit ⟨#[0xC2, 0x80, 0x00, 0xFF]⟩).data == #[0x42, 0x00, 0x00, 0x7F]

/-- `compressWhitespace`: each run of whitespace (`isspace` or `0xA0`) becomes one space.
re_tfns.c `msre_fn_compressWhitespace_execute`. -/
def compressWhitespace (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity b.size
  let mut inWs := false
  for x in b do
    if isWs x then
      inWs := true
    else
      if inWs then out := out.push 32
      inWs := false
      out := out.push x
  if inWs then out := out.push 32
  return out

/-- `hexDecode`: every complete pair of bytes as two hexadecimal digits; a trailing odd byte
is dropped. A non-hex byte is unspecified (`spec/07#hexdecode`; v2 `hex2bytes_inplace` and
v3 `hex_decode.cc` apply digit arithmetic to it) and counts as 0 here. -/
def hexDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if i + 1 < b.size then
      go (i + 2) (out.push ((hexAt b i).getD 0 * 16 + (hexAt b (i + 1)).getD 0))
    else out
  termination_by b.size - i

/-- `urlDecode`: `%XX` and `+`; no `%u`. msc_util.c `urldecode_nonstrict_inplace_ex`. -/
def urlDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c == '+'.toUInt8 then go (i + 1) (out.push 32)
      else if c == '%'.toUInt8 then
        match hexAt b (i + 1), hexAt b (i + 2) with
        | some h1, some h2 => go (i + 3) (out.push (h1 * 16 + h2))
        | _, _ => go (i + 1) (out.push c)
      else go (i + 1) (out.push c)
    else out
  termination_by b.size - i

/-- `urlEncode`: space to `+`; `*`, digits and ASCII letters kept; every other byte `%xx`
in lowercase. msc_util.c `url_encode`. -/
def urlEncode (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity (3 * b.size)
  for x in b do
    if x == 32 then out := out.push '+'.toUInt8
    else if x == '*'.toUInt8 || isAlnum x then out := out.push x
    else out := pushHex (out.push '%'.toUInt8) x
  return out

/-- Number of consecutive hexadecimal digit pairs at `j`, at most `fuel`. -/
def hexPairs (b : ByteArray) (j : Nat) : Nat → Nat
  | 0 => 0
  | k + 1 => if (hexAt b j).isSome && (hexAt b (j + 1)).isSome then 1 + hexPairs b (j + 2) k else 0

/-- `sqlHexDecode`: `0x` or `0X` followed by at least one pair of hexadecimal digits
becomes the bytes of every following pair; a `0x` with no pair is kept. Reference:
libmodsecurity v3 `sql_hex_decode.cc`. ModSecurity v2 `sql_hex2bytes_inplace` differs:
it copies the byte after a literal without examining it (`0x410x42` gives `A0x42`) and
truncates the value at a decoded NUL (`strlen`). -/
def sqlHexDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let isX := (byteAt b (i + 1)).any fun u => u == 'x'.toUInt8 || u == 'X'.toUInt8
      let n := if b[i] == '0'.toUInt8 && isX then hexPairs b (i + 2) b.size else 0
      if n == 0 then go (i + 1) (out.push b[i])
      else
        go (i + 2 + 2 * n) (Id.run do
          let mut o := out
          for k in [:n] do
            o := o.push ((hexAt b (i + 2 + 2 * k)).getD 0 * 16 + (hexAt b (i + 3 + 2 * k)).getD 0)
          return o)
    else out
  termination_by b.size - i

#guard (compressWhitespace ⟨"  T  \t   C  ".toUTF8.data⟩).data == " T C ".toUTF8.data
#guard (compressWhitespace ⟨#[0x61, 0xA0, 0xA0, 0x62, 0x00]⟩).data == #[0x61, 0x20, 0x62, 0x00]
#guard (hexDecode ⟨"546573740043617365".toUTF8.data⟩).data == "Test\u0000Case".toUTF8.data
#guard (hexDecode ⟨"01234567890a0".toUTF8.data⟩).data == #[0x01, 0x23, 0x45, 0x67, 0x89, 0x0A]
#guard (urlDecode ⟨"Test+Case%41%u0042%".toUTF8.data⟩).data == "Test CaseA%u0042%".toUTF8.data
#guard (urlEncode ⟨" !*09AZaz~\u00ff".toUTF8.data⟩).data == "+%21*09AZaz%7e%c3%bf".toUTF8.data
#guard (sqlHexDecode ⟨"0x414243".toUTF8.data⟩).data == "ABC".toUTF8.data
#guard (sqlHexDecode ⟨"a0X41420x0xzz0x4".toUTF8.data⟩).data == "aAB0x0xzz0x4".toUTF8.data

/-- Sextets of every alphabet byte; `=`, NUL and any other byte are skipped (libmodsecurity v3
`decode_forgiven_engine`, Coraza `base64decode.go` ext mode; ModSecurity v2
`decode_base64_ext` stops at NUL). The "`=` after a dangling sextet yields the empty
value" quirk of v2 and v3 is not modelled: `spec/07#base64decodeext` leaves it unspecified. -/
def b64SextetsExt (b : ByteArray) : Array UInt8 := Id.run do
  let mut out := #[]
  for x in b do
    if let some v := b64Val x then out := out.push v
  return out

/-- `base64DecodeExt`. -/
def base64DecodeExt (b : ByteArray) : ByteArray := b64Emit (b64SextetsExt b)

/-- Alphabet byte of a sextet. -/
def b64Char (v : UInt8) : UInt8 :=
  if v < 26 then 65 + v else if v < 52 then 71 + v else if v < 62 then v - 4
  else if v == 62 then '+'.toUInt8 else '/'.toUInt8

/-- `base64Encode`: RFC 4648 §4 with `=` padding. re_tfns.c `msre_fn_base64Encode_execute`
(`apr_base64_encode`). -/
def base64Encode (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity ((b.size + 2) / 3 * 4)
  let mut i := 0
  while i + 3 ≤ b.size do
    let x := b[i]!; let y := b[i + 1]!; let z := b[i + 2]!
    out := out.push (b64Char (x >>> 2))
    out := out.push (b64Char (((x &&& 3) <<< 4) ||| (y >>> 4)))
    out := out.push (b64Char (((y &&& 15) <<< 2) ||| (z >>> 6)))
    out := out.push (b64Char (z &&& 63))
    i := i + 3
  if i + 1 == b.size then
    let x := b[i]!
    out := out.push (b64Char (x >>> 2))
    out := out.push (b64Char ((x &&& 3) <<< 4))
    out := (out.push 61).push 61
  else if i + 2 == b.size then
    let x := b[i]!; let y := b[i + 1]!
    out := out.push (b64Char (x >>> 2))
    out := out.push (b64Char (((x &&& 3) <<< 4) ||| (y >>> 4)))
    out := out.push (b64Char ((y &&& 15) <<< 2))
    out := out.push 61
  return out

#guard (base64Encode ⟨"Test\u0000Case".toUTF8.data⟩).data == "VGVzdABDYXNl".toUTF8.data
#guard (base64Encode ⟨"TestCase1".toUTF8.data⟩).data == "VGVzdENhc2Ux".toUTF8.data
#guard (base64Encode ⟨"TestCase12".toUTF8.data⟩).data == "VGVzdENhc2UxMg==".toUTF8.data
#guard (base64Encode ⟨#[]⟩).data == #[]
#guard (base64DecodeExt ⟨"P.HNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==".toUTF8.data⟩).data == "<script>alert(1)</script>".toUTF8.data
#guard (base64DecodeExt ⟨"VGVz\u0000dENh".toUTF8.data⟩).data == "TestCa".toUTF8.data
#guard (base64DecodeExt ⟨"VG=Vz".toUTF8.data⟩).data == "Tes".toUTF8.data

/-- `cmdLine`. re_tfns.c `msre_fn_cmdline_execute`: deletes `"`, `'`, `\`, `^`; collapses
runs of space, `,`, `;`, HT, CR, LF to one space and drops that space before `/` or `(`;
lower-cases ASCII letters. v2 stops at a NUL byte (C string); v3 and Coraza, and this
definition, process every byte. -/
def cmdLine (b : ByteArray) : ByteArray := Id.run do
  let mut out := ByteArray.emptyWithCapacity b.size
  let mut space := false
  for x in b do
    if x == '"'.toUInt8 || x == '\''.toUInt8 || x == '\\'.toUInt8 || x == '^'.toUInt8 then
      continue
    if x == 32 || x == ','.toUInt8 || x == ';'.toUInt8 || x == 9 || x == 13 || x == 10 then
      if !space then
        out := out.push 32
        space := true
    else if x == '/'.toUInt8 || x == '('.toUInt8 then
      if space then out := out.extract 0 (out.size - 1)
      space := false
      out := out.push x
    else
      out := out.push (if 65 ≤ x && x ≤ 90 then x + 32 else x)
      space := false
  return out

/-- `removeCommentsChar`: drops `/*`, `*/`, `<!--`, `-->`, `--` and `#`. re_tfns.c
`msre_fn_removeCommentsChar_execute`. -/
def removeCommentsChar (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      let n1 := byteAt b (i + 1); let n2 := byteAt b (i + 2); let n3 := byteAt b (i + 3)
      if c == '/'.toUInt8 && n1 == some '*'.toUInt8 then go (i + 2) out
      else if c == '*'.toUInt8 && n1 == some '/'.toUInt8 then go (i + 2) out
      else if c == '<'.toUInt8 && n1 == some '!'.toUInt8 && n2 == some '-'.toUInt8 && n3 == some '-'.toUInt8 then go (i + 4) out
      else if c == '-'.toUInt8 && n1 == some '-'.toUInt8 && n2 == some '>'.toUInt8 then go (i + 3) out
      else if c == '-'.toUInt8 && n1 == some '-'.toUInt8 then go (i + 2) out
      else if c == '#'.toUInt8 then go (i + 1) out
      else go (i + 1) (out.push c)
    else out
  termination_by b.size - i

/-- `removeComments`. re_tfns.c `msre_fn_removeComments_execute`: outside a comment, `/*`
and `<!--` open one and `--` or `#` ends the value; inside, `*/` and `-->` close it and
the byte after the terminator is copied as is, which at end of input is the C terminator,
one NUL byte, in every engine (v3 `remove_comments.cc`; Coraza `remove_comments.go` pads
the input with NUL to reproduce it). An unterminated comment yields one space. -/
def removeComments (b : ByteArray) : ByteArray := go 0 false .empty
where
  go (i : Nat) (inComment : Bool) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      let n1 := byteAt b (i + 1); let n2 := byteAt b (i + 2); let n3 := byteAt b (i + 3)
      if !inComment then
        if c == '/'.toUInt8 && n1 == some '*'.toUInt8 then go (i + 2) true out
        else if c == '<'.toUInt8 && n1 == some '!'.toUInt8 && n2 == some '-'.toUInt8 && n3 == some '-'.toUInt8 then go (i + 4) true out
        else if (c == '-'.toUInt8 && n1 == some '-'.toUInt8) || c == '#'.toUInt8 then out
        else go (i + 1) false (out.push c)
      else
        if c == '*'.toUInt8 && n1 == some '/'.toUInt8 then go (i + 3) false (out.push (n2.getD 0))
        else if c == '-'.toUInt8 && n1 == some '-'.toUInt8 && n2 == some '>'.toUInt8 then go (i + 4) false (out.push (n3.getD 0))
        else go (i + 1) true out
    else if inComment then out.push 32 else out
  termination_by b.size - i

/-- `replaceComments`: each `/* ... */` becomes one space; an unterminated comment becomes
one space. re_tfns.c `msre_fn_replaceComments_execute`. -/
def replaceComments (b : ByteArray) : ByteArray := go 0 false .empty
where
  go (i : Nat) (inComment : Bool) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      let n1 := byteAt b (i + 1)
      if !inComment then
        if c == '/'.toUInt8 && n1 == some '*'.toUInt8 then go (i + 2) true out
        else go (i + 1) false (out.push c)
      else if c == '*'.toUInt8 && n1 == some '/'.toUInt8 then go (i + 2) false (out.push 32)
      else go (i + 1) true out
    else if inComment then out.push 32 else out
  termination_by b.size - i

#guard (cmdLine ⟨"C^OMMAND /C DIR".toUTF8.data⟩).data == "command/c dir".toUTF8.data
#guard (cmdLine ⟨"\"cmd\",;\t\r\n/c (x) \u000b".toUTF8.data⟩).data == "cmd/c(x) \u000b".toUTF8.data
#guard (removeCommentsChar ⟨"a/*b*/c--d#e<!--f-->g".toUTF8.data⟩).data == "abcdefg".toUTF8.data
#guard (removeComments ⟨"/* TestCase */".toUTF8.data⟩).data == #[0]
#guard (removeComments ⟨"Before/* T*/ /* e */ /* s */ /* t */\r\nCase ".toUTF8.data⟩).data == "Before   \r\nCase ".toUTF8.data
#guard (removeComments ⟨"a <!-- b --> c -- d".toUTF8.data⟩).data == "a  c ".toUTF8.data
#guard (removeComments ⟨"a # b".toUTF8.data⟩).data == "a ".toUTF8.data
#guard (removeComments ⟨"Before /* Test".toUTF8.data⟩).data == "Before  ".toUTF8.data
#guard (replaceComments ⟨"Before /* TestCase */ After".toUTF8.data⟩).data == "Before   After".toUTF8.data
#guard (replaceComments ⟨"Before/* Test".toUTF8.data⟩).data == "Before ".toUTF8.data

/-- The byte for a C/JavaScript single-letter escape; any other byte stands for itself. -/
def cEscape (n : UInt8) : UInt8 :=
  if n == 'a'.toUInt8 then 7 else if n == 'b'.toUInt8 then 8 else if n == 'f'.toUInt8 then 12
  else if n == 'n'.toUInt8 then 10 else if n == 'r'.toUInt8 then 13 else if n == 't'.toUInt8 then 9
  else if n == 'v'.toUInt8 then 11 else n

/-- Value of the `j` octal digits at `p`, modulo 256. -/
def octValue (b : ByteArray) (p j : Nat) : UInt8 := Id.run do
  let mut v : Nat := 0
  for k in [:j] do v := v * 8 + ((byteAt b (p + k)).getD 48 - 48).toNat
  return (v % 256).toUInt8

/-- `escapeSeqDecode`: ANSI C escapes. msc_util.c `ansi_c_sequences_decode_inplace`. -/
def escapeSeqDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c != '\\'.toUInt8 then go (i + 1) (out.push c)
      else match byteAt b (i + 1) with
        | none => out.push c                                   -- lone trailing backslash kept
        | some n =>
          if n == 'x'.toUInt8 || n == 'X'.toUInt8 then
            match hexAt b (i + 2), hexAt b (i + 3) with
            | some h1, some h2 => go (i + 4) (out.push (h1 * 16 + h2))
            | _, _ => go (i + 2) (out.push n)                  -- "x" kept, backslash dropped
          else if isOctal n then
            let j := takeWhile b isOctal (i + 1) 3
            go (i + 1 + j) (out.push (octValue b (i + 1) j))
          else go (i + 2) (out.push (cEscape n))
    else out
  termination_by b.size - i

/-- `jsDecode`: `\uHHHH` (low byte, full-width fold as `urlDecodeUni`), `\xHH`, octal up to
three digits (two when three would exceed one byte), `\a \b \f \n \r \t \v`; any other
escaped byte stands for itself. msc_util.c `js_decode_nonstrict_inplace`. -/
def jsDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c != '\\'.toUInt8 then go (i + 1) (out.push c)
      else match byteAt b (i + 1) with
        | none => out.push c
        | some n =>
          match n == 'u'.toUInt8, hexAt b (i + 2), hexAt b (i + 3), hexAt b (i + 4), hexAt b (i + 5) with
          | true, some h2, some h3, some h4, some h5 => go (i + 6) (out.push (uniByte (fun _ => none) h2 h3 h4 h5))
          | _, _, _, _, _ =>
            match n == 'x'.toUInt8, hexAt b (i + 2), hexAt b (i + 3) with
            | true, some h1, some h2 => go (i + 4) (out.push (h1 * 16 + h2))
            | _, _, _ =>
              if isOctal n then
                let j0 := takeWhile b isOctal (i + 1) 3
                let j := if j0 == 3 && n > '3'.toUInt8 then 2 else j0
                go (i + 1 + j) (out.push (octValue b (i + 1) j))
              else go (i + 2) (out.push (cEscape n))
    else out
  termination_by b.size - i

/-- The named entities of ADR-0031: every WHATWG entity that is one code point up to U+007F,
plus `nbsp` and `shy`, as generated in msc_util.c `msc_html_named_entities` (v2.9.15) and
html_entity_decode.cc `named_entities` (v3.0.17). -/
def namedEntities : List (String × UInt8) :=
  [("amp", 0x26), ("apos", 0x27), ("ast", 0x2A), ("bsol", 0x5C), ("colon", 0x3A),
   ("comma", 0x2C), ("commat", 0x40), ("diacriticalgrave", 0x60), ("dollar", 0x24),
   ("equals", 0x3D), ("excl", 0x21), ("grave", 0x60), ("gt", 0x3E), ("hat", 0x5E),
   ("lbrace", 0x7B), ("lbrack", 0x5B), ("lcub", 0x7B), ("lowbar", 0x5F), ("lpar", 0x28),
   ("lsqb", 0x5B), ("lt", 0x3C), ("midast", 0x2A), ("nbsp", 0xA0), ("newline", 0x0A),
   ("nonbreakingspace", 0xA0), ("num", 0x23), ("percnt", 0x25), ("period", 0x2E),
   ("plus", 0x2B), ("quest", 0x3F), ("quot", 0x22), ("rbrace", 0x7D), ("rbrack", 0x5D),
   ("rcub", 0x7D), ("rpar", 0x29), ("rsqb", 0x5D), ("semi", 0x3B), ("shy", 0xAD),
   ("sol", 0x2F), ("tab", 0x09), ("underbar", 0x5F), ("verbar", 0x7C), ("vert", 0x7C),
   ("verticalline", 0x7C)]

/-- The byte of a named entity, the whole name compared case-insensitively. -/
def namedEntity (name : ByteArray) : Option UInt8 :=
  let s := (lowercase name).data
  (namedEntities.find? (fun (n, _) => n.toUTF8.data == s)).map (·.2)

/-- Value of the `n` digits at `p` in the given base, modulo 256. -/
def digitsValue (b : ByteArray) (p n base : Nat) : UInt8 := Id.run do
  let mut v : Nat := 0
  for k in [:n] do v := v * base + ((byteAt b (p + k)).bind hexVal |>.getD 0).toNat
  return (v % 256).toUInt8

/-- `htmlEntityDecode`. msc_util.c `html_entities_decode_inplace`: `&#NNN;`, `&#xHH;` (the
`;` optional, the value modulo 256; v2's `strtol` saturates instead for values beyond
`long`) and the named entities of `namedEntities`; anything else is copied. -/
def htmlEntityDecode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      let c := b[i]
      if c != '&'.toUInt8 then go (i + 1) (out.push c)
      else if byteAt b (i + 1) == some '#'.toUInt8 then
        -- `hx` is 1 for the `&#x` form: the digits start at `i + 2 + hx`
        let hx := if (byteAt b (i + 2)).any (fun u => u == 'x'.toUInt8 || u == 'X'.toUInt8) then 1 else 0
        let n := takeWhile b (if hx == 1 then isHex else isDigit) (i + 2 + hx) b.size
        if n == 0 then go (i + 1) (out.push c)
        else
          let semi := if byteAt b (i + 2 + hx + n) == some ';'.toUInt8 then 1 else 0
          go (i + 2 + hx + n + semi) (out.push (digitsValue b (i + 2 + hx) n (if hx == 1 then 16 else 10)))
      else
        let n := takeWhile b isAlnum (i + 1) b.size
        match if n == 0 then none else namedEntity (b.extract (i + 1) (i + 1 + n)) with
        | some v =>
          let semi := if byteAt b (i + 1 + n) == some ';'.toUInt8 then 1 else 0
          go (i + 1 + n + semi) (out.push v)
        | none => go (i + 1) (out.push c)
    else out
  termination_by b.size - i

#guard (escapeSeqDecode ⟨"\\a\\b\\f\\n\\r\\t\\v\\?\\'\\\"\\0\\12\\123".toUTF8.data⟩).data == #[7, 8, 12, 10, 13, 9, 11, 0x3F, 0x27, 0x22, 0, 10, 0x53]
#guard (escapeSeqDecode ⟨"\\8\\9\\666\\x41\\xag\\x\\".toUTF8.data⟩).data == "89\u00b6Axagx\\".toUTF8.data.filter (· != 0xC2)
#guard (jsDecode ⟨"\\u0041\\uff01\\x42\\101\\400\\a\\q\\".toUTF8.data⟩).data == "A!BA 0\u0007q\\".toUTF8.data
#guard (jsDecode ⟨"\\u\\u0\\u01\\u012".toUTF8.data⟩).data == "uu0u01u012".toUTF8.data
#guard (htmlEntityDecode ⟨"&#x41;&#X42&#67;&#68&quot;&AMP&lt&gt;&nbsp;&foo;&#xg;&#;&".toUTF8.data⟩).data
  == ("ABCD\"&<>".toUTF8.push 0xA0 ++ "&foo;&#xg;&#;&".toUTF8).data
#guard (htmlEntityDecode ⟨"javascript&colon;alert&LPAR;1&rpar&ltest;&Tab;".toUTF8.data⟩).data
  == "javascript:alert(1)&ltest;\t".toUTF8.data

/-- `normalisePath` / `normalisePathWin`. A transcription of msc_util.c
`normalize_path_inplace`: `src` walks the input, `out` is the output written so far (the C
`dst`), `hitroot` remembers a relative path that climbed above its start. When `win`, every
backslash is converted to `/` first, as the spec says; v2 and v3 convert only the current
and the next byte and keep a backslash reached while skipping a run of slashes
(`spec/07#normalisepathwin`). -/
def normalisePathWith (win : Bool) (b0 : ByteArray) : ByteArray := Id.run do
  if b0.size == 0 then return b0
  let b := if win then mapBytes (fun x => if x == '\\'.toUInt8 then '/'.toUInt8 else x) b0 else b0
  let last := b.size - 1
  let slash := '/'.toUInt8
  let dot := '.'.toUInt8
  let relative := b[0]! != slash
  let trailing := b[last]! == slash
  let mut src := 0
  let mut out : Array UInt8 := #[]
  let mut hitroot := false
  let mut done := false
  while !done && src ≤ last && out.size ≤ last do
    let c := b[src]!
    let mut copy := true
    if src == last then done := true
    if done || byteAt b (src + 1) == some slash then
      if src != last && c == slash then
        pure ()                                              -- empty segment: copy skips it
      else if c == dot then
        if out.size > 0 && out[out.size - 1]! == dot then     -- back-reference
          if relative && (hitroot || out.size ≤ 2) then
            hitroot := true
          else
            let mut d := out.size - 3
            while d > 0 && out[d]! != slash do d := d - 1
            if d == 0 then
              hitroot := true
              d := if !relative && src == last then 1 else 0
            out := out.extract 0 d
            if done then copy := false else src := src + 1
        else if out.size == 0 then                            -- relative self-reference
          if done then copy := false else src := src + 1
        else if out[out.size - 1]! == slash then              -- self-reference
          if done then copy := false
          else
            out := out.pop
            src := src + 1
      else if out.size > 0 then
        hitroot := false
    if copy then
      if b[src]! == slash then
        while src < last && b[src + 1]! == slash do src := src + 1
        if relative && out.size == 0 then
          src := src + 1
          copy := false
      if copy then
        out := out.push b[src]!
        src := src + 1
  if !trailing && out.size > 0 && out[out.size - 1]! == slash then out := out.pop
  return ⟨out⟩

def normalisePath : ByteArray → ByteArray := normalisePathWith false
def normalisePathWin : ByteArray → ByteArray := normalisePathWith true

/-- A well-formed multi-byte UTF-8 sequence at `i` (RFC 3629: continuation bytes, no
overlong form, no surrogate, at most U+10FFFF): its length and code point. -/
def utf8Seq (b : ByteArray) (i : Nat) : Option (Nat × Nat) := do
  let c := (← byteAt b i).toNat
  let cont (k : Nat) : Option Nat := do
    let x := (← byteAt b (i + k)).toNat
    if x &&& 0xC0 == 0x80 then some (x &&& 0x3F) else none
  if c &&& 0xE0 == 0xC0 then
    let d := ((c &&& 0x1F) <<< 6) ||| (← cont 1)
    if d < 0x80 then none else some (2, d)
  else if c &&& 0xF0 == 0xE0 then
    let d := ((c &&& 0x0F) <<< 12) ||| ((← cont 1) <<< 6) ||| (← cont 2)
    if d < 0x800 || (0xD800 ≤ d && d ≤ 0xDFFF) then none else some (3, d)
  else if c &&& 0xF8 == 0xF0 then
    let d := ((c &&& 0x07) <<< 18) ||| ((← cont 1) <<< 12) ||| ((← cont 2) <<< 6) ||| (← cont 3)
    if d < 0x10000 || d > 0x10FFFF then none else some (4, d)
  else none

/-- `%u` followed by at least four lowercase hexadecimal digits of `d`. -/
def pushUni (out : ByteArray) (d : Nat) : ByteArray := Id.run do
  let digits := Nat.toDigits 16 d
  let mut o := (out.push '%'.toUInt8).push 'u'.toUInt8
  for _ in [:4 - min 4 digits.length] do o := o.push '0'.toUInt8
  for ch in digits do o := o.push ch.toNat.toUInt8
  return o

/-- `utf8toUnicode`: each well-formed multi-byte sequence becomes `%uXXXX`; every other byte
is copied. msc_util.c `utf8_unicode_inplace_ex` for well-formed input; its NUL handling
and v3's differ from the prose and from each other (`spec/07#utf8tounicode`). -/
def utf8toUnicode (b : ByteArray) : ByteArray := go 0 .empty
where
  go (i : Nat) (out : ByteArray) : ByteArray :=
    if h : i < b.size then
      match utf8Seq b i with
      | some (2, d) => go (i + 2) (pushUni out d)
      | some (3, d) => go (i + 3) (pushUni out d)
      | some (4, d) => go (i + 4) (pushUni out d)
      | _ => go (i + 1) (out.push b[i])
    else out
  termination_by b.size - i

#guard (normalisePath ⟨"dir/../../foo".toUTF8.data⟩).data == "../foo".toUTF8.data
#guard (normalisePath ⟨"/dir/./subdir/../subsubdir/../subsubsubdir/../".toUTF8.data⟩).data == "/dir/".toUTF8.data
#guard (normalisePath ⟨"./..".toUTF8.data⟩).data == "..".toUTF8.data
#guard (normalisePath ⟨"/./.././../../../../../../../\u0000/../etc/./passwd".toUTF8.data⟩).data == "/etc/passwd".toUTF8.data
#guard (normalisePath ⟨"dir//.//..//.//..//..//foo//bar//".toUTF8.data⟩).data == "../../foo/bar/".toUTF8.data
#guard (normalisePathWin ⟨"\\dir\\foo\\\\bar".toUTF8.data⟩).data == "/dir/foo/bar".toUTF8.data
#guard (normalisePathWin ⟨"..\\".toUTF8.data⟩).data == "../".toUTF8.data
#guard (normalisePathWin ⟨"a//\\b".toUTF8.data⟩).data == "a/b".toUTF8.data
#guard (utf8toUnicode ⟨#[0x61, 0xC3, 0xA9, 0xE2, 0x82, 0xAC, 0xF0, 0x9F, 0x98, 0x80, 0x62]⟩).data == "a%u00e9%u20ac%u1f600b".toUTF8.data
#guard (utf8toUnicode ⟨#[0x61, 0xC3]⟩).data == #[0x61, 0xC3]
#guard (utf8toUnicode ⟨#[0xC0, 0x80, 0xED, 0xA0, 0x80, 0x00, 0xC3]⟩).data == #[0xC0, 0x80, 0xED, 0xA0, 0x80, 0x00, 0xC3]

end SecLang
