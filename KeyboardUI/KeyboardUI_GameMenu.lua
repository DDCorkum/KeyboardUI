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

do

	local position = 0
	local buttons = {}

	local module =
	{
		name = "GameMenu",
		title = MAINMENU_BUTTON,
		frame = CreateFrame("Frame", nil, GameMenuFrame),
		secureButtons =
		{
			bindingDoAction1Button = "GameMenuButtonLogout",
			bindingDoAction2Button = "GameMenuButtonQuit",
			bindingDoActionButton = function() return buttons[position]	end,
		},
	}

	KeyboardUI:RegisterModule(module)
	
	for __, frame in ipairs({GameMenuFrame:GetChildren()}) do
		if frame:IsObjectType("Button") and frame:IsShown() then
			tinsert(buttons, frame)
		end
	end
		
	function module:NextEntry()
		if position < #buttons then
			position = position + 1
		end
		module:updatePriorityKeybinds()
		return buttons[position]:GetText()
	end
	
	function module:PrevEntry()
		if position > 1 then
			position = position - 1
		end
		module:updatePriorityKeybinds()
		return buttons[position]:GetText()
	end
	
	function module:RefreshEntry()
		return position > 0
	end
	
	function module:Forward()
		-- nop()
	end
	
	function module:Backward()
		-- nop()
	end
	
	function module:Actions()
		return GameMenuButtonLogout:GetText(), GameMenuButtonQuit:GetText()
	end
	
	function module:DoAction(index)
		if position > 0 and not index then
			buttons[position]:Click()
		end
	end

end -- end of GameMenu

do

	local module =
	{
		name = "InterfaceOptions",
		title = INTERFACE_OPTIONS,
		frames =
		{
			CreateFrame("Frame", nil, InterfaceOptionsFrameCategories),
			CreateFrame("Frame", nil, InterfaceOptionsFrameAddOns),
		},
	}
	
	KeyboardUI:RegisterModule(module)
	
	local entry, entries, labels = 0, {}, {}
	
	function module:ChangeTab()
		if module.frames[1]:IsVisible() then
			InterfaceOptionsFrameTab2:Click()
		else
			InterfaceOptionsFrameTab1:Click()
		end
	end
	
	function module:GainFocus()
		entry = 0
	end
	
	function module:LoseFocus()
		-- nop()
	end
	
	function module:NextGroup()
		if module.frames[1]:IsVisible() then
			local i = 1
			local button = _G["InterfaceOptionsFrameCategoriesButton"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local next = _G["InterfaceOptionsFrameCategoriesButton"..i+1]
					if next and next:IsShown() then
						next:Click()
						return next.text:GetText()
					end
					return
				end
				i = i + 1
				button = _G["InterfaceOptionsFrameCategoriesButton"..i]
			end
			InterfaceOptionsFrameCategoriesButton1:Click()
			return InterfaceOptionsFrameCategoriesButton1.text:GetText()
		else
			local i = 1
			local button = _G["InterfaceOptionsFrameAddOnsButton"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local next, toggle = _G["InterfaceOptionsFrameAddOnsButton"..i+1], _G["InterfaceOptionsFrameAddOnsButton"..i.."Toggle"]
					if toggle and toggle:IsShown() and toggle:GetNormalTexture():GetTexture() == 130838 then
						toggle:Click()
					end
					if next and next:IsShown() then
						next:Click()
						return next.text:GetText()
					end
					return
				end
				i = i + 1
				button = _G["InterfaceOptionsFrameAddOnsButton"..i]
			end
			InterfaceOptionsFrameAddOnsButton1:Click()
			return InterfaceOptionsFrameAddOnsButton1.text:GetText()
		end
	end
	
	function module:PrevGroup()
		if module.frames[1]:IsVisible() then
			local i = 2
			local button = _G["InterfaceOptionsFrameCategoriesButton"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local prev = _G["InterfaceOptionsFrameCategoriesButton"..i-1]
					prev:Click()
					return prev.text:GetText()
				end
				i = i + 1
				button = _G["InterfaceOptionsFrameCategoriesButton"..i]
			end
		else
			local i = 2
			local button = _G["InterfaceOptionsFrameAddOnsButton"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local prev = _G["InterfaceOptionsFrameAddOnsButton"..i-1]
						prev:Click()
					return prev.text:GetText()
				end
				i = i + 1
				button = _G["InterfaceOptionsFrameAddOnsButton"..i]
			end
		end
	end
	
	local function parseFrame(frame)
		for __, frame in ipairs({frame:GetChildren()}) do
			if frame:IsObjectType("CheckButton") or frame:IsObjectType("Slider") or type(frame.initialize)=="function" then
				local text
				if frame:GetName() and _G[frame:GetName().."Label"] and _G[frame:GetName().."Label"]:GetText() then
					if text then
						if not text:find(_G[frame:GetName().."Label"]:GetText()) then
							text = text .. "; " .. _G[frame:GetName().."Label"]:GetText()
						end
					else
						text = _G[frame:GetName().."Label"]:GetText()
					end
				end
				if type(frame.text) == "table" and frame.text.GetText and frame.text:GetText() then
					text = (text and (text .. "; ") or "") .. frame.text:GetText()
				elseif type(frame.Text) == "table" and frame.Text.GetText and frame.Text:GetText() then
					text = (text and (text .. "; ") or "") .. frame.Text:GetText()
				end
				if frame:GetName() then
					if _G[frame:GetName().."Text"] and not text then
						text = _G[frame:GetName().."Text"]:GetText()
					end
					if _G[frame:GetName().."Low"] and _G[frame:GetName().."High"] and _G[frame:GetName().."Low"]:GetText() and _G[frame:GetName().."High"]:GetText() then
						if text then
							text = text .. "; from " .. _G[frame:GetName().."Low"]:GetText() .. " to " .. _G[frame:GetName().."High"]:GetText()
						end
					end
				end
				if text then
					tinsert(entries, frame)
					tinsert(labels, text)
				end
			elseif frame:IsObjectType("ScrollFrame") or frame:GetObjectType() == "Frame" then
				parseFrame(frame)
			end
		end
	end
	
	local function generateLists(frame)
		wipe(entries)
		wipe(labels)
		if frame then
			parseFrame(frame)
		end
	end
	
	local function getStatus(frame)
		if frame:IsObjectType("CheckButton") then
			return frame:GetChecked() and "Checked" or "Unchecked"
		elseif frame:IsObjectType("Slider") then
			return frame.Text and frame.Text:GetText() or frame:GetValue()
		elseif frame.initialize then
			return _G[frame:GetName().."Text"]:GetText()
		end
	end
	
	function module:NextEntry()
		if entry ==  0 then
			generateLists(InterfaceOptionsFramePanelContainer.displayedPanel)
			if #entries == 0 then
				return "Sorry, Keyboard UI cannot interpret the controls for this addon."
			end
		end
		local new = entry + 1
		while new < #entries do
			if entries[new]:IsVisible() and (entries[new].IsEnabled and entries[new]:IsEnabled() or not entries[new].IsEnabled) then
				entry = new		
				return labels[entry] .. "; " .. getStatus(entries[entry])
			end
			new = new + 1
		end
	end
	
	function module:PrevEntry()
		local new = entry - 1
		while new > 0 do
			if entries[new]:IsVisible() and (entries[new].IsEnabled and entries[new]:IsEnabled() or not entries[new].IsEnabled) then
				entry = new		
				return labels[entry] .. "; " .. getStatus(entries[entry])
			end
			new = new - 1
		end
	end
	
	function module:RefreshEntry()
		while entry > 0 do
			if entry < #entries and entries[entry]:IsVisible() and (entries[entry].IsEnabled and entries[entry]:IsEnabled() or not entries[entry].IsEnabled) then
				break
			end
			entry = entry - 1
		end
		return entry > 0
	end

	function module:Forward()
		if entry > 0 then
			local frame = entries[entry]
			if frame:IsObjectType("Slider") then
				local min, max = frame:GetMinMaxValues()
				local value = frame:GetValue()
				local step = frame:GetValueStep()
				if value < min then
					frame:SetValue(min)
				elseif value + step > max then
					frame:SetValue(max)
				else
					frame:SetValue(value + step)
				end
				return getStatus(frame)
			else
				return self:DoAction()
			end
		end
	end

	function module:Backward()
		if entry > 0 then
			local frame = entries[entry]
			if frame:IsObjectType("Slider") then
				local min, max = frame:GetMinMaxValues()
				local value = frame:GetValue()
				local step = frame:GetValueStep()
				if value - step < min then
					frame:SetValue(min)
				elseif value > max then
					frame:SetValue(max)
				else
					frame:SetValue(value - step)
				end
				return getStatus(frame)
			else
				return self:DoAction()
			end	
		end
	end

	function module:Actions()
		if entry > 0 then
			if entry:IsObjectType("Slider") then
				if entry:GetName() and _G[entry:GetName().."Low"] and _G[entry:GetName().."High"] then
					return _G[entry:GetName().."Low"], _G[entry:GetName().."High"], nil, nil, OKAY, CANCEL, DEFAULTS
				end
			end
		end
		return nil, nil, nil, nil, OKAY, CANCEL, DEFAULTS
	end
	
	function module:DoAction(index)
		if index == 5 then
			InterfaceOptionsFrameOkay:Click()
		elseif index == 6 then
			InterfaceOptionsFrameCancel:Click()
		elseif index == 7 then
			InterfaceOptionsFrameDefaults:Click()
		end
		if entry > 0 then
			local frame = entries[entry]
			if frame:IsObjectType("CheckButton") then
				frame:Click()
				return getStatus(frame)
			elseif frame:GetObjectType() == "Frame" and type(frame.initialize) == "function" and frame:GetName() and _G[frame:GetName().."Button"] then
				local button = _G[frame:GetName().."Button"]
				if button:GetScript("OnMouseDown") then
					button:OnMouseDown("LeftButton")
				else
					button:Click()
				end
				return
			end
		end
	end
	
	hooksecurefunc("InterfaceOptionsList_DisplayPanel", function(panel)
		entry = 0
	end)

end