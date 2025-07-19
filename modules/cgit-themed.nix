# inspiration/conventions largely taken from actual cgit service def:
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/cgit.nix

# it took me way too long to figure out how to include custom theme
# files/css/images etc., so this just makes it a bit easier to style in a few
# different ways

# for reference, cgitrc settings are documented here: https://git.zx2c4.com/cgit/tree/cgitrc.5.txt
# note that there seems to be an issue with the 'css' option - the docs say you
# can specify it multiple times to include multiple files, but this doesn't
# appear to work in practice. The approach here gets around it by automatically
# throwing in a head-include with any (multiple) passed css files referenced.

self: { config, pkgs, lib, ... }:
let
  cfgs = config.services.cgit-themed;

  # All individual asset files need to be merged into a single 'assets' folder
  # to make it easily accessible through a nginx location. Not sure if there's a
  # better way of doing this (I was running into difficulties figuring out how
  # to manage individual paths that weren't directories), but this effectively
  # turns a single file into a directory with 'assets' subdirectory containing
  # this one file, and it can later be merged with symlinkJoin. (see
  # mkCombinedAssets)
  mkAssetsFile = filepath: pkgs.runCommand "cgit-themed-asset-filepath-${builtins.baseNameOf filepath}" { } ''
    mkdir -p $out/assets
    cp ${filepath} $out/assets/${builtins.baseNameOf filepath}
  '';

  # turn any raw CSS provided through `css` option into a CSS file (again in an
  # assets subdirectory to be merged in mkCombinedAssets)
  mkCustomCSS = cfg: name: pkgs.writeTextFile {
    name = "cgit-themed-${name}-custom-css.css";
    text = cfg.css;
    destination = "/assets/custom-css.css";
  };

  # https://stackoverflow.com/questions/76242980/create-a-derivation-in-nix-to-only-copy-some-files
  # copy a whole assets path into a assets subdir in a deriv (again to later be
  # merged with mkCombinedAssets)
  mkAssetsFolder = cfg: name: pkgs.stdenvNoCC.mkDerivation {
    name = "cgit-themed-${name}-assets";
    src = cfg.assets;
    installPhase = ''
      mkdir -p $out/assets
      cp -r $src/* $out/assets
    '';
  };

  # make a single combined /nix/store/.../assets folder which we can point to
  # with a single nginx location/root combo. This makes it easier to include
  # arbitrary files with custom CSS and extraHeadInclude
  mkCombinedAssets = cfg: name: pkgs.symlinkJoin {
    name = "cgit-themed-${name}-combined-assets";
    # https://hugosum.com/blog/conditionally-add-values-into-list-or-map-in-nix
    paths = [ ] 
      ++ (builtins.map(cssPath: mkAssetsFile cssPath) cfg.cssFiles)
      ++ (lib.optional (cfg.css != null) (mkCustomCSS cfg name))
      ++ (lib.optional (cfg.logo != null) (mkAssetsFile cfg.logo))
      ++ (lib.optional (cfg.favicon != null) (mkAssetsFile cfg.favicon))
      ++ (lib.optional (cfg.assets != null) (mkAssetsFolder cfg name));
  };

  # Write the HTML file to be included in <HEAD> of every cgit page. This
  # doesn't need to go in an assets folder because the cgitrc will take a full
  # path rather than a frontend URL.
  mkHeadInclude = cfg: name: pkgs.writeText "cgit-themed-${name}-head-include.html" ''
    ${lib.concatStrings 
      (builtins.map (stylepath: 
      "<link rel='stylesheet' type='text/css' href='/assets/${builtins.baseNameOf stylepath}' />\n"
    ) cfg.cssFiles)}

    ${cfg.extraHeadInclude}

    ${if cfg.css != null then "<link rel='stylesheet' type='text/css' href='/assets/custom-css.css' />" else ""}
  '';

  mkAbout = cfg: name: pkgs.writeText "cgit-themed-${name}-about.html" cfg.aboutHTML;
in
{
  options.services.cgit-themed = lib.mkOption {
    description = "Configure cgit instances with easy custom styling.";
    default = { };
    # this is what allows setting up multiple instances
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options = {
            enable = lib.mkEnableOption "cgit-themed";

            aboutHTML = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "An optional about HTML page for the cgit instance, set as the root-readme in the cgitrc.";
            };

            assets = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "An optional path to a collection of asset files (css/images/fonts/js) to place into the nix store and make available to the cgit frontend (through any '/assets/*' URLs.) If you're using this with some CSS files, you probably need to set `extraHeadInclude` to refer to them, or alternatively just rely on the `css` or `cssFiles` options to do this automatically.";
            };

            logo = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to an image file to use as the logo in the upper right. The image is made available to the cgit frontend through a '/assets/[logofilename]' URL. Setting this automatically sets the correct line in the cgitrc.";
            };

            favicon = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to an ico file to use as site favicon. The .ico is made available to the cgit fronend through '/assets/[icofilename]' URL. Setting this automatically sets the correct line in the cgitrc.";
            };

            cssFiles = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = "An optional list of paths to CSS files to use in the cgit frontend. These will be made available to the cgit frontend through a '/assets/*' URLS, and are automatically included through the cgitrc head-include option. (Note that you can add to this through `extraHeadInclude`.)";
            };

            css = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional raw CSS to include in the cgit frontend. Anything here is written to a file available through a '/assets/custom-css.css' URL, and is appended to the head-include html file. This is added after any `cssFiles` any `extraHeadInclude` text, and so can override any styles from the other two.";
              example = lib.literalExpression ''
                body {
                  background-color: red !important;
                }
              '';
            };

            extraHeadInclude = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Any additional HTML to include in the <HEAD> of every page. If an assets folder was specified through the `assets` option, those can be referenced here through any '/assets/*' URLs.";
              example = lib.literalExpression ''
                <meta name="viewport" content="width=device-width initial-scale=1.0" />
                <link rel='stylesheet' type='text/css' href='/assets/css-file-i-added-through-assets-option.css' />
              '';
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (lib.any (cfg: cfg.enable) (lib.attrValues cfgs)) {
    services.cgit = lib.mapAttrs (name: cfg: {
      enable = true;
      settings = {
        head-include = "${mkHeadInclude cfg name}";
      }
        // lib.optionalAttrs (cfg.logo != null) { logo = "/assets/${builtins.baseNameOf cfg.logo}"; }
        // lib.optionalAttrs (cfg.favicon != null) { favicon = "/assets/${builtins.baseNameOf cfg.favicon}"; }
        // lib.optionalAttrs (cfg.aboutHTML != null) { root-readme = "${mkAbout cfg name}"; };
    }) cfgs;

    services.nginx.virtualHosts = lib.mapAttrs (name: cfg: {
      locations."${lib.removeSuffix "/" config.services.cgit.${name}.nginx.location}/assets" = {
        root = "${(mkCombinedAssets cfg name)}";
      };
    }) cfgs;
  };
}
