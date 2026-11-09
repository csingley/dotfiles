{
  description = "csingley's shell environment: zsh for home-manager, and Neovim";

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
    in
    {
      homeModules = {
        zsh = ./zsh;
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
