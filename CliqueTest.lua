local addonName, addon = ...

function addon:RunTest()
    function CliqueTest_Unit_OnShow(self)
        local unit = self:GetAttribute("unit")
        if not unit or not UnitExists(unit) then
            return
        end
        local name = UnitName(unit)
        self.name:SetText(name)
        self.healthBar:SetMinMaxValues(0, UnitHealthMax(unit))
        self.powerBar:SetMinMaxValues(0, UnitPowerMax(unit))
        self.healthBar:SetValue(UnitHealth(unit))
        self.powerBar:SetValue(UnitPower(unit))
    end

    -- Create a fake "group header" to test things properly
    local groupheader = CreateFrame("Button", "MyGroupHeader", UIParent, "SecureGroupHeaderTemplate")
    SecureHandler_OnLoad(groupheader)

    -- Ensure the group header has a reference to the click-cast header
    groupheader:SetFrameRef("clickcast_header", addon.header)

    -- Set header attributes
    groupheader:SetAttribute("showParty", true)
    groupheader:SetAttribute("showRaid", true)
    groupheader:SetAttribute("showPlayer", true)
    groupheader:SetAttribute("showSolo", true)
    groupheader:SetAttribute("maxColumns", 8)
    groupheader:SetAttribute("unitsPerColumn", 5)
    groupheader:SetAttribute("columnAnchorPoint", "TOP")
    groupheader:SetAttribute("point", "LEFT")
    groupheader:SetAttribute("template", "CliqueTest_UnitTemplate")
    groupheader:SetAttribute("templateType", "Button")
    groupheader:SetAttribute("xOffset", -1)
    groupheader:SetAttribute("yOffset", -1)

    -- Set up the group header to display a solo/party/raid frame
    groupheader:SetAttribute("initialConfigFunction", [==[
        self:SetAttribute("shift-type1", "spell")
        self:SetAttribute("shift-spell1", "Flash Heal")

        self:SetAttribute("type-cliquebutton1", "spell")
        self:SetAttribute("spell-cliquebutton1", "Flash Heal")

        -- Register this frame with the global click-cast header
        local header = self:GetParent():GetFrameRef("clickcast_header")
        header:SetAttribute("clickcast_button", self)
        header:RunAttribute("clickcast_register")
    ]==])

    addon.header:SetAttribute("setup_onenter", [[
        local buttonName = ...
        self:ClearBinding("F")
        self:SetBindingClick(true, "F", buttonName, "cliquebutton1")
    ]])
    addon.header:SetAttribute("setup_onleave", [[
        self:ClearBinding("F")
    ]])

    groupheader:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    groupheader:Show()
end


