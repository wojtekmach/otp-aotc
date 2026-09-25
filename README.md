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

## Native SDK: statically linked NIFs

The emulator's own NIFs are linked in statically, but a NIF from an application
dependency is normally a shared library loaded from `priv/`, which an
executable cannot load without extracting it. Each release therefore also ships
an optional `elixiraotc-native-sdk-<os>-<arch>.tar.gz`: the emulator's object
files and static libraries, its exact link order, an extensible static-NIF
registry, and OTP headers needed to compile against it.

`link.exs` in the SDK regenerates the registry and relinks the emulator with
application NIF archives. No OTP rebuild is needed. OTP's ordinary `load_nif`
call then finds those NIFs in the static registry, without opening a shared
library. Use the relinked emulator for both AOT recording and the final
executable. The SDK is a **build-time** input; nothing is extracted at run
time, and OS frameworks and system libraries remain dynamic dependencies.

Describe the NIFs to link in a JSON file:

```json
{
  "schema": 1,
  "nifs": [
    {"archive": "/path/to/libmy_nif.a", "init": "my_nif_nif_init"}
  ],
  "link_args": ["-framework", "AppKit"]
}
```

```sh
mkdir native-sdk && tar -xzf elixiraotc-native-sdk-darwin-arm64.tar.gz -C native-sdk
./elixiraotc-darwin-arm64 run native-sdk/link.exs native-sdk native.json beam.smp
```

Linking needs a system C compiler and linker (`cc`). Archives must match the
SDK's target and NIF ABI, and each NIF needs a unique
exported initialization symbol: `STATIC_ERLANG_NIF_LIBNAME` for C NIFs.
Rustler 0.38 already exports a crate-specific `<crate>_nif_init`; build the
crate as a `staticlib` and pass the complete, ordered
`--print=native-static-libs` output as `link_args`.
`sdk.json` records ERTS, the OTP target triple, linker arguments, and file
hashes. Those hashes detect corruption; verify the tarball itself against
`SHA256SUMS`.

To export an SDK from a locally built patched OTP tree, apply the patches with
`git am` or `git apply`. POSIX `patch` skips their binary preloaded-BEAM changes,
and the result links but cannot boot an embedded release.

```sh
elixir scripts/export-native-sdk.exs otp native-sdk
OTP="$PWD/otp" NATIVE_SDK="$PWD/native-sdk" elixir scripts/test-native-sdk.exs
```

The test statically links a C NIF, loads it through a nonexistent library path,
builds and runs an AOT executable from a copy in an empty directory, and checks
that a corrupted SDK cannot replace an existing output. CI runs it on every
target before publishing an SDK.
