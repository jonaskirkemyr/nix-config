{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # nixGL removed: GUI apps (kitty, IDEs) now come from the OS image / Flatpak,
    # so nothing built by Nix needs to find the system's GL drivers.
  };

  outputs = { nixpkgs, home-manager, ... }:
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
        modules = [ ./home/home.nix ];
        extraSpecialArgs = { inherit username; };
      };
    in
    {
      homeConfigurations = nixpkgs.lib.genAttrs users mkHome;
    };
}
