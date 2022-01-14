--[[

## Title: KeyboardUI
## Notes: Keyboard user interface with text to speech
## Author: Dahk Celes (DDCorkum)
## X-License: All Rights Reserved

This addon is made in partnership with WoWAccess by RogueEugor (A. Agostino).  The two addons may function alongside each other.
Please note that WoWAccess is copyleft via GPL, while KeyboardUI remains all rights reserved

Permission is granted to redistribute without modification outside the traditional WoW ecosystem in locations aimed principally at persons with blindness or low vision.
This includes redistributing inside a zip folder containing multiple addons for assisted play, such as but not limited to WoWAccess.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

0.3 (2022-01-13) by Dahk Celes
- Small tweaks and bug fixes.  First version to be publicly visible.

0.2 (2022-01-12) by Dahk Celes
- Rewrote the core addon using lessons learned from the proof of concept.

0.1 (2022-01-03) by Dahk Celes
- Initial alpha version / proof of concept.

--]]

KeyboardUI = {}
local KeyboardUI = select(2, ...)
--setmetatable(_G["KeyboardUI"], {__index=KeyboardUI})		-- Uncommenting out this line would expose the internal API for other AddOns to integrate with KeyboardUI.
															-- I havn't yet decided yet to do this, but I am designing KeyboardUI with this future possibility in mind.
-------------------------
-- Constants

KUI_FF = 1.00
KUI_F  = 0.95
KUI_MF = 0.90 -- default
KUI_MP = 0.85
KUI_P  = 0.75 -- messages that repeat every few seconds
KUI_PP = 0.50

KUI_CASUAL 	= 1
KUI_NORMAL 	= 2	-- default
KUI_QUICK 	= 4
KUI_RAPID 	= 5

KUI_HIGHLIGHT_COLOR = {1, 1, 0, 0.2}

local TEXT_TO_SPEECH = TEXT_TO_SPEECH or "Text to speech"	-- Classic compatibility for 1.14.1 (not fixed) and 2.5.2 (fixed in 2.5.3)

-------------------------
-- Configuration

local KUI_VOICE = 1 		-- Microsoft Zira (enUS)
local KUI_VOICE_ALT = 0		-- Microsoft David (enUS)

-- modules cannot change these settings with setOption()
local globalDefaults =
{
	-- options duplicated for each module
	enabled = true,									-- Disables a module entirely when false
	volume = 100,									-- Disables text to speech when set to zero
	speed = 1,										-- Less than one slows, and greater than one accelerates text to speech
		
	-- key bindings that are kept the same for the entire addon
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
	bindingReadTitleButton = "CTRL-BACKSPACE",
	bindingReadDescriptionButton = "CTRL-SPACE",
}

-------------------------
-- API / Instructions / Boilerplate

--[[

local module = {name = "must be a string", frame = CreateFrame("Frame", nil, BlizzardFrame)}  -- Keybinds depend on the frame strata, frame level, and visibility.  Parenting to an appropriate BlizzardFrame is optional, but automates this.

KeyboardUI:RegisterModule(module, minorVersion)		

	-- Saved variables
	
		-- KeyboardUI may include custom saved variables on behalf of any module.  The following helper functions are intended to access these custom variables.
		
		-- module:setDefault(option, value)								-- Set a default value that will be used when the user has not made an explicit choice, or after the user resets all settings to their defaults.
		-- module:setOption(option [, value])							-- Write to KeyboardUI SavedVariables.  Not meant to be used except when the user makes an explicit choice (that may or may not deviate from the default).
		-- module:getOption(option)										-- Read from KeyboardUI SavedVariables.
		-- module:onOptionChanged(option, func)							-- Request a callback whenever the user changes an option.  This includes cancelling previous changes, or returning to defaults.

		-- Arguments for setDefault(), setOption() and getOption()
			-- option		string		Silently fails if a reserved keyword is used.  The current reserved keywords are "enableKeyboard", "speed" and "volume".
			-- value		any type	Must be serializable or else SavedVariables will fail.
	
	-- Interface options
	
		-- Insert widgets with a common look and feel to other KeyboardUI interface options.  These widgets automatically use SavedVariables and call module:Update() when changed.
		
		-- module:panelCheckButton(option, title, tooltip [, parentOption])								-- Create a CheckButon.
		-- module:panelSlider(option, title, tooltip, min, max, step, [low, high, top, parentOption])	-- Create a Slider.  "top" is formatted as top:format(slider:GetValue()).  Leaving low, high and top nil results in a smaller slider with no labels.
		
		-- Arguments for addCheckButton(), addSlider()
			-- option		string		Silently fails if an existing keyword is used.
			-- title		string		Label displayed before the slider.
			-- tooltip		string		Text printed and spoken during hover.
			-- parentOption string		Only appears when getOption(parentOption) is neither false nor nil.
					
	-- Text to speech
	
		-- KeyboardUI provides user interface settings to influence properties such as the speed and volume on a per-module basis.
		-- The following wrapper functions apply user settings before calling C_VoiceChat.SpeakText()
		-- If the user sets volume for a module to zero, then nothing is spoken.

		-- module:ttsQueue(text [, rate, dynamics, useAltVoice])		-- Speaks using queued local playback.
		-- module:ttsInterrupt(text [, rate, dynamics, useAltVoice])	-- Interrupts any ongoing or queued local playback with a new message.
		-- module:ttsStop()												-- Stops any ongoing or queued local playback.

		-- Arguments for ttsQueue() and ttsInterrupt()
			-- text			string		Message for local playback.
			-- rate			number		Defaults to 3.
			-- dynamics		number		Defaults to KUI_MF.  Expected values are KUI_FF, KUI_F, KUI_MF, KUI_MP, KUI_P, or KUI_PP. 
			-- useAltVoice	boolean		When true, uses an alternate voice.
		
		
	-- Methods that each module should overwrite as required. (Hint: they start with upper case.)
		
		-- title = module:NextGroup()							-- Go to the first entry in the next/prev group containing entries.  Defaults to Next/PrevEntry(), so override only if there is more than one group.  Return false to indicate failure.
		-- title = module:PrevGroup()							-- Examples: paging in the merchant frame; collapsible headers in the quest log; and sections of settings in the interface options.
		
		-- title = module:NextEntry()							-- Go to the first action in the nextprev entry containing actions.  Defaults to Forward/Backward(), so override only if there is more than one entry.  Return false to indicate failure.
		-- title = module:PrevEntry()							-- Examples: each item in the merchant frame; each quest in the quest log; and each setting in the interface options.
				
		-- title = module:RefreshEntry()						-- Confirm the current entry is valid, and if not, go to the most appropriate entry.  Defaults to NextEntry().  Return false to indicate failure.
		-- description = module:GetEntryLongDescription()		-- Get a full-length description of the entry.
		
		-- title = module:Forward()								-- Cycle between available actions, or does an action going "forward" if the only choices are forward/backward.  Defaults to DoAction(), so override only if there is more than one action.   Return nil to indicate failure.
		-- title = module:Backward()							-- Examples: choosing between tracking, sharing or abandoning a quest; choosing between different buttons in the StaticPopup; or immediately moving a slider forward and back.
		
		-- [title1, ...] = module:Actions()						-- REQUIRED.  Provide a list of up to five available actions.  If none are possible, return an empty string.
		-- [result] = module:DoAction([index])					-- REQUIRED.  Do the action selected with Next/PrevAction(), or the indexth action returned by Actions().

		
	-- Helper functions that should NOT be overwritten. (Hint: they start with lower case.)
	
		-- module:afterCombat(func, ...)							-- Call self:func(...) as soon as possible but outside combat lockdown
		-- module:displayTooltip(text [, optLine1], ...)			-- NEEDS DOCUMENTATION		
	
	-- Methods that each module may overwrite if desired. (Hint: they start with upper case.)
	
		-- module:Init()												-- Called when the module's saved variables are accessible (normally after ADDON_LOADED).  This is the earliest that :setOption() will work; but :setDefault() is permitted earlier.
	
local L = module.text	-- Optional localization.  A metatable is added during registration such that L["something"] returns "something" if a localized alternative is not found
	
--]]


KeyboardUIOptions = {}				-- SavedVariable
local defaultOptions = {}			-- non-persistent
local tempOptions = {}				-- while the interface options are open
local optionCallbacks = {}			-- called when an option changes in the interface options
local lib = {}						-- functions inheritable by all modules
local frame = CreateFrame("Frame")	-- general event handler and override keybind owner
local modules = {}					-- modules in the order they were loaded (unless overridden by optIndex)
local modulesByName = {}			-- modules in no particular order, to simplify getting them by name
local shownModules = {}				-- the modules currently visible

local function enableKeybindings()
	-- todo: turn this into something that activates only when a frame is visible.
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
	SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingReadTitleButton, "KeyboardUIReadTitleButton", "LeftButton")
	SetOverrideBindingClick(frame, false, KeyboardUIOptions.global.bindingReadDescriptionButton, "KeyboardUIReadDescriptionButton", "LeftButton")	
end

local function disableKeybindings()
	ClearOverrideBindings(frame)
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

local function moduleOnShow(frame)
	local module = frame.module
	module.priority = stratas[frame:GetFrameStrata()] + frame:GetFrameLevel()
	if #shownModules == 0 then
		shownModules[1] = module
		enableKeybindings()
	else
		local i = 1
		while shownModules[i] and shownModules[i].priority < module.priority do
			i = i + 1
		end
		tinsert(shownModules, i, module)
	end
end

local function moduleOnHide(frame)
	local module = frame.module
	local n = #shownModules
	if n == 1 then
		disableKeybindings()
		shownModules[1] = nil
	else
		for i=#shownModules, 1, -1 do
			if shownModules[i] == module then
				tremove(shownModules, i)
				return
			end
		end
	end
end

local function updatePriorityWhileVisible(frame)
	if frame:IsVisible() then
		frame:Hide()
		frame:Show()
	end
end

function KeyboardUI:RegisterModule(module, optIndex)
	assert(type(module.name) == "string" and module.frame:IsObjectType("Frame"), "Invalid module registration")
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
	
	module.frame.module = module
	module.frame:HookScript("OnShow", moduleOnShow)
	module.frame:HookScript("OnHide", moduleOnHide)
	hooksecurefunc(module.frame, "SetFrameStrata", updatePriorityWhileVisible)
	hooksecurefunc(module.frame, "SetFrameLevel", updatePriorityWhileVisible)
end



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
		setmetatable(KeyboardUIOptions[name], {__index = globalDefaults})
		setmetatable(defaultOptions[name], {__index = globalDefaults})
	else
		-- the options for each module have a longer default values chain that ultimately terminates with the same global configuration settings
		setmetatable(KeyboardUIOptions[name], {__index = defaultOptions[name]})
		setmetatable(defaultOptions[name], {__index = KeyboardUIOptions.global})
	end
end
	
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(__, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "KeyboardUI" then
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
				module.frame:SetShown(KeyboardUIOptions[module.name]["enabled"])
				module:onOptionChanged("enabled", function(value) module.frame:SetShown(value) end)
				modules[i]:Init()
			end
		end
	elseif event == "PLAYER_LOGIN" then
		C_Timer.After(5, function()
			if KeyboardUIOptions.global.notFirstTime then
				modules[1]:ttsQueue("For help with Keyboard UI, type: slash, K, U, I.", KUI_NORMAL, KUI_PP)
			else
				KeyboardUIOptions.global.notFirstTime = true
				modules[1]:ttsInterrupt([=[<speak>Welcome to Keyboard UI. <silence msec="500"/> For help, type: slash Keyboard UI, all as one word.  Alternatively, type: slash, K, U, I.</speak>]=], KUI_CASUAL, KUI_P)
			end
		end)
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

	end
end

function lib:getOption(option)
	if KeyboardUIOptions[self.name] then
		return KeyboardUIOptions[self.name][option]
	end
end


-------------------------
-- Modules should override these as appropriate

function lib:Init()
	-- Fires when a module is permitted to begin accessing KeyboardUI saved variables using module:setOption().
end

function lib:NextGroup(...)
	-- Override to navigate groups or pages, each with one or more entries, each with one or more actions.
	return self:NextEntry(...)
end

function lib:PrevGroup(...)
	-- Override to navigate groups or pages, each with one or more entries, each with one or more actions.
	return self:NextEntry(...)
end

function lib:NextEntry(...)
	-- Override to navigate a list of entries, each with one or more actions.
	return self:Forward(...)
end

function lib:PrevEntry(...)
	-- Override to navigate a list of entries, each with one or more actions.
	return self:Backward(...)
end

function lib:RefreshEntry(...)
	return self:NextEntry(...)
end

function lib:Forward(...)
	-- Override to go forward to the next action, or to do the only action in the forward direction (when applicable)
	return self:DoAction() -- deliberately not passing args, to avoid misinterpretting as a hotkey
end

function lib:Backward(...)
	-- Override to go backward to the last action, or to do the only action in the reverse direction (when applicable)
	return self:Forward(...)  -- this is a bad user experience; it *should* be overridden!
end

function lib:NextAction(...)
	-- Always override or it will throw an error.
	if self.frame then
		self.frame.Show = self.frame.Hide
		self.frame:Hide()
	end
	print("Keyboard UI: The " .. self.name .. " module is missing module:NextAction().")
end

function lib:PrevAction(...)
	-- This is a bad user experience; 99% of modules should override this.
	lib:NextAction(...)
end

function lib:Actions()
	-- REQUIRED.  Modules must override to avoid blocklisting.
	local text
	if self.name and self.frame then
		self.frame:Hide()
		text = "Keyboard UI found an error.  The " .. self.name .. " module is missing an a required function." 
	else
		text = "Keyboard UI has encountered an unknown error."
	end
	self.Actions = function() return "" end
	print(text)
	return text
end

function lib:DoAction()
	-- REQUIRED.  Modules must override to avoid blocklisting.
	local text
	if self.name and self.frame then
		self.frame:Hide()
		text = "Keyboard UI found an error.  The " .. self.name .. " module is missing an a required function." 
	else
		text = "Keyboard UI has encountered an unknown error."
	end
	self.DoAction = function() return "" end
	print(text)
	return text
end

function lib:GetEntryLongDescription()
	return self:RefreshEntry()
end

-------------------------
-- Speech

local ttsFrame = CreateFrame("Frame", "Foo")
ttsFrame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
ttsFrame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
ttsFrame:SetScript("OnEvent", function(__, event)
	if event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
		ttsFrame:Hide()
	elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
		ttsFrame:Show()
	end
end)

ttsFrame:SetScript("OnUpdate", function()
	if #ttsFrame > 0 then
		local tbl = tremove(ttsFrame,1)
		C_VoiceChat.SpeakText(unpack(tbl))
	else
		ttsFrame:Hide()
	end
end)

-- say something when previous messages have finished
function lib:ttsQueue(text, rate, dynamics, useAltVoice)
	local volume = (dynamics or KUI_MF) * self:getOption("volume")
	if volume > 0  and text and text ~= "" and self:getOption("enabled") then
		if rate == nil or rate > 0 then
			rate = floor((rate or KUI_NORMAL) * self:getOption("speed"))
		end
		if text:sub(1,1) == "<" and not text:sub(1,7) == "<speak>" then
			text = text:gsub("[\<\>]", " -- ")
		end
		tinsert(ttsFrame, {useAltVoice and KUI_VOICE_ALT or KUI_VOICE, text, Enum.VoiceTtsDestination.QueuedLocalPlayback, rate, volume})
		ttsFrame:Show()
	end
end

-- halt any ongoing messages
function lib:ttsStop()
	C_VoiceChat.StopSpeakingText()
end

-- say something immediately, cutting off earlier messages
function lib:ttsInterrupt(...)
	for i=1, #ttsFrame do
		ttsFrame[i] = nil
	end
	self:ttsStop()
	self:ttsQueue(...)
end

local function hideTooltip()
	C_VoiceChat.StopSpeakingText()
	GameTooltip:Hide()
end

function lib:displayTooltip(frame, title, optLine2, optAnchor, optOwner)
	frame:SetScript("OnLeave", hideTooltip)
	GameTooltip:SetOwner(optOwner or frame, optAnchor or "ANCHOR_RIGHT")
	GameTooltip:SetText(title)
	if (optLine2) then
		GameTooltip:AddLine(optLine2, 0.9, 0.9, 0.9)
		title = title .. ": " .. optLine2
		GameTooltip:Show()
	end
	self:ttsInterrupt(title, KUI_QUICK, nil)
end

-------------------------
-- Keybinds (this is temporary code until real keybinds are added)

local function getCurrentModule()
	return shownModules[#shownModules]
end

CreateFrame("Button", "KeyboardUINextGroupButton")
KeyboardUINextGroupButton:SetScript("OnClick", function(__, button, down)
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:NextGroup(), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIPrevGroupButton")
KeyboardUIPrevGroupButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:PrevGroup(), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUINextEntryButton")
KeyboardUINextEntryButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:NextEntry(), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIPrevEntryButton")
KeyboardUIPrevEntryButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:PrevEntry(), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIForwardButton")
KeyboardUIForwardButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		local intro, body, concl = module:Forward()
		module:ttsInterrupt(intro, KUI_QUICK, KUI_MF)
		module:ttsQueue(body, KUI_CASUAL, KUI_MP)
		module:ttsQueue(concl, KUI_NORMAL, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIBackwardButton")
KeyboardUIBackwardButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		local intro, body, concl = module:Backward()
		module:ttsInterrupt(intro, KUI_QUICK, KUI_MF)
		module:ttsQueue(body, KUI_CASUAL, KUI_MP)
		module:ttsQueue(concl, KUI_NORMAL, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoActionButton")
KeyboardUIDoActionButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoAction1Button")
KeyboardUIDoAction1Button:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(1), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoAction2Button")
KeyboardUIDoAction2Button:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(2), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoAction3Button")
KeyboardUIDoAction3Button:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(3), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoAction4Button")
KeyboardUIDoAction4Button:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(4), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIDoAction5Button")
KeyboardUIDoAction5Button:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		module:ttsQueue(module:DoAction(5), KUI_QUICK, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIActionsButton")
KeyboardUIActionsButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		module:ttsStop()
		local title1, title2, title3, title4, title5 = module:Actions()
		local key1, key2, key3, key4, key5 = 
			KeyboardUIOptions.global.bindingDoAction1Button or "Alt-1",
			KeyboardUIOptions.global.bindingDoAction2Button or "Alt-2",
			KeyboardUIOptions.global.bindingDoAction3Button or "Alt-3",
			KeyboardUIOptions.global.bindingDoAction4Button or "Alt-4",
			KeyboardUIOptions.global.bindingDoAction5Button or "Alt-5"
		local text = ""
		if title1 and title1 ~= "" and key1 then
			module:ttsQueue(key1 .. CHAT_HEADER_SUFFIX .. title1)
		end
		if title2 and title2 ~= "" and key2 then
			module:ttsQueue(key2 .. CHAT_HEADER_SUFFIX .. title2)
		end
		if title3 and title3 ~= "" and key3 then
			module:ttsQueue(key3 .. CHAT_HEADER_SUFFIX .. title3)
		end
		if title4 and title4 ~= "" and key4 then
			module:ttsQueue(key4 .. CHAT_HEADER_SUFFIX .. title4)
		end
		if title5 and title5 ~= "" and key5 then
			module:ttsQueue(key5 .. CHAT_HEADER_SUFFIX .. title5)
		end
	end
end)

CreateFrame("Button", "KeyboardUIReadTitleButton")
KeyboardUIReadTitleButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module then
		module:ttsInterrupt(module:RefreshEntry() or "", KUI_NORMAL, KUI_MF)
	end
end)

CreateFrame("Button", "KeyboardUIReadDescriptionButton")
KeyboardUIReadDescriptionButton:SetScript("OnClick", function()
	local module = getCurrentModule()
	if module and module:RefreshEntry() then
		local introduction, body, conclusion = module:GetEntryLongDescription()
		if body then
			module:ttsInterrupt(introduction, KUI_QUICK, KUI_MF)
			module:ttsQueue(body, KUI_CASUAL, KUI_MP)
			module:ttsQueue(conclusion, KUI_NORMAL, KUI_MF)
		else
			module:ttsInterrupt(introduction, KUI_CASUAL, KUI_MF)
		end
	end
end)

_G["BINDING_HEADER_KeyboardUI"] = "Keyboard UI"
_G["BINDING_NAME_CLICK KeyboardUINextGroupButton:LeftButton"] = BROWSER_FORWARD_TOOLTIP
_G["BINDING_NAME_CLICK KeyboardUIPrevGroupButton:LeftButton"] = BROWSER_BACK_TOOLTIP
_G["BINDING_NAME_CLICK KeyboardUINextEntryButton:LeftButton"] = NEXT .. " " .. ENCOUNTER_JOURNAL_ITEM
_G["BINDING_NAME_CLICK KeyboardUIPrevEntryButton:LeftButton"] = PREV .. " " .. ENCOUNTER_JOURNAL_ITEM
_G["BINDING_NAME_CLICK KeyboardUIForwardButton:LeftButton"] = BINDING_NAME_ACTIONWINDOWINCREMENT
_G["BINDING_NAME_CLICK KeyboardUIBackwardButton:LeftButton"] = BINDING_NAME_ACTIONWINDOWDECREMENT
_G["BINDING_NAME_CLICK KeyboardUIDoActionButton:LeftButton"] = SUBMIT .. " / " .. CONTINUE
_G["BINDING_NAME_CLICK KeyboardUIDoAction1Button:LeftButton"] = CHOOSE .. " 1"
_G["BINDING_NAME_CLICK KeyboardUIDoAction2Button:LeftButton"] = CHOOSE .. " 2"
_G["BINDING_NAME_CLICK KeyboardUIDoAction3Button:LeftButton"] = CHOOSE .. " 3"
_G["BINDING_NAME_CLICK KeyboardUIDoAction4Button:LeftButton"] = CHOOSE .. " 4"
_G["BINDING_NAME_CLICK KeyboardUIDoAction5Button:LeftButton"] = CHOOSE .. " 5"
_G["BINDING_NAME_CLICK KeyboardUIActionsButton:LeftButton"] = SAY .. " " .. OPTIONS
_G["BINDING_NAME_CLICK KeyboardUIReadTitleButton:LeftButton"] = SAY .. " " .. NAME
_G["BINDING_NAME_CLICK KeyboardUIReadDescriptionButton:LeftButton"] = SAY .. " " .. DESCRIPTION


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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(__, event)
	if event == "PLAYER_REGEN_ENABLED" then
		for __, funcAndArgs in ipairs(queueDuringCombat) do
			local retOK, msg = pcall(unpack(funcAndArgs))
			if not retOK and msg then
				print("Keyboard UI caught an error: " .. msg)
			end
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

-------------------------
-- Options Menu

local panel = CreateFrame("Frame")
panel.name = "KeyboardUI"
InterfaceOptions_AddCategory(panel)
panel:Hide()	-- important to trigger scrollFrame OnShow()

local kuiOptions = {name = "global", frame = panel, title = TEXT_TO_SPEECH}
KeyboardUI:RegisterModule(kuiOptions)	-- this happens after the panel is added to InterfaceOptions so it has a parent

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
scrollChild:SetWidth(InterfaceOptionsFramePanelContainer:GetWidth()-18)

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
					frame:SetPoint("LEFT", 30, 0)
					frame:SetPoint("TOP", frame.prev or frame.parent, "BOTTOM", 0, -15)
					parent:SetHeight(parent:GetHeight() + frame:GetHeight() + 15)
					scrollChild:SetHeight(scrollChild:GetHeight() + frame:GetHeight() + 15)
					tinsert(frame.parent, frame)
					if frame.parent.next then
						frame.parent.next:SetPoint("TOP", frame, "BOTTOM", 0, 20)
					end
					if frame.parent:IsObjectType("CheckButton") and frame.Enable then
						frame.module:onOptionChanged(frame.parentOption, function(value)
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
		frame:SetPoint("LEFT", 10, 0)
		frame:SetPoint("TOP", frame.prev.last or frame.prev, "BOTTOM", 0, -20)
		parent:SetHeight(parent:GetHeight() + frame:GetHeight() + 20)
		scrollChild:SetHeight(scrollChild:GetHeight() + frame:GetHeight() + 20)
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
		--[[
		
			-- this needs more work.  It isn't a good user experience if tooltips interfere with using the keyboard
		
		frame:SetScript("OnEnter", function()
			modules[1]:displayTooltip(frame, "Mouseover: " .. title, frame:GetChecked() and "Checked " or "Unchecked " .. CHAT_HEADER_SUFFIX .. frame.description, "ANCHOR_BOTTOMRIGHT", panel)
		end)
		--]]
		frame:SetChecked(self:getOption(option))
		frame:SetScript("OnClick", function()
			local checked = frame:GetChecked()
			setTempOption(self, option, checked)
			modules[1]:ttsInterrupt(checked and "Checked." or "Unchecked.", KUI_QUICK, KUI_MP, true)
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
		--[[
		
			-- this needs more work.  It isn't a good user experience if tooltips interfere with using the keyboard
		
		frame:SetScript("OnEnter", function()
			modules[1]:displayTooltip(frame, title, frame.description:format(frame.Text and frame.Text:GetText() or frame:GetValue()), "ANCHOR_BOTTOMRIGHT", panel)
		end)
		--]]
		frame:SetScript("OnValueChanged", function(__, value, userInput)
			if userInput then
				if top then
					frame.Text:SetText(top:format(value))
				end
				setTempOption(self, option, value)
			end
		end)
		frame:HookScript("OnMouseUp", function(w)
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
	modules[1]:panelSlider("volume", VOLUME, "Set the default volume for all Keyboard UI modules, including these interface options.", 0, 100, 25, OFF, "100%", "%d%%")
	modules[1]:panelSlider("speed", SPEED, "Adjust the default seaking rate for all Keyboard UI modules, including these interface options.", 0.8, 1.2, 0.2, "slower", "faster", "%.1f")
	
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
		module:panelCheckButton("enabled", ENABLE .. " " .. module.name, "Enable " .. module.name .. " when " .. (module.frame:GetName() or "it") .. " appears.")
		module:panelSlider("volume", VOLUME, "Set the text to speech volume.", 0, 100, 25, "silent", "100%", "%d%%")
		module:panelSlider("speed", SPEED, "Set the text to speech rate.", 0.8, 1.2, 0.2, "slower", "faster", "%.1f")
		if savedForLater[module] then
			for __, tbl in ipairs(savedForLater) do
				module[tbl[1]](module, select(2,tbl))	--e.g. module["panelCheckButton"](module, ...)
			end
		end
	end
	

	-- now create the panel's functions, because its possible from this point forward for them to be called.
	
	local txtFuncs =
		{
			FontString = function(self) return self:GetText(), self.description end,
			CheckButton = function(self) return self.text:GetText(), self.description end,
			Slider = function(self) return self.text:GetText(), self.description end,
		}

	local currentModule, entry, subEntry = 1, 0, 0

	function kuiOptions:NextGroup()
		if currentModule < #modules then
			currentModule = currentModule + 1
		else
			currentModule = 1
		end
		entry, subEntry = 1, 0
		return txtFuncs.FontString(scrollChild[currentModule][1])
	end

	function kuiOptions:PrevGroup()
		if currentModule > 1 then
			currentModule = currentModule - 1
		else
			currentModule = #modules
		end
		entry, subEntry = 1, 0
		return txtFuncs.FontString(scrollChild[currentModule][1])
	end

	function kuiOptions:NextEntry()
		local parentFrame = scrollChild[currentModule]
		if entry > 0 and #parentFrame[entry] > subEntry and (
			parentFrame[entry]:IsObjectType("CheckButton") and parentFrame[entry]:GetChcked()
			or parentFrame[entry]:IsObjectType("Slider") and parentFrame[entry]:GetValue() > parentFrame[entry]:GetMinMaxValues()
		) then
			subEntry = subEntry + 1
			local frame = parentFrame[entry][subEntry]
			return txtFuncs[frame:GetObjectType()](frame)
		elseif #parentFrame > entry then
			entry, subEntry = entry + 1, 0
			local frame = parentFrame[entry]
			return txtFuncs[frame:GetObjectType()](frame)
		else
			return kuiOptions:NextGroup()
		end
	end

	function kuiOptions:PrevEntry()
		local parentFrame = scrollChild[currentModule]
		if subEntry > 1 then
			subEntry = subEntry - 1
			local frame = parentFrame[entry][subEntry]
			return txtFuncs[frame:GetObjectType()](frame)
		elseif subEntry == 1 then
			subEntry = 0
			local frame = parentFrame[entry]
			return txtFuncs[frame:GetObjectType()](frame)
		elseif entry > 1 then
			entry = entry - 1
			local frame = parentFrame[entry]
			return txtFuncs[frame:GetObjectType()](frame)
		else
			return kuiOptions:PrevGroup()
		end
	end

	function kuiOptions:RefreshEntry()
		if subEntry > 0 then
			local frame = scrollChild[currentModule][entry][subEntry]
			return txtFuncs[frame:GetObjectType()](frame)
		elseif entry > 0 then
			local frame = scrollChild[currentModule][entry]
			return txtFuncs[frame:GetObjectType()](frame)
		else
			return kuiOptions:NextEntry()
		end
	end

	function kuiOptions:GetEntryLongDescription()
		if subEntry > 0 then
			return scrollChild[currentModule][entry][subEntry].description
		elseif entry > 0 then
			return scrollChild[currentModule][entry].description
		end
	end

	function kuiOptions:Forward()
		local frame = subEntry > 0 and scrollChild[currentModule][entry][subEntry] or scrollChild[currentModule][entry]
		if frame:IsObjectType("Slider") then
			local min, max = frame:GetMinMaxValues()
			local value = frame:GetValue()
			local step = frame:GetValueStep()
			if value + step > max then
				setTempOption(frame.module, frame.option, max)
			elseif value < min then
				setTempOption(frame.module, frame.option, min)
			else
				setTempOption(frame.module, frame.option, value + step)
			end
			return frame.Text and frame.Text:GetText() or value
		else
			return self:DoAction()
		end
	end

	function kuiOptions:Backward()
		local frame = subEntry > 0 and scrollChild[currentModule][entry][subEntry] or scrollChild[currentModule][entry]
		if frame:IsObjectType("Slider") then
			local min, max = frame:GetMinMaxValues()
			local value = frame:GetValue()
			local step = frame:GetValueStep()
			if value - step < min then
				setTempOption(frame.module, frame.option, min)
			elseif value > max then
				setTempOption(frame.module, frame.option, max)
			else
				setTempOption(frame.module, frame.option, value - step)
			end
			return frame.Text and frame.Text:GetText() or value
		else
			return self:DoAction()
		end	
	end

	function kuiOptions:DoAction(index)
		local frame = subEntry > 0 and scrollChild[currentModule][entry][subEntry] or scrollChild[currentModule][entry]
		if index == 5 then
			InterfaceOptionsFrameOkay:Click()
		end
		if frame:IsObjectType("FontString") then
			return self:NextEntry()
		elseif frame:IsObjectType("CheckButton") then
			frame:Click()
			return
		elseif frame:IsObjectType("Slider") then
			if index == 1 then
				frame:SetValue(frame:GetMinMaxValues())
				setTempOption(frame.module, frame.option, frame:GetValue())
				return frame.Text and frame.Text:GetText() or frame:GetValue()
			elseif index == 2 then
				frame:SetValue(defaultOptions[frame.module.name][frame.option])
				setTempOption(frame.module, frame.option, frame:GetValue())
				return frame.Text and frame.Text:GetText() or frame:GetValue()
			elseif index == 3 then
				frame:SetValue(select(2, frame:GetMinMaxValues()))
				setTempOption(frame.module, frame.option, frame:GetValue())
				return frame.Text and frame.Text:GetText() or frame:GetValue()
			else
				return self:Actions()
			end
		end
	end

	function kuiOptions:Actions()
		local frame = subEntry > 0 and scrollChild[currentModule][entry][subEntry] or scrollChild[currentModule][entry]
		if frame:IsObjectType("FontString") then
			return "Advance to the next setting", nil, nil, nil, "Save and exit options"
		elseif frame:IsObjectType("CheckButton") then
			return frame:GetChecked() and "Remove checkmark" or "Add checkmark", nil, nil, "Save and exit options"
		elseif frame:IsObjectType("Slider") then
			return "Lowest value", "Default value", "Highest value", nil, "Save and exit options"
		end
	end

end)	-- end of scrollChild:OnShow()


-------------------------
-- Slash command

function SlashCmdList.KEYBOARDUI(msg)
	InterfaceAddOnsList_Update()	-- https://github.com/Stanzilla/WoWUIBugs/issues/89
	InterfaceOptionsFrame_OpenToCategory(panel)
	
	-- give the user a hint
	modules[1]:ttsStop()
	local hintText = [=[<speak>Keyboard UI Options.  Keyboard UI has various keybindings which activate only when a Keyboard-enabled window appears.
<silence msec="500" />The first keybinds are for movement: %1$s, %2$s, %5$s and %6$s.  You always start at the top of a window, so %1$s moves to the next option and %2$s moves back one.  It is also possible to jump to sections with %3$s and %4$s.
<silence msec="500" />Next, once you have reached the desired option, use %5$s, %6$s and %7$s to change it.  If its a number on a sliding scale, move the slider with %5$s and %6$s.  If its a checkbutton, toggle it with %7$s.  If its a more complex option with many actions, use %5$s and %6$s to cycle through the possibilities and %7$s to make the selection.
<silence msec="500" />The next set of keybinds are hot keys such as %11$s and %10$s.  These hot keys change meaning depending which option you are at.  At any time, press %8$s to read out the list of available hot keys.  Of note, %10$s is the hot key to save settings and exit.
<silence msec="500" />While you are at an option, another thing you may query it for more detail.  Press %9$s to request a full-length description. In fact, if you are unsure of what to do, both %9$s and %8$s are always safe choices because they simply read information without changing anything.</speak>]=]
	
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
		KeyboardUIOptions.global.bindingDoAction1Button -- 11
	), KUI_NORMAL, KUI_MP)
end
SLASH_KEYBOARDUI1 = "/keyboardui"
SLASH_KEYBOARDUI2 = "/kui"