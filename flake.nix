{
  description = "Minimal tooling and configuration for setting up a simple git server";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        # https://ertt.ca/nix/shell-scripts/
        packages.default = self'.packages.git-auth-shell;
        packages.git-auth-shell =
          let
            inherit pkgs;
            script = pkgs.writeShellScriptBin "git-auth-shell" builtins.readFile ./git-auth-shell.sh;
          in pkgs.symlinkJoin {
            name = "git-auth-shell";
            paths = [ script pkgs.git ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuid = "wrapProgram $out/bin/git-auth-shell --prefix PATH : $out/bin";
          };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
}
