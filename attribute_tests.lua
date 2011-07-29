local addon = {L = {}}
SlashCmdList = {}
loadfile("Clique.lua")("Clique", addon)
loadfile("Utils.lua")("Clique", addon)

local tests = {}
local function printf(fmt, ...)
	print(fmt:format(...))
end

local prelude = {
	cset = [===[
local inCombat = control:GetAttribute('inCombat')
local setupbutton = self:GetFrameRef('cliquesetup_button')
local button = setupbutton or self
local name = button:GetName()
if blacklist[name] then return end]===],
	crem = [===[
local inCombat = control:GetAttribute('inCombat')
local setupbutton = self:GetFrameRef('cliquesetup_button')
local button = setupbutton or self
local name = button:GetName()
if blacklist[name] then return end]===],
	bset = [===[
local button = self
local name = button:GetName()
if danglingButton then control:RunFor(danglingButton, control:GetAttribute('setup_onleave')) end
if blacklist[name] then return end
danglingButton = button]===],
	brem = [===[
local button = self
local name = button:GetName()
if blacklist[name] then return end
danglingButton = nil]===],
	gcset = [[
local inCombat = control:GetAttribute('inCombat')
local setupbutton = self:GetFrameRef('cliquesetup_button')
local button = setupbutton or self]],
	gcrem = [[
local inCombat = control:GetAttribute('inCombat')
local setupbutton = self:GetFrameRef('cliquesetup_button')
local button = setupbutton or self]],
	gbset = [[]],
	gbrem = [[]],
}

-- Check a test
function check(result, test, atype)
	local pass = true
	local pre, rest = result:sub(1, #prelude[atype]), result:sub(#prelude[atype]+1, -1)
	local expected = tostring(test[atype])
	-- Trim 'rest' to get rid of any spaces at start
	rest = rest:match("^%s*(.-)$")

	-- Check to see if the prelude matches
	if pre ~= prelude[atype] then
		printf("[%s] prelude[%s] mismatch. Expected:\n%s\nGot:\n%s", tostring(test.name), tostring(atype), tostring(prelude[atype]), tostring(pre))
		print(#pre, #prelude[atype], pre == prelude[atype])
		pass = false
	end
	if expected ~= rest then
		printf("[%s] %s mismatch. Expected:\n%s\nGot:\n%s", tostring(test.name), tostring(atype), tostring(test[atype]), tostring(rest))
		print(#expected, #rest, expected ~= rest)
		pass = false
	end

	if not pass then
		error(string.format("Test [%s] failed", test.name))
	end
end

local test_mt = {__index = function(t,k)
	return ""
end}

function addtest(test)
	setmetatable(test, test_mt)
	tests[#tests+1] = test
end

-- Test with no bindings other than target/menu, just for sanity
addtest{
	name = "No bindings",
	bindings = {
		{ key = "BUTTON1", type = "target", unit = "mouseover", sets = { default = true } },
		{ key = "BUTTON2", type = "menu", sets = { default = true } },
	},
	cset = [[
button:SetAttribute("type1", "target")
button:SetAttribute("type2", "menu")]],
	crem = [[
button:SetAttribute("type1", nil)
button:SetAttribute("type2", nil)]],
}

-- Add a binding of each input type, click, key, etc.
addtest{
	name = "Input types",
	bindings = {
		-- Mouse button
		{ key = "BUTTON1", type = "macro", macrotext="button", sets = { default = true } },
		-- Key binding
		{ key = "F", type = "macro", macrotext="key", sets = { default = true } },
		-- Special escaped keys
		{ key = "DASH", type = "macro", macrotext="dash", sets = { default = true } },
		{ key = "BACKSLASH", type = "macro", macrotext="backslash", sets = { default = true } },
		{ key = "DOUBLEQUOTE", type = "macro", macrotext="doublequote", sets = { default = true } },
	},
	cset = [[
button:SetAttribute("type1", "macro")
button:SetAttribute("macrotext1", "button")
button:SetAttribute("type-cliquebuttonBACKSLASH", "macro")
button:SetAttribute("macrotext-cliquebuttonBACKSLASH", "backslash")
button:SetAttribute("type-cliquebuttonDASH", "macro")
button:SetAttribute("macrotext-cliquebuttonDASH", "dash")
button:SetAttribute("type-cliquebuttonF", "macro")
button:SetAttribute("macrotext-cliquebuttonF", "key")
button:SetAttribute("type-cliquebuttonDOUBLEQUOTE", "macro")
button:SetAttribute("macrotext-cliquebuttonDOUBLEQUOTE", "doublequote")]],
	crem = [[
button:SetAttribute("type1", nil)
button:SetAttribute("macrotext1", nil)
button:SetAttribute("type-cliquebuttonBACKSLASH", nil)
button:SetAttribute("macrotext-cliquebuttonBACKSLASH", nil)
button:SetAttribute("type-cliquebuttonDASH", nil)
button:SetAttribute("macrotext-cliquebuttonDASH", nil)
button:SetAttribute("type-cliquebuttonF", nil)
button:SetAttribute("macrotext-cliquebuttonF", nil)
button:SetAttribute("type-cliquebuttonDOUBLEQUOTE", nil)
button:SetAttribute("macrotext-cliquebuttonDOUBLEQUOTE", nil)]],
	bset = [[
self:SetBindingClick(true, "\\", self, "cliquebuttonBACKSLASH");
self:SetBindingClick(true, "-", self, "cliquebuttonDASH");
self:SetBindingClick(true, "F", self, "cliquebuttonF");
self:SetBindingClick(true, "\"", self, "cliquebuttonDOUBLEQUOTE");]],
	brem = [[
self:ClearBinding("\\");
self:ClearBinding("-");
self:ClearBinding("F");
self:ClearBinding("\"");]],
}

-- Test global bindings, button and key
addtest{
	name = "Global bindings",
	bindings = {
		-- Mouse button
		{ key = "BUTTON5", type = "macro", macrotext="button", sets = { global = true } },
		-- Key binding
		{ key = "F", type = "macro", macrotext="key", sets = { global = true } },
	},
	gcset = [[
button:SetAttribute("type-cliquemouse5", "macro")
button:SetAttribute("macrotext-cliquemouse5", "button")
button:SetAttribute("type-cliquebuttonF", "macro")
button:SetAttribute("macrotext-cliquebuttonF", "key")]],
	gcrem = [[
button:SetAttribute("type-cliquemouse5", nil)
button:SetAttribute("macrotext-cliquemouse5", nil)
button:SetAttribute("type-cliquebuttonF", nil)
button:SetAttribute("macrotext-cliquebuttonF", nil)]],
	gbset = [[
self:SetBindingClick(true, "BUTTON5", self, "cliquemouse5");
self:SetBindingClick(true, "F", self, "cliquebuttonF");]],
	gbrem = [[
self:ClearBinding("BUTTON5");
self:ClearBinding("F");]],
}

-- Test hovercast bindings, button and key
-- Test global bindings, button and key
addtest{
	name = "Hovercast bindings",
	bindings = {
		-- Mouse button
		{ key = "BUTTON5", type = "macro", macrotext="button", sets = { hovercast = true } },
		-- Key binding
		{ key = "F", type = "macro", macrotext="key", sets = { hovercast = true } },
	},
	gcset = [[
button:SetAttribute("unit-cliquemouse5", "mouseover")
button:SetAttribute("type-cliquemouse5", "macro")
button:SetAttribute("macrotext-cliquemouse5", "button")
button:SetAttribute("unit-cliquebuttonF", "mouseover")
button:SetAttribute("type-cliquebuttonF", "macro")
button:SetAttribute("macrotext-cliquebuttonF", "key")]],
	gcrem = [[
button:SetAttribute("unit-cliquemouse5", nil)
button:SetAttribute("type-cliquemouse5", nil)
button:SetAttribute("macrotext-cliquemouse5", nil)
button:SetAttribute("unit-cliquebuttonF", nil)
button:SetAttribute("type-cliquebuttonF", nil)
button:SetAttribute("macrotext-cliquebuttonF", nil)]],
	gbset = [[
self:SetBindingClick(true, "BUTTON5", self, "cliquemouse5");
self:SetBindingClick(true, "F", self, "cliquebuttonF");]],
	gbrem = [[
self:ClearBinding("BUTTON5");
self:ClearBinding("F");]],
}

-- Test modified bindings, button and key
addtest{
	name = "Mofidied bindings",
	bindings = {
		-- Mouse button
		{ key = "BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "ALT-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "ALT-SHIFT-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "ALT-CTRL-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "ALT-CTRL-SHIFT-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "CTRL-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "CTRL-SHIFT-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		{ key = "SHIFT-BUTTON5", type = "macro", macrotext="button", sets = { default = true } },
		-- Key binding
		{ key = "F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "ALT-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "ALT-SHIFT-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "ALT-CTRL-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "ALT-CTRL-SHIFT-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "CTRL-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "CTRL-SHIFT-F", type = "macro", macrotext="key", sets = { default = true } },
		{ key = "SHIFT-F", type = "macro", macrotext="key", sets = { default = true } },
	},
	cset = [[
button:SetAttribute("type5", "macro")
button:SetAttribute("macrotext5", "button")
button:SetAttribute("type-cliquebuttonaltshiftF", "macro")
button:SetAttribute("macrotext-cliquebuttonaltshiftF", "key")
button:SetAttribute("type-cliquebuttonaltF", "macro")
button:SetAttribute("macrotext-cliquebuttonaltF", "key")
button:SetAttribute("type-cliquebuttonF", "macro")
button:SetAttribute("macrotext-cliquebuttonF", "key")
button:SetAttribute("type-cliquebuttonaltctrlF", "macro")
button:SetAttribute("macrotext-cliquebuttonaltctrlF", "key")
button:SetAttribute("type-cliquebuttonctrlF", "macro")
button:SetAttribute("macrotext-cliquebuttonctrlF", "key")
button:SetAttribute("type-cliquebuttonaltctrlshiftF", "macro")
button:SetAttribute("macrotext-cliquebuttonaltctrlshiftF", "key")
button:SetAttribute("type-cliquebuttonctrlshiftF", "macro")
button:SetAttribute("macrotext-cliquebuttonctrlshiftF", "key")
button:SetAttribute("shift-type5", "macro")
button:SetAttribute("shift-macrotext5", "button")
button:SetAttribute("ctrl-type5", "macro")
button:SetAttribute("ctrl-macrotext5", "button")
button:SetAttribute("alt-type5", "macro")
button:SetAttribute("alt-macrotext5", "button")
button:SetAttribute("ctrl-shift-type5", "macro")
button:SetAttribute("ctrl-shift-macrotext5", "button")
button:SetAttribute("alt-shift-type5", "macro")
button:SetAttribute("alt-shift-macrotext5", "button")
button:SetAttribute("alt-ctrl-shift-type5", "macro")
button:SetAttribute("alt-ctrl-shift-macrotext5", "button")
button:SetAttribute("alt-ctrl-type5", "macro")
button:SetAttribute("alt-ctrl-macrotext5", "button")
button:SetAttribute("type-cliquebuttonshiftF", "macro")
button:SetAttribute("macrotext-cliquebuttonshiftF", "key")]],
	crem = [[
button:SetAttribute("type5", nil)
button:SetAttribute("macrotext5", nil)
button:SetAttribute("type-cliquebuttonaltshiftF", nil)
button:SetAttribute("macrotext-cliquebuttonaltshiftF", nil)
button:SetAttribute("type-cliquebuttonaltF", nil)
button:SetAttribute("macrotext-cliquebuttonaltF", nil)
button:SetAttribute("type-cliquebuttonF", nil)
button:SetAttribute("macrotext-cliquebuttonF", nil)
button:SetAttribute("type-cliquebuttonaltctrlF", nil)
button:SetAttribute("macrotext-cliquebuttonaltctrlF", nil)
button:SetAttribute("type-cliquebuttonctrlF", nil)
button:SetAttribute("macrotext-cliquebuttonctrlF", nil)
button:SetAttribute("type-cliquebuttonaltctrlshiftF", nil)
button:SetAttribute("macrotext-cliquebuttonaltctrlshiftF", nil)
button:SetAttribute("type-cliquebuttonctrlshiftF", nil)
button:SetAttribute("macrotext-cliquebuttonctrlshiftF", nil)
button:SetAttribute("shift-type5", nil)
button:SetAttribute("shift-macrotext5", nil)
button:SetAttribute("ctrl-type5", nil)
button:SetAttribute("ctrl-macrotext5", nil)
button:SetAttribute("alt-type5", nil)
button:SetAttribute("alt-macrotext5", nil)
button:SetAttribute("ctrl-shift-type5", nil)
button:SetAttribute("ctrl-shift-macrotext5", nil)
button:SetAttribute("alt-shift-type5", nil)
button:SetAttribute("alt-shift-macrotext5", nil)
button:SetAttribute("alt-ctrl-shift-type5", nil)
button:SetAttribute("alt-ctrl-shift-macrotext5", nil)
button:SetAttribute("alt-ctrl-type5", nil)
button:SetAttribute("alt-ctrl-macrotext5", nil)
button:SetAttribute("type-cliquebuttonshiftF", nil)
button:SetAttribute("macrotext-cliquebuttonshiftF", nil)]],
	bset = [[
self:SetBindingClick(true, "ALT-SHIFT-F", self, "cliquebuttonaltshiftF");
self:SetBindingClick(true, "ALT-F", self, "cliquebuttonaltF");
self:SetBindingClick(true, "F", self, "cliquebuttonF");
self:SetBindingClick(true, "ALT-CTRL-F", self, "cliquebuttonaltctrlF");
self:SetBindingClick(true, "CTRL-F", self, "cliquebuttonctrlF");
self:SetBindingClick(true, "ALT-CTRL-SHIFT-F", self, "cliquebuttonaltctrlshiftF");
self:SetBindingClick(true, "CTRL-SHIFT-F", self, "cliquebuttonctrlshiftF");
self:SetBindingClick(true, "SHIFT-F", self, "cliquebuttonshiftF");]],
	brem = [[
self:ClearBinding("ALT-SHIFT-F");
self:ClearBinding("ALT-F");
self:ClearBinding("F");
self:ClearBinding("ALT-CTRL-F");
self:ClearBinding("CTRL-F");
self:ClearBinding("ALT-CTRL-SHIFT-F");
self:ClearBinding("CTRL-SHIFT-F");
self:ClearBinding("SHIFT-F");]],
}

for idx, test in ipairs(tests) do
	addon.bindings = test.bindings
	local cset, crem = addon:GetClickAttributes()
	local bset, brem = addon:GetBindingAttributes()
	local gcset, gcrem = addon:GetClickAttributes(true)
	local gbset, gbrem = addon:GetBindingAttributes(true)

	check(cset, test, "cset")
	check(crem, test, "crem")
	check(bset, test, "bset")
	check(brem, test, "brem")
	check(gcset, test, "gcset")
	check(gcrem, test, "gcrem")
	check(gbset, test, "gbset")
	check(gbrem, test, "gbrem")
end

print("Passed " .. #tests .. " tests")
