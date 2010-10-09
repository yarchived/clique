local addonName, addon = ...
local L = addon.L

-- Returns the prefix string for the current keyboard state. 
-- 
-- Arguments:
--   split - Whether or not to split the modifier keys into left and right components

function addon:GetPrefixString(split)
    shift, lshift, rshift = IsShiftKeyDown(), IsLeftShiftKeyDown(), IsRightShiftKeyDown()
    ctrl, lctrl, rctrl = IsControlKeyDown(), IsLeftControlKeyDown(), IsRightControlKeyDown()
    alt, lalt, ralt = IsAltKeyDown(), IsLeftAltKeyDown() IsRightAltKeyDown()

    if not extended then
        shift = shift or lshift or rshift
        ctrl = ctrl or lctrl or rctrl
        alt = alt or lalt or ralt

        lshift, rshift = false, false
        lctrl, rctrl = false, false
        lalt, ralt = false, false
    end
        
    local prefix = ""
    if shift then
        prefix = ((lshift and "LSHIFT-") or (rshift and "RSHIFT-") or "SHIFT-") .. prefix
    end
    if ctrl then
        prefix = ((lctrl and "LCTRL-") or (rctrl and "RCTRL-") or "CTRL-") .. prefix
    end
    if alt then
        prefix = ((lalt and "LALT-") or (ralt and "RALT-") or "ALT-") .. prefix
    end

    return prefix
end

local convertMap = setmetatable({
    LSHIFT = L["LShift"],
    RSHIFT = L["RShift"],
    SHIFT = L["Shift"],
    LCTRL = L["LCtrl"],
    RCTRL = L["RCtrl"],
    CTRL = L["Ctrl"],
    LALT = L["LAlt"],
    RALT = L["RAlt"],
    ALT = L["Alt"],
    BUTTON1 = L["LeftButton"],
    BUTTON2 = L["RightButton"],
    BUTTON3 = L["MiddleButton"],
    MOUSEWHEELUP = L["MousewheelUp"],
    MOUSEWHEELDOWN = L["MousewheelDown"],
}, {
    __index = function(t, k, v)
        if k:match("^BUTTON(%d+)$") then
            return k:gsub("^BUTTON(%d+)$", "Button%1")
        else
            return k:sub(1,1) .. k:sub(2, -1):lower()
        end
    end,
})

local function convert(item, ...)
    if not item then
        return ""
    else
        local mapItem = convertMap[item]
        item = mapItem and mapItem or item

        if select("#", ...) > 0 then
            return item, "-", convert(...)
        else
            return item, convert(...)
        end
    end
end

function addon:GetBindingIcon(binding)
    local btype = binding.type
    if btype == "menu" then
        --return "Interface\\Icons\\Trade_Engineering"
        return nil
    elseif btype == "target" then
        --return "Interface\\Icons\\Ability_Mage_IncantersAbsorbtion"
        return nil
    else
        return binding.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

function addon:GetBindingKeyComboText(binding)
    if type(binding) == "table" then
        return strconcat(convert(strsplit("-", binding.key))) 
    elseif type(binding) == "string" then
        return strconcat(convert(strsplit("-", binding)))
    end
end

function addon:GetBindingActionText(binding)
    local btype = type(binding) == "table" and binding.type or binding

    if btype == "menu" then
        return L["Show unit menu"]
    elseif btype == "target" then
        return L["Target clicked unit"]
    elseif btype == "spell" then
        if binding.rank then
            return L["Cast %s (Rank %d)"]:format(binding.spell, binding.rank)
        end
        return L["Cast %s"]:format(binding.spell)
    elseif btype == "macro" then
        return L["Run macro '%s'"]:format(tostring(binding.macrotext))
    else
        return L["Unknown binding type '%s'"]:format(tostring(btype))
    end
end

function addon:GetBindingKey(binding)
    local key = binding.key:match("[^%-]+$")
    return key
end

local binMap = {
    ALT = 1,
    LALT = 2,
    RALT = 3,
    CTRL = 4,
    LCTRL = 5,
    LCTRL = 6,
    SHIFT = 7,
    LSHIFT = 8,
    RSHIFT = 9,
}

function addon:GetBinaryBindingKey(binding)
    ret = {"0", "0", "0", "0", "0", "0", "0", "0", "0"}
    splits = {strsplit("-", binding.key)}
    for idx, modifier in ipairs(splits) do
        local bit = binMap[modifier]
        if bit then
            ret[bit] = "1"
        else
            ret[10] = modifier
        end
    end
    return table.concat(ret)
end

invalidKeys = {
    ["UNKNOWN"] = true,
    ["LSHIFT"] = true,
    ["RSHIFT"] = true,
    ["LCTRL"] = true,
    ["RCTRL"] = true,
    ["LALT"] = true,
    ["RALT"] = true,
    ["ESCAPE"] = true,
}

function addon:GetCapturedKey(key)
    -- We can't bind modifiers or invalid keys
    if invalidKeys[key] then
        return
    end

    -- Remap any mouse buttons
    if key == "LeftButton" then
        key = "BUTTON1"
    elseif key == "RightButton" then
        key = "BUTTON2"
    elseif key == "MiddleButton" then
        key = "BUTTON3"
    else
        buttonNum = key:match("Button(%d+)")
        if buttonNum and tonumber(buttonNum) <= 31 then
            key = "BUTTON" .. buttonNum
        end
    end

    -- TODO: Support NOT splitting the modifier keys
    local prefix = addon:GetPrefixString(true)
    return tostring(prefix) .. tostring(key)
end

function addon:GetBindingInfoText(binding)
    local sets = binding.sets
    if not sets then
        return ""
    elseif not next(sets) then
        -- No bindings set, so display a message
        return L["This binding is DISABLED"]
    else
        local bits = {}
        for k,v in pairs(sets) do
            table.insert(bits, k)
        end
        return table.concat(bits, ", ")
    end
end

function addon:GetBindingPrefixSuffix(binding)
    local prefix, suffix = binding.key:match("^(.-)([^%-]+)$")
    if prefix:sub(-1, -1) == "-" then
        prefix = prefix:sub(1, -2)
    end

    prefix = prefix:lower()

    local button = suffix:match("^BUTTON(%d+)$")
    if button then
        suffix = button
    else
        local mbid = (prefix .. suffix):gsub("[^A-Za-z0-9]", "")
        suffix = "cliquebutton" .. mbid
        prefix = ""
    end

    return prefix, suffix
end


-- This function examines the current state of the game
function addon:ShouldSetBinding(binding, global)
    local apply = false

    -- Check for global bindings first
    if binding.sets.global and global then
        apply = true
    elseif binding.sets.global and (not global) then
        apply = false
    end

    if binding.sets.enemy or binding.sets.friend and not binding.sets.global then
        apply = true
    end

    if binding.sets.ooc then
        if UnitAffectingCombat("player") then
            apply = false
        else
            apply = true
        end
    end

    if binding.sets.default then
        apply = true
    end

    return apply
end

function addon:ShouldSetBindingOnFrame(binding, frame)
end
