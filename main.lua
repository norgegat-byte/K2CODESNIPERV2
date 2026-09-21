--[[
  K2 CODE SNIPER V2 — Arctic Aurora
  Intro styled after atradescam.lovable.app (big glow title + soft pill CTA)
]]

repeat task.wait() until game:IsLoaded()
if getgenv().K2CodeSniperV2 then return warn("[K2] Already running") end
getgenv().K2CodeSniperV2 = true

if not table.clear then function table.clear(t) for k in pairs(t) do t[k]=nil end end end

_G.ScriptEnabled=true
_G.AutoWriteEnabled=false
_G.AutoSubmitEnabled=false
_G.RiddleSolverEnabled=false
_G.SubmitAfterCount=1
_G.SubmitAttempts=2
_G.AnchorEnabled=false
_G.AutoBuyEnabled=false

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TS=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer

local Theme={
	Void=Color3.fromRGB(3,8,14),
	Panel=Color3.fromRGB(10,18,28),
	PanelSoft=Color3.fromRGB(16,28,42),
	Card=Color3.fromRGB(14,24,38),
	Cyan=Color3.fromRGB(170,230,230),
	Glow=Color3.fromRGB(140,220,210),
	Teal=Color3.fromRGB(70,190,170),
	Violet=Color3.fromRGB(130,140,200),
	Green=Color3.fromRGB(110,230,180),
	Amber=Color3.fromRGB(255,190,90),
	Red=Color3.fromRGB(255,110,120),
	Text=Color3.fromRGB(230,245,245),
	Muted=Color3.fromRGB(130,155,165),
	ToggleOff=Color3.fromRGB(35,50,60),
}
local FT,FB,FM=Enum.Font.GothamBold,Enum.Font.Gotham,Enum.Font.GothamMedium
local TIQ=TweenInfo.new(0.55,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
local TIS=TweenInfo.new(0.28,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
local TIB=TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
local TIL=TweenInfo.new(1.1,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)

local function corner(p,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 12) c.Parent=p return c end
local function stroke(p,col,th,tr) local s=Instance.new("UIStroke") s.Color=col or Theme.Cyan s.Thickness=th or 1 s.Transparency=tr or 0.4 s.Parent=p return s end

------------------------------------------------------------
-- CORE (hardened sniper)
------------------------------------------------------------
local pendingQueue,pendingSeen,collectedCodes,collectedSeen={},{},{},{}
local writeBusy,lastProcessAt,lastCodeHash=false,0,""
local activeConnections={}
local ScreenGui,MainFrame,Orb
local StatusDot,StatusTitle,StatusSub,QueueLabel,CollectedLabel,activityHost
local ActivityList={}
local currentTab="Main"
local isMinimized=false
local introDone=false

local function pushActivity(text,color)
	if not activityHost then return end
	local row=Instance.new("TextLabel")
	row.Size=UDim2.new(1,-4,0,14)
	row.BackgroundTransparency=1
	row.Font=FM
	row.TextSize=9
	row.TextColor3=color or Theme.Muted
	row.TextXAlignment=Enum.TextXAlignment.Left
	row.Text="●  "..text
	row.TextTransparency=1
	row.Parent=activityHost
	table.insert(ActivityList,1,row)
	while #ActivityList>4 do local o=table.remove(ActivityList) if o then o:Destroy() end end
	for i,r in ipairs(ActivityList) do
		r.LayoutOrder=i
		TS:Create(r,TIS,{TextTransparency=math.min(0.1+(i-1)*0.18,0.75)}):Play()
	end
end

local function setStatus(title,sub,mode)
	if StatusTitle then StatusTitle.Text=title end
	if StatusSub then StatusSub.Text=sub or "" end
	if StatusDot then
		local c=Theme.Cyan
		if mode=="ok" then c=Theme.Green elseif mode=="err" then c=Theme.Red elseif mode=="wait" then c=Theme.Muted end
		StatusDot.BackgroundColor3=c
	end
end

local SAB_DB={
	["how old am i"]="24",["sammy age"]="24",["age"]="24",
	["where am i from"]="BRAZIL",["my country"]="BRAZIL",
	["favorite color"]="BLUE",["color"]="BLUE",
	["favorite football player"]="RONALDO",["ronaldo"]="RONALDO",
	["game created on"]="FRIDAY",["created on"]="FRIDAY",
	["seventh mutation"]="CURSED",["eighth mutation"]="DIVINE",
	["ninth mutation"]="CYBER",["tenth mutation"]="PHANTOM",
	["first machine"]="RAINBOW MACHINE",["highest rarity"]="OG",
	["won the world cup"]="ARGENTINA",["maximum server size"]="EIGHT",
}
local targetUserId=nil
task.spawn(function()
	local ok,id=pcall(function() return Players:GetUserIdFromNameAsync("SpyderSammy") end)
	if ok then targetUserId=id end
end)

local function isAvatarImage(il)
	if not il.Visible or il.Image=="" then return false end
	return targetUserId and string.find(string.lower(il.Image),tostring(targetUserId))~=nil
end
local function verifySourceIsSammy(textObj)
	if MainFrame and textObj:IsDescendantOf(MainFrame) then return false end
	if ScreenGui and textObj:IsDescendantOf(ScreenGui) then return false end
	local container=textObj.Parent
	while container and not container:IsA("ScreenGui") and container.Name~="PlayerGui" do
		for _,item in ipairs(container:GetChildren()) do
			if item:IsA("TextLabel") and string.find(string.lower(item.Text),"spydersammy") then return true end
		end
		for _,item in ipairs(container:GetDescendants()) do
			if item:IsA("ImageLabel") and isAvatarImage(item) then return true end
		end
		if container.Parent and (container.Parent:IsA("Frame") or container.Parent:IsA("ImageLabel") or container.Parent:IsA("CanvasGroup")) then
			container=container.Parent
		else break end
	end
	return false
end
local function answerQuestion(text)
	if not _G.RiddleSolverEnabled or not text or text=="" then return nil end
	local l=text:lower()
	local clean=l:gsub("what%s+is",""):gsub("[%?%.%,!]",""):gsub("^%s+",""):gsub("%s+$","")
	if SAB_DB[clean] then return SAB_DB[clean] end
	for k,v in pairs(SAB_DB) do
		if clean:find(k,1,true) or k:find(clean,1,true) then return v end
	end
	return nil
end

local function isGuiVisible(obj)
	if not obj or not obj.Visible then return false end
	local c=obj.Parent
	while c do
		if c:IsA("GuiObject") and not c.Visible then return false end
		if c:IsA("ScreenGui") and not c.Enabled then return false end
		c=c.Parent
	end
	return true
end
local function looksLikeCode(token)
	if not token or #token<2 or #token>40 then return false end
	return token:match("^[%w%-_]+$")~=nil
end
local function extractCodesFromText(text)
	local found={}
	if not text then return found end
	local trimmed=(text:match("^%s*(.-)%s*$") or ""):gsub("<[^>]->","")
	if looksLikeCode(trimmed) and not trimmed:find("%s") then
		table.insert(found,string.upper(trimmed)) return found
	end
	for token in trimmed:gmatch("[%w%-%_]+") do
		if looksLikeCode(token) and #token>=3 then table.insert(found,string.upper(token)) end
	end
	return found
end
local function formatCode(code) return string.upper(tostring(code or "")) end
local function copyCode(code)
	local f=formatCode(code)
	if setclipboard then pcall(setclipboard,f) elseif toclipboard then pcall(toclipboard,f) end
end

local _cachedBox=nil
local function _isCodeBox(obj)
	if not obj:IsA("TextBox") then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	local hint=((obj.PlaceholderText or "").." "..obj.Name):lower()
	return hint:find("code") or hint:find("redeem") or hint:find("here") or hint:find("enter")
end
local function findCodeTextBox()
	if _cachedBox and _cachedBox.Parent and isGuiVisible(_cachedBox) then return _cachedBox end
	_cachedBox=nil
	local pg=LP:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _,d in ipairs(pg:GetDescendants()) do
		if _isCodeBox(d) and isGuiVisible(d) then _cachedBox=d return d end
	end
	return nil
end
local function fireSignal(sig)
	if not sig then return end
	pcall(function()
		if getconnections then
			for _,c in ipairs(getconnections(sig)) do
				if c.Fire then pcall(function() c:Fire() end) end
				if c.Function then pcall(c.Function) end
			end
		end
	end)
	if firesignal then pcall(firesignal,sig) end
end
local function isSubmitButton(obj)
	if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return false end
	if not isGuiVisible(obj) then return false end
	local hint=(((obj:IsA("TextButton") and obj.Text) or "").." "..obj.Name):lower()
	return hint:find("redeem") or hint:find("submit") or hint:find("claim")
end
local function fireSubmitButton(nearObj)
	local target,container,levels=nil,nearObj and nearObj.Parent,0
	while container and levels<8 do
		for _,ch in ipairs(container:GetDescendants()) do
			if isSubmitButton(ch) then target=ch break end
		end
		if target then break end
		container=container.Parent
		levels=levels+1
	end
	if not target then
		local pg=LP:FindFirstChild("PlayerGui")
		if pg then for _,ch in ipairs(pg:GetDescendants()) do if isSubmitButton(ch) then target=ch break end end end
	end
	if not target then return false end
	pcall(function() fireSignal(target.MouseButton1Click) if target.Activated then fireSignal(target.Activated) end end)
	return true
end
local _rfRemote=nil
local function getRedemptionRF()
	if _rfRemote and _rfRemote.Parent then return _rfRemote end
	_rfRemote=nil
	local rf=RS:FindFirstChild("RF")
	if rf then
		for _,r in ipairs(rf:GetDescendants()) do
			if r:IsA("RemoteFunction") then
				local n=string.lower(r.Name)
				if n:find("code") or n:find("redeem") then _rfRemote=r return r end
			end
		end
	end
	return nil
end
local function redeemViaRF(code)
	local rf=getRedemptionRF()
	if not rf then return false end
	return pcall(function() return rf:InvokeServer(formatCode(code)) end)
end
local function updateCounters()
	local t=math.max(1,math.floor(tonumber(_G.SubmitAfterCount) or 1))
	if QueueLabel then QueueLabel.Text=tostring(#pendingQueue) end
	if CollectedLabel then CollectedLabel.Text=tostring(#collectedCodes).." / "..tostring(t) end
end

local function writeAndSubmit(code)
	code=formatCode(code)
	if code=="" then return false end
	if _G.AutoSubmitEnabled and (_G.SubmitAfterCount or 1)<=1 then
		if redeemViaRF(code) then
			setStatus("✓ SUCCESS","Redeemed "..code,"ok")
			pushActivity("Redeemed "..code,Theme.Green)
			return true
		end
	end
	local textBox=findCodeTextBox()
	if not textBox then
		setStatus("⚠ NO CODE BOX","Waiting for redeem UI","err")
		pushActivity("Code box not found",Theme.Red)
		return false
	end
	pcall(function() textBox.ClearTextOnFocus=false end)
	if not collectedSeen[code] then collectedSeen[code]=true table.insert(collectedCodes,code) end
	local target=math.max(1,math.floor(tonumber(_G.SubmitAfterCount) or 1))
	local fullText=table.concat(collectedCodes,"")
	local ready=#collectedCodes>=target
	pcall(function() textBox:CaptureFocus() textBox.Text=fullText textBox.CursorPosition=#fullText+1 end)
	task.wait(0.04)
	pcall(function() textBox.Text=fullText end)
	updateCounters()
	if ready and _G.AutoSubmitEnabled then
		setStatus("● PROCESSING","Submitting...","wait")
		task.wait(0.06)
		local box=findCodeTextBox() or textBox
		local attempts=math.clamp(tonumber(_G.SubmitAttempts) or 2,1,5)
		for _=1,attempts do
			pcall(function() if box then box.Text=fullText box:CaptureFocus() end end)
			task.wait(0.05)
			fireSubmitButton(box)
			task.wait(0.08)
		end
		setStatus("✓ SUCCESS","Submitted x"..#collectedCodes,"ok")
		pushActivity("Submitted x"..#collectedCodes,Theme.Green)
		table.clear(collectedCodes) table.clear(collectedSeen)
		updateCounters()
		task.delay(1.1,function() setStatus("● SYSTEM ONLINE","Monitoring for codes","ok") end)
	elseif ready then
		setStatus("● READY",#collectedCodes.." codes — submit OFF","wait")
	else
		setStatus("● SYSTEM ONLINE","Typed "..code,"ok")
		pushActivity("Typed "..code,Theme.Cyan)
	end
	return true
end

local function triggerWrite()
	if writeBusy or not _G.AutoWriteEnabled or #pendingQueue==0 then return end
	local focused=UIS:GetFocusedTextBox()
	if focused and ScreenGui and focused:IsDescendantOf(ScreenGui) then return end
	if not findCodeTextBox() then setStatus("● WAITING","Code box not visible","wait") return end
	writeBusy=true
	task.spawn(function()
		pcall(function()
			while _G.AutoWriteEnabled and #pendingQueue>0 do
				local b=findCodeTextBox()
				if not (b and isGuiVisible(b)) then break end
				local code=table.remove(pendingQueue,1)
				if code then pendingSeen[code]=nil writeAndSubmit(code) updateCounters() task.wait(0.07) end
			end
		end)
		writeBusy=false
	end)
end

local function processText(text)
	if _G.RiddleSolverEnabled then
		local answer=answerQuestion(text)
		if answer then
			local box=findCodeTextBox()
			if box then pcall(function() box:CaptureFocus() box.Text=answer end) task.wait(0.05) if _G.AutoSubmitEnabled then fireSubmitButton(box) end end
			setStatus("✓ RIDDLE",answer,"ok")
			pushActivity("Riddle: "..answer,Theme.Violet)
			return
		end
	end
	if not _G.AutoWriteEnabled or not text or text=="" then return end
	local now=tick()
	if text==lastCodeHash and (now-lastProcessAt)<0.35 then return end
	lastCodeHash,lastProcessAt=text,now
	local codes=extractCodesFromText(text)
	if #codes==0 then return end
	local added=0
	for _,code in ipairs(codes) do
		code=formatCode(code)
		if not pendingSeen[code] then pendingSeen[code]=true table.insert(pendingQueue,code) copyCode(code) added=added+1 end
	end
	if added>0 then pushActivity("Queued "..added,Theme.Cyan) updateCounters() triggerWrite() end
end

local function handleIncomingText(textObj)
	if not _G.ScriptEnabled or writeBusy then return end
	local text=textObj.Text
	if not text or text=="" then return end
	if not verifySourceIsSammy(textObj) then return end
	processText(text)
end
local function hookUiTextObject(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	if ScreenGui and obj:IsDescendantOf(ScreenGui) then return end
	handleIncomingText(obj)
	obj:GetPropertyChangedSignal("Text"):Connect(function() handleIncomingText(obj) end)
end
local function startPlayerGuiScanner()
	local pg=LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui",10)
	if not pg then return end
	for _,d in ipairs(pg:GetDescendants()) do hookUiTextObject(d) end
	table.insert(activeConnections,pg.DescendantAdded:Connect(hookUiTextObject))
	table.insert(activeConnections,pg.DescendantAdded:Connect(function(obj) if _isCodeBox(obj) then _cachedBox=obj triggerWrite() end end))
end

-- Auto buy / anchor
local BUY_KW={"buy","purchase","claim","steal","take","get","collect"}
local function isBuyPrompt(p)
	local t=string.lower(tostring(p.ActionText or "").." "..tostring(p.ObjectText or "").." "..p.Name)
	if t:find("craft",1,true) or t:find("sell",1,true) then return false end
	for _,k in ipairs(BUY_KW) do if t:find(k,1,true) then return true end end
	return false
end
local function wpos(inst)
	local c=inst
	for _=1,12 do
		if not c then break end
		if c:IsA("BasePart") then return c.Position end
		if c:IsA("Attachment") and c.Parent and c.Parent:IsA("BasePart") then return c.Parent.Position end
		c=c.Parent
	end
end
task.spawn(function()
	while task.wait(0.15) do
		if _G.AutoBuyEnabled then
			local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _,v in ipairs(workspace:GetDescendants()) do
					if v:IsA("ProximityPrompt") and v.Enabled and isBuyPrompt(v) then
						local pos=wpos(v)
						if pos and (hrp.Position-pos).Magnitude<=10 then
							pcall(function()
								v.HoldDuration=0
								if fireproximityprompt then fireproximityprompt(v) end
								v:InputHoldBegin() task.wait(0.03) v:InputHoldEnd()
							end)
						end
					end
				end
			end
		end
	end
end)
task.spawn(function()
	while task.wait() do
		pcall(function()
			local char=LP.Character
			if not char then return end
			local a=_G.AnchorEnabled==true
			for _,p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=a end end
		end)
	end
end)

------------------------------------------------------------
-- GUI
------------------------------------------------------------
pcall(function()
	for _,n in ipairs({"K2CodeSniperUI","K2CodeSniperV2"}) do
		local p=game.CoreGui:FindFirstChild(n) or LP.PlayerGui:FindFirstChild(n)
		if p then p:Destroy() end
	end
end)

ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="K2CodeSniperV2"
ScreenGui.ResetOnSpawn=false
ScreenGui.IgnoreGuiInset=true
ScreenGui.DisplayOrder=1000
if not pcall(function() ScreenGui.Parent=game.CoreGui end) then ScreenGui.Parent=LP.PlayerGui end

-- Smaller panel
local PANEL_W,PANEL_H=290,385

------------------------------------------------------------
-- INTRO (Welcome-style: big glow text + soft pill + skip)
------------------------------------------------------------
local Intro=Instance.new("Frame")
Intro.Size=UDim2.fromScale(1,1)
Intro.BackgroundColor3=Theme.Void
Intro.BorderSizePixel=0
Intro.ZIndex=80
Intro.Parent=ScreenGui

-- Soft vertical aurora washes (fake sky)
for i=1,4 do
	local wash=Instance.new("Frame")
	wash.Size=UDim2.new(0.22,0,1.2,0)
	wash.Position=UDim2.new(0.08+i*0.18,0,-0.1,0)
	wash.BackgroundColor3=({Theme.Teal,Theme.Glow,Theme.Violet,Theme.Cyan})[i]
	wash.BackgroundTransparency=0.93
	wash.BorderSizePixel=0
	wash.Rotation=-6+i*3
	wash.ZIndex=81
	wash.Parent=Intro
	local g=Instance.new("UIGradient")
	g.Transparency=NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.4,0.2),
		NumberSequenceKeypoint.new(1,1),
	})
	g.Rotation=90
	g.Parent=wash
end

-- Stars
for i=1,40 do
	local s=Instance.new("Frame")
	s.Size=UDim2.fromOffset(1,1)
	s.Position=UDim2.fromScale(math.random(),math.random()*0.75)
	s.BackgroundColor3=Color3.fromRGB(220,240,245)
	s.BackgroundTransparency=0.3+math.random()*0.5
	s.BorderSizePixel=0
	s.ZIndex=81
	s.Parent=Intro
	corner(s,2)
end

-- Center stack
local center=Instance.new("Frame")
center.AnchorPoint=Vector2.new(0.5,0.5)
center.Position=UDim2.fromScale(0.5,0.48)
center.Size=UDim2.fromOffset(420,220)
center.BackgroundTransparency=1
center.ZIndex=85
center.Parent=Intro

-- Big glowing title (like "Welcome")
local bigTitle=Instance.new("TextLabel")
bigTitle.AnchorPoint=Vector2.new(0.5,0.5)
bigTitle.Position=UDim2.new(0.5,0,0.32,0)
bigTitle.Size=UDim2.new(1,0,0,52)
bigTitle.BackgroundTransparency=1
bigTitle.Font=FT
bigTitle.Text="K2 Sniper"
bigTitle.TextSize=42
bigTitle.TextColor3=Theme.Text
bigTitle.TextTransparency=1
bigTitle.ZIndex=86
bigTitle.Parent=center

-- Soft glow under title (large transparent blob)
local titleGlow=Instance.new("Frame")
titleGlow.AnchorPoint=Vector2.new(0.5,0.5)
titleGlow.Position=UDim2.new(0.5,0,0.32,0)
titleGlow.Size=UDim2.fromOffset(200,40)
titleGlow.BackgroundColor3=Theme.Glow
titleGlow.BackgroundTransparency=1
titleGlow.BorderSizePixel=0
titleGlow.ZIndex=84
titleGlow.Parent=center
corner(titleGlow,30)

local tag=Instance.new("TextLabel")
tag.AnchorPoint=Vector2.new(0.5,0.5)
tag.Position=UDim2.new(0.5,0,0.52,0)
tag.Size=UDim2.new(1,0,0,18)
tag.BackgroundTransparency=1
tag.Font=FM
tag.Text="AURORA AUTOMATION"
tag.TextSize=11
tag.TextColor3=Theme.Muted
tag.TextTransparency=1
tag.ZIndex=86
tag.Parent=center

-- Soft pill button (like JOIN THE DISCORD)
local pill=Instance.new("TextButton")
pill.AnchorPoint=Vector2.new(0.5,0.5)
pill.Position=UDim2.new(0.5,0,0.72,0)
pill.Size=UDim2.fromOffset(168,36)
pill.BackgroundColor3=Color3.fromRGB(20,32,40)
pill.BackgroundTransparency=1
pill.Text="  Copy discord.gg/k2scripts"
pill.Font=FM
pill.TextSize=12
pill.TextColor3=Theme.Text
pill.TextTransparency=1
pill.AutoButtonColor=false
pill.ZIndex=87
pill.Parent=center
corner(pill,18)
local pillStroke=stroke(pill,Color3.fromRGB(90,140,150),1,1)

pill.MouseEnter:Connect(function()
	if introDone then return end
	TS:Create(pill,TIS,{BackgroundColor3=Color3.fromRGB(28,44,54)}):Play()
	TS:Create(pillStroke,TIS,{Transparency=0.35}):Play()
end)
pill.MouseLeave:Connect(function()
	if introDone then return end
	TS:Create(pill,TIS,{BackgroundColor3=Color3.fromRGB(20,32,40)}):Play()
	TS:Create(pillStroke,TIS,{Transparency=0.5}):Play()
end)
pill.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then setclipboard("discord.gg/k2scripts")
		elseif toclipboard then toclipboard("discord.gg/k2scripts") end
	end)
	pill.Text="  Copied!"
	task.delay(1,function() if pill and pill.Parent then pill.Text="  Copy discord.gg/k2scripts" end end)
end)

local skipLbl=Instance.new("TextButton")
skipLbl.AnchorPoint=Vector2.new(0.5,1)
skipLbl.Position=UDim2.new(0.5,0,1,-28)
skipLbl.Size=UDim2.fromOffset(120,20)
skipLbl.BackgroundTransparency=1
skipLbl.Text="CLICK TO SKIP"
skipLbl.Font=FM
skipLbl.TextSize=10
skipLbl.TextColor3=Theme.Muted
skipLbl.TextTransparency=0.35
skipLbl.ZIndex=90
skipLbl.AutoButtonColor=false
skipLbl.Parent=Intro

local function finishIntro()
	if introDone then return end
	introDone=true
	-- Fade big words away first
	TS:Create(bigTitle,TIL,{TextTransparency=1,TextSize=48}):Play()
	TS:Create(titleGlow,TIS,{BackgroundTransparency=1}):Play()
	TS:Create(tag,TIS,{TextTransparency=1}):Play()
	TS:Create(pill,TIS,{TextTransparency=1,BackgroundTransparency=1}):Play()
	TS:Create(pillStroke,TIS,{Transparency=1}):Play()
	TS:Create(skipLbl,TIS,{TextTransparency=1}):Play()
	TS:Create(Intro,TIQ,{BackgroundTransparency=1}):Play()
	task.delay(0.7,function()
		if Intro then Intro.Visible=false end
		MainFrame.Visible=true
		MainFrame.Size=UDim2.fromOffset(PANEL_W*0.94,PANEL_H*0.94)
		MainFrame.BackgroundTransparency=1
		TS:Create(MainFrame,TIB,{
			Size=UDim2.fromOffset(PANEL_W,PANEL_H),
			BackgroundTransparency=0.1,
		}):Play()
		pushActivity("System online",Theme.Green)
	end)
end

skipLbl.MouseButton1Click:Connect(finishIntro)
Intro.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		-- only skip if not clicking pill
	end
end)

-- Intro sequence
task.spawn(function()
	task.wait(0.2)
	-- title rises slightly + fades in with glow
	bigTitle.Position=UDim2.new(0.5,0,0.38,0)
	TS:Create(bigTitle,TIL,{TextTransparency=0,Position=UDim2.new(0.5,0,0.32,0)}):Play()
	TS:Create(titleGlow,TIL,{BackgroundTransparency=0.88,Size=UDim2.fromOffset(280,56)}):Play()
	task.wait(0.45)
	TS:Create(tag,TIQ,{TextTransparency=0.15}):Play()
	task.wait(0.25)
	TS:Create(pill,TIQ,{TextTransparency=0,BackgroundTransparency=0.25}):Play()
	TS:Create(pillStroke,TIQ,{Transparency=0.5}):Play()
	task.wait(2.4)
	if not introDone then finishIntro() end
end)

------------------------------------------------------------
-- MAIN PANEL (smaller)
------------------------------------------------------------
MainFrame=Instance.new("Frame")
MainFrame.Name="Main"
MainFrame.AnchorPoint=Vector2.new(1,0)
MainFrame.Position=UDim2.new(1,-14,0,14)
MainFrame.Size=UDim2.fromOffset(PANEL_W,PANEL_H)
MainFrame.BackgroundColor3=Theme.Panel
MainFrame.BackgroundTransparency=0.1
MainFrame.BorderSizePixel=0
MainFrame.ClipsDescendants=true
MainFrame.Visible=false
MainFrame.ZIndex=10
MainFrame.Parent=ScreenGui
corner(MainFrame,14)
local b1=stroke(MainFrame,Theme.Cyan,1,0.55)
local g1=Instance.new("UIGradient")
g1.Color=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Theme.Cyan),
	ColorSequenceKeypoint.new(0.5,Theme.Violet),
	ColorSequenceKeypoint.new(1,Theme.Teal),
})
g1.Parent=b1

local Header=Instance.new("Frame")
Header.Size=UDim2.new(1,0,0,48)
Header.BackgroundTransparency=1
Header.ZIndex=11
Header.Parent=MainFrame

local Logo=Instance.new("Frame")
Logo.Size=UDim2.fromOffset(26,26)
Logo.Position=UDim2.new(0,12,0,11)
Logo.BackgroundColor3=Theme.PanelSoft
Logo.BorderSizePixel=0
Logo.ZIndex=12
Logo.Parent=Header
corner(Logo,13)
stroke(Logo,Theme.Cyan,1,0.45)
local LogoTxt=Instance.new("TextLabel")
LogoTxt.Size=UDim2.fromScale(1,1)
LogoTxt.BackgroundTransparency=1
LogoTxt.Text="❄"
LogoTxt.TextSize=13
LogoTxt.ZIndex=13
LogoTxt.Parent=Logo

local Title=Instance.new("TextLabel")
Title.BackgroundTransparency=1
Title.Position=UDim2.new(0,44,0,10)
Title.Size=UDim2.new(1,-100,0,16)
Title.Font=FT
Title.Text="K2 CODE SNIPER"
Title.TextSize=13
Title.TextColor3=Theme.Text
Title.TextXAlignment=Enum.TextXAlignment.Left
Title.ZIndex=12
Title.Parent=Header

local Subtitle=Instance.new("TextLabel")
Subtitle.BackgroundTransparency=1
Subtitle.Position=UDim2.new(0,44,0,26)
Subtitle.Size=UDim2.new(1,-100,0,12)
Subtitle.Font=FM
Subtitle.Text="AURORA"
Subtitle.TextSize=9
Subtitle.TextColor3=Theme.Cyan
Subtitle.TextXAlignment=Enum.TextXAlignment.Left
Subtitle.ZIndex=12
Subtitle.Parent=Header

local function winBtn(x,sym)
	local b=Instance.new("TextButton")
	b.Size=UDim2.fromOffset(20,20)
	b.Position=UDim2.new(1,x,0,14)
	b.BackgroundColor3=Theme.PanelSoft
	b.BackgroundTransparency=0.25
	b.Text=sym
	b.Font=FT
	b.TextSize=11
	b.TextColor3=Theme.Muted
	b.AutoButtonColor=false
	b.ZIndex=13
	b.Parent=Header
	corner(b,10)
	return b
end
local MinBtn=winBtn(-48,"–")
local CloseBtn=winBtn(-24,"×")
MinBtn.MouseEnter:Connect(function() TS:Create(MinBtn,TIS,{BackgroundColor3=Theme.Cyan,TextColor3=Theme.Void}):Play() end)
MinBtn.MouseLeave:Connect(function() TS:Create(MinBtn,TIS,{BackgroundColor3=Theme.PanelSoft,TextColor3=Theme.Muted}):Play() end)
CloseBtn.MouseEnter:Connect(function() TS:Create(CloseBtn,TIS,{BackgroundColor3=Theme.Red,TextColor3=Theme.Text}):Play() end)
CloseBtn.MouseLeave:Connect(function() TS:Create(CloseBtn,TIS,{BackgroundColor3=Theme.PanelSoft,TextColor3=Theme.Muted}):Play() end)
CloseBtn.MouseButton1Click:Connect(function()
	TS:Create(MainFrame,TIQ,{BackgroundTransparency=1}):Play()
	task.wait(0.3)
	ScreenGui:Destroy()
	getgenv().K2CodeSniperV2=nil
end)

local Content=Instance.new("Frame")
Content.Size=UDim2.new(1,0,1,-92)
Content.Position=UDim2.new(0,0,0,50)
Content.BackgroundTransparency=1
Content.ZIndex=11
Content.Parent=MainFrame

local PageMain=Instance.new("ScrollingFrame")
PageMain.Size=UDim2.fromScale(1,1)
PageMain.BackgroundTransparency=1
PageMain.BorderSizePixel=0
PageMain.ScrollBarThickness=2
PageMain.ScrollBarImageColor3=Theme.Cyan
PageMain.CanvasSize=UDim2.new(0,0,0,310)
PageMain.ZIndex=11
PageMain.Parent=Content

local PageSettings=Instance.new("ScrollingFrame")
PageSettings.Size=UDim2.fromScale(1,1)
PageSettings.BackgroundTransparency=1
PageSettings.BorderSizePixel=0
PageSettings.Visible=false
PageSettings.ScrollBarThickness=2
PageSettings.CanvasSize=UDim2.new(0,0,0,300)
PageSettings.ZIndex=11
PageSettings.Parent=Content

-- Status
local StatusCard=Instance.new("Frame")
StatusCard.Size=UDim2.new(1,-24,0,72)
StatusCard.Position=UDim2.new(0,12,0,2)
StatusCard.BackgroundColor3=Theme.Card
StatusCard.BackgroundTransparency=0.12
StatusCard.BorderSizePixel=0
StatusCard.ZIndex=12
StatusCard.Parent=PageMain
corner(StatusCard,10)
stroke(StatusCard,Theme.Cyan,1,0.55)

StatusDot=Instance.new("Frame")
StatusDot.Size=UDim2.fromOffset(7,7)
StatusDot.Position=UDim2.new(0,12,0,14)
StatusDot.BackgroundColor3=Theme.Cyan
StatusDot.BorderSizePixel=0
StatusDot.ZIndex=13
StatusDot.Parent=StatusCard
corner(StatusDot,4)

StatusTitle=Instance.new("TextLabel")
StatusTitle.BackgroundTransparency=1
StatusTitle.Position=UDim2.new(0,26,0,8)
StatusTitle.Size=UDim2.new(1,-36,0,16)
StatusTitle.Font=FT
StatusTitle.Text="● SYSTEM ONLINE"
StatusTitle.TextSize=11
StatusTitle.TextColor3=Theme.Text
StatusTitle.TextXAlignment=Enum.TextXAlignment.Left
StatusTitle.ZIndex=13
StatusTitle.Parent=StatusCard

StatusSub=Instance.new("TextLabel")
StatusSub.BackgroundTransparency=1
StatusSub.Position=UDim2.new(0,12,0,26)
StatusSub.Size=UDim2.new(1,-24,0,12)
StatusSub.Font=FM
StatusSub.Text="Monitoring for codes"
StatusSub.TextSize=9
StatusSub.TextColor3=Theme.Muted
StatusSub.TextXAlignment=Enum.TextXAlignment.Left
StatusSub.ZIndex=13
StatusSub.Parent=StatusCard

local function metric(x,label)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1
	l.Position=UDim2.new(x,0,0,44)
	l.Size=UDim2.new(0.45,0,0,10)
	l.Font=FM
	l.Text=label
	l.TextSize=8
	l.TextColor3=Theme.Muted
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.ZIndex=13
	l.Parent=StatusCard
	local v=Instance.new("TextLabel")
	v.BackgroundTransparency=1
	v.Position=UDim2.new(x,0,0,54)
	v.Size=UDim2.new(0.45,0,0,14)
	v.Font=FT
	v.Text="0"
	v.TextSize=12
	v.TextColor3=Theme.Cyan
	v.TextXAlignment=Enum.TextXAlignment.Left
	v.ZIndex=13
	v.Parent=StatusCard
	return v
end
QueueLabel=metric(0.04,"QUEUE")
CollectedLabel=metric(0.5,"COLLECTED")
CollectedLabel.Text="0 / 1"

local function makeCardToggle(parent,y,icon,title,desc,initial,cb)
	local card=Instance.new("Frame")
	card.Size=UDim2.new(1,-24,0,46)
	card.Position=UDim2.new(0,12,0,y)
	card.BackgroundColor3=Theme.Card
	card.BackgroundTransparency=0.18
	card.BorderSizePixel=0
	card.ZIndex=12
	card.Parent=parent
	corner(card,10)
	local st=stroke(card,Theme.Cyan,1,initial and 0.35 or 0.7)
	local ic=Instance.new("TextLabel")
	ic.BackgroundTransparency=1
	ic.Position=UDim2.new(0,10,0,6)
	ic.Size=UDim2.new(1,-60,0,16)
	ic.Font=FT
	ic.Text=icon.."  "..title
	ic.TextSize=11
	ic.TextColor3=Theme.Text
	ic.TextXAlignment=Enum.TextXAlignment.Left
	ic.ZIndex=13
	ic.Parent=card
	local ds=Instance.new("TextLabel")
	ds.BackgroundTransparency=1
	ds.Position=UDim2.new(0,10,0,24)
	ds.Size=UDim2.new(1,-60,0,14)
	ds.Font=FB
	ds.Text=desc
	ds.TextSize=9
	ds.TextColor3=Theme.Muted
	ds.TextXAlignment=Enum.TextXAlignment.Left
	ds.ZIndex=13
	ds.Parent=card
	local track=Instance.new("Frame")
	track.Size=UDim2.fromOffset(36,18)
	track.Position=UDim2.new(1,-46,0.5,-9)
	track.BackgroundColor3=initial and Theme.Cyan or Theme.ToggleOff
	track.BorderSizePixel=0
	track.ZIndex=13
	track.Parent=card
	corner(track,9)
	local knob=Instance.new("Frame")
	knob.Size=UDim2.fromOffset(14,14)
	knob.Position=initial and UDim2.new(1,-16,0,2) or UDim2.new(0,2,0,2)
	knob.BackgroundColor3=Theme.Text
	knob.BorderSizePixel=0
	knob.ZIndex=14
	knob.Parent=track
	corner(knob,7)
	local hit=Instance.new("TextButton")
	hit.Size=UDim2.fromScale(1,1)
	hit.BackgroundTransparency=1
	hit.Text=""
	hit.ZIndex=15
	hit.Parent=card
	local state=initial
	hit.MouseButton1Click:Connect(function()
		state=not state
		TS:Create(track,TIS,{BackgroundColor3=state and Theme.Cyan or Theme.ToggleOff}):Play()
		TS:Create(knob,TIB,{Position=state and UDim2.new(1,-16,0,2) or UDim2.new(0,2,0,2)}):Play()
		TS:Create(st,TIS,{Transparency=state and 0.3 or 0.7}):Play()
		if cb then cb(state) end
	end)
	return card
end

makeCardToggle(PageMain,82,"⚡","AUTO WRITE","Write codes automatically",false,function(s)
	_G.AutoWriteEnabled=s
	if not s then table.clear(pendingQueue) table.clear(pendingSeen) end
	pushActivity(s and "Auto Write ON" or "Auto Write OFF",Theme.Cyan)
end)
makeCardToggle(PageMain,134,"◈","AUTO SUBMIT","Submit when count reached",false,function(s)
	_G.AutoSubmitEnabled=s
	pushActivity(s and "Auto Submit ON" or "Auto Submit OFF",Theme.Teal)
end)
makeCardToggle(PageMain,186,"🧠","RIDDLE","Solve detected riddles",false,function(s)
	_G.RiddleSolverEnabled=s
end)

local actTitle=Instance.new("TextLabel")
actTitle.BackgroundTransparency=1
actTitle.Position=UDim2.new(0,12,0,240)
actTitle.Size=UDim2.new(1,-24,0,12)
actTitle.Font=FT
actTitle.Text="ACTIVITY"
actTitle.TextSize=9
actTitle.TextColor3=Theme.Muted
actTitle.TextXAlignment=Enum.TextXAlignment.Left
actTitle.ZIndex=12
actTitle.Parent=PageMain

activityHost=Instance.new("Frame")
activityHost.Size=UDim2.new(1,-24,0,60)
activityHost.Position=UDim2.new(0,12,0,254)
activityHost.BackgroundTransparency=1
activityHost.ZIndex=12
activityHost.Parent=PageMain
local al=Instance.new("UIListLayout")
al.SortOrder=Enum.SortOrder.LayoutOrder
al.Padding=UDim.new(0,2)
al.Parent=activityHost

-- Settings
local function sectionLabel(parent,y,text)
	local l=Instance.new("TextLabel")
	l.BackgroundTransparency=1
	l.Position=UDim2.new(0,12,0,y)
	l.Size=UDim2.new(1,-24,0,14)
	l.Font=FT
	l.Text=text
	l.TextSize=10
	l.TextColor3=Theme.Cyan
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.ZIndex=12
	l.Parent=parent
end
sectionLabel(PageSettings,4,"GENERAL")
makeCardToggle(PageSettings,24,"❄","ANCHOR","Freeze character",false,function(s) _G.AnchorEnabled=s end)
makeCardToggle(PageSettings,76,"🛒","AUTO BUY","Buy only · 10 studs",false,function(s) _G.AutoBuyEnabled=s end)
sectionLabel(PageSettings,132,"SUBMISSION")

local function stepper(parent,y,label,getV,setV,minV,maxV)
	local f=Instance.new("Frame")
	f.Size=UDim2.new(1,-24,0,36)
	f.Position=UDim2.new(0,12,0,y)
	f.BackgroundColor3=Theme.Card
	f.BackgroundTransparency=0.18
	f.BorderSizePixel=0
	f.ZIndex=12
	f.Parent=parent
	corner(f,10)
	local lb=Instance.new("TextLabel")
	lb.BackgroundTransparency=1
	lb.Position=UDim2.new(0,10,0,0)
	lb.Size=UDim2.new(0.45,0,1,0)
	lb.Font=FM
	lb.Text=label
	lb.TextSize=11
	lb.TextColor3=Theme.Text
	lb.TextXAlignment=Enum.TextXAlignment.Left
	lb.ZIndex=13
	lb.Parent=f
	local box=Instance.new("Frame")
	box.Size=UDim2.fromOffset(90,26)
	box.Position=UDim2.new(1,-100,0.5,-13)
	box.BackgroundColor3=Theme.PanelSoft
	box.BorderSizePixel=0
	box.ZIndex=13
	box.Parent=f
	corner(box,8)
	local val=Instance.new("TextLabel")
	val.Size=UDim2.fromScale(1,1)
	val.BackgroundTransparency=1
	val.Font=FT
	val.Text=tostring(getV())
	val.TextSize=13
	val.TextColor3=Theme.Cyan
	val.ZIndex=14
	val.Parent=box
	local mi=Instance.new("TextButton")
	mi.Size=UDim2.fromOffset(26,26)
	mi.BackgroundTransparency=1
	mi.Text="−"
	mi.Font=FT
	mi.TextSize=14
	mi.TextColor3=Theme.Muted
	mi.ZIndex=15
	mi.Parent=box
	local pl=Instance.new("TextButton")
	pl.Size=UDim2.fromOffset(26,26)
	pl.Position=UDim2.new(1,-26,0,0)
	pl.BackgroundTransparency=1
	pl.Text="+"
	pl.Font=FT
	pl.TextSize=14
	pl.TextColor3=Theme.Muted
	pl.ZIndex=15
	pl.Parent=box
	mi.MouseButton1Click:Connect(function() setV(math.max(minV,getV()-1)) val.Text=tostring(getV()) updateCounters() end)
	pl.MouseButton1Click:Connect(function() setV(math.min(maxV,getV()+1)) val.Text=tostring(getV()) updateCounters() end)
end
stepper(PageSettings,152,"Submit After",function() return _G.SubmitAfterCount end,function(v) _G.SubmitAfterCount=v end,1,20)
stepper(PageSettings,194,"Attempts",function() return _G.SubmitAttempts end,function(v) _G.SubmitAttempts=v end,1,5)

local info=Instance.new("TextLabel")
info.BackgroundTransparency=1
info.Position=UDim2.new(0,12,0,244)
info.Size=UDim2.new(1,-24,0,40)
info.Font=FB
info.TextSize=10
info.TextColor3=Theme.Muted
info.TextXAlignment=Enum.TextXAlignment.Left
info.TextYAlignment=Enum.TextYAlignment.Top
info.Text="K2 Code Sniper · Aurora\ndiscord.gg/k2scripts"
info.ZIndex=12
info.Parent=PageSettings

-- Nav
local Nav=Instance.new("Frame")
Nav.Size=UDim2.new(1,-24,0,34)
Nav.Position=UDim2.new(0,12,1,-42)
Nav.BackgroundColor3=Theme.Card
Nav.BackgroundTransparency=0.12
Nav.BorderSizePixel=0
Nav.ZIndex=14
Nav.Parent=MainFrame
corner(Nav,10)
stroke(Nav,Theme.Cyan,1,0.6)

local tabIndicator=Instance.new("Frame")
tabIndicator.Size=UDim2.new(0.5,-6,0,2)
tabIndicator.Position=UDim2.new(0,4,1,-3)
tabIndicator.BackgroundColor3=Theme.Cyan
tabIndicator.BorderSizePixel=0
tabIndicator.ZIndex=15
tabIndicator.Parent=Nav
corner(tabIndicator,2)

local function navTab(text,xScale)
	local b=Instance.new("TextButton")
	b.Size=UDim2.new(0.5,-4,1,-4)
	b.Position=UDim2.new(xScale,2,0,2)
	b.BackgroundTransparency=1
	b.Font=FT
	b.TextSize=10
	b.Text=text
	b.TextColor3=Theme.Muted
	b.ZIndex=15
	b.AutoButtonColor=false
	b.Parent=Nav
	return b
end
local navMain=navTab("◉ MAIN",0)
local navSet=navTab("⚙ SETTINGS",0.5)
local function selectTab(name)
	currentTab=name
	PageMain.Visible=name=="Main"
	PageSettings.Visible=name=="Settings"
	navMain.TextColor3=name=="Main" and Theme.Text or Theme.Muted
	navSet.TextColor3=name=="Settings" and Theme.Text or Theme.Muted
	TS:Create(tabIndicator,TIS,{Position=name=="Main" and UDim2.new(0,4,1,-3) or UDim2.new(0.5,2,1,-3)}):Play()
end
navMain.MouseButton1Click:Connect(function() selectTab("Main") end)
navSet.MouseButton1Click:Connect(function() selectTab("Settings") end)

Orb=Instance.new("TextButton")
Orb.Size=UDim2.fromOffset(42,42)
Orb.AnchorPoint=Vector2.new(1,0)
Orb.Position=UDim2.new(1,-16,0,16)
Orb.BackgroundColor3=Theme.Panel
Orb.BackgroundTransparency=0.08
Orb.Text="❄"
Orb.Font=FT
Orb.TextSize=16
Orb.TextColor3=Theme.Cyan
Orb.Visible=false
Orb.ZIndex=20
Orb.AutoButtonColor=false
Orb.Parent=ScreenGui
corner(Orb,21)
stroke(Orb,Theme.Cyan,1.2,0.4)

local function setMinimized(state)
	isMinimized=state
	if state then
		TS:Create(MainFrame,TIQ,{Size=UDim2.fromOffset(42,42),BackgroundTransparency=1}):Play()
		task.wait(0.22)
		MainFrame.Visible=false
		Orb.Visible=true
	else
		Orb.Visible=false
		MainFrame.Visible=true
		MainFrame.Size=UDim2.fromOffset(PANEL_W*0.94,PANEL_H*0.94)
		MainFrame.BackgroundTransparency=1
		TS:Create(MainFrame,TIB,{Size=UDim2.fromOffset(PANEL_W,PANEL_H),BackgroundTransparency=0.1}):Play()
	end
end
MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
Orb.MouseButton1Click:Connect(function() setMinimized(false) end)

do
	local dragging,start,startPos
	Header.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			dragging=true start=input.Position startPos=MainFrame.Position
		end
	end)
	Header.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
			local d=input.Position-start
			MainFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
		end
	end)
end

task.spawn(function()
	while ScreenGui and ScreenGui.Parent do
		local t=tick()
		g1.Rotation=(t*10)%360
		if StatusDot then StatusDot.BackgroundTransparency=0.1+math.sin(t*2)*0.2 end
		task.wait(0.05)
	end
end)

startPlayerGuiScanner()
print("[K2 Code Sniper V2] Welcome-style intro · smaller panel · Aurora")
