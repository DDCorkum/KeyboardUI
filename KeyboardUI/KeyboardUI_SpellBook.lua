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
	name = "SpellBookFrame",
	frame = CreateFrame("Frame", nil, SpellBookFrame),
	title = SPELLBOOK .. " & " .. BINDING_HEADER_ACTIONBAR,
}

KeyboardUI:RegisterModule(module)

local book, tab, slot, action = 0, 0, 0, 0

local function assertSecureKeybinds()
	if book == 1 then
		if tab < GetNumSpellTabs() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingNextGroupButton"), "SpellBookSkillLineTab"..(tab+1), "LeftButton")
		end
		if tab > 1 then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingPrevGroupButton"), "SpellBookSkillLineTab"..(tab-1), "LeftButton")
		end
	end
	if SpellBookProfessionFrame then
		if book == 1 then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingChangeTabButton"), "SpellBookFrameTabButton2", "LeftButton")
		elseif book == 2 and HasPetSpells() then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingChangeTabButton"), "SpellBookFrameTabButton3", "LeftButton")
		else
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingChangeTabButton"), "SpellBookFrameTabButton1", "LeftButton")
		end
	end
end

local function removeSecureKeybinds()
	ClearOverrideBindings(module.frame)
end

local function petToSpellID(id)
	return bit.band(id, 4294967295) -- 0xFFFFFF
end

local function scanTooltip(id, bookType)
	local tooltip = module:getScanningTooltip(4)
	tooltip:SetSpellBookItem(id, bookType)
	return ("%s, %s, %s, %s, %s. %s"):format(tooltip.left1:GetText() or "", tooltip.left2:GetText() or "", tooltip.right2:GetText() or "", tooltip.left3:GetText() or "", tooltip.right3:GetText() or "", tooltip.left4:GetText() or "")
end

local function getEntryText(longDesc)
	local slotWithOffset = book == 3 and slot or (slot + select(3, GetSpellTabInfo(tab)))
	local bookType = book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL
	local spellType, id = GetSpellBookItemInfo(slotWithOffset, bookType)
	if spellType == "SPELL" then
		return longDesc and scanTooltip(slotWithOffset, bookType) or GetSpellInfo(id)
	elseif spellType == "FUTURESPELL" then
		return longDesc and scanTooltip(slotWithOffset, bookType) or GetSpellInfo(id)
	elseif spellType == "FLYOUT" then
		return longDesc and scanTooltip(slotWithOffset, bookType) or "Collection of " .. GetFlyoutInfo(id) .. " abilities."
	elseif spellType == "PETACTION" then
		return longDesc and scanTooltip(slotWithOffset, bookType) or GetSpellInfo(petToSpellID(id))
	end
end

local function getActionText()
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

local positions = {[0] = SPELLS_PER_PAGE}		-- 1, 3, 5, 7, 9, 11, 2, 4, 6, 8, 10, 12... but the last one is in position 0 because the math is modulo 12.
for i=1, SPELLS_PER_PAGE-1, 2 do
	tinsert(positions, i)
end
for i=2, SPELLS_PER_PAGE-2, 2 do
	tinsert(positions, i)
end

local function getPosition(offset)
	return offset and positions[(slot + offset) % SPELLS_PER_PAGE] or positions[slot % SPELLS_PER_PAGE]
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
	local button = book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
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
	local button = book == 2 and slot > 0 and getProfessionButton() or slot > 0 and _G["SpellButton"..getPosition()]
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
	for __, button in ipairs(professionButtons) do
		if button.AbilityHighlight then
			button.AbilityHighlight:Hide()
		end
	end
end

function module:ChangeTab()
	-- taint; migrated to assertSecureKeybinds()
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
			tab, slot = lowest, 1
			showGlow()
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
			tab, slot = lowest, 1
			showGlow()
			return getEntryText()
		end
	end
end

function module:NextEntry()
	if book == 2 then
		if slot > 0 and slot < select(4, GetSpellTabInfo(tab)) then
			hideGlow()
			slot = slot + 1
			showGlow()
			return getEntryText()
		else
			return module:NextGroup()
		end	
	else
		if book == 1 and slot < select(4, GetSpellTabInfo(tab)) or book == 3 and slot < HasPetSpells() then
			hideGlow()
			slot = slot + 1
			if slot > SpellBook_GetCurrentPage() * SPELLS_PER_PAGE then
				ignorePageButtons = true
				SpellBookNextPageButton:Click()
				ignorePageButtons = false
			end
			showGlow()
			return getEntryText()
		end
	end
end

function module:PrevEntry()
	if book == 2 then
		if slot > 1  then
			hideGlow()
			slot = slot - 1
			showGlow()
			return getEntryText()
		else
			return module:PrevGroup()
		end	
	else
		if slot > 1 then
			hideGlow()
			slot = slot - 1
			if slot <= (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE then
				ignorePageButtons = true
				SpellBookPrevPageButton:Click()
				ignorePageButtons = false
			end
			showGlow()
			return getEntryText()
		end
	end
end

function module:RefreshEntry()
	if book == 2 then
		-- NYI
	elseif book == 1 then
		slot = min(slot, (select(4, GetSpellTabInfo(tab))))
	elseif book == 3 then
		slot = min(slot, (HasPetSpells()))
	end
	return slot > 0 and getEntryText() or ""
end

function module:GetEntryLongDescription()
	return getEntryText(true)
end

function module:Forward()
	if action == 0 then
		local bonus = GetBonusBarOffset()
		if bonus > 0 then
			action = (bonus + 5) * 12 + 1
		else
			action = (GetActionBarPage() - 1) * 12 + 1
		end
	elseif action < 120 then
		action = action + 1
	end
	return (HasAction(action) and (REPLACE .. " ") or "") .. getActionText()
end

function module:Backward()
	if action > 1 then
		action = action - 1
		return (slot > 1 and HasAction(action) and (REPLACE .. " ") or "") .. getActionText()
	end
end

function module:Actions()
	-- nop()
end

function module:DoAction(index)
	if index then
		-- nop()
	elseif slot > 0 and action > 0 then
		PickupSpellBookItem(book == 3 and slot or slot + select(3, GetSpellTabInfo(tab)), book == 3 and BOOKTYPE_PET or BOOKTYPE_SPELL)
		local info = GetCursorInfo()
		if info == "spell" or info == "petaction" then
			PlaceAction(action)
			ClearCursor()
			return getActionText()
		else
			return "Unable to place " .. getEntryText() .. " onto " .. getActionText()
		end
	end
end

local firstTime = true
local function announce(self, book)
	if self:IsVisible() then
		if firstTime then
			firstTime = false
			module:ttsInterrupt(book)
			module:ttsQueue(([=[Use %s and %s and other keybinds to navigate the spell book.  Use %s and %s to choose an action bar slot.  %s puts the spell in the action bar.]=]):format(module:getOption("bindingNextEntryButton"), module:getOption("bindingPrevEntryButton"), module:getOption("bindingForwardButton"), module:getOption("bindingBackwardButton"), module:getOption("bindingDoActionButton")), KUI_NORMAL, KUI_MP, true)
		else
			module:ttsYield(book)
		end
	end
end

SpellBookSpellIconsFrame:Hide()
SpellBookSpellIconsFrame:HookScript("OnShow", function(self)
	if SpellBookFrame.bookType == BOOKTYPE_SPELL then
		book, tab, slot =  1, SpellBookFrame.selectedSkillLine, 0
		removeSecureKeybinds()
		assertSecureKeybinds()
		announce(self, SPELLBOOK)
	else -- BOOKTYPE_PET
		book, tab, slot = 3, 0, 0
		removeSecureKeybinds()
		assertSecureKeybinds()
		announce(self, PET)
	end
end)

SpellBookSpellIconsFrame:HookScript("OnHide", function(self)
	removeSecureKeybinds()
end)

if SpellBookProfessionFrame then
	SpellBookProfessionFrame:Hide()
	
	SpellBookProfessionFrame:HookScript("OnShow", function(self)
		book, tab, slot = 2, 0, 0
		removeSecureKeybinds()
		assertSecureKeybinds()
		announce(self, TRADE_SKILLS)
	end)
end

SpellBookFrame:HookScript("OnHide", function()
	book, tab, slot = 0, 0, 0
end)

SpellBookNextPageButton:HookScript("OnClick", function()
	if not ignorePageButtons then
		hideGlow()
		slot = (slot + SPELLS_PER_PAGE) - (slot % SPELLS_PER_PAGE) + 1
		position = 1
		showGlow()
	end
end)

SpellBookPrevPageButton:HookScript("OnClick", function()
	if not ignorePageButtons then
		hideGlow()
		slot = slot - (slot % SPELLS_PER_PAGE)
		position = SPELLS_PER_PAGE
		showGlow()
	end
end)

if SpellBookFrame_OpenToSpell then
	hooksecurefunc("SpellBookFrame_OpenToSpell", function(spellID)
		if book == 1 then
			local flyout = FindFlyoutSlotBySpellID(spellID)
			hideGlow()
			tab, slot = SpellBookFrame.selectedSkillLine, (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE
			local __, __, offset, numEntries = GetSpellTabInfo(tab)
			while slot + offset < numEntries do
				slot = slot + 1
				local spellType, id = GetSpellBookItemInfo(slot + offset, BOOKTYPE_SPELL)			
				if flyout and id == flyout or id == spellID then
					break;
				end
			end
			showGlow()
		elseif book == 3 then
			local flyout = FindFlyoutSlotBySpellID(spellID)
			hideGlow()
			slot = (SpellBook_GetCurrentPage() - 1) * SPELLS_PER_PAGE
			while slot < HasPetSpells() do
				slot = slot + 1
				local spellType, id = GetSpellBookItemInfo(slot + offset, BOOKTYPE_PET)			
				if flyout and id == flyout or id == spellID then
					break;
				end
			end
			showGlow()	
		end
	end)
end

hooksecurefunc("ChangeActionBarPage", function(page)
	if book > 0 and slot > 0 then
		local page, bonus = GetActionBarPage(), GetBonusBarOffset()
		local firstAction = (bonus and (bonus+5) or (page-1))*12 + 1
		if action >= firstAction and action <= firstAction + 12 then
			action = firstAction
		end
	end
end)

hooksecurefunc("ToggleSpellBook", function(bookType)
	if bookType == BOOKTYPE_SPELL and book ~= 1 then
		hideGlow()
		book, tab, slot = 1, SpellBookFrame.selectedSkillLine, 0		
		removeSecureKeybinds()
		assertSecureKeybinds()
	elseif bookType == BOOKTYPE_PET and book ~= 3 and HasPetSpells() then
		hideGlow()
		book, tab, slot = 3, 0, 0		
		removeSecureKeybinds()
		assertSecureKeybinds()	
	end
	-- BOOKTYPE_PROFESSION is not actually necessary, because the profession frame is guaranteed to appear
end)

hooksecurefunc ("SpellBookFrame_Update", function()
	if book == 1 and tab ~= SpellBookFrame.selectedSkillLine then
		tab, slot = SpellBookFrame.selectedSkillLine, 0
		removeSecureKeybinds()
		assertSecureKeybinds()
	end
end)

hooksecurefunc("ActionBarController_UpdateAll", function()
	if book > 0 and slot > 0 then
		local page, bonus = GetActionBarPage(), GetBonusBarOffset()
		local firstAction = (bonus and (bonus+5) or (page-1))*12 + 1
		if action >= firstAction and action <= firstAction + 12 then
			action = firstAction
		end
	end
end)