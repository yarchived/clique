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
--    * hovercast - These bindings will be available whenever you are over
--      a unit frame, or a unit in the 3D world.
--    * global - These bindings will be always available. They
--      do not specify a target for the action, so if the action requires
--      a target, you must specify it after performing the binding.
--
--  The click-sets layer on each other, with the 'default' click-set
--  being at the bottom, and any other click-set being layered on top.
--  Clique will detect any conflicts that you have other than with
--  default bindings, and will warn you of the situation.
-------------------------------------------------------------------]]--

local addonName, addon = ...
local L = addon.L 

function addon:Initialize()
    -- Create an AceDB, but it needs to be cleared first
    self.db = LibStub("AceDB-3.0"):New("CliqueDB3", self.defaults)
    self.db.RegisterCallback(self, "OnNewProfile", "OnNewProfile")
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")

    self.settings = self.db.char
    self.bindings = self.db.profile.bindings
    
    self.ccframes = {}
    self.hccframes = {}

    -- Registration for group headers (in-combat safe)
    self.header = CreateFrame("Frame", addonName .. "HeaderFrame", UIParent, "SecureHandlerBaseTemplate")
    ClickCastHeader = addon.header

    -- Create a secure action button that can be used for 'hovercast' and 'global'
    self.globutton = CreateFrame("Button", addonName .. "SABButton", UIParent, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")

    -- Create a table within the addon header to store the frames
    -- that are registered for click-casting
    self.header:Execute([[
        ccframes = table.new()
    ]])

    -- Create a table within the addon header to store the frame bakcklist
    self.header:Execute([[
        blacklist = table.new()
    ]])
    self:UpdateBlacklist()

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

    self.header:SetScript("OnAttributeChanged", function(frame, name, value)
        if name == "clickcast_button" and type(value) ~= nil then
            self.hccframes[value] = true
        end
    end)

    local set, clr = self:GetBindingAttributes()
    self.header:SetAttribute("setup_onenter", set)
    self.header:SetAttribute("setup_onleave", clr)

    -- Get the override binding attributes for the global click frame
    self.globutton.setup, self.globutton.remove = self:GetClickAttributes(true)
    self.globutton.setbinds, self.globutton.clearbinds = self:GetBindingAttributes(true)

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
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "EnteringCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "LeavingCombat")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "TalentGroupChanged")

    -- Handle combat watching so we can change ooc based on party combat status
    addon:UpdateCombatWatch()

    -- Trigger a 'TalentGroupChanged' so we end up on the right profile
    addon:TalentGroupChanged()
    addon:UpdateEverything()
end

-- This function may be called during combat. When that is the case, the
-- request must be queued until combat ends, and then we can attempt to
-- register those frames. This is mainly due to integration with the
-- Blizzard raid frames, which we cannot 'register' while in combat.
--
-- TODO: There may be a way, with a handle to the blizzard headers to
-- find these new frames within a secure snippet, but I'm not sure how
-- that would be possible
addon.regqueue = {}
function addon:RegisterFrame(button)
    if InCombatLockdown() then
        table.insert(self.regqueue, button)
        return
    end

    self.ccframes[button] = true

    if self.settings.downclick then
        button:RegisterForClicks("AnyDown")
    else
        button:RegisterForClicks("AnyUp")
    end

    -- Wrap the OnEnter/OnLeave scripts in order to handle keybindings
    addon.header:WrapScript(button, "OnEnter", addon.header:GetAttribute("setup_onenter"))
    addon.header:WrapScript(button, "OnLeave", addon.header:GetAttribute("setup_onleave"))

    -- Set the attributes on the frame
    self.header:SetFrameRef("cliquesetup_button", button)
    self.header:Execute(self.header:GetAttribute("setup_clicks"), button)
end

function addon:Enable()
    -- Make the options window a pushable panel window
    UIPanelWindows["CliqueConfig"] = {
        area = "left",
        pushable = 1,
        whileDead = 1,
    }

    -- Set the tooltip for the spellbook tab
    CliqueSpellTab.tooltip = L["Clique binding configuration"]
end

-- A new profile is being created in the db, called 'profile'
function addon:OnNewProfile(event, db, profile)
    table.insert(db.profile.bindings, {
        key = "BUTTON1",
        type = "target",
        unit = "mouseover",
        sets = {
            default = true
        },
    })
    table.insert(db.profile.bindings, {
        key = "BUTTON2",
        type = "menu",
        sets = {
            default = true
        },
    })
    self.bindings = db.profile.bindings
end

function addon:OnProfileChanged(event, db, newProfile)
    self.bindings = db.profile.bindings
    self:UpdateEverything() 
end

local function ATTR(prefix, attr, suffix, value)
    local fmt = [[button:SetAttribute("%s%s%s%s%s", %q)]]
    return fmt:format(prefix, #prefix > 0 and "-" or "", attr, tonumber(suffix) and "" or "-", suffix, value)  
end

local function REMATTR(prefix, attr, suffix, value)
    local fmt = [[button:SetAttribute("%s%s%s%s%s", nil)]]
    return fmt:format(prefix, #prefix > 0 and "-" or "", attr, tonumber(suffix) and "" or "-", suffix)  
end

-- A sort function that determines in what order bindings should be applied.
-- This function should be treated with care, it can drastically change behavior

local function ApplicationOrder(a, b)
    local acnt, bcnt = 0, 0
    for k,v in pairs(a.sets) do acnt = acnt + 1 end
    for k,v in pairs(b.sets) do bcnt = bcnt + 1 end

    -- Force out-of-combat clicks to take the HIGHEST priority
    if a.sets.ooc and not b.sets.ooc then
        return false
    elseif a.sets.ooc and b.sets.ooc then
        return bcnt < acnt
    end

    -- Try to give any 'default' clicks LOWEST priority
    if a.sets.default and not b.sets.default then
        return true
    elseif a.sets.default and b.sets.default then
        return acnt < bcnt
    end
end

-- This function will create an attribute that when run for a given frame
-- will set the correct set of SAB attributes.
function addon:GetClickAttributes(global)
    local bits = {
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    local rembits = {
        "local setupbutton = self:GetFrameRef('cliquesetup_button')",
        "local button = setupbutton or self",
    }

    -- Global attributes are never blacklisted
    if not global then
        bits[#bits + 1] = "local name = button:GetName()"
        bits[#bits + 1] = "if blacklist[name] then return end"

        rembits[#rembits + 1] = "local name = button:GetName()"
        rembits[#rembits + 1] = "if blacklist[name] then return end"
    end

    table.sort(self.bindings, ApplicationOrder)

    for idx, entry in ipairs(self.bindings) do
        if self:ShouldSetBinding(entry, global) then
            local prefix, suffix = addon:GetBindingPrefixSuffix(entry)

            -- Set up help/harm bindings. The button value will be either a number, 
            -- in the case of mouse buttons, otherwise it will be a string of
            -- characters. Harmbuttons work alongside modifiers, so we need to include
            -- then in the remapping. 

            if entry.sets.friend then
                local newbutton = "friend" .. suffix
                bits[#bits + 1] = ATTR(prefix, "helpbutton", suffix, newbutton)
                suffix = newbutton
            elseif entry.sets.enemy then
                local newbutton = "enemy" .. suffix
                bits[#bits + 1] = ATTR(prefix, "harmbutton", suffix, newbutton)
                suffix = newbutton
            end

            -- Give globutton the 'mouseover' unit as target when using the 'hovercast'
            -- binding set, as opposed to the global set.
            if entry.sets.hovercast then
                bits[#bits + 1] = ATTR(prefix, "unit", suffix, "mouseover")
                rembits[#rembits + 1] = REMATTR(prefix, "unit", suffix)
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

function addon:GetBindingAttributes(global)
    local set = {
    }
    local clr = {
    }

    if not global then
        set = {
            "local button = self",
            "local name = button:GetName()",
            "if blacklist[name] then return end",
        }
        clr = {
            "local button = self",
            "local name = button:GetName()",
            "if blacklist[name] then return end",
        }
    end

    for idx, entry in ipairs(self.bindings) do
        if self:ShouldSetBinding(entry, global) then 
            if not entry.key:match("BUTTON%d+$") then
                -- This is a key binding, so we need a binding for it
                
                local prefix, suffix = addon:GetBindingPrefixSuffix(entry)
                local key = entry.key

                if key == "DASH" then
                    key = "-"
                end

                set[#set + 1] = B_SET:format(key, suffix)
                clr[#clr + 1] = B_CLR:format(key)
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
    if InCombatLockdown() then
        return false
    end

    -- TODO: Check to see if the new binding conflicts with an existing binding
    -- TODO: Validate the entry to ensure it has the correct arguments, etc.

    if not entry.sets then
        entry.sets = {default = true}
    end

    table.insert(self.bindings, entry)
    self:UpdateAttributes()
    return true
end

local function bindingeq(a, b)
    assert(type(a) == "table", "Error during deletion comparison")
    assert(type(b) == "table", "Error during deletion comparison")

    if a.type ~= b.type then
        return false
    elseif a.type == "target" then
        return a.key == b.key
    elseif a.type == "menu" then
        return a.key == b.key
    elseif a.type == "spell" then
        return a.spell == b.spell and a.key == b.key
    elseif a.type == "macro" then
        return a.macrotext == b.macrotext and a.key == b.key
    end

    return false
end

function addon:DeleteBinding(entry)
    if InCombatLockdown() then
        return false
    end

    -- Look for an entry that matches the given binding and remove it
    for idx, bind in ipairs(self.bindings) do
        if bindingeq(entry, bind) then
            -- Found the entry that matches, so remove it
            table.remove(self.bindings, idx)
            break
        end
    end

    -- Update the attributes
    self:UpdateAttributes()
    self:UpdateGlobalAttributes()
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

    -- Update global attributes
    self:UpdateGlobalAttributes()

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

function addon:ClearGlobalAttributes()
    local globutton = self.globutton
    globutton:Execute(globutton.remove)
    globutton:Execute(globutton.clearbinds)
end

-- Update the global click attributes
function addon:UpdateGlobalAttributes()
    local globutton = self.globutton

    self:ClearGlobalAttributes()

    -- Get the override binding attributes for the global click frame
    globutton.setup, globutton.remove = self:GetClickAttributes(true)
    globutton.setbinds, globutton.clearbinds = self:GetBindingAttributes(true)
    globutton:Execute(globutton.setup)
    globutton:Execute(globutton.setbinds)
end

function addon:TalentGroupChanged()
    local currentProfile = self.db:GetCurrentProfile()
    local newProfile

    -- Determine which profile to set, based on talent group
    self.talentGroup = GetActiveTalentGroup()
    if self.talentGroup == 1 and self.settings.pri_profileKey then
        newProfile = self.settings.pri_profileKey
    elseif self.talentGroup == 2 and self.settings.sec_profileKey then
        newProfile = self.settings.sec_profileKey
    end

    if newProfile ~= currentProfile and type(newProfile) == "string" then
        self.db:SetProfile(newProfile)
    end

    self:UpdateEverything()
end

function addon:UpdateCombatWatch()
    if self.settings.fastooc then
        self:RegisterEvent("UNIT_FLAGS", "CheckPartyCombat")
    else
        self:UnregisterEvent("UNIT_FLAGS")
    end
end

function addon:UpdateBlacklist()
    local bits = {
        "blacklist = table.wipe(blacklist)",
    }

    for frame, value in pairs(self.settings.blacklist) do
        if not not value then
            bits[#bits + 1] = string.format("blacklist[%q] = true", frame)
        end
    end

    addon.header:Execute(table.concat(bits, ";\n"))
end

function addon:EnteringCombat()
    addon:UpdateAttributes()
    addon:UpdateGlobalAttributes()
end

function addon:LeavingCombat()
    self.partyincombat = false

    -- Sanity check
    if not InCombatLockdown() then
        for idx, button in ipairs(self.regqueue) do
            self:RegisterFrame(button)
        end

        if #self.regqueue > 0 then
            self.regqueue = {}
        end
    end

    self:UpdateAttributes()
    self:UpdateGlobalAttributes()
end

function addon:CheckPartyCombat(event, unit)
    if InCombatLockdown() or not unit then return end
    if self.settings.fastooc then
        if UnitInParty(unit) or UnitInRaid(unit) then
            if UnitAffectingCombat(unit) == 1 then
                -- Trigger pre-combat switch for fastooc
                self.partyincombat = true
                self.combattrigger = UnitGUID(unit)
                addon:UpdateAttributes()
                addon:UpdateGlobalAttributes()
            elseif self.partyincombat then
                -- The unit is out of combat, so try to clear our flag
                if self.combattrigger == UnitGUID(unit) then
                    self.partyincombat = false
                    addon:UpdateAttributes()
                    addon:UpdateGlobalAttributes()
                end
            end
        end
    end
end

function addon:UpdateEverything()
    -- Update all running attributes and windows (block)
    addon:UpdateAttributes()
    addon:UpdateGlobalAttributes()
    addon:UpdateOptionsPanel()
    CliqueConfig:UpdateList()
end

SLASH_CLIQUE1 = "/clique"
SlashCmdList["CLIQUE"] = function(msg, editbox)
    if SpellBookFrame:IsVisible() then
        CliqueConfig:ShowWithSpellBook()
    else
        ShowUIPanel(CliqueConfig)
    end
end
