--[[
  K2 CODE SNIPER V2 — notifier + capture
  - "code" / "code is" / "use code" / "riddle is" = NOTIFIER only (never types that line)
  - Actual code/riddle is taken from the NEXT message after arm
  - Reset Input clears queue + collected + arm
  - Sammy filter in Settings
]]

repeat task.wait() until game:IsLoaded()
-- Allow re-execute: wipe previous GUI if still present
pcall(function()
	local old = getgenv().K2CodeSniperGui
	if old and old.Parent then old:Destroy() end
end)
getgenv().K2CodeSniperV2 = true

if not table.clear then function table.clear(t) for k in pairs(t) do t[k]=nil end end end

_G.ScriptEnabled = true
_G.AutoWriteEnabled = false
_G.AutoSubmitEnabled = false
_G.RiddleSolverEnabled = false
_G.SammyFilterEnabled = true
_G.SubmitAfterCount = 1
_G.SubmitAttempts = 3
_G.AnchorEnabled = false
_G.AutoBuyEnabled = false

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Theme = {
	Void = Color3.fromRGB(3, 8, 14),
	Panel = Color3.fromRGB(10, 18, 28),
	PanelSoft = Color3.fromRGB(16, 28, 42),
	Card = Color3.fromRGB(14, 24, 38),
	Cyan = Color3.fromRGB(170, 230, 230),
	Teal = Color3.fromRGB(70, 190, 170),
	Violet = Color3.fromRGB(130, 140, 200),
	Green = Color3.fromRGB(110, 230, 180),
	Amber = Color3.fromRGB(255, 190, 90),
	Red = Color3.fromRGB(255, 110, 120),
	Text = Color3.fromRGB(230, 245, 245),
	Muted = Color3.fromRGB(130, 155, 165),
	ToggleOff = Color3.fromRGB(35, 50, 60),
}
local FT, FB, FM = Enum.Font.GothamBold, Enum.Font.Gotham, Enum.Font.GothamMedium
local TIQ = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TIS = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TIB = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TIL = TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
	return c
end
local function stroke(p, col, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or Theme.Cyan
	s.Thickness = th or 1
	s.Transparency = tr or 0.4
	s.Parent = p
	return s
end

local pendingQueue, pendingSeen, collectedCodes, collectedSeen = {}, {}, {}, {}
local writeBusy = false
local ScreenGui, MainFrame, Orb
local StatusDot, StatusTitle, StatusSub, QueueLabel, CollectedLabel, activityHost, sammyLogHost
local ActivityList = {}
local currentTab = "Main"
local isMinimized = false
local introDone = false

-- capture mode: nil | "code" | "riddle"
local captureMode = nil
local captureUntil = 0
local bufferedParts = {}
local lastSammyText, lastSammyAt = "", 0
local lastQueuedAt = 0

local function pushActivity(text, color)
	if not activityHost then return end
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -4, 0, 14)
	row.BackgroundTransparency = 1
	row.Font = FM
	row.TextSize = 9
	row.TextColor3 = color or Theme.Muted
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = "●  " .. text
	row.TextTransparency = 1
	row.Parent = activityHost
	table.insert(ActivityList, 1, row)
	while #ActivityList > 4 do
		local o = table.remove(ActivityList)
		if o then o:Destroy() end
	end
	for i, r in ipairs(ActivityList) do
		r.LayoutOrder = i
		TS:Create(r, TIS, { TextTransparency = math.min(0.1 + (i - 1) * 0.18, 0.75) }):Play()
	end
end

local function pushSammyLog(text)
	-- Sammy log panel removed; keep no-op so callers stay valid
	return
end

local function setStatus(title, sub, mode)
	if StatusTitle then StatusTitle.Text = title end
	if StatusSub then StatusSub.Text = sub or "" end
	if StatusDot then
		local c = Theme.Cyan
		if mode == "ok" then c = Theme.Green
		elseif mode == "err" then c = Theme.Red
		elseif mode == "wait" then c = Theme.Muted
		elseif mode == "arm" then c = Theme.Amber
		end
		StatusDot.BackgroundColor3 = c
	end
end

local RIDDLE_ANSWERS = {
	["10th machine"] = "NEWYEARSMACHINE", ["10th mutation"] = "PHANTOM",
	["11th machine"] = "DUELSMACHINE", ["11th mutation"] = "CRYSTAL",
	["12th machine"] = "CUPIDSMACHINE", ["13th machine"] = "TRADEMACHINE",
	["14th machine"] = "DIVINEFUSE", ["15th machine"] = "EGGINCUBATOR",
	["16th machine"] = "CYBERCRAFTMACHINE", ["17th machine"] = "SUMMERFUSE",
	["18th machine"] = "LOSTRADERS", ["1st machine"] = "RAINBOWMACHINE",
	["1st mutation"] = "BLOODROT", ["1st trait"] = "LIGHTNING", ["1st trait created"] = "LIGHTNING",
	["2nd machine"] = "BUBBLEGUMMACHINE", ["2nd mutation"] = "CANDY",
	["3rd machine"] = "FUSEMACHINE", ["3rd mutation"] = "LAVA",
	["4th machine"] = "CRAFTMACHINE", ["4th mutation"] = "GALAXY",
	["5th machine"] = "WITCHFUSE", ["5th mutation"] = "YINYANG",
	["67"] = "67", ["6th machine"] = "BRAINROTDEALER", ["6th mutation"] = "RADIOACTIVE",
	["7th machine"] = "BRAINROTTRADER", ["7th mutation"] = "CURSED",
	["8th machine"] = "SANTASFUSE", ["8th mutation"] = "DIVINE",
	["9th machine"] = "SANTASSHOP", ["9th mutation"] = "CYBER",
	["age"] = "24", ["angelic"] = "DIVINE", ["angelic mutation"] = "DIVINE",
	["best brainrot"] = "STRAWBERRYELEPHANT", ["best mutation"] = "DIVINE",
	["birth day"] = "FRIDAY", ["birth month"] = "FEBRUARY", ["birth year"] = "2002",
	["birthday"] = "FRIDAY", ["birthplace"] = "ALGERIA",
	["black and white"] = "GALAXY", ["black mutation"] = "GALAXY",
	["born on"] = "FRIDAY", ["born year"] = "2002",
	["city"] = "SAOPAULO", ["color"] = "BLUE", ["color is blue"] = "BLUE",
	["common rarity"] = "COMMON", ["country"] = "BRAZIL", ["created on"] = "FRIDAY",
	["creator"] = "SAMMY", ["creator name"] = "SAMMY", ["creator real name"] = "SAMMY",
	["creator twice"] = "SAMMYSAMMY", ["cursed mutation"] = "CURSED",
	["date made"] = "MAY162025", ["day born"] = "FRIDAY", ["day i was born"] = "FRIDAY",
	["day sab was made"] = "FRIDAY", ["day sab was released"] = "FRIDAY",
	["divine mutation"] = "DIVINE", ["eighteenth machine"] = "LOSTRADERS",
	["eighth machine"] = "SANTASFUSE", ["eleventh machine"] = "DUELSMACHINE",
	["evil"] = "CURSED", ["evil mutation"] = "CURSED",
	["fav animal"] = "SPIDER", ["fav color"] = "BLUE", ["fav color is blue"] = "BLUE",
	["fav food"] = "PIZZA", ["fav football player"] = "FOOTBALL", ["fav game"] = "ROBLOX",
	["fav player"] = "FOOTBALL", ["fav sport"] = "FOOTBALL",
	["favorite animal"] = "SPIDER", ["favorite color"] = "BLUE", ["favorite color twice"] = "BLUEBLUE",
	["favorite food"] = "PIZZA", ["favorite food twice"] = "PIZZAPIZZA",
	["favorite game"] = "ROBLOX", ["favorite player"] = "FOOTBALL",
	["favorite sport"] = "FOOTBALL", ["favorite sport twice"] = "FOOTBALLFOOTBALL",
	["favourite color"] = "BLUE", ["fifteenth machine"] = "EGGINCUBATOR",
	["fifth machine"] = "WITCHFUSE", ["first machine"] = "RAINBOWMACHINE",
	["first mutation"] = "BLOODROT", ["first trait"] = "LIGHTNING", ["first trait created"] = "LIGHTNING",
	["food"] = "PIZZA", ["football player"] = "FOOTBALL",
	["fourteenth machine"] = "DIVINEFUSE", ["fourth machine"] = "CRAFTMACHINE",
	["full name"] = "STEALABRAINROT", ["funny number"] = "67",
	["game created on"] = "FRIDAY", ["game creation day"] = "FRIDAY", ["game made on"] = "FRIDAY",
	["game name"] = "STEALABRAINROT", ["game release"] = "MAY162025",
	["game release date"] = "MAY162025", ["game released"] = "MAY162025",
	["good mutation"] = "DIVINE", ["green"] = "RADIOACTIVE", ["green mutation"] = "RADIOACTIVE",
	["headless horseman"] = "LOSTRADERS", ["highest rarity"] = "OG",
	["how old am i"] = "24", ["how old is sammy"] = "24",
	["latest mutation"] = "CRYSTAL", ["lightning"] = "LIGHTNING", ["lightning trait"] = "LIGHTNING",
	["lowest rarity"] = "COMMON", ["molten"] = "MOLTEN", ["molten mutation"] = "MOLTEN",
	["month born"] = "FEBRUARY", ["month i was born"] = "FEBRUARY", ["month sab was made"] = "MAY",
	["most recent"] = "CRYSTAL", ["most recent mutation"] = "CRYSTAL",
	["my age"] = "24", ["my age 2 times"] = "2424", ["my age 3 times"] = "242424", ["my age twice"] = "2424",
	["my animal"] = "SPIDER", ["my cat's name"] = "NOVA", ["my cats name"] = "NOVA",
	["my city"] = "SAOPAULO", ["my color"] = "BLUE", ["my color is blue"] = "BLUE",
	["my country"] = "BRAZIL", ["my food"] = "PIZZA",
	["my name"] = "SAMMY", ["what is my name"] = "SAMMY", ["whats my name"] = "SAMMY", ["what's my name"] = "SAMMY",
	["my name 2 times"] = "SAMMYSAMMY", ["my name 3 times"] = "SAMMYSAMMYSAMMY", ["my name twice"] = "SAMMYSAMMY",
	["my nationality"] = "BRAZILIAN", ["my pet"] = "SPIDER", ["my real name"] = "SAMMY",
	["my roblox username"] = "SPYDERSAMMY", ["my sport"] = "FOOTBALL", ["my state"] = "SAOPAULO",
	["my username"] = "SPYDERSAMMY", ["my youtube"] = "SPYDERSAMMY",
	["name of the game"] = "STEALABRAINROT", ["name twice"] = "SAMMYSAMMY",
	["nationality"] = "BRAZILIAN", ["newest mutation"] = "CRYSTAL", ["ninth machine"] = "SANTASSHOP",
	["orange"] = "MOLTEN", ["orange mutation"] = "MOLTEN",
	["owner"] = "SAMMY", ["owner real name"] = "SAMMY", ["owner twice"] = "SAMMYSAMMY",
	["purple"] = "GALAXY", ["purple mutation"] = "GALAXY",
	["rarest"] = "LOSTRADERS", ["rarest brainrot"] = "LOSTRADERS", ["rarest rarity"] = "OG",
	["real name"] = "SAMMY", ["red"] = "CURSED", ["red mutation"] = "CURSED",
	["release date"] = "MAY162025", ["release month"] = "MAY", ["release year"] = "2025",
	["roblox name"] = "SPYDERSAMMY", ["roblox username"] = "SPYDERSAMMY", ["ronaldo"] = "FOOTBALL",
	["sab"] = "STEALABRAINROT", ["sab made on"] = "FRIDAY", ["sab release"] = "MAY162025",
	["sab release day"] = "FRIDAY", ["sab release month"] = "MAY", ["sab released"] = "MAY162025",
	["sab stands for"] = "STEALABRAINROT",
	["sammy age"] = "24", ["sammy city"] = "SAOPAULO", ["sammy color"] = "BLUE",
	["sammy color is blue"] = "BLUE", ["sammy country"] = "BRAZIL", ["sammy location"] = "BRAZIL",
	["sammy nationality"] = "BRAZILIAN", ["sammy real name"] = "SAMMY",
	["sammy roblox name"] = "SPYDERSAMMY", ["sammy state"] = "SAOPAULO",
	["sammy username"] = "SPYDERSAMMY", ["sammy youtube"] = "SPYDERSAMMY", ["sammys real name"] = "SAMMY",
	["second machine"] = "BUBBLEGUMMACHINE", ["second mutation"] = "CANDY",
	["seventeenth machine"] = "SUMMERFUSE", ["seventh machine"] = "BRAINROTTRADER",
	["sixteenth machine"] = "CYBERCRAFTMACHINE", ["sixth machine"] = "BRAINROTDEALER",
	["social media"] = "YOUTUBE", ["special number"] = "67", ["sport"] = "FOOTBALL", ["state"] = "SAOPAULO",
	["struck by lightning"] = "LIGHTNING", ["tenth machine"] = "NEWYEARSMACHINE",
	["third machine"] = "FUSEMACHINE", ["third mutation"] = "LAVA", ["thirteenth machine"] = "TRADEMACHINE",
	["top mutation"] = "DIVINE", ["top rarity"] = "OG", ["trait from lightning"] = "LIGHTNING",
	["turns black"] = "GALAXY", ["turns green"] = "RADIOACTIVE", ["turns orange"] = "MOLTEN",
	["turns purple"] = "GALAXY", ["turns red"] = "CURSED", ["turns yellow"] = "DIVINE",
	["twelfth machine"] = "CUPIDSMACHINE", ["unobtainable"] = "STRAWBERRYELEPHANT",
	["username"] = "SPYDERSAMMY", ["what is my cats name"] = "NOVA",
	["when made"] = "MAY162025", ["when was sab created"] = "MAY162025",
	["when was sab made"] = "MAY162025", ["when was sab released"] = "MAY162025",
	["where am i from"] = "BRAZIL", ["where do i live"] = "BRAZIL", ["where does sammy live"] = "BRAZIL",
	["where i was born"] = "ALGERIA", ["where is sammy from"] = "BRAZIL",
	["where was i born"] = "ALGERIA", ["where was i born at"] = "ALGERIA",
	["who created sab"] = "SAMMY", ["who is the owner"] = "SAMMY", ["who made sab"] = "SAMMY", ["who owns sab"] = "SAMMY",
	["year born"] = "2002", ["year created"] = "2025", ["year i was born"] = "2002",
	["year made"] = "2025", ["year of sab"] = "2025", ["year sab was created"] = "2025", ["year sab was made"] = "2025",
	["year we are on"] = "2026", ["year we're on"] = "2026", ["year were on"] = "2026",
	["yellow"] = "DIVINE", ["yellow mutation"] = "DIVINE", ["youtube channel"] = "SPYDERSAMMY",
}

local sortedRiddleKeys
local function getSortedRiddleKeys()
	if sortedRiddleKeys then return sortedRiddleKeys end
	sortedRiddleKeys = {}
	for k in pairs(RIDDLE_ANSWERS) do table.insert(sortedRiddleKeys, k) end
	table.sort(sortedRiddleKeys, function(a, b) return #a > #b end)
	return sortedRiddleKeys
end

local function solveRiddle(raw)
	local normalized = tostring(raw or ""):lower():gsub("[^%w]", "")
	if normalized == "" then return nil end
	local pieces, remaining, guard = {}, normalized, 0
	local ordered = getSortedRiddleKeys()
	while #remaining > 0 and guard < 30 do
		guard += 1
		local bestFirst, bestLast, bestInstr = nil, nil, nil
		for _, instruction in ipairs(ordered) do
			local needle = instruction:lower():gsub("[^%w]", "")
			if #needle >= 2 then
				local first, last = remaining:find(needle, 1, true)
				if first and first <= 10 then
					if not bestFirst or first < bestFirst or (first == bestFirst and #needle > #(bestInstr or "")) then
						bestFirst, bestLast, bestInstr = first, last, instruction
					end
				end
			end
		end
		if not bestInstr then
			remaining = remaining:sub(2)
		else
			local answer = RIDDLE_ANSWERS[bestInstr]
			local after = remaining:sub(bestLast + 1)
			local repeatCount = 1
			if after:sub(1, 5) == "twice" then
				repeatCount = 2
				after = after:sub(6)
			else
				local amount = after:match("^(%d+)times")
				if amount then
					repeatCount = tonumber(amount) or 1
					after = after:gsub("^%d+times", "", 1)
				end
			end
			table.insert(pieces, string.rep(answer, repeatCount))
			remaining = after
		end
	end
	if #pieces == 0 then return nil end
	return table.concat(pieces, "")
end

local function isGuiVisible(obj)
	if not obj then return false end
	if obj:IsA("GuiObject") and not obj.Visible then return false end
	local c = obj.Parent
	while c do
		if c:IsA("GuiObject") and not c.Visible then return false end
		if c:IsA("ScreenGui") and not c.Enabled then return false end
		c = c.Parent
	end
	return true
end

local function formatCode(code)
	return string.upper(tostring(code or ""):gsub("%s+", ""))
end

local function looksLikeCode(token)
	if not token or #token < 3 or #token > 48 then return false end
	if token:find("%s") then return false end
	local low = token:lower()
	if low == "code" or low == "riddle" or low == "the" or low == "is" or low == "use" or low == "answer" then
		return false
	end
	-- reject pure short numbers that look like riddle answers being misread? allow alphanumeric
	return token:match("^[%w%-%_]+$") ~= nil
end

local function extractCodesFromText(text)
	local found = {}
	if not text then return found end
	local trimmed = (text:match("^%s*(.-)%s*$") or ""):gsub("<[^>]->", "")
	-- strip trigger prefixes so "code is ABC" → ABC
	local stripped = trimmed
		:gsub("^[Tt]he%s+[Cc]ode%s+[Ii]s%s*", "")
		:gsub("^[Cc]ode%s+[Ii]s%s*", "")
		:gsub("^[Uu]se%s+[Cc]ode%s*", "")
		:gsub("^[Tt]he%s+[Aa]nswer%s+[Ii]s%s*", "")
		:gsub("^[Aa]nswer%s+[Ii]s%s*", "")
		:gsub("^%s+", "")
	if looksLikeCode(stripped) and not stripped:find("%s") then
		table.insert(found, string.upper(stripped))
		return found
	end
	if looksLikeCode(trimmed) and not trimmed:find("%s") then
		table.insert(found, string.upper(trimmed))
		return found
	end
	for token in stripped:gmatch("[%w%-%_]+") do
		if looksLikeCode(token) and #token >= 4 then
			table.insert(found, string.upper(token))
		end
	end
	return found
end

local function copyCode(code)
	local f = formatCode(code)
	pcall(function()
		if setclipboard then setclipboard(f) elseif toclipboard then toclipboard(f) end
	end)
end

local _cachedBox = nil
local function _isCodeBox(obj)
	if not obj:IsA("TextBox") then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	if not isGuiVisible(obj) then return false end
	local hint = ((obj.PlaceholderText or "") .. " " .. obj.Name):lower()
	if hint:find("code") or hint:find("redeem") or hint:find("enter") or hint:find("type") or hint:find("here") then
		return true
	end
	local sz = obj.AbsoluteSize
	return sz.X >= 80 and sz.Y >= 20 and sz.Y <= 80
end

local function findCodeTextBox()
	if _cachedBox and _cachedBox.Parent and isGuiVisible(_cachedBox) then return _cachedBox end
	_cachedBox = nil
	local focused = UIS:GetFocusedTextBox()
	if focused and _isCodeBox(focused) then
		_cachedBox = focused
		return focused
	end
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, d in ipairs(pg:GetDescendants()) do
		if _isCodeBox(d) then
			_cachedBox = d
			return d
		end
	end
	return nil
end

local function fireSignal(sig)
	if not sig then return end
	pcall(function()
		if getconnections then
			for _, c in ipairs(getconnections(sig)) do
				if c.Fire then pcall(function() c:Fire() end) end
				if c.Function then pcall(c.Function) end
			end
		end
		if firesignal then firesignal(sig) end
	end)
end

local function isSubmitButton(obj)
	if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	if not isGuiVisible(obj) then return false end
	local hint = (((obj:IsA("TextButton") and obj.Text) or "") .. " " .. obj.Name):lower()
	return hint:find("redeem") or hint:find("submit") or hint:find("claim")
		or hint:find("confirm") or hint:find("enter")
end

local _cachedSubmitBtn = nil
local function fireSubmitButton(nearObj)
	local target = nil
	if _cachedSubmitBtn and _cachedSubmitBtn.Parent and isSubmitButton(_cachedSubmitBtn) then
		target = _cachedSubmitBtn
	else
		_cachedSubmitBtn = nil
		local container, levels = nearObj and nearObj.Parent, 0
		while container and levels < 8 do
			for _, ch in ipairs(container:GetChildren()) do
				if isSubmitButton(ch) then target = ch break end
				for _, g in ipairs(ch:GetChildren()) do
					if isSubmitButton(g) then target = g break end
				end
				if target then break end
			end
			if target then break end
			container = container.Parent
			levels += 1
		end
		if not target then
			local pg = LP:FindFirstChild("PlayerGui")
			if pg then
				for _, ch in ipairs(pg:GetDescendants()) do
					if isSubmitButton(ch) then target = ch break end
				end
			end
		end
		if target then _cachedSubmitBtn = target end
	end
	if not target then return false end
	pcall(function()
		fireSignal(target.MouseButton1Click)
		if target.Activated then fireSignal(target.Activated) end
	end)
	return true
end

local _rfRemote = nil
local function redeemViaRF(code)
	if not _rfRemote or not _rfRemote.Parent then
		_rfRemote = nil
		for _, root in ipairs({ RS:FindFirstChild("RF"), RS:FindFirstChild("Packages"), RS }) do
			if root then
				for _, r in ipairs(root:GetDescendants()) do
					if r:IsA("RemoteFunction") then
						local n = string.lower(r.Name)
						if n:find("code") or n:find("redeem") or n:find("promo") then
							_rfRemote = r
							break
						end
					end
				end
			end
			if _rfRemote then break end
		end
	end
	if not _rfRemote then return false end
	return pcall(function()
		_rfRemote:InvokeServer(formatCode(code))
	end)
end

local function updateCounters()
	local t = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
	if QueueLabel then QueueLabel.Text = tostring(#pendingQueue) end
	if CollectedLabel then CollectedLabel.Text = tostring(#collectedCodes) .. " / " .. tostring(t) end
end

-- Mobile-safe type: never hold TextBox focus (focus steals touch → camera zoom on swipe)
local _isMobile = UIS.TouchEnabled

local function restoreCamera(cf, fov)
	pcall(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		if cf then cam.CFrame = cf end
		if fov then cam.FieldOfView = fov end
	end)
end

local function safeTypeIntoBox(textBox, fullText)
	if not textBox then return end
	local cam = workspace.CurrentCamera
	local savedCF, savedFOV
	pcall(function()
		if cam then
			savedCF = cam.CFrame
			savedFOV = cam.FieldOfView
		end
	end)

	pcall(function()
		textBox.ClearTextOnFocus = false
		textBox.TextEditable = true
	end)

	-- Prefer setting Text WITHOUT CaptureFocus (especially mobile)
	pcall(function()
		textBox.Text = fullText
	end)

	-- PC only: brief focus so games that require it still register, then release
	if not _isMobile then
		pcall(function()
			textBox:CaptureFocus()
			textBox.CursorPosition = #fullText + 1
		end)
		task.wait()
		pcall(function()
			textBox:ReleaseFocus(false)
		end)
	else
		-- Mobile: never CaptureFocus — it causes pinch/zoom camera glitches while swiping
		pcall(function()
			if textBox:IsFocused() then
				textBox:ReleaseFocus(false)
			end
		end)
	end

	-- Clear GUI selection so touch goes back to camera/world
	pcall(function()
		GuiService.SelectedObject = nil
	end)

	restoreCamera(savedCF, savedFOV)
	-- one more frame restore (games sometimes nudge FOV on focus change)
	task.defer(function()
		restoreCamera(savedCF, savedFOV)
		pcall(function()
			if textBox and textBox:IsFocused() and _isMobile then
				textBox:ReleaseFocus(false)
			end
			GuiService.SelectedObject = nil
		end)
	end)
end

-- Instant type — one Text set, no held focus
local function writeAndSubmit(code)
	code = formatCode(code)
	if code == "" then return false end

	if _G.AutoSubmitEnabled and (tonumber(_G.SubmitAfterCount) or 1) <= 1 then
		if redeemViaRF(code) then
			setStatus("✓ SUCCESS", "Redeemed " .. code, "ok")
			pushActivity("Redeemed " .. code, Theme.Green)
			return true
		end
	end

	local textBox = findCodeTextBox()
	if not textBox then
		setStatus("⚠ NO BOX", "Open redeem UI", "err")
		return false
	end

	if not collectedSeen[code] then
		collectedSeen[code] = true
		table.insert(collectedCodes, code)
	end

	local target = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
	local fullText = table.concat(collectedCodes, "")
	local ready = #collectedCodes >= target

	safeTypeIntoBox(textBox, fullText)
	updateCounters()
	pushActivity("Typed " .. code, Theme.Cyan)

	if ready and _G.AutoSubmitEnabled then
		setStatus("● SUBMIT", fullText, "wait")
		local attempts = math.clamp(tonumber(_G.SubmitAttempts) or 3, 1, 6)
		local cam = workspace.CurrentCamera
		local savedCF, savedFOV
		pcall(function()
			if cam then savedCF, savedFOV = cam.CFrame, cam.FieldOfView end
		end)
		for _ = 1, attempts do
			pcall(function() textBox.Text = fullText end)
			-- submit without holding focus
			fireSubmitButton(textBox)
			task.wait(0.05)
			restoreCamera(savedCF, savedFOV)
			pcall(function()
				if textBox:IsFocused() then textBox:ReleaseFocus(false) end
				GuiService.SelectedObject = nil
			end)
		end
		redeemViaRF(fullText)
		restoreCamera(savedCF, savedFOV)
		setStatus("✓ SUCCESS", "Submitted", "ok")
		pushActivity("Submitted", Theme.Green)
		table.clear(collectedCodes)
		table.clear(collectedSeen)
		updateCounters()
		task.delay(0.8, function()
			setStatus("● ONLINE", "Waiting for trigger", "ok")
		end)
	elseif ready then
		setStatus("● READY", "Submit OFF", "wait")
	else
		setStatus("● ONLINE", "Typed " .. code, "ok")
	end
	return true
end

local function triggerWrite()
	if writeBusy or not _G.AutoWriteEnabled or #pendingQueue == 0 then return end
	writeBusy = true
	task.spawn(function()
		while _G.AutoWriteEnabled and #pendingQueue > 0 do
			local code = table.remove(pendingQueue, 1)
			if code then
				pendingSeen[code] = nil
				writeAndSubmit(code)
				task.wait(0.04)
			end
		end
		writeBusy = false
	end)
end

local function queueCode(code, reason)
	code = formatCode(code)
	if code == "" or #code < 2 then return false end
	if pendingSeen[code] or collectedSeen[code] then return false end
	-- debounce identical within 0.3s
	if tick() - lastQueuedAt < 0.15 then return false end
	lastQueuedAt = tick()
	pendingSeen[code] = true
	table.insert(pendingQueue, code)
	copyCode(code)
	pushActivity((reason or "Q") .. " " .. code, Theme.Cyan)
	updateCounters()
	if _G.AutoWriteEnabled then triggerWrite() end
	return true
end

------------------------------------------------------------
-- TRIGGER DETECTION (strict)
------------------------------------------------------------
local function stripRich(s)
	return tostring(s or ""):gsub("<[^>]->", "")
end

local function normalize(s)
	s = stripRich(s):lower()
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	s = s:gsub("%.+$", ""):gsub("…+$", "")
	return s
end

-- Returns "code", "riddle", or nil
local function detectTrigger(message)
	local n = normalize(message)
	-- exact / phrase (order matters: longer first)
	if n == "the riddle is" or n:find("the riddle is", 1, true) then return "riddle" end
	if n == "riddle is" or n:find("riddle is", 1, true) then return "riddle" end
	if n == "the code is" or n:find("the code is", 1, true) then return "code" end
	if n == "code is" or n:find("code is", 1, true) then return "code" end
	if n == "use code" or n:find("use code", 1, true) then return "code" end
	if n == "the answer is" or n:find("the answer is", 1, true) then return "riddle" end
	if n == "answer is" or n:find("answer is", 1, true) then return "riddle" end
	-- exact short words only (whole message)
	if n == "riddle" then return "riddle" end
	if n == "code" then return "code" end
	return nil
end

local function isArmed()
	return captureMode ~= nil and tick() < captureUntil
end

local function armCapture(mode)
	captureMode = mode
	captureUntil = tick() + 15
	table.clear(bufferedParts)
	setStatus("● ARMED", mode:upper() .. " — waiting…", "arm")
	pushActivity("Armed: " .. mode, Theme.Amber)
end

local function clearArm()
	captureMode = nil
	captureUntil = 0
	table.clear(bufferedParts)
end

local function resetInput()
	table.clear(pendingQueue)
	table.clear(pendingSeen)
	table.clear(collectedCodes)
	table.clear(collectedSeen)
	clearArm()
	writeBusy = false
	updateCounters()
	setStatus("● RESET", "Queue + collected cleared", "wait")
	pushActivity("Input reset", Theme.Amber)
end

-- Process ONLY after arm; never solve riddles on code path and vice versa
local function processArmedPayload(raw)
	if not isArmed() then return false end
	raw = stripRich(raw)
	local mode = captureMode

	if mode == "riddle" then
		if not _G.RiddleSolverEnabled then
			return true -- armed but riddle off → ignore payload, stay armed briefly
		end
		local ans = solveRiddle(raw)
		if ans then
			clearArm()
			setStatus("✓ RIDDLE", ans, "ok")
			pushActivity("Riddle → " .. ans, Theme.Violet)
			if _G.AutoWriteEnabled then
				queueCode(ans, "Riddle")
			else
				local box = findCodeTextBox()
				if box then
					safeTypeIntoBox(box, ans)
					if _G.AutoSubmitEnabled then
						task.wait(0.03)
						fireSubmitButton(box)
						redeemViaRF(ans)
						pcall(function()
							if box:IsFocused() then box:ReleaseFocus(false) end
							GuiService.SelectedObject = nil
						end)
					end
				end
			end
			return true
		end
		-- not solved yet — keep arm, don't treat as code
		return true
	end

	if mode == "code" then
		if not _G.AutoWriteEnabled then
			return true
		end
		-- NEVER run riddle solver on code path
		local codes = extractCodesFromText(raw)
		if #codes > 0 then
			clearArm()
			for _, c in ipairs(codes) do
				queueCode(c, "Code")
			end
			return true
		end
		-- buffer fragments for multi-part codes
		local cleaned = raw:gsub("%s+", "")
		if cleaned ~= "" and looksLikeCode(cleaned) then
			table.insert(bufferedParts, cleaned)
		elseif cleaned ~= "" then
			table.insert(bufferedParts, cleaned)
		end
		local threshold = math.max(1, math.floor(tonumber(_G.SubmitAfterCount) or 1))
		local joined = table.concat(bufferedParts, "")
		local joinedCodes = extractCodesFromText(joined)
		if #joinedCodes > 0 or #bufferedParts >= threshold then
			clearArm()
			local completed = (#joinedCodes > 0 and joinedCodes[1]) or formatCode(joined)
			if completed ~= "" then queueCode(completed, "Code") end
			return true
		end
		pushActivity("Buffer " .. #bufferedParts .. "/" .. threshold, Theme.Muted)
		return true
	end

	return false
end

local function processText(text)
	if not text or text == "" then return end
	text = stripRich(text)

	-- 1) Trigger lines are NOTIFIERS only — never write / queue from the trigger itself
	--    ("code" / "code is" / "use code" / "riddle is" …) just means something is coming next
	local trig = detectTrigger(text)
	if trig then
		if trig == "riddle" then
			pushActivity("Riddle incoming", Theme.Violet)
			setStatus("● NOTICE", "Riddle incoming…", "arm")
			-- arm only so the NEXT message can be solved / queued
			if _G.RiddleSolverEnabled or _G.AutoWriteEnabled then
				armCapture("riddle")
			end
		elseif trig == "code" then
			pushActivity("Code incoming", Theme.Amber)
			setStatus("● NOTICE", "Code incoming…", "arm")
			-- arm only so the NEXT message can be captured
			if _G.AutoWriteEnabled then
				armCapture("code")
			end
		end
		-- DO NOT extract / queue / type anything from the trigger line
		return
	end

	-- 2) Only process payload if armed (actual code / riddle text after the notifier)
	if isArmed() then
		processArmedPayload(text)
		return
	end

	-- 3) Nothing armed → ignore
end

------------------------------------------------------------
-- SAMMY FILTER
------------------------------------------------------------
local targetUserId = nil
task.spawn(function()
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync("SpyderSammy")
	end)
	if ok then targetUserId = id end
end)

local _sammyCache = {}
local ANNOUNCE_KEYS = {
	"sammy", "spydersammy", "announcement", "announce", "notify", "notification",
	"codeevent", "broadcast", "message", "tip", "live",
}

local function verifySourceIsSammy(textObj)
	if not textObj or not textObj.Parent then return false end
	if ScreenGui and textObj:IsDescendantOf(ScreenGui) then return false end
	local container = textObj.Parent
	local depth = 0
	while container and depth < 12 do
		if container:IsA("ScreenGui") or container.Name == "PlayerGui" then break end
		if _sammyCache[container] ~= nil then return _sammyCache[container] end
		local cname = string.lower(container.Name or "")
		for _, k in ipairs(ANNOUNCE_KEYS) do
			if cname:find(k, 1, true) then
				_sammyCache[container] = true
				return true
			end
		end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				local t = string.lower(item.Text or "")
				if t:find("spydersammy", 1, true) or t:find("sammy", 1, true) then
					_sammyCache[container] = true
					return true
				end
			elseif (item:IsA("ImageLabel") or item:IsA("ImageButton")) and item.Visible and item.Image ~= "" then
				if targetUserId and string.find(string.lower(item.Image), tostring(targetUserId), 1, true) then
					_sammyCache[container] = true
					return true
				end
			end
		end
		container = container.Parent
		depth += 1
	end
	return false
end

local function handleIncomingText(textObj)
	if not _G.ScriptEnabled then return end
	if not textObj or not textObj.Parent then return end
	local text = textObj.Text
	if not text or text == "" or #text > 300 then return end

	if _G.SammyFilterEnabled then
		if not verifySourceIsSammy(textObj) then return end
	else
		if ScreenGui and textObj:IsDescendantOf(ScreenGui) then return end
	end

	local now = tick()
	if text ~= lastSammyText or (now - lastSammyAt) > 0.35 then
		lastSammyText = text
		lastSammyAt = now
		pushSammyLog(text)
	end
	processText(text)
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookUiTextObject(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return end
	if hooked[obj] then return end
	hooked[obj] = true
	task.defer(function()
		if obj.Parent then handleIncomingText(obj) end
	end)
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		handleIncomingText(obj)
	end)
end

local function startPlayerGuiScanner()
	local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
	if not pg then return end
	task.spawn(function()
		local n = 0
		for _, d in ipairs(pg:GetDescendants()) do
			hookUiTextObject(d)
			n += 1
			if n % 120 == 0 then task.wait() end
		end
	end)
	pg.DescendantAdded:Connect(function(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			hookUiTextObject(obj)
		elseif obj:IsA("TextBox") and _isCodeBox(obj) then
			_cachedBox = obj
			triggerWrite()
		end
	end)
end

-- Auto buy / anchor (unchanged, light)
local BUY_KW = { "buy", "purchase", "claim", "steal", "take", "get", "collect" }
local function isBuyPrompt(p)
	local t = string.lower(tostring(p.ActionText or "") .. " " .. tostring(p.ObjectText or "") .. " " .. p.Name)
	if t:find("craft", 1, true) or t:find("sell", 1, true) then return false end
	for _, k in ipairs(BUY_KW) do
		if t:find(k, 1, true) then return true end
	end
	return false
end
local function wpos(inst)
	local c = inst
	for _ = 1, 12 do
		if not c then break end
		if c:IsA("BasePart") then return c.Position end
		if c:IsA("Attachment") and c.Parent and c.Parent:IsA("BasePart") then return c.Parent.Position end
		c = c.Parent
	end
end
local _promptCache = {}
for _, v in ipairs(workspace:GetDescendants()) do
	if v:IsA("ProximityPrompt") then _promptCache[v] = true end
end
workspace.DescendantAdded:Connect(function(v)
	if v:IsA("ProximityPrompt") then _promptCache[v] = true end
end)
workspace.DescendantRemoving:Connect(function(v)
	_promptCache[v] = nil
end)
task.spawn(function()
	while task.wait(0.4) do
		if _G.AutoBuyEnabled then
			local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local hpos = hrp.Position
				for v in pairs(_promptCache) do
					if not v.Parent then
						_promptCache[v] = nil
					elseif v.Enabled and isBuyPrompt(v) then
						local pos = wpos(v)
						if pos and (hpos - pos).Magnitude <= 10 then
							pcall(function()
								v.HoldDuration = 0
								if fireproximityprompt then fireproximityprompt(v)
								else v:InputHoldBegin() task.wait(0.02) v:InputHoldEnd() end
							end)
						end
					end
				end
			end
		end
	end
end)
local _lastAnchor = nil
task.spawn(function()
	while task.wait(0.3) do
		local a = _G.AnchorEnabled == true
		if a ~= _lastAnchor then
			_lastAnchor = a
			local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = a end
		end
	end
end)
LP.CharacterAdded:Connect(function(char)
	task.wait(0.1)
	if _G.AnchorEnabled then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = true end
	end
end)

------------------------------------------------------------
-- GUI (SMALL 290x385)
------------------------------------------------------------
pcall(function()
	for _, n in ipairs({ "K2CodeSniperUI", "K2CodeSniperV2" }) do
		local p = game.CoreGui:FindFirstChild(n) or LP.PlayerGui:FindFirstChild(n)
		if p then p:Destroy() end
	end
end)

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "K2CodeSniperV2"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 1000
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
	local parented = false
	pcall(function()
		if gethui then
			ScreenGui.Parent = gethui()
			parented = ScreenGui.Parent ~= nil
		end
	end)
	if not parented then
		pcall(function()
			if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
			ScreenGui.Parent = game:GetService("CoreGui")
			parented = ScreenGui.Parent ~= nil
		end)
	end
	if not parented then
		ScreenGui.Parent = LP:WaitForChild("PlayerGui")
	end
	getgenv().K2CodeSniperGui = ScreenGui
	print("[K2] GUI parent:", ScreenGui.Parent and ScreenGui.Parent.Name or "nil")
end

local PANEL_W, PANEL_H = 270, 350

-- Intro
local Intro = Instance.new("Frame")
Intro.Size = UDim2.fromScale(1, 1)
Intro.BackgroundColor3 = Theme.Void
Intro.BorderSizePixel = 0
Intro.ZIndex = 80
Intro.Parent = ScreenGui

local titleGlow = Instance.new("Frame")
titleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
titleGlow.Position = UDim2.new(0.5, 0, 0.32, 0)
titleGlow.Size = UDim2.fromOffset(200, 36)
titleGlow.BackgroundColor3 = Theme.Cyan
titleGlow.BackgroundTransparency = 1
titleGlow.BorderSizePixel = 0
titleGlow.ZIndex = 81
titleGlow.Parent = Intro
corner(titleGlow, 18)

local bigTitle = Instance.new("TextLabel")
bigTitle.AnchorPoint = Vector2.new(0.5, 0.5)
bigTitle.Position = UDim2.new(0.5, 0, 0.38, 0)
bigTitle.Size = UDim2.new(1, -40, 0, 36)
bigTitle.BackgroundTransparency = 1
bigTitle.Font = FT
bigTitle.Text = "K2 CODE SNIPER"
bigTitle.TextSize = 26
bigTitle.TextColor3 = Theme.Text
bigTitle.TextTransparency = 1
bigTitle.ZIndex = 82
bigTitle.Parent = Intro

local tag = Instance.new("TextLabel")
tag.AnchorPoint = Vector2.new(0.5, 0)
tag.Position = UDim2.new(0.5, 0, 0.38, 24)
tag.Size = UDim2.new(1, -40, 0, 16)
tag.BackgroundTransparency = 1
tag.Font = FM
tag.Text = "discord.gg/k2scripts"
tag.TextSize = 11
tag.TextColor3 = Theme.Cyan
tag.TextTransparency = 1
tag.ZIndex = 82
tag.Parent = Intro

local pill = Instance.new("TextButton")
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0.48, 0)
pill.Size = UDim2.fromOffset(130, 32)
pill.BackgroundColor3 = Theme.PanelSoft
pill.BackgroundTransparency = 1
pill.Text = "Continue"
pill.Font = FT
pill.TextSize = 12
pill.TextColor3 = Theme.Text
pill.TextTransparency = 1
pill.AutoButtonColor = false
pill.ZIndex = 83
pill.Parent = Intro
corner(pill, 16)
local pillStroke = stroke(pill, Theme.Cyan, 1, 1)

local skipLbl = Instance.new("TextButton")
skipLbl.AnchorPoint = Vector2.new(0.5, 1)
skipLbl.Position = UDim2.new(0.5, 0, 1, -20)
skipLbl.Size = UDim2.fromOffset(60, 18)
skipLbl.BackgroundTransparency = 1
skipLbl.Text = "skip"
skipLbl.Font = FB
skipLbl.TextSize = 10
skipLbl.TextColor3 = Theme.Muted
skipLbl.ZIndex = 83
skipLbl.Parent = Intro

local function finishIntro()
	if introDone then return end
	introDone = true
	TS:Create(Intro, TIQ, { BackgroundTransparency = 1 }):Play()
	TS:Create(bigTitle, TIQ, { TextTransparency = 1 }):Play()
	TS:Create(tag, TIQ, { TextTransparency = 1 }):Play()
	TS:Create(pill, TIQ, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function()
		if Intro then Intro.Visible = false end
		MainFrame.Visible = true
		MainFrame.Size = UDim2.fromOffset(PANEL_W * 0.94, PANEL_H * 0.94)
		MainFrame.BackgroundTransparency = 1
		TS:Create(MainFrame, TIB, {
			Size = UDim2.fromOffset(PANEL_W, PANEL_H),
			BackgroundTransparency = 0.1,
		}):Play()
		pushActivity("Online", Theme.Green)
	end)
end

pill.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then setclipboard("discord.gg/k2scripts") end
	end)
	pill.Text = "Copied!"
	task.delay(0.5, finishIntro)
end)
skipLbl.MouseButton1Click:Connect(finishIntro)

task.spawn(function()
	task.wait(0.15)
	TS:Create(bigTitle, TIL, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.32, 0) }):Play()
	TS:Create(titleGlow, TIL, { BackgroundTransparency = 0.88, Size = UDim2.fromOffset(260, 50) }):Play()
	task.wait(0.4)
	TS:Create(tag, TIQ, { TextTransparency = 0.15 }):Play()
	task.wait(0.2)
	TS:Create(pill, TIQ, { TextTransparency = 0, BackgroundTransparency = 0.25 }):Play()
	TS:Create(pillStroke, TIQ, { Transparency = 0.5 }):Play()
	task.wait(2.2)
	if not introDone then finishIntro() end
	-- hard fallback so GUI never stays invisible
	task.delay(1.5, function()
		if MainFrame and MainFrame.Parent and not MainFrame.Visible then
			if Intro then Intro.Visible = false end
			MainFrame.Visible = true
			MainFrame.BackgroundTransparency = 0.1
			introDone = true
			print("[K2] Forced MainFrame visible (fallback)")
		end
	end)
end)

MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.AnchorPoint = Vector2.new(1, 0)
MainFrame.Position = UDim2.new(1, -14, 0, 14)
MainFrame.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
MainFrame.BackgroundColor3 = Theme.Panel
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
corner(MainFrame, 14)
local b1 = stroke(MainFrame, Theme.Cyan, 1, 0.55)
local g1 = Instance.new("UIGradient")
g1.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.Cyan),
	ColorSequenceKeypoint.new(0.5, Theme.Violet),
	ColorSequenceKeypoint.new(1, Theme.Teal),
})
g1.Parent = b1

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundTransparency = 1
Header.ZIndex = 11
Header.Parent = MainFrame

local Logo = Instance.new("Frame")
Logo.Size = UDim2.fromOffset(20, 20)
Logo.Position = UDim2.new(0, 8, 0, 8)
Logo.BackgroundColor3 = Theme.PanelSoft
Logo.BorderSizePixel = 0
Logo.ZIndex = 12
Logo.Parent = Header
corner(Logo, 12)
stroke(Logo, Theme.Cyan, 1, 0.45)
local LogoTxt = Instance.new("TextLabel")
LogoTxt.Size = UDim2.fromScale(1, 1)
LogoTxt.BackgroundTransparency = 1
LogoTxt.Text = "❄"
LogoTxt.TextSize = 12
LogoTxt.ZIndex = 13
LogoTxt.Parent = Logo

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 34, 0, 5)
Title.Size = UDim2.new(1, -90, 0, 15)
Title.Font = FT
Title.Text = "K2 CODE SNIPER"
Title.TextSize = 11
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 34, 0, 19)
Subtitle.Size = UDim2.new(1, -90, 0, 12)
Subtitle.Font = FM
Subtitle.Text = "AURORA"
Subtitle.TextSize = 8
Subtitle.TextColor3 = Theme.Cyan
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 12
Subtitle.Parent = Header

local function winBtn(x, sym)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(16, 16)
	b.Position = UDim2.new(1, x, 0, 10)
	b.BackgroundColor3 = Theme.PanelSoft
	b.BackgroundTransparency = 0.25
	b.Text = sym
	b.Font = FT
	b.TextSize = 11
	b.TextColor3 = Theme.Muted
	b.AutoButtonColor = false
	b.ZIndex = 13
	b.Parent = Header
	corner(b, 9)
	return b
end
local MinBtn = winBtn(-44, "–")
local CloseBtn = winBtn(-22, "×")
MinBtn.MouseEnter:Connect(function()
	TS:Create(MinBtn, TIS, { BackgroundColor3 = Theme.Cyan, TextColor3 = Theme.Void }):Play()
end)
MinBtn.MouseLeave:Connect(function()
	TS:Create(MinBtn, TIS, { BackgroundColor3 = Theme.PanelSoft, TextColor3 = Theme.Muted }):Play()
end)
CloseBtn.MouseEnter:Connect(function()
	TS:Create(CloseBtn, TIS, { BackgroundColor3 = Theme.Red, TextColor3 = Theme.Text }):Play()
end)
CloseBtn.MouseLeave:Connect(function()
	TS:Create(CloseBtn, TIS, { BackgroundColor3 = Theme.PanelSoft, TextColor3 = Theme.Muted }):Play()
end)
CloseBtn.MouseButton1Click:Connect(function()
	TS:Create(MainFrame, TIQ, { BackgroundTransparency = 1 }):Play()
	task.wait(0.25)
	ScreenGui:Destroy()
	getgenv().K2CodeSniperV2 = nil
end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -72)
Content.Position = UDim2.new(0, 0, 0, 38)
Content.BackgroundTransparency = 1
Content.ZIndex = 11
Content.Parent = MainFrame

local PageMain = Instance.new("ScrollingFrame")
PageMain.Size = UDim2.fromScale(1, 1)
PageMain.BackgroundTransparency = 1
PageMain.BorderSizePixel = 0
PageMain.ScrollBarThickness = 3
PageMain.ScrollBarImageColor3 = Theme.Cyan
PageMain.ScrollingEnabled = true
PageMain.Active = true
PageMain.CanvasSize = UDim2.new(0, 0, 0, 270)
PageMain.ZIndex = 11
PageMain.Parent = Content

local PageSettings = Instance.new("ScrollingFrame")
PageSettings.Size = UDim2.fromScale(1, 1)
PageSettings.BackgroundTransparency = 1
PageSettings.BorderSizePixel = 0
PageSettings.Visible = false
PageSettings.ScrollBarThickness = 2
PageSettings.CanvasSize = UDim2.new(0, 0, 0, 300)
PageSettings.ZIndex = 11
PageSettings.Parent = Content

local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, -16, 0, 54)
StatusCard.Position = UDim2.new(0, 8, 0, 2)
StatusCard.BackgroundColor3 = Theme.Card
StatusCard.BackgroundTransparency = 0.12
StatusCard.BorderSizePixel = 0
StatusCard.ZIndex = 12
StatusCard.Parent = PageMain
corner(StatusCard, 10)
stroke(StatusCard, Theme.Cyan, 1, 0.55)

StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(6, 6)
StatusDot.Position = UDim2.new(0, 10, 0, 12)
StatusDot.BackgroundColor3 = Theme.Cyan
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 13
StatusDot.Parent = StatusCard
corner(StatusDot, 3)

StatusTitle = Instance.new("TextLabel")
StatusTitle.BackgroundTransparency = 1
StatusTitle.Position = UDim2.new(0, 22, 0, 6)
StatusTitle.Size = UDim2.new(1, -28, 0, 14)
StatusTitle.Font = FT
StatusTitle.Text = "● ONLINE"
StatusTitle.TextSize = 10
StatusTitle.TextColor3 = Theme.Text
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.ZIndex = 13
StatusTitle.Parent = StatusCard

StatusSub = Instance.new("TextLabel")
StatusSub.BackgroundTransparency = 1
StatusSub.Position = UDim2.new(0, 10, 0, 22)
StatusSub.Size = UDim2.new(1, -20, 0, 12)
StatusSub.Font = FM
StatusSub.Text = "Waiting for trigger"
StatusSub.TextSize = 8
StatusSub.TextColor3 = Theme.Muted
StatusSub.TextXAlignment = Enum.TextXAlignment.Left
StatusSub.ZIndex = 13
StatusSub.Parent = StatusCard

local function metric(x, label)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(x, 0, 0, 38)
	l.Size = UDim2.new(0.45, 0, 0, 9)
	l.Font = FM
	l.Text = label
	l.TextSize = 8
	l.TextColor3 = Theme.Muted
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 13
	l.Parent = StatusCard
	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Position = UDim2.new(x, 0, 0, 48)
	v.Size = UDim2.new(0.45, 0, 0, 12)
	v.Font = FT
	v.Text = "0"
	v.TextSize = 11
	v.TextColor3 = Theme.Cyan
	v.TextXAlignment = Enum.TextXAlignment.Left
	v.ZIndex = 13
	v.Parent = StatusCard
	return v
end
QueueLabel = metric(0.04, "QUEUE")
CollectedLabel = metric(0.5, "COLLECTED")
CollectedLabel.Text = "0 / 1"

local function makeCardToggle(parent, y, icon, title, desc, initial, cb)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -16, 0, 36)
	card.Position = UDim2.new(0, 8, 0, y)
	card.BackgroundColor3 = Theme.Card
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.ZIndex = 12
	card.Parent = parent
	corner(card, 10)
	local st = stroke(card, Theme.Cyan, 1, initial and 0.35 or 0.7)
	local ic = Instance.new("TextLabel")
	ic.BackgroundTransparency = 1
	ic.Position = UDim2.new(0, 8, 0, 4)
	ic.Size = UDim2.new(1, -55, 0, 15)
	ic.Font = FT
	ic.Text = icon .. "  " .. title
	ic.TextSize = 9
	ic.TextColor3 = Theme.Text
	ic.TextXAlignment = Enum.TextXAlignment.Left
	ic.ZIndex = 13
	ic.Parent = card
	local ds = Instance.new("TextLabel")
	ds.BackgroundTransparency = 1
	ds.Position = UDim2.new(0, 8, 0, 22)
	ds.Size = UDim2.new(1, -55, 0, 14)
	ds.Font = FB
	ds.Text = desc
	ds.TextSize = 7
	ds.TextColor3 = Theme.Muted
	ds.TextXAlignment = Enum.TextXAlignment.Left
	ds.ZIndex = 13
	ds.Parent = card
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(30, 14)
	track.Position = UDim2.new(1, -38, 0.5, -7)
	track.BackgroundColor3 = initial and Theme.Cyan or Theme.ToggleOff
	track.BorderSizePixel = 0
	track.ZIndex = 13
	track.Parent = card
	corner(track, 8)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(10, 10)
	knob.Position = initial and UDim2.new(1, -12, 0, 2) or UDim2.new(0, 2, 0, 2)
	knob.BackgroundColor3 = Theme.Text
	knob.BorderSizePixel = 0
	knob.ZIndex = 14
	knob.Parent = track
	corner(knob, 6)
	local hit = Instance.new("TextButton")
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 15
	hit.Parent = card
	local state = initial
	hit.MouseButton1Click:Connect(function()
		state = not state
		TS:Create(track, TIS, { BackgroundColor3 = state and Theme.Cyan or Theme.ToggleOff }):Play()
		TS:Create(knob, TIB, { Position = state and UDim2.new(1, -12, 0, 2) or UDim2.new(0, 2, 0, 2) }):Play()
		TS:Create(st, TIS, { Transparency = state and 0.3 or 0.7 }):Play()
		if cb then cb(state) end
	end)
	return card
end

makeCardToggle(PageMain, 60, "⚡", "AUTO WRITE", "Only after code/riddle trigger", false, function(s)
	_G.AutoWriteEnabled = s
	if not s then
		table.clear(pendingQueue)
		table.clear(pendingSeen)
		clearArm()
	end
	pushActivity(s and "Write ON" or "Write OFF", Theme.Cyan)
end)
makeCardToggle(PageMain, 100, "◈", "AUTO SUBMIT", "Submit when ready", false, function(s)
	_G.AutoSubmitEnabled = s
	pushActivity(s and "Submit ON" or "Submit OFF", Theme.Teal)
end)
makeCardToggle(PageMain, 140, "🧠", "RIDDLE", "Solve after riddle trigger", false, function(s)
	_G.RiddleSolverEnabled = s
	if not s and captureMode == "riddle" then clearArm() end
	pushActivity(s and "Riddle ON" or "Riddle OFF", Theme.Violet)
end)

-- Reset Input — directly under toggles (always visible, no scroll needed)
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetInput"
resetBtn.Size = UDim2.new(1, -16, 0, 30)
resetBtn.Position = UDim2.new(0, 8, 0, 180)
resetBtn.BackgroundColor3 = Color3.fromRGB(40, 32, 18)
resetBtn.BackgroundTransparency = 0.05
resetBtn.BorderSizePixel = 0
resetBtn.AutoButtonColor = false
resetBtn.Font = FT
resetBtn.TextSize = 12
resetBtn.TextColor3 = Theme.Amber
resetBtn.Text = "↺  RESET INPUT"
resetBtn.ZIndex = 14
resetBtn.Parent = PageMain
corner(resetBtn, 8)
local rstStroke = stroke(resetBtn, Theme.Amber, 1.5, 0.3)
resetBtn.MouseEnter:Connect(function()
	TS:Create(resetBtn, TIQ, { BackgroundTransparency = 0, TextColor3 = Theme.Text }):Play()
	TS:Create(rstStroke, TIQ, { Transparency = 0.1 }):Play()
end)
resetBtn.MouseLeave:Connect(function()
	TS:Create(resetBtn, TIQ, { BackgroundTransparency = 0.05, TextColor3 = Theme.Amber }):Play()
	TS:Create(rstStroke, TIQ, { Transparency = 0.3 }):Play()
end)
resetBtn.MouseButton1Click:Connect(function()
	resetInput()
	resetBtn.Text = "✓  CLEARED"
	task.delay(0.9, function()
		if resetBtn and resetBtn.Parent then
			resetBtn.Text = "↺  RESET INPUT"
		end
	end)
end)

local actTitle = Instance.new("TextLabel")
actTitle.BackgroundTransparency = 1
actTitle.Position = UDim2.new(0, 8, 0, 216)
actTitle.Size = UDim2.new(1, -20, 0, 10)
actTitle.Font = FT
actTitle.Text = "ACTIVITY"
actTitle.TextSize = 8
actTitle.TextColor3 = Theme.Muted
actTitle.TextXAlignment = Enum.TextXAlignment.Left
actTitle.ZIndex = 12
actTitle.Parent = PageMain

activityHost = Instance.new("Frame")
activityHost.Size = UDim2.new(1, -16, 0, 36)
activityHost.Position = UDim2.new(0, 8, 0, 228)
activityHost.BackgroundTransparency = 1
activityHost.ZIndex = 12
activityHost.Parent = PageMain
local al = Instance.new("UIListLayout")
al.SortOrder = Enum.SortOrder.LayoutOrder
al.Padding = UDim.new(0, 1)
al.Parent = activityHost

-- Settings
local function sectionLabel(parent, y, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 10, 0, y)
	l.Size = UDim2.new(1, -20, 0, 12)
	l.Font = FT
	l.Text = text
	l.TextSize = 9
	l.TextColor3 = Theme.Cyan
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 12
	l.Parent = parent
end
sectionLabel(PageSettings, 2, "FILTER")
makeCardToggle(PageSettings, 16, "👁", "SAMMY FILTER", "Only SpyderSammy messages", true, function(s)
	_G.SammyFilterEnabled = s
	pushActivity(s and "Filter ON" or "Filter OFF", Theme.Amber)
end)
sectionLabel(PageSettings, 56, "GENERAL")
makeCardToggle(PageSettings, 70, "❄", "ANCHOR", "Freeze character", false, function(s)
	_G.AnchorEnabled = s
end)
makeCardToggle(PageSettings, 110, "🛒", "AUTO BUY", "Buy · 10 studs", false, function(s)
	_G.AutoBuyEnabled = s
end)
sectionLabel(PageSettings, 150, "SUBMISSION")

local function stepper(parent, y, label, getV, setV, minV, maxV)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -16, 0, 30)
	f.Position = UDim2.new(0, 8, 0, y)
	f.BackgroundColor3 = Theme.Card
	f.BackgroundTransparency = 0.18
	f.BorderSizePixel = 0
	f.ZIndex = 12
	f.Parent = parent
	corner(f, 10)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Position = UDim2.new(0, 8, 0, 0)
	lb.Size = UDim2.new(0.5, 0, 1, 0)
	lb.Font = FM
	lb.Text = label
	lb.TextSize = 10
	lb.TextColor3 = Theme.Text
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.ZIndex = 13
	lb.Parent = f
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(84, 24)
	box.Position = UDim2.new(1, -92, 0.5, -12)
	box.BackgroundColor3 = Theme.PanelSoft
	box.BorderSizePixel = 0
	box.ZIndex = 13
	box.Parent = f
	corner(box, 8)
	local val = Instance.new("TextLabel")
	val.Size = UDim2.fromScale(1, 1)
	val.BackgroundTransparency = 1
	val.Font = FT
	val.Text = tostring(getV())
	val.TextSize = 12
	val.TextColor3 = Theme.Cyan
	val.ZIndex = 14
	val.Parent = box
	local mi = Instance.new("TextButton")
	mi.Size = UDim2.fromOffset(24, 24)
	mi.BackgroundTransparency = 1
	mi.Text = "−"
	mi.Font = FT
	mi.TextSize = 13
	mi.TextColor3 = Theme.Muted
	mi.ZIndex = 15
	mi.Parent = box
	local pl = Instance.new("TextButton")
	pl.Size = UDim2.fromOffset(24, 24)
	pl.Position = UDim2.new(1, -24, 0, 0)
	pl.BackgroundTransparency = 1
	pl.Text = "+"
	pl.Font = FT
	pl.TextSize = 13
	pl.TextColor3 = Theme.Muted
	pl.ZIndex = 15
	pl.Parent = box
	mi.MouseButton1Click:Connect(function()
		setV(math.max(minV, getV() - 1))
		val.Text = tostring(getV())
		updateCounters()
	end)
	pl.MouseButton1Click:Connect(function()
		setV(math.min(maxV, getV() + 1))
		val.Text = tostring(getV())
		updateCounters()
	end)
end
stepper(PageSettings, 164, "Submit After", function()
	return _G.SubmitAfterCount
end, function(v)
	_G.SubmitAfterCount = v
end, 1, 20)
stepper(PageSettings, 200, "Attempts", function()
	return _G.SubmitAttempts
end, function(v)
	_G.SubmitAttempts = v
end, 1, 6)

local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Position = UDim2.new(0, 8, 0, 238)
info.Size = UDim2.new(1, -20, 0, 36)
info.Font = FB
info.TextSize = 9
info.TextColor3 = Theme.Muted
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = "Triggers: code · riddle · code is\nriddle is · the code is · the riddle is"
info.ZIndex = 12
info.Parent = PageSettings

-- Nav
local Nav = Instance.new("Frame")
Nav.Size = UDim2.new(1, -16, 0, 26)
Nav.Position = UDim2.new(0, 8, 1, -32)
Nav.BackgroundColor3 = Theme.Card
Nav.BackgroundTransparency = 0.12
Nav.BorderSizePixel = 0
Nav.ZIndex = 14
Nav.Parent = MainFrame
corner(Nav, 10)
stroke(Nav, Theme.Cyan, 1, 0.6)

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(0.5, -6, 0, 2)
tabIndicator.Position = UDim2.new(0, 4, 1, -3)
tabIndicator.BackgroundColor3 = Theme.Cyan
tabIndicator.BorderSizePixel = 0
tabIndicator.ZIndex = 15
tabIndicator.Parent = Nav
corner(tabIndicator, 2)

local function navTab(text, xScale)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -4, 1, -4)
	b.Position = UDim2.new(xScale, 2, 0, 2)
	b.BackgroundTransparency = 1
	b.Font = FT
	b.TextSize = 8
	b.Text = text
	b.TextColor3 = Theme.Muted
	b.ZIndex = 15
	b.AutoButtonColor = false
	b.Parent = Nav
	return b
end
local navMain = navTab("◉ MAIN", 0)
local navSet = navTab("⚙ SETTINGS", 0.5)
local function selectTab(name)
	currentTab = name
	PageMain.Visible = name == "Main"
	PageSettings.Visible = name == "Settings"
	navMain.TextColor3 = name == "Main" and Theme.Text or Theme.Muted
	navSet.TextColor3 = name == "Settings" and Theme.Text or Theme.Muted
	TS:Create(tabIndicator, TIS, {
		Position = name == "Main" and UDim2.new(0, 4, 1, -3) or UDim2.new(0.5, 2, 1, -3),
	}):Play()
end
navMain.MouseButton1Click:Connect(function() selectTab("Main") end)
navSet.MouseButton1Click:Connect(function() selectTab("Settings") end)

Orb = Instance.new("TextButton")
Orb.Size = UDim2.fromOffset(34, 34)
Orb.AnchorPoint = Vector2.new(1, 0)
Orb.Position = UDim2.new(1, -14, 0, 14)
Orb.BackgroundColor3 = Theme.Panel
Orb.BackgroundTransparency = 0.08
Orb.Text = "❄"
Orb.Font = FT
Orb.TextSize = 15
Orb.TextColor3 = Theme.Cyan
Orb.Visible = false
Orb.ZIndex = 20
Orb.AutoButtonColor = false
Orb.Parent = ScreenGui
corner(Orb, 17)
stroke(Orb, Theme.Cyan, 1.2, 0.4)

local function setMinimized(state)
	isMinimized = state
	if state then
		TS:Create(MainFrame, TIQ, { Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1 }):Play()
		task.wait(0.2)
		MainFrame.Visible = false
		Orb.Visible = true
	else
		Orb.Visible = false
		MainFrame.Visible = true
		MainFrame.Size = UDim2.fromOffset(PANEL_W * 0.94, PANEL_H * 0.94)
		MainFrame.BackgroundTransparency = 1
		TS:Create(MainFrame, TIB, {
			Size = UDim2.fromOffset(PANEL_W, PANEL_H),
			BackgroundTransparency = 0.1,
		}):Play()
	end
end
MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
Orb.MouseButton1Click:Connect(function() setMinimized(false) end)

do
	local dragging, start, startPos
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			start = input.Position
			startPos = MainFrame.Position
		end
	end)
	Header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - start
			MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		local t = tick()
		if g1 then g1.Rotation = (t * 8) % 360 end
		if StatusDot then StatusDot.BackgroundTransparency = 0.15 + math.sin(t * 1.5) * 0.15 end
		task.wait(0.25)
	end
end)

startPlayerGuiScanner()

-- Clear lock if GUI is destroyed so user can re-execute
task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		task.wait(1)
	end
	getgenv().K2CodeSniperV2 = nil
	getgenv().K2CodeSniperGui = nil
end)

print("[K2 Code Sniper V2] Loaded · GUI should be visible")
print("[K2] Parent:", ScreenGui and ScreenGui.Parent and ScreenGui.Parent.Name)
