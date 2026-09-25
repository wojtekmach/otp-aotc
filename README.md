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

The build artifact is a single executable without a separately installed OTP or
Elixir. It may still depend on system libraries. Linux artifacts are built on
Ubuntu 24.04; do not assume compatibility with older glibc systems or musl.
The scripting frontend supports runtime `Mix.install/2`, which may require
network access; being one executable does not make arbitrary scripts offline.

For automated consumers, `toolchain.json` contains an `artifacts` map keyed by
target, with `url`, `sha256`, and `bytes` for each executable. Pin the release
identity and a trusted digest instead of downloading from `main` or following
`latest`. Checksums alone do not authenticate their publisher; GitHub artifact
attestations can be verified with `gh attestation verify FILE --repo OWNER/REPO`.

## Build and release policy

The workflow builds four native targets and runs the existing release,
execution, AOT-content, and self-hosting checks before creating release assets.

| Trigger | OTP input | Publication |
| --- | --- | --- |
| Pull request / branch push | Reviewed commit in `.github/build.json` | CI artifacts only |
| Default-branch push | Reviewed commit | Draft release after all targets pass |
| Daily schedule | Latest stable OTP GitHub release, resolved to a commit | Draft release after all targets pass |
| Manual dispatch | Optional OTP ref, otherwise reviewed commit | Draft only when explicitly requested |

Elixir and Hex are pinned in `.github/build.json`. The patch source is the exact
commit of this repository used by the workflow. A release tag identifies both
the OTP commit and patch-source commit. Existing releases, including drafts,
are not rebuilt or overwritten.

New OTP releases can break the patches. Patch application is deliberately
fail-closed: no automatic conflict resolution, no partial patch sets, and no
release if a native build or check fails. The workflow does **not** update the
reviewed OTP pin automatically.

A maintainer reviews and publishes each draft. Publication never commits
binaries, pushes source-branch changes, or rewrites Git history. Previously
committed binaries remain in history; this change only removes them from the
current tree.

The scheduled workflow must be enabled in the repository's Actions settings.
Drafts and attestations use narrowly scoped write permissions in a separate
publication job; build jobs have read-only repository permissions.

This is not a reproducible-build claim: runner images, OS packages, and native
build tooling are not fully pinned. Nor is a successful build evidence that
the experimental runtime or its native archive loader has been security-audited.
