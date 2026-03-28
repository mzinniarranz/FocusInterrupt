-- FocusInterrupt / Core.lua

local FI = FocusInterruptAddon

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
        if globalCount >= 138 then
            print("|cffff4444" .. FI.TITLE .. ":|r Cannot create macro \"" .. name .. "\": global macro limit reached (138/138).")
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

    print("|cffff4444" .. FI.TITLE .. ":|r Loading: " .. currentSpecName)

    if spell == false then
        print("|cffff4444" .. FI.TITLE .. ":|r Your spec has no interrupt. Macros not generated.")
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

    if spell then
        local kickBody = "#showtooltip " .. spell .. "\n" ..
                         "/cast [@focus,exists][@target] " .. spell
        UpsertMacro("0FI-Kick", nil, kickBody)
    else
        UpsertMacro("0FI-Kick", "INV_Misc_QuestionMark", "-- No interrupt for this class")
        print("|cffff4444" .. FI.TITLE .. ":|r Your class has no direct interrupt.")
    end

    print("|cffff4444" .. FI.TITLE .. ":|r Macros updated (mark " .. FI_Config.markIndex .. ", kick: " .. (spell or "no kick") .. ")")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(self, event, ...)
    FI.UpdateMacros()
    if FI.MenuFrame and FI.MenuFrame:IsShown() then
        FI.MenuFrame:RefreshInfo()
    end
end)
