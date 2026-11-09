-- NOTE: Welcome to your neovim configuration!
-- The first 100ish lines are setup,
-- the rest is usage of lze and various core plugins!
vim.loader.enable() -- <- bytecode caching

-- A distro's own neovim installs plugins under /usr/share/nvim/site (Arch: neovim-nvim-treesitter
-- and friends), which every nvim searches. Those shadow ours: an old nvim-treesitter.lua there
-- breaks the new API. The Nix build carries everything it needs, so drop system dirs.
if vim.g.nix_info_plugin_name then
  local function local_only(opt)
    opt:remove(vim.tbl_filter(function(p)
      return vim.startswith(p, '/usr/') or vim.startswith(p, '/etc/xdg/')
    end, opt:get()))
  end
  local_only(vim.opt.runtimepath)
  local_only(vim.opt.packpath)
end

do
  -- Set up a global in a way that also handles non-nix compat
  local ok
  ok, _G.nixInfo = pcall(require, vim.g.nix_info_plugin_name)
  if not ok then
    package.loaded[vim.g.nix_info_plugin_name] = setmetatable({}, {
      __call = function (_, default) return default end
    })
    _G.nixInfo = require(vim.g.nix_info_plugin_name)
    -- If you always use the fetcher function to fetch nix values,
    -- rather than indexing into the tables directly,
    -- it will use the value you specified as the default
    -- TODO: for non-nix compat, vim.pack.add in another file and require here.
  end
  nixInfo.isNix = vim.g.nix_info_plugin_name ~= nil
  ---@module 'lzextras'
  ---@type lzextras | lze
  nixInfo.lze = setmetatable(require('lze'), getmetatable(require('lzextras')))
  function nixInfo.get_nix_plugin_path(name)
    return nixInfo(nil, "plugins", "lazy", name) or nixInfo(nil, "plugins", "start", name)
  end
end
nixInfo.lze.register_handlers {
  {
    -- adds an `auto_enable` field to lze specs
    -- if true, will disable it if not installed by nix.
    -- if string, will disable if that name was not installed by nix.
    -- if a table of strings, it will disable if any were not.
    spec_field = "auto_enable",
    set_lazy = false,
    modify = function(plugin)
      if vim.g.nix_info_plugin_name then
        if type(plugin.auto_enable) == "table" then
          for _, name in pairs(plugin.auto_enable) do
            if not nixInfo.get_nix_plugin_path(name) then
              plugin.enabled = false
              break
            end
          end
        elseif type(plugin.auto_enable) == "string" then
          if not nixInfo.get_nix_plugin_path(plugin.auto_enable) then
            plugin.enabled = false
          end
        elseif type(plugin.auto_enable) == "boolean" and plugin.auto_enable then
          if not nixInfo.get_nix_plugin_path(plugin.name) then
            plugin.enabled = false
          end
        end
      end
      return plugin
    end,
  },
  {
    -- we made an options.settings.cats with the value of enable for our top level specs
    -- give for_cat = "name" to disable if that one is not enabled
    spec_field = "for_cat",
    set_lazy = false,
    modify = function(plugin)
      if vim.g.nix_info_plugin_name then
        if type(plugin.for_cat) == "string" then
          plugin.enabled = nixInfo(false, "settings", "cats", plugin.for_cat)
        end
      end
      return plugin
    end,
  },
  -- From lzextras. This one makes it so that
  -- you can set up lsps within lze specs,
  -- and trigger lspconfig setup hooks only on the correct filetypes
  -- It is (unfortunately) important that it be registered after the above 2,
  -- as it also relies on the modify hook, and the value of enabled at that point
  nixInfo.lze.lsp,
}

-- NOTE: This config uses lzextras.lsp handler https://github.com/BirdeeHub/lzextras?tab=readme-ov-file#lsp-handler
-- Because we have the paths, we can set a more performant fallback function
-- for when you don't provide a filetype to trigger on yourself.
-- If you do provide a filetype, this will never be called.
nixInfo.lze.h.lsp.set_ft_fallback(function(name)
  local lspcfg = nixInfo.get_nix_plugin_path "nvim-lspconfig"
  if lspcfg then
    local ok, cfg = pcall(dofile, lspcfg .. "/lsp/" .. name .. ".lua")
    return (ok and cfg or {}).filetypes or {}
  else
    -- the less performant thing we are trying to avoid at startup
    return (vim.lsp.config[name] or {}).filetypes or {}
  end
end)

-- Set before any plugin with keymaps loads.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- [[ Options ]]

-- .nvim.lua project config off
vim.o.exrc = false

-- zsh for :terminal and :! wherever it lives (/bin on NixOS, /usr/bin elsewhere); the login
-- shell may be something else (bash on the IT-owned work laptop).
do
  local zsh = vim.fn.exepath('zsh')
  if zsh ~= '' then
    vim.o.shell = zsh
  end
end

vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.opt.inccommand = 'split'
vim.opt.scrolloff = 10
vim.wo.number = true
vim.wo.relativenumber = true
vim.o.mouse = 'a'

-- Indent: vim-sleuth detects it per file; these apply where it finds nothing.
vim.opt.cpoptions:append('I')
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.api.nvim_create_autocmd('FileType', {
  desc = '2-space indent',
  pattern = { 'nix', 'sh', 'bash', 'zsh', 'puppet' },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.wo.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.completeopt = 'menu,preview,noselect'
vim.o.termguicolors = true

-- Yank and put use the system clipboard. Deferred: probing the clipboard provider is slow at
-- startup. x and c delete into the black-hole register so they don't clobber it; d still cuts.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)
vim.keymap.set({ 'n', 'x' }, 'x', '"_x', { desc = 'Delete char (keeps clipboard)' })
vim.keymap.set({ 'n', 'x' }, 'X', '"_X', { desc = 'Delete char before (keeps clipboard)' })
vim.keymap.set({ 'n', 'x' }, 'c', '"_c', { desc = 'Change (keeps clipboard)' })
vim.keymap.set({ 'n', 'x' }, 'C', '"_C', { desc = 'Change to end of line (keeps clipboard)' })
vim.keymap.set('x', '<leader>P', '"_dP', { desc = 'Paste over selection (keeps clipboard)' })
vim.keymap.set('i', '<C-p>', '<C-r><C-p>+', { desc = 'Paste from clipboard' })

vim.diagnostic.config({
  virtual_text = true, -- off by default since Neovim 0.11
  severity_sort = true,
  float = { border = 'rounded', source = true },
})

vim.api.nvim_create_autocmd('FileType', {
  desc = 'No auto-comment on new lines',
  callback = function()
    vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
  end,
})

vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('YankHighlight', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- The terminal draws the background, so a translucent one shows through. A colorscheme load
-- resets these groups, hence the autocmd; nvim_set_hl replaces a whole group, so copy it minus
-- bg to keep its fg.
local function clear_background()
  for _, group in ipairs({ 'Normal', 'NormalNC', 'SignColumn', 'EndOfBuffer' }) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg, hl.ctermbg = nil, nil
    vim.api.nvim_set_hl(0, group, hl)
  end
end
vim.api.nvim_create_autocmd('ColorScheme', { callback = clear_background })
clear_background()

vim.g.netrw_liststyle = 0
vim.g.netrw_banner = 0

-- [[ Keymaps ]]

vim.keymap.set('n', ';', ':', { desc = 'Command line' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move line down' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move line up' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search result' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous search result' })

vim.keymap.set('n', '[b', '<cmd>bprev<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bl', '<cmd>b#<CR>', { desc = '[b]uffer [l]ast' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = '[b]uffer [d]elete' })

-- Move by screen line through wrapped text, unless given a count.
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Diagnostic under cursor' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics list' })

-- [[ Plugins ]] (lze: https://github.com/BirdeeHub/lze#structuring-your-plugins)

nixInfo.lze.load {
  {
    -- Applied after VimEnter, once every plugin a colorscheme might depend on is in place.
    "trigger_colorscheme",
    event = "VimEnter",
    load = function(_name)
      vim.schedule(function()
        local name = nixInfo(nil, "settings", "colorscheme", "name")
        if name then
          vim.cmd.colorscheme(name)
        end
      end)
    end
  },
  {
    "snacks.nvim",
    auto_enable = true,
    lazy = false,
    priority = 1000,
    after = function(plugin)
      require('snacks').setup({
        -- oil takes over directory buffers instead (see the oil spec)
        explorer = { replace_netrw = false, },
        picker = {
          sources = {
            explorer = {
              auto_close = true,
            },
          },
        },
        git = {},
        terminal = {},
        scope = {},
        indent = {
          scope = {
            hl = 'SnacksIndent',
          },
          chunk = {
            hl = 'SnacksIndent',
          }
        },
        statuscolumn = {
          left = { "mark", "git" },
          right = { "sign", "fold" },
          folds = {
            open = false,
            git_hl = false,
          },
          git = {
            patterns = { "GitSign", "MiniDiffSign" },
          },
          refresh = 50,
        },
        -- lazygit's edit commands must reopen files in this nvim (it may not be the `nvim` on
        -- PATH), hence the remote commands and nixInfo.lazygit_fix below.
        lazygit = {
          config = {
            os = {
              editPreset = "nvim-remote",
              edit = vim.v.progpath .. [=[ --server "$NVIM" --remote-send '<cmd>lua nixInfo.lazygit_fix({{filename}})<CR>']=],
              editAtLine = vim.v.progpath .. [=[ --server "$NVIM" --remote-send '<cmd>lua nixInfo.lazygit_fix({{filename}}, {{line}})<CR>']=],
              openDirInEditor = vim.v.progpath .. [=[ --server "$NVIM" --remote-send '<cmd>lua nixInfo.lazygit_fix({{dir}})<CR>']=],
              editAtLineAndWait = nixInfo(vim.v.progpath, "progpath") .. " +{{line}} {{filename}}",
            },
          },
        },
      })
      nixInfo.lazygit_fix = function(path, line)
        local prev = vim.fn.bufnr("#")
        local prev_win = vim.fn.bufwinid(prev)
        vim.api.nvim_feedkeys("q", "n", false)
        vim.api.nvim_buf_call(prev, function()
          vim.cmd.edit(path)
          local buf = vim.api.nvim_get_current_buf()
          vim.schedule(function()
            if buf then
              vim.api.nvim_win_set_buf(prev_win, buf)
              if line then
                vim.api.nvim_win_set_cursor(0, { line or 0, 0 })
              end
            end
          end)
        end)
      end

      local map = function(lhs, rhs, desc, mode)
        vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
      end
      map("<c-\\>", function() Snacks.terminal.open() end, 'Terminal')
      map("<leader>gg", function() Snacks.lazygit.open() end, '[g]it lazy[g]it')
      -- find
      map("<leader><leader>", function() Snacks.picker.buffers() end, 'Find buffers')
      map("<leader>ff", function() Snacks.picker.files() end, '[f]ind [f]iles')
      map("<leader>fg", function() Snacks.picker.git_files() end, '[f]ind [g]it files')
      map("<leader>fb", function() Snacks.picker.buffers() end, '[f]ind [b]uffers')
      map("<leader>fo", function() Snacks.picker.recent() end, '[f]ind [o]ld (recent) files')
      map("<leader>fh", function() Snacks.picker.help() end, '[f]ind [h]elp')
      map("<leader>fe", function() Snacks.explorer.open() end, '[f]ile [e]xplorer (tree)')
      -- search
      map("<leader>/", function() Snacks.picker.lines() end, 'Search buffer lines')
      map("<leader>sf", function() Snacks.picker.smart() end, '[s]mart [f]ind files')
      map("<leader>s.", function() Snacks.picker.recent() end, '[s]earch recent files')
      map("<leader>sb", function() Snacks.picker.lines() end, '[s]earch [b]uffer lines')
      map("<leader>sB", function() Snacks.picker.grep_buffers() end, '[s]earch open [B]uffers')
      map("<leader>s/", function() Snacks.picker.grep_buffers() end, '[s]earch open buffers')
      map("<leader>sg", function() Snacks.picker.grep() end, '[s]earch by [g]rep')
      map("<leader>sw", function() Snacks.picker.grep_word() end, '[s]earch [w]ord or selection', { 'n', 'x' })
      map("<leader>sd", function() Snacks.picker.diagnostics() end, '[s]earch [d]iagnostics')
      map("<leader>sD", function() Snacks.picker.diagnostics_buffer() end, '[s]earch buffer [D]iagnostics')
      map("<leader>sh", function() Snacks.picker.help() end, '[s]earch [h]elp')
      map("<leader>sj", function() Snacks.picker.jumps() end, '[s]earch [j]umps')
      map("<leader>sk", function() Snacks.picker.keymaps() end, '[s]earch [k]eymaps')
      map("<leader>sc", function() Snacks.picker.command_history() end, '[s]earch [c]ommand history')
      map("<leader>sl", function() Snacks.picker.loclist() end, '[s]earch [l]ocation list')
      map("<leader>sm", function() Snacks.picker.marks() end, '[s]earch [m]arks')
      map("<leader>sM", function() Snacks.picker.man() end, '[s]earch [M]an pages')
      map("<leader>sq", function() Snacks.picker.qflist() end, '[s]earch [q]uickfix list')
      map("<leader>sr", function() Snacks.picker.resume() end, '[s]earch [r]esume')
      map("<leader>sR", function() Snacks.picker.resume() end, '[s]earch [R]esume')
      map("<leader>su", function() Snacks.picker.undo() end, '[s]earch [u]ndo history')
      map("<leader>st", function() Snacks.picker.todo_comments() end, '[s]earch [t]odos')
      -- git
      map("<leader>gc", function() Snacks.picker.git_log() end, '[g]it [c]ommits')
      map("<leader>gC", function() Snacks.picker.git_log_file() end, '[g]it buffer [C]ommits')
      map("<leader>gs", function() Snacks.picker.git_status() end, '[g]it [s]tatus')
      map("<leader>gB", function() Snacks.picker.git_branches() end, '[g]it [B]ranches')
    end
  },
  {
    "oil.nvim",
    auto_enable = true,
    -- Not lazy: it replaces netrw for `nvim <dir>` and :e <dir>.
    lazy = false,
    after = function(_)
      require('oil').setup({
        default_file_explorer = true,
        delete_to_trash = true,
        prompt_save_on_select_new_entry = true,
        view_options = { show_hidden = false },
      })
      vim.keymap.set('n', '-', '<cmd>Oil<CR>', { desc = 'Open parent directory (oil)' })
    end,
  },
  {
    "nvim-lspconfig",
    auto_enable = true,
    -- Runs for every spec with an `lsp` table, when its filetype loads it.
    lsp = function(plugin)
      vim.lsp.config(plugin.name, plugin.lsp or {})
      vim.lsp.enable(plugin.name)
    end,
    before = function(_)
      vim.lsp.config('*', {
        on_attach = function(_, bufnr)
          local nmap = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = bufnr, desc = 'LSP: ' .. desc })
          end

          nmap('<leader>rn', vim.lsp.buf.rename, '[r]e[n]ame')
          nmap('<leader>ca', vim.lsp.buf.code_action, '[c]ode [a]ction')
          nmap('gd', vim.lsp.buf.definition, '[g]oto [d]efinition')
          nmap('gD', vim.lsp.buf.declaration, '[g]oto [D]eclaration')
          nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
          nmap('gr', function() Snacks.picker.lsp_references() end, '[g]oto [r]eferences')
          nmap('gI', function() Snacks.picker.lsp_implementations() end, '[g]oto [I]mplementation')
          nmap('<leader>ds', function() Snacks.picker.lsp_symbols() end, '[d]ocument [s]ymbols')
          nmap('<leader>ws', function() Snacks.picker.lsp_workspace_symbols() end, '[w]orkspace [s]ymbols')
          nmap('K', vim.lsp.buf.hover, 'Hover documentation')
          nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature documentation')
          nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[w]orkspace [a]dd folder')
          nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[w]orkspace [r]emove folder')
          nmap('<leader>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, '[w]orkspace [l]ist folders')

          vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
            vim.lsp.buf.format()
          end, { desc = 'Format current buffer with LSP' })
        end
      })
    end,
  },
  {
    "mason.nvim",
    enabled = not nixInfo.isNix,
    priority = 100, -- run its lsp hook before lspconfig's
    on_plugin = { "nvim-lspconfig" },
    lsp = function(plugin)
      vim.cmd.MasonInstall(plugin.name)
    end,
  },
  {
    -- Loads only the Lua definitions a file uses, and maps our globals to their sources.
    "lazydev.nvim",
    auto_enable = true,
    cmd = { "LazyDev" },
    ft = "lua",
    after = function(_)
      require('lazydev').setup({
        library = {
          { words = { "nixInfo%.lze" }, path = nixInfo("lze", "plugins", "start", "lze") .. '/lua', },
          { words = { "nixInfo%.lze" }, path = nixInfo("lzextras", "plugins", "start", "lzextras") .. '/lua' },
        },
      })
    end,
  },
  {
    "lua_ls",
    for_cat = "lua",
    lsp = {
      -- Listing filetypes skips the lspconfig lookup (set_ft_fallback above).
      filetypes = { 'lua' },
      settings = {
        Lua = {
          signatureHelp = { enabled = true },
          diagnostics = {
            globals = { "nixInfo", "vim", },
            disable = { 'missing-fields' },
          },
        },
      },
    },
  },
  {
    "nixd",
    enabled = nixInfo.isNix, -- mason doesn't have nixd
    for_cat = "nix",
    lsp = {
      filetypes = { "nix" },
      settings = {
        nixd = {
          nixpkgs = {
            expr = "import " .. nixInfo("<nixpkgs>", "settings", "nixpkgs_path") .. " {}",
          },
          formatting = {
            command = { "nixfmt" }
          },
          diagnostic = {
            suppress = {
              "sema-escaping-with"
            }
          }
        }
      },
    },
  },
  -- Binaries come from runtimePkgs in module.nix; for_cat matches its top-level spec names.
  { "basedpyright", for_cat = "python",  lsp = {} },
  { "ruff",         for_cat = "python",  lsp = {} },
  { "gopls",        for_cat = "go",      lsp = {} },
  { "bashls",       for_cat = "shell",   lsp = {} },
  { "yamlls",       for_cat = "yaml",    lsp = {} },
  { "taplo",        for_cat = "toml",    lsp = {} },
  { "jsonls",       for_cat = "json",    lsp = {} },
  { "jqls",         for_cat = "jq",      lsp = { filetypes = { "jq" } } },
  { "jsonnet_ls",   for_cat = "jsonnet", lsp = {} },
  { "systemd_ls",   for_cat = "systemd", lsp = {} },
  -- The caller supplies puppet-languageserver (specs.puppet), so only hosts that add it get it.
  {
    "puppet",
    for_cat = "puppet",
    lsp = { filetypes = { "puppet" } },
    before = function(_)
      vim.filetype.add({ extension = { pp = "puppet", epp = "puppet" } })
    end,
  },
  {
    "nvim-treesitter",
    lazy = false,
    auto_enable = true,
    after = function(plugin)
      ---@param buf integer
      ---@param language string
      local function treesitter_try_attach(buf, language)
        if not vim.treesitter.language.add(language) then
          return false
        end
        vim.treesitter.start(buf, language)
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"
        vim.o.foldlevel = 99 -- folds start open
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        return true
      end

      local installable_parsers = require("nvim-treesitter").get_available()
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local buf, filetype = args.buf, args.match
          local language = vim.treesitter.language.get_lang(filetype)
          if not language then
            return
          end
          if not treesitter_try_attach(buf, language) then
            if vim.tbl_contains(installable_parsers, language) then
              require("nvim-treesitter").install(language):await(function()
                treesitter_try_attach(buf, language)
              end)
            end
          end
        end,
      })
    end,
  },
  {
    "nvim-treesitter-textobjects",
    auto_enable = true,
    lazy = false,
    before = function(plugin)
      -- Built-in ftplugin mappings would shadow ours.
      vim.g.no_plugin_maps = true
    end,
    after = function(plugin)
      require("nvim-treesitter-textobjects").setup {
        select = {
          lookahead = true,
          selection_modes = {
            ['@parameter.outer'] = 'v',
            ['@function.outer'] = 'V',
          },
          include_surrounding_whitespace = false,
        },
      }
      -- m for method/function (mini.ai's f is a function call), c class, s scope.
      local select = function(lhs, query, group)
        vim.keymap.set({ "x", "o" }, lhs, function()
          require "nvim-treesitter-textobjects.select".select_textobject(query, group)
        end)
      end
      select("am", "@function.outer", "textobjects")
      select("im", "@function.inner", "textobjects")
      select("ac", "@class.outer", "textobjects")
      select("ic", "@class.inner", "textobjects")
      select("as", "@local.scope", "locals")
    end,
  },
  {
    "conform.nvim",
    auto_enable = true,
    keys = {
      { "<leader>FF", desc = "[F]ormat [F]ile" },
    },
    ft = "go", -- format-on-save below
    after = function (plugin)
      local conform = require("conform")
      conform.setup({
        formatters_by_ft = {
          lua = nixInfo(nil, "settings", "cats", "lua") and { "stylua" } or nil,
          nix = { "nixfmt" },
          python = { "ruff_organize_imports", "ruff_format" },
          go = { "goimports", "gofumpt" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          yaml = { "yamlfmt" },
          toml = { "taplo" },
          json = { "jq" },
          jsonc = { "jq" },
        },
        -- Go only: gofmt'd code is the language's norm, so formatting on save never fights the
        -- surrounding code. Elsewhere it's on demand.
        format_on_save = function(buf)
          if vim.bo[buf].filetype == "go" then
            return { timeout_ms = 1000, lsp_format = "fallback" }
          end
        end,
      })
      vim.keymap.set({ "n", "v" }, "<leader>FF", function()
        conform.format({
          lsp_format = "fallback",
          async = false,
          timeout_ms = 1000,
        })
      end, { desc = "[F]ormat [F]ile" })
    end,
  },
  {
    "nvim-lint",
    auto_enable = true,
    event = "FileType",
    after = function (plugin)
      -- python: the ruff LSP reports diagnostics; shell: bashls runs shellcheck.
      require('lint').linters_by_ft = {
        lua = { 'luacheck' },
        go = { 'golangcilint' },
        yaml = { 'yamllint' },
      }
      -- luacheck doesn't know Neovim's globals.
      local luacheck = require('lint').linters.luacheck
      luacheck.args = vim.list_extend(
        { '--globals', 'vim', 'nixInfo', '--no-max-line-length' },
        luacheck.args or {}
      )
      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },
  {
    "cmp-cmdline",
    auto_enable = true,
    on_plugin = { "blink.cmp" },
    load = nixInfo.lze.loaders.with_after,
  },
  {
    "blink.compat",
    auto_enable = true,
    dep_of = { "cmp-cmdline" },
  },
  {
    "colorful-menu.nvim",
    auto_enable = true,
    on_plugin = { "blink.cmp" },
  },
  {
    "blink.cmp",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function (_)
      require("blink.cmp").setup({
        -- C-y accepts, like built-in completion (:h blink-cmp-config-keymap)
        keymap = {
          preset = 'default',
        },
        cmdline = {
          enabled = true,
          completion = {
            menu = {
              auto_show = true,
            },
          },
          sources = function()
            local type = vim.fn.getcmdtype()
            if type == '/' or type == '?' then return { 'buffer' } end
            if type == ':' or type == '@' then return { 'cmdline', 'cmp_cmdline' } end
            return {}
          end,
        },
        fuzzy = {
          sorts = {
            'exact',
            'score',
            'sort_text',
          },
        },
        signature = {
          enabled = true,
          window = {
            show_documentation = true,
          },
        },
        completion = {
          menu = {
            draw = {
              treesitter = { 'lsp' },
              components = {
                label = {
                  text = function(ctx)
                    return require("colorful-menu").blink_components_text(ctx)
                  end,
                  highlight = function(ctx)
                    return require("colorful-menu").blink_components_highlight(ctx)
                  end,
                },
              },
            },
          },
          documentation = {
            auto_show = true,
          },
        },
        sources = {
          default = { 'lsp', 'path', 'buffer', 'omni' },
          providers = {
            path = {
              score_offset = 50,
            },
            lsp = {
              score_offset = 40,
            },
            cmp_cmdline = {
              name = 'cmp_cmdline',
              module = 'blink.compat.source',
              score_offset = -100,
              opts = {
                cmp_name = 'cmdline',
              },
            },
          },
        },
      })
    end,
  },
  {
    -- ys{motion}{char} add, ds{char} delete, cs{old}{new} change
    "nvim-surround",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function(plugin)
      require('nvim-surround').setup()
    end,
  },
  {
    "mini.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function(_)
      -- Text objects: q any quote, b any bracket, f function call, a argument, t tag; with n/l
      -- for the next/last one (cinq, dalb).
      require('mini.ai').setup({ n_lines = 50 })
      -- Auto-close brackets and quotes, in insert mode only.
      require('mini.pairs').setup({ modes = { insert = true, command = false, terminal = false } })
    end,
  },
  {
    "vim-startuptime",
    auto_enable = true,
    cmd = { "StartupTime" },
    before = function(_)
      vim.g.startuptime_event_width = 0
      vim.g.startuptime_tries = 10
      vim.g.startuptime_exe_path = nixInfo(vim.v.progpath, "progpath")
    end,
  },
  {
    "fidget.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function(plugin)
      require('fidget').setup({})
    end,
  },
  {
    "lualine.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function (plugin)
      -- The colorscheme's own lualine theme when it ships one under that name, else derived.
      local name = nixInfo(nil, "settings", "colorscheme", "name")
      local theme = name and pcall(require, 'lualine.themes.' .. name) and name or 'auto'
      require('lualine').setup({
        options = {
          icons_enabled = false,
          theme = theme,
          component_separators = '|',
          section_separators = '',
        },
        sections = {
          lualine_c = {
            { 'filename', path = 1, status = true, },
          },
        },
        inactive_sections = {
          lualine_b = {
            { 'filename', path = 3, status = true, },
          },
          lualine_x = {'filetype'},
        },
        tabline = {
          lualine_a = { 'buffers' },
          lualine_z = { 'tabs' }
        },
      })
    end,
  },
  {
    "gitsigns.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function (plugin)
      require('gitsigns').setup({
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
          untracked = { text = '┆' },
        },
        signs_staged_enable = true,
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- In diff mode ]c/[c keep their built-in meaning.
          map({ 'n', 'v' }, ']c', function()
            if vim.wo.diff then
              return ']c'
            end
            vim.schedule(function() gs.nav_hunk('next') end)
            return '<Ignore>'
          end, { expr = true, desc = 'Next git hunk' })
          map({ 'n', 'v' }, '[c', function()
            if vim.wo.diff then
              return '[c'
            end
            vim.schedule(function() gs.nav_hunk('prev') end)
            return '<Ignore>'
          end, { expr = true, desc = 'Previous git hunk' })

          map('n', '<leader>ghs', gs.stage_hunk, { desc = '[g]it [h]unk [s]tage (toggle)' })
          map('n', '<leader>ghr', gs.reset_hunk, { desc = '[g]it [h]unk [r]eset' })
          map('v', '<leader>ghs', function()
            gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = '[g]it [h]unk [s]tage selection' })
          map('v', '<leader>ghr', function()
            gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = '[g]it [h]unk [r]eset selection' })
          map('n', '<leader>ghS', gs.stage_buffer, { desc = '[g]it [h]unk [S]tage buffer' })
          map('n', '<leader>ghR', gs.reset_buffer, { desc = '[g]it [h]unk [R]eset buffer' })
          map('n', '<leader>ghp', gs.preview_hunk, { desc = '[g]it [h]unk [p]review' })
          map('n', '<leader>ghb', function()
            gs.blame_line { full = true }
          end, { desc = '[g]it [h]unk [b]lame line' })
          map('n', '<leader>ghd', gs.diffthis, { desc = '[g]it [h]unk [d]iff vs index' })
          map('n', '<leader>ghD', function()
            gs.diffthis '~'
          end, { desc = '[g]it [h]unk [D]iff vs last commit' })
          map('n', '<leader>ghtb', gs.toggle_current_line_blame, { desc = 'toggle line [b]lame' })
          map('n', '<leader>ghtd', gs.preview_hunk_inline, { desc = 'show [d]eleted lines inline' })
          map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Select git hunk' })
        end,
      })
    end,
  },
  {
    "diffview.nvim",
    auto_enable = true,
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<CR>", desc = "[g]it [d]iff [o]pen" },
      { "<leader>gdc", "<cmd>DiffviewClose<CR>", desc = "[g]it [d]iff [c]lose" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory<CR>", desc = "[g]it [d]iff repo [h]istory" },
      { "<leader>gdf", "<cmd>DiffviewFileHistory %<CR>", desc = "[g]it [d]iff [f]ile history" },
      { "<leader>gdm", "<cmd>DiffviewOpen HEAD<CR>", desc = "[g]it [d]iff vs HEAD" },
    },
    after = function(_)
      require('diffview').setup({
        enhanced_diff_hl = true,
        file_panel = {
          listing_style = "tree",
          tree_options = { flatten_dirs = true, folder_statuses = "only_folded" },
        },
      })
    end,
  },
  {
    "todo-comments.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function(_)
      local todo = require('todo-comments')
      todo.setup({})
      vim.keymap.set('n', ']t', todo.jump_next, { desc = 'Next todo comment' })
      vim.keymap.set('n', '[t', todo.jump_prev, { desc = 'Previous todo comment' })
    end,
  },
  {
    "which-key.nvim",
    auto_enable = true,
    event = "DeferredUIEnter",
    after = function (plugin)
      require('which-key').setup({})
      require('which-key').add {
        { "<leader>b", group = "[b]uffer" },
        { "<leader>c", group = "[c]ode" },
        { "<leader>d", group = "[d]ocument" },
        { "<leader>f", group = "[f]ind" },
        { "<leader>F", group = "[F]ormat" },
        { "<leader>g", group = "[g]it" },
        { "<leader>gd", group = "[g]it [d]iff" },
        { "<leader>gh", group = "[g]it [h]unk" },
        { "<leader>ght", group = "[g]it [h]unk [t]oggle" },
        { "<leader>r", group = "[r]ename" },
        { "<leader>s", group = "[s]earch" },
        { "<leader>w", group = "[w]orkspace" },
      }
    end,
  },
}
