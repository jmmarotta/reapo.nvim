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
    input_border = "FloatBorder",
  },
  input = {
    height = 5,
    border = "rounded",
    prompt = "  ", -- Add a small indent for aesthetics
  },
}

-- Chat state management
local chat_history = {}
local current_win = nil
local current_buf = nil
local input_win = nil
local input_buf = nil

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

local function setup_window_autocmds()
  local group = vim.api.nvim_create_augroup("ReapoChat", { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not current_win or not vim.api.nvim_win_is_valid(current_win) then
        return
      end

      local width = math.floor(math.min(vim.o.columns - 4, math.max(80, vim.o.columns * 0.7)))
      local height = math.floor(math.min(vim.o.lines - 4 - config.input.height, math.max(20, vim.o.lines * 0.7)))
      local row = math.floor((vim.o.lines - height - config.input.height - 4) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      -- Resize main window
      vim.api.nvim_win_set_config(current_win, {
        width = width,
        height = height,
        row = row,
        col = col,
      })

      -- Resize and reposition input window
      if input_win and vim.api.nvim_win_is_valid(input_win) then
        vim.api.nvim_win_set_config(input_win, {
          width = width,
          height = config.input.height,
          row = row + height + 1,
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

local function update_chat_content()
  if not current_buf or not vim.api.nvim_buf_is_valid(current_buf) then
    return
  end

  vim.api.nvim_buf_set_option(current_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, {})

  local ns_id = vim.api.nvim_create_namespace("ReapoChat")
  for i, msg in ipairs(chat_history) do
    local role_icon = msg.role == "user" and "󰭹" or "󰚩"
    local role_hl = msg.role == "user" and config.highlights.user or config.highlights.assistant
    local formatted = ("%s %s"):format(role_icon, msg.content)

    local line_num = i - 1
    vim.api.nvim_buf_set_lines(current_buf, line_num, line_num + 1, false, { formatted })
    vim.api.nvim_buf_add_highlight(current_buf, ns_id, role_hl, line_num, 0, -1)
  end

  vim.api.nvim_buf_set_option(current_buf, "modifiable", false)

  -- Scroll to bottom
  vim.api.nvim_win_set_cursor(current_win, { vim.api.nvim_buf_line_count(current_buf), 0 })
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

local function create_chat_win()
  local padding = 4
  local width = math.floor(math.min(vim.o.columns - padding, math.max(80, vim.o.columns * 0.7)))
  local height = math.floor(math.min(vim.o.lines - padding - config.input.height, math.max(20, vim.o.lines * 0.7)))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "reapo")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  local row = math.floor((vim.o.lines - height - config.input.height - padding) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

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

  vim.wo[win].winblend = config.window.blend
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = true
  vim.wo[win].conceallevel = 2

  return buf, win
end

local function create_input_win()
  local main_width = vim.api.nvim_win_get_width(current_win)
  local main_row = vim.api.nvim_win_get_position(current_win)[1]
  local main_col = vim.api.nvim_win_get_position(current_win)[2]
  local main_height = vim.api.nvim_win_get_height(current_win)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "reapo-input")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = main_width,
    height = config.input.height,
    row = main_row + main_height + 1,
    col = main_col,
    style = "minimal",
    border = config.input.border,
    zindex = config.window.zindex,
  })

  vim.wo[win].winblend = config.window.blend
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].wrap = true

  -- Set up input buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { config.input.prompt })

  return buf, win
end

-- Set up keymaps for the input buffer
local function setup_input_keymaps()
  local function set_keymap(mode, lhs, rhs, opts)
    opts = vim.tbl_extend("force", { buffer = input_buf, silent = true }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  -- Submit message with shift+enter
  set_keymap("n", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    local content = table.concat(lines, "\n"):gsub("^%s*", "")

    if #content > 0 then
      -- Add user message to history
      table.insert(chat_history, { role = "user", content = content })
      update_chat_content()

      -- Clear input buffer
      vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { config.input.prompt })
      vim.api.nvim_win_set_cursor(input_win, { 1, #config.input.prompt })

      -- Send request to API
      http.send_chat_request(content, function(err, response)
        vim.schedule(function()
          if err then
            vim.notify(err, vim.log.levels.ERROR)
          else
            table.insert(chat_history, { role = "assistant", content = response })
            update_chat_content()
          end
        end)
      end)
    end
  end, { desc = "Send message" })

  -- Close chat on Escape in normal mode
  set_keymap("n", "<Esc>", function()
    M.close_chat()
  end, { desc = "Close chat" })
end

function M.open_chat(opts)
  -- Create main chat window
  current_buf, current_win = create_chat_win()

  -- Create input window
  input_buf, input_win = create_input_win()

  -- Set up window management
  setup_window_autocmds()
  setup_input_keymaps()

  -- Update content and focus input
  update_chat_content()
  vim.api.nvim_set_current_win(input_win)
  vim.api.nvim_win_set_cursor(input_win, { 1, #config.input.prompt })
  vim.cmd("startinsert!")
end

function M.close_chat()
  if current_win and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_win_close(current_win, true)
  end
  if input_win and vim.api.nvim_win_is_valid(input_win) then
    vim.api.nvim_win_close(input_win, true)
  end
  current_win = nil
  current_buf = nil
  input_win = nil
  input_buf = nil
end

function M.clear_chat()
  chat_history = {}
  update_chat_content()
end

return M
