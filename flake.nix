{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # nixGL removed: GUI apps (kitty, IDEs) now come from the OS image / Flatpak,
    # so nothing built by Nix needs to find the system's GL drivers.

    # KDE Plasma settings as Nix. Has no release branches — `trunk` is the Plasma
    # 6 branch — so it follows our pinned nixpkgs and home-manager rather than
    # dragging in a second copy of each. flake.lock pins the revision as usual.
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
  };

  outputs = { nixpkgs, home-manager, plasma-manager, ... }:
    let
      system = "x86_64-linux";

      # The one place a login name is written down.
      #
      # It has to be written down somewhere: `home.username` is a string option
      # with no default at stateVersion >= 20.09, and flake evaluation is pure,
      # so nothing in here can read $USER. Enumerating the names beats reaching
      # for `--impure`, which would make evaluation uncacheable.
      #
      # Everything downstream derives from this: the ujust recipes switch with
      # `--flake .#$USER`, and home.nix takes `username` as an argument instead
      # of hardcoding it. So a machine with a different login name — or someone
      # forking this repo — adds one word here and changes nothing else.
      users = [ "jonask" ];

      # allowUnfree belongs here, not in home.nix: `nixpkgs.config` inside a
      # home module is silently ignored when `pkgs` is passed in explicitly.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkHome = username: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          plasma-manager.homeModules.plasma-manager
          ./home/home.nix
          ./home/plasma.nix
        ];
        extraSpecialArgs = { inherit username; };
      };
      # Layer 3 starter kits: a devShell flake plus a .envrc, per language.
      #
      # `nix flake init -t <flake>#<name>` copies a template's directory into the
      # current one, so these are plain files — nothing evaluates them from here,
      # which is why they can pin their own nixpkgs branch and know nothing about
      # this flake. `ujust create-flake <language>` is a wrapper around that one
      # command; see files/justfiles/nix.just in the image repo.
      #
      # They live in this repo rather than in the OS image on purpose: a template
      # is the sort of thing you tweak the week after writing it, and an image
      # change costs a CI build, an `ujust update` and a reboot, while this costs
      # a `git pull`.
      mkTemplate = name: description: {
        inherit description;
        path = ./templates/${name};
      };
    in
    {
      homeConfigurations = nixpkgs.lib.genAttrs users mkHome;

      templates = {
        csharp = mkTemplate "csharp" "C# / .NET dev shell (dotnet-sdk)";
        java = mkTemplate "java" "Java dev shell (JDK, Maven, Gradle)";
        kotlin = mkTemplate "kotlin" "Kotlin dev shell (JDK, kotlinc, Gradle)";
        nodejs = mkTemplate "nodejs" "Node.js dev shell (node, npm, pnpm)";
      };
    };
}
