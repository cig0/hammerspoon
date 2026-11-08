--- Gearbox root menu: applications and the Scratchpad.
return {
  id = "leader",
  title = "Gearbox",
  emoji = "⚙️",
  showFooterDivider = true,

  items = {
    {
      key = "f",
      label = "ForkLift",
      kind = "application",
      action = { type = "launchApp", name = "ForkLift" }
    }, {
    key = "s",
    label = "Scratchpad",
    kind = "action",
    requires = "scratchpad",
    action = { type = "openScratchpad" }
  }, {
    key = "i",
    label = "SimpleMind",
    kind = "application",
    action = { type = "launchApp", name = "SimpleMind" }
  }
  }
}
