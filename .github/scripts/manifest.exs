defmodule ReleaseManifest do
  @targets ~w(darwin-arm64 darwin-x86_64 linux-arm64 linux-x86_64)

  def write!(directory, env) do
    repository = Map.fetch!(env, "GITHUB_REPOSITORY")
    source = Map.fetch!(env, "GITHUB_SHA")
    tag = Map.fetch!(env, "RELEASE_TAG")
    otp = Map.fetch!(env, "OTP_SHA")
    elixir = Map.fetch!(env, "ELIXIR_SHA")
    hex = Map.fetch!(env, "HEX_VERSION")

    unless Regex.match?(~r|\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z|, repository),
      do: raise("Invalid repository")

    for commit <- [source, otp, elixir] do
      unless Regex.match?(~r/\A[0-9a-f]{40}\z/, commit), do: raise("Invalid source commit")
    end

    unless tag == "otp-#{String.slice(otp, 0, 12)}-aot-#{String.slice(source, 0, 12)}",
      do: raise("Release tag does not match source commits")

    artifacts =
      Map.new(@targets, fn target ->
        name = "elixiraotc-#{target}"
        path = Path.join(directory, name)
        # File.read/stat failures stop publication if any matrix artifact is absent.
        {target,
         %{
           "url" => "https://github.com/#{repository}/releases/download/#{tag}/#{name}",
           "sha256" => digest(path),
           "bytes" => File.stat!(path).size
         }}
      end)

    manifest = %{
      "schema" => 1,
      "id" => tag,
      "source" => "https://github.com/#{repository}/tree/#{source}",
      "otp_commit" => otp,
      "elixir_commit" => elixir,
      "hex_version" => hex,
      "artifacts" => artifacts
    }

    manifest_path = Path.join(directory, "toolchain.json")
    File.write!(manifest_path, JSON.encode!(manifest) <> "\n")
    names = Enum.map(@targets, &"elixiraotc-#{&1}") ++ ["toolchain.json"]
    sums = Enum.map_join(names, "", &"#{digest(Path.join(directory, &1))}  #{&1}\n")
    File.write!(Path.join(directory, "SHA256SUMS"), sums)
    manifest
  end

  defp digest(path) do
    path
    |> File.stream!(1024 * 1024, [])
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end
end

case System.argv() do
  [directory] -> ReleaseManifest.write!(directory, System.get_env())
  [] -> :ok
  _ -> raise "Usage: elixir .github/scripts/manifest.exs DIST_DIRECTORY"
end
