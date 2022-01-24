--[[

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Refer to KeyboardUI.lua for full details

--]]


local KeyboardUI = select(2, ...)

local module =
{
	name = "StaticPopup",
	frame = CreateFrame("Frame", nil, StaticPopup1),
	title = SYSTEM_MESSAGES .. " (Popups)"
}

KeyboardUI:RegisterModule(module)

local currentPopup, currentButton = 0, 0
local hasBeenMultiplePopups

local popups = {StaticPopup1, StaticPopup2, StaticPopup3}
local buttons =
{
	{StaticPopup1.button1, StaticPopup1.button2, StaticPopup1.button3, StaticPopup1.button4},
	{StaticPopup2.button1, StaticPopup2.button2, StaticPopup2.button3, StaticPopup2.button4},
	{StaticPopup3.button1, StaticPopup3.button2, StaticPopup3.button3, StaticPopup3.button4},
}

local function assertSecureKeybinds()
	if module:hasFocus() and currentPopup > 0 and not InCombatLockdown() then
		if buttons[currentPopup][1]:IsVisible() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction1Button"), buttons[currentPopup][1]:GetName(), "LeftButton")
		end
		if buttons[currentPopup][2]:IsVisible() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction2Button"), buttons[currentPopup][2]:GetName(), "LeftButton")
		end
		if buttons[currentPopup][3]:IsVisible() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction3Button"), buttons[currentPopup][3]:GetName(), "LeftButton")
		end
		if buttons[currentPopup][4]:IsVisible() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction4Button"), buttons[currentPopup][4]:GetName(), "LeftButton")
		end
		if currentButton > 0 then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoActionButton"), buttons[currentPopup][currentButton]:GetName(), "LeftButton")
		end
	end
end

local function removeSecureKeybinds()
	if not InCombatLockdown() then
		ClearOverrideBindings(module.frame)
	end
end

module.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
module.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

module.frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		removeSecureKeybinds()
	elseif event == "PLAYER_REGEN_ENABLED" then
		assertSecureKeybinds()
	end
end)

function module:GainFocus()
	assertSecureKeybinds()
end

function module:LoseFocus()
	removeSecureKeybinds()
end

local function isVisible(frame)
	return frame:IsVisible()
end

function module:NextEntry()
	local newPopup = module:findNextInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
		currentPopup, currentButton = newPopup, 0
		removeSecureKeybinds()
		assertSecureKeybinds()
		return popups[currentPopup].text:GetText()	
	elseif currentPopup > 0 then
		return popups[currentPopup].text:GetText()
	end
	currentPopup = 0
end

function module:PrevEntry()
	local newPopup = module:findPrevInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
		removeSecureKeybinds()
		assertSecureKeybinds()
		currentPopup, currentButton = newPopup, 0
		return popups[currentPopup].text:GetText()	
	elseif currentPopup > 0 then
		return popups[currentPopup].text:GetText()
	end
	currentPopup = 0
end

function module:RefreshEntry()
	return currentPopup > 0 and popups[currentPopup].text:GetText()
end

function module:GetEntryLongDescription()
	return currentPopup > 0 and "Popup: " .. popups[currentPopup].text:GetText()
end

function module:Forward()
	if currentPopup > 0 then
		currentButton = module:findNextInTable(buttons[currentPopup], currentButton, isVisible) or 0
		if currentButton > 0 then
			removeSecureKeybinds()
			assertSecureKeybinds()
			return buttons[currentPopup][currentButton]:GetText()	
		end
	end
end

function module:Backward()
	if currentPopup > 0 then
		currentButton = module:findPrevInTable(buttons[currentPopup], currentButton, isVisible) or 0
		if currentButton > 0 then
			removeSecureKeybinds()
			assertSecureKeybinds()
			return buttons[currentPopup][currentButton]:GetText()	
		end
	end
end

function module:Actions()
	if currentPopup > 0 then
		local retVals = {}
		for i, button in ipairs(buttons[currentPopup]) do
			if button:IsVisible() then
				if button:IsEnabled() then
					retVals[i] = button:GetText()
				else
					retVals[i] = button:GetText() .. " " .. ADDON_DISABLED
				end
			else
				retVals[i] = ""
			end
		end
		return unpack(retVals)
	end
end

function module:DoAction(index)
	-- This can probably be replaced with nop() because of assertSecureKeybinds()
	if currentPopup then
		if index then
			buttons[currentPopup][index]:Click()
		elseif currentButton then
			buttons[currentPopup][currentButton]:Click()
		end
	end
end

local function popupOnShow(frame)
	currentPopup, currentButton = frame:GetID(), 0
	assertSecureKeybinds()
	if frame.text:GetText() == "" or frame.text:GetText() == " " then
		C_Timer.After(0.1, function()
			module:ttsInterrupt("Popup! " .. frame.text:GetText())
		end)
	else
		module:ttsInterrupt("Popup! " .. frame.text:GetText())
	end
end

local function popupOnHide(frame)
	if currentPopup == frame:GetID() then
		currentPopup = module:findNextInTable(popups, currentPopup, isVisible)
		currentButton = 0
		removeSecureKeybinds()
		if currentPopup then
			assertSecureKeybinds()
			module.frame:SetParent(popups[currentPopup])
			module:ttsInterrupt("Another popup! " .. popups[currentPopup].text:GetText())
		else
			currentPopup = 0
			
		end
	end
end

for __, frame in pairs(popups) do
	frame:HookScript("OnShow", popupOnShow)
	frame:HookScript("OnHide", popupOnHide)
end