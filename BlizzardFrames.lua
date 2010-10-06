local addonName, addon = ...

local function enable(frame)
    if type(frame) == "string" then
        local frameName = frame
        frame = _G[frameName]
        if not frame then
            print("Error registering frame: " .. tostring(frameName))
        end
    end

    if frame then
        ClickCastFrames[frame] = true
    end
end

function addon:Enable_BlizzRaidPullouts()
    hooksecurefunc("CreateFrame", function(type, name, parent, template)
        if template == "RaidPulloutButtonTemplate" then
            local frame = _G[tostring(name) .. "ClearButton"]
            if frame then
                enable(frame)
            end
        end
    end)
end

function addon:Enable_BlizzCompactUnitFrames()
    hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame, ...)
        enable(frame)
    end)
end

function addon:Enable_BlizzArenaFrames()
    local frames = {
        "ArenaEnemyFrame1",
        "ArenaEnemyFrame2",
        "ArenaEnemyFrame3",
        "ArenaEnemyFrame4",
        "ArenaEnemyFrame5",
    }
    for idx, frame in ipairs(frames) do
        enable(frame)
    end
end

function addon:Enable_BlizzSelfFrames()
    local frames = {
        "PlayerFrame",
        "PetFrame",
        "TargetFrame",
        "TargetFrameToT",
        "FocusFrame",
        "FocusFrameToT",
    }
    for idx, frame in ipairs(frames) do
        enable(frame)
    end
end

function addon:Enable_BlizzPartyFrames()
    local frames = {
        "PartyMemberFrame1",
		"PartyMemberFrame2",
		"PartyMemberFrame3",
		"PartyMemberFrame4",
        "PartyMemberFrame5",
		"PartyMemberFrame1PetFrame",
		"PartyMemberFrame2PetFrame",
		"PartyMemberFrame3PetFrame",
        "PartyMemberFrame4PetFrame",
        "PartyMemberFrame5PetFrame",
    }
    for idx, frame in ipairs(frames) do
        enable(frame)
    end
end

function addon:Enable_BlizzCompactParty()
    local frames = {
        "CompactPartyFrameMemberSelf", 
        "CompactPartyFrameMemberSelfBuff1", 
        "CompactPartyFrameMemberSelfBuff2", 
        "CompactPartyFrameMemberSelfBuff3", 
        "CompactPartyFrameMemberSelfDebuff1", 
        "CompactPartyFrameMemberSelfDebuff2", 
        "CompactPartyFrameMemberSelfDebuff3", 
        "CompactPartyFrameMember1", 
        "CompactPartyFrameMember1Buff1", 
        "CompactPartyFrameMember1Buff2", 
        "CompactPartyFrameMember1Buff3", 
        "CompactPartyFrameMember1Debuff1", 
        "CompactPartyFrameMember1Debuff2", 
        "CompactPartyFrameMember1Debuff3", 
        "CompactPartyFrameMember2", 
        "CompactPartyFrameMember2Buff1", 
        "CompactPartyFrameMember2Buff2", 
        "CompactPartyFrameMember2Buff3", 
        "CompactPartyFrameMember2Debuff1", 
        "CompactPartyFrameMember2Debuff2", 
        "CompactPartyFrameMember2Debuff3", 
        "CompactPartyFrameMember3", 
        "CompactPartyFrameMember3Buff1", 
        "CompactPartyFrameMember3Buff2", 
        "CompactPartyFrameMember3Buff3", 
        "CompactPartyFrameMember3Debuff1", 
        "CompactPartyFrameMember3Debuff2", 
        "CompactPartyFrameMember3Debuff3", 
        "CompactPartyFrameMember4", 
        "CompactPartyFrameMember4Buff1", 
        "CompactPartyFrameMember4Buff2", 
        "CompactPartyFrameMember4Buff3", 
        "CompactPartyFrameMember4Debuff1", 
        "CompactPartyFrameMember4Debuff2", 
        "CompactPartyFrameMember4Debuff3", 
        "CompactPartyFrameMember5", 
        "CompactPartyFrameMember5Buff1", 
        "CompactPartyFrameMember5Buff2", 
        "CompactPartyFrameMember5Buff3", 
        "CompactPartyFrameMember5Debuff1", 
        "CompactPartyFrameMember5Debuff2", 
        "CompactPartyFrameMember5Debuff3", 
    }
    for idx, frame in ipairs(frames) do
        enable(frame)
    end
end

function addon:Enable_BlizzBossFrames()
    local frames = {
        "Boss1TargetFrame",
        "Boss2TargetFrame",
        "Boss3TargetFrame",
        "Boss4TargetFrame",
    }
    for idx, frame in ipairs(frames) do
        enable(frame)
    end
end


function addon:EnableBlizzardFrames()
    self:Enable_BlizzRaidPullouts()
    self:Enable_BlizzCompactUnitFrames()
    self:Enable_BlizzArenaFrames()
    self:Enable_BlizzSelfFrames()
    self:Enable_BlizzPartyFrames()
    self:Enable_BlizzCompactParty()
    self:Enable_BlizzBossFrames()
    if IsAddOnLoaded("Blizzard_ArenaUI") then
        self:Enable_BlizzArenaFrames()
    else
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(frame, event, ...)
            if ... == "Blizzard_ArenaUI" then
                self:UnregisterEvent("ADDON_LOADED")
                self:SetScript("OnEvent", nil)
                self:Enable_BlizzArenaFrames()
            end
        end)
    end
 end

