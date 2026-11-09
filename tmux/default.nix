# tmux for sessions that outlive the window and the connection, the same on every machine. What
# only one machine needs (the shell, the package, the terminal's capabilities) belongs to that
# machine's config. Colors come from the machine's theme module; for a bell to fill the window's
# label (rather than recolor it), the theme relies on `monitor-bell` below.
{
  programs.tmux = {
    enable = true;

    terminal = "tmux-256color"; # the module default is "screen"
    keyMode = "vi"; # matches zsh's vi keymap
    mouse = true;
    focusEvents = true;
    escapeTime = 10; # the default 500 ms makes Esc lag in Neovim
    historyLimit = 100000; # agent output is long
    aggressiveResize = true;
    clock24 = true; # the module default is 12-hour

    extraConfig = ''
      # Extended keys (Shift-Enter), and programs' escape sequences (notifications, OSC 52) pass
      # through to the terminal. Which terminals support extended keys is the machine's to say
      # (terminal-features).
      set -g extended-keys on
      set -g allow-passthrough on
      set -s set-clipboard on

      # Activity recolors the window's text; a bell fills its label until you visit the window.
      set -g monitor-activity on
      set -g monitor-bell on
      set -g visual-activity off
      set -g renumber-windows on
    '';
  };
}
