--- Hyper / Caps Lock Quick Launch.
-- Keys are free choice; display is alphabetical by label (see loader.lua).
-- Edit target only — order in this file does not matter; loader sorts by label.
-- String = launch app; table = open menu. Use {} to disable (or return {}).
return {
  { key = "a", target = "Agenda" },
  { key = "b", target = "Bike" },
  { key = "l", target = "Calculator" },
  { key = "c", target = "Calendar" },
  { key = "y", target = "cyberWriter" },
  { key = "d", target = "Delta" },
  { key = "v", target = "DevUtils" },
  { key = "f", target = { type = "openMenu", menu = "finder" } },
  { key = "r", target = "Freeform" },
  { key = "i", target = "iA Writer" },
  { key = "k", target = "KeePassXC" },
  { key = "m", target = "Mail" },
  { key = "n", target = "Notes" },
  { key = "p", target = "Passwords" },
  { key = "q", target = "Safari" },
  { key = "s", target = "Siri" },
  { key = "u", target = "Sublime Merge" },
  { key = "e", target = "System Settings" },
  { key = "t", target = "Things" },
  { key = "z", target = "Zed" },
}
