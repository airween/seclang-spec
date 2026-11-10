# ModSecurity v2 + Apache httpd + msc_test, for adapters/modsecurity2.
# Build from the repository root (the context is narrowed by Dockerfile.dockerignore):
#   docker build -t seclang-modsecurity2 -f adapters/modsecurity2/Dockerfile .
# To build a local ModSecurity v2 checkout (with submodules) instead of the pinned tag, replace
# the modsecurity2-src stage with it, as action.yml does:
#   docker build --build-context modsecurity2-src=/path/to/ModSecurity ...
# Package list from v2's own .github/workflows/ci.yml (PCRE2 is the default). The base is
# pinned by digest; apt still resolves bookworm's current packages at build time (Apache
# 2.4.68 on 2026-11-09), and CI keeps the built image cached.
FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS modsecurity2-clone

ARG MODSECURITY2_REF=v2.9.15

RUN apt-get update -qq && apt-get install -y --no-install-recommends ca-certificates git \
    && git clone --depth 1 -b "$MODSECURITY2_REF" --recurse-submodules --shallow-submodules \
      https://github.com/owasp-modsecurity/ModSecurity.git /src

# The source tree alone, at the root, so a --build-context of that name can stand in for it.
FROM scratch AS modsecurity2-src
COPY --from=modsecurity2-clone /src /

FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      ca-certificates git build-essential autoconf automake libtool pkg-config \
      apache2 apache2-dev libxml2-dev libpcre2-dev libyajl-dev libcurl4-gnutls-dev \
      python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=modsecurity2-src / /src
RUN cd /src && ./autogen.sh && ./configure --without-lua \
    && make -j"$(nproc)" && make install && make -C tests msc_test \
    && cp tests/msc_test /usr/local/bin/msc_test

COPY --from=ghcr.io/astral-sh/uv:0.12.15 /uv /usr/local/bin/uv

ENV MODSECURITY2_HTTPD=/usr/sbin/apache2 \
    MODSECURITY2_MODULE=/usr/lib/apache2/modules/mod_security2.so \
    MODSECURITY2_MSC_TEST=/usr/local/bin/msc_test \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PYTHONDONTWRITEBYTECODE=1

# The repository's locked dependencies, so a run needs no network and writes nothing but
# test temp files (the checkout is mounted at /repo and may be owned by another user).
COPY pyproject.toml uv.lock /opt/seclang/
RUN cd /opt/seclang && uv sync --frozen

WORKDIR /repo
