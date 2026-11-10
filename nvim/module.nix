inputs:
{
  config,
  wlib,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [ wlib.wrapperModules.neovim ];

  # Plugins built from the flake's `plugins-*` inputs, as config.nvim-lib.neovimPlugins.<name>.
  options.nvim-lib.neovimPlugins = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf wlib.types.stringable;
    default = config.nvim-lib.pluginsFromPrefix "plugins-" inputs;
  };

  # Only what nvim reads, so editing the Nix files here doesn't change the editor. A string, not
  # the fileset's attrset: settings are serialized into Lua, and the attrset would drag the whole
  # source directory along (its origSrc).
  config.settings.config_directory = "${
    lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./init.lua
        ./queries
      ];
    }
  }";

  # nixd evaluates nixpkgs option/package completions against the same nixpkgs the editor was
  # built from, not whatever <nixpkgs> happens to be on NIX_PATH.
  config.settings.nixpkgs_path = "${pkgs.path}";

  # The colorscheme comes from the caller: `name` is the :colorscheme to apply (and the lualine
  # theme, when one of that name exists), `site` a directory laid out like Neovim's site directory
  # (colors/, lua/): Malachite's `share/nvim/site`, or a colorscheme plugin such as
  # pkgs.vimPlugins.catppuccin-nvim. Unset, Neovim keeps its default colors. Whatever the scheme,
  # the terminal draws the background (init.lua), so a translucent terminal shows through.
  options.settings.colorscheme = lib.mkOption {
    type = lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "catppuccin-mocha";
          description = "The colorscheme to apply at startup; null applies none.";
        };
        site = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "pkgs.vimPlugins.catppuccin-nvim";
          description = "A directory with the colorscheme's colors/ and lua/ files, added to the runtimepath.";
        };
      };
    };
    default = { };
    description = "The colorscheme: its name and the files that provide it.";
  };

  # Whether the terminal's font has Nerd Font glyphs (init.lua: vim.g.have_nerd_font). Off, the file
  # browser and pickers draw no icons. No way to detect it: the font is the terminal's, and over ssh
  # that terminal is another machine's.
  options.settings.nerdFont = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Draw Nerd Font icons.";
  };

  # tinted-nvim is the plugin Malachite's colorscheme is built on.
  config.specs.colors = {
    data = [
      pkgs.vimPlugins.tinted-nvim
    ]
    ++ lib.optional (config.settings.colorscheme.site != null) (
      pkgs.runCommand "colorscheme-site" { } "mkdir -p $out && cp -r ${config.settings.colorscheme.site}/. $out/"
    );
    lazy = false;
  };

  config.specs.lze = [
    config.nvim-lib.neovimPlugins.lze
    {
      data = config.nvim-lib.neovimPlugins.lzextras;
      name = "lzextras";
    }
  ];

  # Language groups: the top-level spec names are what init.lua's `for_cat` checks, so a caller
  # can add one (e.g. specs.puppet = { data = null; runtimePkgs = [ puppet-languageserver ]; })
  # or turn one off (specs.go.enable = false).
  config.specs.nix = {
    data = null;
    runtimePkgs = with pkgs; [
      nixd
      nixfmt
    ];
  };
  config.specs.python = {
    data = null;
    runtimePkgs = with pkgs; [
      basedpyright
      ruff
    ];
  };
  config.specs.go = {
    data = null;
    runtimePkgs = with pkgs; [
      go # gopls needs a go toolchain on PATH
      gopls
      gofumpt
      gotools # goimports
      golangci-lint
    ];
  };
  config.specs.shell = {
    data = null;
    runtimePkgs = with pkgs; [
      bash-language-server
      shellcheck
      shfmt
    ];
  };
  config.specs.yaml = {
    data = null;
    runtimePkgs = with pkgs; [
      yaml-language-server
      yamlfmt
      yamllint
    ];
  };
  config.specs.toml = {
    data = null;
    runtimePkgs = with pkgs; [ taplo ];
  };
  config.specs.json = {
    data = null;
    runtimePkgs = with pkgs; [
      vscode-langservers-extracted # vscode-json-language-server
      jq
    ];
  };
  config.specs.jq = {
    data = null;
    runtimePkgs = with pkgs; [ jq-lsp ];
  };
  config.specs.jsonnet = {
    data = null;
    runtimePkgs = with pkgs; [ jsonnet-language-server ];
  };
  config.specs.systemd = {
    data = null;
    runtimePkgs = with pkgs; [ systemd-language-server ];
  };
  config.specs.lua = {
    after = [ "general" ];
    lazy = true;
    data = with pkgs.vimPlugins; [
      lazydev-nvim
    ];
    runtimePkgs = with pkgs; [
      lua-language-server
      stylua
      luaPackages.luacheck
    ];
  };

  config.specs.general = {
    after = [ "lze" ];
    runtimePkgs = with pkgs; [
      lazygit
      tree-sitter
      ripgrep # snacks picker: grep
      fd # snacks picker: files
    ];
    # lazy carries over to the plugins in `data`; lze loads them from init.lua's specs.
    lazy = true;
    data = with pkgs.vimPlugins; [
      {
        data = vim-sleuth;
        lazy = false;
      }
      snacks-nvim
      oil-nvim
      nvim-web-devicons # oil's icons
      nvim-lspconfig
      nvim-surround
      mini-nvim # mini.ai, mini.pairs
      vim-startuptime
      blink-cmp
      blink-compat
      cmp-cmdline
      colorful-menu-nvim
      lualine-nvim
      gitsigns-nvim
      diffview-nvim
      todo-comments-nvim
      which-key-nvim
      fidget-nvim
      nvim-lint
      conform-nvim
      nvim-treesitter-textobjects
      nvim-treesitter.withAllGrammars
    ];
  };

  # Give every spec a runtimePkgs field (PATH additions, dropped when the spec is disabled).
  config.specMods =
    { ... }:
    {
      options.runtimePkgs = options.runtimePkgs // {
        description = ''
          A runtimePkgs spec field to put packages on the PATH
          If the spec is disabled, this value will not be included in the resulting neovim derivation
        '';
      };
    };
  config.runtimePkgs = config.specCollect (acc: v: acc ++ (v.runtimePkgs or [ ])) [ ];

  # Tell init.lua which top-level specs are enabled.
  options.settings.cats = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf lib.types.bool;
    default = builtins.mapAttrs (_: v: v.enable) config.specs;
  };
  options.nvim-lib.pluginsFromPrefix = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    default =
      prefix: inputs:
      lib.pipe inputs [
        builtins.attrNames
        (builtins.filter (s: lib.hasPrefix prefix s))
        (map (
          input:
          let
            name = lib.removePrefix prefix input;
          in
          {
            inherit name;
            value = config.nvim-lib.mkPlugin name inputs.${input};
          }
        ))
        builtins.listToAttrs
      ];
  };
}
