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
        binds = {},
    }
end

SLASH_CLIQUE1 = "/clique"
SlashCmdList["CLIQUE"] = function(msg, editbox)
    ShowUIPanel(CliqueConfig)
end
