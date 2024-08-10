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
local L = KeyboardUI.text

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
				
	function module:NextEntry()
		if position == 0 then
			for __, frame in ipairs({GameMenuFrame:GetChildren()}) do
				if frame:IsObjectType("Button") and frame:IsShown() then
					tinsert(buttons, frame)
				end
			end		
		end
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
	
	function module:GetLongDescription()
		return position > 0 and buttons[position]:GetText()
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
	
	if C_StorePublic.IsEnabled() then
		local function shopWarning()
			module:ttsInterrupt("Warning: You have openned the in-game shop for purchasing cosmetic items with real money.  Keyboard UI is forbidden from helping you navigate this frame for security reasons.   Pressing escape should close the window safely.", KUI_NORMAL, KUI_FF)
		end
		
		if GameMenuFrame.InitButtons then
			-- WoW 11.0
			hooksecurefunc(GameMenuFrame, "InitButtons", function()
				for _, frame in ipairs({GameMenuFrame:GetChildren()}) do
					if frame:IsObjectType("Button") and frame:GetText() == BLIZZARD_STORE then
						frame:HookScript("OnClick", shopWarning)
						break
					end
				end
			end)
		elseif GameMenuButtonStore then
			-- Prior to WoW 11.0
			GameMenuButtonStore:HookScript("OnClick", shopWarning)
		end
	end

end -- end of GameMenu

do

	local entry, entries, labels = 0, {}, {}

	local currentPanel = nil

	local module =
	{
		name = "InterfaceOptions",
		title = INTERFACE_OPTIONS,
		frames =
		{
			CreateFrame("Frame", nil, InterfaceOptionsFrameCategories or SettingsPanel.CategoryList),
			CreateFrame("Frame", nil, InterfaceOptionsFrameAddOns),
			CreateFrame("Frame", nil, VideoOptionsFrameCategoryFrame),
		},
	}
	
	KeyboardUI:RegisterModule(module)
	
	function module:ChangeTab()
		module:ttsBlock()
		if InterfaceOptionsFrame then
			-- Classic
			if module.frames[1]:IsVisible() then
				InterfaceOptionsFrameTab2:Click()
				module:ttsUnblock()
				return ADDONS .. " " .. SETTINGS
			elseif module.frames[2]:IsVisible() then
				GameMenuButtonOptions:Click()
				module:ttsUnblock()
				return SYSTEMOPTIONS_MENU .. " " .. SETTINGS
			elseif module.frames[3]:IsVisible() then
				GameMenuButtonUIOptions:Click()
				if module.frames[2]:IsVisible() then
					InterfaceOptionsFrameTab1:Click()
				end
				module:ttsUnblock()
				return GAME .. " " .. SETTINGS
			end
		else
			-- WoW 10.x
			if SettingsPanel.GameTab:IsSelected() then
				SettingsPanel.AddOnsTab:Click()
				module:ttsUnblock()
				if SettingsPanel:GetCurrentCategory():GetCategorySet() == 1 then
					local categories = SettingsPanel:GetAllCategories()
					for i=1, #categories do
						if categories[i]:GetCategorySet() == 2 then
							SettingsPanel:SelectCategory(categories[i])
							return ADDONS .. " " .. SETTINGS .. CHAT_HEADER_SUFFIX .. SettingsPanel:GetCurrentCategory():GetName()
						end
					end
				else
					return ADDONS .. " " .. SETTINGS
				end
			else
				SettingsPanel.GameTab:Click()
				module:ttsUnblock()
				if SettingsPanel:GetCurrentCategory():GetCategorySet() == 2 then
					SettingsPanel:SelectCategory(SettingsPanel:GetAllCategories()[1])
					return GAME .. " " .. SETTINGS .. CHAT_HEADER_SUFFIX .. SettingsPanel:GetCurrentCategory():GetName()
				else
					return GAME .. " " .. SETTINGS
				end
			end
		end
	end
	
	function module:NextGroup()
		if InterfaceOptionsFrame then
			local parentName = module.frames[1]:IsVisible() and module.frames[1]:GetParent():GetName()
				or module.frames[2]:IsVisible() and module.frames[2]:GetParent():GetName()
				or module.frames[3]:IsVisible() and module.frames[3]:GetParent():GetName()
			local i = 1
			local button = _G[parentName.."Button"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local toggle = _G[parentName.."Button"..i.."Toggle"]
					if toggle and toggle:IsShown() and _G[parentName.."Button"..i.."ToggleNormalTexture"]:GetTexture() == 130838 then
						toggle:Click()
					end
					local next = _G[parentName.."Button"..i+1]
					if next and next:IsShown() then
						next:Click()
						return next.element.parent and (next.text:GetText() .. " within " .. next.element.parent) or next.text:GetText()
					end
					return
				end
				i = i + 1
				button = _G[parentName.."Button"..i]
			end
			_G[parentName.."Button1"]:Click()
			return _G[parentName.."Button1"].text:GetText()
		else
			local currentCategory = SettingsPanel:GetCurrentCategory()
			local categories
			if currentCategory:HasParentCategory() then
				categories = currentCategory:GetParentCategory():GetSubcategories()
				if currentCategory == categories[#categories] then
					categories = SettingsPanel:GetAllCategories()
					currentCategory = currentCategory:GetParentCategory()
				end
			elseif currentCategory:HasSubcategories() then
				categories = currentCategory:GetSubcategories()
				currentCategory = categories[#categories]
			else
				categories = SettingsPanel:GetAllCategories()
			end
			for i=1, #categories do
				if currentCategory == categories[i] then
					SettingsPanel:SelectCategory(categories[i < #categories and i+1 or 1])
					return SettingsPanel:GetCurrentCategory():GetName()
				end
			end
		end
	end
	
	function module:PrevGroup()
		if InterfaceOptionsFrame then
			local parentName = module.frames[1]:IsVisible() and module.frames[1]:GetParent():GetName()
				or module.frames[2]:IsVisible() and module.frames[2]:GetParent():GetName()
				or module.frames[3]:IsVisible() and module.frames[3]:GetParent():GetName()
			local i = 2
			local button = _G[parentName.."Button"..i]
			while button and button:IsShown() do
				if button.highlight:IsShown() and button.highlight:GetVertexColor() > 0.9 then
					local prev = _G[parentName.."Button"..i-1]
					prev:Click()
					return prev.element.parent and (prev.text:GetText() .. " within " .. prev.element.parent) or prev.text:GetText()
				end
				i = i + 1
				button = _G[parentName.."Button"..i]
			end
			_G[parentName.."Button1"]:Click()
			return _G[parentName.."Button1"].text:GetText()
		else
			local currentCategory = SettingsPanel:GetCurrentCategory()
			local categories
			if currentCategory:HasParentCategory() then
				local parent = currentCategory:GetParentCategory()
				categories = parent:GetSubcategories()
				if currentCategory == categories[1] then
					categories = SettingsPanel:GetAllCategories()
					for i=1, #categories do
						if parent == categories[i] then
							currentCategory = categories[i < #categories and i+1 or 1]
							break
						end
					end
				end
			else
				categories = SettingsPanel:GetAllCategories()
			end
			for i=1, #categories do
				if currentCategory == categories[i] then
					SettingsPanel:SelectCategory(categories[i > 1 and i-1 or #categories])
					return SettingsPanel:GetCurrentCategory():GetName()
				end
			end
		end
	end
		
	local function parseFrame(frameToParse)
		local frames = {frameToParse:GetChildren()}
		for i=#frames, 1, -1 do
			if not frames[i]:GetTop() or not frames[i]:GetLeft() then
				tremove(frames, i)
			end
		end
		sort(frames,function(a, b)
			local ya, yb, xa, xb = a:GetTop(), b:GetTop(), a:GetLeft(), b:GetLeft()
			
			return yb and xb and (ya == yb and a:GetLeft() < b:GetLeft() or ya > yb)
		end)
		for __, frame in ipairs(frames) do
			if frame:IsObjectType("CheckButton") then
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
				elseif type(frame:GetParent().Text) == "table" and frame:GetParent().Text.GetText and frame:GetParent().Text:GetText() then
					text = (text and (text .. "; ") or "") .. frame:GetParent().Text:GetText()
					
				end
				if frame:GetName() then
					if _G[frame:GetName().."Text"] and _G[frame:GetName().."Text"]:IsVisible() then
						text = _G[frame:GetName().."Text"]:GetText()
					end
				end
				if text and text ~= "" then
					tinsert(entries, frame)
					tinsert(labels, text)
				end
			elseif frame:IsObjectType("Slider") then
				local label = frame:GetName() and _G[frame:GetName().."Label"] and _G[frame:GetName().."Label"]:IsVisible() and _G[frame:GetName().."Label"]:GetText() or frame.text and frame.text:GetText()
				local top, low, high
				if frame:GetName() then
					top, low, high = _G[frame:GetName().."Text"], _G[frame:GetName().."Low"], _G[frame:GetName().."High"]
				else
					top, low, high = frame.Text, frame.Low, frame.High
				end
				top, low, high = top and top:GetText(), low and low:GetText(), high and high:GetText()
				top, low, high = top ~= "" and top, low ~= "" and low, high ~= "" and high
				if label and top and low and high then
					tinsert(entries, frame)
					tinsert(labels, label .. " " .. L["FROM_TO"]:format(low, high))
				elseif top or label then
					tinsert(entries, frame)
					tinsert(labels, (top or label) .. " slider")
				end
			elseif type(frame.initialize) == "function" and frame:GetObjectType() == "Frame" then
				tinsert(entries, frame)
				if frame:GetName() and _G[frame:GetName().."Label"] and _G[frame:GetName().."Label"]:GetText() then
					tinsert(labels, _G[frame:GetName().."Label"]:GetText() .. " dropdown")
				else
					tinsert(labels, "Dropdown")
				end
			elseif frame:GetObjectType() == "Button" and frame:GetParent().Dropdown == frame and not frame:GetParent():GetParent().Checkbox and frame:GetParent().IncrementButton then
				-- SettingsDropdownControlMixin, but not SettingsCheckboxDropdownControlMixin
				tinsert(entries, frame)
				tinsert(labels, frame:GetParent():GetParent().Text:GetText())
			elseif frame:IsObjectType("ScrollFrame") or frame:GetObjectType() == "Frame" then
				parseFrame(frame)
			end
		end
	end
	
	local function generateLists(frame)
		wipe(entries)
		wipe(labels)
		if frame then
			local scale = frame:GetScale()
			frame:SetScale(0.0001)
			parseFrame(frame)
			frame:SetScale(scale)
		end
	end
	
	local function getStatus(frame)
		if frame:IsObjectType("CheckButton") then
			return frame:GetChecked() and "Checked" or "Unchecked"
		elseif frame:IsObjectType("Slider") then
			return frame.Text and frame.Text:GetText() or frame:GetValue()
		elseif frame.initialize and frame:GetName() then
			return _G[frame:GetName().."Text"]:GetText()
		elseif frame.Button and frame.Button.SelectionDetails then
			return frame.Button.SelectionDetails.SelectionName:GetText()
		end
	end
	
	local function confirmPanel(arg1, arg2)
		local panel = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and arg2 or arg1
		if panel ~= currentPanel then
			entry = 0
			currentPanel = panel
		end
	end
	
	function module:NextEntry()
		if entry ==  0 then
			if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
				generateLists(InterfaceOptionsFramePanelContainer.displayedPanel)
			elseif VideoOptionsFrame then
				generateLists(VideoOptionsFramePanelContainer.displayedPanel)
			else
				-- WoW 10.x
				generateLists(SettingsPanel.Container.SettingsList:IsShown() and SettingsPanel.Container.SettingsList or SettingsPanel.Container.SettingsCanvas)
			end
			if #entries == 0 then
				return "Sorry, Keyboard UI cannot interpret the controls for this addon."
			end
		end
		local new = entry + 1
		while new <= #entries do
			if entries[new]:IsShown() and (entries[new].IsEnabled and entries[new]:IsEnabled() or not entries[new].IsEnabled) then
				entry = new		
				return labels[entry] .. "; " .. (getStatus(entries[entry]) or "")
			end
			new = new + 1
		end
	end
	
	function module:PrevEntry()
		local new = entry - 1
		while new > 0 do
			if entries[new]:IsShown() and (entries[new].IsEnabled and entries[new]:IsEnabled() or not entries[new].IsEnabled) then
				entry = new		
				return labels[entry] .. "; " .. (getStatus(entries[entry]) or "")
			end
			new = new - 1
		end
	end
	
	function module:GetLongDescription()
		if entry > 0 then
			return labels[entry] .. "; " .. getStatus(entries[entry]), (entries[entry].tooltipText or entries[entry].description or ""):format(getStatus(entries[entry]))
		end
	end

	local function isBlizzardSettings()
		if entry > 0 then
			local frame = entries[entry]
			return SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList and SettingsPanel.Container.SettingsList:IsShown() and (frame:GetParent().data or frame:GetParent():GetParent().data)
		else
			return SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList and SettingsPanel.Container.SettingsList:IsShown()
		end
	end

	function module:Forward()
		if entry > 0 then
			local frame = entries[entry]
			if isBlizzardSettings() then
				local parentData = frame:GetParent().data or frame:GetParent():GetParent().data
				if parentData.sliderSetting and parentData.sliderOptions then
					-- SettingsCheckboxSliderControlMixin and MinimalSliderWithSteppersTemplate
					frame:GetParent().SliderWithSteppers.Forward:Click()
					return frame:GetParent().SliderWithSteppers.RightText:GetText() -- parentData.sliderSetting:GetValue()
				elseif parentData.cbSetting and parentData.dropdownSetting then
					-- SettingsCheckboxDropdownControlMixin
					frame:GetParent().Control.IncrementButton:Click()
					return frame:GetParent().Control.Dropdown:GetText()
				elseif parentData.setting and frame:GetParent().Dropdown == frame and frame:GetParent().IncrementButton then
					-- SettingsDropdownControlMixin
					frame:GetParent().IncrementButton:Click()
					return frame:GetText()
				end
			end
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
			end
			return self:DoAction()
		end
	end

	function module:Backward()
		if entry > 0 then
			local frame = entries[entry]
			local frame = entries[entry]
			if isBlizzardSettings() then
				local parentData = frame:GetParent().data or frame:GetParent():GetParent().data
				if parentData.sliderSetting and parentData.sliderOptions then
					-- SettingsCheckboxSliderControlMixin and MinimalSliderWithSteppersTemplate
					frame:GetParent().SliderWithSteppers.Back:Click()
					return frame:GetParent().SliderWithSteppers.RightText:GetText() -- parentData.sliderSetting:GetValue()
				elseif parentData.cbSetting and parentData.dropdownSetting then
					-- SettingsCheckboxDropdownControlMixin
					frame:GetParent().Control.DecrementButton:Click()
					return frame:GetParent().Control.Dropdown:GetText()
				elseif parentData.setting and frame:GetParent().Dropdown == frame and frame:GetParent().DecrementButton then
					-- SettingsDropdownControlMixin
					frame:GetParent().DecrementButton:Click()
					return frame:GetText()
				end
			end
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
			elseif frame.DecrementButton then
				if propertyNames[entry] and SettingsPanel.Container.SettingsList:IsShown() then
					SettingsPanel.Container.SettingsList:ScrollToElementByName(propertyNames[entry])
					for __, newFrame in ipairs({SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget:GetChildren()}) do
						if newFrame.data and newFrame.data.name == propertyNames[entry] then
							frame = newFrame.DropDown
							break
						end
					end
				end
				frame.DecrementButton:Click()
				return getStatus(frame)
			else
				return self:DoAction()
			end	
		end
	end

	function module:Actions()
		if entry > 0 then
			local frame = entries[entry]
			if frame:IsObjectType("Slider") then
				if frame:GetName() and _G[frame:GetName().."Low"] and _G[frame:GetName().."High"] then
					return _G[frame:GetName().."Low"], _G[frame:GetName().."High"], nil, nil, OKAY, CANCEL, DEFAULTS
				end
			end
		end
		return nil, nil, nil, nil, OKAY, CANCEL, DEFAULTS
	end
		
	function module:DoAction(index)
		if index == 5 then
			(InterfaceOptionsFrameOkay or SettingsPanel.CloseButton):Click()
		elseif index == 6 and InterfaceOptionsFrame then
			InterfaceOptionsFrameCancel:Click()
		elseif index == 7 and InterfaceOptionsFrame then
			InterfaceOptionsFrameDefaults:Click()
		elseif index == 7 and SettingsPanel.Container.SettingsList.Header.DefaultsButton:IsVisible() then
			SettingsPanel.Container.SettingsList.Header.DefaultsButton:Click()
		elseif entry > 0 then				
			local frame = entries[entry]
			if isBlizzardSettings() then
				local parentData = frame:GetParent().data or frame:GetParent():GetParent().data
				if parentData.cbSetting and parentData.sliderSetting then
					-- SettingsCheckboxSliderControlMixin
					parentData.cbSetting:SetValue(not parentData.cbSetting:GetValue())
					return parentData.cbSetting:GetValue() and ("Checked: " .. frame:GetParent().SliderWithSteppers.RightText:GetText()) or "Unchecked"
				elseif parentData.cbSetting and parentData.dropdownSetting then
					-- SettingsCheckboxDropdownControlMixin
					frame:Click()
					return parentData.cbSetting:GetValue() and ("Checked: " .. frame:GetParent().Control.Dropdown:GetText()) or "Unchecked"
				elseif parentData.setting then
					if parentData.setting:GetVariableType() == "boolean" then
						-- SettingsCheckboxControlMixin
						frame:Click()
						return parentData.setting:GetValue() and "Checked" or "Unchecked"
					end
				end
			end
			if frame:IsObjectType("CheckButton") then
				frame:Click()
				return getStatus(frame)
			elseif frame:GetObjectType() == "Frame" and type(frame.initialize) == "function" and frame:GetName() and _G[frame:GetName().."Button"] then
				local button = _G[frame:GetName().."Button"]
				if button:GetScript("OnMouseDown") then
					button:GetScript("OnMouseDown")(button, "LeftButton")
				else
					button:Click()
				end
				return
			end
		end
	end
		
	if InterfaceOptionsList_DisplayPanel then
		-- Classic
		hooksecurefunc("InterfaceOptionsList_DisplayPanel", confirmPanel)
		hooksecurefunc("OptionsList_DisplayPanel", confirmPanel)
	else
		-- WoW 10.x
		hooksecurefunc(SettingsPanel, "SelectCategory", confirmPanel)
		hooksecurefunc(SettingsPanel.CategoryList, "SetCurrentCategory", confirmPanel)
	end

end