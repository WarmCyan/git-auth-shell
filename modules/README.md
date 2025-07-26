# `cgit-theme`

I found it annoyingly difficult to set up custom styles with cgit through nixos,
mostly because several relevant options take web URLs (e.g. logo and favicon)
rather than raw nix store filepaths, and the underlying nginx configuration
configured by the cgit module only targets the default files that come with
cgit.

This module creates a `services.cgit-theme.<name>` to be used in tandem with
`services.cgit.<name>` and allows setting several theming options (image files
for `logo` and `favicon`, and several ways of specifying styling, e.g. using
`css` for raw CSS text, `cssFiles` to include one or more paths to stylesheets,
and/or specifying both `assets` and `extraHeadInclude`.

Under the hood it works by adding all of the resulting files into an 'assets'
subdirectory in the nix store, and then adding a `/assets` location to the cgit
nginx virtual host that points to it.

## Example

```nix
# in a nixos system config
{ ... }:
{
    services.cgit.test = {
        enable = true;
        user = "git";
        scanPath = "/home/git/gitrepos";
    };
    services.cgit-theme.test = {
        enable = true;
        logo = ./my-cgit-assets/logo.png;
        aboutHTML = builtins.readFile ./about.html;
        cssFiles = [ ./my-cgit-assets/style.css ];
        css = /* css */ ''
            body {
                background-color: #333 !important;
            };
        '';
        extraHeadInclude = ''
            <meta name="viewport" content="width=device-width initial-scale=1.0" />
        '';
    };
}
```

# `small-git-server`

This nixos module adds a `small-git-server` service, which when enabled adds a
git user and allows declaratively specifying SSH authorized keys and the
associated "usernames" to use for each with the accompanying `git-auth-shell`
tool. It also allows setting up an associated cgit server, and contains all the
same options as the `cgit-theme` module above to make it easier to define the
theme all in one place. It sets several default options for the cgit server.
