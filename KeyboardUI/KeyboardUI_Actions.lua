--[[

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Refer to KeyboardUI.lua for full details


KeyboardUI_Actions.lua - Includes modules which must share access to the action bar and bags.

--]]


local KeyboardUI = select(2, ...)
local L = KeyboardUI.text

-------------------------
-- Shared action bar management

local moduleUsingActionBar = nil

local action = 0								-- used by SpellBookFrame and ContainerFrame modules to place abilities and consumables on the action bar

local function getActionText(optAction)
	local action = optAction or action
	local contains
	local actionType, id, subType = GetActionInfo(action)
		if actionType == "spell" then
			if id > 0 then
				contains = GetSpellInfo(id)
			elseif subType == "pet" then
				contains = "pet ability"
			end
		elseif actionType == "item" then
			contains = GetItemInfo(id)
		elseif actionType == "macro" then
			contains = "macro " .. GetMacroInfo(id)
		elseif actionType == "companion" then
			contains = subType .. " " .. GetSpellLink(id):match("%[(.*)%]")
		elseif actionType == "equipmentset" then
			contains = "equipment set"
		elseif actionType == "flyout" then
			contains = GetFlyoutInfo(id)
		elseif actionType == nil then
			contains = "empty"
		end
		contains = contains or actionType or ""
	if action <= 24 then
		if action <= 12 then
			return ("%s at %s slot %d"):format(contains, PAGE_NUMBER:format(1), action)
		else
			return ("%s at %s slot %d"):format(contains, PAGE_NUMBER:format(2), action-12)
		end
	elseif action <= 72 then
		local bl, br, r1, r2 = GetActionBarToggles()
		bl = bl and SHOW_MULTIBAR1_TEXT or PAGE_NUMBER:format(3)
		br = br and SHOW_MULTIBAR2_TEXT or PAGE_NUMBER:format(4)
		r1 = r1 and SHOW_MULTIBAR3_TEXT or PAGE_NUMBER:format(5)
		r2 = r1 and r2 and SHOW_MULTIBAR4_TEXT or PAGE_NUMBER:format(6)
		if action <= 36 then
			return ("%s at %s slot %d"):format(contains, bl, action-24)
		elseif action <= 48 then
			return ("%s at %s slot %d"):format(contains, br, action-36)
		elseif action <= 60 then
			return ("%s at %s slot %d"):format(contains, r1, action-48)
		else
			return ("%s at %s slot %d"):format(contains, r2, action-60)
		end
	elseif action <= 120 then
		local __, className = UnitClass("player")
		if action <= 84 then
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Cat Form Bar" or className == "ROGUE" and "Stealth Bar" or className == "WARRIOR" and "Battle Stance Bar" or (PAGE_NUMBER:format(7).." ("..UNUSED..")"), action-72)
		elseif action <= 96 then
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Prowl Bar" or className == "ROGUE" and "Shadow Dance Bar" or className == "WARRIOR" and "Defensive Stance Bar" or (PAGE_NUMBER:format(8).." ("..UNUSED..")"), action-84)
		elseif action <= 108 then
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Bear Form Bar" or className == "WARRIOR" and "Berserker Stance Bar" or (PAGE_NUMBER:format(9).." ("..UNUSED..")"), action-96)
		else
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Moonkin Form Bar" or (PAGE_NUMBER:format(10).." ("..UNUSED..")"), action-108)
		end
	elseif action <= 132 then
		return ("%s at %s slot %d"):format(contains, GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE, action-120)
	else
		return ("%s at %s slot %d"):format(contains, PAGE_NUMBER:format(ceil(action/12)), action%12)
	end
end

local function getAllActionSlotTexts(canReplace)
	local prevBar
	if action == 0 then
		local bonus = GetBonusBarOffset()
		if bonus > 0 then
			prevBar = bonus + 5
		else
			prevBar = GetActionBarPage() - 1
		end		
	else
		prevBar = floor((action-1)/12)
	end
	if canReplace then
		return
			REPLACES_SPELL:format(getActionText(prevBar*12 + 1)),
			REPLACES_SPELL:format(getActionText(prevBar*12 + 2)),
			REPLACES_SPELL:format(getActionText(prevBar*12 + 3)),
			"etcetera", -- 4
			nil, --  5
			nil, --  6
			nil, --  7
			nil, --  8
			nil, --  9
			nil, -- 10
			nil, -- 11
			REPLACES_SPELL:format(getActionText(prevBar*12 + 12))
	else
		return
			getActionText(prevBar*12 + 1),
			getActionText(prevBar*12 + 2),
			getActionText(prevBar*12 + 3),
			"etcetera", -- 4
			nil, --  5
			nil, --  6
			nil, --  7
			nil, --  8
			nil, --  9
			nil, -- 10
			nil, -- 11
			getActionText(prevBar*12 + 12)
	end
end

local function setActionSlot(index)
	local bonus = GetBonusBarOffset()
	if bonus > 0 then
		action = (bonus + 5) * 12 + index
	else
		action = (GetActionBarPage() - 1) * 12 + index
	end
end

local function nextActionSlot(canReplace)
	if action == 0 then
		setActionSlot(1)
	elseif action < 120 then
		action = action + 1
	end
	return HasAction(action) and canReplace and REPLACES_SPELL:format(getActionText()) or getActionText()
end

local function prevActionSlot(canReplace)
	if action > 1 then
		action = action - 1
		return HasAction(action) and canReplace and REPLACES_SPELL:format(getActionText()) or getActionText()
	end
end

(MainMenuBarArtFrame or MainMenuBar):HookScript("OnAttributeChanged", function(__, key, value)
	if key == "actionpage" and action > 0 then
		if action <= (value-1)*12 or action > value*12 then
			action = (value-1)*12 + 1
			if moduleUsingActionBar then
				moduleUsingActionBar:ttsYield(getActionText())
			end
		end
	end
end)


-------------------------
-- SpellBookFrame

do
	local book, tab, slot, flyout = 0, 0, 0, 0
	
	local useActionSlots = false

	local positions = {[0] = SPELLS_PER_PAGE}		-- 1, 3, 5, 7, 9, 11, 2, 4, 6, 8, 10, 12... but the last one is in position 0 because the math is modulo 12.
	for i=1, SPELLS_PER_PAGE-1, 2 do
		tinsert(positions, i)
	end
	for i=2, SPELLS_PER_PAGE-2, 2 do
		tinsert(positions, i)
	end

	local function getPosition()
		return positions[slot % SPELLS_PER_PAGE]
	end
	
	local function getDistanceFromPageStart(spellButtonNumber)
		return spellButtonNumber%2==1 and (spellButtonNumber+1)/2 or (SPELLS_PER_PAGE + spellButtonNumber)/2
	end

	-- bookType, offset, numSpells = getPositionInBook()
	local function getPositionInBook()
		if book == 1 then
			return BOOKTYPE_SPELL, select(3, GetSpellTabInfo(tab))
		elseif book == 2 then
			return BOOKTYPE_SPELL, select(3, GetSpellTabInfo(tab))	-- does not return BOOKTYPE_PROFESSION even though it could
		elseif book == 3 then
			return BOOKTYPE_PET, 0, HasPetSpells()
		end
	end
	
	local module =
	{
		name = "SpellBookFrame",
		frame = CreateFrame("Frame", nil, SpellBookFrame),
		title = SPELLBOOK .. " & " .. BINDING_HEADER_ACTIONBAR,
		secureButtons =
		{
			bindingChangeTabButton = SpellBookProfessionFrame and function()
				if book == 1 then
					return "SpellBookFrameTabButton2"
				elseif book == 2 and HasPetSpells() then
					return "SpellBookFrameTabButton3"
				else
					return "SpellBookFrameTabButton1"
				end
			end or nil, -- Retail only
			bindingNextGroupButton = function() return book == 1 and tab < GetNumSpellTabs() and "SpellBookSkillLineTab" .. (tab+1) end,
			bindingPrevGroupButton = function() return book == 1 and tab > 1 and "SpellBookSkillLineTab" .. (tab-1) end,
			bindingNextEntryButton = function()
				if slot > 0 then
					local bookType, offset = getPositionInBook()
					if GetSpellBookItemInfo(slot + offset, bookType) == "FLYOUT" and flyout == 0 then
						return "SpellButton" .. getPosition()
					elseif getPosition() == SPELLS_PER_PAGE and (
						flyout == 0
						or flyout == MAX_FLYOUTS
						or not spellFlyout[flyout+1]:IsShown()
					) then
						return "SpellBookNextPageButton"
					end
				end
			end,
			bindingPrevEntryButton = function() return book ~= 2 and getPosition() == 1 and flyout < 2 and "SpellBookPrevPageButton" end,
		},
		secureCommands =
		{
			bindingDoActionButton = function()
				if not useActionSlots then
					if flyout > 0 then
						return "CLICK KeyboardUI_SpellFlyoutButton" .. flyout .. ":LeftButton"
					end
					local slotWithOffset = book == 3 and slot or (slot + select(3, GetSpellTabInfo(tab)))
					local bookType = book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
					local spellType, id = GetSpellBookItemInfo(slotWithOffset, bookType)
					if spellType == "SPELL" then
						return "SPELL " .. GetSpellInfo(id)
					elseif spellType == "PETACTION" then
						return "CLICK SpellButton"..getPosition()..":LeftButton"
					end
				end
			end,
		}
	}

	KeyboardUI:RegisterModule(module)

	function module:GainFocus()
		moduleUsingActionBar = self
	end
	
	function module:LoseFocus()
		moduleUsingActionBar = nil
	end

	local function getEntryText(longDesc)
		local slotWithOffset = book == 3 and slot or (slot + select(3, GetSpellTabInfo(tab)))
		local bookType = book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
		local spellType, id = GetSpellBookItemInfo(slotWithOffset, bookType)
		if flyout == 0 then
			if spellType == "SPELL" then
				return longDesc and module:concatTooltipLines("GetSpellBookItem", slotWithOffset, bookType) or GetSpellInfo(id)
			elseif spellType == "FUTURESPELL" then
				local name, __, __, __, minLevel = GetSpellInfo(id)
				return longDesc and module:concatTooltipLines("GetSpellBookItem", slotWithOffset, bookType) or name .. " (" .. UNKNOWN .. ")."
			elseif spellType == "FLYOUT" then
				return longDesc and module:concatTooltipLines("GetSpellBookItem", slotWithOffset, bookType) or "Collection of " .. GetFlyoutInfo(id) .. " abilities."
			elseif spellType == "PETACTION" then
				return longDesc and module:concatTooltipLines("GetSpellBookItem", slotWithOffset, bookType) or GetSpellBookItemName(slotWithOffset, bookType)
			end
		else
			local spellID = GetFlyoutSlotInfo(id, flyout)
			return longDesc and module:concatTooltipLines("GetSpellByID", spellID) or GetSpellInfo(spellID)
		end

	end

	local professionButtons =
	{
		PrimaryProfession1SpellButtonBottom,
		PrimaryProfession1SpellButtonTop,
		PrimaryProfession2SpellButtonBottom,
		PrimaryProfession2SpellButtonTop,
		SecondaryProfession3SpellButtonRight,
		SecondaryProfession3SpellButtonLeft,
		SecondaryProfession2SpellButtonRight,
		SecondaryProfession2SpellButtonLeft,
		SecondaryProfession1SpellButtonRight,
		SecondaryProfession1SpellButtonLeft,
	}
	local function getProfessionButton(offset)
		local professions = {GetProfessions()}
		for i=1, 5 do
			if professions[i] and tab == professions[i] then
				return offset and professionButtons[(i-1)*2 + slot + offset] or professionButtons[(i-1)*2 + slot]
			end
		end
		return nil
	end

	local spellFlyout, MAX_FLYOUTS, setSpellFlyout, hideSpellFlyout = nil, 0, nop, nop

	if SpellFlyout then
		spellFlyout = CreateFrame("Frame", "KeyboardUI_SpellFlyout", SpellBookFrame)
		MAX_FLYOUTS = 16
		
		for i=1, MAX_FLYOUTS do
			spellFlyout[i] = CreateFrame("CheckButton", "KeyboardUI_SpellFlyoutButton"..i, spellFlyout, "SecureActionButtonTemplate,SmallActionButtonTemplate")
			spellFlyout[i].Icon = _G["KeyboardUI_SpellFlyoutButton"..i.."Icon"]
			spellFlyout[i].updateIcon = function(self, spellID)
				self.Icon:SetTexture(GetSpellTexture(self:GetAttribute("spell")))
			end
			spellFlyout[i]:SetAttribute("type", "spell")
		end
		
		spellFlyout:SetHeight(spellFlyout[1]:GetHeight())
		spellFlyout:SetPoint("BOTTOM")
		spellFlyout[1]:SetPoint("LEFT")
		
		for i=2, MAX_FLYOUTS do
			spellFlyout[i]:SetPoint("LEFT", spellFlyout[i-1], "RIGHT")
		end

		function setSpellFlyout(flyoutID)
			local numSlots = select(3, GetFlyoutInfo(flyoutID))
			local numKnown = 0
			for i=1, numSlots do
				local spellID, __, isKnown = GetFlyoutSlotInfo(flyoutID, i)
				if spellID and isKnown then
					numKnown = numKnown + 1
					spellFlyout[numKnown]:SetAttribute("spell", spellID)
					spellFlyout[numKnown]:Show()
					spellFlyout[numKnown]:updateIcon(spellID)
					if numKnown == MAX_FLYOUTS then 
						break
					end
				end
			end
			spellFlyout:SetWidth(spellFlyout[1]:GetWidth() * numKnown)
			for i=numKnown+1, MAX_FLYOUTS do
				spellFlyout[i]:Hide()
			end
		end

		function hideSpellFlyout()
			for i=1, MAX_FLYOUTS do
				spellFlyout[i]:Hide()
			end
			SpellFlyout:Hide()
		end

	end

	local function showGlow()
		local button = flyout > 0 and spellFlyout[flyout] or book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
		if button then
			if button.AbilityHighlight then
				button.AbilityHighlight:Show()
			else
				button.AbilityHighlight = button:CreateTexture(nil, "OVERLAY")
				button.AbilityHighlight:SetTexture("Interface\\Buttons\\CheckButtonHilight-Blue")
				button.AbilityHighlight:SetBlendMode("ADD")
				button.AbilityHighlight:SetPoint("TOPLEFT", -3, 3)
				button.AbilityHighlight:SetPoint("BOTTOMRIGHT", 3, -3)
				button.AbilityHighlight:Show()
			end
		end
	end

	local function hideGlow()
		local button = flyout > 0 and spellFlyout[flyout] or book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
		if button and button.AbilityHighlight then
			button.AbilityHighlight:Hide()
		end
	end

	local function hideAllGlows()
		for i=1, SPELLS_PER_PAGE do
			if _G["SpellButton"..i].AbilityHighlight then
				_G["SpellButton"..i].AbilityHighlight:Hide()
			end
		end
		if SpellFlyout and SpellFlyout:IsShown() then
			local i = 1
			while _G["SpellFlyoutButton"..i] do
				if _G["SpellFlyoutButton"..i].AbilityHighlight then
					_G["SpellFlyoutButton"..i].AbilityHighlight:Hide()
				end
				i = i + 1
			end
		end
		for __, button in ipairs(professionButtons) do
			if button.AbilityHighlight then
				button.AbilityHighlight:Hide()
			end
		end
	end

	local function checkIfFlyoutNeeded(reverseDirection)
		if SpellFlyout and book == 1 then
			local type, id = GetSpellBookItemInfo(slot + select(2, getPositionInBook()), 1)
			if type == "FLYOUT" then
				setSpellFlyout(id)
				if spellFlyout[1]:IsShown() then
					if reverseDirection then
						for i=MAX_FLYOUTS, 1, -1 do
							if spellFlyout[i]:IsShown() then
								flyout = i
								break
							end
						end
					else
						flyout = 1
					end
				end
			end
		end
	end

	local function setBook(val)
		hideGlow()
		hideSpellFlyout()
		if val == 1 then
			book, tab, slot = 1, SpellBookFrame.selectedSkillLine, (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE + 1
		elseif val == 3 then
			book, tab, slot = 3, 0, (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE + 1
		elseif val == 2 then
			book = 2
			tab = 999
			for __, v in pairs({GetProfessions()}) do
				if v < tab then
					tab = v
				end
			end
			slot = 1
		else
			book, tab, slot = nil, 0, 0
		end
		flyout = 0
		useActionSlots = false
		checkIfFlyoutNeeded(false)
		showGlow()
		module:updatePriorityKeybinds()
	end
	
	local function setTab(val)
		hideGlow()
		hideSpellFlyout()
		tab = val
		slot = book ~= 2 and (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE + 1 or 1
		flyout = 0
		useActionSlots = false
		checkIfFlyoutNeeded(false)
		showGlow()
		module:updatePriorityKeybinds()
	end
	
	local GOING_BACKWARD = true
	local GOING_FORWARD = false
	
	local function setSlot(val, goingBackward)
		hideGlow()
		hideSpellFlyout()
		slot = val
		flyout = 0
		useActionSlots = false
		checkIfFlyoutNeeded(goingBackward)
		showGlow()
		module:updatePriorityKeybinds()
	end
	
	local function setFlyout(val)
		hideGlow()
		flyout = val
		useActionSlots = false
		showGlow()
		module:updatePriorityKeybinds()
	end

	function module:NextGroup()
		-- The spellbook uses secure buttons to resolve taint, and the pet book doesn't have tabs.
		if book == 2 then
			local nextLowest
			for __, v in pairs({GetProfessions()}) do
				if v > tab and (not nextLowest or v < nextLowest) then
					nextLowest = v
				end
			end
			if nextLowest then
				setTab(nextLowest)
				return getEntryText()
			end
		end
	end

	function module:PrevGroup()
		-- The spellbook uses secure buttons to resolve taint, and the pet book doesn't have tabs.
		if book == 2 then
			local nextHighest
			for __, v in pairs({GetProfessions()}) do
				if v < tab and (not nextHighest or v > nextHighest) then
					nextHighest = v
				end
			end
			if nextHighest then
				setTab(nextHighest)
				return getEntryText()
			end
		end
	end

	local function validateEntry()
		local numSpells = book == 3 and HasPetSpells() or select(4, GetSpellTabInfo(tab))
		if slot > numSpells then
			setSlot(numSpells)
		end
	end

	function module:NextEntry()
		if book == 2 then
			if slot > 0 and slot < select(4, GetSpellTabInfo(tab)) then
				setSlot(slot + 1, GOING_FORWARD)
				return getEntryText()
			--else
			--	return module:NextGroup()
			end	
		elseif flyout > 0 and flyout < MAX_FLYOUTS and spellFlyout[flyout+1]:IsShown() then
			setFlyout(flyout + 1)
			return getEntryText()
		elseif flyout > 0 then
			setSlot(slot + 1, GOING_FORWARD)
			return getEntryText()
		else
			local __, offset, numSpells = getPositionInBook()
			if slot < numSpells then
				setSlot(slot + 1, GOING_FORWARD)
				return getEntryText()
			end
		end
	end

	function module:PrevEntry()
		if book == 2 then
			if slot > 1  then
				setSlot(slot - 1, GOING_BACKWARD)
				return getEntryText()
			--else
			--	return module:PrevGroup()
			end	
		end
		if flyout > 1 then
			setFlyout(flyout - 1)
			return getEntryText()
		elseif slot > 1 then
			setSlot(slot - 1, GOING_BACKWARD)
			return getEntryText()
		end
	end

	function module:GetShortTitle()
		return slot > 0 and getEntryText(false)
	end

	function module:GetLongDescription()
		return slot > 0 and getEntryText(true)
	end

	function module:Forward()
		if useActionSlots then
			return nextActionSlot(slot > 0)
		elseif slot > 0 then
			useActionSlots = true
			self:updatePriorityKeybinds()
			return action == 0 and nextActionSlot(slot > 0) or slot > 1 and REPLACES_SPELL:format(getActionText()) or getActionText()
		end
	end

	function module:Backward()
		if useActionSlots then
			return prevActionSlot(slot > 0)
		elseif slot > 0 then
			useActionSlots = true
			self:updatePriorityKeybinds()
			return action == 0 and nextActionSlot(slot > 0) or slot > 1 and REPLACES_SPELL:format(getActionText()) or getActionText()
		end
	end

	function module:Actions()
		return getAllActionSlotTexts(slot > 0)
	end

	function module:DoAction(index)
		if index then
			setActionSlot(index)
			useActionSlot = true
			self:updatePriorityKeybinds()
			return module:DoAction()
		elseif slot > 0 and action > 0 then
			if flyout > 0 then
				local foo, flyoutID = GetSpellBookItemInfo(
					book == 3 and slot or slot + select(3, GetSpellTabInfo(tab)),
					book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
				)
				spellID = GetFlyoutSlotInfo(flyoutID, flyout)
				PickupSpell(spellID)
			else
				PickupSpellBookItem(book == 3 and slot or slot + select(3, GetSpellTabInfo(tab)), book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL)
			end
			local info = GetCursorInfo()
			if info == "spell" or info == "petaction" then
				PlaceAction(action)
				ClearCursor()
				return getActionText(action)
			elseif info == "flyout" then
				PlaceAction(action)
				ClearCursor()
				return getActionText() .. "; however, to place only a single ability, press " .. module:getOption("bindingNextEntryButton") .. " to navigate the collection."
			else
				return "Unable to place " .. getEntryText() .. " onto " .. getActionText()
			end
		end
	end

	local firstTime = true
	local function announce(self, book)
		if self:IsVisible() then
			if firstTime and UnitLevel("player") <= 5 then
				firstTime = false
				module:ttsInterrupt(book)
				module:ttsQueue(([=[Use %s and %s to choose a spell, and use %s and %s to choose an action bar slot.  %s puts the chosen spell in the chosen action bar slot.]=]):format(module:getOption("bindingNextEntryButton"), module:getOption("bindingPrevEntryButton"), module:getOption("bindingForwardButton"), module:getOption("bindingBackwardButton"), module:getOption("bindingDoActionButton")), KUI_NORMAL, KUI_MP)
			else
				module:ttsYield(book)
			end
			if TutorialQueue and TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd then
				module:ttsQueue(NPEV2_SPELLBOOKREMINDER:format(GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd)), KUI_NORMAL, KUI_MP)
			end
		end
	end

	-- temporary, to be merged into KeyboardUI_Actions.lua to include a tutorial on changing action bar slots
	module:registerTutorial(
		function()
			if UnitLevel("player") > 5 then
				return nil
			else
				return TutorialQueue and TutorialQueue.currentTutorial and (TutorialQueue.currentTutorial.spellToAdd or false)
			end
		end,
		{
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and SpellBookFrame:IsShown() or L["PRESS_TO"]:format(GetBindingKey("TOGGLESPELLBOOK") or "", NPEV2_SPELLBOOK_ADD_SPELL:format(GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd))) end,
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and slot > 0 or L["PRESS_TO"]:format(module:getOption("bindingNextEntryButton"), CHOOSE .. CHAT_HEADER_SUFFIX .. GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd)) end,
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and action > 0 or L["PRESS_TO"]:format(module:getOption("bindingForwardButton"), CHOOSE .. CHAT_HEADER_SUFFIX .. BINDING_HEADER_ACTIONBAR) end,
		}
	)


	SpellBookSpellIconsFrame:Hide()
	SpellBookSpellIconsFrame:HookScript("OnShow", function(self)
		if SpellBookFrame.bookType == BOOKTYPE_SPELL then
			setBook(1)
			announce(self, SPELLBOOK .. " - " .. getEntryText())
		else -- BOOKTYPE_PET
			setBook(3)
			announce(self, PET .. " - " .. getEntryText())
		end
	end)

	SpellBookSpellIconsFrame:HookScript("OnHide", function(self)
		if book == 1 then
			setBook(nil)
		end
	end)

	if SpellBookProfessionFrame then
		-- Retail only
		SpellBookProfessionFrame:Hide()
		SpellBookProfessionFrame:HookScript("OnShow", function(self)
			setBook(2)
			announce(self, TRADE_SKILLS .. " - " .. getEntryText())
		end)
	end

	SpellBookFrame:HookScript("OnHide", function()
		setBook(nil)
	end)

	
	SpellBookNextPageButton:HookScript("OnClick", function()
		if slot > 0 and getPosition() == SPELLS_PER_PAGE then
			setSlot(slot + 1)
		else
			setSlot(slot - slot % SPELLS_PER_PAGE + SPELLS_PER_PAGE + 1)
		end
		module:ttsInterrupt(getEntryText())
	end)

	SpellBookPrevPageButton:HookScript("OnClick", function()
		
		if slot > 0 and getPosition() == SPELLS_PER_PAGE then
			setSlot(slot - SPELLS_PER_PAGE)
		else
			setSlot(slot - slot % SPELLS_PER_PAGE)
		end
		module:ttsInterrupt(getEntryText())
	end)

	-- when the user clicks on a button, go to that button
	for i=1, SPELLS_PER_PAGE do
		local distance = getDistanceFromPageStart(i)
		_G["SpellButton"..i]:HookScript("PreClick", function()
			setSlot(slot - getDistanceFromPageStart(getPosition()) + distance)
		end)
	end

	hooksecurefunc("ToggleSpellBook", function(bookType)
		if bookType == BOOKTYPE_SPELL and book ~= 1 then
			setBook(1)
		elseif bookType == BOOKTYPE_PET and book ~= 3 and HasPetSpells() then
			setBook(3)
		end
		-- BOOKTYPE_PROFESSION is not actually necessary, because the profession frame is guaranteed to appear
	end)

	hooksecurefunc ("SpellBookFrame_Update", function()
		if book == 1 and tab ~= SpellBookFrame.selectedSkillLine then
			setTab(SpellBookFrame.selectedSkillLine)
			module:ttsYield((GetSpellTabInfo(tab) or "General") .. " - " .. getEntryText())
		end
	end)

end


-------------------------
-- Shared bag management for ContainerFrame and MerchantFrame modules

local moduleUsingBags = nil

local itemLocation = ItemLocation:CreateFromBagAndSlot(BACKPACK_CONTAINER, 0)		-- used by ContainerFrame and MerchantFrame modules to interact with the player inventory

local NUM_REAGENTBAG_SLOTS = NUM_REAGENTBAG_SLOTS or 0 -- classic vs retail

local nextBagID, prevBagID = {}, {}

itemLocation.IsValid = itemLocation.IsValid or function()
	return (GetContainerItemInfo or C_Container.GetContainerItemInfo)(itemLocation.bagID, itemLocation.slotIndex) ~= nil
end

do
	-- populating nextBagID and prevBagID
	for i= BACKPACK_CONTAINER + 1, BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS do
		nextBagID[i-1] = i
		prevBagID[i] = i-1
	end
	nextBagID[BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS] = BANK_CONTAINER
	prevBagID[BANK_CONTAINER] = BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS
	nextBagID[BANK_CONTAINER] = BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + 1
	prevBagID[BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + 1] = BANK_CONTAINER
	for i = BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + 2, BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + NUM_BANKBAGSLOTS do
		nextBagID[i-1] = i
		prevBagID[i] = i-1
	end
	if REAGENTBANK_CONTAINER then
		-- retail
		nextBagID[BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + NUM_BANKBAGSLOTS] = REAGENTBANK_CONTAINER
		prevBagID[REAGENTBANK_CONTAINER] = BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + NUM_BANKBAGSLOTS
	elseif KEYRING_CONTAINER then
		-- classic
		nextBagID[BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + NUM_BANKBAGSLOTS] = KEYRING_CONTAINER
		prevBagID[KEYRING_CONTAINER] = BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS + NUM_BANKBAGSLOTS
	end
end

local function getBagAndSlot()
	return itemLocation.bagID, itemLocation.slotIndex
end

local function setBagAndSlot(bagID, slotIndex)
	itemLocation:SetBagAndSlot(bagID, slotIndex)
end

local containers = {ContainerFrame1, ContainerFrame2, ContainerFrame3, ContainerFrame4, ContainerFrame5, ContainerFrame6, ContainerFrame7, ContainerFrame8, ContainerFrame9, ContainerFrame10, ContainerFrame11, ContainerFrame12, ContainerFrame13}
local function isBagShownForBagID(bagID)
	if bagID >= BACKPACK_CONTAINER then
		for __, bag in ipairs(containers) do
			if bag:GetID() == bagID and bag:IsShown() then
				return true
			end
		end
		return false
	elseif bagID == BANK_CONTAINER then
		return BankFrame:IsShown()
	elseif bagID == REAGENTBANK_CONTAINER then
		return ReagentBankFrame:IsShown()
	end
end

local function refreshBag()
	local bagID = itemLocation.bagID
	while bagID and not isBagShownForBagID(bagID) do
		bagID = prevBagID[bagID]
	end
	if bagID == nil then
		itemLocation:SetBagAndSlot(BACKPACK_CONTAINER, 0)
		return false
	elseif bagID ~= itemLocation.bagID then
		itemLocation:SetBagAndSlot(bagID, 1)
	else
		local numberOfSlots = (GetContainerNumSlots or C_Container.GetContainerNumSlots)(bagID)
		if itemLocation.slotIndex > numberOfSlots then
			itemLocation.slotIndex = numberOfSlots
		end
	end
	return true
end

local function nextBag()
	refreshBag()
	local bagID = nextBagID[itemLocation.bagID]
	while bagID do
		if isBagShownForBagID(bagID) then
			local numberOfSlots = (GetContainerNumSlots or C_Container.GetContainerNumSlots)(bagID)
			if numberOfSlots > 0 then
				itemLocation:SetBagAndSlot(bagID, 1)
				return true
			end
		end
		bagID = nextBagID[bagID]
	end
	return false
end

local function prevBag()
	refreshBag()
	local bagID = prevBagID[itemLocation.bagID]
	while bagID do
		if isBagShownForBagID(bagID) then
			local numberOfSlots = (GetContainerNumSlots or C_Container.GetContainerNumSlots)(bagID)
			if numberOfSlots > 0 then
				itemLocation:SetBagAndSlot(bagID, 1)
				return true
			end
		end
		bagID = prevBagID[bagID]
	end
	return false
end

local function nextBagSlot()
	refreshBag()
	if itemLocation.slotIndex < (GetContainerNumSlots or C_Container.GetContainerNumSlots)(itemLocation.bagID) then
		itemLocation.slotIndex = itemLocation.slotIndex + 1
		return true
	end
	return false
end

local function prevBagSlot()
	refreshBag()
	if itemLocation.slotIndex > 1 then
		itemLocation.slotIndex = itemLocation.slotIndex - 1
		return true
	end
	return false
end

local function getBagSlotTooltip()
	if itemLocation:IsValid() then
		return moduleUsingBags:concatTooltipLines("GetBagItem", getBagAndSlot())
	end
end

local function getBagSlotText()
	if itemLocation:IsValid() then
		local itemID = C_Item.GetItemID(itemLocation)
		local itemCount = GetContainerItemInfo and select(2, GetContainerItemInfo(getBagAndSlot())) or C_Item.GetStackCount(itemLocation)
		local itemName, __, __, __, itemMinLevel, itemType, __, __, itemEquipLoc = GetItemInfo(itemID)
		local itemQuality = C_Item.GetItemQuality(itemLocation)
		local itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
		local redText = moduleUsingBags:getFirstRedTooltipLine("GetBagItem", getBagAndSlot())
		if itemEquipLoc ~= "" and not redText then
			local itemSlot1, itemSlot2 = invTypeToSlot[itemEquipLoc], (itemEquipLoc ~= "INVTYPE_WEAPON" or CanDualWield()) and invTypeToSlot2[itemEquipLoc] or nil
			local oldItemID1, oldItemID2 = itemSlot1 and GetInventoryItemID("player", itemSlot1), itemSlot2 and GetInventoryItemID("player", itemSlot2)
			if oldItemID1 and oldItemID2 then
				local oldName1, __, oldQuality1, oldLevel1 = GetItemInfo(oldItemID1)
				local oldName2, __, oldQuality2, oldLevel2 = GetItemInfo(oldItemID2)
				return ("%s (%s, %s). %s (%s, %s) %s %s (%s, %s)"):format(
					itemName,
					_G["ITEM_QUALITY"..itemQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(itemLevel),
					REPLACES_SPELL:format(oldName1),
					_G["ITEM_QUALITY"..oldQuality1.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(oldLevel1),
					itemType == 4 and QUEST_LOGIC_OR or QUEST_LOGIC_AND,
					oldName2,
					_G["ITEM_QUALITY"..oldQuality2.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(oldLevel2)
				)				
			elseif oldItemID1 or oldItemID2 then
				local oldName, __, oldQuality, oldLevel = GetItemInfo(oldItemID1 or oldItemID2)
				return ("%s (%s, %s). %s (%s, %s)"):format(
					itemName,
					_G["ITEM_QUALITY"..itemQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(itemLevel),
					REPLACES_SPELL:format(oldName),
					_G["ITEM_QUALITY"..oldQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(oldLevel)
				)
			else
				return("%s (%s, %s)."):format(
					itemName,
					_G["ITEM_QUALITY"..itemQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(itemLevel)
				)
			end
		elseif itemCount > 1 then
			return ITEM_QUANTITY_TEMPLATE:format(itemCount, itemName)
		elseif redText then
			return itemName .. ". " .. MOUNT_JOURNAL_FILTER_UNUSABLE .. CHAT_HEADER_SUFFIX .. redText
		else
			return itemName
		end
	end	
end

local function getBagShortTitle()
	local bagID = itemLocation.bagID
	if bagID == BACKPACK_CONTAINER then
		return BAG_NAME_BACKPACK or "Backpack"
	elseif bagID > BACKPACK_CONTAINER then
		if bagID <= BACKPACK_CONTAINER + NUM_BAG_SLOTS then
			local num = bagID-BACKPACK_CONTAINER
			return _G["BAG_NAME_BAG_"..num] or (BAGSLOT .. " " .. num)
		elseif bagID <= BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS then
			return MINIMAP_TRACKING_VENDOR_REAGENT or "Reagents"
		elseif bagID == BANK_CONTAINER then
			return BANK
		else
			local num = bagID - BANK_CONTAINER
			return BANK_BAG .. " " .. num
		end
	elseif KEYRING_CONTAINER and bagID == KEYRING_CONTAINER then
		return KEYRING or "Key Ring"
	elseif REAGENTBANK_CONTAINER and bagID == REAGENTBANK_CONTAINER then
		return REAGENT_BANK or "Reagent Bank"
	else
		return UNKNOWN or "Unknown"
	end
end

local function getBagText()
	local bagID = itemLocation.bagID
	local numSlots = (GetContainerNumSlots or C_Container.GetContainerNumSlots)(bagID) -- classic vs retail
	local numFreeSlots = (GetContainerNumFreeSlots or C_Container.GetContainerNumFreeSlots)(bagID) -- classic vs retail
	if bagID == BACKPACK_CONTAINER then
		return ("%s. %d of %d %s %s. %s"):format(BACKPACK_TOOLTIP, numFreeSlots, numSlots, BAGSLOTTEXT, EMPTY, getBagSlotText() or "")
	elseif bagID <= BACKPACK_CONTAINER + NUM_BAG_SLOTS then
		return ("%s %d. %d of %d %s %s. %s"):format(INVTYPE_BAG, bagID, numFreeSlots, numSlots, BAGSLOTTEXT, EMPTY, getBagSlotText() or "")
	elseif bagID <= BACKPACK_CONTAINER + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS then
		return ("%s. %d of %d %s %s. %s"):format(REAGENT_BANK, numFreeSlots, numSlots, BAGSLOTTEXT, EMPTY, getBagSlotText() or "")
	else
		return ("%s %s %d. %d of %d %s %s. %s"):format(BANK, INVTYPE_BAG, bagID - NUM_BAG_SLOTS - NUM_REAGENTBAG_SLOTS, numFreeSlots, numSlots, BAGSLOTTEXT, EMPTY, getBagSlotText() or "")
	end
end

local function getBagSlotItemID()
	return itemLocation:IsValid() and C_Item.GetItemID(itemLocation) or nil
end

local function getBagSlotHasItem()
	return getBagSlotItemID() ~= nil
end

-------------------------
-- Backpack and bags without a merchant window

do

	local useActionSlots = false

	local function isUsable(itemID)
		return itemID and (IsUsableItem(itemID) or IsConsumableItem(itemID) or GetItemSpell(itemID)) and not IsEquippableItem(itemID)
	end

	local module =
	{
		name = "ContainerFrame",
		title = BACKPACK_TOOLTIP,
		frame = CreateFrame("Frame", nil, ContainerFrame1),
		secureCommands =
		{
			bindingDoActionButton = GetContainerItemID and function() return useActionSlots == false and isUsable(GetContainerItemID(getBagAndSlot())) and "ITEM " .. GetItemInfo(GetContainerItemID(getBagAndSlot())) end
				or function() return useActionSlots == false and isUsable(C_Container.GetContainerItemID(getBagAndSlot())) and "ITEM " .. GetItemInfo(C_Container.GetContainerItemID(getBagAndSlot())) end, -- classic vs retail
		},
	}

	KeyboardUI:RegisterModule(module)
	
	function module:GainFocus()
		moduleUsingActionBar = self
		moduleUsingBags = self
	end
	
	function module:LoseFocus()
		moduleUsingActionBar = nil
		moduleUsingBags = nil
	end	
	
	invTypeToSlot =
	{
		INVTYPE_HEAD = INVSLOT_HEAD,
		INVTYPE_NECK = INVSLOT_NECK,
		INVTYPE_SHOULDER = INVSLOT_SHOULDER,
		INVTYPE_BODY = INVSLOT_BODY,
		INVTYPE_CHEST = INVSLOT_CHEST,
		INVTYPE_WAIST = INVSLOT_WAIST,
		INVTYPE_LEGS = INVSLOT_LEGS,
		INVTYPE_FEET = INVSLOT_FEET,
		INVTYPE_WRIST = INVSLOT_WRIST,
		INVTYPE_HAND = INVSLOT_HAND,
		INVTYPE_FINGER = INVSLOT_FINGER1,
		INVTYPE_TRINKET = INVSLOT_TRINKET1,
		INVTYPE_WEAPON = INVSLOT_MAINHAND,
		INVTYPE_SHIELD = INVSLOT_OFFHAND,
		INVTYPE_RANGED = INVSLOT_MAINHAND, -- INVSLOT_RANGED for classic era???
		INVTYPE_CLOAK = INVSLOT_BACK,
		INVTYPE_2HWEAPON = INVSLOT_MAINHAND,
		--INVTYPE_BAG
		INVTYPE_TABARD = INVSLOT_TABARD,
		INVTYPE_ROBE = INVSLOT_CHEST,
		INVTYPE_WEAPONMAINHAND = INVSLOT_MAINHAND,
		INVTYPE_WEAPONOFFHAND = INVSLOT_OFFHAND,
		INVTYPE_HOLDABLE = INVSLOT_OFFHAND,
		INVTYPE_AMMO = INVSLOT_AMMO,
		INVTYPE_THROWN = INVSLOT_MAINHAND,
		INVTYPE_RANGEDRIGHT = INVSLOT_MAINHAND,
		--INVTYPE_QUIVER,
		--INVTYPE_RELIC,
	}
	
	invTypeToSlot2 =
	{
		INVTYPE_FINGER = INVSLOT_FINGER2,
		INVTYPE_TRINKET = INVSLOT_TRINKET2,
		INVTYPE_WEAPON = INVSLOT_OFFHAND,
	}
	
	function module:NextGroup()
		if nextBag() then
			useActionSlots = false
			self:updatePriorityKeybinds()
			return getBagText()
		end
	end

	function module:PrevGroup()
		if prevBag() then
			useActionSlots = false
			self:updatePriorityKeybinds()
			return getBagText()
		end
	end

	function module:NextEntry()
		if nextBagSlot() then
			useActionSlots = false
			self:updatePriorityKeybinds()
			return getBagSlotText() or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
		end
	end

	function module:PrevEntry()
		if prevBagSlot() then
			useActionSlots = false
			self:updatePriorityKeybinds()
			return getBagSlotText() or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
		end
	end

	function module:GetLongDescription()
		return getBagSlotTooltip()
	end

	function module:Forward()
		if getBagSlotHasItem() then
			local itemID = GetContainerItemInfo and select(10, GetContainerItemInfo(getBagAndSlot())) or C_Container.GetContainerItemInfo(getBagAndSlot()).itemID
			if useActionSlots then
				return nextActionSlot(isUsable(itemID))
			else
				useActionSlots = true
				self:updatePriorityKeybinds()
				return action == 0 and nextActionSlot(isUsable(itemID)) or itemID and HasAction(action) and REPLACES_SPELL:format(getActionText()) or getActionText()
			end
		end
	end

	function module:Backward()
		if getBagSlotHasItem() then
			local itemID = GetContainerItemInfo and select(10, GetContainerItemInfo(getBagAndSlot())) or C_Container.GetContainerItemInfo(getBagAndSlot()).itemID
			if useActionSlots then
				return prevActionSlot(isUsable(itemID))
			else
				useActionSlots = true
				self:updatePriorityKeybinds()
				return action == 0 and prevActionSlot(isUsable(itemID)) or itemID and HasAction(action) and REPLACES_SPELL:format(getActionText()) or getActionText()
			end
		end
	end

	function module:Actions()
		if getBagSlotHasItem() then
			local itemID = GetContainerItemInfo and select(10, GetContainerItemInfo(getBagAndSlot())) or C_Container.GetContainerItemInfo(getBagAndSlot()).itemID
			return getAllActionSlotTexts(isUsable(itemID))
		end
	end

	function module:DoAction(index)
		if index then
			setActionSlot(index)
			useActionSlot = true
			self:updatePriorityKeybinds()
			return module:DoAction()
		end

		local itemID = getBagSlotItemID()
		
		if not itemID then
			return
		end
		
		local itemLoc = ItemLocation:CreateEmpty()	-- just a reusable table
		local bagID, bagSlot = getBagAndSlot()
		
		local redText = module:getFirstRedTooltipLine("GetBagItem", itemLocation.bagID, itemLocation.slotIndex)
		if redText then
			PlayVocalErrorSoundID(51)
			return ("<speak><silence msec=\"2000\" />%s</speak>"):format(ITEM_REQ_SKILL:format(redText))
		end
		
		local itemName, __, __, __, itemMinLevel, itemType, itemSubType, __, itemEquipLoc = GetItemInfo(itemID)
		if itemEquipLoc and itemEquipLoc ~= "" then
			itemLoc:SetBagAndSlot(bagID, bagSlot)
			local itemQuality = C_Item.GetItemQuality(itemLoc)
			local itemLevel = C_Item.GetCurrentItemLevel(itemLoc)	
			
			local itemSlot1, itemSlot2 = invTypeToSlot[itemEquipLoc], (itemEquipLoc ~= "INVTYPE_WEAPON" or CanDualWield()) and invTypeToSlot2[itemEquipLoc] or nil
			local oldItemID1, oldItemID2 = itemSlot1 and GetInventoryItemID("player", itemSlot1), itemSlot2 and GetInventoryItemID("player", itemSlot2)
			if oldItemID1 then
				-- oldItemID2 NYI
				itemLoc:SetEquipmentSlot(itemSlot1)
				local oldName = C_Item.GetItemName(itemLoc)
				local oldQuality = C_Item.GetItemQuality(itemLoc)
				local oldLevel = C_Item.GetCurrentItemLevel(itemLoc)
				EquipItemByName(itemID)
				return ("<speak>%s%s%s (%s, %s).  <silence msec=\"250\" />%s%s%s (%s, %s).</speak>"):format(
					CURRENTLY_EQUIPPED,
					CHAT_HEADER_SUFFIX,
					itemName,
					_G["ITEM_QUALITY"..itemQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(itemLevel),
					BANK_BAG,
					CHAT_HEADER_SUFFIX,
					oldName,
					_G["ITEM_QUALITY"..oldQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(oldLevel)
				)
			else
				EquipItemByName(itemID)
				return ("%s%s%s (%s, %s).  %s %s."):format(
					CURRENTLY_EQUIPPED,
					CHAT_HEADER_SUFFIX,
					itemName,
					_G["ITEM_QUALITY"..itemQuality.."_DESC"],
					CHARACTER_LINK_ITEM_LEVEL_TOOLTIP:format(itemLevel),
					BANK_BAG,
					EMPTY
				)
			end
		elseif useActionSlots and isUsable(itemID) then
			PickupContainerItem(bagID, bagSlot)
			PlaceAction(action)
			ClearCursor()
			return getActionText()
		end
	end
	
	MerchantFrame:HookScript("OnShow", function()
		module.frame:Hide()
	end)
	
	MerchantFrame:HookScript("OnHide", function()
		if not SpellBookFrame:IsShown() and not GossipFrame:IsShown() then
			module.frame:Show()
		end
	end)
	
	SpellBookFrame:HookScript("OnShow", function()
		module.frame:Hide()
	end)
	
	SpellBookFrame:HookScript("OnHide", function()
		if not MerchantFrame:IsShown() and not GossipFrame:IsShown() then
			module.frame:Show()
		end
	end)
	
	GossipFrame:HookScript("OnShow", function()
		module.frame:Hide()
	end)
	
	GossipFrame:HookScript("OnHide", function()
		if not SpellBookFrame:IsShown() and not MerchantFrame:IsShown() then
			module.frame:Show()
		end	
	end)
	
end


-------------------------
-- MerchantFrame

do
	local merchantSlot = 0
	local merchantPage = 0
	local numToBuy = 0
	local buybackSlot = nil		-- nil/false when the buyback frame is closed, 0 when openned, and the slot number starting at 1 when an item is chosen for buyback
	local sellMode = false
	

	local module =
	{
		name = "MerchantFrame",
		title = MERCHANT,
		frame = CreateFrame("Frame", nil, MerchantFrame),
	}
	
	KeyboardUI:RegisterModule(module)
	
	local AUCTION_HOUSE_SELL_TAB = AUCTION_HOUSE_SELL_TAB or "Sell"
	local AUCTION_HOUSE_BUY_TAB = AUCTION_HOUSE_BUY_TAB or "Buy"

	local function getMerchantSlotText()
		if sellMode then
			refreshBag()
			if select(2, getBagAndSlot()) > 0 then
				local text = getBagSlotText()
				if text then
					return ("%s %s"):format(AUCTION_HOUSE_SELL_TAB, text)
				else
					return ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Item", select(2, getBagAndSlot()), getBagSlotText() or EMPTY)
				end
			end
		elseif buybackSlot then
			if buybackSlot > 0 then
				name, __, price, quantity = GetBuybackItemInfo(buybackSlot)
				if quantity > 1 then
					return ("%s %s %s, %s"):format(BUYBACK, quantity, name, GetCoinText(price))
				else
					return ("%s %s, %s"):format(BUYBACK, name, GetCoinText(price))
				end
			end
		elseif merchantSlot > 0 then
			local name, __, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(merchantSlot)
			local itemCount = GetMerchantItemCostInfo(merchantSlot)
			local price = GetCoinText(numToBuy > 0 and price*numToBuy/quantity or price/quantity)
			for itemIndex=1, itemCount do
				local __, itemQty, itemLink, currencyName = GetMerchantItemCostItem(merchantSlot, itemIndex)
				price = price .. ", " .. (numToBuy > 0 and numToBuy*itemQty or itemQty) .. " " .. (currencyName or GetItemInfo(itemLink))
			end
			local text = 
				numToBuy > 0 and ("%d %s; %s"):format(numToBuy, name, price)
				or isPurchasable and ("%s; %s%s"):format(name, COSTS_LABEL, price)
				or ("%s. %s"):format(name, UNAVAILABLE)
			if numToBuy == 0 and numAvailable > 0 then
				text = text .. "; " .. (AUCTION_HOUSE_QUANTITY_AVAILABLE_FORMAT and AUCTION_HOUSE_QUANTITY_AVAILABLE_FORMAT:format(numAvailable) or (numAvailable .. " " .. AVAILABLE))
			end
			if not isUsable then
				local redText = module:getFirstRedTooltipLine("GetMerchantItem", merchantSlot)
				if redText then
					text = text .. " (" .. MOUNT_JOURNAL_FILTER_UNUSABLE .. ", " .. redText .. " )"
				end
			end
			return text
		end
		return ""
	end
	
	MerchantFrame:HookScript("OnShow", function()
		merchantPage, merchantSlot = 0, 0
	end)
		
	hooksecurefunc("MerchantFrame_Update", function()
		if MerchantFrame.selectedTab == 1 then
			buybackSlot = nil
			if MerchantFrame.page > merchantPage then
				merchantPage = MerchantFrame.page
				if merchantPage > 1 then
					merchantSlot = MERCHANT_ITEMS_PER_PAGE * (merchantPage - 1) + 1
				end
				numToBuy = 0
				if module:hasFocus() then
					module:ttsInterrupt(getMerchantSlotText())
				end
			elseif MerchantFrame.page < merchantPage then
				merchantPage = MerchantFrame.page
				merchantSlot = MERCHANT_ITEMS_PER_PAGE * merchantPage
				numToBuy = 0
				if module:hasFocus() then
					module:ttsInterrupt(getMerchantSlotText())
				end
			end
		else
			sellMode = false
			buybackSlot = 0
		end
	end)
	
	function module:GainFocus()
		moduleUsingBags = self
		sellMode = false
		merchantSlot = 0
	end
	
	function module:LoseFocus()
		moduleUsingBags = nil
	end
	
	function module:ChangeTab()
		if buybackSlot then
			MerchantFrameTab1:Click()
			return AUCTION_HOUSE_BUY_TAB
		elseif sellMode then
			MerchantFrameTab2:Click()
			return BUYBACK
		else
			sellMode = true
			return AUCTION_HOUSE_SELL_TAB
		end
	end
	
	function module:NextGroup()
		if sellMode then
			if nextBag() then
				return getMerchantSlotText()
			end
		else
			return self:NextEntry()
		end
	end
	
	function module:PrevGroup()
		if sellMode then
			if prevBag() then
				return getMerchantSlotText()
			end
		else
			return self:PrevEntry()
		end
	end
	
	function module:NextEntry()
		if sellMode then
			if nextBagSlot() then
				return getMerchantSlotText()
			end
		elseif buybackSlot then
			if buybackSlot < BUYBACK_ITEMS_PER_PAGE and buybackSlot < GetNumBuybackItems() then
				buybackSlot = buybackSlot + 1
				return getMerchantSlotText()
			end
		elseif merchantSlot < GetMerchantNumItems() then
			if merchantSlot % MERCHANT_ITEMS_PER_PAGE ~= 0 or merchantSlot == 0 then
				merchantSlot = merchantSlot + 1
				numToBuy = 0
				return getMerchantSlotText()
			else
				MerchantNextPageButton:Click()
			end
		end
	end
	
	function module:PrevEntry()
		if sellMode then
			if prevBagSlot() then
				return getMerchantSlotText()
			end
		elseif buybackSlot then
			if buybackSlot > 1 then
				buybackSlot = buybackSlot - 1
			end
		elseif merchantSlot > 1 then
			if merchantSlot % MERCHANT_ITEMS_PER_PAGE ~= 1 then
				merchantSlot = merchantSlot - 1
				numToBuy = 0
				return getMerchantSlotText()
			else
				MerchantPrevPageButton:Click()
			end		
		end
	end
	
	function module:GetLongDescription()
		if sellMode then
			return getBagSlotTooltip()
		elseif buybackSlot then
			if buybackSlot > 0 then
				return module:concatTooltipLines("GetBuybackItem", buybackSlot)
			end
		elseif numToBuy > 0 then
			return numToBuy .. " " .. module:concatTooltipLines("GetMerchantItem", merchantSlot)
		elseif merchantSlot > 0 then
			return module:concatTooltipLines("GetMerchantItem", merchantSlot)
		end
	end
	
	function module:Forward()
		if not buybackSlot then
			local numAvail, isPurchasable = select(5, GetMerchantItemInfo(merchantSlot))
			if isPurchasable then
				numToBuy = min(numToBuy+1, GetMerchantItemMaxStack(merchantSlot), numAvail == -1 and 1000 or numAvail)
				return getMerchantSlotText()
			end
		end
	end
	
	function module:Backward()
		if not buybackSlot then
			local numAvail, isPurchasable = select(5, GetMerchantItemInfo(merchantSlot))
			if isPurchasable then
				numToBuy = min(numToBuy>1 and numToBuy-1 or 1, GetMerchantItemMaxStack(merchantSlot), numAvail == -1 and 1000 or numAvail)
				return getMerchantSlotText()
			end
		end
	end
	
	local actionSizes =
	{
		[1] = 1,
		[2] = 2,
		[3] = 3,
		[4] = 4,
		[5] = 5,
		[6] = 10,
		[7] = 20,
		[8] = 50,
		[9] = 100,
		[10] = 200,
		[11] = 500,
		[12] = 1000,
	}
	
	function module:DoAction(action)
		if sellMode then
			if itemLocation:IsValid() then
				(UseContainerItem and UseContainerItem or C_Container.UseContainerItem)(getBagAndSlot())
				return "Sold"	
			end
		elseif buybackSlot then
			if buybackSlot > 0 then
				BuybackItem(buybackSlot)
			end
		elseif action then
			local numAvail, isPurchasable = select(5, GetMerchantItemInfo(merchantSlot))
			if isPurchasable then
				if GetMerchantItemMaxStack(merchantSlot) >= actionSizes[action] and (numAvail == -1 or numAvail >= actionSizes[action]) then
					numToBuy = actionSizes[action]
					return getMerchantSlotText()
				end
			else
				return UNAVAILABLE
			end
		elseif numToBuy > 0 then
			BuyMerchantItem(merchantSlot, numToBuy)
			numToBuy = 0
			return BLIZZARD_STORE_PURCHASED or "Purchased"
		end
	end
	
	function module:Actions()
		if buybackSlot then
			-- for now, do nothing
		else
			local numAvail, isPurchasable = select(5, GetMerchantItemInfo(merchantSlot))
			if isPurchasable then
				local tbl = {}
				for i, size in ipairs(actionSizes) do
					if GetMerchantItemMaxStack(merchantSlot) >= size and (numAvail == -1 or numAvail >= size) then
						tbl[i] = AUCTION_HOUSE_BUY_TAB .. " " .. size
					end
				end
				return unpack(tbl)
			end
		end	
	end
	
	
	local quest = UnitFactionGroup("player") == "Alliance" and 55194 or 59950
	local function nopButTrue() return true end
	local tutorialStep = 0
	module:registerTutorial(
		function() 
			if UnitLevel("player") > 10 or C_QuestLog.IsQuestFlaggedCompleted(quest) then
				return nil
			else
				return C_QuestLog.IsOnQuest(quest)
			end
		end,
		{
			function() if tutorialStep > 1 then return true else tutorialStep = 1 end if MerchantFrame:IsShown() then return merchantSlot > 0 or L["PRESS_TO"]:format(module:getOption("bindingNextEntryButton") .. " " .. QUEST_LOGIC_AND .. " " .. module:getOption("bindingPrevEntryButton"), BROWSE) else return false end end,
			function() if tutorialStep > 2 then return true else tutorialStep = 2 end return numToBuy > 0 or L["PRESS_TO"]:format(module:getOption("bindingForwardButton") .. " " .. QUEST_LOGIC_AND .. " " .. module:getOption("bindingBackwardButton"), CHOOSE) end,
			function() if tutorialStep > 3 then return true else tutorialStep = 3 end return numToBuy == 0 or L["PRESS_TO"]:format(module:getOption("bindingDoActionButton"), AUCTION_HOUSE_BUY_TAB) end,
			function() if tutorialStep > 4 then return true else tutorialStep = 4 end return sellMode or L["PRESS_TO"]:format(module:getOption("bindingChangeTabButton"), AUCTION_HOUSE_SELL_TAB) end,
			function() if tutorialStep > 5 then return true else tutorialStep = 5 end return select(2,getBagAndSlot()) > 1 or L["PRESS_TO"]:format(module:getOption("bindingNextEntryButton"), CHOOSE) end,
			function() if tutorialStep >= 6 then return true else tutorialStep = 6 end return L["PRESS_TO"]:format(module:getOption("bindingDoActionButton"), AUCTION_HOUSE_SELL_TAB) end,
			function() if tutorialStep > 7 then return true else tutorialStep = 7 end return buybackSlot or L["PRESS_TO"]:format(module:getOption("bindingChangeTabButton"), BUYBACK) end,
			function() tutorialStep = 8 return not buybackSlot or L["PRESS_TO"]:format(module:getOption("bindingChangeTabButton"), AUCTION_HOUSE_BUY_TAB) end,
		}	
	)
	
end


-------------------------
-- MailFrame

do

	local inboxEntry, inboxItem, sendItem = 0, 0, 0

	local module =
	{
		name = "MailFrame",
		title = MINIMAP_TRACKING_MAILBOX or MAIL_LABEL,
		frame = CreateFrame("Frame", nil, MailFrame),
	}
	
	KeyboardUI:RegisterModule(module)
	
	function module:GainFocus()
		moduleUsingBags = self
	end
	
	function module:LoseFocus()
		moduleUsingBags = self
	end
	
	function module:ChangeTab()
		if InboxFrame:IsShown() then
			MailFrameTab2:Click()
		else
			MailFrameTab1:Click()
		end
	end
	
	function module:NextGroup()
		if SendMailFrame:IsShown() then
			if nextBag() then
				local text = getBagSlotText()
				return text and (SEND_LABEL .. " " .. text) or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
			end
		else
			return self:NextEntry()
		end
	end

	function module:PrevGroup()
		if SendMailFrame:IsShown() then
			if prevBag() then
				local text = getBagSlotText()
				return text and (SEND_LABEL .. " " .. text) or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
			end
		else
			return self:PrevEntry()
		end
	end
	
	function module:NextEntry()
		if InboxFrame:IsShown() then
			OpenMailFrame:Hide()
			if inboxEntry < GetInboxNumItems() then
				if inboxEntry > 0 and inboxEntry % INBOXITEMS_TO_DISPLAY == 0 then
					InboxNextPageButton:Click()
				else
					inboxEntry = inboxEntry + 1
				end
				local sender, subject = select(3, GetInboxHeaderInfo(inboxEntry))
				return sender .. CHAT_HEADER_SUFFIX .. subject
			end
		elseif nextBagSlot() then
			local text = getBagSlotText()
			return text and (SEND_LABEL .. " " .. text) or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
		end
	end
	
	function module:PrevEntry()
		if InboxFrame:IsShown() then
			OpenMailFrame:Hide()
			if inboxEntry > 1 then
				if inboxEntry % INBOXITEMS_TO_DISPLAY == 1 then
					InboxPrevPageButton:Click()
				else
					inboxEntry = inboxEntry - 1
				end
				local sender, subject = select(3, GetInboxHeaderInfo(inboxEntry))
				return sender .. CHAT_HEADER_SUFFIX .. subject
			end
		elseif prevBagSlot() then
			local text = getBagSlotText()
			return text and (SEND_LABEL .. " " .. text) or ("%s %d, %s"):format(AUCTION_HOUSE_HEADER_ITEM or "Slot", select(2, getBagAndSlot()), EMPTY)
		end
	end
	
	local function getInboxButton()
		return _G["MailItem" .. Wrap(inboxEntry, INBOXITEMS_TO_DISPLAY) .. "Button"] -- MailItem1 to MailItem 7
	end
	
	local function getInboxItemSlot()
		local i, x = 0, 0
		while x < inboxItem do
			i = i + 1
			if GetInboxItem(inboxEntry, i) then
				x = x + 1
			end
		end
		return i
	end
	
	local function getInboxItemText()
		local name, __, __, count, __, canUse = GetInboxItem(inboxEntry, getInboxItemSlot())
		if count > 1 then
			if canUse then
				return ("%d %s"):format(count, name)
			else
				return ("%d %s, %s"):format(count, name, MOUNT_JOURNAL_FILTER_UNUSABLE)
			end
		else
			if canUse then
				return name
			else
				return ("%s, %s"):format(name, MOUNT_JOURNAL_FILTER_UNUSABLE)
			end
		end
	end
	
	local function getInboxMessageText()
		if inboxEntry > 0 then
			local sender, subject, money, __, __, hasItem = select(3, GetInboxHeaderInfo(inboxEntry))
			money = money > 0 and GetCoinText(money) or ""
			hasItem = hasItem and hasItem > 0 and (hasItem .. " " .. ITEMS) or ""
			return 
				CHAT_SAY_GET:format(sender) .. subject,
				GetInboxText(inboxEntry),
				money .. " " .. hasItem
		end
	end
	
	function module:Forward()
		if InboxFrame:IsShown() then
			if OpenMailFrame:IsShown() then
				local hasItem = select(8, GetInboxHeaderInfo(inboxEntry)) or 0
				if inboxItem < hasItem then
					inboxItem = inboxItem + 1
					return getInboxItemText()
				elseif inboxItem == hasItem then
					inboxItem = ATTACHMENTS_MAX_RECEIVE + 1
					return InboxItemCanDelete(inboxEntry) and DELETE or MAIL_RETURN
				end
			elseif inboxEntry > 0 then
				getInboxButton():Click()
				return getInboxMessageText()
			end
		else -- if SendMailFrame:IsShown() then
			while sendItem <= ATTACHMENTS_MAX_SEND do
				sendItem = sendItem + 1
				local name = GetSendMailItem(sendItem)
				if name then
					return name
				end
			end
			return SEND_MESSAGE
		end
	end
	
	function module:Backward()
		if InboxFrame:IsShown() then
			if inboxItem > 0 then
				local hasItem = select(8, GetInboxHeaderInfo(inboxEntry)) or 0
				if inboxItem == ATTACHMENTS_MAX_RECEIVE + 1 then
					inboxItem = hasItem
				elseif inboxItem > 0 then
					inboxItem = inboxItem - 1
				end
				if inboxItem > 0 then
					return getInboxItemText()
				else
					return getInboxMessageText()	-- three return values!
				end
			else
				OpenMailFrame:Hide()
			end
		else -- if SendMailFrame:IsShown() then
			while sendItem > 1 do
				sendItem = sendItem - 1
				local name = GetSendMailItem(sendItem)
				if name then
					return name
				end
			end
			sendItem = 0
		end
	end
	
	function module:Actions()
		if InboxFrame:IsShown() then
			if OpenMailFrame:IsShown() then
				local money, __, __, __, __, __, __, canReply, isGM = select(5, GetInboxHeaderInfo(inboxEntry))
				local canDelete = InboxItemCanDelete(inboxEntry)
				return
					nil,
					money > 0 and MONEY, -- 2
					canReply and REPLY_MESSAGE, -- 3
					nil,
					canDelete and DELETE, -- 5
					not canDelete and MAIL_RETURN, -- 6
					nil,
					nil,
					not isGM and REPORT_SPAM -- 9
			elseif GetInboxNumItems() > 0 then
				return OPEN_ALL_MAIL_BUTTON
			end
		else -- if SendMailFrame:IsShown()
			return SEND_MESSAGE, CHOOSE .. " " .. SEND_MONEY, CHOOSE .. " " .. CASH_ON_DELIVERY
		end
	end
	
	function module:DoAction(index)
		if InboxFrame:IsShown() then
			if OpenMailFrame:IsShown() then
				local money, __, __, __, __, __, __, canReply, isGM = select(5, GetInboxHeaderInfo(inboxEntry))
				local canDelete = InboxItemCanDelete(inboxEntry)
				if index then
					if index == 2 and money > 0 then
						TakeInboxMoney(inboxEntry)
					elseif index == 3 and canReply then
						OpenMailReplyButton:Click()
					elseif index == 5 and canDelete then
						OpenMailDeleteButton:Click()
					elseif index == 6 and not canDelete then
						OpenMailDeleteButton:Click()
					elseif index == 9 and not isGM then
						OpenMailReportSpamButton:Click()
					end
				elseif inboxItem == ATTACHMENTS_MAX_RECEIVE + 1 then
					OpenMailDeleteButton:Click()
				elseif inboxItem > 0 then
					TakeInboxItem(inboxEntry, getInboxItemSlot())
				elseif money > 0 then
					TakeInboxMoney(inboxEntry)
				end
			else
				if index == 1 and GetInboxNumItems() > 0 then
					OpenAllMail:Click()
				elseif inboxEntry > 0 then
					getInboxButton():Click()
					return getInboxMessageText()
				end
			end
		else -- if SendMailFrame:IsShown() then
			if index then
				if index == 1 then
					SendMailMailButton:Click()
				elseif index == 2 then
					SendMailSendMoneyButton:Click()
				elseif index == 3 then
					SendMailCODButton:Click()
				end	
			elseif sendItem > 0 and sendItem <= ATTACHMENTS_MAX_SEND then
				ClickSendMailItemButton(sendItem, true)
				sendItem = sendItem - 1
			elseif sendItem > ATTACHMENTS_MAX_SEND then
				SendMailMailButton:Click()
			else
				ClearCursor()
				for i=1, ATTACHMENTS_MAX_SEND do
					if not HasSendMailItem(i) then
						(PickupContainerItem or C_Container.PickupContainerItem)(getBagAndSlot())
						ClickSendMailItemButton(i)
					end
				end
				sendItem = 0
			end
		end
	end
		
	function module:GetLongDescription()
		if InboxFrame:IsShown() then
			local numItems, totalItems = GetInboxNumItems()
			if GetInboxNumItems() == 0 then
				if totalItems > 0 then
					return
				else
					return EMPTY
				end
			elseif OpenMailFrame:IsShown() then
				return getInboxMessageText()
			end
		else -- if SendMailFrame:IsShown() then
			local name, subj = SendMailNameEditBox:GetText(), SendMailSubjectEditBox:GetText()
			name = name ~= "" and name or EMPTY
			subj = subj ~= "" and subj or EMPTY
			local attachments = 0
			for i=1, ATTACHMENTS_MAX_SEND do
				if HasSendMailItem(i) then
					attachments = attachments + 1
				end
			end
			local money = 10000*(tonumber(SendMailMoneyGold:GetText()) or 0) + 100*(tonumber(SendMailMoneySilver:GetText()) or 0) + (tonumber(SendMailMoneyCopper:GetText()) or 0)
			if money > 0 then
				money = GetCoinText(money)
				if SendMailCODButton:GetChecked() then
					money = money .. " " .. CASH_ON_DELIVERY
				end
				if attachments > 0 then
					return SENDMAIL, SendMailBodyEditBox:GetText(), ("%s %s; %s %s; %s; %d %s"):format(MAIL_TO_LABEL, name, MAIL_SUBJECT_LABEL, subj, money, attachments, ITEMS)
				else
					return SENDMAIL, SendMailBodyEditBox:GetText(), ("%s %s; %s %s; %s"):format(MAIL_TO_LABEL, name, MAIL_SUBJECT_LABEL, subj, money)
				end
			elseif attachments > 0 then
				return SENDMAIL, SendMailBodyEditBox:GetText(), ("%s %s; %s %s; %d %s"):format(MAIL_TO_LABEL, name, MAIL_SUBJECT_LABEL, subj, attachments, ITEMS)
			else
				return SENDMAIL, SendMailBodyEditBox:GetText(), ("%s %s; %s %s"):format(MAIL_TO_LABEL, name, MAIL_SUBJECT_LABEL, subj)
			end
		end
	end

	hooksecurefunc("InboxFrame_Update", function()
		local pageNum = InboxFrame.pageNum
		inboxEntry = Clamp(inboxEntry, pageNum > 1 and (pageNum-1) * INBOXITEMS_TO_DISPLAY + 1 or 0, GetInboxNumItems(), pageNum * INBOXITEMS_TO_DISPLAY)
	end)
	
	hooksecurefunc("OpenMail_Update", function()
		local newMailID = InboxFrame.openMailID
		inboxEntry = newMailID and newMailID > 0 and newMailID or min(inboxEntry, GetInboxNumItems())
		if inboxEntry > 0 then
			local hasItem = select(8, GetInboxHeaderInfo(inboxEntry)) or 0
			if inboxItem > hasItem then
				inboxItem = hasItem
			end
		else
			inboxItem = 0
		end
	end)

	module:overrideEditFocus(SendMailFrame)

end


-------------------------
-- PlayerTalentFrameSpecialization (Retail)

if false then -- not yet updated for WoW 10.x -- WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

	local spec, ability = 0, 0
	
	local module =
	{
		name = "PlayerTalentFrameSpecialization",
		title = SPECIALIZATION,
		frame = CreateFrame("Frame", nil, CreateFrame("Frame")),
	}
	
	module.frame:GetParent():Hide()
	
	KeyboardUI:RegisterModule(module)
	
	module:hookWhenFirstLoaded("PlayerTalentFrameSpecialization", "TalentFrame_LoadUI", function()
		module.frame:SetParent(PlayerTalentFrameSpecialization)
		
		hooksecurefunc("PlayerTalentFrame_UpdateSpecFrame", function(self)
			spec, ability = self.previewSpec or 0, 0
			name, description, misc = module:GetEntryLongDescription()
			if name then
				module:ttsExplain("<speak><silence msec=\"1800\" />" .. name .. "</speak>", description, misc)
			end
		end)
	end)

	function module:ChangeTab()
		PlayerTalentFrameTab2:Click()
		return TALENTS
	end

	function module:NextEntry()
		if spec < GetNumSpecializations() then
			_G["PlayerTalentFrameSpecializationSpecButton"..spec+1]:Click()
			return self:GetEntryLongDescription()
		end
	end
	
	function module:PrevEntry()
		if spec > 1 then
			_G["PlayerTalentFrameSpecializationSpecButton"..spec-1]:Click()
			return self:GetEntryLongDescription()
		end	
	end

	function module:Actions()
		return 
	end

	function module:DoAction()
		if ability == 0 then
			PlayerTalentFrameSpecializationLearnButton:Click()
		end
	end
	
	function module:GetLongDescription()
		if spec > 0 then
			local __, name, description, __, role, primaryStat = GetSpecializationInfo(spec)
			details = role .. ". " .. SPEC_FRAME_PRIMARY_STAT:format(SPEC_STAT_STRINGS[primaryStat]) .. ". " .. ABILITIES .. CHAT_HEADER_SUFFIX
			for i=1,10 do
				local fontString = _G["PlayerTalentFrameSpecializationSpellScrollFrameScrollChildAbility"..i.."Name"]
				if fontString then
					details = details .. ", " .. fontString:GetText()
				end
			end
			return name, description, details
		end
	end
	
end


-------------------------
-- PlayerTalentFrameTalents (Retail)

if false then -- not yet updated for WoW 10.x --  WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

	local tier = 0
	
	local module =
	{
		name = "PlayerTalentFrameTalents",
		title = TALENTS,
		frame = CreateFrame("Frame", nil, CreateFrame("Frame")),
	}
	
	module.frame:GetParent():Hide()
	
	KeyboardUI:RegisterModule(module)
	
	module:hookWhenFirstLoaded("PlayerTalentFrameTalents", "TalentFrame_LoadUI", function()
			module.frame:SetParent(PlayerTalentFrameTalents)
	end)

	function module:ChangeTab()
		PlayerTalentFrameTab1:Click()
		return SPECIALIZATION
	end

	local glow = module.frame:CreateTexture(nil, "ARTWORK", nil, -1)
	glow:Hide()
	glow:SetColorTexture(1, 1, 0, 0.1)

	function module:NextEntry()
		if tier < MAX_TALENT_TIERS then
			tier = tier + 1
			glow:SetParent(_G["PlayerTalentFrameTalentsTalentRow"..tier])
			glow:SetAllPoints()
			glow:Show()
			local activeSpec = GetActiveSpecGroup()
			local tierAvailable, selectedTalent, tierUnlockLevel = GetTalentTierInfo(tier, activeSpec)
			if tierAvailable then
				if selectedTalent and selectedTalent > 0 then
					local __, name = GetTalentInfo(tier, selectedTalent, activeSpec)
					return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. name
				else
					return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. LEVEL_UP_TALENT_MAIN
				end
			else
				return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. PVP_TALENTS_BECOME_AVAILABLE_AT_LEVEL:format(tierUnlockLevel)
			end
		end
	end
	
	function module:PrevEntry()
		if tier > 1 then
			tier = tier - 1
			glow:SetParent(_G["PlayerTalentFrameTalentsTalentRow"..tier])
			glow:SetAllPoints()
			glow:Show()
			local activeSpec = GetActiveSpecGroup()
			local tierAvailable, selectedTalent, tierUnlockLevel = GetTalentTierInfo(tier, activeSpec)
			if tierAvailable then
				if selectedTalent and selectedTalent > 0 then
					local __, name = GetTalentInfo(tier, selectedTalent, activeSpec)
					return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. name
				else
					return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. LEVEL_UP_TALENT_MAIN
				end
			else
				return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. PVP_TALENTS_BECOME_AVAILABLE_AT_LEVEL:format(tierUnlockLevel)
			end
		end
	end
	
	local attemptedColumn
	local function clearAttemptedColumn()
		attemptedColumn = nil
	end
	
	function module:Forward()
		if tier > 0 then
			if IsResting() then
				local __, selectedTalent = GetTalentTierInfo(tier, GetActiveSpecGroup())
				if selectedTalent and selectedTalent < NUM_TALENT_COLUMNS then
					_G["PlayerTalentFrameTalentsTalentRow"..tier.."Talent"..(selectedTalent+1)]:Click()
					attemptedColumn = selectedTalent+1
					C_Timer.After(0.5, clearAttemptedColumn)
					return selectedTalent+1
				end
			else
				return TALENT_TOOLTIP_ADD_REST_ERROR
			end
		end
	end
	
	function module:Backward()
		if tier > 0 then
			if IsResting() then
				local __, selectedTalent = GetTalentTierInfo(tier, GetActiveSpecGroup())
				if selectedTalent > 1 then
					_G["PlayerTalentFrameTalentsTalentRow"..tier.."Talent"..(selectedTalent-1)]:Click()
					attemptedColumn = selectedTalent-1
					C_Timer.After(0.5, clearAttemptedColumn)
					return selectedTalent-1
				end
			else
				return TALENT_TOOLTIP_ADD_REST_ERROR
			end
		end
	end

	function module:Actions()
		if tier > 1 then
			local activeSpec = GetActiveSpecGroup()
			local tierAvailable = GetTalentTierInfo(tier, activeSpec)
			if tierAvailable then
				local retVals = {}
				for i=1, NUM_TALENT_COLUMNS do
					tinsert(retVals, GetTalentInfo(tier, i, activeSpec))
				end
				return unpack(retVals)
			end
		end
	end

	function module:DoAction(index)
		if tier > 0 and index <= NUM_TALENT_COLUMNS then
			_G["PlayerTalentFrameTalentsTalentRow"..tier.."Talent"..index]:Click()
			attemptedColumn = index
			C_Timer.After(0.5, clearAttemptedColumn)
			return index
		end
	end
	
	function module:GetEntryLongDescription()
		local activeSpec = GetActiveSpecGroup()
		local tierAvailable, selectedTalent, tierUnlockLevel = GetTalentTierInfo(tier, activeSpec)
		if tierAvailable then
			if selectedTalent and selectedTalent > 0 then
				local __, __, __, __,__, spellID = GetTalentInfo(tier, selectedTalent, activeSpec)
				return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. self:concatTooltipLines("GetSpellByID", spellID)
			else
				return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. LEVEL_UP_TALENT_MAIN
			end
		else
			return PVP_TALENTS_BECOME_AVAILABLE_AT_LEVEL:format(tierUnlockLevel)
		end
	end
	
	module.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
	module.frame:HookScript("OnEvent", function()
		if attemptedColumn and select(4, GetTalentInfo(tier, attemptedColumn, GetActiveSpecGroup())) then
			attemptedColumn = nil
			module:ttsExplain(module:GetEntryLongDescription())
		end
	end)
	
end