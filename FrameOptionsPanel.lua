local addonName, addon = ...

local panel = CreateFrame("Frame")
panel.name = "Frame Editor"
panel.parent = addonName

panel:SetScript("OnShow", function(self)
    if not panel.initialized then
        panel:CreateOptions()
    end
end)

function panel:CreateOptions()
end

InterfaceOptions_AddCategory(panel)

