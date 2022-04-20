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

	local entry, entries = 0, 0

	local module =
	{
		name = "Dialog",
		title = ENABLE_DIALOG,
		frame = CreateFrame("Frame", nil, GossipFrame)
	}

	KeyboardUI:RegisterModule(module)

	function module:NextEntry()
		if entry < entries then
			entry = entry + 1
			return GossipFrame.buttons[entry]:GetText()
		end
	end

	function module:PrevEntry()
		if entry > 0 then
			entry = entry - 1
			return GossipFrame.buttons[entry]:GetText()
		end
	end

	function module:RefreshEntry()
		return true
	end

	function module:GetEntryLongDescription()
		return GossipGreetingText:GetText(), entry > 0 and entry .. ". " .. GossipFrame.buttons[entry]:GetText()
	end

	function module:Actions()
		return
			entries >= 1 and GossipFrame.buttons[1]:GetText() or nil,
			entries >= 2 and GossipFrame.buttons[2]:GetText() or nil,
			entries >= 3 and GossipFrame.buttons[3]:GetText() or nil,
			entries >= 4 and GossipFrame.buttons[4]:GetText() or nil,
			entries >= 5 and GossipFrame.buttons[5]:GetText() or nil,
			entries >= 6 and GossipFrame.buttons[6]:GetText() or nil,
			entries >= 7 and GossipFrame.buttons[7]:GetText() or nil,
			entries >= 8 and GossipFrame.buttons[8]:GetText() or nil,
			entries >= 9 and GossipFrame.buttons[9]:GetText() or nil,
			entries >= 10 and GossipFrame.buttons[10]:GetText() or nil,
			entries >= 11 and GossipFrame.buttons[11]:GetText() or nil,
			entries >= 12 and GossipFrame.buttons[12]:GetText() or nil
	end

	function module:DoAction(index)
		if index and index > 0 and index <= entries then
			GossipFrame.buttons[index]:Click()
		elseif entry > 0 then
			GossipFrame.buttons[entry]:Click()
		end
	end

	hooksecurefunc("GossipFrameUpdate", function()
		entries = GossipFrame.buttons and #GossipFrame.buttons or 0
		entry = 0
		C_Timer.After(0.2, function()
			if not TalkingHeadFrame:IsVisible() then
				module:ttsInterrupt("<speak><silence msec=\"1800\" />" .. GossipGreetingText:GetText():gsub("[\<\>]", " -- ") .. "</speak>")
			end
		end)
	end)

end

do

	local entry = 0
	local buttons = {QuestFrameAcceptButton, QuestFrameDeclineButton, QuestFrameCompleteButton, QuestFrameGoodbyeButton, QuestFrameCompleteQuestButton}

	local module =
	{
		name = "QuestFrame",
		title = LOOT_JOURNAL_LEGENDARIES_SOURCE_QUEST,
		frames =
		{
			CreateFrame("Frame", nil, QuestFrameDetailPanel),
			CreateFrame("Frame", nil, QuestFrameProgressPanel),
			CreateFrame("Frame", nil, QuestFrameRewardPanel),
		}
	}

	KeyboardUI:RegisterModule(module)

	function module:GainFocus()
		entry = 0
		C_Timer.After(0.2, function()
			local title, content, criteria = self:GetEntryLongDescription()
			if title and title ~= "" and not TalkingHeadFrame:IsVisible() then
				module:ttsInterrupt("<speak><silence msec=\"1800\" />" .. title:gsub("[\<\>]", " -- ") .. "</speak>", KUI_QUICK, KUI_MF)
				module:ttsQueue(content, KUI_CASUAL, KUI_MP)
				module:ttsQueue(criteria, KUI_NORMAL, KUI_MF)		
			end
		end)
	end

	function module:NextEntry()
		 entry = module:findNextInTable(buttons, entry, function(btn) return btn:IsVisible() and btn:IsEnabled() end) or 0
		 return entry > 0 and buttons[entry]:GetText()
	end

	function module:PrevEntry()
		entry = module:findPrevInTable(buttons, entry, function(btn) return btn:IsVisible() and btn:IsEnabled() end) or 0
		return entry > 0 and buttons[entry]:GetText()
	end

	function module:RefreshEntry()
		if entry > 0 and not (buttons[entry]:IsVisible() and buttons[entry]:IsEnabled()) then
			entry = module:findNextInTable(buttons, 0, function(btn) return btn:IsVisible() and btn:IsEnabled() end) or 0
		end
		return true
	end

	function module:GetEntryLongDescription()
		local title = 
			QuestInfoTitleHeader:IsVisible() and QuestInfoTitleHeader:GetText()
			or QuestProgressTitleText:IsVisible() and QuestProgressTitleText:GetText()
		
		local content = 
			QuestInfoDescriptionText:IsVisible() and QuestInfoDescriptionText:GetText()
			or QuestProgressText:IsVisible() and QuestProgressText:GetText()
			or QuestInfoRewardText:IsVisible() and QuestInfoRewardText:GetText()
		
		local criteria =
			QuestInfoObjectivesText:IsVisible() and QuestInfoObjectivesText:GetText()
			or ""
		
		for i = 1, GetNumQuestItems() do
			criteria = criteria .. " " .. SPELL_FAILED_NEED_MORE_ITEMS:format(tonumber(_G["QuestProgressItem"..i.."Count"]:GetText()) or 1, _G["QuestProgressItem"..i.."Name"]:GetText())
		end
		
		return title, content, criteria
	end

	function module:Actions()
		return nil
	end

	function module:DoAction(index)
		if entry > 0 then
			buttons[entry]:Click()
		end
	end

end