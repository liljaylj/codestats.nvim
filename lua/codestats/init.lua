local VERSION = '0.0.1'

local LEVEL_FACTOR = 0.025

local curl = require 'plenary.curl'
local filetype_map = require 'codestats.filetypes'

local calculate_level = function(xp)
  return math.floor(LEVEL_FACTOR * math.sqrt(xp))
end

local filetype_to_language = function(ft)
  return filetype_map[ft] or ft
end

local CodeStats = {
  config = {
    base_url = 'https://codestats.net', -- codestats.net base url
    send_on_exit = true, -- send xp on nvim exit
    send_on_timer = true, -- send xp on timer
    timer_interval = 60000, -- timer interval in milliseconds
    curl_timeout = 5, -- curl request timeout in seconds
  },

  current_xp_dict = {},

  profile = {},

  setup = function(self, config)
    -- init

    vim.validate {
      base_url = { config.base_url, 's', true },
      send_on_exit = { config.send_on_exit, 'b', true },
      send_on_timer = { config.send_on_timer, 'b', true },
      timer_interval = { config.timer_interval, 'n', true },
      curl_timeout = { config.curl_timeout, 'n', true },
      api_key = { config.api_key, 's' },
    }
    self.config = vim.tbl_deep_extend('force', self.config, config)
    -- minimum timer timeout
    if self.config.timer_interval < 1000 then
      self.config.timer_interval = 1000
    end

    if self.config.username then
      self.config.profile_url = (self.config.base_url or 'https://codestats.net')
        .. '/api/users/'
        .. self.config.username
    end
    self.config.pulse_url = (self.config.base_url or 'https://codestats.net') .. '/api/my/pulses'

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
    if self.config.send_on_exit == nil or self.config.send_on_exit then -- by default send xp on nvim exit
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
    if self.config.send_on_timer == nil or self.config.send_on_timer then -- by default send xp on timer
      vim.loop.new_timer():start(
        self.config.timer_interval,
        self.config.timer_interval,
        vim.schedule_wrap(function()
          self:send_xp()
        end)
      )
    end

    -- user commands
    vim.api.nvim_create_user_command('CodeStatsXpSend', function()
      self:send_xp()
    end, { desc = 'Explicitly send XP to Code::Stats' })

    vim.api.nvim_create_user_command('CodeStatsProfileUpdate', function()
      self:update_profile()
    end, { desc = 'Explicitly pull profile data from Code::Stats' })

    -- initial profile data update
    self:update_profile()
  end,

  add_xp = function(self, filetype, xp)
    if xp == 0 then
      return
    end

    -- get the language type based on what vim passed to us
    local language_type = filetype_to_language(filetype)

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
      url = self.config.pulse_url,
      body = vim.json.encode {
        coded_at = os.date '%FT%T%z',
        xps = xp_list,
      },
      headers = {
        ['Content-Type'] = 'application/json',
        ['User-Agent'] = 'code-stats-nvim/' .. VERSION,
        ['X-API-Token'] = self.config.api_key,
        ['Accept'] = '*/*',
      },
      raw = { '-m', self.config.curl_timeout },
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
  end,

  update_profile = function(self)
    if not self.config.profile_url then
      return
    end
    curl.get {
      url = self.config.profile_url,
      headers = {
        ['Content-Type'] = 'application/json',
        ['User-Agent'] = 'code-stats-nvim/' .. VERSION,
        ['X-API-Token'] = self.config.api_key,
        ['Accept'] = '*/*',
      },
      raw = { '-m', self.config.curl_timeout },
      callback = function(result)
        local json = vim.json.decode(result.body)
        pcall(vim.validate, {
          user = { json.user, 's' },
          total_xp = { json.total_xp, 'n' },
          new_xp = { json.new_xp, 'n' },
          languages = { json.languages, 'table' },
        })
        self.profile.user = json.user
        self.profile.total_xp = json.total_xp
        self.profile.new_xp = json.new_xp
        self.profile.languages = json.languages
        self.profile.level = calculate_level(json.total_xp)
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
    return CodeStats.profile.total_xp or 0
  else
    if type(CodeStats.profile.languages) ~= 'table' then
      return 0
    end
    local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
    local language_type = filetype_to_language(filetype)
    local xp = (CodeStats.profile.languages[filetype] and CodeStats.profile.languages[filetype].xps) or 0
    return xp + ((CodeStats.profile.languages[language_type] and CodeStats.profile.languages[language_type].xps) or 0)
  end
end

local get_level = function(buf)
  if not buf then
    return CodeStats.profile.level or 0
  else
    return calculate_level(get_xp(buf))
  end
end

return {
  setup = function(config)
    CodeStats:setup(config)
  end,
  calculate_level = calculate_level,
  filetype_to_language = filetype_to_language,
  get_xp = get_xp,
  get_level = get_level,
}
