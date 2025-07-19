self: { config, pkgs, lib, ... }:
let
  cfg = config.services.small-git-server;
  
  themeSubmodule = import ./cgit-theme-options.nix { inherit lib; };
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

    # https://discourse.nixos.org/t/override-submodule-options/12165/3
    # https://discourse.nixos.org/t/how-to-reuse-submodules-in-a-submodule/63880
    cgit = lib.mkOption {
      type = themeSubmodule;
      default = { };
      description = "Optionally set up an associated cgit instance (attribute name 'small-git-server') with custom theming and reasonable defaults."
    };

    cgit.nginx.location = lib.mkOption {
      description = "Location to serve cgit under.";
      type = lib.types.str;
      default = "/";
      example = "/git/";
    };
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
      
      openssh.authorizedKeys.keys = builtins.concatLists 
        (builtins.attrValues 
          (builtins.mapAttrs (name: keylist: 
            builtins.map (x: "restrict,command=\"${self.packages.${pkgs.system}.git-auth-shell}/bin/git-auth-shell ${name} \\\"$SSH_ORIGINAL_COMMAND\\\"\" " + x) keylist) 
            cfg.userSSHKeys
          )
        );
    };

    services.cgit.small-git-server = lib.mkIf cfg.cgit.enable {
      enable = true;
      user = "${cfg.gitUser}";
      scanPath = "${config.users.users.${cfg.gitUser}.home}/gitrepos";
      nginx.location = cfg.cgit.nginx.location;
      settings = {
        source-filter = "${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py";
        about-filter = "${pkgs.cgit}/lib/cgit/filters/about-formatting.sh";
        readme = [ ":README.md" ":readme.md" ":README" ":readme" ":README.rst" ":readme.rst" ":README.txt" ":readme.txt" ];
        enable-blame = 1;
        enable-commit-graph = 1;
        enable-follow-links = 1;
        enable-git-config = 1;
        enable-http-clone = 1;
        enable-html-serving = 1;
        local-time = 1;
        cache = 100;
      };
    };
    services.cgit-theme.small-git-server = lib.mkIf cfg.cgit.enable cfg.cgit;
  };
}
