local McpClient = require("mcp_client")

-- Example showing how to use the client
local function runExample()
  local client = McpClient.new()

  -- Connect over stdio
  client:connectStdio()

  -- Initialize with the server
  local getResult = client:request("initialize", {
    server_name = "lua-client",
    server_version = "1.0.0",
    capabilities = {
      prompts = {},
      tools = {},
      resources = {},
    },
  })

  -- We can poll until we get a result
  local tries = 0
  while true do
    local result, err = getResult()
    if result or err then
      print("Initialize Response:", result and cjson.encode(result) or cjson.encode(err))
      break
    end
    tries = tries + 1
    if tries > 200 then
      print("No response, maybe server not connected or took too long.")
      break
    end
    -- sleep a bit
    os.execute("sleep 0.1")
  end

  -- Suppose we want to list prompts
  local listPrompts = client:request("prompts/list", {})
  tries = 0
  while true do
    local result, err = listPrompts()
    if result or err then
      if err then
        print("Error listing prompts:", cjson.encode(err))
      else
        print("Prompts available:", cjson.encode(result))
      end
      break
    end
    tries = tries + 1
    if tries > 200 then
      break
    end
    os.execute("sleep 0.1")
  end

  -- Example: send a notification
  client:notification("client/logMessage", {
    message = "Lua client says hello!",
  })

  -- Keep running to allow reading any server notifications or responses
  -- Press Ctrl+C to exit, or add a condition to break.
  -- This is just a demonstration loop
  while true do
    os.execute("sleep 1")
  end
end

runExample()
