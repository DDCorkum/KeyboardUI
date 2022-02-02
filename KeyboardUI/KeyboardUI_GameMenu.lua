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
	local module = {name = "GameMenu", title = MAINMENU_BUTTON, frame = CreateFrame("Frame", nil, GameMenuFrame)}

	KeyboardUI:RegisterModule(module)

	local position = 0
	
	local buttons = {}
	
	for __, frame in ipairs({GameMenuFrame:GetChildren()}) do
		if frame:IsObjectType("Button") and frame:IsShown() then
			tinsert(buttons, frame)
		end
	end

	local function assertSecureKeybinds()
		ClearOverrideBindings(module.frame)
		SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction1Button"), "GameMenuButtonLogout")
		SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoAction2Button"), "GameMenuButtonQuit")
		if buttons[position] then
			SetOverrideBindingClick(module.frame, true, module:getOption("bindingDoActionButton"), buttons[position]:GetName())
		end
	end
	
	local function removeSecureKeybinds()
		ClearOverrideBindings(module.frame)
	end

	function module:GainFocus()
		assertSecureKeybinds()
		module:ttsYield("Game Menu")
	end
	
	function module:LoseFocus()
		removeSecureKeybinds()
	end
	
	function module:NextEntry()
		if position < #buttons then
			position = position + 1
		end
		assertSecureKeybinds()
		return buttons[position]:GetText()
	end
	
	function module:PrevEntry()
		if position > 1 then
			position = position - 1
		end
		assertSecureKeybinds()
		return buttons[position]:GetText()
	end
	
	function module:RefreshEntry()
		return position > 0
	end
	
	function module:Forward()
		-- nop()
	end
	
	function module:Backward()
		-- nop()
	end
	
	function module:Actions()
		return GameMenuButtonLogout:GetText(), GameMenuButtonQuit:GetText()
	end
	
	function module:DoAction(index)
		if position > 0 and not index then
			buttons[position]:Click()
		end
	end

end -- end of GameMenu

do

	local module = {name = "InterfaceOptions", title = INTERFACE_OPTIONS, frame = CreateFrame("Frame", nil, InterfaceOptionsFrame)}

end