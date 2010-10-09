--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2010 - James N. Whitehead II
--
--  This is an updated version of the original 'Clique' addon
--  designed to work better with multi-button mice, and those players
--  who want to be able to bind keyboard combinations to enable 
--  hover-casting on unit frames.  It's a bit of a paradigm shift from
--  the original addon, but should make a much simpler and more
--  powerful addon.
--  
--    * Any keyboard combination can be set as a binding.
--    * Any mouse combination can be set as a binding.
--    * The only types that are allowed are spells and macros.
--
--  The concept of 'click-sets' has been simplified and extended
--  so that the user can specify their own click-sets, allowing
--  for different bindings for different sets of frames. By default
--  the following click-sets are available:
--
--    * default - These bindings are active on all frames, unless
--      overridden by another binding in a more specific click-set.
--    * ooc - These bindings will ONLY be active when the player is
--      out of combat.
--    * enemy - These bindings are ONLY active when the unit you are
--      clicking on is an enemy, i.e. a unit that you can attack.
--    * friendly - These bindings are ONLY active when the unit you are
--      clicking on is a friendly unit, i.e. one that you can assist
--    * global - These bindings will be available regardless of where
--      your mouse is on the screen, be it in the 3D world, or over a
--      unit frame. These bindings take up a slot that might otherwise
--      be used in the 'Key Bindings' interface options.
--
--  The click-sets layer on each other, with the 'default' click-set
--  being at the bottom, and any other click-set being layered on top.
--  Clique will detect any conflicts that you have other than with
--  default bindings, and will warn you of the situation.
-------------------------------------------------------------------]]--

local addonName, addon = ...
local L = addon.L 

function addon:Initialize()
    self:InitializeDatabase()
    self.ccframes = {}

    -- Registration for group headers (in-combat safe)
    self.header = CreateFrame("Frame", addonName .. "HeaderFrame", UIParent, "SecureHandlerBaseTemplate")
    ClickCastHeader = addon.header

    -- Create a table within the addon header to store the frames
    -- that are registered for click-casting
    self.header:Execute([[
        ccframes = table.new()
    ]])

    -- OnEnter bootstrap script for group-header frames
    self.header:SetAttribute("clickcast_onenter", [===[
        local header = self:GetParent():GetFrameRef("clickcast_header")
        header:RunFor(self, header:GetAttribute("setup_onenter"))
    ]===])

    -- OnLeave bootstrap script for group-header frames
    self.header:SetAttribute("clickcast_onleave", [===[
        local header = self:GetParent():GetFrameRef("clickcast_header")
        header:RunFor(self, header:GetAttribute("setup_onleave"))
    ]===])

    local setup, remove = self:GetClickAttributes()
    self.header:SetAttribute("setup_clicks", setup) 
    self.header:SetAttribute("remove_clicks", remove)
    self.header:SetAttribute("clickcast_register", ([===[
        local button = self:GetAttribute("clickcast_button")
        button:SetAttribute("clickcast_onenter", self:GetAttribute("clickcast_onenter"))
        button:SetAttribute("clickcast_onleave", self:GetAttribute("clickcast_onleave"))
        ccframes[button] = true
        self:RunFor(button, self:GetAttribute("setup_clicks"))
    ]===]):format(self.attr_setup_clicks))

    local set, clr = self:GetBindingAttributes()
    self.header:SetAttribute("setup_onenter", set)
    self.header:SetAttribute("setup_onleave", clr)

    -- Clickcast registration systems
    -- Compatability with old Clique 1.x registrations
    local oldClickCastFrames = ClickCastFrames

    ClickCastFrames = setmetatable({}, {__newindex = function(t, k, v)
        if v == nil then
            self:UnregisterFrame(k)
        else
            self:RegisterFrame(k, v)
        end
    end})

    -- Iterate over the frames that were set before we arrived
    if oldClickCastFrames then
        for frame, options in pairs(oldClickCastFrames) do
            self:RegisterFrame(frame, options)
        end
    end
    self:EnableBlizzardFrames()

    -- Register for combat events to ensure we can swap between the two states
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateAttributes")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateAttributes")
end

function addon:RegisterFrame(button)
    self.ccframes[button] = true

    button:RegisterForClicks("AnyDown")

    -- Wrap the OnEnter/OnLeave scripts in order to handle keybindings
    addon.header:WrapScript(button, "OnEnter", addon.header:GetAttribute("setup_onenter"))
    addon.header:WrapScript(button, "OnLeave", addon.header:GetAttribute("setup_onleave"))

    -- Set the attributes on the frame
    self.header:SetFrameRef("cliquesetup_button", button)
    self.header:Execute(self.header:GetAttribute("setup_clicks"), button)
end

function addon:Enable()
    print("Addon " .. addonName .. " enabled")
    -- Make the options window a pushable panel window
    UIPanelWindows["CliqueConfig"] = {
        area = "left",
        pushable = 1,
        whileDead = 1,
    }
end

function addon:InitializeDatabase()
    -- TODO: This is all testing boilerplate, try to fix it up
    local reset = false
    if not CliqueDB then
        reset = true
    elseif type(CliqueDB) == "table" and not CliqueDB.dbversion then
        reset = true
    elseif type(CliqueDB) == "table" and CliqueDB.dbversion == 2 then
        reset = false
    end

    if reset then
        CliqueDB = {
            binds = {
                [1] = {key = "BUTTON1", type = "target", unit = "mouseover", sets = {default = true}},
                [2] = {key = "BUTTON2", type = "menu", sets = {default = true}},
            },
            dbversion = 2,
        }
    end

    self.profile = CliqueDB
end

function ATTR(prefix, attr, suffix, value)
    local fmt = [[button:SetAttribute("%s%s%s%s%s", %q)]]
    return fmt:format(prefix, #prefix > 0 and "-" or "", attr, tonumber(suffix) and "" or "-", suffix, value)  
end

function REMATTR(prefix, attr, suffix, value)
    local fmt = [[button:SetAttribute("%s%s%s%s%s", nil)]]
    return fmt:format(prefix, #prefix > 0 and "-" or "", attr, tonumber(suffix) and "" or "-", suffix)  
end

-- This function will create an attribute that when run for a given frame
-- will set the correct set of SAB attributes.
function addon:GetClickAttributes()
    local bits = {
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    local rembits = {
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    for idx, entry in ipairs(self.profile.binds) do
        if self:ShouldSetBinding(entry) then
            local prefix, suffix = entry.key:match("^(.-)([^%-]+)$")
            if prefix:sub(-1, -1) == "-" then
                prefix = prefix:sub(1, -2)
            end

            prefix = prefix:lower()

            local button = suffix:match("^BUTTON(%d+)$")
            if button then
                suffix = button
            else
                suffix = "cliquebutton" .. idx
                prefix = ""
            end

            -- Build any needed SetAttribute() calls
            if entry.type == "target" or entry.type == "menu" then
                bits[#bits + 1] = ATTR(prefix, "type", suffix, entry.type)
                rembits[#rembits + 1] = REMATTR(prefix, "type", suffix)
            elseif entry.type == "spell" then
                bits[#bits + 1] = ATTR(prefix, "type", suffix, entry.type)
                bits[#bits + 1] = ATTR(prefix, "spell", suffix, entry.spell)
                rembits[#rembits + 1] = REMATTR(prefix, "type", suffix)
                rembits[#rembits + 1] = REMATTR(prefix, "spell", suffix)
            elseif entry.type == "macro" then
                bits[#bits + 1] = ATTR(prefix, "type", suffix, entry.type)
                bits[#bits + 1] = ATTR(prefix, "macrotext", suffix, entry.macrotext)
                rembits[#rembits + 1] = REMATTR(prefix, "type", suffix)
                rembits[#rembits + 1] = REMATTR(prefix, "macrotext", suffix)

            else
                error(string.format("Invalid action type: '%s'", entry.type))
            end
        end
    end

    return table.concat(bits, "\n"), table.concat(rembits, "\n")
end

local B_SET = [[self:SetBindingClick(true, "%s", self, "%s");]]
local B_CLR = [[self:ClearBinding("%s");]]

-- This function will create two attributes, the first being a "setup keybindings"
-- script and the second being a "clear keybindings" script.

function addon:GetBindingAttributes()
    local set = {}
    local clr = {}

    for idx, entry in ipairs(self.profile.binds) do
        if self:ShouldSetBinding(entry) then 
            if not entry.key:match("BUTTON%d+$") then
                -- This is a key binding, so we need a binding for it
                set[#set + 1] = B_SET:format(entry.key, "cliquebutton" .. idx)
                clr[#clr + 1] = B_CLR:format(entry.key)
            end
        end
    end

    return table.concat(set, "\n"), table.concat(clr, "\n")
end

-- This function adds a binding to the player's current profile. The
-- following options can be included in the click-cast entry:
--
-- entry = {
--     -- The full prefix and suffix of the key being bound
--     key = "ALT-CTRL-SHIFT-BUTTON1",
--     -- The icon to be used for displaying this entry
--     icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
--
--     -- Any restricted sets that this click should be applied to
--     sets = {"ooc", "harm", "help", "frames_blizzard"},
-- 
--     -- The type of the click-binding
--     type = "spell",
--     type = "macro",
--     type = "target",
--     type = "menu",
-- 
--     -- Any arguments for given click type
--     spell = "Healing Touch",
--     macrotext = "/run Nature's Swiftness\n/cast [target=mouseover] Healing Touch",
--     unit = "mouseover",
-- }

function addon:AddBinding(entry)
    -- TODO: Check to see if the new binding conflicts with an existing binding

    -- TODO: Validate the entry to ensure it has the correct arguments, etc.

    if not entry.sets then
        entry.sets = {default = true}
    end

    table.insert(self.profile.binds, entry)
   
    self:UpdateAttributes()
    return true
end

local function bindingeq(a, b)
    assert(type(a) == "table")
    assert(type(b) == "table")
    if a.type ~= b.type then
        return false
    elseif a.type == "target" then
        return true
    elseif a.type == "menu" then
        return true
    elseif a.type == "spell" then
        return a.spell == b.spell
    elseif a.type == "macro" then
        return a.macrotext == b.macrotext
    end

    return false
end

function addon:DeleteBinding(entry)
    -- Look for an entry that matches the given binding and remove it
    for idx, bind in ipairs(self.profile.binds) do
        if bindingeq(entry, bind) then
            -- Found the entry that matches, so remove it
            table.remove(self.profile.binds, idx)
            break
        end
    end

    -- Update the attributes
    self:UpdateAttributes()
end

function addon:ClearAttributes()
    self.header:Execute([[
        for button, enabled in pairs(ccframes) do
            self:RunFor(button, self:GetAttribute("remove_clicks")) 
        end
    ]])

    for button, enabled in pairs(self.ccframes) do
        -- Perform the setup of click bindings
        self.header:SetFrameRef("cliquesetup_button", button)
        self.header:Execute(self.header:GetAttribute("remove_clicks"), button)
    end
end

function addon:UpdateAttributes()
    if InCombatLockdown() then
        error("panic: Clique:UpdateAttributes() called during combat")
    end

    -- Clear any of the previously set attributes
    self:ClearAttributes()

    local setup, remove = self:GetClickAttributes()
    self.header:SetAttribute("setup_clicks", setup)
    self.header:SetAttribute("remove_clicks", remove)

    local set, clr = self:GetBindingAttributes()
    self.header:SetAttribute("setup_onenter", set)
    self.header:SetAttribute("setup_onleave", clr)

    self.header:Execute([[
        for button, enabled in pairs(ccframes) do
            self:RunFor(button, self:GetAttribute("setup_clicks")) 
        end
    ]])
    
    for button, enabled in pairs(self.ccframes) do
        -- Unwrap any existing enter/leave scripts
        addon.header:UnwrapScript(button, "OnEnter")
        addon.header:UnwrapScript(button, "OnLeave")
        addon.header:WrapScript(button, "OnEnter", addon.header:GetAttribute("setup_onenter"))
        addon.header:WrapScript(button, "OnLeave", addon.header:GetAttribute("setup_onleave"))

        -- Perform the setup of click bindings
        self.header:SetFrameRef("cliquesetup_button", button)
        self.header:Execute(self.header:GetAttribute("setup_clicks"), button)
    end
end

SLASH_CLIQUE1 = "/clique"
SlashCmdList["CLIQUE"] = function(msg, editbox)
    ShowUIPanel(CliqueConfig)
end
