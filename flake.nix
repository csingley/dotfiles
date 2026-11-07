{
  description = "csingley's shell environment: zsh for home-manager";

  inputs = {
    # only for the check
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./zsh
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
        default = ./zsh;
      };

      checks.${system}.zsh = pkgs.runCommand "dotfiles-zsh-check" { } ''
        cd ${hm.config.home-files}
        must() { grep -q "$@" || { echo "missing: $*"; exit 1; }; }
        must 'bindkey -v' .config/zsh/.zshrc
        must 'HISTFILE="/home/test/.local/state/zsh/history"' .config/zsh/.zshrc
        must 'starship init zsh' .config/zsh/.zshrc
        must 'typeset -U path' .config/zsh/.zshenv
        touch $out
      '';
    };
}
