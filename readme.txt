Clique2 Design Information

SavedVariable structure:

self.profile.binds = {
  ["cliqueuid:1"] = { 
    name = "Healing Touch",
    binding = {
      alt = true,
      button = "1",
    },
    action = {
      type = "spell",
      spell = "Healing Touch",
    },
    sets = {
      helpful = true,
    },
  },
  ["cliqueuid:2"] = {
    name = "Show menu",
    binding = {
      button = "2",
    }
    action = {
      type = "menu",
    },
    sets = {
      ooc = true,
    },
  },
}

Bind-set semantics (highest priority to lowest)

  * custom frame set (this set does NOT inherit)
  * out of combat set (inherits everything below, overriding)
  * harmful and helpful
  * default

Database defaults:

defaults = {
  profile = {
    uidCounter = 1,
    binds = {
      -- Show menu (default)
      -- Target unit (default)
    }
  }
}


if not header then
   header = CreateFrame("Button", "header", UIParent, "SecureHandlerBaseTemplate")
end


enter = [[
print("Setting bindings")
self:SetBindingClick(true, "F", self, "cliquebutton1")
]]

leave = [[
print("Clearing bindings")
self:ClearBinding("F")
]]

header:SetFrameRef("player", PlayerFrame)
header:UnwrapScript(PlayerFrame, "OnEnter")
header:UnwrapScript(PlayerFrame, "OnLeave")
header:WrapScript(PlayerFrame, "OnEnter", enter)
header:WrapScript(PlayerFrame, "OnLeave", leave)

PlayerFrame:SetAttribute("type-cliquebutton1", "spell")
PlayerFrame:SetAttribute("spell-cliquebutton1", "Mark of the Wild")
PlayerFrame:SetAttribute("unit-cliquebutton1", "player")

