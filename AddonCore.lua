local addonName, addon = ...

-- Set global name of addon
_G[addonName] = addon

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
            L[k] = v
        end
    end
end

-- Debug messages
addon.debug = false
