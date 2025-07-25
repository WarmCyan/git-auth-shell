{
  description = "Minimal tooling and configuration for setting up a simple git server";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... } @ inputs:
  let
    lib = nixpkgs.lib;

    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = lib.genAttrs systems;
    pkgsFor = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (system:
      let
        pkgs = pkgsFor.${system};
      in {
        git-auth-shell = import ./git-auth-shell { inherit pkgs; };
        default = self.packages.${system}.git-auth-shell;
      });
  
    nixosModules = {
      cgit-theme = import ./modules/cgit-theme.nix;
      small-git-server = import ./modules/small-git-server.nix self;
      default = self.nixosModules.small-git-server;
    };
  };
}
