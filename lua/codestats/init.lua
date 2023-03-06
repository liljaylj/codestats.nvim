local VERSION = '0.0.1'

local curl = require 'plenary.curl'
local filetype_map = require 'codestats.filetypes'

local CodeStats = {
  setup = function(self, config)
    self.xp_dict = {}
    self.pulse_url = (config.base_url or 'https://codestats.net') .. '/api/my/pulses'
    self.api_key = config.api_key
    local group = vim.api.nvim_create_augroup('codestats', { clear = true })
    vim.api.nvim_create_autocmd({ 'InsertCharPre', 'TextChanged' }, {
      group = group,
      pattern = '*',
      callback = function(data)
        if not vim.b.current_xp then
          vim.b.current_xp = 0
        end
        vim.b.current_xp = vim.b.current_xp + 1
      end,
    })
    vim.api.nvim_create_autocmd({ 'BufWrite', 'BufLeave', 'InsertLeave' }, {
      group = group,
      pattern = '*',
      callback = function()
        if vim.b.current_xp then
          self:add_xp(vim.api.nvim_buf_get_option(0, 'filetype'), vim.b.current_xp)
        end
        vim.b.current_xp = 0
      end,
    })
    if config.send_on_exit == nil or config.send_on_exit then  -- by default send xp on nvim exit
      vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
        group = group,
        pattern = '*',
        callback = function()
          self:send_xp()
        end,
      })
    end
    if config.send_on_timer == nil or config.send_on_timer then  -- by default send xp on timer
      local interval = config.timer_interval or 10000 -- every 10 seconds
      vim.loop.new_timer():start(
        interval,
        interval,
        vim.schedule_wrap(function()
          self:send_xp()
        end)
      )
    end
  end,

  add_xp = function(self, filetype, xp)
    if xp == 0 then
      return
    end

    -- get the language type based on what vim passed to us
    local language_type = filetype_map[filetype] or filetype

    local count = self.xp_dict[language_type] or 0
    self.xp_dict[language_type] = count + xp
  end,

  send_xp = function(self)
    local xp_list = {}
    for ft, xp in pairs(self.xp_dict) do
      table.insert(xp_list, {
        language = ft,
        xp = xp,
      })
    end
    self.xp_dict = {}

    curl.post {
      url = self.pulse_url,
      body = vim.json.encode {
        coded_at = os.date '%FT%T%z',
        xps = xp_list,
      },
      headers = {
        ['Content-Type'] = 'application/json',
        ['User-Agent'] = 'code-stats-nvim/' .. VERSION,
        ['X-API-Token'] = self.api_key,
        ['Accept'] = '*/*',
      },
      raw = { '-m', '5' },
      callback = function() end, -- execute curl asynchronously
    }
  end,
}

return {
  setup = function(config)
    CodeStats:setup(config)
  end,
  get_xp = function()
    return CodeStats.xp_dict
  end,
}
