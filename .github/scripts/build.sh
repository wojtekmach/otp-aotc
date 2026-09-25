#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
: "${OTP_SHA:?}"
: "${ELIXIR_SHA:?}"
: "${HEX_VERSION:?}"
: "${TARGET:?}"
[[ "$OTP_SHA" =~ ^[0-9a-f]{40}$ && "$ELIXIR_SHA" =~ ^[0-9a-f]{40}$ ]] || exit 1
case "$TARGET" in darwin-arm64|darwin-x86_64|linux-arm64|linux-x86_64) ;; *) exit 1 ;; esac

git clone --filter=blob:none --no-checkout https://github.com/erlang/otp.git otp
git -C otp checkout --detach "$OTP_SHA"
git -C otp config user.email ci@example.com
git -C otp config user.name ci
# Fail on patch conflicts rather than resolving or ignoring them automatically.
GIT_EDITOR=true git -C otp am "$ROOT"/patches/*.patch

cd otp
if [[ "$(uname -s)" == Darwin ]]; then
  SSL_FLAGS=("--with-ssl=$(brew --prefix openssl@3)" "LIBS=$(brew --prefix openssl@3)/lib/libcrypto.a")
else
  SSL_FLAGS=("LIBS=/usr/lib/$(uname -m)-linux-gnu/libcrypto.a")
fi
./configure --enable-jit --enable-static-nifs --disable-dynamic-ssl-lib \
  --without-javac --without-wx --without-observer --without-debugger --without-et \
  --without-megaco --without-diameter --without-snmp --without-jinterface --without-odbc \
  "${SSL_FLAGS[@]}" > configure.log 2>&1 || { cat configure.log; exit 1; }
ERL_TOP="$PWD" make -C lib BUILD_STATIC_LIBS=1 TYPE=opt static_lib > static.log 2>&1 || { cat static.log; exit 1; }
make -j"$(getconf _NPROCESSORS_ONLN)" > make.log 2>&1 || { cat make.log; exit 1; }
if [[ "$(uname -s)" == Linux ]]; then strip bin/*/beam.smp; fi

cd "$ROOT"
bash release-test.sh
export PATH="$ROOT/otp/bin:$PATH"
git clone --filter=blob:none --no-checkout https://github.com/elixir-lang/elixir.git elixir
git -C elixir checkout --detach "$ELIXIR_SHA"
make -C elixir -j"$(getconf _NPROCESSORS_ONLN)" > elixir/make.log 2>&1 || { cat elixir/make.log; exit 1; }
export PATH="$ROOT/elixir/bin:$PATH"
mix local.hex "$HEX_VERSION" --force
elixir .github/scripts/manifest_test.exs
cd otp/examples
./elixiraotc.exs build elixiraotc.exs
./elixiraotc build hello.exs
./hello
./elixiraotc run hello.exs
for _ in 1 2 3; do time ./hello > /dev/null; done
# A successful exit is not enough: ensure this is an AOT artifact.
unzip -l hello | grep 'jitc/atoms'
PATH=/usr/bin:/bin ./elixiraotc build elixiraotc.exs -o elixiraotc2
PATH=/usr/bin:/bin ./elixiraotc2 run hello.exs
mkdir -p "$ROOT/dist"
cp elixiraotc2 "$ROOT/dist/elixiraotc-$TARGET"
