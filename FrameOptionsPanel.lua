local addonName, addon = ...
local L = addon.L

local panel = CreateFrame("Frame")
panel.name = "Frame Editor"
panel.parent = addonName

panel:SetScript("OnShow", function(self)
    if not panel.initialized then
        panel:CreateOptions()
        panel.refresh()
    end
end)

function panel:CreateOptions()
    panel.initialized = true
end

InterfaceOptions_AddCategory(panel)

