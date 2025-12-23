table.insert(ctrls, {
  Name = "Port",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Count = 1,
  Min = 1,
  Max = 65535,
  DefaultValue = 1800,
  UserPin = true,
  PinStyle = "Both",
})
table.insert(ctrls, {
  Name = "Status",
  ControlType = "Indicator",
  IndicatorType = "Status",
  Count = 1,
  UserPin = true,
  PinStyle = "Output",
})
table.insert(ctrls, {
  Name = "Msg",
  ControlType = "Indicator",
  IndicatorType = "Text",
  Count = 1,
  UserPin = true,
  PinStyle = "Output",
})
table.insert(ctrls, {
  Name = "Gain",
  ControlType = "Knob",
  ControlUnit = "dB",
  Min = -100,
  Max = 20,
  DefaultValue = 0,
  Count = props["Gain Count"].Value,
  UserPin = true,
  PinStyle = "Both",
})
table.insert(ctrls, {
  Name = "Toggle",
  ControlType = "Button",
  ButtonType = "Toggle",
  Count = props["Toggle Count"].Value,
  UserPin = true,
  PinStyle = "Both",
})
table.insert(ctrls, {
  Name = "Trigger",
  ControlType = "Button",
  ButtonType = "Trigger",
  Count = props["Trigger Count"].Value,
  UserPin = true,
  PinStyle = "Both",
})
table.insert(ctrls, {
  Name = "TriggerLED",
  ControlType = "Indicator",
  IndicatorType = "Led",
  Count = props["Trigger Count"].Value,
  UserPin = true,
  PinStyle = "Output",
})
table.insert(ctrls, {
  Name = "Named Controls Name",
  ControlType = "Text",
  Count = props["Named Controls Name Count"].Value,
  UserPin = true,
  PinStyle = "Both",
})
table.insert(ctrls, {
  Name = "To Controls",
  ControlType = "Text",
  Count = props["To Controls Count"].Value,
  UserPin = true,
  PinStyle = "Both",
})