Experimental, ahead-of-time compiled Elixir toolchains for macOS and Linux on ARM64 and x86-64.

Each executable embeds its OTP/Elixir toolchain. No separately installed OTP or Elixir is needed to run it. These are native platform builds, not universally static binaries; the target OS and system libraries must be compatible.

`toolchain.json` records the OTP, Elixir, and patch-source commits, Hex version, and each executable's download URL, size, and SHA-256. `SHA256SUMS` covers the executables and manifest. GitHub artifact attestations are available for these release assets.

This is a **draft** so the maintainers can review the OTP changes and patch compatibility before publishing. Passing the release and self-hosting checks is not a security audit. Consumers should pin a reviewed release and digest, not automatically follow the newest candidate.
