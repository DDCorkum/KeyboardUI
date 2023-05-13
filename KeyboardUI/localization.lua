local KeyboardUI = select(2, ...)

KeyboardUI.text = KeyboardUI.text or {}

local L = KeyboardUI.text
local language = GetLocale():sub(1,2)

setmetatable(L, {__index = function(__, key) return tostring(key) end})

-------------------------
-- enUS and fallback for all languages

L["FROM_TO"] = "from %1$s to %2$s"
L["PRESS_TO"] = "Press %1$s to %2$s"
L["PRESS_HOTKEYS"] = "Press %s for available hotkeys"


-------------------------
-- fr

if language == "fr" then

L["FROM_TO"] = "|2 %1$s à %2$s"
L["PRESS_TO"] = "Appuyez sur %1$s pour %2$s"
L["PRESS_HOTKEYS"] = "Appuyez sur %s pour les raccourcis disponibles"


-------------------------
-- de

elseif language == "de" then

L["FROM_TO"] = "von %1$s bis %2$s"
L["PRESS_TO"] = "Drücken Sie %1$s für %2$s"
L["PRESS_HOTKEYS"] = "Drücken Sie %s für verfügbare Hotkeys"


-------------------------
-- es

elseif language == "es" then

L["FROM_TO"] = "de %1$s a %2$s"
L["PRESS_TO"] = "Presiona %s para habrir %s"
L["PRESS_HOTKEYS"] = "Presiona %s para las teclas rápido disponibles"

end