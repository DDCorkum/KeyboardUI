local KeyboardUI = select(2, ...)

KeyboardUI.text = KeyboardUI.text or {}

local L = KeyboardUI.text
local language = GetLocale():sub(1,2)

setmetatable(L, {__index = function(__, key) return tostring(key) end})

-------------------------
-- enUS and fallback for all languages

L["FROM_TO"] = "from %1$s to %2$s"
L["PRESS_TO"] = "Press %1$s to %2$s"


-------------------------
-- fr

if language == "fr" then

L["FROM_TO"] = "de %1$s à %2$s"
L["PRESS_TO"] = "Appuyez sur %1$s pour %2$s"


-------------------------
-- es

elseif language == "es" then

L["FROM_TO"] = "de %1$s a %2$s"


end