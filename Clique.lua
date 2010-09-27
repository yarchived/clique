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
-------------------------------------------------------------------]]--

local addonName, addon = ...
local L = addon.L 

function addon:Initialize()
    self:InitializeDatabase()
    
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

    -- Registration for group headers (in-combat safe)
    self.header = CreateFrame("Frame", addonName .. "HeaderFrame", UIParent, "SecureHandlerBaseTemplate")
    ClickCastHeader = addon.header

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

    self.header:SetAttribute("setup_clicks", self:GetClickAttribute())
    self.header:SetAttribute("clickcast_register", ([===[
        local button = self:GetAttribute("clickcast_button")
        button:SetAttribute("clickcast_onenter", self:GetAttribute("clickcast_onenter"))
        button:SetAttribute("clickcast_onleave", self:GetAttribute("clickcast_onleave"))
        self:RunFor(button, self:GetAttribute("setup_clicks"))
    ]===]):format(self.attr_setup_clicks))

    local set, clr = self:GetBindingAttributes()
    self.header:SetAttribute("setup_onenter", set)
    self.header:SetAttribute("setup_onleave", clr)
end

function addon:RegisterFrame(button)
    button:RegisterForClicks("AnyDown")

    -- Wrap the OnEnter/OnLeave scripts in order to handle keybindings
    addon.header:WrapScript(button, "OnEnter", addon.header:GetAttribute("setup_onenter"))
    addon.header:WrapScript(button, "OnLeave", addon.header:GetAttribute("setup_onleave"))

    -- Set the attributes on the frame
    -- TODO: Fix this as it is broken
    self.header:RunFor(button, self.header:GetAttribute("setup_clicks"))
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
    self.profile = {
        binds = {
            [1] = {key = "BUTTON1", type = "target", unit = "mouseover"},
            [2] = {key = "BUTTON2", type = "menu"},
            [3] = {key = "F", type = "spell", spell = "Lifebloom"},
            [4] = {key = "SHIFT-F", type = "spell", spell = "Regrowth"},
            [5] = {key = "CTRL-BUTTON1", type = "spell", spell = "Rejuvenation"},
            [6] = {key = "SHIFT-BUTTON1", type = "spell", spell = "Regrowth"},
        },
    }
end

function ATTR(prefix, attr, suffix, value)
    local fmt = [[self:SetAttribute("%s%s%s%s%s", "%s")]]
    return fmt:format(prefix, #prefix > 0 and "-" or "", attr, tonumber(suffix) and "" or "-", suffix, value)  
end

-- This function will create an attribute that when run for a given frame
-- will set the correct set of SAB attributes.
function addon:GetClickAttribute()
    local bits = {}

    for idx, entry in ipairs(self.profile.binds) do
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
        elseif entry.type == "spell" then
            bits[#bits + 1] = ATTR(prefix, "type", suffix, entry.type)
            bits[#bits + 1] = ATTR(prefix, "spell", suffix, entry.spell)
        elseif entry.type == "macro" then
            bits[#bits + 1] = ATTR(prefix, "type", suffix, entry.type)
            bits[#bits + 1] = ATTR(prefix, "macrotext", suffix, entry.macrotext)
        else
            error(string.format("Invalid action type: '%s'", entry.type))
        end
    end

    return table.concat(bits, "\n")
end

local B_SET = [[self:SetBindingClick(true, "%s", self, "%s");]]
local B_CLR = [[self:ClearBinding("%s");]]

-- This function will create two attributes, the first being a "setup keybindings"
-- script and the second being a "clear keybindings" script.

function addon:GetBindingAttributes()
    local set = {}
    local clr = {}

    for idx, entry in ipairs(self.profile.binds) do
        if not entry.key:match("BUTTON%d+$") then
            -- This is a key binding, so we need a binding for it
            set[#set + 1] = B_SET:format(entry.key, "cliquebutton" .. idx)
            clr[#clr + 1] = B_CLR:format(entry.key)
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
    print("Adding new binding")
    for k,v in pairs(entry) do
        print(k, v)
    end
end

SLASH_CLIQUE1 = "/clique"
SlashCmdList["CLIQUE"] = function(msg, editbox)
    ShowUIPanel(CliqueConfig)
end
