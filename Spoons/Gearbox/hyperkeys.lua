--- Hyper / Caps Lock Quick Launch.
-- Keys are free choice; display is alphabetical by label (see loader.lua).
-- Edit target only — order in this file does not matter; loader sorts by label.
-- String = launch app; table = open menu. Use {} to disable (or return {}).
return {
  { key = "a", target = { name = "Agenda", bundleID = "com.momenta.agenda.macos" } },
  { key = "b", target = { name = "Bike", bundleID = "com.hogbaysoftware.Bike" } },
  { key = "l", target = { name = "Calculator", bundleID = "com.apple.calculator" } },
  { key = "c", target = { name = "Calendar", bundleID = "com.apple.iCal" } },
  { key = "y", target = { name = "cyberWriter", bundleID = "pro.writer.mac" } },
  { key = "d", target = { name = "Delta" } },
  { key = "v", target = { name = "DevUtils", bundleID = "com.trungtran.DevUtils" } },
  { key = "f", target = { type = "openMenu", menu = "finder" } },
  { key = "r", target = { name = "Freeform", bundleID = "com.apple.freeform" } },
  { key = "i", target = { name = "iA Writer", bundleID = "pro.writer.mac" } },
  { key = "k", target = { name = "KeePassXC", bundleID = "org.keepassxc.keepassxc" } },
  { key = "m", target = { name = "Mail", bundleID = "com.apple.mail" } },
  { key = "n", target = { name = "Notes", bundleID = "com.apple.Notes" } },
  { key = "o", target = { name = "OmniFocus", bundleID = "com.omnigroup.OmniFocus4" } },
  { key = "p", target = { name = "Passwords", bundleID = "com.apple.Passwords" } },
  { key = "q", target = { name = "Safari", bundleID = "com.apple.Safari" } },
  { key = "s", target = { type = "openSiri" } },
  { key = "u", target = { name = "Sublime Merge", bundleID = "com.sublimemerge" } },
  { key = "e", target = { name = "System Settings", bundleID = "com.apple.systempreferences" } },
  { key = "t", target = { name = "Things", bundleID = "com.culturedcode.ThingsMac" } },
  { key = "z", target = { name = "Zed", bundleID = "dev.zed.Zed" } },
}
