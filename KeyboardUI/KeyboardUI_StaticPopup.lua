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

StaticFoo = module

local currentPopup, currentButton = 0, 0
local hasBeenMultiplePopups

local popups = {StaticPopup1, StaticPopup2, StaticPopup3}
local buttons =
{
	{StaticPopup1.button1, StaticPopup1.button2, StaticPopup1.button3, StaticPopup1.button4},
	{StaticPopup2.button1, StaticPopup2.button2, StaticPopup2.button3, StaticPopup2.button4},
	{StaticPopup3.button1, StaticPopup3.button2, StaticPopup3.button3, StaticPopup3.button4},
}

local function isVisible(frame)
	return frame:IsVisible()
end

function module:NextEntry()
	local newPopup = module:findNextInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
		currentPopup, currentButton = newPopup, 0
		return popups[currentPopup].text:GetText()	
	elseif currentPopup > 0 then
		return popups[currentPopup].text:GetText()
	end
	currentPopup = 0
end

function module:PrevEntry()
	local newPopup = module:findPrevInTable(popups, currentPopup, isVisible)
	if newPopup and newPopup ~= currentPopup then
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
			return buttons[currentPopup][currentButton]:GetText()	
		end
	end
end

function module:Backward()
	if currentPopup > 0 then
		currentButton = module:findPrevInTable(buttons[currentPopup], currentButton, isVisible) or 0
		if currentButton > 0 then
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
	C_Timer.After(0, function()
		module:ttsInterrupt("Popup! " .. frame.text:GetText())
	end)
end

local function popupOnHide(frame)
	if currentPopup == frame:GetID() then
		currentPopup = module:findNextInTable(popups, currentPopup, isVisible)
		currentButton = 0
		if currentPopup then
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