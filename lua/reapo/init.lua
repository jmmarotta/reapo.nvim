local M = {}

function M.setup(user_config)
  local config = require("reapo.config").init(user_config)

  -- Create user commands
  vim.api.nvim_create_user_command("ReapoChat", function()
    require("reapo.ui").open_chat_prompt(config)
  end, {})

  vim.api.nvim_create_user_command("ReapoChatHistory", function()
    require("reapo.ui").show_chat_history(config)
  end, {})
end

return M
