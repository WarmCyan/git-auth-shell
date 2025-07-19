self: { config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.small-git-server;

  # based on https://github.com/NixOS/nixpkgs/blob/32a4e87942101f1c9f9865e04dc3ddb175f5f32e/nixos/modules/services/networking/cgit.nix#L91
  # mkCSSFile = cfg: pkgs.writeText "custom-cgit-theme.css" cfg.cgit.css;
  mkCSSFile = cfg: pkgs.writeTextFile { name="custom-cgit-theme"; text = cfg.cgit.css; destination = "/cgit/custom-cgit-theme.css"; };
in {
  options.services.small-git-server = {
    enable = mkEnableOption "Minimal git server";

    gitUser = mkOption {
      type = types.str;
      default = "git";
      description = "The user under which all git repos are stored. This is also what's used as the ssh target user, e.g. for 'git': 'ssh git@myip'";
    };

    userSSHKeys = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = { };
      description = "A dictionary of lists of SSH keys to place into the authorizedKeys list. The attributes/keys are the usernames, the corresponding lists are the set of keys to associate with that username.";
      example = lib.literalExpresion ''
        {
          my_username = [
            "ssh-rsa AAA..."
            "ssh-rsa BBB..."
          ];
          my_friends_username = [
            "ssh-rsa CCC..."
          ];
        }
      '';
    };

    # TODO: allow configuring GIT_AUTH_USERS/REPOS/LOG vars, directly place into
    # authorizedKeys command

    cgit.enable = mkEnableOption "a cgit instance for the repositories hosted on this git server. Note that this will make a nginx virtualHost at 'simple-git-server'";
    cgit.css = mkOption {
      type = types.str;
      default = "";
      example = lib.literalExpresion ''
        /* insert example here */
      '';
    };


    # TODO: cgit theme and logo file
    # https://discourse.nixos.org/t/is-it-possible-to-write-to-an-arbitrary-file-from-nix-config/61999
  };
  config = mkIf cfg.enable {
    users.users."${cfg.gitUser}" = {
      isNormalUser = lib.mkForce true;
      isSystemUser = lib.mkForce false;  # needed if using cgit, it tries to override this
      description = "Git repos";
      packages = [
        pkgs.git
        self.packages.${pkgs.system}.git-auth-shell
      ];
      
      openssh.authorizedKeys.keys = builtins.concatLists (builtins.attrValues (builtins.mapAttrs (name: keylist: 
        builtins.map (x: "restrict,command=\"${self.packages.${pkgs.system}.git-auth-shell}/bin/git-auth-shell ${name} \\\"$SSH_ORIGINAL_COMMAND\\\"\" " + x) keylist) cfg.userSSHKeys));
    };

    # TODO: override cgit package post to copy in css/logo files
    services.cgit.simple-git-server = mkIf cfg.cgit.enable {
      # https://discourse.nixos.org/t/adding-files-to-a-package/14626
      package = pkgs.buildEnv {
        name = "cgit-styled";
        paths = [ 
          pkgs.cgit
          (mkCSSFile cfg)
        ];
      };

      enable = true;
      user = "${cfg.gitUser}";
      scanPath = "${config.users.users.${cfg.gitUser}.home}/gitrepos";
      settings = {
        source-filter = "${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py";
        about-filter = "${pkgs.cgit}/lib/cgit/filters/about-formatting.sh";
        readme = [ ":README.md" ":readme.md" ":README" ":readme" ":README.rst" ":readme.rst" ":README.txt" ":readme.txt" ];
        # TODO: clone-prefix/clone-url?: https://git.zx2c4.com/cgit/tree/cgitrc.5.txt
        enable-blame = 1;
        enable-commit-graph = 1;
        enable-follow-links = 1;
        enable-git-config = 1;
        enable-http-clone = 1;
        enable-html-serving = 1;
        cache = 100;
        # TODO: header/footer/etc.
        head-include = "${mkCSSFile cfg}/cgit/custom-cgit-theme.css";
        local-time = 1;
      };
    };
  };
}
