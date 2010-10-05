local addonName, addon = ...
local L = addon.L

local MAX_ROWS = 12

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
        self.rows[i] = CreateFrame("Button", "CliqueRow" .. i, self.page1, "CliqueRowTemplate")
    end

    self.rows[1]:ClearAllPoints()
    self.rows[1]:SetPoint("TOPLEFT", "CliqueConfigPage1Column1", "BOTTOMLEFT", 0, -3)
    self.rows[1]:SetPoint("RIGHT", CliqueConfigPage1Column2, "RIGHT", 0, 0)

    for i = 2, MAX_ROWS do
        self.rows[i]:ClearAllPoints()
        self.rows[i]:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT")
        self.rows[i]:SetPoint("RIGHT", CliqueConfigPage1Column2, "RIGHT", 0, 0)
    end

    -- Set text elements using localized values
    _G[self:GetName() .. "TitleText"]:SetText(L["Clique Binding Configuration"])
    
    self.dialog = _G["CliqueDialog"]
    self.dialog.title = _G["CliqueDialogTitleText"]

    self.dialog.title:SetText(L["Set binding"])
    self.dialog.button_accept:SetText(L["Accept"])

    self.dialog.button_binding:SetText(L["Set binding"])
    local desc = L["In order to specify a binding, move your mouse over the button labelled 'Set binding' and either click with your mouse or press a key on your keyboard. You can modify the binding by holding down a combination of the alt, control and shift keys on your keyboard."]
    self.dialog.desc:SetText(desc)

    self.page1.column1:SetText(L["Action"])
    self.page1.column2:SetText(L["Binding"])

    -- Set columns up to handle sorting
    self.page1.column1.sortType = "name"
    self.page1.column2.sortType = "key"
    self.page1.sortType = self.page1.column2.sortType

    self.page1.button_spell:SetText(L["Bind spell"])
    self.page1.button_other:SetText(L["Bind other"])
    self.page1.button_options:SetText(L["Options"])
  
    self.page2.button_binding:SetText(L["Set binding"])
    self.page2.button_save:SetText(L["Save"])
    self.page2.button_cancel:SetText(L["Cancel"])
    local desc = L["You can use this page to create a custom macro to be run when activating a binding on a unit. When creating this macro you should keep in mind that you will need to specify the target of any actions in the macro by using the 'mouseover' unit, which is the unit you are clicking on. For example, you can do any of the following:\n\n/cast [target=mouseover] Regrowth\n/cast [@mouseover] Regrowth\n/cast [@mouseovertarget] Taunt\n\nHover over the 'Set binding' button below and either click or press a key with any modifiers you would like included. Then edit the box below to contain the macro you would like to have run when this binding is activated."]
    
    self.page2.desc:SetText(desc)
    self.page2.editbox = CliqueScrollFrameEditBox

    self.page1:Show()
end

function CliqueConfig:Column_OnClick(frame, button)
    self.page1.sortType = frame.sortType
    self:UpdateList()
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

function CliqueConfig:Spellbook_OnBinding(button, key)
    if key == "ESCAPE" then
        HideUIPanel(CliqueConfig) 
        return
    end

    local slot = SpellBook_GetSpellBookSlot(button:GetParent());
    local name, subtype = GetSpellBookItemName(slot, SpellBookFrame.bookType)
    local texture = GetSpellBookItemTexture(slot, SpellBookFrame.bookType)
    
    local key = addon:GetCapturedKey(key)
    assert(key, "Unable to get binding information: " .. tostring(key))

    local succ, err = addon:AddBinding{
        key = key,
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

function CliqueConfig:Button_OnClick(button)
    -- Click handler for "Bind spell" button
    if button == self.page1.button_spell then
        if SpellBookFrame and not SpellBookFrame:IsVisible() then
            ShowUIPanel(SpellBookFrame)
        end

    -- Click handler for "Bind other" button
    elseif button == self.page1.button_other then
        local config = CliqueConfig
        local menu = {
            { 
                text = L["Select a binding type"], 
                isTitle = true
            },
            { 
                text = L["Target clicked unit"],
                func = function()
                    self:SetupCaptureDialog("target")
                end,
            },
            {
                text = L["Open unit menu"],
                func = function()
                    self:SetupCaptureDialog("menu")
                end,
            },
            {
                text = L["Run custom macro"],
                func = function()
                    config.page1:Hide()
                    config.page2.bindType = "macro"
                    config.page2:Show()
                end,
            },
        }
        UIDropDownMenu_SetAnchor(self.dropdown, 0, 0, "BOTTOMLEFT", self.page1.button_other, "TOP")
        EasyMenu(menu, self.dropdown, nil, 0, 0, nil, nil) 

    -- Click handler for "Edit" button
    elseif button == self.page1.button_options then
        InterfaceOptionsFrame_OpenToCategory("Clique") 
    elseif button == self.page2.button_save then
        -- Check the input
        local key = self.page2.key
        local macrotext = self.page2.editbox:GetText()
        local succ, err = addon:AddBinding{
            key = key,
            type = "macro",
            macrotext = macrotext,
        }
        self:UpdateList()
        self.page2:Hide()
        self.page1:Show()
    elseif button == self.page2.button_cancel then
        self.page2:Hide()
        self.page1:Show()
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

local compareFunctions;
compareFunctions = {
    name = function(a, b)
        local texta = addon:GetBindingActionText(a)
        local textb = addon:GetBindingActionText(b)
        if texta == textb then
            return compareFunctions.key(a, b)
        end
        return texta < textb
    end,
    key = function(a, b)
        local keya = addon:GetBindingKey(a)
        local keyb = addon:GetBindingKey(b)
        if keya == keyb then
            return memoizeBindings[a] < memoizeBindings[b]
        else
            return keya < keyb
        end
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
    local sort = {}
    for uid, entry in pairs(binds) do
        sort[#sort + 1] = entry
    end

    if page.sortType then
        table.sort(sort, compareFunctions[page.sortType]) 
    else
        table.sort(sort, compareFunctions.key)
    end

    -- Enable or disable the scroll bar
    if #sort > MAX_ROWS - 1 then
        -- Set up the scrollbar for the item list
        page.slider:SetMinMaxValues(0, #sort - MAX_ROWS)

        -- Adjust and show
        if not page.slider:IsShown() then
            -- Adjust column positions
            for idx, row in ipairs(self.rows) do
                row.bind:SetWidth(90)
            end
            page.slider:SetValue(0)
            page.slider:Show()
        end
    elseif page.slider:IsShown() then
        -- Move column positions back and hide the slider
        for idx, row in ipairs(self.rows) do
            row.bind:SetWidth(105)
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
    self.page3:Show()
end

function CliqueConfig:Save_OnClick(button, down)
end

function CliqueConfig:Cancel_OnClick(button, down)
    self:ClearEditPage()
    self.page3:Hide()
    self.page1:Show()
end

function CliqueConfig:SetupCaptureDialog(type)
    self.dialog.bindType = type
    self.dialog.bindText:SetText("")

    local actionText = addon:GetBindingActionText(type)
    self.dialog.title:SetText(L["Set binding: %s"]:format(actionText))
    self.dialog:Show()
end

function CliqueConfig:BindingButton_OnClick(button, key)
    local dialog = CliqueDialog
    dialog.key = addon:GetCapturedKey(key)
    if dialog.key then
        CliqueDialog.bindText:SetText(addon:GetBindingKeyComboText(dialog.key))
    end
end

function CliqueConfig:MacroBindingButton_OnClick(button, key)
    local key = addon:GetCapturedKey(key)
    if key then
        self.page2.key = key 
        self.page2.bindText:SetText(addon:GetBindingKeyComboText(key))
    end
end

function CliqueConfig:AcceptSetBinding()
    local dialog = CliqueDialog
    local key = dialog.key
    local succ, err = addon:AddBinding{
        key = key,
        type = dialog.bindType,
    }
    if succ then
        CliqueConfig:UpdateList()
    end
    dialog:Hide()
end
