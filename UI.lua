-- FocusInterrupt / UI.lua

local FI = FocusInterruptAddon

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

local function SetMarkButtonDesaturated(btn, desaturated)
    for _, region in ipairs({btn:GetRegions()}) do
        if region:IsObjectType("Texture") then
            region:SetDesaturated(desaturated)
        end
    end
end

-- Syncs all visual state of a panel to FI_Config and the current player state.
-- refs must contain: infoLabel, spellLabel, markLabel, markButtons,
--                    enemyOnlyCheck, markModeDropdown, minimapCheck
local function ApplyRefreshToRefs(refs)
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
    local spell = FI.GetInterrupt()

    refs.infoLabel:SetText("Class/Spec: " .. class .. " - " .. specName)
    if spell == false then
        refs.spellLabel:SetText("|cffff4444No interrupt available for this spec.|r")
    else
        refs.spellLabel:SetText("|cff00ff00Interrupt: " .. spell .. "|r")
    end
    refs.markLabel:SetText("Current mark: |T" .. MARKS[FI_Config.markIndex].icon .. ":14:14|t " .. MARKS[FI_Config.markIndex].name)
    for _, b in ipairs(refs.markButtons) do
        SetMarkButtonDesaturated(b, b.markIndex ~= FI_Config.markIndex)
    end
    refs.enemyOnlyCheck:SetChecked(FI_Config.focusEnemyOnly or false)
    UIDropDownMenu_SetSelectedValue(refs.markModeDropdown, FI_Config.markMode)
    refs.minimapCheck:SetChecked(not FI_Config.minimapBtn.hide)
end

-- Builds the shared panel content (mark buttons, checkboxes, refresh button, combat state).
-- cfg fields:
--   yBase        (number) Y offset from parent TOPLEFT for the first info label
--   sepWidth     (number) Width of the two separators
--   combatAnchor (table)  { point, relativePoint, x, y } for the combat warning label
-- Returns a refs table with widget references and setCombatState.
local function BuildPanelContent(parent, cfg)
    local yBase = cfg.yBase
    local sepWidth = cfg.sepWidth
    local combatAnchor = cfg.combatAnchor

    -- Info labels
    local infoLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase)
    infoLabel:SetText("Spec: loading...")

    local spellLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellLabel:SetPoint("TOPLEFT", infoLabel, "BOTTOMLEFT", 0, -4)
    spellLabel:SetText("Interrupt: loading...")

    local markLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markLabel:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    markLabel:SetText("Current mark: loading...")

    -- Separator 1
    local sep1 = parent:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    sep1:SetSize(sepWidth, 1)
    sep1:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 60)

    -- Mark selector
    local markTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 74)
    markTitle:SetText("Mark for /focus:")

    local markButtons = {}
    for i, mark in ipairs(MARKS) do
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(42, 42)

        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + col * 48, yBase - 98 - row * 48)

        btn:SetText("")
        btn:SetNormalTexture(mark.icon)

        local icon = btn:GetNormalTexture()
        icon:ClearAllPoints()
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.icon = icon
        btn.markIndex = i

        SetMarkButtonDesaturated(btn, i ~= FI_Config.markIndex)

        btn:SetScript("OnClick", function(self)
            FI_Config.markIndex = self.markIndex
            for _, b in ipairs(markButtons) do
                SetMarkButtonDesaturated(b, true)
            end
            SetMarkButtonDesaturated(self, false)
            FI.UpdateMacros()
            markLabel:SetText("Current mark: |T" .. MARKS[self.markIndex].icon .. ":14:14|t " .. MARKS[self.markIndex].name)
            print(FI.PREFIX .. "|cff00ff00Mark changed to " .. self.markIndex .. " (" .. MARKS[self.markIndex].name .. ").|r")
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(mark.name)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        markButtons[i] = btn
    end

    -- Options section header: ────── Options ──────
    local optionsTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optionsTitle:SetPoint("CENTER", parent, "TOPLEFT", 16 + sepWidth / 2, yBase - 208)
    optionsTitle:SetText("Options")

    local optionsLineLeft = parent:CreateTexture(nil, "ARTWORK")
    optionsLineLeft:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    optionsLineLeft:SetHeight(1)
    optionsLineLeft:SetPoint("LEFT", parent, "TOPLEFT", 16, yBase - 208)
    optionsLineLeft:SetPoint("RIGHT", optionsTitle, "LEFT", -6, 0)

    local optionsLineRight = parent:CreateTexture(nil, "ARTWORK")
    optionsLineRight:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    optionsLineRight:SetHeight(1)
    optionsLineRight:SetPoint("LEFT", optionsTitle, "RIGHT", 6, 0)
    optionsLineRight:SetPoint("RIGHT", parent, "TOPLEFT", 16 + sepWidth, yBase - 208)

    -- Dropdown: mark mode
    local markModeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markModeLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 268)
    markModeLabel:SetText("Mark mode:")

    local markModeDropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    markModeDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yBase - 284)
    UIDropDownMenu_SetWidth(markModeDropdown, 220)
    UIDropDownMenu_SetSelectedValue(markModeDropdown, FI_Config.markMode)

    UIDropDownMenu_Initialize(markModeDropdown, function(self)
    local modes = {
        { value = "both",      text = "Both (mark + focus)" },
        { value = "markOnly",  text = "Mark only" },
        { value = "focusOnly", text = "Focus only" },
     }
     for _, entry in ipairs(modes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text    = entry.text
        info.value   = entry.value
        info.checked = FI_Config.markMode == entry.value
        info.func    = function(self)
            FI_Config.markMode = self.value
            UIDropDownMenu_SetSelectedValue(markModeDropdown, self.value)
            FI.UpdateMacros()
        end
        UIDropDownMenu_AddButton(info)
     end
 end)



    -- Checkbox: focus enemy only
    local enemyOnlyCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enemyOnlyCheck:SetSize(26, 26)
    enemyOnlyCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 234)
    enemyOnlyCheck:SetChecked(FI_Config.focusEnemyOnly or false)

    local enemyOnlyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enemyOnlyLabel:SetPoint("LEFT", enemyOnlyCheck, "RIGHT", 4, 0)
    enemyOnlyLabel:SetText("Set focus only on enemies")

    enemyOnlyCheck:SetScript("OnClick", function(self)
        FI_Config.focusEnemyOnly = self:GetChecked()
        FI.UpdateMacros()
    end)

    -- Checkbox: show minimap button
    local minimapCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    minimapCheck:SetSize(26, 26)
    minimapCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 328)
    minimapCheck:SetChecked(not FI_Config.minimapBtn.hide)

    local minimapLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 4, 0)
    minimapLabel:SetText("Show minimap button")

    minimapCheck:SetScript("OnClick", function(self)
        FI_Config.minimapBtn.hide = not self:GetChecked()
        if FI_Config.minimapBtn.hide then
            LibStub("LibDBIcon-1.0"):Hide("FocusInterrupt")
        else
            LibStub("LibDBIcon-1.0"):Show("FocusInterrupt")
        end
    end)

    -- Refresh macros button
    local regenBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    regenBtn:SetSize(248, 28)
    regenBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 362)
    regenBtn:SetText("Refresh macros")
    regenBtn:SetScript("OnClick", function()
        FI.UpdateMacros()
    end)

    -- Combat warning label
    local combatLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    combatLabel:SetPoint(combatAnchor[1], parent, combatAnchor[2], combatAnchor[3], combatAnchor[4])
    combatLabel:SetText("|cffff4444In combat – changes will apply after combat.|r")
    combatLabel:Hide()

    local function SetCombatState(inCombat)
        if inCombat then combatLabel:Show() else combatLabel:Hide() end
        for _, b in ipairs(markButtons) do
            if inCombat then b:Disable() else b:Enable() end
        end
        if inCombat then
            UIDropDownMenu_DisableDropDown(markModeDropdown)
        else
            UIDropDownMenu_EnableDropDown(markModeDropdown)
        end
        if inCombat then
            enemyOnlyCheck:Disable()
            minimapCheck:Disable()
            regenBtn:Disable()
        else
            enemyOnlyCheck:Enable()
            minimapCheck:Enable()
            regenBtn:Enable()
        end
    end

    parent:RegisterEvent("PLAYER_REGEN_DISABLED")
    parent:RegisterEvent("PLAYER_REGEN_ENABLED")
    parent:SetScript("OnEvent", function(self, event)
        SetCombatState(event == "PLAYER_REGEN_DISABLED")
    end)

    return {
        infoLabel      = infoLabel,
        spellLabel     = spellLabel,
        markLabel      = markLabel,
        markButtons    = markButtons,
        enemyOnlyCheck   = enemyOnlyCheck,
        markModeDropdown = markModeDropdown,
        minimapCheck     = minimapCheck,
        setCombatState = SetCombatState,
    }
end

-- Floating popup menu

local function CreateMenu()
    if FI.MenuFrame then return end

    FI.MenuFrame = CreateFrame("Frame", "FocusInterruptMenu", UIParent, "BasicFrameTemplateWithInset")
    FI.MenuFrame:SetSize(280, 446)
    FI.MenuFrame:SetPoint("CENTER")
    FI.MenuFrame:SetMovable(true)
    FI.MenuFrame:EnableMouse(true)
    FI.MenuFrame:RegisterForDrag("LeftButton")
    FI.MenuFrame:SetScript("OnDragStart", FI.MenuFrame.StartMoving)
    FI.MenuFrame:SetScript("OnDragStop", FI.MenuFrame.StopMovingOrSizing)
    FI.MenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    FI.MenuFrame:Hide()
    FI.MenuFrame.TitleText:SetText(FI.TITLE)
    FI.MenuFrame.CloseButton:SetScript("OnClick", function()
        FI.MenuFrame:Hide()
    end)

    local refs = BuildPanelContent(FI.MenuFrame, {
        yBase        = -36,
        sepWidth     = 248,
        combatAnchor = { "BOTTOMLEFT", "BOTTOMLEFT", 16, 8 },
    })

    for k, v in pairs(refs) do FI.MenuFrame[k] = v end

    function FI.MenuFrame:RefreshInfo()
        ApplyRefreshToRefs(self)
    end

    FI.MenuFrame:SetScript("OnShow", function()
        FI.MenuFrame.setCombatState(InCombatLockdown())
    end)
end

-- Toggle

local function ToggleMenu()
    CreateMenu()
    if FI.MenuFrame:IsShown() then
        FI.MenuFrame:Hide()
    else
        FI.MenuFrame:RefreshInfo()
        FI.MenuFrame:Show()
    end
end

-- Options panel (Interface > AddOns)

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText(FI.TITLE)

    local refs = BuildPanelContent(panel, {
        yBase        = -40,
        sepWidth     = 500,
        combatAnchor = { "TOPLEFT", "TOPLEFT", 16, -438 },
    })

    panel:SetScript("OnShow", function()
        ApplyRefreshToRefs(refs)
        refs.setCombatState(InCombatLockdown())
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, FI.TITLE)
    Settings.RegisterAddOnCategory(category)
    FI.OptionsCategory = category
end

-- Minimap button

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FocusInterrupt", {
    type = "launcher",
    icon = "Interface\\AddOns\\FocusInterrupt\\icon",
    OnClick = function(_, button)
        ToggleMenu()
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText(FI.TITLE)
        tooltip:AddLine("Click to open settings", 1, 1, 1)
    end,
})

local iconFrame = CreateFrame("Frame")
iconFrame:RegisterEvent("ADDON_LOADED")
iconFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "FocusInterrupt" then
        FI_Config.minimapBtn = FI_Config.minimapBtn or { hide = false }
        LibStub("LibDBIcon-1.0"):Register("FocusInterrupt", LDB, FI_Config.minimapBtn)
        CreateOptionsPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands

SLASH_FOCUSINTERRUPT1 = "/fi"
SLASH_FOCUSINTERRUPT2 = "/focusinterrupt"
SlashCmdList["FOCUSINTERRUPT"] = function()
    ToggleMenu()
end
