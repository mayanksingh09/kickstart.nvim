return {
  'sindrets/diffview.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
  keys = {
    {
      '<leader>gd',
      function()
        local lib = require 'diffview.lib'
        if lib.get_current_view() then
          vim.cmd 'DiffviewClose'
          return
        end

        -- Run git in the buffer's repo, so this agrees with the repo Diffview opens.
        local dir = vim.fn.expand '%:p:h'
        if dir == '' or vim.fn.isdirectory(dir) == 0 then
          dir = vim.fn.getcwd()
        end

        -- Local-only git calls: no network, no credential prompt, no hang.
        local function git(args)
          local cmd = { 'git', '-C', dir }
          vim.list_extend(cmd, args)
          local ok, proc = pcall(function()
            return vim.system(cmd, { text = true, env = { GIT_TERMINAL_PROMPT = '0' } }):wait(2000)
          end)
          if not ok or proc.code ~= 0 then
            return nil
          end
          local out = vim.trim(proc.stdout or '')
          return out ~= '' and out or nil
        end

        local toplevel = git { 'rev-parse', '--show-toplevel' }
        if not toplevel then
          vim.notify('Diffview: not inside a git repository', vim.log.levels.WARN)
          return
        end

        local cache = vim.g.diffview_default_base or {}
        local base = cache[toplevel]

        if not base then
          -- Prefer `upstream` over `origin` so fork workflows diff against the real PR target.
          local remotes = vim.split(git { 'remote' } or '', '\n', { trimempty = true })
          table.sort(remotes, function(a, b)
            local rank = { upstream = 1, origin = 2 }
            return (rank[a] or 3) < (rank[b] or 3)
          end)

          -- 1. The remote's HEAD symref, when the clone actually has one.
          for _, remote in ipairs(remotes) do
            base = git { 'symbolic-ref', '--short', 'refs/remotes/' .. remote .. '/HEAD' }
            if base then
              break
            end
          end

          -- 2. Otherwise probe the usual suspects, remote-tracking first.
          if not base then
            local candidates = {}
            for _, remote in ipairs(remotes) do
              vim.list_extend(candidates, { remote .. '/main', remote .. '/master', remote .. '/develop' })
            end
            vim.list_extend(candidates, { 'main', 'master' })
            for _, c in ipairs(candidates) do
              if git { 'rev-parse', '--verify', '--quiet', c .. '^{commit}' } then
                base = c
                break
              end
            end
          end

          if not base then
            vim.notify('Diffview: could not detect a default branch.\nTry: git remote set-head origin --auto', vim.log.levels.ERROR)
            return
          end

          cache[toplevel] = base
          vim.g.diffview_default_base = cache
        end

        -- On the default branch a merge-base diff is empty; show the working tree instead.
        local current = git { 'rev-parse', '--abbrev-ref', 'HEAD' }
        if current == base or (base:find '/' and current == base:match '.*/(.*)') then
          vim.notify('Diffview: on default branch (' .. base .. '); showing working-tree diff', vim.log.levels.INFO)
          vim.cmd 'DiffviewOpen'
          return
        end

        vim.cmd('DiffviewOpen ' .. base .. '...HEAD')
      end,
      desc = '[G]it [D]iff review vs default branch',
    },
    {
      '<leader>gh',
      '<cmd>DiffviewFileHistory %<cr>',
      desc = '[G]it file [H]istory',
    },
  },
}
