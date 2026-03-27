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
    FI_MenuFrame:SetSize(280, 302)
    FI_MenuFrame:SetPoint("CENTER")
    FI_MenuFrame:SetMovable(true)
    FI_MenuFrame:EnableMouse(true)
    FI_MenuFrame:RegisterForDrag("LeftButton")
    FI_MenuFrame:SetScript("OnDragStart", FI_MenuFrame.StartMoving)
    FI_MenuFrame:SetScript("OnDragStop", FI_MenuFrame.StopMovingOrSizing)
    FI_MenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    FI_MenuFrame:Hide()

    FI_MenuFrame.TitleText:SetText(FI_TITLE)

    -- Info spec/spell
    local infoLabel = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -36)
    infoLabel:SetText("Spec: loading...")
    FI_MenuFrame.infoLabel = infoLabel

    local spellLabel = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellLabel:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -4)
    spellLabel:SetText("Interrupt: loading...")
    FI_MenuFrame.spellLabel = spellLabel

    local markLabel = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markLabel:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    markLabel:SetText("Current mark: loading...")
    FI_MenuFrame.markLabel = markLabel

    -- Separator
    local sep1 = FI_MenuFrame:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep1:SetSize(248, 1)
    sep1:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -96)

    -- Mark selector
    local markTitle = FI_MenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markTitle:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -110)
    markTitle:SetText("Mark for /focus:")

    local markButtons = {}
    for i, mark in ipairs(MARKS) do
        local btn = CreateFrame("Button", nil, FI_MenuFrame, "UIPanelButtonTemplate")
        btn:SetSize(42, 42)

        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        btn:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16 + col * 48, -134 - row * 48)

        btn:SetText("")
        btn:SetNormalTexture(mark.icon)

        local icon = btn:GetNormalTexture()
        icon:ClearAllPoints()
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.icon = icon

        btn.markIndex = i

        if i == FI_Config.markIndex then
            btn.icon:SetAlpha(1)
        else
            btn.icon:SetAlpha(0.4)
        end

        btn:SetScript("OnClick", function(self)
            FI_Config.markIndex = self.markIndex
            for _, b in ipairs(markButtons) do
                b.icon:SetAlpha(0.4)
            end
            self.icon:SetAlpha(1)
            FI_UpdateMacros()
            FI_MenuFrame.markLabel:SetText("Current mark: |T" .. MARKS[self.markIndex].icon .. ":14:14|t " .. MARKS[self.markIndex].name)
            print("|cffff4444" .. FI_TITLE .. ":|r Mark changed to " .. self.markIndex .. " (" .. MARKS[self.markIndex].name .. ")")
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
    sep2:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -238)

    -- Refresh macros button
    local regenBtn = CreateFrame("Button", nil, FI_MenuFrame, "UIPanelButtonTemplate")
    regenBtn:SetSize(248, 28)
    regenBtn:SetPoint("TOPLEFT", FI_MenuFrame, "TOPLEFT", 16, -252)
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

        self.markLabel:SetText("Current mark: |T" .. MARKS[FI_Config.markIndex].icon .. ":14:14|t " .. MARKS[FI_Config.markIndex].name)

        for _, b in ipairs(self.markButtons) do
            if b.markIndex == FI_Config.markIndex then
                b.icon:SetAlpha(1)
            else
                b.icon:SetAlpha(0.4)
            end
        end
    end
end

-- Toggle 

function FI_ToggleMenu()
    CreateMenu()
    if FI_MenuFrame:IsShown() then
        FI_MenuFrame:Hide()
    else
        FI_MenuFrame:RefreshInfo()
        FI_MenuFrame:Show()
    end
end

-- Minimap button 
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FocusInterrupt", {
    type = "launcher",
    icon = "Interface\\AddOns\\FocusInterrupt\\icon",
    OnClick = function(_, button)
        FI_ToggleMenu()
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText(FI_TITLE)
        tooltip:AddLine("Click to open settings", 1, 1, 1)
    end,
})

local iconFrame = CreateFrame("Frame")
iconFrame:RegisterEvent("ADDON_LOADED")
iconFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "FocusInterrupt" then
        FI_Config.minimapBtn = FI_Config.minimapBtn or { hide = false }
        LibStub("LibDBIcon-1.0"):Register("FocusInterrupt", LDB, FI_Config.minimapBtn)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands

SLASH_FOCUSINTERRUPT1 = "/fi"
SLASH_FOCUSINTERRUPT2 = "/focusinterrupt"
SlashCmdList["FOCUSINTERRUPT"] = function()
    FI_ToggleMenu()
end