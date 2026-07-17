--!nocheck
-- update!
local TESTING = false

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local ScreenGui = game:GetObjects("rbxassetid://99852798675591")[1]
ScreenGui.Enabled = false

if RunService:IsStudio() then
	ScreenGui.Parent = game.StarterGui
else
	ScreenGui.Parent = cloneref(game.CoreGui)
end

local Library = {
	sizeX = 800,
	sizeY = 600,
	tabSizeX = 200,

	dragging = false,
	sliderDragging = false,
	firstTabDebounce = false,
	firstSubTabDebounce = false,
	processedEvent = false,
	managerCreated = false,
	lineIndex = 0,
	dropdownOpen = 0,

	Connections = {},
	Addons = {},
	Exclusions = {},
	SectionFolder = {
		Left = {},
		Right = {},
	},
	Flags = {
		Toggle = {},
		Slider = {},
		TextBox = {},
		Keybind = {},
		Dropdown = {},
		ColorPicker = {},
	},
	Theme = {},
	DropdownSizes = {},
	TooltipInstance = nil,
	TooltipShowId = 0,
	TooltipMoveConnection = nil,
	TooltipTweens = {},
	IconVisible = true,
}
Library.__index = Library

shared.Flags = Library.Flags

local Connections = Library.Connections
local Exclusions = Library.Exclusions

local Assets = ScreenGui.Assets
local Modules = {
	Dropdown = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Dropdown.lua`,
			true
		)
	)(),
	Toggle = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Toggle.lua`,
			true
		)
	)(),
	Popup = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Popup.lua`,
			true
		)
	)(),
	Slider = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Slider.lua`,
			true
		)
	)(),
	Keybind = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Keybind.lua`,
			true
		)
	)(),
	TextBox = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/TextBox.lua`,
			true
		)
	)(),
	Navigation = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Navigation.lua`,
			true
		)
	)(),
	ColorPicker = loadstring(
		game:HttpGet(
			`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/ColorPicker.lua`,
			true
		)
	)(),
}

local Utility = loadstring(
	game:HttpGet(
		`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Utility.lua`,
		true
	)
)()
local Theme = loadstring(
	game:HttpGet(
		`https://raw.githubusercontent.com/Grayy12/Leny-UI/refs/heads/{TESTING and "testing" or "main"}/Modules/Theme.lua`,
		true
	)
)()
Library.Theme = Theme

local mouseIconEnabled
local mouseBehavior
local mouseCaptured = false

local function setMouseCursorVisibility(visible)
	pcall(function()
		if visible then
			if not mouseCaptured then
				mouseIconEnabled = UserInputService.MouseIconEnabled
				mouseBehavior = UserInputService.MouseBehavior
				mouseCaptured = true
			end

			UserInputService.MouseIconEnabled = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif mouseCaptured then
			local iconEnabled = mouseIconEnabled
			local behavior = mouseBehavior

			mouseIconEnabled = nil
			mouseBehavior = nil
			mouseCaptured = false
			UserInputService.MouseIconEnabled = iconEnabled
			UserInputService.MouseBehavior = behavior
		end
	end)
end

local Popups = ScreenGui.Popups

local Glow = ScreenGui.Glow
Glow.Size = UDim2.fromOffset(Library.sizeX, Library.sizeY)

local Background = Glow.Background

local Tabs = Background.Tabs
local Filler = Tabs.Filler
local Resize = Filler.Resize
local Line = Filler.Line
local Title = Tabs.Frame.Title

function Library:createTooltip()
	if Library.TooltipInstance then
		return Library.TooltipInstance
	end

	local Tooltip = Instance.new("Frame")
	Tooltip.Name = "Tooltip"
	Tooltip.BackgroundColor3 = Theme.SecondaryBackgroundColor
	Tooltip.BorderSizePixel = 0
	Tooltip.Visible = false
	Tooltip.ZIndex = 9999
	Tooltip.AutomaticSize = Enum.AutomaticSize.Y
	Tooltip.Parent = ScreenGui

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0, 4)
	UICorner.Parent = Tooltip

	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingLeft = UDim.new(0, 8)
	UIPadding.PaddingRight = UDim.new(0, 8)
	UIPadding.PaddingTop = UDim.new(0, 6)
	UIPadding.PaddingBottom = UDim.new(0, 6)
	UIPadding.Parent = Tooltip

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "Text"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, 0, 0, 0)
	TextLabel.AutomaticSize = Enum.AutomaticSize.Y
	TextLabel.Font = Enum.Font.Gotham
	TextLabel.TextSize = 13
	TextLabel.TextColor3 = Theme.PrimaryTextColor
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment = Enum.TextYAlignment.Top
	TextLabel.TextWrapped = true
	TextLabel.Parent = Tooltip

	local Border = Instance.new("UIStroke")
	Border.Color = Theme.Line
	Border.Thickness = 1
	Border.Parent = Tooltip

	Theme:registerToObjects({
		{ object = Tooltip, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = TextLabel, property = "TextColor3", theme = { "PrimaryTextColor" } },
		{ object = Border, property = "Color", theme = { "Line" } },
	})

	Library.TooltipInstance = Tooltip
	return Tooltip
end

function Library:cancelTooltipTweens()
	for _, tween in ipairs(Library.TooltipTweens) do
		tween:Cancel()
	end
	Library.TooltipTweens = {}
end

function Library:showTooltip(element, text)
	if not text or text == "" then
		return
	end
	if Library.dropdownOpen > 0 then
		return
	end

	local Tooltip = Library:createTooltip()
	local TextLabel = Tooltip.Text

	Library.TooltipShowId = Library.TooltipShowId + 1
	Library:cancelTooltipTweens()

	if Library.TooltipMoveConnection then
		Library.TooltipMoveConnection:Disconnect()
		Library.TooltipMoveConnection = nil
	end

	TextLabel.Text = text

	local maxW = 260
	local textSize = TextService:GetTextSize(text, 13, Enum.Font.Gotham, Vector2.new(maxW, 10000))
	local w = math.min(textSize.X, maxW) + 16
	Tooltip.Size = UDim2.fromOffset(w, 0)

	Tooltip.BackgroundTransparency = 0
	TextLabel.TextTransparency = 0

	local function updatePosition()
		if Library.dropdownOpen > 0 then
			Tooltip.Visible = false
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local sx = ScreenGui.AbsoluteSize.X
		local sy = ScreenGui.AbsoluteSize.Y
		local tw = Tooltip.AbsoluteSize.X
		local th = Tooltip.AbsoluteSize.Y
		local x = math.clamp(mouse.X + -5, 4, sx - tw - 4)
		local y = math.clamp(mouse.Y + -25, 4, sy - th - 4)
		Tooltip.Position = UDim2.fromOffset(x, y)
	end

	updatePosition()
	Tooltip.Visible = true

	local conn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			updatePosition()
		end
	end)

	Library.TooltipMoveConnection = conn
	table.insert(Connections, conn)
end

function Library:hideTooltip()
	if not Library.TooltipInstance then
		return
	end

	local Tooltip = Library.TooltipInstance
	local TextLabel = Tooltip.Text
	local hideId = Library.TooltipShowId

	-- Cancel any previous tweens before starting new fade-out
	Library:cancelTooltipTweens()

	local t1 = Utility:tween(Tooltip, { BackgroundTransparency = 1 }, 0.1, "Quart", "Out")
	local t2 = Utility:tween(TextLabel, { TextTransparency = 1 }, 0.1, "Quart", "Out")
	t1:Play()
	t2:Play()
	Library.TooltipTweens = { t1, t2 }

	task.delay(0.1, function()
		if Library.TooltipShowId == hideId then
			Tooltip.Visible = false

			if Library.TooltipMoveConnection then
				Library.TooltipMoveConnection:Disconnect()
				Library.TooltipMoveConnection = nil
			end
		end
	end)
end

function Library:forceHideTooltip()
	if not Library.TooltipInstance then
		return
	end

	Library.TooltipShowId = Library.TooltipShowId + 1
	Library:cancelTooltipTweens()

	Library.TooltipInstance.BackgroundTransparency = 1
	Library.TooltipInstance.Text.TextTransparency = 1
	Library.TooltipInstance.Visible = false

	if Library.TooltipMoveConnection then
		Library.TooltipMoveConnection:Disconnect()
		Library.TooltipMoveConnection = nil
	end
end

local tabResizing = false
Resize.MouseButton1Down:Connect(function()
	tabResizing = true
end)

local touchMoved = UserInputService.TouchMoved:Connect(function()
	if tabResizing then
		local newSizeX = math.clamp(
			((input.Position.X - Glow.AbsolutePosition.X) / Glow.AbsoluteSize.X) * Glow.AbsoluteSize.X,
			72,
			208
		)
		Utility:tween(Tabs, { Size = UDim2.new(0, newSizeX, 1, 0) }, 0.2, "Quart", "Out"):Play()
		Utility:tween(Background.Pages, { Size = UDim2.new(1, -newSizeX, 1, 0) }, 0.2, "Quart", "Out"):Play()
	end
end)

local inputChanged = UserInputService.InputChanged:Connect(function(input)
	if tabResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local newSizeX = math.clamp(
			((input.Position.X - Glow.AbsolutePosition.X) / Glow.AbsoluteSize.X) * Glow.AbsoluteSize.X,
			72,
			208
		)
		Utility:tween(Tabs, { Size = UDim2.new(0, newSizeX, 1, 0) }, 0.2, "Quart", "Out"):Play()
		Utility:tween(Background.Pages, { Size = UDim2.new(1, -newSizeX, 1, 0) }, 0.2, "Quart", "Out"):Play()
	end
end)

local touchEnded = UserInputService.TouchEnded:Connect(function(input)
	if tabResizing then
		tabResizing = false
	end
end)

table.insert(Connections, inputChanged)

Resize.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tabResizing = false
	end
end)

Glow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	for _, data in ipairs(Library.SectionFolder.Right) do
		if Glow.AbsoluteSize.X <= 660 then
			data.folders.Right.Visible = false
			data.folders.Left.Size = UDim2.fromScale(1, 1)
			data.object.Parent = data.folders.Left
		else
			data.folders.Left.Size = UDim2.new(0.5, -7, 1, 0)
			data.folders.Right.Visible = true
			data.object.Parent = data.folders.Right
		end
	end

	for _, data in ipairs(Library.SectionFolder.Left) do
		if Glow.AbsoluteSize.X <= 660 then
			data.folders.Right.Visible = false
			data.folders.Left.Size = UDim2.fromScale(1, 1)
		else
			data.folders.Left.Size = UDim2.new(0.5, -7, 1, 0)
			data.folders.Right.Visible = true
		end
	end
end)

function Library.new(options)
	if getgenv().oldLibrary then
		getgenv().oldLibrary:destroy()
	end

	getgenv().oldLibrary = Library

	Utility:validateOptions(options, {
		sizeX = { Default = Library.sizeX, ExpectedType = "number" },
		sizeY = { Default = Library.sizeY, ExpectedType = "number" },
		tabSizeX = { Default = Library.tabSizeX, ExpectedType = "number" },
		title = { Default = "Leny", ExpectedType = "string" },
		iconTitle = { Default = "rbxassetid://110774279816088", ExpectedType = "string" },
		rainbowIcon = { Default = false, ExpectedType = "boolean" },
		PrimaryBackgroundColor = { Default = Library.Theme.PrimaryBackgroundColor, ExpectedType = "Color3" },
		SecondaryBackgroundColor = { Default = Library.Theme.SecondaryBackgroundColor, ExpectedType = "Color3" },
		TertiaryBackgroundColor = { Default = Library.Theme.TertiaryBackgroundColor, ExpectedType = "Color3" },
		TabBackgroundColor = { Default = Library.Theme.TabBackgroundColor, ExpectedType = "Color3" },
		PrimaryTextColor = { Default = Library.Theme.PrimaryTextColor, ExpectedType = "Color3" },
		SecondaryTextColor = { Default = Library.Theme.SecondaryTextColor, ExpectedType = "Color3" },
		PrimaryColor = { Default = Library.Theme.PrimaryColor, ExpectedType = "Color3" },
		ScrollingBarImageColor = { Default = Library.Theme.ScrollingBarImageColor, ExpectedType = "Color3" },
		Line = { Default = Library.Theme.Line, ExpectedType = "Color3" },
	})

	Library.tabSizeX = math.clamp(options.tabSizeX, 72, 208)
	Library.sizeX = options.sizeX
	Library.sizeY = options.sizeY
	Library.Theme.PrimaryBackgroundColor = options.PrimaryBackgroundColor
	Library.Theme.SecondaryBackgroundColor = options.SecondaryBackgroundColor
	Library.Theme.TertiaryBackgroundColor = options.TertiaryBackgroundColor
	Library.Theme.TabBackgroundColor = options.TabBackgroundColor
	Library.Theme.PrimaryTextColor = options.PrimaryTextColor
	Library.Theme.SecondaryTextColor = options.SecondaryTextColor
	Library.Theme.PrimaryColor = options.PrimaryColor
	Library.Theme.ScrollingBarImageColor = options.ScrollingBarImageColor
	Library.Theme.Line = options.Line
	Library.Title = options.title

	ScreenGui.Enabled = true
	setMouseCursorVisibility(true)

	-- Intro animation: scale up with bounce
	Glow.Size = UDim2.fromOffset(options.sizeX * 0.93, options.sizeY * 0.93)
	Utility:tween(Glow, {
		Size = UDim2.fromOffset(options.sizeX, options.sizeY),
	}, 0.4, "Back", "Out"):Play()

	local rainbowConnection = nil

	local function createNaturalRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		local originalColor = Library.Theme.PrimaryTextColor
		local s, v = originalColor:ToHSV()

		local originalSaturation = math.max(s, 0.8)
		local originalValue = math.max(v, 0.9)

		local startTime = tick()
		local cycleDuration = 4

		rainbowConnection = game:GetService("RunService").Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			local progress = (elapsed % cycleDuration) / cycleDuration

			local currentHue = progress

			local newColor = Color3.fromHSV(currentHue, originalSaturation, originalValue)
			titleIcon.ImageColor3 = newColor
		end)

		table.insert(Connections, {
			Disconnect = function()
				if rainbowConnection then
					rainbowConnection:Disconnect()
					rainbowConnection = nil
				end
			end,
		})
	end

	local function stopRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		titleIcon.ImageColor3 = Library.Theme.PrimaryTextColor

		Theme:registerToObjects({
			{ object = titleIcon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
		})
	end

	if UserIsPoor then
		Title.Text = options.title
		if Title:FindFirstChild("TitleIcon") then
			Title.TitleIcon.Visible = false
		end
	else
		local TitleIcon = Title:FindFirstChild("TitleIcon")
		if not TitleIcon then
			TitleIcon = Instance.new("ImageLabel")
			TitleIcon.Name = "TitleIcon"
			TitleIcon.Parent = Title
			TitleIcon.BackgroundTransparency = 1
			TitleIcon.Size = UDim2.new(0, 51, 0, 51)
			TitleIcon.Position = UDim2.new(0, -9, 0.5, 0)
			TitleIcon.AnchorPoint = Vector2.new(0, 0.5)
			TitleIcon.ScaleType = Enum.ScaleType.Fit
		end

		TitleIcon.Image = options.iconTitle
		TitleIcon.Visible = true
		TitleIcon.ImageColor3 = Library.Theme.PrimaryTextColor
		Title.Text = "       " .. options.title

		-- Register icon to theme system
		Theme:registerToObjects({
			{ object = TitleIcon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
		})

		if options.rainbowIcon then
			createNaturalRainbowEffect(TitleIcon)
		end
	end

	Glow.Size = UDim2.fromOffset(options.sizeX, options.sizeY)
end

function Library:createAddons(text, imageButton, scrollingFrame, additionalAddons)
	local Addon = Assets.Elements.Addons:Clone()
	Addon.Size = UDim2.fromOffset(scrollingFrame.AbsoluteSize.X * 0.5, Addon.Inner.UIListLayout.AbsoluteContentSize.Y)
	table.insert(self.Addons, Addon)

	local Inner = Addon.Inner

	local TextLabel = Inner.TextLabel
	TextLabel.Text = text .. " Addons"

	local PopupContext = Utility:validateContext({
		Popup = { Value = Addon, ExpectedType = "Instance" },
		Target = { Value = imageButton, ExpectedType = "Instance" },
		Library = { Value = Library, ExpectedType = "table" },
		TransparentObjects = { Value = Utility:getTransparentObjects(Addon), ExpectedType = "table" },
		ScrollingFrame = { Value = scrollingFrame, ExpectedType = "Instance" },
		Popups = { Value = Popups, ExpectedType = "Instance" },
		Inner = { Value = Inner, ExpectedType = "Instance" },
		PositionPadding = { Value = 18 + 7, ExpectedType = "number" },
		SizePadding = { Value = 30, ExpectedType = "number" },
	})

	Theme:registerToObjects({
		{ object = Addon, property = "BackgroundColor3", theme = { "Line" } },
		{ object = Inner, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = TextLabel, property = "TextColor3", theme = { "PrimaryTextColor" } },
	})

	local Popup = Modules.Popup.new(PopupContext)
	imageButton.MouseButton1Down:Connect(Popup:togglePopup())
	Popup:hidePopupOnClickingOutside()

	local DefaultAddons = {
		createToggle = function(self, options)
			Library:createToggle(options, Addon.Inner, scrollingFrame)
		end,

		createSlider = function(self, options)
			Library:createSlider(options, Addon.Inner, scrollingFrame)
		end,

		createDropdown = function(self, options)
			options.default = {}
			Library:createDropdown(options, Addon.Inner, scrollingFrame)
		end,

		createPicker = function(self, options)
			Library:createPicker(options, Addon.Inner, scrollingFrame, true)
		end,

		createKeybind = function(self, options)
			Library:createKeybind(options, Addon.Inner, scrollingFrame)
		end,

		createButton = function(self, options)
			Library:createButton(options, Addon.Inner, scrollingFrame)
		end,

		createTextBox = function(self, options)
			Library:createTextBox(options, Addon.Inner, scrollingFrame)
		end,
	}

	for key, value in pairs(additionalAddons or {}) do
		DefaultAddons[key] = value
	end

	return setmetatable({}, {
		__index = function(table, key)
			local originalFunction = DefaultAddons[key]

			if type(originalFunction) == "function" then
				return function(...)
					if string.match(key, "create") then
						if Addon.Parent == nil then
							Addon.Parent = Popups
						end

						imageButton.Visible = true
					end

					return originalFunction(...), Popup:updateTransparentObjects(Addon)
				end
			else
				return originalFunction
			end
		end,

		__newindex = function(table, key, value)
			DefaultAddons[key] = value
		end,
	})
end

function Library:destroy()
	setMouseCursorVisibility(false)

	for _, rbxSignals in ipairs(Connections) do
		rbxSignals:Disconnect()
	end
	task.wait(0.1)
	ScreenGui:Destroy()
end

function Library:createLabel(options: table)
	Utility:validateOptions(options, {
		text = { Default = "Main", ExpectedType = "string" },
	})

	options.text = string.upper(options.text)

	local ScrollingFrame = Background.Tabs.Frame.ScrollingFrame

	local Line = Assets.Tabs.Line:Clone()
	Line.Visible = true
	Line.BackgroundColor3 = Theme.Line
	Line.Parent = ScrollingFrame

	local TextLabel = Assets.Tabs.TextLabel:Clone()
	TextLabel.Visible = true
	TextLabel.Text = options.text
	TextLabel.Parent = ScrollingFrame

	for _, line in ipairs(ScrollingFrame:GetChildren()) do
		if line.Name ~= "Line" then
			continue
		end

		self.lineIndex += 1

		if self.lineIndex == 1 then
			line:Destroy()
		end
	end

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Line, property = "BackgroundColor3", theme = { "Line" } },
	})
end

function Library:createTab(options: table)
	Utility:validateOptions(options, {
		text = { Default = "Tab", ExpectedType = "string" },
		icon = { Default = "124718082122263", ExpectedType = "string" },
	})

	Background.Tabs.Size = UDim2.new(0, Library.tabSizeX, 1, 0)
	Background.Pages.Size = UDim2.new(1, -Library.tabSizeX, 1, 0)

	local ScrollingFrame = Background.Tabs.Frame.ScrollingFrame

	local Tab = Assets.Tabs.Tab:Clone()
	Tab.Visible = true
	Tab.Parent = ScrollingFrame

	local ImageButton = Tab.ImageButton
	ImageButton.Modal = true

	local Icon = ImageButton.Icon
	Icon.Image = "rbxassetid://" .. options.icon

	local TextButton = ImageButton.TextButton
	TextButton.Text = options.text

	local Page = Assets.Pages.Page:Clone()
	Page.Parent = Background.Pages

	local Frame = Page.Frame
	local PageLine = Frame.Line

	local CurrentTabLabel = Frame.CurrentTabLabel
	CurrentTabLabel.Text = options.text
	CurrentTabLabel.TextColor3 = Theme.PrimaryTextColor

	local SubTabs = Page.SubTabs
	local SubLine = SubTabs.Line

	local function tweenTabAssets(
		tab: Instance,
		icon: Instance,
		textButton: Instance,
		color: textColor3,
		backgroundColor3: Color3,
		backgroundTransparency: number,
		textTransparency: number,
		imageTransparency: number
	)
		Utility:tween(
			tab,
			{ BackgroundColor3 = backgroundColor3, BackgroundTransparency = backgroundTransparency },
			0.25,
			"Back",
			"Out"
		):Play()
		Utility:tween(textButton, { TextColor3 = color, TextTransparency = textTransparency }, 0.2, "Quart", "Out")
			:Play()
		task.delay(0.03, function()
			Utility:tween(icon, { ImageTransparency = imageTransparency, ImageColor3 = color }, 0.25, "Quart", "Out")
				:Play()
		end)
	end

	local function fadeAnimation()
		local function tweenFadeAndPage(
			fade: Instance,
			backgroundTransparency: number,
			textTransparency: number,
			paddingY: number
		)
			Utility:tween(fade, { BackgroundTransparency = backgroundTransparency }, 0.3, "Quint", "Out"):Play()
			Utility:tween(CurrentTabLabel.UIPadding, { PaddingBottom = UDim.new(0, paddingY) }, 0.3, "Back", "Out")
				:Play()
		end

		for _, subPage in ipairs(Page:GetChildren()) do
			if subPage.Name == "SubPage" and subPage.Visible and subPage:FindFirstChild("ScrollingFrame") then
				Utility:tween(subPage.ScrollingFrame.UIPadding, { PaddingTop = UDim.new(0, 6) }, 0.15, "Quart", "Out")
					:Play()

				task.delay(0.15, function()
					Utility
						:tween(subPage.ScrollingFrame.UIPadding, { PaddingTop = UDim.new(0, 0) }, 0.25, "Back", "Out")
						:Play()
				end)
			end
		end

		local Fade = Assets.Pages.Fade:Clone()
		Fade.BackgroundTransparency = 1
		Fade.Visible = true
		Fade.Parent = Background.Pages

		tweenFadeAndPage(Fade, 0, 1, 10)

		task.delay(0.3, function()
			tweenFadeAndPage(Fade, 1, 0, 0)
			task.wait(0.3)
			Fade:Destroy()
		end)
	end

	local Context = Utility:validateContext({
		Page = { Value = Page, ExpectedType = "Instance" },
		Pages = { Value = Background.Pages, ExpectedType = "Instance" },
		Popups = { Value = Popups, ExpectedType = "Instance" },
		ScrollingFrame = { Value = Background.Tabs.Frame.ScrollingFrame, ExpectedType = "Instance" },
		animation = { Value = fadeAnimation, ExpectedType = "function" },

		tweenTabOn = {
			Value = function()
				tweenTabAssets(Tab, Icon, TextButton, Theme.PrimaryColor, Theme.TabBackgroundColor, 0, 0, 0)
			end,
			ExpectedType = "function",
		},

		tweenTabsOff = {
			Value = function(tab)
				tweenTabAssets(
					tab,
					tab.ImageButton.Icon,
					tab.ImageButton.TextButton,
					Theme.SecondaryTextColor,
					Theme.TabBackgroundColor,
					1,
					0,
					0
				)
			end,
			ExpectedType = "function",
		},

		hoverOn = {
			Value = function()
				tweenTabAssets(Tab, Icon, TextButton, Theme.PrimaryColor, Theme.TabBackgroundColor, 0.16, 0.3, 0.3)
			end,
			ExpectedType = "function",
		},

		hoverOff = {
			Value = function()
				tweenTabAssets(Tab, Icon, TextButton, Theme.SecondaryTextColor, Theme.TabBackgroundColor, 1, 0, 0)
			end,
			ExpectedType = "function",
		},
	})

	local Navigation = Modules.Navigation.new(Context)

	if not self.firstTabDebounce then
		Navigation:enableFirstTab()
		self.firstTabDebounce = true
	end

	ScrollingFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ScrollingFrame.CanvasSize = UDim2.new(
			0,
			0,
			0,
			ScrollingFrame.UIListLayout.AbsoluteContentSize.Y + ScrollingFrame.UIListLayout.Padding.Offset
		)
	end)

	ImageButton.MouseButton1Down:Connect(Navigation:selectTab())
	Icon.MouseButton1Down:Connect(Navigation:selectTab())
	TextButton.MouseButton1Down:Connect(Navigation:selectTab())
	ImageButton.MouseEnter:Connect(Navigation:hoverEffect(true))
	ImageButton.MouseLeave:Connect(Navigation:hoverEffect(false))

	Theme:registerToObjects({
		{ object = Tab, property = "BackgroundColor3", theme = { "TabBackgroundColor" } },
		{ object = Icon, property = "ImageColor3", theme = { "SecondaryTextColor", "PrimaryColor" } },
		{ object = TextButton, property = "TextColor3", theme = { "SecondaryTextColor", "PrimaryColor" } },
		{ object = Frame, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = SubTabs, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = PageLine, property = "BackgroundColor3", theme = { "Line" } },
		{ object = SubLine, property = "BackgroundColor3", theme = { "Line" } },
		{ object = CurrentTabLabel, property = "TextColor3", theme = { "PrimaryTextColor" } },
	}, "Tab")

	local PassingContext = setmetatable({ Page = Page }, Library)
	return PassingContext
end

function Library:createSubTab(options: table)
	Utility:validateOptions(options, {
		sectionStyle = { Default = "Double", ExpectedType = "string" },
		text = { Default = "SubTab", ExpectedType = "string" },
	})

	local Moveable = self.Page.SubTabs.Frame.Moveable
	local Underline, ScrollingFrame = Moveable.Underline, Moveable.Parent.ScrollingFrame

	local SubPage = Assets.Pages.SubPage:Clone()
	SubPage.Parent = self.Page

	local Left, Right = SubPage.ScrollingFrame.Left, SubPage.ScrollingFrame.Right

	local SubTab = Assets.Pages.SubTab:Clone()
	SubTab.Visible = true
	SubTab.Text = options.text
	SubTab.TextColor3 = Theme.SecondaryTextColor
	SubTab.Parent = ScrollingFrame

	SubTab.Size =
		UDim2.new(0, TextService:GetTextSize(options.text, 15, Enum.Font.MontserratMedium, SubTab.AbsoluteSize).X, 1, 0)

	local subTabIndex, subTabPosition = 0, 0

	for index, subTab in ipairs(ScrollingFrame:GetChildren()) do
		if subTab.Name ~= "SubTab" then
			continue
		end

		subTabIndex += 1

		if subTabIndex == 1 then
			subTabPosition = 0
		else
			local condition, object = Utility:lookBeforeChildOfObject(index, ScrollingFrame, "SubTab")
			subTabPosition += subTab.Size.X.Offset + ScrollingFrame.UIListLayout.Padding.Offset

			if condition then
				subTabPosition -= (subTab.Size.X.Offset - object.Size.X.Offset)
			end
		end
	end

	local function tweenSubTabAssets(
		subTab,
		underline,
		textColor,
		textTransparency: number,
		disableUnderlineTween: boolean
	)
		Utility:tween(subTab, { TextColor3 = textColor, TextTransparency = textTransparency }, 0.2, "Quart", "Out")
			:Play()

		if not disableUnderlineTween then
			Utility:tween(underline, {
				BackgroundColor3 = Theme.PrimaryColor,
				Position = UDim2.new(0, subTabPosition, 1, 0),
				Size = UDim2.new(0, subTab.Size.X.Offset, 0, 2),
			}, 0.3, "Back", "Out"):Play()
		end
	end

	local function autoCanvasSizeSubPageScrollingFrame()
		local max = math.max(Left.UIListLayout.AbsoluteContentSize.Y, Right.UIListLayout.AbsoluteContentSize.Y)
		SubPage.ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, max)
	end

	local function updateSectionAnimation()
		Utility:tween(SubPage.ScrollingFrame.UIPadding, { PaddingTop = UDim.new(0, 10) }, 0.2, "Quart", "Out"):Play()

		task.delay(0.2, function()
			Utility:tween(SubPage.ScrollingFrame.UIPadding, { PaddingTop = UDim.new(0, 0) }, 0.2, "Quart", "Out"):Play()
		end)
	end

	local Context = Utility:validateContext({
		Page = { Value = SubPage, ExpectedType = "Instance" },
		Pages = { Value = self.Page, ExpectedType = "Instance" },
		Popups = { Value = Popups, ExpectedType = "Instance" },
		ScrollingFrame = { Value = ScrollingFrame, ExpectedType = "Instance" },
		animation = { Value = updateSectionAnimation, ExpectedType = "function" },

		tweenTabOn = {
			Value = function()
				tweenSubTabAssets(SubTab, Underline, Theme.PrimaryColor, 0, false)
			end,
			ExpectedType = "function",
		},

		tweenTabsOff = {
			Value = function(subTab)
				tweenSubTabAssets(subTab, Underline, Theme.SecondaryTextColor, 0, true)
			end,
			ExpectedType = "function",
		},

		hoverOn = {
			Value = function()
				tweenSubTabAssets(SubTab, Underline, Theme.PrimaryColor, 0.3, true)
			end,
			ExpectedType = "function",
		},

		hoverOff = {
			Value = function()
				tweenSubTabAssets(SubTab, Underline, Theme.SecondaryTextColor, 0, true)
			end,
			ExpectedType = "function",
		},
	})

	local Navigation = Modules.Navigation.new(Context)

	if not self.firstSubTabDebounce then
		Navigation:enableFirstTab()
		self.firstSubTabDebounce = true
	end

	Left.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(autoCanvasSizeSubPageScrollingFrame)
	Right.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(autoCanvasSizeSubPageScrollingFrame)

	SubTab.MouseButton1Down:Connect(Navigation:selectTab())
	SubTab.MouseEnter:Connect(Navigation:hoverEffect(true))
	SubTab.MouseLeave:Connect(Navigation:hoverEffect(false))

	Theme:registerToObjects({
		{ object = Underline, property = "BackgroundColor3", theme = { "PrimaryColor" } },
		{ object = SubTab, property = "TextColor3", theme = { "SecondaryTextColor", "PrimaryColor" } },
		{ object = SubPage.ScrollingFrame, property = "ScrollBarImageColor3", theme = { "ScrollingBarImageColor" } },
	}, "SubTab")

	local PassingContext = setmetatable({ Left = Left, Right = Right, sectionStyle = options.sectionStyle }, Library)
	return PassingContext
end

function Library:createSection(options: table)
	Utility:validateOptions(options, {
		text = { Default = "Section", ExpectedType = "string" },
		position = { Default = "Left", ExpectedType = "string" },
	})

	local Section = Assets.Pages.Section:Clone()
	Section.Visible = true
	Section.Parent = self[options.position]

	local screenSize = workspace.CurrentCamera.ViewportSize
	if self.sectionStyle == "Single" or (screenSize.X <= 740 and screenSize.Y <= 590) or self.sizeX <= 660 then
		if options.position == "Right" then
			table.insert(
				self.SectionFolder.Right,
				{ folders = { Left = self.Left, Right = self.Right }, object = Section }
			)
		end

		self.Right.Visible = false
		self.Left.Size = UDim2.fromScale(1, 1)
		Section.Parent = self.Left
	end

	if options.position == "Right" and self.sectionStyle ~= "Single" then
		table.insert(self.SectionFolder.Right, { folders = { Left = self.Left, Right = self.Right }, object = Section })
	end

	if options.position == "Left" and self.sectionStyle ~= "Single" then
		table.insert(self.SectionFolder.Left, { folders = { Left = self.Left, Right = self.Right }, object = Section })
	end

	local Inner = Section.Inner

	local TextLabel = Inner.TextLabel
	TextLabel.Text = options.text

	Section.Inner.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Section.Size = UDim2.new(1, 0, 0, Section.Inner.UIListLayout.AbsoluteContentSize.Y + 28)
	end)

	Theme:registerToObjects({
		{ object = Section, property = "BackgroundColor3", theme = { "Line" } },
		{ object = Inner, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = TextLabel, property = "TextColor3", theme = { "PrimaryTextColor" } },
	})

	local PassingContext = setmetatable({ Section = Inner, ScrollingFrame = Section.Parent.Parent }, Library)
	return PassingContext
end

function Library:createToggle(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Toggle", ExpectedType = "string" },
		state = { Default = false, ExpectedType = "boolean" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Toggle = Assets.Elements.Toggle:Clone()
	Toggle.Visible = true
	Toggle.Parent = parent or self.Section
	local TextLabel = Toggle.TextLabel
	TextLabel.Text = options.text

	local ImageButton = TextLabel.ImageButton
	local TextButton = TextLabel.TextButton
	local Background = TextButton.Background
	local Circle = Background.Circle

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local function tweenToggleAssets(
		backgroundColor: Color3,
		circleColor: Color3,
		anchorPoint: Vector2,
		position: UDim2
	)
		Utility:tween(Background, { BackgroundColor3 = backgroundColor }, 0.25, "Quart", "Out"):Play()
		Utility:tween(
			Circle,
			{ BackgroundColor3 = circleColor, AnchorPoint = anchorPoint, Position = position },
			0.3,
			"Back",
			"Out"
		):Play()
	end

	local circleOn = false

	local Context = Utility:validateContext({
		state = { Value = options.state, ExpectedType = "boolean" },
		callback = { Value = options.callback, ExpectedType = "function" },

		switchOff = {
			Value = function()
				tweenToggleAssets(
					Theme.SecondaryBackgroundColor,
					Theme.PrimaryBackgroundColor,
					Vector2.new(0, 0.5),
					UDim2.fromScale(0, 0.5)
				)
				circleOn = false
			end,
			ExpectedType = "function",
		},

		switchOn = {
			Value = function()
				tweenToggleAssets(
					Theme.PrimaryColor,
					Theme.TertiaryBackgroundColor,
					Vector2.new(1, 0.5),
					UDim2.fromScale(1, 0.5)
				)
				circleOn = true
			end,
			ExpectedType = "function",
		},
	})

	local Toggle = Modules.Toggle.new(Context)
	Toggle:updateState({ state = options.state })
	TextButton.MouseButton1Down:Connect(Toggle:switch())

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Background, property = "BackgroundColor3", theme = { "PrimaryColor", "SecondaryBackgroundColor" } },
		{
			object = Circle,
			property = "BackgroundColor3",
			theme = { "TertiaryBackgroundColor", "PrimaryBackgroundColor" },
			circleOn = circleOn,
		},
		{ object = ImageButton, property = "ImageColor3", theme = { "PrimaryColor" } },
	})

	shared.Flags.Toggle[options.text] = {
		getState = function(self)
			return Context.state
		end,

		updateState = function(self, options: table)
			Toggle:updateState(options)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getState = function(self)
			return Context.state
		end,

		updateState = function(self, options: table)
			Toggle:updateState(options)
		end,
	})
end

function Library:createSlider(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Slider", ExpectedType = "string" },
		min = { Default = 0, ExpectedType = "number" },
		max = { Default = 100, ExpectedType = "number" },
		step = { Default = 1, ExpectedType = "number" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	options.default = options.default or options.min
	options.value = options.default
	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Slider = Assets.Elements.Slider:Clone()
	Slider.Visible = true
	Slider.Parent = parent or self.Section
	local TextLabel = Slider.TextButton.TextLabel
	local ImageButton = TextLabel.ImageButton
	local TextBox = TextLabel.TextBox

	local Line = Slider.Line
	local TextButton = Slider.TextButton
	local Fill = Line.Fill

	local TextLabel = TextButton.TextLabel
	TextLabel.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local Circle = Fill.Circle
	local InnerCircle = Circle.InnerCircle
	local CurrentValueLabel = Circle.TextButton.CurrentValueLabel

	local function tweenSliderInfoAssets(transparency: number)
		local TextBoundsX = math.clamp(CurrentValueLabel.TextBounds.X + 14, 10, 200)
		local easing = transparency == 0 and "Back" or "Quart"
		Utility:tween(CurrentValueLabel, {
			Size = UDim2.fromOffset(TextBoundsX, 20),
			BackgroundTransparency = transparency,
			TextTransparency = transparency,
		}, 0.2, easing, "Out"):Play()
	end

	local Context = Utility:validateContext({
		min = { Value = options.min, ExpectedType = "number" },
		max = { Value = options.max, ExpectedType = "number" },
		step = { Value = options.step, ExpectedType = "number" },
		value = { Value = options.default, ExpectedType = "number" },
		callback = { Value = options.callback, ExpectedType = "function" },
		Line = { Value = Line, ExpectedType = "Instance" },
		TextBox = { Value = TextLabel.TextBox, ExpectedType = "Instance" },
		Library = { Value = Library, ExpectedType = "table" },
		CurrentValueLabel = { Value = CurrentValueLabel, ExpectedType = "Instance" },
		Connections = { Value = Connections, ExpectedType = "table" },

		autoSizeTextBox = {
			Value = function()
				local TextBoundsX = math.clamp(TextLabel.TextBox.TextBounds.X + 14, 10, 200)
				Utility:tween(TextLabel.TextBox, { Size = UDim2.fromOffset(TextBoundsX, 20) }, 0.2, "Quart", "Out")
					:Play()
			end,
			ExpectedType = "function",
		},

		updateFill = {
			Value = function(sizeX)
				Utility:tween(Line.Fill, { Size = UDim2.fromScale(sizeX, 1) }, 0.2, "Quart", "Out"):Play()
			end,
			ExpectedType = "function",
		},

		showInfo = {
			Value = function()
				tweenSliderInfoAssets(0)
			end,
			ExpectedType = "function",
		},

		dontShowInfo = {
			Value = function()
				tweenSliderInfoAssets(1)
			end,
			ExpectedType = "function",
		},
	})

	local Slider = Modules.Slider.new(Context)
	Slider:handleSlider()

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Line, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = Fill, property = "BackgroundColor3", theme = { "PrimaryColor" } },
		{ object = Circle, property = "BackgroundColor3", theme = { "PrimaryColor" } },
		{ object = ImageButton, property = "ImageColor3", theme = { "PrimaryColor" } },
		{ object = TextBox, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = TextBox, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = CurrentValueLabel, property = "TextColor3", theme = { "TertiaryBackgroundColor" } },
		{ object = CurrentValueLabel, property = "BackgroundColor3", theme = { "PrimaryColor" } },
		{ object = InnerCircle, property = "BackgroundColor3", theme = { "TertiaryBackgroundColor" } },
	})

	Fill.BackgroundColor3 = Theme.PrimaryColor
	Circle.BackgroundColor3 = Theme.PrimaryColor
	InnerCircle.BackgroundColor3 = Theme.TertiaryBackgroundColor
	CurrentValueLabel.BackgroundColor3 = Theme.PrimaryColor

	shared.Flags.Slider[options.text] = {
		getValue = function(self)
			return Context.value
		end,

		updateValue = function(self, options: table)
			Slider:updateValue(options)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getValue = function(self)
			return Context.value
		end,

		updateValue = function(self, options: table)
			Slider:updateValue(options)
		end,
	})
end

function Library:createPicker(options: table, parent, scrollingFrame, isPickerBoolean)
	Utility:validateOptions(options, {
		text = { Default = "Picker", ExpectedType = "string" },
		default = { Default = Color3.fromRGB(255, 0, 0), ExpectedType = "Color3" },
		color = { Default = Color3.fromRGB(255, 0, 0), ExpectedType = "Color3" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	isPickerBoolean = isPickerBoolean or false
	options.color = options.default
	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Picker = Assets.Elements.Picker:Clone()
	Picker.Visible = true
	Picker.Parent = parent or self.Section
	local TextLabel = Picker.TextLabel
	TextLabel.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local ImageButton = TextLabel.ImageButton
	local Background = TextLabel.Background
	local TextButton = Background.TextButton

	local ColorPicker = Assets.Elements.ColorPicker:Clone()
	ColorPicker.Parent = Popups

	local ColorPickerTransparentObjects = Utility:getTransparentObjects(ColorPicker)

	for _, data in ipairs(ColorPickerTransparentObjects) do
		data.object[data.property] = 1
	end

	local Inner = ColorPicker.Inner
	local HSV = Inner.HSV
	local Slider = Inner.Slider
	local Submit = Inner.Submit
	local Hex = Inner.HexAndRGB.Hex
	local RGB = Inner.HexAndRGB.RGB

	local PopupContext = Utility:validateContext({
		Popup = { Value = ColorPicker, ExpectedType = "Instance" },
		Target = { Value = Background, ExpectedType = "Instance" },
		Library = { Value = Library, ExpectedType = "table" },
		TransparentObjects = { Value = ColorPickerTransparentObjects, ExpectedType = "table" },
		Popups = { Value = Popups, ExpectedType = "Instance" },
		isPicker = { Value = isPickerBoolean, ExpectedType = "boolean" },
		ScrollingFrame = { Value = scrollingFrame, ExpectedType = "Instance" },
		PositionPadding = { Value = 18 + 7, ExpectedType = "number" },
		Connections = { Value = Connections, ExpectedType = "table" },
		SizePadding = { Value = 14, ExpectedType = "number" },
	})

	local Popup = Modules.Popup.new(PopupContext)
	TextButton.MouseButton1Down:Connect(Popup:togglePopup())
	Popup:hidePopupOnClickingOutside()

	local ColorPickerContext =
		Utility:validateContext({
			ColorPicker = { Value = ColorPicker, ExpectedType = "Instance" },
			Hex = { Value = Hex, ExpectedType = "Instance" },
			RGB = { Value = RGB, ExpectedType = "Instance" },
			Slider = { Value = Slider, ExpectedType = "Instance" },
			HSV = { Value = HSV, ExpectedType = "Instance" },
			Submit = { Value = Submit, ExpectedType = "Instance" },
			Background = { Value = Background, ExpectedType = "Instance" },
			Connections = { Value = Connections, ExpectedType = "table" },
			color = { Value = options.color, ExpectedType = "Color3" },
			callback = { Value = options.callback, ExpectedType = "function" },

			submitAnimation = {
				Value = function()
					Utility:tween(Submit.TextLabel, { BackgroundTransparency = 0 }, 0.2, "Quart", "Out"):Play()
					Utility:tween(
						Submit.TextLabel,
						{ TextColor3 = Theme.PrimaryColor, TextTransparency = 0 },
						0.2,
						"Quart",
						"Out"
					):Play()

					task.delay(0.2, function()
						Utility:tween(
							Submit.TextLabel,
							{ TextColor3 = Theme.SecondaryTextColor, TextTransparency = 0 },
							0.2,
							"Quart",
							"Out"
						):Play()
						Utility:tween(Submit.TextLabel, { BackgroundTransparency = 0.3 }, 0.2, "Quart", "Out"):Play()
					end)
				end,
				ExpectedType = "function",
			},

			hoveringOn = {
				Value = function()
					Utility:tween(Submit.TextLabel, { BackgroundTransparency = 0.3 }, 0.2, "Quart", "Out"):Play()
					Utility:tween(
						Submit.TextLabel,
						{ TextColor3 = Theme.PrimaryColor, TextTransparency = 0.3 },
						0.2,
						"Quart",
						"Out"
					):Play()
				end,
				ExpectedType = "function",
			},

			hoveringOff = {
				Value = function()
					Utility:tween(Submit.TextLabel, { BackgroundTransparency = 0 }, 0.2, "Quart", "Out"):Play()
					Utility:tween(
						Submit.TextLabel,
						{ TextColor3 = Theme.SecondaryTextColor, TextTransparency = 0 },
						0.2,
						"Quart",
						"Out"
					):Play()
				end,
				ExpectedType = "function",
			},
		})

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = ColorPicker, property = "BackgroundColor3", theme = { "Line" } },
		{ object = ImageButton, property = "ImageColor3", theme = { "PrimaryColor" } },
		{ object = Inner, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = Submit, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = Hex, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = RGB, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = Submit.TextLabel, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
	})

	local ColorPicker = Modules.ColorPicker.new(ColorPickerContext)
	ColorPicker:handleColorPicker()

	shared.Flags.ColorPicker[options.text] = {
		getColor = function(self)
			return ColorPickerContext.color
		end,

		updateColor = function(self, options: table)
			ColorPicker:updateColor(options)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getColor = function(self)
			return ColorPickerContext.color
		end,

		updateColor = function(self, options: table)
			ColorPicker:updateColor(options)
		end,
	})
end

function Library:createDropdown(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Dropdown", ExpectedType = "string" },
		list = { Default = { "Option 1", "Option 2" }, ExpectedType = "table" },
		default = { Default = {}, ExpectedType = "table" },
		multiple = { Default = false, ExpectedType = "boolean" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Dropdown = Assets.Elements.Dropdown:Clone()
	Dropdown.Visible = true
	Dropdown.Parent = parent or self.Section
	local TextLabel = Dropdown.TextLabel
	TextLabel.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local ImageButton = TextLabel.ImageButton
	local Box = Dropdown.Box

	local TextButton = Box.TextButton
	TextButton.Text = table.concat(options.default, ", ")

	if options.default[1] == nil then
		TextButton.Text = "None"
	end

	local List = Dropdown.List
	local Inner = List.Inner
	local DropButtons = Inner.ScrollingFrame
	local Search = Inner.TextBox

	DropButtons.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		DropButtons.CanvasSize =
			UDim2.new(0, 0, 0, DropButtons.UIListLayout.AbsoluteContentSize.Y + Inner.UIListLayout.Padding.Offset)
		DropButtons.Size = UDim2.new(
			1,
			0,
			0,
			math.clamp(DropButtons.UIListLayout.AbsoluteContentSize.Y + Inner.UIListLayout.Padding.Offset, 0, 164)
		)

		if List.Size.Y.Offset > 0 then
			Utility:tween(
				List,
				{ Size = UDim2.new(1, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210)) },
				0.2,
				"Quart",
				"Out"
			):Play()

			for index, value in ipairs(self.DropdownSizes) do
				scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - value.size
				scrollingFrame.CanvasSize = scrollingFrame.CanvasSize
					+ UDim2.new(0, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210))
				table.remove(Library.DropdownSizes, index)
				table.insert(Library.DropdownSizes, {
					object = Dropdown,
					size = UDim2.new(0, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210)),
				})
			end
		end
	end)

	local function toggleList()
		if List.Size.Y.Offset <= 0 then
			Library.dropdownOpen = Library.dropdownOpen + 1
			Library:forceHideTooltip()

			for index, value in ipairs(Library.DropdownSizes) do
				if value.object ~= Dropdown then
					scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - value.size
					table.remove(Library.DropdownSizes, index)
				end
			end

			for _, object in ipairs(scrollingFrame:GetDescendants()) do
				if object.Name == "Section" then
					object.ZIndex = 1
				end
				if object.Name == "List" and object ~= List then
					object.Parent.ZIndex = 1
					Utility:tween(object, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, "Quart", "Out"):Play()
				end
			end

			for _, object in ipairs(Popups:GetDescendants()) do
				if object.Name == "List" and object ~= List then
					object.Parent.ZIndex = 1
					Utility:tween(object, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, "Quart", "Out"):Play()
				end
			end

			Dropdown.ZIndex = 2
			if self.Section then
				self.Section.Parent.ZIndex = 2
			end

			Utility:tween(
				List,
				{ Size = UDim2.new(1, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210)) },
				0.2,
				"Quart",
				"Out"
			):Play()
			table.insert(Library.DropdownSizes, {
				object = Dropdown,
				size = UDim2.new(0, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210)),
			})
			scrollingFrame.CanvasSize = scrollingFrame.CanvasSize
				+ UDim2.new(0, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210))
		else
			Library.dropdownOpen = math.max(0, Library.dropdownOpen - 1)

			Utility:tween(List, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, "Quart", "Out"):Play()
			for index, value in ipairs(Library.DropdownSizes) do
				if value.object == Dropdown then
					scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - value.size
					table.remove(Library.DropdownSizes, index)
				end
			end
		end
	end

	local function createDropButton(value)
		local DropButton = Assets.Elements.DropButton:Clone()
		DropButton.Visible = true
		DropButton.Parent = DropButtons

		local TextButton = DropButton.TextButton
		local Background = TextButton.Background
		local Checkmark = TextButton.Checkmark

		local TextLabel = DropButton.TextLabel
		TextLabel.Text = tostring(value)

		Theme:registerToObjects({
			{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
			{
				object = Background,
				property = "BackgroundColor3",
				theme = { "PrimaryColor", "SecondaryBackgroundColor" },
			},
			{ object = Checkmark, property = "ImageColor3", theme = { "TertiaryBackgroundColor" } },
		})

		return TextButton
	end

	local function tweenDropButton(dropButton: Instance, backgroundColor: Color3, imageTransparency: number)
		Utility:tween(dropButton.Background, { BackgroundColor3 = backgroundColor }, 0.2, "Quart", "Out"):Play()
		Utility:tween(dropButton.Checkmark, { ImageTransparency = imageTransparency }, 0.2, "Quart", "Out"):Play()
	end

	local Context = Utility:validateContext({
		text = { Value = options.text, ExpectedType = "string" },
		default = { Value = options.default, ExpectedType = "table" },
		list = { Value = options.list, ExpectedType = "table" },
		callback = { Value = options.callback, ExpectedType = "function" },
		TextButton = { Value = TextButton, ExpectedType = "Instance" },
		DropButtons = { Value = DropButtons, ExpectedType = "Instance" },
		createDropButton = { Value = createDropButton, ExpectedType = "function" },
		ScrollingFrame = { Value = scrollingFrame, ExpectedType = "Instance" },
		multiple = { Value = options.multiple, ExpectedType = "boolean" },

		tweenDropButtonOn = {
			Value = function(dropButton)
				tweenDropButton(dropButton, Theme.PrimaryColor, 0)
			end,
			ExpectedType = "function",
		},

		tweenDropButtonOff = {
			Value = function(dropButton)
				tweenDropButton(dropButton, Theme.SecondaryBackgroundColor, 1)
			end,
			ExpectedType = "function",
		},
	})

	TextButton.MouseButton1Down:Connect(toggleList)

	Search:GetPropertyChangedSignal("Text"):Connect(function()
		for _, dropButton in ipairs(DropButtons:GetChildren()) do
			if not dropButton:IsA("Frame") then
				continue
			end

			if
				Search.Text == "" or string.match(string.lower(dropButton.TextLabel.Text), string.lower(Search.Text))
			then
				dropButton.Visible = true
			else
				dropButton.Visible = false
			end
		end
	end)

	local Dropdown = Modules.Dropdown.new(Context)
	Dropdown:handleDropdown()

	Theme:registerToObjects({
		{ object = ImageButton, property = "ImageColor3", theme = { "PrimaryColor" } },
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Box, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = TextButton, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = List, property = "BackgroundColor3", theme = { "Line" } },
		{ object = Inner, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = Search, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Search, property = "PlaceholderColor3", theme = { "SecondaryTextColor" } },
		{ object = Search, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = Search.Parent, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
	})

	List.BackgroundColor3 = Theme.Line
	Inner.BackgroundColor3 = Theme.PrimaryBackgroundColor
	Box.BackgroundColor3 = Theme.SecondaryBackgroundColor
	Search.BackgroundColor3 = Theme.SecondaryBackgroundColor

	shared.Flags.Dropdown[options.text] = {
		getList = function()
			return Context.list
		end,

		getValue = function()
			return Dropdown:getValue()
		end,

		updateList = function(self, options: table)
			Dropdown:updateList(options)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getList = function()
			return Context.list
		end,

		getValue = function()
			return Dropdown:getValue()
		end,

		updateList = function(self, options: table)
			Dropdown:updateList(options)
		end,
	})
end

function Library:createKeybind(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Keybind", ExpectedType = "string" },
		default = { Default = "None", ExpectedType = "string" },
		onHeld = { Default = false, ExpectedType = "boolean" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Keybind = Assets.Elements.Keybind:Clone()
	Keybind.Visible = true
	Keybind.Parent = parent or self.Section
	local TextLabel = Keybind.TextLabel
	TextLabel.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local ImageButton = TextLabel.ImageButton
	local Background = TextLabel.Background

	local TextButton = Background.TextButton

	TextButton.Text = options.default

	local Context = Utility:validateContext({
		default = { Value = options.default, ExpectedType = "string" },
		callback = { Value = options.callback, ExpectedType = "function" },
		Background = { Value = TextButton.Parent, ExpectedType = "Instance" },
		TextButton = { Value = TextButton, ExpectedType = "Instance" },
		Connections = { Value = Connections, ExpectedType = "table" },
		Library = { Value = Library, ExpectedType = "table" },
		onHeld = { Value = options.onHeld, ExpectedType = "boolean" },
		Exclusions = { Value = Exclusions, ExpectedType = "table" },

		autoSizeBackground = {
			Value = function()
				local TextBoundsX = math.clamp(TextButton.TextBounds.X + 14, 10, 200)
				Utility:tween(TextButton.Parent, { Size = UDim2.fromOffset(TextBoundsX, 20) }, 0.2, "Quart", "Out")
					:Play()
			end,
			ExpectedType = "function",
		},
	})

	local Keybind = Modules.Keybind.new(Context)
	Keybind:handleKeybind()

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = ImageButton, property = "ImageColor3", theme = { "PrimaryColor" } },
		{ object = Background, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = TextButton, property = "TextColor3", theme = { "SecondaryTextColor" } },
	})

	shared.Flags.Keybind[options.text] = {
		getKeybind = function(self)
			return TextButton.Text
		end,

		updateKeybind = function(self, options: table)
			Keybind:updateKeybind(options)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getKeybind = function(self)
			return TextButton.Text
		end,

		updateKeybind = function(self, options: table)
			Keybind:updateKeybind(options)
		end,
	})
end

function Library:createButton(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Button", ExpectedType = "string" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local Button = Assets.Elements.Button:Clone()
	Button.Visible = true
	Button.Parent = parent or self.Section
	local Background = Button.Background

	local TextButton = Background.TextButton
	TextButton.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextButton.MouseEnter:Connect(function()
			Library:showTooltip(TextButton, options.tooltip)
		end)
		TextButton.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	TextButton.MouseButton1Down:Connect(function()
		Utility:tween(Background, { BackgroundTransparency = 0, Size = UDim2.new(1, 0, 1, -2) }, 0.08, "Quart", "Out")
			:Play()
		Utility:tween(TextButton, { TextColor3 = Theme.PrimaryColor, TextTransparency = 0 }, 0.08, "Quart", "Out")
			:Play()

		task.delay(0.08, function()
			Utility
				:tween(Background, { BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 1, 0) }, 0.2, "Back", "Out")
				:Play()
			Utility
				:tween(TextButton, { TextColor3 = Theme.SecondaryTextColor, TextTransparency = 0 }, 0.2, "Quart", "Out")
				:Play()
		end)

		options.callback()
	end)

	Background.MouseEnter:Connect(function(input)
		Utility:tween(Background, { BackgroundTransparency = 0.3 }, 0.12, "Quart", "Out"):Play()
		Utility:tween(TextButton, { TextColor3 = Theme.PrimaryColor, TextTransparency = 0.3 }, 0.12, "Quart", "Out")
			:Play()
	end)

	Background.MouseLeave:Connect(function()
		Utility:tween(Background, { BackgroundTransparency = 0 }, 0.15, "Quart", "Out"):Play()
		Utility:tween(TextButton, { TextColor3 = Theme.SecondaryTextColor, TextTransparency = 0 }, 0.15, "Quart", "Out")
			:Play()
	end)

	Theme:registerToObjects({
		{ object = Background, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = TextButton, property = "TextColor3", theme = { "SecondaryTextColor" } },
	})
end

function Library:createTextBox(options: table, parent, scrollingFrame)
	Utility:validateOptions(options, {
		text = { Default = "Textbox", ExpectedType = "string" },
		default = { Default = "", ExpectedType = "string" },
		callback = { Default = function() end, ExpectedType = "function" },
		tooltip = { Default = "", ExpectedType = "string" },
	})

	scrollingFrame = self.ScrollingFrame or scrollingFrame

	local TextBox = Assets.Elements.TextBox:Clone()
	TextBox.Visible = true
	TextBox.Parent = parent or self.Section
	local TextLabel = TextBox.TextLabel
	TextLabel.Text = options.text

	if options.tooltip and options.tooltip ~= "" then
		TextLabel.MouseEnter:Connect(function()
			Library:showTooltip(TextLabel, options.tooltip)
		end)
		TextLabel.MouseLeave:Connect(function()
			Library:hideTooltip()
		end)
	end

	local ImageButton = TextLabel.ImageButton

	local Box = TextLabel.TextBox
	Box.Text = options.default

	local Context = Utility:validateContext({
		default = { Value = options.default, ExpectedType = "string" },
		callback = { Value = options.callback, ExpectedType = "function" },
		TextBox = { Value = Box, ExpectedType = "Instance" },

		autoSizeTextBox = {
			Value = function()
				local TextBoundsX = math.clamp(Box.TextBounds.X + 14, 0, 100)
				Utility:tween(Box, { Size = UDim2.fromOffset(TextBoundsX, 20) }, 0.2, "Quart", "Out"):Play()
			end,
			ExpectedType = "function",
		},
	})

	local TextBox = Modules.TextBox.new(Context)
	TextBox:handleTextBox()

	Theme:registerToObjects({
		{ object = TextLabel, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Box, property = "TextColor3", theme = { "SecondaryTextColor" } },
		{ object = Box, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
	})

	shared.Flags.TextBox[options.text] = {
		getText = function(self)
			return Box.Text
		end,

		updateText = function(self, options: table)
			Box.Text = options.text or ""
			Context.callback(Box.Text)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getText = function(self)
			return Box.Text
		end,

		updateText = function(self, options: table)
			Box.Text = options.text or ""
			Context.callback(Box.Text)
		end,
	})
end

local ChildRemoved = false
function Library:notify(options: table)
	Utility:validateOptions(options, {
		title = { Default = "Notification", ExpectedType = "string" },
		text = { Default = "Hello world", ExpectedType = "string" },
		duration = { Default = 3, ExpectedType = "number" },
		maxSizeX = { Default = 300, ExpectedType = "number" },
		scaleX = { Default = 0.165, ExpectedType = "number" },
		sizeY = { Default = 100, ExpectedType = "number" },
	})

	local Notification = Assets.Elements.Notification:Clone()
	Notification.Visible = true
	Notification.Parent = ScreenGui.Notifications
	Notification.Size = UDim2.new(options.scaleX, 0, 0, options.sizeY)
	Notification.UISizeConstraint.MaxSize = Vector2.new(options.maxSizeX, 9e9)

	local Title = Notification.Title
	Title.Text = options.title

	local Body = Notification.Body
	Body.Text = options.text

	local Line = Notification.Line

	local NotificationTransparentObjects = Utility:getTransparentObjects(Notification)

	for _, data in ipairs(NotificationTransparentObjects) do
		data.object[data.property] = 1
	end

	Notification.BackgroundTransparency = 1

	for _, data in ipairs(NotificationTransparentObjects) do
		Utility:tween(data.object, { [data.property] = 0 }, 0.3, "Quint", "Out"):Play()
	end

	Utility:tween(Notification, { ["BackgroundTransparency"] = 0 }, 0.3, "Quint", "Out"):Play()

	local notificationPosition = -24
	local notificationSize = 0
	local PADDING_Y = 14

	for index, notification in ipairs(ScreenGui.Notifications:GetChildren()) do
		if index == 1 then
			notificationSize = notification.AbsoluteSize.Y
			Utility:tween(notification, { Position = UDim2.new(1, -24, 1, notificationPosition) }, 0.2, "Quart", "Out")
				:Play()
			continue
		end

		notificationPosition -= notificationSize + PADDING_Y
		notificationSize = notification.Size.Y.Offset
		Notification.Position = UDim2.new(1, Notification.Position.X.Offset, 1, notificationPosition)
	end

	if not ChildRemoved then
		ScreenGui.Notifications.ChildRemoved:Connect(function(child)
			for index, notification in ipairs(ScreenGui.Notifications:GetChildren()) do
				if index == 1 then
					notificationPosition = -14
					notificationSize = notification.AbsoluteSize.Y
					Utility
						:tween(
							notification,
							{ Position = UDim2.new(1, -24, 1, notificationPosition) },
							0.2,
							"Quart",
							"Out"
						)
						:Play()
					continue
				end

				notificationPosition -= notificationSize + PADDING_Y
				notificationSize = notification.AbsoluteSize.Y
				Utility
					:tween(notification, { Position = UDim2.new(1, -24, 1, notificationPosition) }, 0.2, "Quart", "Out")
					:Play()
			end
		end)

		ChildRemoved = true
	end

	task.delay(options.duration, function()
		if Notification then
			for _, data in ipairs(Utility:getTransparentObjects(Notification)) do
				Utility:tween(data.object, { [data.property] = 1 }, 0.2, "Quart", "Out"):Play()
			end

			Utility:tween(Notification, { ["BackgroundTransparency"] = 1 }, 0.2, "Quart", "Out"):Play()

			task.wait(0.2)
			Notification:Destroy()
		end
	end)

	Utility:tween(Notification, { Position = UDim2.new(1, -24, 1, notificationPosition) }, 0.35, "Back", "Out"):Play()
	task.wait(0.35)

	Theme:registerToObjects({
		{ object = Notification, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
		{ object = Title, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = Title, property = "TextColor3", theme = { "PrimaryTextColor" } },
		{ object = Line, property = "BackgroundColor3", theme = { "Line" } },
		{ object = Body, property = "TextColor3", theme = { "SecondaryTextColor" } },
	})
end

function Library:ToggleUI(state)
	if Library._toggling then
		return
	end

	-- Kill any visible tooltip immediately
	Library:forceHideTooltip()

	local targetVisible
	if typeof(state) == "boolean" then
		targetVisible = state
	else
		targetVisible = not ScreenGui.Enabled
	end

	setMouseCursorVisibility(targetVisible)

	if targetVisible then
		Library._toggling = true
		ScreenGui.Enabled = true
		Glow.Size = UDim2.fromOffset(Library.sizeX * 0.93, Library.sizeY * 0.93)
		Utility:tween(Glow, {
			Size = UDim2.fromOffset(Library.sizeX, Library.sizeY),
		}, 0.3, "Back", "Out"):Play()

		task.delay(0.3, function()
			Library._toggling = false
		end)
	else
		Library._toggling = true
		Utility:tween(Glow, {
			Size = UDim2.fromOffset(Library.sizeX * 0.93, Library.sizeY * 0.93),
		}, 0.15, "Quart", "In"):Play()
		task.delay(0.15, function()
			ScreenGui.Enabled = false
			Glow.Size = UDim2.fromOffset(Library.sizeX, Library.sizeY)
			Library._toggling = false
		end)
	end
end

function Library:createManager(options: table)
	Utility:validateOptions(options, {
		folderName = { Default = "Leny", ExpectedType = "string" },
		icon = { Default = "124718082122263", ExpectedType = "string" },
		apiBaseUrl = { Default = "", ExpectedType = "string" },
	})

	local HttpService = game:GetService("HttpService")
	local exportCooldownUntil = 0
	local THEME_ROOT_FOLDER = "LenyUI"
	local THEME_FOLDER_PATH = THEME_ROOT_FOLDER .. "/Themes"
	local THEME_AUTOLOAD_PATH = THEME_FOLDER_PATH .. "/themeautoload.txt"

	local function getRequestFunction()
		return request or http_request or (syn and syn.request)
	end

	local function resolveApiUrl(path: string)
		if options.apiBaseUrl == "" then
			return path
		end

		if string.sub(options.apiBaseUrl, -1) == "/" and string.sub(path, 1, 1) == "/" then
			return string.sub(options.apiBaseUrl, 1, #options.apiBaseUrl - 1) .. path
		end

		if string.sub(options.apiBaseUrl, -1) ~= "/" and string.sub(path, 1, 1) ~= "/" then
			return options.apiBaseUrl .. "/" .. path
		end

		return options.apiBaseUrl .. path
	end

	local function getHeader(headers: table?, headerName: string)
		for key, value in pairs(headers or {}) do
			if string.lower(tostring(key)) == string.lower(headerName) then
				return value
			end
		end

		return nil
	end

	local function requestApi(method: string, path: string, body: table?)
		local requestFn = getRequestFunction()
		if not requestFn then
			return nil, "No supported request function found (request/http_request/syn.request)."
		end

		local requestData = {
			Url = resolveApiUrl(path),
			Method = method,
			Headers = {
				["Content-Type"] = "application/json",
				["Accept"] = "application/json",
			},
		}

		if body then
			requestData.Body = HttpService:JSONEncode(body)
		end

		local ok, response = pcall(function()
			return requestFn(requestData)
		end)

		if not ok then
			return nil, tostring(response)
		end

		return response, nil
	end

	local function getJsons()
		local jsons = {}
		for _, file in ipairs(listfiles(options.folderName)) do
			if not string.match(file, "Theme") and not string.match(file, "autoload") then
				local fileName = file:match("([^/\\]+)$")
				if fileName then
					fileName = string.gsub(fileName, "%.json$", "")
					table.insert(jsons, fileName)
				end
			end
		end

		return jsons
	end

	local function getThemeJsons()
		local themeJsons = {}
		for _, file in ipairs(listfiles(THEME_FOLDER_PATH)) do
			local fileName = file:match("([^/\\]+)$")
			if fileName and string.match(string.lower(fileName), "%.json$") then
				fileName = string.gsub(fileName, "%.json$", "")
				table.insert(themeJsons, fileName)
			end
		end

		return themeJsons
	end

	-- Function to fetch theme presets from GitHub
	local function getThemePresets()
		local success, result = pcall(function()
			local response = game:HttpGet("https://api.github.com/repos/DontGho/userinterface/contents")
			local decoded = HttpService:JSONDecode(response)
			local presets = {}

			for _, file in ipairs(decoded) do
				if file.type == "file" and string.match(file.name, ".json$") then
					local name = string.gsub(file.name, ".json", "")
					table.insert(presets, name)
				end
			end

			return presets
		end)

		if success then
			return result
		else
			warn("Failed to fetch theme presets from GitHub:", result)
			return {}
		end
	end

	local function getSavedData()
		local SavedData = {
			Dropdown = {},
			Toggle = {},
			Keybind = {},
			Slider = {},
			TextBox = {},
			ColorPicker = {},
		}

		local Excluded = {
			"Line",
			"PrimaryColor",
			"PrimaryTextColor",
			"SecondaryTextColor",
			"PrimaryBackgroundColor",
			"SecondaryBackgroundColor",
			"TertiaryBackgroundColor",
			"ScrollingBarImageColor",
			"TabBackgroundColor",
		}

		for elementType, elementData in pairs(shared.Flags) do
			for elementName, addon in pairs(elementData) do
				if elementType == "Dropdown" and typeof(addon) == "table" and addon.getList and addon.getValue then
					SavedData.Dropdown[elementName] = { list = addon:getList(), value = addon:getValue() }
				end

				if elementType == "Toggle" and typeof(addon) == "table" and addon.getState then
					SavedData.Toggle[elementName] = { state = addon:getState() }
				end

				if elementType == "Slider" and typeof(addon) == "table" and addon.getValue then
					SavedData.Slider[elementName] = { value = addon:getValue() }
				end

				if elementType == "Keybind" and typeof(addon) == "table" and addon.getKeybind then
					SavedData.Keybind[elementName] = { keybind = addon:getKeybind() }
				end

				if elementType == "TextBox" and typeof(addon) == "table" and addon.getText then
					SavedData.TextBox[elementName] = { text = addon:getText() }
				end

				if
					not table.find(Excluded, elementName)
					and elementType == "ColorPicker"
					and typeof(addon) == "table"
					and addon.getColor
				then
					SavedData.ColorPicker[elementName] =
						{ color = { addon:getColor().R * 255, addon:getColor().G * 255, addon:getColor().B * 255 } }
				end
			end
		end

		return SavedData
	end

	local function getThemeData()
		local SavedData = {
			ColorPicker = {},
		}

		for elementType, elementData in pairs(shared.Flags) do
			for elementName, addon in pairs(elementData) do
				for _, themeName in ipairs({
					"Line",
					"PrimaryColor",
					"PrimaryTextColor",
					"SecondaryTextColor",
					"PrimaryBackgroundColor",
					"SecondaryBackgroundColor",
					"TertiaryBackgroundColor",
					"ScrollingBarImageColor",
					"TabBackgroundColor",
				}) do
					if
						elementName == themeName
						and elementType == "ColorPicker"
						and typeof(addon) == "table"
						and addon.getColor
					then
						SavedData.ColorPicker[elementName] =
							{ color = { addon:getColor().R * 255, addon:getColor().G * 255, addon:getColor().B * 255 } }
					end
				end
			end
		end

		return SavedData
	end

	local function applySavedData(decoded: table)
		if type(decoded) ~= "table" then
			return false, "Invalid settings payload"
		end

		for elementType, elementData in pairs(shared.Flags) do
			for elementName, _ in pairs(elementData) do
				if
					elementType == "Dropdown"
					and decoded.Dropdown
					and decoded.Dropdown[elementName]
					and shared.Flags.Dropdown[elementName]
					and elementName ~= "Configs"
					and elementName ~= "Theme Configs"
					and elementName ~= "Theme Presets"
				then
					local defaultValue = decoded.Dropdown[elementName].value
					if type(defaultValue) ~= "table" then
						defaultValue = { defaultValue }
					end

					shared.Flags.Dropdown[elementName]:updateList({
						list = decoded.Dropdown[elementName].list,
						default = defaultValue,
					})
				end

				if
					elementType == "Toggle"
					and decoded.Toggle
					and decoded.Toggle[elementName]
					and shared.Flags.Toggle[elementName]
				then
					shared.Flags.Toggle[elementName]:updateState({ state = decoded.Toggle[elementName].state })
				end

				if
					elementType == "Slider"
					and decoded.Slider
					and decoded.Slider[elementName]
					and shared.Flags.Slider[elementName]
				then
					shared.Flags.Slider[elementName]:updateValue({ value = decoded.Slider[elementName].value })
				end

				if
					elementType == "Keybind"
					and decoded.Keybind
					and decoded.Keybind[elementName]
					and shared.Flags.Keybind[elementName]
				then
					shared.Flags.Keybind[elementName]:updateKeybind({ bind = decoded.Keybind[elementName].keybind })
				end

				if
					elementType == "TextBox"
					and decoded.TextBox
					and decoded.TextBox[elementName]
					and shared.Flags.TextBox[elementName]
				then
					shared.Flags.TextBox[elementName]:updateText({ text = decoded.TextBox[elementName].text })
				end

				if
					elementType == "ColorPicker"
					and decoded.ColorPicker
					and decoded.ColorPicker[elementName]
					and shared.Flags.ColorPicker[elementName]
				then
					shared.Flags.ColorPicker[elementName]:updateColor({
						color = Color3.fromRGB(unpack(decoded.ColorPicker[elementName].color)),
					})
				end
			end
		end

		return true
	end

	local function loadSaveConfig(fileName: string)
		if not fileName or fileName == "" then
			return
		end

		local filePath = options.folderName .. "/" .. fileName .. ".json"
		if not isfile(filePath) then
			return
		end

		local decodeSuccess, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(filePath))
		end)

		if decodeSuccess then
			applySavedData(decoded)
		end
	end

	local function loadThemeConfig(fileName: string, isGitHub: boolean)
		if not fileName or fileName == "" then
			return
		end

		local decoded
		local success, err = pcall(function()
			if isGitHub then
				-- URL encode the filename to handle spaces and special characters
				local encodedFileName = HttpService:UrlEncode(fileName)
				local url = "https://raw.githubusercontent.com/DontGho/userinterface/refs/heads/main/"
					.. encodedFileName
					.. ".json"
				local response = game:HttpGet(url)
				decoded = HttpService:JSONDecode(response)
			else
				local filePath = THEME_FOLDER_PATH .. "/" .. fileName .. ".json"
				if not isfile(filePath) then
					error("File does not exist: " .. filePath)
				end
				decoded = HttpService:JSONDecode(readfile(filePath))
			end
		end)

		if not success then
			warn("Failed to load theme config:", err)
			return
		end

		if not decoded or not decoded.ColorPicker then
			warn("Invalid theme config format")
			return
		end

		for elementType, elementData in pairs(shared.Flags) do
			for elementName, _ in pairs(elementData) do
				if
					elementType == "ColorPicker"
					and decoded.ColorPicker[elementName]
					and shared.Flags.ColorPicker[elementName]
				then
					local colorData = decoded.ColorPicker[elementName].color
					if colorData and #colorData == 3 then
						shared.Flags.ColorPicker[elementName]:updateColor({
							color = Color3.fromRGB(unpack(colorData)),
						})
					end
				end
			end
		end
	end

	local UI = Library:createTab({ text = "UI", icon = options.icon })
	local Page = UI:createSubTab({ text = "Page 1" })
	local UI = Page:createSection({ text = "UI" })
	local SaveManager = Page:createSection({ position = "Right", text = "Save Manager" })
	local ThemeManager = Page:createSection({ position = "Right", text = "Theme Manager" })

	function createNaturalRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		local originalColor = Library.Theme.PrimaryTextColor
		local h, s, v = originalColor:ToHSV()

		local originalSaturation = math.max(s, 0.8)
		local originalValue = math.max(v, 0.9)

		local startTime = tick()
		local cycleDuration = 4

		rainbowConnection = game:GetService("RunService").Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			local progress = (elapsed % cycleDuration) / cycleDuration

			local currentHue = progress

			local newColor = Color3.fromHSV(currentHue, originalSaturation, originalValue)
			titleIcon.ImageColor3 = newColor
		end)

		table.insert(Connections, {
			Disconnect = function()
				if rainbowConnection then
					rainbowConnection:Disconnect()
					rainbowConnection = nil
				end
			end,
		})
	end

	local function stopRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end
		titleIcon.ImageColor3 = Library.Theme.PrimaryTextColor

		-- Re-register to theme so it updates with theme changes
		Theme:registerToObjects({
			{ object = titleIcon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
		})
	end

	-- Only show icon toggles if user is not poor
	if not UserIsPoor then
		UI:createToggle({
			text = "Show Icon",
			state = true,
			callback = function(state)
				Library.IconVisible = state
				local TitleIcon = Title:FindFirstChild("TitleIcon")
				if TitleIcon then
					TitleIcon.Visible = state
					if state then
						Title.Text = "       " .. (Library.Title or "Leny")
					else
						Title.Text = Library.Title or "Leny"
					end
				end
			end,
		})

		UI:createToggle({
			text = "Rainbow Icon",
			state = false,
			callback = function(state)
				local TitleIcon = Title:FindFirstChild("TitleIcon")
				if TitleIcon then
					if state then
						createNaturalRainbowEffect(TitleIcon)
					else
						stopRainbowEffect(TitleIcon)
					end
				end
			end,
		})
	end

	UI:createToggle({
		text = "Aggressive Mouse Unlock",
		state = false,
		tooltip = "Only enable if the mouse is invisible while the UI is open. (May cause detections)",
	})

	UI:createPicker({
		text = "SecondaryTextColor",
		default = Theme.SecondaryTextColor,
		callback = function(color)
			Theme:setTheme("SecondaryTextColor", color)
		end,
	})

	UI:createPicker({
		text = "PrimaryTextColor",
		default = Theme.PrimaryTextColor,
		callback = function(color)
			Theme:setTheme("PrimaryTextColor", color)
		end,
	})

	UI:createPicker({
		text = "PrimaryBackgroundColor",
		default = Theme.PrimaryBackgroundColor,
		callback = function(color)
			Theme:setTheme("PrimaryBackgroundColor", color)
		end,
	})

	UI:createPicker({
		text = "SecondaryBackgroundColor",
		default = Theme.SecondaryBackgroundColor,
		callback = function(color)
			Theme:setTheme("SecondaryBackgroundColor", color)
		end,
	})

	UI:createPicker({
		text = "TabBackgroundColor",
		default = Theme.TabBackgroundColor,
		callback = function(color)
			Theme:setTheme("TabBackgroundColor", color)
		end,
	})

	UI:createPicker({
		text = "PrimaryColor",
		default = Theme.PrimaryColor,
		callback = function(color)
			Theme:setTheme("PrimaryColor", color)
		end,
	})

	UI:createPicker({
		text = "Outline",
		default = Theme.Line,
		callback = function(color)
			Theme:setTheme("Line", color)
		end,
	})

	UI:createPicker({
		text = "TertiaryBackgroundColor",
		default = Theme.TertiaryBackgroundColor,
		callback = function(color)
			Theme:setTheme("TertiaryBackgroundColor", color)
		end,
	})

	UI:createPicker({
		text = "SecondaryTextColor",
		default = Theme.SecondaryTextColor,
		callback = function(color)
			Theme:setTheme("SecondaryTextColor", color)
		end,
	})

	UI:createPicker({
		text = "ScrollingBarImageColor",
		default = Theme.ScrollingBarImageColor,
		callback = function(color)
			Theme:setTheme("ScrollingBarImageColor", color)
		end,
	})

	UI:createKeybind({
		text = "Hide UI",
		default = "Delete",
		callback = function()
			Library:ToggleUI()
		end,
	})

	UI:createButton({
		text = "Destroy UI",
		callback = function()
			Library:destroy()
		end,
	})

	if not isfolder(options.folderName) then
		makefolder(options.folderName)
	end

	if not isfolder(THEME_ROOT_FOLDER) then
		makefolder(THEME_ROOT_FOLDER)
	end

	if not isfolder(THEME_FOLDER_PATH) then
		makefolder(THEME_FOLDER_PATH)
	end

	local jsons = getJsons()

	-- LOAD/MANAGE CONFIGS (most commonly used)
	local Configs = SaveManager:createDropdown({ text = "Configs", list = jsons })

	SaveManager:createButton({
		text = "Load Config",
		callback = function()
			local configValue = Configs:getValue()
			-- Handle both string and table returns from getValue
			if type(configValue) == "table" then
				configValue = configValue[1] or ""
			end
			if configValue and configValue ~= "" and configValue ~= "None" then
				loadSaveConfig(configValue)
			end
		end,
	})

	SaveManager:createButton({
		text = "Set as Auto Load",
		callback = function()
			local configValue = Configs:getValue()
			-- Handle both string and table returns from getValue
			if type(configValue) == "table" then
				configValue = configValue[1] or ""
			end
			if configValue and configValue ~= "" and configValue ~= "None" then
				writefile(options.folderName .. "/autoload.txt", configValue)
			end
		end,
	})

	-- CREATE/SAVE CONFIGS
	local configName = SaveManager:createTextBox({ text = "Config Name" })
	local importCode = nil
	local lastShareCode = ""

	local function normalizeCode(text: string)
		local codeText = tostring(text or "")
		codeText = string.gsub(codeText, "%s+", "")
		return codeText
	end

	local function parseTimestamp(rawValue)
		local numeric = tonumber(rawValue)
		if not numeric then
			return nil
		end

		if numeric > 9999999999 then
			numeric = numeric / 1000
		end

		numeric = math.floor(numeric)
		if numeric <= 0 then
			return nil
		end

		return numeric
	end

	local function formatDuration(seconds: number)
		local totalSeconds = math.max(0, math.floor(tonumber(seconds) or 0))
		local hours = math.floor(totalSeconds / 3600)
		local minutes = math.floor((totalSeconds % 3600) / 60)
		local secs = totalSeconds % 60

		if hours > 0 then
			if minutes > 0 then
				return tostring(hours) .. "h " .. tostring(minutes) .. "m"
			end
			return tostring(hours) .. "h"
		end

		if minutes > 0 then
			return tostring(minutes) .. "m"
		end

		return tostring(secs) .. "s"
	end

	local function isValidShareCode(code: string)
		return string.match(code, "^[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z]$") ~= nil
	end

	local function notifyApiError(statusCode: number, isExport: boolean, responseHeaders: table?)
		if statusCode == 400 then
			Library:notify({ title = "Config API", text = "Invalid request data.", duration = 4 })
			return
		end

		if statusCode == 404 then
			Library:notify({ title = "Config API", text = "Code not found or expired.", duration = 4 })
			return
		end

		if statusCode == 429 then
			local retryAfter = tonumber(getHeader(responseHeaders, "Retry-After")) or 0

			if isExport and retryAfter > 0 then
				exportCooldownUntil = math.max(exportCooldownUntil, tick() + retryAfter)
				Library:notify({
					title = "Export Rate Limited",
					text = "Try again in " .. formatDuration(retryAfter) .. ".",
					duration = 5,
				})
			else
				Library:notify({ title = "Config API", text = "Rate limited. Please wait and retry.", duration = 5 })
			end

			return
		end

		if statusCode == 500 then
			Library:notify({ title = "Config API", text = "Server error while processing config.", duration = 5 })
			return
		end

		Library:notify({
			title = "Config API",
			text = "Unexpected error (" .. tostring(statusCode) .. ").",
			duration = 5,
		})
	end

	if options.apiBaseUrl ~= "" then
		importCode = SaveManager:createTextBox({ text = "Import Code" })

		SaveManager:createButton({
			text = "Import Settings",
			callback = function()
				local code = normalizeCode(importCode:getText())
				if not isValidShareCode(code) then
					Library:notify({
						title = "Import Settings",
						text = "Enter a valid 5-character code.",
						duration = 4,
					})
					return
				end

				local response, requestError = requestApi("GET", "/api/import/" .. code)
				if not response then
					Library:notify({
						title = "Import Settings",
						text = "Request failed: " .. tostring(requestError),
						duration = 5,
					})
					return
				end

				if tonumber(response.StatusCode) ~= 200 then
					notifyApiError(tonumber(response.StatusCode) or 0, false, response.Headers)
					return
				end

				local decodeSuccess, decoded = pcall(function()
					return HttpService:JSONDecode(response.Body or "")
				end)

				if not decodeSuccess or type(decoded) ~= "table" then
					Library:notify({ title = "Import Settings", text = "Failed to decode settings.", duration = 5 })
					return
				end

				local applySuccess, applyError = applySavedData(decoded)
				if not applySuccess then
					Library:notify({ title = "Import Settings", text = tostring(applyError), duration = 5 })
					return
				end

				Library:notify({ title = "Import Settings", text = "Settings imported successfully.", duration = 4 })
			end,
		})

		SaveManager:createButton({
			text = "Export Settings",
			callback = function()
				local now = tick()
				if now < exportCooldownUntil then
					local timeLeft = math.ceil(exportCooldownUntil - now)
					Library:notify({
						title = "Export Settings",
						text = "Export is on cooldown for " .. formatDuration(timeLeft) .. ".",
						duration = 4,
					})
					return
				end

				local payload = getSavedData()
				local response, requestError = requestApi("POST", "/api/export", payload)
				if not response then
					Library:notify({
						title = "Export Settings",
						text = "Request failed: " .. tostring(requestError),
						duration = 5,
					})
					return
				end

				if tonumber(response.StatusCode) ~= 200 then
					notifyApiError(tonumber(response.StatusCode) or 0, true, response.Headers)
					return
				end

				local decodeSuccess, decoded = pcall(function()
					return HttpService:JSONDecode(response.Body or "")
				end)

				if
					not decodeSuccess
					or type(decoded) ~= "table"
					or not isValidShareCode(tostring(decoded.code or ""))
				then
					Library:notify({
						title = "Export Settings",
						text = "Server returned an invalid code.",
						duration = 5,
					})
					return
				end

				local code = tostring(decoded.code)
				lastShareCode = code

				local copyFn = setclipboard or toclipboard
				local copiedToClipboard = false
				if copyFn then
					copiedToClipboard = pcall(function()
						copyFn(code)
					end)
				end

				local remaining = tonumber(getHeader(response.Headers, "X-RateLimit-Remaining"))
				local limit = tonumber(getHeader(response.Headers, "X-RateLimit-Limit"))
				local usageText = "?/?"
				if remaining ~= nil and limit ~= nil then
					local used = math.clamp(limit - remaining, 0, limit)
					usageText = tostring(used) .. "/" .. tostring(limit)
				elseif remaining ~= nil then
					usageText = "?/?"
				end

				local resetInText = "unknown"
				local resetTimestamp = parseTimestamp(getHeader(response.Headers, "X-RateLimit-Reset"))
				if resetTimestamp then
					resetInText = formatDuration(math.max(0, resetTimestamp - os.time()))
				end

				local expiryRaw = decoded.expiresAt or decoded.expires_at or decoded.expiry or decoded.expireAt
				local expiresText = "7d"
				local expiryTimestamp = parseTimestamp(expiryRaw)
				if expiryTimestamp then
					expiresText = formatDuration(math.max(0, expiryTimestamp - os.time()))
				end

				local clipboardText = copiedToClipboard and "Copied" or "No clipboard"

				Library:notify({
					title = "Export Settings",
					text = "Code: "
						.. code
						.. " | "
						.. usageText
						.. " | expires in "
						.. expiresText
						.. " | reset in "
						.. resetInText
						.. " | "
						.. clipboardText,
					duration = 10,
				})
			end,
		})

		SaveManager:createButton({
			text = "Copy Share Code",
			callback = function()
				local code = normalizeCode(lastShareCode)
				if not isValidShareCode(code) then
					Library:notify({ title = "Copy Share Code", text = "No valid share code to copy.", duration = 4 })
					return
				end

				local copyFn = setclipboard or toclipboard
				if not copyFn then
					Library:notify({
						title = "Copy Share Code",
						text = "Clipboard is not supported in this executor.",
						duration = 4,
					})
					return
				end

				local copySuccess = pcall(function()
					copyFn(code)
				end)

				if copySuccess then
					Library:notify({
						title = "Copy Share Code",
						text = "Copied " .. code .. " to clipboard.",
						duration = 4,
					})
				else
					Library:notify({ title = "Copy Share Code", text = "Failed to copy code.", duration = 4 })
				end
			end,
		})
	end

	SaveManager:createButton({
		text = "Create Config",
		callback = function()
			local SavedData = getSavedData()
			local encoded = HttpService:JSONEncode(SavedData)
			writefile(options.folderName .. "/" .. configName:getText() .. ".json", encoded)

			if shared.Flags.Dropdown["Configs"] then
				shared.Flags.Dropdown["Configs"]:updateList({
					list = getJsons(),
					default = { shared.Flags.Dropdown["Configs"]:getValue() },
				})
			end
		end,
	})

	SaveManager:createButton({
		text = "Save/Overwrite Config",
		callback = function()
			local configValue = Configs:getValue()
			-- Handle both string and table returns from getValue
			if type(configValue) == "table" then
				configValue = configValue[1] or ""
			end
			if not configValue or configValue == "" or configValue == "None" then
				return
			end
			local SavedData = getSavedData()
			local encoded = HttpService:JSONEncode(SavedData)
			writefile(options.folderName .. "/" .. configValue .. ".json", encoded)
			Configs:updateList({ list = getJsons(), default = { configValue } })
		end,
	})

	SaveManager:createButton({
		text = "Delete Saved Config",
		callback = function()
			local configToDelete = Configs:getValue()
			-- Handle both string and table returns from getValue
			if type(configToDelete) == "table" then
				configToDelete = configToDelete[1] or ""
			end
			if not configToDelete or configToDelete == "" or configToDelete == "None" then
				return
			end
			local filePath = options.folderName .. "/" .. configToDelete .. ".json"
			if isfile and delfile and isfile(filePath) then
				delfile(filePath)
				Configs:updateList({ list = getJsons(), default = {} })
			end
		end,
	})

	if isfile(options.folderName .. "/autoload.txt") then
		local autoloadConfig = readfile(options.folderName .. "/autoload.txt")
		if autoloadConfig and autoloadConfig ~= "" then
			loadSaveConfig(autoloadConfig)
		end
	end

	-- THEME PRESETS SECTION (from GitHub - most commonly used)
	local ThemePresets = ThemeManager:createDropdown({
		text = "Theme Presets",
		list = getThemePresets(),
	})

	ThemeManager:createButton({
		text = "Load Theme Preset",
		callback = function()
			local presetValue = ThemePresets:getValue()
			-- Handle both string and table returns from getValue
			if type(presetValue) == "table" then
				presetValue = presetValue[1] or ""
			end
			if presetValue and presetValue ~= "" and presetValue ~= "None" then
				loadThemeConfig(presetValue, true)
			end
		end,
	})

	ThemeManager:createButton({
		text = "Refresh Presets",
		callback = function()
			ThemePresets:updateList({
				list = getThemePresets(),
				default = {},
			})
		end,
	})

	ThemeManager:createButton({
		text = "Set Preset Auto Load",
		callback = function()
			local presetValue = ThemePresets:getValue()
			-- Handle both string and table returns from getValue
			if type(presetValue) == "table" then
				presetValue = presetValue[1] or ""
			end
			if presetValue and presetValue ~= "" and presetValue ~= "None" then
				writefile(options.folderName .. "/presetautoload.txt", presetValue)
			end
		end,
	})

	-- LOCAL THEME CONFIGS SECTION (your saved themes)
	local themeConfigName = ThemeManager:createTextBox({ text = "Theme Config Name" })

	ThemeManager:createButton({
		text = "Create Theme Config",
		callback = function()
			local ThemeData = getThemeData()
			local encoded = HttpService:JSONEncode(ThemeData)
			writefile(THEME_FOLDER_PATH .. "/" .. themeConfigName:getText() .. ".json", encoded)

			if shared.Flags.Dropdown["Theme Configs"] then
				shared.Flags.Dropdown["Theme Configs"]:updateList({
					list = getThemeJsons(),
					default = { shared.Flags.Dropdown["Theme Configs"]:getValue() },
				})
			end
		end,
	})

	local ThemeConfigs = ThemeManager:createDropdown({
		text = "Theme Configs",
		list = getThemeJsons(),
	})

	ThemeManager:createButton({
		text = "Load Theme Config",
		callback = function()
			local themeValue = ThemeConfigs:getValue()
			-- Handle both string and table returns from getValue
			if type(themeValue) == "table" then
				themeValue = themeValue[1] or ""
			end
			if themeValue and themeValue ~= "" and themeValue ~= "None" then
				loadThemeConfig(themeValue, false)
			end
		end,
	})

	ThemeManager:createButton({
		text = "Save Theme Config",
		callback = function()
			local themeValue = ThemeConfigs:getValue()
			-- Handle both string and table returns from getValue
			if type(themeValue) == "table" then
				themeValue = themeValue[1] or ""
			end
			if not themeValue or themeValue == "" or themeValue == "None" then
				return
			end
			local ThemeData = getThemeData()
			local encoded = HttpService:JSONEncode(ThemeData)
			writefile(THEME_FOLDER_PATH .. "/" .. themeValue .. ".json", encoded)
			ThemeConfigs:updateList({ list = getThemeJsons(), default = { themeValue } })
		end,
	})

	ThemeManager:createButton({
		text = "Set Config Auto Load",
		callback = function()
			local themeValue = ThemeConfigs:getValue()
			-- Handle both string and table returns from getValue
			if type(themeValue) == "table" then
				themeValue = themeValue[1] or ""
			end
			if themeValue and themeValue ~= "" and themeValue ~= "None" then
				writefile(THEME_AUTOLOAD_PATH, themeValue)
			end
		end,
	})

	-- Auto-load preset from GitHub if set
	-- Delayed so initial tab/subtab tweens (0.2s) settle before setTheme runs;
	-- otherwise the tolerance check fails and active tab text never updates.
	if isfile(options.folderName .. "/presetautoload.txt") then
		local autoloadPreset = readfile(options.folderName .. "/presetautoload.txt")
		if autoloadPreset and autoloadPreset ~= "" then
			task.delay(0.35, function()
				loadThemeConfig(autoloadPreset, true)
			end)
		end
	end

	-- Auto-load local theme config if set
	if isfile(THEME_AUTOLOAD_PATH) then
		local autoloadTheme = readfile(THEME_AUTOLOAD_PATH)
		if autoloadTheme and autoloadTheme ~= "" then
			task.delay(0.35, function()
				loadThemeConfig(autoloadTheme, false)
			end)
		end
	end

	self.managerCreated = true
end

Theme:registerToObjects({
	{ object = Glow, property = "ImageColor3", theme = { "PrimaryBackgroundColor" } },
	{ object = Background, property = "BackgroundColor3", theme = { "SecondaryBackgroundColor" } },
	{ object = Line, property = "BackgroundColor3", theme = { "Line" } },
	{ object = Tabs, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
	{ object = Filler, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
	{ object = Title, property = "TextColor3", theme = { "PrimaryTextColor" } },
	{ object = Assets.Pages.Fade, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
})

Utility:draggable(Library, Glow)
Utility:resizable(Library, Glow.Background.Pages.Resize, Glow)

task.spawn(function()
	while not Library.managerCreated do
		task.wait()
	end

	for _, addon in pairs(Library.Addons) do
		if addon.Parent == nil then
			addon:Destroy()
		end
	end
end)

return Library
