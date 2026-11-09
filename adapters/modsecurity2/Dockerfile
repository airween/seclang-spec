# ModSecurity v2 + Apache httpd + msc_test, for adapters/modsecurity2.
# Package list from v2's own .github/workflows/ci.yml (PCRE2 is the default).
FROM debian:bookworm-slim

ARG MODSECURITY2_REF=v2.9.15

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      ca-certificates git build-essential autoconf automake libtool pkg-config \
      apache2 apache2-dev libxml2-dev libpcre2-dev libyajl-dev libcurl4-gnutls-dev \
      python3 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 -b "$MODSECURITY2_REF" --recurse-submodules --shallow-submodules \
      https://github.com/owasp-modsecurity/ModSecurity.git /src \
    && cd /src && ./autogen.sh && ./configure --without-lua \
    && make -j"$(nproc)" && make install && make -C tests msc_test \
    && cp tests/msc_test /usr/local/bin/msc_test

COPY --from=ghcr.io/astral-sh/uv:0.12.15 /uv /usr/local/bin/uv

ENV MODSECURITY2_HTTPD=/usr/sbin/apache2 \
    MODSECURITY2_MODULE=/usr/lib/apache2/modules/mod_security2.so \
    MODSECURITY2_MSC_TEST=/usr/local/bin/msc_test \
    UV_PROJECT_ENVIRONMENT=/opt/venv
WORKDIR /repo
