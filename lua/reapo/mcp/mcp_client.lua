local cjson = require("cjson.safe")

local McpClient = {}
McpClient.__index = McpClient

-- Creates a new MCP Client instance
function McpClient.new()
  local self = setmetatable({}, McpClient)
  self.idCounter = 0
  self.pendingRequests = {}
  self.serverCapabilities = {}
  return self
end

-- Generates a unique ID for JSON-RPC requests
function McpClient:generateId()
  self.idCounter = self.idCounter + 1
  return self.idCounter
end

-- Connect using stdio (read from stdin, write to stdout)
-- In a real application, you may want to connect to other transports (WebSocket, TCP, HTTP, etc.)
function McpClient:connectStdio()
  -- For stdio-based communication, we read lines in a loop in a separate coroutine or thread
  self.running = true

  -- Start a coroutine that reads from stdin
  local co = coroutine.create(function()
    while self.running do
      local line = io.read("*line")
      if not line then
        -- End of file or stream closed
        self.running = false
        break
      end

      local success, msg = self:handleMessage(line)
      if not success then
        -- Optionally log or handle parsing errors
      end
    end
  end)

  coroutine.resume(co)
end

-- Stop the client
function McpClient:stop()
  self.running = false
end

-- Sends a Lua table as a JSON-RPC message to stdout
function McpClient:send(messageTable)
  local jsonStr = cjson.encode(messageTable)
  io.write(jsonStr .. "\n")
  io.flush()
end

-- Send an MCP request (returns a promise-like function that can be polled for a result)
function McpClient:request(method, params)
  local reqId = self:generateId()
  local requestObj = {
    jsonrpc = "2.0",
    id = reqId,
    method = method,
    params = params,
  }

  self:send(requestObj)

  -- Store a placeholder where we'll capture the response
  self.pendingRequests[reqId] = {
    done = false,
    result = nil,
    error = nil,
  }

  -- Return a function that can be polled until the response is ready
  -- or that can be used with a coroutine-based approach
  return function()
    local info = self.pendingRequests[reqId]
    if info.done then
      return info.result, info.error
    else
      return nil, nil -- Not ready yet
    end
  end
end

-- Send a notification (no response expected)
function McpClient:notification(method, params)
  local messageObj = {
    jsonrpc = "2.0",
    method = method,
    params = params,
  }
  self:send(messageObj)
end

-- Called internally to handle incoming JSON lines from the server
function McpClient:handleMessage(raw)
  local decoded, parseErr = cjson.decode(raw)
  if not decoded then
    return false, parseErr
  end

  -- JSON-RPC can be a Request, Response, or Notification
  if decoded.method and decoded.id then
    -- This might be a request from server (some servers can call client methods)
    -- For a minimal example, let's just reply with an error or ignore
    self:handleServerRequest(decoded)
  elseif decoded.method and not decoded.id then
    -- A notification from the server
    self:handleServerNotification(decoded)
  elseif decoded.id then
    -- A response to a client request
    self:handleServerResponse(decoded)
  end

  return true, nil
end

-- Handle server-initiated requests (rare for standard usage)
function McpClient:handleServerRequest(req)
  -- For example, automatically return MethodNotFound
  local response = {
    jsonrpc = "2.0",
    id = req.id,
    error = {
      code = -32601,
      message = "Method not found",
    },
  }
  self:send(response)
end

-- Handle notifications from the server
function McpClient:handleServerNotification(notification)
  local method = notification.method
  local params = notification.params or {}

  -- Example: if server sends "notifications/tools/list_changed",
  -- we can refresh the tool list, etc.
  -- For now, we just print
  print("Server Notification:", method, cjson.encode(params))
end

-- Handle responses to our requests
function McpClient:handleServerResponse(resp)
  local reqId = resp.id
  if not reqId then
    return
  end

  local info = self.pendingRequests[reqId]
  if not info then
    -- No matching request found
    return
  end

  if resp.error then
    info.error = resp.error
    info.done = true
  else
    info.result = resp.result
    info.done = true
  end
end

return McpClient
