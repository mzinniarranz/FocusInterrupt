FocusInterruptAddon = FocusInterruptAddon or {}
FocusInterruptAddon.TITLE = "FocusInterrupt"
FocusInterruptAddon.DISPLAY_NAME = "Focus Interrupt"

local DB_VERSION = 10

FI_Config = FI_Config or {
    dbVersion = DB_VERSION,
    markIndex = 1,
    minimapBtn = { hide = false },
    focusEnemyOnly = false,
    focusMouseover = true,
    markMode = "both", -- "both", "markOnly", "focusOnly"
    verbose = false,
    readyCheckAnnounce = true,
    castAlertSound = false,
    alertSoundIndex = 6,
    announceWatermark = false,
    markMacroName = "0FI-Mark",
    kickMacroName = "0FI-Kick",
}

-- Migrate saved config from older versions
local migrationFrame = CreateFrame("Frame")
migrationFrame:RegisterEvent("ADDON_LOADED")
migrationFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "FocusInterrupt" then
        if (FI_Config.dbVersion or 0) < DB_VERSION then
            FI_Config.focusEnemyOnly = FI_Config.focusEnemyOnly or false
            FI_Config.markMode = FI_Config.markOnly and "markOnly" or (FI_Config.markMode or "both")
            FI_Config.markOnly = nil
            FI_Config.verbose = FI_Config.verbose or false
            if FI_Config.readyCheckAnnounce == nil then FI_Config.readyCheckAnnounce = true end
            if FI_Config.focusMouseover == nil then FI_Config.focusMouseover = true end
            FI_Config.castAlertSound = FI_Config.castAlertSound or false
            FI_Config.alertSoundIndex = FI_Config.alertSoundIndex or 6
            if FI_Config.announceWatermark == nil then FI_Config.announceWatermark = false end
            if FI_Config.markMacroName == nil then FI_Config.markMacroName = "0FI-Mark" end
            if FI_Config.kickMacroName == nil then FI_Config.kickMacroName = "0FI-Kick" end
            FI_Config.dbVersion = DB_VERSION
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
