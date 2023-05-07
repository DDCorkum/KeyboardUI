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

local quests = {}
local group, entry, questID, action = 0, 0, 0, 0

local module =
{
	name = "QuestLog",
	title = QUEST_LOG,
	frame = CreateFrame("Frame", nil, QuestMapFrame)
}

KeyboardUI:RegisterModule(module)

local highlightTexture = module.frame:CreateTexture("BACKGROUND", nil)
highlightTexture:SetColorTexture(unpack(KUI_HIGHLIGHT_COLOR))

local function moveHighlight(region)
	highlightTexture:SetParent(region:IsObjectType("Frame") and region or region:GetParent())
	highlightTexture:SetPoint("TOPLEFT", region)
	highlightTexture:SetPoint("BOTTOMRIGHT", region)
	highlightTexture:Show()
	if QuestScrollFrame.ScrollBar.OnStepperMouseDown then
		if highlightTexture:GetTop() and highlightTexture:GetBottom() then
			local function goBack()
				if highlightTexture:GetTop() > QuestScrollFrame:GetTop() then
					QuestScrollFrame.ScrollBar:ScrollInDirection(0.05,-1)
					C_Timer.After(0.01, goBack)
				end
			end
			goBack()
			local function goForward()
				if highlightTexture:GetBottom() < QuestScrollFrame:GetBottom() then
					QuestScrollFrame.ScrollBar:ScrollInDirection(0.05,1)
					C_Timer.After(0.01, goForward)
				end
			end
			goForward()
		else
			print("huh?")
		end
	--[[
		while top > QuestScrollFrame:GetTop() do
			QuestScrollFrame.ScrollBar.Back:Click()
		end
		while highlightTexture:GetBottom() < QuestScrollFrame:GetBottom() do
			QuestScrollFrame.ScrollBar.Forward:Click()
		end
		--]]
		--[[if QuestScrollFrame.ScrollBar.SetScrollPercentage then
			local contentsTop, contentsHeight = QuestScrollFrame.Contents:GetTop(), QuestScrollFrame.Contents:GetHeight()
			local scrollPercent = (contentsTop - top)/contentsHeight*100
			if top > QuestScrollFrame:GetTop() and
			QuestScrollFrame.ScrollBar:SetScrollPercentage(scrollPercent)
		else--]]


	else
		local top = highlightTexture:GetTop() or 0
		if top > QuestScrollFrame:GetTop() or highlightTexture:GetBottom() < QuestScrollFrame:GetBottom() then
			ScrollFrame_SetScrollOffset(QuestScrollFrame, QuestScrollFrame.Contents:GetTop() - top)
		end
	end
end

local function clearHighlight()
	highlightTexture:ClearAllPoints()
	highlightTexture:Hide()
end

local function highlightGroup()
	for frame in QuestMapFrame.QuestsFrame.headerFramePool:EnumerateActive() do
		if frame.questLogIndex == group then
			moveHighlight(frame.ButtonText or frame)
			return
		end
	end
	for frame in QuestMapFrame.QuestsFrame.campaignHeaderFramePool:EnumerateActive() do
		if frame.questLogIndex == group then
			moveHighlight(frame.Text or frame)
			return
		end
	end
	for frame in QuestMapFrame.QuestsFrame.campaignHeaderMinimalFramePool:EnumerateActive() do
		if frame.questLogIndex == group then
			moveHighlight(frame.Text or frame)
			return
		end
	end
	clearHighlight()
end

local function highlightEntryFunc()
	for frame in QuestMapFrame.QuestsFrame.titleFramePool:EnumerateActive() do
		if frame.questLogIndex == entry then
			moveHighlight(frame)
			return
		end
	end
end

local function highlightEntry()
	clearHighlight()
	C_Timer.After(0, highlightEntryFunc)
end

local function highlightAction()
	if action == 1 then
		moveHighlight(QuestMapFrame.DetailsFrame.TrackButton)
	elseif action == 2 then
		moveHighlight(QuestMapFrame.DetailsFrame.ShareButton)
	elseif action == 3 then
		moveHighlight(QuestMapFrame.DetailsFrame.AbandonButton)
	else
		clearHighlight()
	end
end

function module:NextGroup()
	if QuestMapFrame.DetailsFrame:IsShown() then
		QuestMapFrame.DetailsFrame.BackButton:Click()
		action = 0
	end
	for i=entry+1, #quests-1 do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end
	for i=1, entry do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end
	clearHighlight()
	group, entry, questID, action = 0, 0, 0, 0
	return
end

function module:PrevGroup()
	if QuestMapFrame.DetailsFrame:IsShown() then
		QuestMapFrame.DetailsFrame.BackButton:Click()
		action = 0
	end
	for i=entry-1, 1, -1 do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end
	for i=#quests-1, entry, -1 do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end
	group, entry, questID, action = 0, 0, 0, 0
	clearHighlight()
	return
end

function module:NextEntry()
	if QuestMapFrame.DetailsFrame:IsShown() then
		QuestMapFrame.DetailsFrame.BackButton:Click()
		action = 0
	end
	if #quests == 0 then
		group, entry, questID, action = 0, 0, 0, 0
		return "The quest log is empty"
	end
	for i=entry+1, #quests do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		elseif not (quests[i].isBounty or quests[i].isHidden) then
			ExpandQuestHeader(group)
			entry, questID, action = i, quests[i].questID, 0
			highlightEntry()
			return quests[entry].title
		end
	end
	for i=1, entry do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID, action = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end

end

function module:PrevEntry()
	if QuestMapFrame.DetailsFrame:IsShown() then
		QuestMapFrame.DetailsFrame.BackButton:Click()
		action = 0
	end
	if #quests == 0 then
		group, entry, questID, action = 0, 0, 0, 0
		return "The quest log is empty"
	end
	for i=entry-1, 1, -1 do
		if quests[i].isHeader then
			for j=i+1, #quests do
				if quests[j].isHeader then
					break
				elseif not (quests[j].isBounty or quests[j].isHidden) then
					group, entry, questID = i, i, 0, 0
					highlightGroup()
					return quests[entry].title
				end
			end
		elseif not (quests[i].isBounty or quests[i].isHidden) then
			for j=i-1, 1, -1 do
				if quests[j].isHeader then
					group, entry, questID, action = j, i, quests[i].questID, 0
					ExpandQuestHeader(group)
					highlightEntry()
					return quests[entry].title					
				end
			end
		end
	end
	for i=#quests, entry+1, -1 do
		if not (quests[i].isBounty or quests[i].isHidden or quests[i].isHeader) then
			for j=i-1, 1, -1 do
				if quests[j].isHeader then
					group, entry, questID, action = j, i, 0, 0
					ExpandQuestHeader(group)
					highlightGroup()
					return quests[entry].title
				end
			end
		end
	end
end

function module:Forward()
	if questID > 0 then
		if QuestMapFrame.QuestsFrame:IsShown() then
			QuestMapFrame_ShowQuestDetails(questID)
			action = 0
			return module:GetLongDescription()
		end
		for i=1, 3 do
			if (action+i)%3 == 1 then
				action = 1
				highlightAction()
				return QuestMapFrame.DetailsFrame.TrackButton:GetText()
			elseif (action+i)%3 == 2 and C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
				action = 2
				highlightAction()
				return "Share"
			elseif (action+i)%3 == 0 and C_QuestLog.CanAbandonQuest(questID) then
				action = 3
				highlightAction()
				return "Abandon"
			end
		end
	else
		ExpandQuestHeader(entry)
	end
end

function module:Backward()
	if questID > 0 then
		if QuestMapFrame.QuestsFrame:IsShown() then
			QuestMapFrame_ShowQuestDetails(questID)
			return module:GetLongDescription()
		end	
		action = action + 3		--resolves an edge case
		for i=2, 0, -1 do
			if (action+i)%3 == 1 then
				action = 1
				highlightAction()
				return QuestMapFrame.DetailsFrame.TrackButton:GetText()
			elseif (action+i)%3 == 2 and C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
				action = 2
				highlightAction()
				return "Share"
			elseif (action+i)%3 == 0 and C_QuestLog.CanAbandonQuest(questID) then
				action = 3
				highlightAction()
				return "Abandon"
			end
		end
	else
		CollapseQuestHeader(entry)
	end
end

function module:Actions()
	local title1, title2, title3
	if questID > 0 then
		title1 = QuestMapFrame.DetailsFrame.TrackButton:GetText()
		if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
			title2 = "Share"
		end
		if C_QuestLog.CanAbandonQuest(questID) then
			title3 = "Abandon"
		end
		return title1, title2, title3
	end
end

function module:DoAction(hotkey)
	if questID > 0 then
		if (hotkey or action) == 1 then
			QuestMapQuestOptions_TrackQuest(questID)
		elseif (hotkey or action) == 2 and C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
			QuestMapQuestOptions_ShareQuest(questID)
		elseif (hotkey or action) == 3 and C_QuestLog.CanAbandonQuest(questID) then
			QuestMapQuestOptions_AbandonQuest(questID)
		elseif QuestMapFrame.QuestsFrame:IsShown() then
			QuestMapFrame_ShowQuestDetails(questID)
			clearHighlight()
			return module:GetLongDescription()
		end
		clearHighlight()
	end
end

function module:GetLongDescription()
	if entry == 0 then
		return "None selected", #quests == 0 and "The quest log is empty"
	elseif questID > 0 then
		return quests[entry].title, quests[entry].description, quests[entry].objectives
	else
		return quests[entry].title, "This is a header"
	end
end

QuestMapFrame.QuestsFrame:HookScript("OnHide", function()
	if quests[entry] then
		if action == 0 then
			if entry == group then
				highlightGroup()
			else
				highlightEntry()
			end
		end
	else
		entry = 0
		clearHighlight()
	end
end)

QuestMapFrame.DetailsFrame:HookScript("OnShow", function()
	if QuestMapFrame.DetailsFrame.questID ~= questID then
		for i=1, #quests do
			if quests[i].questID == QuestMapFrame.DetailsFrame.questID then
				for j = i-1, 1, -1 do
					if quests[j].isHeader then
						group, entry, action, questID = j, i, 0, QuestMapFrame.DetailsFrame.questID
						return
					end
				end
			end
		end
	end
end)

-- flip these buttons around so that 'tracking' is reached sooner than 'abandon' when going through the list left to right
QuestMapFrame.DetailsFrame.TrackButton:ClearAllPoints()
QuestMapFrame.DetailsFrame.ShareButton:ClearAllPoints()
QuestMapFrame.DetailsFrame.AbandonButton:ClearAllPoints()
QuestMapFrame.DetailsFrame.TrackButton:SetPoint("BOTTOMLEFT", QuestMapFrame, "BOTTOMLEFT", -3, 0)
QuestMapFrame.DetailsFrame.ShareButton:SetPoint("LEFT", QuestMapFrame.DetailsFrame.TrackButton, "RIGHT")
QuestMapFrame.DetailsFrame.AbandonButton:SetPoint("LEFT", QuestMapFrame.DetailsFrame.ShareButton, "RIGHT")

module.frame:RegisterEvent("QUEST_LOG_UPDATE")
module.frame:SetScript("OnEvent", function(__, event)
	if event == "QUEST_LOG_UPDATE" and not QuestMapFrame.ignoreQuestLogUpdate then
		local questName = quests[module.position] and quests[module.position].title
		for i=1, C_QuestLog.GetNumQuestLogEntries() do
			quests[i] = C_QuestLog.GetInfo(i)
			if quests[i].questID > 0 then
				local desc, obj = GetQuestLogQuestText(i)
				quests[i].description, quests[i].objectives = desc and desc:gsub("[\<\>]", " "), obj and obj:gsub("[\<\>]", " ")
			else
				quests[i].title = "Header - " .. quests[i].title
			end
		end
		for i = C_QuestLog.GetNumQuestLogEntries() + 1, #quests do
			quests[i] = nil
		end
		if questName and questName ~= quests[module.position].title then
			for i, quest in ipairs(quests) do
				if questName == quest.title then
					module:SetPosition(i)
					module:Title()
					return
				end
			end
			module:SetPosition(1)
		end
	end
end)