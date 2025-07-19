{ lib, ... }:
lib.types.submodule
{
  options = {
    enable = lib.mkEnableOption "cgit-theme";

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
