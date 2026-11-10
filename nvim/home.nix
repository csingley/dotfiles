# home-manager module: the editor (./module.nix) in the user profile, as nvim, vi and vim, and
# the default editor. Importing it turns it on, like the zsh module; a machine sets only what
# differs (its colorscheme, extra language groups).
#
# Not programs.neovim: that module manages ~/.config/nvim. This editor's config is baked into the
# store and ignores ~/.config/nvim, so a hand-rolled config there is left alone.
nvim:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.neovim;
  bin = "${cfg.package}/bin/nvim";
in
{
  options.dotfiles.neovim = {
    colorscheme = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''{ name = "catppuccin-mocha"; site = pkgs.vimPlugins.catppuccin-nvim; }'';
      description = "settings.colorscheme of the editor (./module.nix); {} keeps Neovim's default.";
    };
    nerdFont = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "The terminal's font has Nerd Font glyphs: icons in the file browser and pickers.";
    };
    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      example = lib.literalExpression ''[ { specs.puppet = { data = null; runtimePkgs = [ puppet-lsp ]; }; } ]'';
      description = "More nix-wrapper-modules modules for the editor: language groups, overrides.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = nvim.wrap (
        [
          {
            inherit pkgs;
            settings.colorscheme = cfg.colorscheme;
            settings.nerdFont = cfg.nerdFont;
          }
        ]
        ++ cfg.extraModules
      );
      description = "The built editor, for anything that needs its path.";
    };
  };

  config = {
    home.packages = [
      cfg.package
      # Binaries, not aliases, so vi/vim resolve under sudo, git over ssh and other
      # non-interactive contexts.
      (pkgs.writeShellScriptBin "vi" ''exec ${bin} "$@"'')
      (pkgs.writeShellScriptBin "vim" ''exec ${bin} "$@"'')
    ];
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GIT_EDITOR = "nvim";
    };
    home.shellAliases.vimdiff = "nvim -d";
  };
}
