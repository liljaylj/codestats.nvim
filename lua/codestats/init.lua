local VERSION = '0.0.1'

local LEVEL_FACTOR = 0.025

local curl = require 'plenary.curl'
local filetype_map = require 'codestats.filetypes'

local calculate_level = function(xp)
  return math.floor(LEVEL_FACTOR * math.sqrt(xp))
end

local CodeStats = {
  setup = function(self, config)
    -- init
    self.current_xp_dict = {}
    self.username = config.username
    if self.username then
      self.profile_url = (config.base_url or 'https://codestats.net') .. '/api/users/' .. self.username
    end
    self.pulse_url = (config.base_url or 'https://codestats.net') .. '/api/my/pulses'
    self.curl_timeout = config.curl_timeout or 5
    self.api_key = config.api_key

    -- autocmds
    local group = vim.api.nvim_create_augroup('codestats-plugin-autocommands', { clear = true })

    vim.api.nvim_create_autocmd({ 'InsertCharPre', 'TextChanged' }, {
      group = group,
      pattern = '*',
      callback = function()
        if not vim.b.current_xp then
          vim.b.current_xp = 0
        end
        vim.b.current_xp = vim.b.current_xp + 1
      end,
    })

    vim.api.nvim_create_autocmd({ 'CursorHold', 'BufLeave' }, {
      group = group,
      pattern = '*',
      callback = function()
        if vim.b.current_xp then
          self:add_xp(vim.api.nvim_buf_get_option(0, 'filetype'), vim.b.current_xp)
        end
        vim.b.current_xp = 0
      end,
    })

    -- send xp on vim leave
    if config.send_on_exit == nil or config.send_on_exit then -- by default send xp on nvim exit
      vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
        group = group,
        pattern = '*',
        callback = function()
          if vim.b.current_xp then
            self:add_xp(vim.api.nvim_buf_get_option(0, 'filetype'), vim.b.current_xp)
          end
          self:send_xp()
        end,
      })
    end

    -- send xp on timer
    if config.send_on_timer == nil or config.send_on_timer then -- by default send xp on timer
      local interval = config.timer_interval or 60000 -- every 60 seconds
      vim.loop.new_timer():start(
        interval,
        interval,
        vim.schedule_wrap(function()
          self:send_xp()
        end)
      )
    end

    -- user commands
    vim.api.nvim_create_user_command('CodeStatsSend', function()
      self:send_xp()
    end, { desc = 'Explicitly send XP to Code::Stats' })

    -- update profile data
    self:update_profile()
  end,

  add_xp = function(self, filetype, xp)
    if xp == 0 then
      return
    end

    -- get the language type based on what vim passed to us
    local language_type = filetype_map[filetype] or filetype

    local count = self.current_xp_dict[language_type] or 0
    self.current_xp_dict[language_type] = count + xp
  end,

  send_xp = function(self)
    local xp_list = {}
    for ft, xp in pairs(self.current_xp_dict) do
      table.insert(xp_list, {
        language = ft,
        xp = xp,
      })
    end

    if #xp_list == 0 then
      return
    end

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
      raw = { '-m', self.curl_timeout },
      callback = function()
        self.current_xp_dict = {}
        vim.schedule(function()
          vim.api.nvim_exec_autocmds('User', { pattern = 'CodeStatsXpSent' })
        end)
        self:update_profile()
      end,
      on_error = function(err)
        -- TODO: handle error
      end,
    }

    -- update profile data
  end,

  update_profile = function(self)
    if not self.profile_url then
      return
    end
    curl.get {
      url = self.profile_url,
      headers = {
        ['Content-Type'] = 'application/json',
        ['User-Agent'] = 'code-stats-nvim/' .. VERSION,
        ['X-API-Token'] = self.api_key,
        ['Accept'] = '*/*',
      },
      raw = { '-m', self.curl_timeout },
      callback = function(result)
        local json = vim.json.decode(result.body)
        self.total_xp = json.total_xp
        self.new_xp = json.new_xp
        self.total_xp_dict = json.languages
        self.level = calculate_level(json.total_xp)
        vim.schedule(function()
          vim.api.nvim_exec_autocmds('User', { pattern = 'CodeStatsProfileUpdated', data = self })
        end)
      end,
      on_error = function(err)
        -- TODO: handle error
      end,
    }
  end,
}

local get_xp = function(buf)
  if not buf then
    return CodeStats.total_xp or 0
  else
    if type(CodeStats.total_xp_dict) ~= 'table' then
      return 0
    end
    local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
    local language_type = filetype_map[filetype] or filetype
    local xp = (CodeStats.total_xp_dict[filetype] and CodeStats.total_xp_dict[filetype].xps) or 0
    return xp + ((CodeStats.total_xp_dict[language_type] and CodeStats.total_xp_dict[language_type].xps) or 0)
  end
end

local get_level = function(buf)
  if not buf then
    return CodeStats.level or 0
  else
    return calculate_level(get_xp(buf))
  end
end

return {
  setup = function(config)
    CodeStats:setup(config)
  end,
  get_xp = get_xp,
  get_level = get_level,
}
