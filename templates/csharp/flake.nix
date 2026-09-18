{
  description = "C# / .NET dev shell";

  # See the nodejs template for why there is exactly one input, and why it points
  # at a branch while flake.lock does the actual pinning.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs:
        let
          # Named once, because DOTNET_ROOT below has to point at the same SDK.
          # `dotnet-sdk_10` is the current LTS; `dotnet-sdk_9` is the previous
          # release, and the unversioned `dotnet-sdk` is older still (8.0), so
          # spell the version out rather than inheriting whatever it points at.
          #
          # For a solution that needs several SDKs side by side:
          #   dotnet = pkgs.dotnetCorePackages.combinePackages [
          #     pkgs.dotnet-sdk_10 pkgs.dotnet-sdk_9
          #   ];
          dotnet = pkgs.dotnet-sdk_10;
        in
        {
          default = pkgs.mkShell {
            packages = [
              dotnet
              # pkgs.csharp-ls     # language server, if your editor has none
              # pkgs.netcoredbg    # debugger
            ];

            # The SDK's own setup hook sets DOTNET_NOLOGO,
            # DOTNET_CLI_TELEMETRY_OPTOUT and the first-run skips — but not this
            # one, and plenty of tooling (MSBuild tasks, language servers, `dotnet
            # ef`) resolves the SDK through DOTNET_ROOT rather than by walking up
            # from the dotnet binary. Nix even patches the CLI to prefer it.
            DOTNET_ROOT = "${dotnet}/share/dotnet";
          };
        });
    };
}
