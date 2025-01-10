local M = {}

-- Default configuration
M.defaults = {
  endpoint = "",
  model = "claude-3-5-sonnet-20241022",
  window_style = "float",
  max_tokens = 1000000,
  temperature = 0.7,
  debug = false,
}

-- Function to get API key from environment
local function get_api_key()
  local api_key = os.getenv("ANTHROPIC_API_KEY")
  if not api_key then
    vim.notify("ANTHROPIC_API_KEY environment variable not set", vim.log.levels.ERROR)
    return nil
  end
  return api_key
end

-- Initialize config with environment variables
function M.init(user_config)
  local config = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  config.api_key = get_api_key()
  return config
end

return M
