# Codestats.nvim

## [Code::Stats](https://codestats.net) lua plugin for Neovim

Neovim plugin that counts your keypresses and saves statistics to [Code::Stats](https://codestats.net), a free stats tracking service for programmers.

This is port of the [official plugin](https://gitlab.com/code-stats/code-stats-vim) written in Lua. It don't use pythonx interface (it is not a remote-plugin), instead it spawns curl process as luv asynchronous job and therefore it loads faster and don't interfere with interface rendering.

# Requirements

- Neovim
- Curl
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

# Installation

1) Get a Code::Stats account and copy your API key from the [Code::Stats machine page](https://codestats.net/my/machines).

2) Install and configure code-stats-nvim


```lua
-- Lazy.nvim
{
  'liljaylj/code-stats-nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('codestats').setup {
      base_url = 'https://codestats.net',  -- codestats.net base url
      api_key = '<your API key>',
      send_on_exit = true,  -- send xp on nvim exit
      send_on_timer = true,  -- send xp on timer
      timer_interval = 10000,  -- timer interval in ms
    }
  end,
}
```

# Commands

- `:CodeStatsSend` — manually send XP to [Code::Stats](https://codestats.net)
