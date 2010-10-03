local addonName, addon = ...

local panel = CreateFrame("Frame")
panel.name = "Clique"

panel:SetScript("OnShow", function(self)
    if not panel.initialized then
        panel:CreateOptions()
    end
end)

function panel:CreateOptions()
end

InterfaceOptions_AddCategory(panel)
