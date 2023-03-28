--[[

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Refer to KeyboardUI.lua for full details


KeyboardUI_LFG.lua - Looking for dungeons, raids, arenas and battlegrounds

--]]


local KeyboardUI = select(2, ...)
local L = KeyboardUI.text

local tab, pveGroup, pvpGroup = 0, 0, 0
local action = 0
local premade = 0

local module =
{
	name = "PVEFrame",
	frame = CreateFrame("Frame", nil, PVEFrame),
	title = DUNGEONS_BUTTON,
	secureButtons =
	{
		bindingChangeTabButton = function()
			local btn = _G["PVEFrameTab"..(tab%3 + 1)]
			return btn:IsShown() and not btn.isDisabled and btn or PVEFrameTab1
		end,
		bindingNextGroupButton = function()
			if tab == 1 then
				return _G["GroupFinderFrameGroupButton"..(pveGroup+1)]			
			elseif tab == 2 then
				return _G["PVPQueueFrameCategoryButton"..(pvpGroup+1)]
			end
		end,
		bindingPrevGroupButton = function()
			if tab == 1 then
				return _G["GroupFinderFrameGroupButton"..(pveGroup-1)]
			elseif tab == 2 then
				return _G["PVPQueueFrameCategoryButton"..(pvpGroup-1)]
			end
		end,
		bindingDoActionButton = function()
			if tab == 1 and pveGroup < 3 then
				if action == 1 then
					return pveGroup == 1 and LFDQueueFrameTypeDropDownButton or pveGroup == 2 and RaidFinderQueueFrameSelectionDropDownButton
				elseif action == 2 then
					return pveGroup == 1 and LFDQueueFrameFindGroupButton or pveGroup == 2 and RaidFinderFrameFindRaidButton
				end
			--elseif tab == 2 and pvpGroup == 1 then
			--	return action == 1 and HonorFrameTypeDropDownButton or action == 2 and HonorFrameQueueButton
			end
		end,
	},
	--secureCommands = {},
}

KeyboardUI:RegisterModule(module)

function module:NextGroup() end
function module:PrevGroup() end

function module:Forward()
	if tab == 1 and pveGroup < 3 then
		if action < 2 then
			action = action + 1
			self:updatePriorityKeybinds()
			local frame = self.secureButtons.bindingDoActionButton()
			if frame then
				return action == 1 and UIDropDownMenu_GetText(frame:GetParent()) or action == 2 and frame:GetText()
			end
		end
	else
		return ERR_USE_LOCKED_WITH_ITEM_S:format(MOUSE_LABEL)
	end
end

function module:Backward()
	if tab == 1 and pveGroup < 3 then
		if action > 1 then
			action = action - 1
			self:updatePriorityKeybinds()
			local frame = self.secureButtons.bindingDoActionButton()
			if frame then
				return action == 1 and UIDropDownMenu_GetText(frame:GetParent()) or action == 2 and frame:GetText()
			end
		end
	else
		return ERR_USE_LOCKED_WITH_ITEM_S:format(MOUSE_LABEL)
	end
end

local function update()
	local isNewTab
	if PVEFrame.activeTabIndex ~= tab then
		isNewTab = true
		tab = PVEFrame.activeTabIndex
		module:ttsInterrupt(_G["PVEFrameTab"..tab]:GetText())
	end
	if tab == 1 and (isNewTab or GroupFinderFrame.selectionIndex ~= pveGroup) then
		if pveGroup ~= 0 then
			module:ttsStopMessage(_G["GroupFinderFrameGroupButton"..pveGroup.."Name"]:GetText())
		end
		pveGroup = GroupFinderFrame.selectionIndex
		action = 0
		module:ttsQueue(_G["GroupFinderFrameGroupButton"..pveGroup.."Name"]:GetText())
	elseif isNewTab and tab == 2 and pvpGroup > 0 then
		module:ttsQueue(_G["PVPQueueFrameCategoryButton"..pvpGroup].Name:GetText())
		action = 0
	end
	module:updatePriorityKeybinds()
end

hooksecurefunc("PVEFrame_ShowFrame", update)
hooksecurefunc("GroupFinderFrame_SelectGroupButton", update)

module:hookWhenFirstLoaded(PVPQueueFrame, "Blizzard_PVPUI", function()
	hooksecurefunc("PVPQueueFrame_SelectButton", function(index)
		pvpGroup = index
		if tab == 2 then
			module:ttsQueue(_G["PVPQueueFrameCategoryButton"..pvpGroup].Name:GetText())
			action = 0
			module:updatePriorityKeybinds()
		end
	end)
end)