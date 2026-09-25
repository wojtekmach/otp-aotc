# elixiraotc

Experimental OTP patches and native builds for compiling Elixir scripts to
single executables, including ahead-of-time compiled BEAM code.

## Download

Published toolchains live in [GitHub Releases](../../releases), not the source
branch. Select a reviewed release and the matching `elixiraotc-<os>-<arch>` asset:

- `darwin-arm64`
- `darwin-x86_64`
- `linux-arm64`
- `linux-x86_64`

Download `SHA256SUMS` and `toolchain.json` alongside the executable. Verify its
SHA-256 before running it, then make it executable:

```sh
# Use sha256sum on Linux, or shasum -a 256 on macOS, and compare with SHA256SUMS.
shasum -a 256 elixiraotc-darwin-arm64
chmod +x elixiraotc-darwin-arm64
./elixiraotc-darwin-arm64 build hello.exs -o hello
./hello
```
