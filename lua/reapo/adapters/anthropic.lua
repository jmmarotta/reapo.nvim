local M = {}
local config = require("reapo.config")
local curl = require("plenary.curl")

function M.send_chat_request(prompt, callback, on_stream)
  local current_config = config.get_config()
  local api_key = current_config.api_key
  local endpoint = "https://api.anthropic.com/v1/messages"

  local data = {
    model = current_config.model,
    messages = {
      { role = "user", content = prompt },
    },
    max_tokens = current_config.max_tokens,
    stream = true,
  }

  print("Sending to anthropic...")

  curl.post(endpoint, {
    headers = {
      content_type = "application/json",
      ["x-api-key"] = api_key,
      ["anthropic-version"] = "2023-06-01",
    },
    body = vim.fn.json_encode(data),
    stream = function(err, data)
      if err then
        print("Stream error:", vim.inspect(err))
        if callback then
          callback(err, nil)
        end
        return
      end

      print("Stream data received:", vim.inspect(data))

      -- Handle SSE events
      local event_type, json_str = data:match("event: (.-)%s+data: (.+)")
      if not event_type or not json_str then
        return
      end

      local ok, parsed = pcall(vim.fn.json_decode, json_str)
      if not ok then
        print("Failed to parse JSON:", json_str)
        return
      end

      if event_type == "message_start" then
        print("Message started")
      elseif event_type == "content_block_start" then
        print("Content block started:", vim.inspect(parsed))
      elseif event_type == "content_block_delta" then
        if parsed.delta and parsed.delta.type == "text_delta" then
          local delta = parsed.delta.text
          if on_stream then
            on_stream(nil, delta)
          end
        end
      elseif event_type == "message_stop" then
        print("Message completed")
        if callback then
          callback(nil, "Message completed")
        end
      end
    end,
    callback = function(response)
      if response.status ~= 200 then
        print("Request failed:", vim.inspect(response))
        if callback then
          callback("Request failed with status: " .. response.status, nil)
        end
      end
    end,
  })
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

return M
