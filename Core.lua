-- FocusInterrupt / Core.lua

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

function FI_GetInterrupt()
    local _, class = UnitClass("player")
    local currentSpec = GetSpecialization()
    local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
    local isHealer = HEALERS[currentSpecName]

    print("|cffff4444" .. FI_TITLE .. ":|r Loading: " .. currentSpecName .. (isHealer and " (Healer)" or ""))

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
        local globalCount, perCharCount = GetNumMacros()
        if globalCount >= 138 then
            print("|cffff4444" .. FI_TITLE .. ":|r Cannot create macro \"" .. name .. "\": global macro limit reached (138/138).")
            return false
        end
        CreateMacro(name, resolvedIcon, body, false)
    end
    return true
end

function FI_UpdateMacros()
    local spell = FI_GetInterrupt()

    if spell == false then
        print("|cffff4444" .. FI_TITLE .. ":|r Your spec has no interrupt. Macros not generated.")
        return
    end

    local markBody = "/focus [@mouseover,exists,nodead][@target,exists,nodead]\n" ..
                     "/target [@mouseover,exists,nodead][@target,exists,nodead]\n" ..
                     "/tm [exists,nodead] " .. FI_Config.markIndex .. "\n" ..
                     "/targetlasttarget"
                     
    if not UpsertMacro("0FI-Mark", "ability_hunter_markedfordeath", markBody) then return end

    if spell then
        local kickBody = "#showtooltip " .. spell .. "\n" ..
                         "/cast [@focus,exists][@target] " .. spell
        UpsertMacro("0FI-Kick", nil, kickBody)
    else
        UpsertMacro("0FI-Kick", "INV_Misc_QuestionMark", "-- No interrupt for this class")
        print("|cffff4444" .. FI_TITLE .. ":|r Your class has no direct interrupt.")
    end

    print("|cffff4444" .. FI_TITLE .. ":|r Macros updated (mark " .. FI_Config.markIndex .. ", kick: " .. (spell or "no kick") .. ")")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(self, event, ...)
    FI_UpdateMacros()
    if FI_MenuFrame and FI_MenuFrame:IsShown() then
        FI_MenuFrame:RefreshInfo()
    end
end)