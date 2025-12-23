local CurrentPage = PageNames[props["page_index"].Value]

local Colors = {Black={0,0,0},Black0={0,0,0,0},White={255,255,255}}
local g_count = props["Gain Count"].Value
local t_count = props["Toggle Count"].Value
local tri_count = props["Trigger Count"].Value
local n_count = props["Named Controls Name Count"].Value
local to_count = props["To Controls Count"].Value

local labels = {size={64,16}}
local ctrls = {size={label={36,16}, status={192,16}, text={128,16}, knob={36,36}, btn={36,16}, led={16,16}} }

-- Calculate maximum X position for all controls
local c_Ctrls = {"Named Controls Name","To Controls","Gain", "Toggle", "Trigger", "TriggerLED"}
local c_Counts = {n_count, to_count, g_count, t_count, tri_count, tri_count}
local c_Size = {ctrls.size.text, ctrls.size.text, ctrls.size.knob, ctrls.size.btn, ctrls.size.btn, ctrls.size.led}
local c_Space = {128,128,36,36,36,36}
local c_Y =  {134,166,198,245,277,309}

if CurrentPage == "Controls" then
  local maxX = 360 -- Initial minimum width
  for c_index, ctrlName in ipairs(c_Ctrls) do
    if c_Counts[c_index] > 0 then
      local xbase = ctrlName == "TriggerLED" and 130 or 120
      local lastIndex = c_Counts[c_index]
      local lastXPos = xbase + c_Space[c_index] * (lastIndex - 1)
      local controlEndX = lastXPos + c_Size[c_index][1] -- X position + width
      maxX = math.max(maxX, controlEndX)
    end
  end
  local groupBoxWidth = maxX + 20 -- Add 20px padding from rightmost control

  -- GroupBoxes, Header
  table.insert(graphics, {Type = "GroupBox", Fill = Colors.Black0, StrokeColor = Colors.Black, CornerRadius = 8, StrokeWidth = 1, Position = {0,0}, Size = {groupBoxWidth, 350}})
  table.insert(graphics, {Type = "Header", Text = "Q-SYS Server for Axon C1 (3rd Party Mode)", Position = {20,3}, Color = Colors.Black, Size = {320,40}, FontSize = 12, HTextAlign = "Center"})

  -- Labels
  local texts = {'Port','Status','Message','Named Controls Name','To Controls','Gain','Toggle','Trigger','TriggerLED'}
  local textsPos = {{54,54},{54,70},{54,102},{40,126},{54,166},{54,198},{54,245},{54,277},{54,309}}

  for i = 1, #texts do
    table.insert(graphics, {
      Type = "Text",
      Text = texts[i],
      Position = textsPos[i],
      Size = i == 4 and {78,32} or labels.size,
      Font = "Roboto",
      HTextAlign = "Left",
    })
  end

  -- Controls
  for c_index, ctrlName in ipairs(c_Ctrls) do
    for index = 1, c_Counts[c_index] do
      local suffix = (c_Counts[c_index] == 1 and index == 1) and "" or " " .. index
      local xbase = ctrlName == "TriggerLED" and 130 or 120
      local xpos = xbase + c_Space[c_index] * (index - 1)
      local ypos = c_Y[c_index]

      layout[ctrlName .. suffix] = {
        PrettyName = ctrlName .. "~" .. index,
        Style = ctrlName == "Gain" and "Knob"
            or ctrlName == "Named Controls Name" and "ComboBox"
            or ctrlName == "To Controls" and "ComboBox"
            or nil,
        Position = {xpos, ypos},
        Size = c_Size[c_index],
        Margin = ctrlName == "TriggerLED" and 3 or nil,
      }
    end
  end

  -- Fixed controls
  layout["Port"] = {
    PrettyName = "Port",
    Style = "Text",
    Position = {120,54},
    Size = ctrls.size.label,
    TextColor = Colors.Black,
    Color = Colors.White,
    CornerRadius = 2,
    Margin = 0,
    Padding = 0,
    HTextAlign = "Center",
    FontSize = 9
  }

  layout["Status"] = {
    PrettyName = "Status",
    Style = "Text",
    Position = {120,70},
    Size = ctrls.size.status,
    CornerRadius = 0,
    Margin = 0,
    Padding = 0,
    HTextAlign = "Center",
    FontSize = 9
  }

  layout["Msg"] = {
    PrettyName = "Message",
    Style = "Text",
    Position = {120,102},
    Size = ctrls.size.status,
    TextColor = Colors.Black,
    CornerRadius = 0,
    Margin = 0,
    Padding = 0,
    HTextAlign = "Center",
    FontSize = 9
  }
elseif CurrentPage == "Help" then
  table.insert(graphics, {
    Type = "Text",
    Text =
[[How to Use
With the Core’s standard ECP port 1702, communication from C1 is disconnected after 60 seconds.
After that, C1 does not recognize that the connection has been lost and continues to send commands, but Core cannot receive them for several seconds.
For example, snapshot loading may fail.
By using this plugin, the communication will remain constantly connected without being disconnected, and snapshots can be received reliably.

Properties
Gain Count・・・Number of Gains inside Core that are controlled from C1
Toggle Count・・・Number of Toggles inside Core that are controlled from C1
Trigger Count・・・Number of Triggers inside Core that are controlled from C1
Named Controls Name Count・・・Number of Named Controls Names inside Core that are controlled from C1
To Controls Count・・・Number of control destinations inside Core

Port・・・The port number on which Core listens. Make sure it does not conflict with ECP 1702 or others.
Status・・・Leave as is
Message・・・Displays the Tx/Rx communication between C1 and Core
Named Controls Name・・・A list of names registered in Named Controls is displayed.
Select the target to be controlled from the C1 side.
To Controls・・・Select which component the control selected in Named Controls Name will be assigned to.
Named Controls Name[idx] corresponds to To Controls[idx].

On the C1 side
C1 Menu Mode: [3rd Party]
3rd Party Devices List: Devicename (e.g. Core)
Device Type: [General]
Control Port Settings
Device IP: [Core IP]
Port: [Plugin Setting Port]
Proto: TCP

In Menu Builder
Under the Menu Screen(s) hierarchy

Sample
//////////////////////////////////////////////////////////////////////////////////////////
When loading a snapshot
Actions Trigger
Destination: [Devicename (e.g. Core)]
Payload:
csv Snapshot_Controller Load1 1
*Snapshot_ControllerLoad1 is the name registered in Named Controls
//////////////////////////////////////////////////////////////////////////////////////////
When controlling Level
Actions Level
Level Config
Destination: [Devicename (e.g. Core)]
Type: Explicit
Attributes
Min: -100 (as preferred)
Max: 20 (as preferred)
Step: 1 (as preferred)
Precision: 0.0 Trim [Check]

Level Set Command:
csv GainGain ❶dB
CR [Check] LF [Check]
*GainGain is the name registered in Named Controls
//////////////////////////////////////////////////////////////////////////////////////////
Level Query
Enable Polling [Check]
Interval: 1500 (as preferred)

Query Command:
cg GainGain
CR [Check] LF [Check]

Response Command:
cv "GainGain" "❶dB" ✪
CR [Check] LF [Check]
*Must be enclosed in double quotes
//////////////////////////////////////////////////////////////////////////////////////////
When controlling Mute
Mute Config
Destination: [Devicename (e.g. Core)]
Attributes
Inactive State: 0
Active State: 1
ALT Inactive State: unmuted
ALT Active State: muted

Mute Set Command:
csv GainMute ❶
CR [Check] LF [Check]
*GainMute is the name registered in Named Controls

Mute Query
Enable Polling [Check]
Interval: 500 (as preferred)

Query Command:
cg GainMute
CR [Check] LF [Check]

Response
Use Alternative State [Check]

Response Command:
cv "GainMute" "❶" ✪
CR [Check] LF [Check]
*Must be enclosed in double quotes]],
    Position = {0,0},
    Size = {625,1100},
    Padding = 5,
    Font = "Roboto",
    FontSize = 9,
    HTextAlign = "Left",
    VTextAlign = "Top",
  })
end