local addonName, addon = ...
local L = addon.L

local MAX_ROWS = 19

function CliqueConfig:OnShow()
    if not self.initialized then
        self:SetupGUI()
        self:HijackSpellbook()
        self.initialized = true
    end

    self:UpdateList()
    self:EnableSpellbookButtons()
end


function CliqueConfig:SetupGUI()
    self.rows = {}
    for i = 1, MAX_ROWS do
        self.rows[i] = CreateFrame("Button", "CliqueRow" .. i, CliqueConfig, "CliqueRowTemplate")
    end

    self.rows[1]:ClearAllPoints()
    self.rows[1]:SetPoint("TOPLEFT", "CliqueConfigPage1Column1", "BOTTOMLEFT", 0, -6)

    for i = 2, MAX_ROWS do
        self.rows[i]:ClearAllPoints()
        self.rows[i]:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT")
    end

    -- Set text elements using localized values
    _G[self:GetName() .. "TitleText"]:SetText(L["Clique Configuration"])
    self.page1.column1:SetText(L["Action"])
    self.page1.column2:SetText(L["Binding"])

    self.button_add:SetText(L["Add binding"])
    self.button_edit:SetText(L["Edit"])

    self.page1:Show()
end

function CliqueConfig:HijackSpellbook()
    self.spellbookButtons = {}

    for idx = 1, 12 do
        local parent = getglobal("SpellButton" .. idx)
        local button = CreateFrame("Button", "CliqueSpellbookButton" .. idx, parent, "CliqueSpellbookButtonTemplate")
        button.spellbutton = parent
        button:EnableKeyboard(false)
        button:EnableMouseWheel(true)
        button:RegisterForClicks("AnyDown")
        button:SetID(parent:GetID())
        self.spellbookButtons[idx] = button
    end

    local function showHideHandler(frame)
        self:EnableSpellbookButtons()
    end
    SpellBookFrame:HookScript("OnShow", showHideHandler)
    SpellBookFrame:HookScript("OnHide", showHideHandler)

    -- TODO: This isn't a great way to do this, but for now
    hooksecurefunc("SpellBookSkillLineTab_OnClick", showHideHandler)
    self:EnableSpellbookButtons()
end

function CliqueConfig:EnableSpellbookButtons()
    local enabled;

    if self.page1:IsVisible() and SpellBookFrame:IsVisible() then
        enabled = true
        self:SetNotification("Your spellbook is open.  You can mouse over a spell in your spellbook and click or press a key conbination to add it to your bindings configuration")
    else
        method = false
        self:ClearNotification()
    end

    if self.spellbookButtons then
        for idx, button in ipairs(self.spellbookButtons) do
            if enabled and button.spellbutton:IsEnabled() == 1 then
                button:Show()
            else
                button:Hide()
            end
        end
    end
end

-- Spellbook button functions
function CliqueConfig:Spellbook_EnableKeyboard(button, motion)
    button:EnableKeyboard(true)
end

function CliqueConfig:Spellbook_DisableKeyboard(button, motion)
    button:EnableKeyboard(false)
end

invalidKeys = {
    ["UNKNOWN"] = true,
    ["LSHIFT"] = true,
    ["RSHIFT"] = true,
    ["LCTRL"] = true,
    ["RCTRL"] = true,
    ["LALT"] = true,
    ["RALT"] = true,
}

function CliqueConfig:Spellbook_OnBinding(button, key)
    -- We can't bind modifiers or invalid keys
    if invalidKeys[key] then
        return
    elseif key == "ESCAPE" then
        HideUIPanel(CliqueConfig) 
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

    local slot = SpellBook_GetSpellBookSlot(button:GetParent());
    local name, subtype = GetSpellBookItemName(slot, SpellBookFrame.bookType)
    local texture = GetSpellBookItemTexture(slot, SpellBookFrame.bookType)

    local succ, err = addon:AddBinding{
        key = prefix .. key,
        type = "spell",
        spell = name,
        icon = texture
    }

    if not succ then
        CliqueConfig:SetNotification(err)
    else
        CliqueConfig:UpdateList()
    end
end

function CliqueConfig:SetNotification(text)
end

function CliqueConfig:ClearNotification()
end

local memoizeBindings = setmetatable({}, {__index = function(t, k, v)
    local binbits = addon:GetBinaryBindingKey(k)
    rawset(t, k, binbits)
    return binbits
end})

local compareFunctions = {
    name = function(a, b)
        return a.binding < b.binding
    end,
    binding = function(a, b)
        local mem = memoizeBindings
        return mem[a] < mem[b]
    end,
}

CliqueConfig.binds = {}
function CliqueConfig:UpdateList()
    local page = self.page1
    local binds = Clique.profile.binds

    -- GUI not created yet
    if not page then
        return
    end

    -- Sort the bindings
    -- TODO: Use a custom sort function here

    local sort = {}
    for uid, entry in pairs(binds) do
        sort[#sort + 1] = entry
    end
    table.sort(sort, compareFunctions.binding) 

    -- Enable or disable the scroll bar
    if #sort > MAX_ROWS - 1 then
        -- Set up the scrollbar for the item list
        page.slider:SetMinMaxValues(0, #sort - MAX_ROWS)

        -- Adjust and show
        if not page.slider:IsShown() then
            -- Adjust column positions
            for idx, row in ipairs(self.rows) do
                row.bind:SetWidth(100)
            end
            page.slider:SetValue(0)
            page.slider:Show()
        end
    elseif page.slider:IsShown() then
        -- Move column positions back and hide the slider
        for idx, row in ipairs(self.rows) do
            row.bind:SetWidth(115)
        end
        page.slider:Hide()
    end

    -- Update the rows in the list
    local offset = page.slider:GetValue() or 0
    for idx, row in ipairs(self.rows) do
        local offsetIndex = offset + idx
        if sort[offsetIndex] then
            local bind = sort[offsetIndex]
            row.icon:SetTexture(addon:GetBindingIcon(bind))
            row.name:SetText(addon:GetBindingActionText(bind))
            --row.type:SetText(bind.type)
            row.bind:SetText(addon:GetBindingKeyComboText(bind))
            row:Show()
        else 
            row:Hide()
        end
    end
end

function CliqueConfig:ClearEditPage()
end

function CliqueConfig:ShowEditPage()
    self:ClearEditPage()
    self.page1:Hide()
    self.page2:Show()
end

function CliqueConfig:Save_OnClick(button, button, down)
end

function CliqueConfig:Cancel_OnClick(button, button, down)
    self:ClearEditPage()
    self.page2:Hide()
    self.page1:Show()
end

