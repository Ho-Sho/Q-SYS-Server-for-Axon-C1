-- ============================================================================
-- QDS Server for Axon C1
-- ============================================================================
-- Server configuration
server = TcpSocketServer.New()
sockets = {}
-- Current control values
syncVals = {}
-- Control ranges for position calculation
ranges = { min = -100, max = 20 } -- default gain value
-- Control name tables
local ctrlNames = {}
local namectrlNames = {}
local nonCtrl = {'Port','Status','TriggerLED','Named Controls Name','To Controls','Msg'}

-- ============================================================================
-- Helper function to display messages
-- ============================================================================
function ShowMsg(msg)
  Controls.Msg.String = msg
  print(msg) -- Keep console log for debugging
end

-- ============================================================================
-- Helper Functions for Control Name Management
-- ============================================================================
-- Helper function to check if table contains element
function checkContains(table, element)
  for _, v in ipairs(table) do
    if v == element then return true end
  end
  return false
end

-- Get control names from Controls table
function GetControlNames()
  ctrlNames = {}
  for name, control in pairs(Controls) do
    for _, nonctrl in ipairs(nonCtrl) do
      if name == nonctrl then goto continue end
    end

    if type(control) == "userdata" then
      if not checkContains(ctrlNames, tostring(name)) then
        table.insert(ctrlNames, tostring(name))
      end
    elseif type(control) == "table" then
      for i, _ in pairs(control) do
        if not checkContains(ctrlNames, tostring(name).." "..i) then
          table.insert(ctrlNames, tostring(name).." "..i)
        end
      end
    end
    table.sort(ctrlNames)
    ::continue::
  end
  return ctrlNames
end

-- Get named control names from XML file
function GetNamedControlsName()
  namectrlNames = {}
  local file = io.open('design/ExternalControls.xml')
  if file then
    content = file:read("*all")
    file:close()
    for name in content:gmatch('Control Id="([^"]+)"') do
      if not checkContains(namectrlNames, tostring(name)) then
        table.insert(namectrlNames, tostring(name))
      end
    end
  end
  return namectrlNames
end

-- ============================================================================
-- Utility Functions
-- ============================================================================
-- Convert single control to table format (modifies Controls directly)
function ToTable(controlName)
  if Controls[controlName] and type(Controls[controlName]) ~= 'table' then
    Controls[controlName] = {Controls[controlName]}
  end
end

-- Calculate normalized position (0.0 to 1.0) from value and range
function GetPosition(value, min, max)
  return (value - min) / (max - min) -- offset Value / range
end

-- Get actual control reference from To Controls mapping string
-- Input: "Gain 1" or "Toggle 2" etc. Output: Controls["Gain"][1] or Controls["Toggle"][2]
function GetMappedControl(mappingStr)
  if not mappingStr or mappingStr == "" then return nil end
  -- Parse control name and index (ex. "Gain 1")
  local ctrlName, ctrlIdx = mappingStr:match("^(.+)%s+(%d+)$")

  if ctrlName and ctrlIdx then -- Array control
    if Controls[ctrlName] and Controls[ctrlName][tonumber(ctrlIdx)] then
      return Controls[ctrlName][tonumber(ctrlIdx)]
    end
  else -- Single control
    if Controls[mappingStr] then
      return Controls[mappingStr]
    end
  end

  return nil
end

-- Broadcast message to all connected C1 clients (ECP format)
function PushToC1(cmd)
  ShowMsg("Tx: " .. cmd:gsub("[\r\n]+", ""))
  for _, sock in ipairs(sockets) do
    if sock.IsConnected then
      sock:Write(cmd)
    end
  end
end

-- Send initial state to newly connected client
function SendInitialState(sock)
  if not sock or not sock.IsConnected then return end
  ShowMsg("Client connected - Sending initial state")
  -- Send all controls mapped via Named Controls Name
  for idx, ctrl in ipairs(Controls["Named Controls Name"]) do
    local controlName = ctrl.String
    if controlName and controlName ~= "" then
      -- Check if it's a Gain control
      local val = syncVals[controlName .. "_Gain"]
      if val then
        local pos = GetPosition(val, ranges.min, ranges.max)
        local msg = string.format('cv "%s" "%.2fdB" %.2f %.6f\r\n', controlName, val, val, pos)
        sock:Write(msg)
      end

      -- Check if it's a Toggle control
      val = syncVals[controlName .. "_Toggle"]
      if val ~= nil then
        local strVal = (val == 1) and "muted" or "unmuted"
        local msg = string.format('cv "%s" "%s" %d %d\r\n', controlName, strVal, val, val)
        sock:Write(msg)
      end
    end
  end
end

-- ============================================================================
-- CSV Parser (C1 to QDS) Parses state changes from C1
-- ============================================================================
triggerTimers = {}
function CreateTimers(idx)
  triggerTimers[idx] = Timer.New()
  triggerTimers[idx].EventHandler = function()
    Controls['TriggerLED'][idx].Boolean = false
  end
end

function ParseCSV(data)
  ShowMsg('Rx: ' .. data)
  -- Process all controls via Named Controls Name
  for idx, ctrl in ipairs(Controls["Named Controls Name"]) do
    local controlName = ctrl.String
    if controlName and controlName ~= "" then
      local escapedName = controlName:gsub("%-", "%%-"):gsub("%.", "%%."):gsub("%_", "%%_")

      -- Check for Gain update (pattern: "csv ControlName -10.5dB")
      local gainPattern = '^csv%s' .. escapedName .. '%s([%-%d%.]+)dB'
      local gainValue = data:match(gainPattern)
      if gainValue then
        syncVals[controlName .. "_Gain"] = tonumber(gainValue)
        local mappedCtrl = GetMappedControl(Controls["To Controls"][idx].String)
        if mappedCtrl then
          mappedCtrl.Value = tonumber(gainValue)
        end
        return
      end

      -- Check if this control is mapped to Trigger
      local mappingStr = Controls["To Controls"][idx].String
      local isTrigger = mappingStr and mappingStr:find("^Trigger%s")

      if isTrigger then
        local triggerPattern = '^csv%s' .. escapedName .. "%s1$"
        if data:match(triggerPattern) then
          local mappedCtrl = GetMappedControl(mappingStr)
          if mappedCtrl then
            mappedCtrl:Trigger()
            -- Handle TriggerLED
            local ctrlName, ctrlIdx = mappingStr:match("^(.+)%s+(%d+)$")
            if ctrlName == "Trigger" and ctrlIdx then
              local ledIdx = tonumber(ctrlIdx)
              if Controls['TriggerLED'] and Controls['TriggerLED'][ledIdx] then
                -- Stop existing timer if running
                if not triggerTimers[ledIdx] then
                  CreateTimers(ledIdx)
                end
                if triggerTimers[ledIdx]:IsRunning() then
                  triggerTimers[ledIdx]:Stop()
                end
                -- Turn LED on
                Controls['TriggerLED'][ledIdx].Boolean = true
                -- Start timer to turn LED off after 0.5 seconds
                triggerTimers[ledIdx]:Start(0.5)
              end
            end
          end
          return
        end
      end

      -- Check for Toggle update (pattern: "csv ControlName 0/1")
      local togglePattern = '^csv%s' .. escapedName .. "%s([01])$"
      local toggleValue = data:match(togglePattern)
      if toggleValue then
        syncVals[controlName .. "_Toggle"] = tonumber(toggleValue)
        local mappedCtrl = GetMappedControl(Controls["To Controls"][idx].String)
        if mappedCtrl then
          mappedCtrl.Boolean = (toggleValue == "1")
        end
        return
      end
    end
  end
end

-- ============================================================================
-- CG Parser (C1 to QDS)
-- Parses control queries from C1 and returns current values in ECP format
-- Format: cv "ControlName" "StringValue" NumericValue Position
-- ============================================================================
function ParseCG(data)
  ShowMsg('Rx: ' .. data)
  for line in data:gmatch("[^\r\n]+") do
    -- Check all controls via Named Controls Name
    for idx, ctrl in ipairs(Controls["Named Controls Name"]) do
      local controlName = ctrl.String
      if controlName and controlName ~= "" then
        local escapedName = controlName:gsub("%-", "%%-"):gsub("%.", "%%.")

        -- Check for control query (pattern: "cg ControlName")
        if line:find('^cg%s' .. escapedName .. "$") or line:find('^cg%s' .. escapedName .. '%s') then
          local val = syncVals[controlName .. "_Gain"] -- Check if it's a Gain control
          if val then
            local pos = GetPosition(val, ranges.min, ranges.max)
            PushToC1(string.format('cv "%s" "%.2fdB" %.2f %.6f\r\n', controlName, val, val, pos))
            return
          end
          val = syncVals[controlName .. "_Toggle"] -- Check if it's a Toggle control
          if val ~= nil then
            local strVal = (val == 1) and "muted" or "unmuted"
            PushToC1(string.format('cv "%s" "%s" %d %d\r\n', controlName, strVal, val, val))
            return
          end
        end
      end
    end
  end
end

-- ============================================================================
-- Socket Event Handler
-- ============================================================================

function SocketHandler(sock, event)
  if event == TcpSocket.Events.Data then
    local d = sock:Read(sock.BufferLength)
    if not d then return end
    d = d:gsub("[\r\n]+$", "")

    if d:find("^csv") then
      ParseCSV(d)
    elseif d:find("^cg") then
      ParseCG(d)
    end

  elseif event == TcpSocket.Events.Closed or
         event == TcpSocket.Events.Error or
         event == TcpSocket.Events.Timeout then
    
    ShowMsg("Client disconnected")
    for instance, s in ipairs(sockets) do
      if s == sock then
        table.remove(sockets, instance)
        break
      end
    end
  end
end

-- ============================================================================
-- Connection Handler
-- ============================================================================
server.EventHandler = function(sock)
  table.insert(sockets, sock)
  sock.EventHandler = SocketHandler
  SendInitialState(sock)
end

-- ============================================================================
-- Initialization - Convert single controls to table format
-- ============================================================================
for name, _ in pairs(Controls) do
  if name~='Port' and name~='Status' and name~='Msg' then
    ToTable(tostring(name))
  end
end

-- ============================================================================
-- Set control choices for dropdowns
-- ============================================================================
-- Populate To Controls dropdown choices
for _, ctrl in ipairs(Controls['To Controls']) do
  ctrl.Choices = GetControlNames()
end

-- Populate Named Controls Name dropdown choices
for _, ctrl in ipairs(Controls['Named Controls Name']) do
  ctrl.Choices = GetNamedControlsName()
end

-- ============================================================================
-- UI Event Handlers
-- ============================================================================
-- Setup event handlers for Named Controls Name changes
for idx, ctrl in ipairs(Controls["Named Controls Name"]) do
  ctrl.EventHandler = function(c)
    local controlName = c.String
    if controlName and controlName ~= "" then
      -- Initialize sync values when control name changes
      if Controls["To Controls"] and Controls["To Controls"][idx] then
        local mappedCtrl = GetMappedControl(Controls["To Controls"][idx].String)
        if mappedCtrl then
          if mappedCtrl.Value ~= nil then
            syncVals[controlName .. "_Gain"] = mappedCtrl.Value
          elseif mappedCtrl.Boolean ~= nil then
            syncVals[controlName .. "_Toggle"] = mappedCtrl.Boolean and 1 or 0
          end
        end
      end
    end
  end
end

-- Setup event handlers for To Controls mapping changes
for idx, ctrl in ipairs(Controls["To Controls"]) do
  ctrl.EventHandler = function(c)
    local mappingStr = c.String
    local mappedCtrl = GetMappedControl(mappingStr)
    
    ShowMsg(string.format("Mapping changed [%d]: %s", idx, mappingStr or "none"))
    
    if mappedCtrl and Controls["Named Controls Name"] and Controls["Named Controls Name"][idx] then
      local controlName = Controls["Named Controls Name"][idx].String
      if controlName and controlName ~= "" then
        -- Initialize sync value from mapped control
        if mappedCtrl.Value ~= nil then
          syncVals[controlName .. "_Gain"] = mappedCtrl.Value
        elseif mappedCtrl.Boolean ~= nil then
          syncVals[controlName .. "_Toggle"] = mappedCtrl.Boolean and 1 or 0
        end
        
        -- Setup event handler on the mapped control
        mappedCtrl.EventHandler = function(mc)
          -- Check control type by mapping string to determine correct handling
          local isToggle = mappingStr and mappingStr:find("^Toggle%s")
          
          if isToggle then
            -- Toggle control changed
            local toggleVal = mc.Boolean and 1 or 0
            syncVals[controlName .. "_Toggle"] = toggleVal
            local strVal = (toggleVal == 1) and "muted" or "unmuted"
            local msg = string.format('cv "%s" "%s" %d %d\r\n', controlName, strVal, toggleVal, toggleVal)
            PushToC1(msg)
          elseif mc.Value ~= nil then
            -- Gain control changed
            syncVals[controlName .. "_Gain"] = mc.Value
            local msg = string.format('csv %s %.2fdB\r\n', controlName, mc.Value)
            PushToC1(msg)
          end
        end
      end
    end
  end
end

-- ============================================================================
-- Initialize control values and event handlers
-- ============================================================================
for idx, ctrl in ipairs(Controls["Named Controls Name"]) do
  local controlName = ctrl.String
  if controlName and controlName ~= "" then
    local mappingStr = Controls["To Controls"][idx].String
    local mappedCtrl = GetMappedControl(mappingStr)

    if mappedCtrl then
      -- Initialize sync value from mapped control
      if mappedCtrl.Value ~= nil then
        syncVals[controlName .. "_Gain"] = mappedCtrl.Value
      elseif mappedCtrl.Boolean ~= nil then
        syncVals[controlName .. "_Toggle"] = mappedCtrl.Boolean and 1 or 0
      end

      -- Setup event handler on the mapped control
      mappedCtrl.EventHandler = function(mc)
        -- Check control type by mapping string to determine correct handling
        local isToggle = mappingStr and mappingStr:find("^Toggle%s")

        if isToggle then
          -- Toggle control changed
          local toggleVal = mc.Boolean and 1 or 0
          syncVals[controlName .. "_Toggle"] = toggleVal
          local strVal = (toggleVal == 1) and "muted" or "unmuted"
          local msg = string.format('cv "%s" "%s" %d %d\r\n', controlName, strVal, toggleVal, toggleVal)
          PushToC1(msg)
        elseif mc.Value ~= nil then
          -- Gain control changed
          syncVals[controlName .. "_Gain"] = mc.Value
          local msg = string.format('csv %s %.2fdB\r\n', controlName, mc.Value)
          PushToC1(msg)
        end
      end
    end
  end
end

-- ============================================================================
-- Server Start/Restart Function with Error Handling
-- ============================================================================
function Listen()
  -- Close existing server safely
  pcall(function() server:Close() end)

  Timer.CallAfter(function()
    sockets = {}
    local port = math.floor(tonumber(Controls.Port.Value))
    -- Use pcall to catch port binding errors
    local success, err = pcall(function() server:Listen(port) end)

    if not success then
      ShowMsg(string.format("Error: Port %d unavailable", port))
      Controls.Status.Value = 2
      Controls.Status.String = string.format("Port %d unavailable", port)
    else
      ShowMsg(string.format("Listening on port %d", port))
      Controls.Status.Value = 0
      Controls.Status.String = string.format("Listening on port %d", port)
    end
  end, 0.1)
end

-- Setup port change handler
Controls.Port.EventHandler = Listen

-- Start server with error handling
local port = math.floor(tonumber(Controls.Port.Value))
local success, err = pcall(function()
  server:Listen(port)
end)

if not success then
  ShowMsg(string.format("Error: Port %d unavailable on startup", port))
  if Controls.Status then
    Controls.Status.Value = 2
    Controls.Status.String = string.format("Port %d unavailable", port)
  end
else
  ShowMsg(string.format("Server started on port %d", port))
  if Controls.Status then
    Controls.Status.Value = 0
    Controls.Status.String = string.format("Listening on port %d", port)
  end
end