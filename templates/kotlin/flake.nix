{
  description = "Kotlin dev shell";

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
          # A JDK is not optional: the `kotlin` package is the compiler and its
          # runner scripts, both of which need a JVM. Pin it explicitly rather
          # than relying on whatever gradle drags in, because the JDK decides the
          # bytecode target and Kotlin only supports up to a given release.
          #
          # `kotlin` gives you kotlinc for one-off compiles; gradle is what an
          # actual project builds with.
          packages = with pkgs; [
            jdk21
            kotlin
            gradle
            # ktlint                    # formatter/linter
            # kotlin-language-server    # for editors that don't bring their own
          ];

          # JAVA_HOME comes from openjdk's setup hook — see the java template.
        };
      });
    };
}
