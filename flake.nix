{
  description = "csingley's environment: zsh, tmux, Neovim and CLI tools for home-manager";

  inputs = {
    # Callers' own nixpkgs builds the editor (wrap { pkgs }); this one is for the
    # package output and the checks.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Every `plugins-*` input becomes a Neovim plugin (nvim/module.nix).
    plugins-lze = {
      url = "github:BirdeeHub/lze";
      flake = false;
    };
    plugins-lzextras = {
      url = "github:BirdeeHub/lzextras";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      wrappers,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAll = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      nvimModule = lib.modules.importApply ./nvim/module.nix inputs;
      nvim = (wrappers.lib.evalModule nvimModule).config;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./zsh
          ./tmux
          ./tools
          self.homeModules.neovim
          {
            home = {
              username = "test";
              homeDirectory = "/home/test";
              stateVersion = "26.05";
            };
          }
        ];
      };

      # The same modules for macOS, to be evaluated (never built) by the darwin check below.
      hmDarwin = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./zsh
          ./tmux
          ./tools
          self.homeModules.neovim
          {
            home = {
              username = "test";
              homeDirectory = "/Users/test";
              stateVersion = "26.05";
            };
          }
        ];
      };
    in
    {
      homeModules = {
        zsh = ./zsh;
        tmux = ./tmux;
        tools = ./tools;
        neovim = import ./nvim/home.nix nvim;
        default = ./zsh;
      };

      # nvim.wrap { pkgs = ...; settings.colorscheme = ...; specs.<name> = ...; } builds the
      # editor with the caller's nixpkgs and settings.
      wrappers.neovim = nvim;
      wrapperModules.neovim = nvimModule;

      packages = forAll (pkgs: {
        neovim = nvim.wrap { inherit pkgs; };
      });

      checks.${system} = {
        neovim = self.packages.${system}.neovim;
        zsh = pkgs.runCommand "dotfiles-zsh-check" { } ''
          cd ${hm.config.home-files}
          must() { grep -q "$@" || { echo "missing: $*"; exit 1; }; }
          must 'bindkey -v' .config/zsh/.zshrc
          must 'HISTFILE="/home/test/.local/state/zsh/history"' .config/zsh/.zshrc
          must 'starship init zsh' .config/zsh/.zshrc
          must 'typeset -U path' .config/zsh/.zshenv
          must 'SHELL:t} == zsh' .config/zsh/.zshenv
          touch $out
        '';
        tmux = pkgs.runCommand "dotfiles-tmux-check" { } ''
          cd ${hm.config.home-files}
          must() { grep -q "$@" || { echo "missing: $*"; exit 1; }; }
          must 'mode-keys  *vi' .config/tmux/tmux.conf
          must 'monitor-bell on' .config/tmux/tmux.conf
          must 'allow-passthrough on' .config/tmux/tmux.conf
          touch $out
        '';
        tools = pkgs.runCommand "dotfiles-tools-check" { } ''
          cd ${hm.config.home.path}
          for b in rg fd fzf direnv jq yq curl bat btop tree lsof dig socat iftop strace iostat iotop iotop-c powertop; do
            test -x bin/$b || { echo "missing: $b"; exit 1; }
          done
          test -e share/man/man8/iotop.8.gz
          touch $out
        '';
        # `sudo cmd` passes the command's full path (the Nix profile is not on sudo's secure_path);
        # anything else goes through as typed.
        zsh-sudo = pkgs.runCommand "dotfiles-zsh-sudo-check" { nativeBuildInputs = [ pkgs.zsh ]; } ''
          mkdir fake nix
          printf '#!/bin/sh\necho "$@"\n' > fake/sudo
          printf '#!/bin/sh\n' > nix/iftop
          chmod +x fake/sudo nix/iftop
          export PATH=$PWD/nix:$PWD/fake:$PATH
          got=$(zsh -fc 'source ${./zsh/funcs.sh}; sudo iftop -i eth0')
          [ "$got" = "$PWD/nix/iftop -i eth0" ] || { echo "plain: $got"; exit 1; }
          got=$(zsh -fc 'source ${./zsh/funcs.sh}; sudo -u root iftop')
          [ "$got" = "-u root iftop" ] || { echo "with options: $got"; exit 1; }
          touch $out
        '';
        # The macOS profile must evaluate: a package missing there, or an unguarded Linux-only one,
        # fails here instead of on a Mac. Nothing is built; the profile's derivation is only
        # computed, and its context dropped so the Linux check does not depend on it.
        darwin = pkgs.runCommand "dotfiles-darwin-eval-check"
          {
            profile = builtins.unsafeDiscardStringContext hmDarwin.config.home.path.drvPath;
            tools = lib.concatMapStringsSep " " (p: p.pname or p.name) hmDarwin.config.dotfiles.tools.packages;
          }
          ''
            echo "$profile"
            case " $tools " in *" ripgrep "*) ;; *) echo "tools list lost ripgrep: $tools"; exit 1 ;; esac
            for n in strace sysstat iotop-c powertop; do
              case " $tools " in *" $n "*) echo "Linux-only on macOS: $n"; exit 1 ;; esac
            done
            touch $out
          '';
        neovim-home = pkgs.runCommand "dotfiles-neovim-home-check" { } ''
          cd ${hm.config.home.path}
          must() { grep -q "$@" || { echo "missing: $*"; exit 1; }; }
          test -x bin/nvim
          must 'exec /nix/store/.*/bin/nvim' bin/vi
          must 'exec /nix/store/.*/bin/nvim' bin/vim
          must 'EDITOR="nvim"' etc/profile.d/hm-session-vars.sh
          touch $out
        '';
      };
    };
}
