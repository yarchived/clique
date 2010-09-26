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
    -- Compatability with old Clique 1.x registrations
    if not ClickCastFrames then
        ClickCastFrames = {}
    else
        local oldClickCastFrames = ClickCastFrames
        ClickCastFrames = setmetatable({}, {__newindex = function(t, k, v)
            if v == nil then
                self:UnregisterFrame(k)
            else
                self:RegisterFrame(k, v)
            end
        end})

        -- Iterate over the frames that were set before we arrived
        for frame, options in pairs(oldClickCastFrames) do
            self:RegisterFrame(frame, options)
        end
    end

    -- Registration for group headers (in-combat safe)
    addon.header = CreateFrame("Frame", addonName .. "HeaderFrame", UIParent, "SecureHandlerBaseTemplate")
    ClickCastHeader = addon.header

    addon.header:SetAttribute("clickcast_onenter", [===[
        local header = self:GetParent():GetFrameRef("clickcast_header")
        header:RunAttribute("setup_onenter", self:GetName())
    ]===])

    addon.header:SetAttribute("clickcast_onleave", [===[
        local header = self:GetParent():GetFrameRef("clickcast_header")
        header:RunAttribute("setup_onleave", self:GetName())
    ]===])

    addon.header:SetAttribute("clickcast_register", [===[
        local button = self:GetAttribute("clickcast_button")
        print("Registering ", button, " for clickcasting")
        button:SetAttribute("clickcast_onenter", self:GetAttribute("clickcast_onenter"))
        button:SetAttribute("clickcast_onleave", self:GetAttribute("clickcast_onleave"))
    ]===])
end

function addon:Enable()
    print("Addon " .. addonName .. " enabled")
    -- Make the options window a pushable panel window
    UIPanelWindows["CliqueConfig"] = {
        area = "left",
        pushable = 1,
        whileDead = 1,
    }

    self:InitializeDatabase()
end

function addon:InitializeDatabase()
    -- Force a clean database everytime
    self.profile = {
        binds = {
        },
    }
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
