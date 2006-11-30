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

if not InCombatLockdown then
    function InCombatLockdown()
	return UnitAffectingCombat("player")
    end
end
   
function Clique:Enable()
	-- Grab the localisation header
	L = Clique.Locals

	self.defaults = {
		profile = {
			[L.CLICKSET_DEFAULT] = {},
			[L.CLICKSET_HARMFUL] = {},
			[L.CLICKSET_HELPFUL] = {},
			[L.CLICKSET_OOC] = {},
		}
	}

	self.db = self:InitializeDB("CliqueDB", self.defaults)
	self.profile = self.db.profile

    self.editSet = self.profile[L.CLICKSET_DEFAULT]

    local newindex = function(t,k,v)
		Clique:RegisterFrame(k)
		rawset(t,k,v)
    end
    
	ClickCastFrames = ClickCastFrames or {}
    setmetatable(ClickCastFrames, {__newindex=newindex})
    
    -- Register all frames that snuck in before we did =)
    for frame in pairs(ClickCastFrames) do
		self:RegisterFrame(frame)
    end

    Clique:OptionsOnLoad()
    Clique:EnableFrames()

	-- Run the OOC script if we need to
	Clique:CombatUnlock()

    -- Securehook the RaidFrame_LoadUI
    local raidFunc = function(type, name, parent, template)
		if template == "RaidPulloutButtonTemplate" then
			ClickCastFrames[getglobal(name.."ClearButton")] = true
		end
	end
		 
    hooksecurefunc("CreateFrame", raidFunc)
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

	if self.editSet == self.profile[L.CLICKSET_HARMFUL] then
		button = string.format("%s%d", "harmbutton", self:GetButtonNumber())
	elseif self.editSet == self.profile[L.CLICKSET_HELPFUL] then
		button = string.format("%s%d", "helpbutton", self:GetButtonNumber())
	else
		button = self:GetButtonNumber()
	end
    
    -- Build the SVN/live structure
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
    
    self:SetAction(t)
    self:ListScrollUpdate()
end

function Clique:CombatLockdown()
	self:Debug(1, "Going into combat mode")
	-- Remove all OOC clicks
	for k,v in pairs(self.profile[L.CLICKSET_OOC]) do
		self:DeleteAction(v)
		self:Debug(1, "Removing %s, %s", v.type, tostring(v.arg1))
	end

	-- Just bluntly force our clicks back onto the frames
    for frame in pairs(ClickCastFrames) do
		self:RegisterFrame(frame)
    end
end	

function Clique:CombatUnlock()
	self:Debug(1, "Setting any out of combat clicks")
    for frame in pairs(ClickCastFrames) do
		for k,v in pairs(self.profile[L.CLICKSET_OOC]) do
			self:SetAttribute(v,frame)
		end
	end
end

local queue = {}

function Clique:CombatDelay(tbl)
	if InCombatLockdown() then
		if #queue == 0 then 
			self:Print("Cannot make changes in combat.  These changes will be delayed until you exit combat.")
		end
		table.insert(queue, tbl)
		eventFrame:Show()		
		return true
	end
end

function Clique:ClearQueue()
	if InCombatLockdown() then return end

	eventFrame:Hide()	
	self:Print("Out of combat.  Applying all queued changes.")
	for k,v in ipairs(queue) do
	    if v.GetAttribute then
			self:RegisterFrame(v)
	    else
			if v.delete then
				self:DeleteAction(v)
			else
				self:SetAction(v)
			end
	    end
	end
	queue = {}
end

function Clique:RegisterFrame(frame)
	if self:CombatDelay(frame) then return end
	-- Ensure we have all the buttons registered
	frame:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp", "Button4Up", "Button5Up")
	
	for name,set in pairs(self.profile) do
		if name ~= L.CLICKSET_OOC then
			for modifier,entry in pairs(set) do
				self:SetAttribute(entry, frame)
			end
		end
	end
end

function Clique:ProfileChanged(new)

	for name,set in pairs(self.profile) do
	    for modifier,entry in pairs(set) do
			self:DeleteAction(entry)
	    end
	end

	self.profile = self.db.profile
    self.editSet = self.profile[L.CLICKSET_DEFAULT]
	self.profileKey = new
	
	-- refresh the dropdown if its active
	CliqueDropDownProfile:Hide()
	CliqueDropDownProfile:Show()

	self:Print("Profile changed to '%s'", new)

    for frame in pairs(ClickCastFrames) do
		self:RegisterFrame(frame)
    end
end

function Clique:SetAttribute(entry, frame)
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
		frame:SetAttribute(entry.modifier.."delegate"..button, getglobal(entry.arg1))
	end
end

function Clique:SetAction(entry)
	if self:CombatDelay(entry) then return end
	for frame in pairs(ClickCastFrames) do
		self:SetAttribute(entry, frame)
	end
end

function Clique:DeleteAction(entry)
	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		for frame in pairs(ClickCastFrames) do
			frame:SetAttribute(entry.modifier..entry.button, nil)
		end
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	entry.delete = true

	if self:CombatDelay(entry) then return end
	for frame in pairs(ClickCastFrames) do
		frame:SetAttribute(entry.modifier.."type"..button, nil)
		frame:SetAttribute(entry.modifier..entry.type..button, nil)
	end
end

function Clique:Print(msg, ...)
	if string.find(msg, "%%") then
		-- This is a string format, so lets format
		msg = string.format(msg, ...)
	end
	ChatFrame1:AddMessage("|cFF33FF99Clique|r: " .. tostring(msg))
end
