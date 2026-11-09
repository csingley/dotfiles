# Interactive zsh, the same on every machine. What only one machine needs (local PATH additions,
# aliases for local tools, key loaders) belongs to that machine's config.
{ config, lib, ... }:
let
  state = "${config.xdg.stateHome}/zsh";
  cache = "${config.xdg.cacheHome}/zsh";
in
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    defaultKeymap = "viins";
    autocd = true;
    setOptions = [ "INTERACTIVE_COMMENTS" ]; # allow `# comments` at the prompt

    enableCompletion = true;
    completionInit = ''
      autoload -U compinit && compinit -d "${cache}/zcompdump"
    '';
    # Inline suggestion from history, then completion.
    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };
    historySubstringSearch.enable = true; # ↑/↓ cycle entries matching the typed prefix
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "brackets" ]; # added to the default `main`
    };

    history = {
      path = "${state}/history";
      size = 1000000;
      save = 1000000;
      ignoreAllDups = true;
      share = true;
    };

    shellAliases.ll = "ls -lah";

    # zsh doesn't source the Nix profile itself; .zshenv covers every kind of shell. The script is
    # where Nix's installer puts it, or where a distro's nix package does (Arch). Order 900 so a
    # machine's own PATH additions (at a later order) come after the de-duplication.
    envExtra = lib.mkOrder 900 ''
      for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh /etc/profile.d/nix-daemon.sh; do
        if [ -e "$f" ]; then . "$f"; break; fi
      done
      typeset -U path # PATH without duplicates; the first occurrence wins

      # Tools read $SHELL. Where this zsh isn't the login shell (a work laptop's IT-owned bash),
      # the session's value is the login shell's, and terminals don't override it for a Nix path
      # that is not in /etc/shells. Where the login shell is already zsh, nothing changes.
      [[ ''${SHELL:t} == zsh ]] || export SHELL=${config.programs.zsh.package}/bin/zsh
    '';

    initContent = ''
      bindkey '^[[Z' autosuggest-accept # Shift-Tab accepts the suggestion; Tab still completes
      source ${./funcs.sh}
    '';
  };

  # zsh creates neither directory itself.
  home.activation.zshDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${state} ${cache}
  '';

  programs.fzf.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.starship = {
    enable = true;
    settings.add_newline = false;
  };
}
