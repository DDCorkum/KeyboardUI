--[[

## Title: KeyboardUI
## Notes: Keyboard user interface with text to speech
## Author: Dahk Celes (DDCorkum), in partnership with RogueEugor (A. Agostino)
## X-License: All Rights Reserved

This addon is made in partnership with WoWAccess by RogueEugor (A. Agostino).  The two addons may function alongside each other.
Please note that WoWAccess and KeyboardUI have different licenses.

Permission is granted to redistribute without modification outside the traditional WoW ecosystem in locations aimed principally at persons with blindness or low vision.
This redistribution may include packaging (eg, zip file) with other addons (eg, WoWAccess) and technologies (eg, golden cursor files) for persons with blindness or low vision.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

### 10.08 (2023-05-07) by Dahk Celes
- Quest log fixes and updates for 10.1.0
- Proper item levels for equipped items
- Dungeon ready popup

### 10.07 (2023-03-28) by Dahk Celes
- Mouseover tooltip text on more frames
- Queue for normal and heroic dungeons, and looking for raid
- Migrating ALT-V hotkey from WoWAccess to stop speaking text
- New ALT-T hotkey to simulate right-clicking the target frame portrait

### 10.06 (2023-02-04) by Dahk Celes
- Follows game TTS voice settings
- Adds mailboxes

### 10.05 (2023-01-22) by Dahk Celes
- Choose quest item rewards

### 10.04 (2023-01-08) by Dahk Celes
- Buy, sell and buyback at merchants

### 10.03 (2022-12-27) by Dahk Celes
- Updated the spellbook and bags for Dragonflight

### 10.02 (2022-11-20) by Dahk Celes
- Minor bugfixes

### 10.01 (2022-11-15) by Dahk Celes
- Updates for Dragonflight
- Avoids forbidden frames

### 0.10 (2022-05-03) by Dahk Celes
- Adding NPC gossip and quest frames
- Adding player talents in retail
- Spell book bugfixes

### 0.9 (2022-03-04) by Dahk Celes
- Rudimentary keyboard navigation for the backpack and bags
- Rudimentary support for the retail new player experience
- Use spells directly from the spell book

### 0.8 (2022-02-07) by Dahk Celes
- Extended keyboard navigation to the system options
- Various bug fixes including the quest log and closing windows

### 0.7 (2022-02-04) by Dahk Celes
- More TTS when hovering over the game world and UI
- More control over TTS volume and rate
- New modules: game menu and interface options

### 0.6 (2022-01-27) by Dahk Celes
- Spell book and action bar improvements
- Soft-spoken TTS when hovering over UI elements

### 0.5 (2022-01-23) by Dahk Celes
- New module: spell book and action bars
- Attempts to use /tts preferred voice setting
- Better text recognition for special popups like logging out

### 0.4 (2022-01-15) by Dahk Celes
- Secure keybinds outside combat.
- New module: drop down menus

### 0.3 (2022-01-13) by Dahk Celes
- Small tweaks and bug fixes
- First version to be publicly visible

### 0.2 (2022-01-12) by Dahk Celes
- Rewrote the core addon using lessons learned from the proof of concept

### 0.1 (2022-01-03) by Dahk Celes
- Initial alpha version / proof of concept

--]]

KeyboardUI = {}
local KeyboardUI = select(2, ...)
local L = KeyboardUI.text or {}	-- see localization.lua
--setmetatable(_G["KeyboardUI"], {__index=KeyboardUI})		-- Uncommenting out this line would expose the internal API for other AddOns to integrate with KeyboardUI.
															-- I havn't yet decided yet to do this, but I am designing KeyboardUI with this future possibility in mind.
-------------------------
-- Constants

-- Multiplied with volumeVariance, which ranges between 0 and 50
KUI_FF =  0.000
KUI_F  = -0.001
KUI_MF = -0.002 -- default
KUI_MP = -0.003
KUI_P  = -0.005
KUI_PP = -0.010

-- Multiplied with speedVariance, which ranges between 0 and 4
KUI_SLOW	= -1.00
KUI_CASUAL 	= -0.75
KUI_NORMAL 	= -0.50	-- default
KUI_QUICK 	= -0.25
KUI_RAPID 	=  0.00

KUI_HIGHLIGHT_COLOR = {1, 1, 0, 0.2}

local TEXT_TO_SPEECH = TEXT_TO_SPEECH or "Text to speech"	-- Classic compatibility for 1.14.1 (not fixed) and 2.5.2 (fixed in 2.5.3)

local KUI_VOICE					-- defined at PLAYER_LOGIN

KeyboardUI.tooltips = true		-- temporary flag to inform WoWAccess that this version of Keyboard UI has more tooltips installed.

-------------------------
-- Configuration

-- modules cannot change these settings with setOption()
local globalDefaults =
{
	-- Text to speech
	volumeMax = 100,							-- Volume of a KUI_FF message, out of 100
	volumeVariance = 50,						-- How much quieter is a KUI_PP message relative to KUI_FF, out of 100
	speedMax = 5,								-- Rate of a KUI_RAPID message, between 0 and 10
	speedVariance = 2,							-- How much slower is a KUI_SLOW message, between 0 and 4
	
	-- Text to speech when mousing over elements
	onEnter = true,
	onEnterSayNPC = true,
	onEnterSayGroup = true,
	onEnterSayObject = true,
	onEnterSayUI = true,
	onEnterSayFullTooltip = true,
	onEnterPing = true,
	
	-- Default state for all modules
	enabled = true,								-- Disables a module entirely when false
	
	-- Core keybinds
	bindingChangeTabButton = "CTRL-TAB",
	bindingNextGroupButton = "CTRL-SHIFT-DOWN",
	bindingPrevGroupButton = "CTRL-SHIFT-UP",
	bindingNextEntryButton = "CTRL-DOWN",
	bindingPrevEntryButton = "CTRL-UP",
	bindingForwardButton = "CTRL-RIGHT",
	bindingBackwardButton = "CTRL-LEFT",
	bindingDoActionButton = "CTRL-ENTER",
	bindingActionsButton = "ALT-SPACE",
	bindingDoAction1Button = "ALT-1",
	bindingDoAction2Button = "ALT-2",
	bindingDoAction3Button = "ALT-3",
	bindingDoAction4Button = "ALT-4", 
	bindingDoAction5Button = "ALT-5",
	bindingDoAction6Button = "ALT-6",
	bindingDoAction7Button = "ALT-7",
	bindingDoAction8Button = "ALT-8",
	bindingDoAction9Button = "ALT-9",
	bindingDoAction10Button = "ALT-0",
	bindingDoAction11Button = "ALT--",
	bindingDoAction12Button = "ALT-=",
	bindingReadTitleButton = "CTRL-BACKSPACE",
	bindingReadDescriptionButton = "CTRL-SPACE",
	
	-- Option toggle keybinds
	bindingToggleOnEnterButton = "ALT-O",
	
	-- Additional keybinds
	enableRightClickTargetFrame = true,
	bindingRightClickTargetFrame = "ALT-T",
	enableStopSpeakingText = true,
	bindingStopSpeakingText = "ALT-V",
}

-------------------------
-- Private properties

-- Modules, which contain options and 1 or more frames
local modules = {}					-- Modules in the order they were loaded (unless overridden by optIndex)
local modulesByName = {}			-- Modules in no particular order, to simplify getting them by name

local metamodules = {}				-- Groups of modules that appear together in the options menu

-- Frames that are currently visible and associated with a module
local shownFrames = {}				-- Frames associated to a module that are currently visible, prioritized by frame strata and level

-- Options used by the modules, including the global one
KeyboardUIOptions = {}				-- SavedVariable
local defaultOptions = {}			-- Non-persistent
local tempOptions = {}				-- While the interface options are open
local optionCallbacks = {}			-- Called when an option changes in the interface options

-- Core addon
local lib = {name = "global"}		-- Functions and settings inheritable by all modules
local frame = CreateFrame("Frame")	-- General event handler and override keybind owner
local events = {}					-- The event handlers for frame, sorted by event


-------------------------
-- Keybindings

local function enableOverrideKeybinds()
	if not InCombatLockdown() then
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingChangeTabButton, "KeyboardUIChangeTabButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingNextGroupButton, "KeyboardUINextGroupButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingPrevGroupButton, "KeyboardUIPrevGroupButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingNextEntryButton, "KeyboardUINextEntryButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingPrevEntryButton, "KeyboardUIPrevEntryButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingForwardButton, "KeyboardUIForwardButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingBackwardButton, "KeyboardUIBackwardButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoActionButton, "KeyboardUIDoActionButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingActionsButton, "KeyboardUIActionsButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction1Button, "KeyboardUIDoAction1Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction2Button, "KeyboardUIDoAction2Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction3Button, "KeyboardUIDoAction3Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction4Button, "KeyboardUIDoAction4Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction5Button, "KeyboardUIDoAction5Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction6Button, "KeyboardUIDoAction6Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction7Button, "KeyboardUIDoAction7Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction8Button, "KeyboardUIDoAction8Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction9Button, "KeyboardUIDoAction9Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction10Button, "KeyboardUIDoAction10Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction11Button, "KeyboardUIDoAction11Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingDoAction12Button, "KeyboardUIDoAction12Button", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingReadTitleButton, "KeyboardUIReadTitleButton", "LeftButton")
		SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingReadDescriptionButton, "KeyboardUIReadDescriptionButton", "LeftButton")
	end
end

local function disableOverrideKeybinds()
	if not InCombatLockdown() then
		ClearOverrideBindings(frame)
	end
end

function lib:updatePriorityKeybinds()
	if self:hasFocus() and not InCombatLockdown() then
		ClearOverrideBindings(self.frame)
		if self.secureButtons then
			for option, button in pairs(self.secureButtons) do
				option = self:getOption(option)
				if type(button) == "function" then
					button = button()
				end
				if type(button) == "table" then
					button = button:GetName()
				end
				if option and button then
					SetOverrideBindingClick(self.frame, true, option, button)
				end
			end
		end
		if self.secureCommands then
			for option, command in pairs(self.secureCommands) do
				option = self:getOption(option)
				if type(command) == "function" then			
					command = command()
				end
				if option and command then
					SetOverrideBinding(self.frame, true, option, command)
				end
			end
		end
	end
end

function lib:removePriorityKeybinds()
	if not InCombatLockdown() then
		ClearOverrideBindings(self.frame)
	end
end

local stratas = {
	WORLD = 0,
	BACKGROUND = 10000,
	LOW = 20000,
	MEDIUM = 30000,
	HIGH = 40000,
	DIALOG = 50000,
	FULLSCREEN = 60000,
	FULLSCREEN_DIALOG = 70000,
	TOOLTIP = 80000,
}

local function setFocus(module)
	module:GainFocus()
	module:updatePriorityKeybinds()
	module:ttsYield(module.title or module.name, KUI_QUICK, KUI_MF)
end

local function clearFocus(module)
	module:LoseFocus()
	lib.removePriorityKeybinds(module)
end

local function frameOnShow(frame)
	frame.priority = frame.priority or stratas[frame:GetFrameStrata()] + frame:GetFrameLevel()
	if #shownFrames == 0 then
		shownFrames[1] = frame
		if not InCombatLockdown() then
			enableOverrideKeybinds()
			setFocus(frame.module)
		end
	elseif frame.priority > shownFrames[#shownFrames].priority then
		if InCombatLockdown() then
			shownFrames[#shownFrames+1] = frame
		else
			clearFocus(shownFrames[#shownFrames].module)
			shownFrames[#shownFrames+1] = frame
			setFocus(frame.module)
		end
	else
		local i = 1
		while shownFrames[i] and shownFrames[i].priority < frame.priority do
			i = i + 1
		end
		tinsert(shownFrames, i, frame)
	end
end

local function frameOnHide(frame)
	if shownFrames[#shownFrames] == frame then
		clearFocus(frame.module)
		shownFrames[#shownFrames] = nil
	else
		for i=#shownFrames, 1, -1 do
			if shownFrames[i] == frame then
				tremove(shownFrames, i)
				break
			end
		end
	end
	if #shownFrames > 0 then
		setFocus(shownFrames[#shownFrames].module)
	else
		disableOverrideKeybinds()
	end
end

local function updateFrameStrataAndLevel(frame)
	frame.priority = nil
	if frame:IsVisible() then
		frame:Hide()
		frame:Show()
	end
end

-- module.name		string
-- module.title 	string		defaults to module.name
-- module.frame		Frame
-- module.frames	Frame[]		substitute for module.frame

function KeyboardUI:RegisterModule(module, optIndex)
	assert(type(module.name) == "string" and (module.frame and module.frame:IsObjectType("Frame") or module.frames) and not modules[module.name], "Invalid module registration")
	if optIndex then
		tinsert(modules, optIndex, module)
		module.id = optIndex
		for i=optIndex+1, #modules do
			modules[i].id = i
		end
	else
		tinsert(modules, module)
		module.id = #modules
	end
	modulesByName[module.name] = module
	
	setmetatable(module, {__index = lib})
	
	if module.frames then
		for __, frame in pairs(module.frames) do
			module.frame = module.frame or frame
			frame.module = module
			frame:HookScript("OnShow", frameOnShow)
			frame:HookScript("OnHide", frameOnHide)
			hooksecurefunc(frame, "SetFrameStrata", updateFrameStrataAndLevel)
			hooksecurefunc(frame, "SetFrameLevel", updateFrameStrataAndLevel)
		end
	else
		module.frame.module = module
		module.frame:HookScript("OnShow", frameOnShow)
		module.frame:HookScript("OnHide", frameOnHide)
		hooksecurefunc(module.frame, "SetFrameStrata", updateFrameStrataAndLevel)
		hooksecurefunc(module.frame, "SetFrameLevel", updateFrameStrataAndLevel)
	end
end

function lib:hasFocus(frame)
	return #shownFrames > 0 and shownFrames[#shownFrames].module == self and not InCombatLockdown()
end

-------------------------
-- General event handling

function lib:onEvent(event, func)
	if events[event] then
		events[event][func] = true
	else
		frame:RegisterEvent(event)
		events[event] = {}
		events[event][func] = true
	end
end

frame:SetScript("OnEvent", function(__, event, ...)
	if events[event] then
		for func in pairs(events[event]) do
			func(...)
		end
	end
end)

-------------------------
-- Options, including saved variables

function lib:onOptionChanged(option, func, optArg)
	optionCallbacks[self.name] = optionCallbacks[self.name] or {}
	optionCallbacks[self.name][option] = optionCallbacks[self.name][option] or {}
	optionCallbacks[self.name][option][func] = optArg == nil and "nil" or optArg
end

function lib:triggerOptionCallbacks(option, value)
	if optionCallbacks[self.name] and optionCallbacks[self.name][option] then
		for func, optArg in pairs(optionCallbacks[self.name][option]) do
			local retOK, msg = pcall(func, value, optArg ~= "nil" and optArg or nil)
			if not retOK and msg then
				print("Keyboard UI: Error in " .. self.name .. " in callback after " .. option .. " changed.")
				optionCallbacks[self.name][option][func] = nil
			end
		end
	end
end

local function configureOptions(name)
	KeyboardUIOptions[name] = KeyboardUIOptions[name] or {}
	defaultOptions[name] = defaultOptions[name] or {}
	tempOptions[name] = tempOptions[name] or {}
	if name == "global" then
		-- the global options default to configuration settings at the top of this file
		setmetatable(tempOptions.global, {__index = KeyboardUIOptions.global})
		setmetatable(KeyboardUIOptions.global, {__index = globalDefaults})
		setmetatable(defaultOptions.global, {__index = globalDefaults})
	else
		-- the options for each module have a longer default values chain that ultimately terminates with the same global configuration settings
		setmetatable(tempOptions[name], {__index = KeyboardUIOptions[name]})
		setmetatable(KeyboardUIOptions[name], {__index = defaultOptions[name]})
		setmetatable(defaultOptions[name], {__index = KeyboardUIOptions.global})
	end
end

local function configureVoices()
	local opt = C_TTSSettings.GetVoiceOptionID(0) or C_TTSSettings.GetVoiceOptionID(1)
	if opt then
		KUI_VOICE = opt
	else
		local voices = C_VoiceChat.GetTtsVoices()
		if voices and voices[1] then
			KUI_VOICE = voices[1].voiceID
		end
	end
end

lib:onEvent("ADDON_LOADED", function(arg1)
	if arg1 == "KeyboardUI" then
		configureVoices()
		options = KeyboardUIOptions
		for __, module in ipairs(modules) do	-- order matters.  The global one must be first.
			configureOptions(module.name)
			if not KeyboardUIOptions[module.name]["enabled"] then
				module.frame:Hide()
			end
			module:onOptionChanged("enabled", function(value) module.frame:SetShown(value) end)
			module:Init()
		end
		frame.numLoaded = #modules
	elseif frame.numLoaded then
		for i = frame.numLoaded + 1, #modules do
			configureOptions(modules[i].name)
			if not KeyboardUIOptions[modules[i].name]["enabled"] then
				modules[i].frame:Hide()
			end
			modules[i]:onOptionChanged("enabled", function(value) modules[i].frame:SetShown(value) end)
			modules[i]:Init()
		end
	end
end)

lib:onEvent("PLAYER_REGEN_DISABLED", function()
	if #shownFrames > 0 then
		disableOverrideKeybinds()
		clearFocus(shownFrames[#shownFrames].module)
	end
end)

lib:onEvent("PLAYER_REGEN_ENABLED", function()
	if #shownFrames > 0 then
		enableOverrideKeybinds()
		setFocus(shownFrames[#shownFrames].module)
	end
end)

function lib:setDefault(option, value)
	defaultOptions[self.name] = defaultOptions[self.name] or {}
	if type(option) == "string" and globalDefaults[option] == nil then
		defaultOptions[self.name][option] = value
	end
end

function lib:setOption(option, value)
	assert(KeyboardUIOptions[self.name], "Keyboard UI: The ".. self.name " module tried to access KUI saved variables before module:Init().")
	if type(option) == "string" and globalDefaults[option] == nil then
		KeyboardUIOptions[self.name][option] = value
		tempOptions[self.name][option] = nil
	end
end

function lib:getOption(option)
	if tempOptions[self.name] then
		return tempOptions[self.name][option]
	end
end


-------------------------
-- Modules should override these as appropriate

function lib:Init()
	-- Fires when a module is permitted to begin accessing KeyboardUI saved variables using module:setOption().
end

function lib:GainFocus()
	-- Fires when a module is now the target for keybindings.  Followed by self:updatePriorityKeybinds().
end

function lib:LoseFocus()
	-- Fires when a module is no longer the target for keybindings.  Followed by self:removePriorityKeybinds().
end

function lib:ChangeTab(...)
	-- Override to cycle entire tabs when a frame comprises distinct tabs, each with independent layouts that each contain one or more groups.  From the last tab, it should cycle to the beginning.
	-- To ensure that 'tabbing' remains mentally distinct from navigating within the current frame, this is purposefully a very different keybind that does not default to the use of arrow keys.
end

function lib:NextGroup(...)
	-- Override to navigate groups or pages, each with one or more entries, each with one or more actions.
	-- Don't override if all entries are in the same group.
	return self:NextEntry(...)
end

function lib:PrevGroup(...)
	-- Override to navigate groups or pages, each with one or more entries, each with one or more actions.
	-- Don't override if all entries are in the same group.
	return self:PrevEntry(...)
end

function lib:NextEntry(...)
	-- Override to navigate a list of entries, each with one or more actions.
	return self:Forward(...)
end

function lib:PrevEntry(...)
	-- Override to navigate a list of entries, each with one or more actions.
	return self:Backward(...)
end

function lib:GetShortTitle()
	-- OVerride to say something other than the introductory part of self:GetLongDescription()
	return (self:GetLongDescription())
end


function lib:GetLongDescription()
	-- Override with three return values, strings, that will be read as an introduction, body and conclusion.
end

function lib:Forward(...)
	-- Override to go forward to the next action, or to do the only action in the forward direction (when applicable)
	return self:DoAction() -- deliberately not passing args, to avoid misinterpretting as a hotkey
end

function lib:Backward(...)
	-- Override to go backward to the last action, or to do the only action in the reverse direction (when applicable)
	return self:Forward(...)  -- this is a bad user experience; it *should* be overridden!
end

function lib:Actions()
	-- Override with up to twelve return values; any that are a non-empty string will enable a special hotkey
	return nil
end

function lib:DoAction(index)
	return "Not yet implemented"
end

-------------------------
-- Speech

local ttsFrame = CreateFrame("Frame")
ttsFrame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
ttsFrame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
ttsFrame:RegisterEvent("PLAYER_LOGOUT")
ttsFrame:SetScript("OnEvent", function(__, event)
	if event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
		ttsFrame:Hide()
	elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
		ttsFrame.current = nil
		ttsFrame:Show()
	elseif event == "PLAYER_LOGOUT" then
		if ttsFrame.current then
			C_VoiceChat.StopSpeakingText()
		end
	end
end)

ttsFrame:SetScript("OnUpdate", function()
	ttsFrame.isBlocking = nil
	if #ttsFrame > 0 then
		local tbl = tremove(ttsFrame,1)
		ttsFrame.current = tbl[2]
		ttsFrame:Hide()
		C_VoiceChat.SpeakText(unpack(tbl))
	end
end)

-- say something when previous messages have finished
function lib:ttsQueue(text, rate, dynamics)
	local volume = self:getOption("volumeMax") * (1 + (dynamics or KUI_MF) * self:getOption("volumeVariance"))
	if KUI_VOICE and volume > 0  and text and text ~= "" and self:getOption("enabled") and not ttsFrame.isBlocking then
		text = tostring(text)
		rate = self:getOption("speedMax") + (rate or KUI_NORMAL) * self:getOption("speedVariance")
		if text:sub(1,1) == "<" and not text:sub(1,7) == "<speak>" then
			text = text:gsub("[\<\>]", " -- ")
		end
		tinsert(ttsFrame, {KUI_VOICE, text, Enum.VoiceTtsDestination.LocalPlayback, rate, volume})
	end
end

function lib:ttsYield(...)
	if #ttsFrame == 0 and ttsFrame:IsShown() and not ttsFrame.isBlocking then
		self:ttsQueue(...)
		return true
	end
end

function lib:ttsBlock()
	if not ttsFrame.isBlocking and #ttsFrame == 0 and ttsFrame:IsShown() then
		ttsFrame.isBlocking = self
		return true
	end
end

function lib:ttsUnblock()
	if ttsFrame.isBlocking == self then
		ttsFrame.isBlocking = nil
	end
end

function lib:ttsStopMessage(text)
	if text then
		if	ttsFrame.current == text then
			C_VoiceChat.StopSpeakingText()
			ttsFrame.current = nil
		elseif #ttsFrame > 0 then
			for i=#ttsFrame, 1, -1 do
				if ttsFrame[#ttsFrame][2] == text then
					tremove(ttsFrame, i)
				end
			end
		end
	end
end

-- halt any ongoing messages
function lib:ttsStop()
	for i=1, #ttsFrame do
		ttsFrame[i] = nil
	end
	C_VoiceChat.StopSpeakingText()
end

-- say something immediately, cutting off earlier messages
function lib:ttsInterrupt(msg, ...)
	if msg and msg ~= "" then
		self:ttsStop()
		self:ttsQueue(msg, ...)
	end
end

-- say three things in a row, using a body/intro/conclusion pattern
function lib:ttsExplain(intro, body, conclusion)
	if intro and intro ~= "" then
		self:ttsStop()
		self:ttsQueue(intro, KUI_QUICK, KUI_MF)
		self:ttsQueue(body, KUI_CASUAL, KUI_MP)
		self:ttsQueue(conclusion, KUI_NORMAL, KUI_MF)
	end
end

local function hideTooltip()
	GameTooltip:Hide()
end

function lib:displayTooltip(frame, title, optLine2, optAnchor, optOwner)
	if title then
		if not frame.kuiOnLeaveHooked then
			frame:HookScript("OnLeave", hideTooltip)
		end
		GameTooltip:SetOwner(optOwner or frame, optAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if optLine2 then
			GameTooltip:AddLine(optLine2, 0.9, 0.9, 0.9)
			title = title .. ": " .. optLine2
			GameTooltip:Show()
		end
	end
end

-------------------------
-- Keybindings continued

local insecureButtons = {}

local function getCurrentModule()
	return shownFrames[#shownFrames] and shownFrames[#shownFrames].module
end

insecureButtons.ChangeTab = CreateFrame("Button", "KeyboardUIChangeTabButton")
insecureButtons.ChangeTab:SetScript("OnClick", function(__, button, down)
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:ChangeTab())
	end
end)

insecureButtons.NextGroup = CreateFrame("Button", "KeyboardUINextGroupButton")
insecureButtons.NextGroup:SetScript("OnClick", function(__, button, down)
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:NextGroup())
	end
end)

insecureButtons.PrevGroup = CreateFrame("Button", "KeyboardUIPrevGroupButton")
insecureButtons.PrevGroup:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:PrevGroup())
	end
end)

insecureButtons.NextEntry = CreateFrame("Button", "KeyboardUINextEntryButton")
insecureButtons.NextEntry:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:NextEntry())
	end
end)

insecureButtons.PrevEntry = CreateFrame("Button", "KeyboardUIPrevEntryButton")
insecureButtons.PrevEntry:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:PrevEntry())
	end
end)

insecureButtons.Forward = CreateFrame("Button", "KeyboardUIForwardButton")
insecureButtons.Forward:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		lib:ttsExplain(module:Forward())
	end
end)

insecureButtons.Backward = CreateFrame("Button", "KeyboardUIBackwardButton")
insecureButtons.Backward:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		lib:ttsExplain(module:Backward())
	end
end)

insecureButtons.DoAction = CreateFrame("Button", "KeyboardUIDoActionButton")
insecureButtons.DoAction:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:DoAction())
	end
end)

for i=1, 12 do
	local shortName = "DoAction"..i
	insecureButtons[shortName] = CreateFrame("Button", "KeyboardUI"..shortName.."Button")
	insecureButtons[shortName]:SetScript("OnClick", function()
		local module = getCurrentModule()
		if module then
			local action = select(i, module:Actions())
			if type(action) == "string" and action ~= "" then
				module:ttsExplain(module:DoAction(i))
			end
		end
	end)
end

insecureButtons.Actions = CreateFrame("Button", "KeyboardUIActionsButton")
insecureButtons.Actions:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsStop()
		local actions = {module:Actions()}
		for i=1, 12 do
			if type(actions[i]) == "string" and actions[i] ~= "" then
				local keybind = module:getOption("bindingDoAction"..i.."Button")
				if keybind then
					if keybind:sub(-2, -1) == "--" then
						keybind = keybind:sub(1, -3) .. "-dash"
					elseif keybind:sub(-2, -1) == "-=" then
						keybind = keybind:sub(1, -3) .. "-equals"
					end
					module:ttsQueue(keybind .. actions[i])
				end
			end 
		end
	end
end)

insecureButtons.ReadTitle = CreateFrame("Button", "KeyboardUIReadTitleButton")
insecureButtons.ReadTitle:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:GetShortTitle(), KUI_NORMAL, KUI_MF)
	end
end)

insecureButtons.ReadDescription = CreateFrame("Button", "KeyboardUIReadDescriptionButton")
insecureButtons.ReadDescription:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsExplain(module:GetLongDescription())
	end
end)

local function createToggleKeybind(option, bindingOption, buttonName)
	local button = CreateFrame("Button", buttonName)
	if KeyboardUIOptions.global[bindingOption] then
		SetOverrideBindingClick(button, false, KeyboardUIOptions.global[bindingOption], buttonName)
	end
	lib:onOptionChanged(bindingOption, function(value)
		ClearOverrideBindings(button)
		if value then
			SetOverrideBindingClick(button, false, value, buttonName)
		end
	end)	
	button:SetScript("OnClick", function()
		local value = not KeyboardUIOptions.global[option]
		KeyboardUIOptions.global[option] = value
		tempOptions.global[option] = nil
		lib:triggerOptionCallbacks("onEnter", value)
	end)
end

lib:onEvent("PLAYER_LOGIN", function()
	createToggleKeybind("onEnter", "bindingToggleOnEnterButton", "KeyboardUIToggleOnEnterButton")
end)


-------------------------
-- Persistant Secure Keybinds

local persistantKeybinds = CreateFrame("Button", "KeyboardUIPersistantKeybinds", nil, "SecureFrameTemplate")
persistantKeybinds.postFuncs = {}
persistantKeybinds:HookScript("OnClick", function(__, button)
	if persistantKeybinds.postFuncs[button] then
		persistantKeybinds.postFuncs[button]()
	end
end)


local function addPersistantKeybind(option, command, postFunc)
	command = command or ("CLICK KeyboardUIPersistantKeybinds:" .. option)
	persistantKeybinds.postFuncs[option] = postFunc
	
	local enabled
	local keybind
	
	local function enableFunc(value)
		enabled = value
		if keybind then
			lib:afterCombat(SetOverrideBinding, KeyboardUIPersistantKeybinds, false, keybind, value and command or nil)
		end
	end
	
	local function bindingFunc(value)
		if enabled then
			local oldKeybind = keybind
			lib:afterCombat(SetOverrideBinding, persistantKeybinds, oldKeybind, nil) 
			lib:afterCombat(SetOverrideBinding, persistantKeybinds, value, command)
		end
		keybind = value
	end
	
	lib:onOptionChanged("enable"..option, enableFunc)
	lib:onOptionChanged("binding"..option, bindingFunc)
	
	lib:onEvent("PLAYER_LOGIN", function()
		keybind = lib:getOption("binding"..option)
		enableFunc(lib:getOption("enable"..option))
	end)	
end

addPersistantKeybind("RightClickTargetFrame", "CLICK TargetFrame:RightButton", nil)
addPersistantKeybind("StopSpeakingText", nil, function() lib:ttsStop() end)

-------------------------
-- Misc helper functions

local queueDuringCombat = {}

function lib:afterCombat(func, ...)
	if InCombatLockdown() then
		tinsert(queueDuringCombat, {func, ...})
	else
		func(...)
	end
end

lib:onEvent("PLAYER_REGEN_ENABLED", function()
	for __, funcAndArgs in ipairs(queueDuringCombat) do
		local retOK, msg = pcall(unpack(funcAndArgs))
		if not retOK and msg then
			print("Keyboard UI caught an error: " .. msg)
		end
	end
end)

function lib:findNextInTable(tbl, index, criteria)
	for i=index+1, #tbl do
		if criteria(tbl[i]) then
			return i
		end
	end
	for i=1, index do
		if criteria(tbl[i]) then
			return i
		end
	end
end

function lib:findPrevInTable(tbl, index, criteria)
	for i=index-1, 1, -1 do
		if criteria(tbl[i]) then
			return i
		end
	end
	for i=#tbl, index, -1 do
		if criteria(tbl[i]) then
			return i
		end
	end
end

local lastKey

local function onEditBoxKeyDown(editBox, key)
	local alt = IsAltKeyDown() and "ALT-" or ""
	local ctrl = IsControlKeyDown() and "CTRL-" or ""
	local shift = IsShiftKeyDown() and "SHIFT-" or ""
	local bindingAction = GetBindingByKey(alt .. ctrl .. shift .. key)
	for name, button in pairs(insecureButtons) do
		if bindingAction == "CLICK KeyboardUI" .. name .. "Button:LeftButton" then
			editBox:ClearFocus()
			button:Click()
			return
		end
	end
end

function lib:overrideEditFocus(frame)
	if frame:IsObjectType("EditBox") then
		frame:HookScript("OnKeyDown", onEditBoxKeyDown)
	end
	for i=1, frame:GetNumChildren() do
		self:overrideEditFocus(select(i, frame:GetChildren()))
	end
end

-------------




if C_TooltipInfo then

	function lib:getTooltipLines(kind, ...)
		local tooltipData = C_TooltipInfo[kind](...)
		TooltipUtil.SurfaceArgs(tooltipData)
		for __, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
		return tooltipData.lines
	end

else

	-- classic compatibility
	local scanningTooltip = CreateFrame("GameTooltip", "KeyboardUIScanningTooltip", nil, "SharedTooltipTemplate")
	scanningTooltip:SetOwner(frame, "ANCHOR_NONE")

	function lib:getTooltipLines(kind, ...)
		kind = "Set" .. kind:sub(4)
		scanningTooltip[kind](scanningTooltip, ...)
		local lines = {}
		local i = 1
		while _G["KeyboardUIScanningTooltipTextLeft" .. i] do
			lines[i] =
			{
				leftText =_G["KeyboardUIScanningTooltipTextLeft" .. i]:GetText(),
				rightText = _G["KeyboardUIScanningTooltipTextRight" .. i]:GetText(),
				leftColor = CreateColor(_G["KeyboardUIScanningTooltipTextLeft" .. i]:GetTextColor()),
				leftColor = CreateColor(_G["KeyboardUIScanningTooltipTextRight" .. i]:GetTextColor()),
			}
			i = i+1
		end
		return lines
	end
end

function lib:concatTooltipLines(kind, ...)
	local lines = self:getTooltipLines(kind, ...) or {}
	for i=1, #lines do
		lines[i] = lines[i].leftText or ""
	end
	return table.concat(lines, ". ")	
end

function lib:getFirstRedTooltipLine(kind, ...)
	local lines = self:getTooltipLines(kind, ...)
	for i=1, #lines do
		if lines[i].leftColor.g < 0.2 and lines[i].leftColor.b < 0.2 and lines[i].leftColor.r > 0.9 and lines[i].leftText and lines[i].leftText ~= "" then
			return lines[i].leftText
		end
	end
end


-- Executes func() right away if _G[frame] exists, or after _G[trigger] happens for the first time.
function lib:hookWhenFirstLoaded(frame, trigger, func)
	if _G[frame] then
		func(self, _G[frame])
		return true;
	elseif type("trigger") == "string" then
		if type(_G[trigger]) == "function" then
			hooksecurefunc(trigger, function()
				func(self, _G[frame])
				func = nop
			end)
		else
			self:onEvent("ADDON_LOADED", function(addonName)
				if addonName == trigger then
					func(self, _G[frame])
					func = nop
				end
			end)
		end
		return true;
	end
	return false;
end

-------------------------
-- Global mouse integration
do
	local onEnter, onEnterSayNPC, onEnterSayGroup, onEnterSayObject, onEnterSayUI, onEnterSayFullTooltip, onEnterPing

	-- World Frame
	
	local monitorNonPlayers
	local lastWorldFrameMessage
	local lastOnEnterPing
	local lastOnEnterPingInProgress
	
	local lastUIObject
	local lastUIObjectLine
	
	local noTooltipTicker
		
	local function stopMonitoringTooltip()
		if not GameTooltip:IsShown() then
			monitorNonPlayers = false
		end
	end
	
	lib:onEvent(WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and "CURSOR_UPDATE" or "CURSOR_CHANGED", function()
		if GetMouseFocus() == WorldFrame then
			monitorNonPlayers = true
			C_Timer.After(0, stopMonitoringTooltip)
		end
	end)
	
	local function monitorWorldFrameTooltips()
		local mouseFocus = GetMouseFocus()
		if mouseFocus == WorldFrame and onEnter and (
			onEnterSayNPC and monitorNonPlayers and UnitExists("mouseover") and not UnitIsPlayer("mouseover")
			or onEnterSayGroup and UnitExists("mouseover") and (UnitInParty("mouseover") or UnitInRaid("mouseover"))
			or onEnterSayObject and monitorNonPlayers and GameTooltip:IsShown() and not UnitExists("mouseover")
		) then
			local message = GameTooltipTextLeft1:GetText()
			if onEnterPing and message and message ~= lastOnEnterPing then
				__, lastOnEnterPingInProgress = PlaySound(823, nil, nil, true)
				lastOnEnterPing = message
			end
			if message and message ~= lastWorldFrameMessage and not lastOnEnterPingInProgress then
				lib:ttsStopMessage(lastWorldFrameMessage) -- this line caused stuttering in Patch 9.1.5; but has seemed okay from 9.2.0 onwards
				if lib:ttsYield(GameTooltipTextLeft1:GetText(), KUI_RAPID, KUI_PP) then
					lastWorldFrameMessage = message
				end
			end
		elseif mouseFocus and not mouseFocus:IsForbidden() and onEnter and onEnterSayUI and GameTooltip:IsShown() and (mouseFocus == GameTooltip:GetOwner() or mouseFocus:GetScript("OnLeave") ~= nil) and select(2, GameTooltip:GetOwner()) ~= "ANCHOR_NONE" then
			monitorNonPlayers = nil
			lastOnEnterPing = nil
			lastWorldFrameMessage = nil
			if mouseFocus ~= lastUIObject then
				lastUIObjectLine = 1
				lastUIObject = mouseFocus
				if onEnterPing then
					__, lastOnEnterPingInProgress = PlaySound(823, nil, nil, true)
				end
			end
			if lastOnEnterPingInProgress or lastUIObjectLine > 1 and not onEnterSayFullTooltip then
				return
			end
			local left, right = _G["GameTooltipTextLeft"..lastUIObjectLine], _G["GameTooltipTextRight"..lastUIObjectLine]
			if left and right then
				left = left:GetText()
				right = right:GetText()
			end
			if lastUIObjectLine == 1 and (right == "" or not right) and mouseFocus.GetMap and mouseFocus.GetGlobalPosition and mouseFocus:GetMap() == WorldMapFrame then
				local uiMapID = WorldMapFrame:GetMapID()
				if uiMapID and uiMapID == C_Map.GetBestMapForUnit("player") then
					local playerPosition = C_Map.GetPlayerMapPosition(uiMapID, "player")
					local pinX, pinY = mouseFocus:GetGlobalPosition()
					local x, y = playerPosition:GetXY()
					if playerPosition and pinX and pinY and x and y and (x > 0 or y > 0) then
						
						x = pinX - x
						y = pinY - y
						if abs(x) < 0.05 and abs(y) < 0.05 then
							right = NEAR
						elseif abs(x) > 2 * abs(y) then
							right = x > 0 and "east" or "west"
						elseif abs(y) > 2 * abs(x) then
							right = y > 0 and "south" or "north"
						elseif x > 0 then
							right = y > 0 and "southeast" or "northeast"
						else
							right = y > 0 and "southwest" or "northwest"
						end
						if abs(x) + abs(y) > 0.3 and C_Map.GetMapInfo(uiMapID).mapType == Enum.UIMapType.Zone then
							right = FAR .. " " .. right
						end
					end
				end
			end
			if left and right and right ~= "" and lib:ttsYield(left .. "; " .. right, KUI_RAPID, KUI_PP)
				or left and left ~= "" and lib:ttsYield(left, KUI_RAPID, KUI_PP)
			then
				lastUIObjectLine = lastUIObjectLine + 1
			end
		else
			monitorNonPlayers = false
			lastOnEnterPing = nil
			lastWorldFrameMessage = nil
		end
	end

	local function monitorUIElementsWithoutTooltip()
		local mouseFocus = GetMouseFocus()
		if mouseFocus and mouseFocus ~= WorldFrame then
			monitorNonPlayers = nil
			lastOnEnterPing = nil
			lastWorldFrameMessage = nil
			if mouseFocus ~= lastUIObject then
				lastUIObjectLine = 1
				lastUIObject = mouseFocus
				if onEnterPing then
					__, lastOnEnterPingInProgress = PlaySound(823, nil, nil, true)
				end
			end
			if lastUIObjectLine == 1 and not lastOnEnterPingInProgress then 
				local text = 
					mouseFocus:IsForbidden() and UNKNOWN
					or mouseFocus.GetText and mouseFocus:GetText() 
					--or type(mouseFocus.text) == "table" and mouseFocus.text.GetText and mouseFocus.text:GetText()
					--or type(mouseFocus.Text) == "table" and mouseFocus.Text.GetText and mouseFocus.Text:GetText()
					--or type(mouseFocus.Label) == "table" and mouseFocus.Label.GetText and mouseFocus.Label:GetText()
					--or type(mouseFocus.Description) == "table" and mouseFocus.Description.GetText and mouseFocus.Description:GetText()
					--or type(mouseFocus.HeaderText) == "table" and mouseFocus.HeaderText.GetText and mouseFocus.HeaderText:GetText()
				if not text then
					local frames = {mouseFocus}
					local texts = {}
					local i=1
					while frames[i] do
						for __, child in ipairs({frames[i]:GetChildren()}) do
							if child:IsMouseOver() and child:IsVisible() then
								tinsert(frames, child)
							end
						end
						for __, region in ipairs({frames[i]:GetRegions()}) do
							if region.GetText and region:GetText() and region:GetText() ~= "" and region:IsVisible() then
								tinsert(texts, region:GetText())
							end
						end
						i = i+1
					end
					if #texts > 0 then
						text = table.concat(texts, "; ")
					end
				end
				if not text and mouseFocus:IsObjectType("Button") then
					local parent = mouseFocus:GetParent()
					if parent then
						local texts = {}
						for __, region in ipairs({parent:GetRegions()}) do
							if region.GetText and region:GetText() and region:GetText() ~= "" and region:IsVisible() then
								tinsert(texts, region:GetText())
							end
						end
						if #texts > 0 then
							text = table.concat(texts, "; ")
						end
					end
				end
				if text then
					if lib:ttsYield(text, KUI_RAPID, KUI_PP) then
						lastUIObjectLine = 2
					end
				else
					lastUIObjectLine = 2
				end
			end
		end
	end

	local function resetTooltipMonitor()
		monitorNonPlayers = false
		lastOnEnterPing = nil
		lastWorldFrameMessage = nil
		noTooltipTicker = noTooltipTicker or onEnter and onEnterSayUI and C_Timer.NewTicker(0.1, monitorUIElementsWithoutTooltip)
	end
	
	local function resetNoTooltipMonitor()
		if noTooltipTicker then
			noTooltipTicker:Cancel()
			noTooltipTicker = nil
		end
	end

	GameTooltip:HookScript("OnUpdate", monitorWorldFrameTooltips)
	GameTooltip:HookScript("OnHide", resetTooltipMonitor)
	GameTooltip:HookScript("OnShow", resetNoTooltipMonitor)
		
	lib:onEvent("SOUNDKIT_FINISHED", function(soundHandle)
		if soundHandle == lastOnEnterPingInProgress then
			lastOnEnterPingInProgress = nil
		end
	end)	
	
	local function setOnEnter(val)
		onEnter = val
		if val and not GameTooltip:IsShown() then
			resetTooltipMonitor()
		else
			resetNoTooltipMonitor()
		end
	end
		
	-- option initialization
	lib:onEvent("PLAYER_LOGIN", function()
		onEnterSayGroup = lib:getOption("onEnterSayGroup")
		onEnterSayNPC = lib:getOption("onEnterSayNPC")
		onEnterSayObject = lib:getOption("onEnterSayObject")
		onEnterSayUI = lib:getOption("onEnterSayUI")
		onEnterSayFullTooltip = lib:getOption("onEnterSayFullTooltip")
		onEnterPing = lib:getOption("onEnterPing")

		-- save this for last
		setOnEnter(lib:getOption("onEnter"))
	end)
	
	lib:onOptionChanged("onEnter", setOnEnter)
	lib:onOptionChanged("onEnterSayGroup", function(value) onEnterSayGroup = value end)
	lib:onOptionChanged("onEnterSayNPC", function(value) onEnterNPC = value end)
	lib:onOptionChanged("onEnterSayObject", function(value) onEnterSayObject = value end)
	lib:onOptionChanged("onEnterSayUI", function(value) onEnterSayUI = value end)
	lib:onOptionChanged("onEnterSayFullTooltip", function(value) onEnterSayFullTooltip = value end)
	lib:onOptionChanged("onEnterPing", function(value) onEnterPing = value end)
	
end

-------------------------
-- Options Menu

local panel = CreateFrame("Frame")
panel.name = "KeyboardUI"
panel:Hide()	-- important to trigger scrollFrame OnShow()

local kuiOptions = {name = "global", frame = panel, title = TEXT_TO_SPEECH}
KeyboardUI:RegisterModule(kuiOptions)	-- this happens after the panel is added to InterfaceOptions so it has a parent
panel:SetScript("OnShow", nil)
panel:SetScript("OnHide", nil)

function panel.default()
	for name, module in pairs(modulesByName) do
		for option, value in pairs(tempOptions[name]) do
			tempOptions[name][option] = nil
			KeyboardUIOptions[name][option] = nil
			module:triggerOptionCallbacks(option, defaultOptions[name][option])
		end
		for option, value in pairs(KeyboardUIOptions[name]) do
			KeyboardUIOptions[name][option] = nil					
			module:triggerOptionCallbacks(option, defaultOptions[name][option])
		end
	end
end

function panel.okay()
	for name, module in pairs(modulesByName) do
		for option, value in pairs(tempOptions[name]) do
			KeyboardUIOptions[name][option] = value
			tempOptions[name][option] = nil
		end
	end
end

function panel.cancel()
	for name, module in pairs(modulesByName) do
		for option, value in pairs(tempOptions[name]) do
			tempOptions[name][option] = nil
			module:triggerOptionCallbacks(option, KeyboardUIOptions[name][option])
		end
	end
end

InterfaceOptions_AddCategory(panel)

local title = panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
title:SetText("Keyboard User Interface")
title:SetPoint("TOP", 0, -5)

local subtitle = panel:CreateFontString("ARTWORK", nil, "GameFontNormal")
subtitle:SetText("/keyboardui or /kui")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)

local scrollParent = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollParent:SetPoint("TOPLEFT", 3, -50)
scrollParent:SetPoint("BOTTOMRIGHT", -27, 4)

local track = scrollParent:CreateTexture("BACKGROUND")
track:SetColorTexture(0.1, 0.1, 0.1, 0.3)
track:SetPoint("TOPLEFT", scrollParent, "TOPRIGHT", 4, 0)
track:SetPoint("BOTTOMRIGHT", scrollParent, 22, 0)

local scrollChild = CreateFrame("Frame")
scrollParent:SetScrollChild(scrollChild)
scrollChild:SetWidth((InterfaceOptionsFramePanelContainer or SettingsPanel.Container.SettingsCanvas):GetWidth()-18)

-- defer creating most widgets until the first OnShow() which follows right after these lib funcs.
-- also defer creating the functions to handle keyboard input until the first OnShow()

local savedForLater = {}

local function saveForLater(module, ...)
	savedForLater[module] = saveForLater[module] or {}
	tinsert(savedForLater[module], {...})
end

function lib:panelCheckButton(...)
	saveForLater(self, "panelCheckButton", ...)
end

function lib:panelSlider(...)
	saveForLater(self, "panelSlider", ...)
end


scrollChild:SetScript("OnShow", function()

	local options = KeyboardUIOptions -- I'm lazy

	scrollChild:SetScript("OnShow", nil)	-- do this once only!

	local function insertFrame(parent, frame, parentOption)
		if parentOption then
			for i=1, #parent do
				if parent[i].option == parentOption then
					frame.parent = parent[i]
					frame.prev = frame.parent.last
					frame.parent.last = frame
					frame:SetPoint("LEFT", 50, 0)
					local anchorTo = frame.prev or frame.parent
					local spacing = anchorTo:IsObjectType("Slider") and 12 or 6
					frame:SetPoint("TOP", anchorTo, "BOTTOM", 0, -spacing)
					parent:SetHeight(parent:GetHeight() + frame:GetHeight() + spacing)
					scrollChild:SetHeight(scrollChild:GetHeight() + frame:GetHeight() + spacing)
					tinsert(frame.parent, frame)
					if frame.parent.next then
						frame.parent.next:SetPoint("TOP", frame.parent.last, "BOTTOM", 0, frame.parent.last:IsObjectType("Slider") and -20 or -16)
					end
					if frame.parent:IsObjectType("CheckButton") and frame.Enable then
						frame.module:onOptionChanged(parentOption, function(value)
							if value then
								frame:Enable()
							else
								frame:Disable()
							end
						end)
					elseif frame.parent:IsObjectType("Slider") and frame.Enable then
						frame.module:onOptionChanged(parentOption, function(value)
							if value > frame.parent:GetMinMax() then
								frame:Enable()
							else
								frame:Disable()
							end
						end)
					end
					return
				end
			end
		end
		frame.prev = parent[#parent]
		frame.prev.next = frame
		frame:SetPoint("LEFT", 25, 0)
		local anchorTo = frame.prev.last or frame.prev
		local spacing = anchorTo:IsObjectType("Slider") and 20 or 16
		frame:SetPoint("TOP", anchorTo, "BOTTOM", 0, -spacing)
		parent:SetHeight(parent:GetHeight() + frame:GetHeight() + spacing)
		scrollChild:SetHeight(scrollChild:GetHeight() + frame:GetHeight() + spacing)
		tinsert(parent, frame)
	end

	local function setTempOption(module, option, value)
		if tempOptions[module.name][option] ~= value then
			tempOptions[module.name][option] = value
			module:triggerOptionCallbacks(option, value)
		end
	end

	-- overwrite the earlier functions now that the interface options have been shown for the first time.
	function lib:panelCheckButton(option, title, description, parentOption)
		local parent = scrollChild[self.id]
		local frame = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		frame.module = self
		frame.option = option
		frame.description = description
		insertFrame(parent, frame, parentOption)
		frame.text:SetText(title)
		frame.text:SetTextColor(1,1,1)
		frame:SetScript("OnEnter", function()
			modules[1]:displayTooltip(frame, "Mouseover: " .. title, frame:GetChecked() and "Checked " or "Unchecked " .. CHAT_HEADER_SUFFIX .. frame.description, "ANCHOR_BOTTOMRIGHT", panel)
		end)
		frame:SetChecked(self:getOption(option))
		frame:SetScript("OnClick", function()
			local checked = frame:GetChecked()
			setTempOption(self, option, checked)
			modules[1]:ttsInterrupt(checked and "Checked." or "Unchecked.", KUI_QUICK, KUI_MP)
		end)
		self:onOptionChanged(option, function(value)
			frame:SetChecked(value)
		end)
		if globalDefaults[option] and self.name ~= "global" then
			modules[1]:onOptionChanged(option, function(value)
				if tempOptions[self.name][option] == nil and rawget(options[self.name], "option") == nil then
					frame:SetChecked(value)
				end
			end)
		end
	end

	-- overwrite the earlier functions now that the interface options have been shown for the first time.
	function lib:panelSlider(option, title, description, min, max, step, low, high, top, parentOption)
		local parent = scrollChild[self.id]
		local frame = CreateFrame("Slider", nil, parent, top and "OptionsSliderTemplate" or "HorizontalSliderTemplate")
		frame.module = self
		frame.option = option
		if top then
			frame.description = ("%s |n%s %%s. |n%s %d, %s %d"):format(description, ASSIGNED_COLON, MINIMUM, min, MAXIMUM, max)
		elseif step%1 == 0 then
			frame.description = ("%s |n%s %%d. |n%s %d, %s %d"):format(description, ASSIGNED_COLON, MINIMUM, min, MAXIMUM, max)
		elseif step%0.1 == 0 then
			frame.description = ("%s |n%s %%.1f. |n%s %.1f, %s %.1f"):format(description, ASSIGNED_COLON, MINIMUM, min, MAXIMUM, max)
		else
			frame.description = ("%s |n%s %%.2f. |n%s %.2f, %s %.2f"):format(description, ASSIGNED_COLON, MINIMUM, min, MAXIMUM, max)
		end
		insertFrame(parent, frame, parentOption)
		frame.text = frame:CreateFontString("ARTWORK", nil, "ChatFontNormal")
		frame.text:SetText(title)
		local width = frame.text:GetWidth()
		frame.text:SetPoint("CENTER", frame, "LEFT", width < 100 and -60 or -125, 0)
		if frame.prev:IsObjectType("Slider") then
			if select(4, frame.prev:GetPointByName("LEFT")) == 125 and width < 100 and frame:GetHeight() == frame.prev:GetHeight() then
				frame:SetPoint("TOP", frame.prev)
				frame:SetPoint("LEFT", parent:GetWidth()/2 + 125, 0)
				scrollChild:SetHeight(scrollChild:GetHeight() - frame:GetHeight() - 20)
				parent:SetHeight(parent:GetHeight() - frame:GetHeight() - 20)
			else
				frame:SetPoint(frame.prev:GetPointByName("LEFT"))
			end
		else
			frame:SetPoint("LEFT", width < 100 and 125 or 250, 0)
		end
		frame:SetMinMaxValues(min, max)
		frame:SetValueStep(step)
		frame:SetObeyStepOnDrag(true)
		frame:SetValue(self:getOption(option))
		if top then
			frame.Low:SetText(low or min)
			frame.High:SetText(high or max)
			frame.Text:SetText(top:format(frame:GetValue()))
		end
		frame:SetScript("OnEnter", function()
			modules[1]:displayTooltip(frame, title, frame.description:format(frame.Text and frame.Text:GetText() or frame:GetValue()), "ANCHOR_BOTTOMRIGHT", panel)
		end)
		frame:SetScript("OnValueChanged", function(__, value)
			if top then
				frame.Text:SetText(top:format(value))
			end
			setTempOption(self, option, value)
		end)
		frame:HookScript("OnMouseUp", function()
			if not down then
				modules[1]:ttsInterrupt(frame.Text and frame.Text:GetText() or frame:GetValue())
			end
		end)
		self:onOptionChanged(option, function(value)
			frame:SetValue(value)
			if frame.Text then
				frame.Text:SetText(top:format(value))
			end
		end)
		if globalDefaults[option] and self.name ~= "global" then
			modules[1]:onOptionChanged(option, function(value)
				if tempOptions[self.name][option] == nil and rawget(options[self.name], "option") == nil then
					frame:SetValue(value)
					if frame.Text then
						frame.Text:SetText(top:format(value))
					end
				end
			end)
		end
	end

	-- i=1
	scrollChild[1] = CreateFrame("Frame", nil, scrollChild)
	scrollChild[1]:SetPoint("TOPLEFT")
	scrollChild[1]:SetPoint("TOPRIGHT")
	scrollChild[1][1] = scrollChild[1]:CreateFontString("ARTWORK", nil, "GameFontNormal")
	scrollChild[1][1]:SetPoint("TOPLEFT", 10, 0)
	scrollChild[1][1]:SetText(modules[1].title or module[1].name)
	scrollChild[1][1].module = panel
	scrollChild[1]:SetHeight(scrollChild[1][1]:GetHeight())
	scrollChild:SetHeight(scrollChild[1][1]:GetHeight())
	modules[1]:panelSlider("volumeMax", VOLUME, "Set the maximum volume for the loudest message.  Most messages will be softer.", 0, 100, 25, OFF, "100%", "%d%%")
	modules[1]:panelSlider("volumeVariance", VOLUME .. " variance", "Limit how much softer the quietest message can be.", 0, 50, 10, 0, 50, "%d%%")
	modules[1]:panelSlider("speedMax", SPEED, "Set the maximum speaking rate.  Some messages will be slightly slower.", 0, 10, 0.5, "slower", "faster", "+%.1f")
	modules[1]:panelSlider("speedVariance", SPEED .. " variance", "Limit how much slower the slowest message can be.  Most messages are not quite this much slower.", 0, 4, 1, 0, -4, "-%d")
	
	modules[1]:panelCheckButton("onEnter", BINDING_NAME_INTERACTMOUSEOVER .. " (" .. KeyboardUIOptions.global.bindingToggleOnEnterButton .. " )", "Make sounds and read names when moving the mouse.")
	modules[1]:panelCheckButton("onEnterSayNPC", NPC_NAMES_DROPDOWN_HOSTILE, "Read out names of interactive NPCs.", "onEnter")
	modules[1]:panelCheckButton("onEnterSayGroup", VOICE_CHAT_PARTY_RAID, "Read out names of interactive NPCs.", "onEnter")
	modules[1]:panelCheckButton("onEnterSayObject", OBJECTIVES_LABEL, "Read out names of interactive objects.", "onEnter")
	modules[1]:panelCheckButton("onEnterSayUI", UIOPTIONS_MENU, "Read out buttons and other UI objects.", "onEnter")
	modules[1]:panelCheckButton("onEnterSayFullTooltip", ITEM_MOUSE_OVER, "Read the complete tooltip during mouseover, instead of waiting for ctrl-space.", "onEnter")
	modules[1]:panelCheckButton("onEnterPing", SOUND, "Make a clicking sound.", "onEnter")
	
	modules[1]:panelCheckButton("enableRightClickTargetFrame", L["PRESS_TO"]:format(ALT_KEY_TEXT.."-T", "toggle menu on current target"), "Enables a keyboard shortcut to simulate right-clicking on your current target's portrait, opening an options menu.  You can also target yourself, your pet, or party members to open up additional options with this keybind.")
	modules[1]:panelCheckButton("enableStopSpeakingText", L["PRESS_TO"]:format(ALT_KEY_TEXT.."-V", MUTE), "Enables a keyboard shortcut to stop the current text to speech message.")
	
	for i=2, #modules do
		local module = modules[i]
		scrollChild[i] = CreateFrame("Frame", nil, scrollChild)
		scrollChild[i]:SetPoint("TOPLEFT", scrollChild[i-1], "BOTTOMLEFT")
		scrollChild[i]:SetPoint("TOPRIGHT", scrollChild[i-1], "BOTTOMRIGHT")
		scrollChild[i][1] = scrollChild[i]:CreateFontString("ARTWORK", nil, "GameFontNormal")
		scrollChild[i][1]:SetPoint("TOPLEFT", 10, -30)
		scrollChild[i][1]:SetText(module.title or module.name)
		scrollChild[i][1].module = module
		scrollChild[i]:SetHeight(scrollChild[i][1]:GetHeight() + 30)
		scrollChild:SetHeight(scrollChild:GetHeight() + scrollChild[i][1]:GetHeight() + 30)
		module:panelCheckButton("enabled", ENABLE .. " " .. (module.title or module.name), "Enable keyboard navigation when " .. (module.title or module.name) .. " appears.")
		if savedForLater[module] then
			for __, tbl in ipairs(savedForLater) do
				module[tbl[1]](module, select(2,tbl))	--e.g. module["panelCheckButton"](module, ...)
			end
		end
	end

end)	-- end of scrollChild:OnShow()


-------------------------
-- Slash command

function SlashCmdList.KEYBOARDUI(msg)
	if InterfaceAddOnsList_Update and (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC) then
		InterfaceAddOnsList_Update()	-- https://github.com/Stanzilla/WoWUIBugs/issues/89
		InterfaceOptionsFrame_OpenToCategory(panel)
	else
		-- WoW 10.x
		Settings.OpenToCategory(panel.name)
	end
	-- give the user a hint
	modules[1]:ttsStop()
	local hintText = [=[<speak>Keyboard UI Options.  Keyboard UI has various keybindings which activate only outside combat, and only while a keyboard-enabled window appears.
<silence msec="750" />The first set of keybinds are for moving around each window: %1$s, %2$s, %5$s and %6$s.  You always start at the top of a window, so %1$s moves to the next option and %2$s moves back one.  It is also possible to jump sections with %3$s and %4$s.
<silence msec="750" />Next, once you have reached the desired option, use %5$s, %6$s and %7$s to change it.  Increment a slider with %5$s and decrement it with %6$s.  Toggle a checkbutton with %7$s.  If its a more complex choice, with many buttons to choose from, use %5$s and %6$s to cycle through the possibilities and %7$s to commit the action.
<silence msec="750" />The next set of keybinds are hot keys such as %11$s and %10$s.  These hot keys change meaning depending which option you are at.  Press %8$s to read out the list of available hot keys.  Of note, %10$s is the hot key to save these Kebyoard UI settings and exit.  Without pressing %10$s, any changes you make will not save.
<silence msec="750" />You may also query for more detail.  Press %9$s to read a full-length description. In fact, if you are unsure of what to do, both %9$s and %8$s are always safe choices because they simply read information without changing anything.
<silence msec="750" />Finally, these keybinds are re-used throughout the user interface.  Each window is a little different, but its the same key strokes.  There is one other not yet listed: %12$s switches between tabs, on a window that has tabs.  Note that this does not apply to these Keyboard UI options.</speak>]=]
	
	modules[1]:ttsInterrupt(hintText:format(
		KeyboardUIOptions.global.bindingNextEntryButton, -- 1
		KeyboardUIOptions.global.bindingPrevEntryButton, -- 2
		KeyboardUIOptions.global.bindingNextGroupButton, -- 3
		KeyboardUIOptions.global.bindingPrevGroupButton, -- 4
		KeyboardUIOptions.global.bindingForwardButton, -- 5
		KeyboardUIOptions.global.bindingBackwardButton, -- 6
		KeyboardUIOptions.global.bindingDoActionButton, -- 7
		KeyboardUIOptions.global.bindingActionsButton, -- 8
		KeyboardUIOptions.global.bindingReadDescriptionButton, -- 9
		KeyboardUIOptions.global.bindingDoAction5Button, -- 10
		KeyboardUIOptions.global.bindingDoAction1Button, -- 11
		KeyboardUIOptions.global.bindingChangeTabButton -- 12
	), KUI_NORMAL, KUI_MP)
end
SLASH_KEYBOARDUI1 = "/keyboardui"
SLASH_KEYBOARDUI2 = "/kui"


-------------------------
-- Tutorial

local tutorialChapters = 
{
}

local currentTutorial

local function startNextTutorial()
	for trigger in pairs(tutorialChapters) do
		local val = trigger()
		if val then
			currentTutorial = tutorialChapters[trigger]
			tutorialChapters[trigger] = nil
			return currentTutorial
		elseif val == nil then
			tutorialChapters[trigger] = nil
		end
	end
end

local currentTutorialMsg, currentTutorialMsgTime = nil, 0


local function playTutorial()
	C_Timer.After(0.5, playTutorial)
	currentTutorial = currentTutorial or startNextTutorial()
	if currentTutorial then
		for i=1, #currentTutorial do
			if type(currentTutorial[i]) == "string" then
				if lib:ttsYield(currentTutorial[i], KUI_SLOW, KUI_MP) then
					currentTutorial[i] = function() return true end
					return
				end
			else
				local val = currentTutorial[i]()
				if type(val) == "string" then
					if (val ~= currentTutorialMsg or GetTime() - currentTutorialMsgTime > 12) and not InCombatLockdown() and lib:ttsYield(val, KUI_SLOW, KUI_MP) then
						currentTutorialMsg = val
						currentTutorialMsgTime = GetTime()
					end
					return
				elseif val == false then
					return
				end
			end
		end
		currentTutorial = nil
	end
end
	
lib:onEvent("PLAYER_LOGIN", function()

	lib:registerTutorial(function() return UnitLevel("player") == 1 or nil end,
		{
			TUTORIAL_TITLE42,
			("%s%s%s, %s, %s, %s"):format(BINDING_HEADER_MOVEMENT, CHAT_HEADER_SUFFIX, GetBindingKey("MOVEFORWARD") or "", GetBindingKey("MOVEBACKWARD") or "", GetBindingKey("TURNLEFT") or "", GetBindingKey("TURNRIGHT") or ""),
		}
	)

	C_Timer.After(7.5, function()
		if not startNextTutorial() and UnitLevel("player") <= 30 then
			lib:ttsQueue("For help with Keyboard UI, type: slash, K, U, I.", KUI_NORMAL, KUI_PP)
		end
		playTutorial()
	end)
end)


-- triggerFunc should return true to activate a tutorial, false to defer execution, or nil when the tutorial is no longer required
-- stepFuncs should be an array of functions that returns one of the following:
--		string			play this message through tts
--		true			move onto the next function in the array; but recheck this again in the future
--		false			delay for five seconds; the user is not ready for the next tutorial step
-- alternatively, if a string appears in the table (in lieu of a function) then it will just be spoken one time only when all previous functions return true (or immediately when the tutorial activates, if it was the first element in the array)
-- once the last function in stepFuncs returns true, the tutorial ends and never fires again

function lib:registerTutorial(triggerFunc, stepFuncs)
	tutorialChapters[triggerFunc] = stepFuncs
end