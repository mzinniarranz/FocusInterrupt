-- FocusInterrupt / UI.lua

local MARKS = {
    { index = 1, name = "Star",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    { index = 2, name = "Circle",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { index = 3, name = "Diamond",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { index = 4, name = "Triangle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { index = 5, name = "Moon",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { index = 6, name = "Square",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { index = 7, name = "Cross",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { index = 8, name = "Skull",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
}

local function CreateMenu()
    if FI_MenuFrame then return end

    FI_MenuFrame = CreateFrame("Frame", "FocusInterruptMenu", UIParent, "BasicFrameTemplateWithInset")
    FI_MenuFrame:SetFrameStrata("HIGH")
    FI_MenuFrame:SetSize(280, 286)
    FI_MenuFrame:SetPoint("CENTER")
    FI_MenuFrame:SetMovable(true)
    FI_MenuFrame:EnableMouse(true)
    FI_MenuFrame:RegisterForDrag("LeftButton")
    FI_MenuFrame:SetScript("OnDragStart", FI_MenuFrame.StartMoving)
    FI_MenuFrame:SetScript("OnDragStop", FI_MenuFrame.StopMovingOrSizing)
    FI_MenuFrame:Hide()

    FI_MenuFrame.TitleText:SetText(FI_TITLE)

    -- Spec/spell info
    local infoLabel = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -36)
    infoLabel:SetText("Spec: loading...")
    FI_MenuFrame.infoLabel = infoLabel

    local spellLabel = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellLabel:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -4)
    spellLabel:SetText("Interrupt: loading...")
    FI_MenuFrame.spellLabel = spellLabel

    -- Separator
    local sep1 = FI_MenuFrame:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep1:SetSize(248, 1)
    sep1:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -80)

    -- Mark selector
    local markTitle = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markTitle:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -94)
    markTitle:SetText("Mark for /focus:")

    local markButtons = {}
    for i, mark in ipairs(MARKS) do
        local btn = CreateFrame("Button", nil, FI_MenuFrame, "UIPanelButtonTemplate")
        btn:SetSize(42, 42)
        
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        btn:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16 + col * 48, -118 - row * 48)
        
        btn:SetText("")
        btn:SetNormalTexture(mark.icon)
        
        local icon = btn:GetNormalTexture()
        icon:ClearAllPoints()
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        
        btn.markIndex = i
        
        btn:SetScript("OnClick", function(self)
            FI_Config.markIndex = self.markIndex
            for _, b in ipairs(markButtons) do
                b:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
            self:GetNormalTexture():SetVertexColor(1, 1, 0)
            FI_UpdateMacros()
            print("|cffff4444" .. FI_TITLE .. ":|r Changing mark to " .. self.markIndex .. " (" .. MARKS[self.markIndex].name .. ")")
        end)
        
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(mark.name)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        markButtons[i] = btn
    end
    FI_MenuFrame.markButtons = markButtons

    -- Separator 2
    local sep2 = FI_MenuFrame:CreateTexture(nil, "ARTWORK")
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep2:SetSize(248, 1)
    sep2:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -222)

    -- Refresh macro button 
    local regenBtn = CreateFrame("Button", nil, FI_MenuFrame, "UIPanelButtonTemplate")
    regenBtn:SetSize(248, 28)
    regenBtn:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -236)
    regenBtn:SetText("Refresh macros")
    regenBtn:SetScript("OnClick", function()
        FI_UpdateMacros()
    end)

    -- RefreshInfo
    function FI_MenuFrame:RefreshInfo()
        local _, class = UnitClass("player")
        local currentSpec = GetSpecialization()
        local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
        local spell = FI_GetInterrupt()

        self.infoLabel:SetText("Class/Spec: " .. class .. " - " .. specName)

        if spell == false then
            self.spellLabel:SetText("|cffff4444Interrupt: Healer, no interrupt|r")
        elseif spell then
            self.spellLabel:SetText("|cff00ff00Interrupt: " .. spell .. "|r")
        else
            self.spellLabel:SetText("|cffff4444Interrupt: none|r")
        end

        for _, b in ipairs(self.markButtons) do
            if b.markIndex == FI_Config.markIndex then
                b:GetNormalTexture():SetVertexColor(1, 1, 0)
            else
                b:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
        end
    end
end

function FI_ToggleMenu()
    CreateMenu()
    if FI_MenuFrame:IsShown() then
        FI_MenuFrame:Hide()
    else
        FI_MenuFrame:RefreshInfo()
        FI_MenuFrame:Show()
    end
end

SLASH_FOCUSINTERRUPT1 = "/fi"
SLASH_FOCUSINTERRUPT2 = "/focusinterrupt"
SlashCmdList["FOCUSINTERRUPT"] = function()
    FI_ToggleMenu()
end