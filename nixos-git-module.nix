# nginx: any /assets/* goes through to assets folder, so assets folder needs to
# be a builtEnv?

# BUG: in cgit you apparently can't _actually_ specify more than one css file,
# their docs lie.



# optionally allow an assets folder, does still get pointed to, we prob use
# buildEnv to combine all assets
# mkCSSFile we keep, as well as a mkHeadInclude
#
# we can copy in image path by having the runcommand and using the cfg with cp
# dest using the baseNameOf the actual path


self: { config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.small-git-server;

  # based on https://github.com/NixOS/nixpkgs/blob/32a4e87942101f1c9f9865e04dc3ddb175f5f32e/nixos/modules/services/networking/cgit.nix#L91
  # mkCSSFile = cfg: pkgs.writeText "custom-cgit-theme.css" cfg.cgit.css;
  # NOTE: using writeTextFile into subdir because buildEnv doesn't work with a
  # single path. So, use /cgit/ because that's where default /cgit/cgit.css goes
  # in cgit package
  # mkCSSFile = cfg: pkgs.writeTextFile { 
  #   name="custom-cgit-theme";
  #   text = ''
  #     <style>
  #       ${cfg.cgit.css};
  #     </style>
  #   '';
  #   destination = "/cgit/custom-cgit-theme.html";
  # };
  # Ended up not going with this approach because it would be much easier to
  # support any of the custom files cgit supports by just taking a user's
  # "assets" folder and letting them refer to paths within it, and then
  # combining all those assets into the cgit pkg with buildEnv
  # Leaving the code around because this is a cool thing to know how to do (the
  # mk function in the let approach)
  mkCustomCSSFileFromText = cfg: pkgs.writeTextFile {
    name = "custom-css.css";
    text = cfg.cgit.css;
    destination = "/assets/custom-css.css";
  };

  # take any single file store path and put it into an /nix/store/.../assets
  # subpath. This was the only way I could figure out how to take individual
  # filepaths and put them into store subdirectories for non-text files.
  mkCopyIntoAssets = filepath: pkgs.runCommand "convert-to-asset-path" { } ''
    mkdir -p $out/assets
    cp ${filepath} $out/assets/${builtins.baseNameOf filepath}
  '';

  # this one doesn't need to go _into_ the assets folder because cgitrc can
  # reference from scratch
  mkHeadInclude = cfg: pkgs.writeText "cgit-head-include.html" ''
      <meta name="viewport" content="width=device-width initial-scale=1.0" />

      <link rel='stylesheet' type='text/css' href='/assets/custom-css.css' />

      ${lib.concatStrings (builtins.map (x: "<link rel='stylesheet' type='text/css' href='/assets/${builtins.baseNameOf x}' />\n") cfg.cgit.css_files)}

      ${cfg.cgit.extraHeadInclude}
  '';

  # mkLogo = cfg: pkgs.runCommand "cgit-assets-logo" { } ''
  #   mkdir -p $out/assets
  #   cp ${cfg.cgit.logo} $out/assets/${builtins.baseNameOf cfg.cgit.logo}
  # '';

  # https://stackoverflow.com/questions/76242980/create-a-derivation-in-nix-to-only-copy-some-files
  mkAssets = cfg: pkgs.stdenvNoCC.mkDerivation {
    name = "cgit-assets";
    src = cfg.cgit.assets;
    installPhase = ''
      mkdir -p $out/assets
      cp -r $src/* $out/assets
    '';
  };

  # make a single combined /nix/store/.../assets folder which we
  # can point to with a single nginx location/root combo. This makes it
  # so you can do more with custom css and head include
  mkCombinedAssets = cfg: pkgs.symlinkJoin {
    name = "combined-cgit-assets";
    paths = [
      (mkCustomCSSFileFromText cfg)
      # (mkLogo cfg)
      (mkCopyIntoAssets cfg.cgit.logo)
      (mkAssets cfg)
    ] ++ (builtins.map(x: mkCopyIntoAssets x) cfg.cgit.css_files);
  };
  
  # mkAssets = cfg: pkgs.stdenvNoCC.mkDerivation {
  #   name = "cgit-assets";
  #   src = lib.fileset.toSource {
  #     root = ../.;
  #     fileset = lib.fileset.unions [
  #       cfg.cgit.logo
  #       (lib.fileset.unions cfg.cgit.css_files)
  #     ];
  #   };
  #   installPhase = ''
  #     cp -r $src/* $out
  #   '';
  # };
  # mkAssets = cfg: pkgs.runCommand "cgit-assets" { } ''
  #   mkdir $out
  #   cp "${cfg.cgit.logo}" $out
  # '';

  

  # mkAssets = cfg: pkgs.symlinkJoin {
  #   name = "cgit-assets";
  #   paths = [ cfg.cgit.logo ] ++ cfg.cgit.css_files;
  # };
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
    cgit.assets = mkOption {
      type = types.path;
      description = "A folder containing files for customizing cgit's appearance, e.g. css, logo, favicon, additional header/footer html etc. To use these files, ...";
    };
    cgit.css_files = mkOption {
      type = types.listOf types.path;
      # default = [ "cgit.css" ];
      default = [ ];
      # TODO: wrong
      example = lib.literalExpresion ''
        [ "cgit.css" "mycustomcss.css" ];
      '';
      description = "A list of string paths to css files within the small-git-server.cgit.assets folder. 'cgit.css' is the file that comes with cgit, include this one first to base styling off of the default cgit style.";
    };
    cgit.logo = mkOption {
      type = types.path;
      # default = "cgit.png";
      # TODO: wrong
      description = "Path within assets folder to the image to use in upper left of every page. Default that comes with cgit is 'cgit.png'";
    };
    # TODO: icon
    cgit.css = mkOption {
      type = types.str;
      default = "";
    };



    cgit.extraHeadInclude = mkOption {
      type = types.str;
      default = "";
      example = lib.literalExpresion ''
        <link 
      '';
    };

    cgit.extraSettings = mkOption {
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
    services.cgit.small-git-server = mkIf cfg.cgit.enable {
      # https://discourse.nixos.org/t/adding-files-to-a-package/14626
      # package = pkgs.buildEnv {
      #   name = "cgit-styled";
      #   paths = [
      #     pkgs.cgit
      #     (mkAssets cfg)
      #   ];
      # };
      # package = 

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
        head-include = "${mkHeadInclude cfg}";
        # head-include = "${mkCSSFile cfg}/cgit/custom-cgit-theme.html";
        # css = (builtins.map (x: "/assets/" + (builtins.baseNameOf x)) cfg.cgit.css_files) ++ [ "/cgit.css" ];
        # css = [ "/cgit.css" ] ++ (builtins.map (x: "/assets/" + (builtins.baseNameOf x)) cfg.cgit.css_files);
        # css = [ "/cgit.css" ] ++ (builtins.map (x: "/assets/" + x) cfg.cgit.css_files);
        # css = (builtins.map (x: "/assets/" + (builtins.baseNameOf x)) cfg.cgit.css_files);
        logo = "/assets/${builtins.baseNameOf cfg.cgit.logo}";
        # logo = "/assets/${cfg.cgit.logo}";
        local-time = 1;
      };
    };
    services.nginx.virtualHosts.small-git-server = {
      locations."/assets" = {
        root = "${(mkCombinedAssets cfg)}";
      };
    };
  };
}
