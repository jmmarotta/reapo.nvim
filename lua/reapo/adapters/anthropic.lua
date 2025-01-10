local M = {}
local config_mod = require("reapo")
local Job = require("plenary.job")

function M.send_chat_request(prompt, callback, on_stream)
  local config = config_mod.get_config()
  local api_key = config.api_key
  local endpoint = "https://api.anthropic.com/v1/messages"

  local data = {
    model = "claude-3-sonnet-20240229", -- or config.model
    messages = {
      { role = "user", content = prompt },
    },
    max_tokens = config.max_tokens,
    temperature = config.temperature,
    stream = true, -- Enable streaming
  }

  local buffer = "" -- Buffer for incomplete JSON chunks

  Job:new({
    command = "curl",
    args = {
      "-N", -- Disable buffering
      "-X",
      "POST",
      endpoint,
      "-H",
      "Content-Type: application/json",
      "-H",
      "x-api-key: " .. api_key,
      "-H",
      "anthropic-version: 2023-06-01",
      "-H",
      "Accept: text/event-stream", -- Required for streaming
      "-d",
      vim.json_encode(data),
    },
    on_stdout = function(_, data)
      if not data or data == "" then
        return
      end

      -- Handle SSE data
      if vim.startswith(data, "data: ") then
        local json_str = string.sub(data, 7) -- Remove "data: " prefix

        -- Handle stream end
        if json_str == "[DONE]" then
          if callback then
            callback(nil, buffer)
          end
          return
        end

        local ok, parsed = pcall(vim.json_decode, json_str)
        if ok and parsed then
          if parsed.type == "message_delta" then
            local delta = parsed.delta.text or ""
            buffer = buffer .. delta

            if on_stream then
              on_stream(nil, delta)
            end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if callback then
        callback("Stream error: " .. (data or "Unknown error"), nil)
      end
    end,
    on_exit = function(_, return_val)
      if return_val ~= 0 and callback then
        callback("HTTP request failed with code: " .. return_val, nil)
      end
    end,
  }):start()
end

-- Helper function to create a displayer that shows streaming output in a buffer
function M.create_stream_displayer(bufnr)
  local namespace = vim.api.nvim_create_namespace("claude_stream")
  local line_nr = 0

  return function(err, chunk)
    if err then
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { err })
      end)
      return
    end

    vim.schedule(function()
      local lines = vim.split(chunk, "\n", { plain = true })
      for _, line in ipairs(lines) do
        if line_nr == 0 then
          vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr + 1, false, { line })
        else
          local last_line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
          if #last_line == 0 then
            vim.api.nvim_buf_set_lines(bufnr, line_nr - 1, line_nr, false, { line })
          else
            vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr + 1, false, { line })
            line_nr = line_nr + 1
          end
        end
      end
    end)
  end
end

-- Example usage:
-- local bufnr = vim.api.nvim_create_buf(false, true)
-- local displayer = M.create_stream_displayer(bufnr)
-- M.send_chat_request("Hello!", nil, displayer)

return M
