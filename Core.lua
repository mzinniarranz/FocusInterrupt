-- FocusInterrupt / Core.lua

local FI = FocusInterruptAddon

local PREFIX  = "|cffffaa00" .. FocusInterruptAddon.TITLE .. ":|r "
FI.PREFIX = PREFIX
local C_ERROR = "|cffff4444"
local C_OK    = "|cff00ff00"

local INTERRUPTS = {
    WARRIOR       = "Pummel",
    PALADIN       = "Rebuke",
    HUNTER        = "Counter Shot",
    ROGUE         = "Kick",
    DEATHKNIGHT   = "Mind Freeze",
    MONK          = "Spear Hand Strike",
    DRUID         = "Skull Bash",
    DRUID_BALANCE = "Solar Beam",
    DEMONHUNTER   = "Disrupt",
    EVOKER        = "Quell",
    SHAMAN        = "Wind Shear",
    MAGE          = "Counterspell",
    WARLOCK       = "Spell Lock",
    PRIEST        = "Silence",
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

FI.MARK_NAMES = {
    "Star", "Circle", "Diamond", "Triangle",
    "Moon", "Square", "Cross", "Skull",
}

function FI.Log(msg)
    if FI_Config.verbose then
        print(msg)
    end
end

function FI.GetInterrupt()
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local specID = currentSpec and GetSpecializationInfo(currentSpec)

    if HEALER_SPEC_IDS[specID] then
        return false
    end

    if specID == BALANCE_DRUID_SPEC_ID then
        return INTERRUPTS["DRUID_BALANCE"]
    end

    return INTERRUPTS[class]
end

local function UpsertMacro(name, icon, body)
    local resolvedIcon = icon or "INV_Misc_QuestionMark"
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

    local spell = FI.GetInterrupt()
    local markMode = FI_Config.markMode or "both"

    local markBody
    if markMode == "markOnly" then
        markBody = "/tm [@mouseover,exists,nodead][] " .. FI_Config.markIndex
    else
        local stopLine = FI_Config.focusEnemyOnly
            and "/stopmacro [@mouseover,exists,nodead,noharm]\n"
            or  ""

        local condition = FI_Config.focusEnemyOnly
            and "[@mouseover,exists,nodead,harm][@target,exists,nodead,harm]"
            or  "[@mouseover,exists,nodead][]"

        if markMode == "focusOnly" then
            markBody = stopLine .. "/focus " .. condition
        else -- "both"
            markBody = stopLine ..
                       "/focus " .. condition .. "\n" ..
                       "/tm " .. condition .. " " .. FI_Config.markIndex
        end
    end

    if not UpsertMacro("0FI-Mark", "ability_hunter_markedfordeath", markBody) then return end

    if spell then
        local kickBody = "#showtooltip " .. spell .. "\n" ..
                         "/cast [@focus,exists][@target] " .. spell
        UpsertMacro("0FI-Kick", nil, kickBody)
    end

    local kickInfo = spell and (", kick: " .. spell) or ", no kick (healer spec)"
    FI.Log(PREFIX .. C_OK .. "Macros updated (mark " .. FI_Config.markIndex .. kickInfo .. ").|r")
end

local pendingUpdate = false

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("READY_CHECK")
f:SetScript("OnEvent", function(self, event, unit)
    if event == "READY_CHECK" then
        if not FI_Config.readyCheckAnnounce then return end
        if FI_Config.markMode == "focusOnly" then return end
        if select(2, GetInstanceInfo()) ~= "party" then return end
        local idx = FI_Config.markIndex
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
        SendChatMessage("Interrupt mark: {rt" .. idx .. "} " .. FI.MARK_NAMES[idx], channel)
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
