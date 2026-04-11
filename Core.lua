-- FocusInterrupt / Core.lua

local FI = FocusInterruptAddon

local PREFIX  = "|cffffaa00" .. FocusInterruptAddon.TITLE .. ":|r "
FI.PREFIX = PREFIX
local C_ERROR = "|cffff4444"
local C_OK    = "|cff00ff00"

local INTERRUPT_SPELLS = {
    WARRIOR       = 6552,   -- Pummel
    PALADIN       = 96231,  -- Rebuke
    HUNTER        = 147362, -- Counter Shot
    ROGUE         = 1766,   -- Kick
    DEATHKNIGHT   = 47528,  -- Mind Freeze
    MONK          = 116705, -- Spear Hand Strike
    DRUID         = 106839, -- Skull Bash
    DRUID_BALANCE = 78675,  -- Solar Beam
    DEMONHUNTER   = 183752, -- Disrupt
    EVOKER        = 351338, -- Quell
    SHAMAN        = 57994,  -- Wind Shear
    MAGE          = 2139,   -- Counterspell
    WARLOCK       = 119910, -- Spell Lock (Command Demon)
    WARLOCK_DEMO  = 119914, -- Axe Toss (Command Demon)
    PRIEST        = 15487,  -- Silence
}

-- Spec IDs are locale-independent, unlike spec names returned by GetSpecializationInfo
local HEALER_SPEC_IDS = {
    [65]   = true, -- Holy Paladin
    [105]  = true, -- Restoration Druid
    [256]  = true, -- Discipline Priest
    [257]  = true, -- Holy Priest
    [270]  = true, -- Mistweaver Monk
    [1468] = true, -- Preservation Evoker
}

local BALANCE_DRUID_SPEC_ID = 102
local DEMO_WARLOCK_SPEC_ID  = 266

local function ValidMarkIndex(index)
    if type(index) ~= "number" or index < 1 or index > 8 then return 1 end
    return math.floor(index)
end
FI.ValidMarkIndex = ValidMarkIndex

FI.MARK_NAMES = {
    "Star", "Circle", "Diamond", "Triangle",
    "Moon", "Square", "Cross", "Skull",
}

FI.ALERT_SOUNDS = {
    { name = "Raid Warning",   soundKitID = 8959  },
    { name = "Ready Check",    soundKitID = 8960  },
    { name = "Fel Reaver",     soundKitID = 10571 },
    { name = "Dungeon Ready",  soundKitID = 11466 },
    { name = "Alarm Clock",    soundKitID = 12867 },
    { name = "PVP Warning",    soundKitID = 8174  },
}

function FI.ValidAlertSoundIndex(index)
    local idx = index or FI_Config.alertSoundIndex or 1
    if idx < 1 or idx > #FI.ALERT_SOUNDS then idx = 1 end
    return idx
end

function FI.PlayAlertSound(index)
    local sound = FI.ALERT_SOUNDS[FI.ValidAlertSoundIndex(index)]
    PlaySound(sound.soundKitID, "Master", false)
end

function FI.Log(msg)
    if FI_Config.verbose then
        print(msg)
    end
end

local function ResolveSpellName(spellID)
    if not spellID then return nil end
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name
end

function FI.GetInterrupt()
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local specID = currentSpec and GetSpecializationInfo(currentSpec)

    if HEALER_SPEC_IDS[specID] then
        return false
    end

    local key = class
    if specID == BALANCE_DRUID_SPEC_ID then
        key = "DRUID_BALANCE"
    elseif specID == DEMO_WARLOCK_SPEC_ID then
        key = "WARLOCK_DEMO"
    end

    local spellID = INTERRUPT_SPELLS[key]
    local spellName = ResolveSpellName(spellID)
    return spellName, spellID
end

local prevMarkName = nil
local prevKickName = nil

local function FindExistingMacroName(configName, defaultName)
    local name = configName or defaultName
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then return name end
    if name ~= defaultName then
        idx = GetMacroIndexByName(defaultName)
        if idx and idx > 0 then return defaultName end
    end
    return name
end

local function UpsertMacro(name, icon, body, oldName)
    local resolvedIcon = icon or "INV_Misc_QuestionMark"
    if oldName and oldName ~= name then
        local oldIdx = GetMacroIndexByName(oldName)
        if oldIdx and oldIdx > 0 then
            EditMacro(oldIdx, name, resolvedIcon, body)
            return true
        end
    end
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        EditMacro(idx, name, resolvedIcon, body)
    else
        local globalCount = GetNumMacros()
        if globalCount >= 120 then
            print(PREFIX .. C_ERROR .. "Cannot create macro \"" .. name .. "\": global macro limit reached (120/120).|r")
            return false
        end
        CreateMacro(name, resolvedIcon, body, false)
    end
    return true
end

function FI.UpdateMacros()
    if InCombatLockdown() then
        return
    end

    if prevMarkName == nil then
        prevMarkName = FindExistingMacroName(FI_Config.markMacroName, "0FI-Mark")
    end
    if prevKickName == nil then
        prevKickName = FindExistingMacroName(FI_Config.kickMacroName, "0FI-Kick")
    end

    FI_Config.markIndex = ValidMarkIndex(FI_Config.markIndex)

    local spell = FI.GetInterrupt()
    local markMode = FI_Config.markMode or "both"

    local useMouseover = FI_Config.focusMouseover
    local enemyOnly   = FI_Config.focusEnemyOnly

    local condition
    local stopLine = ""

    if useMouseover then
        if enemyOnly then
            stopLine  = "/stopmacro [@mouseover,exists,nodead,noharm]\n"
            condition = "[@mouseover,exists,nodead,harm][@target,exists,nodead,harm]"
        else
            condition = "[@mouseover,exists,nodead][]"
        end
    else
        if enemyOnly then
            condition = "[@target,exists,nodead,harm]"
        else
            condition = "[@target,exists,nodead]"
        end
    end

    local markBody
    if markMode == "markOnly" then
        markBody = "/tm " .. condition .. " " .. FI_Config.markIndex
    elseif markMode == "focusOnly" then
        markBody = stopLine .. "/focus " .. condition
    else -- "both"
        markBody = stopLine ..
                   "/focus " .. condition .. "\n" ..
                   "/tm " .. condition .. " " .. FI_Config.markIndex
    end

    local markName = FI_Config.markMacroName or "0FI-Mark"
    if not UpsertMacro(markName, "ability_hunter_markedfordeath", markBody, prevMarkName) then return end
    prevMarkName = markName

    if spell then
        local kickName = FI_Config.kickMacroName or "0FI-Kick"
        local kickBody = "#showtooltip " .. spell .. "\n" ..
                         "/cast [@focus,exists][@target] " .. spell
        UpsertMacro(kickName, nil, kickBody, prevKickName)
        prevKickName = kickName
    end

    local kickInfo = spell and (", kick: " .. spell) or ", no kick (healer spec)"
    FI.Log(PREFIX .. C_OK .. "Macros updated (mark " .. FI_Config.markIndex .. kickInfo .. ").|r")
end

-- TODO: Focus cast alert disabled – not working reliably, needs more testing
--[[ Cast alert: plays a sound when focus starts an interruptible cast and interrupt is off cooldown
local castAlertFrame = CreateFrame("Frame")
castAlertFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
castAlertFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
castAlertFrame:SetScript("OnEvent", function(self, event)
    if not FI_Config.castAlertSound then return end

    local spell, spellID = FI.GetInterrupt()
    if not spellID then return end

    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if cooldown and cooldown.duration > 1.5 then return end

    local notInterruptible
    if event == "UNIT_SPELLCAST_START" then
        notInterruptible = select(8, UnitCastingInfo("focus"))
    else
        notInterruptible = select(7, UnitChannelInfo("focus"))
    end

    if notInterruptible == false then
        FI.PlayAlertSound()
    end
end)
--]]

local pendingUpdate = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "READY_CHECK" then
        if not FI_Config.readyCheckAnnounce then return end
        if FI_Config.markMode == "focusOnly" then return end
        if select(2, GetInstanceInfo()) ~= "party" then return end
        local idx = FI_Config.markIndex
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
        local msg = "Interrupt mark: {rt" .. idx .. "} " .. FI.MARK_NAMES[idx]
        if FI_Config.announceWatermark then
            msg = msg .. " (Addon: Focus Interrupt)"
        end
        SendChatMessage(msg, channel)
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingUpdate then
            pendingUpdate = false
            FI.UpdateMacros()
        end
        return
    end
    if InCombatLockdown() then
        pendingUpdate = true
        return
    end
    FI.UpdateMacros()
    if FI.MenuFrame and FI.MenuFrame:IsShown() then
        FI.MenuFrame:RefreshInfo()
    end
end)
