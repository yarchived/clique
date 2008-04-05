--[[---------------------------------------------------------------------------------
  Clique by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------------]]

Clique = {Locals = {}}

assert(DongleStub, string.format("Clique requires DongleStub."))
DongleStub("Dongle-1.1"):New("Clique", Clique)
Clique.version = GetAddOnMetadata("Clique", "Version")
if Clique.version == "wowi:revision" then Clique.version = "SVN" end

local L = Clique.Locals

function Clique:Initialize()
end

function Clique:Enable()
	-- Grab the localisation header
	L = Clique.Locals
	self.ooc = {}

	self.defaults = {
		profile = {
			clicksets = {
				[L.CLICKSET_DEFAULT] = {},
				[L.CLICKSET_HARMFUL] = {},
				[L.CLICKSET_HELPFUL] = {},
				[L.CLICKSET_OOC] = {},
			},
			blacklist = {
			},
			tooltips = false,
		}
	}
	
	self.db = self:InitializeDB("CliqueDB", self.defaults)
	self.profile = self.db.profile
	self.clicksets = self.profile.clicksets

    self.editSet = self.clicksets[L.CLICKSET_DEFAULT]

	ClickCastFrames = ClickCastFrames or {}
	self.ccframes = ClickCastFrames

    local newindex = function(t,k,v)
		if v == nil then
			Clique:UnregisterFrame(k)
			rawset(self.ccframes, k, nil)
		else
			Clique:RegisterFrame(k)
			rawset(self.ccframes, k, v)
		end
    end
    
	ClickCastFrames = setmetatable({}, {__newindex=newindex})

    Clique:OptionsOnLoad()
    Clique:EnableFrames()

	-- Register for dongle events
	self:RegisterMessage("DONGLE_PROFILE_CHANGED")
	self:RegisterMessage("DONGLE_PROFILE_DELETED")
	self:RegisterMessage("DONGLE_PROFILE_RESET")

	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	self:RegisterEvent("LEARNED_SPELL_IN_TAB")

	self:UpdateClicks()

    -- Register all frames that snuck in before we did =)
    for frame in pairs(self.ccframes) do
		self:RegisterFrame(frame)
    end

    -- Securehook CreateFrame to catch any new raid frames
    local raidFunc = function(type, name, parent, template)
		if template == "RaidPulloutButtonTemplate" then
			ClickCastFrames[getglobal(name.."ClearButton")] = true
		end
	end

	local oldotsu = GameTooltip:GetScript("OnTooltipSetUnit")
	if oldotsu then
		GameTooltip:SetScript("OnTooltipSetUnit", function(...)
			Clique:AddTooltipLines()
			return oldotsu(...)
		end)
	else
		GameTooltip:SetScript("OnTooltipSetUnit", function(...)
			Clique:AddTooltipLines()
		end)
	end
		
    hooksecurefunc("CreateFrame", raidFunc)

	-- Create our slash command
	self.cmd = self:InitializeSlashCommand("Clique commands", "CLIQUE", "clique")
	self.cmd:RegisterSlashHandler("debug - Enables extra messages for debugging purposes", "debug", "ShowAttributes")
	self.cmd:InjectDBCommands(self.db, "copy", "delete", "list", "reset", "set")
	self.cmd:RegisterSlashHandler("tooltip - Enables binding lists in tooltips.", "tooltip", "ToggleTooltip")

	-- Place the Clique tab
	self:LEARNED_SPELL_IN_TAB()
end

function Clique:EnableFrames()
    local tbl = {
		PlayerFrame,
		PetFrame,
		PartyMemberFrame1,
		PartyMemberFrame2,
		PartyMemberFrame3,
		PartyMemberFrame4,
		PartyMemberFrame1PetFrame,
		PartyMemberFrame2PetFrame,
		PartyMemberFrame3PetFrame,
		PartyMemberFrame4PetFrame,
		TargetFrame,
		TargetofTargetFrame,
    }
    
    for i,frame in pairs(tbl) do
		rawset(self.ccframes, frame, true)
    end
end	   

function Clique:SpellBookButtonPressed(frame, button)
    local id = SpellBook_GetSpellID(this:GetParent():GetID());
    local texture = GetSpellTexture(id, SpellBookFrame.bookType)
    local name, rank = GetSpellName(id, SpellBookFrame.bookType)

    if rank == L.RACIAL_PASSIVE or rank == L.PASSIVE then
		StaticPopup_Show("CLIQUE_PASSIVE_SKILL")
		return
    end
    
    local type = "spell"

	if self.editSet == self.clicksets[L.CLICKSET_HARMFUL] then
		button = string.format("%s%d", "harmbutton", self:GetButtonNumber(button))
	elseif self.editSet == self.clicksets[L.CLICKSET_HELPFUL] then
		button = string.format("%s%d", "helpbutton", self:GetButtonNumber(button))
	else
		button = self:GetButtonNumber(button)
	end
    
    -- Build the structure
    local t = {
		["button"] = button,
		["modifier"] = self:GetModifierText(),
		["texture"] = GetSpellTexture(id, SpellBookFrame.bookType),
		["type"] = type,
		["arg1"] = name,
		["arg2"] = rank,
    }
    
    local key = t.modifier .. t.button
    
    if self:CheckBinding(key) then
		StaticPopup_Show("CLIQUE_BINDING_PROBLEM")
	return
    end
    
    self.editSet[key] = t
    self:ListScrollUpdate()
	self:UpdateClicks()
	-- We can only make changes when out of combat
	self:PLAYER_REGEN_ENABLED()
end

function Clique:PLAYER_REGEN_ENABLED()
	self:ApplyClickSet(L.CLICKSET_DEFAULT)
	self:RemoveClickSet(L.CLICKSET_HARMFUL)
	self:RemoveClickSet(L.CLICKSET_HELPFUL)
	self:ApplyClickSet(self.ooc)
end

function Clique:PLAYER_REGEN_DISABLED()
	self:RemoveClickSet(self.ooc)
	self:ApplyClickSet(L.CLICKSET_DEFAULT)
	self:ApplyClickSet(L.CLICKSET_HARMFUL)
	self:ApplyClickSet(L.CLICKSET_HELPFUL)
end

function Clique:UpdateClicks()
	local ooc = self.clicksets[L.CLICKSET_OOC]
	local harm = self.clicksets[L.CLICKSET_HARMFUL]
	local help = self.clicksets[L.CLICKSET_HELPFUL]

	self.ooc = self.ooc or {}
	for k,v in pairs(self.ooc) do self.ooc[k] = nil end

	for modifier,entry in pairs(harm) do
		local button = string.gsub(entry.button, "harmbutton", "")
		button = tonumber(button)
		local mask = false

		for k,v in pairs(ooc) do
 			if button == v.button and v.modifier == entry.modifier then
				mask = true
			end
		end

		if not mask then
			table.insert(self.ooc, entry)
		end
	end

	for modifier,entry in pairs(help) do
		local button = string.gsub(entry.button, "helpbutton", "")
		button = tonumber(button)
		local mask = false

		for k,v in pairs(ooc) do
 			if button == v.button and v.modifier == entry.modifier then
				mask = true
			end
		end

		if not mask then
			table.insert(self.ooc, entry)
		end
	end

	for modifier,entry in pairs(ooc) do
		table.insert(self.ooc, entry)
	end
	
	self:UpdateTooltip()
end

function Clique:RegisterFrame(frame)
	local name = frame:GetName()

	if self.profile.blacklist[name] then 
		rawset(self.ccframes, frame, false)
		return 
	end

	if not ClickCastFrames[frame] then 
		rawset(self.ccframes, frame, true)
		if CliqueTextListFrame then
			Clique:TextListScrollUpdate()
		end
	end

	frame:RegisterForClicks("AnyUp")

	if frame:CanChangeProtectedState() then
		if InCombatLockdown() then
			self:ApplyClickSet(L.CLICKSET_DEFAULT, frame)
			self:ApplyClickSet(L.CLICKSET_HOSTILE, frame)
			self:ApplyClickSet(L.CLICKSET_HARMFUL, frame)
		else
			self:ApplyClickSet(L.CLICKSET_DEFAULT, frame)
			self:ApplyClickSet(self.ooc, frame)
		end
	end
end

function Clique:ApplyClickSet(name, frame)
	local set = self.clicksets[name] or name

	if frame then
		for modifier,entry in pairs(set) do
			self:SetAttribute(entry, frame)
		end
	else
		for modifier,entry in pairs(set) do
			self:SetAction(entry)
		end
	end					
end

function Clique:RemoveClickSet(name, frame)
	local set = self.clicksets[name] or name

	if frame then
		for modifier,entry in pairs(set) do
			self:DeleteAttribute(entry, frame)
		end
	else
		for modifier,entry in pairs(set) do
			self:DeleteAction(entry)
		end
	end					
end

function Clique:UnregisterFrame(frame)
	assert(not InCombatLockdown(), "An addon attempted to unregister a frame from Clique while in combat.")
	for name,set in pairs(self.clicksets) do
		for modifier,entry in pairs(set) do
			self:DeleteAttribute(entry, frame)
		end
	end
end

function Clique:DONGLE_PROFILE_CHANGED(event, db, parent, svname, profileKey)
	if db == self.db then
		self:PrintF(L.PROFILE_CHANGED, profileKey)

		for name,set in pairs(self.clicksets) do
			self:RemoveClickSet(set)
		end
		self:RemoveClickSet(self.ooc)

		self.profile = self.db.profile
		self.clicksets = self.profile.clicksets
		self.editSet = self.clicksets[L.CLICKSET_DEFAULT]
		self.profileKey = profileKey
	
		-- Refresh the profile editor if it exists
		self.textlistSelected = nil
		self:TextListScrollUpdate()
		self:ListScrollUpdate()
		self:UpdateClicks()

		self:PLAYER_REGEN_ENABLED()
	end
end

function Clique:DONGLE_PROFILE_RESET(event, db, parent, svname, profileKey)
	if db == self.db then
		for name,set in pairs(self.clicksets) do
			self:RemoveClickSet(set)
		end
		self:RemoveClickSet(self.ooc)

		self.profile = self.db.profile
		self.clicksets = self.profile.clicksets
		self.editSet = self.clicksets[L.CLICKSET_DEFAULT]
		self.profileKey = profileKey
	
		-- Refresh the profile editor if it exists
		self.textlistSelected = nil
		self:TextListScrollUpdate()
		self:ListScrollUpdate()
		self:UpdateClicks()

		self:PLAYER_REGEN_ENABLED()
		self:Print(L.PROFILE_RESET, profileKey)
	end
end


function Clique:DONGLE_PROFILE_DELETED(event, db, parent, svname, profileKey)
	if db == self.db then
		self:PrintF(L.PROFILE_DELETED, profileKey)
	
		self.textlistSelected = nil
		self:TextListScrollUpdate()
		self:ListScrollUpdate()
	end
end

function Clique:SetAttribute(entry, frame)
	local name = frame:GetName()

	if	self.profile.blacklist and self.profile.blacklist[name] then
		return
	end

	-- Set up any special attributes
	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		frame:SetAttribute(entry.modifier..entry.button, type..button)
		assert(frame:GetAttribute(entry.modifier..entry.button, type..button))
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	if entry.type == "actionbar" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)		
	elseif entry.type == "action" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		if entry.arg2 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
		end
	elseif entry.type == "pet" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		if entry.arg2 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
		end
	elseif entry.type == "spell" then
		local rank = entry.arg2
		local cast
		if rank then
			if tonumber(rank) then
				-- The rank is a number (pre-2.3) so fill in the format
				cast = L.CAST_FORMAT:format(entry.arg1, rank)
			else
				-- The whole rank string is saved (post-2.3) so use it
				cast = string.format("%s(%s)", entry.arg1, rank)
			end
		else
			cast = entry.arg1
		end

		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."spell"..button, cast)

		frame:SetAttribute(entry.modifier.."bag"..button, entry.arg2)
		frame:SetAttribute(entry.modifier.."slot"..button, entry.arg3)
		frame:SetAttribute(entry.modifier.."item"..button, entry.arg4)
		if entry.arg5 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg5)
		end
	elseif entry.type == "item" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."bag"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."slot"..button, entry.arg2)
		frame:SetAttribute(entry.modifier.."item"..button, entry.arg3)
		if entry.arg4 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg4)
		end
	elseif entry.type == "macro" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."macro"..button, entry.arg1)
		else
			local unit = SecureButton_GetModifiedUnit(frame, entry.modifier.."unit"..button)
			local macro = tostring(entry.arg2)
			if unit and macro then
				macro = macro:gsub("target%s*=%s*clique", "target="..unit)
			end

			frame:SetAttribute(entry.modifier.."macro"..button, nil)
			frame:SetAttribute(entry.modifier.."macrotext"..button, macro)
		end
	elseif entry.type == "stop" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	elseif entry.type == "target" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "focus" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "assist" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "click" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."clickbutton"..button, getglobal(entry.arg1))
	elseif entry.type == "menu" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	end
end

function Clique:DeleteAttribute(entry, frame)
	local name = frame:GetName()
	if	self.profile.blacklist and self.profile.blacklist[name] then
		return
	end

	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		frame:SetAttribute(entry.modifier..entry.button, nil)
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	entry.delete = true

	frame:SetAttribute(entry.modifier.."type"..button, nil)
	frame:SetAttribute(entry.modifier..entry.type..button, nil)
end

function Clique:SetAction(entry)
	for frame,enabled in pairs(self.ccframes) do
		if enabled then
			self:SetAttribute(entry, frame)
		end
	end
end

function Clique:DeleteAction(entry)
	for frame in pairs(self.ccframes) do
		self:DeleteAttribute(entry, frame)
	end
end

local mods = {"Shift", "Ctrl", "Alt"}
local buttonsraw = {1,2,3,4,5}
local buttonmods = {"-help", "-harm"}

local buttons = {}
for idx,button in pairs(buttonsraw) do
	for k,v in pairs(buttonmods) do
		table.insert(buttons, v..button)
	end
end
for k,v in pairs(buttonsraw) do
	table.insert(buttons, v)
end

--collectgarbage("setpause", 100)
--collectgarbage("setstepmul", 2000)

--[[
local tbl = {}

local min 
local max
local elapsed = 0
local frame = CreateFrame("Frame", "gctest")
frame:SetScript("OnUpdate", function(f, t)
	elapsed = elapsed + t
	if elapsed >= 0.3 then
		local count = collectgarbage("count")
		if not min then
			min = count
			max = count
		end
	
		if count > max then max = count end
		if count < min then min = count end
		Clique:Print(string.format("%2.f (min %2.f, max %2.f)", count, min, max), count < max and "Cycle" or "")
		elapsed = 0
		for i=1,500 do
			table.insert(tbl, {1,2,3,4,5})
		end
		tbl = {}
	end
end)
--]]

-- pause, mul
-- 100,200
-- min: 16096
-- max: 20993
-- cycle: 19794

-- 100,500
-- min: 16096
-- max: 18292
-- cycle: 16500

-- 100,1000
-- min: 16095
-- max: 17225
-- cycle: 16500

-- 100,2000
-- min: 16095
-- max: 16722
-- cycle: 16300

-- Default Settings
-- min: 16095
-- max: 36114
-- cycle: 18600

-- 100 pause, default mult
-- min: 16095
-- max: 20052
-- cycle: 17857

function Clique:ShowAttributes()
	self:Print("Enabled enhanced debugging.")
	PlayerFrame:SetScript("OnAttributeChanged", function(...) self:Print(...) end)
	self:UnregisterFrame(PlayerFrame)
	self:RegisterFrame(PlayerFrame)
end

local tt_ooc = {}
local tt_help = {}
local tt_harm = {}
local tt_default = {}

function Clique:UpdateTooltip()
	local ooc = self.ooc
	local default = self.clicksets[L.CLICKSET_DEFAULT]
	local harm = self.clicksets[L.CLICKSET_HARMFUL]
	local help = self.clicksets[L.CLICKSET_HELPFUL]

	-- Build the ooc lines, which includes both helpful and harmful
	for k,v in pairs(ooc) do
		local button = self:GetButtonText(v.button)
		local line = string.format("%s%s - %s (%s)", v.modifier or "", button, v.arg1 or "", v.type)
		table.insert(tt_ooc, line)
	end

	-- Build the default lines
	for k,v in pairs(default) do
		local button = self:GetButtonText(v.button)
		local line = string.format("%s%s - %s (%s)", v.modifier or "", button, v.arg1 or "", v.type)
		table.insert(tt_default, line)
	end

	-- Build the harm lines
	for k,v in pairs(harm) do
		local button = self:GetButtonText(v.button)
		local line = string.format("%s%s - %s (%s)", v.modifier or "", button, v.arg1 or "", v.type)
		table.insert(tt_harm, line)
	end

	-- Build the help lines
	for k,v in pairs(help) do
		local button = self:GetButtonText(v.button)
		local line = string.format("%s%s - %s (%s)", v.modifier or "", button, v.arg1 or "", v.type)
		table.insert(tt_help, line)
	end

	table.sort(tt_ooc)
	table.sort(tt_default)
	table.sort(tt_harm)
	table.sort(tt_help)
end
	
function Clique:AddTooltipLines()
	if not self.profile.tooltips then return end

	local frame = GetMouseFocus()
	if not frame then return end
	if not self.ccframes[frame] then return end

	if UnitAffectingCombat("player") then
		if #tt_default ~= 0 then
			GameTooltip:AddLine("Default bindings:")
			for k,v in ipairs(tt_default) do
				GameTooltip:AddLine(v)
			end
		end

		if #tt_help ~= 0 and not UnitCanAttack("player", "mouseover") then
			GameTooltip:AddLine("Helpful bindings:")
			for k,v in ipairs(tt_help) do
				GameTooltip:AddLine(v)
			end
		end

		if #tt_harm ~= 0 and UnitCanAttack("player", "mouseover") then
			GameTooltip:AddLine("Hostile bindings:")
			for k,v in ipairs(tt_harm) do
				GameTooltip:AddLine(v)
			end
		end
	else
		if #tt_ooc ~= 0 then
			GameTooltip:AddLine("Out of combat bindings:")
			for k,v in ipairs(tt_ooc) do
				GameTooltip:AddLine(v)
			end
		end
	end
end

function Clique:ToggleTooltip()
	self.profile.tooltips = not self.profile.tooltips
	self:PrintF("Listing of bindings in tooltips has been %s", 
	self.profile.tooltips and "Enabled" or "Disabled")
end
 
