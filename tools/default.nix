# Command-line tools without a configuration of their own, on every machine: search and data
# wrangling, a monitor, and the network and process inspectors. Tools that carry configuration
# (zsh's fzf, direnv and starship, Neovim, tmux) come with their own modules; fzf and direnv are
# listed here too so they are on the PATH whichever modules a machine imports.
#
# These are not setuid and have no file capabilities. iftop, iotop and powertop need root, and
# sudo's secure_path usually lacks the Nix profile. The zsh module's `sudo` function passes the full
# path for `sudo cmd`; other shells, and `sudo -u user cmd`, need `sudo $(which cmd)`.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dotfiles.tools.packages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default =
      with pkgs;
      [
        ripgrep
        fd
        fzf
        direnv
        jq
        yq-go
        curl
        bat
        btop
        tree
        lsof
        dnsutils # dig, nslookup
        socat
        iftop
      ]
      # Linux interfaces: macOS has its own (dtruss, vm_stat, iostat, lsof -i).
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        strace
        sysstat # iostat, mpstat, sar
        # The maintained C rewrite of the Python iotop. Distros install it as `iotop` too
        # (Debian, Fedora); nixpkgs only as iotop-c, so add the usual name and its man page.
        (symlinkJoin {
          name = "iotop-c-${iotop-c.version}";
          paths = [ iotop-c ];
          postBuild = ''
            ln -s iotop-c $out/bin/iotop
            ln -s iotop-c.8.gz $out/share/man/man8/iotop.8.gz
          '';
        })
        powertop
      ];
    defaultText = lib.literalExpression "ripgrep fd fzf direnv jq yq-go curl bat btop tree lsof dnsutils socat iftop, and on Linux strace sysstat iotop-c powertop";
    description = "The tools to install; set it to change the list. Add one more with home.packages.";
  };

  config.home.packages = config.dotfiles.tools.packages;
}
