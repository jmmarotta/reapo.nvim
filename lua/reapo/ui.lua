local M = {}
local http = require("reapo.adapters.anthropic")

-- Configuration
local config = {
  window = {
    title = " Reapo Chat ",
    border = "rounded",
    zindex = 45,
    blend = 10,
  },
  highlights = {
    user = "Comment",
    assistant = "Normal",
    border = "FloatBorder",
  },
}

-- Chat state management
local chat_history = {}
local current_win = nil
local current_buf = nil

-- Window management
local function create_float_win()
  -- Size calculation with padding
  local padding = 4
  local width = math.floor(math.min(vim.o.columns - padding, math.max(80, vim.o.columns * 0.7)))
  local height = math.floor(math.min(vim.o.lines - padding, math.max(20, vim.o.lines * 0.7)))

  -- Buffer creation with options
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "reapo")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- Position calculation
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Window creation
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.window.border,
    title = config.window.title,
    title_pos = "center",
    zindex = config.window.zindex,
  })

  -- Window options
  vim.wo[win].winblend = config.window.blend
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = true
  vim.wo[win].conceallevel = 2

  -- Store current window and buffer
  current_win = win
  current_buf = buf

  -- Set up window-local keymaps
  local function set_keymap(mode, lhs, rhs, opts)
    opts = vim.tbl_extend("force", { buffer = buf, silent = true }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  set_keymap("n", "q", function()
    M.close_chat()
  end, { desc = "Close chat" })
  set_keymap("n", "<CR>", function()
    M.open_chat_prompt({})
  end, { desc = "New message" })
  set_keymap("n", "<C-c>", function()
    M.clear_chat()
  end, { desc = "Clear chat" })

  return buf, win
end

-- Window resize handling
local function setup_window_autocmds()
  local group = vim.api.nvim_create_augroup("ReapoChat", { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if current_win and vim.api.nvim_win_is_valid(current_win) then
        local width = math.floor(math.min(vim.o.columns - 4, math.max(80, vim.o.columns * 0.7)))
        local height = math.floor(math.min(vim.o.lines - 4, math.max(20, vim.o.lines * 0.7)))
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        vim.api.nvim_win_set_config(current_win, {
          width = width,
          height = height,
          row = row,
          col = col,
        })
      end
    end,
  })
end

-- Format chat messages with proper highlighting
local function format_message(msg)
  local role_icon = msg.role == "user" and "󰭹" or "󰚩"
  local role_hl = msg.role == "user" and config.highlights.user or config.highlights.assistant
  return {
    ("%s %s"):format(role_icon, msg.content),
    role_hl,
  }
end

-- Update chat window content
local function update_chat_content()
  if not current_buf or not vim.api.nvim_buf_is_valid(current_buf) then
    return
  end

  vim.api.nvim_buf_set_option(current_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, {})

  -- Add messages with highlighting
  local ns_id = vim.api.nvim_create_namespace("ReapoChat")
  for i, msg in ipairs(chat_history) do
    local formatted, hl_group = format_message(msg)
    local line_num = i - 1
    vim.api.nvim_buf_set_lines(current_buf, line_num, line_num + 1, false, { formatted })
    vim.api.nvim_buf_add_highlight(current_buf, ns_id, hl_group, line_num, 0, -1)
  end

  vim.api.nvim_buf_set_option(current_buf, "modifiable", false)
end

-- Public API
function M.open_chat_prompt(opts)
  vim.ui.input({ prompt = "Your question: " }, function(input)
    if not input or #input == 0 then
      return
    end

    table.insert(chat_history, { role = "user", content = input })
    update_chat_content()

    http.send_chat_request(input, function(err, response)
      vim.schedule(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        else
          table.insert(chat_history, { role = "assistant", content = response })
          M.show_chat_history(opts)
        end
      end)
    end)
  end)
end

function M.show_chat_history(opts)
  if not current_win or not vim.api.nvim_win_is_valid(current_win) then
    create_float_win()
    setup_window_autocmds()
  end

  update_chat_content()
end

function M.close_chat()
  if current_win and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_win_close(current_win, true)
  end
  current_win = nil
  current_buf = nil
end

function M.clear_chat()
  chat_history = {}
  update_chat_content()
end

return M
