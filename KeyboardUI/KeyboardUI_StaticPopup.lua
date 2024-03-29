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

local currentPopup, currentButton = 0, 0
local hasBeenMultiplePopups

local popups = {StaticPopup1, StaticPopup2, StaticPopup3, LFGDungeonReadyDialog}
local buttons =
{
	{StaticPopup1.button1, StaticPopup1.button2, StaticPopup1.button3, StaticPopup1.button4},
	{StaticPopup2.button1, StaticPopup2.button2, StaticPopup2.button3, StaticPopup2.button4},
	{StaticPopup3.button1, StaticPopup3.button2, StaticPopup3.button3, StaticPopup3.button4},
	LFGDungeonReadyDialog and {LFGDungeonReadyDialogEnterDungeonButton, LFGDungeonReadyDialogLeaveQueueButton},
	PVPReadyDialog and {PVPReadyDialogEnterBattleButton, PVPReadyDialogLeaveQueueButton},
}

local module =
{
	name = "StaticPopup",
	title = SYSTEM_MESSAGES .. " (Popups)",
	frames =
	{
		CreateFrame("Frame", nil, StaticPopup1),
		CreateFrame("Frame", nil, StaticPopup2),
		CreateFrame("Frame", nil, StaticPopup3),
		LFGDungeonReadyDialog and CreateFrame("Frame", nil, LFGDungeonReadyDialog),
		PVPReadyDialog and CreateFrame("Frame", nil, PVPReadyDialog),
	},
	secureButtons =
	{
		bindingDoAction1Button = function() return currentPopup > 0 and buttons[currentPopup][1] and buttons[currentPopup][1]:IsVisible() and buttons[currentPopup][1] end,
		bindingDoAction2Button = function() return currentPopup > 0 and buttons[currentPopup][2] and buttons[currentPopup][2]:IsVisible() and buttons[currentPopup][2] end,
		bindingDoAction3Button = function() return currentPopup > 0 and buttons[currentPopup][3] and buttons[currentPopup][3]:IsVisible() and buttons[currentPopup][3] end,
		bindingDoAction4Button = function() return currentPopup > 0 and buttons[currentPopup][4] and buttons[currentPopup][4]:IsVisible() and buttons[currentPopup][4] end,
		bindingDoActionButton = function() return currentButton > 0 and buttons[currentPopup][currentButton] end,
	},
}

KeyboardUI:RegisterModule(module)

local function isVisible(frame)
	return frame:IsVisible()
end

local function getPopupText()
	if currentPopup < 4 then
		return popups[currentPopup].text:GetText()
	elseif currentPopup == 4 then
		return (LFGDungeonReadyDialogInstanceInfoFrameName:GetText() or "") .. " " .. (LFGDungeonReadyDialogInstanceInfoFrameStatusText:GetText() or "") .. " " .. (LFGDungeonReadyDialogYourRoleDescription:GetText() or "")
	else -- if currentPopup == 5 then
		return (PVPReadyDialogInstanceInfoFrameName:GetText() or "") .. " " .. (PVPReadyDialogInstanceInfoFrameStatusText:GetText() or "") .. " " .. (PVPReadyDialogYourRoleDescription:GetText() or "")
	end
end

function module:NextEntry()
	local newPopup = module:findNextInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
		currentPopup, currentButton = newPopup, 0
		module:updatePriorityKeybinds()
		return getPopupText()
	elseif currentPopup > 0 then
		return getPopupText()
	end
end

function module:PrevEntry()
	local newPopup = module:findPrevInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
		currentPopup, currentButton = newPopup, 0
		module:updatePriorityKeybinds()
		return getPopupText()
	elseif currentPopup > 0 then
		return getPopupText()
	end
end

function module:GetShortTitle()
	return currentPopup > 0 and getPopupText()
end

function module:GetLongDescription()
	if currentPopup > 0 then
		local tbl = {}
		for i, button in ipairs(buttons[currentPopup]) do
			local txt = button:GetText()
			if txt then
				tinsert(tbl, button:GetText())
			end
		end
		local delim = " " .. QUEST_LOGIC_OR .. " "
		return "Popup: " ..getPopupText() .. " " .. table.concat(tbl, delim)
	end
end

function module:Forward()
	if currentPopup > 0 then
		currentButton = module:findNextInTable(buttons[currentPopup], currentButton, isVisible) or 0
		if currentButton > 0 then
			module:updatePriorityKeybinds()
			return buttons[currentPopup][currentButton]:GetText()	
		end
	end
end

function module:Backward()
	if currentPopup > 0 then
		currentButton = module:findPrevInTable(buttons[currentPopup], currentButton, isVisible) or 0
		if currentButton > 0 then
			module:updatePriorityKeybinds()
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
			if buttons[currentPopup][index] and buttons[currentPopup][index]:IsShown() then
				buttons[currentPopup][index]:Click()
			end
		elseif currentButton > 0 then
			buttons[currentPopup][currentButton]:Click()
		end
	end
end

local function popupOnShow(frame)
	currentPopup = 
		frame == LFGDungeonReadyDialog and 4 
		or frame == PVPReadyDialog and 5 
		or frame:GetID()	-- static popups 1, 2 or 3
	currentButton = 0
	module:updatePriorityKeybinds()
	if currentPopup < 4 then
		if frame.text:GetText() == "" or frame.text:GetText() == " " then
			C_Timer.After(0.1, function()
				module:ttsInterrupt("Popup! " .. getPopupText())
			end)
		else
			module:ttsInterrupt("Popup! " .. getPopupText())
		end
	else -- if currentPopup >= 4
		module:ttsInterrupt("Dungeon! " .. getPopupText())
	end
end

local function popupOnHide(frame)
	if currentPopup == frame:GetID() then
		currentPopup, currentButton = module:findNextInTable(popups, currentPopup, isVisible) or 0, 0
		if currentPopup > 0 then
			module:updatePriorityKeybinds()
			module:ttsInterrupt("Another popup! " .. getPopupText())
		end
	end
end

for __, frame in pairs(popups) do
	frame:HookScript("OnShow", popupOnShow)
	frame:HookScript("OnHide", popupOnHide)
end