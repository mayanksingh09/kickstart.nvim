return {
  'sudo-tee/opencode.nvim',
  -- Lazy-loaded on its own command and keymap prefix. Loading it eagerly runs
  -- setup(), which probes for the `opencode` binary and raises an error
  -- notification at startup on machines where the CLI is not installed.
  cmd = 'Opencode',
  keys = {
    -- The plugin registers every editor mapping under this prefix itself; the
    -- stub below only exists to trigger the load, which then re-feeds the keys.
    { '<leader>o', mode = { 'n', 'x', 'v' }, desc = 'Opencode' },
  },
  config = function()
    require('opencode').setup {}
  end,
  dependencies = {
    {
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        anti_conceal = { enabled = false },
        file_types = { 'markdown', 'opencode_output' },
      },
      ft = { 'markdown', 'Avante', 'copilot-chat', 'opencode_output' },
    },
    'saghen/blink.cmp',
    'folke/snacks.nvim',
  },
}
