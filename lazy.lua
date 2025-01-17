return {
  {
    'liljaylj/codestats.nvim',
    dependencies = {},
    event = { 'TextChanged', 'InsertEnter' },
    cmd = { 'CodeStatsXpSend', 'CodeStatsProfileUpdate' },
    opts = {},
  },
  { 'nvim-lua/plenary.nvim', lazy = true },
}
