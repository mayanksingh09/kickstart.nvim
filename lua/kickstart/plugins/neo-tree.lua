-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  -- NOTE: kept as `config` rather than upstream's `opts` — the custom
  -- cross-instance clipboard commands below close over `clipboard_path`.
  config = function()
    -- Shared clipboard file so file yank/paste works across Neovim instances
    local clipboard_path = vim.fn.stdpath('data') .. '/neo-tree-clipboard.json'

    require('neo-tree').setup({
      filesystem = {
        window = {
          mappings = {
            ['\\'] = 'close_window',
          },
        },
        commands = {
          -- Neo-tree keeps one state per tabpage, but its buffer-local mappings
          -- live on the (global) neo-tree buffer. So when that buffer is shown
          -- in a tab where the tree was never rendered, `state.tree` is still
          -- nil and upstream's `common/commands.lua` indexes it unguarded:
          --   E5108: attempt to index local 'tree' (a nil value)
          -- Render the tree for this tab instead of erroring.
          toggle_node = function(state)
            if not state.tree then
              require('neo-tree.sources.manager').navigate(state)
              return
            end
            local fs = require('neo-tree.sources.filesystem')
            require('neo-tree.sources.common.commands').toggle_node(state, require('neo-tree.utils').wrap(fs.toggle_directory, state))
          end,
          copy_to_clipboard = function(state)
            local node = state.tree:get_node()
            local filepath = node:get_id()
            -- Run default behavior (in-process clipboard)
            require('neo-tree.sources.common.commands').copy_to_clipboard(state)
            -- Also persist to shared file for cross-instance paste
            local data = vim.fn.json_encode({ action = 'copy', path = filepath })
            vim.fn.writefile({ data }, clipboard_path)
          end,
          cut_to_clipboard = function(state)
            local node = state.tree:get_node()
            local filepath = node:get_id()
            require('neo-tree.sources.common.commands').cut_to_clipboard(state)
            local data = vim.fn.json_encode({ action = 'cut', path = filepath })
            vim.fn.writefile({ data }, clipboard_path)
          end,
          paste_from_clipboard = function(state)
            -- If internal clipboard has items, use default behavior
            if state.clipboard and next(state.clipboard) then
              require('neo-tree.sources.common.commands').paste_from_clipboard(state)
              return
            end
            -- Otherwise try the shared clipboard file (cross-instance paste)
            if vim.fn.filereadable(clipboard_path) ~= 1 then
              vim.notify('Clipboard is empty', vim.log.levels.WARN)
              return
            end
            local lines = vim.fn.readfile(clipboard_path)
            if #lines == 0 then
              vim.notify('Clipboard is empty', vim.log.levels.WARN)
              return
            end
            local ok, entry = pcall(vim.fn.json_decode, lines[1])
            if not ok or not entry or not entry.path then
              vim.notify('Invalid clipboard data', vim.log.levels.ERROR)
              return
            end
            if vim.fn.filereadable(entry.path) == 0 and vim.fn.isdirectory(entry.path) == 0 then
              vim.notify('Source no longer exists: ' .. entry.path, vim.log.levels.ERROR)
              return
            end
            local node = state.tree:get_node()
            local dest_dir = node:get_id()
            if node.type ~= 'directory' then
              dest_dir = vim.fn.fnamemodify(dest_dir, ':h')
            end
            local filename = vim.fn.fnamemodify(entry.path, ':t')
            local dest = dest_dir .. '/' .. filename
            local function do_paste()
              if entry.action == 'copy' then
                vim.fn.system({ 'cp', '-r', entry.path, dest })
                vim.notify('Copied ' .. filename)
              elseif entry.action == 'cut' then
                vim.fn.system({ 'mv', entry.path, dest })
                vim.fn.delete(clipboard_path)
                vim.notify('Moved ' .. filename)
              end
              require('neo-tree.sources.manager').refresh('filesystem')
            end
            if vim.fn.filereadable(dest) == 1 or vim.fn.isdirectory(dest) == 1 then
              vim.ui.input({ prompt = filename .. ' already exists. Overwrite? (y/n): ' }, function(input)
                if input and input:lower() == 'y' then
                  do_paste()
                else
                  vim.notify('Paste cancelled')
                end
              end)
            else
              do_paste()
            end
          end,
        },
      },
    })
  end,
}
