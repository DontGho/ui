--!nocheck
-- update!

local TESTING = false

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local isMobile = UserInputService.TouchEnabled

-- game:GetObjects is identity gated -- at identity 2 it is not even a member of the
-- DataModel, and at identity 5 it lacks the LoadLocalAsset capability. A game script that
-- lowers identity to require RobloxScript modules and then errors before restoring it
-- leaves this thread at 2, and the asset load fails. Some executors raise there; others
-- hand back an error STRING inside the table, which used to surface as the baffling
-- "attempt to index string with 'Enabled'" on the next line.
--
-- So: elevate for the load, always restore, and fail with a message that says what
-- actually went wrong.
local ScreenGui = (function()
	local previousIdentity
	if getthreadidentity and setthreadidentity then
		local ok, current = pcall(getthreadidentity)
		if ok then
			previousIdentity = current
			pcall(setthreadidentity, 8)
		end
	end

	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://99852798675591")
	end)

	if previousIdentity then
		pcall(setthreadidentity, previousIdentity)
	end

	if ok and type(objects) == "table" and typeof(objects[1]) == "Instance" then
		return objects[1]
	end

	local detail
	if not ok then
		detail = "GetObjects errored: " .. tostring(objects)
	elseif type(objects) ~= "table" then
		detail = "GetObjects returned " .. typeof(objects)
	else
		detail = "GetObjects returned " .. typeof(objects[1]) .. ": " .. tostring(objects[1])
	end

	error("MaxHub UI: could not load the interface asset. This usually means the thread "
		.. "identity was lowered and not restored, or your executor cannot load assets. ("
		.. detail .. ")", 0)
end)()
ScreenGui.Enabled = false

if RunService:IsStudio() then
	ScreenGui.Parent = game.StarterGui
else
	local parentSuccess, hiddenUi = pcall(gethui)
	if not parentSuccess or typeof(hiddenUi) ~= "Instance" then
		error("MaxHub UI: could not access the executor UI container", 0)
	end
	ScreenGui.Parent = hiddenUi
end

local Library = {
	sizeX = 800,
	sizeY = 600,
	tabSizeX = 220,

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

local SKIP_INTRO_FOLDER = "Maxhub"
local SKIP_INTRO_PATH = SKIP_INTRO_FOLDER .. "/skipintro.txt"

Library.SkipIntro = false

do
	local success, value = pcall(function()
		if isfile(SKIP_INTRO_PATH) then
			return readfile(SKIP_INTRO_PATH)
		end
	end)

	if success then
		Library.SkipIntro = value == "true"
	end
end

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

local popupTransparencyProperties = { "BackgroundTransparency", "TextTransparency", "ImageTransparency" }

local function hideNavigationPopups(popups)
	if Library.ActiveDropdownClose then
		pcall(Library.ActiveDropdownClose)
	end

	for _, popup in ipairs(popups:GetChildren()) do
		local isOpen = false
		if popup.Visible then
			local success, transparency = pcall(function()
				return popup.BackgroundTransparency
			end)
			isOpen = not success or transparency < 0.9
		end

		if isOpen then
			pcall(function()
				popup.BackgroundTransparency = 1
			end)

			local queue = popup:GetChildren()
			local queueIndex = 1
			while queueIndex <= #queue do
				local object = queue[queueIndex]
				queueIndex += 1

				for _, child in ipairs(object:GetChildren()) do
					table.insert(queue, child)
				end

				if object.Name ~= "CurrentValueLabel" and object.Name ~= "Checkmark" then
					for _, property in ipairs(popupTransparencyProperties) do
						pcall(function()
							if object[property] <= 0.1 then
								object[property] = 1
							end
						end)
					end
				end
			end

			popup.Visible = false
		end
	end
end

function Modules.Navigation:selectTab()
	local navigation = self

	return function()
		if navigation.Page.Visible then
			return
		end

		hideNavigationPopups(navigation.Popups)

		for _, page in ipairs(navigation.Pages:GetChildren()) do
			if string.match(page.Name, "Page") and page.Visible then
				page.Visible = false
			end
		end

		navigation.Page.Visible = true
		navigation.animation()

		for _, tab in ipairs(navigation.ScrollingFrame:GetChildren()) do
			if string.match(tab.Name, "Tab") then
				navigation.tweenTabsOff(tab)
			end
		end

		navigation.tweenTabOn()
	end
end

-- default outline color
Theme.Line = Color3.fromRGB(50, 53, 63)

-- global animation switch: when NoAnimations is on, tweens apply their target instantly
do
	local rawTween = Utility.tween
	Utility.tween = function(self, object, properties, duration, easingStyle, easingDirection)
		if Library.NoAnimations and typeof(object) == "Instance" and typeof(properties) == "table" then
			for property, value in pairs(properties) do
				pcall(function()
					object[property] = value
				end)
			end
			return { Play = function() end, Cancel = function() end }
		end
		return rawTween(self, object, properties, duration, easingStyle, easingDirection)
	end
end

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

local AddonBackdrop = Instance.new("TextButton")
AddonBackdrop.Name = "AddonBackdrop"
AddonBackdrop.Text = ""
AddonBackdrop.AutoButtonColor = false
AddonBackdrop.Active = true
AddonBackdrop.Modal = true
AddonBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
AddonBackdrop.BackgroundTransparency = 1
AddonBackdrop.BorderSizePixel = 0
AddonBackdrop.AnchorPoint = Vector2.zero
AddonBackdrop.Visible = false
AddonBackdrop.ZIndex = 90
AddonBackdrop.Parent = ScreenGui

if Popups:IsA("GuiObject") then
	Popups.ZIndex = math.max(Popups.ZIndex, AddonBackdrop.ZIndex + 1)
end

local DropdownOverlay = Instance.new("Frame")
DropdownOverlay.Name = "DropdownOverlay"
DropdownOverlay.BackgroundTransparency = 1
DropdownOverlay.BorderSizePixel = 0
DropdownOverlay.Size = UDim2.fromScale(1, 1)
DropdownOverlay.Active = false
DropdownOverlay.ClipsDescendants = false
DropdownOverlay.ZIndex = 300
DropdownOverlay.Parent = ScreenGui

local backgroundCorner = Background:FindFirstChildOfClass("UICorner")
if backgroundCorner then
	backgroundCorner:Clone().Parent = AddonBackdrop
else
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = AddonBackdrop
end

local function updateAddonBackdropBounds()
	local screenOrigin = Vector2.zero
	local success, absolutePosition = pcall(function()
		return ScreenGui.AbsolutePosition
	end)

	if success and typeof(absolutePosition) == "Vector2" then
		screenOrigin = absolutePosition
	elseif not ScreenGui.IgnoreGuiInset then
		local insetSuccess, inset = pcall(function()
			return GuiService:GetGuiInset()
		end)
		if insetSuccess then
			screenOrigin = inset
		end
	end

	local position = Background.AbsolutePosition - screenOrigin
	AddonBackdrop.Position = UDim2.fromOffset(position.X, position.Y)
	AddonBackdrop.Size = UDim2.fromOffset(Background.AbsoluteSize.X, Background.AbsoluteSize.Y)
end

table.insert(Connections, Background:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateAddonBackdropBounds))
table.insert(Connections, Background:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateAddonBackdropBounds))
task.defer(updateAddonBackdropBounds)

local addonPopups = {}
local addonBackdropShown = false
local addonBackdropVersion = 0

local function setAddonBackdropVisible(visible)
	if addonBackdropShown == visible then
		return
	end

	addonBackdropShown = visible
	addonBackdropVersion += 1
	local version = addonBackdropVersion

	if visible then
		if Library.forceHideTooltip then
			Library:forceHideTooltip()
		end

		AddonBackdrop.Visible = true
		Utility:tween(AddonBackdrop, { BackgroundTransparency = 0.55 }, 0.22, "Quart", "Out"):Play()
	else
		if Library.ActiveDropdownClose then
			pcall(Library.ActiveDropdownClose)
		end

		Utility:tween(AddonBackdrop, { BackgroundTransparency = 1 }, 0.2, "Quart", "Out"):Play()
		task.delay(Library.NoAnimations and 0 or 0.2, function()
			if addonBackdropVersion == version then
				AddonBackdrop.Visible = false
			end
		end)
	end
end

local function updateAddonBackdrop()
	local visible = false

	for _, popup in ipairs(addonPopups) do
		if popup.Parent and popup.Visible and popup.BackgroundTransparency < 0.9 then
			visible = true
			break
		end
	end

	setAddonBackdropVisible(visible)
end

local function elevateAddonPopup(object)
	local queue = { object }
	local queueIndex = 1

	while queueIndex <= #queue do
		local current = queue[queueIndex]
		queueIndex += 1

		if current:IsA("GuiObject") and not current:GetAttribute("MaxhubAddonPopupZ") then
			current:SetAttribute("MaxhubAddonPopupZ", true)
			current.ZIndex += 100
		end

		for _, child in ipairs(current:GetChildren()) do
			table.insert(queue, child)
		end
	end
end

local function registerAddonPopup(popup)
	table.insert(addonPopups, popup)
	elevateAddonPopup(popup)

	table.insert(Connections, popup:GetPropertyChangedSignal("Visible"):Connect(updateAddonBackdrop))
	table.insert(Connections, popup:GetPropertyChangedSignal("BackgroundTransparency"):Connect(updateAddonBackdrop))
	table.insert(Connections, popup.AncestryChanged:Connect(updateAddonBackdrop))
	table.insert(Connections, popup.DescendantAdded:Connect(elevateAddonPopup))
end

table.insert(Connections, AddonBackdrop.MouseButton1Down:Connect(function()
	pcall(function()
		hideNavigationPopups(Popups)
	end)
end))

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
	if addonBackdropShown then
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
		if Library.dropdownOpen > 0 or addonBackdropShown then
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
			240
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
			240
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

local LOGO_MODEL_ID = "76424111135112"
local LOGO_AMBIENT_COLOR = Color3.fromRGB(78, 255, 255)
local LOGO_LIGHT_COLOR = Color3.fromRGB(255, 255, 255)
local LOGO_IMAGE_COLOR = Color3.fromRGB(255, 74, 76)
local LOGO_LIGHT_DIR = Vector3.new(-0.37, -0.94, 0.19)
local LOGO_TINT = Color3.fromRGB(255, 0, 0)
local LOGO_MATERIAL = Enum.Material.Glass
local OLD_LOGO_IMAGE = "rbxassetid://110774279816088"

Library.LogoSpinSpeed = 0.5
Library.LogoSize = 39
Library.LogoColor = Color3.fromRGB(0, 98, 238)
Library.LogoColorEffect = true
Library.LogoRainbow = false

local function applyLogoAppearance(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Material = LOGO_MATERIAL
			descendant.Reflectance = 0
			descendant.Color = LOGO_TINT
		end
	end
end

function Library:playIntro(introId, onDone)
	if Library.NoAnimations or Library.SkipIntro or not introId or introId == "" then
		onDone()
		return
	end

	task.spawn(function()
		-- intro settings (tuned). SPIN_SPEED is the speed once it starts spinning; the tuner
		-- used 0 only to freeze the model while aiming the facing.
		local TILT_X, TILT_Z, YAW = 5.9, 0.74, 36.89
		local SPIN_SPEED = 5
		local ZOOM, HEIGHT, FOV = 0.98, 0.12, 49
		local SIZE, POS_X, POS_Y = 417, -10, 0
		local OUTLINE_FOV = FOV - 0.93
		local OUTLINE_COLOR = Color3.fromRGB(165, 0, 0)
		local FADE_IN, SETTLE, HOLD, FADE_OUT = 0.7, 0.05, 1, 1

		local ok, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. introId)
		end)

		if not ok or type(objects) ~= "table" or #objects == 0 then
			onDone()
			return
		end

		local model = Instance.new("Model")

		for _, obj in ipairs(objects) do
			obj.Parent = model
		end

		applyLogoAppearance(model)

		local introGui = Instance.new("ScreenGui")
		introGui.Name = "MaxhubIntro"
		introGui.DisplayOrder = 100000
		introGui.IgnoreGuiInset = true
		introGui.ResetOnSpawn = false
		introGui.Parent = ScreenGui.Parent

		local outlineViewport = Instance.new("ViewportFrame")
		outlineViewport.AnchorPoint = Vector2.new(0.5, 0.5)
		outlineViewport.Position = UDim2.new(0.5, POS_X, 0.5, POS_Y)
		outlineViewport.Size = UDim2.fromOffset(SIZE, SIZE)
		outlineViewport.BackgroundTransparency = 1
		outlineViewport.ImageTransparency = 1
		outlineViewport.Ambient = OUTLINE_COLOR
		outlineViewport.LightColor = OUTLINE_COLOR
		outlineViewport.LightDirection = LOGO_LIGHT_DIR
		outlineViewport.ZIndex = 1
		outlineViewport.Parent = introGui

		local viewport = Instance.new("ViewportFrame")
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.Position = UDim2.new(0.5, POS_X, 0.5, POS_Y)
		viewport.Size = UDim2.fromOffset(SIZE, SIZE)
		viewport.BackgroundTransparency = 1
		viewport.ImageTransparency = 1
		viewport.Ambient = LOGO_AMBIENT_COLOR
		viewport.LightColor = LOGO_LIGHT_COLOR
		viewport.LightDirection = LOGO_LIGHT_DIR
		viewport.ImageColor3 = LOGO_IMAGE_COLOR
		viewport.ZIndex = 2
		viewport.Parent = introGui

		local world = Instance.new("WorldModel")
		world.Parent = viewport
		model.Parent = world

		local outlineWorld = Instance.new("WorldModel")
		outlineWorld.Parent = outlineViewport

		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local outlineCamera = Instance.new("Camera")
		outlineCamera.Parent = outlineViewport
		outlineViewport.CurrentCamera = outlineCamera

		-- orient the model so it faces the camera at the start (tilt + yaw)
		local levelCenter = model:GetBoundingBox().Position
		model:PivotTo(
			CFrame.new(levelCenter)
				* CFrame.Angles(0, math.rad(YAW), 0)
				* CFrame.Angles(math.rad(TILT_X), 0, math.rad(TILT_Z))
				* CFrame.new(-levelCenter)
				* model:GetPivot()
		)

		local outlineModel = model:Clone()
		for _, descendant in ipairs(outlineModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Material = Enum.Material.SmoothPlastic
				descendant.Reflectance = 0
				descendant.Color = OUTLINE_COLOR
			end
		end
		outlineModel.Parent = outlineWorld

		local pivot, size = model:GetBoundingBox()
		local center = pivot.Position
		local distance = math.max(size.Magnitude, 1) * ZOOM

		local angle = 0
		local function updateCamera()
			camera.FieldOfView = FOV
			outlineCamera.FieldOfView = OUTLINE_FOV

			local cameraCFrame = CFrame.lookAt(
				center + Vector3.new(math.sin(angle) * distance, size.Y * HEIGHT, math.cos(angle) * distance),
				center
			)
			camera.CFrame = cameraCFrame
			outlineCamera.CFrame = cameraCFrame
		end
		updateCamera()

		local spin = RunService.Heartbeat:Connect(function(dt)
			angle = angle + dt * SPIN_SPEED
			updateCamera()
		end)

		Utility:tween(outlineViewport, { ImageTransparency = 0 }, FADE_IN, "Quart", "In"):Play()
		Utility:tween(viewport, { ImageTransparency = 0 }, FADE_IN, "Quart", "In"):Play()
		task.wait(FADE_IN + SETTLE)

		task.wait(HOLD)

		-- fade the logo out (still spinning), then bring in the window once it's gone
		Utility:tween(outlineViewport, { ImageTransparency = 1 }, FADE_OUT, "Quart", "Out"):Play()
		Utility:tween(viewport, { ImageTransparency = 1 }, FADE_OUT, "Quart", "Out"):Play()
		task.delay(FADE_OUT, function()
			spin:Disconnect()
			introGui:Destroy()
			onDone()
		end)
	end)
end

local function createTitleLogo(parent, modelId)
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. modelId)
	end)

	if not ok or type(objects) ~= "table" or #objects == 0 then
		return nil
	end

	local model = Instance.new("Model")
	for _, object in ipairs(objects) do
		object.Parent = model
	end

	applyLogoAppearance(model)

	local hasPart = false
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			hasPart = true
			break
		end
	end

	if not hasPart then
		model:Destroy()
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "TitleIcon"
	viewport.AnchorPoint = Vector2.new(0, 0.5)
	viewport.Position = UDim2.new(0, -1, 0.5, 0)
	viewport.Size = UDim2.fromOffset(Library.LogoSize, Library.LogoSize)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = LOGO_AMBIENT_COLOR
	viewport.LightColor = LOGO_LIGHT_COLOR
	viewport.LightDirection = LOGO_LIGHT_DIR
	viewport.ImageColor3 = Library.LogoColor
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	model.Parent = world

	local camera = Instance.new("Camera")
	camera.FieldOfView = 49
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local levelCenter = model:GetBoundingBox().Position
	model:PivotTo(
		CFrame.new(levelCenter)
			* CFrame.Angles(0, math.rad(36.89), 0)
			* CFrame.Angles(math.rad(5.9), 0, math.rad(0.74))
			* CFrame.new(-levelCenter)
			* model:GetPivot()
	)

	local pivot, size = model:GetBoundingBox()
	local center = pivot.Position
	local distance = math.max(size.Magnitude, 1) * 0.98
	local angle = 0
	local colorTime = 0
	local pulseColor = Color3.fromRGB(255, 135, 170)

	local function updateCamera()
		camera.CFrame = CFrame.lookAt(
			center + Vector3.new(math.sin(angle) * distance, size.Y * 0.12, math.cos(angle) * distance),
			center
		)
	end

	updateCamera()

	local connection = RunService.Heartbeat:Connect(function(dt)
		if ScreenGui.Enabled and viewport.Visible and viewport.Parent then
			angle = angle + dt * Library.LogoSpinSpeed
			colorTime = colorTime + dt
			updateCamera()

			if not Library.LogoRainbow then
				if Library.LogoColorEffect then
					local pulse = 0.04 + ((math.sin(colorTime * 2) + 1) * 0.5) * 0.14
					viewport.ImageColor3 = Library.LogoColor:Lerp(pulseColor, pulse)
				else
					viewport.ImageColor3 = Library.LogoColor
				end
			end
		end
	end)
	table.insert(Connections, connection)

	return viewport
end

local function createStaticTitleLogo(parent, image)
	local icon = Instance.new("ImageLabel")
	icon.Name = "TitleIcon"
	icon.Parent = parent
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(Library.LogoSize, Library.LogoSize)
	icon.Position = UDim2.new(0, -1, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = image or OLD_LOGO_IMAGE
	icon.ImageColor3 = Library.Theme.PrimaryTextColor

	Theme:registerToObjects({
		{ object = icon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
	})

	return icon
end

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
		iconTitle = { Default = OLD_LOGO_IMAGE, ExpectedType = "string" },
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

	Library.tabSizeX = options.tabSizeX >= 200 and 220 or math.clamp(options.tabSizeX, 72, 240)
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

	setMouseCursorVisibility(true)

	-- Keep the UI hidden while the intro plays so it never flashes on screen while the
	-- game script is still building tabs behind it; the reveal enables it at the end.
	ScreenGui.Enabled = false

	-- Intro: spinning 3D model, then the window scales up with a bounce
	local function revealWindow()
		ScreenGui.Enabled = true
		Glow.Size = UDim2.fromOffset(options.sizeX * 0.93, options.sizeY * 0.93)
		Utility:tween(Glow, {
			Size = UDim2.fromOffset(options.sizeX, options.sizeY),
		}, 0.4, "Back", "Out"):Play()
	end

	Library:playIntro(options.introModel or LOGO_MODEL_ID, revealWindow)

	local rainbowConnection = nil

	local function createNaturalRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		Library.LogoRainbow = true

		local originalColor = titleIcon:IsA("ViewportFrame") and Library.LogoColor or Library.Theme.PrimaryTextColor
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

		Library.LogoRainbow = false

		if titleIcon:IsA("ViewportFrame") then
			titleIcon.ImageColor3 = Library.LogoColor
		else
			titleIcon.ImageColor3 = Library.Theme.PrimaryTextColor

			Theme:registerToObjects({
				{ object = titleIcon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
			})
		end
	end

	if UserIsPoor then
		Title.Text = options.title
		if Title:FindFirstChild("TitleIcon") then
			Title.TitleIcon.Visible = false
		end
	else
		local existingIcon = Title:FindFirstChild("TitleIcon")
		if existingIcon then
			existingIcon:Destroy()
		end

		local logoSuccess, TitleIcon = pcall(createTitleLogo, Title, options.introModel or LOGO_MODEL_ID)
		if not logoSuccess then
			TitleIcon = nil
		end

		if not TitleIcon then
			local failedIcon = Title:FindFirstChild("TitleIcon")
			if failedIcon then
				failedIcon:Destroy()
			end

			TitleIcon = createStaticTitleLogo(Title, options.iconTitle)
		end

		TitleIcon.Visible = true
		Title.Text = "        " .. options.title

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
	local addonRegistered = false

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
			options.default = options.default or {}
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

						if not addonRegistered then
							registerAddonPopup(Addon)
							addonRegistered = true
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

local activeTabTransition
local tabSectionFadeDuration = 0.3
local tabSectionStagger = 0.12

local function stopTabTransition()
	local transition = activeTabTransition
	if not transition then
		return
	end

	transition.active = false
	for _, tween in ipairs(transition.tweens) do
		pcall(function()
			tween:Cancel()
		end)
	end

	for _, group in ipairs(transition.groups) do
		pcall(function()
			group.GroupTransparency = 0
		end)
	end

	activeTabTransition = nil
end

local function getTabSections(page)
	local sections = {}

	local function addSubPage(subPage)
		if not subPage.Visible then
			return
		end

		local scrollingFrame = subPage:FindFirstChild("ScrollingFrame")
		if scrollingFrame then
			for _, column in ipairs(scrollingFrame:GetChildren()) do
				if (column.Name == "Left" or column.Name == "Right") and column.Visible then
					for _, section in ipairs(column:GetChildren()) do
						if section.Name == "Section" and section.Visible then
							table.insert(sections, section)
						end
					end
				end
			end
		end
	end

	if page.Name == "SubPage" then
		addSubPage(page)
	else
		for _, subPage in ipairs(page:GetChildren()) do
			if subPage.Name == "SubPage" then
				addSubPage(subPage)
			end
		end
	end

	table.sort(sections, function(first, second)
		local verticalDifference = math.abs(first.AbsolutePosition.Y - second.AbsolutePosition.Y)
		if verticalDifference <= 4 then
			return first.AbsolutePosition.X < second.AbsolutePosition.X
		end

		return first.AbsolutePosition.Y < second.AbsolutePosition.Y
	end)

	return sections
end

local function getTabSectionGroup(section)
	if section:IsA("CanvasGroup") then
		return section
	end
end

local function playTabSectionTransition(page, startDelay)
	if Library.ActiveDropdownClose then
		pcall(Library.ActiveDropdownClose)
	end

	stopTabTransition()

	if Library.NoAnimations then
		return
	end

	local transition = {
		active = true,
		groups = {},
		tweens = {},
	}
	activeTabTransition = transition

	local sections = getTabSections(page)

	for _, section in ipairs(sections) do
		local group = getTabSectionGroup(section)
		if group then
			group.GroupTransparency = 1
			table.insert(transition.groups, group)
		end
	end

	for index, group in ipairs(transition.groups) do
		task.delay(startDelay + ((index - 1) * tabSectionStagger), function()
			if not transition.active or activeTabTransition ~= transition or not page.Visible then
				return
			end

			local groupTween =
				Utility:tween(group, { GroupTransparency = 0 }, tabSectionFadeDuration, "Sine", "Out")
			table.insert(transition.tweens, groupTween)
			groupTween:Play()
		end)
	end

	local transitionLength =
		startDelay + tabSectionFadeDuration + (math.max(#transition.groups - 1, 0) * tabSectionStagger)
	task.delay(transitionLength, function()
		if not transition.active or activeTabTransition ~= transition then
			return
		end

		for _, group in ipairs(transition.groups) do
			group.GroupTransparency = 0
		end

		transition.active = false
		activeTabTransition = nil
	end)
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
		imageTransparency: number,
		duration: number
	)
		duration = duration or 0.25
		Utility:tween(
			tab,
			{ BackgroundColor3 = backgroundColor3, BackgroundTransparency = backgroundTransparency },
			duration,
			"Quart",
			"Out"
		):Play()
		Utility:tween(textButton, { TextColor3 = color, TextTransparency = textTransparency }, duration * 0.85, "Quart", "Out")
			:Play()
		Utility:tween(icon, { ImageTransparency = imageTransparency, ImageColor3 = color }, duration * 0.85, "Quart", "Out")
			:Play()
	end

	local function fadeAnimation()
		playTabSectionTransition(Page, 0.18)
	end

	local Context = Utility:validateContext({
		Page = { Value = Page, ExpectedType = "Instance" },
		Pages = { Value = Background.Pages, ExpectedType = "Instance" },
		Popups = { Value = Popups, ExpectedType = "Instance" },
		ScrollingFrame = { Value = Background.Tabs.Frame.ScrollingFrame, ExpectedType = "Instance" },
		animation = { Value = fadeAnimation, ExpectedType = "function" },

		tweenTabOn = {
			Value = function()
				if Library.NoAnimations then
					tweenTabAssets(Tab, Icon, TextButton, Theme.PrimaryColor, Theme.TabBackgroundColor, 0, 0, 0, 0)
				else
					task.delay(0.04, function()
						if Page.Visible then
							tweenTabAssets(
								Tab,
								Icon,
								TextButton,
								Theme.PrimaryColor,
								Theme.TabBackgroundColor,
								0,
								0,
								0,
								0.3
							)
						end
					end)
				end
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
					0,
					0.24
				)
			end,
			ExpectedType = "function",
		},

		hoverOn = {
			Value = function()
				tweenTabAssets(Tab, Icon, TextButton, Theme.PrimaryColor, Theme.TabBackgroundColor, 0.16, 0.3, 0.3, 0.18)
			end,
			ExpectedType = "function",
		},

		hoverOff = {
			Value = function()
				tweenTabAssets(Tab, Icon, TextButton, Theme.SecondaryTextColor, Theme.TabBackgroundColor, 1, 0, 0, 0.18)
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
		local function playTransition()
			Utility:tween(subTab, { TextColor3 = textColor, TextTransparency = textTransparency }, 0.25, "Quint", "Out")
				:Play()

			if not disableUnderlineTween then
				Utility:tween(underline, {
					BackgroundColor3 = Theme.PrimaryColor,
					Position = UDim2.new(0, subTabPosition, 1, 0),
					Size = UDim2.new(0, subTab.Size.X.Offset, 0, 2),
				}, 0.28, "Quint", "Out"):Play()
			end
		end

		if disableUnderlineTween or Library.NoAnimations then
			playTransition()
		else
			task.delay(0.04, function()
				if SubPage.Visible then
					playTransition()
				end
			end)
		end
	end

	local function autoCanvasSizeSubPageScrollingFrame()
		local max = math.max(Left.UIListLayout.AbsoluteContentSize.Y, Right.UIListLayout.AbsoluteContentSize.Y)
		SubPage.ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, max)
	end

	local function updateSectionAnimation()
		playTabSectionTransition(SubPage, 0.16)
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

	local SectionFrame = Assets.Pages.Section:Clone()
	local Section = Instance.new("CanvasGroup")
	Section.Name = "Section"
	Section.BackgroundTransparency = 1
	Section.BorderSizePixel = 0
	Section.GroupTransparency = 0
	Section.Size = SectionFrame.Size
	Section.Visible = true
	local sectionParent = options.position == "Single" and self.Left or self[options.position]
	Section.Parent = sectionParent

	SectionFrame.Name = "Content"
	SectionFrame.AnchorPoint = Vector2.zero
	SectionFrame.Position = UDim2.fromScale(0, 0)
	SectionFrame.Size = UDim2.fromScale(1, 1)
	SectionFrame.Visible = true
	SectionFrame.Parent = Section

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

	local Inner = SectionFrame.Inner

	local TextLabel = Inner.TextLabel
	TextLabel.Text = options.text

	-- section reorder + resize, persisted through the config system
	Library.SectionRegistry = Library.SectionRegistry or {}
	Library.SectionTextCounts = Library.SectionTextCounts or {}

	Library.SectionTextCounts[options.text] = (Library.SectionTextCounts[options.text] or 0) + 1
	local sectionKey = options.text .. "#" .. Library.SectionTextCounts[options.text]

	Library.SectionOrderCounter = (Library.SectionOrderCounter or 0) + 1
	Section.LayoutOrder = Library.SectionOrderCounter

	local function applySortOrder(folder)
		if folder then
			local layout = folder:FindFirstChildOfClass("UIListLayout")
			if layout then
				layout.SortOrder = Enum.SortOrder.LayoutOrder
			end
		end
	end

	applySortOrder(self.Left)
	applySortOrder(self.Right)

	Inner.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Section.Size = UDim2.new(1, 0, 0, Inner.UIListLayout.AbsoluteContentSize.Y + 28)
	end)

	do
		-- drag the header to reorder within the current column
		local dragging = false

		local function siblingSections()
			local list = {}
			for _, child in ipairs(Section.Parent:GetChildren()) do
				if child:IsA("GuiObject") and child.Name == "Section" then
					table.insert(list, child)
				end
			end
			table.sort(list, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			return list
		end

		local function reorderTo(mouseY)
			local others = {}
			for _, s in ipairs(siblingSections()) do
				if s ~= Section then
					table.insert(others, s)
				end
			end

			local insertIndex = #others + 1
			for i, s in ipairs(others) do
				if mouseY < s.AbsolutePosition.Y + s.AbsoluteSize.Y * 0.5 then
					insertIndex = i
					break
				end
			end

			table.insert(others, insertIndex, Section)
			for i, s in ipairs(others) do
				s.LayoutOrder = i
			end
		end

		local armed = false
		local pressY = 0

		TextLabel.Active = true
		TextLabel.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				armed = true
				pressY = UserInputService:GetMouseLocation().Y
			end
		end)

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if not armed or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local mouseY = UserInputService:GetMouseLocation().Y
			-- ignore tiny jitter: only start reordering once the pointer actually moves
			if not dragging and math.abs(mouseY - pressY) < 6 then
				return
			end
			dragging = true
			Section.ZIndex = 5
			pcall(function()
				reorderTo(mouseY)
			end)
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				armed = false
				dragging = false
				Section.ZIndex = 1
			end
		end)

		table.insert(Connections, moveConn)
		table.insert(Connections, endConn)
	end

	Library.SectionRegistry[sectionKey] = {
		getLayout = function()
			return { order = Section.LayoutOrder }
		end,
		setLayout = function(state)
			if type(state) == "table" and type(state.order) == "number" then
				Section.LayoutOrder = state.order
			end
		end,
	}

	Theme:registerToObjects({
		{ object = SectionFrame, property = "BackgroundColor3", theme = { "Line" } },
		{ object = Inner, property = "BackgroundColor3", theme = { "PrimaryBackgroundColor" } },
		{ object = TextLabel, property = "TextColor3", theme = { "PrimaryTextColor" } },
	})

	local PassingContext = setmetatable({ Section = Inner, ScrollingFrame = Section.Parent.Parent }, Library)
	return PassingContext
end

function Library:getSectionLayout()
	local data = {}
	for key, entry in pairs(Library.SectionRegistry or {}) do
		local ok, layout = pcall(entry.getLayout)
		if ok then
			data[tostring(key)] = layout
		end
	end
	return data
end

function Library:applySectionLayout(data)
	if type(data) ~= "table" then
		return
	end
	for key, entry in pairs(Library.SectionRegistry or {}) do
		local layout = data[tostring(key)]
		if layout then
			pcall(entry.setLayout, layout)
		end
	end
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
	if isPickerBoolean then
		registerAddonPopup(ColorPicker)
	end

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
	local dropdownLayer
	local dropdownIsOpen = false
	local dropdownSection = self.Section and self.Section:FindFirstAncestor("Section")
		or Dropdown:FindFirstAncestor("Section")
	local listPortal
	local listPortalVersion = 0

	local function getDropdownListSize(height)
		if listPortal then
			return UDim2.fromOffset(listPortal.width, height)
		end

		return UDim2.new(1, 0, 0, height)
	end

	local function updateDropdownPortalPosition()
		if not listPortal then
			return
		end

		local dropdownPosition = Dropdown.AbsolutePosition
		local overlayPosition = DropdownOverlay.AbsolutePosition
		local viewportPosition = scrollingFrame.AbsolutePosition
		local viewportSize = scrollingFrame.AbsoluteSize
		listPortal.clip.Position = UDim2.fromOffset(
			viewportPosition.X - overlayPosition.X,
			viewportPosition.Y - overlayPosition.Y
		)
		listPortal.clip.Size = UDim2.fromOffset(viewportSize.X, viewportSize.Y)
		List.Position = UDim2.fromOffset(
			dropdownPosition.X + listPortal.offset.X - viewportPosition.X,
			dropdownPosition.Y + listPortal.offset.Y - viewportPosition.Y
		)
	end

	local function portalDropdownList()
		if not dropdownSection then
			return
		end

		listPortalVersion += 1
		if listPortal then
			return
		end

		local absolutePosition = List.AbsolutePosition
		local absoluteSize = List.AbsoluteSize
		local clip = Instance.new("Frame")
		clip.Name = "DropdownClip"
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.Active = false
		clip.ClipsDescendants = true
		clip.ZIndex = DropdownOverlay.ZIndex
		clip.Parent = DropdownOverlay

		listPortal = {
			parent = List.Parent,
			position = List.Position,
			anchorPoint = List.AnchorPoint,
			size = List.Size,
			visible = List.Visible,
			width = math.max(absoluteSize.X, Dropdown.AbsoluteSize.X),
			offset = absolutePosition - Dropdown.AbsolutePosition,
			clip = clip,
		}

		List.Parent = clip
		List.AnchorPoint = Vector2.zero
		updateDropdownPortalPosition()
		List.Size = UDim2.fromOffset(listPortal.width, 0)
	end

	local function restoreDropdownPortal()
		if not listPortal then
			return
		end

		local portal = listPortal
		listPortal = nil
		List.Parent = portal.parent
		List.AnchorPoint = portal.anchorPoint
		List.Position = portal.position
		List.Size = portal.size
		List.Visible = portal.visible
		portal.clip:Destroy()
	end

	local function restoreDropdownLayer()
		if not dropdownLayer then
			return
		end

		for _, record in ipairs(dropdownLayer.zIndexes) do
			pcall(function()
				record.object.ZIndex = record.value
			end)
		end

		dropdownLayer = nil
		if Library.ActiveDropdownLayer == restoreDropdownLayer then
			Library.ActiveDropdownLayer = nil
		end
	end

	local function elevateDropdownLayer()
		if Library.ActiveDropdownLayer and Library.ActiveDropdownLayer ~= restoreDropdownLayer then
			pcall(Library.ActiveDropdownLayer)
		end
		restoreDropdownLayer()

		local root = dropdownSection or Dropdown
		local zIndexes = {}
		local queue = { root }
		local queueIndex = 1
		if listPortal then
			table.insert(queue, List)
		end

		while queueIndex <= #queue do
			local object = queue[queueIndex]
			queueIndex += 1

			if object:IsA("GuiObject") then
				table.insert(zIndexes, {
					object = object,
					value = object.ZIndex,
				})
				object.ZIndex += 200
			end

			for _, child in ipairs(object:GetChildren()) do
				table.insert(queue, child)
			end
		end

		local ancestor = root.Parent
		while ancestor and ancestor ~= Background do
			if ancestor:IsA("GuiObject") then
				table.insert(zIndexes, {
					object = ancestor,
					value = ancestor.ZIndex,
				})
				ancestor.ZIndex += 200
			end
			ancestor = ancestor.Parent
		end

		dropdownLayer = {
			zIndexes = zIndexes,
		}
		Library.ActiveDropdownLayer = restoreDropdownLayer
	end

	Dropdown:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if dropdownIsOpen then
			updateDropdownPortalPosition()
		end
	end)

	scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if dropdownIsOpen then
			updateDropdownPortalPosition()
		end
	end)

	scrollingFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if dropdownIsOpen then
			updateDropdownPortalPosition()
		end
	end)

	scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if dropdownIsOpen then
			updateDropdownPortalPosition()
		end
	end)

	DropButtons.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		DropButtons.CanvasSize =
			UDim2.new(0, 0, 0, DropButtons.UIListLayout.AbsoluteContentSize.Y + Inner.UIListLayout.Padding.Offset)
		DropButtons.Size = UDim2.new(
			1,
			0,
			0,
			math.clamp(DropButtons.UIListLayout.AbsoluteContentSize.Y + Inner.UIListLayout.Padding.Offset, 0, 164)
		)

		if dropdownIsOpen then
			local size = UDim2.new(0, 0, 0, math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210))
			Utility:tween(
				List,
				{ Size = getDropdownListSize(size.Y.Offset) },
				0.2,
				"Quart",
				"Out"
			):Play()

			for _, value in ipairs(self.DropdownSizes) do
				if value.object == Dropdown then
					scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - value.size + size
					value.size = size
					break
				end
			end
		end
	end)

	local function removeDropdownSize()
		for index = #Library.DropdownSizes, 1, -1 do
			local value = Library.DropdownSizes[index]
			if value.object == Dropdown then
				scrollingFrame.CanvasSize = scrollingFrame.CanvasSize - value.size
				table.remove(Library.DropdownSizes, index)
			end
		end
	end

	local function closeDropdownList()
		if dropdownIsOpen then
			dropdownIsOpen = false
			Library.dropdownOpen = math.max(0, Library.dropdownOpen - 1)
			Utility:tween(List, { Size = getDropdownListSize(0) }, 0.2, "Quart", "Out"):Play()
		end

		removeDropdownSize()
		listPortalVersion += 1
		local version = listPortalVersion
		task.delay(Library.NoAnimations and 0 or 0.2, function()
			if listPortalVersion == version and not dropdownIsOpen then
				restoreDropdownLayer()
				restoreDropdownPortal()
			end
		end)

		if Library.ActiveDropdownClose == closeDropdownList then
			Library.ActiveDropdownClose = nil
		end
	end

	local function toggleList()
		if not dropdownIsOpen then
			if Library.ActiveDropdownClose and Library.ActiveDropdownClose ~= closeDropdownList then
				pcall(Library.ActiveDropdownClose)
			end

			dropdownIsOpen = true
			portalDropdownList()
			elevateDropdownLayer()
			Library.dropdownOpen = Library.dropdownOpen + 1
			Library:forceHideTooltip()

			Utility:tween(
				List,
				{ Size = getDropdownListSize(math.clamp(Inner.UIListLayout.AbsoluteContentSize.Y, 0, 210)) },
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
			Library.ActiveDropdownClose = closeDropdownList
		else
			closeDropdownList()
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

	local function setDropdownValue(value)
		local requestedValues = type(value) == "table" and value or { value }
		local selectedValues = {}

		if Context.multiple then
			for _, listValue in ipairs(Context.list) do
				if table.find(requestedValues, listValue) then
					table.insert(selectedValues, listValue)
				end
			end
		else
			for _, listValue in ipairs(Context.list) do
				if listValue == requestedValues[1] then
					table.insert(selectedValues, listValue)
					break
				end
			end

			if selectedValues[1] == nil then
				return
			end
		end

		for _, dropButton in ipairs(DropButtons:GetChildren()) do
			if dropButton.Name == "DropButton" then
				local selected = false
				for _, selectedValue in ipairs(selectedValues) do
					if dropButton.TextLabel.Text == tostring(selectedValue) then
						selected = true
						break
					end
				end

				if selected then
					tweenDropButton(dropButton.TextButton, Theme.PrimaryColor, 0)
				else
					tweenDropButton(dropButton.TextButton, Theme.SecondaryBackgroundColor, 1)
				end
			end
		end

		if Context.multiple then
			local selectedText = {}
			for _, selectedValue in ipairs(selectedValues) do
				table.insert(selectedText, tostring(selectedValue))
			end

			Dropdown.default = selectedValues
			Dropdown.multipleTable = selectedValues
			Dropdown.value = selectedValues
			TextButton.Text = selectedText[1] and table.concat(selectedText, ", ") or "None"
		else
			Dropdown.default = { selectedValues[1] }
			Dropdown.multipleTable = {}
			Dropdown.value = selectedValues[1]
			TextButton.Text = tostring(selectedValues[1])
		end

		pcall(Context.callback, Dropdown.value)
	end

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

		setValue = function(self, value)
			setDropdownValue(value)
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

		setValue = function(self, value)
			setDropdownValue(value)
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

	local function setKeybindValue(bind)
		bind = type(bind) == "string" and bind or "None"
		local currentBind = TextButton.Text

		if currentBind ~= bind and currentBind ~= "None" then
			for index = #Exclusions, 1, -1 do
				if Exclusions[index] == currentBind then
					table.remove(Exclusions, index)
					break
				end
			end
		end

		TextButton.Text = bind
		Context.default = bind

		if bind ~= "None" and not table.find(Exclusions, bind) then
			table.insert(Exclusions, bind)
		end
	end

	-- release any focused TextBox before capture starts, otherwise its input focus makes
	-- key presses arrive as gameProcessedEvent and the module silently drops the bind
	TextButton.MouseButton1Down:Connect(function()
		pcall(function()
			local focused = UserInputService:GetFocusedTextBox()
			if focused then
				focused:ReleaseFocus()
			end
		end)
	end)

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

		setKeybind = function(self, bind)
			setKeybindValue(bind)
		end,
	}

	return self:createAddons(options.text, ImageButton, scrollingFrame, {
		getKeybind = function(self)
			return TextButton.Text
		end,

		updateKeybind = function(self, options: table)
			Keybind:updateKeybind(options)
		end,

		setKeybind = function(self, bind)
			setKeybindValue(bind)
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
		if Library.ActiveDropdownClose then
			pcall(Library.ActiveDropdownClose)
		end

		Library.sizeX = Glow.AbsoluteSize.X
		Library.sizeY = Glow.AbsoluteSize.Y
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

function Library:loadBeta(options: table)
	
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

	local function getHeader(headers, headerName: string)
		for key, value in pairs(headers or {}) do
			if string.lower(tostring(key)) == string.lower(headerName) then
				return value
			end
		end

		return nil
	end

	local function requestApi(method: string, path: string, body)
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

		SavedData.SectionLayout = Library:getSectionLayout()

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
					SavedData.Dropdown[elementName] = { value = addon:getValue() }
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
					local dropdown = shared.Flags.Dropdown[elementName]
					local savedValue = decoded.Dropdown[elementName].value
					if dropdown.setValue then
						dropdown:setValue(savedValue)
					else
						local defaultValue = type(savedValue) == "table" and savedValue or { savedValue }
						local currentList = dropdown:getList()
						if type(currentList) ~= "table" then
							currentList = {}
						end

						dropdown:updateList({
							list = currentList,
							default = defaultValue,
						})
					end
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
					local keybind = shared.Flags.Keybind[elementName]
					local savedBind = decoded.Keybind[elementName].keybind
					if keybind.setKeybind then
						keybind:setKeybind(savedBind)
					else
						keybind:updateKeybind({ bind = savedBind })
					end
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

		Library:applySectionLayout(decoded.SectionLayout)

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

	local SettingsTab = Library:createTab({ text = "UI", icon = options.icon })

	local ConfigPage = SettingsTab:createSubTab({ text = "Config", sectionStyle = "Double" })
	local ThemePage = SettingsTab:createSubTab({ text = "Theme", sectionStyle = "Double" })

	local SaveManager = ConfigPage:createSection({ text = "Configs" })

	local UI = ThemePage:createSection({ text = "UI" })
	local ThemeManager = ThemePage:createSection({ position = "Right", text = "Theme Manager" })
	local Logo
	if not UserIsPoor then
		Logo = ThemePage:createSection({ text = "Logo" })
	end

	function createNaturalRainbowEffect(titleIcon)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end

		Library.LogoRainbow = true

		local originalColor = titleIcon:IsA("ViewportFrame") and Library.LogoColor or Library.Theme.PrimaryTextColor
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
		Library.LogoRainbow = false

		if titleIcon:IsA("ViewportFrame") then
			titleIcon.ImageColor3 = Library.LogoColor
		else
			titleIcon.ImageColor3 = Library.Theme.PrimaryTextColor

			Theme:registerToObjects({
				{ object = titleIcon, property = "ImageColor3", theme = { "PrimaryTextColor" } },
			})
		end
	end

	UI:createToggle({
		text = "No Animations",
		state = false,
		tooltip = "Disables all UI animations (tab loads, toggles, sliders, fades).",
		callback = function(state)
			Library.NoAnimations = state
		end,
	})

	UI:createToggle({
		text = "Skip Intro",
		state = Library.SkipIntro,
		tooltip = "Skips the logo intro the next time the UI loads.",
		callback = function(state)
			Library.SkipIntro = state

			pcall(function()
				if not isfolder(SKIP_INTRO_FOLDER) then
					makefolder(SKIP_INTRO_FOLDER)
				end

				writefile(SKIP_INTRO_PATH, state and "true" or "false")
			end)
		end,
	})

	if not UserIsPoor then
		Logo:createToggle({
			text = "Show Logo",
			state = true,
			callback = function(state)
				Library.IconVisible = state
				local TitleIcon = Title:FindFirstChild("TitleIcon")
				if TitleIcon then
					TitleIcon.Visible = state
					if state then
						Title.Text = "        " .. (Library.Title or "Leny")
					else
						Title.Text = Library.Title or "Leny"
					end
				end
			end,
		})

		Logo:createSlider({
			text = "Logo Spin Speed",
			default = Library.LogoSpinSpeed,
			min = 0,
			max = 1.5,
			callback = function(value)
				Library.LogoSpinSpeed = value
			end,
		})

		Logo:createSlider({
			text = "Logo Size",
			default = Library.LogoSize,
			min = 28,
			max = 48,
			step = 1,
			callback = function(value)
				Library.LogoSize = value

				local TitleIcon = Title:FindFirstChild("TitleIcon")
				if TitleIcon then
					TitleIcon.Size = UDim2.fromOffset(value, value)
				end
			end,
		})

		Logo:createPicker({
			text = "Logo Color",
			default = Library.LogoColor,
			callback = function(color)
				Library.LogoColor = color

				local TitleIcon = Title:FindFirstChild("TitleIcon")
				if TitleIcon and not Library.LogoRainbow then
					TitleIcon.ImageColor3 = color
				end
			end,
		})

		Logo:createToggle({
			text = "Logo Color Pulse",
			state = true,
			callback = function(state)
				Library.LogoColorEffect = state
			end,
		})

		Logo:createToggle({
			text = "Rainbow Logo",
			state = Library.LogoRainbow,
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

	-- config management: name a new config or target the selected one, then act on it
	local configName = SaveManager:createTextBox({ text = "Config Name" })
	local Configs = SaveManager:createDropdown({ text = "Configs", list = jsons })
	local importCode = nil
	local lastShareCode = ""

	local function selectedConfig()
		local value = Configs:getValue()
		if type(value) == "table" then
			value = value[1] or ""
		end
		return value
	end

	local function refreshConfigsList(selected)
		Configs:updateList({ list = getJsons(), default = selected and { selected } or {} })
	end

	-- creates a new config from the typed name, otherwise overwrites the selected one
	SaveManager:createButton({
		text = "Save Config",
		callback = function()
			local name = configName:getText()
			if not name or name == "" then
				name = selectedConfig()
			end
			if not name or name == "" or name == "None" then
				Library:notify({ title = "Save Config", text = "Enter a name or select a config first.", duration = 4 })
				return
			end
			writefile(options.folderName .. "/" .. name .. ".json", HttpService:JSONEncode(getSavedData()))
			refreshConfigsList(name)
			Library:notify({ title = "Save Config", text = 'Saved "' .. name .. '".', duration = 3 })
		end,
	})

	SaveManager:createButton({
		text = "Load Config",
		callback = function()
			local name = selectedConfig()
			if name and name ~= "" and name ~= "None" then
				loadSaveConfig(name)
				Library:notify({ title = "Load Config", text = 'Loaded "' .. name .. '".', duration = 3 })
			end
		end,
	})

	SaveManager:createButton({
		text = "Delete Config",
		callback = function()
			local name = selectedConfig()
			if not name or name == "" or name == "None" then
				return
			end
			local filePath = options.folderName .. "/" .. name .. ".json"
			if isfile and delfile and isfile(filePath) then
				delfile(filePath)
				refreshConfigsList(nil)
				Library:notify({ title = "Delete Config", text = 'Deleted "' .. name .. '".', duration = 3 })
			end
		end,
	})

	SaveManager:createButton({
		text = "Set as Auto Load",
		callback = function()
			local name = selectedConfig()
			if name and name ~= "" and name ~= "None" then
				writefile(options.folderName .. "/autoload.txt", name)
				Library:notify({ title = "Auto Load", text = 'Auto-loading "' .. name .. '".', duration = 3 })
			end
		end,
	})

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

	local function notifyApiError(statusCode: number, isExport: boolean, responseHeaders)
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
		local Sharing = ConfigPage:createSection({ text = "Imports", position = "Right" })
		importCode = Sharing:createTextBox({
			text = "Import Share Code",
			tooltip = "Paste a 5-character share code here, then press Import Settings to load that config.",
		})

		Sharing:createButton({
			text = "Import Settings",
			tooltip = "Loads the config from the share code you entered above.",
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

		Sharing:createButton({
			text = "Export Settings",
			tooltip = "Uploads your current config and copies a share code to your clipboard.",
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

		Sharing:createButton({
			text = "Copy Share Code",
			tooltip = "Copies your last generated share code to the clipboard again.",
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

if isMobile then
	Glow.Active = true
	Glow.Draggable = true
else
	Utility:draggable(Library, Glow)
end

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
