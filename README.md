# dotfiles

The shell environment shared by every machine: the fleet, nous, macmini and the work laptop.

| Output | What |
|---|---|
| `homeModules.zsh` (also `default`) | zsh with vi keys, autosuggestions, history-substring search, syntax highlighting, fzf, direnv and the starship prompt |

What only one machine needs (local PATH additions, aliases for local tools, key loaders) stays in
that machine's config. Colors come from the machine's theme module (starship reads its palette).

```nix
inputs.dotfiles.url = "git+ssh://git@github.com/csingley/dotfiles";
# home-manager modules:
dotfiles.homeModules.zsh
```
