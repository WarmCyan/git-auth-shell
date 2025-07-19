# inspiration/conventions largely taken from actual cgit service def:
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/cgit.nix

# it took me way too long to figure out how to include custom theme
# files/css/images etc., so this just makes it a bit easier to style in a few
# different ways

# for reference, cgitrc settings are documented here: https://git.zx2c4.com/cgit/tree/cgitrc.5.txt
# note that there seems to be an issue with the 'css' option - the docs say you
# can specify it multiple times to include multiple files, but this doesn't
# appear to work in practice. The approach here gets around it by automatically
# throwing in a head-include with any (multiple) passed css files.

{ config, pkgs, lib, ... }:
let
  cfgs = config.services.cgit-theme;

  themeOptions = import ./cgit-theme-options.nix { inherit lib; };

  # All individual asset files need to be merged into a single 'assets' folder
  # to make it easily accessible through a nginx location. Not sure if there's a
  # better way of doing this (I was running into difficulties figuring out how
  # to manage individual paths that weren't directories), but this effectively
  # turns a single file into a directory with 'assets' subdirectory containing
  # this one file, and it can later be merged with symlinkJoin. (see
  # mkCombinedAssets)
  mkAssetsFile = filepath: pkgs.runCommand "cgit-theme-asset-filepath-${builtins.baseNameOf filepath}" { } ''
    mkdir -p $out/assets
    cp ${filepath} $out/assets/${builtins.baseNameOf filepath}
  '';

  # turn any raw CSS provided through `css` option into a CSS file (again in an
  # assets subdirectory to be merged in mkCombinedAssets)
  mkCustomCSS = cfg: name: pkgs.writeTextFile {
    name = "cgit-theme-${name}-custom-css.css";
    text = cfg.css;
    destination = "/assets/custom-css.css";
  };

  # https://stackoverflow.com/questions/76242980/create-a-derivation-in-nix-to-only-copy-some-files
  # copy a whole assets path into a assets subdir in a deriv (again to later be
  # merged with mkCombinedAssets)
  mkAssetsFolder = cfg: name: pkgs.stdenvNoCC.mkDerivation {
    name = "cgit-theme-${name}-assets";
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
    name = "cgit-theme-${name}-combined-assets";
    # https://hugosum.com/blog/conditionally-add-values-into-list-or-map-in-nix
    paths = [ ] 
      ++ (builtins.map(cssPath: mkAssetsFile cssPath) cfg.cssFiles)
      ++ (lib.optional (cfg.css != null) (mkCustomCSS cfg name))
      ++ (lib.optional (cfg.logo != null) (mkAssetsFile cfg.logo))
      ++ (lib.optional (cfg.favicon != null) (mkAssetsFile cfg.favicon))
      ++ (lib.optional (cfg.assets != null) (mkAssetsFolder cfg name));
  };

  # <base href='${config.services.cgit.${name}.nginx.location}'
  # Write the HTML file to be included in <HEAD> of every cgit page. This
  # doesn't need to go in an assets folder because the cgitrc will take a full
  # path rather than a frontend URL.
  mkHeadInclude = cfg: name: pkgs.writeText "cgit-theme-${name}-head-include.html" ''
    ${lib.concatStrings 
      (builtins.map (stylepath: 
      "<link rel='stylesheet' type='text/css' href='${assetsURL name}/${builtins.baseNameOf stylepath}' />\n"
    ) cfg.cssFiles)}

    ${cfg.extraHeadInclude}

    ${if cfg.css != null then "<link rel='stylesheet' type='text/css' href='${assetsURL name}/custom-css.css' />" else ""}
  '';

  mkAbout = cfg: name: pkgs.writeText "cgit-theme-${name}-about.html" cfg.aboutHTML;

  assetsURL = name: "${lib.removeSuffix "/" config.services.cgit.${name}.nginx.location}/assets";
in
{
  options.services.cgit-theme = lib.mkOption {
    description = "Configure cgit instances with easy custom styling.";
    default = { };
    # this is what allows setting up multiple instances
    type = lib.types.attrsOf themeOptions;
  };

  config = lib.mkIf (lib.any (cfg: cfg.enable) (lib.attrValues cfgs)) {
    services.cgit = lib.mapAttrs (name: cfg: {
      enable = true;
      settings = {
        head-include = "${mkHeadInclude cfg name}";
      }
        // lib.optionalAttrs (cfg.logo != null) { logo = "${assetsURL name}/${builtins.baseNameOf cfg.logo}"; }
        // lib.optionalAttrs (cfg.favicon != null) { favicon = "${assetsURL name}/${builtins.baseNameOf cfg.favicon}"; }
        // lib.optionalAttrs (cfg.aboutHTML != null) { root-readme = "${mkAbout cfg name}"; };
    }) cfgs;

    services.nginx.virtualHosts = lib.mapAttrs (name: cfg: {
      locations."${assetsURL name}/" = {
        alias = "${(mkCombinedAssets cfg name)}/assets/";
      };
    }) cfgs;
  };
}
