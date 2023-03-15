# Codestats.nvim

Neovim plugin that counts your keypresses and saves statistics to [Code::Stats](https://codestats.net), a free stats tracking service for programmers.

This is port of the [official plugin](https://gitlab.com/code-stats/code-stats-vim) written in Lua. It don't use pythonx interface (it is not a remote-plugin), instead it spawns curl process as luv asynchronous job and therefore it loads faster and don't interfere with interface rendering.

# Installation

## Requirements

- Neovim
- Curl
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Setup

1) Get a Code::Stats account and copy your API key from the [Code::Stats machine page](https://codestats.net/my/machines).

2) Install and configure code-stats-nvim


```lua
-- Lazy.nvim
{
  'liljaylj/code-stats-nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('codestats').setup {
      username = '<your user name>',  -- needed to fetch profile data
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
- `:CodeStatsProfileUpdate` — manually pull profile data from [Code::Stats](https://codestats.net)

# Events

- `CodeStatsXpSent` — triggers when XP is succesfully sent to [Code::Stats](https://codestats.net)
- `CodeStatsProfileUpdated` — triggers when profile data successfully pulled from [Code::Stats](https://codestats.net)
