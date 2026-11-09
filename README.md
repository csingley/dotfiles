# dotfiles

The shell environment, multiplexer and editor shared by every machine: the fleet, nous, macmini and the work
laptop.

| Output | What |
|---|---|
| `homeModules.zsh` (also `default`) | zsh with vi keys, autosuggestions, history-substring search, syntax highlighting, fzf, direnv and the starship prompt |
| `homeModules.tmux` | tmux with vi keys, mouse, long history, activity and bell marks on the window labels, and clipboard and passthrough for the terminal |
| `homeModules.neovim` | that editor in the user profile as nvim, vi and vim, and the default editor; options `dotfiles.neovim.colorscheme` and `.extraModules` |
| `wrappers.neovim` | Neovim 0.12, built with [nix-wrapper-modules](https://github.com/nix-community/nix-wrapper-modules): `.wrap { pkgs; ... }` builds it with the caller's nixpkgs |
| `packages.<system>.neovim` | the same, with this flake's nixpkgs and no colorscheme |

What only one machine needs (local PATH additions, aliases for local tools, key loaders) stays in
that machine's config. Colors come from the machine's theme module (starship reads its palette).

```nix
inputs.dotfiles.url = "github:csingley/dotfiles";
# home-manager modules:
dotfiles.homeModules.zsh
dotfiles.homeModules.tmux
```

## Neovim

`nvim/module.nix` lists the plugins, tree-sitter grammars and tools; `nvim/init.lua` is the
configuration (plugins load lazily through lze). The config is baked into the store and ignores
`~/.config/nvim`. A home-manager machine imports `homeModules.neovim` and sets what differs:

```nix
dotfiles.neovim = {
  colorscheme = { name = "catppuccin-mocha"; site = pkgs.vimPlugins.catppuccin-nvim; };
  extraModules = [ { specs.puppet = { data = null; runtimePkgs = [ puppet-languageserver ]; }; } ];
};
```

Anything else builds the package directly, passing the same things:

```nix
dotfiles.wrappers.neovim.wrap {
  inherit pkgs;
  # the :colorscheme and the directory that provides it; unset keeps Neovim's default
  settings.colorscheme = { name = "catppuccin-mocha"; site = pkgs.vimPlugins.catppuccin-nvim; };
  # a language group of your own (init.lua's for_cat matches the spec name), or one turned off
  specs.puppet = { data = null; runtimePkgs = [ puppet-languageserver ]; };
  specs.go.enable = false;
}
```

Whatever the colorscheme, the terminal draws the background, so a translucent terminal shows
through. `nvim/queries/` extends the bash and python highlights.
