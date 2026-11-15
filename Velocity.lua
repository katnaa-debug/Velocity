local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
local isMobile = UIS.TouchEnabled

local function getFS()
    local g = (getgenv and getgenv()) or _G or {}
    local env = (getfenv and getfenv()) or {}
    return {
        isfolder = isfolder or env.isfolder or g.isfolder,
        makefolder = makefolder or env.makefolder or g.makefolder,
        listfiles = listfiles or listdir or env.listfiles or env.listdir or g.listfiles or g.listdir,
        readfile = readfile or env.readfile or g.readfile,
        writefile = writefile or env.writefile or g.writefile,
        delfile = delfile or deletefile or env.delfile or env.deletefile or g.delfile or g.deletefile
    }
end

local function safeIsFolder(path)
    local fs = getFS()
    if fs.isfolder then
        local s, res = pcall(fs.isfolder, path)
        return s and res
    end
    return false
end

local function safeMakeFolder(path)
    local fs = getFS()
    if fs.makefolder and not safeIsFolder(path) then
        pcall(fs.makefolder, path)
    end
end

local function safeWriteFile(path, content)
    local fs = getFS()
    if fs.writefile then
        return pcall(fs.writefile, path, content)
    end
    return false, "writefile not supported"
end

local function safeReadFile(path)
    local fs = getFS()
    if fs.readfile then
        local s, content = pcall(fs.readfile, path)
        if s then return content end
    end
    return nil
end

local function safeDelFile(path)
    local fs = getFS()
    if fs.delfile then
        return pcall(fs.delfile, path)
    end
    return false
end

local function safeListFiles(folder)
    local fs = getFS()
    if not fs.listfiles then return {} end
    local s, files = pcall(fs.listfiles, folder)
    if s and type(files) == "table" and next(files) ~= nil then return files end
    local s2, files2 = pcall(fs.listfiles, folder .. "/")
    if s2 and type(files2) == "table" and next(files2) ~= nil then return files2 end
    local s3, files3 = pcall(fs.listfiles, "./" .. folder)
    if s3 and type(files3) == "table" and next(files3) ~= nil then return files3 end
    local s4, files4 = pcall(fs.listfiles, "")
    if not s4 or type(files4) ~= "table" then
        s4, files4 = pcall(fs.listfiles)
    end
    if s4 and type(files4) == "table" then
        local matched = {}
        local targetFolder = folder:lower():gsub("[/\\]+$", "")
        for _, f in pairs(files4) do
            local fStr = tostring(f):lower():gsub("\\", "/")
            if fStr:find(targetFolder .. "/", 1, true) then
                table.insert(matched, f)
            end
        end
        if #matched > 0 then return matched end
    end
    if s and type(files) == "table" then return files end
    return {}
end

local function parseAsset(input)
	if not input or input == "" then return "" end
	local str = tostring(input):match("^%s*(.-)%s*$")
	if str == "" then return "" end
	if str:match("^rbxthumb://") or str:match("^rbxasset://textures") then 
		return str 
	end
	local id = str:match("(%d+)")
	if id then 
		return "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420"
	end
	return str
end

local function getFirstChar(str)
	if not str or str == "" then return "" end
	for _, code in utf8.codes(str) do
		return string.upper(utf8.char(code))
	end
	return string.upper(string.sub(str, 1, 1))
end

local function truncateTwoDots(text, font, size, maxW)
	if not text or text == "" then return "" end
	if maxW <= 10 then return ".." end
	local full = TextService:GetTextSize(text, size, font, Vector2.new(10000, 100))
	if full.X <= maxW then return text end
	local dotsW = TextService:GetTextSize("..", size, font, Vector2.new(10000, 100)).X
	local avail = maxW - dotsW
	if avail <= 0 then return ".." end
	local len = utf8.len(text) or #text
	for i = len, 1, -1 do
		local offset = utf8.offset(text, i + 1)
		local sub = string.sub(text, 1, offset and (offset - 1) or i)
		local s = TextService:GetTextSize(sub, size, font, Vector2.new(10000, 100))
		if s.X <= avail then
			return sub .. ".."
		end
	end
	return ".."
end

local Library = {}
Library.__index = Library

local THEME = {
	Accent = Color3.fromRGB(110, 100, 255), 
	Background = Color3.fromRGB(24, 23, 35),
	Sidebar = Color3.fromRGB(20, 19, 30),
	Card = Color3.fromRGB(34, 32, 48),
	CardHover = Color3.fromRGB(42, 40, 58),
	Element = Color3.fromRGB(24, 23, 35),
	ElementHover = Color3.fromRGB(32, 31, 45),
	Outlines = Color3.fromRGB(50, 48, 68),
	Input = Color3.fromRGB(16, 15, 23),
	Text = Color3.fromRGB(245, 245, 250),
	TextMuted = Color3.fromRGB(145, 142, 165),
	CloseBtn = Color3.fromRGB(255, 87, 87),
	BackgroundTrans = 0,
	HUDTransparency = 0,
	BgImageTrans = 1,
	CardTrans = 0,
	ElementTrans = 0,
	InputTrans = 0,
	TextFont = "Gotham",
	SubtextFont = "Gotham",
	BackgroundImage = "",
	TogglePosition = "Right",
	InternalOutlines = "Off",
	ElementStyle = 1,
	TopbarAlign = "Right",
	MainOutlineEnabled = false,
	CloseAnimation = 1,
	BackgroundEffect = "Constellation"
}

local function ApplyTheme(obj, themeKey, prop)
	prop = prop or "BackgroundColor3"
	obj:SetAttribute("ThemeProp_" .. prop, themeKey)
	CS:AddTag(obj, "ThemeBind")
	if prop == "Font" then
		pcall(function() obj[prop] = Enum.Font[THEME[themeKey]] end)
	elseif prop == "Image" and themeKey == "BackgroundImage" then
		obj[prop] = parseAsset(THEME[themeKey])
	else
		obj[prop] = THEME[themeKey]
	end
end

local function UpdateTheme(themeKey, value)
	THEME[themeKey] = value
	for _, obj in ipairs(CS:GetTagged("ThemeBind")) do
		for attrName, attrValue in pairs(obj:GetAttributes()) do
			if string.sub(attrName, 1, 10) == "ThemeProp_" and attrValue == themeKey then
				local prop = string.sub(attrName, 11)
				if prop == "Font" then
					pcall(function() obj[prop] = Enum.Font[value] end)
				elseif prop == "Image" and themeKey == "BackgroundImage" then
					obj[prop] = parseAsset(value)
				else
					obj[prop] = value
				end
			end
		end
	end
end

local function UpdateTogglePosition(posMode)
	THEME.TogglePosition = posMode
	local isCompact = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4)
	local edge = isCompact and 5 or 7
	local boxSize = isCompact and 18 or 24
	for _, toggleBox in ipairs(CS:GetTagged("ToggleBoxBind")) do
		if posMode == "Left" then
			toggleBox.AnchorPoint = Vector2.new(0, 0.5)
			toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
		else
			toggleBox.AnchorPoint = Vector2.new(1, 0.5)
			toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
		end
	end
	for _, label in ipairs(CS:GetTagged("ToggleLabelBind")) do
		if posMode == "Left" then
			label.Position = UDim2.new(0, edge + boxSize + 7, 0, 0)
			label.Size = UDim2.new(1, -(edge + boxSize + 15), 1, 0)
		else
			label.Position = UDim2.new(0, 15, 0, 0)
			label.Size = UDim2.new(1, -60, 1, 0)
		end
	end
	for _, combo in ipairs(CS:GetTagged("ComboToggleBind")) do
		combo:SetAttribute("TogglePos", posMode)
	end
end

local function UpdateTopbarAlign(align)
	THEME.TopbarAlign = align
	for _, layout in ipairs(CS:GetTagged("TopbarLayoutBind")) do
		if align == "Left" then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		else
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	for _, padding in ipairs(CS:GetTagged("TopbarPaddingBind")) do
		if align == "Left" then
			padding.PaddingLeft = UDim.new(0, 14)
			padding.PaddingRight = UDim.new(0, 0)
		else
			padding.PaddingLeft = UDim.new(0, 0)
			padding.PaddingRight = UDim.new(0, 14)
		end
	end
	for _, search in ipairs(CS:GetTagged("SearchContainerBind")) do
		search.LayoutOrder = (align == "Left") and 3 or 1
	end
	for _, prof in ipairs(CS:GetTagged("ProfileBlockBind")) do
		prof.LayoutOrder = 2
	end
	for _, btn in ipairs(CS:GetTagged("CloseBtnBind")) do
		btn.LayoutOrder = (align == "Left") and 1 or 3
	end
	for _, descLabel in ipairs(CS:GetTagged("TopbarDescLabelBind")) do
		if align == "Left" then
			descLabel.Position = UDim2.new(0, 440, 0, 0)
			descLabel.Size = UDim2.new(1, -455, 1, 0)
			descLabel.TextXAlignment = Enum.TextXAlignment.Right
		else
			descLabel.Position = UDim2.new(0, 15, 0, 0)
			descLabel.Size = UDim2.new(1, -455, 1, 0)
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

local FontsList = {}
for _, font in pairs(Enum.Font:GetEnumItems()) do
	if font.Name ~= "Unknown" then table.insert(FontsList, font.Name) end
end
table.sort(FontsList)

local shortKeys = {
	LeftControl = "LC", RightControl = "RC", LeftShift = "LS", RightShift = "RS",
	LeftAlt = "LA", RightAlt = "RA",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	LeftBracket = "[", RightBracket = "]", Semicolon = ";", Quote = "'",
	Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
	Minus = "-", Equals = "=", Backquote = "`",
	Space = "Spc", Tab = "Tab", CapsLock = "Caps", Escape = "Esc",
	Return = "Ent", KeypadZero = "Num0", KeypadOne = "Num1", KeypadTwo = "Num2",
	KeypadThree = "Num3", KeypadFour = "Num4", KeypadFive = "Num5", KeypadSix = "Num6",
	KeypadSeven = "Num7", KeypadEight = "Num8", KeypadNine = "Num9"
}

local function resolveKeycode(value)
	if value == false then return Enum.KeyCode.Unknown end
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then return value end
	if type(value) == "string" then
		local name = value:match("^Enum%.KeyCode%.(.+)$") or value
		return Enum.KeyCode[name]
	end
	return nil
end

local function getShortKey(keyObj)
	if type(keyObj) == "string" then return keyObj end
	if not keyObj or keyObj == Enum.KeyCode.Unknown then return "None" end
	return shortKeys[keyObj.Name] or keyObj.Name
end

local SEARCH_ICON_ID = "rbxassetid://118685771787843"
local SETTINGS_ICON_ID = "rbxassetid://7059346373"

function Library.CreateWindow(arg1, arg2)
	local config = (arg1 == Library and arg2) or (type(arg1) == "table" and arg1) or {}
	local title = config.Title or "iu"
	local searchPlaceholder = config.SearchPlaceholder or "Search components..."
	local logoRaw = config.Logo or config.LogoIcon
	local logoIconId = logoRaw and parseAsset(logoRaw) or nil
	local description = config.Description 
	local isInitiallyCollapsed = (config.Collapsed == true) or (config.SidebarCollapsed == true)
	local notifPosition = config.NotificationPosition or "BottomRight"
	local configFolder = config.ConfigFolder or "AxiomConfigs"
	local watermarkEnabled = (config.Watermark == true) or (config.Watermark == nil and true)
	
	local customTheme = type(config.Theme) == "table" and config.Theme or {}
	local function getSetting(key, fallback)
		if customTheme[key] ~= nil then return customTheme[key] end
		if config[key] ~= nil then return config[key] end
		return fallback
	end
	for k in pairs(THEME) do
		local v = getSetting(k)
		if v ~= nil then THEME[k] = v end
	end
	THEME.HUDTransparency = math.clamp(tonumber(THEME.HUDTransparency) or 0, 0, 1)
	local openKeybind = resolveKeycode(getSetting("OpenKeybind")) or Enum.KeyCode.RightShift
	watermarkEnabled = getSetting("ShowWatermark", config.Watermark ~= false)
	local showSearchBar = getSetting("ShowSearchBar", true)
	local showProfile = getSetting("ShowProfile", true)
	local keybindsEnabled = getSetting("ShowKeybindsHUD", nil)
	if keybindsEnabled == nil then
		if config.Keybinds ~= nil then keybindsEnabled = config.Keybinds
		elseif config.KeybindsMenu ~= nil then keybindsEnabled = config.KeybindsMenu
		elseif config.KeybindsHUD ~= nil then keybindsEnabled = config.KeybindsHUD
		else keybindsEnabled = true end
	end
	local cornerRadiusNum = tonumber(getSetting("CornerRadius", 20)) or 20
	local elCornerRadiusNum = tonumber(getSetting("ElementsCornerRadius", cornerRadiusNum)) or cornerRadiusNum
	local hudCornerRadiusNum = tonumber(getSetting("HUDCornerRadius", 10)) or 10
	local MAIN_CORNER = UDim.new(0, cornerRadiusNum)
	local GLOBAL_CORNER = UDim.new(0, elCornerRadiusNum)

	local function UpdateElementCorners(radius)
		elCornerRadiusNum = radius
		GLOBAL_CORNER = UDim.new(0, radius)
		for _, corner in ipairs(CS:GetTagged("ElementCorner")) do
			corner.CornerRadius = GLOBAL_CORNER
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModernDashboardGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local success, _ = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
	if not success then screenGui.Parent = LP:WaitForChild("PlayerGui") end

	local Window = { 
		Tabs = {}, 
		CurrentTab = nil,
		_connections = {},
		_styleCallbacks = {},
		ActivePopupClose = nil,
		IsEditMode = false,
		_searchRegistry = {},
		_configElements = {},
		_themeElements = {},
		_themeControls = {},
		_blockRegistry = {},
		ConfigFolder = configFolder,
		ThemeFolder = "AxiomUIThemes"
	}

	local notifHolder = Instance.new("Frame")
	notifHolder.Name = "NotificationHolder"
	notifHolder.BackgroundTransparency = 1
	notifHolder.Size = isMobile and UDim2.new(0, 280, 1, -120) or UDim2.new(0, 300, 1, -40)
	notifHolder.ZIndex = 100000
	notifHolder.Parent = screenGui

	local notifLayout = Instance.new("UIListLayout")
	notifLayout.Padding = UDim.new(0, 10)
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	local notifScale = Instance.new("UIScale")
	notifScale.Scale = isMobile and 0.65 or 1
	notifScale.Parent = notifHolder

	local isNotifTop = string.find(notifPosition, "Top") ~= nil
	local isNotifLeft = string.find(notifPosition, "Left") ~= nil

	if isNotifTop and isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(0, 0)
		notifHolder.Position = isMobile and UDim2.new(0, 12, 0, 70) or UDim2.new(0, 20, 0, 20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	elseif isNotifTop and not isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(1, 0)
		notifHolder.Position = isMobile and UDim2.new(1, -12, 0, 70) or UDim2.new(1, -20, 0, 20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	elseif not isNotifTop and isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(0, 1)
		notifHolder.Position = isMobile and UDim2.new(0, 12, 1, -90) or UDim2.new(0, 20, 1, -20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	else 
		notifHolder.AnchorPoint = Vector2.new(1, 1)
		notifHolder.Position = isMobile and UDim2.new(1, -12, 1, -90) or UDim2.new(1, -20, 1, -20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	notifLayout.Parent = notifHolder

	local notifCount = 0

	function Window:Notify(notifConfig)
		local nTitle = notifConfig.Title or "Notification"
		local nContent = notifConfig.Description or notifConfig.Content or ""
		local nDuration = notifConfig.Duration or 5
		local nIcon = parseAsset(notifConfig.Icon)
		local isCompactNotif = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4)

		notifCount = notifCount + 1

		local notifWrapper = Instance.new("Frame")
		notifWrapper.Name = "NotifWrapper"
		notifWrapper.BackgroundTransparency = 1
		notifWrapper.Size = UDim2.new(1, 0, 0, 0)
		notifWrapper.AutomaticSize = Enum.AutomaticSize.Y
		notifWrapper.Parent = notifHolder
		
		if isNotifTop then
			notifWrapper.LayoutOrder = -notifCount
		else
			notifWrapper.LayoutOrder = notifCount
		end

		local notif = Instance.new("Frame")
		notif.Name = "Notification"
		notif.Size = UDim2.new(1, 0, 0, 0)
		notif.AutomaticSize = Enum.AutomaticSize.Y
		notif.BackgroundTransparency = 1
		notif.Parent = notifWrapper
		
		ApplyTheme(notif, "Background", "BackgroundColor3")
		ApplyTheme(notif, "HUDTransparency", "BackgroundTransparency")
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		corner.Parent = notif
		CS:AddTag(corner, "HUDCorner")

		local stroke = Instance.new("UIStroke")
		stroke.Name = "NotificationStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 1
		stroke.Enabled = THEME.MainOutlineEnabled
		stroke.Parent = notif
		ApplyTheme(stroke, "Outlines", "Color")
		CS:AddTag(stroke, "NotificationStrokeBind")

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, isCompactNotif and 10 or 15)
		pad.PaddingBottom = UDim.new(0, isCompactNotif and 10 or 15)
		pad.PaddingLeft = UDim.new(0, isCompactNotif and 11 or 15)
		pad.PaddingRight = UDim.new(0, isCompactNotif and 11 or 15)
		pad.Parent = notif

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, isCompactNotif and 8 or 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = notif

		local topContent = Instance.new("Frame")
		topContent.Name = "TopContent"
		topContent.Size = UDim2.new(1, 0, 0, 0)
		topContent.AutomaticSize = Enum.AutomaticSize.Y
		topContent.BackgroundTransparency = 1
		topContent.LayoutOrder = 1
		topContent.Parent = notif

		local topLayout = Instance.new("UIListLayout")
		topLayout.FillDirection = Enum.FillDirection.Horizontal
		topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		topLayout.Padding = UDim.new(0, isCompactNotif and 9 or 12)
		topLayout.SortOrder = Enum.SortOrder.LayoutOrder
		topLayout.Parent = topContent

		local hasIcon = (nIcon and nIcon ~= "")
		local iconSize = isCompactNotif and 28 or 36
		
		local iconImg
		if hasIcon then
			iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.new(0, iconSize, 0, iconSize)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = nIcon
			iconImg.LayoutOrder = isNotifLeft and 2 or 1
			iconImg.Parent = topContent
			ApplyTheme(iconImg, "Text", "ImageColor3")
		end

		local txtFrame = Instance.new("Frame")
		txtFrame.BackgroundTransparency = 1
		txtFrame.Size = UDim2.new(1, hasIcon and -(iconSize + (isCompactNotif and 9 or 12)) or 0, 0, 0)
		txtFrame.AutomaticSize = Enum.AutomaticSize.Y
		txtFrame.LayoutOrder = isNotifLeft and 1 or 2
		txtFrame.Parent = topContent

		local txtLayout = Instance.new("UIListLayout")
		txtLayout.FillDirection = Enum.FillDirection.Vertical
		txtLayout.Padding = UDim.new(0, 3)
		txtLayout.Parent = txtFrame

		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.Size = UDim2.new(1, 0, 0, 0)
		titleLbl.AutomaticSize = Enum.AutomaticSize.Y
		titleLbl.TextWrapped = true
		titleLbl.TextXAlignment = isNotifLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		titleLbl.TextSize = isCompactNotif and 13 or 15
		titleLbl.Text = nTitle
		titleLbl.Font = Enum.Font.GothamMedium
		titleLbl.Parent = txtFrame
		ApplyTheme(titleLbl, "Text", "TextColor3")
		ApplyTheme(titleLbl, "TextFont", "Font")

		local descLbl = Instance.new("TextLabel")
		descLbl.BackgroundTransparency = 1
		descLbl.Size = UDim2.new(1, 0, 0, 0)
		descLbl.AutomaticSize = Enum.AutomaticSize.Y
		descLbl.TextWrapped = true
		descLbl.TextXAlignment = isNotifLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		descLbl.TextSize = isCompactNotif and 11 or 13
		descLbl.Text = nContent
		descLbl.Parent = txtFrame
		ApplyTheme(descLbl, "TextMuted", "TextColor3")
		ApplyTheme(descLbl, "SubtextFont", "Font")

		local bottomContainer = Instance.new("Frame")
		bottomContainer.Name = "BottomContainer"
		bottomContainer.Size = UDim2.new(1, 0, 0, isCompactNotif and 16 or 20)
		bottomContainer.BackgroundTransparency = 1
		bottomContainer.LayoutOrder = 2
		bottomContainer.Parent = notif

		local badgeW = isCompactNotif and 36 or 40
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Size = UDim2.new(1, -(badgeW + 8), 0, isCompactNotif and 3 or 4)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0, 0, 0.5, 0)
		track.BorderSizePixel = 0
		track.Parent = bottomContainer
		ApplyTheme(track, "Input", "BackgroundColor3")
		ApplyTheme(track, "InputTrans", "BackgroundTransparency")
		
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BorderSizePixel = 0
		fill.Parent = track
		ApplyTheme(fill, "Accent", "BackgroundColor3")
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local timeBadge = Instance.new("Frame")
		timeBadge.Name = "TimeBadge"
		timeBadge.Size = UDim2.new(0, badgeW, 1, 0)
		timeBadge.AnchorPoint = Vector2.new(1, 0.5)
		timeBadge.Position = UDim2.new(1, 0, 0.5, 0)
		timeBadge.BorderSizePixel = 0
		timeBadge.Parent = bottomContainer
		ApplyTheme(timeBadge, "Input", "BackgroundColor3")
		ApplyTheme(timeBadge, "InputTrans", "BackgroundTransparency")

		local timeBadgeCorner = Instance.new("UICorner")
		timeBadgeCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		timeBadgeCorner.Parent = timeBadge
		CS:AddTag(timeBadgeCorner, "HUDCorner")

		local timeBadgeStroke = Instance.new("UIStroke")
		timeBadgeStroke.Name = "TimeBadgeStroke"
		timeBadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		timeBadgeStroke.Thickness = 1
		timeBadgeStroke.Parent = timeBadge
		ApplyTheme(timeBadgeStroke, "Outlines", "Color")

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Name = "TimeLabel"
		timeLabel.Size = UDim2.new(1, 0, 1, 0)
		timeLabel.Position = UDim2.new(0, 0, 0, -1)
		timeLabel.BackgroundTransparency = 1
		timeLabel.TextSize = isCompactNotif and 10 or 11
		timeLabel.TextXAlignment = Enum.TextXAlignment.Center
		timeLabel.Text = string.format("%.1fs", nDuration)
		timeLabel.Parent = timeBadge
		ApplyTheme(timeLabel, "TextMuted", "TextColor3")
		ApplyTheme(timeLabel, "SubtextFont", "Font")

		notif.Position = isNotifLeft and UDim2.new(0, -350, 0, 0) or UDim2.new(0, 350, 0, 0)
		
		notif.BackgroundTransparency = 1
		TS:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = THEME.HUDTransparency,
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

		TS:Create(fill, TweenInfo.new(nDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0)
		}):Play()

		local startTime = os.clock()
		local connection
		local lastFormatted = ""
		connection = RS.RenderStepped:Connect(function()
			local remaining = math.max(0, nDuration - (os.clock() - startTime))
			local formatted = string.format("%.1fs", remaining)
			if formatted ~= lastFormatted then
				lastFormatted = formatted
				timeLabel.Text = formatted
			end
			if remaining <= 0 then
				if connection then 
					connection:Disconnect() 
					connection = nil 
				end
			end
		end)
		
		local function closeNotification()
			local fadeOut = TS:Create(notif, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				Position = isNotifLeft and UDim2.new(0, -350, 0, 0) or UDim2.new(0, 350, 0, 0)
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if connection then 
					connection:Disconnect() 
					connection = nil 
				end
				notifWrapper:Destroy()
			end)
		end

		task.delay(nDuration, closeNotification)
		
		local api = {}
		function api:SetTitle(newTitle)
			if titleLbl then titleLbl.Text = newTitle end
		end
		function api:SetDescription(newDesc)
			if descLbl then descLbl.Text = newDesc end
		end
		function api:SetIcon(newIcon)
			if iconImg then iconImg.Image = parseAsset(newIcon) end
		end
		function api:Close()
			closeNotification()
		end
		return api
	end

	local function attachStroke(obj, tag)
		local s = Instance.new("UIStroke")
		s.Name = obj.Name .. "Stroke"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = 1
		if tag == "BlockStroke" then
			s.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
		else
			s.Enabled = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")
		end
		s.Parent = obj
		ApplyTheme(s, "Outlines", "Color")
		CS:AddTag(s, tag)
		return s
	end

	local mobileBindOrder = 0

	local function createMobileBindButton(text, callback)
		local btn = Instance.new("TextButton")
		btn.Name = "MobileBindButton"
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		mobileBindOrder = mobileBindOrder + 1
		btn.Position = UDim2.new(1, -78, 1, -180 - ((mobileBindOrder - 1) * 54))
		btn.AutoButtonColor = false
		btn.BackgroundTransparency = 0
		btn.Text = text or "None"
		btn.TextSize = 13
		btn.TextWrapped = true
		btn.Font = Enum.Font.GothamMedium
		btn.Active = true
		btn.ZIndex = 100001
		btn.Parent = screenGui
		ApplyTheme(btn, "Element", "BackgroundColor3")
		ApplyTheme(btn, "ElementTrans", "BackgroundTransparency")
		ApplyTheme(btn, "Text", "TextColor3")
		ApplyTheme(btn, "TextFont", "Font")

		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = btn
		CS:AddTag(corner, "ElementCorner")

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn
		ApplyTheme(stroke, "Outlines", "Color")
		CS:AddTag(stroke, "ElementStroke")

		local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false
		table.insert(Window._connections, btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				moved = false
				dragStart = input.Position
				startPos = btn.Position
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if conn then conn:Disconnect() end
					end
				end)
				table.insert(Window._connections, conn)
			end
		end))
		table.insert(Window._connections, btn.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
				dragInput = input
			end
		end))
		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if dragging and input == dragInput then
				local delta = input.Position - dragStart
				if delta.Magnitude > 8 then moved = true end
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
		table.insert(Window._connections, btn.MouseButton1Click:Connect(function()
			if not moved then callback() end
		end))
		return btn
	end

	local function createMobileToggle(parent, callback)
		local box = Instance.new("TextButton")
		box.Name = "MobileBindToggle"
		box.Size = UDim2.new(0, 20, 0, 20)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.Text = ""
		box.ZIndex = 5
		box.Parent = parent

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = box
		ApplyTheme(stroke, "Outlines", "Color")

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.AnchorPoint = Vector2.new(0.5, 0.5)
		fill.Position = UDim2.new(0.5, 0, 0.5, 0)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(0, 0, 0, 0)
		fill.Parent = box
		ApplyTheme(fill, "Accent", "BackgroundColor3")

		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = box
		CS:AddTag(corner, "ElementCorner")

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = GLOBAL_CORNER
		fillCorner.Parent = fill
		CS:AddTag(fillCorner, "ElementCorner")

		local enabled = false
		local mobileBtn
		local function setEnabled(value)
			enabled = value
			if enabled then
				ApplyTheme(stroke, "Accent", "Color")
				TS:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -6, 1, -6)}):Play()
			else
				ApplyTheme(stroke, "Outlines", "Color")
				TS:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
			end
			callback(enabled, function()
				if mobileBtn then
					mobileBtn:Destroy()
					mobileBtn = nil
				end
			end, function(btn)
				mobileBtn = btn
			end)
		end
		table.insert(Window._connections, box.MouseButton1Click:Connect(function()
			setEnabled(not enabled)
		end))
		return box, setEnabled, function() return mobileBtn end
	end

	local initShadows = true
	if customTheme.DropShadows ~= nil then
		initShadows = (customTheme.DropShadows == true)
	elseif config.DropShadows ~= nil then
		initShadows = (config.DropShadows == true)
	end

	local SIDEBAR_STATE = {
		Position = customTheme.SidebarPosition or config.SidebarPosition or "Left",
		Detached = getSetting("DetachedSidebar", false),
		ShadowsEnabled = initShadows
	}

	local editModeBackdrop = Instance.new("Frame")
	editModeBackdrop.Name = "EditModeBackdrop"
	editModeBackdrop.Size = UDim2.new(1, 0, 1, 0)
	editModeBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	editModeBackdrop.BackgroundTransparency = 1
	editModeBackdrop.ZIndex = 400
	editModeBackdrop.Visible = false
	editModeBackdrop.Parent = screenGui

	local editModeBlur = Instance.new("BlurEffect")
	editModeBlur.Name = "UI_EditMode_Blur"
	editModeBlur.Size = 0
	editModeBlur.Parent = Lighting
	
	local uiScaleValue = isMobile and 0.65 or 1
	local finalW, finalH
	do
		local targetSize = config.WindowSize or Vector2.new(950, 600)
		local reqW = typeof(targetSize) == "Vector2" and targetSize.X or targetSize[1] or 950
		local reqH = typeof(targetSize) == "Vector2" and targetSize.Y or targetSize[2] or 600
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local maxAvailW = (viewport.X / uiScaleValue) - 40 
		local maxAvailH = (viewport.Y / uiScaleValue) - 40 
		local minUIW = isMobile and 350 or 500
		local minUIH = isMobile and 250 or 350
		finalW = math.clamp(reqW, minUIW, math.max(minUIW, maxAvailW))
		finalH = math.clamp(reqH, minUIH, math.max(minUIH, maxAvailH))
	end

	local wrapper = Instance.new("Frame")
	wrapper.Name = "Wrapper"
	wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
	wrapper.Size = UDim2.new(0, finalW, 0, finalH)
	wrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
	wrapper.BackgroundTransparency = 1
	wrapper.Active = true 
	wrapper.Parent = screenGui

	do
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = uiScaleValue
		uiScale.Parent = wrapper
	end

	local contentWrapper = Instance.new("Frame")
	contentWrapper.Name = "ContentWrapper"
	contentWrapper.Size = UDim2.new(1, 0, 1, 0)
	contentWrapper.BackgroundTransparency = 1
	contentWrapper.Parent = wrapper

	local shadowFolder = Instance.new("Frame")
	shadowFolder.Name = "Shadows"
	shadowFolder.Size = UDim2.new(1, 0, 1, 0)
	shadowFolder.BackgroundTransparency = 1
	shadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
	shadowFolder.ZIndex = 0
	shadowFolder.Parent = contentWrapper

	local sidebarShadowFolder = Instance.new("Frame")
	sidebarShadowFolder.Name = "SidebarShadows"
	sidebarShadowFolder.Size = UDim2.new(1, 0, 1, 0)
	sidebarShadowFolder.BackgroundTransparency = 1
	sidebarShadowFolder.ZIndex = 0
	sidebarShadowFolder.Visible = false
	sidebarShadowFolder.Parent = contentWrapper

	local shadowLayers = 8
	for i = 1, shadowLayers do
		local trans = 0.8 + (i * 0.02)
		local shadow = Instance.new("Frame")
		shadow.Name = "ShadowLayer" .. i
		shadow.BackgroundTransparency = 1
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, 0) 
		shadow.Size = UDim2.new(1, 0, 1, 0)
		shadow.ZIndex = 0
		shadow.BorderSizePixel = 0
		shadow.Parent = shadowFolder
		
		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
		shadowCorner.Parent = shadow
		CS:AddTag(shadowCorner, "MainCorner")
		
		local shadowStroke = Instance.new("UIStroke")
		shadowStroke.Name = "ShadowStroke"
		shadowStroke.Color = Color3.fromRGB(0, 0, 0)
		shadowStroke.Transparency = trans
		shadowStroke:SetAttribute("TargetTransparency", trans)
		shadowStroke.Thickness = i * 2.5
		shadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		shadowStroke.Enabled = SIDEBAR_STATE.ShadowsEnabled
		shadowStroke.Parent = shadow

		local sidebarShadow = Instance.new("Frame")
		sidebarShadow.Name = "ShadowLayer" .. i
		sidebarShadow.BackgroundTransparency = 1
		sidebarShadow.AnchorPoint = Vector2.new(0.5, 0.5)
		sidebarShadow.Position = UDim2.new(0.5, 0, 0.5, 0) 
		sidebarShadow.Size = UDim2.new(1, 0, 1, 0)
		sidebarShadow.ZIndex = 0
		sidebarShadow.BorderSizePixel = 0
		sidebarShadow.Parent = sidebarShadowFolder
		
		local sidebarShadowCorner = Instance.new("UICorner")
		sidebarShadowCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
		sidebarShadowCorner.Parent = sidebarShadow
		CS:AddTag(sidebarShadowCorner, "MainCorner")
		
		local sidebarShadowStroke = Instance.new("UIStroke")
		sidebarShadowStroke.Name = "ShadowStroke"
		sidebarShadowStroke.Color = Color3.fromRGB(0, 0, 0)
		sidebarShadowStroke.Transparency = trans
		sidebarShadowStroke:SetAttribute("TargetTransparency", trans)
		sidebarShadowStroke.Thickness = i * 2.5
		sidebarShadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		sidebarShadowStroke.Enabled = (SIDEBAR_STATE.ShadowsEnabled and SIDEBAR_STATE.Detached)
		sidebarShadowStroke.Parent = sidebarShadow
	end

	local main = Instance.new("CanvasGroup")
	main.Name = "MainFrame"
	main.Size = UDim2.new(1, 0, 1, 0)
	main.Position = UDim2.new(0, 0, 0, 0)
	main.BorderSizePixel = 0
	main.ZIndex = 2
	main.BackgroundTransparency = 1
	main.Parent = contentWrapper
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = MAIN_CORNER
	mainCorner.Parent = main
	CS:AddTag(mainCorner, "MainCorner")

	local mainOutlineStroke = Instance.new("UIStroke")
	mainOutlineStroke.Name = "MainOutlineStroke"
	mainOutlineStroke.Enabled = false 
	mainOutlineStroke.Thickness = 1
	mainOutlineStroke.Parent = main
	ApplyTheme(mainOutlineStroke, "Outlines", "Color")

	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.ZIndex = 0 
	bgImage.BackgroundTransparency = 1
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.Parent = main
	ApplyTheme(bgImage, "BgImageTrans", "ImageTransparency")
	ApplyTheme(bgImage, "BackgroundImage", "Image")

	local bgColorOverlay = Instance.new("Frame")
	bgColorOverlay.Name = "BackgroundColorOverlay"
	bgColorOverlay.Size = UDim2.new(1, 0, 1, 0)
	bgColorOverlay.ZIndex = 1 
	bgColorOverlay.BorderSizePixel = 0
	bgColorOverlay.Parent = main
	ApplyTheme(bgColorOverlay, "Background", "BackgroundColor3")
	ApplyTheme(bgColorOverlay, "BackgroundTrans", "BackgroundTransparency")

	local bgFXHolder = Instance.new("Frame")
	bgFXHolder.Name = "BackgroundFXHolder"
	bgFXHolder.Size = UDim2.new(1, 0, 1, 0)
	bgFXHolder.BackgroundTransparency = 1
	bgFXHolder.ClipsDescendants = true
	bgFXHolder.ZIndex = 1
	bgFXHolder.Parent = main

	local currentFXConnection = nil
	local fxElements = {}

	local function clearFX()
		if currentFXConnection then
			currentFXConnection:Disconnect()
			currentFXConnection = nil
		end
		for _, el in ipairs(fxElements) do
			if typeof(el) == "Instance" then el:Destroy() end
		end
		table.clear(fxElements)
	end

	local function initBackgroundFX(mode)
		clearFX()
		if mode == "None" then return end

		if mode == "Constellation" then
			local count = 22
			local nodes = {}
			local linesPool = {}
			for i = 1, count do
				local node = Instance.new("Frame")
				node.Size = UDim2.new(0, 4, 0, 4)
				node.AnchorPoint = Vector2.new(0.5, 0.5)
				node.BorderSizePixel = 0
				node.BackgroundTransparency = 0.3
				ApplyTheme(node, "Accent", "BackgroundColor3")
				local nc = Instance.new("UICorner")
				nc.CornerRadius = UDim.new(1, 0)
				nc.Parent = node
				node.Parent = bgFXHolder
				table.insert(fxElements, node)
				table.insert(nodes, {
					Obj = node,
					X = math.random() * (bgFXHolder.AbsoluteSize.X > 0 and bgFXHolder.AbsoluteSize.X or 800),
					Y = math.random() * (bgFXHolder.AbsoluteSize.Y > 0 and bgFXHolder.AbsoluteSize.Y or 500),
					VX = (math.random() - 0.5) * 32,
					VY = (math.random() - 0.5) * 32
				})
			end
			for i = 1, 45 do
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.BorderSizePixel = 0
				line.Visible = false
				ApplyTheme(line, "Accent", "BackgroundColor3")
				line.Parent = bgFXHolder
				table.insert(fxElements, line)
				table.insert(linesPool, line)
			end
			currentFXConnection = RS.RenderStepped:Connect(function(dt)
				if not bgFXHolder.Parent then return end
				local w, h = bgFXHolder.AbsoluteSize.X, bgFXHolder.AbsoluteSize.Y
				if w <= 10 or h <= 10 then return end
				for _, n in ipairs(nodes) do
					n.X = n.X + (n.VX * dt)
					n.Y = n.Y + (n.VY * dt)
					if n.X <= 0 then n.X = 0; n.VX = -n.VX end
					if n.X >= w then n.X = w; n.VX = -n.VX end
					if n.Y <= 0 then n.Y = 0; n.VY = -n.VY end
					if n.Y >= h then n.Y = h; n.VY = -n.VY end
					n.Obj.Position = UDim2.new(0, n.X, 0, n.Y)
				end
				local lineIdx = 1
				local maxDist = 95
				for i = 1, #nodes do
					for j = i + 1, #nodes do
						local p1, p2 = nodes[i], nodes[j]
						local dx = p2.X - p1.X
						local dy = p2.Y - p1.Y
						local dist = math.sqrt((dx * dx) + (dy * dy))
						if dist < maxDist and lineIdx <= #linesPool then
							local line = linesPool[lineIdx]
							lineIdx = lineIdx + 1
							local midX = (p1.X + p2.X) * 0.5
							local midY = (p1.Y + p2.Y) * 0.5
							local angle = math.deg(math.atan2(dy, dx))
							line.Size = UDim2.new(0, dist, 0, 1)
							line.Position = UDim2.new(0, midX, 0, midY)
							line.Rotation = angle
							line.BackgroundTransparency = 0.4 + (0.55 * (dist / maxDist))
							line.Visible = true
						end
					end
				end
				for k = lineIdx, #linesPool do
					linesPool[k].Visible = false
				end
			end)
		elseif mode == "Matrix Dots" then
			local dotSize = 3
			local spacing = 34
			local matrix = {}
			local function spawnMatrix()
				for _, el in ipairs(fxElements) do el:Destroy() end
				table.clear(fxElements)
				table.clear(matrix)
				local w, h = bgFXHolder.AbsoluteSize.X, bgFXHolder.AbsoluteSize.Y
				if w <= 10 or h <= 10 then return end
				local cols = math.floor(w / spacing)
				local rows = math.floor(h / spacing)
				for r = 0, rows do
					for c = 0, cols do
						local dot = Instance.new("Frame")
						dot.Size = UDim2.new(0, dotSize, 0, dotSize)
						dot.AnchorPoint = Vector2.new(0.5, 0.5)
						dot.Position = UDim2.new(0, (c * spacing) + 16, 0, (r * spacing) + 16)
						dot.BorderSizePixel = 0
						dot.BackgroundTransparency = 0.95
						ApplyTheme(dot, "Accent", "BackgroundColor3")
						local cObj = Instance.new("UICorner")
						cObj.CornerRadius = UDim.new(1, 0)
						cObj.Parent = dot
						dot.Parent = bgFXHolder
						table.insert(fxElements, dot)
						table.insert(matrix, {Dot = dot, Seed = math.random() * 100})
					end
				end
			end
			spawnMatrix()
			table.insert(Window._connections, bgFXHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(spawnMatrix))
			currentFXConnection = RS.RenderStepped:Connect(function()
				local t = os.clock() * 1.5
				for _, item in ipairs(matrix) do
					local val = math.sin(t + item.Seed) * math.cos((t * 0.7) + (item.Seed * 0.4))
					if val > 0.45 then
						item.Dot.BackgroundTransparency = 0.25 + ((1 - val) * 1.1)
					else
						item.Dot.BackgroundTransparency = 0.94
					end
				end
			end)
		elseif mode == "Floating Sparks" then
			local sparksCount = 30
			local sparks = {}
			for i = 1, sparksCount do
				local s = Instance.new("Frame")
				local sz = math.random(2, 4)
				s.Size = UDim2.new(0, sz, 0, sz)
				s.AnchorPoint = Vector2.new(0.5, 0.5)
				s.BorderSizePixel = 0
				s.BackgroundTransparency = math.random(20, 60) / 100
				ApplyTheme(s, "Accent", "BackgroundColor3")
				local sc = Instance.new("UICorner")
				sc.CornerRadius = UDim.new(1, 0)
				sc.Parent = s
				s.Parent = bgFXHolder
				table.insert(fxElements, s)
				table.insert(sparks, {
					Obj = s,
					X = math.random() * (bgFXHolder.AbsoluteSize.X > 0 and bgFXHolder.AbsoluteSize.X or 800),
					Y = math.random() * (bgFXHolder.AbsoluteSize.Y > 0 and bgFXHolder.AbsoluteSize.Y or 500),
					Speed = math.random(15, 45),
					Sway = math.random(1, 3),
					Offset = math.random() * 10
				})
			end
			currentFXConnection = RS.RenderStepped:Connect(function(dt)
				local w, h = bgFXHolder.AbsoluteSize.X, bgFXHolder.AbsoluteSize.Y
				if w <= 10 or h <= 10 then return end
				local t = os.clock()
				for _, sp in ipairs(sparks) do
					sp.Y = sp.Y - (sp.Speed * dt)
					local wave = math.sin(t * sp.Sway + sp.Offset) * 20 * dt
					sp.X = sp.X + wave
					if sp.Y <= -5 then
						sp.Y = h + 5
						sp.X = math.random() * w
					end
					sp.Obj.Position = UDim2.new(0, sp.X, 0, sp.Y)
				end
			end)
		end
	end

	task.spawn(function()
		task.wait(0.2)
		initBackgroundFX(THEME.BackgroundEffect)
	end)

	local dragArea = Instance.new("Frame")
	dragArea.Name = "DragArea"
	dragArea.Size = UDim2.new(1, 0, 0, 60)
	dragArea.BackgroundTransparency = 1
	dragArea.Active = true
	dragArea.ZIndex = 10
	dragArea.Parent = wrapper

	local dragging, dragInput, dragStart, startPos
	local targetPos = wrapper.Position
	local dragConn = nil

	local function startDragLoop()
		if dragConn then return end
		dragConn = RS.RenderStepped:Connect(function(dt)
			if not wrapper.Parent then
				if dragConn then dragConn:Disconnect(); dragConn = nil end
				return
			end
			local diffX = math.abs(wrapper.Position.X.Offset - targetPos.X.Offset)
			local diffY = math.abs(wrapper.Position.Y.Offset - targetPos.Y.Offset)
			if diffX > 0.1 or diffY > 0.1 then
				wrapper.Position = wrapper.Position:Lerp(targetPos, 1 - math.exp(-28 * dt))
			else
				wrapper.Position = targetPos
				if not dragging then
					dragConn:Disconnect()
					dragConn = nil
				end
			end
		end)
		table.insert(Window._connections, dragConn)
	end

	table.insert(Window._connections, dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetPos
			startDragLoop()
			local inputEndConn
			inputEndConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					inputEndConn:Disconnect()
				end
			end)
			table.insert(Window._connections, inputEndConn)
		end
	end))

	table.insert(Window._connections, dragArea.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			startDragLoop()
		end
	end))

	local resizeHitbox = Instance.new("TextButton")
	resizeHitbox.Name = "ResizeHitbox"
	resizeHitbox.Size = UDim2.new(0, isMobile and 64 or 50, 0, isMobile and 64 or 50)
	resizeHitbox.Position = UDim2.new(1, 10, 1, 10) 
	resizeHitbox.AnchorPoint = Vector2.new(1, 1)
	resizeHitbox.BackgroundTransparency = 1
	resizeHitbox.Text = ""
	resizeHitbox.Active = true
	resizeHitbox.ZIndex = 20
	resizeHitbox.Parent = wrapper

	local arcOuterStroke, topCap, leftCap
	do
		local WINDOW_CORNER = cornerRadiusNum
		local GAP = 5
		local STROKE_THICKNESS = 4
		local R_CENTER = WINDOW_CORNER + GAP 
		local FRAME_RADIUS = R_CENTER - (STROKE_THICKNESS / 2) 
		local OUTER_RADIUS = R_CENTER + (STROKE_THICKNESS / 2) 
		local CAP_OFFSET = 4 
		local CAP_X = math.sqrt(math.max(0, R_CENTER^2 - CAP_OFFSET^2)) + 0.5 
		local CAP_SIZE = STROKE_THICKNESS + 0.6 
		
		local arcMaster = Instance.new("Frame")
		arcMaster.Name = "ArcMaster"
		arcMaster.Size = UDim2.new(0, OUTER_RADIUS, 0, OUTER_RADIUS)
		arcMaster.Position = UDim2.new(1, -WINDOW_CORNER, 1, -WINDOW_CORNER) 
		arcMaster.BackgroundTransparency = 1
		arcMaster.ZIndex = 3
		arcMaster.Parent = contentWrapper

		local arcClipped = Instance.new("Frame")
		arcClipped.Name = "ArcClipped"
		arcClipped.Size = UDim2.new(1, -CAP_OFFSET, 1, -CAP_OFFSET)
		arcClipped.Position = UDim2.new(0, CAP_OFFSET, 0, CAP_OFFSET)
		arcClipped.BackgroundTransparency = 1
		arcClipped.ClipsDescendants = true
		arcClipped.Parent = arcMaster

		local arcOuter = Instance.new("Frame")
		arcOuter.Name = "ArcOuter"
		arcOuter.Size = UDim2.new(0, FRAME_RADIUS * 2, 0, FRAME_RADIUS * 2) 
		arcOuter.Position = UDim2.new(0, -CAP_OFFSET, 0, -CAP_OFFSET) 
		arcOuter.AnchorPoint = Vector2.new(0.5, 0.5) 
		arcOuter.BackgroundTransparency = 1
		arcOuter.Parent = arcClipped
		
		local arcOuterCorner = Instance.new("UICorner")
		arcOuterCorner.CornerRadius = UDim.new(0, FRAME_RADIUS)
		arcOuterCorner.Parent = arcOuter
		CS:AddTag(arcOuterCorner, "MainCorner")

		arcOuterStroke = Instance.new("UIStroke")
		arcOuterStroke.Name = "ArcOuterStroke"
		arcOuterStroke.Thickness = STROKE_THICKNESS
		arcOuterStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border 
		arcOuterStroke.Parent = arcOuter
		ApplyTheme(arcOuterStroke, "TextMuted", "Color")

		topCap = Instance.new("Frame")
		topCap.Name = "TopCap"
		topCap.Size = UDim2.new(0, CAP_SIZE, 0, CAP_SIZE)
		topCap.Position = UDim2.new(0, CAP_X, 0, CAP_OFFSET) 
		topCap.AnchorPoint = Vector2.new(0.5, 0.5)
		topCap.BorderSizePixel = 0
		topCap.Parent = arcMaster
		ApplyTheme(topCap, "TextMuted", "BackgroundColor3")
		
		local topCapCorner = Instance.new("UICorner")
		topCapCorner.CornerRadius = UDim.new(1, 0)
		topCapCorner.Parent = topCap

		leftCap = topCap:Clone()
		leftCap.Name = "LeftCap"
		leftCap.Position = UDim2.new(0, CAP_OFFSET, 0, CAP_X) 
		leftCap.Parent = arcMaster
	end

	local resizing = false
	local resizeStartPos, resizeStartSize

	table.insert(Window._connections, resizeHitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStartPos = input.Position
			resizeStartSize = wrapper.AbsoluteSize
			local inputEndConn
			inputEndConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
					inputEndConn:Disconnect()
				end
			end)
			table.insert(Window._connections, inputEndConn)
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local scaleMultiplier = isMobile and 0.65 or 1
			local delta = (input.Position - resizeStartPos) / scaleMultiplier
			local sw, sh = screenGui.AbsoluteSize.X, screenGui.AbsoluteSize.Y
			local minResW = isMobile and 350 or 500
			local minResH = isMobile and 250 or 350
			local maxResW = math.max(minResW, (sw / scaleMultiplier) - 40)
			local maxResH = math.max(minResH, (sh / scaleMultiplier) - 40)
			wrapper.Size = UDim2.new(0, math.clamp(resizeStartSize.X + (delta.X * 2), minResW, maxResW), 0, math.clamp(resizeStartSize.Y + (delta.Y * 2), minResH, maxResH))
		end
	end))

	Window.Overlay = Instance.new("TextButton")
	Window.Overlay.Name = "PopupOverlay"
	Window.Overlay.Size = UDim2.new(1, 0, 1, 0)
	Window.Overlay.BackgroundTransparency = 1
	Window.Overlay.Text = ""
	Window.Overlay.ZIndex = 100000
	Window.Overlay.Visible = false
	Window.Overlay.Parent = screenGui 

	Window.ClosePopup = function()
		if Window.ActivePopup then
			local p = Window.ActivePopup
			Window.ActivePopup = nil
			if Window.ActivePopupClose then
				Window.ActivePopupClose()
				Window.ActivePopupClose = nil
			else
				p.Visible = false
				if not Window.ActivePopup then Window.Overlay.Visible = false end
			end
		end
	end

	table.insert(Window._connections, Window.Overlay.MouseButton1Click:Connect(Window.ClosePopup))

	local MIN_SIDEBAR_WIDTH = isMobile and 48 or 58 
	local MAX_SIDEBAR_WIDTH = isMobile and 150 or 210
	local currentSidebarWidth = getSetting("SidebarWidth", isInitiallyCollapsed and MIN_SIDEBAR_WIDTH or MAX_SIDEBAR_WIDTH)
	local savedSidebarWidth = currentSidebarWidth

	local sidebarVisuals = Instance.new("Frame")
	sidebarVisuals.Name = "SidebarVisuals"
	sidebarVisuals.Size = UDim2.new(0, currentSidebarWidth, 1, 0)
	sidebarVisuals.BorderSizePixel = 0
	sidebarVisuals.ZIndex = 3 
	sidebarVisuals.BackgroundTransparency = 1 
	sidebarVisuals.Parent = main
	
	local svCorner = Instance.new("UICorner")
	svCorner.CornerRadius = MAIN_CORNER
	svCorner.Parent = sidebarVisuals
	CS:AddTag(svCorner, "MainCorner")

	local sidebarBgImage = Instance.new("ImageLabel")
	sidebarBgImage.Name = "SidebarBackgroundImage"
	sidebarBgImage.Size = UDim2.new(1, 0, 1, 0)
	sidebarBgImage.ZIndex = 0 
	sidebarBgImage.BackgroundTransparency = 1
	sidebarBgImage.ScaleType = Enum.ScaleType.Crop
	sidebarBgImage.Visible = false
	sidebarBgImage.Parent = sidebarVisuals
	ApplyTheme(sidebarBgImage, "BgImageTrans", "ImageTransparency")
	ApplyTheme(sidebarBgImage, "BackgroundImage", "Image")

	local sidebarBase = Instance.new("Frame")
	sidebarBase.Name = "SidebarBase"
	sidebarBase.Size = UDim2.new(1, 0, 1, 0)
	sidebarBase.ZIndex = 1
	sidebarBase.BorderSizePixel = 0
	sidebarBase.Parent = sidebarVisuals
	ApplyTheme(sidebarBase, "Sidebar", "BackgroundColor3")
	ApplyTheme(sidebarBase, "BackgroundTrans", "BackgroundTransparency")
	
	local sidebarBaseCorner = Instance.new("UICorner")
	sidebarBaseCorner.CornerRadius = MAIN_CORNER
	sidebarBaseCorner.Parent = sidebarBase
	CS:AddTag(sidebarBaseCorner, "MainCorner")

	local sidebarFiller = Instance.new("Frame")
	sidebarFiller.Name = "SidebarFiller"
	sidebarFiller.ZIndex = 1
	sidebarFiller.BorderSizePixel = 0
	sidebarFiller.Parent = sidebarVisuals
	ApplyTheme(sidebarFiller, "Sidebar", "BackgroundColor3")
	ApplyTheme(sidebarFiller, "BackgroundTrans", "BackgroundTransparency")

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, currentSidebarWidth, 1, 0)
	sidebar.BorderSizePixel = 0
	sidebar.BackgroundTransparency = 1
	sidebar.ZIndex = 5
	sidebar.Parent = main
	
	local sidebarCorner = Instance.new("UICorner")
	sidebarCorner.CornerRadius = MAIN_CORNER
	sidebarCorner.Parent = sidebar
	CS:AddTag(sidebarCorner, "MainCorner")

	local sidebarOutlineStroke = Instance.new("UIStroke")
	sidebarOutlineStroke.Name = "SidebarOutlineStroke"
	sidebarOutlineStroke.Enabled = false 
	sidebarOutlineStroke.Thickness = 1
	sidebarOutlineStroke.Parent = sidebar
	ApplyTheme(sidebarOutlineStroke, "Outlines", "Color")

	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.Size = UDim2.new(1, 0, 0, 60)
	logoContainer.Position = UDim2.new(0, 0, 0, -2)
	logoContainer.BackgroundTransparency = 1
	logoContainer.ClipsDescendants = true
	logoContainer.Parent = sidebar

	local logoLayout = Instance.new("UIListLayout")
	logoLayout.Name = "LogoLayout"
	logoLayout.FillDirection = Enum.FillDirection.Horizontal
	logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	logoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	logoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logoLayout.Padding = UDim.new(0, 10)
	logoLayout.Parent = logoContainer
	
	local logoPadding = Instance.new("UIPadding")
	logoPadding.Name = "LogoPadding"
	logoPadding.PaddingLeft = UDim.new(0, 0)
	logoPadding.Parent = logoContainer

	local logoImage, logoLabel
	if logoIconId and logoIconId ~= "" then
		logoImage = Instance.new("ImageLabel")
		logoImage.Name = "LogoImage"
		logoImage.Size = UDim2.new(0, 32, 0, 32) 
		logoImage.BackgroundTransparency = 1
		logoImage.Image = logoIconId
		logoImage.LayoutOrder = 1
		logoImage.Parent = logoContainer
	end

	logoLabel = Instance.new("TextLabel")
	logoLabel.Name = "LogoLabel"
	logoLabel.AutomaticSize = Enum.AutomaticSize.X
	logoLabel.Size = UDim2.new(0, 0, 1, 0)
	logoLabel.BackgroundTransparency = 1
	logoLabel.TextSize = 30 
	logoLabel.Text = title
	logoLabel.TextTruncate = Enum.TextTruncate.AtEnd
	logoLabel.LayoutOrder = 2
	logoLabel.Parent = logoContainer
	ApplyTheme(logoLabel, "Text", "TextColor3")
	ApplyTheme(logoLabel, "TextFont", "Font")

	local sidebarDivider = Instance.new("Frame")
	sidebarDivider.Name = "SidebarDivider"
	sidebarDivider.Size = UDim2.new(1, 0, 0, 1)
	sidebarDivider.Position = UDim2.new(0, 0, 0, 60)
	sidebarDivider.BorderSizePixel = 0
	sidebarDivider.ZIndex = 6
	sidebarDivider.Parent = sidebar
	ApplyTheme(sidebarDivider, "Outlines", "BackgroundColor3")

	local tabList = Instance.new("ScrollingFrame")
	tabList.Name = "TabList"
	tabList.Size = UDim2.new(1, -20, 1, (description and type(description) == "string") and -140 or -90) 
	tabList.Position = UDim2.new(0, 10, 0, 75)
	tabList.BackgroundTransparency = 1
	tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabList.ScrollBarThickness = 2
	tabList.Parent = sidebar
	ApplyTheme(tabList, "Outlines", "ScrollBarImageColor3")

	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Name = "TabListLayout"
	tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tabListLayout.Padding = UDim.new(0, 4)
	tabListLayout.Parent = tabList

	local tabListPadding = Instance.new("UIPadding")
	tabListPadding.Name = "TabListPadding"
	tabListPadding.PaddingTop = UDim.new(0, 2)
	tabListPadding.PaddingBottom = UDim.new(0, 2)
	tabListPadding.PaddingLeft = UDim.new(0, 2)
	tabListPadding.PaddingRight = UDim.new(0, 2)
	tabListPadding.Parent = tabList
	
	local settingsContainer = Instance.new("Frame")
	settingsContainer.Name = "SettingsContainer"
	settingsContainer.Size = UDim2.new(0, 70, 1, 0)
	settingsContainer.Position = UDim2.new(1, -70, 0, 0)
	settingsContainer.BackgroundTransparency = 1
	settingsContainer.Visible = false
	settingsContainer.Parent = sidebar

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.FillDirection = Enum.FillDirection.Horizontal
	settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	settingsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Padding = UDim.new(0, 4)
	settingsLayout.Parent = settingsContainer

	local dividerContainer = Instance.new("Frame")
	dividerContainer.Name = "DividerContainer"
	dividerContainer.Size = UDim2.new(1, 0, 0, 16)
	dividerContainer.BackgroundTransparency = 1
	dividerContainer.LayoutOrder = 9998
	dividerContainer.Parent = tabList

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.8, 0, 0, 1)
	divider.Position = UDim2.new(0.5, 0, 0.5, 0)
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.BorderSizePixel = 0
	divider.Parent = dividerContainer
	ApplyTheme(divider, "Outlines", "BackgroundColor3")

	local descLabel = nil
	if description and type(description) == "string" then
		descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(1, -16, 0, 36)
		descLabel.Position = UDim2.new(0, 8, 1, -44)
		descLabel.BackgroundTransparency = 1
		descLabel.TextSize = 11
		descLabel.TextWrapped = true
		descLabel.ClipsDescendants = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Center
		descLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		descLabel.Text = description
		descLabel.Parent = sidebar
		ApplyTheme(descLabel, "TextMuted", "TextColor3")
		ApplyTheme(descLabel, "SubtextFont", "Font")
	end

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, -currentSidebarWidth, 0, 60)
	topbar.Position = UDim2.new(0, currentSidebarWidth, 0, 0)
	topbar.BackgroundTransparency = 1
	topbar.ClipsDescendants = true
	topbar.ZIndex = 5
	topbar.Parent = main

	local topbarDivider = Instance.new("Frame")
	topbarDivider.Name = "TopbarDivider"
	topbarDivider.Size = UDim2.new(1, -currentSidebarWidth, 0, 1) 
	topbarDivider.Position = UDim2.new(0, currentSidebarWidth, 0, 60)
	topbarDivider.BorderSizePixel = 0
	topbarDivider.ZIndex = 6
	topbarDivider.Parent = main
	ApplyTheme(topbarDivider, "Outlines", "BackgroundColor3")

	local topbarDescLabel = nil
	if description and type(description) == "string" then
		topbarDescLabel = Instance.new("TextLabel")
		topbarDescLabel.Name = "TopbarDescLabel"
		topbarDescLabel.Size = UDim2.new(1, -455, 1, 0)
		topbarDescLabel.Position = UDim2.new(0, 15, 0, 0)
		topbarDescLabel.BackgroundTransparency = 1
		topbarDescLabel.TextSize = 11
		topbarDescLabel.TextWrapped = true
		topbarDescLabel.TextTruncate = Enum.TextTruncate.AtEnd
		topbarDescLabel.ClipsDescendants = true
		topbarDescLabel.TextYAlignment = Enum.TextYAlignment.Center
		topbarDescLabel.TextXAlignment = Enum.TextXAlignment.Left
		topbarDescLabel.Text = description
		topbarDescLabel.ZIndex = 6
		topbarDescLabel.Visible = false
		topbarDescLabel.Parent = topbar
		ApplyTheme(topbarDescLabel, "TextMuted", "TextColor3")
		ApplyTheme(topbarDescLabel, "SubtextFont", "Font")
		CS:AddTag(topbarDescLabel, "TopbarDescLabelBind")
	end

	local topbarControls = Instance.new("Frame")
	topbarControls.Name = "TopbarControls"
	topbarControls.Size = UDim2.new(1, 0, 1, 0)
	topbarControls.BackgroundTransparency = 1
	topbarControls.ZIndex = 5
	topbarControls.Parent = topbar

	local topbarLayout = Instance.new("UIListLayout")
	topbarLayout.Name = "TopbarLayout"
	topbarLayout.FillDirection = Enum.FillDirection.Horizontal
	topbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	topbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topbarLayout.Padding = UDim.new(0, 15)
	topbarLayout.Parent = topbarControls
	CS:AddTag(topbarLayout, "TopbarLayoutBind")

	local topbarPadding = Instance.new("UIPadding")
	topbarPadding.Name = "TopbarPadding"
	topbarPadding.PaddingRight = UDim.new(0, 14)
	topbarPadding.Parent = topbarControls
	CS:AddTag(topbarPadding, "TopbarPaddingBind")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 42, 0, 42)
	closeBtn.Text = "" 
	closeBtn.AutoButtonColor = false
	closeBtn.LayoutOrder = 3
	closeBtn.ZIndex = 50
	closeBtn.Parent = topbarControls
	ApplyTheme(closeBtn, "Card", "BackgroundColor3")
	ApplyTheme(closeBtn, "CardTrans", "BackgroundTransparency")
	CS:AddTag(closeBtn, "CloseBtnBind")
	
	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = MAIN_CORNER
	closeBtnCorner.Parent = closeBtn
	CS:AddTag(closeBtnCorner, "MainCorner")
	
	attachStroke(closeBtn, "BlockStroke")

	local crossLine1 = Instance.new("Frame")
	crossLine1.Name = "CrossLine1"
	crossLine1.Size = UDim2.new(0, 14, 0, 1) 
	crossLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
	crossLine1.AnchorPoint = Vector2.new(0.5, 0.5)
	crossLine1.Rotation = 45
	crossLine1.BorderSizePixel = 0
	crossLine1.Parent = closeBtn
	ApplyTheme(crossLine1, "TextMuted", "BackgroundColor3")

	local crossLine2 = crossLine1:Clone()
	crossLine2.Name = "CrossLine2"
	crossLine2.Rotation = -45
	crossLine2.Parent = closeBtn

	local profileBlock = Instance.new("Frame")
	profileBlock.Name = "ProfileBlock"
	profileBlock.AutomaticSize = Enum.AutomaticSize.X 
	profileBlock.Size = UDim2.new(0, 0, 0, 42)
	profileBlock.LayoutOrder = 2
	profileBlock.Parent = topbarControls
	ApplyTheme(profileBlock, "Card", "BackgroundColor3")
	ApplyTheme(profileBlock, "CardTrans", "BackgroundTransparency")
	CS:AddTag(profileBlock, "ProfileBlockBind")
	
	local profileBlockCorner = Instance.new("UICorner")
	profileBlockCorner.CornerRadius = MAIN_CORNER
	profileBlockCorner.Parent = profileBlock
	CS:AddTag(profileBlockCorner, "MainCorner")
	
	attachStroke(profileBlock, "BlockStroke")

	do
		local profilePadding = Instance.new("UIPadding")
		profilePadding.Name = "ProfilePadding"
		profilePadding.PaddingLeft = UDim.new(0, 15)
		profilePadding.PaddingRight = UDim.new(0, 5)
		profilePadding.Parent = profileBlock

		local profileLayout = Instance.new("UIListLayout")
		profileLayout.Name = "ProfileLayout"
		profileLayout.FillDirection = Enum.FillDirection.Horizontal
		profileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
		profileLayout.Padding = UDim.new(0, 10)
		profileLayout.Parent = profileBlock

		local namesContainer = Instance.new("Frame")
		namesContainer.Name = "NamesContainer"
		namesContainer.AutomaticSize = Enum.AutomaticSize.X
		namesContainer.Size = UDim2.new(0, 0, 1, 0)
		namesContainer.BackgroundTransparency = 1
		namesContainer.LayoutOrder = 1
		namesContainer.Parent = profileBlock

		local namesLayout = Instance.new("UIListLayout")
		namesLayout.Name = "NamesLayout"
		namesLayout.FillDirection = Enum.FillDirection.Vertical
		namesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		namesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		namesLayout.Padding = UDim.new(0, 2)
		namesLayout.Parent = namesContainer

		local displayName = Instance.new("TextLabel")
		displayName.Name = "DisplayName"
		displayName.AutomaticSize = Enum.AutomaticSize.X
		displayName.Size = UDim2.new(0, 0, 0, 14)
		displayName.BackgroundTransparency = 1
		displayName.TextSize = 13
		displayName.Text = LP.DisplayName
		displayName.TextTruncate = Enum.TextTruncate.AtEnd
		displayName.Parent = namesContainer
		ApplyTheme(displayName, "Text", "TextColor3")
		ApplyTheme(displayName, "TextFont", "Font")

		local userName = Instance.new("TextLabel")
		userName.Name = "UserName"
		userName.AutomaticSize = Enum.AutomaticSize.X
		userName.Size = UDim2.new(0, 0, 0, 12)
		userName.BackgroundTransparency = 1
		userName.TextSize = 11
		userName.Text = "@" .. LP.Name
		userName.TextTruncate = Enum.TextTruncate.AtEnd
		userName.Parent = namesContainer
		ApplyTheme(userName, "TextMuted", "TextColor3")
		ApplyTheme(userName, "SubtextFont", "Font")

		local avatarImage = Instance.new("ImageLabel")
		avatarImage.Name = "AvatarImage"
		avatarImage.Size = UDim2.new(0, 32, 0, 32)
		avatarImage.BackgroundTransparency = 1
		avatarImage.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		avatarImage.LayoutOrder = 2
		avatarImage.Parent = profileBlock
		
		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(1, 0)
		avatarCorner.Parent = avatarImage
	end

	local searchContainer = Instance.new("Frame")
	searchContainer.Name = "SearchContainer"
	searchContainer.Size = UDim2.new(0, 230, 0, 42)
	searchContainer.ClipsDescendants = true
	searchContainer.LayoutOrder = 1
	searchContainer.Parent = topbarControls
	ApplyTheme(searchContainer, "Card", "BackgroundColor3")
	ApplyTheme(searchContainer, "CardTrans", "BackgroundTransparency")
	CS:AddTag(searchContainer, "SearchContainerBind")
	
	local searchContainerCorner = Instance.new("UICorner")
	searchContainerCorner.CornerRadius = MAIN_CORNER
	searchContainerCorner.Parent = searchContainer
	CS:AddTag(searchContainerCorner, "MainCorner")
	
	attachStroke(searchContainer, "BlockStroke")

	local searchInput = Instance.new("TextBox")
	searchInput.Name = "SearchInput"
	searchInput.Size = UDim2.new(1, -45, 1, 0)
	searchInput.Position = UDim2.new(0, 15, 0, 0)
	searchInput.BackgroundTransparency = 1
	searchInput.TextSize = 13
	searchInput.PlaceholderText = searchPlaceholder
	searchInput.Text = ""
	searchInput.ClipsDescendants = true
	searchInput.TextXAlignment = Enum.TextXAlignment.Left
	searchInput.Parent = searchContainer
	ApplyTheme(searchInput, "Text", "TextColor3")
	ApplyTheme(searchInput, "TextMuted", "PlaceholderColor3")
	ApplyTheme(searchInput, "TextFont", "Font")

	local searchIcon = Instance.new("ImageLabel")
	searchIcon.Name = "SearchIcon"
	searchIcon.Size = UDim2.new(0, 20, 0, 20)
	searchIcon.Position = UDim2.new(1, -32, 0.5, -10)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Image = SEARCH_ICON_ID
	searchIcon.Parent = searchContainer
	ApplyTheme(searchIcon, "TextMuted", "ImageColor3")

	local pagesFolder = Instance.new("Frame")
	pagesFolder.Name = "PagesFolder"
	pagesFolder.Size = UDim2.new(1, -currentSidebarWidth, 1, -60) 
	pagesFolder.Position = UDim2.new(0, currentSidebarWidth, 0, 60)
	pagesFolder.BackgroundTransparency = 1
	pagesFolder.ClipsDescendants = true
	pagesFolder.ZIndex = 5
	pagesFolder.Parent = main

	local searchPage = Instance.new("CanvasGroup")
	searchPage.Name = "SearchPage"
	searchPage.Size = UDim2.new(1, 0, 1, 0)
	searchPage.Position = UDim2.new(0, 0, 0, 0)
	searchPage.BackgroundTransparency = 1
	searchPage.GroupTransparency = 1
	searchPage.ClipsDescendants = true
	searchPage.Visible = false
	searchPage.Parent = pagesFolder

	local searchPageContent = Instance.new("ScrollingFrame")
	searchPageContent.Name = "PageContent"
	searchPageContent.Size = UDim2.new(1, 0, 1, 0)
	searchPageContent.BackgroundTransparency = 1
	searchPageContent.ScrollBarThickness = 0
	searchPageContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	searchPageContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	searchPageContent.Parent = searchPage
	
	local spPadding = Instance.new("UIPadding")
	spPadding.PaddingTop = UDim.new(0, 14) 
	spPadding.PaddingBottom = UDim.new(0, 14)
	spPadding.PaddingLeft = UDim.new(0, 14)
	spPadding.PaddingRight = UDim.new(0, 14)
	spPadding.Parent = searchPageContent

	local spLayout = Instance.new("UIListLayout")
	spLayout.FillDirection = Enum.FillDirection.Horizontal
	spLayout.SortOrder = Enum.SortOrder.LayoutOrder
	spLayout.Padding = UDim.new(0, 14)
	spLayout.Parent = searchPageContent

	local searchLeftCol = Instance.new("Frame")
	searchLeftCol.Size = UDim2.new(0.5, -7, 0, 0)
	searchLeftCol.AutomaticSize = Enum.AutomaticSize.Y
	searchLeftCol.BackgroundTransparency = 1
	searchLeftCol.Parent = searchPageContent
	local slLayout = Instance.new("UIListLayout")
	slLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slLayout.Padding = UDim.new(0, 14)
	slLayout.Parent = searchLeftCol

	local searchRightCol = Instance.new("Frame")
	searchRightCol.Size = UDim2.new(0.5, -7, 0, 0)
	searchRightCol.AutomaticSize = Enum.AutomaticSize.Y
	searchRightCol.BackgroundTransparency = 1
	searchRightCol.Parent = searchPageContent
	local srLayout = Instance.new("UIListLayout")
	srLayout.SortOrder = Enum.SortOrder.LayoutOrder
	srLayout.Padding = UDim.new(0, 14)
	srLayout.Parent = searchRightCol

	local function updateSearchTabStyle(style)
		if style == 3 or style == 4 then
			searchLeftCol.Size = UDim2.new(0.5, -4, 0, 0)
			searchRightCol.Size = UDim2.new(0.5, -4, 0, 0)
			spPadding.PaddingTop = UDim.new(0, 8)
			spPadding.PaddingBottom = UDim.new(0, 8)
			spPadding.PaddingLeft = UDim.new(0, 8)
			spPadding.PaddingRight = UDim.new(0, 8)
			spLayout.Padding = UDim.new(0, 8)
			slLayout.Padding = UDim.new(0, 8)
			srLayout.Padding = UDim.new(0, 8)
		else
			searchLeftCol.Size = UDim2.new(0.5, -7, 0, 0)
			searchRightCol.Size = UDim2.new(0.5, -7, 0, 0)
			spPadding.PaddingTop = UDim.new(0, 14)
			spPadding.PaddingBottom = UDim.new(0, 14)
			spPadding.PaddingLeft = UDim.new(0, 14)
			spPadding.PaddingRight = UDim.new(0, 14)
			spLayout.Padding = UDim.new(0, 14)
			slLayout.Padding = UDim.new(0, 14)
			srLayout.Padding = UDim.new(0, 14)
		end
	end
	table.insert(Window._styleCallbacks, updateSearchTabStyle)
	updateSearchTabStyle(THEME.ElementStyle)

	local function ConstructBlockUI(bName, bIcon, parent)
		local blockContainer = Instance.new("Frame")
		blockContainer.Name = bName .. "_Block"
		blockContainer.Size = UDim2.new(1, 0, 0, 0)
		blockContainer.AutomaticSize = Enum.AutomaticSize.Y
		blockContainer.Parent = parent
		ApplyTheme(blockContainer, "Card", "BackgroundColor3")
		ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
		
		local currentElRadius = 6
		for _, c in ipairs(CS:GetTagged("ElementCorner")) do
			currentElRadius = c.CornerRadius.Offset
			break
		end
		
		local blockContainerCorner = Instance.new("UICorner")
		blockContainerCorner.CornerRadius = UDim.new(0, currentElRadius)
		blockContainerCorner.Parent = blockContainer
		CS:AddTag(blockContainerCorner, "ElementCorner")

		local blockStroke = Instance.new("UIStroke")
		blockStroke.Name = "BlockStroke"
		blockStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
		blockStroke.Thickness = 1
		blockStroke.Parent = blockContainer
		ApplyTheme(blockStroke, "Outlines", "Color")
		CS:AddTag(blockStroke, "BlockStroke")

		local blockPadding = Instance.new("UIPadding")
		blockPadding.Name = "BlockPadding"
		blockPadding.PaddingTop = UDim.new(0, 12)
		blockPadding.PaddingBottom = UDim.new(0, 12)
		blockPadding.PaddingLeft = UDim.new(0, 12)
		blockPadding.PaddingRight = UDim.new(0, 12)
		blockPadding.Parent = blockContainer

		local blockLayout = Instance.new("UIListLayout")
		blockLayout.Name = "BlockLayout"
		blockLayout.FillDirection = Enum.FillDirection.Vertical
		blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
		blockLayout.Padding = UDim.new(0, 6)
		blockLayout.Parent = blockContainer

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 20)
		header.BackgroundTransparency = 1
		header.LayoutOrder = 0
		header.Parent = blockContainer

		local headerLayout = Instance.new("UIListLayout")
		headerLayout.Name = "HeaderLayout"
		headerLayout.FillDirection = Enum.FillDirection.Horizontal
		headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		headerLayout.Padding = UDim.new(0, 8)
		headerLayout.Parent = header

		local blockIconLabel
		if bIcon and bIcon ~= "" then
			blockIconLabel = Instance.new("ImageLabel")
			blockIconLabel.Name = "BlockIcon"
			blockIconLabel.Size = UDim2.new(0, 26, 0, 26)
			blockIconLabel.BackgroundTransparency = 1
			blockIconLabel.Image = bIcon
			blockIconLabel.Parent = header
			ApplyTheme(blockIconLabel, "Text", "ImageColor3")
		end

		local blockTitle = Instance.new("TextLabel")
		blockTitle.Name = "BlockTitle"
		blockTitle.AutomaticSize = Enum.AutomaticSize.X
		blockTitle.Size = UDim2.new(0, 0, 1, 0)
		blockTitle.BackgroundTransparency = 1
		blockTitle.TextSize = 13
		blockTitle.TextTruncate = Enum.TextTruncate.AtEnd
		blockTitle.Text = bName
		blockTitle.Parent = header
		ApplyTheme(blockTitle, "Text", "TextColor3")
		ApplyTheme(blockTitle, "TextFont", "Font")

		local blockDivider = Instance.new("Frame")
		blockDivider.Name = "BlockDivider"
		blockDivider.Size = UDim2.new(1, 0, 0, 1)
		blockDivider.BorderSizePixel = 0
		blockDivider.LayoutOrder = 1
		blockDivider.Parent = blockContainer
		ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

		local function updateBlockStyle(style)
			if style == 3 or style == 4 then
				blockPadding.PaddingTop = UDim.new(0, 8)
				blockPadding.PaddingBottom = UDim.new(0, 8)
				blockPadding.PaddingLeft = UDim.new(0, 8)
				blockPadding.PaddingRight = UDim.new(0, 8)
				blockLayout.Padding = UDim.new(0, 4)
				header.Size = UDim2.new(1, 0, 0, 22)
				if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 22, 0, 22) end
			else
				blockPadding.PaddingTop = UDim.new(0, 12)
				blockPadding.PaddingBottom = UDim.new(0, 12)
				blockPadding.PaddingLeft = UDim.new(0, 12)
				blockPadding.PaddingRight = UDim.new(0, 12)
				blockLayout.Padding = UDim.new(0, 6)
				header.Size = UDim2.new(1, 0, 0, 26)
				if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 26, 0, 26) end
			end
		end
		table.insert(Window._styleCallbacks, updateBlockStyle)
		updateBlockStyle(THEME.ElementStyle)

		return blockContainer
	end

	table.insert(Window._connections, searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(searchInput.Text)
		if q == "" then
			for _, entry in ipairs(Window._searchRegistry) do
				entry.UI.Parent = entry.OriginalParent
			end
			for _, b in ipairs(searchLeftCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			for _, b in ipairs(searchRightCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			
			TS:Create(searchPage, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 1}):Play()
			task.delay(0.2, function()
				if searchInput.Text == "" then
					searchPage.Visible = false
				end
			end)
			if Window.CurrentTab and Window.CurrentTab.Page then
				Window.CurrentTab.Page.Visible = true
				TS:Create(Window.CurrentTab.Page, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()
			end
		else
			if Window.CurrentTab and Window.CurrentTab.Page then
				TS:Create(Window.CurrentTab.Page, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 1, Position = UDim2.new(0, 0, 0, -8)}):Play()
				task.delay(0.18, function()
					if searchInput.Text ~= "" and Window.CurrentTab and Window.CurrentTab.Page then
						Window.CurrentTab.Page.Visible = false
					end
				end)
			end
			for _, entry in ipairs(Window._searchRegistry) do
				entry.UI.Parent = entry.OriginalParent
			end
			for _, b in ipairs(searchLeftCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			for _, b in ipairs(searchRightCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end

			local matchedGroups = { Left = {}, Right = {} }
			local blocksOrder = { Left = {}, Right = {} }

			for _, entry in ipairs(Window._searchRegistry) do
				if string.find(entry.Name, q) then
					local side = entry.BlockSide
					local bName = entry.BlockName
					if not matchedGroups[side][bName] then
						matchedGroups[side][bName] = { Icon = entry.BlockIcon, Elements = {} }
						table.insert(blocksOrder[side], bName)
					end
					table.insert(matchedGroups[side][bName].Elements, entry)
				end
			end

			for side, col in pairs({ Left = searchLeftCol, Right = searchRightCol }) do
				for _, bName in ipairs(blocksOrder[side]) do
					local data = matchedGroups[side][bName]
					local mockBlock = ConstructBlockUI(bName, data.Icon, col)
					for _, entry in ipairs(data.Elements) do
						entry.UI.Parent = mockBlock
					end
				end
			end
			searchPage.Position = UDim2.new(0, 0, 0, 8)
			searchPage.GroupTransparency = 1
			searchPage.Visible = true
			TS:Create(searchPage, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				GroupTransparency = 0,
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()
		end
	end))

	local sidebarResizer = Instance.new("TextButton")
	sidebarResizer.Name = "SidebarResizer"
	sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
	sidebarResizer.Position = UDim2.new(0, currentSidebarWidth, 0, 0)
	sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
	sidebarResizer.BackgroundTransparency = 1
	sidebarResizer.Text = ""
	sidebarResizer.AutoButtonColor = false
	sidebarResizer.ZIndex = 25
	sidebarResizer.Parent = main

	local resizerLine = Instance.new("Frame")
	resizerLine.Name = "ResizerLine"
	resizerLine.Size = UDim2.new(0, 1, 1, 0)
	resizerLine.Position = UDim2.new(0.5, 0, 0, 0)
	resizerLine.AnchorPoint = Vector2.new(0.5, 0)
	resizerLine.BorderSizePixel = 0
	resizerLine.Parent = sidebarResizer
	ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")

	local function FullUpdateLayout()
		local isTopOrBottom = (SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom")
		local effWidth = isTopOrBottom and MIN_SIDEBAR_WIDTH or currentSidebarWidth
		local isCollapsed = effWidth < 115
		
		tabListLayout.Padding = UDim.new(0, (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 2 or 4)
		if isTopOrBottom then isCollapsed = true end

		sidebarResizer.Visible = not SIDEBAR_STATE.Detached

		if SIDEBAR_STATE.Detached then
			sidebarBgImage.Visible = true
			svCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
			sidebarBaseCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
			sidebarCorner.CornerRadius = UDim.new(0, cornerRadiusNum)

			sidebar.Parent = contentWrapper
			sidebarVisuals.Parent = contentWrapper
			sidebarOutlineStroke.Enabled = THEME.MainOutlineEnabled
			sidebarOutlineStroke.Transparency = 0
			sidebarFiller.Visible = false
			topbar.Size = UDim2.new(1, 0, 0, 60)
			topbar.Position = UDim2.new(0, 0, 0, 0)
			pagesFolder.Size = UDim2.new(1, 0, 1, -60)
			pagesFolder.Position = UDim2.new(0, 0, 0, 60)
            
			topbarDivider.Size = UDim2.new(1, 0, 0, 1)
			topbarDivider.Position = UDim2.new(0, 0, 0, 60)

			if SIDEBAR_STATE.Position == "Left" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(0, -effWidth - 15, 0, 0)
			elseif SIDEBAR_STATE.Position == "Right" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(1, 15, 0, 0)
			elseif SIDEBAR_STATE.Position == "Top" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 0, -MIN_SIDEBAR_WIDTH - 15)
			elseif SIDEBAR_STATE.Position == "Bottom" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 1, 15)
			end
			
			sidebarVisuals.Size = sidebar.Size
			sidebarVisuals.Position = sidebar.Position
			
			sidebarShadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
			sidebarShadowFolder.Size = sidebar.Size
			sidebarShadowFolder.Position = sidebar.Position
		else
			sidebarBgImage.Visible = false
			svCorner.CornerRadius = UDim.new(0, 0)
			sidebarBaseCorner.CornerRadius = UDim.new(0, 0)
			sidebarCorner.CornerRadius = UDim.new(0, 0)

			sidebar.Parent = main
			sidebarVisuals.Parent = main
			sidebarOutlineStroke.Enabled = false 
			sidebarFiller.Visible = false
			sidebarShadowFolder.Visible = false
			
			if SIDEBAR_STATE.Position == "Left" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(0, 0, 0, 0)
				topbar.Size = UDim2.new(1, -effWidth, 0, 60)
				topbar.Position = UDim2.new(0, effWidth, 0, 0)
				pagesFolder.Size = UDim2.new(1, -effWidth, 1, -60)
				pagesFolder.Position = UDim2.new(0, effWidth, 0, 60)
				topbarDivider.Size = UDim2.new(1, -effWidth, 0, 1)
				topbarDivider.Position = UDim2.new(0, effWidth, 0, 60)
				
				sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
				sidebarResizer.Position = UDim2.new(0, effWidth, 0, 0)
				sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
				resizerLine.Size = UDim2.new(0, 1, 1, 0)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Right" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(1, -effWidth, 0, 0)
				topbar.Size = UDim2.new(1, -effWidth, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, 0)
				pagesFolder.Size = UDim2.new(1, -effWidth, 1, -60)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60)
				topbarDivider.Size = UDim2.new(1, -effWidth, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60)
				
				sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
				sidebarResizer.Position = UDim2.new(1, -effWidth, 0, 0)
				sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
				resizerLine.Size = UDim2.new(0, 1, 1, 0)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Top" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 0, 0)
				topbar.Size = UDim2.new(1, 0, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, MIN_SIDEBAR_WIDTH)
				pagesFolder.Size = UDim2.new(1, 0, 1, -60 - MIN_SIDEBAR_WIDTH)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60 + MIN_SIDEBAR_WIDTH)
				topbarDivider.Size = UDim2.new(1, 0, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60 + MIN_SIDEBAR_WIDTH)
				
				sidebarResizer.Size = UDim2.new(1, 0, 0, 12)
				sidebarResizer.Position = UDim2.new(0, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebarResizer.AnchorPoint = Vector2.new(0, 0.5)
				resizerLine.Size = UDim2.new(1, 0, 0, 1)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Bottom" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 1, -MIN_SIDEBAR_WIDTH)
				topbar.Size = UDim2.new(1, 0, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, 0)
				pagesFolder.Size = UDim2.new(1, 0, 1, -60 - MIN_SIDEBAR_WIDTH)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60)
				topbarDivider.Size = UDim2.new(1, 0, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60)
				
				sidebarResizer.Size = UDim2.new(1, 0, 0, 12)
				sidebarResizer.Position = UDim2.new(0, 0, 1, -MIN_SIDEBAR_WIDTH)
				sidebarResizer.AnchorPoint = Vector2.new(0, 0.5)
				resizerLine.Size = UDim2.new(1, 0, 0, 1)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			end
			sidebarVisuals.Size = sidebar.Size
			sidebarVisuals.Position = sidebar.Position
		end

		if isTopOrBottom then
			logoContainer.Size = UDim2.new(0, 60, 1, 0)
			logoContainer.Position = UDim2.new(0, 0, 0, 0)
			logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			logoPadding.PaddingLeft = UDim.new(0, 15)
			settingsContainer.Visible = true
			settingsContainer.Position = UDim2.new(1, -120, 0, 0)
			tabList.Position = UDim2.new(0, 60, 0, 0)
			tabList.Size = UDim2.new(1, -120, 1, 0)
			tabListLayout.FillDirection = Enum.FillDirection.Horizontal
			tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
			tabList.AutomaticCanvasSize = Enum.AutomaticSize.X
			
			if Window.SettingsTab and Window.SettingsTab.Button then
				Window.SettingsTab.Button.Parent = settingsContainer
				dividerContainer.Parent = settingsContainer
				dividerContainer.Size = UDim2.new(0, 16, 1, 0)
				divider.Size = UDim2.new(0, 1, 0.6, 0)
			end
		else
			logoContainer.Size = UDim2.new(1, 0, 0, 60)
			logoContainer.Position = UDim2.new(0, 0, 0, -2)
			logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			logoPadding.PaddingLeft = UDim.new(0, 0)
			settingsContainer.Visible = false

			if isCollapsed then
				tabList.Position = UDim2.new(0, 0, 0, 75)
				tabList.Size = UDim2.new(1, 0, 1, (description and type(description) == "string") and -140 or -90)
			else
				tabList.Position = UDim2.new(0, 10, 0, 75)
				tabList.Size = UDim2.new(1, -20, 1, (description and type(description) == "string") and -140 or -90)
			end
			
			tabListLayout.FillDirection = Enum.FillDirection.Vertical
			tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
			tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			
			if Window.SettingsTab and Window.SettingsTab.Button then
				Window.SettingsTab.Button.Parent = tabList
				dividerContainer.Parent = tabList
				dividerContainer.Size = UDim2.new(1, 0, 0, 16)
				divider.Size = UDim2.new(0.8, 0, 0, 1)
			end
		end

		if logoImage then
			logoImage.Visible = true
			if logoLabel then logoLabel.Visible = not isCollapsed end
		else
			if logoLabel then
				logoLabel.Visible = true
				logoLabel.Text = isCollapsed and getFirstChar(title) or title
			end
		end
		if descLabel then descLabel.Visible = not isCollapsed end
		if topbarDescLabel then
			topbarDescLabel.Visible = isCollapsed
		end
		
		local btnSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 30 or 38
		local iconSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 22 or 26
		local letterSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 16 or 18

		for _, tab in ipairs(Window.Tabs) do
			local hasIcon = (tab.Icon ~= nil)
			if isTopOrBottom then
				tab.Button.Size = UDim2.new(0, 36, 0, 36)
				tab.Padding.PaddingLeft = UDim.new(0, 0)
				tab.Padding.PaddingRight = UDim.new(0, 0)
				tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				tab.Label.Visible = false

				if hasIcon then
					tab.Icon.Visible = true
					tab.Icon.Size = UDim2.new(0, 30, 0, 30)
					if tab.LetterLabel then tab.LetterLabel.Visible = false end
				else
					if tab.LetterLabel then 
						tab.LetterLabel.Visible = true 
						tab.LetterLabel.Size = UDim2.new(0, 30, 0, 30)
						tab.LetterLabel.TextSize = 24
					end
				end
			else
				if isCollapsed then
					tab.Button.Size = UDim2.new(0, 36, 0, 36)
					tab.Padding.PaddingLeft = UDim.new(0, 0)
					tab.Padding.PaddingRight = UDim.new(0, 0)
					tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					tab.Label.Visible = false

					if hasIcon then
						tab.Icon.Visible = true
						tab.Icon.Size = UDim2.new(0, 30, 0, 30)
						if tab.LetterLabel then tab.LetterLabel.Visible = false end
					else
						if tab.LetterLabel then 
							tab.LetterLabel.Visible = true 
							tab.LetterLabel.Size = UDim2.new(0, 30, 0, 30)
							tab.LetterLabel.TextSize = 24
						end
					end
				else
					tab.Button.Size = UDim2.new(1, -4, 0, btnSizeList)
					local isCurrent = (Window.CurrentTab == tab)
					tab.Padding.PaddingLeft = isCurrent and UDim.new(0, 22) or UDim.new(0, 15)
					tab.Padding.PaddingRight = UDim.new(0, 15)
					tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
					tab.Label.Visible = true
					tab.Label.Text = tab.Name

					if hasIcon then 
						tab.Icon.Visible = true 
						tab.Icon.Size = UDim2.new(0, iconSizeList, 0, iconSizeList) 
					end
					if tab.LetterLabel then 
						tab.LetterLabel.Visible = false 
						tab.LetterLabel.Size = UDim2.new(0, iconSizeList, 0, iconSizeList)
						tab.LetterLabel.TextSize = letterSizeList 
					end
				end
			end
		end
	end

	local function updateSidebarWidth(newWidth)
		currentSidebarWidth = math.clamp(newWidth, MIN_SIDEBAR_WIDTH, MAX_SIDEBAR_WIDTH)
		savedSidebarWidth = currentSidebarWidth
		local bound = Window._themeControls["Layout & Styles~Sidebar Width"]
		if bound and bound.API:Save().Value ~= currentSidebarWidth then
			bound.API:Set(currentSidebarWidth)
		end
		FullUpdateLayout()
	end

	local resizingSidebar = false
	local resizeSidebarStartPos, resizeSidebarStartWidth

	table.insert(Window._connections, sidebarResizer.InputBegan:Connect(function(input)
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizingSidebar = true
			resizeSidebarStartPos = input.Position.X
			resizeSidebarStartWidth = currentSidebarWidth
			ApplyTheme(resizerLine, "Accent", "BackgroundColor3")

			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizingSidebar = false
					ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")
					endConn:Disconnect()
				end
			end)
			table.insert(Window._connections, endConn)
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if resizingSidebar and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position.X - resizeSidebarStartPos
			if SIDEBAR_STATE.Position == "Right" then delta = -delta end
			updateSidebarWidth(resizeSidebarStartWidth + delta)
		end
	end))

	table.insert(Window._connections, sidebarResizer.MouseEnter:Connect(function()
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if not resizingSidebar then
			ApplyTheme(resizerLine, "Accent", "BackgroundColor3")
		end
	end))

	table.insert(Window._connections, sidebarResizer.MouseLeave:Connect(function()
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if not resizingSidebar then
			ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")
		end
	end))

	local isDestroyed, isUIOpen = false, true
	local animInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local currentActiveTween = nil

	local function getAnimHideTransform(animType)
		if animType == 2 then
			return UDim2.new(0, 0, 0, -25), UDim2.new(1, 0, 1, 0)
		elseif animType == 3 then
			return UDim2.new(0.03, 0, 0.03, 0), UDim2.new(0.94, 0, 0.94, 0)
		elseif animType == 4 then
			return UDim2.new(0, 30, 0, 0), UDim2.new(1, 0, 1, 0)
		else
			return UDim2.new(0, 0, 0, 25), UDim2.new(1, 0, 1, 0)
		end
	end

	local function PlayFadeAnim(show)
		if currentActiveTween then
			currentActiveTween:Cancel()
			currentActiveTween = nil
		end

		local aType = THEME.CloseAnimation or 1
		local hidePos, hideSize = getAnimHideTransform(aType)
		
		if show then
			wrapper.Visible = true
			contentWrapper.Position = hidePos
			contentWrapper.Size = hideSize
			
			currentActiveTween = TS:Create(contentWrapper, animInfo, {
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0)
			})
			currentActiveTween:Play()
			
			TS:Create(main, animInfo, {GroupTransparency = 0}):Play()
			
			if THEME.MainOutlineEnabled then
				TS:Create(mainOutlineStroke, animInfo, {Transparency = 0}):Play()
				if SIDEBAR_STATE.Detached then
					sidebarOutlineStroke.Enabled = true
					TS:Create(sidebarOutlineStroke, animInfo, {Transparency = 0}):Play()
				end
			end
			
			if SIDEBAR_STATE.ShadowsEnabled then
				for _, shadow in ipairs(shadowFolder:GetChildren()) do
					local stroke = shadow:FindFirstChild("ShadowStroke")
					if stroke then 
						stroke.Enabled = true
						TS:Create(stroke, animInfo, {Transparency = stroke:GetAttribute("TargetTransparency") or 0.8}):Play() 
					end
				end
				if SIDEBAR_STATE.Detached then
					for _, shadow in ipairs(sidebarShadowFolder:GetChildren()) do
						local stroke = shadow:FindFirstChild("ShadowStroke")
						if stroke then 
							stroke.Enabled = true
							TS:Create(stroke, animInfo, {Transparency = stroke:GetAttribute("TargetTransparency") or 0.8}):Play() 
						end
					end
				end
			end
			TS:Create(arcOuterStroke, animInfo, {Transparency = 0}):Play()
			TS:Create(topbarDivider, animInfo, {BackgroundTransparency = 0}):Play()
			TS:Create(sidebarDivider, animInfo, {BackgroundTransparency = 0}):Play()
		else
			Window.ClosePopup()
			
			currentActiveTween = TS:Create(contentWrapper, animInfo, {
				Position = hidePos,
				Size = hideSize
			})
			currentActiveTween:Play()
			
			TS:Create(main, animInfo, {GroupTransparency = 1}):Play()
			TS:Create(mainOutlineStroke, animInfo, {Transparency = 1}):Play()
			if sidebarOutlineStroke.Enabled then
				TS:Create(sidebarOutlineStroke, animInfo, {Transparency = 1}):Play()
			end
			
			for _, shadow in ipairs(shadowFolder:GetChildren()) do
				local stroke = shadow:FindFirstChild("ShadowStroke")
				if stroke then TS:Create(stroke, animInfo, {Transparency = 1}):Play() end
			end
			for _, shadow in ipairs(sidebarShadowFolder:GetChildren()) do
				local stroke = shadow:FindFirstChild("ShadowStroke")
				if stroke then TS:Create(stroke, animInfo, {Transparency = 1}):Play() end
			end
			TS:Create(arcOuterStroke, animInfo, {Transparency = 1}):Play()
			TS:Create(topbarDivider, animInfo, {BackgroundTransparency = 1}):Play()
			TS:Create(sidebarDivider, animInfo, {BackgroundTransparency = 1}):Play()
			
			local animRef = currentActiveTween
			animRef.Completed:Connect(function()
				if not isUIOpen and currentActiveTween == animRef then
					wrapper.Visible = false
				end
			end)
		end
	end

	table.insert(Window._connections, closeBtn.Activated:Connect(function()
		if isDestroyed then return end
		isDestroyed = true
		if Window.IsEditMode then 
			CAS:UnbindAction("AxiomEditSink") 
		end
		pcall(function() Window.ToggleEditMode(false) end)
		
		PlayFadeAnim(false)
		for _, conn in ipairs(Window._connections) do
			if conn.Connected then conn:Disconnect() end
		end
		table.clear(Window._connections)
		clearFX()
		task.delay(0.4, function() 
			pcall(function() editModeBlur:Destroy() end)
			pcall(function() screenGui:Destroy() end) 
		end)
	end))

	table.insert(Window._connections, closeBtn.MouseEnter:Connect(function() 
		TS:Create(crossLine1, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.CloseBtn}):Play() 
		TS:Create(crossLine2, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.CloseBtn}):Play() 
	end))
	table.insert(Window._connections, closeBtn.MouseLeave:Connect(function() 
		TS:Create(crossLine1, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.TextMuted}):Play() 
		TS:Create(crossLine2, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.TextMuted}):Play() 
	end))

	if isMobile then
		local mobileToggleUI = Instance.new("ImageButton")
		mobileToggleUI.Name = "MobileToggleUI"
		mobileToggleUI.Size = UDim2.new(0, 40, 0, 40)
		mobileToggleUI.AnchorPoint = Vector2.new(0.5, 0.5)
		mobileToggleUI.Position = UDim2.new(0.5, 0, 0, 30)
		mobileToggleUI.BackgroundColor3 = THEME.Sidebar
		mobileToggleUI.Image = (logoIconId and logoIconId ~= "") and logoIconId or "rbxassetid://118685771787843"
		mobileToggleUI.ZIndex = 999999
		mobileToggleUI.Parent = screenGui
		
		local mtCorner = Instance.new("UICorner")
		mtCorner.CornerRadius = UDim.new(0, 10)
		mtCorner.Parent = mobileToggleUI
		
		local mtStroke = Instance.new("UIStroke")
		mtStroke.Thickness = 1
		mtStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		mtStroke.Color = THEME.Outlines
		mtStroke.Parent = mobileToggleUI

		local mtDragging, mtDragStart, mtStartPos, mtMoved
		table.insert(Window._connections, mobileToggleUI.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mtDragging = true
				mtMoved = false
				mtDragStart = input.Position
				mtStartPos = mobileToggleUI.Position
			end
		end))
		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if mtDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - mtDragStart
				if delta.Magnitude > 5 then mtMoved = true end
				mobileToggleUI.Position = UDim2.new(mtStartPos.X.Scale, mtStartPos.X.Offset + delta.X, mtStartPos.Y.Scale, mtStartPos.Y.Offset + delta.Y)
			end
		end))
		table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mtDragging = false
			end
		end))
		
		table.insert(Window._connections, mobileToggleUI.Activated:Connect(function()
			if mtMoved then return end
			isUIOpen = not isUIOpen
			PlayFadeAnim(isUIOpen)
		end))
	end

	table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
		if not Window._capturingOpenKeybind and input.KeyCode == openKeybind and not UIS:GetFocusedTextBox() then
			isUIOpen = not isUIOpen
			PlayFadeAnim(isUIOpen)
		end
	end))

	local themeEditorFrame = Instance.new("Frame")
	themeEditorFrame.Name = "ThemeEditorFrame"
	themeEditorFrame.Size = UDim2.new(0, 560, 0, 520)
	themeEditorFrame.Position = UDim2.new(0, 25, 0.5, -260)
	themeEditorFrame.BackgroundTransparency = 1
	themeEditorFrame.ZIndex = 800
	themeEditorFrame.Visible = false
	themeEditorFrame.Active = true
	themeEditorFrame.Parent = screenGui

	local teScale = Instance.new("UIScale")
	teScale.Scale = isMobile and 0.65 or 1
	teScale.Parent = themeEditorFrame

	local teDragHeader = Instance.new("Frame")
	teDragHeader.Name = "ThemeEditorHeader"
	teDragHeader.Size = UDim2.new(1, 0, 0, 36)
	teDragHeader.BorderSizePixel = 0
	teDragHeader.ZIndex = 802
	teDragHeader.Parent = themeEditorFrame
	ApplyTheme(teDragHeader, "Card", "BackgroundColor3")

	local teHeaderCorner = Instance.new("UICorner")
	teHeaderCorner.CornerRadius = GLOBAL_CORNER
	teHeaderCorner.Parent = teDragHeader
	CS:AddTag(teHeaderCorner, "ElementCorner")

	local teHeaderTitle = Instance.new("TextLabel")
	teHeaderTitle.Size = UDim2.new(1, -20, 1, 0)
	teHeaderTitle.Position = UDim2.new(0, 14, 0, 0)
	teHeaderTitle.BackgroundTransparency = 1
	teHeaderTitle.Text = "Theme Customizer"
	teHeaderTitle.TextSize = 13
	teHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	teHeaderTitle.Parent = teDragHeader
	ApplyTheme(teHeaderTitle, "Text", "TextColor3")
	ApplyTheme(teHeaderTitle, "TextFont", "Font")

	local teDragging, teDragInput, teDragStart, teStartPos
	table.insert(Window._connections, teDragHeader.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			teDragging = true
			teDragStart = input.Position
			teStartPos = themeEditorFrame.Position
			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					teDragging = false
					endConn:Disconnect()
				end
			end)
			table.insert(Window._connections, endConn)
		end
	end))
	table.insert(Window._connections, teDragHeader.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			teDragInput = input
		end
	end))
	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if input == teDragInput and teDragging then
			local delta = input.Position - teDragStart
			themeEditorFrame.Position = UDim2.new(teStartPos.X.Scale, teStartPos.X.Offset + delta.X, teStartPos.Y.Scale, teStartPos.Y.Offset + delta.Y)
		end
	end))

	local themeEditorContainer = Instance.new("ScrollingFrame")
	themeEditorContainer.Name = "ThemeEditorContainer"
	themeEditorContainer.Size = UDim2.new(1, 0, 1, -42)
	themeEditorContainer.Position = UDim2.new(0, 0, 0, 42)
	themeEditorContainer.BackgroundTransparency = 1
	themeEditorContainer.ScrollBarThickness = 2
	themeEditorContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	themeEditorContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	themeEditorContainer.ZIndex = 801
	themeEditorContainer.Parent = themeEditorFrame
	ApplyTheme(themeEditorContainer, "Outlines", "ScrollBarImageColor3")

	local themeEditorPad = Instance.new("UIPadding")
	themeEditorPad.PaddingTop = UDim.new(0, 4)
	themeEditorPad.PaddingBottom = UDim.new(0, 15)
	themeEditorPad.PaddingLeft = UDim.new(0, 2)
	themeEditorPad.PaddingRight = UDim.new(0, 8)
	themeEditorPad.Parent = themeEditorContainer

	local themeEditorLayout = Instance.new("UIListLayout")
	themeEditorLayout.Name = "ThemeEditorLayout"
	themeEditorLayout.FillDirection = Enum.FillDirection.Horizontal
	themeEditorLayout.Padding = UDim.new(0, 15)
	themeEditorLayout.SortOrder = Enum.SortOrder.LayoutOrder
	themeEditorLayout.Parent = themeEditorContainer
	
	local themeEditorLeft = Instance.new("Frame")
	themeEditorLeft.Name = "ThemeLeftCol"
	themeEditorLeft.Size = UDim2.new(0.5, -8, 0, 0)
	themeEditorLeft.AutomaticSize = Enum.AutomaticSize.Y
	themeEditorLeft.BackgroundTransparency = 1
	themeEditorLeft.Parent = themeEditorContainer

	local tlLayout = Instance.new("UIListLayout")
	tlLayout.Padding = UDim.new(0, 15)
	tlLayout.Parent = themeEditorLeft

	local themeEditorRight = Instance.new("Frame")
	themeEditorRight.Name = "ThemeRightCol"
	themeEditorRight.Size = UDim2.new(0.5, -8, 0, 0)
	themeEditorRight.AutomaticSize = Enum.AutomaticSize.Y
	themeEditorRight.BackgroundTransparency = 1
	themeEditorRight.Parent = themeEditorContainer

	local trLayout = Instance.new("UIListLayout")
	trLayout.Padding = UDim.new(0, 15)
	trLayout.Parent = themeEditorRight

	local function updateThemeLayout(style)
		if style == 3 or style == 4 then
			themeEditorPad.PaddingTop = UDim.new(0, 4)
			themeEditorPad.PaddingBottom = UDim.new(0, 8)
			themeEditorLayout.Padding = UDim.new(0, 8)
			tlLayout.Padding = UDim.new(0, 8)
			trLayout.Padding = UDim.new(0, 8)
		else
			themeEditorPad.PaddingTop = UDim.new(0, 4)
			themeEditorPad.PaddingBottom = UDim.new(0, 15)
			themeEditorLayout.Padding = UDim.new(0, 15)
			tlLayout.Padding = UDim.new(0, 15)
			trLayout.Padding = UDim.new(0, 15)
		end
	end
	table.insert(Window._styleCallbacks, updateThemeLayout)
	updateThemeLayout(THEME.ElementStyle)

	local editModeLoop
	Window.ToggleEditMode = function(state)
		Window.IsEditMode = state
		if state then
			editModeBackdrop.Visible = true
			editModeBackdrop.BackgroundTransparency = 1
			TS:Create(editModeBackdrop, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0.4}):Play()
			TS:Create(editModeBlur, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = 20}):Play()
			editModeLoop = RS.RenderStepped:Connect(function()
				UIS.MouseIconEnabled = true
				UIS.MouseBehavior = Enum.MouseBehavior.Default
			end)
			CAS:BindAction("AxiomEditSink", function() return Enum.ContextActionResult.Sink end, false,
				Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3,
				Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space
			)
			themeEditorFrame.Visible = true
		else
			if editModeLoop then editModeLoop:Disconnect(); editModeLoop = nil end
			CAS:UnbindAction("AxiomEditSink")
			TS:Create(editModeBackdrop, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
			TS:Create(editModeBlur, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = 0}):Play()
			task.delay(0.3, function()
				if not Window.IsEditMode then
					editModeBackdrop.Visible = false
				end
			end)
			themeEditorFrame.Visible = false
		end
	end

	local function BuildElementAPI(blockContainer, bName, bIcon, bSide, tabName, isSettings)
		local BlockObj = {}
		local elementCount = 2

		local function RegisterElementAPI(type, elName, api)
			if not bName or not tabName or not elName then return end
			local uniqueId = tabName .. "~" .. bName .. "~" .. elName
			if isSettings then
				Window._themeElements[uniqueId] = { Type = type, API = api }
				Window._themeControls[bName .. "~" .. elName] = { Type = type, API = api }
				return
			end
			Window._configElements[uniqueId] = { Type = type, API = api }
		end

		local function RegisterElement(name, container)
			elementCount = elementCount + 1
			container.LayoutOrder = elementCount
			if bName and bSide and not isSettings then
				table.insert(Window._searchRegistry, {
					Name = string.lower(tostring(name)),
					UI = container,
					OriginalParent = blockContainer,
					BlockName = bName,
					BlockIcon = bIcon,
					BlockSide = bSide
				})
			end
		end

		local function CreateElementBase(height)
			local elContainer = Instance.new("Frame")
			elContainer.Name = "ElementContainer"
			elContainer.Size = UDim2.new(1, 0, 0, height or 38)
			elContainer.BorderSizePixel = 0
			elContainer.LayoutOrder = 2
			elContainer.Parent = blockContainer
			ApplyTheme(elContainer, "Element", "BackgroundColor3")
			ApplyTheme(elContainer, "ElementTrans", "BackgroundTransparency")
			
			local elContainerCorner = Instance.new("UICorner")
			elContainerCorner.CornerRadius = GLOBAL_CORNER
			elContainerCorner.Parent = elContainer
			CS:AddTag(elContainerCorner, "ElementCorner")
			
			local elStroke = Instance.new("UIStroke")
			elStroke.Name = "ElementStroke"
			elStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			elStroke.Thickness = 1
			elStroke.Parent = elContainer
			ApplyTheme(elStroke, "Outlines", "Color")
			CS:AddTag(elStroke, "ElementStroke")

			table.insert(Window._connections, elContainer.MouseEnter:Connect(function()
				TS:Create(elContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					BackgroundColor3 = THEME.ElementHover
				}):Play()
			end))
			table.insert(Window._connections, elContainer.MouseLeave:Connect(function()
				TS:Create(elContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					BackgroundColor3 = THEME.Element
				}):Play()
			end))

			return elContainer
		end
		
		local function AttachColorPicker(previewBox, initialColor, callback)
			local h, s, v = initialColor:ToHSV()
			local currentColor = initialColor
			
			local popup = Instance.new("CanvasGroup")
			popup.Name = "ColorPopup"
			popup.BorderSizePixel = 0
			popup.AnchorPoint = Vector2.new(1, 0)
			popup.GroupTransparency = 1
			popup.Visible = false
			popup.ZIndex = 100000
			popup.Parent = screenGui 
			ApplyTheme(popup, "Background", "BackgroundColor3")
			ApplyTheme(popup, "BackgroundTrans", "BackgroundTransparency")
			
			local popupCorner = Instance.new("UICorner")
			popupCorner.CornerRadius = UDim.new(0, 10)
			popupCorner.Parent = popup
			CS:AddTag(popupCorner, "ElementCorner")
			
			local popupStroke = attachStroke(popup, "ElementStroke")

			local popupPadding = Instance.new("UIPadding")
			popupPadding.Name = "PopupPadding"
			popupPadding.PaddingTop = UDim.new(0, 10)
			popupPadding.PaddingBottom = UDim.new(0, 10)
			popupPadding.PaddingLeft = UDim.new(0, 10)
			popupPadding.PaddingRight = UDim.new(0, 10)
			popupPadding.Parent = popup

			local popupLayout = Instance.new("UIListLayout")
			popupLayout.Name = "PopupLayout"
			popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
			popupLayout.Padding = UDim.new(0, 10)
			popupLayout.Parent = popup

			local rgbContainer = Instance.new("Frame")
			rgbContainer.Name = "RGBContainer"
			rgbContainer.Size = UDim2.new(1, 0, 0, 24)
			rgbContainer.BackgroundTransparency = 1
			rgbContainer.LayoutOrder = 1
			rgbContainer.Parent = popup

			local rgbLayout = Instance.new("UIListLayout")
			rgbLayout.FillDirection = Enum.FillDirection.Horizontal
			rgbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rgbLayout.Padding = UDim.new(0, 8)
			rgbLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rgbLayout.Parent = rgbContainer

			local rInput, gInput, bInput
			local function createRGBBox(name, order, prefix)
				local box = Instance.new("Frame")
				box.Name = name .. "Box"
				box.Size = UDim2.new(0, 48, 1, 0)
				box.LayoutOrder = order
				box.Parent = rgbContainer
				ApplyTheme(box, "Input", "BackgroundColor3")
				ApplyTheme(box, "InputTrans", "BackgroundTransparency")

				local corner = Instance.new("UICorner")
				corner.CornerRadius = GLOBAL_CORNER
				corner.Parent = box
				CS:AddTag(corner, "ElementCorner")

				attachStroke(box, "ElementStroke")

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(0, 16, 1, 0)
				lbl.Position = UDim2.new(0, 4, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = prefix
				lbl.TextSize = 11
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = box
				ApplyTheme(lbl, "TextMuted", "TextColor3")
				ApplyTheme(lbl, "TextFont", "Font")

				local inp = Instance.new("TextBox")
				inp.Size = UDim2.new(1, -20, 1, 0)
				inp.Position = UDim2.new(0, 16, 0, 0)
				inp.BackgroundTransparency = 1
				inp.Text = "255"
				inp.TextSize = 11
				inp.Font = Enum.Font.Gotham
				inp.TextXAlignment = Enum.TextXAlignment.Center
				inp.Parent = box
				ApplyTheme(inp, "Text", "TextColor3")
				ApplyTheme(inp, "TextFont", "Font")
				return inp
			end

			rInput = createRGBBox("R", 1, "R:")
			gInput = createRGBBox("G", 2, "G:")
			bInput = createRGBBox("B", 3, "B:")

			local svSquare = Instance.new("TextButton")
			svSquare.Name = "SVSquare"
			svSquare.Size = UDim2.new(1, 0, 0, 160)
			svSquare.BackgroundColor3 = Color3.new(1, 1, 1)
			svSquare.BorderSizePixel = 0
			svSquare.AutoButtonColor = false
			svSquare.Text = ""
			svSquare.LayoutOrder = 2
			svSquare.Parent = popup
			
			local svSquareCorner = Instance.new("UICorner")
			svSquareCorner.CornerRadius = UDim.new(0, 6)
			svSquareCorner.Parent = svSquare
			CS:AddTag(svSquareCorner, "ElementCorner")

			local hueOverlay = Instance.new("Frame")
			hueOverlay.Name = "HueOverlay"
			hueOverlay.Size = UDim2.new(1, 0, 1, 0)
			hueOverlay.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			hueOverlay.BorderSizePixel = 0
			hueOverlay.Parent = svSquare
			
			local hueOverlayCorner = Instance.new("UICorner")
			hueOverlayCorner.CornerRadius = UDim.new(0, 6)
			hueOverlayCorner.Parent = hueOverlay
			CS:AddTag(hueOverlayCorner, "ElementCorner")
			
			local hueGrad = Instance.new("UIGradient")
			hueGrad.Name = "HueGradient"
			hueGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
			hueGrad.Parent = hueOverlay

			local blackOverlay = Instance.new("Frame")
			blackOverlay.Name = "BlackOverlay"
			blackOverlay.Size = UDim2.new(1, 0, 1, 0)
			blackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
			blackOverlay.BorderSizePixel = 0
			blackOverlay.Parent = svSquare
			
			local blackOverlayCorner = Instance.new("UICorner")
			blackOverlayCorner.CornerRadius = UDim.new(0, 6)
			blackOverlayCorner.Parent = blackOverlay
			CS:AddTag(blackOverlayCorner, "ElementCorner")

			local blackGrad = Instance.new("UIGradient")
			blackGrad.Name = "BlackGradient"
			blackGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
			blackGrad.Rotation = 90
			blackGrad.Parent = blackOverlay

			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.Size = UDim2.new(0, 10, 0, 10)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(s, 0, 1 - v, 0)
			dot.BackgroundColor3 = Color3.new(1, 1, 1)
			dot.BorderSizePixel = 0
			dot.Parent = svSquare
			
			local dotCorner = Instance.new("UICorner")
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot
			
			local dotStroke = Instance.new("UIStroke")
			dotStroke.Name = "DotStroke"
			dotStroke.Color = Color3.new(0, 0, 0)
			dotStroke.Thickness = 1
			dotStroke.Parent = dot

			local hueSlider = Instance.new("TextButton")
			hueSlider.Name = "HueSlider"
			hueSlider.Size = UDim2.new(1, 0, 0, 12)
			hueSlider.BackgroundColor3 = Color3.new(1, 1, 1)
			hueSlider.BorderSizePixel = 0
			hueSlider.AutoButtonColor = false
			hueSlider.Text = ""
			hueSlider.LayoutOrder = 3
			hueSlider.Parent = popup
			
			local hueSliderCorner = Instance.new("UICorner")
			hueSliderCorner.CornerRadius = UDim.new(0, 6)
			hueSliderCorner.Parent = hueSlider
			CS:AddTag(hueSliderCorner, "ElementCorner")

			local rainbowGrad = Instance.new("UIGradient")
			rainbowGrad.Name = "RainbowGradient"
			rainbowGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
			})
			rainbowGrad.Parent = hueSlider

			local hueKnob = Instance.new("Frame")
			hueKnob.Name = "HueKnob"
			hueKnob.Size = UDim2.new(0, 4, 1, 4)
			hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			hueKnob.BackgroundColor3 = Color3.new(1, 1, 1)
			hueKnob.BorderSizePixel = 0
			hueKnob.Parent = hueSlider
			
			local hueKnobCorner = Instance.new("UICorner")
			hueKnobCorner.CornerRadius = UDim.new(1, 0)
			hueKnobCorner.Parent = hueKnob
			CS:AddTag(hueKnobCorner, "ElementCorner")
			
			local hueKnobStroke = Instance.new("UIStroke")
			hueKnobStroke.Name = "HueKnobStroke"
			hueKnobStroke.Color = Color3.new(0, 0, 0)
			hueKnobStroke.Parent = hueKnob

			local function updateColors(fromRGB)
				if not fromRGB then
					currentColor = Color3.fromHSV(h, s, v)
					rInput.Text = tostring(math.round(currentColor.R * 255))
					gInput.Text = tostring(math.round(currentColor.G * 255))
					bInput.Text = tostring(math.round(currentColor.B * 255))
				else
					currentColor = Color3.fromHSV(h, s, v)
				end
				previewBox.BackgroundColor3 = currentColor
				hueOverlay.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				dot.Position = UDim2.new(s, 0, 1 - v, 0)
				hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
				callback(currentColor)
			end
			updateColors(false)

			local function onRGBFocusLost()
				local r = math.clamp(tonumber(rInput.Text) or math.round(currentColor.R * 255), 0, 255)
				local g = math.clamp(tonumber(gInput.Text) or math.round(currentColor.G * 255), 0, 255)
				local b = math.clamp(tonumber(bInput.Text) or math.round(currentColor.B * 255), 0, 255)
				rInput.Text = tostring(r)
				gInput.Text = tostring(g)
				bInput.Text = tostring(b)
				local newColor = Color3.fromRGB(r, g, b)
				h, s, v = newColor:ToHSV()
				updateColors(true)
			end
			
			table.insert(Window._connections, rInput.FocusLost:Connect(onRGBFocusLost))
			table.insert(Window._connections, gInput.FocusLost:Connect(onRGBFocusLost))
			table.insert(Window._connections, bInput.FocusLost:Connect(onRGBFocusLost))

			local popupTween
			local popupStrokeTween
			local popupFadeToken = 0
			table.insert(Window._connections, previewBox.MouseButton1Click:Connect(function()
				if Window.ActivePopup == popup then return Window.ClosePopup() end
				Window.ClosePopup()
				popupFadeToken = popupFadeToken + 1
				if popupTween then popupTween:Cancel() end
				if popupStrokeTween then popupStrokeTween:Cancel() end
				local absX = previewBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X + previewBox.AbsoluteSize.X + 10
				local absY = previewBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
				popup.Parent = Window.Overlay
				popup.Position = UDim2.new(0, absX, 0, absY + 6)
				Window.Overlay.Visible = true
				Window.ActivePopup = popup
				popup.Size = UDim2.new(0, 180 * 0.92, 0, 244 * 0.92)
				popup.GroupTransparency = 1
				popup.Visible = true
				if popupStroke then popupStroke.Transparency = 0 end
				Window.ActivePopupClose = function()
					popupFadeToken = popupFadeToken + 1
					local token = popupFadeToken
					if popupTween then popupTween:Cancel() end
					local fadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
					popupTween = TS:Create(popup, fadeInfo, {GroupTransparency = 1, Position = UDim2.new(0, absX, 0, absY + 6), Size = UDim2.new(0, 180 * 0.92, 0, 244 * 0.92)})
					popupTween:Play()
					if popupStroke then
						if popupStrokeTween then popupStrokeTween:Cancel() end
						popupStrokeTween = TS:Create(popupStroke, fadeInfo, {Transparency = 1})
						popupStrokeTween:Play()
					end
					local closeTween = popupTween
					closeTween.Completed:Once(function(playbackState)
						if playbackState ~= Enum.PlaybackState.Completed or token ~= popupFadeToken then return end
						popup.Visible = false
						if not Window.ActivePopup then Window.Overlay.Visible = false end
					end)
				end
				popupTween = TS:Create(popup, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					GroupTransparency = 0,
					Position = UDim2.new(0, absX, 0, absY),
					Size = UDim2.new(0, 180, 0, 244)
				})
				popupTween:Play()
			end))

			local draggingSV = false
			local function moveSV(input)
				local relX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
				local relY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
				s = relX
				v = 1 - relY
				updateColors(false)
			end
			table.insert(Window._connections, svSquare.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = true; moveSV(input)
				end
			end))
			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					moveSV(input)
				end
			end))
			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = false
				end
			end))

			local draggingHue = false
			local function moveHue(input)
				local relX = math.clamp((input.Position.X - hueSlider.AbsolutePosition.X) / hueSlider.AbsoluteSize.X, 0, 1)
				h = relX
				updateColors(false)
			end
			table.insert(Window._connections, hueSlider.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = true; moveHue(input)
				end
			end))
			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					moveHue(input)
				end
			end))
			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = false
				end
			end))
			
			local api = {}
			function api:SetColor(c)
				h, s, v = c:ToHSV()
				updateColors(false)
			end
			return api
		end
		
		local function CreateAdvancedDropdown(dropConfig, isMulti, isSearch)
			local dropName = dropConfig.Name or "Dropdown"
			local options = dropConfig.Options or {}
			local callback = dropConfig.Callback or function() end
			local maxSelections = dropConfig.MaxSelections or math.huge
			local defaultOpt = dropConfig.Default
			
			local selectedItems = isMulti and {} or nil
			local selectedItem = not isMulti and defaultOpt or nil

			local container = CreateElementBase(38)

			local topBar = Instance.new("TextButton")
			topBar.Name = "DropdownTopBar"
			topBar.Size = UDim2.new(1, 0, 1, 0)
			topBar.BackgroundTransparency = 1
			topBar.BorderSizePixel = 0
			topBar.Text = ""
			topBar.Parent = container

			local label = Instance.new("TextLabel")
			label.Name = "DropdownLabel"
			label.Size = UDim2.new(0.52, -15, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = dropName
			label.Font = Enum.Font.Gotham
			label.Parent = topBar
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local selectedBox = Instance.new("Frame")
			selectedBox.Name = "SelectedBox"
			selectedBox.Size = UDim2.new(0.44, 0, 0, 28)
			selectedBox.AnchorPoint = Vector2.new(1, 0.5)
			selectedBox.Position = UDim2.new(1, -7, 0.5, 0) 
			selectedBox.BorderSizePixel = 0
			selectedBox.Parent = topBar
			ApplyTheme(selectedBox, "Input", "BackgroundColor3")
			ApplyTheme(selectedBox, "InputTrans", "BackgroundTransparency")
			
			local selectedBoxCorner = Instance.new("UICorner")
			selectedBoxCorner.CornerRadius = GLOBAL_CORNER
			selectedBoxCorner.Parent = selectedBox
			CS:AddTag(selectedBoxCorner, "ElementCorner")
			
			local selectedBoxStroke = attachStroke(selectedBox, "ElementStroke")

			local arrow = Instance.new("ImageLabel")
			arrow.Name = "Arrow"
			arrow.Size = UDim2.new(0, 14, 0, 14)
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.Position = UDim2.new(1, -8, 0.5, 0)
			arrow.BackgroundTransparency = 1
			arrow.Image = "rbxassetid://10709790948" 
			arrow.Rotation = 180 
			arrow.ZIndex = 3
			arrow.Parent = selectedBox
			ApplyTheme(arrow, "TextMuted", "ImageColor3")

			local selectedText = Instance.new("TextLabel")
			selectedText.Name = "SelectedText"
			selectedText.Size = UDim2.new(1, -26, 1, 0) 
			selectedText.Position = UDim2.new(0, 6, 0, 0)
			selectedText.BackgroundTransparency = 1
			selectedText.BorderSizePixel = 0
			selectedText.TextSize = 12
			selectedText.Text = "Select..."
			selectedText.TextXAlignment = Enum.TextXAlignment.Center
			selectedText.TextTruncate = Enum.TextTruncate.AtEnd
			selectedText.Font = Enum.Font.Gotham
			selectedText.ZIndex = 2
			selectedText.Parent = selectedBox
			ApplyTheme(selectedText, "Text", "TextColor3")
			ApplyTheme(selectedText, "TextFont", "Font")

			local dropPopup = Instance.new("Frame")
			dropPopup.Name = "DropdownPopup"
			dropPopup.BorderSizePixel = 0
			dropPopup.AnchorPoint = Vector2.new(0, 0)
			dropPopup.Visible = false
			dropPopup.ClipsDescendants = true
			dropPopup.ZIndex = 100000 
			dropPopup.Parent = screenGui 
			ApplyTheme(dropPopup, "Input", "BackgroundColor3")
			ApplyTheme(dropPopup, "InputTrans", "BackgroundTransparency")
			
			local dropPopupCorner = Instance.new("UICorner")
			dropPopupCorner.CornerRadius = GLOBAL_CORNER
			dropPopupCorner.Parent = dropPopup
			CS:AddTag(dropPopupCorner, "ElementCorner")
			
			attachStroke(dropPopup, "ElementStroke")

			local headerBtn = Instance.new("TextButton")
			headerBtn.Name = "HeaderBtn"
			headerBtn.Size = UDim2.new(1, 0, 0, 28)
			headerBtn.BackgroundTransparency = 1
			headerBtn.BorderSizePixel = 0
			headerBtn.Text = ""
			headerBtn.ZIndex = 100001
			headerBtn.Parent = dropPopup

			local headerArrow = Instance.new("ImageLabel")
			headerArrow.Name = "HeaderArrow"
			headerArrow.Size = UDim2.new(0, 14, 0, 14)
			headerArrow.AnchorPoint = Vector2.new(1, 0.5)
			headerArrow.Position = UDim2.new(1, -8, 0.5, 0)
			headerArrow.BackgroundTransparency = 1
			headerArrow.Image = "rbxassetid://10709790948" 
			headerArrow.Rotation = 180 
			headerArrow.ZIndex = 100002
			headerArrow.Parent = headerBtn
			ApplyTheme(headerArrow, "TextMuted", "ImageColor3")

			local headerText = Instance.new("TextLabel")
			headerText.Name = "HeaderText"
			headerText.Size = UDim2.new(1, -26, 1, 0)
			headerText.Position = UDim2.new(0, 6, 0, 0)
			headerText.BackgroundTransparency = 1
			headerText.BorderSizePixel = 0
			headerText.TextSize = 12
			headerText.Text = "Select..."
			headerText.TextXAlignment = Enum.TextXAlignment.Center
			headerText.TextTruncate = Enum.TextTruncate.AtEnd
			headerText.Font = Enum.Font.Gotham
			headerText.ZIndex = 100002
			headerText.Parent = headerBtn
			ApplyTheme(headerText, "Text", "TextColor3")
			ApplyTheme(headerText, "TextFont", "Font")

			if defaultOpt then
				if isMulti and type(defaultOpt) == "table" then
					for _, opt in ipairs(defaultOpt) do
						if table.find(options, opt) and #selectedItems < maxSelections then
							table.insert(selectedItems, opt)
						end
					end
					if #selectedItems > 0 then
						local txt = table.concat(selectedItems, ", ")
						selectedText.Text = txt
						headerText.Text = txt
					end
				elseif not isMulti and table.find(options, defaultOpt) then
					selectedText.Text = defaultOpt
					headerText.Text = defaultOpt
				end
			end

			local dividerLine = Instance.new("Frame")
			dividerLine.Name = "DividerLine"
			dividerLine.Size = UDim2.new(1, -16, 0, 1)
			dividerLine.Position = UDim2.new(0.5, 0, 0, 28)
			dividerLine.AnchorPoint = Vector2.new(0.5, 0)
			dividerLine.BorderSizePixel = 0
			dividerLine.ZIndex = 100001
			dividerLine.Parent = dropPopup
			ApplyTheme(dividerLine, "Outlines", "BackgroundColor3")

			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "Scroll"
			scroll.Position = UDim2.new(0, 0, 0, 31)
			scroll.Size = UDim2.new(1, 0, 1, -(33 + (isSearch and 34 or 0)))
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 2
			scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroll.ZIndex = 100001
			scroll.Parent = dropPopup
			ApplyTheme(scroll, "Outlines", "ScrollBarImageColor3")

			local scrollLayout = Instance.new("UIListLayout")
			scrollLayout.Name = "ScrollLayout"
			scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
			scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			scrollLayout.Padding = UDim.new(0, 2)
			scrollLayout.Parent = scroll
			
			local scrollPadding = Instance.new("UIPadding")
			scrollPadding.Name = "ScrollPadding"
			scrollPadding.PaddingTop = UDim.new(0, 3)
			scrollPadding.PaddingBottom = UDim.new(0, 4)
			scrollPadding.PaddingLeft = UDim.new(0, 4)
			scrollPadding.PaddingRight = UDim.new(0, 4)
			scrollPadding.Parent = scroll

			local searchInputBar, sf
			if isSearch then
				sf = Instance.new("Frame")
				sf.Name = "SearchFrame"
				sf.Size = UDim2.new(1, -16, 0, 24)
				sf.Position = UDim2.new(0.5, 0, 0, 0)
				sf.AnchorPoint = Vector2.new(0.5, 1)
				sf.BorderSizePixel = 0
				sf.ZIndex = 100001
				sf.Parent = dropPopup
				ApplyTheme(sf, "Element", "BackgroundColor3")
				
				local sfc = Instance.new("UICorner")
				sfc.CornerRadius = GLOBAL_CORNER
				sfc.Parent = sf
				CS:AddTag(sfc, "ElementCorner")
				
				attachStroke(sf, "ElementStroke")
				
				searchInputBar = Instance.new("TextBox")
				searchInputBar.Size = UDim2.new(1, -10, 1, 0)
				searchInputBar.Position = UDim2.new(0, 5, 0, 0)
				searchInputBar.BackgroundTransparency = 1
				searchInputBar.TextSize = 12
				searchInputBar.PlaceholderText = "Search..."
				searchInputBar.Text = ""
				searchInputBar.TextXAlignment = Enum.TextXAlignment.Left
				searchInputBar.Font = Enum.Font.Gotham
				searchInputBar.ZIndex = 100002
				searchInputBar.Parent = sf
				ApplyTheme(searchInputBar, "Text", "TextColor3")
				ApplyTheme(searchInputBar, "TextMuted", "PlaceholderColor3")
				ApplyTheme(searchInputBar, "TextFont", "Font")
				
				searchInputBar:GetPropertyChangedSignal("Text"):Connect(function()
					local q = string.lower(searchInputBar.Text)
					for _, btn in ipairs(scroll:GetChildren()) do
						if btn:IsA("TextButton") then
							if q == "" or string.find(string.lower(btn.Name:sub(8)), q) then
								btn.Visible = true
							else
								btn.Visible = false
							end
						end
					end
				end)
			end

			local function updateVisuals()
				for _, btn in ipairs(scroll:GetChildren()) do
					if btn:IsA("TextButton") then
						local optName = btn.Name:sub(8)
						if isMulti and table.find(selectedItems, optName) then
							ApplyTheme(btn, "Accent", "TextColor3")
						else
							ApplyTheme(btn, "Text", "TextColor3")
						end
					end
				end
			end

			local function buildOptions(optsList)
				options = optsList
				for _, child in ipairs(scroll:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				for _, opt in ipairs(options) do
					local btn = Instance.new("TextButton")
					btn.Name = "Option_" .. opt
					btn.Size = UDim2.new(1, 0, 0, 24)
					btn.BackgroundTransparency = 1
					btn.BorderSizePixel = 0
					btn.AutoButtonColor = false
					btn.TextSize = 12
					btn.Text = opt
					btn.TextXAlignment = Enum.TextXAlignment.Center
					btn.TextTruncate = Enum.TextTruncate.AtEnd
					btn.Font = Enum.Font.Gotham
					btn.ZIndex = 100002
					btn.Parent = scroll
					ApplyTheme(btn, "TextFont", "Font")
					
					local btnCorner = Instance.new("UICorner")
					btnCorner.CornerRadius = GLOBAL_CORNER
					btnCorner.Parent = btn
					CS:AddTag(btnCorner, "ElementCorner")

					table.insert(Window._connections, btn.MouseEnter:Connect(function() 
						TS:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = THEME.ElementTrans}):Play()
						ApplyTheme(btn, "ElementHover", "BackgroundColor3")
					end))
					table.insert(Window._connections, btn.MouseLeave:Connect(function() 
						TS:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					end))
					table.insert(Window._connections, btn.MouseButton1Click:Connect(function()
						if isMulti then
							local idx = table.find(selectedItems, opt)
							if idx then
								table.remove(selectedItems, idx)
							else
								if #selectedItems < maxSelections then
									table.insert(selectedItems, opt)
								end
							end
							local txt = #selectedItems > 0 and table.concat(selectedItems, ", ") or "Select..."
							selectedText.Text = txt
							headerText.Text = txt
							callback(selectedItems)
							updateVisuals()
						else
							selectedItem = opt
							selectedText.Text = opt
							headerText.Text = opt
							callback(opt)
							Window.ClosePopup()
						end
					end))
				end
				updateVisuals()
			end
			
			buildOptions(options)

			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					selectedBox.Size = UDim2.new(0.44, 0, 0, 28)
					selectedBox.AnchorPoint = Vector2.new(1, 0.5)
					selectedBox.Position = UDim2.new(1, -7, 0.5, 0)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 56)
					label.Size = UDim2.new(1, -24, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					selectedBox.Size = UDim2.new(1, -16, 0, 26) 
					selectedBox.AnchorPoint = Vector2.new(0, 0)
					selectedBox.Position = UDim2.new(0, 8, 0, 22) 
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					selectedBox.Size = UDim2.new(0.44, 0, 0, 22)
					selectedBox.AnchorPoint = Vector2.new(1, 0.5)
					selectedBox.Position = UDim2.new(1, -5, 0.5, 0)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 46)
					label.Size = UDim2.new(1, -24, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					selectedBox.Size = UDim2.new(1, -12, 0, 22) 
					selectedBox.AnchorPoint = Vector2.new(0, 0)
					selectedBox.Position = UDim2.new(0, 6, 0, 18) 
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, headerBtn.MouseButton1Click:Connect(function()
				Window.ClosePopup()
			end))

			local dropTrackConn = nil

			table.insert(Window._connections, topBar.MouseButton1Click:Connect(function()
				if Window.ActivePopup == dropPopup then 
					Window.ClosePopup()
					return 
				end
				Window.ClosePopup()
				
				if searchInputBar then searchInputBar.Text = "" end
				
				local absX = selectedBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X
				local absY = selectedBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
				local boxW = selectedBox.AbsoluteSize.X
				local boxH = selectedBox.AbsoluteSize.Y

				dropPopup.Parent = Window.Overlay
				dropPopup.Position = UDim2.new(0, absX, 0, absY)

				local itemHeight = 26
				local visibleCount = math.clamp(#options, 1, 5)
				local extraH = isSearch and 34 or 0
				local targetH = boxH + 3 + (visibleCount * itemHeight) + 6 + extraH

				if sf then
					sf.Position = UDim2.new(0.5, 0, 0, targetH - 6)
				end

				dropPopup.Size = UDim2.new(0, boxW, 0, boxH)
				dropPopup.Visible = true
				
				selectedBox.BackgroundTransparency = 1
				selectedText.Visible = false
				arrow.Visible = false
				selectedBoxStroke.Enabled = false
				
				headerBtn.Size = UDim2.new(1, 0, 0, boxH)
				dividerLine.Position = UDim2.new(0.5, 0, 0, boxH)
				scroll.Position = UDim2.new(0, 0, 0, boxH + 3)
				scroll.Size = UDim2.new(1, 0, 1, -(boxH + 5 + extraH))

				Window.Overlay.Visible = true
				Window.ActivePopup = dropPopup

				if dropTrackConn then dropTrackConn:Disconnect() end
				dropTrackConn = RS.RenderStepped:Connect(function()
					if not dropPopup.Visible or not selectedBox.Parent then
						if dropTrackConn then dropTrackConn:Disconnect(); dropTrackConn = nil end
						return
					end
					local curX = selectedBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X
					local curY = selectedBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
					dropPopup.Position = UDim2.new(0, curX, 0, curY)

					local scrollParent = selectedBox:FindFirstAncestorWhichIsA("ScrollingFrame")
					if scrollParent then
						local sTop = scrollParent.AbsolutePosition.Y - 15
						local sBottom = scrollParent.AbsolutePosition.Y + scrollParent.AbsoluteSize.Y + 15
						if selectedBox.AbsolutePosition.Y < sTop or selectedBox.AbsolutePosition.Y > sBottom then
							Window.ClosePopup()
						end
					end
				end)

				Window.ActivePopupClose = function()
					if dropTrackConn then
						dropTrackConn:Disconnect()
						dropTrackConn = nil
					end
					
					local closeTween = TS:Create(dropPopup, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, boxW, 0, boxH)
					})
					closeTween:Play()
					
					TS:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 180}):Play()
					TS:Create(headerArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 180}):Play()
					
					local conn
					conn = closeTween.Completed:Connect(function()
						conn:Disconnect()
						dropPopup.Visible = false
						
						ApplyTheme(selectedBox, "InputTrans", "BackgroundTransparency")
						selectedText.Visible = true
						arrow.Visible = true
						selectedBoxStroke.Enabled = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")

						if not Window.ActivePopup then Window.Overlay.Visible = false end
					end)
				end

				TS:Create(dropPopup, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, boxW, 0, targetH)
				}):Play()
				
				headerArrow.Rotation = 180
				arrow.Rotation = 180
				TS:Create(arrow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0}):Play()
				TS:Create(headerArrow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0}):Play()
			end))
			RegisterElement(dropName, container)
			
			local api = {}
			function api:Set(newSelection)
				if isMulti then
					if type(newSelection) == "table" then
						selectedItems = {}
						for _, opt in ipairs(newSelection) do
							if table.find(options, opt) and #selectedItems < maxSelections then
								table.insert(selectedItems, opt)
							end
						end
					end
					local txt = #selectedItems > 0 and table.concat(selectedItems, ", ") or "Select..."
					if selectedText.Text ~= txt then
						selectedText.Text = txt
						headerText.Text = txt
						if dropPopup.Visible then updateVisuals() end
						callback(selectedItems)
					end
				else
					if selectedItem == newSelection then return end
					if table.find(options, newSelection) then
						selectedItem = newSelection
						selectedText.Text = newSelection
						headerText.Text = newSelection
						if dropPopup.Visible then updateVisuals() end
						callback(newSelection)
					end
				end
			end
			function api:SetOptions(newOpts)
				buildOptions(newOpts)
				if searchInputBar and searchInputBar.Text ~= "" then
					local q = string.lower(searchInputBar.Text)
					for _, btn in ipairs(scroll:GetChildren()) do
						if btn:IsA("TextButton") then
							if q == "" or string.find(string.lower(btn.Name:sub(8)), q) then
								btn.Visible = true
							else
								btn.Visible = false
							end
						end
					end
				end
			end
			function api:Save()
				return { Selected = isMulti and selectedItems or selectedItem }
			end
			function api:Load(val)
				if val.Selected ~= nil then
					api:Set(val.Selected)
				end
			end
			RegisterElementAPI("Dropdown", dropName, api)
			return api
		end

		function BlockObj:CreatePicture(picConfig)
			local name = picConfig.Name or "Picture"
			local imgId = parseAsset(picConfig.Image)
			local sizePct = math.clamp(picConfig.Size or 100, 0, 100)
			local desc = picConfig.Description or ""
			
			local container = CreateElementBase(0)
			container.Size = UDim2.new(1, 0, 0, 0)
			container.AutomaticSize = Enum.AutomaticSize.Y
			
			local contentFrame = Instance.new("Frame")
			contentFrame.Size = UDim2.new(1, 0, 0, 0)
			contentFrame.AutomaticSize = Enum.AutomaticSize.Y
			contentFrame.BackgroundTransparency = 1
			contentFrame.Parent = container
			
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 12)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = contentFrame
			
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = imgId
			img.ScaleType = Enum.ScaleType.Crop
			img.Parent = contentFrame
			
			local imgCorner = Instance.new("UICorner")
			imgCorner.CornerRadius = GLOBAL_CORNER
			imgCorner.Parent = img
			CS:AddTag(imgCorner, "ElementCorner")
			
			local rightTextLbl = Instance.new("TextLabel")
			rightTextLbl.BackgroundTransparency = 1
			rightTextLbl.TextWrapped = true
			rightTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			rightTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			rightTextLbl.TextSize = 13
			rightTextLbl.Font = Enum.Font.Gotham
			rightTextLbl.Parent = contentFrame
			ApplyTheme(rightTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(rightTextLbl, "SubtextFont", "Font")

			local bottomTextLbl = Instance.new("TextLabel")
			bottomTextLbl.BackgroundTransparency = 1
			bottomTextLbl.TextWrapped = true
			bottomTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			bottomTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			bottomTextLbl.TextSize = 13
			bottomTextLbl.Font = Enum.Font.Gotham
			bottomTextLbl.Parent = contentFrame
			ApplyTheme(bottomTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(bottomTextLbl, "SubtextFont", "Font")
		
			local function updateLayout()
				if not contentFrame.Parent then return end
				local fullW = contentFrame.AbsoluteSize.X - 24 
				if fullW <= 0 then return end

				local imgW = math.floor(fullW * (sizePct / 100))
				local imgH = imgW 
				img.Size = UDim2.new(0, imgW, 0, imgH)
				img.Position = UDim2.new(0, 0, 0, 0)

				local textGapX = 14
				local textGapY = 10
				local availRightW = fullW - imgW - textGapX

				if sizePct == 100 or sizePct == 0 or availRightW < 40 or desc == "" then
					rightTextLbl.Visible = false
					bottomTextLbl.Visible = (desc ~= "")
					img.Visible = (sizePct > 0)
					bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
					bottomTextLbl.Position = UDim2.new(0, 0, 0, sizePct > 0 and (imgH + textGapY) or 0)
					bottomTextLbl.Text = desc
					bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
				else
					rightTextLbl.Visible = true
					img.Visible = true
					local len = string.len(desc)
					local l, r = 1, len
					local splitIdx = len
					while l <= r do
						local m = math.floor((l + r) / 2)
						local testStr = string.sub(desc, 1, m)
						local bounds = TextService:GetTextSize(testStr, 13, Enum.Font.Gotham, Vector2.new(availRightW, 10000))
						if bounds.Y > imgH then
							r = m - 1
						else
							splitIdx = m
							l = m + 1
						end
					end
					if splitIdx < len then
						local safeIdx = splitIdx
						while safeIdx > 0 and string.sub(desc, safeIdx, safeIdx):match("%S") do
							safeIdx = safeIdx - 1
						end
						if safeIdx > 0 then splitIdx = safeIdx end
					end
					local rightText = string.sub(desc, 1, splitIdx)
					local bottomText = string.sub(desc, splitIdx + 1)
					bottomText = string.gsub(bottomText, "^%s+", "")
					rightTextLbl.Position = UDim2.new(0, imgW + textGapX, 0, 0)
					rightTextLbl.Size = UDim2.new(0, availRightW, 0, imgH)
					rightTextLbl.Text = rightText
					rightTextLbl.AutomaticSize = Enum.AutomaticSize.None
					if bottomText ~= "" then
						bottomTextLbl.Visible = true
						bottomTextLbl.Position = UDim2.new(0, 0, 0, imgH + textGapY)
						bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
						bottomTextLbl.Text = bottomText
						bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
					else
						bottomTextLbl.Visible = false
					end
				end
			end
			
			table.insert(Window._connections, contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
			task.spawn(function()
				task.wait()
				updateLayout()
			end)
			
			RegisterElement(name, container)
			
			local api = {}
			function api:SetImage(id)
				img.Image = parseAsset(id)
			end
			function api:SetSize(pct)
				sizePct = math.clamp(pct, 0, 100)
				updateLayout()
			end
			function api:SetDescription(txt)
				desc = txt
				updateLayout()
			end
			return api
		end

		function BlockObj:CreateObject(objConfig)
			local name = objConfig.Name or "Object Preview"
			local rawObj = objConfig.Object
			local sizePct = math.clamp(objConfig.Size or 100, 0, 100)
			local desc = objConfig.Description or ""

			local container = CreateElementBase(0)
			container.Size = UDim2.new(1, 0, 0, 0)
			container.AutomaticSize = Enum.AutomaticSize.Y

			local contentFrame = Instance.new("Frame")
			contentFrame.Size = UDim2.new(1, 0, 0, 0)
			contentFrame.AutomaticSize = Enum.AutomaticSize.Y
			contentFrame.BackgroundTransparency = 1
			contentFrame.Parent = container

			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 12)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = contentFrame

			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "ObjectViewport"
			viewport.BackgroundTransparency = 1
			viewport.BorderSizePixel = 0
			viewport.ClipsDescendants = true
			viewport.Ambient = Color3.fromRGB(220, 220, 220)
			viewport.LightColor = Color3.fromRGB(255, 255, 255)
			viewport.LightDirection = Vector3.new(-1, -2, -1)
			viewport.Parent = contentFrame

			local worldModel = Instance.new("WorldModel")
			worldModel.Name = "ModelHolder"
			worldModel.Parent = viewport

			local camera = Instance.new("Camera")
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 50
			camera.Parent = viewport
			viewport.CurrentCamera = camera

			local rightTextLbl = Instance.new("TextLabel")
			rightTextLbl.BackgroundTransparency = 1
			rightTextLbl.TextWrapped = true
			rightTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			rightTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			rightTextLbl.TextSize = 13
			rightTextLbl.Font = Enum.Font.Gotham
			rightTextLbl.Parent = contentFrame
			ApplyTheme(rightTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(rightTextLbl, "SubtextFont", "Font")

			local bottomTextLbl = Instance.new("TextLabel")
			bottomTextLbl.BackgroundTransparency = 1
			bottomTextLbl.TextWrapped = true
			bottomTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			bottomTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			bottomTextLbl.TextSize = 13
			bottomTextLbl.Font = Enum.Font.Gotham
			bottomTextLbl.Parent = contentFrame
			ApplyTheme(bottomTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(bottomTextLbl, "SubtextFont", "Font")

			local function resolveInstance(input)
				if typeof(input) == "Instance" then
					if input:IsA("Player") then return input.Character or input.CharacterAdded:Wait() end
					return input
				elseif type(input) == "string" then
					local clean = input:match("^%s*['\"]?(.-)['\"]?%s*$") or input
					local lower = string.lower(clean)

					if lower == "character" or lower == "localplayer" or lower == "me" or lower == "player" 
					   or lower == "game.players.localplayer" or lower == "game.players.localplayer.character"
					   or lower == "players.localplayer" or lower == "players.localplayer.character" then
						return LP.Character or LP.CharacterAdded:Wait()
					end

					if workspace:FindFirstChild(clean) then return workspace:FindFirstChild(clean) end
					if Players:FindFirstChild(clean) then 
						local p = Players:FindFirstChild(clean)
						return p.Character or p.CharacterAdded:Wait()
					end

					local current = game
					for seg in string.gmatch(clean, "[^%.]+") do
						local segLower = string.lower(seg)
						if segLower == "game" then
							current = game
						elseif segLower == "workspace" then
							current = workspace
						elseif segLower == "players" then
							current = Players
						elseif segLower == "localplayer" and current == Players then
							current = LP.Character or LP.CharacterAdded:Wait()
						elseif segLower == "character" and current:IsA("Player") then
							current = current.Character or current.CharacterAdded:Wait()
						else
							current = current and current:FindFirstChild(seg)
						end
					end

					if current and current ~= game then 
						if current:IsA("Player") then return current.Character or current.CharacterAdded:Wait() end
						return current 
					end

					if input == LP.Name and LP.Character then return LP.Character end
				end
				return nil
			end

			local currentClone = nil
			local currentCenter = Vector3.new(0, 1.5, 0)
			local currentDistance = 7.5
			local rotX = 0
			local rotY = math.pi
			local renderConn = nil

			local function updateCamera()
				if not camera then return end
				local rotCFrame = CFrame.Angles(0, rotY, 0) * CFrame.Angles(rotX, 0, 0)
				local camPos = currentCenter + (rotCFrame * Vector3.new(0, 0, currentDistance))
				camera.CFrame = CFrame.lookAt(camPos, currentCenter)
			end

			local validCharParts = {
				HumanoidRootPart=true, Head=true, Torso=true,
				["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
				UpperTorso=true, LowerTorso=true,
				LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
				RightUpperArm=true, RightLowerArm=true, RightHand=true,
				LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
				RightUpperLeg=true, RightLowerLeg=true, RightFoot=true
			}

			local function loadTargetObject(target)
				if renderConn then renderConn:Disconnect(); renderConn = nil end
				if currentClone then currentClone:Destroy(); currentClone = nil end

				local src = resolveInstance(target)
				if not src and (target == nil or target == "Character") then
					src = LP.Character or LP.CharacterAdded:Wait()
				end
				if not src then return end

				local isChar = false
				if src == LP.Character or src:FindFirstChildOfClass("Humanoid") then
					isChar = true
					if src == LP.Character then
						local t = 0
						while not LP:HasAppearanceLoaded() and t < 2 do
							task.wait(0.1); t = t + 0.1
						end
					end
					if not src:FindFirstChild("HumanoidRootPart") and not src:FindFirstChild("Head") then
						task.wait(0.5)
					end
				end

				local archCache = {}
				archCache[src] = src.Archivable
				src.Archivable = true
				for _, desc in ipairs(src:GetDescendants()) do
					archCache[desc] = desc.Archivable
					pcall(function() desc.Archivable = true end)
				end

				local clone = src:Clone()

				for obj, arch in pairs(archCache) do
					if obj and obj.Parent then pcall(function() obj.Archivable = arch end) end
				end
				if not clone then return end

				if not clone:IsA("Model") and not clone:IsA("BasePart") then
					local wrapper = Instance.new("Model")
					wrapper.Name = clone.Name
					for _, child in ipairs(clone:GetChildren()) do
						child.Parent = wrapper
					end
					clone:Destroy()
					clone = wrapper
				end

				if isChar then
					for _, child in ipairs(clone:GetChildren()) do
						if child:IsA("Tool") or child:IsA("Folder") or child:IsA("Model") then
							child:Destroy()
						elseif child:IsA("BasePart") and not validCharParts[child.Name] then
							child:Destroy()
						end
					end

					for _, desc in ipairs(clone:GetDescendants()) do
						if desc:IsA("BasePart") and not validCharParts[desc.Name] then
							if not desc:FindFirstAncestorOfClass("Accessory") then
								desc:Destroy()
							end
						elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("Highlight") or desc:IsA("ParticleEmitter") or desc:IsA("Sound") or desc:IsA("LuaSourceContainer") then
							desc:Destroy()
						end
					end
				else
					for _, desc in ipairs(clone:GetDescendants()) do
						if desc:IsA("LuaSourceContainer") or desc:IsA("Sound") then
							desc:Destroy()
						end
					end
				end

				local motorMap = {}
				if isChar then
					for _, cloneDesc in ipairs(clone:GetDescendants()) do
						if cloneDesc:IsA("Motor6D") then
							local realDesc = src:FindFirstChild(cloneDesc.Name, true)
							if realDesc and realDesc:IsA("Motor6D") then
								table.insert(motorMap, {Real = realDesc, Clone = cloneDesc})
							end
						end
					end
				end

				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						if isChar then
							d.Anchored = false 
							if d.Name == "HumanoidRootPart" then
								d.Anchored = true
								d.Transparency = 1
							else
								d.LocalTransparencyModifier = 0
								if validCharParts[d.Name] or d:IsA("MeshPart") or d:FindFirstChildWhichIsA("DataModelMesh") then
									if d.Transparency >= 1 then
										d.Transparency = 0
									end
								end
							end
						else
							d.Anchored = true
						end
					end
				end

				local hum = clone:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				end

				clone.Parent = worldModel
				currentClone = clone
				local srcRoot = src:FindFirstChild("HumanoidRootPart") or (src:IsA("Model") and src.PrimaryPart) or src:FindFirstChildWhichIsA("BasePart") or (src:IsA("BasePart") and src)
				local cloneRoot = clone:FindFirstChild("HumanoidRootPart") or (clone:IsA("Model") and clone.PrimaryPart) or clone:FindFirstChildWhichIsA("BasePart") or (clone:IsA("BasePart") and clone)

				if not isChar then
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") and d.Transparency >= 1 and not d:IsA("MeshPart") and not d:FindFirstChildWhichIsA("DataModelMesh") and not d:FindFirstChildWhichIsA("Decal") then
							d:Destroy()
						end
					end
				end

				local cf, size
				if isChar then
					if cloneRoot then
						cloneRoot.CFrame = CFrame.new(0, 0, 0)
					end
					for _, pair in ipairs(motorMap) do
						pair.Clone.Transform = pair.Real.Transform
						pair.Clone.C0 = pair.Real.C0
						pair.Clone.C1 = pair.Real.C1
					end
					cf, size = clone:GetBoundingBox()
					currentCenter = cf.Position
				else
					if clone:IsA("Model") then
						clone.PrimaryPart = nil
						local tempCF = clone:GetBoundingBox()
						clone:PivotTo(clone:GetPivot() + (-tempCF.Position))
						cf, size = clone:GetBoundingBox()
						currentCenter = cf.Position
					elseif clone:IsA("BasePart") then
						clone.CFrame = CFrame.new(0, 0, 0)
						cf = clone.CFrame
						size = clone.Size
						currentCenter = Vector3.new(0, 0, 0)
					end
				end

				local maxDim = math.max(size.X, size.Y, size.Z)
				if maxDim <= 0.1 then maxDim = 5 end

				currentDistance = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.45
				rotX = 0
				rotY = math.pi
				updateCamera()

				renderConn = RS.RenderStepped:Connect(function()
					if not viewport.Parent then 
						if renderConn then renderConn:Disconnect(); renderConn = nil end
						return 
					end
					if not viewport.Visible or viewport.AbsoluteSize.X == 0 then return end
					if not src or not src.Parent then return end

					if isChar then
						if cloneRoot then
							cloneRoot.CFrame = CFrame.new(0, 0, 0)
						end
						for _, pair in ipairs(motorMap) do
							pair.Clone.Transform = pair.Real.Transform
							pair.Clone.C0 = pair.Real.C0
							pair.Clone.C1 = pair.Real.C1
						end
					else
						if srcRoot and srcRoot.Parent and (srcRoot:IsA("BasePart") or src:IsA("Model")) then
							local rot = (srcRoot.CFrame - srcRoot.CFrame.Position)
							if clone:IsA("Model") then
								clone:PivotTo(CFrame.new(currentCenter) * rot)
							elseif clone:IsA("BasePart") then
								clone.CFrame = CFrame.new(currentCenter) * rot
							end
						end
					end
					updateCamera()
				end)
			end

			task.spawn(function()
				task.wait(0.2)
				loadTargetObject(rawObj)
			end)

			table.insert(Window._connections, LP.CharacterAdded:Connect(function(newChar)
				if rawObj == nil or rawObj == "Character" or rawObj == LP.Character or (type(rawObj) == "string" and string.find(string.lower(rawObj), "character")) then
					task.wait(0.5)
					loadTargetObject(newChar)
				end
			end))

			local isRotating = false
			local lastMousePos = Vector2.new()

			table.insert(Window._connections, viewport.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					isRotating = true
					lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
				end
			end))

			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if isRotating and input.UserInputType == Enum.UserInputType.MouseMovement then
					local curPos = Vector2.new(input.Position.X, input.Position.Y)
					local delta = curPos - lastMousePos
					lastMousePos = curPos
					rotY = rotY - (delta.X * 0.015)
					rotX = math.clamp(rotX - (delta.Y * 0.015), -math.rad(80), math.rad(80))
				end
			end))

			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					isRotating = false
				end
			end))

			local function updateLayout()
				if not contentFrame.Parent then return end
				local fullW = contentFrame.AbsoluteSize.X - 24 
				if fullW <= 0 then return end

				local vpW = math.floor(fullW * (sizePct / 100))
				local vpH = vpW 
				viewport.Size = UDim2.new(0, vpW, 0, vpH)
				viewport.Position = UDim2.new(0, 0, 0, 0)

				local textGapX = 14
				local textGapY = 10
				local availRightW = fullW - vpW - textGapX

				if sizePct == 100 or sizePct == 0 or availRightW < 40 or desc == "" then
					rightTextLbl.Visible = false
					bottomTextLbl.Visible = (desc ~= "")
					viewport.Visible = (sizePct > 0)
					bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
					bottomTextLbl.Position = UDim2.new(0, 0, 0, sizePct > 0 and (vpH + textGapY) or 0)
					bottomTextLbl.Text = desc
					bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
				else
					rightTextLbl.Visible = true
					viewport.Visible = true
					local len = string.len(desc)
					local l, r = 1, len
					local splitIdx = len
					while l <= r do
						local m = math.floor((l + r) / 2)
						local testStr = string.sub(desc, 1, m)
						local bounds = TextService:GetTextSize(testStr, 13, Enum.Font.Gotham, Vector2.new(availRightW, 10000))
						if bounds.Y > vpH then
							r = m - 1
						else
							splitIdx = m
							l = m + 1
						end
					end
					if splitIdx < len then
						local safeIdx = splitIdx
						while safeIdx > 0 and string.sub(desc, safeIdx, safeIdx):match("%S") do
							safeIdx = safeIdx - 1
						end
						if safeIdx > 0 then splitIdx = safeIdx end
					end
					local rightText = string.sub(desc, 1, splitIdx)
					local bottomText = string.sub(desc, splitIdx + 1)
					bottomText = string.gsub(bottomText, "^%s+", "")
					rightTextLbl.Position = UDim2.new(0, vpW + textGapX, 0, 0)
					rightTextLbl.Size = UDim2.new(0, availRightW, 0, vpH)
					rightTextLbl.Text = rightText
					rightTextLbl.AutomaticSize = Enum.AutomaticSize.None
					if bottomText ~= "" then
						bottomTextLbl.Visible = true
						bottomTextLbl.Position = UDim2.new(0, 0, 0, vpH + textGapY)
						bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
						bottomTextLbl.Text = bottomText
						bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
					else
						bottomTextLbl.Visible = false
					end
				end
			end

			table.insert(Window._connections, contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
			task.spawn(function()
				task.wait()
				updateLayout()
			end)

			RegisterElement(name, container)

			local api = {}
			function api:SetObject(newObj)
				rawObj = newObj
				loadTargetObject(newObj)
			end
			function api:SetSize(pct)
				sizePct = math.clamp(pct, 0, 100)
				updateLayout()
			end
			function api:SetDescription(txt)
				desc = txt
				updateLayout()
			end
			function api:ResetRotation()
				rotX = 0
				rotY = math.pi
			end
			return api
		end

		function BlockObj:CreateButton(btnConfig)
			local btnName = btnConfig.Name or "Button"
			local callback = btnConfig.Callback or function() end

			local btn = CreateElementBase(38)
			
			local btnInteractive = Instance.new("TextButton")
			btnInteractive.Name = "InteractiveButton"
			btnInteractive.Size = UDim2.new(1, 0, 1, 0)
			btnInteractive.BackgroundTransparency = 1
			btnInteractive.BorderSizePixel = 0
			btnInteractive.TextSize = 13
			btnInteractive.Text = btnName
			btnInteractive.TextTruncate = Enum.TextTruncate.AtEnd
			btnInteractive.Font = Enum.Font.Gotham
			btnInteractive.Parent = btn
			ApplyTheme(btnInteractive, "Text", "TextColor3")
			ApplyTheme(btnInteractive, "TextFont", "Font")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					btn.Size = UDim2.new(1, 0, 0, 30)
					btnInteractive.TextSize = 12
				else
					btn.Size = UDim2.new(1, 0, 0, 38)
					btnInteractive.TextSize = 13
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, btnInteractive.MouseButton1Down:Connect(function()
				TS:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.CardHover}):Play()
			end))
			table.insert(Window._connections, btnInteractive.MouseButton1Up:Connect(function()
				TS:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.Element}):Play()
				callback()
			end))
			RegisterElement(btnName, btn)
			
			local api = {}
			function api:SetText(txt)
				btnInteractive.Text = txt
			end
			function api:SetCallback(cb)
				callback = cb
			end
			return api
		end
		
		function BlockObj:CreateButtonKeybind(cfg)
			local btnName = cfg.Name or "Button"
			local callback = cfg.Callback or function() end
			local bind = cfg.Default

			local el = CreateElementBase(38)
			
			local btnInteractive = Instance.new("TextButton")
			btnInteractive.Name = "InteractiveButton"
			btnInteractive.Size = UDim2.new(1, -50, 1, 0)
			btnInteractive.BackgroundTransparency = 1
			btnInteractive.BorderSizePixel = 0
			btnInteractive.TextSize = 13
			btnInteractive.Text = btnName
			btnInteractive.TextTruncate = Enum.TextTruncate.AtEnd
			btnInteractive.Font = Enum.Font.Gotham
			btnInteractive.Parent = el
			ApplyTheme(btnInteractive, "Text", "TextColor3")
			ApplyTheme(btnInteractive, "TextFont", "Font")
			
			local box = Instance.new("Frame")
			box.Name = "KeybindBox"
			box.Size = UDim2.new(0, 30, 0, 24)
			box.AutomaticSize = Enum.AutomaticSize.X
			box.AnchorPoint = Vector2.new(1, 0.5)
			box.Position = UDim2.new(1, -7, 0.5, 0)
			box.ZIndex = 5
			box.Parent = el
			ApplyTheme(box, "Input", "BackgroundColor3")
			ApplyTheme(box, "InputTrans", "BackgroundTransparency")
			
			local boxCorner = Instance.new("UICorner")
			boxCorner.CornerRadius = GLOBAL_CORNER
			boxCorner.Parent = box
			CS:AddTag(boxCorner, "ElementCorner")
			
			attachStroke(box, "ElementStroke")
			
			local bBtn = Instance.new("TextButton")
			bBtn.Name = "KeybindButton"
			bBtn.Size = UDim2.new(1,0,1,0)
			bBtn.BackgroundTransparency = 1
			bBtn.TextSize = 12
			bBtn.Text = getShortKey(bind)
			bBtn.Font = Enum.Font.Gotham
			bBtn.ZIndex = 6
			bBtn.Parent = box
			ApplyTheme(bBtn, "TextMuted", "TextColor3")
			ApplyTheme(bBtn, "TextFont", "Font")
			
			local mobileToggle, getMobileBtn
			if isMobile then
				mobileToggle, _, getMobileBtn = createMobileToggle(el, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), callback))
					else
						removeBtn()
					end
				end)
			end

			local p = Instance.new("UIPadding")
			p.Name = "KeybindPadding"
			p.PaddingLeft = UDim.new(0,6)
			p.PaddingRight = UDim.new(0,6)
			p.Parent = bBtn

			local function updateStyle(style)
				local edge = (style == 3 or style == 4) and 5 or 7
				if style == 3 or style == 4 then
					el.Size = UDim2.new(1, 0, 0, 30)
					btnInteractive.TextSize = 12
					box.Size = UDim2.new(0, 30, 0, 20)
					bBtn.TextSize = 11
				else
					el.Size = UDim2.new(1, 0, 0, 38)
					btnInteractive.TextSize = 13
					box.Size = UDim2.new(0, 30, 0, 24)
					bBtn.TextSize = 12
				end

				box.AnchorPoint = Vector2.new(1, 0.5)
				box.Position = UDim2.new(1, -edge, 0.5, 0)
				btnInteractive.Position = UDim2.new(0, mobileToggle and 36 or 0, 0, 0)
				btnInteractive.Size = UDim2.new(1, -(50 + (mobileToggle and 36 or 0)), 1, 0)
				btnInteractive.TextXAlignment = Enum.TextXAlignment.Center
				if mobileToggle then
					mobileToggle.AnchorPoint = Vector2.new(0, 0.5)
					mobileToggle.Position = UDim2.new(0, 12, 0.5, 0)
					mobileToggle.Size = UDim2.new(0, 20, 0, 20)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, btnInteractive.MouseButton1Down:Connect(function()
				TS:Create(el, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.CardHover}):Play()
			end))
			table.insert(Window._connections, btnInteractive.MouseButton1Up:Connect(function()
				TS:Create(el, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = THEME.Element}):Play()
				callback()
			end))
			
			local isBinding = false
			
			table.insert(Window._connections, bBtn.MouseButton1Click:Connect(function() 
				isBinding = true
				bBtn.Text = "..."
				ApplyTheme(bBtn, "Accent", "TextColor3") 
			end))
			
			table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then return end
				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						bind = input.KeyCode
						bBtn.Text = getShortKey(bind)
						ApplyTheme(bBtn, "TextMuted", "TextColor3")
						isBinding = false
					end
				else
					if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
						callback()
					end
				end
			end))
			RegisterElement(btnName, el)
			
			local api = {}
			function api:SetText(txt)
				btnInteractive.Text = txt
			end
			function api:SetKeybind(k)
				bind = k
				bBtn.Text = getShortKey(k)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(k) end
			end
			function api:SetCallback(cb)
				callback = cb
			end
			function api:Save()
				return { Bind = bind and bind.Name or nil }
			end
			function api:Load(val)
				if val.Bind then
					api:SetKeybind(Enum.KeyCode[val.Bind])
				end
			end
			RegisterElementAPI("ButtonKeybind", btnName, api)
			return api
		end

		function BlockObj:CreateToggle(cfg)
			local tglName = cfg.Name or "Toggle"
			local state = cfg.Default or false
			local callback = cfg.Callback or function() end

			local hasColorpicker = cfg.Colorpicker or (cfg.Color ~= nil)
			local hasColorpicker2 = cfg.Colorpicker2 or (cfg.Color2 ~= nil)
			local hasKeybind = (cfg.Keybind ~= nil)
			
			local bind = nil
			if typeof(cfg.Keybind) == "EnumItem" then
				bind = cfg.Keybind
			elseif cfg.Keybind == true then
				bind = Enum.KeyCode.Unknown
			end
			
			local defaultColor = cfg.Color or Color3.fromRGB(255, 255, 255)
			local defaultColor2 = cfg.Color2 or Color3.fromRGB(255, 255, 255)
			local isCombo = hasColorpicker or hasColorpicker2 or hasKeybind

			local container = CreateElementBase(38)
			if isCombo then
				container:SetAttribute("TogglePos", THEME.TogglePosition)
				CS:AddTag(container, "ComboToggleBind")
			end

			local fullBarBtn = Instance.new("TextButton")
			fullBarBtn.Name = "FullBarClick"
			fullBarBtn.Size = UDim2.new(1, 0, 1, 0)
			fullBarBtn.Position = UDim2.new(0, 0, 0, 0)
			fullBarBtn.BackgroundTransparency = 1
			fullBarBtn.BorderSizePixel = 0
			fullBarBtn.Text = ""
			fullBarBtn.ZIndex = 2
			fullBarBtn.Parent = container
			
			local label = Instance.new("TextLabel")
			label.Name = isCombo and "Label" or "ToggleLabel"
			label.Size = UDim2.new(1, -60, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = tglName
			label.Font = Enum.Font.Gotham
			label.ZIndex = 3
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")
			if not isCombo then CS:AddTag(label, "ToggleLabelBind") end

			local toggleBox = Instance.new("Frame")
			toggleBox.Name = "ToggleBox"
			toggleBox.Size = UDim2.new(0, 24, 0, 24)
			toggleBox.AnchorPoint = Vector2.new(1, 0.5)
			toggleBox.Position = UDim2.new(1, -7, 0.5, 0) 
			toggleBox.BackgroundTransparency = 1
			toggleBox.BorderSizePixel = 0
			toggleBox.ZIndex = 3
			toggleBox.Parent = container
			if not isCombo then CS:AddTag(toggleBox, "ToggleBoxBind") end
			
			local toggleBoxCorner = Instance.new("UICorner")
			toggleBoxCorner.CornerRadius = GLOBAL_CORNER
			toggleBoxCorner.Parent = toggleBox
			CS:AddTag(toggleBoxCorner, "ElementCorner")

			local toggleStroke = Instance.new("UIStroke")
			toggleStroke.Name = "ToggleStroke"
			toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			toggleStroke.Thickness = 1
			toggleStroke.Parent = toggleBox
			ApplyTheme(toggleStroke, state and "Accent" or "Outlines", "Color")

			local fill = Instance.new("Frame")
			fill.Name = "ToggleFill"
			fill.Position = UDim2.new(0.5, 0, 0.5, 0)
			fill.AnchorPoint = Vector2.new(0.5, 0.5)
			fill.BorderSizePixel = 0
			fill.ZIndex = 4
			fill.Parent = toggleBox
			ApplyTheme(fill, "Accent", "BackgroundColor3")
			
			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = GLOBAL_CORNER
			fillCorner.Parent = fill
			CS:AddTag(fillCorner, "ElementCorner")

			if state then fill.Size = UDim2.new(1, -10, 1, -10) else fill.Size = UDim2.new(0, 0, 0, 0) end

			local mobileToggle, getMobileBtn
			local previewBox, previewBox2, kbBox, kbBtn
			local currentColor = defaultColor
			local currentColor2 = defaultColor2
			local updateColors, updateColors2

			local function fireCallback()
				if not callback then return end
				if hasColorpicker and hasColorpicker2 and hasKeybind then
					callback(state, currentColor, currentColor2, bind)
				elseif hasColorpicker and hasColorpicker2 then
					callback(state, currentColor, currentColor2)
				elseif hasColorpicker and hasKeybind then
					callback(state, currentColor, bind)
				elseif hasColorpicker2 and hasKeybind then
					callback(state, currentColor2, bind)
				elseif hasColorpicker then
					callback(state, currentColor)
				elseif hasColorpicker2 then
					callback(state, currentColor2)
				elseif hasKeybind then
					callback(state, bind)
				else
					callback(state)
				end
			end
			
			if hasColorpicker then
				previewBox = Instance.new("TextButton")
				previewBox.Name = "PreviewBox"
				previewBox.BackgroundColor3 = defaultColor
				previewBox.BorderSizePixel = 0
				previewBox.Text = ""
				previewBox.ZIndex = 5
				previewBox.Parent = container
				
				local previewCorner = Instance.new("UICorner")
				previewCorner.CornerRadius = GLOBAL_CORNER
				previewCorner.Parent = previewBox
				CS:AddTag(previewCorner, "ElementCorner")
				
				local previewStroke = Instance.new("UIStroke")
				previewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				previewStroke.Thickness = 2
				previewStroke.Parent = previewBox
				ApplyTheme(previewStroke, "Outlines", "Color")
				
				updateColors = AttachColorPicker(previewBox, defaultColor, function(col)
					currentColor = col
					fireCallback()
				end)
			end

			if hasColorpicker2 then
				previewBox2 = Instance.new("TextButton")
				previewBox2.Name = "PreviewBox2"
				previewBox2.BackgroundColor3 = defaultColor2
				previewBox2.BorderSizePixel = 0
				previewBox2.Text = ""
				previewBox2.ZIndex = 5
				previewBox2.Parent = container
				
				local previewCorner2 = Instance.new("UICorner")
				previewCorner2.CornerRadius = GLOBAL_CORNER
				previewCorner2.Parent = previewBox2
				CS:AddTag(previewCorner2, "ElementCorner")
				
				local previewStroke2 = Instance.new("UIStroke")
				previewStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				previewStroke2.Thickness = 2
				previewStroke2.Parent = previewBox2
				ApplyTheme(previewStroke2, "Outlines", "Color")
				
				updateColors2 = AttachColorPicker(previewBox2, defaultColor2, function(col)
					currentColor2 = col
					fireCallback()
				end)
			end
			
			if hasKeybind then
				kbBox = Instance.new("Frame")
				kbBox.Name = "KeybindBox"
				kbBox.BorderSizePixel = 0
				kbBox.AutomaticSize = Enum.AutomaticSize.X
				kbBox.ZIndex = 5
				kbBox.Parent = container
				ApplyTheme(kbBox, "Input", "BackgroundColor3")
				ApplyTheme(kbBox, "InputTrans", "BackgroundTransparency")
				
				local kbCorner = Instance.new("UICorner")
				kbCorner.CornerRadius = GLOBAL_CORNER
				kbCorner.Parent = kbBox
				CS:AddTag(kbCorner, "ElementCorner")
				attachStroke(kbBox, "ElementStroke")
				
				kbBtn = Instance.new("TextButton")
				kbBtn.Size = UDim2.new(1,0,1,0)
				kbBtn.BackgroundTransparency = 1
				kbBtn.Text = getShortKey(bind)
				kbBtn.Font = Enum.Font.Gotham
				kbBtn.ZIndex = 6
				kbBtn.Parent = kbBox
				ApplyTheme(kbBtn, "TextMuted", "TextColor3")
				ApplyTheme(kbBtn, "TextFont", "Font")

				local kbPad = Instance.new("UIPadding")
				kbPad.Name = "KeybindPadding"
				kbPad.PaddingLeft = UDim.new(0, 6)
				kbPad.PaddingRight = UDim.new(0, 6)
				kbPad.Parent = kbBtn
			end
			
			local function updateStyle(style)
				local isCompact = (style == 3 or style == 4)
				
				if not isCombo then
					container.Size = UDim2.new(1, 0, 0, isCompact and 30 or 38)
					label.TextSize = isCompact and 12 or 13
					
					local boxSize = isCompact and 18 or 24
					toggleBox.Size = UDim2.new(0, boxSize, 0, boxSize)
					
					local tPos = THEME.TogglePosition
					local edge = isCompact and 5 or 7
					
					if tPos == "Left" then
						toggleBox.AnchorPoint = Vector2.new(0, 0.5)
						toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
						label.Position = UDim2.new(0, edge + boxSize + 7, 0, 0)
						label.Size = UDim2.new(1, -(edge + boxSize + 15), 1, 0)
					else
						toggleBox.AnchorPoint = Vector2.new(1, 0.5)
						toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
						label.Position = UDim2.new(0, 15, 0, 0)
						label.Size = UDim2.new(1, -60, 1, 0)
					end
				else
					container.Size = UDim2.new(1, 0, 0, isCompact and 30 or 38)
					label.TextSize = isCompact and 12 or 13
					
					local boxSize = isCompact and 18 or 24
					local kbH = isCompact and 20 or 24
					toggleBox.Size = UDim2.new(0, boxSize, 0, boxSize)
					
					if previewBox then previewBox.Size = UDim2.new(0, boxSize, 0, boxSize) end
					if previewBox2 then previewBox2.Size = UDim2.new(0, boxSize, 0, boxSize) end
					if kbBox then kbBox.Size = UDim2.new(0, 30, 0, kbH); kbBtn.TextSize = isCompact and 11 or 12 end
					
					local gap = 6
					local edge = isCompact and 5 or 7
					local tPos = container:GetAttribute("TogglePos") or THEME.TogglePosition
					
					if tPos == "Left" then
						toggleBox.AnchorPoint = Vector2.new(0, 0.5)
						toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
						
						local rightOffset = edge
						
						if kbBox then
							kbBox.AnchorPoint = Vector2.new(1, 0.5)
							kbBox.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + 30 + gap
						end

						if previewBox2 then
							previewBox2.AnchorPoint = Vector2.new(1, 0.5)
							previewBox2.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + boxSize + gap
						end
						
						if previewBox then
							previewBox.AnchorPoint = Vector2.new(1, 0.5)
							previewBox.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + boxSize + gap
						end
						if mobileToggle then
							mobileToggle.AnchorPoint = Vector2.new(1, 0.5)
							mobileToggle.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + 22 + gap
						end
						
						local leftOffset = edge + boxSize + gap
						label.Position = UDim2.new(0, leftOffset, 0, 0)
						label.Size = UDim2.new(1, -(leftOffset + rightOffset + 5), 1, 0)
						label.TextXAlignment = Enum.TextXAlignment.Left
					else
						toggleBox.AnchorPoint = Vector2.new(1, 0.5)
						toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
						
						local offset = edge + boxSize + gap
						if previewBox then
							previewBox.AnchorPoint = Vector2.new(1, 0.5)
							previewBox.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + boxSize + gap
						end

						if previewBox2 then
							previewBox2.AnchorPoint = Vector2.new(1, 0.5)
							previewBox2.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + boxSize + gap
						end
						
						if kbBox then
							kbBox.AnchorPoint = Vector2.new(1, 0.5)
							kbBox.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + 30 + gap
						end
						
						offset = offset + 5
						label.Position = UDim2.new(0, 15, 0, 0)
						label.Size = UDim2.new(1, -offset - 15, 1, 0)
						label.TextXAlignment = Enum.TextXAlignment.Left
					end
				end
			end
			
			table.insert(Window._styleCallbacks, updateStyle)
			if isCombo then container:GetAttributeChangedSignal("TogglePos"):Connect(function() updateStyle(THEME.ElementStyle) end) end
			updateStyle(THEME.ElementStyle)
			
			local function updateToggle()
				if state then
					ApplyTheme(toggleStroke, "Accent", "Color")
					TS:Create(fill, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -10, 1, -10)}):Play()
				else
					ApplyTheme(toggleStroke, "Outlines", "Color")
					TS:Create(fill, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
				end
				fireCallback()
				if Window.UpdateKeybinds then Window.UpdateKeybinds() end
			end
			
			if isMobile and hasKeybind then
				mobileToggle, _, getMobileBtn = createMobileToggle(container, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), function()
							state = not state
							updateToggle()
						end))
					else
						removeBtn()
					end
				end)
				updateStyle(THEME.ElementStyle)
			end

			table.insert(Window._connections, fullBarBtn.MouseButton1Click:Connect(function()
				state = not state
				updateToggle()
			end))
			
			if hasKeybind then
				local isBinding = false
				table.insert(Window._connections, kbBtn.MouseButton1Click:Connect(function() 
					isBinding = true
					kbBtn.Text = "..."
					ApplyTheme(kbBtn, "Accent", "TextColor3") 
				end))
				
				table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if isBinding then
						if input.UserInputType == Enum.UserInputType.Keyboard then
							bind = input.KeyCode
							kbBtn.Text = getShortKey(bind)
							ApplyTheme(kbBtn, "TextMuted", "TextColor3")
							isBinding = false
							fireCallback()
							if Window.UpdateKeybinds then Window.UpdateKeybinds() end
						end
					else
						if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
							state = not state
							updateToggle()
						end
					end
				end))
			end
			
			RegisterElement(tglName, container)
			
			local api = {}
			function api:Set(newState)
				if state == newState then return end
				state = newState
				if state then
					ApplyTheme(toggleStroke, "Accent", "Color")
					fill.Size = UDim2.new(1, -10, 1, -10)
				else
					ApplyTheme(toggleStroke, "Outlines", "Color")
					fill.Size = UDim2.new(0, 0, 0, 0)
				end
				fireCallback()
				if Window.UpdateKeybinds then Window.UpdateKeybinds() end
			end
			function api:SetColor(newColor)
				if not hasColorpicker then return end
				currentColor = newColor
				if updateColors then 
					updateColors:SetColor(newColor)
				end
			end
			function api:SetColor2(newColor)
				if not hasColorpicker2 then return end
				currentColor2 = newColor
				if updateColors2 then 
					updateColors2:SetColor(newColor)
				end
			end
			function api:SetKeybind(newKey)
				if not hasKeybind then return end
				bind = newKey
				kbBtn.Text = getShortKey(bind)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(bind) end
			end
			function api:Save()
				return {
					State = state,
					Color = hasColorpicker and {currentColor.R, currentColor.G, currentColor.B} or nil,
					Color2 = hasColorpicker2 and {currentColor2.R, currentColor2.G, currentColor2.B} or nil,
					Bind = hasKeybind and (bind and bind.Name) or nil
				}
			end
			function api:Load(val)
				if val.State ~= nil then api:Set(val.State) end
				if hasColorpicker and val.Color then api:SetColor(Color3.new(unpack(val.Color))) end
				if hasColorpicker2 and val.Color2 then api:SetColor2(Color3.new(unpack(val.Color2))) end
				if hasKeybind and val.Bind then api:SetKeybind(Enum.KeyCode[val.Bind]) end
			end
			RegisterElementAPI("Toggle", tglName, api)

			if state then
				task.spawn(fireCallback)
			end

			return api
		end

		function BlockObj:CreateInput(inpConfig)
			local inpName = inpConfig.Name or "Input"
			local placeholder = inpConfig.Placeholder or "..."
			local defaultText = inpConfig.Default or ""
			local callback = inpConfig.Callback or function() end

			local container = CreateElementBase(38)

			local label = Instance.new("TextLabel")
			label.Name = "InputLabel"
			label.Size = UDim2.new(0.52, -15, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = inpName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local inputBox = Instance.new("Frame")
			inputBox.Name = "InputBox"
			inputBox.Size = UDim2.new(0.44, 0, 0, 28)
			inputBox.AnchorPoint = Vector2.new(1, 0.5)
			inputBox.Position = UDim2.new(1, -7, 0.5, 0)
			inputBox.BorderSizePixel = 0
			inputBox.ClipsDescendants = true
			inputBox.Parent = container
			ApplyTheme(inputBox, "Input", "BackgroundColor3")
			ApplyTheme(inputBox, "InputTrans", "BackgroundTransparency")
			
			local inputBoxCorner = Instance.new("UICorner")
			inputBoxCorner.CornerRadius = GLOBAL_CORNER
			inputBoxCorner.Parent = inputBox
			CS:AddTag(inputBoxCorner, "ElementCorner")
			
			attachStroke(inputBox, "ElementStroke")

			local textBox = Instance.new("TextBox")
			textBox.Name = "TextBox"
			textBox.Size = UDim2.new(1, 0, 1, 0)
			textBox.Position = UDim2.new(0, 0, 0, 0)
			textBox.BackgroundTransparency = 1
			textBox.BorderSizePixel = 0
			textBox.TextSize = 12
			textBox.PlaceholderText = placeholder
			textBox.Text = defaultText
			textBox.TextXAlignment = Enum.TextXAlignment.Center
			textBox.TextTruncate = Enum.TextTruncate.AtEnd
			textBox.Font = Enum.Font.Gotham
			textBox.Parent = inputBox
			ApplyTheme(textBox, "Text", "TextColor3")
			ApplyTheme(textBox, "TextMuted", "PlaceholderColor3")
			ApplyTheme(textBox, "TextFont", "Font")
			
			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					inputBox.Size = UDim2.new(0.44, 0, 0, 28)
					inputBox.AnchorPoint = Vector2.new(1, 0.5)
					inputBox.Position = UDim2.new(1, -7, 0.5, 0)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 56)
					label.Size = UDim2.new(1, -24, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					inputBox.Size = UDim2.new(1, -16, 0, 26) 
					inputBox.AnchorPoint = Vector2.new(0, 0)
					inputBox.Position = UDim2.new(0, 8, 0, 22) 
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					inputBox.Size = UDim2.new(0.44, 0, 0, 22)
					inputBox.AnchorPoint = Vector2.new(1, 0.5)
					inputBox.Position = UDim2.new(1, -5, 0.5, 0)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 46)
					label.Size = UDim2.new(1, -24, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					inputBox.Size = UDim2.new(1, -12, 0, 22) 
					inputBox.AnchorPoint = Vector2.new(0, 0)
					inputBox.Position = UDim2.new(0, 6, 0, 18) 
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, textBox.FocusLost:Connect(function()
				callback(textBox.Text)
			end))
			RegisterElement(inpName, container)
			
			local api = {}
			function api:SetText(txt)
				textBox.Text = txt
				callback(txt)
			end
			function api:Save()
				return { Text = textBox.Text }
			end
			function api:Load(val)
				if val.Text ~= nil then
					api:SetText(val.Text)
				end
			end
			RegisterElementAPI("Input", inpName, api)
			return api
		end

		function BlockObj:CreateDropdown(dropConfig)
			local isMulti = dropConfig.Multi or false
			local isSearch = dropConfig.Search or false
			return CreateAdvancedDropdown(dropConfig, isMulti, isSearch)
		end

		function BlockObj:CreateSlider(slConfig)
			local slName = slConfig.Name or "Slider"
			local min = slConfig.Min or 0
			local max = slConfig.Max or 100
			local rawStep = slConfig.Step or 1
			local step = (type(rawStep) == "number" and rawStep > 0) and rawStep or 1

			local stepStr = tostring(step)
			local decimals = 0
			local exp = stepStr:match("[eE]%-(%d+)")
			if exp then
				local mantissa = stepStr:match("^(.-)[eE]")
				local mantissaDecs = (mantissa and mantissa:find("%.")) and #mantissa:split(".")[2] or 0
				decimals = tonumber(exp) + mantissaDecs
			elseif stepStr:find("%.") then
				decimals = #stepStr:split(".")[2]
			end
			decimals = math.clamp(decimals, 0, 14)

			local function roundVal(val)
				val = math.clamp(val, min, max)
				local snapped = math.round(val / step) * step
				return tonumber(string.format("%." .. decimals .. "f", snapped)) or snapped
			end

			local function formatVal(val)
				return string.format("%." .. decimals .. "f", val)
			end

			local default = roundVal(slConfig.Default or min)
			local callback = slConfig.Callback or function() end
			local currentValue = default

			local container = CreateElementBase(38) 

			local label = Instance.new("TextLabel")
			label.Name = "SliderLabel"
			label.Size = UDim2.new(0.35, 0, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = slName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local valueBox = Instance.new("Frame")
			valueBox.Name = "ValueBox"
			valueBox.Size = UDim2.new(0, 52, 0, 24)
			valueBox.AnchorPoint = Vector2.new(1, 0.5)
			valueBox.Position = UDim2.new(1, -7, 0.5, 0)
			valueBox.BorderSizePixel = 0
			valueBox.Parent = container
			ApplyTheme(valueBox, "Input", "BackgroundColor3")
			ApplyTheme(valueBox, "InputTrans", "BackgroundTransparency")
			
			local valueBoxCorner = Instance.new("UICorner")
			valueBoxCorner.CornerRadius = GLOBAL_CORNER
			valueBoxCorner.Parent = valueBox
			CS:AddTag(valueBoxCorner, "ElementCorner")
			
			attachStroke(valueBox, "ElementStroke")

			local valueInput = Instance.new("TextBox")
			valueInput.Name = "ValueInput"
			valueInput.Size = UDim2.new(1, 0, 1, 0)
			valueInput.BackgroundTransparency = 1
			valueInput.BorderSizePixel = 0
			valueInput.TextSize = 12
			valueInput.Text = formatVal(default)
			valueInput.TextTruncate = Enum.TextTruncate.AtEnd
			valueInput.Font = Enum.Font.Gotham
			valueInput.Parent = valueBox
			ApplyTheme(valueInput, "Text", "TextColor3")
			ApplyTheme(valueInput, "TextFont", "Font")

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(0.52, -64, 0, 6) 
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -64, 0.5, 0)
			track.BorderSizePixel = 0
			track.Parent = container
			ApplyTheme(track, "Input", "BackgroundColor3")
			ApplyTheme(track, "InputTrans", "BackgroundTransparency")
			
			local trackCorner = Instance.new("UICorner")
			trackCorner.CornerRadius = UDim.new(1, 0)
			trackCorner.Parent = track

			local trackStroke = Instance.new("UIStroke")
			trackStroke.Name = "TrackStroke"
			trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			trackStroke.Thickness = 1
			trackStroke.Parent = track
			ApplyTheme(trackStroke, "Outlines", "Color")
			CS:AddTag(trackStroke, "ElementStroke")

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0)
			fill.BorderSizePixel = 0
			fill.Parent = track
			ApplyTheme(fill, "Accent", "BackgroundColor3")
			
			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(1, 0)
			fillCorner.Parent = fill

			local knob = Instance.new("Frame")
			knob.Name = "SliderKnob"
			knob.Size = UDim2.new(0, 12, 0, 12)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.Position = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 0.5, 0)
			knob.BorderSizePixel = 0
			knob.ZIndex = 3
			knob.Parent = track
			ApplyTheme(knob, "Accent", "BackgroundColor3")

			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = knob

			local knobStroke = Instance.new("UIStroke")
			knobStroke.Thickness = 1.5
			knobStroke.Color = Color3.fromRGB(255, 255, 255)
			knobStroke.Parent = knob

			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.35, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 52, 0, 24)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -7, 0.5, 0)
					track.Size = UDim2.new(0.52, -64, 0, 6)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -64, 0.5, 0)
					knob.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 44)
					label.Size = UDim2.new(0.5, 0, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 52, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 4)
					track.Size = UDim2.new(1, -24, 0, 6)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 28)
					knob.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.35, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 52, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -5, 0.5, 0)
					track.Size = UDim2.new(0.52, -64, 0, 4)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -61, 0.5, 0)
					knob.Size = UDim2.new(0, 10, 0, 10)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.5, 0, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 52, 0, 18)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 3)
					track.Size = UDim2.new(1, -24, 0, 4)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 24)
					knob.Size = UDim2.new(0, 10, 0, 10)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local draggingSlider = false
			local function updateSlider(inputPos)
				local relative = math.clamp((inputPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local rawValue = min + ((max - min) * relative)
				local steppedValue = roundVal(rawValue)
				currentValue = steppedValue
				valueInput.Text = formatVal(steppedValue)
				local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
				TS:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
				TS:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
				callback(steppedValue)
			end

			table.insert(Window._connections, track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSlider = true
					updateSlider(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateSlider(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSlider = false
				end
			end))

			table.insert(Window._connections, valueInput.FocusLost:Connect(function()
				local num = tonumber(valueInput.Text)
				if num then
					local steppedValue = roundVal(num)
					currentValue = steppedValue
					valueInput.Text = formatVal(steppedValue)
					local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
					TS:Create(fill, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
					TS:Create(knob, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
					callback(steppedValue)
				else
					currentValue = min
					valueInput.Text = formatVal(min)
					fill.Size = UDim2.new(0, 0, 1, 0)
					knob.Position = UDim2.new(0, 0, 0.5, 0)
					callback(min)
				end
			end))
			RegisterElement(slName, container)
			
			local api = {}
			function api:Set(newVal)
				local steppedValue = roundVal(newVal)
				if currentValue == steppedValue then return end
				currentValue = steppedValue
				valueInput.Text = formatVal(steppedValue)
				local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
				TS:Create(fill, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
				TS:Create(knob, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
				callback(steppedValue)
			end
			function api:Save()
				return { Value = currentValue }
			end
			function api:Load(val)
				if val.Value ~= nil then
					api:Set(val.Value)
				end
			end
			RegisterElementAPI("Slider", slName, api)
			return api
		end

		function BlockObj:CreateRangeSlider(rsConfig)
			local rsName = rsConfig.Name or "Range Slider"
			local min = rsConfig.Min or 0
			local max = rsConfig.Max or 100
			local rawStep = rsConfig.Step or 1
			local step = (type(rawStep) == "number" and rawStep > 0) and rawStep or 1

			local stepStr = tostring(step)
			local decimals = 0
			local exp = stepStr:match("[eE]%-(%d+)")
			if exp then
				local mantissa = stepStr:match("^(.-)[eE]")
				local mantissaDecs = (mantissa and mantissa:find("%.")) and #mantissa:split(".")[2] or 0
				decimals = tonumber(exp) + mantissaDecs
			elseif stepStr:find("%.") then
				decimals = #stepStr:split(".")[2]
			end
			decimals = math.clamp(decimals, 0, 14)

			local function roundVal(val)
				val = math.clamp(val, min, max)
				local snapped = math.round(val / step) * step
				return tonumber(string.format("%." .. decimals .. "f", snapped)) or snapped
			end

			local function formatVal(val)
				return string.format("%." .. decimals .. "f", val)
			end

			local def = rsConfig.Default
			local defMin = min
			local defMax = max
			if type(def) == "table" then
				defMin = def.Min or def[1] or min
				defMax = def.Max or def[2] or max
			end
			local currentMin = roundVal(defMin)
			local currentMax = roundVal(defMax)
			if currentMin > currentMax then currentMin, currentMax = currentMax, currentMin end
			local callback = rsConfig.Callback or function() end

			local container = CreateElementBase(38)

			local label = Instance.new("TextLabel")
			label.Name = "RangeLabel"
			label.Size = UDim2.new(0.32, 0, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = rsName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local valueBox = Instance.new("Frame")
			valueBox.Name = "ValueBox"
			valueBox.Size = UDim2.new(0, 72, 0, 24)
			valueBox.AnchorPoint = Vector2.new(1, 0.5)
			valueBox.Position = UDim2.new(1, -7, 0.5, 0)
			valueBox.BorderSizePixel = 0
			valueBox.Parent = container
			ApplyTheme(valueBox, "Input", "BackgroundColor3")
			ApplyTheme(valueBox, "InputTrans", "BackgroundTransparency")
			
			local valueBoxCorner = Instance.new("UICorner")
			valueBoxCorner.CornerRadius = GLOBAL_CORNER
			valueBoxCorner.Parent = valueBox
			CS:AddTag(valueBoxCorner, "ElementCorner")
			attachStroke(valueBox, "ElementStroke")

			local valueDisplay = Instance.new("TextLabel")
			valueDisplay.Name = "ValueDisplay"
			valueDisplay.Size = UDim2.new(1, 0, 1, 0)
			valueDisplay.BackgroundTransparency = 1
			valueDisplay.TextSize = 11
			valueDisplay.Text = formatVal(currentMin) .. " - " .. formatVal(currentMax)
			valueDisplay.TextTruncate = Enum.TextTruncate.AtEnd
			valueDisplay.Font = Enum.Font.Gotham
			valueDisplay.Parent = valueBox
			ApplyTheme(valueDisplay, "Text", "TextColor3")
			ApplyTheme(valueDisplay, "TextFont", "Font")

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(0.52, -84, 0, 6)
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -84, 0.5, 0)
			track.BorderSizePixel = 0
			track.Parent = container
			ApplyTheme(track, "Input", "BackgroundColor3")
			ApplyTheme(track, "InputTrans", "BackgroundTransparency")

			local trackCorner = Instance.new("UICorner")
			trackCorner.CornerRadius = UDim.new(1, 0)
			trackCorner.Parent = track

			local trackStroke = Instance.new("UIStroke")
			trackStroke.Name = "TrackStroke"
			trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			trackStroke.Thickness = 1
			trackStroke.Parent = track
			ApplyTheme(trackStroke, "Outlines", "Color")
			CS:AddTag(trackStroke, "ElementStroke")

			local alpha1 = math.clamp((currentMin - min) / (max - min), 0, 1)
			local alpha2 = math.clamp((currentMax - min) / (max - min), 0, 1)

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Position = UDim2.new(alpha1, 0, 0, 0)
			fill.Size = UDim2.new(math.max(0, alpha2 - alpha1), 0, 1, 0)
			fill.BorderSizePixel = 0
			fill.Parent = track
			ApplyTheme(fill, "Accent", "BackgroundColor3")

			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(1, 0)
			fillCorner.Parent = fill

			local knob1 = Instance.new("Frame")
			knob1.Name = "KnobMin"
			knob1.Size = UDim2.new(0, 12, 0, 12)
			knob1.AnchorPoint = Vector2.new(0.5, 0.5)
			knob1.Position = UDim2.new(alpha1, 0, 0.5, 0)
			knob1.BorderSizePixel = 0
			knob1.ZIndex = 3
			knob1.Parent = track
			ApplyTheme(knob1, "Accent", "BackgroundColor3")

			local k1Corner = Instance.new("UICorner")
			k1Corner.CornerRadius = UDim.new(1, 0)
			k1Corner.Parent = knob1

			local k1Stroke = Instance.new("UIStroke")
			k1Stroke.Thickness = 1.5
			k1Stroke.Color = Color3.fromRGB(255, 255, 255)
			k1Stroke.Parent = knob1

			local knob2 = Instance.new("Frame")
			knob2.Name = "KnobMax"
			knob2.Size = UDim2.new(0, 12, 0, 12)
			knob2.AnchorPoint = Vector2.new(0.5, 0.5)
			knob2.Position = UDim2.new(alpha2, 0, 0.5, 0)
			knob2.BorderSizePixel = 0
			knob2.ZIndex = 3
			knob2.Parent = track
			ApplyTheme(knob2, "Accent", "BackgroundColor3")

			local k2Corner = Instance.new("UICorner")
			k2Corner.CornerRadius = UDim.new(1, 0)
			k2Corner.Parent = knob2

			local k2Stroke = Instance.new("UIStroke")
			k2Stroke.Thickness = 1.5
			k2Stroke.Color = Color3.fromRGB(255, 255, 255)
			k2Stroke.Parent = knob2

			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.32, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 72, 0, 24)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -7, 0.5, 0)
					track.Size = UDim2.new(0.52, -84, 0, 6)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -84, 0.5, 0)
					knob1.Size = UDim2.new(0, 12, 0, 12)
					knob2.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 44)
					label.Size = UDim2.new(0.5, 0, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 72, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 4)
					track.Size = UDim2.new(1, -24, 0, 6)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 28)
					knob1.Size = UDim2.new(0, 12, 0, 12)
					knob2.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.32, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 68, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -5, 0.5, 0)
					track.Size = UDim2.new(0.52, -80, 0, 4)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -77, 0.5, 0)
					knob1.Size = UDim2.new(0, 10, 0, 10)
					knob2.Size = UDim2.new(0, 10, 0, 10)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.5, 0, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 68, 0, 18)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 3)
					track.Size = UDim2.new(1, -24, 0, 4)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 24)
					knob1.Size = UDim2.new(0, 10, 0, 10)
					knob2.Size = UDim2.new(0, 10, 0, 10)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local draggingKnob = nil
			local function applyVisuals()
				local a1 = math.clamp((currentMin - min) / (max - min), 0, 1)
				local a2 = math.clamp((currentMax - min) / (max - min), 0, 1)
				valueDisplay.Text = formatVal(currentMin) .. " - " .. formatVal(currentMax)
				TS:Create(knob1, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(a1, 0, 0.5, 0)}):Play()
				TS:Create(knob2, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(a2, 0, 0.5, 0)}):Play()
				TS:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.new(a1, 0, 0, 0),
					Size = UDim2.new(math.max(0, a2 - a1), 0, 1, 0)
				}):Play()
				callback(currentMin, currentMax)
			end

			local function updateDrag(inputX)
				local rel = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local val = roundVal(min + ((max - min) * rel))
				if draggingKnob == 1 then
					currentMin = math.clamp(val, min, currentMax)
				elseif draggingKnob == 2 then
					currentMax = math.clamp(val, currentMin, max)
				end
				applyVisuals()
			end

			table.insert(Window._connections, track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					local a1 = (currentMin - min) / (max - min)
					local a2 = (currentMax - min) / (max - min)
					if math.abs(rel - a1) <= math.abs(rel - a2) then
						draggingKnob = 1
					else
						draggingKnob = 2
					end
					updateDrag(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingKnob and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateDrag(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingKnob = nil
				end
			end))

			RegisterElement(rsName, container)

			local api = {}
			function api:Set(newMin, newMax)
				currentMin = roundVal(newMin)
				currentMax = roundVal(newMax)
				if currentMin > currentMax then currentMin, currentMax = currentMax, currentMin end
				applyVisuals()
			end
			function api:Save()
				return { Min = currentMin, Max = currentMax }
			end
			function api:Load(val)
				if val.Min ~= nil and val.Max ~= nil then
					api:Set(val.Min, val.Max)
				end
			end
			RegisterElementAPI("RangeSlider", rsName, api)
			return api
		end
		
		function BlockObj:CreateColorpicker(cpConfig)
			local cpName = cpConfig.Name or "Colorpicker"
			local defaultColor = cpConfig.Default or Color3.fromRGB(255, 255, 255)
			local callback = cpConfig.Callback or function() end
			local currentColor = defaultColor
			
			local container = CreateElementBase(38)

			local label = Instance.new("TextLabel")
			label.Name = "ColorpickerLabel"
			label.Size = UDim2.new(1, -60, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = cpName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local previewBox = Instance.new("TextButton")
			previewBox.Name = "PreviewBox"
			previewBox.Size = UDim2.new(0, 24, 0, 24)
			previewBox.AnchorPoint = Vector2.new(1, 0.5)
			previewBox.Position = UDim2.new(1, -7, 0.5, 0) 
			previewBox.BackgroundColor3 = defaultColor
			previewBox.BorderSizePixel = 0
			previewBox.Text = ""
			previewBox.Parent = container
			
			local previewBoxCorner = Instance.new("UICorner")
			previewBoxCorner.CornerRadius = GLOBAL_CORNER
			previewBoxCorner.Parent = previewBox
			CS:AddTag(previewBoxCorner, "ElementCorner")

			local stroke = Instance.new("UIStroke")
			stroke.Name = "PreviewStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 2
			stroke.Parent = previewBox
			ApplyTheme(stroke, "Outlines", "Color")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.TextSize = 12
					previewBox.Size = UDim2.new(0, 18, 0, 18)
					previewBox.Position = UDim2.new(1, -5, 0.5, 0)
				else
					container.Size = UDim2.new(1, 0, 0, 38)
					label.TextSize = 13
					previewBox.Size = UDim2.new(0, 24, 0, 24)
					previewBox.Position = UDim2.new(1, -7, 0.5, 0)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local innerAPI = AttachColorPicker(previewBox, defaultColor, function(c)
				currentColor = c
				callback(c)
			end)
			RegisterElement(cpName, container)
			
			local api = {}
			function api:SetColor(c)
				currentColor = c
				innerAPI:SetColor(c)
			end
			function api:Save()
				return { Color = {currentColor.R, currentColor.G, currentColor.B} }
			end
			function api:Load(val)
				if val.Color then
					api:SetColor(Color3.new(unpack(val.Color)))
				end
			end
			RegisterElementAPI("Colorpicker", cpName, api)
			return api
		end
		
		function BlockObj:CreateLabel(text)
			local lbl = Instance.new("TextLabel")
			lbl.Name = "BlockLabel"
			lbl.Size = UDim2.new(1, 0, 0, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.BackgroundTransparency = 1
			lbl.BorderSizePixel = 0
			lbl.TextSize = 13
			lbl.Text = text
			lbl.TextWrapped = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.LayoutOrder = 2
			lbl.Font = Enum.Font.Gotham
			lbl.Parent = blockContainer
			ApplyTheme(lbl, "TextMuted", "TextColor3")
			ApplyTheme(lbl, "SubtextFont", "Font")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					lbl.TextSize = 12
				else
					lbl.TextSize = 13
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)
			RegisterElement(text, lbl)
			
			local api = {}
			function api:SetText(txt)
				lbl.Text = txt
			end
			return api
		end

		function BlockObj:CreateSection(text)
			local hasText = type(text) == "string" and text ~= ""

			local container = Instance.new("Frame")
			container.Name = "SectionContainer"
			container.Size = UDim2.new(1, 0, 0, 24)
			container.BackgroundTransparency = 1
			container.BorderSizePixel = 0
			container.ClipsDescendants = true
			container.LayoutOrder = 2
			container.Parent = blockContainer

			local function updateStyle(style)
				if style == 3 or style == 4 then
					container.Size = UDim2.new(1, 0, 0, 16)
				else
					container.Size = UDim2.new(1, 0, 0, 24)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local label, leftLine, rightLine
			local function updateLines()
				if not label or not container then return end
				local totalW = container.AbsoluteSize.X
				if totalW <= 0 then return end

				local textWidth = label.AbsoluteSize.X
				local gap = 8
				local sidePad = 4
				local lineW = math.max(0, (totalW / 2) - (textWidth / 2) - gap - sidePad)

				if leftLine then
					leftLine.Size = UDim2.new(0, lineW, 0, 1)
					leftLine.Position = UDim2.new(0.5, -((textWidth / 2) + gap), 0.5, 0)
				end
				if rightLine then
					rightLine.Size = UDim2.new(0, lineW, 0, 1)
					rightLine.Position = UDim2.new(0.5, ((textWidth / 2) + gap), 0.5, 0)
				end
			end

			if not hasText then
				local line = Instance.new("Frame")
				line.Name = "SectionLine"
				line.Size = UDim2.new(1, -8, 0, 1)
				line.Position = UDim2.new(0.5, 0, 0.5, 0)
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.BorderSizePixel = 0
				line.Parent = container
				ApplyTheme(line, "Outlines", "BackgroundColor3")
			else
				label = Instance.new("TextLabel")
				label.Name = "SectionLabel"
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Size = UDim2.new(0, 0, 1, 0)
				label.Position = UDim2.new(0.5, 0, 0.5, 0)
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.BackgroundTransparency = 1
				label.BorderSizePixel = 0
				label.TextSize = 11
				label.Text = text
				label.ZIndex = 2
				label.Parent = container
				
				ApplyTheme(label, "TextMuted", "TextColor3")
				ApplyTheme(label, "SubtextFont", "Font")

				leftLine = Instance.new("Frame")
				leftLine.Name = "LeftLine"
				leftLine.AnchorPoint = Vector2.new(1, 0.5)
				leftLine.BorderSizePixel = 0
				leftLine.Parent = container
				ApplyTheme(leftLine, "Outlines", "BackgroundColor3")

				rightLine = Instance.new("Frame")
				rightLine.Name = "RightLine"
				rightLine.AnchorPoint = Vector2.new(0, 0.5)
				rightLine.BorderSizePixel = 0
				rightLine.Parent = container
				ApplyTheme(rightLine, "Outlines", "BackgroundColor3")
				
				table.insert(Window._connections, label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLines))
				table.insert(Window._connections, container:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLines))
				task.spawn(function()
					task.wait()
					updateLines()
				end)
			end
			RegisterElement(text or "Section", container)
			
			local api = {}
			function api:SetText(txt)
				if label then 
					label.Text = txt
					task.spawn(updateLines)
				end
			end
			return api
		end

		function BlockObj:CreateKeybind(cfg)
			local el = CreateElementBase(38)
			
			local bind = cfg.Default
			
			local lbl = Instance.new("TextLabel")
			lbl.Name = "KeybindLabel"
			lbl.Size = UDim2.new(1, -120, 1, 0)
			lbl.Position = UDim2.new(0, 15, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.TextSize = 13
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = cfg.Name
			lbl.Font = Enum.Font.Gotham
			lbl.Parent = el
			ApplyTheme(lbl, "Text", "TextColor3")
			ApplyTheme(lbl, "TextFont", "Font")
			
			local box = Instance.new("Frame")
			box.Name = "KeybindBox"
			box.Size = UDim2.new(0, 30, 0, 24)
			box.AutomaticSize = Enum.AutomaticSize.X
			box.AnchorPoint = Vector2.new(1, 0.5)
			box.Position = UDim2.new(1, -7, 0.5, 0)
			box.Parent = el
			ApplyTheme(box, "Input", "BackgroundColor3")
			ApplyTheme(box, "InputTrans", "BackgroundTransparency")
			
			local boxCorner = Instance.new("UICorner")
			boxCorner.CornerRadius = GLOBAL_CORNER
			boxCorner.Parent = box
			CS:AddTag(boxCorner, "ElementCorner")
			
			attachStroke(box, "ElementStroke")
			
			local bBtn = Instance.new("TextButton")
			bBtn.Name = "KeybindButton"
			bBtn.Size = UDim2.new(1,0,1,0)
			bBtn.BackgroundTransparency = 1
			bBtn.TextSize = 12
			bBtn.Text = getShortKey(bind)
			bBtn.Font = Enum.Font.Gotham
			bBtn.Parent = box
			ApplyTheme(bBtn, "TextMuted", "TextColor3")
			ApplyTheme(bBtn, "TextFont", "Font")
			
			local mobileToggle, getMobileBtn
			if isMobile then
				mobileToggle, _, getMobileBtn = createMobileToggle(el, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), function()
							if cfg.Callback then pcall(function() cfg.Callback(bind) end) end
						end))
					else
						removeBtn()
					end
				end)
			end

			local p = Instance.new("UIPadding")
			p.Name = "KeybindPadding"
			p.PaddingLeft = UDim.new(0,6)
			p.PaddingRight = UDim.new(0,6)
			p.Parent = bBtn

			local function updateStyle(style)
				local edge = (style == 3 or style == 4) and 5 or 7
				if style == 3 or style == 4 then
					el.Size = UDim2.new(1, 0, 0, 30)
					lbl.TextSize = 12
					box.Size = UDim2.new(0, 30, 0, 20)
					bBtn.TextSize = 11
				else
					el.Size = UDim2.new(1, 0, 0, 38)
					lbl.TextSize = 13
					box.Size = UDim2.new(0, 30, 0, 24)
					bBtn.TextSize = 12
				end

				box.AnchorPoint = Vector2.new(1, 0.5)
				box.Position = UDim2.new(1, -edge, 0.5, 0)
				lbl.Position = UDim2.new(0, mobileToggle and 38 or 15, 0, 0)
				lbl.Size = UDim2.new(1, -(120 + (mobileToggle and 30 or 0)), 1, 0)
				if mobileToggle then
					mobileToggle.AnchorPoint = Vector2.new(0, 0.5)
					mobileToggle.Position = UDim2.new(0, 12, 0.5, 0)
					mobileToggle.Size = UDim2.new(0, 20, 0, 20)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)
	
			local isBinding = false
			
			table.insert(Window._connections, bBtn.MouseButton1Click:Connect(function() 
				isBinding = true
				if isSettings and cfg.Name == "Open GUI Keybind" then Window._capturingOpenKeybind = true end
				bBtn.Text = "..."
				ApplyTheme(bBtn, "Accent", "TextColor3") 
			end))
			
			table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed and not isBinding then return end
				
				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						bind = input.KeyCode
						bBtn.Text = getShortKey(bind)
						ApplyTheme(bBtn, "TextMuted", "TextColor3")
						isBinding = false
						if isSettings and cfg.Name == "Open GUI Keybind" then Window._capturingOpenKeybind = false end
						
						if cfg.Callback then 
							pcall(function() cfg.Callback(bind) end)
						end
						if Window.UpdateKeybinds then Window.UpdateKeybinds() end
					end
				else
					if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
						if cfg.Callback then 
							pcall(function() cfg.Callback(bind) end)
						end
					end
				end
			end))
			RegisterElement(cfg.Name, el)
			
			local api = {}
			function api:SetKeybind(k)
				bind = k
				bBtn.Text = getShortKey(k)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(bind) end
			end
			function api:Save()
				return { Bind = bind and bind.Name or nil }
			end
			function api:Load(val)
				if val.Bind then
					local resolved = resolveKeycode(val.Bind)
					if resolved then
						api:SetKeybind(resolved)
						if isSettings and cfg.Name == "Open GUI Keybind" then
							Window:SetOpenKeybind(resolved)
						end
					end
				end
			end
			RegisterElementAPI("Keybind", cfg.Name, api)
			return api
		end
		
		return BlockObj
	end
	
	function Window:CreateTab(tabConfig, legacyIcon, legacyIsSettings)
		local name, icon, isSettings
		if type(tabConfig) == "table" then
			name = tabConfig.Name or "Tab"
			icon = tabConfig.Icon
			isSettings = tabConfig.IsSettings or false
		else
			name = tostring(tabConfig or "Tab")
			icon = legacyIcon
			isSettings = legacyIsSettings or false
		end
	
		local tabData = {Name = name, IsSettings = isSettings}
		local iconAsset = parseAsset(icon)
		local hasIcon = (iconAsset and iconAsset ~= "")
		local isCollapsed = (currentSidebarWidth < 115)
		
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "TabButton_" .. name
		tabButton.Size = isCollapsed and UDim2.new(0, 36, 0, 36) or UDim2.new(1, -4, 0, 38)
		tabButton.AutoButtonColor = false
		tabButton.Text = ""
		tabButton.BackgroundTransparency = 1
		tabButton.BorderSizePixel = 0
		tabButton.LayoutOrder = isSettings and 9999 or (#Window.Tabs + 1)
		tabButton.Parent = tabList
		
		local tabStroke = Instance.new("UIStroke")
		tabStroke.Name = "TabStroke"
		tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tabStroke.Thickness = 1
		tabStroke.Transparency = 1
		tabStroke.Parent = tabButton
		ApplyTheme(tabStroke, "Outlines", "Color")
	
		local tabButtonCorner = Instance.new("UICorner")
		tabButtonCorner.CornerRadius = GLOBAL_CORNER
		tabButtonCorner.Parent = tabButton
		CS:AddTag(tabButtonCorner, "ElementCorner")
	
		local tabBtnPadding = Instance.new("UIPadding")
		tabBtnPadding.Name = "TabBtnPadding"
		tabBtnPadding.PaddingLeft = isCollapsed and UDim.new(0, 0) or UDim.new(0, 15) 
		tabBtnPadding.PaddingRight = isCollapsed and UDim.new(0, 0) or UDim.new(0, 15)
		tabBtnPadding.Parent = tabButton
	
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.Name = "TabLayout"
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		tabLayout.HorizontalAlignment = isCollapsed and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Padding = UDim.new(0, 10)
		tabLayout.Parent = tabButton
	
		local tabIconLabel
		if hasIcon then
			tabIconLabel = Instance.new("ImageLabel")
			tabIconLabel.Name = "TabIcon"
			tabIconLabel.Size = isCollapsed and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 26, 0, 26)
			tabIconLabel.BackgroundTransparency = 1
			tabIconLabel.Image = iconAsset
			tabIconLabel.LayoutOrder = 1
			tabIconLabel.Parent = tabButton
			ApplyTheme(tabIconLabel, "TextMuted", "ImageColor3")
		end
	
		local tabLetterLabel
		if not hasIcon then
			tabLetterLabel = Instance.new("TextLabel")
			tabLetterLabel.Name = "TabLetter"
			tabLetterLabel.Size = isCollapsed and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 26, 0, 26)
			tabLetterLabel.BackgroundTransparency = 1
			tabLetterLabel.TextSize = isCollapsed and 24 or 18
			tabLetterLabel.TextXAlignment = Enum.TextXAlignment.Center
			tabLetterLabel.TextYAlignment = Enum.TextYAlignment.Center
			tabLetterLabel.Text = getFirstChar(name)
			tabLetterLabel.LayoutOrder = 1
			tabLetterLabel.Visible = isCollapsed
			tabLetterLabel.Parent = tabButton
			ApplyTheme(tabLetterLabel, "TextMuted", "TextColor3")
			ApplyTheme(tabLetterLabel, "TextFont", "Font")
		end
	
		local tabBtnTitle = Instance.new("TextLabel")
		tabBtnTitle.Name = "TabTitle"
		tabBtnTitle.AutomaticSize = Enum.AutomaticSize.X
		tabBtnTitle.Size = UDim2.new(0, 0, 1, 0)
		tabBtnTitle.BackgroundTransparency = 1
		tabBtnTitle.TextSize = 13
		tabBtnTitle.TextXAlignment = Enum.TextXAlignment.Left
		tabBtnTitle.Text = name
		tabBtnTitle.TextTruncate = Enum.TextTruncate.AtEnd
		tabBtnTitle.Visible = not isCollapsed
		tabBtnTitle.LayoutOrder = 2
		tabBtnTitle.Parent = tabButton
		ApplyTheme(tabBtnTitle, "TextMuted", "TextColor3")
		ApplyTheme(tabBtnTitle, "TextFont", "Font")
	
		local page = Instance.new("CanvasGroup")
		page.Name = "Page_" .. name
		page.Size = UDim2.new(1, 0, 1, 0)
		page.Position = UDim2.new(0, 0, 0, 0)
		page.BackgroundTransparency = 1
		page.GroupTransparency = 1
		page.Visible = false
		page.Parent = pagesFolder
	
		local pageContent = Instance.new("ScrollingFrame")
		pageContent.Name = "PageContent"
		pageContent.Size = UDim2.new(1, 0, 1, 0)
		pageContent.Position = UDim2.new(0, 0, 0, 0)
		pageContent.BackgroundTransparency = 1
		pageContent.ScrollBarThickness = 0
		pageContent.CanvasSize = UDim2.new(0, 0, 0, 0)
		pageContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
		pageContent.Parent = page
		
		local pagePadding = Instance.new("UIPadding")
		pagePadding.Name = "PagePadding"
		pagePadding.PaddingTop = UDim.new(0, 14)
		pagePadding.PaddingBottom = UDim.new(0, 14)
		pagePadding.PaddingLeft = UDim.new(0, 14)
		pagePadding.PaddingRight = UDim.new(0, 14)
		pagePadding.Parent = pageContent
	
		local columnsLayout = Instance.new("UIListLayout")
		columnsLayout.Name = "ColumnsLayout"
		columnsLayout.FillDirection = Enum.FillDirection.Horizontal
		columnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		columnsLayout.Padding = UDim.new(0, 14)
		columnsLayout.Parent = pageContent
	
		local leftColumn = Instance.new("Frame")
		leftColumn.Name = "LeftColumn"
		leftColumn.Size = UDim2.new(0.5, -7, 0, 0)
		leftColumn.AutomaticSize = Enum.AutomaticSize.Y
		leftColumn.BackgroundTransparency = 1
		leftColumn.Parent = pageContent
		
		local leftColLayout = Instance.new("UIListLayout")
		leftColLayout.Name = "LeftColLayout"
		leftColLayout.FillDirection = Enum.FillDirection.Vertical
		leftColLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftColLayout.Padding = UDim.new(0, 14)
		leftColLayout.Parent = leftColumn
	
		local rightColumn = Instance.new("Frame")
		rightColumn.Name = "RightColumn"
		rightColumn.Size = UDim2.new(0.5, -7, 0, 0)
		rightColumn.AutomaticSize = Enum.AutomaticSize.Y
		rightColumn.BackgroundTransparency = 1
		rightColumn.Parent = pageContent
		
		local rightColLayout = Instance.new("UIListLayout")
		rightColLayout.Name = "RightColLayout"
		rightColLayout.FillDirection = Enum.FillDirection.Vertical
		rightColLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rightColLayout.Padding = UDim.new(0, 14)
		rightColLayout.Parent = rightColumn
	
		local function updateTabStyle(style)
			if style == 3 or style == 4 then
				leftColumn.Size = UDim2.new(0.5, -4, 0, 0)
				rightColumn.Size = UDim2.new(0.5, -4, 0, 0)
				pagePadding.PaddingTop = UDim.new(0, 8)
				pagePadding.PaddingBottom = UDim.new(0, 8)
				pagePadding.PaddingLeft = UDim.new(0, 8)
				pagePadding.PaddingRight = UDim.new(0, 8)
				columnsLayout.Padding = UDim.new(0, 8)
				leftColLayout.Padding = UDim.new(0, 8)
				rightColLayout.Padding = UDim.new(0, 8)
			else
				leftColumn.Size = UDim2.new(0.5, -7, 0, 0)
				rightColumn.Size = UDim2.new(0.5, -7, 0, 0)
				pagePadding.PaddingTop = UDim.new(0, 14)
				pagePadding.PaddingBottom = UDim.new(0, 14)
				pagePadding.PaddingLeft = UDim.new(0, 14)
				pagePadding.PaddingRight = UDim.new(0, 14)
				columnsLayout.Padding = UDim.new(0, 14)
				leftColLayout.Padding = UDim.new(0, 14)
				rightColLayout.Padding = UDim.new(0, 14)
			end
		end
		table.insert(Window._styleCallbacks, updateTabStyle)
		updateTabStyle(THEME.ElementStyle)
	
		tabData.Button = tabButton
		tabData.Stroke = tabStroke
		tabData.Label = tabBtnTitle
		tabData.Icon = tabIconLabel
		tabData.LetterLabel = tabLetterLabel
		tabData.Page = page
		tabData.Padding = tabBtnPadding
		tabData.Layout = tabLayout
		
		function tabData:SetTitle(newTitle)
			tabBtnTitle.Text = newTitle
			if tabLetterLabel then
				tabLetterLabel.Text = getFirstChar(newTitle)
			end
		end
	
		local function activateTab()
			if Window.CurrentTab == tabData then return end
	
			if searchInput and searchInput.Text ~= "" then
				searchInput.Text = "" 
			end
	
			local prevTab = Window.CurrentTab
			Window.CurrentTab = tabData
			local isTopOrBottom = (SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom")
			local collapsedNow = (currentSidebarWidth < 115)
	
			if prevTab then
				TS:Create(prevTab.Stroke, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Transparency = 1}):Play()
				ApplyTheme(prevTab.Stroke, "Outlines", "Color")
				
				ApplyTheme(prevTab.Label, "TextMuted", "TextColor3")
				if prevTab.Icon then ApplyTheme(prevTab.Icon, "TextMuted", "ImageColor3") end
				if prevTab.LetterLabel then ApplyTheme(prevTab.LetterLabel, "TextMuted", "TextColor3") end
				
				if not isTopOrBottom and not collapsedNow then 
					TS:Create(prevTab.Padding, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 15)}):Play() 
				else
					TS:Create(prevTab.Padding, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 0)}):Play()
				end
	
				local oldPage = prevTab.Page
				local fadeOut = TS:Create(oldPage, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					GroupTransparency = 1,
					Position = UDim2.new(0, 0, 0, -8)
				})
				fadeOut:Play()
				fadeOut.Completed:Once(function()
					if Window.CurrentTab ~= prevTab then
						oldPage.Visible = false
					end
				end)
			end
	
			TS:Create(tabStroke, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			ApplyTheme(tabStroke, "Accent", "Color")
			
			ApplyTheme(tabBtnTitle, "Text", "TextColor3")
			if tabIconLabel then ApplyTheme(tabIconLabel, "Accent", "ImageColor3") end
			if tabLetterLabel then ApplyTheme(tabLetterLabel, "Accent", "TextColor3") end
			
			if not isTopOrBottom and not collapsedNow then 
				TS:Create(tabBtnPadding, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 22)}):Play() 
			else
				TS:Create(tabBtnPadding, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 0)}):Play() 
			end
	
			page.Position = UDim2.new(0, 0, 0, 8)
			page.GroupTransparency = 1
			page.Visible = true
			TS:Create(page, TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				GroupTransparency = 0,
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()
		end
		
		table.insert(Window._connections, tabButton.MouseButton1Click:Connect(activateTab))
	
		function tabData:CreateBlock(blockConfig, overrideParent)
			local bName = blockConfig.Name or "Block"
			local bSide = blockConfig.Side or "Left"
			local bIcon = parseAsset(blockConfig.Icon)
			local variants = blockConfig.Variants

			local originalParent = overrideParent or ((bSide == "Right") and rightColumn or leftColumn)

			local blockAnchor = Instance.new("Frame")
			blockAnchor.Name = bName .. "_Anchor"
			blockAnchor.Size = UDim2.new(1, 0, 0, 0)
			blockAnchor.AutomaticSize = Enum.AutomaticSize.Y
			blockAnchor.BackgroundTransparency = 1
			blockAnchor.Parent = originalParent

			local dummyCard = Instance.new("Frame")
			dummyCard.Name = "DummyCard"
			dummyCard.Size = UDim2.new(1, 0, 0, 38)
			dummyCard.BackgroundTransparency = 1
			dummyCard.Visible = false
			dummyCard.Parent = blockAnchor
			ApplyTheme(dummyCard, "Card", "BackgroundColor3")
			ApplyTheme(dummyCard, "CardTrans", "BackgroundTransparency")

			local dummyCorner = Instance.new("UICorner")
			dummyCorner.CornerRadius = GLOBAL_CORNER
			dummyCorner.Parent = dummyCard
			CS:AddTag(dummyCorner, "ElementCorner")

			local dummyStroke = Instance.new("UIStroke")
			dummyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			dummyStroke.Thickness = 1
			dummyStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			dummyStroke.Parent = dummyCard
			ApplyTheme(dummyStroke, "Outlines", "Color")
			CS:AddTag(dummyStroke, "BlockStroke")

			local dummyTitle = Instance.new("TextLabel")
			dummyTitle.Size = UDim2.new(1, -40, 1, 0)
			dummyTitle.Position = UDim2.new(0, 16, 0, 0)
			dummyTitle.BackgroundTransparency = 1
			dummyTitle.Text = bName
			dummyTitle.TextSize = 13
			dummyTitle.TextXAlignment = Enum.TextXAlignment.Left
			dummyTitle.Parent = dummyCard
			ApplyTheme(dummyTitle, "TextMuted", "TextColor3")
			ApplyTheme(dummyTitle, "TextFont", "Font")

			local dummyReturnBtn = Instance.new("ImageButton")
			dummyReturnBtn.Size = UDim2.new(0, 24, 0, 24) 
			dummyReturnBtn.AnchorPoint = Vector2.new(1, 0.5)
			dummyReturnBtn.Position = UDim2.new(1, -12, 0.5, 0)
			dummyReturnBtn.BackgroundTransparency = 1
			dummyReturnBtn.Image = "rbxassetid://10709790948"
			dummyReturnBtn.Rotation = 90 
			dummyReturnBtn.Parent = dummyCard
			ApplyTheme(dummyReturnBtn, "TextMuted", "ImageColor3")

			local blockContainer = Instance.new("Frame")
			blockContainer.Name = bName .. "_Block"
			blockContainer.Size = UDim2.new(1, 0, 0, 0)
			blockContainer.AutomaticSize = Enum.AutomaticSize.Y
			blockContainer.ZIndex = 100
			blockContainer.Active = true
			blockContainer.Parent = blockAnchor
			ApplyTheme(blockContainer, "Card", "BackgroundColor3")
			ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
			
			local blockContainerCorner = Instance.new("UICorner")
			blockContainerCorner.CornerRadius = GLOBAL_CORNER
			blockContainerCorner.Parent = blockContainer
			CS:AddTag(blockContainerCorner, "ElementCorner")

			local blockStroke = Instance.new("UIStroke")
			blockStroke.Name = "BlockStroke"
			blockStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			blockStroke.Thickness = 1
			blockStroke.Parent = blockContainer
			ApplyTheme(blockStroke, "Outlines", "Color")
			CS:AddTag(blockStroke, "BlockStroke")

			local blockPadding = Instance.new("UIPadding")
			blockPadding.Name = "BlockPadding"
			blockPadding.PaddingTop = UDim.new(0, 12)
			blockPadding.PaddingBottom = UDim.new(0, 12)
			blockPadding.PaddingLeft = UDim.new(0, 12)
			blockPadding.PaddingRight = UDim.new(0, 12)
			blockPadding.Parent = blockContainer

			local blockLayout = Instance.new("UIListLayout")
			blockLayout.Name = "BlockLayout"
			blockLayout.FillDirection = Enum.FillDirection.Vertical
			blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
			blockLayout.Padding = UDim.new(0, 6)
			blockLayout.Parent = blockContainer

			local detachBtn = Instance.new("ImageButton")
			detachBtn.Size = UDim2.new(0, 24, 0, 24)
			detachBtn.AnchorPoint = Vector2.new(1, 0.5)
			detachBtn.Position = UDim2.new(1, 0, 0.5, 0)
			detachBtn.BackgroundTransparency = 1
			detachBtn.Image = "rbxassetid://10709790948"
			detachBtn.Rotation = -90 
			ApplyTheme(detachBtn, "Text", "ImageColor3")

			local isDetached = false
			local dragTriggers = {}
			local activeDragConns = {}

			local function ToggleDetach(customPos)
				isDetached = not isDetached
				if isDetached then
					local absPos = blockContainer.AbsolutePosition
					local absSize = blockContainer.AbsoluteSize
					
					blockContainer.Size = UDim2.new(0, absSize.X, 0, 0)
					if customPos and type(customPos) == "table" then
						blockContainer.Position = UDim2.new(customPos.ScaleX or 0, customPos.OffsetX or 0, customPos.ScaleY or 0, customPos.OffsetY or 0)
					else
						blockContainer.Position = UDim2.new(0, absPos.X, 0, absPos.Y + 15)
					end
					blockContainer.Parent = screenGui

					ApplyTheme(blockContainer, "Background", "BackgroundColor3")
					ApplyTheme(blockContainer, "HUDTransparency", "BackgroundTransparency")
					
					dummyCard.Visible = true
					ApplyTheme(detachBtn, "TextMuted", "ImageColor3")
					detachBtn.Rotation = 90
					
					local dragging = false
					local dragStart, startPos
					
					for _, trigger in ipairs(dragTriggers) do
						local conn1 = trigger.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								dragging = true
								dragStart = input.Position
								startPos = blockContainer.Position
							end
						end)
						table.insert(activeDragConns, conn1)
					end
					
					local conn2 = UIS.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							local delta = input.Position - dragStart
							blockContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
						end
					end)
					table.insert(activeDragConns, conn2)
					
					local conn3 = UIS.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = false
						end
					end)
					table.insert(activeDragConns, conn3)
				else
					for _, c in ipairs(activeDragConns) do c:Disconnect() end
					activeDragConns = {}
					
					blockContainer.Size = UDim2.new(1, 0, 0, 0)
					blockContainer.Position = UDim2.new(0, 0, 0, 0)
					blockContainer.Parent = blockAnchor
					
					ApplyTheme(blockContainer, "Card", "BackgroundColor3")
					ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
					
					dummyCard.Visible = false
					ApplyTheme(detachBtn, "Text", "ImageColor3")
					detachBtn.Rotation = -90
				end
			end

			detachBtn.MouseButton1Click:Connect(function() ToggleDetach() end)
			dummyReturnBtn.MouseButton1Click:Connect(function() ToggleDetach() end)

			local blockUniqueKey = name .. "~" .. bName
			Window._blockRegistry[blockUniqueKey] = {
				IsDetached = function() return isDetached end,
				GetPosition = function()
					return {
						ScaleX = blockContainer.Position.X.Scale,
						OffsetX = blockContainer.Position.X.Offset,
						ScaleY = blockContainer.Position.Y.Scale,
						OffsetY = blockContainer.Position.Y.Offset
					}
				end,
				SetDetached = function(targetState, posData)
					if targetState and not isDetached then
						ToggleDetach(posData)
					elseif not targetState and isDetached then
						ToggleDetach()
					elseif targetState and isDetached and posData then
						blockContainer.Position = UDim2.new(posData.ScaleX or 0, posData.OffsetX or 0, posData.ScaleY or 0, posData.OffsetY or 0)
					end
				end
			}

			if variants and type(variants) == "table" and #variants > 1 then
				local headerWrapper = Instance.new("Frame")
				headerWrapper.Name = "VariantsHeaderWrapper"
				headerWrapper.Size = UDim2.new(1, 0, 0, 26)
				headerWrapper.BackgroundTransparency = 1
				headerWrapper.LayoutOrder = 0
				headerWrapper.Parent = blockContainer

				table.insert(dragTriggers, headerWrapper)
				detachBtn.Parent = headerWrapper

				local tabsContainer = Instance.new("Frame")
				tabsContainer.Name = "TabsContainer"
				tabsContainer.Size = UDim2.new(1, -32, 1, 0) 
				tabsContainer.BackgroundTransparency = 1
				tabsContainer.Parent = headerWrapper

				local gap = 4
				local totalGaps = gap * (#variants - 1)

				local headerLayout = Instance.new("UIListLayout")
				headerLayout.FillDirection = Enum.FillDirection.Horizontal
				headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
				headerLayout.Padding = UDim.new(0, gap)
				headerLayout.Parent = tabsContainer

				local blockDivider = Instance.new("Frame")
				blockDivider.Name = "BlockDivider"
				blockDivider.Size = UDim2.new(1, 0, 0, 1)
				blockDivider.BorderSizePixel = 0
				blockDivider.LayoutOrder = 1
				blockDivider.Parent = blockContainer
				ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

				local activeIndex = 1
				local contentContainers = {}
				local apis = {}
				local tabs = {}

				local function updateVariantTabTexts()
					for _, tData in ipairs(tabs) do
						local padX = 14
						local maxW = tData.Btn.AbsoluteSize.X - (tData.HasIcon and 24 or 8) - padX
						local font = Enum.Font[THEME.TextFont] or Enum.Font.Gotham
						tData.Label.Text = truncateTwoDots(tData.RawName, font, tData.Label.TextSize, math.max(0, maxW))
					end
				end

				for i, vData in ipairs(variants) do
					local vName = vData.Name or ("Tab " .. i)
					local vIcon = parseAsset(vData.Icon)

					local tabBtn = Instance.new("TextButton")
					tabBtn.Name = "Tab_" .. vName
					tabBtn.Size = UDim2.new(1 / #variants, -(totalGaps / #variants), 1, 0)
					tabBtn.BackgroundTransparency = 1
					tabBtn.AutoButtonColor = false
					tabBtn.Text = ""
					tabBtn.LayoutOrder = i
					tabBtn.Parent = tabsContainer
					
					table.insert(dragTriggers, tabBtn)

					local tabBtnCorner = Instance.new("UICorner")
					tabBtnCorner.CornerRadius = GLOBAL_CORNER
					tabBtnCorner.Parent = tabBtn
					CS:AddTag(tabBtnCorner, "ElementCorner")

					local tabStroke = Instance.new("UIStroke")
					tabStroke.Name = "TabStroke"
					tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					tabStroke.Thickness = 1
					tabStroke.Transparency = (i == 1) and 0 or 1
					tabStroke.Parent = tabBtn
					ApplyTheme(tabStroke, "Outlines", "Color")

					local tabPad = Instance.new("UIPadding")
					tabPad.Name = "TabPadding"
					tabPad.PaddingLeft = UDim.new(0, 6)
					tabPad.PaddingRight = UDim.new(0, 6)
					tabPad.Parent = tabBtn

					local btnLayout = Instance.new("UIListLayout")
					btnLayout.FillDirection = Enum.FillDirection.Horizontal
					btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
					btnLayout.Padding = UDim.new(0, 6)
					btnLayout.Parent = tabBtn

					local tIcon
					if vIcon and vIcon ~= "" then
						tIcon = Instance.new("ImageLabel")
						tIcon.Size = UDim2.new(0, 16, 0, 16)
						tIcon.BackgroundTransparency = 1
						tIcon.Image = vIcon
						tIcon.Parent = tabBtn
						ApplyTheme(tIcon, i == 1 and "Text" or "TextMuted", "ImageColor3")
					end

					local tLabel = Instance.new("TextLabel")
					tLabel.AutomaticSize = Enum.AutomaticSize.X
					tLabel.Size = UDim2.new(0, 0, 1, 0)
					tLabel.BackgroundTransparency = 1
					tLabel.TextSize = 12
					tLabel.TextTruncate = Enum.TextTruncate.AtEnd
					tLabel.TextXAlignment = Enum.TextXAlignment.Center
					tLabel.Text = vName
					tLabel.Parent = tabBtn
					ApplyTheme(tLabel, i == 1 and "Text" or "TextMuted", "TextColor3")
					ApplyTheme(tLabel, i == 1 and "TextFont" or "SubtextFont", "Font")
					
					tabs[i] = {
						Btn = tabBtn,
						Stroke = tabStroke,
						Label = tLabel,
						RawName = vName,
						HasIcon = (vIcon and vIcon ~= "")
					}

					local contentFrame = Instance.new("CanvasGroup")
					contentFrame.Name = "Content_" .. vName
					contentFrame.Size = UDim2.new(1, 0, 0, 0)
					contentFrame.AutomaticSize = Enum.AutomaticSize.Y
					contentFrame.BackgroundTransparency = 1
					contentFrame.GroupTransparency = (i == 1) and 0 or 1
					contentFrame.Visible = (i == 1)
					contentFrame.LayoutOrder = 2
					contentFrame.Parent = blockContainer
					contentContainers[i] = contentFrame

					local cLayout = Instance.new("UIListLayout")
					cLayout.FillDirection = Enum.FillDirection.Vertical
					cLayout.SortOrder = Enum.SortOrder.LayoutOrder
					cLayout.Padding = UDim.new(0, 6)
					cLayout.Parent = contentFrame
					
					local cPadding = Instance.new("UIPadding")
					cPadding.PaddingTop = UDim.new(0, 6)
					cPadding.Parent = contentFrame

					tabBtn.MouseButton1Click:Connect(function()
						if activeIndex == i then return end
						
						local oldIdx = activeIndex
						local oldTab = tabs[oldIdx]
						local oldContent = contentContainers[oldIdx]
						
						if oldTab and oldTab.Stroke then
							TS:Create(oldTab.Stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Transparency = 1}):Play()
							for _, child in ipairs(oldTab.Btn:GetChildren()) do
								if child:IsA("ImageLabel") then ApplyTheme(child, "TextMuted", "ImageColor3") end
								if child:IsA("TextLabel") then 
									ApplyTheme(child, "TextMuted", "TextColor3") 
									ApplyTheme(child, "SubtextFont", "Font")
								end
							end
						end
						
						activeIndex = i
						local newTab = tabs[i]
						local newContent = contentContainers[i]
						
						if newTab and newTab.Stroke then
							TS:Create(newTab.Stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Transparency = 0}):Play()
							for _, child in ipairs(newTab.Btn:GetChildren()) do
								if child:IsA("ImageLabel") then ApplyTheme(child, "Text", "ImageColor3") end
								if child:IsA("TextLabel") then 
									ApplyTheme(child, "Text", "TextColor3") 
									ApplyTheme(child, "TextFont", "Font")
								end
							end
						end

						local fadeOut = TS:Create(oldContent, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
							GroupTransparency = 1,
							Position = UDim2.new(0, 0, 0, -4)
						})
						fadeOut:Play()
						fadeOut.Completed:Once(function()
							if activeIndex ~= oldIdx then
								oldContent.Visible = false
							end
						end)

						newContent.Position = UDim2.new(0, 0, 0, 4)
						newContent.GroupTransparency = 1
						newContent.Visible = true
						TS:Create(newContent, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
							GroupTransparency = 0,
							Position = UDim2.new(0, 0, 0, 0)
						}):Play()
					end)

					local bObj = BuildElementAPI(contentFrame, vName, vIcon, bSide, name, tabData.IsSettings)
					
					function bObj:SetTitle(newTitle)
						tabs[i].RawName = newTitle
						updateVariantTabTexts()
					end

					apis[i] = bObj
				end
				
				table.insert(Window._connections, tabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVariantTabTexts))

				task.spawn(function()
					task.wait()
					updateVariantTabTexts()
				end)

				local function updateBlockStyle(style)
					updateVariantTabTexts()

					if style == 3 or style == 4 then
						blockPadding.PaddingTop = UDim.new(0, 8)
						blockPadding.PaddingBottom = UDim.new(0, 8)
						blockPadding.PaddingLeft = UDim.new(0, 8)
						blockPadding.PaddingRight = UDim.new(0, 8)
						blockLayout.Padding = UDim.new(0, 4)
						headerWrapper.Size = UDim2.new(1, 0, 0, 22)
						dummyCard.Size = UDim2.new(1, 0, 0, 30)
						dummyTitle.TextSize = 12
						for _, c in pairs(contentContainers) do
							c.UIListLayout.Padding = UDim.new(0, 4)
							c.UIPadding.PaddingTop = UDim.new(0, 4)
						end
					else
						blockPadding.PaddingTop = UDim.new(0, 12)
						blockPadding.PaddingBottom = UDim.new(0, 12)
						blockPadding.PaddingLeft = UDim.new(0, 12)
						blockPadding.PaddingRight = UDim.new(0, 12)
						blockLayout.Padding = UDim.new(0, 6)
						headerWrapper.Size = UDim2.new(1, 0, 0, 26)
						dummyCard.Size = UDim2.new(1, 0, 0, 38)
						dummyTitle.TextSize = 13
						for _, c in pairs(contentContainers) do
							c.UIListLayout.Padding = UDim.new(0, 6)
							c.UIPadding.PaddingTop = UDim.new(0, 6)
						end
					end
				end
				table.insert(Window._styleCallbacks, updateBlockStyle)
				updateBlockStyle(THEME.ElementStyle)

				return unpack(apis)
			else
				local bName = blockConfig.Name or "Block"
				local bIcon = parseAsset(blockConfig.Icon)

				local header = Instance.new("Frame")
				header.Name = "Header"
				header.Size = UDim2.new(1, 0, 0, 20)
				header.BackgroundTransparency = 1
				header.LayoutOrder = 0
				header.Parent = blockContainer

				table.insert(dragTriggers, header)
				detachBtn.Parent = header

				local titleContainer = Instance.new("Frame")
				titleContainer.Name = "TitleContainer"
				titleContainer.Size = UDim2.new(1, -22, 1, 0)
				titleContainer.BackgroundTransparency = 1
				titleContainer.Parent = header

				local headerLayout = Instance.new("UIListLayout")
				headerLayout.Name = "HeaderLayout"
				headerLayout.FillDirection = Enum.FillDirection.Horizontal
				headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
				headerLayout.Padding = UDim.new(0, 8)
				headerLayout.Parent = titleContainer

				local blockIconLabel
				if bIcon and bIcon ~= "" then
					blockIconLabel = Instance.new("ImageLabel")
					blockIconLabel.Name = "BlockIcon"
					blockIconLabel.Size = UDim2.new(0, 26, 0, 26)
					blockIconLabel.BackgroundTransparency = 1
					blockIconLabel.Image = bIcon
					blockIconLabel.Parent = titleContainer
					ApplyTheme(blockIconLabel, "Text", "ImageColor3")
				end

				local blockTitle = Instance.new("TextLabel")
				blockTitle.Name = "BlockTitle"
				blockTitle.AutomaticSize = Enum.AutomaticSize.X
				blockTitle.Size = UDim2.new(0, 0, 1, 0)
				blockTitle.BackgroundTransparency = 1
				blockTitle.TextSize = 13
				blockTitle.TextTruncate = Enum.TextTruncate.AtEnd
				blockTitle.Text = bName
				blockTitle.Parent = titleContainer
				ApplyTheme(blockTitle, "Text", "TextColor3")
				ApplyTheme(blockTitle, "TextFont", "Font")

				local blockDivider = Instance.new("Frame")
				blockDivider.Name = "BlockDivider"
				blockDivider.Size = UDim2.new(1, 0, 0, 1)
				blockDivider.BorderSizePixel = 0
				blockDivider.LayoutOrder = 1
				blockDivider.Parent = blockContainer
				ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

				local function updateBlockStyle(style)
					if style == 3 or style == 4 then
						blockPadding.PaddingTop = UDim.new(0, 8)
						blockPadding.PaddingBottom = UDim.new(0, 8)
						blockPadding.PaddingLeft = UDim.new(0, 8)
						blockPadding.PaddingRight = UDim.new(0, 8)
						blockLayout.Padding = UDim.new(0, 4)
						header.Size = UDim2.new(1, 0, 0, 22)
						dummyCard.Size = UDim2.new(1, 0, 0, 30)
						dummyTitle.TextSize = 12
						if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 22, 0, 22) end
					else
						blockPadding.PaddingTop = UDim.new(0, 12)
						blockPadding.PaddingBottom = UDim.new(0, 12)
						blockPadding.PaddingLeft = UDim.new(0, 12)
						blockPadding.PaddingRight = UDim.new(0, 12)
						blockLayout.Padding = UDim.new(0, 6)
						header.Size = UDim2.new(1, 0, 0, 26)
						dummyCard.Size = UDim2.new(1, 0, 0, 38)
						dummyTitle.TextSize = 13
						if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 26, 0, 26) end
					end
				end
				table.insert(Window._styleCallbacks, updateBlockStyle)
				updateBlockStyle(THEME.ElementStyle)

				local bObj
				if tabData.IsSettings then
					bObj = BuildElementAPI(blockContainer, bName, bIcon, bSide, name, true)
				else
					bObj = BuildElementAPI(blockContainer, bName, bIcon, bSide, name, false)
				end
				
				function bObj:SetTitle(newTitle)
					blockTitle.Text = newTitle
				end
				
				return bObj
			end
		end
	
		if not isSettings and not Window.CurrentTab then task.spawn(activateTab) end
		table.insert(Window.Tabs, tabData)
		FullUpdateLayout()
	
		return tabData
	end
	
	local watermarkHolder = Instance.new("Frame")
	watermarkHolder.Name = "WatermarkHolder"
	watermarkHolder.AnchorPoint = Vector2.new(0.5, 0)
	watermarkHolder.Position = isMobile and UDim2.new(0.5, 0, 0, 8) or UDim2.new(0.5, 0, 0, 20)
	watermarkHolder.Size = UDim2.new(0, 0, 0, isMobile and 34 or 40)
	watermarkHolder.AutomaticSize = Enum.AutomaticSize.X
	watermarkHolder.BackgroundTransparency = 1
	watermarkHolder.Active = true
	watermarkHolder.ZIndex = 99999
	watermarkHolder.Visible = watermarkEnabled
	watermarkHolder.Parent = screenGui

	local wmShadowFolder = Instance.new("Frame")
	wmShadowFolder.Name = "WatermarkShadows"
	wmShadowFolder.Size = UDim2.new(0, 0, 1, 0)
	wmShadowFolder.Position = UDim2.new(0, 0, 0, 0)
	wmShadowFolder.BackgroundTransparency = 1
	wmShadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
	wmShadowFolder.ZIndex = 0
	wmShadowFolder.Parent = watermarkHolder

	local wmShadowStrokes = {}
	for i = 1, shadowLayers do
		local trans = 0.8 + (i * 0.02)
		local wmShadow = Instance.new("Frame")
		wmShadow.Name = "WMShadowLayer" .. i
		wmShadow.BackgroundTransparency = 1
		wmShadow.AnchorPoint = Vector2.new(0, 0)
		wmShadow.Position = UDim2.new(0, 0, 0, 0)
		wmShadow.Size = UDim2.new(1, 0, 1, 0)
		wmShadow.BorderSizePixel = 0
		wmShadow.ZIndex = 0
		wmShadow.Parent = wmShadowFolder

		local wmShadowCorner = Instance.new("UICorner")
		wmShadowCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		wmShadowCorner.Parent = wmShadow
		CS:AddTag(wmShadowCorner, "HUDCorner")

		local wmShadowStroke = Instance.new("UIStroke")
		wmShadowStroke.Color = Color3.fromRGB(0, 0, 0)
		wmShadowStroke.Transparency = trans
		wmShadowStroke:SetAttribute("TargetTransparency", trans)
		wmShadowStroke.Thickness = i * 2
		wmShadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		wmShadowStroke.Enabled = SIDEBAR_STATE.ShadowsEnabled
		wmShadowStroke.Parent = wmShadow
		table.insert(wmShadowStrokes, wmShadowStroke)
	end

	local function setLayeredShadows(enabled)
		enabled = enabled == true
		SIDEBAR_STATE.ShadowsEnabled = enabled
		shadowFolder.Visible = enabled
		sidebarShadowFolder.Visible = enabled and SIDEBAR_STATE.Detached
		wmShadowFolder.Visible = enabled
		for _, layer in ipairs(shadowFolder:GetChildren()) do
			local stroke = layer:FindFirstChild("ShadowStroke")
			if stroke then
				stroke.Enabled = enabled
				if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
			end
		end
		for _, layer in ipairs(sidebarShadowFolder:GetChildren()) do
			local stroke = layer:FindFirstChild("ShadowStroke")
			if stroke then
				stroke.Enabled = enabled and SIDEBAR_STATE.Detached
				if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
			end
		end
		for _, stroke in ipairs(wmShadowStrokes) do
			stroke.Enabled = enabled
			if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
		end
	end

	local wmBar = Instance.new("Frame")
	wmBar.Name = "WatermarkBar"
	wmBar.Size = UDim2.new(0, 0, 1, 0)
	wmBar.AutomaticSize = Enum.AutomaticSize.X
	wmBar.BorderSizePixel = 0
	wmBar.ZIndex = 2
	wmBar.Parent = watermarkHolder
	ApplyTheme(wmBar, "Background", "BackgroundColor3")
	ApplyTheme(wmBar, "HUDTransparency", "BackgroundTransparency")

	local wmCorner = Instance.new("UICorner")
	wmCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
	wmCorner.Parent = wmBar
	CS:AddTag(wmCorner, "HUDCorner")

	local wmStroke = Instance.new("UIStroke")
	wmStroke.Name = "WatermarkStroke"
	wmStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	wmStroke.Thickness = 1
	wmStroke.Enabled = THEME.MainOutlineEnabled
	wmStroke.Parent = wmBar
	ApplyTheme(wmStroke, "Outlines", "Color")
	CS:AddTag(wmStroke, "WatermarkStrokeBind")

	local wmPadding = Instance.new("UIPadding")
	wmPadding.PaddingLeft = UDim.new(0, isMobile and 9 or 14)
	wmPadding.PaddingRight = UDim.new(0, isMobile and 10 or 16)
	wmPadding.Parent = wmBar

	local wmLayout = Instance.new("UIListLayout")
	wmLayout.FillDirection = Enum.FillDirection.Horizontal
	wmLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	wmLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wmLayout.Padding = UDim.new(0, isMobile and 7 or 10)
	wmLayout.Parent = wmBar

	local wmLogo = Instance.new("ImageLabel")
	wmLogo.Name = "WMLogo"
	wmLogo.Size = UDim2.new(0, isMobile and 18 or 22, 0, isMobile and 18 or 22)
	wmLogo.BackgroundTransparency = 1
	wmLogo.Image = (logoIconId and logoIconId ~= "") and logoIconId or SEARCH_ICON_ID
	wmLogo.LayoutOrder = 1
	wmLogo.Parent = wmBar
	ApplyTheme(wmLogo, "Accent", "ImageColor3")

	local function createWMDivider(order)
		local div = Instance.new("Frame")
		div.Name = "WMDivider"
		div.Size = UDim2.new(0, 1, 0, isMobile and 14 or 18)
		div.BorderSizePixel = 0
		div.LayoutOrder = order
		div.Parent = wmBar
		ApplyTheme(div, "Outlines", "BackgroundColor3")
		return div
	end

	createWMDivider(2)

	local wmFps = Instance.new("TextLabel")
	wmFps.Name = "WMFps"
	wmFps.AutomaticSize = Enum.AutomaticSize.X
	wmFps.Size = UDim2.new(0, 0, 1, 0)
	wmFps.BackgroundTransparency = 1
	wmFps.TextSize = isMobile and 11 or 14
	wmFps.Text = "60 fps"
	wmFps.LayoutOrder = 3
	wmFps.Parent = wmBar
	ApplyTheme(wmFps, "Text", "TextColor3")
	ApplyTheme(wmFps, "TextFont", "Font")

	createWMDivider(4)

	local wmPing = Instance.new("TextLabel")
	wmPing.Name = "WMPing"
	wmPing.AutomaticSize = Enum.AutomaticSize.X
	wmPing.Size = UDim2.new(0, 0, 1, 0)
	wmPing.BackgroundTransparency = 1
	wmPing.TextSize = isMobile and 11 or 14
	wmPing.Text = "0 ms"
	wmPing.LayoutOrder = 5
	wmPing.Parent = wmBar
	ApplyTheme(wmPing, "Text", "TextColor3")
	ApplyTheme(wmPing, "TextFont", "Font")

	createWMDivider(6)

	local wmUser = Instance.new("TextLabel")
	wmUser.Name = "WMUser"
	wmUser.AutomaticSize = Enum.AutomaticSize.X
	wmUser.Size = UDim2.new(0, 0, 1, 0)
	wmUser.BackgroundTransparency = 1
	wmUser.TextSize = isMobile and 11 or 14
	wmUser.Text = LP.DisplayName
	wmUser.LayoutOrder = 7
	wmUser.Parent = wmBar
	ApplyTheme(wmUser, "Text", "TextColor3")
	ApplyTheme(wmUser, "TextFont", "Font")

	local function updateWMShadowSize()
		local w = wmBar.AbsoluteSize.X
		if w > 0 then
			wmShadowFolder.Size = UDim2.new(0, w, 1, 0)
		end
	end
	table.insert(Window._connections, wmBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateWMShadowSize))
	task.spawn(function()
		task.wait(0.1)
		updateWMShadowSize()
	end)

	local wmDragging, wmDragInput, wmDragStart, wmStartPos
	local wmTargetPos = watermarkHolder.Position
	local wmDragConn = nil

	local function startWMLoop()
		if wmDragConn then return end
		wmDragConn = RS.RenderStepped:Connect(function(dt)
			if not watermarkHolder.Parent then
				if wmDragConn then wmDragConn:Disconnect(); wmDragConn = nil end
				return
			end
			local diffX = math.abs(watermarkHolder.Position.X.Offset - wmTargetPos.X.Offset)
			local diffY = math.abs(watermarkHolder.Position.Y.Offset - wmTargetPos.Y.Offset)
			if diffX > 0.1 or diffY > 0.1 then
				watermarkHolder.Position = watermarkHolder.Position:Lerp(wmTargetPos, 1 - math.exp(-28 * dt))
			else
				watermarkHolder.Position = wmTargetPos
				if not wmDragging then
					wmDragConn:Disconnect()
					wmDragConn = nil
				end
			end
		end)
		table.insert(Window._connections, wmDragConn)
	end

	table.insert(Window._connections, watermarkHolder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			wmDragging = true
			wmDragStart = input.Position
			wmStartPos = wmTargetPos
			startWMLoop()
			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					wmDragging = false
					endConn:Disconnect()
				end
			end)
			table.insert(Window._connections, endConn)
		end
	end))

	table.insert(Window._connections, watermarkHolder.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			wmDragInput = input
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if input == wmDragInput and wmDragging then
			local delta = input.Position - wmDragStart
			wmTargetPos = UDim2.new(wmStartPos.X.Scale, wmStartPos.X.Offset + delta.X, wmStartPos.Y.Scale, wmStartPos.Y.Offset + delta.Y)
			startWMLoop()
		end
	end))

	local fpsFrames = 0
	local fpsElapsed = 0
	table.insert(Window._connections, RS.RenderStepped:Connect(function(dt)
		if not watermarkHolder.Visible then
			fpsFrames = 0
			fpsElapsed = 0
			return
		end
		fpsFrames = fpsFrames + 1
		fpsElapsed = fpsElapsed + dt
		if fpsElapsed >= 0.5 then
			wmFps.Text = tostring(math.round(fpsFrames / fpsElapsed)) .. " fps"
			fpsFrames = 0
			fpsElapsed = 0
		end
	end))

	task.spawn(function()
		while watermarkHolder.Parent do
			task.wait(2.0)
			if not watermarkHolder.Parent then break end
			if watermarkHolder.Visible then
				local pingVal = 0
				pcall(function()
					local netStats = StatsService:FindFirstChild("Network")
					if netStats and netStats:FindFirstChild("ServerStatsItem") then
						local pingItem = netStats.ServerStatsItem:FindFirstChild("Data Ping")
						if pingItem then
							pingVal = math.round(pingItem:GetValue())
						end
					end

					if pingVal == 0 then
						local perf = StatsService:FindFirstChild("PerformanceStats")
						if perf and perf:FindFirstChild("Ping") then
							pingVal = math.round(perf.Ping:GetValue())
						end
					end

					if pingVal == 0 then
						local rawPing = LP:GetNetworkPing()
						if rawPing and rawPing > 0 then
							pingVal = math.round(rawPing * 2000)
						end
					end
				end)
				wmPing.Text = tostring(pingVal) .. " ms"
			end
		end
	end)

	Window.Watermark = {
		SetVisible = function(self, state)
			watermarkHolder.Visible = state
			local control = Window._themeControls["Layout & Styles~Show Watermark"]
			if control then control.API:Set(state == true) end
		end,
		SetLogo = function(self, id)
			wmLogo.Image = parseAsset(id)
		end
	}

	local function SetupKeybindsHUD()
		local kbDockSide = "Right"
		local kbIsOpen = false
		local kbOffsetY = 0
		local KB_WIDTH = 195
		local VISIBLE_EDGE = 14

		local kbEnabled = keybindsEnabled

		local kbHolder = Instance.new("Frame")
		kbHolder.Name = "KeybindsHUD"
		kbHolder.Size = UDim2.new(0, KB_WIDTH, 0, 0)
		kbHolder.AutomaticSize = Enum.AutomaticSize.Y
		kbHolder.AnchorPoint = Vector2.new(0, 0.5)
		kbHolder.BackgroundTransparency = 1
		kbHolder.ZIndex = 9000
		kbHolder.Visible = kbEnabled
		kbHolder.Parent = screenGui

		Window.Keybinds = {
			SetVisible = function(self, state)
				kbHolder.Visible = state
				local control = Window._themeControls["Layout & Styles~Show Keybinds HUD"]
				if control then control.API:Set(state == true) end
			end
		}

		local kbMain = Instance.new("Frame")
		kbMain.Name = "MainCard"
		kbMain.Size = UDim2.new(1, 0, 0, 0)
		kbMain.AutomaticSize = Enum.AutomaticSize.Y
		kbMain.BorderSizePixel = 0
		kbMain.ZIndex = 9001
		kbMain.Parent = kbHolder
		ApplyTheme(kbMain, "Background", "BackgroundColor3")
		ApplyTheme(kbMain, "HUDTransparency", "BackgroundTransparency")

		local kbCorner = Instance.new("UICorner")
		kbCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		kbCorner.Parent = kbMain
		CS:AddTag(kbCorner, "HUDCorner")

		local kbStroke = Instance.new("UIStroke")
		kbStroke.Name = "KeybindStroke"
		kbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		kbStroke.Thickness = 1
		kbStroke.Enabled = THEME.MainOutlineEnabled
		kbStroke.Parent = kbMain
		ApplyTheme(kbStroke, "Outlines", "Color")

		table.insert(Window._connections, mainOutlineStroke:GetPropertyChangedSignal("Enabled"):Connect(function()
			kbStroke.Enabled = mainOutlineStroke.Enabled
		end))

		local kbBar = Instance.new("Frame")
		kbBar.Name = "AccentStrip"
		kbBar.Size = UDim2.new(0, 3, 0, 44)
		kbBar.BorderSizePixel = 0
		kbBar.ZIndex = 9003
		kbBar.Parent = kbMain
		ApplyTheme(kbBar, "Accent", "BackgroundColor3")

		local kbBarCorner = Instance.new("UICorner")
		kbBarCorner.CornerRadius = UDim.new(1, 0)
		kbBarCorner.Parent = kbBar

		local kbEdgeBtn = Instance.new("TextButton")
		kbEdgeBtn.Name = "EdgeTrigger"
		kbEdgeBtn.BackgroundTransparency = 1
		kbEdgeBtn.Text = ""
		kbEdgeBtn.ZIndex = 9004
		kbEdgeBtn.Parent = kbMain

		local kbHeader = Instance.new("TextButton")
		kbHeader.Name = "Header"
		kbHeader.Size = UDim2.new(1, 0, 0, 28)
		kbHeader.BackgroundTransparency = 1
		kbHeader.Text = ""
		kbHeader.Parent = kbMain

		local kbTitle = Instance.new("TextLabel")
		kbTitle.Name = "Title"
		kbTitle.Size = UDim2.new(1, -20, 1, 0)
		kbTitle.Position = UDim2.new(0, 16, 0, 0)
		kbTitle.BackgroundTransparency = 1
		kbTitle.Text = "Keybinds"
		kbTitle.TextSize = 12
		kbTitle.TextXAlignment = Enum.TextXAlignment.Left
		kbTitle.Parent = kbHeader
		ApplyTheme(kbTitle, "Text", "TextColor3")
		ApplyTheme(kbTitle, "TextFont", "Font")

		local kbDivider = Instance.new("Frame")
		kbDivider.Name = "Divider"
		kbDivider.Size = UDim2.new(1, -20, 0, 1)
		kbDivider.Position = UDim2.new(0.5, 0, 1, -1)
		kbDivider.AnchorPoint = Vector2.new(0.5, 1)
		kbDivider.BorderSizePixel = 0
		kbDivider.Parent = kbHeader
		ApplyTheme(kbDivider, "Outlines", "BackgroundColor3")

		local kbEntries = Instance.new("ScrollingFrame")
		kbEntries.Name = "Entries"
		kbEntries.Size = UDim2.new(1, 0, 0, 0)
		kbEntries.Position = UDim2.new(0, 0, 0, 29)
		kbEntries.BackgroundTransparency = 1
		kbEntries.BorderSizePixel = 0
		kbEntries.ScrollBarThickness = 2
		kbEntries.CanvasSize = UDim2.new(0, 0, 0, 0)
		kbEntries.AutomaticCanvasSize = Enum.AutomaticSize.Y
		kbEntries.Parent = kbMain
		ApplyTheme(kbEntries, "Outlines", "ScrollBarImageColor3")

		local kbLayout = Instance.new("UIListLayout")
		kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
		kbLayout.Padding = UDim.new(0, 4)
		kbLayout.Parent = kbEntries

		local kbPad = Instance.new("UIPadding")
		kbPad.PaddingTop = UDim.new(0, 6)
		kbPad.PaddingBottom = UDim.new(0, 8)
		kbPad.PaddingLeft = UDim.new(0, 14)
		kbPad.PaddingRight = UDim.new(0, 8)
		kbPad.Parent = kbEntries

		local kbTargetPos = UDim2.new(1, -VISIBLE_EDGE, 0.5, kbOffsetY)

		local function UpdateKBDocking()
			if kbDockSide == "Right" then
				kbBar.AnchorPoint = Vector2.new(0, 0.5)
				kbBar.Position = UDim2.new(0, 5, 0.5, 0)

				kbEdgeBtn.AnchorPoint = Vector2.new(0, 0)
				kbEdgeBtn.Position = UDim2.new(0, 0, 0, 0)
				kbEdgeBtn.Size = UDim2.new(0, VISIBLE_EDGE + 6, 1, 0)

				kbTitle.Position = UDim2.new(0, 16, 0, 0)
				kbPad.PaddingLeft = UDim.new(0, 15)
				kbPad.PaddingRight = UDim.new(0, 8)

				if kbIsOpen then
					kbTargetPos = UDim2.new(1, -KB_WIDTH - 8, 0.5, kbOffsetY)
				else
					kbTargetPos = UDim2.new(1, -VISIBLE_EDGE, 0.5, kbOffsetY)
				end
			else
				kbBar.AnchorPoint = Vector2.new(1, 0.5)
				kbBar.Position = UDim2.new(1, -5, 0.5, 0)

				kbEdgeBtn.AnchorPoint = Vector2.new(1, 0)
				kbEdgeBtn.Position = UDim2.new(1, 0, 0, 0)
				kbEdgeBtn.Size = UDim2.new(0, VISIBLE_EDGE + 6, 1, 0)

				kbTitle.Position = UDim2.new(0, 10, 0, 0)
				kbPad.PaddingLeft = UDim.new(0, 8)
				kbPad.PaddingRight = UDim.new(0, 15)

				if kbIsOpen then
					kbTargetPos = UDim2.new(0, 8, 0.5, kbOffsetY)
				else
					kbTargetPos = UDim2.new(0, -KB_WIDTH + VISIBLE_EDGE, 0.5, kbOffsetY)
				end
			end
		end

		local kbStepConn = nil
		local function startKBLoop()
			if kbStepConn then return end
			kbStepConn = RS.RenderStepped:Connect(function(dt)
				if not kbHolder.Parent then
					if kbStepConn then kbStepConn:Disconnect(); kbStepConn = nil end
					return
				end
				local diffX = math.abs(kbHolder.Position.X.Offset - kbTargetPos.X.Offset)
				local diffY = math.abs(kbHolder.Position.Y.Offset - kbTargetPos.Y.Offset)
				if diffX > 0.1 or diffY > 0.1 then
					kbHolder.Position = kbHolder.Position:Lerp(kbTargetPos, 1 - math.exp(-26 * dt))
				else
					kbHolder.Position = kbTargetPos
					if not kbDragging then
						kbStepConn:Disconnect()
						kbStepConn = nil
					end
				end
			end)
			table.insert(Window._connections, kbStepConn)
		end

		UpdateKBDocking()
		kbHolder.Position = kbTargetPos

		table.insert(Window._connections, kbEdgeBtn.MouseButton1Click:Connect(function()
			kbIsOpen = not kbIsOpen
			UpdateKBDocking()
			startKBLoop()
		end))

		local kbDragging = false
		local kbStartMouseX, kbStartMouseY
		local kbStartPosX, kbStartPosY

		local function StartDrag(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				kbDragging = true
				kbStartMouseX = input.Position.X
				kbStartMouseY = input.Position.Y
				kbStartPosX = kbHolder.Position.X.Offset
				kbStartPosY = kbHolder.Position.Y.Offset
				startKBLoop()

				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						kbDragging = false
						endConn:Disconnect()

						local screenW = screenGui.AbsoluteSize.X
						local screenH = screenGui.AbsoluteSize.Y

						if input.Position.X < screenW / 2 then
							kbDockSide = "Left"
						else
							kbDockSide = "Right"
						end

						kbOffsetY = math.clamp(kbTargetPos.Y.Offset, -screenH / 2 + 60, screenH / 2 - 60)
						UpdateKBDocking()
						startKBLoop()
					end
				end)
				table.insert(Window._connections, endConn)
			end
		end

		table.insert(Window._connections, kbHeader.InputBegan:Connect(StartDrag))

		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if kbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local deltaX = input.Position.X - kbStartMouseX
				local deltaY = input.Position.Y - kbStartMouseY
				kbTargetPos = UDim2.new(kbHolder.Position.X.Scale, kbStartPosX + deltaX, 0.5, kbStartPosY + deltaY)
				startKBLoop()
			end
		end))

		local function UpdateKeybindList()
			for _, child in ipairs(kbEntries:GetChildren()) do
				if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
			end

			local count = 0
			for uniqueId, element in pairs(Window._configElements) do
				local success, data = pcall(function() return element.API:Save() end)
				if success and type(data) == "table" and data.Bind and data.Bind ~= "" and data.Bind ~= "Unknown" and data.Bind ~= "None" then
					local shortKeyTxt = shortKeys[data.Bind] or tostring(data.Bind)
					if shortKeyTxt ~= "None" and shortKeyTxt ~= "Unknown" and shortKeyTxt ~= "" then
						count = count + 1
						local itemName = uniqueId:match("~[^~]+~([^~]+)$") or uniqueId
						local isToggle = (element.Type == "Toggle")
						local isActive = (data.State == true)

						local row = Instance.new("Frame")
						row.Name = "Row_" .. tostring(itemName)
						row.Size = UDim2.new(1, 0, 0, 22)
						row.BackgroundTransparency = 1
						row.Parent = kbEntries

						local rowTitle = Instance.new("TextLabel")
						rowTitle.Size = UDim2.new(1, -40, 1, 0)
						rowTitle.Position = UDim2.new(0, 0, 0, 0)
						rowTitle.BackgroundTransparency = 1
						rowTitle.TextSize = 12
						rowTitle.Text = tostring(itemName)
						rowTitle.TextXAlignment = Enum.TextXAlignment.Left
						rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
						rowTitle.Parent = row
						ApplyTheme(rowTitle, "Text", "TextColor3")
						ApplyTheme(rowTitle, "TextFont", "Font")

						local badge = Instance.new("Frame")
						badge.Size = UDim2.new(0, 26, 0, 18)
						badge.AnchorPoint = Vector2.new(1, 0.5)
						badge.Position = UDim2.new(1, 0, 0.5, 0)
						badge.AutomaticSize = Enum.AutomaticSize.X
						badge.BorderSizePixel = 0
						badge.Parent = row
						ApplyTheme(badge, "Input", "BackgroundColor3")
						ApplyTheme(badge, "InputTrans", "BackgroundTransparency")

						local badgeCorner = Instance.new("UICorner")
						badgeCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
						badgeCorner.Parent = badge
						CS:AddTag(badgeCorner, "HUDCorner")

						local badgeStroke = Instance.new("UIStroke")
						badgeStroke.Thickness = 1
						badgeStroke.Parent = badge

						if isToggle and isActive then
							ApplyTheme(badgeStroke, "Accent", "Color")
						else
							ApplyTheme(badgeStroke, "Outlines", "Color")
						end

						local badgeTxt = Instance.new("TextLabel")
						badgeTxt.Size = UDim2.new(1, 0, 1, 0)
						badgeTxt.BackgroundTransparency = 1
						badgeTxt.TextSize = 11
						badgeTxt.Text = shortKeyTxt
						badgeTxt.Parent = badge
						ApplyTheme(badgeTxt, "SubtextFont", "Font")

						if isToggle and isActive then
							ApplyTheme(badgeTxt, "Accent", "TextColor3")
						else
							ApplyTheme(badgeTxt, "TextMuted", "TextColor3")
						end

						local badgePad = Instance.new("UIPadding")
						badgePad.PaddingLeft = UDim.new(0, 5)
						badgePad.PaddingRight = UDim.new(0, 5)
						badgePad.Parent = badgeTxt
					end
				end
			end

			if count == 0 then
				local emptyLbl = Instance.new("TextLabel")
				emptyLbl.Name = "EmptyLabel"
				emptyLbl.Size = UDim2.new(1, 0, 0, 18)
				emptyLbl.BackgroundTransparency = 1
				emptyLbl.TextSize = 11
				emptyLbl.Text = "No active binds"
				emptyLbl.Parent = kbEntries
				ApplyTheme(emptyLbl, "TextMuted", "TextColor3")
				ApplyTheme(emptyLbl, "SubtextFont", "Font")
				kbEntries.Size = UDim2.new(1, 0, 0, 32)
			else
				local visibleCount = math.min(count, 10)
				local targetHeight = 14 + (visibleCount * 22) + ((visibleCount - 1) * 4)
				kbEntries.Size = UDim2.new(1, 0, 0, targetHeight)
			end
		end

		local isUpdatingKB = false
		local function RequestKBUpdate()
			if isUpdatingKB then return end
			isUpdatingKB = true
			task.delay(0.1, function()
				isUpdatingKB = false
				UpdateKeybindList()
			end)
		end

		Window.UpdateKeybinds = RequestKBUpdate

		task.spawn(function()
			task.wait(1.5)
			UpdateKeybindList()
		end)
	end
	SetupKeybindsHUD()
	
	Window.SettingsTab = Window:CreateTab({
		Name = "UI Settings",
		Icon = SETTINGS_ICON_ID,
		IsSettings = true
	})
	
	local MainSettingsBlock = Window.SettingsTab:CreateBlock({
		Name = "UI Configuration",
		Side = "Left"
	})
	
	MainSettingsBlock:CreateToggle({
		Name = "GUI Edit",
		Default = false,
		Callback = function(state)
			Window.ToggleEditMode(state)
		end
	})
	
	MainSettingsBlock:CreateLabel("Enable GUI Edit to visually customize the menu without game interference. The mouse will be forced to stay unlocked.")

	local ThemeSaveBlock = Window.SettingsTab:CreateBlock({
		Name = "Theme Management",
		Side = "Left"
	})

	safeMakeFolder(Window.ThemeFolder)

	local function getThemes()
		local list = {}
		safeMakeFolder(Window.ThemeFolder)
		for _, file in pairs(safeListFiles(Window.ThemeFolder)) do
			local clean = tostring(file):gsub("[%z\r\n%s]+$", "")
			if clean:lower():match("%.json$") then
				local name = clean:match("([^/\\]+)%.[jJ][sS][oO][nN]$")
				if name and name ~= "" then 
					table.insert(list, name) 
				end
			end
		end
		return list
	end

	local themeAutoLoadPath = Window.ThemeFolder .. "/autoload_theme.txt"
	local currentThemeAutoLoad = safeReadFile(themeAutoLoadPath)
	currentThemeAutoLoad = currentThemeAutoLoad and currentThemeAutoLoad:match("^%s*(.-)%s*$") or ""

	local themeNameInput = ThemeSaveBlock:CreateInput({
		Name = "Theme Name",
		Placeholder = "Enter theme name..."
	})

	local themeDropdown = ThemeSaveBlock:CreateDropdown({
		Name = "Select Theme",
		Options = getThemes(),
		Default = (currentThemeAutoLoad ~= "" and currentThemeAutoLoad or nil)
	})

	ThemeSaveBlock:CreateButton({
		Name = "Load Theme",
		Callback = function()
			local tName = themeDropdown:Save().Selected
			if tName and tName ~= "" then
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				local raw = safeReadFile(path)
				if raw and raw ~= "" then
					local success, res = pcall(function() return HttpService:JSONDecode(raw) end)
					if success and type(res) == "table" then
						for id, val in pairs(res) do
							if id == "SidebarWidth" then
								updateSidebarWidth(val)
							elseif Window._themeElements[id] then
								Window._themeElements[id].API:Load(val)
							end
						end
						Window:Notify({
							Title = "Theme System",
							Description = "Loaded theme: " .. tName,
							Duration = 3,
							Icon = SETTINGS_ICON_ID
						})
					end
				end
			end
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Save Theme",
		Callback = function()
			local tName = themeNameInput:Save().Text
			if not tName or tName == "" then
				tName = themeDropdown:Save().Selected
			end
			if tName and tName ~= "" then
				local data = {}
				for id, el in pairs(Window._themeElements) do
					if not string.find(id, "~Configuration~") and not string.find(id, "~Theme Management~") and not string.find(id, "~UI Configuration~") then
						local savedData = el.API:Save()
						if savedData then
							data[id] = savedData
						end
					end
				end
				data["SidebarWidth"] = currentSidebarWidth
			
				safeMakeFolder(Window.ThemeFolder)
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				safeWriteFile(path, HttpService:JSONEncode(data))
				themeDropdown:SetOptions(getThemes())
				themeDropdown:Set(tName)
				Window:Notify({
					Title = "Theme System",
					Description = "Saved theme: " .. tName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Theme Error", Description = "Enter a theme name first.", Duration = 3})
			end
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Refresh List",
		Callback = function()
			themeDropdown:SetOptions(getThemes())
			Window:Notify({Title = "Theme System", Description = "Theme list refreshed.", Duration = 2})
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Delete Theme",
		Callback = function()
			local tName = themeDropdown:Save().Selected
			if tName and tName ~= "" then
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				safeDelFile(path)
				themeDropdown:SetOptions(getThemes())
				themeDropdown:Set(nil)
				Window:Notify({
					Title = "Theme System",
					Description = "Deleted theme: " .. tName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			end
		end
	})

	local isInitThemeAutoLoad = true
	ThemeSaveBlock:CreateToggle({
		Name = "Auto-Load Selected Theme",
		Default = (currentThemeAutoLoad ~= ""),
		Callback = function(state)
			if isInitThemeAutoLoad then return end
			if state then
				local tName = themeDropdown:Save().Selected
				if tName and tName ~= "" then
					safeWriteFile(themeAutoLoadPath, tName)
				else
					Window:Notify({Title = "Error", Description = "Please select a theme first to auto-load.", Duration = 3})
				end
			else
				safeDelFile(themeAutoLoadPath)
			end
		end
	})
	isInitThemeAutoLoad = false

	local function CreateThemeEditorBlock(name, sideName)
		local blockContainer = Instance.new("Frame")
		blockContainer.Name = name .. "_ThemeBlock"
		blockContainer.Size = UDim2.new(1, 0, 0, 0)
		blockContainer.AutomaticSize = Enum.AutomaticSize.Y
		blockContainer.Parent = sideName == "Right" and themeEditorRight or themeEditorLeft
		ApplyTheme(blockContainer, "Background", "BackgroundColor3")
		ApplyTheme(blockContainer, "BackgroundTrans", "BackgroundTransparency")
	
		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = blockContainer
		CS:AddTag(corner, "ElementCorner")

		local blockStroke = Instance.new("UIStroke")
		blockStroke.Name = "EditorOutlineStroke"
		blockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		blockStroke.Thickness = 1
		blockStroke.Enabled = THEME.MainOutlineEnabled
		blockStroke.Parent = blockContainer
		ApplyTheme(blockStroke, "Outlines", "Color")
		CS:AddTag(blockStroke, "EditorLeftOutlineBind")

		local blockPadding = Instance.new("UIPadding")
		blockPadding.PaddingTop = UDim.new(0, 12)
		blockPadding.PaddingBottom = UDim.new(0, 12)
		blockPadding.PaddingLeft = UDim.new(0, 12)
		blockPadding.PaddingRight = UDim.new(0, 12)
		blockPadding.Parent = blockContainer

		local blockLayout = Instance.new("UIListLayout")
		blockLayout.FillDirection = Enum.FillDirection.Vertical
		blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
		blockLayout.Padding = UDim.new(0, 6)
		blockLayout.Parent = blockContainer
	
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 20)
		title.BackgroundTransparency = 1
		title.TextSize = 13
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = name
		title.Parent = blockContainer
		ApplyTheme(title, "Text", "TextColor3")
		ApplyTheme(title, "TextFont", "Font")
	
		local div = Instance.new("Frame")
		div.Size = UDim2.new(1, 0, 0, 1)
		div.BorderSizePixel = 0
		div.Parent = blockContainer
		ApplyTheme(div, "Outlines", "BackgroundColor3")

		local function updateThemeBlockStyle(style)
			if style == 3 or style == 4 then
				blockPadding.PaddingTop = UDim.new(0, 8)
				blockPadding.PaddingBottom = UDim.new(0, 8)
				blockPadding.PaddingLeft = UDim.new(0, 8)
				blockPadding.PaddingRight = UDim.new(0, 8)
				blockLayout.Padding = UDim.new(0, 4)
				title.Size = UDim2.new(1, 0, 0, 16)
			else
				blockPadding.PaddingTop = UDim.new(0, 12)
				blockPadding.PaddingBottom = UDim.new(0, 12)
				blockPadding.PaddingLeft = UDim.new(0, 12)
				blockPadding.PaddingRight = UDim.new(0, 12)
				blockLayout.Padding = UDim.new(0, 6)
				title.Size = UDim2.new(1, 0, 0, 20)
			end
		end
		table.insert(Window._styleCallbacks, updateThemeBlockStyle)
		updateThemeBlockStyle(THEME.ElementStyle)

		return BuildElementAPI(blockContainer, name, "", sideName, "SettingsTab", true)
	end

	local colorsBlock = CreateThemeEditorBlock("Colors", "Left")
	colorsBlock:CreateColorpicker({
		Name = "Accent Color",
		Default = THEME.Accent,
		Callback = function(c) UpdateTheme("Accent", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Background",
		Default = THEME.Background,
		Callback = function(c) UpdateTheme("Background", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Sidebar",
		Default = THEME.Sidebar,
		Callback = function(c) UpdateTheme("Sidebar", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Cards & Panels",
		Default = THEME.Card,
		Callback = function(c) UpdateTheme("Card", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Elements",
		Default = THEME.Element,
		Callback = function(c) UpdateTheme("Element", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Inputs & Highlights",
		Default = THEME.Input,
		Callback = function(c) UpdateTheme("Input", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Outlines & Borders",
		Default = THEME.Outlines,
		Callback = function(c) UpdateTheme("Outlines", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Main Text",
		Default = THEME.Text,
		Callback = function(c) UpdateTheme("Text", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Subtext",
		Default = THEME.TextMuted,
		Callback = function(c) UpdateTheme("TextMuted", c) end
	})

	local transBlock = CreateThemeEditorBlock("Transparency", "Left")
	transBlock:CreateSlider({
		Name = "Background",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.BackgroundTrans * 100),
		Callback = function(v) UpdateTheme("BackgroundTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Bg Image",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.BgImageTrans * 100),
		Callback = function(v) UpdateTheme("BgImageTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Cards & Panels",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.CardTrans * 100),
		Callback = function(v) UpdateTheme("CardTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Elements",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.ElementTrans * 100),
		Callback = function(v) UpdateTheme("ElementTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Inputs",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.InputTrans * 100),
		Callback = function(v) UpdateTheme("InputTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "HUD",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.HUDTransparency * 100),
		Callback = function(v) UpdateTheme("HUDTransparency", v / 100) end
	})

	local miscBlock = CreateThemeEditorBlock("Fonts & Extras", "Left")
	miscBlock:CreateInput({
		Name = "Bg Image ID",
		Placeholder = "rbxassetid://...",
		Default = THEME.BackgroundImage or "",
		Callback = function(t) UpdateTheme("BackgroundImage", t) end
	})
	miscBlock:CreateDropdown({
		Name = "Primary Font",
		Options = FontsList,
		Default = THEME.TextFont,
		Callback = function(v) UpdateTheme("TextFont", v) end
	})
	miscBlock:CreateDropdown({
		Name = "Subtext Font",
		Options = FontsList,
		Default = THEME.SubtextFont,
		Callback = function(v) UpdateTheme("SubtextFont", v) end
	})

	local layoutBlock = CreateThemeEditorBlock("Layout & Styles", "Right")
	layoutBlock:CreateSlider({
		Name = "Sidebar Width",
		Min = MIN_SIDEBAR_WIDTH,
		Max = MAX_SIDEBAR_WIDTH,
		Step = 1,
		Default = math.clamp(currentSidebarWidth, MIN_SIDEBAR_WIDTH, MAX_SIDEBAR_WIDTH),
		Callback = function(width) updateSidebarWidth(width) end
	})
	layoutBlock:CreateKeybind({
		Name = "Open GUI Keybind",
		Default = openKeybind,
		Callback = function(key) Window:SetOpenKeybind(key) end
	})
	layoutBlock:CreateDropdown({
		Name = "Background Effect",
		Options = {"None", "Constellation", "Matrix Dots", "Floating Sparks"},
		Default = THEME.BackgroundEffect or "Constellation",
		Callback = function(opt)
			THEME.BackgroundEffect = opt
			initBackgroundFX(opt)
		end
	})
	layoutBlock:CreateToggle({
		Name = "Main GUI Outline",
		Default = THEME.MainOutlineEnabled,
		Callback = function(s)
			THEME.MainOutlineEnabled = s
			mainOutlineStroke.Enabled = s 
			sidebarOutlineStroke.Enabled = (s and SIDEBAR_STATE.Detached)
			sidebarOutlineStroke.Transparency = 0
			mainOutlineStroke.Transparency = 0
			for _, ns in ipairs(CS:GetTagged("NotificationStrokeBind")) do
				ns.Enabled = s
			end
			for _, ws in ipairs(CS:GetTagged("WatermarkStrokeBind")) do
				ws.Enabled = s
			end
			for _, ls in ipairs(CS:GetTagged("EditorLeftOutlineBind")) do
				ls.Enabled = s
			end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Internal Outlines",
		Options = {"Off", "Only Blocks", "Only Elements", "All"},
		Default = THEME.InternalOutlines,
		Callback = function(opt)
			THEME.InternalOutlines = opt
			local showBlocks = (opt == "Only Blocks" or opt == "All")
			local showElems = (opt == "Only Elements" or opt == "All")
			for _, stroke in ipairs(CS:GetTagged("BlockStroke")) do stroke.Enabled = showBlocks end
			for _, stroke in ipairs(CS:GetTagged("ElementStroke")) do stroke.Enabled = showElems end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "GUI Style",
		Options = {"Style 1", "Style 2", "Style 3", "Style 4"},
		Default = "Style " .. tostring(THEME.ElementStyle or 1),
		Callback = function(opt)
			THEME.ElementStyle = tonumber(opt:match("%d+")) or 1
			for _, cb in ipairs(Window._styleCallbacks) do
				cb(THEME.ElementStyle)
			end
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Close Animation",
		Options = {"Fade Slide Down", "Fade Slide Up", "Zoom Fade", "Slide Right"},
		Default = (THEME.CloseAnimation == 2 and "Fade Slide Up") or (THEME.CloseAnimation == 3 and "Zoom Fade") or (THEME.CloseAnimation == 4 and "Slide Right") or "Fade Slide Down",
		Callback = function(opt)
			if opt == "Fade Slide Up" then
				THEME.CloseAnimation = 2
			elseif opt == "Zoom Fade" then
				THEME.CloseAnimation = 3
			elseif opt == "Slide Right" then
				THEME.CloseAnimation = 4
			else
				THEME.CloseAnimation = 1
			end
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Watermark",
		Default = watermarkEnabled,
		Callback = function(s)
			watermarkHolder.Visible = s
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Keybinds HUD",
		Default = keybindsEnabled,
		Callback = function(s)
			if Window.Keybinds then
				Window.Keybinds:SetVisible(s)
			end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Topbar Elements Pos",
		Options = {"Right", "Left"},
		Default = THEME.TopbarAlign or "Right",
		Callback = function(opt)
			UpdateTopbarAlign(opt)
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Search Bar",
		Default = showSearchBar,
		Callback = function(s)
			searchContainer.Visible = s 
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Profile",
		Default = showProfile,
		Callback = function(s)
			profileBlock.Visible = s 
		end
	})
	layoutBlock:CreateToggle({
		Name = "Drop Shadows",
		Default = SIDEBAR_STATE.ShadowsEnabled,
		Callback = function(s)
			setLayeredShadows(s)
		end
	})
	setLayeredShadows(SIDEBAR_STATE.ShadowsEnabled)
	layoutBlock:CreateSlider({
		Name = "Main Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = cornerRadiusNum,
		Callback = function(v)
			cornerRadiusNum = v
			MAIN_CORNER = UDim.new(0, v)
			for _, corner in ipairs(CS:GetTagged("MainCorner")) do corner.CornerRadius = MAIN_CORNER end
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateSlider({
		Name = "Elements Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = elCornerRadiusNum,
		Callback = function(v)
			UpdateElementCorners(v)
		end
	})
	layoutBlock:CreateSlider({
		Name = "HUD Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = hudCornerRadiusNum,
		Callback = function(v)
			hudCornerRadiusNum = v
			for _, corner in ipairs(CS:GetTagged("HUDCorner")) do corner.CornerRadius = UDim.new(0, v) end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Sidebar Position",
		Options = {"Left", "Right", "Top", "Bottom"},
		Default = SIDEBAR_STATE.Position or "Left",
		Callback = function(opt)
			SIDEBAR_STATE.Position = opt
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateToggle({
		Name = "Detached Sidebar",
		Default = SIDEBAR_STATE.Detached or false,
		Callback = function(s)
			SIDEBAR_STATE.Detached = s
			FullUpdateLayout()
			setLayeredShadows(SIDEBAR_STATE.ShadowsEnabled)
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Toggle Checkbox Pos",
		Options = {"Right", "Left"},
		Default = THEME.TogglePosition or "Right",
		Callback = function(opt)
			UpdateTogglePosition(opt)
		end
	})
	
	local configBlock = Window.SettingsTab:CreateBlock({
		Name = "Configuration",
		Side = "Right"
	})
	
	safeMakeFolder(Window.ConfigFolder)
	
	local function getConfigs()
		local list = {}
		safeMakeFolder(Window.ConfigFolder)
		for _, file in pairs(safeListFiles(Window.ConfigFolder)) do
			local clean = tostring(file):gsub("[%z\r\n%s]+$", "")
			if clean:lower():match("%.json$") then
				local name = clean:match("([^/\\]+)%.[jJ][sS][oO][nN]$")
				if name and name ~= "" then 
					table.insert(list, name) 
				end
			end
		end
		return list
	end
	
	local autoLoadPath = Window.ConfigFolder .. "/autoload.txt"
	local currentAutoLoad = safeReadFile(autoLoadPath)
	currentAutoLoad = currentAutoLoad and currentAutoLoad:match("^%s*(.-)%s*$") or ""

	local configNameInput = configBlock:CreateInput({
		Name = "Config Name",
		Placeholder = "Enter name..."
	})
	
	local configDropdown = configBlock:CreateDropdown({
		Name = "Select Config",
		Options = getConfigs(),
		Default = (currentAutoLoad ~= "" and currentAutoLoad or nil)
	})
	
	configBlock:CreateButton({
		Name = "Load Config",
		Callback = function()
			local cfgName = configDropdown:Save().Selected
			if not cfgName or cfgName == "" then
				Window:Notify({Title = "Config Error", Description = "No config selected.", Duration = 3})
				return
			end
			
			local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
			local raw = safeReadFile(path)
			if not raw or raw == "" then
				Window:Notify({Title = "Config Error", Description = "File is empty or cannot be read.", Duration = 3})
				return
			end

			local success, res = pcall(function() return HttpService:JSONDecode(raw) end)
			if success and type(res) == "table" then
				for id, val in pairs(res) do
					if id == "__DetachedBlocks__" and type(val) == "table" then
						for bKey, bInfo in pairs(Window._blockRegistry) do
							if val[bKey] then
								bInfo.SetDetached(true, val[bKey])
							else
								bInfo.SetDetached(false)
							end
						end
					elseif Window._configElements[id] then
						pcall(function() Window._configElements[id].API:Load(val) end)
					end
				end
				Window:Notify({
					Title = "Config System",
					Description = "Loaded config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Config Error", Description = "Failed to parse JSON file.", Duration = 3})
			end
		end
	})
	
	configBlock:CreateButton({
		Name = "Save Config",
		Callback = function()
			local cfgName = configNameInput:Save().Text
			if not cfgName or cfgName == "" then
				cfgName = configDropdown:Save().Selected
			end
			
			if not cfgName or cfgName == "" then
				Window:Notify({Title = "Config Error", Description = "Enter a config name first.", Duration = 3})
				return
			end
			
			safeMakeFolder(Window.ConfigFolder)
			
			local data = {}
			for id, el in pairs(Window._configElements) do
				local s, savedData = pcall(function() return el.API:Save() end)
				if s and savedData ~= nil then
					data[id] = savedData
				end
			end

			local detachedBlocksData = {}
			for bKey, bInfo in pairs(Window._blockRegistry) do
				if bInfo.IsDetached() then
					detachedBlocksData[bKey] = bInfo.GetPosition()
				end
			end
			data["__DetachedBlocks__"] = detachedBlocksData
			
			local sEncode, json = pcall(function() return HttpService:JSONEncode(data) end)
			if not sEncode then
				Window:Notify({Title = "Config Error", Description = "JSON serialization failed.", Duration = 3})
				return
			end

			local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
			local sWrite, err = safeWriteFile(path, json)
			if sWrite then
				configDropdown:SetOptions(getConfigs())
				configDropdown:Set(cfgName)
				Window:Notify({
					Title = "Config System",
					Description = "Saved config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Config Error", Description = "Executor blocked writing file: " .. tostring(err), Duration = 4})
			end
		end
	})

	configBlock:CreateButton({
		Name = "Refresh List",
		Callback = function()
			configDropdown:SetOptions(getConfigs())
			Window:Notify({Title = "Config System", Description = "Config list refreshed.", Duration = 2})
		end
	})
	
	configBlock:CreateButton({
		Name = "Delete Config",
		Callback = function()
			local cfgName = configDropdown:Save().Selected
			if cfgName and cfgName ~= "" then
				local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
				safeDelFile(path)
				configDropdown:SetOptions(getConfigs())
				configDropdown:Set(nil)
				Window:Notify({
					Title = "Config System",
					Description = "Deleted config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			end
		end
	})
	
	local isInitConfigAutoLoad = true
	configBlock:CreateToggle({
		Name = "Auto-Load Selected Config",
		Default = (currentAutoLoad ~= ""),
		Callback = function(state)
			if isInitConfigAutoLoad then return end
			if state then
				local cfgName = configDropdown:Save().Selected
				if cfgName and cfgName ~= "" then
					safeWriteFile(autoLoadPath, cfgName)
				else
					Window:Notify({Title = "Error", Description = "Please select a config first to auto-load.", Duration = 3})
				end
			else
				safeDelFile(autoLoadPath)
			end
		end
	})
	isInitConfigAutoLoad = false
	
	function Window:SetOpenKeybind(key)
		local resolved = resolveKeycode(key)
		if not resolved then return false end
		openKeybind = resolved
		local control = self._themeControls["Layout & Styles~Open GUI Keybind"]
		if control then control.API:SetKeybind(resolved) end
		return true
	end

	function Window:GetOpenKeybind()
		return openKeybind
	end

	local controlBindings = {
		Accent = {"Colors~Accent Color", "Colorpicker"},
		Background = {"Colors~Background", "Colorpicker"},
		Sidebar = {"Colors~Sidebar", "Colorpicker"},
		Card = {"Colors~Cards & Panels", "Colorpicker"},
		Element = {"Colors~Elements", "Colorpicker"},
		Input = {"Colors~Inputs & Highlights", "Colorpicker"},
		Outlines = {"Colors~Outlines & Borders", "Colorpicker"},
		Text = {"Colors~Main Text", "Colorpicker"},
		TextMuted = {"Colors~Subtext", "Colorpicker"},
		BackgroundTrans = {"Transparency~Background", "Percent"},
		HUDTransparency = {"Transparency~HUD", "Percent"},
		BgImageTrans = {"Transparency~Bg Image", "Percent"},
		CardTrans = {"Transparency~Cards & Panels", "Percent"},
		ElementTrans = {"Transparency~Elements", "Percent"},
		InputTrans = {"Transparency~Inputs", "Percent"},
		BackgroundImage = {"Fonts & Extras~Bg Image ID", "Text"},
		TextFont = {"Fonts & Extras~Primary Font", "Dropdown"},
		SubtextFont = {"Fonts & Extras~Subtext Font", "Dropdown"},
		BackgroundEffect = {"Layout & Styles~Background Effect", "Dropdown"},
		MainOutlineEnabled = {"Layout & Styles~Main GUI Outline", "Toggle"},
		InternalOutlines = {"Layout & Styles~Internal Outlines", "Dropdown"},
		ElementStyle = {"Layout & Styles~GUI Style", "Style"},
		CloseAnimation = {"Layout & Styles~Close Animation", "Animation"},
		ShowWatermark = {"Layout & Styles~Show Watermark", "Toggle"},
		ShowKeybindsHUD = {"Layout & Styles~Show Keybinds HUD", "Toggle"},
		TopbarAlign = {"Layout & Styles~Topbar Elements Pos", "Dropdown"},
		ShowSearchBar = {"Layout & Styles~Show Search Bar", "Toggle"},
		ShowProfile = {"Layout & Styles~Show Profile", "Toggle"},
		DropShadows = {"Layout & Styles~Drop Shadows", "Toggle"},
		SidebarWidth = {"Layout & Styles~Sidebar Width", "Slider"},
		CornerRadius = {"Layout & Styles~Main Corner Radius", "Slider"},
		ElementsCornerRadius = {"Layout & Styles~Elements Corner Radius", "Slider"},
		HUDCornerRadius = {"Layout & Styles~HUD Corner Radius", "Slider"},
		SidebarPosition = {"Layout & Styles~Sidebar Position", "Dropdown"},
		DetachedSidebar = {"Layout & Styles~Detached Sidebar", "Toggle"},
		TogglePosition = {"Layout & Styles~Toggle Checkbox Pos", "Dropdown"}
	}

	function Window:SetThemeOption(key, value)
		if key == "OpenKeybind" then return self:SetOpenKeybind(value) end
		local binding = controlBindings[key]
		if not binding then
			if THEME[key] ~= nil then
				UpdateTheme(key, value)
				return true
			end
			return false
		end
		local entry = self._themeControls[binding[1]]
		if not entry then return false end
		local kind = binding[2]
		if kind == "Percent" then
			if tonumber(value) == nil then return false end
			value = math.round(math.clamp(tonumber(value), 0, 1) * 100) / 100
			if THEME[key] ~= value then UpdateTheme(key, value) end
			entry.API:Set(math.round(value * 100))
		elseif kind == "Colorpicker" then
			if typeof(value) ~= "Color3" then return false end
			entry.API:SetColor(value)
		elseif kind == "Text" then
			entry.API:SetText(tostring(value))
		elseif kind == "Style" then
			local n = tonumber(value)
			if not n or n < 1 or n > 4 then return false end
			entry.API:Set("Style " .. tostring(math.floor(n)))
		elseif kind == "Animation" then
			if type(value) == "number" then
				value = ({"Fade Slide Down", "Fade Slide Up", "Zoom Fade", "Slide Right"})[value]
			end
			if not value then return false end
			entry.API:Set(value)
		elseif kind == "Toggle" then
			entry.API:Set(value == true)
		else
			entry.API:Set(value)
		end
		return true
	end

	function Window:SetTheme(options)
		if type(options) ~= "table" then return false end
		local allApplied = true
		for key, value in pairs(options) do
			if not self:SetThemeOption(key, value) then allApplied = false end
		end
		return allApplied
	end

	function Window:SetHUDTransparency(value)
		return self:SetThemeOption("HUDTransparency", value)
	end

	searchContainer.Visible = showSearchBar
	profileBlock.Visible = showProfile
	UpdateElementCorners(elCornerRadiusNum)

	UpdateTopbarAlign(THEME.TopbarAlign)
	UpdateTogglePosition(THEME.TogglePosition)

	mainOutlineStroke.Enabled = THEME.MainOutlineEnabled
	mainOutlineStroke.Transparency = 0
	sidebarOutlineStroke.Enabled = (THEME.MainOutlineEnabled and SIDEBAR_STATE.Detached)
	sidebarOutlineStroke.Transparency = 0
	for _, ns in ipairs(CS:GetTagged("NotificationStrokeBind")) do
		ns.Enabled = THEME.MainOutlineEnabled
	end
	for _, ws in ipairs(CS:GetTagged("WatermarkStrokeBind")) do
		ws.Enabled = THEME.MainOutlineEnabled
	end
	for _, ls in ipairs(CS:GetTagged("EditorLeftOutlineBind")) do
		ls.Enabled = THEME.MainOutlineEnabled
	end

	local showBlocks = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
	local showElems = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")
	for _, stroke in ipairs(CS:GetTagged("BlockStroke")) do stroke.Enabled = showBlocks end
	for _, stroke in ipairs(CS:GetTagged("ElementStroke")) do stroke.Enabled = showElems end

	updateSidebarWidth(currentSidebarWidth)

	task.spawn(function()
		task.wait(1.5)
	
		local tAutoName = safeReadFile(themeAutoLoadPath)
		if tAutoName and tAutoName ~= "" then
			tAutoName = tAutoName:match("^%s*(.-)%s*$")
			local tPath = Window.ThemeFolder .. "/" .. tAutoName .. ".json"
			local rawTheme = safeReadFile(tPath)
			if rawTheme and rawTheme ~= "" then
				local ts2, tRes = pcall(function() return HttpService:JSONDecode(rawTheme) end)
				if ts2 and type(tRes) == "table" then
					for id, val in pairs(tRes) do
						if id == "SidebarWidth" then
							updateSidebarWidth(val)
						elseif Window._themeElements[id] then
							Window._themeElements[id].API:Load(val)
						end
					end
					themeDropdown:Set(tAutoName)
					Window:Notify({
						Title = "Theme System",
						Description = "Auto-loaded theme: " .. tAutoName,
						Duration = 3,
						Icon = SETTINGS_ICON_ID
					})
				end
			end
		end

		task.wait(0.5)

		local autoName = safeReadFile(autoLoadPath)
		if autoName and autoName ~= "" then
			autoName = autoName:match("^%s*(.-)%s*$")
			local path = Window.ConfigFolder .. "/" .. autoName .. ".json"
			local rawJson = safeReadFile(path)
			if rawJson and rawJson ~= "" then
				local s2, res = pcall(function() return HttpService:JSONDecode(rawJson) end)
				if s2 and type(res) == "table" then
					for id, val in pairs(res) do
						if id == "__DetachedBlocks__" and type(val) == "table" then
							for bKey, bInfo in pairs(Window._blockRegistry) do
								if val[bKey] then
									bInfo.SetDetached(true, val[bKey])
								else
									bInfo.SetDetached(false)
								end
							end
						elseif Window._configElements[id] then
							pcall(function() Window._configElements[id].API:Load(val) end)
						end
					end
					configDropdown:Set(autoName)
					Window:Notify({
						Title = "Config System",
						Description = "Auto-loaded config: " .. autoName,
						Duration = 3,
						Icon = SETTINGS_ICON_ID
					})
				end
			end
		end
	end)

	return Window
end

return Library
