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

local currentButtons = {}	-- n is the number of open drop down lists (ie, depth); tbl[n] is the button selected within it

local function getName(offset)
	return #currentButtons > 0 and "DropDownList" .. #currentButtons .. "Button" .. (currentButtons[#currentButtons] + (offset or 0))
end

local module =
{
	name = "UIDropDownMenu",
	title = "Drop down menus",
	frame = CreateFrame("Frame", nil, DropDownList1),
	secureButtons =
	{
		bindingDoActionButton = function() return getName(0) end,
	},
}

KeyboardUI:RegisterModule(module)


local function getButton(offset)
	return #currentButtons > 0 and _G[getName(offset)]
end

local function getText()
	return #currentButtons > 0 and _G["DropDownList" .. #currentButtons .. "Button" .. currentButtons[#currentButtons] .. "NormalText"]:GetText()
end

function module:NextEntry()
	local btn = getButton()
	if btn then
		local nextBtn = getButton(1)
		if nextBtn and nextBtn:IsVisible() then
			btn.Highlight:Hide()
			nextBtn.Highlight:Show()
			currentButtons[#currentButtons] = currentButtons[#currentButtons] + 1
			module:updatePriorityKeybinds()
		end
		return getText()
	end
end

function module:PrevEntry()
	local btn = getButton()
	if btn then
		local prevBtn = getButton(-1)
		if prevBtn and prevBtn:IsVisible() then
			btn.Highlight:Hide()
			prevBtn.Highlight:Show()
			currentButtons[#currentButtons] = currentButtons[#currentButtons] - 1
			module:updatePriorityKeybinds()
		end
		return getText()
	end
end

function module:RefreshEntry()
	return getButton() or self:Backward() or self:PrevEntry() or self:NextEntry() or self:Forward()	and getText() -- failsafe nudge!
end

function module:GetEntryLongDescription()
	-- NYI.  Eventually this needs to describe the setting (is it checked, does it expand, etc.)
	return getText()
end

function module:Forward()
	local btn = getButton()
	if btn.hasArrow and btn:IsEnabled() then
		ToggleDropDownMenu(btn:GetParent():GetID() + 1, btn.value, nil, nil, nil, nil, btn.menuList, btn)
		tinsert(currentButtons, 1)
		local fwdButton = getButton()
		if fwdButton then
			fwdButton.Highlight:Show()
			return getText()
		end
		tremove(currentButtons)
	end
	CloseDropDownMenus(btn:GetParent():GetID() + 1)
end

function module:Backward()
	local btn = getButton()
	if btn then
		btn.Highlight:Hide()
		currentButtons[#currentButtons] = nil
		CloseDropDownMenus(btn:GetParent():GetID())
	end
	if getButton() then
		return getText()
	end
end

function module:Actions()
	-- NYI.
end

function module:DoAction(index)
	-- Deliberately nop(); replaced with secureButtons.bindingDoActionButton
end

DropDownList1:HookScript("OnShow", function()
	currentButtons[1] = 1
	getButton().Highlight:Show()
	module:updatePriorityKeybinds()
	local text = getText()
	if text then
		module:ttsInterrupt("Dropdown" .. getText(), KUI_QUICK, KUI_MF)
	end
end)

DropDownList1:HookScript("OnHide", function()
	-- this might not even be necessary
	if getButton() then
		getButton().Highlight:Hide()
	end
	wipe(currentButtons)
end)

hooksecurefunc("UIDropDownMenuButton_OnClick", function(self)
	if self.keepShownOnClick and not self.notCheckable then
		module:ttsYield((_G[self:GetName().."Check"]:IsVisible() and "Checked " or "Unchecked ") .. self:GetFontString():GetText(), KUI_RAPID, KUI_MP)
	elseif self.func and not self.hasArrow then
		module:ttsYield("Selected " .. self:GetFontString():GetText(), KUI_RAPID, KUI_MP)
	else
		module:ttsYield("Clicked " .. self:GetFontString():GetText(), KUI_RAPID, KUI_MP)
	end
end)