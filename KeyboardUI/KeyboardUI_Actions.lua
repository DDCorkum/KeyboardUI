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

local action = 0								-- used by SpellBookFrame and ContainerFrame modules to place abilities and consumables on the action bar
local bagID, bagSlot = BACKPACK_CONTAINER, 0	-- used by ContainerFrame and MerchantFrame modules to interact with the player inventory

local moduleUsingActionBar = nil

-------------------------
-- Shared action bar management

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
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Prowl Bar" or className == "ROGUE" and "Shadow Dance Bar" or className == "WARRIOR" and "Defensive Stance Bar" or (PAGE_NUMBER:format(7).." ("..UNUSED..")"), action-84)
		elseif action <= 108 then
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Bear Form Bar" or className == "WARRIOR" and "Berserker Stance Bar" or (PAGE_NUMBER:format(7).." ("..UNUSED..")"), action-96)
		else
			return ("%s at %s slot %d"):format(contains, className == "DRUID" and "Moonkin Form Bar" or (PAGE_NUMBER:format(7).." ("..UNUSED..")"), action-108)
		end
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
	
MainMenuBarArtFrame:HookScript("OnAttributeChanged", function(__, key, value)
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
					elseif getPosition() == SPELLS_PER_PAGE then
						if flyout > 0 then
							local btn = _G["SpellFlyoutButton"..(flyout+1)]
							if not btn or not btn:IsShown() then
								return "SpellBookNextPageButton"
							end
						else
							return "SpellBookNextPageButton"
						end
					end
				end
			end,
			bindingPrevEntryButton = function() return flyout == 1 and "SpellButton"..getPosition() or flyout == 0 and getPosition() == 1 and "SpellBookPrevPageButton" end,
		},
		secureCommands =
		{
			bindingDoActionButton = function()
				if not useActionSlots then
					if flyout > 0 then
						return "CLICK SpellFlyoutButton" .. flyout .. ":LeftButton"
					end
					local slotWithOffset = book == 3 and slot or (slot + select(3, GetSpellTabInfo(tab)))
					local bookType = book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
					local spellType, id = GetSpellBookItemInfo(slotWithOffset, bookType)
					if spellType == "SPELL" then
						return "SPELL " .. GetSpellInfo(id)
					elseif spellType == "FLYOUT" then
						return "CLICK SpellButton"..getPosition()
					elseif spellType == "PETACTION" then
						return "CLICK SpellButton"..getPosition()..":LeftButton"
					end
				end
			end,
		}
	}

	KeyboardUI:RegisterModule(module)

	local parentGainFocus = module.GainFocus
	function module:GainFocus()
		parentGainFocus(self)
		moduleUsingActionBar = self
	end
	
	function module:LoseFocus()
		moduleUsingActionbAr = nil
	end

	local function scanTooltip(id, bookType)
		module:getScanningTooltip():SetSpellBookItem(id, bookType)
		return module:readScanningTooltip()
	end

	local function scanTooltipByID(spellID)
		module:getScanningTooltip():SetSpellByID(spellID)
		return module:readScanningTooltip()
	end

	local function getEntryText(longDesc)
		local slotWithOffset = book == 3 and slot or (slot + select(3, GetSpellTabInfo(tab)))
		local bookType = book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
		local spellType, id = GetSpellBookItemInfo(slotWithOffset, bookType)
		if flyout == 0 then
			if spellType == "SPELL" then
				return longDesc and scanTooltip(slotWithOffset, bookType) or GetSpellInfo(id)
			elseif spellType == "FUTURESPELL" then
				local name, __, __, __, minLevel = GetSpellInfo(id)
				return longDesc and scanTooltip(slotWithOffset, bookType) or name .. " (" .. UNKNOWN .. ")."
			elseif spellType == "FLYOUT" then
				return longDesc and scanTooltip(slotWithOffset, bookType) or "Collection of " .. GetFlyoutInfo(id) .. " abilities."
			elseif spellType == "PETACTION" then
				return longDesc and scanTooltip(slotWithOffset, bookType) or GetSpellBookItemName(slotWithOffset, bookType)
			end
		else
			local spellID = GetFlyoutSlotInfo(id, flyout)
			return longDesc and scanTooltipByID(spellID) or GetSpellInfo(spellID)
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

	local function showGlow()
		local button = flyout > 0 and _G["SpellFlyoutButton"..flyout] or book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
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
		local button = flyout > 0 and _G["SpellFlyoutButton"..flyout] or book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
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

	function module:NextGroup()
		-- The spellbook uses secure buttons to resolve taint, and the pet book doesn't have tabs.
		if book == 2 then
			local lowest
			for __, v in pairs({GetProfessions()}) do
				if v > tab and (not lowest or v < lowest) then
					lowest = v
				end
			end
			if lowest then
				hideGlow()
				tab, slot, flyout, useActionSlots = lowest, 1, 0, false
				showGlow()
				useActionSlots = false
				self:updatePriorityKeybinds()
				return getEntryText()
			end
		end
	end

	function module:PrevGroup()
		-- The spellbook uses secure buttons to resolve taint, and the pet book doesn't have tabs.
		if book == 2 then
			local lowest
			for __, v in pairs({GetProfessions()}) do
				if v < tab and (not lowest or v > lowest) then
					lowest = v
				end
			end
			if lowest then
				hideGlow()
				tab, slot, flyout, useActionSlots = lowest, 1, 0, false
				showGlow()
				useActionSlots = false
				self:updatePriorityKeybinds()
				return getEntryText()
			end
		end
	end

	function module:NextEntry()
		if book == 2 then
			if slot > 0 and slot < select(4, GetSpellTabInfo(tab)) then
				hideGlow()
				slot, useActionSlots = slot + 1, false
				showGlow()
				self:updatePriorityKeybinds()
				return getEntryText()
			else
				return module:NextGroup()
			end	
		elseif flyout > 0 and _G["SpellFlyoutButton"..(flyout+1)] and _G["SpellFlyoutButton"..(flyout+1)]:IsShown() then
			hideGlow()
			flyout, useActionSlots = flyout + 1, false
			showGlow()
			self:updatePriorityKeybinds()
			return getEntryText()
		else
			__, __, numSpells = getPositionInBook()
			if slot < numSpells then
				if SpellFlyout then
					SpellFlyout:Hide()
				end
				hideGlow()
				slot, flyout, useActionSlots = slot + 1, 0, false
				showGlow()
				self:updatePriorityKeybinds()
				return getEntryText()
			end
		end
	end

	function module:PrevEntry()
		if book == 2 then
			if slot > 1  then
				hideGlow()
				slot, useActionSlots = slot - 1, false
				showGlow()
				self:updatePriorityKeybinds()
				return getEntryText()
			else
				return module:PrevGroup()
			end	
		end
		if flyout > 1 then
			hideGlow()
			flyout, useActionSlots = flyout - 1, false
			showGlow()
			module:updatePriorityKeybinds()
			return getEntryText()
		elseif slot > 1 then
			hideGlow()
			slot, useActionSlots = slot - 1, false
			showGlow()
			self:updatePriorityKeybinds()
			return getEntryText()
		end
	end

	function module:RefreshEntry()
		local oldSlot = slot
		if book == 3 then
			slot = min(slot, (HasPetSpells()))
		else
			slot = min(slot, (select(4, GetSpellTabInfo(tab))))
		end
		if oldSlot ~= slot then
			flyout = 0
		end
		return slot > 0 and getEntryText() or ""
	end

	function module:GetEntryLongDescription()
		return getEntryText(true)
	end

	function module:Forward()
		if useActionSlots then
			return nextActionSlot(slot > 0)
		else
			useActionSlots = true
			self:updatePriorityKeybinds()
			return action == 0 and nextActionSlot(slot > 0) or slot > 1 and REPLACES_SPELL:format(getActionText()) or getActionText()
		end
	end

	function module:Backward()
		if useActionSlots then
			return prevActionSlot(slot > 0)
		else
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
				module:ttsQueue(([=[Use %s and %s to choose a spell, and use %s and %s to choose an action bar slot.  %s puts the chosen spell in the chosen action bar slot.]=]):format(module:getOption("bindingNextEntryButton"), module:getOption("bindingPrevEntryButton"), module:getOption("bindingForwardButton"), module:getOption("bindingBackwardButton"), module:getOption("bindingDoActionButton")), KUI_NORMAL, KUI_MP, true)
			else
				module:ttsYield(book)
			end
			if TutorialQueue and TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd then
				module:ttsQueue(NPEV2_SPELLBOOKREMINDER:format(GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd)), KUI_NORMAL, KUI_MP)
			end
		end
	end

	-- temporary, to be merged into KeyboardUI_Actions.lua to include a tutorial on changing action bar slots
	module:registerTutorial(function() return TutorialQueue and TutorialQueue.currentTutorial and (TutorialQueue.currentTutorial.spellToAdd or false) end,
		{
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and SpellBookFrame:IsShown() or L["PRESS_TO"]:format(GetBindingKey("TOGGLESPELLBOOK") or "", NPEV2_SPELLBOOK_ADD_SPELL:format(GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd))) end,
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and slot > 0 or L["PRESS_TO"]:format(module:getOption("bindingNextEntryButton"), CHOOSE .. CHAT_HEADER_SUFFIX .. GetSpellInfo(TutorialQueue.currentTutorial.spellToAdd)) end,
			function() return TutorialQueue.currentTutorial and TutorialQueue.currentTutorial.spellToAdd and action > 0 or L["PRESS_TO"]:format(module:getOption("bindingForwardButton"), CHOOSE .. CHAT_HEADER_SUFFIX .. BINDING_HEADER_ACTIONBAR) end,
		}
	)
	

	SpellBookSpellIconsFrame:Hide()
	SpellBookSpellIconsFrame:HookScript("OnShow", function(self)
		if SpellBookFrame.bookType == BOOKTYPE_SPELL then
			book, tab, flyout =  1, SpellBookFrame.selectedSkillLine, 0
			local page = SpellBook_GetCurrentPage()
			if page == 1 then
				slot = 0
			else
				slot = (page-1) * SPELLS_PER_PAGE + 1
				showGlow()
			end
			useActionSlots = false
			module:updatePriorityKeybinds()
			announce(self, SPELLBOOK)
		else -- BOOKTYPE_PET
			book, tab, slot, flyout = 3, 0, 0, 0
			useActionSlots = false
			module:updatePriorityKeybinds()
			announce(self, PET)
		end
	end)

	SpellBookSpellIconsFrame:HookScript("OnHide", function(self)
		if book == 1 then
			hideGlow()
			book, slot = nil, 0
			module:updatePriorityKeybinds()
		end
	end)

	if SpellBookProfessionFrame then
		-- Retail only
		SpellBookProfessionFrame:Hide()
		SpellBookProfessionFrame:HookScript("OnShow", function(self)
			book, tab, slot, flyout = 2, 0, 0, 0
			module:updatePriorityKeybinds()
			announce(self, TRADE_SKILLS)
		end)
	end

	SpellBookFrame:HookScript("OnHide", function()
		hideGlow()
		flyout, action = 0, 0
	end)

	
	SpellBookNextPageButton:HookScript("OnClick", function()
		if not ignorePageButtons then
			hideGlow()
			if slot > 0 and getPosition() == SPELLS_PER_PAGE then
				slot, flyout, useActionSlots = slot + 1, 0, useActionSlots
			else
				slot, flyout, useActionSlots = slot - slot % SPELLS_PER_PAGE + SPELLS_PER_PAGE, 0, false
			end
			showGlow()
			module:updatePriorityKeybinds()
		end
	end)

	SpellBookPrevPageButton:HookScript("OnClick", function()
		if not ignorePageButtons then
			hideGlow()
			if slot > 0 and getPosition() == SPELLS_PER_PAGE then
				slot, flyout, useActionSlots = slot - SPELLS_PER_PAGE, 0, useActionSlots
			else
				slot, flyout, useActionSlots = slot - slot % SPELLS_PER_PAGE, 0, false
			end
			showGlow()
			module:updatePriorityKeybinds()
		end
	end)

	if SpellFlyout then
	
		-- Classic vs. Retail
		
		SpellFlyout:HookScript("OnShow", function()
			local parent = SpellFlyout:GetParent()
			if parent and parent:GetName():find("SpellButton") then
				hideGlow()
				flyout, useActionSlots = 1, false
				showGlow()
				module:updatePriorityKeybinds()
			end
		end)

		SpellFlyout:HookScript("OnHide", function()
			hideGlow()
			flyout, useActionSlots = 0, false
			showGlow()
			module:updatePriorityKeybinds()
		end)
		
	end
	
--[[
	-- this wasn't working out in the tutorial.  For some classes, it would go to the wrong spell

	if SpellBookFrame_OpenToSpell then
		hooksecurefunc("SpellBookFrame_OpenToSpell", function(spellID)
			hideGlow()
			if book == 2 then
				tab, slot, flyout = SpellBookFrame.selectedSkillLine, 1, 0
				if select(2, GetSpellBookItemInfo(slot + select(3,GetSpellTabInfo(tab)), BOOKTYPE_SPELL)) ~= spellID then
					slot = 2 -- a bit of an assumption here, needs testing
				end
			else
				if book == 1 then
					tab, slot, flyout = SpellBookFrame.selectedSkillLine, (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE, 0
				else
					tab, slot, flyout = 0, (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE, 0
				end
				local __, __, offset, numEntries = GetSpellTabInfo(tab)
				while slot + offset < numEntries do
					slot = slot + 1
					local actionType, actionID = GetSpellBookItemInfo(slot + offset, BOOKTYPE_SPELL)
					if actionType == "FLYOUT" then
						local __, __, flyoutNumSlots = GetFlyoutInfo(actionID)
						if not SpellFlyout:IsShown() then
							_G["SpellButton"..getPosition()]:Click()
						end
						flyout = 1
						for i=1, flyoutNumSlots do
							if spellID == GetFlyoutSlotInfo(actionID, i) then
								flyout = i
								break
							end
						end
						break;
					elseif id == spellID then
						break;
					end
				end
			end
			showGlow()
			useActionSlots = false
			module:updatePriorityKeybinds()
			module:ttsQueue("Currently at " .. getEntryText())
		end)
	end
	
--]]

	hooksecurefunc("ToggleSpellBook", function(bookType)
		if bookType == BOOKTYPE_SPELL and book ~= 1 then
			hideGlow()
			book, tab, flyout = 1, SpellBookFrame.selectedSkillLine, 0
			local page = SpellBook_GetCurrentPage()
			if page == 1 then
				slot = 0
			else
				slot = (page-1) * SPELLS_PER_PAGE + 1
				showGlow()
			end
			module:updatePriorityKeybinds()
		elseif bookType == BOOKTYPE_PET and book ~= 3 and HasPetSpells() then
			hideGlow()
			book, tab, slot, flyout = 3, 0, 0, 0
			useActionSlots = false
			module:updatePriorityKeybinds()
		end
		-- BOOKTYPE_PROFESSION is not actually necessary, because the profession frame is guaranteed to appear
	end)

	hooksecurefunc ("SpellBookFrame_Update", function()
		if book == 1 and tab ~= SpellBookFrame.selectedSkillLine then
			tab, flyout = SpellBookFrame.selectedSkillLine, 0
			local page = SpellBook_GetCurrentPage()
			if page == 1 then
				slot = 0
			else
				slot = (page-1) * SPELLS_PER_PAGE + 1
				showGlow()
			end
			module:updatePriorityKeybinds()
			module:ttsYield(GetSpellTabInfo(tab) or "General")
		end
	end)

end


-------------------------
-- Backpack and bags without a merchant window

do

	local itemLoc = ItemLocation:CreateEmpty()	-- just a reusable table

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
			bindingDoActionButton = function() return useActionSlots == false and isUsable(GetContainerItemID(bagID, bagSlot)) and "ITEM " .. GetItemInfo(GetContainerItemID(bagID, bagSlot)) end,
		},
	}

	KeyboardUI:RegisterModule(module)
	
	function module:GainFocus()
		moduleUsingActionBar = self
	end
	
	function module:LoseFocus()
		moduleUsingActionbAr = nil
	end

	local function getRedTooltipText()
		local tooltip = module:getScanningTooltip()
		tooltip:SetBagItem(bagID, bagSlot)
		for __, fontString in ipairs(tooltip) do
			local r, g, b = fontString:GetTextColor()
			local text = fontString:GetText()
			if text and text ~= "" and g < 0.2 and b < 0.2 and r > 0.9 then
				return text
			end
		end
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
	
	
	local function getCountAndName()
		local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, bagSlot)
		if itemID then
			local itemName, __, __, __, itemMinLevel, itemType, __, __, itemEquipLoc = GetItemInfo(itemID)
			itemLoc:SetBagAndSlot(bagID, bagSlot)
			local itemQuality = C_Item.GetItemQuality(itemLoc)
			local itemLevel = C_Item.GetCurrentItemLevel(itemLoc)
			local redText = getRedTooltipText()
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

	function module:NextGroup()
		for i=bagID+1, BACKPACK_CONTAINER + 4 do
			local numberOfSlots = GetContainerNumSlots(i)
			if numberOfSlots > 0 then
				bagID, bagSlot = i, 1
				useActionSlots = false
				self:updatePriorityKeybinds()
				local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(i)
				if bagID == BACKPACK_CONTAINER then
					return ("%s. %d of %d %s %s. %s"):format(BACKPACK_TOOLTIP, numberOfFreeSlots, numberOfSlots, BAGSLOTTEXT, EMPTY, getCountAndName() or "")
				else
					return ("%s %d. %d of %d %s %s. %s"):format(INVTYPE_BAG, bagID, numberOfFreeSlots, numberOfSlots, BAGSLOTTEXT, EMPTY, getCountAndName() or "")
				end
			end
		end
	end

	function module:PrevGroup()
		for i=bagID-1, BACKPACK_CONTAINER, -1 do
			local numberOfSlots = GetContainerNumSlots(i)
			if numberOfSlots > 0 then
				bagID, bagSlot = i, 1
				useActionSlots = false
				self:updatePriorityKeybinds()
				local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(i)
				if bagID == BACKPACK_CONTAINER then
					return ("%s. %d of %d %s %s. %s"):format(BACKPACK_TOOLTIP, numberOfFreeSlots, numberOfSlots, BAGSLOTTEXT, EMPTY, getCountAndName() or "")
				else
					return ("%s %d. %d of %d %s %s. %s"):format(INVTYPE_BAG, bagID, numberOfFreeSlots, numberOfSlots, BAGSLOTTEXT, EMPTY, getCountAndName() or "")
				end
			end
		end
	end

	function module:NextEntry()
		if bagSlot < GetContainerNumSlots(bagID) then
			bagSlot = bagSlot + 1
			useActionSlots = false
			self:updatePriorityKeybinds()
			return bagSlot .. "; " .. (getCountAndName() or EMPTY)
			
		end
	end

	function module:PrevEntry()
		if bagSlot > 1 then
			bagSlot = bagSlot - 1
			local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, bagSlot)
			useActionSlots = false
			self:updatePriorityKeybinds()
			return bagSlot .. "; " .. (getCountAndName() or EMPTY)
		end
	end

	function module:RefreshEntry()
		if bagSlot > GetContainerNumSlots(bagID) then
			bagSlot = GetContainerNumSlots(bagID)
			useActionSlots = false
			self:updatePriorityKeybinds()
		end
		if bagSlot == 0 then
			bagID = BACKPACK_CONTAINER
			useActionSlots = false
			self:updatePriorityKeybinds()
		end
		return bagSlot > 0
	end

	function module:GetEntryLongDescription()
		if self:RefreshEntry() then
			self:getScanningTooltip():SetBagItem(bagID, bagSlot)
			return self:readScanningTooltip()
		end
	end

	function module:Forward()
		local itemID = select(10, GetContainerItemInfo(bagID, bagSlot))
		if useActionSlots then
			return nextActionSlot(isUsable(itemID))
		else
			useActionSlots = true
			self:updatePriorityKeybinds()
			return action == 0 and nextActionSlot(isUsable(itemID)) or itemID and HasAction(action) and REPLACES_SPELL:format(getActionText()) or getActionText()
		end
	end

	function module:Backward()
			local itemID = select(10, GetContainerItemInfo(bagID, bagSlot))
			if useActionSlots then
				return prevActionSlot(isUsable(itemID))
			else
				useActionSlots = true
				self:updatePriorityKeybinds()
				return action == 0 and prevActionSlot(isUsable(itemID)) or itemID and HasAction(action) and REPLACES_SPELL:format(getActionText()) or getActionText()
			end
	end

	function module:Actions()
		local itemID = select(10, GetContainerItemInfo(bagID, bagSlot))
		return getAllActionSlotTexts(isUsable(itemID))
	end

	function module:DoAction(index)
		if index then
			setActionSlot(index)
			useActionSlot = true
			self:updatePriorityKeybinds()
			return module:DoAction()
		end
		
		local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, bagSlot)
		if not itemID then
			return
		end
		
		local redText = getRedTooltipText()
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
		if not SpellBookFrame:IsShown() then
			module.frame:Show()
		end
	end)
	
	SpellBookFrame:HookScript("OnShow", function()
		module.frame:Hide()
	end)
	
	SpellBookFrame:HookScript("OnHide", function()
		if not MerchantFrame:IsShown() then
			module.frame:Show()
		end
	end)
end


-------------------------
-- MerchantFrame

do
	local module =
	{
		name = "MerchantFrame",
		title = MERCHANT,
		frame = CreateFrame("Frame", nil, MerchantFrame),
	}
	
	-- NYI
	--KeyboardUI:RegisterModule(module)
end


-------------------------
-- PlayerTalentFrameSpecialization (Retail)

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

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
				module:ttsInterruptExtended("<speak><silence msec=\"1800\" />" .. name .. "</speak>", description, misc)
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
	
	function module:RefreshEntry()
		return spec > 0
	end
	
	function module:GetEntryLongDescription()
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

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

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

	local glow = module.frame:CreateTexture(nil, ARTWORK, -1)
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
	
	function module:RefreshEntry()
		return tier > 0
	end
	
	function module:GetEntryLongDescription()
		local activeSpec = GetActiveSpecGroup()
		local tierAvailable, selectedTalent, tierUnlockLevel = GetTalentTierInfo(tier, activeSpec)
		if tierAvailable then
			if selectedTalent and selectedTalent > 0 then
				local __, __, __, __,__, spellID = GetTalentInfo(tier, selectedTalent, activeSpec)
				self:getScanningTooltip():SetSpellByID(spellID)
				return LEVEL_GAINED:format(tierUnlockLevel) .. CHAT_HEADER_SUFFIX .. self:readScanningTooltip()
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
			module:ttsInterruptExtended(module:GetEntryLongDescription())
		end
	end)
	
end