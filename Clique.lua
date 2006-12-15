--[[---------------------------------------------------------------------------------
  Clique by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------------]]

Clique = {Locals = {}}

DongleStub("Dongle"):New(Clique, "Clique")

local L = Clique.Locals
-- Create a frame for event registration
local eventFrame = CreateFrame("Frame")
local elapsed = 0
eventFrame:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 2.0 then 
		elapsed = 0
		Clique:ClearQueue()
	end
end)
eventFrame:Hide()
   
function Clique:Enable()
	-- Grab the localisation header
	L = Clique.Locals

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
    
    -- Register all frames that snuck in before we did =)

    Clique:OptionsOnLoad()
    Clique:EnableFrames()

    for frame in pairs(self.ccframes) do
		self:RegisterFrame(frame)
    end

	-- Define a state header for forms
	self.stateheader = CreateFrame("Frame", "CliqueStateHeader", UIParent, "SecureStateDriverTemplate")
	self.stateheader:SetAttribute("statemap-stance-0", "s0")
	self.stateheader:SetAttribute("statemap-stance-1", "s1")
	self.stateheader:SetAttribute("statemap-stance-2", "s2")
	self.stateheader:SetAttribute("statemap-stance-3", "s3")
	self.stateheader:SetAttribute("statemap-stance-4", "s4")
	self.stateheader:SetAttribute("statemap-stance-5", "s5")

	--PlayerFrame:SetAttribute("shift-statebutton1", "s0:s0;s1:s1;s2:s2;s3:s3;s4:s4;s5:s5")
--[[
	PlayerFrame:SetAttribute("shift-unit-s1", "player")
	PlayerFrame:SetAttribute("shift-type-s1", "spell")
	PlayerFrame:SetAttribute("shift-spell-s1", "Enrage")

	PlayerFrame:SetAttribute("shift-unit1", "player")
	PlayerFrame:SetAttribute("shift-type1", "spell")
	PlayerFrame:SetAttribute("shift-spell1", "Rejuvenation")

	PlayerFrame:SetAttribute("alt-type1", "spell")
	PlayerFrame:SetAttribute("alt-spell1", "Attack")
--]]

	-- Register for LEARNED_SPELL_IN_TAB
	self:RegisterEvent("LEARNED_SPELL_IN_TAB")
	self:LEARNED_SPELL_IN_TAB()

	-- Register for dongle events
	self:RegisterEvent("DONGLE_PROFILE_CHANGED")
	self:RegisterEvent("DONGLE_PROFILE_DELETED")

	-- Run the OOC script if we need to
	Clique:CombatUnlock()

    -- Securehook CreateFrame to catch any new raid frames
    local raidFunc = function(type, name, parent, template)
		if template == "RaidPulloutButtonTemplate" then
			ClickCastFrames[getglobal(name.."ClearButton")] = true
		end
	end
		 
    hooksecurefunc("CreateFrame", raidFunc)
end

function Clique:LEARNED_SPELL_IN_TAB()
	local forms = {
		[L.DIRE_BEAR_FORM] = L.CLICKSET_BEARFORM,
		[L.BEAR_FORM] = L.CLICKSET_BEARFORM,
		[L.AQUATIC_FORM] = L.CLICKSET_AQUATICFORM,
		[L.CAT_FORM] = L.CLICKSET_CATFORM,
		[L.TRAVEL_FORM] = L.CLICKSET_TRAVELFORM,
		[L.MOONKIN_FORM] = L.CLICKSET_MOONKINFORM,
		[L.TREEOFLIFE] = L.CLICKSET_TREEOFLIFE,
		[L.STEALTH] = L.CLICKSET_STEALTHED,
		[L.BATTLESTANCE] = L.CLICKSET_BATTLESTANCE,
		[L.DEFENSIVESTANCE] = L.CLICKSET_DEFENSIVESTANCE,
		[L.BERSERKERSTANCE] = L.CLICKSET_BERSERKERSTANCE,
		[L.SHADOWFORM] = L.CLICKSET_SHADOWFORM,
	}
	self.forms = forms
	local profile = self.defaults.profile

	local offset,num = select(3, GetSpellTabInfo(GetNumSpellTabs()))
	local num = num + offset

	for i=1,num do
		local name = GetSpellName(i, BOOKTYPE_SPELL)
		if forms[name] then
			--profile[name] = profile[name] or {}
			--self.profile[name] = self.profile[name] or {}
		end
	end
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
		ClickCastFrames[frame] = true
    end
end	   

function Clique:SpellBookButtonPressed()
    local id = SpellBook_GetSpellID(this:GetParent():GetID());
    local texture = GetSpellTexture(id, SpellBookFrame.bookType)
    local name, rank = GetSpellName(id, SpellBookFrame.bookType)
	    
    if rank == L.RACIAL_PASSIVE or rank == L.PASSIVE then
		StaticPopup_Show("CLIQUE_PASSIVE_SKILL")
		return
    else
		rank = select(3, string.find(rank, L.RANK_PATTERN))
		if rank then rank = tonumber(rank) end
    end
    
    local type = "spell"
	local button

	if self.editSet == self.clicksets[L.CLICKSET_HARMFUL] then
		button = string.format("%s%d", "harmbutton", self:GetButtonNumber())
	elseif self.editSet == self.clicksets[L.CLICKSET_HELPFUL] then
		button = string.format("%s%d", "helpbutton", self:GetButtonNumber())
	else
		button = self:GetButtonNumber()
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
	self:UpdateClicks()
    self:ListScrollUpdate()
end

function Clique:UpdateClicks(frame)
	for name in pairs(self.clicksets) do
		self:RemoveClickSet(name, frame)
	end

	self:ApplyClickSet(L.CLICKSET_DEFAULT, frame)
	self:ApplyClickSet(L.CLICKSET_HARMFUL, frame)
	self:ApplyClickSet(L.CLICKSET_HELPFUL, frame)
	if not InCombatLockdown() then
		self:TrimClickSet(L.CLICKSET_HARMFUL, frame)
		self:TrimClickSet(L.CLICKSET_HELPFUL, frame)
	end
	self:ApplyClickSet(L.CLICKSET_OOC, frame)
end
		
function Clique:CombatLockdown()
	self:Debug(1, "Going into combat mode")
	-- Remove all OOC clicks
	self:RemoveClickSet(L.CLICKSET_OOC)
	self:ApplyClickSet(L.CLICKSET_DEFAULT)
	self:ApplyClickSet(L.CLICKSET_HARMFUL)
	self:ApplyClickSet(L.CLICKSET_HELPFUL)
end	

function Clique:CombatUnlock()
	self:Debug(1, "Setting any out of combat clicks")
	self:ApplyClickSet(L.CLICKSET_DEFAULT)
	self:ApplyClickSet(L.CLICKSET_HARMFUL)
	self:ApplyClickSet(L.CLICKSET_HELPFUL)
	self:TrimClickSet(L.CLICKSET_HARMFUL, frame)
	self:TrimClickSet(L.CLICKSET_HELPFUL, frame)
	self:RemoveClickSet(L.CLICKSET_OOC)
end

function Clique:RegisterFrame(frame)
	local name = frame:GetName()

	-- Check to see if we can register this frame at this time
	frame:SetAttribute("Clique-test", true)
	if frame:GetAttribute("Clique-test") then
		frame:SetAttribute("Clique-test", nil)
	else
		self:Print("Cannot register frame %s", tostring(name))
	end

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

	frame:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp", "Button4Up", "Button5Up")
	self:UpdateClicks()
end

function Clique:ApplyClickSet(name, frame)
	local set = self.clicksets[name]

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
	local set = self.clicksets[name]

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

function Clique:TrimClickSet(name)
	local base = self.clicksets[L.CLICKSET_OOC]
	local set = self.clicksets[name]

	for modifier,entry in pairs(set) do
		for modifierbase,entrybase in pairs(base) do
			local button = string.format("%s%d", "harmbutton", entrybase.button)
			local button2 = string.format("%s%d", "helpbutton", entrybase.button)
			if entry.button == button or entry.button == button2 then
				self:DeleteAction(entry)
			end
		end
	end
end

function Clique:UnregisterFrame(frame)
	for name,set in pairs(self.clicksets) do
		for modifier,entry in pairs(set) do
			self:DeleteAttribute(entry, frame)
		end
	end
end

function Clique:DONGLE_PROFILE_CHANGED(event, addon, svname, name)
	if addon == "Clique" then
		self:Print(L.PROFILE_CHANGED, name)
		for name,set in pairs(self.clicksets) do
			for modifier,entry in pairs(set) do
				self:DeleteAction(entry)
			end
		end

		self.profile = self.db.profile
		self.clicksets = self.profile.clicksets
		self.editSet = self.clicksets[L.CLICKSET_DEFAULT]
		self.profileKey = new
	
		-- Refresh the profile editor if it exists
		self.textlistSelected = nil
		self:TextListScrollUpdate()
		self:ListScrollUpdate()

		for frame in pairs(self.ccframes) do
			self:RegisterFrame(frame)
		end
	end
end

function Clique:DONGLE_PROFILE_DELETED(event, addon, svname, name)
	if addon == "Clique" then
		self:Print(L.PROFILE_DELETED, name)
	
		self.textlistSelected = nil
		self:TextListScrollUpdate()
		self:ListScrollUpdate()
	end
end

function Clique:SetAttribute(entry, frame)
	local name = frame:GetName()
	if	self.profile.blacklist[name] then
		return
	end

	-- Set up any special attributes
	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		frame:SetAttribute(entry.modifier..entry.button, type..button)
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	if entry.type == "actionbar" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)		
	elseif entry.type == "action" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
	elseif entry.type == "pet" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
	elseif entry.type == "spell" then
		local rank = tonumber(entry.arg2)
		local cast = string.format(rank and L.CAST_FORMAT or "%s", entry.arg1, rank)
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."spell"..button, cast)

		frame:SetAttribute(entry.modifier.."bag"..button, entry.arg2)
		frame:SetAttribute(entry.modifier.."slot"..button, entry.arg3)
		frame:SetAttribute(entry.modifier.."item"..button, entry.arg4)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg5)
	elseif entry.type == "item" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."bag"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."slot"..button, entry.arg2)
		frame:SetAttribute(entry.modifier.."item"..button, entry.arg3)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg4)
	elseif entry.type == "macro" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."macro"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."macrotext"..button, entry.arg2)
	elseif entry.type == "stop" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	elseif entry.type == "target" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
	elseif entry.type == "focus" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
	elseif entry.type == "assist" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
	elseif entry.type == "click" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."clickbutton"..button, getglobal(entry.arg1))
	elseif entry.type == "menu" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	end
end

function Clique:DeleteAttribute(entry, frame)
	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		for frame in pairs(self.ccframes) do
			frame:SetAttribute(entry.modifier..entry.button, nil)
		end
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


function test(func, num)
	local start = GetTime()

	debugprofilestart()
	for i=1,num do
		func()
	end
	local total = GetTime() - start
	
	ChatFrame1:AddMessage("Calls took a total of " .. total .. "msec")
	ChatFrame1:AddMessage("Time per call: " ..(total / num))
end
	