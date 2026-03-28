-- FocusInterrupt / Core.lua

local FI = FocusInterruptAddon

local PREFIX  = "|cffffaa00" .. FocusInterruptAddon.TITLE .. ":|r "
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

local HEALERS = {
    HOLY         = true,
    DISCIPLINE   = true,
    RESTORATION  = true,
    PRESERVATION = true,
}

local function SpecialCases(class, spec)
    if class == "DRUID" and spec == "Balance" then
        return INTERRUPTS["DRUID_BALANCE"]
    end
    return INTERRUPTS[class]
end

function FI.GetInterrupt()
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
    local isHealer = HEALERS[currentSpecName]

    if isHealer and class ~= "SHAMAN" then
        return false
    end

    return SpecialCases(class, currentSpecName)
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
    local currentSpec = GetSpecialization()
    local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
    local spell = FI.GetInterrupt()

    print(PREFIX .. "Loading: " .. currentSpecName)

    if spell == false then
        print(PREFIX .. C_ERROR .. "Your spec has no interrupt. Macros not generated.|r")
        return
    end

    local unitCondition = FI_Config.focusEnemyOnly
        and "[@mouseover,exists,nodead,harm][@target,exists,nodead,harm]"
        or  "[@mouseover,exists,nodead][@target,exists,nodead]"

    local markCondition = FI_Config.focusEnemyOnly
        and "[exists,nodead,harm]"
        or  "[exists,nodead]"

    local markBody = "/focus " .. unitCondition .. "\n" ..
                     "/target " .. unitCondition .. "\n" ..
                     "/tm " .. markCondition .. " " .. FI_Config.markIndex .. "\n" ..
                     "/targetlasttarget"

    if not UpsertMacro("0FI-Mark", "ability_hunter_markedfordeath", markBody) then return end

    local kickBody = "#showtooltip " .. spell .. "\n" ..
                     "/cast [@focus,exists][@target] " .. spell
    UpsertMacro("0FI-Kick", nil, kickBody)

    print(PREFIX .. C_OK .. "Macros updated (mark " .. FI_Config.markIndex .. ", kick: " .. spell .. ").|r")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    FI.UpdateMacros()
    if FI.MenuFrame and FI.MenuFrame:IsShown() then
        FI.MenuFrame:RefreshInfo()
    end
end)
