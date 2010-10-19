--[[-------------------------------------------------------------------------
-- AddonCore.lua
--
-- This is a very simple, bare-minimum core for addon development. It provide
-- methods to register events, call initialization functions, and sets up the
-- localization table so it can be used elsewhere. This file is designed to be
-- loaded first, as it has no further dependencies.
--
-- Events registered:
--   * ADDON_LOADED - Watch for saved variables to be loaded, and call the
--       'Initialize' function in response.
--   * PLAYER_LOGIN - Call the 'Enable' method once the major UI elements
--       have been loaded and initialized.
-------------------------------------------------------------------------]]--

local addonName, addon = ...

-- Set global name of addon
_G[addonName] = addon

-- Set up an EMERGENCY debug mode
local EMERGENCY_DEBUG = false
if EMERGENCY_DEBUG then
    local private = {}
    for k,v in pairs(addon) do
        rawset(private, k, v)
        rawset(addon, k, nil)
    end

    setmetatable(addon, {
        __index = function(t, k)
            local value = rawget(private, k)
            print(addonName, "INDEX", k, value)
            return value
        end,
        __newindex = function(t, k, v)
            print(addonName, "NEWINDEX", k, v)
            rawset(private, k, v)
        end,
    })
end

-- Extract version information from TOC file
addon.version = GetAddOnMetadata(addonName, "Version")
if addon.version == "@project-version" then
    addon.version = "SCM"
end

-- Event registration and dispatch
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
local eventMap = {}
    
function addon:RegisterEvent(event, handler)
    assert(eventMap[event] == nil, "Attempt to re-register event: " .. tostring(event))
    eventMap[event] = handler and handler or event
    addon.eventFrame:RegisterEvent(event)
end

function addon:UnregisterEvent(event)
    assert(type(event) == "string", "Invalid argument to 'UnregisterEvent'")
    eventMap[event] = nil
    addon.eventFrame:UnregisterEvent(event)
end

addon.eventFrame:SetScript("OnEvent", function(frame, event, ...)
    local handler = eventMap[event]
    local handler_t = type(handler)
    if handler_t == "function" then
        handler(event, ...)
    elseif handler_t == "string" and addon[handler] then
        addon[handler](addon, event, ...)
    end
end)

addon:RegisterEvent("PLAYER_LOGIN", "Enable")
addon:RegisterEvent("ADDON_LOADED", function(event, ...)
    if ... == addonName then
        addon:UnregisterEvent("ADDON_LOADED")
        if type(addon["Initialize"]) == "function" then
            addon["Initialize"](addon)
        end
        
        -- If this addon was loaded-on-demand, trigger 'Enable' as well
        if IsLoggedIn() and type(addon["Enable"]) == "function" then
            addon["Enable"](addon)
        end
    end
end)

-- Localization setup
addon.L = addon.L or setmetatable({}, {
    __index = function(t, k)
        rawset(t, k, k)
        return k
    end,
    __newindex = function(t, k, v)
        if v == true then
            rawset(t, k, k)
        else
            rawset(t, k, v)
        end
    end,
})

function addon:RegisterLocale(locale, tbl)
    if locale == "enUS" or locale == GetLocale() then
        for k,v in pairs(tbl) do
            self.L[k] = v
        end
    end
end

-- Debug messages
addon.debug = false
