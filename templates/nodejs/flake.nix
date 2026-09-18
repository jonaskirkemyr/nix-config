{
  description = "Node.js dev shell";

  # nixpkgs and nothing else. No flake-utils: it would be a second input to
  # update and to read in every `nix flake update` diff, to save four lines below.
  #
  # This tracks a release branch, not a revision. The *lock file* next to this
  # flake is what actually pins the toolchain — commit it, and the versions stay
  # put until you run `nix flake update`.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # `nodejs_22` is the current LTS line; `nodejs_24` for the newer one.
          # npm ships with it; pnpm does not, hence the second entry.
          #
          # If package.json has a "packageManager" field, drop pnpm and use
          # `corepack_22` instead — it reads that field and fetches the exact
          # version the project asks for, which is the point of the field.
          packages = with pkgs; [
            nodejs_22
            pnpm
            # typescript-language-server  # for editors that don't bring their own
          ];
        };
      });
    };
}
