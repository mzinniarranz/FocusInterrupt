FocusInterruptAddon = FocusInterruptAddon or {}
FocusInterruptAddon.TITLE = "FocusInterrupt"

local DB_VERSION = 3

FI_Config = FI_Config or {
    dbVersion = DB_VERSION,
    markIndex = 1,
    minimapBtn = { hide = false },
    focusEnemyOnly = false,
    markOnly = false,
}

-- Migrate saved config from older versions
local migrationFrame = CreateFrame("Frame")
migrationFrame:RegisterEvent("ADDON_LOADED")
migrationFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "FocusInterrupt" then
        if (FI_Config.dbVersion or 0) < DB_VERSION then
            FI_Config.focusEnemyOnly = FI_Config.focusEnemyOnly or false
            FI_Config.markOnly = FI_Config.markOnly or false
            FI_Config.dbVersion = DB_VERSION
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
