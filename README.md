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
  event = { 'TextChanged', 'InsertEnter' },
  cmd = { 'CodeStatsXpSend', 'CodeStatsProfileUpdate' },
  config = function()
    require('codestats').setup {
      username = '<your user name>',  -- needed to fetch profile data
      base_url = 'https://codestats.net',  -- codestats.net base url
      api_key = '<your API key>',
      send_on_exit = true,  -- send xp on nvim exit
      send_on_timer = true,  -- send xp on timer
      timer_interval = 10000,  -- timer interval in milliseconds
      curl_timeout = 5,  -- curl request timeout in seconds
    }
  end,
}
```

# Commands

- `:CodeStatsXpSend` — manually send XP to [Code::Stats](https://codestats.net)
- `:CodeStatsProfileUpdate` — manually pull profile data from [Code::Stats](https://codestats.net)

# Events

- `CodeStatsXpSent` — triggers when XP is succesfully sent to [Code::Stats](https://codestats.net)
- `CodeStatsProfileUpdated` — triggers when profile data successfully pulled from [Code::Stats](https://codestats.net)

# API

```lua
local codestats = require 'codestats'

codestats.get_xp()  -- get total xp for profile
codestats.get_xp(<buffer id>)  -- get xp for language of specified buffer
codestats.get_xp(0)  -- get xp for language of current buffer

codestats.get_level()  -- get level for profile
codestats.get_level(<buffer id>)  -- get level for language of specified buffer
codestats.get_level(0)  -- get level for language of current buffer

-- utils
codestats.calculate_level(<xp>)  -- calculate level for given XP value
codestats.filetype_to_language(<ft>)  -- map language for given filetype
```

## Tips

### Neovim native statusline

```lua
vim.opt.statusline:append [[%{luaeval("require'codestats'.get_xp()")}]]  -- total xp
vim.opt.statusline:append [[%{luaeval("require'codestats'.get_xp(0)")}]]  -- current buf language xp
vim.opt.statusline:append [[%{luaeval("require'codestats'.get_level()")}]]  -- total level
vim.opt.statusline:append [[%{luaeval("require'codestats'.get_level(0)")}]]  -- current buf language level
```

### Lualine

```lua
local xp = function()
  return codestats.get_xp(0)  -- current buf language xp
end

require('lualine').setup {
  sections = { 
    lualine_x = {
      'filetype',
      {
        xp,
        fmt = function(s)
          return s and (s ~= '0' or nil) and s .. 'xp'
        end,
      },
    },
  },
}
```
