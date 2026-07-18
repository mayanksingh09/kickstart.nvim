return {
  'folke/snacks.nvim',
  opts = {
    gitbrowse = { enabled = true },
  },
  keys = {
    {
      '<leader>go',
      function()
        require('snacks').gitbrowse()
      end,
      mode = { 'n', 'v' },
      desc = '[G]it [O]pen line(s) on GitHub',
    },
  },
}
