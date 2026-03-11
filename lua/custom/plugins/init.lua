-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'petertriho/nvim-scrollbar',
    dependencies = {
      'lewis6991/gitsigns.nvim',
    },
    config = function()
      require('scrollbar').setup()
      require('scrollbar.handlers.gitsigns').setup()
    end,
  },
}
