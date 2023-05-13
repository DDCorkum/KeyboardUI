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

local function hasRole()
	if pveGroup == 1 then 
		return LFDQueueFrameRoleButtonTank.checkButton:GetChecked() or LFDQueueFrameRoleButtonHealer.checkButton:GetChecked() or LFDQueueFrameRoleButtonDPS.checkButton:GetChecked()
	elseif pveGroup == 2 then
		return RaidFinderQueueFrameRoleButtonTank.checkButton:GetChecked() or RaidFinderQueueFrameRoleButtonHealer.checkButton:GetChecked() or RaidFinderQueueFrameRoleButtonDPS.checkButton:GetChecked()
	elseif pvpGroup == 2 then
		return HonorFrameRoleButtonTank.checkButton:GetChecked() or HonorFrameRoleButtonHealer.checkButton:GetChecked() or HonorFrameRoleButtonDPS.checkButton:GetChecked()
	elseif pvpGroup == 2 then
		return ConquestFrameRoleButtonTank.checkButton:GetChecked() or ConquestFrameRoleButtonHealer.checkButton:GetChecked() or ConquestFrameRoleButtonDPS.checkButton:GetChecked()
	end
	return nil
end

function module:Forward()
	if tab == 1 and pveGroup < 3 then
		if action < 2 then
			action = action + 1
			self:updatePriorityKeybinds()
			local frame = self.secureButtons.bindingDoActionButton()
			if frame then	
				return action == 1 and UIDropDownMenu_GetText(frame:GetParent()) or action == 2 and frame:GetText(), action == 2 and not hasRole() and (INSTANCE_UNAVAILABLE_SELF_NO_SPEC .. ". " .. L["PRESS_HOTKEYS"]:format(module:getOption("bindingActionsButton")))
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
				return action == 1 and UIDropDownMenu_GetText(frame:GetParent()) or action == 2 and frame:GetText(), action == 2 and not hasRole() and INSTANCE_UNAVAILABLE_SELF_NO_SPEC
			end
		end
	else
		return ERR_USE_LOCKED_WITH_ITEM_S:format(MOUSE_LABEL)
	end
end

function module:Actions()
	return TANK, HEALER, DAMAGER
end

function module:DoAction(index)
	local roleButton =
		index == 1 and (pveGroup == 1 and LFDQueueFrameRoleButtonTank.checkButton or pveGroup == 2 and RaidFinderQueueFrameRoleButtonTank.checkButton or pvpGroup == 1 and HonorFrame.TankIcon.checkButton or pvpGroup == 2 and ConquestFrame.TankIcon.checkButton)
		or index == 2 and (pveGroup == 1 and LFDQueueFrameRoleButtonHealer.checkButton or pveGroup == 2 and RaidFinderQueueFrameRoleButtonHealer.checkButton or pvpGroup == 1 and HonorFrame.HealerIcon.checkButton or pvpGroup == 2 and ConquestFrame.HealerIcon.checkButton)
		or index == 3 and (pveGroup == 1 and LFDQueueFrameRoleButtonDPS.checkButton or pveGroup == 2 and RaidFinderQueueFrameRoleButtonDPS.checkButton or pvpGroup == 1 and HonorFrame.DPSIcon.checkButton or pvpGroup == 2 and ConquestFrame.DPSIcon.checkButton)
	if roleButton then
		if roleButton:IsVisible() and roleButton:IsEnabled() then
			roleButton:Click()
			local role = (index == 1 and TANK or index == 2 and HEALER or DAMAGER)
			return roleButton:GetChecked() and QUEUED_FOR:format(role) or (role .. " unchecked")
		else
			return YOUR_CLASS_MAY_NOT_PERFORM_ROLE
		end
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

module:registerTutorial(
	function()
		if tonumber(GetStatistic(932) or 0) + tonumber(GetStatistic(933) or 0) + tonumber(GetStatistic(934) or 0) + tonumber(GetStatistic(838) or 0) > 5 then
			return nil
		else
			return PVEFrame:IsShown()
		end
	end,
	{
		function(__, played) 
			if played then
				return nil
			elseif pveGroup == 1 or pveGroup == 2 then
				local canTank, canHeal, canDPS = C_LFGList.GetAvailableRoles()
				if (canTank and canHeal or canTank and canDPS or canHeal and canDPS) then
					return L["PRESS_TO"]:format(module:getOption("bindingActionsButton"), CHOOSE .. " " .. CLASS_ROLES) .. "; " .. AND .. L["PRESS_TO"]:format(module:getOption("bindingForwardButton") .. CHOOSE .. " " .. INSTANCE)
				else
					return L["PRESS_TO"]:format(module:getOption("bindingForwardButton"), CHOOSE .. " " .. INSTANCE)
				end
			elseif pvpGroup == 1 or pvpGroup == 2 then
				local canTank, canHeal, canDPS = C_LFGList.GetAvailableRoles()
				if (canTank and canHeal or canTank and canDPS or canHeal and canDPS) then
					return L["PRESS_TO"]:format(module:getOption("bindingActionsButton"), CHOOSE .. " " .. CLASS_ROLES)
				else
					return false
				end			
			else
				return false
			end
		end,
	}
)