Code.require_file("manifest.exs", __DIR__)
ExUnit.start()

defmodule ReleaseManifestTest do
  use ExUnit.Case, async: true
  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    for target <- ~w(darwin-arm64 darwin-x86_64 linux-arm64 linux-x86_64) do
      File.write!(Path.join(dir, "elixiraotc-#{target}"), "executable for #{target}")
    end

    {:ok,
     env: %{
       "GITHUB_REPOSITORY" => "owner/elixiraotc",
       "GITHUB_SHA" => String.duplicate("a", 40),
       "RELEASE_TAG" => "otp-bbbbbbbbbbbb-aot-aaaaaaaaaaaa",
       "OTP_SHA" => String.duplicate("b", 40),
       "ELIXIR_SHA" => String.duplicate("c", 40),
       "HEX_VERSION" => "2.3.2"
     }}
  end

  test "all platform artifacts have pinned URLs and matching checksums", %{tmp_dir: dir, env: env} do
    manifest = ReleaseManifest.write!(dir, env)
    assert JSON.decode!(File.read!(Path.join(dir, "toolchain.json"))) == manifest
    assert map_size(manifest["artifacts"]) == 4

    for {target, artifact} <- manifest["artifacts"] do
      bytes = File.read!(Path.join(dir, "elixiraotc-#{target}"))
      assert artifact["sha256"] == Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
      assert artifact["bytes"] == byte_size(bytes)
      assert artifact["url"] =~ "/releases/download/#{env["RELEASE_TAG"]}/elixiraotc-#{target}"
    end

    sums = File.read!(Path.join(dir, "SHA256SUMS"))
    assert length(String.split(sums, "\n", trim: true)) == 5
    assert sums =~ "  toolchain.json\n"
    assert ReleaseManifest.write!(dir, env) == manifest
  end

  test "a missing matrix artifact prevents publication", %{tmp_dir: dir, env: env} do
    File.rm!(Path.join(dir, "elixiraotc-linux-arm64"))
    assert_raise File.Error, fn -> ReleaseManifest.write!(dir, env) end
    refute File.exists?(Path.join(dir, "toolchain.json"))
  end

  test "release identity must agree with the source", %{tmp_dir: dir, env: env} do
    assert_raise RuntimeError, ~r/does not match/, fn ->
      ReleaseManifest.write!(dir, Map.put(env, "RELEASE_TAG", "latest"))
    end
  end
end
