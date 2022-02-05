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
	name = "UIDropDownMenu",
	frame = CreateFrame("Frame", nil, DropDownList1),
	title = "Drop down menus",
}

KeyboardUI:RegisterModule(module)

local currentButtons = {}	-- n is the number of open drop down lists (ie, depth); tbl[n] is the button selected within it

local function getName(offset)
	offset = offset or 0
	return "DropDownList" .. #currentButtons .. "Button" .. (currentButtons[#currentButtons] + offset)
end

local function getButton(offset)
	return #currentButtons > 0 and _G[getName(offset)]
end

local function getText()
	return #currentButtons > 0 and _G["DropDownList" .. #currentButtons .. "Button" .. currentButtons[#currentButtons] .. "NormalText"]:GetText()
end

local function assertSecureKeybinds()
	if module:hasFocus() and getButton() and not InCombatLockdown() then
		SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoActionButton"), getName(), "LeftButton")
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

function module:NextEntry()
	local btn = getButton()
	if btn then
		local nextBtn = getButton(1)
		if nextBtn and nextBtn:IsVisible() then
			btn.Highlight:Hide()
			nextBtn.Highlight:Show()
			currentButtons[#currentButtons] = currentButtons[#currentButtons] + 1
			removeSecureKeybinds()
			assertSecureKeybinds()
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
			removeSecureKeybinds()
			assertSecureKeybinds()
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
	-- Deliberately nop() because of assertSecureKeybinds()
end

DropDownList1:HookScript("OnShow", function()
	currentButtons[1] = 1
	getButton().Highlight:Show()
	assertSecureKeybinds()
	module:ttsInterrupt(getText(), KUI_QUICK, KUI_MF)
end)

DropDownList1:HookScript("OnHide", function()
	if getButton() then
		getButton().Highlight:Hide()
	end
	wipe(currentButtons)
	removeSecureKeybinds()
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