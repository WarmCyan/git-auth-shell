self: { config, pkgs, lib, ... }:
let
  cfg = config.services.small-git-server;
in
{
  imports = [
    ./cgit-theme.nix
  ];

  options.services.small-git-server = {
    enable = lib.mkEnableOption "Minimal git server";

    gitUser = lib.mkOption {
      type = lib.types.str;
      default = "git";
      description = "The user under which all git repos are stored. This is also what's used as the ssh target user, e.g. for 'git': 'ssh git@myip'";
    };

    userSSHKeys = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
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

    cgit = (import ./cgit-theme.nix { inherit self config pkgs lib; }).options.services.cgit-theme.small-git-server;

    # cgit = {
    #   enable = mkEnableOption "A cgit instance for the repositories hosted on this git server. Note that this will make a nginx virtualHost at 'simple-git-server', or the `cgit.name` attribute".;
    #
    #   name = lib.mkOption {
    #     type = lib.types.str;
    #     default = "small-git-server";
    #     description = "The attribute name to use for the cgit instance and nginx virtual host. This is so you can manually set additional nginx and cgit configuration if desired";
    #   };
    #
    #   aboutHTML = lib.mkOption {
    #     type = lib.types.nullOr lib.types.str;
    #     default = null;
    #     description = "An optional about HTML page for the cgit instance, set as the root-readme in the cgitrc.";
    #   };
    #
    #   assets = lib.mkOption {
    #     type = lib.types.nullOr lib.types.path;
    #     default = null;
    #     description = "An optional path to a collection of asset files (css/images/fonts/js) to place into the nix store and make available to the cgit frontend (through any '/assets/*' URLs.) If you're using this with some CSS files, you probably need to set `extraHeadInclude` to refer to them, or alternatively just rely on the `css` or `cssFiles` options to do this automatically.";
    #   };
    #
    #   logo = lib.mkOption {
    #     type = lib.types.nullOr lib.types.path;
    #     default = null;
    #     description = "Path to an image file to use as the logo in the upper right. The image is made available to the cgit frontend through a '/assets/[logofilename]' URL. Setting this automatically sets the correct line in the cgitrc.";
    #   };
    #
    #   favicon = lib.mkOption {
    #     type = lib.types.nullOr lib.types.path;
    #     default = null;
    #     description = "Path to an ico file to use as site favicon. The .ico is made available to the cgit fronend through '/assets/[icofilename]' URL. Setting this automatically sets the correct line in the cgitrc.";
    #   };
    #
    #   cssFiles = lib.mkOption {
    #     type = lib.types.listOf lib.types.path;
    #     default = [ ];
    #     description = "An optional list of paths to CSS files to use in the cgit frontend. These will be made available to the cgit frontend through a '/assets/*' URLS, and are automatically included through the cgitrc head-include option. (Note that you can add to this through `extraHeadInclude`.)";
    #   };
    #
    #   css = lib.mkOption {
    #     type = lib.types.nullOr lib.types.str;
    #     default = null;
    #     description = "Optional raw CSS to include in the cgit frontend. Anything here is written to a file available through a '/assets/custom-css.css' URL, and is appended to the head-include html file. This is added after any `cssFiles` any `extraHeadInclude` text, and so can override any styles from the other two.";
    #     example = lib.literalExpression ''
    #       body {
    #         background-color: red !important;
    #       }
    #     '';
    #   };
    #
    #   extraHeadInclude = lib.mkOption {
    #     type = lib.types.str;
    #     default = "";
    #     description = "Any additional HTML to include in the <HEAD> of every page. If an assets folder was specified through the `assets` option, those can be referenced here through any '/assets/*' URLs.";
    #     example = lib.literalExpression ''
    #       <meta name="viewport" content="width=device-width initial-scale=1.0" />
    #       <link rel='stylesheet' type='text/css' href='/assets/css-file-i-added-through-assets-option.css' />
    #     '';
    #   };
    # };
  };

  config = lib.mkIf cfg.enable {
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

    services.cgit.small-git-server = mkIf cfg.cgit.enable {
      enable = true;
      user = "${cfg.gitUser}";
      scanPath = "${config.users.users.${cfg.gitUser}.home}/gitrepos";
    };
    services.cgit-theme.small-git-server = mkIf cfg.cgit.enable cfg.cgit;
  };
}
