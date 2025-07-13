self: { config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.simple-git-server;
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
      packages = [
        pkgs.git
        self.packages.${pkgs.system}.git-auth-shell
      ];
      
      openssh.authorizedKeys.keys = builtins.attrValues (builtins.mapAttrs (name: keylist: 
        builtins.map (x: "restrict,command=\"${self.packages.${pkgs.system}.git-auth-shell} ${name} \\\"$SSH_ORIGINAL_COMMAND\\\"\"" + x) keylist) cfg.userSSHKeys);
    };
  };
}
