# https://flake.parts/define-module-in-separate-file
{ localFlake, withSystem }:
{ lib, config, ... }: 
with lib;
let
  cfg = config.services.simple-git-server;
  pkgs = withSystem ({ config, ... }: config.packages);
in {
  options.services.simple-git-server = {
    enable = mkEnableOption "Minimal git server";
    git-user = mkOption {
      type = types.str;
      default = "git";
    };
    userSSHKeys = mkOption {
      type = types.attrsOf types.listOf types.str;
      default = { };
    };
  };
  config = mkIf cfg.enable {
    users.users."${cfg.git-user}" = {
      isNormalUser = lib.mkForce true;
      isSystemUser = lib.mkForce false;  # needed if using cgit, it tries to override this
      description = "Git repositories for use by minimal git server.";
      packages = with pkgs [
        git
        git-auth-shell
      ];

      openssh.authorizedKeys.keys = builtins.attrValues (builtins.mapAttrs (name: keylist: 
        builtins.map (x: "restrict,command=\"${pkgs.git-auth-shell} ${cfg.git-user} \\\"$SSH_ORIGINAL_COMMAND\\\"\" + x) keylist));
    };
  };
}
