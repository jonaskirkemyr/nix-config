{
  description = "Java dev shell";

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
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # JDK 21 is the LTS; `jdk25` is the newer one, `jdk17` the older. Note
          # nixpkgs removes JDKs when they go end-of-life rather than keeping a
          # broken attribute around, so `jdk23` does not exist — if an update ever
          # fails with "OpenJDK N was removed as it has reached its end of life",
          # that is this, and the fix is to name a version that is still supported.
          #
          # Both build tools are here because a project usually ships a wrapper
          # (`./gradlew`, `./mvnw`) that downloads its own — having the real thing
          # on PATH is what lets you skip the wrapper. Delete the one you don't use.
          packages = with pkgs; [
            jdk21
            maven
            gradle
          ];

          # No JAVA_HOME here on purpose: openjdk ships a setup hook that exports
          # it (`$out/lib/openjdk`) whenever the shell doesn't already set one, so
          # writing it out again would just be a second place to keep in sync.
        };
      });
    };
}
