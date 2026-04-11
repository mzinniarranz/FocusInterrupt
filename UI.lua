-- FocusInterrupt / UI.lua

local FI = FocusInterruptAddon

local MARKS = {}
for i = 1, 8 do
    MARKS[i] = {
        index = i,
        name  = FI.MARK_NAMES[i],
        icon  = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i,
    }
end

local function SetMarkButtonDesaturated(btn, desaturated)
    for _, region in ipairs({btn:GetRegions()}) do
        if region:IsObjectType("Texture") then
            region:SetDesaturated(desaturated)
        end
    end
end

-- Syncs all visual state of a panel to FI_Config and the current player state.
-- refs must contain: infoLabel, spellLabel, markLabel, markButtons,
--                    enemyOnlyCheck, mouseoverCheck, markModeDropdown, minimapCheck, verboseCheck, announceCheck
local function ApplyRefreshToRefs(refs)
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
    local spell = FI.GetInterrupt()

    FI_Config.markIndex = FI.ValidMarkIndex(FI_Config.markIndex)
    refs.infoLabel:SetText("Class/Spec: " .. class .. " - " .. specName)
    if spell == false then
        refs.spellLabel:SetText("|cffff4444No interrupt available for this spec.|r")
    elseif spell then
        refs.spellLabel:SetText("|cff00ff00Interrupt: " .. spell .. "|r")
    else
        refs.spellLabel:SetText("|cffff8800Interrupt spell not found.|r")
    end
    refs.markLabel:SetText("Current mark: |T" .. MARKS[FI_Config.markIndex].icon .. ":14:14|t " .. MARKS[FI_Config.markIndex].name)
    for _, b in ipairs(refs.markButtons) do
        SetMarkButtonDesaturated(b, b.markIndex ~= FI_Config.markIndex)
    end
    refs.enemyOnlyCheck:SetChecked(FI_Config.focusEnemyOnly or false)
    UIDropDownMenu_SetSelectedValue(refs.markModeDropdown, FI_Config.markMode)
    UIDropDownMenu_SetText(refs.markModeDropdown, refs.getMarkModeText(FI_Config.markMode))
    refs.minimapCheck:SetChecked(not FI_Config.minimapBtn.hide)
    refs.verboseCheck:SetChecked(FI_Config.verbose or false)
    refs.announceCheck:SetChecked(FI_Config.readyCheckAnnounce or false)
    refs.watermarkCheck:SetChecked(FI_Config.announceWatermark or false)
    if FI_Config.readyCheckAnnounce then
        refs.watermarkCheck:Enable()
        refs.watermarkLabel:SetAlpha(1)
    else
        refs.watermarkCheck:Disable()
        refs.watermarkLabel:SetAlpha(0.5)
    end
    refs.mouseoverCheck:SetChecked(FI_Config.focusMouseover)
    refs.markNameInput:SetText(FI_Config.markMacroName or "0FI-Mark")
    refs.kickNameInput:SetText(FI_Config.kickMacroName or "0FI-Kick")
    -- TODO: cast alert UI disabled
    -- refs.castAlertCheck:SetChecked(FI_Config.castAlertSound or false)
    -- local soundIdx = FI.ValidAlertSoundIndex()
    -- UIDropDownMenu_SetSelectedValue(refs.alertSoundDropdown, soundIdx)
    -- UIDropDownMenu_SetText(refs.alertSoundDropdown, FI.ALERT_SOUNDS[soundIdx].name)
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
            FI.Log(FI.PREFIX .. "|cff00ff00Mark changed to " .. self.markIndex .. " (" .. MARKS[self.markIndex].name .. ").|r")
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
    markModeLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 228)
    markModeLabel:SetText("Mark mode:")

    local markModeDropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    markModeDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yBase - 244)
    local MARK_MODES = {
        { value = "both",      text = "Both (mark + focus)" },
        { value = "markOnly",  text = "Mark only" },
        { value = "focusOnly", text = "Focus only" },
    }

    local function GetMarkModeText(value)
        for _, m in ipairs(MARK_MODES) do
            if m.value == value then return m.text end
        end
        return MARK_MODES[1].text
    end

    UIDropDownMenu_SetWidth(markModeDropdown, 220)
    UIDropDownMenu_SetSelectedValue(markModeDropdown, FI_Config.markMode)
    UIDropDownMenu_SetText(markModeDropdown, GetMarkModeText(FI_Config.markMode))

    UIDropDownMenu_Initialize(markModeDropdown, function(self)
        for _, entry in ipairs(MARK_MODES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = entry.text
            info.value   = entry.value
            info.checked = FI_Config.markMode == entry.value
            info.func    = function(self)
                FI_Config.markMode = self.value
                UIDropDownMenu_SetSelectedValue(markModeDropdown, self.value)
                UIDropDownMenu_SetText(markModeDropdown, entry.text)
                FI.UpdateMacros()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Checkbox: focus enemy only
    local enemyOnlyCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enemyOnlyCheck:SetSize(26, 26)
    enemyOnlyCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 288)
    enemyOnlyCheck:SetChecked(FI_Config.focusEnemyOnly or false)

    local enemyOnlyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enemyOnlyLabel:SetPoint("LEFT", enemyOnlyCheck, "RIGHT", 4, 0)
    enemyOnlyLabel:SetText("Set focus only on enemies")

    enemyOnlyCheck:SetScript("OnClick", function(self)
        FI_Config.focusEnemyOnly = self:GetChecked()
        FI.UpdateMacros()
    end)

    -- Checkbox: announce mark on ready check
    local announceCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    announceCheck:SetSize(26, 26)
    announceCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 322)
    announceCheck:SetChecked(FI_Config.readyCheckAnnounce or false)

    local announceLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    announceLabel:SetPoint("LEFT", announceCheck, "RIGHT", 4, 0)
    announceLabel:SetText("Announce mark on ready check")

    announceCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Announce mark on ready check", 1, 1, 1)
        GameTooltip:AddLine("Posts the interrupt mark to group chat\nwhen a ready check fires (5-man dungeons only).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    announceCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Sub-checkbox: addon watermark in announce message
    local watermarkCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    watermarkCheck:SetSize(26, 26)
    watermarkCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 32, yBase - 350)
    watermarkCheck:SetChecked(FI_Config.announceWatermark or false)
    if not FI_Config.readyCheckAnnounce then watermarkCheck:Disable() end

    local watermarkLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    watermarkLabel:SetPoint("LEFT", watermarkCheck, "RIGHT", 4, 0)
    watermarkLabel:SetText("Include addon name in message")
    if not FI_Config.readyCheckAnnounce then watermarkLabel:SetAlpha(0.5) end

    watermarkCheck:SetScript("OnClick", function(self)
        FI_Config.announceWatermark = self:GetChecked()
    end)
    watermarkCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Include addon name in message", 1, 1, 1)
        GameTooltip:AddLine("Appends \"(Addon: Focus Interrupt)\" to the announce\nmessage to help promote the addon.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    watermarkCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    announceCheck:SetScript("OnClick", function(self)
        FI_Config.readyCheckAnnounce = self:GetChecked()
        if self:GetChecked() then
            watermarkCheck:Enable()
            watermarkLabel:SetAlpha(1)
        else
            watermarkCheck:Disable()
            watermarkLabel:SetAlpha(0.5)
        end
    end)

    -- Checkbox: mouseover targeting
    local mouseoverCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    mouseoverCheck:SetSize(26, 26)
    mouseoverCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 384)
    mouseoverCheck:SetChecked(FI_Config.focusMouseover)

    local mouseoverLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mouseoverLabel:SetPoint("LEFT", mouseoverCheck, "RIGHT", 4, 0)
    mouseoverLabel:SetText("Use mouseover targeting")

    mouseoverCheck:SetScript("OnClick", function(self)
        FI_Config.focusMouseover = self:GetChecked()
        FI.UpdateMacros()
    end)
    mouseoverCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Use mouseover targeting", 1, 1, 1)
        GameTooltip:AddLine("When enabled, the macro targets your mouseover\nfirst, falling back to your current target.\nWhen disabled, it only targets your current target.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mouseoverCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- TODO: Cast alert UI disabled – feature not working reliably, needs more testing
    --[[ Checkbox: sound alert on focus interruptible cast
    local castAlertCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    castAlertCheck:SetSize(26, 26)
    castAlertCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 356)
    castAlertCheck:SetChecked(FI_Config.castAlertSound or false)

    local castAlertLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castAlertLabel:SetPoint("LEFT", castAlertCheck, "RIGHT", 4, 0)
    castAlertLabel:SetText("Play sound on focus cast |cffff8800(Beta)|r")

    castAlertCheck:SetScript("OnClick", function(self)
        FI_Config.castAlertSound = self:GetChecked()
    end)
    castAlertCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Play sound on focus cast (Beta)", 1, 1, 1)
        GameTooltip:AddLine("Plays a sound when your focus target starts\nan interruptible cast and your interrupt\nis off cooldown.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    castAlertCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Dropdown: alert sound selection
    local alertSoundDropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    alertSoundDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yBase - 386)
    UIDropDownMenu_SetWidth(alertSoundDropdown, 150)
    local initSoundIdx = FI.ValidAlertSoundIndex()
    UIDropDownMenu_SetSelectedValue(alertSoundDropdown, initSoundIdx)
    UIDropDownMenu_SetText(alertSoundDropdown, FI.ALERT_SOUNDS[initSoundIdx].name)

    UIDropDownMenu_Initialize(alertSoundDropdown, function(self)
        for i, sound in ipairs(FI.ALERT_SOUNDS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = sound.name
            info.value   = i
            info.checked = FI_Config.alertSoundIndex == i
            info.func    = function(self)
                FI_Config.alertSoundIndex = self.value
                UIDropDownMenu_SetSelectedValue(alertSoundDropdown, self.value)
                UIDropDownMenu_SetText(alertSoundDropdown, sound.name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Test sound button
    local testSoundBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testSoundBtn:SetSize(60, 26)
    testSoundBtn:SetPoint("LEFT", alertSoundDropdown, "RIGHT", -10, 2)
    testSoundBtn:SetText("Test")
    testSoundBtn:SetScript("OnClick", function()
        FI.PlayAlertSound()
    end)
    --]]

    -- Checkbox: show minimap button
    local minimapCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    minimapCheck:SetSize(26, 26)
    minimapCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 418)
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

    -- Checkbox: verbose chat log
    local verboseCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    verboseCheck:SetSize(26, 26)
    verboseCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yBase - 452)
    verboseCheck:SetChecked(FI_Config.verbose or false)

    local verboseLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verboseLabel:SetPoint("LEFT", verboseCheck, "RIGHT", 4, 0)
    verboseLabel:SetText("Show chat notifications")

    verboseCheck:SetScript("OnClick", function(self)
        FI_Config.verbose = self:GetChecked()
    end)
    verboseCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show chat notifications", 1, 1, 1)
        GameTooltip:AddLine("Prints a message in chat whenever\nthe macros are created or updated.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    verboseCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Input: mark macro name
    local markNameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markNameLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 490)
    markNameLabel:SetText("Mark macro name:")

    local markNameInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    markNameInput:SetSize(sepWidth - 66, 20)
    markNameInput:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, yBase - 506)
    markNameInput:SetAutoFocus(false)
    markNameInput:SetMaxLetters(16)
    markNameInput:SetText(FI_Config.markMacroName or "0FI-Mark")

    local markCharCount = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markCharCount:SetPoint("TOPLEFT", markNameInput, "BOTTOMLEFT", 0, -2)
    markCharCount:SetTextColor(0.5, 0.5, 0.5)
    markCharCount:SetText(#(FI_Config.markMacroName or "0FI-Mark") .. "/16 — Leave empty to reset to default")

    markNameInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            markCharCount:SetTextColor(0.5, 0.5, 0.5)
        end
        markCharCount:SetText(#self:GetText() .. "/16 — Leave empty to reset to default")
    end)

    -- Input: kick macro name
    local kickNameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    kickNameLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 544)
    kickNameLabel:SetText("Kick macro name:")

    local kickNameInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    kickNameInput:SetSize(sepWidth - 66, 20)
    kickNameInput:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, yBase - 560)
    kickNameInput:SetAutoFocus(false)
    kickNameInput:SetMaxLetters(16)
    kickNameInput:SetText(FI_Config.kickMacroName or "0FI-Kick")

    local kickCharCount = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    kickCharCount:SetPoint("TOPLEFT", kickNameInput, "BOTTOMLEFT", 0, -2)
    kickCharCount:SetTextColor(0.5, 0.5, 0.5)
    kickCharCount:SetText(#(FI_Config.kickMacroName or "0FI-Kick") .. "/16 — Leave empty to reset to default")

    kickNameInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            kickCharCount:SetTextColor(0.5, 0.5, 0.5)
        end
        kickCharCount:SetText(#self:GetText() .. "/16 — Leave empty to reset to default")
    end)

    local function SaveMarkName()
        local text = strtrim(markNameInput:GetText())
        if text == "" then text = "0FI-Mark" end
        local kickName = FI_Config.kickMacroName or "0FI-Kick"
        if text == kickName then
            markNameInput:SetText(FI_Config.markMacroName or "0FI-Mark")
            markNameInput:ClearFocus()
            markCharCount:SetTextColor(1, 0.27, 0.27)
            return
        end
        markNameInput:SetText(text)
        FI_Config.markMacroName = text
        markNameInput:ClearFocus()
        FI.UpdateMacros()
    end

    local markNameSaveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    markNameSaveBtn:SetSize(50, 22)
    markNameSaveBtn:SetPoint("LEFT", markNameInput, "RIGHT", 4, 0)
    markNameSaveBtn:SetText("Save")
    markNameSaveBtn:SetScript("OnClick", SaveMarkName)

    markNameInput:SetScript("OnEnterPressed", function() SaveMarkName() end)
    markNameInput:SetScript("OnEscapePressed", function(self)
        self:SetText(FI_Config.markMacroName or "0FI-Mark")
        self:ClearFocus()
    end)

    local function SaveKickName()
        local text = strtrim(kickNameInput:GetText())
        if text == "" then text = "0FI-Kick" end
        local markName = FI_Config.markMacroName or "0FI-Mark"
        if text == markName then
            kickNameInput:SetText(FI_Config.kickMacroName or "0FI-Kick")
            kickNameInput:ClearFocus()
            kickCharCount:SetTextColor(1, 0.27, 0.27)
            return
        end
        kickNameInput:SetText(text)
        FI_Config.kickMacroName = text
        kickNameInput:ClearFocus()
        FI.UpdateMacros()
    end

    local kickNameSaveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    kickNameSaveBtn:SetSize(50, 22)
    kickNameSaveBtn:SetPoint("LEFT", kickNameInput, "RIGHT", 4, 0)
    kickNameSaveBtn:SetText("Save")
    kickNameSaveBtn:SetScript("OnClick", SaveKickName)

    kickNameInput:SetScript("OnEnterPressed", function() SaveKickName() end)
    kickNameInput:SetScript("OnEscapePressed", function(self)
        self:SetText(FI_Config.kickMacroName or "0FI-Kick")
        self:ClearFocus()
    end)

    -- Refresh macros button
    local regenBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    regenBtn:SetSize(248, 28)
    regenBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yBase - 600)
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
            mouseoverCheck:Disable()
            minimapCheck:Disable()
            markNameInput:Disable()
            markNameSaveBtn:Disable()
            kickNameInput:Disable()
            kickNameSaveBtn:Disable()
            regenBtn:Disable()
        else
            enemyOnlyCheck:Enable()
            mouseoverCheck:Enable()
            minimapCheck:Enable()
            markNameInput:Enable()
            markNameSaveBtn:Enable()
            kickNameInput:Enable()
            kickNameSaveBtn:Enable()
            regenBtn:Enable()
        end
        -- verboseCheck, announceCheck and watermarkCheck are intentionally not disabled in combat (no macro changes needed)
    end

    parent:RegisterEvent("PLAYER_REGEN_DISABLED")
    parent:RegisterEvent("PLAYER_REGEN_ENABLED")
    parent:SetScript("OnEvent", function(self, event)
        SetCombatState(event == "PLAYER_REGEN_DISABLED")
    end)

    return {
        infoLabel        = infoLabel,
        spellLabel       = spellLabel,
        markLabel        = markLabel,
        markButtons      = markButtons,
        enemyOnlyCheck   = enemyOnlyCheck,
        mouseoverCheck   = mouseoverCheck,
        markModeDropdown = markModeDropdown,
        minimapCheck     = minimapCheck,
        verboseCheck     = verboseCheck,
        announceCheck    = announceCheck,
        watermarkCheck   = watermarkCheck,
        watermarkLabel   = watermarkLabel,
        markNameInput    = markNameInput,
        kickNameInput    = kickNameInput,
        -- TODO: cast alert UI disabled
        -- castAlertCheck   = castAlertCheck,
        -- alertSoundDropdown = alertSoundDropdown,
        getMarkModeText  = GetMarkModeText,
        setCombatState   = SetCombatState,
    }
end

-- Floating popup menu

local function CreateMenu()
    if FI.MenuFrame then return end

    FI.MenuFrame = CreateFrame("Frame", "FocusInterruptMenu", UIParent, "BasicFrameTemplateWithInset")
    FI.MenuFrame:SetSize(280, 686)
    FI.MenuFrame:SetPoint("CENTER")
    FI.MenuFrame:SetMovable(true)
    FI.MenuFrame:EnableMouse(true)
    FI.MenuFrame:RegisterForDrag("LeftButton")
    FI.MenuFrame:SetScript("OnDragStart", FI.MenuFrame.StartMoving)
    FI.MenuFrame:SetScript("OnDragStop", FI.MenuFrame.StopMovingOrSizing)
    FI.MenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    FI.MenuFrame:Hide()
    FI.MenuFrame.TitleText:SetText(FI.DISPLAY_NAME)
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

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(500)
    scrollChild:SetHeight(660)
    scrollFrame:SetScrollChild(scrollChild)

    local title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -6)
    title:SetText(FI.DISPLAY_NAME)

    local refs = BuildPanelContent(scrollChild, {
        yBase        = -30,
        sepWidth     = 500,
        combatAnchor = { "TOPLEFT", "TOPLEFT", 16, -594 },
    })

    panel:SetScript("OnShow", function()
        ApplyRefreshToRefs(refs)
        refs.setCombatState(InCombatLockdown())
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, FI.DISPLAY_NAME)
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
        tooltip:SetText(FI.DISPLAY_NAME)
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
