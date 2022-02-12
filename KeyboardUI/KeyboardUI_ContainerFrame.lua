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

local bagID, slot = BACKPACK_CONTAINER, 0
local itemLoc = ItemLocation:CreateEmpty()

local module =
{
	name = "ContainerFrame",
	title = BACKPACK_TOOLTIP,
	frame = ContainerFrame1,
	secureCommands =
	{
		bindingDoActionButton = function() return IsUsableItem(GetContainerItemID(bagID, slot)) and "ITEM " .. GetItemInfo(GetContainerItemID(bagID, slot)) end,
	},
}

KeyboardUI:RegisterModule(module)

local function getCountAndName()
	local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, slot)
	if itemID then
		local itemName, __, __, __, itemMinLevel, __, __, __, itemEquipLoc = GetItemInfo(itemID)
		itemLoc:SetBagAndSlot(bagID, slot)
		local itemQuality = C_Item.GetItemQuality(itemLoc)
		local itemLevel = C_Item.GetCurrentItemLevel(itemLoc)		
		if itemEquipLoc ~= "" and UnitLevel("player") >= itemMinLevel then
			local itemSlot = itemEquipLoc:gsub("TYPE", "SLOT")
			if not _G[itemSlot] then
				itemSlot = itemSlot.."1"
			end
			local oldItemID = GetInventoryItemID("player", _G[itemSlot])
			if oldItemID then
				local oldName, __, oldQuality, oldLevel = GetItemInfo(oldItemID)
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
		else
			return itemName
		end
	end
end

function module:NextGroup()
	for i=bagID+1, BACKPACK_CONTAINER + 4 do
		local numberOfSlots = GetContainerNumSlots(i)
		if numberOfSlots > 0 then
			bagID, slot = i, 1
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
			bagID, slot = i, 1
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
	if slot < GetContainerNumSlots(bagID) then
		slot = slot + 1
		self:updatePriorityKeybinds()
		local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, slot)
		return slot .. "; " .. (getCountAndName() or EMPTY)
	end
end

function module:PrevEntry()
	if slot > 1 then
		slot = slot - 1
		local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, slot)
		self:updatePriorityKeybinds()
		return slot .. "; " .. (getCountAndName() or EMPTY)
	end
end

function module:RefreshEntry()
	if slot > GetContainerNumSlots(bagID) then
		slot = GetContainerNumSlots(bagID)
		self:updatePriorityKeybinds()
	end
	if slot == 0 then
		bagID = BACKPACK_CONTAINER
		self:updatePriorityKeybinds()
	end
	return slot > 0
end

function module:GetEntryLongDescription()
	if self:RefreshEntry() then
		local tooltip = self:getScanningTooltip()
		tooltip:SetBagItem(bagID, slot)
		return self:readScanningTooltip()
		
	--[[	local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, slot)
		if bagID == BACKPACK_CONTAINER then
			return BACKPACK_TOOLTIP .. "; " .. slot .. "; " .. (itemID and (itemCount > 1 and ITEM_QUANTITY_TEMPLATE:format(itemCount, GetItemInfo(itemID)) or GetItemInfo(itemID)) or EMPTY)
		else
			return INVTYPE_BAG .. bagID .. "; " .. slot .. "; " .. (itemID and (itemCount > 1 and ITEM_QUANTITY_TEMPLATE:format(itemCount, GetItemInfo(itemID)) or GetItemInfo(itemID)) or EMPTY)
		end
	--]]
	end
end


-- this will not happen for consumable items, due to the use of secure frames.
function module:DoAction()
	local __, itemCount, __, __, __, __, __, __, __, itemID = GetContainerItemInfo(bagID, slot)
	local itemName, __, __, __, itemMinLevel, itemType, itemSubType, __, itemEquipLoc = GetItemInfo(itemID)
	itemLoc:SetBagAndSlot(bagID, slot)
	local itemQuality = C_Item.GetItemQuality(itemLoc)
	local itemLevel = C_Item.GetCurrentItemLevel(itemLoc)	
	if itemEquipLoc ~= "" and UnitLevel("player") >= itemMinLevel then
		local itemSlot = itemEquipLoc:gsub("TYPE", "SLOT")
		if not _G[itemSlot] then
			itemSlot = itemSlot.."1"
		end
		local oldItemID = GetInventoryItemID("player", _G[itemSlot])
		if oldItemID then
			itemLoc:SetEquipmentSlot(_G[itemSlot])
			local oldName = C_Item.GetItemName(itemLoc)
			local oldQuality = C_Item.GetItemQuality(itemLoc)
			local oldLevel = C_Item.GetCurrentItemLevel(itemLoc)
			EquipItemByName(itemID)
			print(oldQuality)
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
	end
end     