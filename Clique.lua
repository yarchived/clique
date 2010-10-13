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
    self.hccframes = {}

    -- Registration for group headers (in-combat safe)
    self.header = CreateFrame("Frame", addonName .. "HeaderFrame", UIParent, "SecureHandlerBaseTemplate")
    ClickCastHeader = addon.header

    -- Create a secure action button that can be used for 'global' bindings
    self.globutton = CreateFrame("Button", addonName .. "SABButton", UIParent, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    self.globutton:SetAttribute("unit", "mouseover")

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

    -- Trigger a profile change, updating all attributes
    self:ChangeProfile()

    -- Register for combat events to ensure we can swap between the two states
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "EnteringCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "LeavingCombat")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", function()
        self:ChangeProfile()
    end)
    -- Handle combat watching so we can change ooc based on party combat status
    addon:UpdateCombatWatch()
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
    -- Make the options window a pushable panel window
    UIPanelWindows["CliqueConfig"] = {
        area = "left",
        pushable = 1,
        whileDead = 1,
    }

    -- Set the tooltip for the spellbook tab
    CliqueSpellTab.tooltip = L["Clique binding configuration"]
end

-- Leave CliqueDB in place for now, to ease any migration that users might have.
-- Instead use CliqueDB2 for the active database and use versioning to move
-- forward from this point. The database consists of two sections:
--   * settings - used to handle the basic options Clique uses
--   * profiles - used for the binding configuration profiles, possibly shared
local current_db_version = 6
function addon:InitializeDatabase()
    local realmKey = GetRealmName()
    local charKey = UnitName("player") .. " - " .. realmKey
    addon.staticProfileKey = charKey

    local reset = false
    if not CliqueDB2 then
        reset = true
    elseif CliqueDB2.dbversion == 5 then
        if not CliqueDB2.settings or CliqueDB2.settings[charKey] then
            reset = true
        else
            -- Upgrade to add the blacklist table to settings
            CliqueDB2.settings[charKey].blacklist = {}
        end
        CliqueDB2.dbversion = current_db_version
    elseif CliqueDB2.dbversion ~= current_db_version then
        reset = true
    end

    if reset then
        CliqueDB2 = {
            settings = {},
            bindings = {},
            dbversion = current_db_version,
        }
    end
    
    local db = CliqueDB2

    addon.db = db
    if not db.settings[charKey] then
        db.settings[charKey] = {
            profileKey = charKey,
            blacklist = {},
            blizzframes = {
                PlayerFrame = true,
                PetFrame = true,
                TargetFrame = true,
                TargetFrameToT = true,
                FocusFrame = true,
                FocusFrameToT = true,
                arena = true,
                party = true,
                compactraid = true,
                compactparty = true,
                boss = true,
            },
        }
    end

    addon.settings = db.settings[charKey]
    self:InitializeBindingProfile()
end

function addon:InitializeBindingProfile()
    local db = CliqueDB2
    if not db.bindings[addon.settings.profileKey] then
        db.bindings[addon.settings.profileKey] = {
            [1] = {
                key = "BUTTON1",
                type = "target",
                unit = "mouseover",
                sets = {
                    default = true
                },
            },
            [2] = {
                key = "BUTTON2",
                type = "menu",
                sets = {
                    default = true
                },
            },
        }
    end

    self.bindings = db.bindings[addon.settings.profileKey] 
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

                set[#set + 1] = B_SET:format(entry.key, suffix)
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
    for idx, bind in ipairs(self.bindings) do
        if bindingeq(entry, bind) then
            -- Found the entry that matches, so remove it
            table.remove(self.bindings, idx)
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

function addon:ChangeProfile(profileName)
    -- Clear the current profile
    addon:ClearAttributes()
    addon:ClearGlobalAttributes()

    -- Check to see if this is a force-create of a new profile
    if type(profileName) == "string" and #profileName > 0 then
        -- Do nothing
    else
        -- Determine which profile to set, based on talent group
        self.talentGroup = GetActiveTalentGroup()
        if self.talentGroup == 1 and self.settings.pri_profileKey then
            profileName = self.settings.pri_profileKey
        elseif self.talentGroup == 2 and self.settings.sec_profileKey then
            profileName = self.settings.sec_profileKey
        end

        if type(profileName) == "string" and addon.db.bindings[profileName] then
            -- Do nothing
        else
            profileName = addon.staticProfileKey
        end
    end

    -- We've been given a profile name, so just change to it
    addon.settings.profileKey = profileName
    addon:InitializeBindingProfile()
    addon:UpdateAttributes()
    addon:UpdateGlobalAttributes()
    addon:UpdateOptionsPanel()

    CliqueConfig:UpdateList()
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
    addon:UpdateAttributes()
    addon:UpdateGlobalAttributes()
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

SLASH_CLIQUE1 = "/clique"
SlashCmdList["CLIQUE"] = function(msg, editbox)
    if SpellBookFrame:IsVisible() then
        CliqueConfig:ShowWithSpellBook()
    else
        ShowUIPanel(CliqueConfig)
    end
end
