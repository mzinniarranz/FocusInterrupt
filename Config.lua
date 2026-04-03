FocusInterruptAddon = FocusInterruptAddon or {}
FocusInterruptAddon.TITLE = "FocusInterrupt"

local DB_VERSION = 6

FI_Config = FI_Config or {
    dbVersion = DB_VERSION,
    markIndex = 1,
    minimapBtn = { hide = false },
    focusEnemyOnly = false,
    markMode = "both", -- "both", "markOnly", "focusOnly"
    verbose = false,
    readyCheckAnnounce = true,
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
            FI_Config.dbVersion = DB_VERSION
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
