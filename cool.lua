--[[
	ModernGui.client.lua  --  Lumen
	Author: ZaneGwapo

	INSTALL
		Put this LocalScript in StarterPlayer > StarterPlayerScripts (or
		StarterGui) and press Play. The panel opens on join. Afterwards use
		the floating button, or press M. Escape and the X button close it.

	NOTES
		* Fully self-contained: no assets, no plugins, no other scripts. The
		  only optional extra is CONFIG.Logo, an image you supply yourself;
		  left empty, every brand mark falls back to the accent gradient.
		* Everything is client-side and cosmetic (GUI-only). Nothing here
		  pretends to perform server-authoritative actions.
		* Colours, radii, type sizes and motion timings live in the Theme
		  and Motion tables. The Visuals and Settings tabs change them live.
		* Re-running the script replaces the previous copy cleanly.
		* 2.1.0 adds: loading screen + password gate, profile card, FPS Boost
		  and a Game info section (all on the Home page).
		* 2.2.0 adds: Misc tab + config manager, background theme picker, custom
		  accent hue, egg sort dropdown, Auto Max Upgrade, waiting auto farm and a
		  self-healing ESP driver.
		* 2.3.0 fixes the access gate (it never released its click-blocker, which
		  made the panel unreachable), rebuilds window dragging with time-based
		  smoothing and release glide, and adds a glass loading card.
		* 2.4.0 renames the tabs to Home, Eggs, Automation, Visuals, Configs,
		  Settings and About; folds the old Main page into Settings, moves
		  Utilities onto Automation, and folds the egg work into a single live
		  model so the scanner, the list, the farm and the placer all read the
		  same set of eggs instead of each walking the folder. Auto farm now
		  wakes the instant an egg spawns or is taken, Home carries the farm and
		  place quick actions with a live status card and rarity breakdown, a new
		  Auto place mode fills the plot's egg slots with the rarest eggs it can
		  find, and a "Remember me" box on the gate skips the password next run.
	* 2.4.1 fixes three icons that were pinned to the top edge of their row
	  (UDim2.fromOffset misuse), the nearest-egg return value, and redraws the
	  whole icon set as consistent round-capped outline glyphs.
	* Branding pass: the Lumen logo (embedded, transparent) is the main mark on
	  the loading screen and password gate and a compact mark in the sidebar. See
	  CONFIG.Logo / LogoCompact / LogoFile.
	* Polish pass (Fluent-inspired UX, Lumen's own implementation): collapsible
	  section headers, an animated inline Dropdown (startup config), sidebar tab
	  pinning, 7 more accent themes and 6 more backgrounds, an optional border
	  shimmer, a draggable floating button that remembers its place, and new
	  glyphs (moon, gauge, server, save, clock, layers, bookmark) so each feature
	  has its own icon.
--]]


--------------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------

local CONFIG = {
	Title = "Lumen",
	Author = "ZaneGwapo",
	Version = "2.4.0",
	GuiName = "ModernGui",
	BlurName = "ModernGuiBlur",
	-- Optional brand image. Paste an rbxassetid or an http(s) image URL here and
	-- every brand mark in the interface switches to it. Left empty on purpose, so
	-- the interface falls back to the built-in accent mark that needs no upload.
	Logo = "",
	-- Optional icon-only variant for the small sidebar mark. Same formats as Logo.
	-- Empty means the sidebar reuses Logo.
	LogoCompact = "",
	-- Where the embedded Lumen logo is cached inside the executor workspace. It is
	-- only written when Logo is empty and the executor has file access.
	LogoFile = "ModernGui/lumen_logo.png",
	-- Optional direct link to a PNG of the logo (for example a GitHub raw link:
	-- https://raw.githubusercontent.com/<you>/<repo>/main/lumen_logo.png).
	-- Executors only: it needs request/http_request plus writefile and
	-- getcustomasset. It is downloaded once and cached in the workspace; if the
	-- download fails the embedded logo is used instead. Leave empty to skip.
	LogoUrl = "",
	-- How this script is started again in the NEW server after a hop. Executors
	-- only, and only needed when the script is not already auto-executed:
	-- ReloadUrl is a link loadstring can fetch, ReloadFile a path in the executor
	-- workspace. Leave both empty if your executor re-runs it by itself.
	ReloadUrl = "",
	ReloadFile = "",
	LogoUrlFile = "ModernGui/lumen_logo_download.png",
	ToggleKey = Enum.KeyCode.M,
	AutoOpen = true,
	PanelSize = Vector2.new(940, 560),
	MinPanelSize = Vector2.new(460, 320),
	CompactBelow = 720, -- panel width (unscaled) under which the sidebar collapses to icons
	SidebarWide = 196,
	SidebarCompact = 64,
	BlurSize = 18,
	MaxToasts = 3,
	Password = "ZaneGwapoKaayo sa tanan", -- access gate (exact match)
	MaxAttempts = 5, -- wrong tries before a short lock
	LockSeconds = 10,
}

-- Every user-adjustable setting, with its shipped value. "Reset UI" restores these.
local DEFAULTS = {
	UIScale = 1,
	PanelTransparency = 6, -- percent
	AnimSpeed = 1,
	ReduceMotion = false,
	Blur = true,
	Ambient = true,
	Notifications = true,
	AccentIndex = 1,
	Gradient = true,
	Roundness = 1,
	AmbientStrength = 1,
	FpsOverlay = false,
	QuickOverlay = false,
	QuickOverlayDetails = true,
	Shimmer = true, -- slow accent highlight travelling round the window border
	-- AFK mode itself is runtime-only (never a default that survives a restart);
	-- these two are real preferences.
	AfkPause3D = true,
	AutoHop = false,
	HopMinutes = 5,
	DebugMode = false,
	Crosshair = false,
	CrosshairSize = 10,
	FpsBoost = false,
	EggsESP = false,
	EggsHighlight = true,
	EggsTPHeight = 10,
	EggsSmoothMove = true,
	EggsMoveSpeed = 500,
	EggsHoldTime = 3,
	EggsAutoFarm = false,
	EggsAutoPlace = false,
	EggsPlaceSlots = 2,
	EggsSort = "Best",
	AutoMaxUpgrade = false,
	BgPreset = 1, -- 0 = custom (uses the three sliders below)
	BgHue = 230,
	BgSat = 40,
	BgVal = 13,
	AccentHue = 265,
}

local State = {}
for key, value in pairs(DEFAULTS) do
	State[key] = value
end

-- Replace any previous copy of the interface instead of stacking a second one.
-- Destroying the old ScreenGui also triggers that copy's own cleanup.
do
	local existing = playerGui:FindFirstChild(CONFIG.GuiName)
	if existing then
		existing:Destroy()
	end
	local staleBlur = Lighting:FindFirstChild(CONFIG.BlurName)
	if staleBlur then
		staleBlur:Destroy()
	end
end

--------------------------------------------------------------------------
-- THEME
--------------------------------------------------------------------------

local Theme = {
	Color = {
		Cover = Color3.fromRGB(6, 7, 13),
		Surface = Color3.fromRGB(20, 22, 33),
		Alt = Color3.fromRGB(30, 33, 48),
		White = Color3.new(1, 1, 1),
		TextHi = Color3.fromRGB(243, 245, 255),
		TextMid = Color3.fromRGB(170, 176, 200),
		TextLow = Color3.fromRGB(132, 139, 165),
		Positive = Color3.fromRGB(58, 205, 148),
		Caution = Color3.fromRGB(255, 190, 92),
		Negative = Color3.fromRGB(255, 96, 112),
		Info = Color3.fromRGB(96, 165, 250),
	},
	Radius = { XS = 6, SM = 9, MD = 13, LG = 18, XL = 24, Pill = 999 },
	Type = { Display = 24, Title = 17, Heading = 15, Body = 14, Caption = 12, Micro = 11 },
}

local ACCENTS = {
	{ Name = "Violet", A = Color3.fromRGB(129, 96, 255), B = Color3.fromRGB(64, 216, 226) },
	{ Name = "Ocean", A = Color3.fromRGB(59, 130, 246), B = Color3.fromRGB(34, 211, 238) },
	{ Name = "Emerald", A = Color3.fromRGB(16, 185, 129), B = Color3.fromRGB(163, 230, 53) },
	{ Name = "Sunset", A = Color3.fromRGB(249, 115, 22), B = Color3.fromRGB(244, 63, 94) },
	{ Name = "Rose", A = Color3.fromRGB(236, 72, 153), B = Color3.fromRGB(168, 85, 247) },
	-- Added with the theme pass. Lumen is the brand's own blue (the logo's
	-- gradient), the rest are distinct moods rather than hue nudges. Saved
	-- configs refer to an accent by NAME, so adding or reordering is safe.
	{ Name = "Lumen", A = Color3.fromRGB(36, 120, 255), B = Color3.fromRGB(110, 205, 255) },
	{ Name = "Aurora", A = Color3.fromRGB(45, 212, 191), B = Color3.fromRGB(129, 140, 248) },
	{ Name = "Amber", A = Color3.fromRGB(251, 191, 36), B = Color3.fromRGB(249, 115, 22) },
	{ Name = "Crimson", A = Color3.fromRGB(239, 68, 68), B = Color3.fromRGB(251, 146, 60) },
	{ Name = "Neon", A = Color3.fromRGB(0, 245, 160), B = Color3.fromRGB(0, 160, 255) },
	{ Name = "Candy", A = Color3.fromRGB(244, 114, 182), B = Color3.fromRGB(125, 211, 252) },
	{ Name = "Silver", A = Color3.fromRGB(203, 213, 225), B = Color3.fromRGB(148, 163, 184) },
	-- Always the last entry; its colours are rebuilt from State.AccentHue.
	{
		Name = "Custom",
		Custom = true,
		A = Color3.fromHSV(DEFAULTS.AccentHue / 360, 0.68, 1),
		B = Color3.fromHSV(((DEFAULTS.AccentHue + 40) % 360) / 360, 0.62, 1),
	},
}

local TONES = {
	Success = { Color = Theme.Color.Positive, Icon = "check" },
	Info = { Color = Theme.Color.Info, Icon = "info" },
	Warning = { Color = Theme.Color.Caution, Icon = "warn" },
	Error = { Color = Theme.Color.Negative, Icon = "close" },
}
TONES.Caution = TONES.Warning

-- The live accent. Everything accent-coloured registers a binding so a
-- single change repaints the whole interface.
local Accent = { Color = ACCENTS[1].A, Color2 = ACCENTS[1].B, On = Color3.new(1, 1, 1), Text = ACCENTS[1].A }
do
	local ON_DARK = Color3.fromRGB(12, 14, 24)
	local function luminance(color)
		local function lin(v)
			if v <= 0.03928 then
				return v / 12.92
			end
			return ((v + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * lin(color.R) + 0.7152 * lin(color.G) + 0.0722 * lin(color.B)
	end

	-- Accent.On   = colour for text/icons drawn ON an accent fill (dark on light accents).
	-- Accent.Text = accent used as text on dark surfaces (dark accents are lifted).
	function Accent.Derive()
		local average = (luminance(Accent.Color) + luminance(Accent.Color2)) / 2
		Accent.On = average > 0.3 and ON_DARK or Color3.new(1, 1, 1)
		local lum = luminance(Accent.Color)
		local lift = lum < 0.1 and 0.5 or (lum < 0.2 and 0.3 or 0.08)
		Accent.Text = Accent.Color:Lerp(Color3.new(1, 1, 1), lift)
		-- Info toasts follow the accent so notifications match the theme.
		TONES.Info.Color = Accent.Color
	end
end
Accent.Derive()
local accentBinds = {}

local function bindAccent(callback)
	table.insert(accentBinds, callback)
	callback(Accent.Color, Accent.Color2)
end

local function applyAccent()
	local preset = ACCENTS[State.AccentIndex] or ACCENTS[1]
	if preset.Custom then
		local hue = (State.AccentHue % 360) / 360
		preset.A = Color3.fromHSV(hue, 0.68, 1)
		preset.B = Color3.fromHSV((hue + 40 / 360) % 1, 0.62, 1)
	end
	Accent.Color = preset.A
	Accent.Color2 = State.Gradient and preset.B or preset.A
	Accent.Derive()
	for _, callback in ipairs(accentBinds) do
		callback(Accent.Color, Accent.Color2)
	end
end

local function setAccent(index)
	State.AccentIndex = index
	applyAccent()
end

--------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------

-- BACKGROUND THEME -------------------------------------------------------
-- Every GuiObject created with one of the three base surface colours is
-- registered under a role (Cover / Surface / Alt). Changing the background
-- theme rewrites Theme.Color and repaints the registered objects, so existing
-- and future controls stay in sync without rebuilding anything.
local Bg = {
	Role = setmetatable({}, { __mode = "k" }),
	Base = { Cover = Theme.Color.Cover, Surface = Theme.Color.Surface, Alt = Theme.Color.Alt },
	Binds = {},
	Silent = false,
	Presets = {
		{ Name = "Midnight", Cover = Theme.Color.Cover, Surface = Theme.Color.Surface, Alt = Theme.Color.Alt },
		{ Name = "Graphite", Cover = Color3.fromRGB(9, 9, 11), Surface = Color3.fromRGB(24, 24, 28), Alt = Color3.fromRGB(37, 37, 43) },
		{ Name = "Ocean Night", Cover = Color3.fromRGB(4, 10, 18), Surface = Color3.fromRGB(13, 26, 42), Alt = Color3.fromRGB(21, 39, 61) },
		{ Name = "Forest", Cover = Color3.fromRGB(5, 12, 10), Surface = Color3.fromRGB(15, 30, 26), Alt = Color3.fromRGB(23, 45, 38) },
		{ Name = "Plum", Cover = Color3.fromRGB(12, 7, 16), Surface = Color3.fromRGB(30, 20, 39), Alt = Color3.fromRGB(45, 30, 58) },
		{ Name = "Crimson", Cover = Color3.fromRGB(14, 6, 8), Surface = Color3.fromRGB(35, 18, 22), Alt = Color3.fromRGB(52, 28, 34) },
		-- Theme pass. All stay inside the brightness cap the sliders use, so
		-- the light text colours remain readable on every one of them.
		{ Name = "AMOLED", Cover = Color3.fromRGB(0, 0, 0), Surface = Color3.fromRGB(6, 6, 8), Alt = Color3.fromRGB(17, 17, 21) },
		{ Name = "Midnight Blue", Cover = Color3.fromRGB(3, 6, 18), Surface = Color3.fromRGB(10, 16, 38), Alt = Color3.fromRGB(17, 26, 58) },
		{ Name = "Charcoal", Cover = Color3.fromRGB(12, 12, 13), Surface = Color3.fromRGB(28, 28, 30), Alt = Color3.fromRGB(44, 44, 47) },
		{ Name = "Galaxy", Cover = Color3.fromRGB(8, 4, 20), Surface = Color3.fromRGB(20, 12, 44), Alt = Color3.fromRGB(32, 20, 66) },
		{ Name = "Deep Teal", Cover = Color3.fromRGB(3, 12, 14), Surface = Color3.fromRGB(10, 30, 34), Alt = Color3.fromRGB(16, 46, 52) },
		{ Name = "Espresso", Cover = Color3.fromRGB(12, 8, 6), Surface = Color3.fromRGB(32, 22, 18), Alt = Color3.fromRGB(48, 34, 28) },
	},
}

function Bg.RoleOf(color)
	for name, base in pairs(Bg.Base) do
		if color == base or color == Theme.Color[name] then
			return name
		end
	end
	return nil
end

-- Brightness is capped so the light text colours stay readable on any result.
function Bg.Colors()
	local preset = Bg.Presets[State.BgPreset]
	if preset then
		return preset.Cover, preset.Surface, preset.Alt
	end
	local hue = (State.BgHue % 360) / 360
	local sat = math.clamp(State.BgSat, 0, 100) / 100
	local val = math.clamp(State.BgVal, 2, 18) / 100
	return Color3.fromHSV(hue, sat, val * 0.4),
		Color3.fromHSV(hue, sat, val),
		Color3.fromHSV(hue, sat * 0.9, math.min(val * 1.42 + 0.01, 0.26))
end

function Bg.Apply()
	local cover, surface, alt = Bg.Colors()
	Theme.Color.Cover, Theme.Color.Surface, Theme.Color.Alt = cover, surface, alt
	for instance, role in pairs(Bg.Role) do
		if instance.Parent then
			instance.BackgroundColor3 = Theme.Color[role]
		end
	end
	for _, callback in ipairs(Bg.Binds) do
		callback()
	end
end
-- Creates an instance, applies props, and parents last (cheaper and avoids
-- layout thrash from parenting a half-configured object).
local function New(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if props and props.BackgroundColor3 ~= nil then
		local role = Bg.RoleOf(props.BackgroundColor3)
		if role then
			Bg.Role[instance] = role
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function shade(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- Running LayoutOrder counter per parent, so siblings keep creation order.
local nextOrder
do
	local orderCounters = setmetatable({}, { __mode = "k" })
	nextOrder = function(parent)
		local n = (orderCounters[parent] or 0) + 1
		orderCounters[parent] = n
		return n
	end
end

-- Corner radii are registered so the "Corner roundness" slider can rescale them.
local cornerRegistry = setmetatable({}, { __mode = "k" })
local function scaledRadius(base)
	if base >= Theme.Radius.Pill then
		return base
	end
	return math.floor(base * State.Roundness + 0.5)
end

local function Round(instance, radius)
	local corner = New("UICorner", { CornerRadius = UDim.new(0, scaledRadius(radius)), Parent = instance })
	if radius < Theme.Radius.Pill then
		cornerRegistry[corner] = radius
	end
	return corner
end

local function refreshCorners()
	for corner, base in pairs(cornerRegistry) do
		corner.CornerRadius = UDim.new(0, scaledRadius(base))
	end
end

local function Stroke(instance, transparency, color, thickness)
	return New("UIStroke", {
		Color = color or Theme.Color.White,
		Thickness = thickness or 1,
		Transparency = transparency or 0.9,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = instance,
	})
end

local function Padding(instance, top, right, bottom, left)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		Parent = instance,
	})
end

local function AccentGradient(parent, rotation, transparency)
	local gradient = New("UIGradient", { Rotation = rotation or 0, Parent = parent })
	if transparency then
		gradient.Transparency = transparency
	end
	bindAccent(function(a, b)
		gradient.Color = ColorSequence.new(a, b)
	end)
	return gradient
end

-- Gotham (GothamSSm) with real weights; falls back to the legacy enum fonts.
local applyFont
do
local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local FALLBACK_FONTS = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	SemiBold = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}
local fontCache = {}

applyFont = function(gui, weight)
	local face = fontCache[weight]
	if face == nil then
		local ok, result = pcall(function()
			return Font.new(FONT_FAMILY, Enum.FontWeight[weight], Enum.FontStyle.Normal)
		end)
		face = ok and result or false
		fontCache[weight] = face
	end
	if face then
		gui.FontFace = face
	else
		gui.Font = FALLBACK_FONTS[weight] or Enum.Font.Gotham
	end
end
end

-- props.Wrap = true makes a multi-line label that grows to fit its text.
local function Text(parent, content, size, weight, color, props)
	local label = New("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = content,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, size + 6),
	})
	applyFont(label, weight)
	if props then
		for key, value in pairs(props) do
			if key == "Wrap" then
				if value then
					label.TextWrapped = true
					label.TextTruncate = Enum.TextTruncate.None
					label.TextYAlignment = Enum.TextYAlignment.Top
					label.AutomaticSize = Enum.AutomaticSize.Y
				end
			else
				label[key] = value
			end
		end
	end
	label.Parent = parent
	return label
end

--------------------------------------------------------------------------
-- ANIMATION HELPERS
--------------------------------------------------------------------------

local Motion = { Swift = 0.14, Quick = 0.2, Base = 0.28, Reveal = 0.4 }

local EASE = {
	Out = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
	Soft = { Enum.EasingStyle.Quart, Enum.EasingDirection.Out },
	In = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	Back = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
	Sine = { Enum.EasingStyle.Sine, Enum.EasingDirection.InOut },
}

-- Honour the OS / Roblox reduced-motion preference if this client exposes it.
local systemReducedMotion = false
do
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	if ok and type(value) == "boolean" then
		systemReducedMotion = value
	end
end

local function motionReduced()
	return State.ReduceMotion or State.FpsBoost or systemReducedMotion
end

local function scaledTime(seconds)
	if motionReduced() then
		return 0.001
	end
	return math.max(0.001, seconds / math.max(State.AnimSpeed, 0.1))
end

-- The one tween entry point. Durations honour the animation-speed slider and
-- the reduce-animations toggle, so nothing else builds TweenInfo by hand.
local function play(target, seconds, ease, props, delay)
	if not target then
		return nil
	end
	local style = EASE[ease] or EASE.Out
	local wait = 0
	if delay and not motionReduced() then
		wait = delay / math.max(State.AnimSpeed, 0.1)
	end
	local info = TweenInfo.new(scaledTime(seconds), style[1], style[2], 0, false, wait)
	local tween = TweenService:Create(target, info, props)
	tween:Play()
	return tween
end

--------------------------------------------------------------------------
-- ICONS
--
-- Drawn from primitives on a 20x20 grid (no image assets), then scaled with
-- a UIScale inside a fixed-size holder so layouts see the real pixel size.
--------------------------------------------------------------------------

local ICONS = {}
do

-- Stroke weight shared by every glyph so the set reads at one optical size.
local SW = 1.8

local function iconPart(canvas, x, y, w, h, color, radius, rotation)
	local part = New("Frame", {
		Name = "Part",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset(x, y),
		Rotation = rotation or 0,
		Parent = canvas,
	})
	if radius then
		New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = part })
	end
	return part
end

-- A round-capped line between two points on the 20x20 grid.
local function line(canvas, x1, y1, x2, y2, color, width)
	width = width or SW
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy) + width
	local part = iconPart(canvas, 0, 0, length, width, color, width / 2, math.deg(math.atan2(dy, dx)))
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	return part
end

-- Connected round-capped lines; the caps double as round joins.
local function poly(canvas, points, color, width)
	for i = 1, #points - 1 do
		line(canvas, points[i].X, points[i].Y, points[i + 1].X, points[i + 1].Y, color, width)
	end
end

local function dot(canvas, x, y, diameter, color)
	local part = iconPart(canvas, 0, 0, diameter, diameter, color, diameter / 2)
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromOffset(x, y)
	return part
end

-- Outlined rounded rectangle; (x, y, w, h, r) describe the stroke centreline.
local function box(canvas, x, y, w, h, r, color, width)
	width = width or SW
	local part = iconPart(
		canvas, x + width / 2, y + width / 2, w - width, h - width, color, math.max(0, r - width / 2)
	)
	part.BackgroundTransparency = 1
	New("UIStroke", {
		Color = color,
		Thickness = width,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = part,
	})
	return part
end

local function circle(canvas, cx, cy, r, color, width)
	return box(canvas, cx - r, cy - r, r * 2, r * 2, r, color, width)
end

-- Arc from angle a1 to a2 in degrees (0 = right, 90 = down). Returns the end
-- point and the direction of travel there, which arrowheads use.
local function arc(canvas, cx, cy, r, a1, a2, color, width)
	local steps = math.max(3, math.ceil(math.abs(a2 - a1) / 22))
	local points = {}
	for i = 0, steps do
		local a = math.rad(a1 + (a2 - a1) * i / steps)
		points[#points + 1] = Vector2.new(cx + r * math.cos(a), cy + r * math.sin(a))
	end
	poly(canvas, points, color, width)
	local heading = a2 + (a2 >= a1 and 90 or -90)
	return points[#points], heading
end

local function arrowhead(canvas, tip, heading, size, color, width)
	for _, offset in ipairs({ -42, 42 }) do
		local a = math.rad(heading + 180 + offset)
		line(canvas, tip.X, tip.Y, tip.X + size * math.cos(a), tip.Y + size * math.sin(a), color, width)
	end
end

local function bezier(a, control, b, steps)
	local points = {}
	for i = 0, steps do
		local t = i / steps
		points[#points + 1] = a * (1 - t) ^ 2 + control * (2 * (1 - t) * t) + b * (t * t)
	end
	return points
end

-- Rounds the corners of a polyline (or closed polygon) with small curves.
local function roundedPath(points, radius, closed)
	local n = #points
	local out = {}
	local first, last = closed and 1 or 2, closed and n or n - 1
	if not closed then
		out[#out + 1] = points[1]
	end
	for i = first, last do
		local prev = points[(i - 2) % n + 1]
		local cur = points[i]
		local nxt = points[i % n + 1]
		local toPrev, toNext = prev - cur, nxt - cur
		local r = math.min(radius, toPrev.Magnitude / 2, toNext.Magnitude / 2)
		for _, p in ipairs(bezier(cur + toPrev.Unit * r, cur, cur + toNext.Unit * r, 4)) do
			out[#out + 1] = p
		end
	end
	if not closed then
		out[#out + 1] = points[n]
	else
		out[#out + 1] = out[1]
	end
	return out
end

local function V(x, y)
	return Vector2.new(x, y)
end

local function outline(canvas, points, radius, closed, color, width)
	poly(canvas, roundedPath(points, radius, closed), color, width)
end

ICONS.grid = function(canvas, c)
	box(canvas, 3, 3, 6, 6, 1.8, c)
	box(canvas, 11, 3, 6, 6, 1.8, c)
	box(canvas, 3, 11, 6, 6, 1.8, c)
	box(canvas, 11, 11, 6, 6, 1.8, c)
end

ICONS.home = function(canvas, c)
	outline(canvas, { V(2.6, 9.6), V(10, 3), V(17.4, 9.6) }, 0.8, false, c)
	outline(canvas, { V(4.6, 8.6), V(4.6, 16.8), V(15.4, 16.8), V(15.4, 8.6) }, 1.4, false, c)
	outline(canvas, { V(8, 16.8), V(8, 12.2), V(12, 12.2), V(12, 16.8) }, 0.8, false, c)
end

ICONS.eye = function(canvas, c)
	poly(canvas, bezier(V(1.6, 10), V(10, 1.2), V(18.4, 10), 10), c)
	poly(canvas, bezier(V(1.6, 10), V(10, 18.8), V(18.4, 10), 10), c)
	circle(canvas, 10, 10, 2.7, c)
end

ICONS.sliders = function(canvas, c)
	line(canvas, 2.5, 4.5, 9, 4.5, c)
	line(canvas, 14.9, 4.5, 17.5, 4.5, c)
	circle(canvas, 12, 4.5, 2.1, c)
	line(canvas, 2.5, 10, 4.6, 10, c)
	line(canvas, 10.4, 10, 17.5, 10, c)
	circle(canvas, 7.5, 10, 2.1, c)
	line(canvas, 2.5, 15.5, 9.6, 15.5, c)
	line(canvas, 15.5, 15.5, 17.5, 15.5, c)
	circle(canvas, 12.5, 15.5, 2.1, c)
end

ICONS.info = function(canvas, c)
	circle(canvas, 10, 10, 8, c)
	dot(canvas, 10, 6.4, 2.2, c)
	line(canvas, 10, 9.4, 10, 14, c)
end

ICONS.warn = function(canvas, c)
	outline(canvas, { V(10, 2.8), V(18.2, 16.6), V(1.8, 16.6) }, 1.6, true, c)
	line(canvas, 10, 7.8, 10, 11.4, c)
	dot(canvas, 10, 14, 2.1, c)
end

ICONS.check = function(canvas, c)
	poly(canvas, { V(4, 10.4), V(8.3, 14.6), V(16, 5.8) }, c, 2.1)
end

ICONS.close = function(canvas, c)
	line(canvas, 5, 5, 15, 15, c, 2.1)
	line(canvas, 15, 5, 5, 15, c, 2.1)
end

ICONS.sparkle = function(canvas, c)
	outline(canvas, {
		V(10, 2.4), V(12, 8), V(17.6, 10), V(12, 12), V(10, 17.6), V(8, 12), V(2.4, 10), V(8, 8),
	}, 1.1, true, c, 1.7)
	line(canvas, 16.2, 2.6, 16.2, 5.4, c, 1.4)
	line(canvas, 14.8, 4, 17.6, 4, c, 1.4)
end

ICONS.reset = function(canvas, c)
	local tip, heading = arc(canvas, 10, 10, 6.8, 160, -140, c)
	arrowhead(canvas, tip, heading, 4.2, c)
end

ICONS.refresh = function(canvas, c)
	local tipA, headingA = arc(canvas, 10, 10, 6.6, 195, 338, c)
	arrowhead(canvas, tipA, headingA, 3.8, c)
	local tipB, headingB = arc(canvas, 10, 10, 6.6, 15, 158, c)
	arrowhead(canvas, tipB, headingB, 3.8, c)
end

ICONS.copy = function(canvas, c)
	box(canvas, 7.5, 7.5, 10, 10, 2.2, c)
	outline(canvas, { V(6.4, 12.5), V(4.7, 12.5), V(2.5, 10.3), V(2.5, 4.7), V(4.7, 2.5), V(10.3, 2.5), V(12.5, 4.7), V(12.5, 6.4) }, 0.9, false, c)
end

ICONS.egg = function(canvas, c)
	local points = {}
	for i = 0, 24 do
		local t = math.rad(i * 360 / 24)
		points[#points + 1] = V(10 + 6.6 * math.sin(t) * (1 - 0.2 * math.cos(t)), 10.4 - 8 * math.cos(t))
	end
	poly(canvas, points, c)
	arc(canvas, 10, 11, 4.2, 148, 196, c, 1.6)
end

ICONS.target = function(canvas, c)
	circle(canvas, 10, 10, 8, c)
	circle(canvas, 10, 10, 4.2, c)
	dot(canvas, 10, 10, 2.2, c)
end

ICONS.bolt = function(canvas, c)
	outline(canvas, { V(11.6, 2), V(4, 11.2), V(9.6, 11.2), V(8.4, 18), V(16, 8.6), V(10.4, 8.6) }, 1.2, true, c)
end

ICONS.palette = function(canvas, c)
	circle(canvas, 10, 10, 8, c)
	dot(canvas, 6.6, 9.4, 2.3, c)
	dot(canvas, 8.8, 5.9, 2.3, c)
	dot(canvas, 13, 6.1, 2.3, c)
	dot(canvas, 14.2, 10.2, 2.3, c)
	dot(canvas, 11, 14.2, 3, c)
end

ICONS.folder = function(canvas, c)
	outline(canvas, { V(2.4, 4.6), V(7.6, 4.6), V(9.6, 7), V(17.6, 7), V(17.6, 16), V(2.4, 16) }, 1.8, true, c)
end

ICONS.lock = function(canvas, c)
	box(canvas, 3.6, 9, 12.8, 8.6, 2.2, c)
	line(canvas, 6.6, 6.6, 6.6, 9, c)
	line(canvas, 13.4, 6.6, 13.4, 9, c)
	arc(canvas, 10, 6.6, 3.4, 180, 360, c)
	dot(canvas, 10, 12.3, 2.2, c)
	line(canvas, 10, 12.6, 10, 14.7, c)
end

ICONS.key = function(canvas, c)
	circle(canvas, 6, 13.8, 3.6, c)
	line(canvas, 8.6, 11.2, 17, 2.8, c)
	line(canvas, 13, 6.8, 15.2, 9, c)
	line(canvas, 15.6, 4.2, 17.8, 6.4, c)
end

ICONS.rocket = function(canvas, c)
	outline(canvas, { V(10, 1.6), V(14.6, 7.6), V(14.6, 13.4), V(5.4, 13.4), V(5.4, 7.6) }, 3, true, c)
	outline(canvas, { V(5.4, 10.2), V(2.6, 14.2), V(5.4, 13.8) }, 0.8, false, c)
	outline(canvas, { V(14.6, 10.2), V(17.4, 14.2), V(14.6, 13.8) }, 0.8, false, c)
	circle(canvas, 10, 8.4, 1.6, c)
	line(canvas, 10, 15.8, 10, 18.3, c)
end

ICONS.gem = function(canvas, c)
	outline(canvas, { V(5.6, 3.6), V(14.4, 3.6), V(18.2, 8), V(10, 17.4), V(1.8, 8) }, 1.2, true, c)
	line(canvas, 1.8, 8, 18.2, 8, c, 1.6)
	line(canvas, 5.6, 3.6, 7.6, 8, c, 1.6)
	line(canvas, 14.4, 3.6, 12.4, 8, c, 1.6)
	line(canvas, 7.6, 8, 10, 17.4, c, 1.6)
	line(canvas, 12.4, 8, 10, 17.4, c, 1.6)
end

ICONS.power = function(canvas, c)
	arc(canvas, 10, 10.6, 6.6, 305, 595, c)
	line(canvas, 10, 2.6, 10, 9.6, c)
end

ICONS.trash = function(canvas, c)
	line(canvas, 3, 5.6, 17, 5.6, c)
	outline(canvas, { V(7.6, 5.6), V(7.6, 3.2), V(12.4, 3.2), V(12.4, 5.6) }, 1, false, c)
	outline(canvas, { V(5, 5.6), V(5.8, 16), V(7, 17.2), V(13, 17.2), V(14.2, 16), V(15, 5.6) }, 1, false, c)
	line(canvas, 8.3, 8.8, 8.3, 14, c, 1.6)
	line(canvas, 11.7, 8.8, 11.7, 14, c, 1.6)
end

ICONS.chevronUp = function(canvas, c)
	poly(canvas, { V(4.6, 12.6), V(10, 7.2), V(15.4, 12.6) }, c, 2.1)
end

ICONS.search = function(canvas, c)
	circle(canvas, 8.6, 8.6, 5.6, c)
	line(canvas, 12.8, 12.8, 17.2, 17.2, c, 2.1)
end

-- Added in the Fluent-inspired polish pass so each feature has its own glyph
-- instead of reusing power / bolt / rocket / folder.
ICONS.moon = function(canvas, c)
	-- A crescent: a big arc, closed by a smaller one that sits inside it.
	arc(canvas, 10, 10, 7, 55, 305, c)
	arc(canvas, 13.2, 7.4, 5.6, 330, 120, c)
	dot(canvas, 15.6, 4.2, 1.8, c)
end

ICONS.gauge = function(canvas, c)
	-- A speedometer: open dial, tick marks and a needle.
	arc(canvas, 10, 11.4, 7.4, 150, 390, c)
	line(canvas, 10, 11.4, 14, 6.6, c, 2)
	dot(canvas, 10, 11.4, 2.6, c)
	line(canvas, 3.6, 11.4, 5, 11.4, c, 1.6)
	line(canvas, 15, 11.4, 16.4, 11.4, c, 1.6)
	line(canvas, 10, 3.9, 10, 5.3, c, 1.6)
end

ICONS.server = function(canvas, c)
	box(canvas, 2.6, 3, 14.8, 5.6, 1.8, c)
	box(canvas, 2.6, 11.4, 14.8, 5.6, 1.8, c)
	dot(canvas, 5.8, 5.8, 1.5, c)
	dot(canvas, 5.8, 14.2, 1.5, c)
	line(canvas, 10, 5.8, 14.4, 5.8, c, 1.4)
	line(canvas, 10, 14.2, 14.4, 14.2, c, 1.4)
end

ICONS.save = function(canvas, c)
	outline(canvas, { V(3, 3), V(14, 3), V(17, 6), V(17, 17), V(3, 17) }, 1.2, true, c)
	outline(canvas, { V(6.2, 3.2), V(6.2, 7.4), V(12.2, 7.4), V(12.2, 3.2) }, 0.5, false, c, 1.5)
	box(canvas, 6.4, 11, 7.2, 6, 1, c, 1.5)
end

ICONS.clock = function(canvas, c)
	circle(canvas, 10, 10, 7.2, c)
	poly(canvas, { V(10, 5.4), V(10, 10), V(13.4, 12) }, c, 1.9)
end

ICONS.layers = function(canvas, c)
	outline(canvas, { V(10, 3), V(17.4, 7), V(10, 11), V(2.6, 7) }, 0.8, true, c)
	poly(canvas, { V(2.8, 10.6), V(10, 14.4), V(17.2, 10.6) }, c, 1.8)
	poly(canvas, { V(2.8, 14), V(10, 17.6), V(17.2, 14) }, c, 1.8)
end

ICONS.bookmark = function(canvas, c)
	outline(canvas, { V(5, 2.8), V(15, 2.8), V(15, 17.2), V(10, 13), V(5, 17.2) }, 1.2, true, c)
end

-- Pinned: the same ribbon with a tick inside, so the state is a shape and not
-- only a colour.
ICONS.bookmarkCheck = function(canvas, c)
	outline(canvas, { V(5, 2.8), V(15, 2.8), V(15, 17.2), V(10, 13), V(5, 17.2) }, 1.2, true, c)
	poly(canvas, { V(7.6, 8), V(9.4, 9.8), V(12.6, 6.2) }, c, 1.7)
end

ICONS.chevronDown = function(canvas, c)
	poly(canvas, { V(4.6, 7.4), V(10, 12.8), V(15.4, 7.4) }, c, 2.1)
end

ICONS.filter = function(canvas, c)
	outline(canvas, { V(2.6, 3.6), V(17.4, 3.6), V(11.6, 10.4), V(11.6, 16.4), V(8.4, 14.8), V(8.4, 10.4) }, 1, true, c)
end
end

-- Returns a holder of exactly `size` pixels. props may set Position/AnchorPoint/LayoutOrder.
local function Icon(parent, name, size, color, props)
	local holder = New("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
	})
	if props then
		for key, value in pairs(props) do
			holder[key] = value
		end
	end
	local canvas = New("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		Parent = holder,
	})
	New("UIScale", { Scale = size / 20, Parent = canvas })
	local build = ICONS[name] or ICONS.grid
	build(canvas, color)
	holder.Parent = parent
	return holder
end

-- Icons are made of real child parts, so tinting means recolouring them.
local function iconTint(holder, color)
	for _, object in ipairs(holder:GetDescendants()) do
		if object:IsA("UIStroke") then
			object.Color = color
		elseif object:IsA("Frame") and object.Name == "Part" then
			object.BackgroundColor3 = color
		end
	end
end

-- LOGO SOURCE -----------------------------------------------------------
-- Roblox cannot display an image that only exists as a chat attachment, so the
-- Lumen logo travels inside this script and is turned into something an
-- ImageLabel can show at runtime. CONFIG.ResolvedLogo ends up as one of:
--   { Image = "<asset string>", Px = <pixels or nil> }   -- asset id / file asset
--   { Content = <Content of an EditableImage>, Px = 128 } -- built in memory
--   nil                                                    -- nothing worked
-- Tried in this order, and the winner is named in CONFIG.LogoStatus (shown on
-- the About page):
--   1. CONFIG.Logo      an asset id / rbxassetid / URL you set yourself. This is
--                       the only route that always works, in Studio and live
--                       games alike (upload the PNG, paste the id).
--   2. executor file    writefile + getcustomasset, 256px PNG.
--   3. EditableImage    AssetService, 128px pixels drawn in memory. Needs
--                       EditableImage to be allowed for the account / place.
-- A `do` block, so it adds no locals to the main chunk.
do
	local EMBEDDED_PNG = [==[
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAMAAABrrFhUAAAB/lBMVEVhot4oYaVUaZ0nZP8AIP8CH5lyiqrLz9tMWXsAJtk1S3si
j9CWtNgpaNtLXo6lxOckTJESJnsZV98HIZgq8/6PmLNMdc4bVLFOc+Eopv9bmtoAK+VadLR2yNw4iqdZiv8kPrFRjLoAAAABVP8A
TP8BVP8ATP8AJHry+v0AKIwAKYkAN7EASe8AJX0DV/UALJcHZ/jQ9v0BR+0CU/oKd/oAO8UANq4AKK/O5/wANtEJh/oMl/sAJ4EA
KsoARNYBNJK02Pyu6f0AM6OP5v1t2PwBM5lNx/0AOOcMp/wup/wBRtCx9v0OYv80tvwAHHoQt/wBRMgAPdQsmP0AGo7P2+4Nx/wA
N/8BRq0nh/uqyvaP+P1KufxU0/0AKP905Pxt9f0sx/2EnMyM2PyNpM1P6v0AKq8CVtEt2PwCMowO1/1VZYvm6/hR9P4AKqIy5v0A
N/8EVrBtyPsAHH2KlbBreJcDZ9Wvt8wKYf8DdtIkevsAG4gON3oJQ7IFQpcAOOwM5v4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADqx0PXAAAAgHRSTlP/9v0aGuf///BY5////6b/ou5UlP///3RUFFf/c///K3ZtAAoL
LjDy//+vdUzU/5T///9G/2T////////F/1j///+E//+S////////Dv/0/2JZ/////w////////8K/////////3f//6n/////hf8u
///V/////y7//7Pzc/9N/72eRHoAACVpSURBVHja7Z2JQ1rJs+9xTTRmTMzM/Ob3u/fd+x7nsB8EZBfEFRfELSouUeMk4jYuiVl0
TMb866+qejmHRQQUjCQ9mZnECPL9dFV19enqbpO5cZuCzcKa368lgi5XAn6r5DRTI+tXjQAS80GXVqC/sQEYTAABzPsL5DcwACVP
v5ZIFNPfsACUPACaVsT8wUfURgWQztEPFlC0+4GAqcENQBCwFNOvNiwApRCAUqypqtrwAJQS+hs2Bij5AJRr9KuK2dTo+pXr9YMB
mBsRQL7+68RDMzcigDyh13Y/0994AJTymvx+0w+u/wcFYG5YAJXKbzAAlYpvNABVyP+xABR90Q8C4PoXmX4E/aVeZfqRe7+BAFSp
vtEBlPNKU6PqL/elph9cfwMAqN76GwPALfU/eAC3lP/QASi31t+AACp8C9MPbf8PG4ByF/q/IwDKXch/iACq+fhK1XOf7wtAdZ//
hqceykMBUGUPllSffigWUMWjq/Je+jBigFLV08syX/r9u0DFazeVvvg7B6AotyHw4AEoBWv3pSpY8sTcjt33AOBa+SUgVKy+QgKm
e9Kvl69p7N/rGVQs/3t9HlCgH8s354NBF7b5hFbCFcxF6zvuhIDpHuTL4l1UPpKkNgIMNH+JaKDUyAhM99P7TD6I33c6nfF43Onc
BwaJeyBguo/+R/lfXaQ+7nbbqLkBASOgKPVEYKqzfla5TL0P8pn6QWgOmy3uZDZQhrLSY2dFBEx110/WD/L340L9PysrK4ODNpsz
6ZovxwSM46b+W0t1BEz11M+7H6x/f9/pFurfvftkerpSPgDLte07XRvM1c+6n4yfyW+6MA3bOYCRoHYTgULZVvhltfLfV0zAVFf9
fj94PwQ/tP4vJP/Tk5lhuz3SBADczpsGAouePvn131EixVMpa+Fr7xtAjn6Ndz9ZP/X+FMi327vf/YMA9gUAS4meR72aRrITmpaQ
TcNGlvBd1QcUMf84s37w/YupN3ZqphUYBgjANdmQLp80z0MCGeQ5pGzBIFKwkjuUT8BUN/0Q/Sn6se5H+U+4fDuGgFwAxQI9ps7a
vK56ZCTpSXp4w99ANhlMcCuwfB8lMnnm7zJ0/yddvj3yDmMgxYB8AEbxCVKPuj0ep2zxOGWS2DweQLCg4VtYLd8TAD76gfmz4Afd
/6Tbrre1lesAWOWetwRaPGoXqt1ukUSyTBIaMjgGVwAE1nIJmOpjABj+WfSD4AfW/95ubCbMg9xxDkAS0FiEh64ndx9h4uM5wh3Y
DBQYggWKBer3AoDZP5g/i/0rFyZ7buMhABIhV0Lzi4ZRHXseDX+EqTeIdxRpbE7hhGAQLJuAqS76E/MjSd79K02mSI56nwwBCAAj
OdOuodWzkCfVF2gPyyYZgCVBLCACqnxycC8AcvRj9KehP08+AuimmQCEgCQOZvNsWJ/XxRvUG4SH8huHwIxAJ3CDCdQcAPr/1xFm
/oP58n3Y7KYQmwzSYxGXYYAfKaqeaY9CSxka/JEzYEaQR+AeAAj9537ofzcFf9OSvVC/z96Es2H40EhgxDDMe0i+sHxDzzPtfX19
vbL19SEDQGAkgGFAvYGAqfYOgPpBfuj3oSLqoUWYB0gA+EsO9sbOl9qZdC+1QCDw999PvV5iAAjIDxiBBTIB9V4BoP7k/nPQ37RW
VD0YwBp5AAIgApTfJcWQZ+z7gYHoBEgH0X+vrr58+XJKtJcvV1eBAjBIMSOwoUcdcydQ7wWAMADs/y82W1PXNfIxBAzqADzJJMtu
ZecL9dFUr3f1pWl8Y2xr6/U6tGlo+Prh4dE379+bTKZVRMCNACOhcAK5R/IeAJxbekb222xNb6+VDwCe6gA8Qjykekz94iJY/u6n
/tjc9t7JyRG019TW1zkEeAN60+E3DEGfkQA5QWkfqCGANBhAz9f9NrfpevW+aQwBaLLuuNOQ36P62VmHg7RPQov1By4+ffq0i64f
CPSvvpx6NT62RWYgGQwBAiIQJgJxZxacwGK9FwCsXOH8vOfZvu3t9fJ908M+FgIgi41L9ZTvgXiMcJ8+vVsJyXQHwyAMALu7+HeA
ZnkDIDBDwvZGEMgxgXsDABHg676z3e67Rvw0/Br2mcIcgBundfQfEI8aUyFwgdnZWZn+QCZBKc/KCjL49OmiHxns7ayjJRGECBJI
cSeIeyAOskkRhMJ7sQAwgM5rxFMbHh72PRVJPLW4G+w+mkKrcLfFc+Z7NomBQVjhDCbnlk90X+he9QIBaQIYBllCXHcAaeX8fD7p
/FCoXsifHh0dnY6sGKdzONY7HG5n3ozfOPXlpjCICN4hA3KFvfVpCoo++9Cqtw9NQPqA5d5cAAG4H9mvUU/6R6e7wAMYApbJO100
+dMTwqRH0tAng0YGaAaxybktPjD43gR6U+gDsyII3AMAmQQkv/yVG/N4E/pHp03hkJzLOl00AwzSI07+rDNofACWdBpmhYIBmgEg
iG2ss+HRZ8IoYACg3guAdDoNMTB5aC+uf3h6dAv/mX4qZnCQt+CDDE08B7L4rX6/hU+NNTE9xMVkmSISAx4NAv39GzxDmA4QAJkL
3ZMFpMECnnna7RHI9iO+aSmeIxgdg5Rua3Q45NAfBfi59BJPBeddYlGZJ4poBgLBDsuT1k19KQFgAYCq9+UC5z1J52ffsC8yXNCm
h8ewba130cQlSdUB1mvWRPIhCAY6ghAR8E4d7ezsAILRXmkBCwBVVa/PhGsbA3qSXyK+4aJtjLV10yx8TnyEdXNpgL4ugovruMC0
LxHAsJja7Q3sUDta/1sCkLOBegPAPNgyP9Jkz9VNgQ8MYGwD29jOdNMZfsyEVlZdgOFsQF5esU/RQBLYPjk5AQKvTRzASPCmUbA2
APjHPf+abfblamdtemycAGzsDA+6nVQXYbWUVQVkOB1QICACDkyOUn0zJ3swZTrhAOIsBqr3BsD/7Pitr0A9tvFxRuB11yx8yjKr
IvKqywQCpySQSk0CAJw0IgAYVctIA2oCQNFnAkvThepJ//b29t7G3uv2M2eRYy7LI8AQSAKQQUcnDw4OgMDR6kAIPeBYDoKquf4A
LJaeYKeviPxRVI9tb2+9GeNUkVV9Ko1Tb1ojp1AgCYRD0bmD5eWDvW9HT8MUApgH4CBwPwDmFz76pOo3b94I/TMzMwzAyRsbxulS
C5lK6YVyQYABSC1DOzj4tpNCAPKBiFpCfy0AyM/51fV2mmt/84ZGPdI/NTPDEex0XSYXrNZSi3ilq0Q4ATQBcIGw92AOCfw6Y/AA
mgveDwCYCayNvhkV4inx2Rodm5yZ4QSWj5pfjGjWKgrEcwmMeJwEYCC2PDeHAP4O0xiQlYNgXQEYFgSbhkcN6onA2NTU5OTkHLTl
7YOtpqzLb6lmk4ShYAKmS0kCEE7R2y5/24uGHYaHAWp9l8YU3QBOD6fH8toWymcEoKvG9l0J/rhCKafKpmgs1OZdzALCgblJfNtf
V5kByDFQrefqsGFFfP70w3q+/pnYpCCwvHxiys7flKjdGAr9WpADiNL7Lh9sD4RpKiwiQH0BqHpJxLyre0sox7wX2qsYNgHg1+aO
ef7U2lwxACUHAD5LCkzGEMC3XTEE8JUxtZ4VIgYDSCSe8SnP+3GW+Y2Nx2KCAAA4OOqEyepN9s/fV70OAQKAYdDhSE3CG8/NfYu1
0bMQMQSWeBxYAwCGT6Z9vXo8+p6rp7Yh9AsAY/sJi1IegOttwJ9wjaAHhNkbHywPkP7joCb6v9QYcLcAFN3+rf7E19b2rXFj23jZ
H+vv1wF8M3Vo1lJPrMsCoCVcHjCAxQt63+WDqCEAUA6o1qlMLv9z+eetXWM5+qf6qTECGAObO/zWmyxUvn0RL+AegAawuBvrRw/4
ttvmmOU5oErHxqp1KpRkP4t3vzXpgQT/2ZscA5gJ5AHY6byyqOWVdBe3Ad0AFlfItia/fVpk+jWRA6s3mZfpzvRTs1o17XT+ixvy
m83HOOsbf8Ua6A/oBGi4GnuhsTHAXCUBAgAh0D07SO87eXAB+mflAFCO/rsBwHxNVeDHzi9kv3xJ4tO91uaxV0w+Jr7j/QFBgPTP
QRbQwczUfAsL8KMBzDrY+y5j/585PdmFsvv/LgBQGGPdD2lpx5d3X1ixasaky58Zf4kLnYwA94Cj5la/qpa/v6soAC147DyzXeAb
M/2YAV+JBKAM/bcGwFce0fitiZEO57sm5yk9hVJb3kv5MzNTTD8R4B6w1XlquTFGlwCAsUZbwBzgAt83Nvdu0TYb51NApr/mW2YU
lsZx53d5Xgxe/HOlUfqhZH4ZI+VTU6Sfl/MYAFAIUKq3ANDvB/1O26cAvHNsMjRrO9OrQtTy+v9WAPRHl1y+7eLC3cr1K+bmjakZ
XsMzE8gDwEKAX1GqNwCQ6ddIP77xZAyif1x/BKKUbVumW+mn7oePsuDyXF7+E3vXcaVRNEAA7duihmmmX6/oomjNQ0BlHqDm69e0
oMdjo/edvFhE789y86chuczgWjUAlTs/d8Qzx0VssCMo9astr/QiLq6fASAP2IYQ0Gq9xRiI+l2e7KC3t9fbH1vB7j/OyvSvXPuv
HgDzfuH7ztnZd5MX7o4gSz4pu/t/41i+RsVsVMnICUgAY/8X5qplf0zpb+zHkgFI/ReOMyqMXND7v8YAFJb1ofGDGTpts44nc00v
sgk++4JvSJs7Z2IvGQBvryTAAVAIIA9QK9Wv8phjTbhcxyuk/13bpaiMZaO/Uolrmaob+cnM0PqzkIctvpubW3nh0fjkg6Xu/zPF
p36BvmIAKARU6AFMGRtyNdfVfgreNXDx5dKDxp8jXy1fjKnK6I9WqAWzmIeHnyxPDl66NOOzDbXlCYoHuf2ioDfHA5Z5FlBBssV/
rNRv2+3t8wZWZG28yP0qSC6rA6BHIXoSs5iaO4g5Lj1i9sXnbv+Z4Yl/b19vXyGAg7Eea4UeIO+FgZ+c0IKD8Lbed+7scY78iuJf
VQD4x7CyWYjN0XaxvPxk8XJkgQ3//LswBDD93r4+XtVt8ICZbQwBSvkxUBoA079gja/Am+4OHmdp4Bcz/7Lz3+oByCyMd384drB8
MXvmueL+J2fv/xMjAIG+PkEAAfAsYHt7B0JA+Z9VvxSHPE/TBlPwloOeDilf9H2l8isFwJ4wKZj5UPeD+YN+tyeYqx9DQI5+BkD3
gD0eAtRK7J9NOMHenSF4x1D8Sh/32OCrKhVE/6oAiDGIxj7Q7z1YXr5YtIH+fIf+z1QA5r/9vRNFAIAH7L0vPwQYbwWyWP1WzZFK
pVZsC8Gg6H2Fm75ScfdXCEDlHwLMH59CDvR/A/2zNicNALnwO6cw6/NGCy2APOCkvdw8WDG4P/5oqzuUSoVsC5ox62HylSrkVwRA
5bPQBNc/+W35APrfmS3QnzY3xQCANxqNThgByBBwdFhOGiQmWypzf9wknxyMRqV8qxz3FEWt/Bi1SgHwR36QgtFT6Ojct+VvT4T+
fPxPcOaHG5kmJjgAQxYEIeBZplS+ouaXyqiUdlkXbKFoyOHStFzjv3H1504AiBU/Fv7CE8vQ/6Df7VnIC4DY/o0PQHqjBGAiHwAM
gv+nxVpiwFZUVS0y+7W6w9D7LuuClmf9SpXWXxEA4oyj/wgtQ/Xtgf7YIlZhWIusvjTFvEx/HgA2Bmz/2n6tB+hWn1MqZbX4nY6w
w+bS9HH/FocIVgOA6z924jos6Z8LX+cA5qaA1xs1AMjzAAgBZNWFCZaqFHY+PvyyuEC+O6Gx3tf3A6rqLfWXC4BnPzj8of4N0L8c
Av3HV0VLUJ54vamBYgDwWQgPAYZBS9q8wfZV1bDMMmKjMvIgy3otwgCY9d9Kf5kAmBmi/+MydN/GrwcHB6lF2xnPAPL74N/93t4B
aLkeIA0AQgDzYBHq1SJ1gSrvevgVjNtsHk0LBoMGA1AVvvB3O/3lAeBuKPSPg/5vgUXHLDlAkZT+WT/pH9ANgAOgCLB3xLMAJb+3
cx/5WuixFz74j7vm8WQELKRn54Socuy/RfgrH4Ac/1F/aIL0T7Y5ZuPXGACEgGgeABEC0QAgBGwq4smZvPyUj2dWK6uWtzL1QQi6
zhHDBgpkYNWfe94yAJQHQDGO/6EJ0xHY/0EUHIBHwCIhoC9cFACLACcsC5BeLOyZnxlhlYcm6EdG0KYRtqlwxEUI+FqUelsDKB+A
xvRHTa9P0AHAAJzHC1b5ECw3BAywZvAAFgLJACAE6OkrMwD9dmTcFxHkx+yJHZRsOxn7XxzPRwgaCNQeAE+Agh7S//T1ycnBt7kB
KsLgOXBBCNhtywMgI8Dy3p4IAaqh39leiK+0H2R/37nPN0rZija++q/WCYCo+kzibr5o75ujk72Db70sAmjWoiUog9Fw2ACAG4CI
ACfrjzPn52T+GWinra0d1LLZY88ltrazs1nWcC9AwVkZizAi4vqXUvnTn6oB4LIfBcC+V2AAe2AAYRwCgnxjbv6HWBngAIoZwNGo
KfXp4umTJ09MhvZWtD//hH/Zb/6U/9ebCf753UET0CIZeC0AkI9iAMC9rKnV6aOdk71fvW2OxVn+IQoB/Hs3zAAID5BDwPLyweuu
pwMpZIJIpqZmsHpqC5rYCy32hMut1YXtKQdwF1lAeQBgBKAAkPK+Wd/ZOTnZZnU4Lo1vyswD8CzVlusB3ABwNWDLhBvhUyIzfPly
amaGSsiojhZ3Ucm2LvcX+iLU/qKG+nEGxheAzTUGIEcAm2Mw1Ds1/fro5OTXGFUiergFFPjhP9F8DxAGcGRqagtHdQCxl1P5AHQC
wiBwv4UEYLf/HpYecPssqDwAFkvQQ/uZA2+mX6MFeBFAXAegFIaAsASgG8DBzu9t4XAIAMgv6gA2eDG1gQIQGB4dHh4aGh6SBOxd
YayC5eH39g5QHgBmACu9Md86AtjrywOQ2w8tqTADID2ADGDuxNS0iCdBEAA+NyIAM7yOcmNMhzAqy+yhDUFjAPC4DZtbD4HmWgPg
KQANgSnvOAE42p4IhUUtZpFSzH9BCCg0gOWN3xeFfhkCDAD4JiKBAOtL378fMxBYAgL2JdwLBYOgyIPqA4A9Aw3tBkYZgJn/YkHw
WOYBOR/kSzTfAEDp9qu2RTr2iQ6BkXMDBsBIgBBQbdl71ro5AfACDIBYBYxJwJ2kweUBsEoPmDYAsNlkPpY3EIoQYHCAye2mRaGf
IgBPjREAEdiWCEC6ycRL63IIAAAKgDz4KopaBwA8CcQkCDxg0gcAXu8cvZrA8wkwCCxY5HK8IQTkeAA6wNzMYFuefg4gNsUJcAQz
U1RQgKmRgQESgKHAbgpTAFi4cSPU3QLwz7MxgACACRxt9LEDGmRBbs58SIQAGQFiM02ziw6pnzmAACAIbG+D9lU6HYjOBxIAxt/z
UAD6u8IOngXzNLhOAHgIIADTZAJeMgHDtjRjRB6MtuUYwOTU4PNFin+s/4V+DiDGqsheYh1lvyDArUAQGMMNZz4WAD0usQ3kbvSX
ByCOMWA3NmxnAKYm8KCa2Vk6pyaXgComAlFmAIE59H7Sj48HonKNiNeLxSanpmIBUUIWWF2VDAABARhHAHjUxlO+D8ZPBqAqSh0B
wERgEEaBMTv5wM5OL4sCfGOWJIAIWnaNITD25B/R/Ub9Xqm/P+DVq0fwWDAdATgCARiHcXF02P67tDnLnTwKqwAA1aOjD8zZuQ+M
T9BRPViXnA1eGYszaCLAAIDYyabZEvpRfF9O/YxEwAkQgA0E4DPl7AZXFVWpGwB/wpWkcXC3fwx8gEZCcAI6pgRLU12G0mRFPAvA
JCAQo+5n+qOkXwaAAIk3HIjnNZwNxxFgeCQAW1vTXWGh36rcpQOUBsCfhWjzwgRiPhYFiACzgTNjeaJKIYBHgH69+w36KQCAeP68
PJ9AcQDTa3rMvdVKaHUAIAqQCeBAYEcCeErDTN9/wYzAsYgEjl1iqT6TTvGHod5V6n5HOL//6cA3uWqsE5AAAjqAGfa4YD3ShieD
6frVu9NfGoCq8g1gbCAI7XqnfIzA3sne6gTEezzqihCwJYvMfh/qH5hYfbqodz8RIaV9qSgFA9n/RUzgbzIBHcDYlq9p1mY4Gk69
qxGwDAvgm2B4QRQSwLEQnWBvb2+7v28AMjzwAzz5KRtcWAie/jOBFtCL3e9g8sNcfl9fNMqso7R+owsQgC1fMzsRyC+XA8x1AqDK
ZRo+EoAX9AZeRWhKsLe9fLAc80bD0NFgBXiSq8cZfAciJwJPHTz1k+qZ+AL5vUVi4Gox/a5iSWc9YoAqd2ZwAiuAwDQ8vX4EFoB7
lSdjn1IhcoSztsvL+C52/4roexI7IcQPiPXiAvnGAGAMgaB/PdJ8CTk32wZcA/2lh0GxCI8E5jEO2Oiojr7ev01vXh+d7C2DfiwH
DXh3d1dCg47Ff7wTf6+GwryfSbwIAwMDefLzR0BvbhpAALam3z7vSLoWDFXgZnMdAYgFO7YZnu9Sd9DRrn1PTa/G9/aWl/GsxwAl
sxDj+idf8tJgEIjyJYprbF7IZoYvpYP1b2+MjQ6/fdxxxethbjodtkbPA1TjDq0gMwJ2tDG6N7gDm9H0IwJQHZvy9n7aXVkJhUKD
vP0DDQ99k60ppzWbCtrbLtY+ND/b3GTLpOqNxwPX7JmgtAERCeLGw70x0ePH+7EvwIhwme24Os3cJla3UNs0mzO8OvbWlVC3WRcw
LN1bMScakUe58UaLWGcQA9su6Xz/bHBBM1bvVvnBZHGgaqgaMtcfQA4D1Uq71UfESfdnZ279cofjbNaVNVSv3kG8EuXPd7MGdKsS
GWmE/NiOoAvUHmPLQsOTAK80Ub6i3pV+UT5Uyf7aWhVJ5e4OZ+UberPyphqa+YE0U4VuKZ0hp6l5zfxwWnX7BUSEK9rMD6pVvGVG
1vOpPEoLFMrDE18VAD5NFDXa/P+1+4B3Ug971wAMc6Vads7tLxavLYAatxvvkFTuBcDNh17d9JprOjP/y7nnJRUguDObqGYUuKnT
Sn2V/T5d5FbtdM6L6XYGVkKXf6Nknnnk/bCaAlDSLemWlvT157614N8rBS9q0V+kKC0gLGM9z7cKS8bSY9kUglDZpvWrbPM9/h6/
vwfenL4D/+uf99P3G9+H/aiaAUibm5cePVpqN1/3I/6ztPRo6XNL3ld/wxc9Zn2TzvwHvmWp65mazrlXPK30fIAXN1vZV3Hmdf7x
81Jh+yXDTCgD3770qN2SOTci+Mh+VO0AtGOZ2odrACjmX/Cvl1rU3K8+wq8yADBu/DeVui39Sz039DYY+mf6elNGpFrPHtmLtceZ
NAPAvv9R56lOIG3+wH7UfQHIEIBHuS6iKAKAYgBgf/QMvYDfKp62BJke++EmDwVqcf32Z2xqmj7lL7B/tFrSdQPQygBslgbQYnRL
6F0GYJN9cPUX/sEfJfXYbjkVt/Ac8m8zP2Z//iuvfSST1y0AWlcPQqPPt0kADs3p+wGQznAXKAoATJdSJwHA3i2OU7b4Tz+ILx4y
gVzK5+dfDO3586Z/CQ8xALBjfCFbwlf99dd3B0DlFpDmvi0/eNcpI3DeKvUDAIvBwpv5dUNueu6SdAWl0RgB2O3tKsXUtPk3eyRS
YwBA+LfW4gNhurgLqEYXMFiA3f7bFY7x55sf7fkAzjkAmw2vmOFP3S6zCYvcTsQAHHaTk9g/P0O+GAMAwOOaAzAXB3BNDFCkC6gS
wCPW5x86/P6vrYf0+89dLAbkAJht7jI8Lm53+ZVcC3je8ZvdHvkrYo9A8EijC0QivppZgJJu/YiEP4igUwzAXwRAMWY4HAD75BwS
fnC03davHc0sJgY/GABYBADTNLs6hS7PGHP65TNqAAAfpdO6+XjJjlWkvg8tmZ5Me2RpKVIhgArOsjICKJbyZn75C/6aAKgyY7P4
wUwjEoBKkLpdzs/wv4i9uaOTBbIv2d/wLw5bJQB4KwDAbhZ7jZeMHT3x+BXxdDLThbo7M+enL+BblyJLvu7Ozc32yNBQpQAqeOAI
APC6kPbN82IzNOxd7IulnrwNcN3kmDwGnP6Cf+pOOp0oMWL/DTvQvvTc6WEBLA/Auyd6a3oetMgFokwXFtE3ZSwW62nzUmRoaSiy
9NH8sRoA5RNImz/6wMTaM5DNp6HhVTJibqMDeIRnRafZL7orptsXkRZgOW0CK/F1J5Mjyc8oASn4lp5n97MfGAB8tcVyxQC4bbMO
XHym9sI1b7EIH8i8jSwNLXXSu5p/+RyhguoPH4aG1oYqTIQqeKqhIOGlyNvWzCa21lb2P7NYSFf/WEIffMb/nrVWooJ9RU/VTzvx
T93JkZFgfI3vhIiA/mSWBbAOvDIZMoO3YEq+w0ub7QxbG24Wy57CTxRrFABgSABIb7Z8iIDyNZC/tjZ0WCGA8hdvlM3HSHrpw8f8
1sI/1+cl6Ie1j4d6a25eQ4lrPVY8NMVquepERt0wqCc9z4EXwbkEfcd/+uBPhx0J3BzsR29eiqw1y0bvBb/+4E6QeYt93pnh2043
H6+heGwVW0D5a86K2rI2JIr3c1qPynqiOVLkr5fAP5vRtLFrrzqJUdyJy0ttRKD5zOZ0xi//BJuOHGbpRHT4tggvkedteIj95M5N
YQEgmACQ/aVb/3jLCHRXCqCiUz3RBNYK2tDaH2IL5NsI+6BrjBRvkc9JVkblT1x10p9pQc191gShC/TbIOEDABjAXrgSmubXXGAQ
4p1yGvW5BACTR76Ils5kPg6tdXd3d1UMoKJjPcHUIkOF7X/FINfzYYj31dAw7XaBvhuOvHVng5qFdkJnIQYMR7r4/XGzjqbBRXbX
3BmwG/YdvkjiqXAJ14j7z6FirXOTrRVm3uLP+UV/AgTJWXMXQun+34otoJInYpv/OmzP3cr354f29hZ5lklrZ7NJ7Pnj/21uojw+
sRDErcDPcTOgKe8ObfxtM+4XbKKbw6F5nG1NzXwPob5r0PTnM+71mY/wY9v/MDwCg0y45RC+9t/mSi2gwifhm5u439PQIOaL/c84
zrV2XJ1e0cJp9sVlW9vlixe0eDxyzG5Rti3i5k/e2J3Zg2JLqGORXSAP3w/TIOflWRu2y8sXHny3jo6O01OrWIvIbGZw+Tg3RlXz
ULSyF+Vf/iWeVcplEqsFL4aj2/HwWrg4TefcuAHaLS8KFJeF61dnR/lXxBXy7PpJ9l9+H7HLNT+PFxKpOcds1HzfYMmH9apiPPIE
PxWWUOCdFyOFl2azy6BCK3hlqr5n6tWrV1NTL6nOytu7uwt/aTAJvlea7uMdEScHWOWhnXezFlfF2mD+MR/yEEc6ZJGd+4AU+OZ/
uQ3ceF8oXZoqCsS9XrxhNbVC2gcN0vldxHhuQn7xwZ3sG65yZUjJ7QNVXxyVi4V00gk/BoFfpO7MswjpCKH8Phe6KRjSHYxW41mh
av1KZctAoRjXKuRMhS0e8wgBAhaQA4Mg74oUd6cO6iOBjYdAdk4ESfcb6w8URVXvfDWyJjdMyPM/6UQQ9AqkQDdmGq+UZxzkuQgs
/GPH68fFWOnoWeFjqlr3MrlqF41lrOYOwYtqFuhcEAZB3qUrQr3HcyzEa7LjjbUYNVmKrslNU6pqjJHiJExeWMQgjBgvFmZGXyDe
UHhRu9KLGt47rI/X8vYFmg+IE2IQw4g4IAe06+Kl2ctinNqtwtesPsAwUopOVAQEOi9GSywsgOqFRGIhUVhqptS+7+tQIGE4ft8w
iCmUKxAIq2YpVm2mVH1E6ncGQJzCKjmIwyGFO7CSQwsej2bApIjQp5jNDx2AWdaHKLoRKIohwik51qFbjFKnirO61gjpVe/6AKeI
WGf4ty5dfx8ADLFRP0tNlVFCuY86y/pXieXUFxqOzMYnM/dQaHlfZXJUGqEa9mPc0+f4jusEfwL4CeAngJ8AfgL4CeAngJ8AfgL4
CeC7B6D82ADqPH//rgDgBFY88foRARhugPkBASjGg/GVh0vAVK30vBqBBxsHqi2Q0K93EgTMPxgAebIDf77X4DFAKdzKqloNZRKN
DaDoJl5529HdH+/1vQG4Rr64XkNVGjsRUvIuveLXfude8tqgAJQi9x+xQ1S0qm+5fTAAlGv276t0uN6CphlrlxpuMqRc27DsK+HC
im59Pf9B6y8KoJR6PF3SpRdxNR4ApWTv40FaHo9evWhVlQeuPx+AUrr3Ey4PHSIb5CWMDz0A5AMoKd/qx9P0nE6PsX5VaSAApTsf
j1CD7ndT7TIB0BpCvw6gpHo6Qc7libvjonAdAaiK2jgAbur9IHY/1u5T8XqQ9DdABOAAyuj9JJ6lifXMVMwMLmC538KOOwVQWr5f
m3clsftp84aHA2CnfD98/bh19nrxtAFmHq2fVfmjAeDunWCC629IAHTjJ+97tvOFdT/3ALIAzao0KgB+8acFL/5MsC0O1P0Ovn2J
Ctul/sYDwK49ZZ0/T9uenE46TFnfv4X3vKgNoz8XgPHuU7G/hbqfAPA9La6EVVEaEQB3fex7sn3c9yjkGwAk9bNsGkG/BKAPehj2
yfX53iaHDgBjQNAvrvloCP0cgFTPel/seNR3fcr9fC5NGoC5YQDwuC/2ORrk41XzOQBc7J6fRgJgEYEfO59tasP9XML6Q2HjpsYR
mQE1in4GgMY90fv69k7a3m7YxhzHANCIAFjKl7+xk2/vN8QAjyEANA4AP0t6aNxPGva15uh3SP0NFgEAgFas97n55xiA05XwN54B
mE0JPu4z59c3uOdva8/VbzY3DgC2lZdbv9zaHgpFcwBABtiIDgAAmPw8/XiTTo4FxD1kAI0IgMyf5/1u2f3iXJNBrj/pSjSmAZj/
Py9lclV006kEAAAAAElFTkSuQmCC
]==]
	local EMBEDDED_PNG_BYTES = 10296
	local EMBEDDED_PIXELS = [==[
/xdQqulhodjlV2yfmCRi3SJuluIQWZPXop+01t4kXLAaGkuqkzKb0/SsxNvpLlqwaRVo0eljcbYaWGuea1h54RqUstmYFyVZDRQo
oSFMZqXetcjrnwUs1ykQUsSmMJ7iEXeMs2Z5kLad0tzp6gEQoWgMKJDTACLbRnGIuN1hjtR0mKrSbgAuopwhjuORPvT+/24MDAZk
YRIGVnjIclDy8gy/v38EmpqyB4qYvHqkrb7yrKz/BKzm/wT//wABzMzmBQI/xdgVXNdTLou5FgDU/wZVqlUDVaqqA6TC613/qqoD
wM3oiwAAAAAASv4LAVb+CwA7+wgBVP4vAAD/AwEni/v0/P7+ACmJrwAke+4AN7RyAEv8MQBK7kjR9v7/ACyWlgRY8/8Ld/f/AUTX
VQho9//N6Pr9ADfQ/gFH7P8CN6/9ACiw/g+X+v8AJXzTAWf/CguI+f4APMVkACaEyU/H+/8AK8r+ATSmhW3X+/8Pp/r/kub9/wIy
mo8AGXjuAj3PWbHo/f8vqPv/NLb8/wAaivwCR83+ADvo/wdX0P6sx+f9AT3ZCgQ0lfy0+P7/kKjL8AAYd9MoiPn/s9f4/gZ7/ggQ
t/v9LZn8/k25+v5vy/v/ACn8B1LV/P5y6P7/////AgZIrv0EU/dEy9rs+Alm1f0Qx/7+AABPEi7Y/f+S9f7/S6jz/Y3H6PwDKKtx
MMf6/jHo/v9KevINNGn0DH9/fwOK2fr/BCjNTwD//wFU9f7/kKjVkAlJ1wxLZ67zU+n9/2mazgWuu9PJp7nU8gAAMg0ABXcQAByI
qQM3tVcW6f//M2aZBShmr3pu9v3/AAGPFwAbjo4FQ8hiDli4+hDX//91lM+TdpjK92y67P2LmbqKBzORrAA3r6oJRbFyBli6fzZ8
/AmbstLxyNbyjQAYe7cAM5kFADj7MgxZ1gkMd83+LkmT9FVVqgNXdbrIcIe4TXuTuvF0ptP2f7+/BIabxouQq9u3v7+/BP//sgMA
BOokAD9/BAQ/vwcAZswFE4XQ/iZW0w8mfPX+UGqnjlN40hlLeMj/UJj/CVyj4n9Ottj4ZXaahHOIsotujtSaYKLif3n//wOYq9DS
nLjsqQAKcNgADnLoAAOqDwAHuSoAHaf+ABvFRwAkfboAJ7APACisXQko7y0ENZPJAjqzyxFl/ysWiv8MCKf/BipKlNUoRsoVJ0n/
Cixktvwpa9UKM4r/Dj+b/wlWZphJTWevZVFqstRJadcRWXexR1p7wrxbhLKHSIXL/VeK/wxPmdD1Var/Bki2/wdmZpkFcbj/B4SY
veiZmcwFhZzG8pOivIOMuuj9AAuRIwAGgpEAANgUARypagASzy8AGPYuCia2NDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTlTOjtEPT09RVVDRD06Ojo6Ojo6OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+PDo6Oz09RD1FSj07Ojo6Ojo6
Ojo5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs7Ojs6RD09RUU9Ojw6Ojo6Ojo6Ojk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk+Ojo6Ozs9PT09Ozs8Ojo6Ojo6Ojo6OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTw6Ojo6Ozs9PTuN
Ojo6Ojo6Ojo6Ojw5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk6Ojo6Ojo6PTs7PDo6Ojo6Ojo6Ojo8OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk+Ojo6Ojo6Ozo6Ozo6Ojo6Ojo6Ojo8PDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTw6Ojo6
Ojo6Ojw6Ojo6Ojo6Ojo6OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT48Ozo6Ojo6Ojo6Ojo6Ojo6Ojo8Ozk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PDw6Ojo6Ojo6Ojo6Ojo6Ojw7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OT46Ojo6Ojo6Ojo6Ojo7PD4+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk6Ojo6Ojo6Ojo6Ojo6PD45OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozo6Ojo6Ojo6Ozw8Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5O3Q6Ojo6Ojo6Ojw8OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs6Ojo6Ojo6Ojo6PD45OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk8Ojo6Ojo6Ojo6PDs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk+PDs6Ojo6Ojo6Ojo+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Ozw8PDo8PD45OTk5OTk5OTk5OTk5OTk5OTk7dDs6Ojo6Ojo6Ojo6
Oj45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5Pjt0Ozo6Ojo6Ojo6Ojs5OTk5OTk5OTk5OTk5OTk8Ozo6Ojo6Ojo6Ojo6Ojo6PDk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozw6Ojo6Ojo7Ozo6Ojo6
Ojo8Pjk5OTk5OTk5OTk5PDo6Ojo6Ojo6Ojo6Ojo6Ojs7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjo6Ojo6PDo6Ozs6Ojo8Ojo6Ojo6Oz45OTk5OTk5OT46Ojo6Ojo6
Ojo6Ojo6Ojo6Ojs+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTw7Ojo7Ojw6PT09PT09Ojo6Ozo6Ojo6Ozs8Pjk5Pjw6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojs7OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT46Ojo6Ojs9PT1F
RUpKSkpFPT07PDo6Ojo6Ojo6PDs7Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo6Ojo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk8Ozo6PDs9PT1FQ0NZR0FBQVlDRT09Ojo6Ojo6Ojo6Ojo6
Ojo6Ojo8Ojo6Ojo7Ozs6Ojo6Ojo6Ojo6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5Ozo6Ojo7PT1FQ1lHQVJCQj8/UkFDRT06Ozo6Ojo6Ojo6Ojo6Ojo7PDs7Ozs8Ozo7Ojo7PDs6Ojo6
Ojo6Ozk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs6Ojs6
Oz15SkNdQUI/P2l4DJ4/UllKPTs7Ojo6Ojo6Ojo6Ojs6PDs9PT09PTs9PT09REQ6Ojs8Ojo6Ojo6Ozk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7Ojo8Oz09RUNZQVJCaWl4v4FM4T9SXVU9PTs8
Ojs7Ojo6Ozw7Ojs7PT09PT09PT09PT1EPT09RDs7aDo6Ojo6Ozk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozo6PDs9PUpDXUFCP2l4r6JGQG54P1ZdQ3k9PTo7Ozo6aDs6Oz09PT1FRUVKRUpfVVVV
VVVVSkVEPUQ7Ojs6Ojo6Ozk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OT46Ojs6PXlKQ0FSQj9Pe6JGQEBAAWlCVl1DRT09PT09PT07PT09PUVKVUNZWV1HR0FBQUFBQUFHWUNKRT09Ozo6Ojo7Pjk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ojo7Oj09nV1BQj9pnrVMQEBAQEDs
P0JBXUNFPT09PT09PURFSlVVQ0dBQVZSUkJCQkI/QkJCQkJSQUdDSkVEOjs6Ojo8OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs6Ozs9RZ1dUj8/eO5MQEBAQEBARp4/QkFZQ0V5eUVFRUpVQ0NDR0FBUkJC
Qj8/Pz8/Pz8/Pz8/Pz9CUkEhVUVEOjs6Ojs+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk+Ojo6PXlDQVI/AOx6QEBAQEBARkBuTz9SQVlDQ19VVUNDQ1lHQUFSQkI/Pz8/P1BPT09NTU1NTU9PPz8/QkFHVUVE
Ojo6Ojw5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTo6aDs9naRCP8RuQEBA
QEBARkZGQLU/P1JBXVlDQ0NDXUdHQVZCQkI/Pz9QWE1NZU5ISEhLS0tITmRNTz8/QlZHX0Q6Ojo6Oz45OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Ojo7PZ1BQuFnQEBAQEBARkZGRkZAxD9CUkFBXVlHR0dBQVJe
XmM/UGRmSW1hcldzc3NzgXNzcoBtS0hkT1A/QlZDRUQ6PDo6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OXQ7OjsxlbCSQEBAQEBGRkZGRkZGRkx4P0JWQUFBR0FBUkJCaU9me0lUUVthYWJyV1dadn9qRkBAQEyB
AUtOTVA/QkFDRUQ8Ozo8OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Ojo621ne
TEBAQEBGRkZGRkZGRkZqZ09CQlJBQUFBVj9pT2RkZHgAT09QPz9QUE1kZEhJUWF1dmpGQEBGoktOTz9CUkdKRDo7Ojw5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT46Ojt5QZJARkZGRkZGRkZGampqXGqhYz9CQkJC
Pz8/T9rZVkFsbGxCQkJCPz8/P2lPT3hme0lRcI9qampAgUtNUD9CQVVEOjo8PDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjs8U0WkTEZGRkZGRmpgYGpqalxcasQ/Pz9CP1ZBWUNDll9DVZ1DWVlHR0FBUlJSQkI/
aWlPeGZ7VGJ2mn9qok5PP0JBVUU6Ojw8OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTlTOzpTQxNGRkxGamBgYGBgYGpcWnZceD8/VkdDRT09PT09PT09PUREPURFSkpDQ11BQVJCQj9pT3hmS1GLi5p/DE8/QkFVRTpo
Ojw5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTw7aOOCHkZgYGBgYGBgYGBgXFpa
doFCUkdVeT09Ojo7Ozs7Ojo8Ozs7Ozs9PT1FSkNDXUFSQkI/aU9kSGKLj5qAUD9CQVU9Ojw6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ojs624JrRmBgYGBcXFxcXGB1dVd27mxdSj09Ojo6Ojs7Ozo6Ojo6O2g8
aDo7PT09eUpDQ12kVkI/aU9NVIR+i3NPP0JHSkQ6Ojo+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OT46Ojs9XW5qYFxcXFxcXFxcdYODdXaOlUo9Ojs6Ojo6Ojo6Ojo6Ojo6Ojo6Ojs7PT1EPXlKQ0NdVkI/aVBJl36E
ck8/UkNFRDw6PDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PDpoO60CYFxcXFyI
XFxcXFdig4N+j96CPTs8Ojo6Ozw8PDw7PDw8Ojo6Ojo6Ojo7PUQ9PT1FVUNHVkI/UEmffIRh00JBQ0Q6PDw+OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT47OjxTiQFqXIhaWlpaWlxXYWJig37HR0U7PDo6Ozw+OTk5
OTk5OT48Ojo6Ojo6Ojs6RD09RD1FVUNBQj9QW3x8l3tjQkdfRDo7Oj45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk+Ojo6Oj2JtVxaWlpaWlpadVtbW3Bwfu77PTo6Ojw+OTk5OTk5OTk5OTk6Ojo6Ojo6Ojs6Oj09PT1F
Q0dCP2RwcHyDUEJBQ0VEOzo8Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTw8Ozw9
PZ2BdlpaWlpaWlpbUVtbW3CEFhVvPDo7OTk5OTk5OTk5OTk5OTk8Ojo6Ojo6Ojo6PT09PUVDQUI/SVtbn3tjUkdKRDw8Oj45OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk8Ojs7Oj0dCIhaWldXV1d1W1FRUVtbfH4IRFM7
PDk5OTk5OTk5OTk5OTk5OTk8Ojo6Ojo6Ojo6Oj09RUNBXmRRUXxRY0JBX0Q6PDw6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTlTPDpoOzs9eYmgWldXV1dXV2FUVFFRW1t8CYlTPDs+OTk5OTk5OTk5OTk5OTk5OTw7Ojo6
Ojo6Ojo7PT1KXV4/VFFwcFBCQUNEOjo6Ojs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+
PDw6OztESl2d/AF1V1dXcldhSVRUVFFRW58JG906bzk5OTk5OTk5OTk5OTk5OTk5OTs6Ojo6Ojo6Ojo9RFVBP0lUUXBPXkFDRUQ8
Ojo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7Ojo8PFOtXwDZlj0VAVdycmJiYklJSVRU
UVtwhAU+hjs+OTk5OTk5OTk5OTk5OTk5OTk5PDo6Ojo6Ojo8OkRFR157VFFbT15BQ0VEPDo8Ozk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTlTPDo8OlM916V4CK3cPOlXYmJhYmJJS0lJSVRRW3x+CDw6Uzk5OTk5OTk5OTk5OTk5
OTk5OTk8Ojo6Ojo6Ozs9RUNSZklUVD9sQVVERDo6Ojs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk7Ojo6Ojs9gkeeDEM8Oo0561dhYWFiVEtLS0lJVFFbn8eJUzo+OTk5OTk5OTk5OTk5OTk5OTk5Pjs6Ojo6Ojw7RHlDQWZLVK9j
bFlfRDo6Ojo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozo6Ojs9Q6tpewCJO648byQFYnFx
YW1IS0tLSUlUUVt+AdLcOjk5OTk5OTk5OTk5OTk5OTk5OTk8Ojo6Ojo6OkRFQ6RmS0l4bEdVRUQ6PDo8PDk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozo6PDpESkdeAL8I1FM8OzuKEQlbUVFRSEhISEtLVFFbcH4FPuJTOTk5OTk5
OTk5OTk5OTk5OTk5Pjs6Ojo6OjpERJalSEt72ZxDRUQ6Ojo6OnQ5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTs6Ojo9RVlsP1FRVolvPDo7OTkEUVRUUUhOSEhIS0lUUVt8dQs+Oz45OTk5OTk5OTk5OTk5OTk5OTk8Ojo6Ojo8RESW
2khIAEeCRUQ6PDw6PDo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk6Oo06PUNBXnhwvxxfUzw6
PjkHOQtRVFRLTk5OSEhLSVRRW37H2FM6Pjk5OTk5OTk5OTk5OTk5OTk5Pjo6Ojo8aEREQ2RODFnXRD06Ozw6PDw8Ozk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PDo6O0VZUmN7n69sQztoOjs5OYo5IlRUSU5OTk5ISEtJVFtwfgHS
bzs+OTk5OTk5OTk5OTk5OTk5OTs6Ojo6aDs9SqVkZKWWRD06Ojw6PDw6dDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTw6PD1KR0JQVJevXkM9OjxvOTk5OSQMVElkZU5OTkhISVRRW3B16z7AOzk5OTk5OTk5OTk5OT4+Ozw6Ojo6
PGhvRFlPT6WWREQ6Ojo6Ojw6PD45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT48Ojs9SkFCUFuX
v15ZPTw8dDk5OYo5F1RJSE1NZU5OSEtJVFFbg3UOdDo8OTk5OTk5OTk5Pjs6Ojo6PDo6OmhTU0McT6WWPT06Ojo6Ojo6PDs5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozo6RFVBQlBbl1RjQUU8PDw+OTk5mDmZVEhNTU1lTk5I
S0lUW3B+xxJvOj45OTk5O1NTOzw6Ojo6OjpoaDpTU19WPyFVRD1EOmg7Ojo6Ojs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTs7Oj1fQT9YYpdbP1ZfOjw6Pjk5OTmoOSJLWFhNZWVOTkhJVFFbcIQFfdw6Pj5TOzo6PDo8Ojw6
aDw6Ozs7PUpHVkdDSkVERDo6PDo6Ojo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7Ojo9
SkE/UGGXfE9eWUQ8Ojs5OTk5PjklDE5YWE1lZU5IS0lUUXCDj+s8rjs6Ojo7OuDgOjs6Ojs7PUQ9RUpDQUdDX1VDSkVERDo6Ojo6
PDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PjqNO0pBQlABhJ97XkFfOjw8PDk5OTmKOSdm
WFhYTWVOTkhLSVFbcH51DTk8PnR0OjtTOzs9REVKSkpfQ0NHR0FBQUFBQUFBR0NFPTo6Ojo+OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk6Ojs9R0JQwYuXcFBCWUQ8Ojo+OTk5Obw5pk1YWFhNZU5ISElUUXB8IwH+FzIED+gD
RF9fVUNHQUFWVlZCQkJCQj8/Pz8/Pz8/P0dFOjw8Oj45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5Ozo8PUNCP2Z2hIR7Y1ZVRDw6Oj45OTk5vTkWWFBYWGVlTkhLSVFbfI+iZmZLVHGAgHJyooGBgYEKgYFnZ2dnZ2dnZ2dnZ2dn
Z2cAbEo9Ozo6OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7PDtKVj9NcpqEg1BCQV89Ojo6
Pjk5OT45JQBQWFhNZU5OS0lUUXx+7FBNTkhJVFFhYld1dnZ2dn9/f1xcf2pqakZGRkZGQEBAAT9BRTo8PDw5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjo7PVlCT0t/diNRUD9BX0Q6Ojo+OTk5PjlvT1BQWE1lTkhLSVF8CU/T
TU1IS0lUUWFiV1dXdVpaWlp2dlxcXFxciG5uTExMQGtjUkM9PDo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTlTPDtKQT9PgGqPi0lQP1ZDRDw6Ojw5OTm8OQtNUFhYZWVOS0lRYuFjUE1NZEhLSVRRYWJiV1dXdXVaWlp1V3Nz
c3OIiG5uTEBnP0JHRTs8PD45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OVM6PVVWP2Rzao+L
wVA/UkNFOnQ6Ojw5Oaw5CFBQWE1lTkhLUQlpY1BQTWRISEtJUVFhYWJiV1dXV2JhgICAcnJXc3OIiG5MenheQUpEPDo8OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Ojo9WUI/SHNGmotxWD9CQVVEOmg6Ojs5PhHaUFhYZWVO
S1EAY2NQUE1kTkhLSUlUUVFhYmJhUVRtcXFxcYCAcnJXc3OIXEYAY0FVPTs8Oj45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OT46OkRZUj9kckB/mnVOUD9CR19EOjo6PDo5A09QWE1lTkuvaWM/UFhNTU5IS0lJVFFRVFRJS0tL
SUltbW1xcXGAcnJXWohGxGNSQ0U9PDw8OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjs6
PUNBP09URmqai2FYUD9eQUNFPTo8jTmmT1BYWGVLnl5jUFBYTU1OSEtJSUlJS0hOSEhIS0tLS0lJbW1xcWFicldaf6FjUllFRDs6
Oj45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTlTOjs9RV1SP2SAQH+Pi2FN0z9eQUNKRDo7
OVlNWFhOe2ljP1BQWE1NTkhISEhOZWVOTk5ISEhIS0tLSUltbW1xYWJXV3/3Y1JDRUQ8Ojo7OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTw6Ozs9SkFCaWSARn+PhGJLTWNebEFDX0UDMFhYSJ4/Y1BQUFhNTk5OTU1NTU1l
Tk5OTkhISEhLS0tJScFtcXFhYld2gT9BQ0VEPDo6PDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5PDo6OzpEVUFCaWRJ93+ahJ9bSWRQY15slUFNTWZPY1BQWE1NTU1YWFhYWE1lTk5OTkhISEhIS0tLSUnBbW1xcWFXdgoc
lUpEOjo6Ojs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Ojo6Ozs9SkdSP1BNSG1y
g3x8W1RJS2ZNZlRJZE5OTmVlTU1NTWVOTk5OSEhISEhLS0tJSUltbW1tcXFhYXJXc3MBgok9RDo6Ojo+OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7Ojo6Ojs9RUNBQj8/P1BPeGZmZmZmZE1mnk8WFllZXV1dCKam
p6enp6enmZmZmZmZmR/GxsvLy8vGxoyMEBAZDZs7Ozo8Ozs6Ozk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk7PDo6Ojw6PUVDR1ZSUkJeXmxsbKuVlZyc1xU6bzk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk+qDo8Ojo6PDs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjs7
Ojw8Ozs9RV9VVUNVVVVKRUQ9O1NTO2g8aKy8vL2srKy+vr6+B5iYmJiYmJiQF5CQkJCQkJDytra2trG9Ojs7Uz45OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OztoPDo7Ojs7Ozs7Ojo7PDw7aDw6
PD45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT5Trjo6jTw8PGg6Oo0Vrjs+Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk+PlM8PDtTPjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTmHd3cuOT4+Uzs8Pj4+OTk5dy+5OTk5OTk5OTm5Lzc5OTk5d3ctdzk5OTk5OTk5KXe5Pjk5OTk8hQQE7YWF7QQP
7eg5OTk5LHf0ijk5OTk5OYe6uoc5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OT45OTk+OTk5OTk5OTk5OW85OW85OTlTwDk5OTk5OQM5OTlvPjk5O1M++vq7u7s+Pj45OTo5OVM5OTlvDTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OYc56aqqGDnMOTk5OTk5OTl3OTaqFOg5Pjk5OTkREKoqETl3
PCCqEAc54jk5OT6FPh8Ut2hvPt08Ere4uLi4uM7OzhQg1qg7vYwUjBI+BD45NTmzqjjlObE5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5uTkZQECjObk5OTk5OTk5OTk5CkBMwzl3OTl3OQ1MQCs5d/KTGkBACpbghjw8kD4fGkBAwjnAOxIK
QEBAQEBAQEBAQJJ98jsDekBACuY5LLG6OaNAQAI58Tk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTm6OclA
QKM5KDk5OTk5OTk5OX2RQEyFOTk5OS45A0xAkn3MhZORQEBAktiG36g+JkxAQEDIPsM5GEBAkh60tLS0tKEGs3SGO996QEBATLc5
OQQ5o0BADjmHOTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Obo5yUBAozkoOTk5OTk5OTk5fZFATA85OTk5
OT7DTEAGffDFk5FAQEBABvwDPuZ6QEBAQAI+Dz6MQECwz15e0M/P+dQ+Ozs7B3pAenpAQBQHPjn2QEwOOYc5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5tjnJQED2OQ2KPjk5OTk5OTmTkUBMwz7MlDl3Pg9MQAZ95MU5kUB6zUBAzR0LekAa
zUBAAj4EPoxAQLC1iFpaWlqipsU6OzsHekDzDhpAQGezObdMTMg5hzk5OTk5OTk5OTk5OTk5OTk5OTk5Ojw+OTk5OTk5OTk5OTk5
OTk5OTmHOQJMRqNv5FPdioqKOTk5d32RQHoPOfAXJ+9vPXpAK5Pw75uRQHpHa0BGBpJAQBMCQEDCPik+jEBMsAlXV1eDgwlDMzo7
dI1uQGubX5FMTEyjyExuyDmHOTk5OTk5OTk5OTk5OTk5OTk5OTk6Oj45OTk5OTk5OTk5OTk5OTk5OYc5yUxMoJsSlJuUlJR9mzrj
fRBGeguTlH19+PgLekBrm8Xj0mtAbl2cqUZMTEzn+R5ATMLYA7uMRkwA0GPQXmxsG/50Ojs7aGdG8xF3OSpnTG6pbm4OOfE5OTk5
OTk5OTk5OTk5OTk5OTk5OTo6Pjk5OTk5OTk5OTk5OTk5OTk5hznlbmBna6mpa2upawqMPoU5IExgkmtra2trawZMRgX9O9vU80xn
pIJBqUBGE2yVskx6Ah09rQJMTJL1a2tra2traxnRqDrABkyhfS2FOeUGbm5nZwI58Tk5OTk5OTk5OTk5OTk5OTk5OTk5Ojo+OTk5
OTk5OTk5OTk5OTk5OTk575MZbm5MTExMTExMRs45qDvWzWBgTExGRkxGTGD1gj1Eefv1RmdWVlI/oY5eQmyOTEwTgkV5R6FuTExM
TExMTGBGoZPkOt/3TLV9OTn0OX0QZ25nDjmxOTk5OTk5OTk5OTk5OTk5OTk5OTk6Ozk5OTk5OTk5OTk5OTk5OTk5OTk5htHmt6Cg
ysrKoKCgszw6PIrRwgXK6rLq546yAEFHQ4JHq7ATAD9eQj9jYz8/Y2mOjmnVR0dHVt6Ojo7nsrLqBQUm1js8jRj2s293OTk0zDnp
jBg5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs5OTk5OTk5OTk5OTk5OTk5OTk5OTmUbzk5Pj4+Pj4+Pjk5Ojo8Oj2tiYIbnJyrbGxe
Pz8/Pz9pT09kZmZ7SW1tSUtmZE1PTz8/Pz8/Xl5ebKuVnIKJ/Tw7PDw6OTk5dDk5OTk5dzk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+roaGhYWFhoaGhjs6Ojo8Oj09REpKpkNZXUFBVlZWPz9pT09PZGZme3tmZnhPT09p
Pz9WVlZBpF1ZQ0pKPT09Ozo6PDvihQc5OTk5OTk5sfQNOTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5Pj4+Pj47Ozs7Oz47Ozo8Ozs6O1NTOz09PUVFVUNHR9VSUkJCQj8/P15CQkJSUtVBR0NVSkQ9PTs7Ozo8Ojw6Pj45OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OT48
Ojo6Ojw6Ojo8OjpEREVKVUNHR0FWVlZWVkFBR1lDVUpFREQ6Ojw8PDw8Ojo7lDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PlM7Ojo6Ojs8PDw6OkREREVKX1VD
Q0NVVUpFRURERDo8Ojw8Ojo6OlM+OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Uzo6PDo6Ojo8Ojo6OkREREQ9REREPTo6Ojw6PDs6PDw8Oz45OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTs8PjlTOzo6Ojs6Ojo8Ozw8PDo6aDw6PDo6OjtTPjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
Pjs8Ojo6Ojo6Ojo6Ojw6Ojw7Oz45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Pjs7UztTU1NTUz45OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs8dDk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Ozw8Ojo8Oz45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5PjxT
Ozo6Ojo6Ojo6Ojk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Pjs6Ojw6PDo6Ojo6Ojo8OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5O3Q6Ojo6Ojo6OjpEOjw6Ojo6Ojk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk+Pjw6
Ojo6Ojo6O1M7REQ6Ojw6Ojo5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OW87Ojo6Ojo6Ojo8PDo7PUpFREQ6Ojo6Ozk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjs7Ojo6Ojo6Ojo8Ozs7PUVDVUVEREQ6PDw5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Pjo6
Ojo6Ojo6Ojs6PDo6PUVDR1lfRURERDo7Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5O3Q7Ojo6Ojo6Ojs7Ojo9PT1FR0FHQ19FRUQ7
PDs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTs6Ojo6Ojo6Ojw6Oj09PT1FQ0FSQVlDX0VFOjw7OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
Pjs7Ojo6Ojo8Ojo8Oz09PT1FQ0dSQlJBXUNVRTpTPD45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk7Ojo6Ojo7PDs7PT09PURKVUNBQkJC
VkddQ19EOjo6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTo6Ojo8Ojs9PT09eUVKQ1lHUj8/QkJBQUdDRDw6Ojo+OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5Ojo8PDs7RD1ERUpVQ0dBQUI/Pz9CUkFBWUQ7Ojo6Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk6PDo9PT09RUpDQ11B
VkJCPz8/QkJSQUdFOjw6Ojs5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTo9PT09RV9DWUdBQVJCPz8/Pz9CQlJBXz06Ojo6OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5PT09RV9DQ11BQVZCQj9PTz8/P0JCVkM9Ozw6Ojw5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTl5RUpD
Q0dHQVZCQkI/T08/Pz8/QlJDPT06Ojo7Pjk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OUpDQ1lHQVZCQkI/P09PTz8/Pz9CWXk9Ojs6
Oz45OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5Q0NdR0FWQkI/P09NTU9PPz8/P0dKPT06Ojo6OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5OTk5
OTk5OTk=
]==]
	local PIXEL_SIZE = 128

	local function decode(data)
		local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local lookup = {}
		for i = 1, #alphabet do
			lookup[string.byte(alphabet, i)] = i - 1
		end
		data = string.gsub(data, "[^%w%+/]", "")
		local out, chunk = {}, {}
		for i = 1, #data, 4 do
			local a, b = lookup[string.byte(data, i)], lookup[string.byte(data, i + 1)]
			local c, d = lookup[string.byte(data, i + 2) or 0], lookup[string.byte(data, i + 3) or 0]
			local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
			chunk[#chunk + 1] = string.char(math.floor(n / 65536) % 256)
			if c then
				chunk[#chunk + 1] = string.char(math.floor(n / 256) % 256)
			end
			if d then
				chunk[#chunk + 1] = string.char(n % 256)
			end
			if #chunk >= 2048 then
				out[#out + 1] = table.concat(chunk)
				table.clear(chunk)
			end
		end
		out[#out + 1] = table.concat(chunk)
		return table.concat(out)
	end

	-- A user-supplied value -> an asset string an ImageLabel accepts.
	local function normalise(value)
		if type(value) ~= "string" or value == "" then
			return nil
		end
		if value:match("^https?://") or value:match("^rbxassetid://") or value:match("^rbxasset://") then
			return value
		end
		return "rbxassetid://" .. value
	end

	-- Route 2. Returns the asset string or nil, reason.
	local function fromFile()
		local customAsset = getcustomasset or getsynasset
		if type(customAsset) ~= "function" then
			return nil, "no getcustomasset"
		end
		if type(writefile) ~= "function" or type(isfile) ~= "function" then
			return nil, "no writefile / isfile"
		end
		local path = CONFIG.LogoFile
		local ok, result = pcall(function()
			local present = isfile(path)
			if present and type(readfile) == "function" then
				-- A cut-off or stale file would load as a blank image.
				local existing = readfile(path)
				present = type(existing) == "string" and #existing == EMBEDDED_PNG_BYTES
			end
			if not present then
				if type(isfolder) == "function" and type(makefolder) == "function" then
					local folder = string.match(path, "^(.*)/[^/]+$")
					if folder and not isfolder(folder) then
						makefolder(folder)
					end
				end
				writefile(path, decode(EMBEDDED_PNG))
			end
			return customAsset(path)
		end)
		if ok and type(result) == "string" and result ~= "" then
			return result
		end
		return nil, ok and "getcustomasset returned nothing" or tostring(result)
	end

	-- Route 2b: download CONFIG.LogoUrl once, cache it, load it. Returns
	-- asset, pixelWidth or nil, reason.
	local function fromUrl()
		local url = CONFIG.LogoUrl
		if type(url) ~= "string" or not url:match("^https?://") then
			return nil, "no LogoUrl"
		end
		local customAsset = getcustomasset or getsynasset
		if type(customAsset) ~= "function" or type(writefile) ~= "function"
			or type(isfile) ~= "function" or type(readfile) ~= "function" then
			return nil, "executor has no file functions"
		end
		local path = CONFIG.LogoUrlFile
		local PNG_SIGNATURE = "\137PNG\r\n\26\n"

		local function width(data)
			-- IHDR width: 4 bytes, big-endian, right after the 8-byte signature,
			-- the chunk length and the "IHDR" tag.
			local a, b, c, d = string.byte(data, 17, 20)
			if a then
				return a * 16777216 + b * 65536 + c * 256 + d
			end
			return nil
		end

		local ok, assetOrWhy, px = pcall(function()
			local data
			if isfile(path) then
				data = readfile(path)
			end
			if type(data) ~= "string" or string.sub(data, 1, 8) ~= PNG_SIGNATURE then
				data = nil
				local requester = (syn and syn.request) or (http and http.request)
					 or http_request or request
				if type(requester) == "function" then
					local response = requester({ Url = url, Method = "GET" })
					if type(response) == "table" and response.Success ~= false
						and (response.StatusCode == nil or response.StatusCode == 200) then
						data = response.Body
					end
				elseif type(game.HttpGet) == "function" then
					data = game:HttpGet(url)
				end
				if type(data) ~= "string" or string.sub(data, 1, 8) ~= PNG_SIGNATURE then
					error("the link did not return a PNG (expired, private or not a direct image link)")
				end
				if type(isfolder) == "function" and type(makefolder) == "function" then
					local folder = string.match(path, "^(.*)/[^/]+$")
					if folder and not isfolder(folder) then
						makefolder(folder)
					end
				end
				writefile(path, data)
			end
			return customAsset(path), width(data)
		end)
		if ok and type(assetOrWhy) == "string" and assetOrWhy ~= "" then
			return assetOrWhy, px
		end
		return nil, ok and "getcustomasset returned nothing" or tostring(assetOrWhy)
	end

	-- Route 3. Returns a Content or nil, reason.
	local function fromPixels()
		local ok, result = pcall(function()
			local AssetService = game:GetService("AssetService")
			local raw = decode(EMBEDDED_PIXELS)
			local count = string.byte(raw, 1)
			if count == 0 then
				count = 256
			end
			local paletteStart = 2
			local indexStart = paletteStart + count * 4
			local total = PIXEL_SIZE * PIXEL_SIZE
			assert(#raw == indexStart + total - 1, "pixel data is the wrong length")

			local pixels = buffer.create(total * 4)
			for i = 0, total - 1 do
				local entry = paletteStart + string.byte(raw, indexStart + i) * 4
				buffer.writeu8(pixels, i * 4, string.byte(raw, entry))
				buffer.writeu8(pixels, i * 4 + 1, string.byte(raw, entry + 1))
				buffer.writeu8(pixels, i * 4 + 2, string.byte(raw, entry + 2))
				buffer.writeu8(pixels, i * 4 + 3, string.byte(raw, entry + 3))
			end

			local image = AssetService:CreateEditableImage({ Size = Vector2.new(PIXEL_SIZE, PIXEL_SIZE) })
			image:WritePixelsBuffer(Vector2.zero, Vector2.new(PIXEL_SIZE, PIXEL_SIZE), pixels)
			local content = Content.fromObject(image)
			-- Prove an ImageLabel really accepts it before anything relies on it.
			local probe = Instance.new("ImageLabel")
			probe.ImageContent = content
			probe:Destroy()
			return content
		end)
		if ok and result ~= nil then
			return result
		end
		return nil, tostring(result)
	end

	local custom = normalise(CONFIG.Logo)
	if custom then
		CONFIG.ResolvedLogo = { Image = custom }
		CONFIG.LogoStatus = "CONFIG.Logo asset"
	else
		local downloaded, downloadPx = fromUrl()
		if not downloaded and CONFIG.LogoUrl ~= "" then
			warn(string.format("[%s] Logo download failed (%s); using the embedded logo.",
				CONFIG.Title, tostring(downloadPx)))
		end
		local file, fileWhy
		if downloaded then
			file = downloaded
		else
			file, fileWhy = fromFile()
		end
		if downloaded then
			CONFIG.ResolvedLogo = { Image = downloaded, Px = downloadPx }
			CONFIG.LogoStatus = "Downloaded (CONFIG.LogoUrl)"
		elseif file then
			CONFIG.ResolvedLogo = { Image = file, Px = 256 }
			CONFIG.LogoStatus = "Embedded (file asset)"
		else
			local content, pixelWhy = fromPixels()
			if content then
				CONFIG.ResolvedLogo = { Content = content, Px = PIXEL_SIZE }
				CONFIG.LogoStatus = "Embedded (EditableImage)"
			else
				CONFIG.LogoStatus = "Not loaded"
				warn(string.format(
					"[%s] Lumen logo could not be loaded (file route: %s; EditableImage route: %s). "
					.. "Upload the logo PNG to Roblox as an image and put its id in CONFIG.Logo.",
					CONFIG.Title, tostring(fileWhy), tostring(pixelWhy)
				))
			end
		end
	end

	-- Optional icon-only logo for the sidebar, same formats as Logo.
	local compact = normalise(CONFIG.LogoCompact)
	CONFIG.ResolvedLogoCompact = compact and { Image = compact } or CONFIG.ResolvedLogo
end

-- Draws a resolved logo source into an ImageLabel. `compact` shows only the
-- emblem (the full logo carries the LUMEN wordmark, which is unreadable at
-- sidebar size) by cropping with ImageRect on the one embedded image, so no
-- second asset is needed. Custom ids have unknown dimensions and are shown whole.
local LOGO_EMBLEM = { X = 0.15, Y = 0.172, W = 0.703, H = 0.457 }
local function applyLogo(label, source, compact)
	if source.Content then
		label.ImageContent = source.Content
	else
		label.Image = source.Image
	end
	if compact and source.Px then
		label.ImageRectOffset = Vector2.new(
			math.floor(LOGO_EMBLEM.X * source.Px), math.floor(LOGO_EMBLEM.Y * source.Px))
		label.ImageRectSize = Vector2.new(
			math.floor(LOGO_EMBLEM.W * source.Px), math.floor(LOGO_EMBLEM.H * source.Px))
	end
end

-- The brand mark used by the sidebar, the access gate, the About hero and the
-- floating button. With a logo it is a bare, transparent ImageLabel at native
-- proportions (Fit, never stretched). Without one it falls back to the accent
-- gradient and sparkle.
local function Brandmark(parent, size, props, compact)
	local mark = New("Frame", {
		Name = "BrandMark",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
	})
	if props then
		for key, value in pairs(props) do
			mark[key] = value
		end
	end

	local source = compact and CONFIG.ResolvedLogoCompact or CONFIG.ResolvedLogo
	if source then
		mark.BackgroundTransparency = 1
		local label = New("ImageLabel", {
			Name = "Logo",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = Theme.Color.White,
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = mark.ZIndex + 1,
		})
		applyLogo(label, source, compact)
		label.Parent = mark
	else
		Round(mark, Theme.Radius.SM)
		AccentGradient(mark, 45)
		Icon(mark, "sparkle", math.floor(size * 0.52), Theme.Color.White, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
	end

	mark.Parent = parent
	return mark
end

--------------------------------------------------------------------------
-- REUSABLE UI COMPONENTS
--------------------------------------------------------------------------

-- Assigned in the notification section; declared here so components can call it.
local notify

-- Controls that "Reset UI" restores: { Set = fn, Default = value }.
local resettables = {}

-- Controls a saved config can restore, keyed by their label (duplicates get
-- a numeric suffix). Toggle and Slider register themselves.
local Config = { Controls = {} }
function Config.Register(key, control, kind)
	if type(key) ~= "string" or key == "" then
		return
	end
	local unique, n = key, 1
	while Config.Controls[unique] do
		n = n + 1
		unique = key .. "#" .. n
	end
	control.ConfigKey = unique
	control.Kind = kind
	Config.Controls[unique] = control
end

-- QUICK ACTION STATE ----------------------------------------------------
-- One record per feature that can be switched from more than one place (the
-- main toggle, the Home quick action, the floating overlay). A record owns no
-- state of its own: `Get` / `Set` reach the feature's real state (for the egg
-- features that is Eggs.FarmActive / Eggs.PlaceActive, reached through
-- Stats.Hub because the egg page is built after Home). Every view reads
-- through Features.Get, writes through Features.Set, and repaints itself from
-- Features.Subscribe, so two views cannot disagree: there is nothing to
-- disagree about.
local Features = {
	List = {},
	ByKey = {},
	Listeners = {},
	-- Runtime-only details the overlay shows. Never saved.
	Snapshot = { Farm = { Phase = "off" }, Place = {}, Stats = {}, Recent = {} },
	-- Auto Server Hop runtime (never saved): when the next automatic hop is due
	-- and whether a teleport is in flight. Filled in by the Automation page.
	Hop = { NextAt = nil, Busy = false },
	Source = function()
		return nil
	end,
}
local QuickOverlay = {}

function Features.Define(def)
	table.insert(Features.List, def)
	Features.ByKey[def.Key] = def
end

-- The features that appear as Quick Actions (Home buttons and overlay rows).
function Features.Quick()
	local out = {}
	for _, def in ipairs(Features.List) do
		if def.Quick then
			table.insert(out, def)
		end
	end
	return out
end

local function featureHandle(def, name)
	local hub = Features.Source()
	local handle = hub and hub[name]
	if type(handle) == "function" then
		return handle
	end
	return nil
end

function Features.Get(key)
	local def = Features.ByKey[key]
	if not def then
		return false
	end
	local getter = def.Get or featureHandle(def, def.HubGet)
	if not getter then
		return false
	end
	local ok, value = pcall(getter)
	return ok and value == true
end

-- Tells every view that `key` (or, with nil, anything) may have changed. Each
-- listener re-reads Features.Get, so calling this when nothing changed is
-- harmless.
function Features.Changed(key)
	local copy = {}
	for index, entry in ipairs(Features.Listeners) do
		copy[index] = entry
	end
	for _, entry in ipairs(copy) do
		if entry.On then
			local ok, err = pcall(entry.Fn, key)
			if not ok then
				warn("[Features] a listener failed: " .. tostring(err))
			end
		end
	end
end

function Features.Set(key, value)
	local def = Features.ByKey[key]
	if not def then
		return false
	end
	value = value == true
	if Features.Get(key) ~= value then
		local setter = def.Set or featureHandle(def, def.HubSet)
		if setter then
			pcall(setter, value)
		end
	end
	Features.Changed(key)
	-- Whether it ended up as asked: a farm that refuses to start stays off.
	return Features.Get(key) == value
end

function Features.Subscribe(callback)
	local entry = { Fn = callback, On = true }
	table.insert(Features.Listeners, entry)
	return {
		Disconnect = function()
			entry.On = false
		end,
	}
end

function Features.Clear()
	for _, entry in ipairs(Features.Listeners) do
		entry.On = false
	end
	table.clear(Features.Listeners)
end

-- Called by the egg page whenever it publishes; stores what the overlay shows
-- and only announces a change when something visible actually moved.
function Features.Publish(card, place, counters)
	local farm = Features.Snapshot.Farm
	local nextFarm = {
		Phase = card and card.Phase or "off",
		Target = card and card.Target or nil,
		Rarity = card and card.Rarity or nil,
		Step = card and card.Step or nil,
		Message = card and card.Message or nil,
	}
	local farmChanged = false
	for _, field in ipairs({ "Phase", "Target", "Rarity", "Step", "Message" }) do
		if farm[field] ~= nextFarm[field] then
			farmChanged = true
		end
		farm[field] = nextFarm[field]
	end
	local slots = Features.Snapshot.Place
	local nextPlace = {
		Discovered = place and place.Discovered == true or false,
		Filled = place and place.Filled or 0,
		Slots = place and place.Slots or 0,
	}
	local placeChanged = false
	for _, field in ipairs({ "Discovered", "Filled", "Slots" }) do
		if slots[field] ~= nextPlace[field] then
			placeChanged = true
		end
		slots[field] = nextPlace[field]
	end
	-- The egg counters are read from the one store the egg page keeps
	-- (Eggs.Counters); this only mirrors what the overlay prints.
	local statsChanged = false
	if counters then
		local best = counters.Best
		local nextStats = {
			Farmed = counters.Farmed or 0,
			Placed = counters.Placed or 0,
			Detected = counters.Detected or 0,
			BestName = best and best.Name or nil,
			BestRarity = best and best.Rarity or nil,
			RecentVersion = counters.RecentVersion or 0,
		}
		local current = Features.Snapshot.Stats
		for field, value in pairs(nextStats) do
			if current[field] ~= value then
				statsChanged = true
			end
		end
		for field in pairs(current) do
			if nextStats[field] == nil and current[field] ~= nil then
				statsChanged = true
			end
		end
		Features.Snapshot.Stats = nextStats
		Features.Snapshot.Recent = counters.Recent or {}
	end
	if farmChanged then
		Features.Changed("farm")
	end
	if placeChanged then
		Features.Changed("place")
	end
	if statsChanged then
		Features.Changed("stats")
	end
end

Features.Define({
	Key = "farm", Text = "Auto farm", Icon = "target", Quick = true,
	Hint = "Hunt every egg of the rarities you picked",
	HubGet = "IsFarmActive", HubSet = "SetFarm",
})
Features.Define({
	Key = "place", Text = "Auto place", Icon = "gem", Quick = true,
	Hint = "Move the rarest eggs onto your plot",
	HubGet = "IsPlaceActive", HubSet = "SetPlace",
})
-- FPS Boost, AFK mode and Auto Server Hop are the same kind of record: their
-- state lives in State (State.FpsBoost / State.Afk / State.AutoHop), the Get
-- and Set are attached where each feature is implemented, and every view
-- (Home button, settings toggle, overlay row) reads and writes through them.
Features.Define({
	Key = "fps", Text = "FPS Boost", Icon = "gauge", Quick = true,
	Hint = "Cut visual effects, shadows and textures",
})
Features.Define({
	Key = "afk", Text = "AFK mode", Icon = "moon", Quick = true,
	Hint = "Black screen; farming and audio keep running",
})
Features.Define({
	Key = "hop", Text = "Auto server hop", Icon = "server", Quick = true, HideWhenOff = true,
	Hint = "Join a different server on a timer",
})
-- Auto Load Config is a Home quick action only: it has no live status to show.
Features.Define({
	Key = "autoload", Text = "Auto load config", Icon = "save", Quick = true, Overlay = false,
	Hint = "Load your startup config when this script starts",
})
-- The overlay's own switch is a feature too (not a quick action), so the
-- settings toggle, the Home button and the overlay's close button all share it.
Features.Define({
	Key = "overlay", Text = "Quick actions overlay", Icon = "eye",
	Hint = "Floating live status you can drag anywhere",
	Get = function()
		return State.QuickOverlay == true
	end,
	Set = function(value)
		QuickOverlay.SetEnabled(value)
	end,
})

-- Hover / press feedback for any GuiButton. `Visual` is the object that
-- animates (defaults to the button itself). Transparencies animate when
-- Rest/Hover/Press are supplied; PressScale/HoverScale add a UIScale bounce.
local function attachFeedback(button, options)
	local visual = options.Visual or button
	local rest, hover, press = options.Rest, options.Hover, options.Press
	local scale = nil
	if options.PressScale or options.HoverScale then
		scale = New("UIScale", { Parent = visual })
	end
	local hovered = false
	local pressed = false

	local function refresh()
		if rest ~= nil then
			local goal = rest
			if pressed then
				goal = press
			elseif hovered then
				goal = hover
			end
			play(visual, Motion.Swift, "Out", { BackgroundTransparency = goal })
		end
		if scale then
			local s = 1
			if pressed then
				s = options.PressScale or 1
			elseif hovered then
				s = options.HoverScale or 1
			end
			play(scale, Motion.Swift, "Out", { Scale = s })
		end
		if options.OnState then
			options.OnState(hovered, pressed)
		end
	end

	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		refresh()
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		refresh()
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		-- Touch never sends MouseLeave, so drop the hover state on release.
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			hovered = false
		end
		refresh()
	end)
end

--------------------------------------------------------------------------
-- TOOLTIPS
--
-- One shared bubble that moves to whichever control is hovered, so switching
-- targets never stacks bubbles. The host is built on first use rather than at
-- load because the ScreenGui is created after the widget helpers, and the
-- widget helpers are what call this.
--
-- Forward declaration, same pattern as notify/setPage/setOpen: the ScreenGui
-- is created far below, but the bubble parents itself to it on first use.
-- Without this the name resolves to a nil global and the tooltip silently
-- never appears.
local screen
--------------------------------------------------------------------------

local TOOLTIP_MAX_WIDTH = 230
local TOOLTIP_DELAY = 0.35

local tooltipHost = nil
local tooltipBubble = nil
local tooltipBody = nil

local function ensureTooltip()
	if tooltipBubble and tooltipBubble.Parent then
		return tooltipBubble
	end
	tooltipHost = New("Frame", {
		Name = "Tooltips",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		DisplayOrder = 60,
		Parent = screen,
	})
	tooltipBubble = New("CanvasGroup", {
		Name = "Bubble",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		GroupTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = tooltipHost,
	})
	local plate = New("Frame", {
		Name = "Plate",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Parent = tooltipBubble,
	})
	Round(plate, Theme.Radius.SM)
	local plateStroke = Stroke(plate, 0.5, Accent.Color)
	bindAccent(function()
		plateStroke.Color = Theme.Color.White:Lerp(Accent.Color, 0.6)
	end)
	Padding(plate, 7, 10, 7, 10)
	tooltipBody = Text(plate, "", Theme.Type.Micro, "SemiBold", Theme.Color.TextHi, {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
	})
	-- Caps a long string instead of letting the bubble run off-screen.
	New("UISizeConstraint", {
		MaxSize = Vector2.new(TOOLTIP_MAX_WIDTH, 20),
		Parent = tooltipBody,
	})
	return tooltipBubble
end

local function hideTooltip()
	if not tooltipBubble or not tooltipBubble.Parent or not tooltipBubble.Visible then
		return
	end
	local bubble = tooltipBubble
	play(bubble, Motion.Swift, "In", { GroupTransparency = 1 })
	task.delay(scaledTime(Motion.Swift) + 0.03, function()
		-- A newer hover may have reused this bubble in the meantime.
		if tooltipBubble == bubble and bubble.Visible then
			bubble.Visible = false
		end
	end)
end

local function showTooltip(target, content)
	local bubble = ensureTooltip()
	if not bubble then
		return
	end
	tooltipBody.Text = content
	bubble.Visible = true
	bubble.GroupTransparency = 1
	-- One frame is needed so the label reports its real measured size.
	task.defer(function()
		if tooltipBubble ~= bubble or not bubble.Parent or not bubble.Visible then
			return
		end
		local width = tooltipBody.AbsoluteSize.X
		local height = tooltipBody.AbsoluteSize.Y
		if width <= 0 or height <= 0 then
			return
		end
		bubble.Size = UDim2.fromOffset(math.ceil(width) + 20, math.ceil(height) + 14)
		local left, top = target.AbsolutePosition.X, target.AbsolutePosition.Y
		local tWidth, tHeight = target.AbsoluteSize.X, target.AbsoluteSize.Y
		local bubbleHeight = bubble.Size.Y.Offset
		local bubbleWidth = bubble.Size.X.Offset
		-- Kept inside the screen so a control near an edge never clips its tip.
		local viewport = screen.AbsoluteSize
		local x = math.clamp(left + (tWidth / 2), bubbleWidth / 2 + 8, math.max(viewport.X - bubbleWidth / 2 - 8, bubbleWidth / 2 + 8))
		-- Above the control when there is room, otherwise below it; it
		-- drifts 4px into place while fading in.
		local goal, from
		if top - 8 >= bubbleHeight + 4 then
			goal = UDim2.fromOffset(x, top - 8)
			from = UDim2.fromOffset(x, top - 4)
		else
			goal = UDim2.fromOffset(x, top + tHeight + 8)
			from = UDim2.fromOffset(x, top + tHeight + 4)
		end
		bubble.Position = from
		play(bubble, Motion.Quick, "Out", { GroupTransparency = 0, Position = goal })
	end)
end

-- Tip(target, text) attaches a hover tooltip to any GuiObject with MouseEnter.
-- No-ops on empty text so callers can pass an optional field straight through.
local function Tip(target, content)
	if not content or content == "" then
		return
	end
	local token = 0
	target.MouseEnter:Connect(function()
		token = token + 1
		local mine = token
		-- A short delay stops the bubble flickering across the sidebar as the
		-- pointer travels down the list.
		task.delay(TOOLTIP_DELAY, function()
			if mine == token and target.Parent then
				showTooltip(target, content)
			end
		end)
	end)
	target.MouseLeave:Connect(function()
		token = token + 1
		hideTooltip()
	end)
end

-- Section(parent, title, options) -> card
-- The card is still the parent every control is added to. With a title it now
-- has a header you can click to collapse it: the card animates down to just the
-- header and back, nothing inside is hidden, destroyed or re-parented (it is
-- simply clipped while closed), so every control keeps working and keeps its
-- own state. options.Collapsed starts it closed; options.Collapsible = false
-- keeps a plain heading. Open/closed is remembered for the session by title.
local sectionMemory = {}
local function Section(parent, title, options)
	options = options or {}
	local card = New("Frame", {
		Name = "Section",
		BackgroundColor3 = Theme.Color.Alt,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Round(card, Theme.Radius.MD)
	Stroke(card, 0.92)
	-- A faint fade toward the bottom gives cards depth without extra frames.
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.22),
		}),
		Parent = card,
	})
	Padding(card, 8, 8, 8, 8)
	local layout = New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = card,
	})
	if not title then
		return card
	end

	local HEAD = 24
	local collapsible = options.Collapsible ~= false
	local head
	if collapsible then
		head = New("TextButton", {
			Name = "Heading",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, HEAD),
			LayoutOrder = nextOrder(card),
			Parent = card,
		})
		Round(head, Theme.Radius.XS)
		local label = Text(head, string.upper(title), Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -34, 1, 0),
		})
		local chevron = Icon(head, "chevronUp", 12, Theme.Color.TextLow, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
		})
		attachFeedback(head, {
			Rest = 1, Hover = 0.95, Press = 0.9,
			OnState = function(hovered)
				label.TextColor3 = hovered and Theme.Color.TextMid or Theme.Color.TextLow
				iconTint(chevron, hovered and Theme.Color.TextMid or Theme.Color.TextLow)
			end,
		})

		local closed = sectionMemory[title] == true
		if options.Collapsed ~= nil and sectionMemory[title] == nil then
			closed = options.Collapsed == true
		end
		local token = 0
		-- Total card height with everything showing: the list's content plus
		-- the card's own top and bottom padding (8 + 8).
		local function openHeight()
			return layout.AbsoluteContentSize.Y + 16
		end
		local function apply(wantClosed, animate)
			closed = wantClosed
			sectionMemory[title] = closed
			token = token + 1
			local mine = token
			local rotation = closed and 180 or 0
			if not animate then
				chevron.Rotation = rotation
				if closed then
					card.AutomaticSize = Enum.AutomaticSize.None
					card.ClipsDescendants = true
					card.Size = UDim2.new(1, 0, 0, HEAD + 16)
				end
				return
			end
			play(chevron, Motion.Base, "Back", { Rotation = rotation })
			if closed then
				-- Freeze at the current height, then shrink to the header.
				local current = card.AbsoluteSize.Y
				card.AutomaticSize = Enum.AutomaticSize.None
				card.ClipsDescendants = true
				card.Size = UDim2.new(1, 0, 0, current)
				play(card, Motion.Base, "Out", { Size = UDim2.new(1, 0, 0, HEAD + 16) })
			else
				-- Grow to the content height, then hand sizing back to the
				-- layout so later changes (a list gaining rows) still fit.
				play(card, Motion.Base, "Out", { Size = UDim2.new(1, 0, 0, openHeight()) })
				task.delay(scaledTime(Motion.Base) + 0.03, function()
					if token == mine and not closed and card.Parent then
						card.ClipsDescendants = false
						card.AutomaticSize = Enum.AutomaticSize.Y
						card.Size = UDim2.new(1, 0, 0, 0)
					end
				end)
			end
		end
		head.Activated:Connect(function()
			apply(not closed, true)
		end)
		if closed then
			apply(true, false)
		end
		-- Lets a caller (and later a saved layout) open or close it.
		card:SetAttribute("Collapsible", true)
		Features.Sections = Features.Sections or {}
		Features.Sections[title] = apply
	else
		local plain = Text(card, string.upper(title), Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Name = "Heading",
			Size = UDim2.new(1, 0, 0, HEAD),
			LayoutOrder = nextOrder(card),
		})
		Padding(plain, 0, 0, 0, 6)
	end
	return card
end

local function ButtonGrid(parent, columns)
	local frame = New("Frame", {
		Name = "ButtonGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	New("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.new(1 / columns, -(columns - 1) * 8 / columns, 0, 40),
		CellPadding = UDim2.fromOffset(8, 8),
		Parent = frame,
	})
	return frame
end

-- Button(parent, { Text, Icon, Style = "Primary"|"Secondary"|"Danger", Callback, Size })
local function Button(parent, options)
	local style = options.Style or "Secondary"
	local button = New("TextButton", {
		Name = "Button",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.White,
		Size = options.Size or UDim2.new(1, 0, 0, 40),
		LayoutOrder = options.LayoutOrder or nextOrder(parent),
		Parent = parent,
	})
	Round(button, Theme.Radius.SM)

	local rest, hover, press = 0.92, 0.86, 0.8
	local contentColor = Theme.Color.TextHi
	if style == "Primary" then
		rest, hover, press = 0.05, 0, 0.2
		contentColor = Theme.Color.White
		AccentGradient(button, 15)
	elseif style == "Danger" then
		button.BackgroundColor3 = Theme.Color.Negative
		rest, hover, press = 0.85, 0.75, 0.65
		contentColor = Theme.Color.Negative
		Stroke(button, 0.7, Theme.Color.Negative)
	else
		Stroke(button, 0.88)
	end
	button.BackgroundTransparency = rest

	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = button,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = content,
	})
	local glyph = nil
	if options.Icon then
		glyph = Icon(content, options.Icon, 16, contentColor, { LayoutOrder = 1 })
	end
	local label = Text(content, options.Text or "Button", Theme.Type.Body, "SemiBold", contentColor, {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 2,
	})
	if style == "Primary" then
		-- Readable on every accent: dark content on light accents, white otherwise.
		bindAccent(function()
			label.TextColor3 = Accent.On
			if glyph then
				iconTint(glyph, Accent.On)
			end
		end)
	end

	attachFeedback(button, { Rest = rest, Hover = hover, Press = press, HoverScale = 1.02, PressScale = 0.97 })
	Tip(button, options.Tip)

	button.Activated:Connect(function()
		if options.Callback then
			options.Callback()
		else
			notify("Not configured", "Info", "This feature is not configured yet.")
		end
	end)

	return {
		Instance = button,
		SetText = function(text)
			label.Text = text
		end,
	}
end

local function IconButton(parent, iconName, options)
	local size = options.Size or 34
	local button = New("TextButton", {
		Name = "IconButton",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.93,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	if options.Position then
		button.Position = options.Position
	end
	if options.AnchorPoint then
		button.AnchorPoint = options.AnchorPoint
	end
	Round(button, Theme.Radius.SM)
	Stroke(button, 0.9)
	local glyph = Icon(button, iconName, options.IconSize or 16, Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	attachFeedback(button, {
		Rest = 0.93,
		Hover = 0.82,
		Press = 0.72,
		HoverScale = 1.06,
		PressScale = 0.92,
		OnState = function(hovered)
			iconTint(glyph, hovered and Theme.Color.TextHi or Theme.Color.TextMid)
		end,
	})
	Tip(button, options.Tip)
	button.Activated:Connect(function()
		if options.Callback then
			options.Callback()
		end
	end)
	return button
end

-- Toggle(parent, { Text, Description, Default, Callback }) -> { Get, Set, Default }
local function Toggle(parent, options)
	-- Shared = "farm" binds the switch to a Features record: it then owns no
	-- state of its own, reads the feature's, writes the feature's, and repaints
	-- whenever any other view changes it.
	local shared = options.Shared
	local state = options.Default == true
	if shared then
		state = Features.Get(shared)
	end
	local hasDescription = options.Description ~= nil
	-- Optional, for the rare cases where the label itself carries meaning
	-- (the rarity picker). Defaults to the normal title colour.
	local textColor = options.TextColor or Theme.Color.TextHi

	local row = New("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, hasDescription and 56 or 46),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Round(row, Theme.Radius.SM)

	local descLabel = nil
	if hasDescription then
		Text(row, options.Text, Theme.Type.Body, "Medium", textColor, {
			Position = UDim2.fromOffset(12, 9),
			Size = UDim2.new(1, -120, 0, 20),
		})
		descLabel = Text(row, options.Description, Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(12, 29),
			Size = UDim2.new(1, -120, 0, 16),
		})
	else
		Text(row, options.Text, Theme.Type.Body, "Medium", textColor, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -120, 1, 0),
		})
	end

	local stateLabel = Text(row, "OFF", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, 0),
		Size = UDim2.fromOffset(30, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local track = New("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		Parent = row,
	})
	Round(track, Theme.Radius.Pill)
	local trackStroke = Stroke(track, 1, Accent.Color, 1)
	local knob = New("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.Color.TextHi,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		Parent = track,
	})
	Round(knob, Theme.Radius.Pill)

	local function render(animate)
		local trackGoal = {
			BackgroundColor3 = state and Accent.Color or Theme.Color.White,
			BackgroundTransparency = state and 0.05 or 0.86,
		}
		local knobGoal = {
			Position = UDim2.new(0, state and 23 or 3, 0.5, 0),
			BackgroundColor3 = state and Accent.On or Theme.Color.TextHi,
		}
		local strokeGoal = { Transparency = state and 0.35 or 1 }
		if animate then
			play(track, Motion.Base, "Soft", trackGoal)
			play(knob, Motion.Base, "Back", knobGoal)
			play(trackStroke, Motion.Base, "Soft", strokeGoal)
		else
			for key, value in pairs(trackGoal) do
				track[key] = value
			end
			for key, value in pairs(knobGoal) do
				knob[key] = value
			end
			trackStroke.Transparency = strokeGoal.Transparency
		end
		stateLabel.Text = state and "ON" or "OFF"
		stateLabel.TextColor3 = state and Accent.Text or Theme.Color.TextLow
	end

	-- Accent changes repaint an ON toggle in place (track, outline, knob, label).
	bindAccent(function()
		trackStroke.Color = Accent.Color
		if state then
			track.BackgroundColor3 = Accent.Color
			knob.BackgroundColor3 = Accent.On
			stateLabel.TextColor3 = Accent.Text
		end
	end)

	local function set(value, silent)
		value = value == true
		if shared then
			-- The feature decides. Write the request to it (unless this is only
			-- a repaint) and show what it actually ended up as.
			if not silent then
				Features.Set(shared, value)
			end
			state = Features.Get(shared)
			render(true)
			return
		end
		local changed = value ~= state
		state = value
		render(true)
		if changed and not silent and options.Callback then
			options.Callback(state)
		end
	end

	attachFeedback(row, { Rest = 1, Hover = 0.95, Press = 0.9 })
	row.Activated:Connect(function()
		local current = state
		if shared then
			current = Features.Get(shared)
		end
		set(not current)
	end)
	render(false)
	if shared then
		Features.Subscribe(function(key)
			if key == nil or key == shared then
				local now = Features.Get(shared)
				if now ~= state then
					state = now
					render(true)
				end
			end
		end)
	end

	local control = {
		Instance = row,
		Default = options.Default == true,
		Get = function()
			if shared then
				return Features.Get(shared)
			end
			return state
		end,
		Set = set,
		SetDescription = function(text)
			if descLabel then
				descLabel.Text = text
			end
		end,
	}
	if options.Reset ~= false then
		table.insert(resettables, control)
	end
	if options.Persist ~= false then
		Config.Register(options.Key or options.Text, control, "toggle")
	end
	return control
end

-- Checkbox(parent, { Text, Default, Color, TextColor, Key, Persist, Reset, Callback })
-- A compact square-tick control. Used for "Remember me" on the access gate and
-- for the Auto Place rarity picker, where a full-width toggle switch would make
-- the list far taller than it needs to be. `Color` tints it with a rarity colour
-- so the picker reads as a set of coloured tags rather than switches.
local function Checkbox(parent, options)
	local state = options.Default == true
	local tint = options.Color

	local row = New("TextButton", {
		Name = "Checkbox",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Round(row, Theme.Radius.XS)

	local box = New("Frame", {
		Name = "Box",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 7),
		Size = UDim2.fromOffset(16, 16),
		Parent = row,
	})
	Round(box, Theme.Radius.XS)
	local boxStroke = Stroke(box, 1, tint or Accent.Color, 1)
	local tick = Icon(box, "check", 12, Theme.Color.White, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	tick.Visible = false

	Text(row, options.Text, Theme.Type.Body, "Medium", options.TextColor or Theme.Color.TextHi, {
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -32, 1, 0),
	})

	local function render(animate)
		local color = tint or Accent.Color
		local boxGoal = {
			BackgroundColor3 = state and color or Theme.Color.White,
			BackgroundTransparency = state and 0.05 or 0.86,
		}
		local strokeGoal = { Transparency = state and 0.35 or 1, Color = color }
		if animate then
			play(box, Motion.Base, "Soft", boxGoal)
			play(boxStroke, Motion.Base, "Soft", strokeGoal)
		else
			for key, value in pairs(boxGoal) do
				box[key] = value
			end
			for key, value in pairs(strokeGoal) do
				boxStroke[key] = value
			end
		end
		tick.Visible = state
	end

	bindAccent(function()
		if not tint then
			boxStroke.Color = Accent.Color
		end
		if state then
			box.BackgroundColor3 = tint or Accent.Color
		end
	end)

	local function set(value, silent)
		value = value == true
		local changed = value ~= state
		state = value
		render(true)
		if changed and not silent and options.Callback then
			options.Callback(state)
		end
	end

	attachFeedback(row, { Rest = 1, Hover = 0.95, Press = 0.9 })
	row.Activated:Connect(function()
		set(not state)
	end)
	render(false)

	local control = {
		Instance = row,
		Default = options.Default == true,
		Get = function()
			return state
		end,
		Set = set,
	}
	if options.Reset ~= false then
		table.insert(resettables, control)
	end
	if options.Persist ~= false then
		Config.Register(options.Key or options.Text, control, "toggle")
	end
	return control
end

-- ActionToggle(parent, { Text, Icon, Hint, Get, Set }) -> { Instance, Refresh }
-- A compact two-line button that also reports on/off state, so a feature can be
-- flipped straight from the Home page without visiting the page that owns it.
-- `Get`/`Set` are passed in rather than owned, which is what lets the Home
-- controls drive the farm/place state that the egg page manages.
local function ActionToggle(parent, options)
	local get = options.Get
	local set = options.Set

	local row = New("TextButton", {
		Name = "ActionToggle",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.94,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Round(row, Theme.Radius.SM)
	local rowStroke = Stroke(row, 1, Accent.Color, 1)

	local iconHolder = Icon(row, options.Icon or "power", 18, Theme.Color.TextHi, {
		Position = UDim2.fromOffset(11, 10),
	})
	local titleLabel = Text(row, options.Text, Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(37, 9),
		Size = UDim2.new(1, -48, 0, 18),
	})
	local hintLabel = Text(row, options.Hint or "", Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
		Position = UDim2.fromOffset(37, 27),
		Size = UDim2.new(1, -104, 0, 16),
	})
	local stateLabel = Text(row, "OFF", Theme.Type.Micro, "Bold", Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(48, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function render(animate)
		local state = get() == true
		local rowGoal = {
			BackgroundColor3 = state and Accent.Color or Theme.Color.White,
			BackgroundTransparency = state and 0.9 or 0.94,
		}
		local strokeGoal = { Transparency = state and 0.3 or 1, Color = Accent.Color }
		if animate then
			play(row, Motion.Base, "Soft", rowGoal)
			play(rowStroke, Motion.Base, "Soft", strokeGoal)
		else
			for key, value in pairs(rowGoal) do
				row[key] = value
			end
			for key, value in pairs(strokeGoal) do
				rowStroke[key] = value
			end
		end
		titleLabel.TextColor3 = state and Accent.On or Theme.Color.TextHi
		stateLabel.Text = state and "ON" or "OFF"
		stateLabel.TextColor3 = state and Accent.Text or Theme.Color.TextLow
		iconTint(iconHolder, state and Accent.On or Theme.Color.TextHi)
	end

	bindAccent(function()
		rowStroke.Color = Accent.Color
		if get() == true then
			row.BackgroundColor3 = Accent.Color
		end
	end)

	attachFeedback(row, { Rest = 0.94, Hover = 0.88, Press = 0.82 })
	row.Activated:Connect(function()
		set(not get())
		render(true)
	end)
	render(false)

	return {
		Instance = row,
		Refresh = render,
		SetHint = function(text)
			hintLabel.Text = text
		end,
	}
end

-- Slider(parent, { Text, Min, Max, Default, Step, Suffix, Format, Callback }) -> { Get, Set, Default }
local function Slider(parent, options)
	local minValue = options.Min or 0
	local maxValue = options.Max or 100
	local step = options.Step or 1
	local suffix = options.Suffix or ""
	local formatter = options.Format

	local function snap(raw)
		if step > 0 then
			raw = minValue + math.floor((raw - minValue) / step + 0.5) * step
		end
		raw = math.clamp(raw, minValue, maxValue)
		-- Strip floating-point noise (0.30000000000000004 and friends).
		return tonumber(string.format("%.4f", raw))
	end

	local function display(v)
		if formatter then
			return formatter(v)
		end
		if step >= 1 then
			return tostring(math.floor(v + 0.5)) .. suffix
		end
		return string.format("%.1f", v) .. suffix
	end

	local defaultValue = snap(options.Default or minValue)
	local value = defaultValue

	local row = New("Frame", {
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Text(row, options.Text, Theme.Type.Body, "Medium", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -100, 0, 20),
	})
	local valueLabel = Text(row, "", Theme.Type.Body, "SemiBold", Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(80, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bindAccent(function()
		valueLabel.TextColor3 = Accent.Text
	end)

	-- The hit area is taller than the visible track so it is easy to grab on touch.
	local hit = New("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = row,
	})
	local track = New("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		Parent = hit,
	})
	Round(track, Theme.Radius.Pill)
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Round(fill, Theme.Radius.Pill)
	AccentGradient(fill, 0)
	local knob = New("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.Color.TextHi,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		Parent = track,
	})
	Round(knob, Theme.Radius.Pill)
	local knobStroke = Stroke(knob, 0, Accent.Color, 2)
	bindAccent(function(a)
		knobStroke.Color = a
	end)
	local knobScale = New("UIScale", { Parent = knob })

	local fillTween, knobTween

	local function ratioOf(v)
		if maxValue == minValue then
			return 0
		end
		return (v - minValue) / (maxValue - minValue)
	end

	local function render(animate)
		local ratio = ratioOf(value)
		valueLabel.Text = display(value)
		if fillTween then
			fillTween:Cancel()
		end
		if knobTween then
			knobTween:Cancel()
		end
		if animate then
			fillTween = play(fill, Motion.Quick, "Out", { Size = UDim2.fromScale(ratio, 1) })
			knobTween = play(knob, Motion.Quick, "Out", { Position = UDim2.fromScale(ratio, 0.5) })
		else
			fill.Size = UDim2.fromScale(ratio, 1)
			knob.Position = UDim2.fromScale(ratio, 0.5)
		end
	end

	local function commit(newValue, animate, silent)
		newValue = snap(newValue)
		local changed = newValue ~= value
		value = newValue
		render(animate)
		if changed and not silent and options.Callback then
			options.Callback(value)
		end
	end

	local function valueFromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return value
		end
		local ratio = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		return minValue + ratio * (maxValue - minValue)
	end

	-- Drag state. InputChanged / InputEnded listeners exist only while a
	-- drag is in progress, and are always disconnected in stopDrag.
	local dragInput, moveConnection, endConnection, lockedScroll
	local sliderHovered = false

	-- One owner for the knob's scale so the drag bump and the hover lift can
	-- never overwrite each other and leave it stranded mid-size.
	local function applyKnob()
		local size = 1
		if dragInput then
			size = 1.2
		elseif sliderHovered then
			size = 1.12
		end
		play(knobScale, Motion.Swift, "Out", { Scale = size })
	end

	local function stopDrag()
		if moveConnection then
			moveConnection:Disconnect()
			moveConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
		dragInput = nil
		if lockedScroll then
			lockedScroll.ScrollingEnabled = true
			lockedScroll = nil
		end
		applyKnob()
	end

	-- Hover brightens the track and lifts the knob a little, so the control
	-- reads as grabbable before the pointer even reaches it.
	hit.MouseEnter:Connect(function()
		sliderHovered = true
		play(track, Motion.Swift, "Out", { BackgroundTransparency = 0.8 })
		applyKnob()
	end)
	hit.MouseLeave:Connect(function()
		sliderHovered = false
		play(track, Motion.Swift, "Out", { BackgroundTransparency = 0.88 })
		applyKnob()
	end)

	hit.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end
		stopDrag()
		dragInput = input
		-- Stop the page scrolling under the finger while dragging a slider.
		lockedScroll = hit:FindFirstAncestorWhichIsA("ScrollingFrame")
		if lockedScroll then
			lockedScroll.ScrollingEnabled = false
		end
		applyKnob()
		commit(valueFromX(input.Position.X), false)

		moveConnection = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed == dragInput then
				commit(valueFromX(changed.Position.X), false)
			end
		end)
		endConnection = UserInputService.InputEnded:Connect(function(ended)
			local mouseRelease = dragInput
				and dragInput.UserInputType == Enum.UserInputType.MouseButton1
				and ended.UserInputType == Enum.UserInputType.MouseButton1
			if ended == dragInput or mouseRelease then
				stopDrag()
			end
		end)
	end)
	hit.Destroying:Connect(stopDrag)

	hit.MouseEnter:Connect(function()
		if not dragInput then
			play(knobScale, Motion.Swift, "Out", { Scale = 1.12 })
		end
	end)
	hit.MouseLeave:Connect(function()
		if not dragInput then
			play(knobScale, Motion.Swift, "Out", { Scale = 1 })
		end
	end)

	render(false)

	local control = {
		Instance = row,
		Default = defaultValue,
		Get = function()
			return value
		end,
		Set = function(newValue, silent)
			commit(newValue, true, silent)
		end,
		-- Widens or narrows the range after the fact. Used by the Auto Place
		-- slot control, which only learns the game's real limit once the plot
		-- has been inspected. The current value is re-snapped, so lowering the
		-- range can never leave the knob outside the track.
		SetMax = function(newMax, silent)
			if type(newMax) ~= "number" or newMax <= minValue then
				return
			end
			maxValue = newMax
			-- Not silent by default: if the new range clamps the value down,
			-- the callback has to run so the owner's state follows the knob.
			commit(value, true, silent)
		end,
	}
	if options.Reset ~= false then
		table.insert(resettables, control)
	end
	if options.Persist ~= false then
		Config.Register(options.Key or options.Text, control, "slider")
	end
	return control
end

local function InfoRow(parent, title, value, valueColor)
	local row = New("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Text(row, title, Theme.Type.Body, "Medium", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
	})
	local valueLabel = Text(row, value, Theme.Type.Body, "SemiBold", valueColor or Theme.Color.TextHi, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return valueLabel
end

-- Dropdown(parent, { Text, Options = function() -> {names}, Get, Set, Empty })
-- A row with a label and a field showing the current choice. Pressing the
-- field opens its list inline, directly under it, by animating the height (so
-- it can never be clipped by the scrolling page the way a floating menu can).
-- Options is a function so the list is read fresh every time it opens: a
-- config saved a second ago is there. Choosing, pressing the field again, or
-- an empty list all close it. Returns { Close, Refresh, Frame }.
local function Dropdown(parent, options)
	local ROW, ITEM, MAX_SHOWN = 38, 30, 6
	local holder = New("Frame", {
		Name = "Dropdown",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, ROW),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Text(holder, options.Text, Theme.Type.Body, "Medium", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.4, -12, 0, ROW),
	})
	local field = New("TextButton", {
		Name = "Field",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.new(0.6, -12, 0, ROW - 8),
		Parent = holder,
	})
	Round(field, Theme.Radius.SM)
	local fieldStroke = Stroke(field, 0.9)
	local value = Text(field, "", Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -36, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local caret = Icon(field, "chevronDown", 12, Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
	})
	attachFeedback(field, { Rest = 0.92, Hover = 0.86, Press = 0.8 })

	local list = New("Frame", {
		Name = "List",
		BackgroundColor3 = Theme.Color.Cover,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, ROW),
		Size = UDim2.new(0.6, -12, 0, 0),
		ClipsDescendants = true,
		Parent = holder,
	})
	Round(list, Theme.Radius.SM)
	Stroke(list, 0.9)
	local scroll = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Color.TextLow,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = list,
	})
	Padding(scroll, 3, 3, 3, 3)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = scroll })

	local control = { Open = false, Frame = holder }
	local token = 0

	local function paintValue()
		local current = options.Get and options.Get()
		value.Text = current or options.Empty or "None"
		value.TextColor3 = current and Theme.Color.TextHi or Theme.Color.TextLow
	end

	function control.Close()
		if not control.Open then
			return
		end
		control.Open = false
		token = token + 1
		play(caret, Motion.Quick, "Out", { Rotation = 0 })
		play(list, Motion.Quick, "In", { Size = UDim2.new(0.6, -12, 0, 0) })
		play(holder, Motion.Quick, "In", { Size = UDim2.new(1, 0, 0, ROW) })
		play(fieldStroke, Motion.Quick, "Out", { Transparency = 0.9 })
	end

	function control.Refresh()
		paintValue()
	end

	local function open()
		local names = options.Options and options.Options() or {}
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		if #names == 0 then
			notify("Nothing to choose", "Warning", options.EmptyHint or "There are no options yet.")
			return
		end
		local current = options.Get and options.Get()
		for index, name in ipairs(names) do
			local item = New("TextButton", {
				Name = "Option",
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Accent.Color,
				BackgroundTransparency = name == current and 0.82 or 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, ITEM),
				LayoutOrder = index,
				Parent = scroll,
			})
			Round(item, Theme.Radius.XS)
			Text(item, name, Theme.Type.Caption, name == current and "Bold" or "Medium",
				name == current and Theme.Color.TextHi or Theme.Color.TextMid, {
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -20, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
			attachFeedback(item, { Rest = name == current and 0.82 or 1, Hover = 0.9, Press = 0.84 })
			item.Activated:Connect(function()
				control.Close()
				if options.Set then
					options.Set(name)
				end
				paintValue()
			end)
		end
		local shown = math.min(#names, MAX_SHOWN)
		local height = shown * (ITEM + 2) + 6
		control.Open = true
		token = token + 1
		play(caret, Motion.Quick, "Out", { Rotation = 180 })
		play(fieldStroke, Motion.Quick, "Out", { Transparency = 0.4 })
		play(list, Motion.Base, "Out", { Size = UDim2.new(0.6, -12, 0, height) })
		play(holder, Motion.Base, "Out", { Size = UDim2.new(1, 0, 0, ROW + height + 8) })
	end

	field.Activated:Connect(function()
		if control.Open then
			control.Close()
		else
			open()
		end
	end)
	bindAccent(function()
		if control.Open then
			fieldStroke.Color = Accent.Color
		end
	end)
	paintValue()
	return control
end

-- StatCard(parent, { Caption, Value, Ratio }) -> { Set(text, ratio) }
local function StatCard(parent, options)
	local card = New("Frame", {
		Name = "Stat",
		BackgroundColor3 = Theme.Color.Alt,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.new(1 / 3, -8, 1, 0),
		LayoutOrder = nextOrder(parent),
		Parent = parent,
	})
	Round(card, Theme.Radius.MD)
	Stroke(card, 0.92)
	Padding(card, 12, 14, 12, 14)
	Text(card, options.Caption, Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 14),
	})
	local valueLabel = Text(card, options.Value, Theme.Type.Display, "Bold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 30),
	})
	local track = New("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 5),
		Parent = card,
	})
	Round(track, Theme.Radius.Pill)
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(options.Ratio or 0, 0, 1), 1),
		Parent = track,
	})
	Round(fill, Theme.Radius.Pill)
	AccentGradient(fill, 0)
	return {
		Set = function(text, ratio)
			valueLabel.Text = text
			play(fill, Motion.Base, "Soft", { Size = UDim2.fromScale(math.clamp(ratio or 0, 0, 1), 1) })
		end,
	}
end

--------------------------------------------------------------------------
-- MAIN GUI  (screen, layers, panel, sidebar, header, pages host)
--------------------------------------------------------------------------

local connections = {} -- service-level connections, all released in cleanup()
local function track(connection)
	table.insert(connections, connection)
	return connection
end

local isOpen = false
local openToken = 0
local currentPage = nil

-- Assigned later; declared here because earlier callbacks reach them.
local setOpen
local setPage
local applyLayout
local refreshBlur
local logActivity

-- Stats is the one place the two egg-facing pages meet. Home owns the widgets,
-- the egg page owns the data, and Stats.Hub is the handle between them: Home
-- creates it and registers the painter, the egg page fills in the controls.
local Stats = { Hub = nil } -- live stat cards, filled in by the Home page
Features.Source = function()
	return Stats.Hub
end
local Ambient = { Tweens = {} }
local Metrics = { Fps = 60, Ping = 0, Frames = 0, Elapsed = 0, Connection = nil }
local Boost = {} -- FPS Boost logic (filled in by the FPS BOOST section)
local Controls = {} -- settings toggles the boost mirrors into
local Gate = { Loaded = false, Authenticated = false, Tweens = {}, Connection = nil }

-- Assigned here rather than declared: the tooltip helpers above capture
-- `screen` as an upvalue and must see the same instance.
screen = New("ScreenGui", {
	Name = CONFIG.GuiName,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- Background blur. BlurEffect lives in Lighting; created from a LocalScript
-- it is local to this client. If it can't be created the toggle simply has
-- no visual effect and the rest of the GUI is unaffected.
local blurEffect = nil
do
	local ok, effect = pcall(function()
		return New("BlurEffect", {
			Name = CONFIG.BlurName,
			Size = 0,
			Parent = Lighting,
		})
	end)
	if ok then
		blurEffect = effect
	end
end

refreshBlur = function()
	if not blurEffect then
		return
	end
	local goal = (isOpen and State.Blur and not State.FpsBoost) and CONFIG.BlurSize or 0
	play(blurEffect, Motion.Base, "Out", { Size = goal })
end

-- Layer 1: scrim. A deliberately inert dim layer.
-- The panel closes only through the close button, the floating toggle or the
-- hotkey. This is a plain Frame rather than a TextButton precisely so it can
-- never receive Activated, and it is never made Modal, so it cannot steal
-- interactivity from the panel either.
local scrim = New("Frame", {
	Name = "Scrim",
	BackgroundColor3 = Theme.Color.Cover,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 1,
	Parent = screen,
})

-- Layer 2: ambient glow. Concentric translucent discs fake a radial gradient
-- (UIGradient has no radial mode).
local ambientHost = New("Frame", {
	Name = "Ambient",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 2,
	Parent = screen,
})

local ORB_SPECS = {
	{ X = 0.2, Y = 0.2, Diameter = 640, Key = "A" },
	{ X = 0.82, Y = 0.78, Diameter = 560, Key = "B" },
	{ X = 0.5, Y = 1.0, Diameter = 480, Key = "A" },
}
local ORB_LAYERS = 7
local orbs = {}

for index, spec in ipairs(ORB_SPECS) do
	local orb = New("Frame", {
		Name = "Orb" .. index,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(spec.X, spec.Y),
		Size = UDim2.fromOffset(spec.Diameter, spec.Diameter),
		Parent = ambientHost,
	})
	local layers = {}
	for layer = 1, ORB_LAYERS do
		local diameter = 1 - (layer - 1) / ORB_LAYERS
		local disc = New("Frame", {
			Name = "Layer",
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 0.97,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(diameter, diameter),
			Parent = orb,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disc })
		layers[layer] = disc
	end
	orbs[index] = { Frame = orb, Layers = layers, Spec = spec }
end

local function refreshOrbTint()
	local alpha = math.min(0.08, 0.026 * State.AmbientStrength)
	for _, orb in ipairs(orbs) do
		local color = orb.Spec.Key == "A" and Accent.Color or Accent.Color2
		for _, disc in ipairs(orb.Layers) do
			disc.BackgroundColor3 = color
			disc.BackgroundTransparency = 1 - alpha
		end
	end
end
bindAccent(refreshOrbTint)

-- Layer 3: panel holder.
local holder = New("Frame", {
	Name = "Holder",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 3,
	Parent = screen,
})

-- Drift is a handful of looping tweens (no per-frame connection) and only
-- runs while the panel is visible.
-- The border shimmer: one gradient on the window's outline, turned by a single
-- looping tween (no per-frame code). It is part of the same on/off logic as the
-- drift: never while FPS Boost is on, and still (a fixed highlight) rather than
-- moving when animations are reduced. The stroke and gradient are created with
-- the panel, further down; this only runs once they exist.
function Ambient.applyShimmer(panelVisible)
	local stroke, gradient = Ambient.ShimmerStroke, Ambient.ShimmerGradient
	if not stroke or not gradient then
		return
	end
	local wanted = State.Shimmer == true and not State.FpsBoost
	gradient.Enabled = wanted
	stroke.Transparency = wanted and 0.38 or 0.86
	if wanted and panelVisible and not motionReduced() then
		gradient.Rotation = 0
		local tween = TweenService:Create(
			gradient,
			TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false),
			{ Rotation = 360 }
		)
		tween:Play()
		table.insert(Ambient.Tweens, tween)
	else
		gradient.Rotation = 35
	end
end

function Ambient.refresh()
	for _, tween in ipairs(Ambient.Tweens) do
		tween:Cancel()
	end
	table.clear(Ambient.Tweens)

	local visible = State.Ambient and not State.FpsBoost and holder.Visible
	ambientHost.Visible = visible
	Ambient.applyShimmer(holder.Visible)
	if not visible or motionReduced() then
		for _, orb in ipairs(orbs) do
			orb.Frame.Position = UDim2.fromScale(orb.Spec.X, orb.Spec.Y)
		end
		return
	end
	for index, orb in ipairs(orbs) do
		local dx = (index % 2 == 0) and -0.05 or 0.05
		local info = TweenInfo.new(9 + index * 2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		local tween = TweenService:Create(orb.Frame, info, {
			Position = UDim2.fromScale(orb.Spec.X + dx, orb.Spec.Y - 0.04),
		})
		tween:Play()
		table.insert(Ambient.Tweens, tween)
	end
end

local panel = New("Frame", {
	Name = "Panel",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIG.PanelSize.X, CONFIG.PanelSize.Y),
	Parent = holder,
})
local panelScale = New("UIScale", { Scale = 1, Parent = panel })
local panelTween = nil

-- DRAG OFFSET ----------------------------------------------------------
-- The panel is centre-anchored inside the full-screen holder, so position is
-- expressed as a pixel offset from dead centre rather than an absolute
-- UDim2. That keeps the existing open/close animation and the responsive
-- layout working untouched: they keep aiming at the centre, and the offset is
-- layered on top. drag.X / drag.Y are authoritative; a drag in progress
-- smooths its own copy and the release settles it back onto these values.
local drag = { X = 0, Y = 0 }
-- Drag tuning and helpers. Follow is per second (time-based); Glide is the
-- seconds of release velocity the window may coast on.
local Drag = { Velocity = { X = 0, Y = 0 }, Handles = {}, Shadows = {}, Follow = 24, Glide = 0.085, Rest = 1 }

-- Keeps the whole panel inside the viewport, so it can never be dragged off
-- screen where the close button would become unreachable.
local function clampDragOffset(x, y)
	local halfW = panel.AbsoluteSize.X * 0.5
	local halfH = panel.AbsoluteSize.Y * 0.5
	local bound = holder.AbsoluteSize * 0.5
	-- Offsets are scaled by the panel's UIScale, so the allowed range is the
	-- on-screen slack divided by that scale.
	local scale = math.max(panelScale.Scale, 0.1)
	local maxX = math.max(0, (bound.X - halfW - 8) / scale)
	local maxY = math.max(0, (bound.Y - halfH - 8) / scale)
	return math.clamp(x, -maxX, maxX), math.clamp(y, -maxY, maxY)
end

-- Rest position: centre plus however far the panel has been dragged.
local function panelHome()
	return UDim2.new(0.5, drag.X, 0.5, drag.Y)
end

-- Soft drop shadow: UIShadow does not exist, so two dark rounded frames sit behind the panel.
for _, spec in ipairs({ { 44, 0.93, 14 }, { 18, 0.85, 6 } }) do
	local shadow = New("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = spec[2],
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, spec[3]),
		Size = UDim2.new(1, spec[1], 1, spec[1]),
		Parent = panel,
	})
	Round(shadow, Theme.Radius.XL + 10)
	table.insert(Drag.Shadows, { Frame = shadow, Rest = spec[2] })
end

local root = New("Frame", {
	Name = "Root",
	BackgroundColor3 = Theme.Color.Surface,
	BackgroundTransparency = State.PanelTransparency / 100,
	BorderSizePixel = 0,
	Active = true, -- keep clicks on the panel from reaching the world behind it
	Size = UDim2.fromScale(1, 1),
	Parent = panel,
})
Round(root, Theme.Radius.XL)
local rootStroke = Stroke(root, 0.86)
bindAccent(function()
	rootStroke.Color = Theme.Color.White:Lerp(Accent.Color, 0.55)
end)
-- The shimmer: a soft highlight (clear -> accent -> clear) that circles the
-- border. Disabled until Ambient.applyShimmer says otherwise.
Ambient.ShimmerStroke = rootStroke
Ambient.ShimmerGradient = New("UIGradient", {
	Enabled = false,
	Rotation = 35,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.92),
	}),
	Parent = rootStroke,
})
bindAccent(function(a, b)
	Ambient.ShimmerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, a),
	})
end)
Ambient.applyShimmer(false)

local sheen = New("Frame", {
	Name = "Sheen",
	BackgroundColor3 = Theme.Color.White,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(28, 0),
	Size = UDim2.new(1, -56, 0, 1),
	Parent = root,
})
AccentGradient(sheen, 0, NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.15),
	NumberSequenceKeypoint.new(1, 1),
}))

-- Sidebar --------------------------------------------------------------

local sidebar = New("Frame", {
	Name = "Sidebar",
	BackgroundColor3 = Theme.Color.Alt,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(0, CONFIG.SidebarWide, 1, -20),
	Parent = root,
})
Round(sidebar, Theme.Radius.LG)
Stroke(sidebar, 0.92)

Brandmark(sidebar, 34, { Position = UDim2.fromOffset(15, 15) }, true)

local brandText = New("Frame", {
	Name = "BrandText",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(58, 12),
	Size = UDim2.new(1, -64, 0, 40),
	Parent = sidebar,
})
Text(brandText, CONFIG.Title, Theme.Type.Heading, "Bold", Theme.Color.TextHi, {
	Position = UDim2.fromOffset(0, 2),
	Size = UDim2.new(1, 0, 0, 20),
})
Text(brandText, "by " .. CONFIG.Author, Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, 0, 0, 14),
})

New("Frame", {
	Name = "Divider",
	BackgroundColor3 = Theme.Color.White,
	BackgroundTransparency = 0.93,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(14, 64),
	Size = UDim2.new(1, -28, 0, 1),
	Parent = sidebar,
})

-- Header + pages host --------------------------------------------------

local body = New("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10 + CONFIG.SidebarWide + 16, 0),
	Size = UDim2.new(1, -(10 + CONFIG.SidebarWide + 16) - 18, 1, 0),
	Parent = root,
})

local headerTitle = Text(body, "Home", Theme.Type.Display, "Bold", Theme.Color.TextHi, {
	Position = UDim2.fromOffset(0, 14),
	Size = UDim2.new(1, -50, 0, 30),
})
local headerSub = Text(body, "", Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
	Position = UDim2.fromOffset(2, 44),
	Size = UDim2.new(1, -50, 0, 16),
})
IconButton(body, "close", {
	Size = 34,
	IconSize = 15,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 16),
	Tip = "Close panel",
	Callback = function()
		setOpen(false)
	end,
})
New("Frame", {
	Name = "HeaderDivider",
	BackgroundColor3 = Theme.Color.White,
	BackgroundTransparency = 0.93,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 1),
	Parent = body,
})
local pageHost = New("Frame", {
	Name = "Pages",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromOffset(0, 82),
	Size = UDim2.new(1, 0, 1, -94),
	Parent = body,
})

--------------------------------------------------------------------------
-- WINDOW DRAGGING  (header strip + sidebar brand area)
--------------------------------------------------------------------------

-- Drag state. The move / render / release listeners exist only while a drag
-- is in progress and are always torn down in stopDrag, matching how the
-- Slider scopes its own input connections. There is no persistent per-frame
-- connection: RenderStepped is attached on grab and dropped on release.
local dragInput, dragMove, dragEnd, dragStep, dragSettle
local dragTarget = { X = 0, Y = 0 }
local grabbed = false

-- How tightly the window chases the pointer (per second). Time-based, so it
-- feels the same at 30 and 240 fps; higher is snappier.
-- Seconds of release velocity the window is allowed to glide on.

local function stopDrag()
	local wasDragging = dragInput ~= nil
	if dragMove then
		dragMove:Disconnect()
		dragMove = nil
	end
	if dragEnd then
		dragEnd:Disconnect()
		dragEnd = nil
	end
	if dragStep then
		dragStep:Disconnect()
		dragStep = nil
	end
	grabbed = false
	dragInput = nil
	for _, handle in ipairs(Drag.Handles) do
		if handle.Parent then
			play(handle, Motion.Quick, "Out", { BackgroundTransparency = 1 })
		end
	end
	if not wasDragging then
		return
	end

	-- Release: adopt the target plus a short glide along the release
	-- velocity, then ease the panel onto it so it settles instead of
	-- stopping dead. A later setOpen tween on the same property supersedes
	-- this one automatically.
	local x, y = dragTarget.X, dragTarget.Y
	if not motionReduced() then
		x = x + Drag.Velocity.X * Drag.Glide
		y = y + Drag.Velocity.Y * Drag.Glide
	end
	Drag.Velocity.X, Drag.Velocity.Y = 0, 0
	drag.X, drag.Y = clampDragOffset(x, y)
	if dragSettle then
		dragSettle:Cancel()
	end
	dragSettle = play(panel, Motion.Base, "Out", { Position = panelHome() })
	if isOpen then
		-- Put the panel back down: full size and resting shadow depth.
		panelTween = play(panelScale, Motion.Quick, "Out", { Scale = Drag.Rest })
		for _, shadow in ipairs(Drag.Shadows) do
			play(shadow.Frame, Motion.Base, "Out", { BackgroundTransparency = shadow.Rest })
		end
	end
end

local function beginDrag(input)
	-- Only while the panel is actually on screen; dragging it mid open/close
	-- would fight the reveal tween.
	if not isOpen or not holder.Visible then
		return
	end
	stopDrag()
	if dragSettle then
		dragSettle:Cancel()
		dragSettle = nil
	end
	grabbed = true
	dragInput = input
	dragTarget.X, dragTarget.Y = drag.X, drag.Y
	Drag.Velocity.X, Drag.Velocity.Y = 0, 0

	local origin = input.Position
	local startX, startY = drag.X, drag.Y
	-- Offsets live in the panel's scaled space, so pointer pixels are divided
	-- by the scale that was active when the grab began.
	local scaleNow = math.max(panelScale.Scale, 0.1)
	Drag.Rest = scaleNow
	local lastX, lastY, lastTime = drag.X, drag.Y, os.clock()

	-- Lift: a hair smaller with a deeper shadow while held.
	if not motionReduced() then
		panelTween = play(panelScale, Motion.Quick, "Out", { Scale = scaleNow * 0.988 })
		for _, shadow in ipairs(Drag.Shadows) do
			play(shadow.Frame, Motion.Quick, "Out", { BackgroundTransparency = math.max(shadow.Rest - 0.06, 0.5) })
		end
	end

	dragMove = UserInputService.InputChanged:Connect(function(changed)
		if changed == dragInput or changed.UserInputType == Enum.UserInputType.MouseMovement then
			local dx = (changed.Position.X - origin.X) / scaleNow
			local dy = (changed.Position.Y - origin.Y) / scaleNow
			dragTarget.X, dragTarget.Y = clampDragOffset(startX + dx, startY + dy)

			-- Smoothed pointer velocity, used for the release glide.
			local now = os.clock()
			local dt = now - lastTime
			if dt > 0.001 then
				local blend = 0.4
				Drag.Velocity.X = Drag.Velocity.X * (1 - blend) + ((dragTarget.X - lastX) / dt) * blend
				Drag.Velocity.Y = Drag.Velocity.Y * (1 - blend) + ((dragTarget.Y - lastY) / dt) * blend
				lastX, lastY, lastTime = dragTarget.X, dragTarget.Y, now
			end
			if motionReduced() then
				-- Under reduced motion the panel tracks the pointer directly.
				drag.X, drag.Y = dragTarget.X, dragTarget.Y
				panel.Position = panelHome()
			end
		end
	end)

	if not motionReduced() then
		dragStep = RunService.RenderStepped:Connect(function(dt)
			-- A drag left running while the panel closes or the reveal starts
			-- would keep writing Position every frame and fight that tween.
			if not isOpen or not holder.Visible then
				return
			end
			-- Exponential smoothing: the panel trails the cursor slightly
			-- without feeling disconnected, whatever the frame rate.
			local alpha = 1 - math.exp(-Drag.Follow * dt)
			drag.X = drag.X + (dragTarget.X - drag.X) * alpha
			drag.Y = drag.Y + (dragTarget.Y - drag.Y) * alpha
			panel.Position = panelHome()
		end)
	end

	dragEnd = UserInputService.InputEnded:Connect(function(ended)
		local mouseRelease = dragInput
			and dragInput.UserInputType == Enum.UserInputType.MouseButton1
			and ended.UserInputType == Enum.UserInputType.MouseButton1
		if ended == dragInput or mouseRelease then
			stopDrag()
		end
	end)
end
-- The handles are transparent buttons sitting over the otherwise inert top
-- strips: the header (stopping short of the close button) and the sidebar
-- brand block. Because they cover only empty space, dragging cannot steal
-- clicks from the nav, close button, sliders, dropdowns or page content.
-- They are parented to the panel, so the screen's own Destroying cleanup
-- takes them with it.
local function dragHandle(parent, size, position, cornerRadius)
	local handle = New("TextButton", {
		Name = "DragHandle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Parent = parent,
	})
	if cornerRadius then
		Round(handle, cornerRadius)
	end
	handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	-- Lua cannot request a grab cursor, so the strip brightens faintly to
	-- advertise that the window can be moved.
	table.insert(Drag.Handles, handle)
	handle.MouseEnter:Connect(function()
		play(handle, Motion.Quick, "Out", { BackgroundTransparency = 0.94 })
	end)
	handle.MouseLeave:Connect(function()
		if not grabbed then
			play(handle, Motion.Quick, "Out", { BackgroundTransparency = 1 })
		end
	end)
	return handle
end

dragHandle(body, UDim2.new(1, -54, 0, 72), UDim2.fromOffset(0, 0), Theme.Radius.LG)
dragHandle(sidebar, UDim2.new(1, -8, 0, 60), UDim2.fromOffset(4, 2), Theme.Radius.MD)

--------------------------------------------------------------------------
-- NAVIGATION  (sidebar tabs, sliding indicator, page switching)
--------------------------------------------------------------------------

local NAV_ROW_HEIGHT = 44
local NAV_ROW_GAP = 4

-- Ordered by how often each page is used: the egg features people live in come
-- first, appearance next, and utilities/settings/credits last. Every tab has its
-- own icon so the sidebar never repeats a glyph.
local NAV_ITEMS = {
	{ Name = "Home", Caption = "Overview and live stats", Icon = "home" },
	{ Name = "Eggs", Caption = "Scanner, list and teleports", Icon = "egg" },
	{ Name = "Automation", Caption = "Auto farm and auto place", Icon = "bolt" },
	{ Name = "Visuals", Caption = "Theme and appearance", Icon = "palette" },
	{ Name = "Configs", Caption = "Save and load setups", Icon = "folder" },
	{ Name = "Settings", Caption = "Tune the interface", Icon = "sliders" },
	{ Name = "About", Caption = "Credits and details", Icon = "info" },
}

local pages = {}
local navButtons = {}
local switchToken = 0

local nav = New("Frame", {
	Name = "Nav",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 78),
	Size = UDim2.new(1, 0, 0, #NAV_ITEMS * (NAV_ROW_HEIGHT + NAV_ROW_GAP)),
	Parent = sidebar,
})

-- The indicator is created first so the rows (created after) draw above it.
local indicator = New("Frame", {
	Name = "Indicator",
	BackgroundColor3 = Theme.Color.White,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.new(1, -16, 0, NAV_ROW_HEIGHT),
	Parent = nav,
})
Round(indicator, Theme.Radius.SM)
AccentGradient(indicator, 0, NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.72),
	NumberSequenceKeypoint.new(1, 0.9),
}))
local indicatorStroke = Stroke(indicator, 0.7, Accent.Color)
local indicatorBar = New("Frame", {
	Name = "Bar",
	BackgroundColor3 = Accent.Color,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(3, 22),
	Parent = indicator,
})
Round(indicatorBar, Theme.Radius.Pill)
-- Squeezed while the indicator travels, so a jump between distant pages reads
-- as one continuous movement rather than a teleport.
local indicatorBarScale = New("UIScale", { Parent = indicatorBar })
bindAccent(function(a)
	indicatorStroke.Color = a
	indicatorBar.BackgroundColor3 = a
end)

-- Pinned tabs float to the top of the sidebar (a Fluent-style favourites
-- idea, done with Lumen's own rows). Order is derived, never stored: the pinned
-- names in the order they were pinned, then everything else in its normal order.
Stats.Nav = { Pinned = {}, Order = {}, Compact = false }
local function navSlot(name)
	for slot, entry in ipairs(Stats.Nav.Order) do
		if entry == name then
			return slot
		end
	end
	return 1
end
local function rebuildNavOrder()
	local nav = Stats.Nav
	table.clear(nav.Order)
	local seen = {}
	for _, name in ipairs(nav.Pinned) do
		if not seen[name] then
			seen[name] = true
			table.insert(nav.Order, name)
		end
	end
	for _, item in ipairs(NAV_ITEMS) do
		if not seen[item.Name] then
			table.insert(nav.Order, item.Name)
		end
	end
end
rebuildNavOrder()
local function navY(name)
	return (navSlot(name) - 1) * (NAV_ROW_HEIGHT + NAV_ROW_GAP)
end

for index, item in ipairs(NAV_ITEMS) do
	local row = New("TextButton", {
		Name = "Tab_" .. item.Name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(8, navY(item.Name)),
		Size = UDim2.new(1, -16, 0, NAV_ROW_HEIGHT),
		Parent = nav,
	})
	Round(row, Theme.Radius.SM)
	local glyph = Icon(row, item.Icon, 19, Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
	})
	local label = Text(row, item.Name, Theme.Type.Body, "SemiBold", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -76, 1, 0),
	})
	attachFeedback(row, { Rest = 1, Hover = 0.95, Press = 0.9, HoverScale = 1.015, PressScale = 0.99 })

	-- The pin button: a small ribbon at the row's right edge. Shown while the
	-- row is hovered, always on touch (there is no hover), and always when the
	-- tab is pinned. It is a sibling button on top of the row, so pressing it
	-- pins without also switching page.
	local pin = New("TextButton", {
		Name = "Pin",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Visible = false,
		ZIndex = row.ZIndex + 2,
		Parent = row,
	})
	Round(pin, Theme.Radius.XS)
	local pinIcon = Icon(pin, "bookmark", 14, Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	local pinHot = false
	local rowHot = false
	local function isPinned()
		return table.find(Stats.Nav.Pinned, item.Name) ~= nil
	end
	local pinGlyph = "bookmark"
	local function paintPin()
		local pinned = isPinned()
		-- No hover on touch devices, so the button is simply always there.
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		pin.Visible = not Stats.Nav.Compact and (pinned or rowHot or pinHot or touch)
		local wantGlyph = pinned and "bookmarkCheck" or "bookmark"
		local tint = pinned and Accent.Text or (pinHot and Theme.Color.TextHi or Theme.Color.TextLow)
		if wantGlyph ~= pinGlyph then
			-- The shape itself changes (ribbon with a tick), not only the colour.
			pinGlyph = wantGlyph
			pinIcon:Destroy()
			pinIcon = Icon(pin, wantGlyph, 14, tint, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
		else
			iconTint(pinIcon, tint)
		end
		pin.BackgroundTransparency = pinHot and 0.9 or 1
	end
	row.MouseEnter:Connect(function()
		rowHot = true
		paintPin()
	end)
	row.MouseLeave:Connect(function()
		rowHot = false
		paintPin()
	end)
	pin.MouseEnter:Connect(function()
		pinHot = true
		paintPin()
	end)
	pin.MouseLeave:Connect(function()
		pinHot = false
		paintPin()
	end)
	pin.Activated:Connect(function()
		Stats.Nav.Toggle(item.Name)
	end)
	Tip(pin, "Pin to top")
	bindAccent(paintPin)
	-- Essential once the sidebar collapses to icons on narrow panels.
	Tip(row, item.Caption)
	row.Activated:Connect(function()
		setPage(item.Name)
	end)
	navButtons[index] = { Name = item.Name, Row = row, Icon = glyph, Label = label, PaintPin = paintPin }
end

-- Footer chip: avatar initial + display name.
local userChip = New("Frame", {
	Name = "User",
	BackgroundColor3 = Theme.Color.White,
	BackgroundTransparency = 0.94,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 8, 1, -10),
	Size = UDim2.new(1, -16, 0, 44),
	Parent = sidebar,
})
Round(userChip, Theme.Radius.SM)
local userAvatar = New("Frame", {
	Name = "Avatar",
	BackgroundColor3 = Theme.Color.White,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(28, 28),
	Parent = userChip,
})
Round(userAvatar, Theme.Radius.Pill)
AccentGradient(userAvatar, 45)
Text(userAvatar, string.upper(string.sub(player.DisplayName, 1, 1)), Theme.Type.Body, "Bold", Theme.Color.White, {
	Size = UDim2.fromScale(1, 1),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local userLabel = Text(userChip, player.DisplayName, Theme.Type.Caption, "SemiBold", Theme.Color.TextMid, {
	Position = UDim2.fromOffset(46, 0),
	Size = UDim2.new(1, -54, 1, 0),
})

local function paintNav()
	for _, item in ipairs(navButtons) do
		local active = item.Name == currentPage
		iconTint(item.Icon, active and shade(Accent.Color, 0.35) or Theme.Color.TextMid)
		play(item.Label, Motion.Quick, "Out", {
			TextColor3 = active and Theme.Color.TextHi or Theme.Color.TextMid,
		})
	end
end
bindAccent(paintNav)

local function moveIndicator(animate)
	if not table.find(Stats.Nav.Order, currentPage) then
		return
	end
	local goal = UDim2.fromOffset(8, navY(currentPage))
	if animate then
		play(indicator, Motion.Base, "Back", { Position = goal })
		indicatorBarScale.Scale = 0.35
		play(indicatorBarScale, Motion.Base, "Back", { Scale = 1 })
	else
		indicator.Position = goal
	end
end

-- Moves every row to its slot (the pinned ones to the top) and the indicator
-- with the current page's row, so the highlight never drifts off its tab.
local function layoutNav(animate)
	for _, item in ipairs(navButtons) do
		local goal = UDim2.fromOffset(8, navY(item.Name))
		if animate then
			play(item.Row, Motion.Base, "Out", { Position = goal })
		else
			item.Row.Position = goal
		end
		item.PaintPin()
	end
	moveIndicator(animate)
end

-- Public: pin / unpin, and the saved list (kept in configs).
function Stats.Nav.Toggle(name)
	local nav = Stats.Nav
	local at = table.find(nav.Pinned, name)
	if at then
		table.remove(nav.Pinned, at)
	else
		table.insert(nav.Pinned, 1, name)
	end
	rebuildNavOrder()
	layoutNav(true)
end
function Stats.Nav.Set(list)
	local nav = Stats.Nav
	table.clear(nav.Pinned)
	if type(list) == "table" then
		for _, name in ipairs(list) do
			local known = false
			for _, item in ipairs(NAV_ITEMS) do
				known = known or item.Name == name
			end
			if known and not table.find(nav.Pinned, name) then
				table.insert(nav.Pinned, name)
			end
		end
	end
	rebuildNavOrder()
	layoutNav(isOpen)
end
function Stats.Nav.Collect()
	return table.clone(Stats.Nav.Pinned)
end
layoutNav(false)

-- Pages are built once and shown/hidden; switching never creates new ones.
local function CreatePage(name)
	local group = New("CanvasGroup", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pageHost,
	})
	local scroll = New("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Color.White,
		ScrollBarImageTransparency = 0.8,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = group,
	})
	local column = New("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = column,
	})
	Padding(column, 2, 0, 16, 0)
	pages[name] = { Name = name, Group = group, Scroll = scroll, Column = column, Fade = nil }
	return column
end

setPage = function(name, instant)
	local page = pages[name]
	if not page or name == currentPage then
		return
	end
	switchToken = switchToken + 1
	local previous = pages[currentPage]
	currentPage = name

	for _, item in ipairs(NAV_ITEMS) do
		if item.Name == name then
			headerTitle.Text = item.Name
			headerSub.Text = item.Caption
		end
	end
	paintNav()
	moveIndicator(not instant)

	if previous then
		if previous.Fade then
			previous.Fade:Cancel()
		end
		local fade = play(previous.Group, Motion.Quick, "In", { GroupTransparency = 1 })
		previous.Fade = fade
		if fade then
			fade.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and currentPage ~= previous.Name then
					previous.Group.Visible = false
				end
			end)
		end
	end

	if page.Fade then
		page.Fade:Cancel()
	end
	page.Group.Visible = true
	if instant then
		page.Group.GroupTransparency = 0
		page.Scroll.Position = UDim2.new()
	else
		page.Group.GroupTransparency = 1
		page.Scroll.Position = UDim2.fromOffset(0, 10)
		page.Fade = play(page.Group, Motion.Reveal, "Out", { GroupTransparency = 0 }, 0.05)
		play(page.Scroll, Motion.Reveal, "Out", { Position = UDim2.new() }, 0.05)
	end
end

--------------------------------------------------------------------------
-- NOTIFICATION SYSTEM
--------------------------------------------------------------------------

-- How long a toast stays up. The dismiss delay and the progress bar both read
-- this, so the bar always reflects the real time left rather than a scaled one.
local TOAST_SECONDS = 3.6

local toastHost = New("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	-- Top centre, just under the Roblox top bar and the FPS pill.
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 58),
	Size = UDim2.new(0.92, 0, 1, -82),
	ZIndex = 10,
	Parent = screen,
})
New("UISizeConstraint", { MaxSize = Vector2.new(360, math.huge), Parent = toastHost })
New("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, 8),
	Parent = toastHost,
})

local activeToasts = {}

local function dismissToast(entry)
	if entry.Dismissed then
		return
	end
	entry.Dismissed = true
	if entry.Rail then
		-- Stop the countdown so a toast pushed out by the stack cap does not
		-- keep animating against a visible label.
		entry.Rail:Cancel()
		entry.Rail = nil
	end
	local index = table.find(activeToasts, entry)
	if index then
		table.remove(activeToasts, index)
	end
	play(entry.Group, Motion.Quick, "In", { GroupTransparency = 1 })
	task.delay(scaledTime(Motion.Quick) + 0.05, function()
		if entry.Group.Parent then
			entry.Group:Destroy()
		end
	end)
end

-- notify(title, tone, message, force)   tone: Success | Info | Warning | Error
-- `force` shows the toast even when notifications are switched off.
notify = function(title, tone, message, force)
	if Config.Loading then
		return
	end
	if not State.Notifications and not force then
		return
	end
	local spec = TONES[tone] or TONES.Info

	local group = New("CanvasGroup", {
		Name = "Toast",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		-- Negative, so the newest toast sits on top of the stack.
		LayoutOrder = -nextOrder(toastHost),
		Parent = toastHost,
	})
	local card = New("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = group,
	})
	Round(card, Theme.Radius.MD)
	Stroke(card, 0.6, spec.Color)
	Padding(card, 10, 12, 10, 12)
	-- A real vertical layout instead of absolute positions. Previously the card had
	-- no layout at all, so AutomaticSize measured only the text column and the
	-- bottom padding never counted - which put the countdown rail straight through
	-- the last line of the message. Laying content and rail out in flow also means
	-- the card now grows correctly for 1-line, 2-line and 3-line messages.
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 9),
		Parent = card,
	})
	local cardScale = New("UIScale", { Scale = 1, Parent = card })

	-- Row one: badge beside the wrapped text. Deliberately no UIListLayout here -
	-- a horizontal one would stretch both children to the row height, and the row
	-- height is what AutomaticSize is trying to resolve, which deadlocks.
	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(card),
		Parent = card,
	})

	local badge = New("Frame", {
		Name = "Badge",
		BackgroundColor3 = spec.Color,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 30),
		Parent = content,
	})
	Round(badge, Theme.Radius.SM)
	Icon(badge, spec.Icon, 16, spec.Color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})

	local column = New("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -42, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = content,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = column,
	})
	Text(column, title, Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
		Wrap = true,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = nextOrder(column),
	})
	if message and message ~= "" then
		Text(column, message, Theme.Type.Caption, "Regular", Theme.Color.TextMid, {
			Wrap = true,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = nextOrder(column),
		})
	end

	-- Row two: the countdown rail, in flow under the content so it can never sit
	-- on top of the text no matter how many lines the message wraps to. Clipped
	-- inside its own rounded host so the shrinking fill never escapes the track.
	local railHost = New("Frame", {
		Name = "RailHost",
		BackgroundColor3 = spec.Color,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		LayoutOrder = nextOrder(card),
		ClipsDescendants = true,
		Parent = card,
	})
	Round(railHost, Theme.Radius.Pill)
	local railFill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = spec.Color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = railHost,
	})
	Round(railFill, Theme.Radius.Pill)

	local entry = { Group = group, Dismissed = false, Rail = nil }
	table.insert(activeToasts, entry)

	-- Entrance: fade plus a small scale-up, so toasts arrive rather than blink.
	cardScale.Scale = 0.96
	play(group, Motion.Reveal, "Out", { GroupTransparency = 0 })
	play(cardScale, Motion.Reveal, "Back", { Scale = 1 })

	-- Countdown. Deliberately a plain TweenService tween rather than play(),
	-- because play() scales with the animation-speed slider and the bar would
	-- then disagree with the fixed dismiss delay below.
	local countdown = TweenService:Create(
		railFill,
		TweenInfo.new(TOAST_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(0, 1) }
	)
	countdown:Play()
	entry.Rail = countdown

	-- Cap the stack: the oldest toast leaves when a fourth arrives.
	while #activeToasts > CONFIG.MaxToasts do
		dismissToast(activeToasts[1])
	end
	task.delay(TOAST_SECONDS, function()
		dismissToast(entry)
	end)
end

--------------------------------------------------------------------------
-- HUD OVERLAYS  (FPS pill and crosshair; GUI-only demos)
--------------------------------------------------------------------------

local hud = New("Frame", {
	Name = "Hud",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 6,
	Parent = screen,
})

local fpsPill = New("Frame", {
	Name = "FpsOverlay",
	BackgroundColor3 = Theme.Color.Surface,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	Visible = false,
	Parent = hud,
})
Round(fpsPill, Theme.Radius.Pill)
Stroke(fpsPill, 0.85)
Padding(fpsPill, 6, 14, 6, 14)
local fpsPillLabel = Text(fpsPill, "-- FPS", Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
	Size = UDim2.new(0, 0, 0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
	TextTruncate = Enum.TextTruncate.None,
})

local crosshair = New("Frame", {
	Name = "Crosshair",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(72, 72),
	Visible = false,
	Parent = hud,
})
local crosshairParts = {}
for _, name in ipairs({ "Top", "Bottom", "Left", "Right", "Dot" }) do
	local part = New("Frame", {
		Name = name,
		BackgroundColor3 = Accent.Color,
		BorderSizePixel = 0,
		Parent = crosshair,
	})
	crosshairParts[name] = part
end
Round(crosshairParts.Dot, Theme.Radius.Pill)

local function layoutCrosshair()
	local length, gap, thickness = State.CrosshairSize, 4, 2
	local center = UDim2.fromScale(0.5, 0.5)
	crosshairParts.Top.AnchorPoint = Vector2.new(0.5, 1)
	crosshairParts.Top.Position = UDim2.new(0.5, 0, 0.5, -gap)
	crosshairParts.Top.Size = UDim2.fromOffset(thickness, length)
	crosshairParts.Bottom.AnchorPoint = Vector2.new(0.5, 0)
	crosshairParts.Bottom.Position = UDim2.new(0.5, 0, 0.5, gap)
	crosshairParts.Bottom.Size = UDim2.fromOffset(thickness, length)
	crosshairParts.Left.AnchorPoint = Vector2.new(1, 0.5)
	crosshairParts.Left.Position = UDim2.new(0.5, -gap, 0.5, 0)
	crosshairParts.Left.Size = UDim2.fromOffset(length, thickness)
	crosshairParts.Right.AnchorPoint = Vector2.new(0, 0.5)
	crosshairParts.Right.Position = UDim2.new(0.5, gap, 0.5, 0)
	crosshairParts.Right.Size = UDim2.fromOffset(length, thickness)
	crosshairParts.Dot.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshairParts.Dot.Position = center
	crosshairParts.Dot.Size = UDim2.fromOffset(4, 4)
end
layoutCrosshair()
bindAccent(function(a)
	for _, part in pairs(crosshairParts) do
		part.BackgroundColor3 = a
	end
end)

--------------------------------------------------------------------------
-- QUICK ACTIONS OVERLAY  (floating live status for the Quick actions)
--
-- Everything shown is read from Features: the ON/OFF rows are the same records
-- the Home buttons and the settings toggles are built from, and the farm
-- details come from the snapshot the egg page publishes. The overlay keeps no
-- copy of any feature's state, so it cannot disagree with them. It lives in
-- the HUD layer, so it stays up while the main window is closed, and it only
-- appears once the access gate has been passed.
--------------------------------------------------------------------------
do
	local O = QuickOverlay
	local WIDTH, MARGIN = 232, 6
	local token = 0
	O.Shown = false
	O.Pos = nil -- { X, Y } in pixels, top-left; remembered for this session

	local holder = New("Frame", {
		Name = "QuickOverlay",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 96),
		Size = UDim2.fromOffset(WIDTH, 96),
		Visible = false,
		ZIndex = 7,
		Parent = hud,
	})

	-- Depth: two soft dark frames behind the card (UIShadow does not exist).
	local shadows = {}
	for _, spec in ipairs({ { 22, 0.93, 7 }, { 8, 0.86, 3 } }) do
		local shadow = New("Frame", {
			Name = "Shadow",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, spec[3]),
			Size = UDim2.new(1, spec[1], 1, spec[1]),
			ZIndex = 7,
			Parent = holder,
		})
		Round(shadow, Theme.Radius.MD + 6)
		table.insert(shadows, { Frame = shadow, Rest = spec[2] })
	end

	-- A CanvasGroup, so the whole card fades as one and its corners clip.
	local card = New("CanvasGroup", {
		Name = "Card",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 8,
		Parent = holder,
	})
	Round(card, Theme.Radius.MD)
	local cardStroke = Stroke(card, 0.84)
	bindAccent(function()
		cardStroke.Color = Theme.Color.White:Lerp(Accent.Color, 0.5)
	end)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	-- Header: title, the drag handle and the close button. The handle stops
	-- short of the button, so dragging can never swallow a click on it.
	local header = New("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Parent = card,
	})
	local titleDot = New("Frame", {
		Name = "Dot",
		BackgroundColor3 = Accent.Color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		Parent = header,
	})
	Round(titleDot, Theme.Radius.Pill)
	bindAccent(function(a)
		titleDot.BackgroundColor3 = a
	end)
	local titleLabel = Text(header, "QUICK ACTIONS", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
		Position = UDim2.fromOffset(25, 0),
		Size = UDim2.new(1, -60, 1, 0),
	})
	local handle = New("TextButton", {
		Name = "DragHandle",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -34, 1, 0),
		ZIndex = 9,
		Parent = header,
	})
	local closeButton = New("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 9,
		Parent = header,
	})
	Round(closeButton, Theme.Radius.XS)
	Icon(closeButton, "close", 11, Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 10,
	})
	attachFeedback(closeButton, { Rest = 1, Hover = 0.9, Press = 0.84 })
	closeButton.Activated:Connect(function()
		-- In AFK mode the dashboard is the only way out of the black screen, so
		-- its close button leaves AFK instead of hiding the dashboard.
		if State.Afk then
			Features.Set("afk", false)
		else
			Features.Set("overlay", false)
		end
	end)

	New("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = card,
	})

	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = card,
	})
	Padding(body, 8, 12, 10, 12)
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = body,
	})

	-- The body is built inside its own function: it has a lot of widgets, and
	-- locals declared in it would otherwise count against the main chunk's limit
	-- of 200. Only O.Render / O.RenderTimes / O.Expanded escape.
	function O.Build()
	-- One ON/OFF row per Quick Action that exists (and wants a row), in the
	-- order Home lists them. Each feature's own details sit directly under its
	-- row: LayoutOrder is index * 10 for the row, + 1 for what hangs off it.
	local rows = {}
	local quickIndex = {}
	for index, def in ipairs(Features.Quick()) do
		if def.Overlay ~= false then
			quickIndex[def.Key] = index
			local row = New("Frame", {
				Name = "Row_" .. def.Key,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = index * 10,
				Parent = body,
			})
			Text(row, def.Text, Theme.Type.Caption, "Medium", Theme.Color.TextMid, {
				Size = UDim2.new(1, -56, 1, 0),
			})
			local mark = New("Frame", {
				Name = "Mark",
				BackgroundColor3 = Accent.Color,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -34, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				Parent = row,
			})
			Round(mark, Theme.Radius.Pill)
			local markStroke = Stroke(mark, 0, Theme.Color.TextLow, 1)
			local stateLabel = Text(row, "OFF", Theme.Type.Micro, "Bold", Theme.Color.TextLow, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(28, 16),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			rows[def.Key] = { Frame = row, Mark = mark, Stroke = markStroke, State = stateLabel, Def = def }
		end
	end

	-- A caption / value pair on one line.
	local function detailRow(parent, caption, order, captionWidth)
		captionWidth = captionWidth or 50
		local row = New("Frame", {
			Name = "Detail_" .. caption,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = order,
			Parent = parent,
		})
		Text(row, caption, Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
			Size = UDim2.new(0, captionWidth, 1, 0),
		})
		local value = Text(row, "", Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
			Position = UDim2.fromOffset(captionWidth + 2, 0),
			Size = UDim2.new(1, -(captionWidth + 2), 1, 0),
		})
		return row, value
	end

	local function indented(order, name)
		local frame = New("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Visible = false,
			Parent = body,
		})
		Padding(frame, 0, 0, 0, 12)
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
			Parent = frame,
		})
		return frame
	end

	-- Auto farm: Target, then Status, straight under its row.
	local details, targetValue, statusValue
	if rows.farm then
		details = indented(quickIndex.farm * 10 + 1, "FarmDetails")
		local _, target = detailRow(details, "Target:", 1)
		local _, status = detailRow(details, "Status:", 2)
		targetValue, statusValue = target, status
	end
	-- Auto place: how full the plot is.
	local slotsRow, slotsValue
	if rows.place then
		local holder = indented(quickIndex.place * 10 + 1, "PlaceDetails")
		slotsRow = holder
		local _, value = detailRow(holder, "Slots:", 1)
		slotsValue = value
	end
	-- Auto server hop: only exists while it is on.
	local hopDetails, hopValue
	if rows.hop then
		hopDetails = indented(quickIndex.hop * 10 + 1, "HopDetails")
		local _, value = detailRow(hopDetails, "Next hop:", 1, 58)
		hopValue = value
	end

	-- STATS ---------------------------------------------------------------
	local function rule(parent, order)
		return New("Frame", {
			Name = "Rule",
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = order,
			Parent = parent,
		})
	end

	local statsBlock = New("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 900,
		Visible = false,
		Parent = body,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = statsBlock,
	})
	rule(statsBlock, 0)
	local _, farmedValue = detailRow(statsBlock, "Eggs Farmed:", 1, 84)
	local _, placedValue = detailRow(statsBlock, "Eggs Placed:", 2, 84)
	Text(statsBlock, "Best Egg Farmed:", Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 3,
	})
	local bestValue = Text(statsBlock, "None yet", Theme.Type.Caption, "SemiBold", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 4,
	})

	-- SEE MORE -> RECENT EGGS --------------------------------------------
	local moreButton = New("TextButton", {
		Name = "SeeMore",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 940,
		Visible = false,
		Parent = body,
	})
	Round(moreButton, Theme.Radius.XS)
	local moreLabel = Text(moreButton, "See More...", Theme.Type.Caption, "SemiBold", Accent.Text, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	attachFeedback(moreButton, { Rest = 1, Hover = 0.92, Press = 0.86 })

	local RECENT_ROWS = 10
	local recentPanel = New("Frame", {
		Name = "Recent",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 950,
		Visible = false,
		Parent = body,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = recentPanel,
	})
	rule(recentPanel, 0)
	Text(recentPanel, "RECENT EGGS", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
	})
	local recentEmpty = Text(recentPanel, "No eggs farmed yet", Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
	})
	local recentRows = {}
	for index = 1, RECENT_ROWS do
		local entry = New("Frame", {
			Name = "Recent_" .. index,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = 2 + index,
			Visible = false,
			Parent = recentPanel,
		})
		local name = Text(entry, "", Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
			Size = UDim2.new(1, 0, 0, 16),
		})
		local age = Text(entry, "", Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 14),
		})
		recentRows[index] = { Frame = entry, Name = name, Age = age }
	end
	rule(recentPanel, 100)
	local _, detectedValue = detailRow(recentPanel, "Eggs Detected:", 101, 92)

	-- EXIT AFK ------------------------------------------------------------
	local exitButton = New("TextButton", {
		Name = "ExitAfk",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Accent.Color,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 960,
		Visible = false,
		Parent = body,
	})
	Round(exitButton, Theme.Radius.SM)
	local exitLabel = Text(exitButton, "Exit AFK Mode", Theme.Type.Caption, "Bold", Accent.On, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	attachFeedback(exitButton, { Rest = 0.15, Hover = 0.05, Press = 0 })
	exitButton.Activated:Connect(function()
		Features.Set("afk", false)
	end)
	bindAccent(function()
		exitButton.BackgroundColor3 = Accent.Color
		exitLabel.TextColor3 = Accent.On
		moreLabel.TextColor3 = Accent.Text
	end)

	O.Expanded = false -- runtime only
	moreButton.Activated:Connect(function()
		O.Expanded = not O.Expanded
		O.Render()
	end)

	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds + 0.5))
		return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	end

	local function ago(seconds)
		if seconds < 3 then
			return "Just now"
		elseif seconds < 60 then
			return string.format("%d sec ago", math.floor(seconds))
		elseif seconds < 3600 then
			return string.format("%d min ago", math.floor(seconds / 60))
		end
		return string.format("%d hr ago", math.floor(seconds / 3600))
	end

	-- What the farm is doing, in words. The step comes from the farm itself;
	-- "Waiting" is only refined by the farm's own message (no character yet,
	-- no rarity picked, or simply no matching egg out).
	local function statusText(farm)
		local step = farm.Step or "Searching"
		if step == "Waiting" then
			local message = farm.Message or ""
			if message:find("character") then
				return "Waiting for Character"
			elseif message:find("rarities") then
				return "Pick a Rarity"
			end
			return "Waiting for Eggs"
		end
		return step
	end

	local DISTANCE_STEPS = { Moving = true, Retrying = true, ["Picking Up"] = true }
	local CALM_STEPS = { Waiting = true, Searching = true, Returning = true }

	-- The parts that change with time rather than with an event: the recent
	-- eggs' ages and the hop countdown. Cheap, and only run while shown.
	function O.RenderTimes()
		if hopValue and hopDetails and hopDetails.Visible then
			local hop = Features.Hop
			if hop.Busy then
				hopValue.Text = "Hopping..."
				hopValue.TextColor3 = Theme.Color.Caution
			elseif hop.NextAt then
				hopValue.Text = clock(hop.NextAt - os.clock())
				hopValue.TextColor3 = Theme.Color.TextHi
			else
				hopValue.Text = "--:--"
				hopValue.TextColor3 = Theme.Color.TextLow
			end
		end
		if recentPanel.Visible then
			local now = os.clock()
			for index, entry in ipairs(Features.Snapshot.Recent) do
				local row = recentRows[index]
				if row then
					row.Age.Text = ago(now - entry.At)
				end
			end
		end
	end

	-- Paints every row from the shared state. Cheap, and safe to call any time.
	function O.Render()
		local afk = State.Afk == true
		titleLabel.Text = afk and "AFK MODE" or "QUICK ACTIONS"
		titleLabel.TextColor3 = afk and Accent.Text or Theme.Color.TextLow

		for key, row in pairs(rows) do
			local on = Features.Get(key)
			row.Frame.Visible = not (row.Def.HideWhenOff and not on)
			row.Mark.BackgroundTransparency = on and 0 or 1
			row.Mark.BackgroundColor3 = Accent.Color
			row.Stroke.Color = on and Accent.Color or Theme.Color.TextLow
			row.State.Text = on and "ON" or "OFF"
			row.State.TextColor3 = on and Accent.Text or Theme.Color.TextLow
		end

		-- The dashboard is the whole screen's content while AFK, so it shows
		-- its details then even if the settings switch hides them otherwise.
		local showDetails = State.QuickOverlayDetails == true or afk

		if details then
			local farm = Features.Snapshot.Farm
			details.Visible = Features.Get("farm") and showDetails
			if details.Visible then
				local hub = Stats.Hub
				local target = farm.Target
				-- Straight from the farm's own target: it is cleared the
				-- moment an egg is finished with, so this is never the egg
				-- that was just collected.
				targetValue.Text = target or "None"
				local color = target and farm.Rarity and hub and hub.RarityColor and hub.RarityColor(farm.Rarity)
				targetValue.TextColor3 = color or (target and Theme.Color.TextHi or Theme.Color.TextLow)
				local step = farm.Step or "Searching"
				local text = statusText(farm)
				if DISTANCE_STEPS[step] then
					local distance = hub and hub.FarmDistance and hub.FarmDistance()
					if distance then
						text = string.format("%s  %d studs", text, math.floor(distance + 0.5))
					end
				end
				statusValue.Text = text
				statusValue.TextColor3 = CALM_STEPS[step] and Theme.Color.Caution or Theme.Color.Positive
			end
		end

		if slotsRow then
			local slots = Features.Snapshot.Place
			slotsRow.Visible = Features.Get("place") and slots.Discovered == true and showDetails
			if slotsRow.Visible then
				slotsValue.Text = string.format("%d / %d filled", slots.Filled or 0, slots.Slots or 0)
			end
		end

		if hopDetails then
			hopDetails.Visible = Features.Get("hop")
		end

		local stats = Features.Snapshot.Stats
		statsBlock.Visible = showDetails
		if showDetails then
			farmedValue.Text = tostring(stats.Farmed or 0)
			placedValue.Text = tostring(stats.Placed or 0)
			if stats.BestName then
				bestValue.Text = stats.BestName .. " - " .. tostring(stats.BestRarity or "Unknown")
				local hub = Stats.Hub
				local color = hub and hub.RarityColor and stats.BestRarity and hub.RarityColor(stats.BestRarity)
				bestValue.TextColor3 = color or Theme.Color.TextHi
			else
				bestValue.Text = "None yet"
				bestValue.TextColor3 = Theme.Color.TextLow
			end
		end

		moreButton.Visible = showDetails
		local expanded = O.Expanded and showDetails
		recentPanel.Visible = expanded
		moreLabel.Text = expanded and "See Less" or "See More..."
		if expanded then
			local list = Features.Snapshot.Recent
			recentEmpty.Visible = #list == 0
			for index, row in ipairs(recentRows) do
				local entry = list[index]
				row.Frame.Visible = entry ~= nil
				if entry then
					row.Name.Text = entry.Name .. " - " .. tostring(entry.Rarity)
					local hub = Stats.Hub
					local color = hub and hub.RarityColor and hub.RarityColor(entry.Rarity)
					row.Name.TextColor3 = color or Theme.Color.TextHi
				end
			end
			detectedValue.Text = tostring(stats.Detected or 0)
		end

		exitButton.Visible = afk
		O.RenderTimes()
	end

	end
	O.Build()

	-- Coalesces bursts of changes into one repaint per frame.
	local dirty = false
	function O.Dirty()
		if dirty or not O.Shown then
			return
		end
		dirty = true
		task.defer(function()
			dirty = false
			O.Render()
		end)
	end
	track(Features.Subscribe(function()
		O.Dirty()
	end))
	bindAccent(function()
		O.Dirty()
	end)

	-- POSITION ----------------------------------------------------------
	local function clampPosition(x, y)
		local viewport = screen.AbsoluteSize
		local size = holder.AbsoluteSize
		local maxX = math.max(MARGIN, viewport.X - size.X - MARGIN)
		local maxY = math.max(MARGIN, viewport.Y - size.Y - MARGIN)
		return math.clamp(x, MARGIN, maxX), math.clamp(y, MARGIN, maxY)
	end

	local function ensurePosition()
		if not O.Pos then
			local viewport = screen.AbsoluteSize
			O.Pos = { X = math.max(MARGIN, viewport.X - WIDTH - 16), Y = 96 }
		end
	end

	local settle = nil
	local function reclamp()
		ensurePosition()
		local x, y = clampPosition(O.Pos.X, O.Pos.Y)
		O.Pos.X, O.Pos.Y = x, y
		holder.Position = UDim2.fromOffset(x, y)
	end

	-- The holder follows the card's automatic height, and the overlay is kept
	-- on screen whenever its size or the viewport changes.
	local dragging = false
	track(card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		holder.Size = UDim2.fromOffset(WIDTH, math.max(card.AbsoluteSize.Y, 1))
		if O.Shown and not dragging then
			reclamp()
		end
	end))
	track(screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if O.Shown and not dragging then
			reclamp()
		end
	end))

	-- DRAGGING ----------------------------------------------------------
	-- Same feel as the main panel: the overlay chases the pointer with
	-- time-based smoothing, then glides a touch on release and settles. The
	-- move / render / release listeners exist only during a drag.
	local dragInput, dragMove, dragEnd, dragStep
	local target = { X = 0, Y = 0 }
	local current = { X = 0, Y = 0 }
	local velocity = { X = 0, Y = 0 }

	local function liftShadows(lifted)
		for _, shadow in ipairs(shadows) do
			if shadow.Frame.Parent then
				local rest = lifted and math.max(shadow.Rest - 0.06, 0.5) or shadow.Rest
				play(shadow.Frame, Motion.Quick, "Out", { BackgroundTransparency = rest })
			end
		end
	end

	local function stopDrag()
		if dragMove then
			dragMove:Disconnect()
			dragMove = nil
		end
		if dragEnd then
			dragEnd:Disconnect()
			dragEnd = nil
		end
		if dragStep then
			dragStep:Disconnect()
			dragStep = nil
		end
		if not dragging then
			return
		end
		dragging = false
		dragInput = nil
		local x, y = target.X, target.Y
		if not motionReduced() then
			x = x + velocity.X * Drag.Glide
			y = y + velocity.Y * Drag.Glide
		end
		velocity.X, velocity.Y = 0, 0
		x, y = clampPosition(x, y)
		O.Pos = { X = x, Y = y }
		if settle then
			settle:Cancel()
		end
		settle = play(holder, Motion.Base, "Out", { Position = UDim2.fromOffset(x, y) })
		if O.Shown then
			liftShadows(false)
		end
	end

	local function beginDrag(input)
		if not O.Shown then
			return
		end
		stopDrag()
		if settle then
			settle:Cancel()
			settle = nil
		end
		ensurePosition()
		dragging = true
		dragInput = input
		local origin = input.Position
		local startX, startY = holder.AbsolutePosition.X, holder.AbsolutePosition.Y
		current.X, current.Y = startX, startY
		target.X, target.Y = startX, startY
		velocity.X, velocity.Y = 0, 0
		local lastX, lastY, lastTime = startX, startY, os.clock()
		liftShadows(true)

		dragMove = UserInputService.InputChanged:Connect(function(changed)
			if changed == dragInput or changed.UserInputType == Enum.UserInputType.MouseMovement then
				target.X, target.Y = clampPosition(
					startX + (changed.Position.X - origin.X),
					startY + (changed.Position.Y - origin.Y)
				)
				local now = os.clock()
				local dt = now - lastTime
				if dt > 0.001 then
					local blend = 0.4
					velocity.X = velocity.X * (1 - blend) + ((target.X - lastX) / dt) * blend
					velocity.Y = velocity.Y * (1 - blend) + ((target.Y - lastY) / dt) * blend
					lastX, lastY, lastTime = target.X, target.Y, now
				end
				if motionReduced() then
					current.X, current.Y = target.X, target.Y
					holder.Position = UDim2.fromOffset(current.X, current.Y)
				end
			end
		end)
		if not motionReduced() then
			dragStep = RunService.RenderStepped:Connect(function(dt)
				local alpha = 1 - math.exp(-Drag.Follow * dt)
				current.X = current.X + (target.X - current.X) * alpha
				current.Y = current.Y + (target.Y - current.Y) * alpha
				holder.Position = UDim2.fromOffset(current.X, current.Y)
			end)
		end
		dragEnd = UserInputService.InputEnded:Connect(function(ended)
			local mouseRelease = dragInput
				and dragInput.UserInputType == Enum.UserInputType.MouseButton1
				and ended.UserInputType == Enum.UserInputType.MouseButton1
			if ended == dragInput or mouseRelease then
				stopDrag()
			end
		end)
	end

	-- The handle is a button, so it takes the press: nothing underneath the
	-- header (game UI included) sees the click that starts a drag.
	handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	-- SHOW / HIDE -------------------------------------------------------
	local function startLoop()
		local mine = token
		task.spawn(function()
			-- Distance and the clocks are the only things that change without an
			-- event: distance is refreshed while the farm is walking, and the hop
			-- countdown and the recent eggs' ages once a second.
			local ticks = 0
			while O.Shown and token == mine and screen.Parent do
				task.wait(0.25)
				if O.Shown and token == mine then
					ticks = ticks + 1
					local step = Features.Snapshot.Farm.Step
					if step == "Moving" or step == "Picking Up" or step == "Retrying" then
						O.Render()
					elseif ticks % 4 == 0 then
						O.RenderTimes()
					end
				end
			end
		end)
	end

	-- Shown only when switched on AND the access gate has been passed.
	function O.Refresh()
		local want = (State.QuickOverlay == true or State.Afk == true) and Gate.Authenticated == true
		if want == O.Shown then
			return
		end
		O.Shown = want
		token = token + 1
		local mine = token
		if want then
			holder.Visible = true
			O.Render()
			holder.Size = UDim2.fromOffset(WIDTH, math.max(card.AbsoluteSize.Y, 1))
			reclamp()
			card.Position = UDim2.fromOffset(0, 8)
			play(card, Motion.Reveal, "Out", { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
			for _, shadow in ipairs(shadows) do
				play(shadow.Frame, Motion.Reveal, "Out", { BackgroundTransparency = shadow.Rest })
			end
			startLoop()
		else
			if dragging then
				stopDrag()
			end
			play(card, Motion.Quick, "In", { GroupTransparency = 1, Position = UDim2.fromOffset(0, 6) })
			for _, shadow in ipairs(shadows) do
				play(shadow.Frame, Motion.Quick, "In", { BackgroundTransparency = 1 })
			end
			task.delay(scaledTime(Motion.Quick) + 0.05, function()
				if token == mine and not O.Shown then
					holder.Visible = false
				end
			end)
		end
	end

	function O.SetEnabled(enabled)
		State.QuickOverlay = enabled == true
		O.Refresh()
	end

	-- Puts the overlay back where it starts. Used by Reset UI.
	function O.ResetPosition()
		O.Pos = nil
		if O.Shown and not dragging then
			ensurePosition()
			reclamp()
		end
	end

	-- PERSISTENCE -------------------------------------------------------
	-- Position only, as a fraction of the screen so it survives a different
	-- resolution. Whether it is on is an ordinary registered toggle, and the
	-- live farm details are runtime data that is never saved.
	function O.Collect()
		local viewport = screen.AbsoluteSize
		if O.Pos and viewport.X > 0 and viewport.Y > 0 then
			return { x = O.Pos.X / viewport.X, y = O.Pos.Y / viewport.Y }
		end
		return {}
	end

	function O.Apply(data)
		if type(data) ~= "table" or type(data.x) ~= "number" or type(data.y) ~= "number" then
			return
		end
		local viewport = screen.AbsoluteSize
		O.Pos = { X = math.clamp(data.x, 0, 1) * viewport.X, Y = math.clamp(data.y, 0, 1) * viewport.Y }
		if O.Shown and not dragging then
			reclamp()
		end
	end

	-- Drops a drag and every loop that points at this overlay.
	function O.Release()
		token = token + 1
		O.Shown = false
		if dragMove or dragEnd or dragStep then
			dragging = true
			stopDrag()
		end
		if settle then
			settle:Cancel()
			settle = nil
		end
	end
end

--------------------------------------------------------------------------
-- AFK MODE  (black cover while the automation keeps running)
--
-- AFK is one Features record ("afk"), so the Home quick action, the settings
-- toggle and the dashboard's own exit button are one state (State.Afk). It
-- touches nothing that belongs to the automation: Auto Farm, Auto Place, FPS
-- Boost and audio carry on exactly as they were, and leaving AFK restores only
-- what AFK itself changed (the cover, and the 3D renderer if it was paused).
--
-- A black frame alone does not stop the GPU drawing the world, so once the
-- cover is solid the 3D renderer is paused with RunService:Set3dRenderingEnabled
-- (UI keeps drawing, scripts and sound are unaffected). That is the AFK-only
-- performance step; the user's FPS Boost choice is neither enabled nor
-- disabled by AFK. The cover sits below the floating button, the Quick Actions
-- dashboard and the notifications, so the way out is always on top of it.
--------------------------------------------------------------------------
do
	local A = { Paused = false }
	Features.AFK = A
	local token = 0

	local cover = New("Frame", {
		Name = "AfkCover",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true, -- a stray click on the black must not reach the game
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 4,
		Parent = screen,
	})

	local function setRendering(paused)
		if paused then
			if A.Paused then
				return
			end
			A.Paused = pcall(function()
				RunService:Set3dRenderingEnabled(false)
			end)
		elseif A.Paused then
			A.Paused = false
			pcall(function()
				RunService:Set3dRenderingEnabled(true)
			end)
		end
	end

	-- Re-applies the "pause 3D" preference to a running AFK session.
	function A.Sync()
		if State.Afk and State.AfkPause3D and cover.BackgroundTransparency <= 0.01 then
			setRendering(true)
		else
			setRendering(false)
		end
	end

	function A.Enable()
		if State.Afk or not Gate.Authenticated then
			return
		end
		State.Afk = true
		token = token + 1
		local mine = token
		if isOpen then
			setOpen(false)
		end
		cover.Visible = true
		play(cover, Motion.Reveal, "Out", { BackgroundTransparency = 0 })
		-- Nothing is visible once the cover is solid, so only then is the world
		-- left undrawn: the fade-in is never a frozen frame.
		task.delay(scaledTime(Motion.Reveal) + 0.05, function()
			if token == mine and State.Afk and State.AfkPause3D then
				setRendering(true)
			end
		end)
		QuickOverlay.Refresh()
		QuickOverlay.Render()
		Features.Changed("afk")
		notify("AFK mode on", "Info", "Screen is black. Auto farm, Auto place and audio keep running.")
	end

	function A.Disable()
		if not State.Afk then
			return
		end
		State.Afk = false
		token = token + 1
		local mine = token
		-- The world is drawn again before the cover fades, so it fades onto a
		-- live frame rather than a stale one.
		setRendering(false)
		play(cover, Motion.Reveal, "In", { BackgroundTransparency = 1 })
		task.delay(scaledTime(Motion.Reveal) + 0.05, function()
			if token == mine and not State.Afk then
				cover.Visible = false
			end
		end)
		QuickOverlay.Refresh()
		QuickOverlay.Render()
		Features.Changed("afk")
		notify("AFK mode off", "Info", "Normal view restored.")
	end

	-- Teardown: never leave the renderer paused or a cover up.
	function A.Release()
		token = token + 1
		State.Afk = false
		setRendering(false)
		cover.Visible = false
	end

	local def = Features.ByKey.afk
	def.Get = function()
		return State.Afk == true
	end
	def.Set = function(enabled)
		if enabled then
			A.Enable()
		else
			A.Disable()
		end
	end
end

--------------------------------------------------------------------------
-- LIVE METRICS  (one Heartbeat connection, only while something shows it)
--------------------------------------------------------------------------

local function readPingMs()
	local ok, seconds = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(seconds) == "number" then
		return math.floor(seconds * 1000 + 0.5)
	end
	return 0
end

local function publishMetrics()
	if isOpen then
		if Stats.Fps then
			Stats.Fps.Set(tostring(Metrics.Fps), Metrics.Fps / 120)
		end
		if Stats.Ping then
			Stats.Ping.Set(tostring(Metrics.Ping) .. " ms", Metrics.Ping / 300)
		end
		if Stats.SetLiveFps then
			Stats.SetLiveFps(Metrics.Fps)
		end
		if Stats.InfoFps then
			Stats.InfoFps.Text = tostring(Metrics.Fps)
		end
		if Stats.InfoPing then
			Stats.InfoPing.Text = tostring(Metrics.Ping) .. " ms"
		end
	end
	if State.FpsOverlay then
		fpsPillLabel.Text = string.format("%d FPS   %d ms", Metrics.Fps, Metrics.Ping)
	end
end

function Metrics.refresh()
	local needed = isOpen or State.FpsOverlay
	if needed and not Metrics.Connection then
		Metrics.Frames, Metrics.Elapsed = 0, 0
		Metrics.Connection = RunService.Heartbeat:Connect(function(dt)
			Metrics.Frames = Metrics.Frames + 1
			Metrics.Elapsed = Metrics.Elapsed + dt
			if Metrics.Elapsed >= 0.5 then
				Metrics.Fps = math.floor(Metrics.Frames / Metrics.Elapsed + 0.5)
				Metrics.Ping = readPingMs()
				Metrics.Frames, Metrics.Elapsed = 0, 0
				publishMetrics()
			end
		end)
		publishMetrics()
	elseif not needed and Metrics.Connection then
		Metrics.Connection:Disconnect()
		Metrics.Connection = nil
	end
end

--------------------------------------------------------------------------
-- FPS BOOST  (state + real, reversible client-side visual reduction)
--
-- State.FpsBoost gates blur (refreshBlur), ambient drift (Ambient.refresh)
-- and every tween (motionReduced -> play), and mirrors itself into the
-- visible Settings toggles. The switch is the Features "fps" record, so the
-- Home button, the settings toggle and the overlay row are one state.
--
-- On top of that it is a genuine rendering mode. Every change goes through
-- one function, lower(), which reads the property first, only writes if the
-- value actually differs, and remembers the value it replaced. Nothing is
-- destroyed, nothing is assumed to share a default (each object's own Enabled,
-- Transparency, Material, Reflectance, CastShadow, RenderFidelity, ... is what
-- comes back), and a property that does not exist or cannot be written on this
-- client is skipped instead of throwing.
--
--   world       ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles, lights and
--               Clouds are switched off with Enabled; Decal and Texture are
--               hidden with Transparency; parts lose reflections, shadow
--               casting and fancy materials; MeshPart detail drops to
--               Performance. A MeshPart's TextureID is never touched.
--   lighting    post-processing effects off, Atmosphere thinned, shadows and
--               specular reflections off, Compatibility technology.
--   terrain     water waves and reflections off, grass decoration off.
--   renderer    QualityLevel to the lowest step.
--
-- The workspace is walked once, in slices that yield, when the boost turns on.
-- After that only DescendantAdded / ChildAdded feed it, so there is no polling.
--------------------------------------------------------------------------

do
	-- [instance] = { [property] = valueBeforeTheBoost }. Weak-keyed: an object
	-- the game destroyed simply drops out, one the game keeps (a pooled effect
	-- parked in ReplicatedStorage) is still restored.
	local suppressed = setmetatable({}, { __mode = "k" })
	local effects = setmetatable({}, { __mode = "k" }) -- the ones counted on the Home card
	local connections = {}
	local sweepToken = 0
	local saved = nil -- the user's own Blur / Ambient / Reduce-animations choices
	local globalsLowered = false

	-- Post-processing: all of these have Enabled. blurEffect is this interface's
	-- own and is handled by refreshBlur instead, so it is left alone.
	local POST_EFFECTS = {
		BlurEffect = true,
		BloomEffect = true,
		SunRaysEffect = true,
		DepthOfFieldEffect = true,
		ColorCorrectionEffect = true,
	}

	-- Instanced effects and lights: switched off with Enabled.
	local WORLD_ENABLED = {
		ParticleEmitter = true,
		Trail = true,
		Beam = true,
		Fire = true,
		Smoke = true,
		Sparkles = true,
		PointLight = true,
		SpotLight = true,
		SurfaceLight = true,
		Clouds = true,
	}

	-- Surface detail: hidden with Transparency rather than disabled.
	local WORLD_TRANSPARENT = {
		Decal = true,
		Texture = true,
	}

	-- Anything with a solid surface. Terrain is a BasePart too but has no
	-- per-part material, so it is not in this list.
	local PART_CLASSES = {
		Part = true,
		MeshPart = true,
		UnionOperation = true,
		WedgePart = true,
		CornerWedgePart = true,
		TrussPart = true,
	}

	-- Materials that are already cheap, or that carry meaning (a glowing or
	-- see-through surface) and are better left as the game made them.
	local KEEP_MATERIAL = {
		[Enum.Material.Plastic] = true,
		[Enum.Material.SmoothPlastic] = true,
		[Enum.Material.Neon] = true,
		[Enum.Material.Glass] = true,
		[Enum.Material.ForceField] = true,
	}

	-- These hold real gameplay state: the character is the player, and the
	-- egg and plot folders are what the ESP, the auto farm and the plot
	-- buttons read. Their internals are left completely alone.
	local PROTECTED_NAMES = {
		RenderedEggs = true,
		Plots = true,
	}

	-- The one place a property is changed. Returns whether it was.
	local function lower(object, property, value, isEffect)
		local readable, current = pcall(function()
			return object[property]
		end)
		if not readable or current == value then
			return false
		end
		local entry = suppressed[object]
		if entry and entry[property] ~= nil then
			-- Already lowered by this boost: the first value stays the one
			-- that is restored.
			return false
		end
		local written = pcall(function()
			object[property] = value
		end)
		if not written then
			return false
		end
		if not entry then
			entry = {}
			suppressed[object] = entry
		end
		entry[property] = current
		if isEffect then
			effects[object] = true
		end
		return true
	end

	local function isProtected(instance)
		local current = instance
		while current and current ~= workspace do
			if current == player.Character or PROTECTED_NAMES[current.Name] then
				return true
			end
			current = current.Parent
		end
		return false
	end

	local function lowerLightingChild(instance)
		local class = instance.ClassName
		if instance == blurEffect then
			return
		end
		if POST_EFFECTS[class] then
			lower(instance, "Enabled", false, true)
		elseif class == "Atmosphere" then
			-- Atmosphere has no Enabled property: thin it out instead.
			lower(instance, "Density", 0, true)
			lower(instance, "Haze", 0, true)
			lower(instance, "Glare", 0, true)
		end
	end

	local function lowerWorldInstance(instance)
		local class = instance.ClassName
		if WORLD_ENABLED[class] then
			if not isProtected(instance) then
				lower(instance, "Enabled", false, true)
			end
		elseif WORLD_TRANSPARENT[class] then
			if not isProtected(instance) then
				lower(instance, "Transparency", 1, true)
			end
		elseif PART_CLASSES[class] then
			if instance.Transparency < 1 and not isProtected(instance) then
				if instance.Reflectance > 0 then
					lower(instance, "Reflectance", 0)
				end
				if instance.CastShadow then
					lower(instance, "CastShadow", false)
				end
				if not KEEP_MATERIAL[instance.Material] then
					lower(instance, "Material", Enum.Material.SmoothPlastic)
				end
				if class == "MeshPart" then
					lower(instance, "RenderFidelity", Enum.RenderFidelity.Performance)
				end
			end
		end
	end

	-- Settings that are not per-object: lighting, terrain and the renderer.
	-- Each is written through lower(), so a client that refuses one (Technology
	-- is plugin-level on a stock client) just skips it.
	local function lowerGlobals()
		if globalsLowered then
			return
		end
		globalsLowered = true
		lower(Lighting, "GlobalShadows", false)
		lower(Lighting, "ShadowSoftness", 0)
		lower(Lighting, "EnvironmentSpecularScale", 0)
		-- Compatibility is the low-end lighting path: it drops the dynamic
		-- shadow and lighting features, the biggest single saving available.
		lower(Lighting, "Technology", Enum.Technology.Compatibility)
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			lower(terrain, "WaterWaveSize", 0)
			lower(terrain, "WaterWaveSpeed", 0)
			lower(terrain, "WaterReflectance", 0)
			lower(terrain, "Decoration", false)
		end
		pcall(function()
			lower(settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)
		end)
	end

	-- One pass over the world when the boost turns on, in slices that yield so
	-- a large map never costs a single long frame. Not a loop: everything that
	-- appears later arrives through DescendantAdded. Objects the pass reaches
	-- twice are harmless, because lower() keeps the first value.
	local function sweepWorld()
		sweepToken = sweepToken + 1
		local mine = sweepToken
		task.spawn(function()
			local list = workspace:GetDescendants()
			for index = 1, #list do
				if sweepToken ~= mine or not State.FpsBoost then
					return
				end
				local ok = pcall(lowerWorldInstance, list[index])
				if not ok then
					-- an instance destroyed mid-walk: nothing to do
				end
				if index % 500 == 0 then
					task.wait()
				end
			end
			if Stats.RefreshBoost then
				Stats.RefreshBoost()
			end
		end)
	end

	local function disconnectAll()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function restoreEverything()
		sweepToken = sweepToken + 1 -- a sweep still running stops at its next slice
		disconnectAll()
		-- Restored whether or not the object is still parented: something
		-- re-parented later must not stay switched off.
		for instance, properties in pairs(suppressed) do
			for property, value in pairs(properties) do
				pcall(function()
					instance[property] = value
				end)
			end
		end
		table.clear(suppressed)
		table.clear(effects)
		globalsLowered = false
	end

	function Boost.release()
		restoreEverything()
	end

	-- Read by the FPS Boost card so the effect is visible in the GUI rather
	-- than being a switch with no stated consequence.
	function Boost.suppressedCount()
		local count = 0
		for _ in pairs(effects) do
			count = count + 1
		end
		return count
	end

	function Boost.apply()
		if State.FpsBoost then
			for _, child in ipairs(Lighting:GetChildren()) do
				lowerLightingChild(child)
			end
			if #connections == 0 then
				table.insert(connections, Lighting.ChildAdded:Connect(function(child)
					pcall(lowerLightingChild, child)
				end))
				table.insert(connections, workspace.DescendantAdded:Connect(function(instance)
					pcall(lowerWorldInstance, instance)
				end))
			end
			lowerGlobals()
			sweepWorld()
			if not saved then
				saved = {
					Blur = State.Blur,
					Ambient = State.Ambient,
					ReduceMotion = State.ReduceMotion,
				}
			end
			if Controls.Blur then Controls.Blur.Set(false) end
			if Controls.Ambient then Controls.Ambient.Set(false) end
			if Controls.ReduceMotion then Controls.ReduceMotion.Set(true) end
		else
			restoreEverything()
			if saved then
				local previous = saved
				saved = nil
				if Controls.Blur then Controls.Blur.Set(previous.Blur) end
				if Controls.Ambient then Controls.Ambient.Set(previous.Ambient) end
				if Controls.ReduceMotion then Controls.ReduceMotion.Set(previous.ReduceMotion) end
			end
		end
		Ambient.refresh()
		refreshBlur()
		if Stats.RefreshBoost then
			Stats.RefreshBoost()
		end
	end

	-- The Features "fps" record: the one read/write path for every view.
	local fps = Features.ByKey.fps
	fps.Get = function()
		return State.FpsBoost == true
	end
	fps.Set = function(enabled)
		enabled = enabled == true
		if State.FpsBoost == enabled then
			return
		end
		State.FpsBoost = enabled
		Boost.apply()
		notify(
			"FPS Boost " .. (enabled and "on" or "off"),
			enabled and "Success" or "Info",
			enabled
				and "Effects, shadows and textures are lowered. Everything is restored when this is switched off."
				or "Visual effects are back."
		)
		logActivity("FPS Boost " .. (enabled and "on" or "off"), "Performance mode updated", "Info")
	end
end

--------------------------------------------------------------------------
-- PAGE CONTENTS
--------------------------------------------------------------------------

local sessionStart = os.time()
local function elapsedText()
	local seconds = os.time() - sessionStart
	return string.format("T+%02d:%02d", math.floor(seconds / 60) % 100, seconds % 60)
end

local function playerCountText()
	return tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
end

local serverSizeLabel -- set by the Settings page, refreshed on join/leave
local toneCycle = { "Success", "Info", "Warning", "Error" }
local toneMessages = {
	Success = "Everything worked as expected.",
	Info = "Here is something worth knowing.",
	Warning = "Heads up: check this before continuing.",
	Error = "Something went wrong (this is only a demo).",
}

local function cycleAccent()
	local nextIndex = State.AccentIndex % #ACCENTS + 1
	setAccent(nextIndex)
	notify("Accent: " .. ACCENTS[nextIndex].Name, "Success", "The whole interface was recoloured.")
	logActivity("Accent changed", ACCENTS[nextIndex].Name .. " theme applied", "Info")
end

local function resetAll()
	-- Background sliders would otherwise flip the preset to "custom" mid-reset.
	Bg.Silent = true
	for _, control in ipairs(resettables) do
		control.Set(control.Default)
	end
	Bg.Silent = false
	QuickOverlay.ResetPosition()
	State.BgPreset = DEFAULTS.BgPreset
	Bg.Apply()
	State.AccentHue = DEFAULTS.AccentHue
	setAccent(DEFAULTS.AccentIndex)
	notify("Interface reset", "Success", "All settings are back to their defaults.", true)
	logActivity("Interface reset", "Settings restored to defaults", "Warning")
end

-- HOME ------------------------------------------------------------------
do
	local column = CreatePage("Home")

	local welcome = New("Frame", {
		Name = "Welcome",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = nextOrder(column),
		Parent = column,
	})
	Round(welcome, Theme.Radius.MD)
	AccentGradient(welcome, 15, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.85),
	}))
	Stroke(welcome, 0.85)
	Padding(welcome, 18, 20, 18, 20)
	Text(welcome, "Welcome back, " .. player.DisplayName, Theme.Type.Title, "Bold", Theme.Color.TextHi, {
		Size = UDim2.new(1, 0, 0, 24),
	})
	Text(welcome, "Your control panel is ready. Use the tabs on the left to explore tools, themes and settings.",
		Theme.Type.Caption, "Regular", Theme.Color.TextMid, {
			Wrap = true,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 32),
		})

	-- Profile card: avatar, names, user id and live health.
	do
		local card = New("Frame", {
			Name = "ProfileCard",
			BackgroundColor3 = Theme.Color.Alt,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 116),
			LayoutOrder = nextOrder(column),
			Parent = column,
		})
		Round(card, Theme.Radius.MD)
		Stroke(card, 0.92)

		local ring = New("Frame", {
			Name = "AvatarRing",
			BackgroundColor3 = Theme.Color.White,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(80, 80),
			Parent = card,
		})
		Round(ring, Theme.Radius.Pill)
		AccentGradient(ring, 45)
		local avatar = New("ImageLabel", {
			Name = "Avatar",
			BackgroundColor3 = Theme.Color.Surface,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
			Image = "",
			ScaleType = Enum.ScaleType.Crop,
			Parent = ring,
		})
		Round(avatar, Theme.Radius.Pill)
		-- Initial shows until the real avatar thumbnail has loaded.
		Stats.AvatarInitial = Text(avatar, string.upper(string.sub(player.DisplayName, 1, 1)), Theme.Type.Display,
			"Bold", Theme.Color.TextHi, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		Stats.Avatar = avatar

		local info = New("Frame", {
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(108, 0),
			Size = UDim2.new(1, -124, 1, 0),
			Parent = card,
		})
		Text(info, player.DisplayName, Theme.Type.Title, "Bold", Theme.Color.TextHi, {
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.new(1, 0, 0, 22),
		})
		Text(info, "@" .. player.Name, Theme.Type.Caption, "Medium", Theme.Color.TextMid, {
			Position = UDim2.fromOffset(0, 35),
			Size = UDim2.new(1, 0, 0, 16),
		})
		Text(info, "User ID  " .. tostring(player.UserId), Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 0, 14),
		})
		Text(info, "HEALTH", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(0, 75),
			Size = UDim2.new(0.5, 0, 0, 14),
		})
		local healthValue = Text(info, "--", Theme.Type.Micro, "SemiBold", Theme.Color.TextHi, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 75),
			Size = UDim2.new(0.5, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local healthTrack = New("Frame", {
			Name = "HealthTrack",
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 93),
			Size = UDim2.new(1, 0, 0, 6),
			Parent = info,
		})
		Round(healthTrack, Theme.Radius.Pill)
		local healthFill = New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.Color.Positive,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Parent = healthTrack,
		})
		Round(healthFill, Theme.Radius.Pill)

		local function setHealth(current, maximum)
			if not current then
				healthValue.Text = "--"
				play(healthFill, Motion.Quick, "Out", { Size = UDim2.fromScale(0, 1) })
				return
			end
			maximum = math.max(maximum or 100, 1)
			local ratio = math.clamp(current / maximum, 0, 1)
			local color = Theme.Color.Positive
			if ratio <= 0.25 then
				color = Theme.Color.Negative
			elseif ratio <= 0.5 then
				color = Theme.Color.Caution
			end
			healthValue.Text = string.format("%d / %d", math.floor(current + 0.5), math.floor(maximum + 0.5))
			play(healthFill, Motion.Quick, "Out", { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = color })
		end

		-- Health follows whichever character is current (respawns included).
		local healthToken = 0
		local healthConnections = {}
		local function clearHealth()
			for _, connection in ipairs(healthConnections) do
				connection:Disconnect()
			end
			table.clear(healthConnections)
		end
		Stats.ClearHealth = clearHealth

		local function bindCharacter(character)
			healthToken = healthToken + 1
			local token = healthToken
			clearHealth()
			if not character then
				setHealth(nil)
				return
			end
			task.spawn(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
				if not humanoid or token ~= healthToken then
					return
				end
				local function refresh()
					setHealth(humanoid.Health, humanoid.MaxHealth)
				end
				table.insert(healthConnections, humanoid.HealthChanged:Connect(refresh))
				table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
				refresh()
			end)
		end
		track(player.CharacterAdded:Connect(bindCharacter))
		track(player.CharacterRemoving:Connect(function()
			bindCharacter(nil)
		end))
		bindCharacter(player.Character)
	end

	local statRow = New("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = nextOrder(column),
		Parent = column,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = statRow,
	})
	Stats.Ping = StatCard(statRow, { Caption = "PING", Value = "-- ms", Ratio = 0.1 })
	Stats.Fps = StatCard(statRow, { Caption = "FPS", Value = "--", Ratio = 0.5 })
	Stats.Players = StatCard(statRow, {
		Caption = "PLAYERS",
		Value = tostring(#Players:GetPlayers()),
		Ratio = #Players:GetPlayers() / math.max(Players.MaxPlayers, 1),
	})

	-- FPS BOOST -----------------------------------------------------------
	do
		local boost = Section(column, "FPS Boost")
		-- An accent outline makes this card stand out from the other sections.
		local boostStroke = boost:FindFirstChildOfClass("UIStroke")
		if boostStroke then
			bindAccent(function(a)
				boostStroke.Color = a
				boostStroke.Transparency = 0.55
			end)
		end

		local live = New("Frame", {
			Name = "LiveFps",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 62),
			LayoutOrder = nextOrder(boost),
			Parent = boost,
		})
		local fpsNumber = Text(live, "--", 34, "Bold", Theme.Color.TextHi, {
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(78, 42),
			TextTruncate = Enum.TextTruncate.None,
		})
		Text(live, "LIVE FPS", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(96, 14),
			Size = UDim2.new(1, -210, 0, 14),
		})
		local fpsStatus = Text(live, "Measuring...", Theme.Type.Body, "SemiBold", Theme.Color.TextMid, {
			Position = UDim2.fromOffset(96, 30),
			Size = UDim2.new(1, -210, 0, 20),
		})
		local pill = New("Frame", {
			Name = "BoostState",
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(96, 26),
			Parent = live,
		})
		Round(pill, Theme.Radius.Pill)
		local pillLabel = Text(pill, "BOOST OFF", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
		})

		-- Shared: reads and writes the Features "fps" record, so this switch, the
		-- Home quick action and the overlay row can never disagree.
		Controls.FpsBoost = Toggle(boost, {
			Text = "FPS Boost",
			Description = "Cuts client-side visual work: post-processing, shadows, particles, trails, beams and surface textures",
			Default = DEFAULTS.FpsBoost,
			Shared = "fps",
		})

		local note = Text(boost, "", Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
			Wrap = true,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = nextOrder(boost),
		})
		Padding(note, 2, 8, 4, 12)

		local function fpsTone(fps)
			if fps >= 55 then
				return Theme.Color.Positive, "Smooth"
			elseif fps >= 30 then
				return Theme.Color.Caution, "Playable"
			end
			return Theme.Color.Negative, "Choppy"
		end

		Stats.SetLiveFps = function(fps)
			local color, word = fpsTone(fps)
			fpsNumber.Text = tostring(fps)
			fpsNumber.TextColor3 = color
			fpsStatus.Text = word
		end

		Stats.RefreshBoost = function()
			local on = State.FpsBoost
			play(pill, Motion.Quick, "Out", {
				BackgroundColor3 = on and Theme.Color.Positive or Theme.Color.White,
				BackgroundTransparency = on and 0.8 or 0.92,
			})
			pillLabel.Text = on and "BOOST ON" or "BOOST OFF"
			pillLabel.TextColor3 = on and Theme.Color.Positive or Theme.Color.TextLow
			note.Text = on
				and ("Active: " .. Boost.suppressedCount()
					.. " world effects and textures are off, plus shadows, lighting effects and UI animations. "
					.. "All of it comes back when this is switched off.")
				or "Off: turn this on to cut client-side visual effects and raise FPS on weaker devices."
		end
		Stats.RefreshBoost()
	end

	-- GAME INFO -----------------------------------------------------------
	do
		local info = Section(column, "Game info")
		Stats.PlaceLabel = InfoRow(info, "Game", game.Name) -- real name is fetched during loading
		Stats.GamePlayers = InfoRow(info, "Players", playerCountText())
		Stats.InfoFps = InfoRow(info, "FPS", "--")
		Stats.InfoPing = InfoRow(info, "Ping", "-- ms")

		local jobId = game.JobId
		local jobText = jobId ~= "" and jobId or "Unavailable in Studio"
		local jobRow = New("Frame", {
			Name = "JobRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 38),
			LayoutOrder = nextOrder(info),
			Parent = info,
		})
		Text(jobRow, "Job ID", Theme.Type.Body, "Medium", Theme.Color.TextMid, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(70, 38),
		})
		-- Roblox scripts cannot write to the clipboard, so the ID lives in a
		-- selectable box: the button selects it, then Ctrl+C / long-press copies.
		local jobBox = New("TextBox", {
			Name = "JobIdBox",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(1, -96, 1, 0),
			ClearTextOnFocus = false,
			PlaceholderText = "",
			Text = jobText,
			TextSize = Theme.Type.Caption,
			TextColor3 = Theme.Color.TextHi,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = jobRow,
		})
		applyFont(jobBox, "SemiBold")
		-- Read-only in practice: any edit is reverted immediately.
		jobBox:GetPropertyChangedSignal("Text"):Connect(function()
			if jobBox.Text ~= jobText then
				jobBox.Text = jobText
			end
		end)

		local function selectAll()
			task.defer(function()
				if jobBox.Parent and jobId ~= "" then
					jobBox.SelectionStart = 1
					jobBox.CursorPosition = #jobBox.Text + 1
				end
			end)
		end
		jobBox.Focused:Connect(selectAll)

		Button(info, {
			Text = "Copy Job ID",
			Icon = "copy",
			Callback = function()
				if jobId == "" then
					notify("No Job ID", "Warning", "Job IDs only exist in live servers, not in Studio.")
					return
				end
				jobBox:CaptureFocus()
				selectAll()
				notify("Job ID selected", "Success", "Press Ctrl+C (or long-press > Copy) to copy it.", true)
				logActivity("Job ID selected", "Ready to copy", "Info")
			end,
		})
		local hint = Text(info, "Roblox blocks scripts from writing to the clipboard, so the button selects the ID for you to copy.",
			Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
				Wrap = true,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = nextOrder(info),
			})
		Padding(hint, 4, 8, 2, 8)
	end

	-- QUICK ACTIONS ---------------------------------------------------------
	-- The three egg controls people reach for mid-session, without leaving Home.
	-- They read and write the state the egg page owns (through Stats.Hub), so
	-- there is exactly one source of truth for "is the farm on".
	local quick = Section(column, "Quick actions")
	InfoRow(quick, "What these do", "Same controls as the Eggs and Automation tabs", Theme.Color.TextMid)
	local quickGrid = New("Frame", {
		Name = "EggActions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(quick),
		Parent = quick,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = quickGrid,
	})
	New("UISizeConstraint", {
		MinSize = Vector2.new(300, 0),
		MaxSize = Vector2.new(460, math.huge),
		Parent = quickGrid,
	})

	-- The hub is filled in by the egg page, which is built after this one. The
	-- Get/Set wrappers fall back to "off" until then, so a click during startup
	-- cannot error on a nil call.
	local hub = Stats.Hub or {}
	Stats.Hub = hub
	local function hubGet(name)
		local getter = hub[name]
		if type(getter) ~= "function" then
			return false
		end
		local ok, value = pcall(getter)
		return ok and value == true
	end
	local function hubSet(name, enabled)
		local setter = hub[name]
		if type(setter) == "function" then
			pcall(setter, enabled)
		end
	end

	-- Built from the Features registry, so the same records drive the main
	-- toggles and the floating overlay. Each button repaints whenever any view
	-- changes its feature, instead of only when it is clicked itself.
	for _, def in ipairs(Features.Quick()) do
		local action = ActionToggle(quickGrid, {
			Text = def.Text,
			Icon = def.Icon,
			Hint = def.Hint,
			Get = function()
				return Features.Get(def.Key)
			end,
			Set = function(value)
				Features.Set(def.Key, value)
			end,
		})
		track(Features.Subscribe(function(key)
			if key == nil or key == def.Key then
				action.Refresh(true)
			end
		end))
	end
	Button(quickGrid, {
		Text = "Reload eggs",
		Icon = "refresh",
		Style = "Secondary",
		Callback = function()
			-- Forces a full re-scan and wakes the farm and the placer, so a list
			-- that looks stale can be fixed without touching the toggles.
			if hub.Rescan then
				pcall(hub.Rescan)
				notify("Eggs rescanned", "Success", "The list, the farm and the placer were all refreshed.")
			else
				notify("Not ready", "Warning", "The egg scanner is still starting up.")
			end
		end,
	})

	local overlayAction = ActionToggle(quickGrid, {
		Text = Features.ByKey.overlay.Text,
		Icon = Features.ByKey.overlay.Icon,
		Hint = Features.ByKey.overlay.Hint,
		Get = function()
			return Features.Get("overlay")
		end,
		Set = function(value)
			Features.Set("overlay", value)
		end,
	})
	track(Features.Subscribe(function(key)
		if key == nil or key == "overlay" then
			overlayAction.Refresh(true)
		end
	end))

	-- AUTO FARM STATUS ------------------------------------------------------
	-- A live card rather than a single text row, because the question this
	-- answers is "is it working right now", and the answer is a state plus a
	-- target rather than one sentence.
	local farmSection = Section(column, "Auto farm status")
	local farmCard = New("Frame", {
		Name = "FarmCard",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = nextOrder(farmSection),
		Parent = farmSection,
	})
	Round(farmCard, Theme.Radius.SM)
	Stroke(farmCard, 0.9)

	local farmChip = New("Frame", {
		Name = "Chip",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(74, 20),
		Parent = farmCard,
	})
	Round(farmChip, Theme.Radius.Pill)
	local farmDot = New("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.Color.TextLow,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(7, 7),
		Parent = farmChip,
	})
	Round(farmDot, Theme.Radius.Pill)
	local farmChipText = Text(farmChip, "OFF", Theme.Type.Micro, "Bold", Theme.Color.TextLow, {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.fromOffset(48, 20),
	})

	local farmTargetLabel = Text(farmCard, "Auto farm is off", Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(96, 11),
		Size = UDim2.new(1, -108, 0, 20),
	})
	local farmDetailLabel = Text(farmCard, "Turn it on from the quick actions above.", Theme.Type.Caption,
		"Regular", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(96, 31),
		Size = UDim2.new(1, -108, 0, 18),
	})
	local farmMetaLabel = Text(farmCard, "", Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 0, 20),
	})

	-- EGG STATISTICS --------------------------------------------------------
	local statsSection = Section(column, "Egg statistics")
	local chips = New("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = nextOrder(statsSection),
		Parent = statsSection,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = chips,
	})
	New("UISizeConstraint", {
		MinSize = Vector2.new(300, 0),
		MaxSize = Vector2.new(460, math.huge),
		Parent = chips,
	})
	local counterLabels = {}
	do
		local definitions = {
			{ Key = "Detected", Caption = "Detected", Icon = "eye" },
			{ Key = "Farmed", Caption = "Farmed", Icon = "target" },
			{ Key = "Placed", Caption = "Placed", Icon = "gem" },
		}
		for index, definition in ipairs(definitions) do
			local chip = New("Frame", {
				Name = definition.Key,
				BackgroundColor3 = Theme.Color.Surface,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.new(1 / #definitions, -4, 1, 0),
				LayoutOrder = index,
				Parent = chips,
			})
			Round(chip, Theme.Radius.SM)
			Stroke(chip, 0.9)
			Icon(chip, definition.Icon, 13, Theme.Color.TextLow, {
				Position = UDim2.fromOffset(9, 8),
			})
			Text(chip, definition.Caption, Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
				Position = UDim2.fromOffset(26, 6),
				Size = UDim2.new(1, -32, 0, 16),
			})
			counterLabels[definition.Key] = Text(chip, "0", Theme.Type.Body, "Bold", Theme.Color.TextHi, {
				Position = UDim2.fromOffset(9, 22),
				Size = UDim2.new(1, -18, 0, 18),
			})
		end
	end

	local rarityHead = Text(statsSection, "ON THE SERVER RIGHT NOW", Theme.Type.Micro, "SemiBold",
		Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = nextOrder(statsSection),
	})
	Padding(rarityHead, 6, 0, 0, 2)
	local rarityRows = New("Frame", {
		Name = "RarityBreakdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(statsSection),
		Parent = statsSection,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = rarityRows,
	})
	New("UISizeConstraint", {
		MinSize = Vector2.new(300, 0),
		MaxSize = Vector2.new(460, math.huge),
		Parent = rarityRows,
	})
	-- Shown until the first publish, so the section is never blank.
	local rarityEmpty = Text(rarityRows, "No eggs on the server yet.", Theme.Type.Caption, "Regular",
		Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
	})

	-- Collects the widgets the egg page repaints. Registered here because Home
	-- is built first, and the egg page publishes into it as soon as it exists.
	hub.OnEggs = function(card, counters, place)
		-- Chip and dot carry the state, so the state is never signalled by
		-- colour alone.
		local phase = card and card.Phase or "off"
		local chipText, chipColor = "OFF", Theme.Color.TextLow
		if phase == "farming" then
			chipText, chipColor = "ACTIVE", Theme.Color.Positive
		elseif phase == "listening" or phase == "waiting" then
			chipText, chipColor = "WAITING", Theme.Color.Caution
		elseif phase == "placing" or phase == "full" then
			chipText, chipColor = "PLACING", Accent.Text
		end
		farmChipText.Text = chipText
		farmChipText.TextColor3 = chipColor
		farmChip.BackgroundColor3 = chipColor
		farmChip.BackgroundTransparency = phase == "off" and 0.88 or 0.82
		farmDot.BackgroundColor3 = chipColor

		if card then
			if card.Target then
				farmTargetLabel.Text = card.Target
				farmTargetLabel.TextColor3 = card.Rarity
					and (Stats.RarityColor and Stats.RarityColor(card.Rarity))
					or Theme.Color.TextHi
			else
				farmTargetLabel.Text = card.Active and "Looking for an egg" or "Auto farm is off"
				farmTargetLabel.TextColor3 = Theme.Color.TextHi
			end
			farmDetailLabel.Text = card.Message or ""
		end
		-- The meta line is the farm's target and the placer's slots together,
		-- because the two answers are what people actually want side by side.
		local meta = {}
		if card and card.Distance then
			table.insert(meta, string.format("%.0f studs away", card.Distance))
		end
		if place and place.Discovered then
			table.insert(meta, string.format("Slots %d/%d filled", place.Filled or 0, place.Slots))
		end
		farmMetaLabel.Text = #meta > 0 and table.concat(meta, "   ") or "Waiting for eggs to spawn"

		if counters then
			for key, label in pairs(counterLabels) do
				local value = counters[key] or 0
				if label.Text ~= tostring(value) then
					label.Text = tostring(value)
				end
			end
			-- Rarity breakdown, rebuilt only when the numbers actually move.
			local signature = ""
			for rarity, count in pairs(counters.ByRarity or {}) do
				signature = signature .. rarity .. ":" .. count .. ","
			end
			if signature ~= rarityEmpty:GetAttribute("Signature") then
				rarityEmpty:SetAttribute("Signature", signature)
				for _, child in ipairs(rarityRows:GetChildren()) do
					if child:IsA("TextLabel") or child:IsA("Frame") then
						if child ~= rarityEmpty then
							child:Destroy()
						end
					end
				end
				local order = {}
				for rarity, count in pairs(counters.ByRarity or {}) do
					if count > 0 then
						table.insert(order, { Rarity = rarity, Count = count })
					end
				end
				table.sort(order, function(a, b)
					local rankA = Stats.RarityRank and Stats.RarityRank(a.Rarity) or 0
					local rankB = Stats.RarityRank and Stats.RarityRank(b.Rarity) or 0
					if rankA == rankB then
						return a.Rarity < b.Rarity
					end
					return rankA > rankB
				end)
				rarityEmpty.Visible = #order == 0
				for index, item in ipairs(order) do
					local row = New("Frame", {
						Name = "Rarity",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 20),
						LayoutOrder = index + 1,
						Parent = rarityRows,
					})
					local dot = New("Frame", {
						Name = "Dot",
						BackgroundColor3 = Stats.RarityColor and Stats.RarityColor(item.Rarity) or Theme.Color.TextLow,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(2, 8),
						Size = UDim2.fromOffset(6, 6),
						Parent = row,
					})
					Round(dot, Theme.Radius.Pill)
					Text(row, item.Rarity, Theme.Type.Caption, "Medium", Theme.Color.TextMid, {
						Position = UDim2.fromOffset(16, 0),
						Size = UDim2.new(1, -60, 1, 0),
					})
					Text(row, tostring(item.Count), Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -2, 0, 0),
						Size = UDim2.fromOffset(40, 20),
						TextXAlignment = Enum.TextXAlignment.Right,
					})
				end
			end
		end
	end

	local activity = Section(column, "Recent activity")
	local emptyLabel = Text(activity, "No activity yet.", Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
		Visible = false,
	})
	Padding(emptyLabel, 0, 0, 0, 8)

	local entries = {}
	local entryCounter = 0

	logActivity = function(title, caption, tone)
		if Config.Loading then
			return
		end
		local spec = TONES[tone] or TONES.Info
		entryCounter = entryCounter + 1
		local row = New("Frame", {
			Name = "Entry",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 46),
			LayoutOrder = 1000 - entryCounter, -- newest first, below the heading
			Parent = activity,
		})
		local badge = New("Frame", {
			Name = "Badge",
			BackgroundColor3 = spec.Color,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = row,
		})
		Round(badge, Theme.Radius.XS)
		Icon(badge, spec.Icon, 15, spec.Color, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		Text(row, title, Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
			Position = UDim2.fromOffset(46, 5),
			Size = UDim2.new(1, -120, 0, 18),
		})
		Text(row, caption, Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(46, 24),
			Size = UDim2.new(1, -120, 0, 16),
		})
		Text(row, elapsedText(), Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(60, 46),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		table.insert(entries, 1, row)
		while #entries > 5 do
			table.remove(entries):Destroy()
		end
		emptyLabel.Visible = false
	end

	-- Exposed to the Main page's "Clear activity" button.
	function Stats.ClearActivity()
		for _, row in ipairs(entries) do
			row:Destroy()
		end
		table.clear(entries)
		emptyLabel.Visible = true
	end

	logActivity("Interface ready", CONFIG.Title .. " " .. CONFIG.Version .. " loaded", "Success")
	logActivity("Signed in", player.DisplayName .. " joined this server", "Info")
end

-- VISUALS ---------------------------------------------------------------
do
	local column = CreatePage("Visuals")

	-- ACCENT ------------------------------------------------------------
	local theme = Section(column, "Accent theme")

	local picker = New("Frame", {
		Name = "AccentPicker",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 76),
		AutomaticSize = Enum.AutomaticSize.Y, -- grows when the swatches wrap
		LayoutOrder = nextOrder(theme),
		Parent = theme,
	})
	Padding(picker, 0, 0, 12, 0)
	Text(picker, "Accent colour", Theme.Type.Body, "Medium", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -120, 0, 20),
	})
	local accentName = Text(picker, ACCENTS[State.AccentIndex].Name, Theme.Type.Caption, "SemiBold",
		Theme.Color.TextLow, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 8),
			Size = UDim2.fromOffset(100, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	local strip = New("Frame", {
		Name = "Swatches",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = picker,
	})
	-- A grid wraps onto a second row when the list outgrows the width.
	New("UIGridLayout", {
		CellSize = UDim2.fromOffset(30, 30),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = strip,
	})
	local swatches, swatchGradients = {}, {}
	for index, preset in ipairs(ACCENTS) do
		local swatch = New("TextButton", {
			Name = "Swatch_" .. preset.Name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.White,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(30, 30),
			LayoutOrder = index,
			Parent = strip,
		})
		Round(swatch, Theme.Radius.Pill)
		swatchGradients[index] = New("UIGradient", {
			Color = ColorSequence.new(preset.A, preset.B),
			Rotation = 45,
			Parent = swatch,
		})
		local ring = Stroke(swatch, 1, Theme.Color.White, 2)
		attachFeedback(swatch, { HoverScale = 1.1, PressScale = 0.92 })
		swatch.Activated:Connect(function()
			setAccent(index)
			notify("Accent: " .. preset.Name, "Success", "The whole interface was recoloured.")
		end)
		swatches[index] = ring
	end
	bindAccent(function()
		accentName.Text = ACCENTS[State.AccentIndex].Name
		for index, ring in ipairs(swatches) do
			local preset = ACCENTS[index]
			if preset.Custom then
				swatchGradients[index].Color = ColorSequence.new(preset.A, preset.B)
			end
			play(ring, Motion.Quick, "Out", { Transparency = index == State.AccentIndex and 0 or 1 })
		end
	end)

	Slider(theme, {
		Text = "Custom accent hue",
		Min = 0, Max = 360, Default = DEFAULTS.AccentHue, Step = 5,
		Format = function(value)
			return tostring(math.floor(value + 0.5)) .. " deg"
		end,
		Callback = function(value)
			State.AccentHue = value
			if Bg.Silent then
				return
			end
			setAccent(#ACCENTS)
		end,
	})
	Toggle(theme, {
		Text = "Gradient accents",
		Description = "Blend two colours, or use a solid accent",
		Default = DEFAULTS.Gradient,
		Callback = function(enabled)
			State.Gradient = enabled
			applyAccent()
		end,
	})

	-- BACKGROUND --------------------------------------------------------
	local backdrop = Section(column, "Background theme")

	local bgPicker = New("Frame", {
		Name = "BackgroundPicker",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 76),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(backdrop),
		Parent = backdrop,
	})
	Padding(bgPicker, 0, 0, 12, 0)
	Text(bgPicker, "Panel background", Theme.Type.Body, "Medium", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -140, 0, 20),
	})
	local bgName = Text(bgPicker, "", Theme.Type.Caption, "SemiBold", Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(120, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local bgStrip = New("Frame", {
		Name = "Swatches",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = bgPicker,
	})
	New("UIGridLayout", {
		CellSize = UDim2.fromOffset(30, 30),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = bgStrip,
	})

	local bgSliders = {}
	local function syncBgSliders()
		Bg.Silent = true
		if bgSliders.Hue then
			bgSliders.Hue.Set(State.BgHue, true)
			bgSliders.Sat.Set(State.BgSat, true)
			bgSliders.Val.Set(State.BgVal, true)
		end
		Bg.Silent = false
	end

	local bgRings = {}
	for index, preset in ipairs(Bg.Presets) do
		local swatch = New("TextButton", {
			Name = "Bg_" .. preset.Name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = preset.Alt,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(30, 30),
			LayoutOrder = index,
			Parent = bgStrip,
		})
		Round(swatch, Theme.Radius.SM)
		-- Two-tone chip: surface on top of the raised colour, so the preset reads at a glance.
		local inner = New("Frame", {
			BackgroundColor3 = preset.Surface,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			Parent = swatch,
		})
		Round(inner, Theme.Radius.XS)
		Stroke(swatch, 0.6, Theme.Color.White, 1)
		local ring = Stroke(swatch, 1, Accent.Color, 2)
		attachFeedback(swatch, { HoverScale = 1.1, PressScale = 0.92 })
		swatch.Activated:Connect(function()
			State.BgPreset = index
			-- Sliders start from the chosen preset, so nudging one edits it
			-- instead of jumping to an unrelated colour.
			local h, sat, val = preset.Surface:ToHSV()
			State.BgHue = math.floor(h * 360 / 5 + 0.5) * 5
			State.BgSat = math.floor(sat * 100 / 5 + 0.5) * 5
			State.BgVal = math.clamp(math.floor(val * 100 + 0.5), 2, 18)
			syncBgSliders()
			Bg.Apply()
			notify("Background: " .. preset.Name, "Success", "Panel colours updated.")
		end)
		bgRings[index] = ring
	end
	local function paintBgPicker()
		local preset = Bg.Presets[State.BgPreset]
		bgName.Text = preset and preset.Name or "Custom"
		for index, ring in ipairs(bgRings) do
			ring.Color = Accent.Color
			play(ring, Motion.Quick, "Out", { Transparency = index == State.BgPreset and 0 or 1 })
		end
	end
	bindAccent(paintBgPicker)
	table.insert(Bg.Binds, paintBgPicker)
	paintBgPicker()

	local function customBg()
		if Bg.Silent then
			return
		end
		State.BgPreset = 0
		Bg.Apply()
	end
	bgSliders.Hue = Slider(backdrop, {
		Text = "Background hue",
		Min = 0, Max = 360, Default = DEFAULTS.BgHue, Step = 5,
		Format = function(value)
			return tostring(math.floor(value + 0.5)) .. " deg"
		end,
		Callback = function(value)
			State.BgHue = value
			customBg()
		end,
	})
	bgSliders.Sat = Slider(backdrop, {
		Text = "Background saturation",
		Min = 0, Max = 100, Default = DEFAULTS.BgSat, Step = 5, Suffix = "%",
		Callback = function(value)
			State.BgSat = value
			customBg()
		end,
	})
	bgSliders.Val = Slider(backdrop, {
		Text = "Background brightness",
		Min = 2, Max = 18, Default = DEFAULTS.BgVal, Step = 1, Suffix = "%",
		Callback = function(value)
			State.BgVal = value
			customBg()
		end,
	})
	InfoRow(backdrop, "Readability", "Brightness is capped so text stays legible", Theme.Color.TextMid)

	-- SHAPE -------------------------------------------------------------
	local shape = Section(column, "Shape and glow")
	Toggle(shape, {
		Text = "Border shimmer",
		Description = "A slow accent highlight round the window edge. Off with FPS Boost",
		Default = DEFAULTS.Shimmer,
		Callback = function(enabled)
			State.Shimmer = enabled
			Ambient.refresh()
		end,
	})
	Slider(shape, {
		Text = "Corner roundness",
		Min = 0, Max = 150, Default = DEFAULTS.Roundness * 100, Step = 10, Suffix = "%",
		Callback = function(value)
			State.Roundness = value / 100
			refreshCorners()
		end,
	})
	Slider(shape, {
		Text = "Ambient glow strength",
		Min = 0, Max = 200, Default = DEFAULTS.AmbientStrength * 100, Step = 10, Suffix = "%",
		Callback = function(value)
			State.AmbientStrength = value / 100
			refreshOrbTint()
		end,
	})
end
-- SETTINGS --------------------------------------------------------------
do
	local column = CreatePage("Settings")

	local interface = Section(column, "Interface")
	Slider(interface, {
		Text = "UI scale",
		Min = 70, Max = 130, Default = DEFAULTS.UIScale * 100, Step = 5, Suffix = "%",
		Callback = function(value)
			State.UIScale = value / 100
			applyLayout()
		end,
	})
	Slider(interface, {
		Text = "Panel transparency",
		Min = 0, Max = 40, Default = DEFAULTS.PanelTransparency, Step = 1, Suffix = "%",
		Callback = function(value)
			State.PanelTransparency = value
			play(root, Motion.Quick, "Out", { BackgroundTransparency = value / 100 })
		end,
	})
	Slider(interface, {
		Text = "Animation speed",
		Min = 0.5, Max = 2, Default = DEFAULTS.AnimSpeed, Step = 0.1,
		Format = function(value)
			return string.format("%.1fx", value)
		end,
		Callback = function(value)
			State.AnimSpeed = value
		end,
	})

	local behaviour = Section(column, "Behaviour")
	Controls.ReduceMotion = Toggle(behaviour, {
		Text = "Reduce animations",
		Description = "Near-instant transitions and no ambient drift",
		Default = DEFAULTS.ReduceMotion,
		Callback = function(enabled)
			State.ReduceMotion = enabled
			Ambient.refresh()
		end,
	})
	Controls.Blur = Toggle(behaviour, {
		Text = "Background blur",
		Description = "Blur the game behind the panel while it is open",
		Default = DEFAULTS.Blur,
		Callback = function(enabled)
			State.Blur = enabled
			refreshBlur()
		end,
	})
	Controls.Ambient = Toggle(behaviour, {
		Text = "Ambient effects",
		Description = "Soft drifting glow behind the panel",
		Default = DEFAULTS.Ambient,
		Callback = function(enabled)
			State.Ambient = enabled
			Ambient.refresh()
		end,
	})
	Toggle(behaviour, {
		Text = "Notifications",
		Description = "Show toast messages for actions",
		Default = DEFAULTS.Notifications,
		Callback = function(enabled)
			if enabled then
				State.Notifications = true
				notify("Notifications on", "Success", "Toasts will appear again.")
			else
				notify("Notifications off", "Info", "Toasts are now hidden.", true)
				State.Notifications = false
			end
		end,
	})

	-- OVERLAYS --------------------------------------------------------------
	-- The floating HUD widgets, as opposed to the panel's own appearance above.
	local overlays = Section(column, "Overlays")
	Toggle(overlays, {
		Text = "FPS overlay",
		Description = "Live FPS and ping at the top of the screen",
		Default = DEFAULTS.FpsOverlay,
		Callback = function(enabled)
			State.FpsOverlay = enabled
			fpsPill.Visible = enabled
			Metrics.refresh()
			logActivity("FPS overlay " .. (enabled and "on" or "off"), "HUD widget updated", "Info")
		end,
	})
	Toggle(overlays, {
		Text = "Crosshair",
		Description = "An accent-coloured crosshair in the screen centre",
		Default = DEFAULTS.Crosshair,
		Callback = function(enabled)
			State.Crosshair = enabled
			crosshair.Visible = enabled
			logActivity("Crosshair " .. (enabled and "on" or "off"), "HUD widget updated", "Info")
		end,
	})
	Slider(overlays, {
		Text = "Crosshair size",
		Min = 4, Max = 24, Default = DEFAULTS.CrosshairSize, Step = 1, Suffix = " px",
		Callback = function(value)
			State.CrosshairSize = value
			layoutCrosshair()
		end,
	})

	Toggle(overlays, {
		Text = "Show Quick Actions Overlay",
		Description = "Floating live status of Auto farm and Auto place. Drag it by its header",
		Default = false,
		Shared = "overlay",
	})
	Toggle(overlays, {
		Text = "AFK mode",
		Description = "Black screen over the game. Auto farm, Auto place, FPS Boost and audio keep running",
		Default = false,
		Shared = "afk",
		Persist = false,
		Reset = false,
	})
	Button(overlays, {
		Text = "Reset button position",
		Icon = "reset",
		Style = "Secondary",
		Callback = function()
			if Stats.Fab then
				Stats.Fab.Reset()
			end
		end,
	})
	Toggle(overlays, {
		Text = "AFK pauses 3D rendering",
		Description = "While AFK, stop drawing the world as well as hiding it. Restored when AFK ends",
		Default = DEFAULTS.AfkPause3D,
		Callback = function(enabled)
			State.AfkPause3D = enabled
			if Features.AFK then
				Features.AFK.Sync()
			end
		end,
	})
	Toggle(overlays, {
		Text = "Overlay farm details",
		Description = "Target, status and egg stats under the Quick Actions overlay",
		Default = DEFAULTS.QuickOverlayDetails,
		Callback = function(enabled)
			State.QuickOverlayDetails = enabled
			QuickOverlay.Render()
		end,
	})

	-- DIAGNOSTICS ----------------------------------------------------------
	-- Deliberate misbehaviour checks, kept next to the settings they verify
	-- rather than on the Home page where they would compete with the real
	-- status readouts.
	local diagnostics = Section(column, "Diagnostics")
	InfoRow(diagnostics, "Check the toasts", "One button per tone")
	local toneGrid = ButtonGrid(diagnostics, 3)
	for _, tone in ipairs(toneCycle) do
		Button(toneGrid, {
			Text = tone,
			Icon = TONES[tone].Icon,
			Style = tone == "Error" and "Danger" or "Secondary",
			Callback = function()
				notify(tone, tone, toneMessages[tone])
			end,
		})
	end
	local diagGrid = ButtonGrid(diagnostics, 2)
	Button(diagGrid, {
		Text = "Cycle accent", Icon = "sparkle",
		Callback = cycleAccent,
	})
	Button(diagGrid, {
		Text = "Clear activity", Icon = "trash",
		Callback = function()
			Stats.ClearActivity()
			notify("Activity cleared", "Info", "The Home feed is empty again.")
		end,
	})

	-- DEBUG MODE -----------------------------------------------------------
	-- Live health of every stage between "the egg exists" and "the farm
	-- collected it", so a failure can be located instead of guessed at. Rows
	-- stay hidden until Debug Mode is on, and nothing runs while it is off.
	local debugSection = Section(column, "Debug mode")
	-- One table instead of several locals: this block shares the main chunk's
	-- 200-local budget.
	local Debug = { Rows = {}, Cells = {}, Mark = { ok = "\u{2713}", off = "\u{25CB}", bad = "\u{2717}" } }
	function Debug.Row(key, title)
		local label = InfoRow(debugSection, title, "--", Theme.Color.TextMid)
		label.Parent.Visible = false
		table.insert(Debug.Rows, label.Parent)
		Debug.Cells[key] = label
	end
	function Debug.Paint()
		local on = State.DebugMode == true
		for _, row in ipairs(Debug.Rows) do
			row.Visible = on
		end
		if not on then
			return
		end
		local hub = Stats.Hub
		local data = hub and hub.Debug and hub.Debug()
		local function mark(label, check)
			if not check then
				label.Text = "--"
				label.TextColor3 = Theme.Color.TextLow
				return
			end
			label.Text = Debug.Mark[check.Kind] .. "  " .. check.Text
			label.TextColor3 = (check.Kind == "ok" and Theme.Color.Positive)
				or (check.Kind == "bad" and Theme.Color.Negative)
				or Theme.Color.TextLow
		end
		local function plain(label, text, color)
			label.Text = text or "--"
			label.TextColor3 = color or Theme.Color.TextHi
		end
		local function ago(seconds)
			return seconds and string.format("%.2fs ago", seconds) or "never"
		end
		mark(Debug.Cells.Scanner, data and data.Scanner)
		mark(Debug.Cells.Farm, data and data.Farm)
		mark(Debug.Cells.Place, data and data.Place)
		mark(Debug.Cells.ESP, data and data.ESP)
		mark(Debug.Cells.Character, data and data.Character)
		if data then
			local mismatch = data.Detected ~= data.Listed
			plain(
				Debug.Cells.Detected,
				string.format("%d   (list %d, farm can take %d)", data.Detected, data.Listed, data.Candidates),
				mismatch and Theme.Color.Caution or Theme.Color.TextHi
			)
			plain(Debug.Cells.Target, data.Target or "None", data.Target and Theme.Color.TextHi or Theme.Color.TextLow)
			plain(Debug.Cells.Status, data.Step)
			plain(Debug.Cells.Detection, ago(data.LastDetection), Theme.Color.TextMid)
			plain(Debug.Cells.Scan, ago(data.LastScan), (data.LastScan and data.LastScan > 2) and Theme.Color.Caution or Theme.Color.TextMid)
			plain(
				Debug.Cells.Recovery,
				data.Recoveries == 0 and "None" or (tostring(data.Recoveries) .. "  (" .. tostring(data.LastRecoveryWhy or "stuck") .. ")"),
				data.Recoveries == 0 and Theme.Color.TextMid or Theme.Color.Caution
			)
		else
			for _, key in ipairs({ "Detected", "Target", "Status", "Detection", "Scan", "Recovery" }) do
				plain(Debug.Cells[key], "--", Theme.Color.TextLow)
			end
		end
	end
	Toggle(debugSection, {
		Text = "Debug Mode",
		Description = "Live status of the scanner, farm, placer, ESP and your character",
		Default = DEFAULTS.DebugMode,
		Callback = function(enabled)
			State.DebugMode = enabled
			Debug.Paint()
		end,
	})
	Debug.Row("Scanner", "Egg Scanner")
	Debug.Row("Farm", "Auto Farm")
	Debug.Row("Place", "Auto Place")
	Debug.Row("ESP", "ESP")
	Debug.Row("Character", "Character")
	Debug.Row("Detected", "Eggs Detected")
	Debug.Row("Target", "Current Target")
	Debug.Row("Status", "Farm Status")
	Debug.Row("Detection", "Last Detection")
	Debug.Row("Scan", "Last Scan")
	Debug.Row("Recovery", "Stuck Recoveries")
	task.spawn(function()
		while screen.Parent do
			local page = pages.Settings
			if State.DebugMode and Gate.Authenticated and page and page.Group and page.Group.Visible then
				pcall(Debug.Paint)
			end
			task.wait(0.25)
		end
	end)

	local actions = Section(column, "Actions")
	Button(actions, {
		Text = "Reset UI",
		Icon = "reset",
		Style = "Danger",
		Callback = resetAll,
	})
	InfoRow(actions, "Toggle key", string.upper(CONFIG.ToggleKey.Name))
	InfoRow(actions, "Player", player.DisplayName)
	InfoRow(actions, "Account age", tostring(player.AccountAge) .. " days")
	InfoRow(actions, "Place ID", game.PlaceId == 0 and "Unpublished" or tostring(game.PlaceId))
	-- Read live from the join/leave listeners below, so it never goes stale.
	serverSizeLabel = InfoRow(actions, "Server size", playerCountText())
end

-- ABOUT -----------------------------------------------------------------
do
	local column = CreatePage("About")

	local hero = New("Frame", {
		Name = "Hero",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(column),
		Parent = column,
	})
	Round(hero, Theme.Radius.MD)
	AccentGradient(hero, 15, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.85),
	}))
	Stroke(hero, 0.85)
	Padding(hero, 18, 20, 18, 20)
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = hero,
	})
	-- Same Brandmark the sidebar and the gate use, so CONFIG.Logo propagates to
	-- the About page without being restated here.
	Brandmark(hero, 44, { LayoutOrder = nextOrder(hero) })
	Text(hero, CONFIG.Title, Theme.Type.Title, "Bold", Theme.Color.TextHi, {
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = nextOrder(hero),
	})
	Text(hero, "Author: " .. CONFIG.Author, Theme.Type.Body, "SemiBold", Theme.Color.TextMid, {
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = nextOrder(hero),
	})
	Text(hero,
		"A self-contained interface built entirely in Luau. It includes animated tabs, reusable toggles, sliders and buttons, a toast system, live stats and a layout that adapts from desktop to phone. Every control in the Eggs, Automation, Visuals and Settings tabs drives real interface behaviour.",
		Theme.Type.Body, "Regular", Theme.Color.TextMid, {
			Wrap = true,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = nextOrder(hero),
		})

	local details = Section(column, "Details")
	InfoRow(details, "Version", CONFIG.Version)
	InfoRow(details, "Author", CONFIG.Author)
	InfoRow(details, "Script type", "LocalScript")
	InfoRow(details, "Toggle shortcut", string.upper(CONFIG.ToggleKey.Name))
	InfoRow(details, "Logo", CONFIG.LogoStatus or "Not loaded",
		CONFIG.ResolvedLogo and Theme.Color.TextHi or Theme.Color.Caution)
	InfoRow(details, "Assets required", "None", Theme.Color.Positive)
end

-- CONFIGS ----------------------------------------------------------------
-- Config manager. Configs are JSON files under ModernGui/configs in the
-- executor workspace; without file access they fall back to session memory so
-- the buttons still work. The old Utilities section moved to the Automation
-- page, which is where the other run-and-leave features live.
function Config.BuildConfigs()
	local column = CreatePage("Configs")

	local HttpService = game:GetService("HttpService")
	local DIR = "ModernGui/configs"
	local INDEX = DIR .. "/_index.json"
	local memory = {}

	local Store = {}
	Store.Persistent = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local canList = type(listfiles) == "function"

	local function ensureDir()
		if not Store.Persistent then
			return
		end
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" then
				if not isfolder("ModernGui") then
					makefolder("ModernGui")
				end
				if not isfolder(DIR) then
					makefolder(DIR)
				end
			end
		end)
	end

	local function pathOf(name)
		return DIR .. "/" .. name .. ".json"
	end

	-- Without listfiles the names are tracked in a small index file instead.
	local function readIndex()
		local names = {}
		if Store.Persistent and pcall(isfile, INDEX) and isfile(INDEX) then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(readfile(INDEX))
			end)
			if ok and type(decoded) == "table" then
				for _, name in ipairs(decoded) do
					if type(name) == "string" then
						table.insert(names, name)
					end
				end
			end
		end
		return names
	end

	local function writeIndex(names)
		pcall(function()
			writefile(INDEX, HttpService:JSONEncode(names))
		end)
	end

	function Store.Exists(name)
		if Store.Persistent then
			local ok, result = pcall(isfile, pathOf(name))
			return ok and result == true
		end
		return memory[name] ~= nil
	end

	function Store.Read(name)
		if Store.Persistent then
			if not Store.Exists(name) then
				return false, "missing"
			end
			local ok, result = pcall(readfile, pathOf(name))
			if ok and type(result) == "string" then
				return true, result
			end
			return false, tostring(result)
		end
		if memory[name] then
			return true, memory[name]
		end
		return false, "missing"
	end

	function Store.Write(name, text)
		if Store.Persistent then
			ensureDir()
			local ok, err = pcall(writefile, pathOf(name), text)
			if not ok then
				return false, tostring(err)
			end
			-- The index is kept even when listfiles exists: it is the second
			-- source Store.List falls back on if a scan comes back short.
			local names = readIndex()
			if not table.find(names, name) then
				table.insert(names, name)
				writeIndex(names)
			end
			return true
		end
		memory[name] = text
		return true
	end

	function Store.Delete(name)
		if Store.Persistent then
			if type(delfile) ~= "function" then
				return false, "delfile is unavailable in this executor"
			end
			local ok, err = pcall(delfile, pathOf(name))
			if not ok then
				return false, tostring(err)
			end
			local names = readIndex()
			local at = table.find(names, name)
			if at then
				table.remove(names, at)
				writeIndex(names)
			end
			return true
		end
		memory[name] = nil
		return true
	end

	-- Lists saved configs from every source available and merges them: a
	-- listfiles scan (tried against a few path spellings, since executors
	-- differ) and the index file. Relying on only one is what made saved
	-- configs vanish until a new one was created.
	function Store.List()
		local names, seen = {}, {}
		local function add(name)
			if name and name ~= "" and name:sub(1, 1) ~= "_" and not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
		if Store.Persistent then
			ensureDir()
			local indexed = readIndex()
			if canList then
				local function scan(folder, mustBeInConfigs)
					local ok, files = pcall(listfiles, folder)
					if not ok or type(files) ~= "table" then
						return
					end
					for _, path in ipairs(files) do
						path = tostring(path)
						local file = path:match("([^/\\]+)$")
						local name = file and file:match("^(.+)%.json$")
						if name and (not mustBeInConfigs or path:lower():find("configs", 1, true)) then
							add(name)
						end
					end
				end
				scan(DIR)
				if #names == 0 then
					scan(DIR .. "/")
				end
				if #names == 0 then
					scan("ModernGui", true)
				end
			end
			-- Anything the index knows about that still exists on disk.
			for _, name in ipairs(indexed) do
				if Store.Exists(name) then
					add(name)
				end
			end
			-- A config saved before the index existed is added to it now, so the
			-- two sources agree from here on.
			local missing = false
			for _, name in ipairs(names) do
				if not table.find(indexed, name) then
					missing = true
					break
				end
			end
			if missing then
				writeIndex(names)
			end
		else
			for name in pairs(memory) do
				add(name)
			end
		end
		table.sort(names, function(a, b)
			return a:lower() < b:lower()
		end)
		return names
	end

	-- Automation switches are restored LAST, not in the same pass as everything
	-- else - see Config.Apply. They are no longer opt-in: loading a config puts
	-- every module back the way the user left it. The keys must match the
	-- Toggle text exactly, since Config looks controls up by their label.
	local AUTOMATION = {
		["Auto farm"] = true,
		["Auto Max Upgrade"] = true,
		["Auto place"] = true,
	}
	local restoreAutomation = true

	function Config.Collect()
		local data = { version = 1, script = CONFIG.Version, controls = {}, state = {} }
		for key, control in pairs(Config.Controls) do
			local ok, value = pcall(control.Get)
			if ok and (type(value) == "boolean" or type(value) == "number") then
				data.controls[key] = value
			end
		end
		data.state = {
			AccentIndex = State.AccentIndex,
			AccentName = ACCENTS[State.AccentIndex] and ACCENTS[State.AccentIndex].Name or nil,
			AccentHue = State.AccentHue,
			BgPreset = State.BgPreset,
			BgHue = State.BgHue,
			BgSat = State.BgSat,
			BgVal = State.BgVal,
		}
		if Config.Extra and Config.Extra.Collect then
			local ok, extra = pcall(Config.Extra.Collect)
			if ok then
				data.extra = extra
			end
		end
		return data
	end

	-- Restores one control if the stored value matches its kind. Returns whether
	-- it was actually applied so the caller can count it.
	local function applyControl(control, value)
		local wanted = control.Kind == "toggle" and "boolean" or "number"
		if type(value) ~= wanted then
			return false
		end
		return (pcall(control.Set, value))
	end

	-- Returns how many controls were restored and how many were skipped
	-- (unknown key, wrong type, or automation turned off by the opt-out switch).
	--
	-- Three passes, in this order, and the order matters. Controls came out of a
	-- pairs() loop before, which is random: Auto farm could be switched on before
	-- the rarity filters it depends on were restored, so it would wake up and grab
	-- an egg the loaded config had not selected. Passive settings first, theme and
	-- egg extras second, automation last.
	function Config.Apply(data)
		local applied, skipped = 0, 0
		local controls = type(data.controls) == "table" and data.controls or {}
		Config.Loading = true
		Bg.Silent = true
		for key, control in pairs(Config.Controls) do
			if not AUTOMATION[key] then
				if applyControl(control, controls[key]) then
					applied = applied + 1
				else
					skipped = skipped + 1
				end
			end
		end
		Bg.Silent = false

		local state = type(data.state) == "table" and data.state or {}
		pcall(function()
			if type(state.BgHue) == "number" then
				State.BgHue = state.BgHue
			end
			if type(state.BgSat) == "number" then
				State.BgSat = state.BgSat
			end
			if type(state.BgVal) == "number" then
				State.BgVal = state.BgVal
			end
			if type(state.BgPreset) == "number" then
				State.BgPreset = Bg.Presets[state.BgPreset] and state.BgPreset or 0
			end
			Bg.Apply()
			if type(state.AccentHue) == "number" then
				State.AccentHue = state.AccentHue
			end
			-- By name first: indexes moved when themes were added. A config saved
			-- before that has no name, and its "Custom" slot (6) is now last.
			local accentIndex = nil
			if type(state.AccentName) == "string" then
				for index, accent in ipairs(ACCENTS) do
					if accent.Name == state.AccentName then
						accentIndex = index
					end
				end
			end
			if not accentIndex and type(state.AccentIndex) == "number" and ACCENTS[state.AccentIndex] then
				accentIndex = state.AccentIndex
				if state.AccentName == nil and state.AccentIndex == 6 then
					accentIndex = #ACCENTS
				end
			end
			if accentIndex then
				setAccent(accentIndex)
			end
		end)
		if type(data.extra) == "table" and Config.Extra and Config.Extra.Apply then
			pcall(Config.Extra.Apply, data.extra)
		end

		-- Automation last, now that its rarities and filters are already correct.
		-- Config.Loading is still true, so these start quietly instead of firing a
		-- toast per module; loadConfig reports the result once at the end.
		for key, control in pairs(Config.Controls) do
			if AUTOMATION[key] then
				if restoreAutomation and applyControl(control, controls[key]) then
					applied = applied + 1
				else
					skipped = skipped + 1
				end
			end
		end
		Config.Loading = false
		return applied, skipped
	end

	local function cleanName(raw)
		local name = tostring(raw or "")
		name = name:gsub("[^%w _%-]", "")
		name = name:gsub("^%s+", "")
		name = name:gsub("%s+$", "")
		return name:sub(1, 32)
	end

	-- UI ---------------------------------------------------------------
	local selected = nil
	local loaded = nil
	local filter = ""
	local rows = {}
	local names = {}

	local manager = Section(column, "Config manager")
	local selectedRow = InfoRow(manager, "Selected", "None", Theme.Color.TextHi)
	local loadedRow = InfoRow(manager, "Loaded", "None", Theme.Color.TextHi)
	InfoRow(manager, "Storage",
		Store.Persistent and "Executor workspace" or "Session only",
		Store.Persistent and Theme.Color.Positive or Theme.Color.Caution)

	local function makeBox(parent, placeholder)
		local frame = New("Frame", {
			Name = "Input",
			BackgroundColor3 = Theme.Color.Alt,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = nextOrder(parent),
			Parent = parent,
		})
		Round(frame, Theme.Radius.SM)
		local stroke = Stroke(frame, 0.85)
		local box = New("TextBox", {
			Name = "Box",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			ClearTextOnFocus = false,
			PlaceholderText = placeholder,
			PlaceholderColor3 = Theme.Color.TextLow,
			Text = "",
			TextColor3 = Theme.Color.TextHi,
			TextSize = Theme.Type.Caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		applyFont(box, "Medium")
		box.Focused:Connect(function()
			play(stroke, Motion.Quick, "Out", { Color = Accent.Color, Transparency = 0.35 })
		end)
		box.FocusLost:Connect(function()
			play(stroke, Motion.Quick, "Out", { Color = Theme.Color.White, Transparency = 0.85 })
		end)
		return box
	end

	local nameBox = makeBox(manager, "New config name...")
	local actionGrid = ButtonGrid(manager, 2)

	local listSection = Section(column, "Saved configs")
	local countRow = InfoRow(listSection, "Configs", "0", Theme.Color.TextHi)
	local filterBox = makeBox(listSection, "Filter configs...")

	local listFrame = New("ScrollingFrame", {
		Name = "ConfigList",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 190),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Color.White,
		ScrollBarImageTransparency = 0.7,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		LayoutOrder = nextOrder(listSection),
		Parent = listSection,
	})
	Round(listFrame, Theme.Radius.SM)
	Padding(listFrame, 4, 4, 4, 4)
	local listColumn = New("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = listFrame,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = listColumn,
	})
	local emptyLabel = Text(listColumn, "No configs yet. Type a name and press Create.", Theme.Type.Caption,
		"Regular", Theme.Color.TextLow, {
			Size = UDim2.new(1, 0, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			Wrap = true,
		})

	local function paintRows()
		for _, row in pairs(rows) do
			local isSelected = row.Name == selected
			local isLoaded = row.Name == loaded
			play(row.Button, Motion.Swift, "Out", {
				BackgroundTransparency = isSelected and 0.72 or 0.9,
				BackgroundColor3 = isSelected and Accent.Color or Theme.Color.White,
			})
			row.Stroke.Color = isSelected and Accent.Color or Theme.Color.White
			row.Stroke.Transparency = isSelected and 0.25 or 0.9
			row.Bar.Visible = isSelected
			row.Bar.BackgroundColor3 = Accent.Color
			row.Label.TextColor3 = isSelected and Theme.Color.TextHi or Theme.Color.TextMid
			row.Tag.Visible = isLoaded
			row.Tag.TextColor3 = Accent.Text
		end
		selectedRow.Text = selected or "None"
		selectedRow.TextColor3 = selected and Accent.Text or Theme.Color.TextLow
		loadedRow.Text = loaded or "None"
		loadedRow.TextColor3 = loaded and Theme.Color.Positive or Theme.Color.TextLow
	end
	bindAccent(paintRows)

	local function refreshList()
		names = Store.List()
		if selected and not table.find(names, selected) then
			selected = nil
		end
		if loaded and not table.find(names, loaded) then
			loaded = nil
		end
		for _, row in pairs(rows) do
			row.Button:Destroy()
		end
		table.clear(rows)
		local shown = 0
		local query = filter:lower()
		for index, name in ipairs(names) do
			if query == "" or name:lower():find(query, 1, true) then
				shown = shown + 1
				local button = New("TextButton", {
					Name = "Config_" .. name,
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Theme.Color.White,
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = index,
					Parent = listColumn,
				})
				Round(button, Theme.Radius.SM)
				local stroke = Stroke(button, 0.9)
				local bar = New("Frame", {
					BackgroundColor3 = Accent.Color,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(3, 18),
					Visible = false,
					Parent = button,
				})
				Round(bar, Theme.Radius.Pill)
				local label = Text(button, name, Theme.Type.Body, "Medium", Theme.Color.TextMid, {
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.new(1, -100, 1, 0),
				})
				local tag = Text(button, "LOADED", Theme.Type.Micro, "SemiBold", Accent.Text, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 0),
					Size = UDim2.fromOffset(70, 34),
					TextXAlignment = Enum.TextXAlignment.Right,
					Visible = false,
				})
				attachFeedback(button, { Rest = 0.9, Hover = 0.84, Press = 0.78 })
				button.Activated:Connect(function()
					selected = name
					nameBox.Text = ""
					paintRows()
				end)
				rows[name] = { Name = name, Button = button, Stroke = stroke, Bar = bar, Label = label, Tag = tag }
			end
		end
		emptyLabel.Visible = shown == 0
		emptyLabel.Text = #names == 0 and "No configs yet. Type a name and press Create."
			or "No configs match that filter."
		countRow.Text = shown == #names and tostring(#names) or (tostring(shown) .. " / " .. tostring(#names))
		paintRows()
	end

	track(filterBox:GetPropertyChangedSignal("Text"):Connect(function()
		filter = filterBox.Text
		refreshList()
	end))

	local function writeConfig(name)
		local encoded, text = pcall(function()
			return HttpService:JSONEncode(Config.Collect())
		end)
		if not encoded then
			return false, "settings could not be encoded"
		end
		return Store.Write(name, text)
	end

	local function createConfig()
		local name = cleanName(nameBox.Text)
		if name == "" then
			notify("Name required", "Warning", "Type a config name (letters, numbers, spaces, - and _).")
			return
		end
		if Store.Exists(name) then
			notify("Config exists", "Warning", "\"" .. name .. "\" already exists. Select it and press Save to overwrite.")
			return
		end
		local ok, err = writeConfig(name)
		if not ok then
			notify("Create failed", "Error", tostring(err))
			return
		end
		nameBox.Text = ""
		selected, loaded = name, name
		refreshList()
		notify("Config created", "Success", "\"" .. name .. "\" holds your current settings.")
	end

	local function saveConfig()
		local name = selected or loaded
		if not name then
			notify("No config selected", "Warning", "Select a config from the list, or create a new one.")
			return
		end
		local ok, err = writeConfig(name)
		if not ok then
			notify("Save failed", "Error", tostring(err))
			return
		end
		loaded = name
		selected = selected or name
		refreshList()
		notify("Config saved", "Success", "\"" .. name .. "\" was overwritten with the current settings.")
	end

	-- Reads, validates and applies one saved config. Used by the Load button and
	-- by the startup loader, so there is exactly one way a config goes in.
	-- Returns applied, skipped on success, or nil and a reason. A setting the
	-- config holds that no longer exists is simply never looked up (Config.Apply
	-- walks the controls that DO exist), a wrong-typed value is skipped, and a
	-- failure in the middle cannot leave notifications muted.
	local function loadByName(name)
		local ok, text = Store.Read(name)
		if not ok then
			refreshList()
			return nil, "missing"
		end
		local decoded, data = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if not decoded or type(data) ~= "table" or type(data.controls) ~= "table" then
			return nil, "invalid"
		end
		local worked, applied, skipped = pcall(Config.Apply, data)
		if not worked then
			Config.Loading = false
			Bg.Silent = false
			return nil, "failed: " .. tostring(applied)
		end
		loaded = name
		paintRows()
		return applied, skipped
	end

	local function loadConfig()
		local name = selected
		if not name then
			notify("No config selected", "Warning", "Pick a config from the list first.")
			return
		end
		local applied, skipped = loadByName(name)
		if not applied then
			if skipped == "missing" then
				notify("Config missing", "Warning", "\"" .. name .. "\" could not be found. It may have been deleted.")
			elseif skipped == "invalid" then
				notify("Config invalid", "Error", "\"" .. name .. "\" is corrupted or not a settings file. Nothing was changed.")
			else
				notify("Config failed", "Error", tostring(skipped))
			end
			return
		end
		notify("Config loaded", "Success",
			string.format("\"%s\": %d settings restored%s.", name, applied,
				skipped > 0 and (", " .. skipped .. " left as they were") or ""))
		logActivity("Config loaded", name, "Info")
	end

	local deleteArmed = 0
	local deleteButton
	local function deleteConfig()
		local name = selected
		if not name then
			notify("No config selected", "Warning", "Pick a config from the list first.")
			return
		end
		-- Two clicks: the first arms the button, so a stray tap cannot delete.
		if deleteArmed == 0 then
			deleteArmed = os.clock()
			deleteButton.SetText("Confirm delete?")
			local stamp = deleteArmed
			task.delay(3, function()
				if deleteArmed == stamp then
					deleteArmed = 0
					deleteButton.SetText("Delete Config")
				end
			end)
			return
		end
		deleteArmed = 0
		deleteButton.SetText("Delete Config")
		local ok, err = Store.Delete(name)
		if not ok then
			notify("Delete failed", "Error", tostring(err))
			return
		end
		if loaded == name then
			loaded = nil
		end
		selected = nil
		refreshList()
		notify("Config deleted", "Success", "\"" .. name .. "\" was removed.")
	end

	Button(actionGrid, { Text = "Create Config", Icon = "sparkle", Style = "Primary", Callback = createConfig })
	Button(actionGrid, { Text = "Save Config", Icon = "check", Callback = saveConfig })
	Button(actionGrid, { Text = "Load Config", Icon = "reset", Callback = loadConfig })
	deleteButton = Button(actionGrid, { Text = "Delete Config", Icon = "close", Style = "Danger", Callback = deleteConfig })

	-- STARTUP + RESUME ----------------------------------------------------
	-- Two small files beside the configs, never part of a config (a config
	-- that decided whether configs load could not be read to find out):
	--   startup.json  { auto = bool, name = "MainConfig" }  the user's choice
	--   resume.json   { at, placeId, afk, data = <Config.Collect()> }  written by
	--                 a server hop just before it leaves, read once by the next
	--                 server, and only if it is fresh.
	-- Only settings go in: Config.Collect holds toggles, sliders, theme and the
	-- egg preferences, never a target, a status, a server or a teleport state.
	local STARTUP_PATH = "ModernGui/startup.json"
	local RESUME_PATH = "ModernGui/resume.json"
	local RESUME_MAX_AGE = 300 -- seconds; an older file is from some other session
	Config.Startup = { Auto = false, Name = nil }

	local function readJson(path)
		if not Store.Persistent or not pcall(isfile, path) or not isfile(path) then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		return ok and type(decoded) == "table" and decoded or nil
	end
	local function writeJson(path, value)
		if not Store.Persistent then
			return false
		end
		ensureDir()
		return pcall(function()
			writefile(path, HttpService:JSONEncode(value))
		end)
	end
	do
		local saved = readJson(STARTUP_PATH)
		if saved then
			Config.Startup.Auto = saved.auto == true
			Config.Startup.Name = type(saved.name) == "string" and saved.name or nil
		end
	end
	local function saveStartup()
		writeJson(STARTUP_PATH, { auto = Config.Startup.Auto, name = Config.Startup.Name })
	end

	function Config.SaveResume(snapshot)
		writeJson(RESUME_PATH, {
			at = os.time(),
			placeId = game.PlaceId,
			afk = State.Afk == true,
			data = snapshot or Config.Collect(),
		})
	end

	function Config.ClearResume()
		if type(delfile) == "function" and Store.Persistent then
			pcall(function()
				if isfile(RESUME_PATH) then
					delfile(RESUME_PATH)
				end
			end)
		else
			writeJson(RESUME_PATH, {})
		end
	end

	-- Runs once, after the access gate: the interface is built, every control is
	-- registered and the egg scanner has had its first pass.
	--   1. the startup config, if Auto Load Config is on and one is chosen;
	--   2. the snapshot a server hop left, if it is fresh. It wins over (1)
	--      because it is what was running moments ago.
	-- Either one only applies what still exists, so an old file cannot break
	-- the new server's GUI.
	function Config.RunStartup()
		local notes = {}
		if Config.Startup.Auto and Config.Startup.Name then
			local applied, skipped = loadByName(Config.Startup.Name)
			if applied then
				table.insert(notes, "config \"" .. Config.Startup.Name .. "\"")
			elseif skipped == "missing" then
				notify("Startup config missing", "Warning",
					"\"" .. Config.Startup.Name .. "\" no longer exists. Pick another under Configs.", true)
			else
				notify("Startup config not loaded", "Warning", tostring(skipped), true)
			end
		end

		local resume = readJson(RESUME_PATH)
		if resume then
			-- Consumed either way, so it can never be replayed by a later start.
			if type(delfile) == "function" then
				pcall(delfile, RESUME_PATH)
			else
				writeJson(RESUME_PATH, {})
			end
			local fresh = type(resume.at) == "number" and math.abs(os.time() - resume.at) <= RESUME_MAX_AGE
			if fresh and type(resume.data) == "table" and type(resume.data.controls) == "table" then
				local worked = pcall(Config.Apply, resume.data)
				if worked then
					table.insert(notes, "your settings from before the hop")
				else
					Config.Loading = false
					Bg.Silent = false
				end
				if resume.afk == true then
					Features.Set("afk", true)
				end
			end
		end

		if #notes > 0 then
			notify("Settings restored", "Success", "Loaded " .. table.concat(notes, " and ") .. ".", true)
			logActivity("Startup restore", table.concat(notes, ", "), "Info")
		end
		-- Every view repaints from the shared state, whatever the load changed.
		Features.Changed(nil)
		QuickOverlay.Dirty()
	end

	local autoLoad = Features.ByKey.autoload
	autoLoad.Get = function()
		return Config.Startup.Auto == true
	end
	autoLoad.Set = function(enabled)
		Config.Startup.Auto = enabled == true
		saveStartup()
		if Config.Startup.Auto and not Config.Startup.Name then
			notify("Choose a startup config", "Warning",
				"Auto Load Config is on, but no startup config is chosen yet. Select one and press Use as Startup.", true)
		end
	end

	local options = Section(column, "Config options")
	Toggle(options, {
		Text = "Auto Load Config",
		Description = "Loads the startup config below when this script starts",
		Default = false,
		Shared = "autoload",
		Persist = false,
		Reset = false,
	})
	local startupDropdown = Dropdown(options, {
		Text = "Startup config",
		Empty = "None chosen",
		EmptyHint = "Save a config first, then choose it here.",
		Options = function()
			return Store.List()
		end,
		Get = function()
			return Config.Startup.Name
		end,
		Set = function(name)
			Config.Startup.Name = name
			saveStartup()
			Features.Changed("autoload")
			notify("Startup config set", "Success", "\"" .. name .. "\" loads when Auto Load Config is on.")
		end,
	})
	local function paintStartup()
		startupDropdown.Refresh()
	end
	paintStartup()
	local startupGrid = ButtonGrid(options, 2)
	Button(startupGrid, {
		Text = "Use as Startup",
		Icon = "check",
		Callback = function()
			local name = selected
			if not name then
				notify("No config selected", "Warning", "Select a config from the list first.")
				return
			end
			Config.Startup.Name = name
			saveStartup()
			paintStartup()
			notify("Startup config set", "Success", "\"" .. name .. "\" loads when Auto Load Config is on.")
		end,
	})
	Button(startupGrid, {
		Text = "Clear Startup",
		Icon = "close",
		Style = "Secondary",
		Callback = function()
			Config.Startup.Name = nil
			saveStartup()
			paintStartup()
			Features.Changed("autoload")
		end,
	})
	Features.Changed("autoload")
	Toggle(options, {
		Text = "Restore automation on load",
		Description = "On by default: re-enables Auto farm, Auto place and Auto Max Upgrade after a config loads, once its rarities are already set",
		Default = true,
		Persist = false,
		Reset = false,
		Callback = function(enabled)
			restoreAutomation = enabled
		end,
	})
	InfoRow(options, "Saved", "Toggles, sliders, rarities, eggs, theme", Theme.Color.TextMid)

	-- UTILITIES -------------------------------------------------------
	refreshList()

	-- The list used to be read once, at build time, and then only after a
	-- create / save / delete, so a scan that came back short (the executor's
	-- workspace not ready yet) stayed wrong. It is now re-read shortly after
	-- startup and every time the Configs page is opened; the rows are only
	-- rebuilt if the list actually changed.
	local function rescan()
		local latest = Store.List()
		local same = #latest == #names
		if same then
			for index, name in ipairs(latest) do
				if names[index] ~= name then
					same = false
					break
				end
			end
		end
		if not same then
			refreshList()
		end
	end
	for _, delay in ipairs({ 1, 4 }) do
		task.delay(delay, function()
			if column.Parent then
				pcall(rescan)
			end
		end)
	end
	local page = pages["Configs"]
	if page and page.Group then
		track(page.Group:GetPropertyChangedSignal("Visible"):Connect(function()
			if page.Group.Visible then
				pcall(rescan)
			end
		end))
	end
	return column
end
-- TOOLS -------------------------------------------------------------------
-- Egg scanner: live ESP (name + distance at any range), a searchable and
-- sortable list grouped by egg type, direct teleports, and an auto farm
-- that walks to marked eggs, presses E and returns to the player's plot.
-- Own function = separate 200-local budget (main chunk exceeded Lua's limit).
local function buildToolsPage()
	-- Two pages off one module: everything about reading the world (scanner,
	-- list, overlay, teleports) on one, everything that acts on it (farm,
	-- place, upgrades, hop, utilities) on the other.
	local column = CreatePage("Eggs")
	local autoColumn = CreatePage("Automation")

	-- VirtualInputManager is only used to press E for the auto farm. If the
	-- service is unavailable the rest of the page still works.
	local virtualInput = nil
	do
		local ok, service = pcall(function()
			return game:GetService("VirtualInputManager")
		end)
		if ok then
			virtualInput = service
		end
	end

	local UPDATE_RATE = 0.2
	-- Plots are expensive to walk, so the folder is searched a bounded number of
	-- times. The budget is handed back on a respawn and whenever the folder is
	-- replaced, so a plot that streamed in late is still found.
	local MAX_PLOT_SCANS = 8
	-- A hatch needs the character in range and the key press to register. The
	-- press is retried this many times before an egg is given up on.
	local PICKUP_ATTEMPTS = 3
	-- The game only exposes the Place prompt once an egg tool is in hand, so it is
	-- looked for a few times over rather than once.
	local PLACE_ATTEMPTS = 6

	local Eggs = {
		Folder = workspace:FindFirstChild("RenderedEggs"),
		Plots = workspace:FindFirstChild("Plots"),
		ESPs = {},
		Entries = {},
		Groups = {},
		Running = true,
		GlobalESP = DEFAULTS.EggsESP,
		ShowHighlight = DEFAULTS.EggsHighlight,
		HeightOffset = DEFAULTS.EggsTPHeight,
		SmoothMove = DEFAULTS.EggsSmoothMove,
		MoveSpeed = DEFAULTS.EggsMoveSpeed,
		HoldTime = DEFAULTS.EggsHoldTime,
		FarmTypes = {},
		FarmRarities = {},
		Processed = {},
		FarmActive = false,
		FarmThread = nil,
		Moving = false,
		MoveHumanoid = nil,
		CollideState = nil,
		CachedPlot = nil,
		CachedBaseplate = nil,
		PlotScans = 0,
		Query = "",
		SortBy = "Best",
		TypeESPOff = {},
		WatchConns = {},
		FarmState = "Idle",
		HomeKey = Enum.KeyCode.T,
		Listening = false,
		Total = 0,
		-- Live registry. One event-fed set of the eggs currently in the world,
		-- weak-keyed so an egg that leaves without ever firing an event cannot
		-- be held alive here. The list, the overlay, Auto Farm and Auto Place
		-- all read this instead of each walking the workspace themselves.
		Live = setmetatable({}, { __mode = "k" }),
		Version = 0,
		Waiters = {},
		-- Counters behind the Home page's egg statistics.
		-- Best / Recent / RecentVersion are runtime-only: the best egg this
		-- session's farm actually collected, and the last few it collected.
		Counters = { Detected = 0, Farmed = 0, Placed = 0, ByRarity = {}, Best = nil, Recent = {}, RecentVersion = 0 },
		-- Structured mirror of the farm's state, published to the Home card.
		Card = {
			Active = false,
			Phase = "off",
			Target = nil,
			Rarity = nil,
			Distance = nil,
			Message = "Auto farm is off",
		},
		PlaceRarities = {},
		PlaceActive = false,
		PlaceThread = nil,
		PlaceHolder = nil,
		PlaceSlots = DEFAULTS.EggsPlaceSlots,
		PlaceLimit = 1,
		PlaceDiscovered = false,
		PlaceMissed = 0,
		-- Runtime-only health data for the scanner indicator and Debug Mode.
		Diag = { LastScan = nil, LastDetection = nil, Recoveries = 0, LastRecovery = nil, LastRecoveryWhy = nil },
	}

	-- UTILITY --------------------------------------------------------------

	local function isFinite(value)
		return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
	end

	local function isValidPosition(position)
		if typeof(position) ~= "Vector3" then
			return false
		end
		return isFinite(position.X) and isFinite(position.Y) and isFinite(position.Z)
	end

	local function characterRoot()
		local character = player.Character
		if not character then
			return nil
		end
		return character:FindFirstChild("HumanoidRootPart")
	end

	-- Any egg can expose its anchor differently, so PrimaryPart, the usual
	-- root names and finally the first BasePart are all tried.
	local function getRootPart(model)
		if not model or not model:IsA("Model") then
			return nil
		end
		if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
			return model.PrimaryPart
		end
		local root = model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("RootPart")
			or model:FindFirstChild("Handle")
		if root and root:IsA("BasePart") then
			return root
		end
		return model:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Egg rarity is read from the game's own data module, the same one the
	-- eggName chat command uses, so it always matches the live game. The
	-- require is optional: if it is unavailable the table below is used, which
	-- is a copy of ReplicatedStorage.GameData.Eggs taken from the game.
	local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Ethereal" }
	local RARITY_RANK = {}
	for rank, name in ipairs(RARITY_ORDER) do
		RARITY_RANK[name] = rank
	end

	-- Increasing prestige, so rarity is readable at a glance without relying on
	-- the sort order.
	local RARITY_COLORS = {
		Common = Color3.fromRGB(170, 178, 192),
		Rare = Color3.fromRGB(96, 165, 250),
		Epic = Color3.fromRGB(167, 139, 250),
		Legendary = Color3.fromRGB(245, 190, 66),
		Mythic = Color3.fromRGB(244, 114, 182),
		Divine = Color3.fromRGB(94, 206, 222),
		Ethereal = Color3.fromRGB(74, 222, 128),
	}

	local FALLBACK_RARITY = {
		["White Egg"] = "Common",
		["Brown Egg"] = "Common",
		["Cracked Egg"] = "Rare",
		["Easter Egg"] = "Rare",
		["Stone Egg"] = "Rare",
		["Leaf Egg"] = "Rare",
		["Mushroom Egg"] = "Epic",
		["Flower Egg"] = "Epic",
		["Slime Egg"] = "Epic",
		["Ice Egg"] = "Epic",
		["Glass Egg"] = "Legendary",
		["Golden Egg"] = "Legendary",
		["Diamond Egg"] = "Mythic",
		["Crystal Egg"] = "Mythic",
		["Skull Egg"] = "Mythic",
		["Asteroid Egg"] = "Mythic",
		["Dominus Egg"] = "Mythic",
		["Flaming Egg"] = "Mythic",
		["Sinister Egg"] = "Mythic",
		["Soul Egg"] = "Mythic",
		["Tidal Egg"] = "Mythic",
		["Aurora Egg"] = "Divine",
		["Galaxy Egg"] = "Divine",
		["Bloom Egg"] = "Divine",
		["Blackhole Egg"] = "Ethereal",
		["Solaris Egg"] = "Ethereal",
		["Cherub Egg"] = "Ethereal",
		["Volcanic Egg"] = "Ethereal",
		["Dragon Egg"] = "Ethereal",
		["Giant Egg"] = "Ethereal",
	}

	local eggData = nil
	do
		-- Timeouts on purpose: this runs while the page is being built, and an
		-- unbounded WaitForChild would hang the whole interface if the module is
		-- ever renamed or removed.
		local ok, data = pcall(function()
			local replicated = game:GetService("ReplicatedStorage")
			return require(replicated:WaitForChild("GameData", 5):WaitForChild("Eggs", 5))
		end)
		if ok and type(data) == "table" then
			eggData = data
		end
	end

	local function rarityOf(eggName)
		if eggData then
			local entry = eggData[eggName]
			if type(entry) == "table" and type(entry.Rarity) == "string" then
				return entry.Rarity
			end
		end
		return FALLBACK_RARITY[eggName] or "Unknown"
	end

	-- The picker lists the game's real rarities, not just the seven this script
	-- shipped with: anything Eggs reports that is missing from RARITY_ORDER is
	-- appended and given a rank and a colour, so a rarity added by the game
	-- still shows up and still sorts.
	local RARITY_LIST = {}
	do
		local seen = {}
		for _, rarity in ipairs(RARITY_ORDER) do
			table.insert(RARITY_LIST, rarity)
			seen[rarity] = true
		end
		if eggData then
			local extra = {}
			for _, entry in pairs(eggData) do
				if type(entry) == "table" and type(entry.Rarity) == "string" then
					local rarity = entry.Rarity
					if not seen[rarity] then
						seen[rarity] = true
						table.insert(extra, rarity)
					end
				end
			end
			table.sort(extra)
			for _, rarity in ipairs(extra) do
				table.insert(RARITY_LIST, rarity)
			end
		end
		for rank, rarity in ipairs(RARITY_LIST) do
			if not RARITY_RANK[rarity] then
				RARITY_RANK[rarity] = rank
			end
			if not RARITY_COLORS[rarity] then
				-- Deterministic colour from the name, so an unknown rarity is
				-- still readable instead of rendering as flat grey.
				local hash = 0
				for index = 1, #rarity do
					hash = (hash * 31 + rarity:byte(index)) % 997
				end
				RARITY_COLORS[rarity] = Color3.fromHSV((hash % 360) / 360, 0.55, 0.92)
			end
		end
	end

	-- 0 for anything unknown, which sorts last under the rarity mode.
	local function rarityRank(eggName)
		return RARITY_RANK[rarityOf(eggName)] or 0
	end

	-- "Best" ranks by rarity first, then by the egg's price when the game data
	-- exposes one (Price / Cost), then by name.
	local function eggPrice(eggName)
		if eggData then
			local entry = eggData[eggName]
			if type(entry) == "table" then
				local price = entry.Price or entry.Cost or entry.Value
				if type(price) == "number" then
					return price
				end
			end
		end
		return 0
	end

	-- Called by the farm once a pickup is confirmed, and only then. "Best" is
	-- the egg with the highest value the game's own data exposes (the price);
	-- rarity rank only breaks a tie or stands in when the game gives no price,
	-- so a higher rarity does not automatically outrank a more valuable egg.
	local RECENT_LIMIT = 10
	Eggs.RecordFarmed = function(name)
		local counters = Eggs.Counters
		local rarity = rarityOf(name)
		local entry = {
			Name = name,
			Rarity = rarity,
			Price = eggPrice(name),
			Rank = RARITY_RANK[rarity] or 0,
			At = os.clock(),
		}
		local best = counters.Best
		if not best or entry.Price > best.Price or (entry.Price == best.Price and entry.Rank > best.Rank) then
			counters.Best = entry
		end
		table.insert(counters.Recent, 1, entry)
		while #counters.Recent > RECENT_LIMIT do
			table.remove(counters.Recent)
		end
		counters.RecentVersion = counters.RecentVersion + 1
	end

	local SORT_MODES = {
		{ Key = "Names", Hint = "A to Z" },
		{ Key = "Rarity", Hint = "Grouped, Common to Ethereal" },
		{ Key = "Best", Hint = "Highest value first" },
		{ Key = "Nearest", Hint = "Closest to you first" },
	}
	local function validSort(key)
		for _, mode in ipairs(SORT_MODES) do
			if mode.Key == key then
				return true
			end
		end
		return false
	end
	if not validSort(Eggs.SortBy) then
		Eggs.SortBy = "Best"
	end
	State.EggsSort = Eggs.SortBy

	local function rarityColor(rarity)
		return RARITY_COLORS[rarity] or Theme.Color.TextLow
	end

	local function isFarmRaritySelected(eggName)
		return Eggs.FarmRarities[rarityOf(eggName)] == true
	end

	-- LIVE EGG REGISTRY ---------------------------------------------------
	-- A spawn, a collection or a despawn bumps the version and releases
	-- everything parked in liveWait, so the farm and the placer resume on the
	-- same frame the world changed instead of finishing a fixed sleep first.
	local function liveWake()
		Eggs.Version = Eggs.Version + 1
		local waiters = Eggs.Waiters
		for index = #waiters, 1, -1 do
			local waiter = waiters[index]
			waiters[index] = nil
			if waiter then
				pcall(waiter)
			end
		end
	end

	local function liveAdd(egg)
		if Eggs.Live[egg] then
			return
		end
		Eggs.Live[egg] = true
		Eggs.Diag.LastDetection = os.clock()
		liveWake()
	end

	local function liveDrop(egg)
		if not Eggs.Live[egg] then
			return
		end
		Eggs.Live[egg] = nil
		liveWake()
	end

	-- Returns true when the world actually changed while waiting. The timer is
	-- the fallback, not the main path: eggs can also arrive through a folder
	-- swap that never fires DescendantAdded, and the loop has to keep breathing
	-- either way. 0.3s is the slowest the farm or placer will ever idle.
	local function liveWait(timeout)
		local token = Eggs.Version
		local released = false
		local waiter
		waiter = function()
			if released then
				return
			end
			released = true
			local index = table.find(Eggs.Waiters, waiter)
			if index then
				table.remove(Eggs.Waiters, index)
			end
		end
		table.insert(Eggs.Waiters, waiter)
		local deadline = os.clock() + (timeout or 0.3)
		while not released and os.clock() < deadline and Eggs.Running and screen.Parent do
			task.wait(0.05)
		end
		waiter()
		return Eggs.Version ~= token
	end

	-- What is live right now, grouped by rarity, for the Home statistics.
	local function recountLive()
		local byRarity = {}
		local detected = 0
		for egg in pairs(Eggs.Live) do
			if egg.Parent then
				detected = detected + 1
				local rarity = rarityOf(egg.Name)
				byRarity[rarity] = (byRarity[rarity] or 0) + 1
			end
		end
		Eggs.Counters.Detected = detected
		Eggs.Counters.ByRarity = byRarity
		return detected
	end


	-- Egg icons are read from the game's own index, falling back to the asset
	-- id in the game data; an empty image is fine.
	local function getEggImage(eggName)
		local main = playerGui:FindFirstChild("Main")
		local index = main and main:FindFirstChild("Index")
		local holders = index and index:FindFirstChild("Holders")
		local eggsHolder = holders and holders:FindFirstChild("EggsHolder")
		if eggsHolder then
			local frame = eggsHolder:FindFirstChild(eggName)
			local label = frame and frame:FindFirstChild("ImageLabel")
			if label and label:IsA("ImageLabel") then
				return label.Image or ""
			end
		end
		if eggData then
			local entry = eggData[eggName]
			if type(entry) == "table" and type(entry.Image) == "string" then
				return entry.Image
			end
		end
		return ""
	end

	local function distanceTo(target)
		local root = characterRoot()
		local part = getRootPart(target)
		if not root or not part then
			return nil
		end
		return (root.Position - part.Position).Magnitude
	end

	-- Standing 10 studs above an egg / baseplate keeps the character clear
	-- of the model instead of inside it.
	local function topCFrame(part, size)
		if not part or not part:IsA("BasePart") or not part.Parent then
			return nil
		end
		if not isValidPosition(part.CFrame.Position) then
			return nil
		end
		if not isFinite(size.Y) or size.Y <= 0 then
			return nil
		end
		local goal = part.CFrame * CFrame.new(0, (size.Y * 0.5) + Eggs.HeightOffset, 0)
		if not isValidPosition(goal.Position) then
			return nil
		end
		return goal
	end

	-- The landing spot is derived from the model's bounding box rather than
	-- from its PrimaryPart, because the PrimaryPart is not necessarily at the
	-- centre of the box and would drop the player off to one side.
	local function eggTopCFrame(egg)
		if not egg or not egg:IsA("Model") or not egg.Parent then
			return nil
		end
		local cframe, size = egg:GetBoundingBox()
		if not isValidPosition(cframe.Position) then
			return nil
		end
		if not isFinite(size.Y) or size.Y <= 0 then
			return nil
		end
		return CFrame.new(cframe.Position + Vector3.new(0, (size.Y * 0.5) + Eggs.HeightOffset, 0))
	end

	-- No distance limit: teleporting far is a deliberate user action.
	local function safeTeleport(target)
		local character = player.Character
		local root = characterRoot()
		if not character or not root or not character.Parent then
			return false, "Character not ready"
		end
		local ok, err = pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(target)
		end)
		if not ok then
			warn("[Eggs] teleport failed: " .. tostring(err))
			return false, tostring(err)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return true
	end

	-- MY PLOT -------------------------------------------------------------

	-- The owner is read through plot > Data > Owner. The game writes it either
	-- as an ObjectValue pointing at the player or as a StringValue holding the
	-- player name, so both are resolved to the local player.
	local function ownerOf(plot)
		if not plot or not plot.Parent then
			return nil
		end
		-- The game tags the one plot it has actually loaded for this account with
		-- the owner's UserId in NestsOwnerLoaded, and leaves the attribute off every
		-- other plot. That is the signal the real game publishes, so it is checked
		-- before anything guessed from folder layout.
		local loaded = plot:GetAttribute("NestsOwnerLoaded")
		if type(loaded) == "number" then
			return loaded == player.UserId and player or nil
		end
		local data = plot:FindFirstChild("Data")
		local owner = data and data:FindFirstChild("Owner")
		if owner and owner:IsA("ObjectValue") then
			return owner.Value
		end
		if owner and owner:IsA("StringValue") and owner.Value == player.Name then
			return player
		end
		-- Some plots publish only the UserId as a value rather than an attribute.
		for _, name in ipairs({ "UserId", "OwnerId", "PlayerUserId" }) do
			local value = plot:GetAttribute(name)
			if type(value) == "number" then
				return value == player.UserId and player or nil
			end
			local part = plot:FindFirstChild(name)
			if part and (part:IsA("IntValue") or part:IsA("NumberValue")) then
				return part.Value == player.UserId and player or nil
			end
		end
		return nil
	end

	-- The folder can stream in or be replaced, so it is re-resolved whenever
	-- the cached one is gone.
	local function plotsFolder()
		local plots = Eggs.Plots
		if not plots or not plots.Parent then
			plots = workspace:FindFirstChild("Plots")
			Eggs.Plots = plots
		end
		return plots
	end

	-- Plots are expensive to walk, so the folder is searched a bounded number
	-- of times (MAX_PLOT_SCANS). The cap resets on a respawn or a new folder.
	local function scanMyPlot()
		local missing = not (Eggs.Plots and Eggs.Plots.Parent)
		local plots = plotsFolder()
		-- A respawn is the natural point to start over: the old character is gone
		-- and the plot streams back in, so the budget is handed back rather than
		-- spent on a character that no longer exists.
		if player.Character ~= Eggs.PlotScanCharacter then
			Eggs.PlotScanCharacter = player.Character
			Eggs.PlotScans = 0
		end
		if missing then
			Eggs.PlotScans = 0
		end
		if not plots then
			return nil
		end
		if Eggs.CachedPlot and Eggs.CachedPlot.Parent and ownerOf(Eggs.CachedPlot) == player then
			return Eggs.CachedPlot
		end
		if Eggs.PlotScans >= MAX_PLOT_SCANS then
			return Eggs.CachedPlot
		end
		Eggs.PlotScans = Eggs.PlotScans + 1
		Eggs.CachedPlot = nil
		Eggs.CachedBaseplate = nil
		for _, plot in ipairs(plots:GetChildren()) do
			if ownerOf(plot) == player then
				Eggs.CachedPlot = plot
				local baseplate = plot:FindFirstChild("Baseplate", true)
				if baseplate and baseplate:IsA("BasePart") then
					Eggs.CachedBaseplate = baseplate
				end
				break
			end
		end
		return Eggs.CachedPlot
	end

	local function plotBaseplate()
		local plot = scanMyPlot()
		if not plot then
			return nil
		end
		if Eggs.CachedBaseplate and Eggs.CachedBaseplate.Parent and Eggs.CachedBaseplate:IsDescendantOf(plot) then
			return Eggs.CachedBaseplate
		end
		local baseplate = plot:FindFirstChild("Baseplate", true)
		if baseplate and baseplate:IsA("BasePart") then
			Eggs.CachedBaseplate = baseplate
			return baseplate
		end
		return nil
	end

	local function teleportHome(silent)
		local baseplate = plotBaseplate()
		if not baseplate then
			if not silent then
				notify("Plot not found", "Warning", "workspace.Plots is missing or your plot is not loaded yet.")
			end
			return false
		end
		local goal = topCFrame(baseplate, baseplate.Size)
		if not goal then
			if not silent then
				notify("Teleport failed", "Error", "That baseplate has no usable size.")
			end
			return false
		end
		local ok, reason = safeTeleport(goal)
		if not silent then
			if ok then
				notify("Teleported home", "Success", "Back on your plot.")
			else
				notify("Teleport failed", "Error", reason)
			end
		end
		return ok
	end

	-- MOVEMENT ------------------------------------------------------------

	-- The egg's Pickup prompt lives inside its own mesh
	-- (RenderedEggs > <Egg> > Sphere.007 > Pickup). Everything below aims at
	-- that prompt, never at the model, so it is defined first.
	local function findPickupPrompt(egg)
		if not egg then
			return nil
		end
		local fallback = nil
		for _, descendant in ipairs(egg:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") and descendant.Enabled then
				if descendant.Name == "Pickup" then
					return descendant
				end
				fallback = fallback or descendant
			end
		end
		return fallback
	end

	-- PHASE MODE ----------------------------------------------------------
	-- While the farm is walking to an egg and collecting it, the character is
	-- "phased": every part of it has CanCollide off, so no wall or floor can
	-- trap it, and it is pinned to a hover point just above the Pickup prompt
	-- on every frame, so it can never fall under the egg. One session covers
	-- the whole walk -> stabilise -> verify -> pickup sequence and is always
	-- ended by Phase.End, which puts every part back to the CanCollide value it
	-- had before. Nothing is ever left permanently non-colliding.
	--
	-- (A floating platform is not layered on top: with the character's own
	-- collision off it could not hold the character up anyway. The per-frame
	-- pin is what replaces gravity.)
	local Phase = {
		State = nil, -- non-nil only while a move / pickup is running
		StandHeight = 2.5, -- studs above the prompt the root hovers at
		Heights = { 2.5, 1.5, 3.5 }, -- one per pickup attempt, so a retry is a real reposition
		Arrive = 1.5, -- how close to the hover point counts as "there"
		Lease = 5, -- a session dies this many seconds after its owner last checked in
		StuckTime = 1.5, -- no real movement for this long while walking = stuck
		StuckDistance = 0.75, -- ...where "real movement" is at least this many studs
		MaxRecoveries = 2, -- per approach, so a recovery can never loop forever
		PickupTimeout = 30, -- hard ceiling for one egg, every attempt and recovery included
		DescendBy = 14, -- after a pickup in walk mode: studs to sink before going home
		VoidMargin = 60, -- ...and never lower than this above the world's kill height
		LevelTolerance = 0.6, -- "same height as the egg" counts within this many studs
	}

	-- Where the game measures range from: the prompt's parent (the mesh).
	function Phase.PromptPosition(prompt)
		local holder = prompt and prompt.Parent
		local position = nil
		if holder and holder:IsA("BasePart") then
			position = holder.Position
		elseif holder and holder:IsA("Attachment") then
			position = holder.WorldPosition
		end
		if position and isValidPosition(position) then
			return position
		end
		return nil
	end

	-- The prompt if there is one. Without it, the egg's visible mesh; never the
	-- model's bounding box, which is skewed by helper parts such as a mutation
	-- hitbox and is what used to drop the character below the egg.
	function Phase.EggPosition(egg, prompt)
		local position = Phase.PromptPosition(prompt)
		if position then
			return position
		end
		if not egg then
			return nil
		end
		for _, child in ipairs(egg:GetChildren()) do
			if child:IsA("MeshPart") and isValidPosition(child.Position) then
				return child.Position
			end
		end
		local part = getRootPart(egg)
		if part and isValidPosition(part.Position) then
			return part.Position
		end
		return nil
	end

	-- Egg -> Pickup prompt -> a safe point just above it. Kept within the
	-- prompt's own activation distance so the interaction stays in range.
	function Phase.StandPoint(egg, prompt, height)
		local base = Phase.EggPosition(egg, prompt)
		if not base then
			return nil
		end
		height = height or Phase.StandHeight
		if prompt and isFinite(prompt.MaxActivationDistance) then
			height = math.min(height, math.max(prompt.MaxActivationDistance * 0.5, 1))
		end
		return base + Vector3.new(0, height, 0)
	end

	function Phase.Snap(state)
		local root = state.Root
		if state.Goal and root.Parent then
			root.CFrame = CFrame.new(state.Goal)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- On the hover point, and not below it.
	function Phase.Settled(state)
		local goal = state.Goal
		local root = state.Root
		if not goal or not root.Parent then
			return false
		end
		local offset = root.Position - goal
		return offset.Magnitude <= Phase.Arrive and offset.Y >= -0.75
	end

	-- Runs every frame while a session is open: keeps the session honest
	-- (character alive, lease not expired), follows the prompt, walks or holds
	-- the character on the hover point and cancels any fall.
	function Phase.Tick(state, dt)
		if Phase.State ~= state then
			return
		end
		local root = state.Root
		if not root.Parent or not state.Character.Parent or state.Humanoid.Health <= 0 or os.clock() > state.Expires then
			Phase.End()
			return
		end
		local egg = state.Egg
		if egg and egg.Parent then
			if not (state.Prompt and state.Prompt.Parent) then
				state.Prompt = findPickupPrompt(egg)
			end
			local point = Phase.StandPoint(egg, state.Prompt, state.Height)
			if point then
				state.Goal = point
			end
		end
		local goal = state.Goal
		if not goal then
			return
		end
		local position = root.Position
		-- Where this frame is heading. Leg one keeps X and Z and only changes
		-- height; once level with the hover point it switches to leg two, the
		-- straight run across. Everything is phased, so walls are no obstacle.
		local aim = goal
		if state.Speed and state.Stage == "level" then
			if math.abs(goal.Y - position.Y) <= Phase.LevelTolerance then
				state.Stage = "across"
			else
				aim = Vector3.new(position.X, goal.Y, position.Z)
			end
		end
		local offset = aim - position
		local nextPosition = aim
		if state.Speed then
			local step = state.Speed * dt
			if offset.Magnitude > step then
				nextPosition = position + offset.Unit * step
			end
		end
		root.CFrame = CFrame.new(nextPosition)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Collision is about to come back. If the root is sitting inside solid
	-- geometry, lift it clear first so restoring collision cannot trap it.
	function Phase.Clear(state)
		local root = state.Root
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { state.Character }
		local origin = root.CFrame
		for step = 0, 6 do
			local cframe = origin + Vector3.new(0, step * 2, 0)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(cframe, Vector3.new(3, 5, 3), params)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				if step > 0 then
					root.CFrame = cframe
				end
				return
			end
		end
	end

	-- Opens a session, or joins the caller's own open one (Depth counts the
	-- joins). Returns nil when the character is not ready or another thread's
	-- live session owns it.
	function Phase.Begin()
		local character = player.Character
		local root = characterRoot()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not humanoid or humanoid.Health <= 0 then
			return nil
		end
		local owner = coroutine.running()
		local existing = Phase.State
		if existing then
			if existing.Character == character and existing.Owner == owner then
				existing.Depth = existing.Depth + 1
				existing.Expires = os.clock() + Phase.Lease
				return existing
			end
			if existing.Character == character and os.clock() < existing.Expires then
				return nil
			end
			Phase.End()
		end
		local state = {
			Character = character,
			Root = root,
			Humanoid = humanoid,
			Owner = owner,
			Depth = 1,
			Saved = {},
			Conns = {},
			AutoRotate = humanoid.AutoRotate,
			Expires = os.clock() + Phase.Lease,
		}
		Phase.State = state
		Eggs.Moving = true
		Eggs.MoveHumanoid = humanoid
		local function lock(part)
			if part:IsA("BasePart") and state.Saved[part] == nil then
				state.Saved[part] = part.CanCollide
				part.CanCollide = false
			end
		end
		local ok = pcall(function()
			for _, descendant in ipairs(character:GetDescendants()) do
				lock(descendant)
			end
			humanoid.AutoRotate = false
			-- Parts added mid-session (an equipped tool) are phased too.
			table.insert(state.Conns, character.DescendantAdded:Connect(lock))
			-- The Humanoid switches CanCollide back on for the torso every
			-- physics step, so setting it once is not enough: it is re-applied
			-- before every step. This is what let the character clip walls.
			table.insert(state.Conns, RunService.Stepped:Connect(function()
				for part in pairs(state.Saved) do
					if part.Parent and part.CanCollide then
						part.CanCollide = false
					end
				end
			end))
			table.insert(state.Conns, RunService.Heartbeat:Connect(function(dt)
				Phase.Tick(state, dt)
			end))
			table.insert(state.Conns, humanoid.Died:Connect(function()
				if Phase.State == state then
					Phase.End()
				end
			end))
		end)
		if not ok then
			Phase.End()
			return nil
		end
		return state
	end

	-- Leaves a session joined with Begin. The last one out ends it.
	function Phase.Release(state)
		if not state or Phase.State ~= state then
			return
		end
		state.Depth = state.Depth - 1
		if state.Depth <= 0 then
			Phase.End()
		end
	end

	-- Always safe to call, from any thread, any number of times: stops every
	-- connection, lifts the character out of solid geometry and restores each
	-- part to the collision it had before the session.
	function Phase.End()
		local state = Phase.State
		Eggs.Moving = false
		Eggs.MoveHumanoid = nil
		if not state then
			return
		end
		Phase.State = nil
		for _, connection in ipairs(state.Conns) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		pcall(function()
			if state.Root.Parent then
				state.Root.AssemblyLinearVelocity = Vector3.zero
				state.Root.AssemblyAngularVelocity = Vector3.zero
				Phase.Clear(state)
			end
		end)
		for part, previous in pairs(state.Saved) do
			if part.Parent then
				pcall(function()
					part.CanCollide = previous
				end)
			end
		end
		pcall(function()
			if state.Humanoid.Parent then
				state.Humanoid.AutoRotate = state.AutoRotate
			end
		end)
	end

	-- Aims the session at an egg. The hover point is recomputed from the live
	-- prompt every frame, so it follows the egg if it moves.
	function Phase.Target(state, egg, prompt, speed, height)
		state.Egg = egg
		state.Prompt = prompt
		state.Speed = speed
		state.Height = height
		-- Walking is two legs: first straight up or down to the egg's height,
		-- then straight across to it. Teleporting (no speed) has neither.
		state.Stage = speed and "level" or nil
		local point = Phase.StandPoint(egg, prompt, height)
		if not point then
			return false
		end
		state.Goal = point
		return true
	end

	-- Stabilise, then verify. If the character is off the hover point or below
	-- it, it is put straight back before the check is repeated.
	function Phase.Verify(state, egg)
		for _ = 1, 4 do
			if Phase.State ~= state or not egg.Parent then
				return false
			end
			if not Phase.Settled(state) then
				Phase.Snap(state)
			end
			state.Expires = os.clock() + Phase.Lease
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			if Phase.Settled(state) then
				return true
			end
		end
		return false
	end

	-- The character has stopped making progress (rubber-banded by the server,
	-- wedged, or snapped back after every write). Cancel the current target,
	-- go back to a position that is known to be open ground, and aim again from
	-- there with a freshly resolved prompt and a different hover height.
	function Phase.Recover(state, egg, why)
		local diag = Eggs.Diag
		diag.Recoveries = diag.Recoveries + 1
		diag.LastRecovery = os.clock()
		diag.LastRecoveryWhy = why
		warn("[Eggs] auto farm movement recovery #" .. diag.Recoveries .. ": " .. tostring(why))
		if logActivity then
			pcall(logActivity, "Auto farm recovered", tostring(why) .. ", retrying from a safe spot", "Warning")
		end
		-- 1. Cancel the target, so the tick stops pushing the character at it.
		state.Goal = nil
		state.Speed = nil
		state.Egg = nil
		local root = state.Root
		if not root.Parent then
			return false
		end
		-- 2. Safe position: the plot, or straight up if the plot is unavailable.
		if not teleportHome(true) then
			root.CFrame = CFrame.new(root.Position + Vector3.new(0, 12, 0))
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- 3. Recalculate: a fresh prompt, and a different hover height each time.
		state.Recoveries = (state.Recoveries or 0) + 1
		local heights = Phase.Heights
		local height = heights[((state.Recoveries) % #heights) + 1]
		local speed = Eggs.SmoothMove and math.max(Eggs.MoveSpeed, 1) or nil
		return Phase.Target(state, egg, findPickupPrompt(egg), speed, height)
	end

	-- Walk (or jump) to the hover point above the egg's prompt, then verify.
	-- If the character stops making progress it is recovered, a bounded number
	-- of times, rather than left standing there until the lease runs out.
	-- The two-leg path is longer than the straight line, so the time budget is
	-- the vertical distance plus the horizontal one.
	function Phase.PathLength(from, goal)
		return math.abs(goal.Y - from.Y) + Vector3.new(goal.X - from.X, 0, goal.Z - from.Z).Magnitude
	end

	function Phase.Approach(state, egg, height)
		local prompt = findPickupPrompt(egg)
		local smooth = Eggs.SmoothMove
		local speed = smooth and math.max(Eggs.MoveSpeed, 1) or nil
		if not Phase.Target(state, egg, prompt, speed, height) then
			return false
		end
		local root = state.Root
		state.Recoveries = 0
		if not smooth or (state.Goal - root.Position).Magnitude <= 3 then
			state.Speed = nil
			Phase.Snap(state)
		else
			local startedAt = os.clock()
			local budget = math.max(4, (Phase.PathLength(root.Position, state.Goal) / speed) + 3)
			local progressPosition, progressAt = root.Position, os.clock()
			while not Phase.Settled(state) and os.clock() - startedAt <= budget do
				if Phase.State ~= state or not egg.Parent then
					return false
				end
				state.Expires = os.clock() + Phase.Lease
				RunService.Heartbeat:Wait()
				local now = os.clock()
				if (root.Position - progressPosition).Magnitude >= Phase.StuckDistance then
					progressPosition, progressAt = root.Position, now
				elseif now - progressAt >= Phase.StuckTime and state.Goal then
					if state.Recoveries >= Phase.MaxRecoveries then
						return false
					end
					if not Phase.Recover(state, egg, "no movement for " .. string.format("%.1fs", now - progressAt)) then
						return false
					end
					speed = state.Speed or speed
					startedAt = os.clock()
					budget = math.max(4, (Phase.PathLength(root.Position, state.Goal) / speed) + 3)
					progressPosition, progressAt = root.Position, os.clock()
				end
			end
			-- From here the tick only holds the hover point. If the walk ran out
			-- of time it lands there in one step rather than failing.
			state.Speed = nil
		end
		local reached = Phase.Verify(state, egg)
		-- Still not on the hover point after the snaps: something keeps moving
		-- the character. Recover and verify again, but only a bounded number of times.
		while not reached and Phase.State == state and egg.Parent and state.Recoveries < Phase.MaxRecoveries do
			if not Phase.Recover(state, egg, "could not hold position at the egg") then
				break
			end
			state.Speed = nil
			Phase.Snap(state)
			reached = Phase.Verify(state, egg)
		end
		return reached
	end

	-- After a pickup in walk mode: sink straight down a little (still phased, so
	-- the floor is no obstacle) before the trip home. Bounded twice over: by
	-- DescendBy, and by a floor well above the world's kill height, so it can
	-- never head for the void. Returns once it has sunk, ran out of time, or the
	-- session ended.
	function Phase.Descend(state)
		local root = state.Root
		if Phase.State ~= state or not root.Parent then
			return
		end
		local speed = math.max(Eggs.MoveSpeed, 1)
		local floorY = workspace.FallenPartsDestroyHeight + Phase.VoidMargin
		local goalY = math.max(root.Position.Y - Phase.DescendBy, floorY)
		if root.Position.Y - goalY < 1 then
			return
		end
		-- Nothing to chase any more: the egg is gone, only this point matters.
		state.Egg, state.Prompt = nil, nil
		state.Goal = Vector3.new(root.Position.X, goalY, root.Position.Z)
		state.Speed = speed
		state.Stage = "across" -- straight down only, no height leg
		local startedAt = os.clock()
		local budget = ((root.Position.Y - goalY) / speed) + 1.5
		while Phase.State == state and root.Parent and root.Position.Y - goalY > Phase.LevelTolerance
			and os.clock() - startedAt <= budget do
			state.Expires = os.clock() + Phase.Lease
			RunService.Heartbeat:Wait()
		end
	end

	-- Ends any open session. Kept as the one cleanup entry point because the
	-- respawn handler, the stop buttons and the error path all call it.
	local function stopMovement()
		Phase.End()
	end

	-- Goes to the egg through Phase mode and reports whether the character is
	-- settled on the hover point. Joins the caller's session if it has one
	-- open, otherwise opens (and closes) its own.
	local function moveToEgg(egg, height)
		if not egg or not egg.Parent then
			return false
		end
		local state = Phase.Begin()
		if not state then
			return false
		end
		local ok, arrived = pcall(Phase.Approach, state, egg, height)
		Phase.Release(state)
		if not ok then
			warn("[Eggs] move to egg failed: " .. tostring(arrived))
			return false
		end
		return arrived == true
	end

	-- AUTO FARM -----------------------------------------------------------

	-- Declared ahead of its first use: holdInteract and startAutoFarm both
	-- call these, and a `local function` below would be out of scope inside
	-- them (resolving to a nil global at run time).
	local releaseInteract
	local stopAutoFarm
	-- Same reason, for the Auto Place loop: it stops the previous run and
	-- paints its own state, both of which are defined further down.
	local stopAutoPlace
	local setPlaceStatus
	local paintPlace
	-- The slot slider, so the placer can widen it to whatever the plot reports
	-- the moment it finds out.
	local placeSlotSlider = nil

	-- The game clones ReplicatedStorage.Assets.Prompts.Pickup onto each egg, so
	-- the egg's own ProximityPrompt is triggered directly. That needs no
	-- keyboard input and only holds for the prompt's HoldDuration. The E key
	-- press is kept as a fallback for eggs without a prompt.
	local activePrompt = nil

	local function pickupTemplate()
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
		local prompts = assets and assets:FindFirstChild("Prompts")
		local template = prompts and prompts:FindFirstChild("Pickup")
		if template and template:IsA("ProximityPrompt") then
			return template
		end
		return nil
	end

	-- The same template lookup for the other side of the egg. Checked at start so
	-- an executor that can fire prompts, on a game that publishes no Place
	-- prompt, fails with a clear reason instead of a repeated miss.
	local function placeTemplate()
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
		local prompts = assets and assets:FindFirstChild("Prompts")
		local template = prompts and prompts:FindFirstChild("Place")
		if template and template:IsA("ProximityPrompt") then
			return template
		end
		return nil
	end

	-- Triggers the prompt at once when the executor provides
	-- fireproximityprompt, which skips the hold. Returns true on success.
	-- HoldDuration is zeroed for the call and restored right after, since
	-- some implementations still honour it.
	local function fireInstant(prompt)
		if type(fireproximityprompt) ~= "function" then
			return false
		end
		local hold, distance, sight = prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight
		pcall(function()
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = math.max(distance, 32)
			prompt.RequiresLineOfSight = false
		end)
		local ok = pcall(fireproximityprompt, prompt)
		task.defer(function()
			pcall(function()
				prompt.HoldDuration = hold
				prompt.MaxActivationDistance = distance
				prompt.RequiresLineOfSight = sight
			end)
		end)
		return ok
	end

	-- Slow path: an honest hold. Ends the moment the prompt fires or the egg
	-- disappears instead of always running the full duration.
	local function holdPrompt(prompt, egg)
		local duration = prompt.HoldDuration
		local ok = pcall(function()
			prompt:InputHoldBegin()
		end)
		if not ok then
			return false
		end
		activePrompt = prompt
		local triggered = false
		local connection = prompt.Triggered:Connect(function()
			triggered = true
		end)
		local deadline = os.clock() + duration + 0.1
		while Eggs.FarmActive and not triggered and egg.Parent and os.clock() < deadline do
			task.wait(0.03)
		end
		connection:Disconnect()
		activePrompt = nil
		pcall(function()
			prompt:InputHoldEnd()
		end)
		return true
	end

	local function holdKey()
		if not virtualInput then
			return false
		end
		local deadline = os.clock() + Eggs.HoldTime
		local ok = pcall(function()
			virtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game)
		end)
		if not ok then
			return false
		end
		while Eggs.FarmActive and os.clock() < deadline do
			task.wait(0.05)
		end
		releaseInteract()
		return true
	end

	local function holdInteract(egg)
		local prompt = findPickupPrompt(egg)
		if prompt then
			if fireInstant(prompt) then
				return true, true -- second value: no hold was needed
			end
			return holdPrompt(prompt, egg)
		end
		return holdKey()
	end

	-- Always released, even if the farm was cancelled mid-hold, so nothing
	-- can stay stuck down.
	releaseInteract = function()
		if activePrompt then
			local prompt = activePrompt
			activePrompt = nil
			pcall(function()
				prompt:InputHoldEnd()
			end)
		end
		if not virtualInput then
			return
		end
		pcall(function()
			virtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		end)
	end

	-- The game removes the egg from the world once it hatches, so a missing
	-- model is the only trustworthy confirmation that the press landed. The
	-- farm used to assume success the moment it walked over an egg, which made
	-- a rejected key press look exactly like a working farm: every egg was
	-- marked done and nothing was ever collected.
	local function isPickedUp(egg)
		return egg == nil or egg.Parent == nil
	end

	-- Returns whether the egg was collected, plus the reason when it was not.
	-- isActive lets the auto placer reuse this: the farm owns Eggs.FarmActive,
	-- and a caller that passes its own flag keeps cancelling on its own state
	-- instead of on the farm's.
	local function tryPickup(egg, isActive, descend)
		local running = isActive
			or function()
				return Eggs.FarmActive
			end
		if not virtualInput and not findPickupPrompt(egg) then
			return false, "no Pickup prompt on the egg and no interact key available"
		end
		if isPickedUp(egg) then
			return true
		end
		-- One Phase session spans every attempt: the character stays phased and
		-- pinned above the prompt from the first step of the walk until the egg
		-- is collected (or the attempts run out), and collision is restored by
		-- Phase.Release whichever way this returns, error included.
		local state = Phase.Begin()
		if not state then
			return false, "could not reach the egg"
		end
		local function step(name)
			if isActive == nil and Eggs.SetStep then
				Eggs.SetStep(name)
			end
		end
		local giveUpAt = os.clock() + Phase.PickupTimeout
		local ok, picked, reason, confirmed = pcall(function()
			local why = "could not reach the egg"
			for attempt = 1, PICKUP_ATTEMPTS do
				if not running() or not screen.Parent then
					return false, "cancelled"
				end
				if os.clock() > giveUpAt then
					return false, "timed out on this egg"
				end
				if isPickedUp(egg) then
					return true
				end
				-- The session can be ended from outside (a button, the walk
				-- toggle). Reopen it rather than pressing E unprotected.
				if Phase.State ~= state then
					state = Phase.Begin()
					if not state then
						return false, "your character is not ready"
					end
				end
				state.Expires = os.clock() + Phase.Lease
				-- Move -> stabilise -> verify -> pickup. Each retry uses a
				-- different hover height, so it is a genuine reposition.
				step(attempt > 1 and "Retrying" or "Moving")
				local reached = moveToEgg(egg, Phase.Heights[attempt] or Phase.StandHeight)
				if not reached and isPickedUp(egg) then
					-- The egg vanished on the way: the pickup went through.
					return true
				end
				if reached then
					-- One frame is enough for the new position to register.
					task.wait(0.08)
					if isPickedUp(egg) then
						return true
					end
					-- Re-verified right before the press: if anything moved the
					-- character, it is corrected here, not after a failed press.
					if Phase.Verify(state, egg) then
						step("Picking Up")
						local pressed, instant = holdInteract(egg)
						if not pressed then
							return false, "the pickup prompt / E key press was rejected"
						end
						-- Give the game a moment to remove the egg before calling it a miss.
						step("Confirming Pickup")
						local deadline = os.clock() + (instant and 0.8 or 1.5)
						while os.clock() < deadline do
							if isPickedUp(egg) then
								-- Walk mode only, and only for the farm: sink a little,
								-- then go home while still phased, so collision never
								-- comes back with the character inside the floor.
								if descend and Eggs.SmoothMove then
									step("Returning")
									pcall(Phase.Descend, state)
									teleportHome(true)
								end
								-- Third value: the egg left after THIS press, from the
								-- hover point over its prompt. That is the only case the
								-- farm counts as its own pickup.
								return true, nil, true
							end
							state.Expires = os.clock() + Phase.Lease
							task.wait(0.03)
						end
						why = "still there after " .. PICKUP_ATTEMPTS .. " attempts"
					end
				end
			end
			return false, why
		end)
		Phase.Release(state)
		if not ok then
			warn("[Eggs] pickup errored: " .. tostring(picked))
			return false, "error: " .. tostring(picked)
		end
		return picked, reason, confirmed
	end

	-- A selected rarity takes priority: with any rarity on, the farm hunts every
	-- egg of those rarities and ignores the per-group FARM marks. With none on,
	-- it falls back to the FARM marks so the original behaviour still works.
	local function farmWants(eggName, rarityCount)
		if rarityCount > 0 then
			return isFarmRaritySelected(eggName)
		end
		return Eggs.FarmTypes[eggName] == true
	end

	local function farmRarityCount()
		local count = 0
		for _ in pairs(Eggs.FarmRarities) do
			count = count + 1
		end
		return count
	end

	-- Nearest eligible egg, read from the live registry rather than walking the
	-- folder. Returns the egg and its distance so the status card can show both
	-- without measuring a second time.
	local function nextFarmEgg()
		if not (Eggs.Folder and Eggs.Folder.Parent) then
			-- Re-resolved every call, so a folder that streams in later is picked up.
			local folder = workspace:FindFirstChild("RenderedEggs")
			Eggs.Folder = folder
			if not folder then
				return nil, nil
			end
		end
		local root = characterRoot()
		local rarityCount = farmRarityCount()
		local best, bestDistance = nil, math.huge
		for egg in pairs(Eggs.Live) do
			if egg.Parent and not Eggs.Processed[egg] and farmWants(egg.Name, rarityCount) then
				local part = getRootPart(egg)
				if part then
					local distance = root and (root.Position - part.Position).Magnitude or 0
					if distance < bestDistance then
						best, bestDistance = egg, distance
					end
				end
			end
		end
		return best, best and bestDistance or nil
	end

	-- DIAGNOSTICS ---------------------------------------------------------
	-- Shared by the scanner indicator on this page and by Debug Mode.

	-- Is the scanner actually wired up: the folder exists AND at least one of
	-- its event connections is still live.
	function Eggs.Diag.Health()
		local watching = false
		for _, connection in ipairs(Eggs.WatchConns) do
			if connection.Connected then
				watching = true
				break
			end
		end
		local folder = Eggs.Folder
		local present = folder ~= nil and folder.Parent ~= nil
		return present and watching and Eggs.Running == true, present, watching
	end

	function Eggs.Diag.Age(stamp)
		if not stamp then
			return nil
		end
		return os.clock() - stamp
	end

	-- How many live eggs the farm would take right now. When this is lower than
	-- "detected", the difference is the rarity filter or eggs already tried.
	function Eggs.Diag.Candidates()
		local rarityCount = farmRarityCount()
		local count = 0
		for egg in pairs(Eggs.Live) do
			if egg.Parent and not Eggs.Processed[egg] and farmWants(egg.Name, rarityCount) and getRootPart(egg) then
				count = count + 1
			end
		end
		return count
	end

	-- Best first, so the message names the rarities in prize order.
	local function selectedRaritiesText()
		local picked = {}
		for rarity in pairs(Eggs.FarmRarities) do
			table.insert(picked, rarity)
		end
		table.sort(picked, function(a, b)
			return (RARITY_RANK[a] or 0) > (RARITY_RANK[b] or 0)
		end)
		return table.concat(picked, ", ")
	end

	local paintFarm = nil
	local autoFarmToggle = nil
	local setFarmStatus = nil
	-- Assigned further down in this page. Declared here because the farm loop
	-- needs to force a scan before its first pass, and because every state
	-- change has to reach the Home page's card and counters.
	local ensureWatched = nil
	-- Replaced near the end of this page, once the real publisher is built. The
	-- stub means a scan, a respawn or a watcher callback that lands before then
	-- is a no-op instead of a nil call.
	local publishEggs = function() end

	-- Processed eggs that left the world no longer need remembering.
	local function pruneProcessed()
		for egg in pairs(Eggs.Processed) do
			if not egg.Parent then
				Eggs.Processed[egg] = nil
			end
		end
	end

	local farmMissed = 0

	-- One farm pass. Returns how long to wait before the next one. With no
	-- valid target it reports "Waiting for Eggs" and parks on the live registry
	-- rather than sleeping a fixed interval, so the first eligible egg is picked
	-- up the moment it spawns.
	local function farmStep()
		if not characterRoot() then
			setFarmStatus("ON / Waiting for Character", "waiting", "Waiting for your character")
			return 0.5
		end
		if farmRarityCount() == 0 and next(Eggs.FarmTypes) == nil then
			setFarmStatus("ON / Pick a rarity or FARM an egg", "waiting", "No rarities selected yet")
			return 0.5
		end
		pruneProcessed()
		local egg, distance = nextFarmEgg()
		if not egg then
			setFarmStatus("ON / Waiting for Eggs", "listening", "Listening for a matching egg")
			-- Released by the next spawn or collection. The 0.3s timer is only a
			-- safety net for changes that never fire an event.
			liveWait(0.3)
			return 0
		end
		local rarity = rarityOf(egg.Name)
		setFarmStatus("ON / Farming " .. egg.Name, "farming", "Collecting it now", egg.Name, rarity, distance, "Target Found")
		local name = egg.Name
		Eggs.FarmTarget = egg
		local picked, reason, confirmed = tryPickup(egg, nil, true)
		Eggs.FarmTarget = nil
		-- This egg is finished with, however it went: it must not stay on show
		-- as the current target while the farm walks home.
		Eggs.Card.Target = nil
		Eggs.Card.Rarity = nil
		Eggs.SetStep("Returning")
		publishEggs() -- SetStep only publishes when the step changed
		teleportHome(true)
		-- Marked either way. Leaving a failed egg unmarked would make the
		-- farm select that same egg again on every pass and never reach
		-- any of the others.
		Eggs.Processed[egg] = true
		if picked and confirmed then
			-- Counted only once the pickup was confirmed: the egg left right after
			-- this farm's own press. Detected or targeted eggs never count.
			Eggs.Counters.Farmed = Eggs.Counters.Farmed + 1
			Eggs.RecordFarmed(name)
		elseif picked then
			-- The egg was already gone (or went while walking): not this farm's.
		elseif reason ~= "cancelled" then
			farmMissed = farmMissed + 1
			warn("[Eggs] auto farm did not collect a " .. name .. " (" .. tostring(reason) .. ")")
			if farmMissed == 1 then
				notify("Egg not collected", "Warning", name .. ": " .. tostring(reason))
			end
		end
		-- The egg is gone or marked, so release anything else parked on the
		-- registry: the next pass can start without waiting out its timeout.
		Eggs.SetStep("Searching")
		liveDrop(egg)
		publishEggs()
		return 0.1
	end

	-- Returns whether the farm actually started, so the caller can put the
	-- toggle back instead of leaving it showing ON for a farm that never ran.
	-- An empty egg list is NOT a reason to refuse: the farm waits for eggs.
	local function startAutoFarm()
		if not virtualInput and not pickupTemplate() then
			notify("Auto farm unavailable", "Error", "Assets.Prompts.Pickup was not found and VirtualInputManager is not accessible.")
			return false
		end
		stopAutoFarm(true)
		Eggs.FarmActive = true
		Eggs.Processed = {}
		farmMissed = 0
		Eggs.FarmState = ""
		-- Scan before the first pass instead of letting it discover the world on
		-- its own: an egg that is already out is eligible right now.
		if ensureWatched then
			ensureWatched()
		end
		recountLive()
		liveWake()
		if paintFarm then
			paintFarm(true)
		end
		local rarityCount = farmRarityCount()
		if rarityCount > 0 then
			local target = selectedRaritiesText()
			notify("Auto farm ON", "Success", "Hunting every " .. target .. " egg. It waits for eggs when none are out.", true)
			logActivity("Auto farm started", "Farming " .. target, "Success")
		elseif next(Eggs.FarmTypes) ~= nil then
			notify("Auto farm ON", "Success", "Hunting every marked egg. It waits for eggs when none are out.", true)
			logActivity("Auto farm started", "Farming marked egg types", "Success")
		else
			notify("Auto farm ON", "Info", "Pick a rarity below, or FARM an egg group, to give it targets.", true)
			logActivity("Auto farm started", "Waiting for targets", "Info")
		end

		Eggs.FarmThread = task.spawn(function()
			local errors = 0
			while Eggs.FarmActive and screen.Parent do
				local ok, result = pcall(farmStep)
				local delay = 0.5
				if ok then
					delay = tonumber(result) or 0.3
				else
					-- A failed step must not leave the walk or the key stuck.
					errors = errors + 1
					if errors <= 3 then
						warn("[Eggs] auto farm step failed: " .. tostring(result))
					end
					stopMovement()
					releaseInteract()
					delay = 1
				end
				task.wait(delay)
			end
			-- Only reached when the interface is going away; a normal stop
			-- cancels this thread from stopAutoFarm.
			Eggs.FarmActive = false
			Eggs.FarmThread = nil
			stopMovement()
			releaseInteract()
		end)
		return true
	end
	stopAutoFarm = function(silent)
		Eggs.FarmActive = false
		Eggs.FarmTarget = nil
		stopMovement()
		releaseInteract()
		Eggs.Processed = {}
		local thread = Eggs.FarmThread
		Eggs.FarmThread = nil
		if thread then
			pcall(task.cancel, thread)
		end
		-- Silent when a new farm is taking over, so the toggle is not sent
		-- OFF and straight back ON within one frame.
		if not silent and paintFarm then
			paintFarm(false)
		end
	end

	-- AUTO PLACE EGGS -----------------------------------------------------
	-- Everything here is resolved from the player's own plot at run time rather
	-- than hardcoded: the container is whichever folder on the plot already
	-- holds eggs, and the slot count is read from the game's own value when it
	-- publishes one. No remote is fired and no name is guessed, so an update to
	-- the game shows up as "could not find" rather than as silent misbehaviour.
	local PLACE_CONTAINERS = {
		"Eggs",
		"EggHolder",
		"EggsHolder",
		"PlacedEggs",
		"RenderedEggs",
		"EquippedEggs",
		"HatchedEggs",
		"DisplayEggs",
		"ShowcaseEggs",
		"Decor",
	}
	local PLACE_SLOT_VALUES = {
		"MaxEggs",
		"EggSlots",
		"MaxEggSlots",
		"EggLimit",
		"MaxSlots",
		"PlotEggs",
		"EggCapacity",
		"Slots",
	}

	-- The folder on the plot that placed eggs live in. Cached: a plot is an
	-- expensive thing to search and the answer does not change while you are
	-- standing on it.
	local function findPlaceHolder()
		if Eggs.PlaceHolder and Eggs.PlaceHolder.Parent then
			return Eggs.PlaceHolder
		end
		local plot = scanMyPlot()
		if not plot then
			return nil
		end
		local data = plot:FindFirstChild("Data")
		for _, name in ipairs(PLACE_CONTAINERS) do
			local direct = plot:FindFirstChild(name)
			if direct and direct:IsA("Folder") then
				Eggs.PlaceHolder = direct
				return direct
			end
			if data then
				local nested = data:FindFirstChild(name)
				if nested and nested:IsA("Folder") then
					Eggs.PlaceHolder = nested
					return nested
				end
			end
		end
		-- Nothing matched by name, so make one bounded pass over the plot for a
		-- folder whose name mentions eggs. The result is remembered either way,
		-- so this runs at most once per plot.
		for _, child in ipairs(plot:GetDescendants()) do
			if child:IsA("Folder") and string.lower(child.Name):find("egg") then
				Eggs.PlaceHolder = child
				return child
			end
		end
		return nil
	end

	-- The game keeps a Nests folder on the plot with one numbered model per slot,
	-- and a slot you have not paid for still carries a Locked model inside it.
	-- That is the real capacity, so it is read straight off the plot instead of
	-- being guessed from an attribute name that may not exist.
	local function nestSlots()
		local plot = scanMyPlot()
		if not plot then
			return nil, 0, 0
		end
		local nests = plot:FindFirstChild("Nests")
		if not nests then
			return nil, 0, 0
		end
		local total, unlocked = 0, 0
		for _, nest in ipairs(nests:GetChildren()) do
			if nest:IsA("Model") then
				total = total + 1
				if not nest:FindFirstChild("Locked", true) then
					unlocked = unlocked + 1
				end
			end
		end
		return nests, total, unlocked
	end

	-- How many eggs the plot will actually take: the nests it has unlocked, and
	-- never more than the nests it owns. Only when the plot publishes no nests at
	-- all does this fall back to the old published-value search.
	local function placeLimit()
		local _, total, unlocked = nestSlots()
		if total > 0 then
			return math.max(1, math.min(unlocked, total))
		end
		local sources = {}
		local plot = scanMyPlot()
		if plot then
			table.insert(sources, plot)
			local data = plot:FindFirstChild("Data")
			if data then
				table.insert(sources, data)
			end
		end
		local saved = player:FindFirstChild("SavedData")
		if saved then
			table.insert(sources, saved)
		end
		for _, source in ipairs(sources) do
			for _, name in ipairs(PLACE_SLOT_VALUES) do
				local value = source:FindFirstChild(name)
				if value and (value:IsA("IntValue") or value:IsA("NumberValue")) and value.Value >= 1 then
					return math.floor(value.Value)
				end
			end
			for _, name in ipairs(PLACE_SLOT_VALUES) do
				local attribute = source:GetAttribute(name)
				if type(attribute) == "number" and attribute >= 1 then
					return math.floor(attribute)
				end
			end
		end
		local holder = findPlaceHolder()
		if holder and #holder:GetChildren() > 0 then
			return #holder:GetChildren()
		end
		return 1
	end

	local function placeRarityCount()
		local count = 0
		for _ in pairs(Eggs.PlaceRarities) do
			count = count + 1
		end
		return count
	end

	-- Rarest first, so scarce slots go to the best eggs on the server; distance
	-- only breaks ties inside a single rarity.
	local function nextPlaceEgg()
		if placeRarityCount() == 0 then
			return nil, nil, nil
		end
		local root = characterRoot()
		local best, bestRank, bestDistance = nil, -1, math.huge
		for egg in pairs(Eggs.Live) do
			if egg.Parent and Eggs.PlaceRarities[rarityOf(egg.Name)] then
				local part = getRootPart(egg)
				if part then
					local rank = RARITY_RANK[rarityOf(egg.Name)] or 0
					local distance = root and (root.Position - part.Position).Magnitude or 0
					if rank > bestRank or (rank == bestRank and distance < bestDistance) then
						best, bestRank, bestDistance = egg, rank, distance
					end
				end
			end
		end
		return best, bestRank, bestDistance
	end

	-- The prompt the game shows once you are holding an egg on your own plot.
	-- Matched on the action text because the instance is a clone the game
	-- parents onto the plot at that moment, and only the action is fixed.
	local function findPlacePrompt(plot)
		if not plot then
			return nil
		end
		local fallback = nil
		for _, descendant in ipairs(plot:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") and descendant.Enabled then
				local action = string.lower(descendant.ActionText or "")
				if string.find(action, "place", 1, true) then
					return descendant
				end
				if descendant.Name == "Place" then
					fallback = fallback or descendant
				end
			end
		end
		return fallback
	end

	-- The tool the game hands over when a world egg is collected. Egg tools are
	-- named after the egg they place, which is how the backpack is matched.
	local function findEggTool(eggName)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if not backpack then
			return nil
		end
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == eggName then
				return tool
			end
		end
		return nil
	end

	-- Places the egg the way a player does: collect it at the world prompt, take
	-- the tool the game gives, stand on the plot and fire the Place prompt.
	-- Nothing is cloned and no world egg is destroyed, so the server stays the
	-- only thing that decides what ends up on the plot, and the egg that appears
	-- is the one the game actually put there.
	local function placeEgg(egg)
		if not characterRoot() then
			return false, "your character is not ready"
		end
		local plot = scanMyPlot()
		if not plot then
			return false, "your plot was not found"
		end
		local holder = findPlaceHolder()
		if not holder then
			return false, "no egg folder was found on your plot"
		end
		if #holder:GetChildren() >= Eggs.PlaceLimit then
			return false, "every slot is already used"
		end
		local filled = #holder:GetChildren()
		local name = egg.Name
		local running = function()
			return Eggs.PlaceActive
		end

		-- Collected exactly as the farm collects, so the game issues the tool.
		if not moveToEgg(egg) then
			return false, "could not reach the egg"
		end
		local picked, reason = tryPickup(egg, running)
		if not picked then
			return false, reason
		end

		-- The tool is what actually gets placed, so the flow waits for it rather
		-- than assuming the pickup produced one.
		local tool = nil
		local deadline = os.clock() + 3
		while os.clock() < deadline do
			if not running() or not screen.Parent then
				return false, "cancelled"
			end
			tool = findEggTool(name)
			if tool then
				break
			end
			task.wait(0.1)
		end
		if not tool then
			return false, "no egg tool was given for " .. name
		end

		if not teleportHome(true) then
			return false, "could not get back to your plot"
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "no humanoid to hold the egg with"
		end
		humanoid:EquipTool(tool)
		task.wait(0.1)

		-- Re-read every attempt: the prompt is created when the tool is equipped,
		-- so it is often not there on the first look.
		local fired = false
		for _ = 1, PLACE_ATTEMPTS do
			if not running() or not screen.Parent then
				return false, "cancelled"
			end
			local prompt = findPlacePrompt(plot)
			if prompt and fireInstant(prompt) then
				fired = true
				break
			end
			task.wait(0.15)
		end
		if not fired then
			return false, "your plot offered no Place prompt"
		end

		-- Confirmed against the plot rather than assumed, so a prompt that did
		-- nothing is reported as a miss instead of counted as a placement.
		local settled = os.clock() + 3
		while os.clock() < settled do
			if #holder:GetChildren() > filled then
				Eggs.Counters.Placed = Eggs.Counters.Placed + 1
				return true
			end
			task.wait(0.1)
		end
		return false, "the game did not confirm the placement"
	end

	-- Returns how long to wait before the next pass. Every "nothing to do" path
	-- parks on the registry, so the placer reacts to a spawn in the same frame
	-- instead of after a fixed sleep.
	local function placeStep()
		if not Eggs.PlaceDiscovered then
			-- Resolved once per start, then only if the plot changes. The slider
			-- is widened to match, so the control can never offer a slot the
			-- plot will not take.
			local limit = placeLimit()
			Eggs.PlaceLimit = limit
			if placeSlotSlider and placeSlotSlider.SetMax then
				placeSlotSlider.SetMax(limit, true)
			end
			if Eggs.PlaceSlots > limit then
				Eggs.PlaceSlots = limit
				if placeSlotSlider then
					placeSlotSlider.Set(limit, true)
				end
			end
			Eggs.PlaceDiscovered = true
			publishEggs()
		end
		local holder = findPlaceHolder()
		if not holder then
			setPlaceStatus("On / Waiting for your plot", "waiting", "Your plot or its egg folder has not loaded yet")
			liveWait(0.3)
			return 0
		end
		local filled = #holder:GetChildren()
		if filled >= Eggs.PlaceSlots then
			setPlaceStatus("On / " .. filled .. " of " .. Eggs.PlaceSlots .. " slots used", "full", "Waiting for a slot to free up")
			liveWait(0.3)
			return 0
		end
		if placeRarityCount() == 0 then
			setPlaceStatus("On / Pick a rarity", "waiting", "No rarities selected yet")
			liveWait(0.3)
			return 0
		end
		local egg, _, distance = nextPlaceEgg()
		if not egg then
			setPlaceStatus("On / Waiting for a matching egg", "listening", "Listening for a rarity you selected")
			liveWait(0.3)
			return 0
		end
		local rarity = rarityOf(egg.Name)
		setPlaceStatus("On / Placing " .. egg.Name, "placing", "Moving it onto your plot", egg.Name, rarity, distance)
		local ok, reason = placeEgg(egg)
		if not ok then
			Eggs.PlaceMissed = Eggs.PlaceMissed + 1
			if Eggs.PlaceMissed <= 2 then
				warn("[Eggs] auto place could not place a " .. egg.Name .. " (" .. tostring(reason) .. ")")
			end
			-- The egg is very often still in the world after a miss, and it stays
			-- the top candidate, so the pass backs off instead of re-running this
			-- same attempt several times a second.
			return 1
		end
		publishEggs()
		return 0.1
	end

	local function startAutoPlace()
		stopAutoPlace(true)
		-- Placement is done by the game's own prompts, so an executor that cannot
		-- fire them can never place anything. Refused up front, the same way the
		-- farm refuses without an interact option, rather than as a silent miss.
		if type(fireproximityprompt) ~= "function" then
			notify("Auto place unavailable", "Error", "This executor cannot fire ProximityPrompts (fireproximityprompt is missing), so eggs cannot be placed.")
			return false
		end
		if not placeTemplate() then
			notify("Auto place unavailable", "Error", "ReplicatedStorage.Assets.Prompts.Place was not found, so this game cannot place eggs by prompt.")
			return false
		end
		Eggs.PlaceActive = true
		Eggs.PlaceMissed = 0
		Eggs.PlaceDiscovered = false
		-- Scan before the first pass, so an egg that is already out counts.
		if ensureWatched then
			ensureWatched()
		end
		recountLive()
		liveWake()
		if paintPlace then
			paintPlace(true)
		end
		if placeRarityCount() == 0 then
			notify("Auto place ON", "Info", "Pick at least one rarity below to give it something to place.", true)
			logActivity("Auto place started", "Waiting for rarities", "Info")
		else
			notify("Auto place ON", "Success", "Placing the rarest eggs it finds into your plot.", true)
			logActivity("Auto place started", placeRarityCount() .. " rarities selected", "Success")
		end

		Eggs.PlaceThread = task.spawn(function()
			local errors = 0
			while Eggs.PlaceActive and screen.Parent do
				local ok, result = pcall(placeStep)
				local delay = 0.4
				if ok then
					delay = tonumber(result) or 0.3
				else
					errors = errors + 1
					if errors <= 3 then
						warn("[Eggs] auto place step failed: " .. tostring(result))
					end
					delay = 1
				end
				task.wait(delay)
			end
			Eggs.PlaceActive = false
			Eggs.PlaceThread = nil
		end)
		return true
	end
	stopAutoPlace = function(silent)
		Eggs.PlaceActive = false
		local thread = Eggs.PlaceThread
		Eggs.PlaceThread = nil
		if thread then
			-- The placer's thread is cancelled outright, so it can never reach its
			-- own cleanup: end the phase session it may be holding first.
			if Phase.State and Phase.State.Owner == thread then
				Phase.End()
			end
			pcall(task.cancel, thread)
		end
		if not silent and paintPlace then
			paintPlace(false)
		end
	end

	-- AUTO MAX UPGRADE -----------------------------------------------------
	-- Buys the luck upgrade in bulk through the game's own Upgrades remote:
	-- "MaxFree" while free upgrades remain, "Max" for everything affordable,
	-- or a plain single buy. Affordability is read from the game's HatchLuck
	-- module so nothing is fired when there is nothing to buy. One loop at a
	-- time: every start bumps Token and older loops exit on their next pass.
	local Upg = { Token = 0, Remote = nil, Luck = nil, Row = nil, Toggle = nil, State = "" }

	local function setUpgStatus(text)
		if Upg.State == text then
			return
		end
		Upg.State = text
		if Upg.Row and Eggs.Running then
			Upg.Row.Text = text
			Upg.Row.TextColor3 = text:find("Buying") and Theme.Color.Positive
				or (text == "Idle" and Theme.Color.TextMid or Theme.Color.Caution)
		end
	end

	local function upgradeRemote()
		if Upg.Remote and Upg.Remote.Parent then
			return Upg.Remote
		end
		local node = game:GetService("ReplicatedStorage")
		for _, name in ipairs({ "Remotes", "Game", "Plot", "Upgrades" }) do
			node = node and node:FindFirstChild(name)
		end
		if node and node:IsA("RemoteEvent") then
			Upg.Remote = node
			return node
		end
		return nil
	end

	-- Blocking (timeouts), so only ever called from the upgrade loop.
	local function luckModule()
		if Upg.Luck == nil then
			local ok, module = pcall(function()
				local data = game:GetService("ReplicatedStorage"):WaitForChild("GameData", 3)
				return require(data:WaitForChild("HatchLuck", 3))
			end)
			Upg.Luck = (ok and type(module) == "table") and module or false
		end
		return Upg.Luck or nil
	end

	local function upgradeStep()
		local plot = scanMyPlot()
		if not plot or ownerOf(plot) ~= player then
			setUpgStatus("ON / Waiting for your plot")
			return 1
		end
		if player:GetAttribute("Setting_LuckMultiplier") == false then
			setUpgStatus("ON / Turn on Luck Multiplier setting")
			return 1
		end
		local saved = player:FindFirstChild("SavedData")
		local upgrades = saved and saved:FindFirstChild("HatchUpgrades")
		local cash = saved and saved:FindFirstChild("Cash")
		if not upgrades or not cash then
			setUpgStatus("ON / Waiting for data")
			return 1
		end
		local remote = upgradeRemote()
		if not remote then
			setUpgStatus("ON / Upgrade remote missing")
			return 2
		end
		local freeValue = saved:FindFirstChild("FreeHatchUpgrades")
		local used = saved:FindFirstChild("UsedFreeHatchUpgrades")
		if freeValue and (tonumber(freeValue.Value) or 0) > 0 then
			remote:FireServer("MaxFree")
			setUpgStatus("ON / Buying free upgrades")
			return 0.6
		end
		local luck = luckModule()
		if luck then
			local paid = luck.GetPaidUpgrades(upgrades.Value, used and used.Value or 0)
			local count = luck.GetMaxAffordable(paid, tonumber(cash.Value) or 0)
			if count >= 2 then
				remote:FireServer("Max")
			elseif count == 1 then
				remote:FireServer()
			else
				setUpgStatus("ON / Waiting for cash")
				return 0.5
			end
			setUpgStatus("ON / Buying upgrades")
			return 0.6
		end
		-- Module unavailable: the server ignores a Max it cannot afford.
		remote:FireServer("Max")
		setUpgStatus("ON / Buying upgrades")
		return 2
	end

	local function stopAutoUpgrade()
		Upg.Token = Upg.Token + 1
		setUpgStatus("Idle")
	end

	local function startAutoUpgrade()
		if not upgradeRemote() then
			notify("Auto Max Upgrade unavailable", "Error", "ReplicatedStorage.Remotes.Game.Plot.Upgrades was not found.")
			return false
		end
		Upg.Token = Upg.Token + 1
		local token = Upg.Token
		Upg.State = ""
		setUpgStatus("ON / Waiting for cash")
		task.spawn(function()
			local errors = 0
			while Upg.Token == token and Eggs.Running and screen.Parent do
				local ok, result = pcall(upgradeStep)
				if not ok then
					errors = errors + 1
					if errors <= 3 then
						warn("[Eggs] auto upgrade failed: " .. tostring(result))
					end
				end
				task.wait(ok and tonumber(result) or 1)
			end
		end)
		return true
	end
	-- ESP + LIST ----------------------------------------------------------

	-- Overlays fade in and out instead of popping, and are coloured by egg
	-- rarity so the good ones stand out from across the map.
	local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local HL_FILL, HL_OUTLINE = 0.82, 0.05
	local warnedESP = false

	local function espEnabledFor(name)
		local group = Eggs.Groups[name]
		return Eggs.GlobalESP and (not group or group.TypeESP)
	end

	local function buildHighlight(model, color, visible)
		return New("Highlight", {
			Name = "EggHighlight",
			Adornee = model,
			FillColor = color,
			OutlineColor = color,
			FillTransparency = visible and HL_FILL or 1,
			OutlineTransparency = visible and HL_OUTLINE or 1,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Enabled = visible,
			Parent = model,
		})
	end

	local function fadeESP(esp, visible)
		if esp.Visible == visible then
			return
		end
		esp.Visible = visible
		esp.Token = (esp.Token or 0) + 1
		local token = esp.Token
		if visible then
			esp.Billboard.Enabled = true
			if esp.Highlight then
				esp.Highlight.Enabled = true
			end
		end
		TweenService:Create(esp.Card, FADE, { GroupTransparency = visible and 0 or 1 }):Play()
		if esp.Highlight then
			TweenService:Create(esp.Highlight, FADE, {
				FillTransparency = visible and HL_FILL or 1,
				OutlineTransparency = visible and HL_OUTLINE or 1,
			}):Play()
		end
		if not visible then
			task.delay(FADE.Time + 0.05, function()
				if esp.Token ~= token then
					return
				end
				if esp.Billboard and esp.Billboard.Parent then
					esp.Billboard.Enabled = false
				end
				if esp.Highlight and esp.Highlight.Parent then
					esp.Highlight.Enabled = false
				end
			end)
		end
	end

	local function buildESP(model)
		local root = getRootPart(model)
		if not root then
			return
		end
		local rarity = rarityOf(model.Name)
		local color = rarityColor(rarity)

		local billboard = New("BillboardGui", {
			Name = "EggESP",
			Adornee = root,
			AlwaysOnTop = true,
			Active = false,
			LightInfluence = 0,
			MaxDistance = math.huge,
			Size = UDim2.fromOffset(190, 46),
			StudsOffset = Vector3.new(0, 3.4, 0),
			Enabled = false,
			Parent = root,
		})
		local card = New("CanvasGroup", {
			Name = "Card",
			BackgroundColor3 = Theme.Color.Surface,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = billboard,
		})
		Round(card, Theme.Radius.SM)
		Stroke(card, 0.35, color, 1.5)
		New("Frame", {
			Name = "Accent",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 1, 0),
			Parent = card,
		})
		Text(card, model.Name, Theme.Type.Body, "SemiBold", Theme.Color.TextHi, {
			Name = "EggName",
			Position = UDim2.fromOffset(14, 5),
			Size = UDim2.new(1, -20, 0, 20),
		})
		local sub = Text(card, rarity, Theme.Type.Caption, "Medium", color, {
			Name = "Details",
			Position = UDim2.fromOffset(14, 25),
			Size = UDim2.new(1, -20, 0, 16),
		})

		local highlight = nil
		if Eggs.ShowHighlight then
			highlight = buildHighlight(model, color, false)
		end
		local esp = {
			Billboard = billboard,
			Card = card,
			Sub = sub,
			Root = root,
			Highlight = highlight,
			Rarity = rarity,
			Color = color,
			Visible = false,
		}
		Eggs.ESPs[model] = esp
		fadeESP(esp, espEnabledFor(model.Name) and true or false)
	end

	-- Wrapped so one odd egg can never take the scan loop down with it.
	local function createESP(model)
		if Eggs.ESPs[model] then
			return
		end
		local ok, err = pcall(buildESP, model)
		if not ok and not warnedESP then
			warnedESP = true
			warn("[Eggs] egg ESP could not be built: " .. tostring(err))
		end
	end

	local function destroyESP(model)
		local esp = Eggs.ESPs[model]
		if not esp then
			return
		end
		esp.Token = (esp.Token or 0) + 1
		if esp.Billboard then
			esp.Billboard:Destroy()
		end
		if esp.Highlight then
			esp.Highlight:Destroy()
		end
		Eggs.ESPs[model] = nil
	end

	-- ESP DRIVER -----------------------------------------------------------
	-- One Heartbeat connection keeps every overlay's distance current. It is
	-- always disconnected before being recreated, so respawns and watchdog
	-- restarts can never stack a second copy. Overlays whose anchor part was
	-- destroyed or replaced are rebuilt individually instead of everything
	-- being recreated each frame.
	local ESP_STEP = 0.1
	local Driver = { Conn = nil, Last = 0, Accum = 0, Errors = 0 }

	local function distanceText(esp, root, part)
		if root and part then
			local shown = math.floor((root.Position - part.Position).Magnitude + 0.5)
			if shown ~= esp.LastShown then
				esp.LastShown = shown
				esp.Sub.Text = string.format("%s  ·  %d studs", esp.Rarity, shown)
			end
		elseif esp.LastShown ~= nil then
			esp.LastShown = nil
			esp.Sub.Text = esp.Rarity
		end
	end

	local function stepESP(dt)
		Driver.Last = os.clock()
		Driver.Accum = Driver.Accum + dt
		if Driver.Accum < ESP_STEP then
			return
		end
		Driver.Accum = 0
		if not Gate.Authenticated then
			return
		end
		local root = characterRoot()
		local stale = nil
		for model, esp in pairs(Eggs.ESPs) do
			local part = model.Parent and getRootPart(model) or nil
			if not part or part ~= esp.Root or not esp.Billboard or not esp.Billboard.Parent then
				stale = stale or {}
				table.insert(stale, model)
			else
				distanceText(esp, root, part)
			end
		end
		if stale then
			for _, model in ipairs(stale) do
				destroyESP(model)
				if model.Parent and Eggs.Entries[model] then
					createESP(model)
				end
			end
		end
	end

	local function stopESPDriver()
		if Driver.Conn then
			Driver.Conn:Disconnect()
			Driver.Conn = nil
		end
	end

	local function startESPDriver()
		stopESPDriver()
		Driver.Accum = 0
		Driver.Last = os.clock()
		Driver.Conn = RunService.Heartbeat:Connect(function(dt)
			if not Eggs.Running or not screen.Parent then
				stopESPDriver()
				return
			end
			local ok, err = pcall(stepESP, dt)
			if not ok then
				Driver.Errors = Driver.Errors + 1
				if Driver.Errors <= 3 then
					warn("[Eggs] ESP update error: " .. tostring(err))
				end
			end
		end)
	end

	-- A compact ON/OFF chip, used for the per-group ESP and FARM switches.
	-- `onChange` receives the new value on every click; there is no separate
	-- subscription step so a caller can never forget to wire it up.
	local pillRegistry = setmetatable({}, { __mode = "k" })
	bindAccent(function()
		for render in pairs(pillRegistry) do
			render()
		end
	end)

	local function pillButton(parent, on, onChange)
		local on_ = on == true
		local button = New("TextButton", {
			Name = "Pill",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(52, 22),
			Parent = parent,
		})
		Round(button, Theme.Radius.XS)
		local stroke = Stroke(button, 0.85)
		local label = Text(button, "", Theme.Type.Micro, "SemiBold", Theme.Color.TextLow, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local function render()
			label.Text = on_ and "ON" or "OFF"
			label.TextColor3 = on_ and Accent.Text or Theme.Color.TextLow
			stroke.Color = on_ and Accent.Color or Theme.Color.White
			stroke.Transparency = on_ and 0.3 or 0.85
			button.BackgroundColor3 = on_ and Accent.Color or Theme.Color.White
			button.BackgroundTransparency = on_ and 0.72 or 0.9
		end
		pillRegistry[render] = true
		render()
		attachFeedback(button, { Rest = 0.9, Hover = 0.82, Press = 0.7, PressScale = 0.94 })
		button.Activated:Connect(function()
			on_ = not on_
			render()
			if onChange then
				onChange(on_)
			end
		end)
		return {
			Instance = button,
			Get = function()
				return on_
			end,
			Set = function(value)
				on_ = value == true
				render()
			end,
		}
	end

	-- Rows and groups are created once and kept; the search only toggles
	-- visibility, and sorting rewrites LayoutOrder.
	local listColumn = nil
	local emptyLabel = nil
	local countLabel = nil
	local rarityHeaders = {}

	local function rarityHeader(rarity)
		local header = rarityHeaders[rarity]
		if header and header.Parent then
			return header
		end
		header = Text(listColumn, string.upper(rarity), Theme.Type.Micro, "SemiBold", rarityColor(rarity), {
			Name = "RarityHeader",
			Size = UDim2.new(1, 0, 0, 20),
			Visible = false,
		})
		Padding(header, 0, 0, 0, 6)
		rarityHeaders[rarity] = header
		return header
	end

	-- Headers only exist in Rarity mode, and only over rarities with a visible group.
	local function updateRarityHeaders()
		local show = Eggs.SortBy == "Rarity"
		local seen = {}
		if show then
			for _, group in pairs(Eggs.Groups) do
				if group.Frame.Visible then
					seen[group.Rarity] = true
				end
			end
		end
		for rarity, header in pairs(rarityHeaders) do
			header.Visible = show and seen[rarity] == true
		end
	end

	local function applyFilter()
		local query = string.lower(Eggs.Query)
		local visible = 0
		for name, group in pairs(Eggs.Groups) do
			local groupVisible = false
			for model, entry in pairs(group.Eggs) do
				local matches = query == "" or string.find(string.lower(name), query, 1, true) ~= nil
				entry.Frame.Visible = matches
				if matches then
					groupVisible = true
					visible = visible + 1
				end
			end
			group.Frame.Visible = groupVisible
		end
		if emptyLabel then
			emptyLabel.Visible = visible == 0
		end
		if countLabel then
			countLabel.Text = tostring(visible) .. " / " .. tostring(Eggs.Total)
		end
		updateRarityHeaders()
	end

	-- Distance is only known once the player exists, so ordering is
	-- recomputed whenever a new egg shows up or the sort mode changes.
	local function applySort()
		if not listColumn then
			return
		end
		local names = {}
		for name in pairs(Eggs.Groups) do
			table.insert(names, name)
		end
		local mode = Eggs.SortBy
		local function alpha(a, b)
			return a:lower() < b:lower()
		end
		if mode == "Nearest" then
			table.sort(names, function(a, b)
				local da = Eggs.Groups[a].Distance or math.huge
				local db = Eggs.Groups[b].Distance or math.huge
				if da ~= db then
					return da < db
				end
				return alpha(a, b)
			end)
		elseif mode == "Rarity" then
			-- Grouped by rarity, Common up to Ethereal, unknown last; A to Z inside a group.
			table.sort(names, function(a, b)
				local rankA = rarityRank(a) == 0 and 99 or rarityRank(a)
				local rankB = rarityRank(b) == 0 and 99 or rarityRank(b)
				if rankA ~= rankB then
					return rankA < rankB
				end
				return alpha(a, b)
			end)
		elseif mode == "Best" then
			-- Highest value first: rarity, then price, then name.
			table.sort(names, function(a, b)
				local rankA, rankB = rarityRank(a), rarityRank(b)
				if rankA ~= rankB then
					return rankA > rankB
				end
				local priceA, priceB = eggPrice(a), eggPrice(b)
				if priceA ~= priceB then
					return priceA > priceB
				end
				return alpha(a, b)
			end)
		else
			table.sort(names, alpha)
		end

		local order = 0
		local lastRarity = nil
		for _, name in ipairs(names) do
			local group = Eggs.Groups[name]
			if mode == "Rarity" and group.Rarity ~= lastRarity then
				lastRarity = group.Rarity
				order = order + 1
				rarityHeader(group.Rarity).LayoutOrder = order
			end
			order = order + 1
			group.Frame.LayoutOrder = order
		end

		if mode == "Nearest" then
			for _, group in pairs(Eggs.Groups) do
				local rows = {}
				for _, entry in pairs(group.Eggs) do
					if type(entry) == "table" then
						table.insert(rows, entry)
					end
				end
				table.sort(rows, function(a, b)
					return (a.Distance or math.huge) < (b.Distance or math.huge)
				end)
				for index, entry in ipairs(rows) do
					entry.Frame.LayoutOrder = index
				end
			end
		end
		updateRarityHeaders()
	end
	local function refreshESPState()
		for model, esp in pairs(Eggs.ESPs) do
			fadeESP(esp, espEnabledFor(model.Name) and true or false)
		end
	end

	local function removeEgg(model)
		destroyESP(model)
		Eggs.Processed[model] = nil
		local group = Eggs.Groups[model.Name]
		if group then
			group.Eggs[model] = nil
			local entry = Eggs.Entries[model]
			if entry and entry.Frame then
				entry.Frame:Destroy()
			end
			Eggs.Entries[model] = nil
			if not next(group.Eggs) then
				group.Frame:Destroy()
				Eggs.Groups[model.Name] = nil
			end
		end
	end

	local function registerEgg(model)
		if Eggs.Entries[model] then
			return
		end
		local name = model.Name
		local group = Eggs.Groups[name]
		if not group then
			local frame = New("Frame", {
				Name = "Group",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = listColumn,
			})
			New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				Parent = frame,
			})
			-- No layout on the header: the title is scale-sized and a
			-- horizontal UIListLayout would read that scale as the full
			-- width and push the switches off the right edge. The switches
			-- are anchored to the right instead.
			local header = New("Frame", {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				Parent = frame,
			})
		local title = New("TextButton", {
			Name = "Title",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -276, 1, 0),
			ClipsDescendants = true,
			Parent = header,
		})
			local titleLabel = Text(title, "▶  " .. name, Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
				Size = UDim2.fromScale(1, 1),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			attachFeedback(title, { Rest = 1, Hover = 0.95, Press = 0.9 })
			local container = New("Frame", {
				Name = "Container",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = frame,
			})
			New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
				Parent = container,
			})
			group = {
				Name = name,
				Rarity = rarityOf(name),
				Frame = frame,
				Header = header,
				Title = title,
				TitleLabel = titleLabel,
				Container = container,
				Eggs = {},
				Expanded = false,
				TypeESP = Eggs.TypeESPOff[name] ~= true,
				Distance = nil,
			}
			-- Rarity sits between the name and the ESP switch. Every egg in a
			-- group shares one rarity, so it is shown once here instead of on
			-- each row.
			Text(header, group.Rarity, Theme.Type.Micro, "SemiBold", rarityColor(group.Rarity), {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -198, 0, 3),
				Size = UDim2.fromOffset(74, 22),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			title.Activated:Connect(function()
				group.Expanded = not group.Expanded
				group.Container.Visible = group.Expanded
				group.TitleLabel.Text = (group.Expanded and "▼  " or "▶  ") .. name
			end)
			Eggs.Groups[name] = group

			-- Caption then switch, laid out from the right edge inwards so
			-- each label stays attached to the switch it names.
			Text(header, "ESP", Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -162, 0, 2),
				Size = UDim2.fromOffset(30, 22),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local espPill = pillButton(header, group.TypeESP, function(value)
				group.TypeESP = value
				Eggs.TypeESPOff[name] = (not value) or nil
				refreshESPState()
			end)
			group.EspPill = espPill
			espPill.Instance.AnchorPoint = Vector2.new(1, 0)
			espPill.Instance.Position = UDim2.new(1, -104, 0, 2)
			Text(header, "FARM", Theme.Type.Micro, "Medium", Theme.Color.TextLow, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -64, 0, 2),
				Size = UDim2.fromOffset(34, 22),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local farmPill = pillButton(header, Eggs.FarmTypes[name] == true, function(value)
				if value then
					Eggs.FarmTypes[name] = true
				else
					Eggs.FarmTypes[name] = nil
					Eggs.Processed = {}
				end
			end)
			farmPill.Instance.AnchorPoint = Vector2.new(1, 0)
			farmPill.Instance.Position = UDim2.new(1, -6, 0, 2)
			group.FarmPill = farmPill
		end
		group.Eggs[model] = true

		local row = New("Frame", {
			Name = "Egg",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = group.Container,
		})
		-- Positioned rather than laid out, for the same reason as the group
		-- header: the name is scale-sized, so a horizontal UIListLayout would
		-- give it the full row width and push the TP button out of view.
		New("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(20, 20),
			Image = getEggImage(name),
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
		local label = Text(row, name, Theme.Type.Caption, "Regular", Theme.Color.TextMid, {
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -170, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		-- Rarity beside every egg, not only on its group header.
		local eggRarity = rarityOf(name)
		Text(row, eggRarity, Theme.Type.Micro, "SemiBold", rarityColor(eggRarity), {
			Name = "Rarity",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -66, 0.5, 0),
			Size = UDim2.fromOffset(78, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local tp = Button(row, {
			Text = "TP",
			Icon = "sparkle",
			Size = UDim2.fromOffset(58, 22),
			Callback = function()
				local goal = eggTopCFrame(model)
				if not goal then
					notify("Egg not ready", "Warning", "That egg has no usable parts yet.")
					return
				end
				local ok, reason = safeTeleport(goal)
				if ok then
					notify("Teleported", "Success", "Moved to " .. name .. ".", true)
					logActivity("Teleported", "Moved to " .. name, "Success")
				else
					notify("Teleport failed", "Error", reason)
				end
			end,
		})
		tp.Instance.AnchorPoint = Vector2.new(1, 0.5)
		tp.Instance.Position = UDim2.new(1, -2, 0.5, 0)
		local entry = { Frame = row, Label = label, Distance = nil }
		Eggs.Entries[model] = entry
		-- applyFilter / applySort read the row through the group.
		group.Eggs[model] = entry
	end

	-- UI ------------------------------------------------------------------

	local status = Section(column, "Scanner")
	countLabel = InfoRow(status, "Eggs listed", "0 / 0", Theme.Color.TextHi)
	local folderRow = InfoRow(status, "Egg folder", "Checking...")
	local plotsRow = InfoRow(status, "Plots folder", "Checking...")
	-- Scanner health: is it wired up, how many eggs the farm's registry holds
	-- (compared with what the list shows), and how fresh the last pass is.
	local scannerRow = InfoRow(status, "Egg scanner", "Checking...")
	local detectedRow = InfoRow(status, "Eggs detected", "0", Theme.Color.TextHi)
	local scanAgeRow = InfoRow(status, "Last scan", "--", Theme.Color.TextMid)
	local farmInfo = InfoRow(status, "Auto farm", "Idle", Theme.Color.TextMid)

	function Eggs.Diag.Paint()
		local ok, present = Eggs.Diag.Health()
		if ok then
			scannerRow.Text = "\u{25CF} Connected"
			scannerRow.TextColor3 = Theme.Color.Positive
		elseif present then
			scannerRow.Text = "\u{25CB} Not watching"
			scannerRow.TextColor3 = Theme.Color.Negative
		else
			scannerRow.Text = "\u{25CB} Waiting for folder"
			scannerRow.TextColor3 = Theme.Color.Caution
		end
		local detected = Eggs.Counters.Detected or 0
		local listed = Eggs.Total or 0
		if detected ~= listed then
			-- The farm reads the registry, the list reads its own entries. A
			-- difference between the two is the "list sees it, farm doesn't" case.
			detectedRow.Text = string.format("%d   (list shows %d)", detected, listed)
			detectedRow.TextColor3 = Theme.Color.Caution
		else
			detectedRow.Text = tostring(detected)
			detectedRow.TextColor3 = Theme.Color.TextHi
		end
		local age = Eggs.Diag.Age(Eggs.Diag.LastScan)
		scanAgeRow.Text = age and string.format("%.2fs ago", age) or "--"
		scanAgeRow.TextColor3 = (age and age > 2) and Theme.Color.Caution or Theme.Color.TextMid
	end

	local searchSection = Section(column, "Egg list")

	local selectSort = nil
	local sortHead = New("TextButton", {
		Name = "SortDropdown",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Alt,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = nextOrder(searchSection),
		Parent = searchSection,
	})
	Round(sortHead, Theme.Radius.SM)
	local sortStroke = Stroke(sortHead, 0.85)
	-- A drawn caret rather than the "▲"/"▼" characters the header used before,
	-- so the dropdown matches the rest of the icon set and the arrow is
	-- centred on the same grid as every other glyph.
	Icon(sortHead, "chevronUp", 13, Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
	})
	Text(sortHead, "Sort", Theme.Type.Caption, "Medium", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.fromOffset(52, 34),
	})
	local sortValue = Text(sortHead, "", Theme.Type.Body, "SemiBold", Accent.Text, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 0),
		Size = UDim2.new(1, -98, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local sortCaret = Icon(sortHead, "chevronUp", 13, Theme.Color.TextMid, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
	})
	-- Rotated rather than swapped, because chevronUp points up: 180 means closed.
	sortCaret.Rotation = 180
	attachFeedback(sortHead, { Rest = 0.3, Hover = 0.2, Press = 0.1 })
	local sortMenu = New("Frame", {
		Name = "SortMenu",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = nextOrder(searchSection),
		Parent = searchSection,
	})
	Round(sortMenu, Theme.Radius.SM)
	Stroke(sortMenu, 0.88)
	Padding(sortMenu, 4, 4, 4, 4)
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = sortMenu,
	})
	local sortOptions = {}
	for index, mode in ipairs(SORT_MODES) do
		local option = New("TextButton", {
			Name = "Sort_" .. mode.Key,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = index,
			Parent = sortMenu,
		})
		Round(option, Theme.Radius.XS)
		local bar = New("Frame", {
			BackgroundColor3 = Accent.Color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(3, 16),
			Visible = false,
			Parent = option,
		})
		Round(bar, Theme.Radius.Pill)
		local label = Text(option, mode.Key, Theme.Type.Body, "SemiBold", Theme.Color.TextMid, {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.fromOffset(90, 32),
		})
		Text(option, mode.Hint, Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(1, -120, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		attachFeedback(option, { Rest = 1, Hover = 0.93, Press = 0.86 })
		option.Activated:Connect(function()
			if selectSort then
				selectSort(mode.Key)
			end
		end)
		sortOptions[mode.Key] = { Button = option, Bar = bar, Label = label }
	end
	local function paintSort()
		for key, option in pairs(sortOptions) do
			local active = key == Eggs.SortBy
			option.Bar.Visible = active
			option.Bar.BackgroundColor3 = Accent.Color
			option.Button.BackgroundColor3 = active and Accent.Color or Theme.Color.White
			option.Button.BackgroundTransparency = active and 0.82 or 1
			option.Label.TextColor3 = active and Theme.Color.TextHi or Theme.Color.TextMid
		end
		sortValue.Text = Eggs.SortBy
		sortValue.TextColor3 = Accent.Text
	end
	bindAccent(paintSort)
	sortHead.Activated:Connect(function()
		sortMenu.Visible = not sortMenu.Visible
		play(sortCaret, Motion.Quick, "Out", { Rotation = sortMenu.Visible and 0 or 180 })
		play(sortStroke, Motion.Quick, "Out", {
			Color = sortMenu.Visible and Accent.Color or Theme.Color.White,
			Transparency = sortMenu.Visible and 0.35 or 0.85,
		})
	end)

	local searchFrame = New("Frame", {
		Name = "Search",
		BackgroundColor3 = Theme.Color.Alt,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = nextOrder(searchSection),
		Parent = searchSection,
	})
	Round(searchFrame, Theme.Radius.SM)
	local searchStroke = Stroke(searchFrame, 0.85)
	-- Leading glyph so the field reads as a filter at a glance rather than as a
	-- blank text box.
	Icon(searchFrame, "search", 13, Theme.Color.TextLow, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 11, 0.5, 0),
	})
	local searchBox = New("TextBox", {
		Name = "Box",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -38, 1, 0),
		Position = UDim2.fromOffset(30, 0),
		ClearTextOnFocus = false,
		PlaceholderText = "Search egg types...",
		PlaceholderColor3 = Theme.Color.TextLow,
		Text = "",
		TextColor3 = Theme.Color.TextHi,
		TextSize = Theme.Type.Caption,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = searchFrame,
	})
	applyFont(searchBox, "Medium")
	searchBox.Focused:Connect(function()
		play(searchStroke, Motion.Quick, "Out", { Color = Accent.Color, Transparency = 0.35 })
	end)
	searchBox.FocusLost:Connect(function()
		play(searchStroke, Motion.Quick, "Out", { Color = Theme.Color.White, Transparency = 0.85 })
	end)
	track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		Eggs.Query = searchBox.Text
		applyFilter()
	end))

	local list = New("ScrollingFrame", {
		Name = "List",
		BackgroundColor3 = Theme.Color.Surface,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 260),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Color.White,
		ScrollBarImageTransparency = 0.7,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		LayoutOrder = nextOrder(searchSection),
		Parent = searchSection,
	})
	Round(list, Theme.Radius.SM)
	Padding(list, 4, 4, 4, 4)
	listColumn = New("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = list,
	})
	New("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = listColumn,
	})
	emptyLabel = Text(listColumn, "No eggs found yet.", Theme.Type.Caption, "Regular", Theme.Color.TextLow, {
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- One complete pass over the egg folder: forgets the cached plot lookups,
	-- drops anything that left the folder, re-registers every model and rebuilds
	-- the list ordering. The per-tick scanner is incremental, so this is what the
	-- Reload button, the post-load scan and the respawn scan all go through.
	local function fullRescan()
		Eggs.PlotScans = 0
		Eggs.CachedPlot = nil
		Eggs.CachedBaseplate = nil
		local folder = workspace:FindFirstChild("RenderedEggs")
		Eggs.Folder = folder

		local stale = nil
		for model in pairs(Eggs.Entries) do
			if not model.Parent or not folder or not model:IsDescendantOf(folder) then
				stale = stale or {}
				table.insert(stale, model)
			end
		end
		if stale then
			for _, model in ipairs(stale) do
				removeEgg(model)
			end
		end

		if folder then
			for _, egg in ipairs(folder:GetDescendants()) do
				if egg:IsA("Model") then
					registerEgg(egg)
				end
			end
		end
		applyFilter()
		applySort()
		return folder
	end

	Config.Rescan = fullRescan

	local listActions = Section(column, "List controls")
	local listGrid = ButtonGrid(listActions, 2)
	-- Applies immediately: the list is re-ordered and the menu closes.
	selectSort = function(key)
		if not validSort(key) then
			return
		end
		Eggs.SortBy = key
		State.EggsSort = key
		applySort()
		paintSort()
		sortMenu.Visible = false
		play(sortCaret, Motion.Quick, "Out", { Rotation = 180 })
		play(sortStroke, Motion.Quick, "Out", { Color = Theme.Color.White, Transparency = 0.85 })
	end
	Button(listGrid, {
		Text = "Expand all",
		Icon = "grid",
		Callback = function()
			for _, group in pairs(Eggs.Groups) do
				group.Expanded = true
				group.Container.Visible = true
				group.TitleLabel.Text = "▼  " .. group.Name
			end
		end,
	})
	Button(listGrid, {
		Text = "Collapse all",
		Icon = "grid",
		Callback = function()
			for _, group in pairs(Eggs.Groups) do
				group.Expanded = false
				group.Container.Visible = false
				group.TitleLabel.Text = "▶  " .. group.Name
			end
		end,
	})
	Button(listGrid, {
		Text = "Reload Eggs",
		Icon = "refresh",
		Callback = function()
			local folder = fullRescan()
			if folder then
				notify("Eggs reloaded", "Success", "Re-scanned the egg folder.")
			else
				notify("Eggs not found", "Caution", "workspace.RenderedEggs is not available yet.")
			end
		end,
	})

	local teleport = Section(column, "Teleport")
	local homeGrid = ButtonGrid(teleport, 2)
	Button(homeGrid, {
		Text = "TP to my plot",
		Icon = "home",
		Style = "Primary",
		Callback = function()
			if teleportHome(false) then
				logActivity("Teleported home", "Back on your plot", "Success")
			end
		end,
	})
	Button(homeGrid, {
		Text = "Set home key",
		Icon = "key",
		Callback = function()
			Eggs.Listening = true
			notify("Press a key", "Info", "It becomes your teleport-home shortcut.", true)
		end,
	})
	local homeKeyInfo = InfoRow(teleport, "Home shortcut", string.upper(Eggs.HomeKey.Name))
	Slider(teleport, {
		Text = "Teleport height",
		Min = 2, Max = 40, Default = DEFAULTS.EggsTPHeight, Step = 1, Suffix = " studs",
		Callback = function(value)
			State.EggsTPHeight = value
			Eggs.HeightOffset = value
		end,
	})
	Toggle(teleport, {
		Text = "Walk to eggs",
		Description = "Phase through walls: up or down to the egg's height, across to it, a dip after pickup, then home. Off teleports instead",
		Default = DEFAULTS.EggsSmoothMove,
		Callback = function(enabled)
			State.EggsSmoothMove = enabled
			Eggs.SmoothMove = enabled
			if not enabled then
				stopMovement()
			end
		end,
	})
	Slider(teleport, {
		Text = "Walk speed",
		Min = 50, Max = 1500, Default = DEFAULTS.EggsMoveSpeed, Step = 25, Suffix = " studs/s",
		Callback = function(value)
			State.EggsMoveSpeed = value
			Eggs.MoveSpeed = value
		end,
	})

	-- SERVER ----------------------------------------------------------------
	-- Built further down, after the farm and place sections, so the Automation
	-- page reads in the order things are used: farm, place, upgrades, hop.
	local stopServerHop = nil

	local farm = Section(autoColumn, "Auto farm")
	InfoRow(farm, "How it works", "Stays ON and waits when no eggs are out", Theme.Color.TextMid)
	-- Shared: the switch reads and writes the same state as the Home quick
	-- action and the overlay (Features "farm" -> hub.SetFarm, which starts or
	-- stops the farm; only a missing input service refuses, an empty egg list
	-- does not, the farm waits for the next egg instead).
	autoFarmToggle = Toggle(farm, {
		Text = "Auto farm",
		Description = "Walks to every egg of the rarities you pick, presses E, returns to your plot",
		Default = DEFAULTS.EggsAutoFarm,
		Shared = "farm",
	})
	InfoRow(farm, "Farm by rarity", "Any rarity on overrides the FARM marks", Theme.Color.TextMid)
	-- Best first, so the top of the list is the prize eggs. Built from the
	-- game's own data, so a rarity this script has never heard of still shows.
	for index = #RARITY_LIST, 1, -1 do
		local rarity = RARITY_LIST[index]
		Toggle(farm, {
			Text = rarity,
			TextColor = rarityColor(rarity),
			Default = false,
			Callback = function(enabled)
				if enabled then
					Eggs.FarmRarities[rarity] = true
				else
					Eggs.FarmRarities[rarity] = nil
				end
				-- Eggs already dismissed under the old target set must be
				-- allowed to run again.
				if Eggs.FarmActive then
					Eggs.Processed = {}
				end
			end,
		})
	end
	Slider(farm, {
		Text = "Interact hold time",
		Min = 0.5, Max = 10, Default = DEFAULTS.EggsHoldTime, Step = 0.5, Suffix = " s",
		Callback = function(value)
			State.EggsHoldTime = value
			Eggs.HoldTime = value
		end,
	})
	local farmGrid = ButtonGrid(farm, 2)
	Button(farmGrid, {
		Text = "Stop farming",
		Icon = "close",
		Style = "Danger",
		Callback = function()
			stopAutoFarm()
			notify("Auto farm stopped", "Warning", "Movement and the interact key were released.")
		end,
	})
	Button(farmGrid, {
		Text = "Release key",
		Icon = "close",
		Callback = function()
			stopMovement()
			releaseInteract()
			notify("Released", "Success", "Noclip off and E is no longer held.")
		end,
	})

	-- AUTO PLACE ------------------------------------------------------------
	-- The slot limit is not hardcoded: it is read from the plot when the placer
	-- starts, and the slider is widened to match. That is what keeps this from
	-- promising slots the game will not hold.
	local placeRows = { Status = nil, Slots = nil, Folder = nil, Limit = nil }
	local place = Section(autoColumn, "Auto place")
	InfoRow(place, "How it works", "Collects the rarest egg you allow, then places it in a nest on your plot", Theme.Color.TextMid)
	placeRows.Status = InfoRow(place, "Auto place", "Off", Theme.Color.TextMid)
	placeRows.Slots = InfoRow(place, "Egg slots", "Checking...", Theme.Color.TextMid)
	placeRows.Folder = InfoRow(place, "Plot egg folder", "Checking...", Theme.Color.TextMid)
	placeRows.Limit = InfoRow(place, "Unlocked nests", "Checking...", Theme.Color.TextMid)

	local autoPlaceToggle = Toggle(place, {
		Text = "Auto place",
		Description = "Fills the nests you have unlocked with the rarest eggs it can find",
		Default = DEFAULTS.EggsAutoPlace,
		Shared = "place",
	})

	InfoRow(place, "Slot limit", "Taken from your plot, never higher than the game allows", Theme.Color.TextMid)
	placeSlotSlider = Slider(place, {
		Text = "Egg slots to fill",
		Min = 1,
		Max = 8,
		Default = DEFAULTS.EggsPlaceSlots,
		Step = 1,
		Callback = function(value)
			State.EggsPlaceSlots = value
			-- Until the plot has actually been scanned, Eggs.PlaceLimit is only a
			-- placeholder, so narrowing the slider here would permanently cap a
			-- restored value at 1. The real limit is applied by placeStep, which
			-- has seen the folder by then.
			local limit = Eggs.PlaceDiscovered and Eggs.PlaceLimit or value
			-- Clamped so the slider can never claim more than the plot holds,
			-- and so the callback that narrows the range lands on the same
			-- number the loop uses.
			local slots = math.min(value, limit)
			Eggs.PlaceSlots = slots
			if value ~= slots and placeSlotSlider.SetMax then
				placeSlotSlider.SetMax(slots, true)
			end
			publishEggs()
		end,
	})

	InfoRow(place, "Place by rarity", "Tick the rarities worth a slot; rarer wins", Theme.Color.TextMid)
	-- Compact two-column checkbox grid, so a long rarity list does not turn
	-- into a wall of full-width rows.
	local placeRarityGrid = New("Frame", {
		Name = "PlaceRarities",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(place),
		Parent = place,
	})
	New("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.new(0.5, -4, 0, 30),
		CellPadding = UDim2.new(0, 8, 0, 2),
		Parent = placeRarityGrid,
	})
	-- Best first, so the top of the list is the prize eggs.
	for index = #RARITY_LIST, 1, -1 do
		local rarity = RARITY_LIST[index]
		Checkbox(placeRarityGrid, {
			Text = rarity,
			TextColor = rarityColor(rarity),
			Color = rarityColor(rarity),
			Key = "Place " .. rarity,
			Default = false,
			Callback = function(enabled)
				if enabled then
					Eggs.PlaceRarities[rarity] = true
				else
					Eggs.PlaceRarities[rarity] = nil
				end
			end,
		})
	end

	local placeGrid = ButtonGrid(place, 2)
	Button(placeGrid, {
		Text = "Stop placing",
		Icon = "close",
		Style = "Danger",
		Callback = function()
			stopAutoPlace()
			notify("Auto place stopped", "Warning", "No more eggs will be moved onto your plot.")
		end,
	})
	Button(placeGrid, {
		Text = "Recheck plot",
		Icon = "reset",
		Callback = function()
			Eggs.PlaceHolder = nil
			Eggs.PlaceDiscovered = false
			local holder = findPlaceHolder()
			local limit = placeLimit()
			Eggs.PlaceLimit = limit
			if placeSlotSlider.SetMax then
				placeSlotSlider.SetMax(limit, true)
			end
			Eggs.PlaceSlots = math.min(Eggs.PlaceSlots, limit)
			placeSlotSlider.Set(math.max(Eggs.PlaceSlots, 1), true)
			if holder then
				notify("Plot found", "Success", holder:GetFullName() .. " holds up to " .. limit .. " egg(s).")
			else
				notify("No egg folder", "Warning", "Your plot did not expose an egg folder to place into.")
			end
			publishEggs()
		end,
	})

	local upgradeSection = Section(autoColumn, "Luck upgrades")
	Upg.Row = InfoRow(upgradeSection, "Auto Max Upgrade", "Idle", Theme.Color.TextMid)
	Upg.Toggle = Toggle(upgradeSection, {
		Text = "Auto Max Upgrade",
		Description = "Keeps buying every affordable luck upgrade on your plot",
		Default = DEFAULTS.AutoMaxUpgrade,
		Callback = function(enabled)
			State.AutoMaxUpgrade = enabled
			if enabled then
				if not startAutoUpgrade() then
					Upg.Toggle.Set(false, true)
					State.AutoMaxUpgrade = false
				end
			else
				stopAutoUpgrade()
			end
		end,
	})
	Button(upgradeSection, {
		Text = "Buy max now",
		Icon = "sparkle",
		Callback = function()
			task.spawn(function()
				local ok, result = pcall(upgradeStep)
				if not ok then
					notify("Upgrade failed", "Error", tostring(result))
				elseif Upg.Token == 0 or Upg.State == "Idle" then
					setUpgStatus("Idle")
				end
			end)
		end,
	})

	-- SERVER HOP + AUTO SERVER HOP -------------------------------------------
	-- One controller (Features.Hop) behind the button, the timer, the Home
	-- quick action and the overlay's countdown.
	--
	-- What was wrong with the old button: it called
	-- TeleportService:Teleport(PlaceId, jobId), whose second argument is a
	-- PLAYER, not a server id, so the chosen server was never used. The right
	-- call for "this experience, that server" is TeleportToPlaceInstance
	-- (PlaceId, jobId, player). It also treated a refused hop as "nothing came
	-- back for 6 seconds", never listening for TeleportInitFailed, which is how
	-- Roblox actually reports a failure.
	--
	-- A hop leaves the current server, so the farm, the placer, the held
	-- interact key and noclip are released first: they would otherwise be
	-- aiming at a world that is about to stop existing. The settings are saved
	-- BEFORE that (Config.SaveResume), so the next server can put them back, and
	-- if the hop ends up failing they are put back here.
	do
		local Hop = Features.Hop
		local TeleportService = game:GetService("TeleportService")
		local HttpService = game:GetService("HttpService")
		local TIMEOUT = 25 -- seconds without a teleport or a failure report
		local RETRY_MIN, RETRY_MAX = 15, 120 -- automatic retry back-off, seconds
		local MAX_TRIES = 3 -- servers tried for one hop request
		-- Results worth another server (full / gone), as opposed to a refusal
		-- that the next server would meet too (rate limit, no permission).
		local RETRYABLE = {}
		for _, name in ipairs({ "GameFull", "GameEnded", "GameNotFound", "Failure" }) do
			local ok, value = pcall(function()
				return Enum.TeleportResult[name]
			end)
			if ok and value then
				RETRYABLE[value] = true
			end
		end

		Hop.Busy = false
		Hop.Token = 0
		Hop.Failed = {} -- server ids that refused us this session
		Hop.Retry = RETRY_MIN
		Hop.Queued = false
		Hop.Snapshot = nil
		local loopToken = 0
		local nextRow, resumeRow

		local function clock(seconds)
			seconds = math.max(0, math.floor(seconds + 0.5))
			return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
		end

		local function paintHop()
			if nextRow then
				if Hop.Busy then
					nextRow.Text = "Hopping..."
					nextRow.TextColor3 = Theme.Color.Caution
				elseif State.AutoHop and Hop.NextAt then
					nextRow.Text = clock(Hop.NextAt - os.clock())
					nextRow.TextColor3 = Theme.Color.TextHi
				else
					nextRow.Text = "Auto hop is off"
					nextRow.TextColor3 = Theme.Color.TextLow
				end
			end
		end

		-- GET with whatever HTTP the environment offers. Returns body, or nil
		-- and why, plus whether HTTP simply is not available here.
		local function httpGet(url)
			local requester = (type(syn) == "table" and syn.request)
				or (type(http) == "table" and http.request)
				or http_request
				or request
			if type(requester) == "function" then
				local ok, response = pcall(requester, { Url = url, Method = "GET" })
				if not ok or type(response) ~= "table" then
					return nil, "the server list request failed"
				end
				if response.StatusCode == 429 then
					return nil, "Roblox is rate limiting the server list (HTTP 429)"
				end
				if response.StatusCode and response.StatusCode ~= 200 then
					return nil, "the server list returned HTTP " .. tostring(response.StatusCode)
				end
				return response.Body
			end
			local ok, body = pcall(function()
				return game:HttpGet(url)
			end)
			if ok and type(body) == "string" then
				return body
			end
			return nil, "HTTP requests are not available here", true
		end

		-- Another server of this experience with room, never this one and never
		-- one that already refused us. The list is ordered fewest players first;
		-- one of the first few is picked at random so several people hopping at
		-- once do not all land on the same server.
		local function pickServer()
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
				game.PlaceId
			)
			local body, why, unavailable = httpGet(url)
			if not body then
				return nil, why, unavailable
			end
			local decoded, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
				return nil, "the server list was not in the expected format"
			end
			local pool = {}
			for _, entry in ipairs(data.data) do
				if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= game.JobId
					and not Hop.Failed[entry.id] and type(entry.playing) == "number"
					and type(entry.maxPlayers) == "number" and entry.playing < entry.maxPlayers then
					table.insert(pool, entry)
				end
			end
			if #pool == 0 then
				return nil, "no other server with room was found"
			end
			return pool[math.random(1, math.min(#pool, 5))].id
		end

		-- Re-runs this script in the new server (executors only). Queued once:
		-- a failed hop leaves the queued code waiting for the next real one.
		local function queueReload()
			if Hop.Queued then
				return
			end
			local queue = queue_on_teleport
				or (type(syn) == "table" and syn.queue_on_teleport)
				or (type(fluxus) == "table" and fluxus.queue_on_teleport)
			if type(queue) ~= "function" then
				return
			end
			local code
			if CONFIG.ReloadUrl ~= "" then
				code = string.format("loadstring(game:HttpGet(%q))()", CONFIG.ReloadUrl)
			elseif CONFIG.ReloadFile ~= "" then
				code = string.format("loadstring(readfile(%q))()", CONFIG.ReloadFile)
			end
			if code and pcall(queue, code) then
				Hop.Queued = true
			end
		end

		-- Whatever the hop stopped, switched back on from the snapshot taken
		-- before it stopped them.
		local function resumeAutomation()
			local saved = Hop.Snapshot
			Hop.Snapshot = nil
			local controls = saved and saved.controls
			if type(controls) ~= "table" then
				return
			end
			local function on(key)
				return controls[key] == true
			end
			Config.Loading = true -- quiet: one summary toast instead of one per module
			pcall(function()
				if on("Auto farm") then
					Features.Set("farm", true)
				end
				if on("Auto place") then
					Features.Set("place", true)
				end
				local upgrade = Config.Controls["Auto Max Upgrade"]
				if upgrade and on("Auto Max Upgrade") then
					upgrade.Set(true)
				end
			end)
			Config.Loading = false
		end

		-- Ends a hop that did not leave. `retryable` + a free try = another
		-- server straight away; otherwise it is over: the user hears why, the
		-- automation the hop stopped comes back, and Auto Server Hop (if on)
		-- is rescheduled with a growing delay instead of being disabled.
		local tryServer
		function Hop.Fail(message, jobId, retryable)
			if not Hop.Busy then
				return
			end
			if jobId then
				Hop.Failed[jobId] = true
			end
			if retryable and (Hop.Attempt or 1) < MAX_TRIES then
				notify("Trying another server", "Warning", message, true)
				tryServer((Hop.Attempt or 1) + 1)
				return
			end
			Hop.Busy = false
			Hop.Token = Hop.Token + 1
			notify("Server hop failed", "Error", message, true)
			logActivity("Server hop failed", message, "Error")
			-- Nothing left, so nothing is waiting to be resumed elsewhere.
			if Config.ClearResume then
				Config.ClearResume()
			end
			resumeAutomation()
			if State.AutoHop then
				Hop.NextAt = os.clock() + Hop.Retry
				Hop.Retry = math.min(Hop.Retry * 2, RETRY_MAX)
			end
			Features.Changed("hop")
			paintHop()
		end

		-- One attempt: choose a server, ask Roblox to go there, then wait for
		-- either the place to change (this script is destroyed) or a failure.
		tryServer = function(attempt)
			Hop.Token = Hop.Token + 1
			local mine = Hop.Token
			Hop.Attempt = attempt
			task.spawn(function()
				local jobId, why, unavailable = pickServer()
				if Hop.Token ~= mine or not Hop.Busy or not screen.Parent then
					return
				end
				if not jobId and not unavailable then
					Hop.Fail(tostring(why):gsub("^%l", string.upper) .. ".")
					return
				end
				Hop.Target = jobId
				if not jobId then
					-- No way to read the server list here. Roblox may still send
					-- us somewhere else, but it is not guaranteed to be a
					-- different server, so say so.
					notify("Server list unavailable", "Warning",
						"Asking Roblox for any server; it may be this one.", true)
				end
				queueReload()
				local ok, err = pcall(function()
					if jobId then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
					else
						TeleportService:Teleport(game.PlaceId, player)
					end
				end)
				if not ok then
					Hop.Fail("The teleport request was rejected: " .. tostring(err), jobId, true)
					return
				end
				-- A successful hop destroys this script, so reaching the end of
				-- this timer means nothing happened.
				task.delay(TIMEOUT, function()
					if Hop.Busy and Hop.Token == mine and screen.Parent then
						Hop.Fail("Roblox did not start the teleport within " .. TIMEOUT .. " seconds.", jobId, true)
					end
				end)
			end)
		end

		function Hop.Start(reason)
			if Hop.Busy then
				notify("Already hopping", "Warning", "A server hop is already in progress.", true)
				return false
			end
			if not Gate.Authenticated or not screen.Parent then
				return false
			end
			Hop.Busy = true
			Hop.Reason = reason
			Hop.NextAt = nil
			notify(reason == "auto" and "Auto server hop" or "Finding a server", "Info",
				"Looking for another server to join.", true)
			-- Settings first, while the automation is still running, so what is
			-- saved is what was on.
			Hop.Snapshot = Config.Collect()
			if Config.SaveResume then
				Config.SaveResume(Hop.Snapshot)
			end
			stopAutoFarm()
			stopAutoPlace()
			stopAutoUpgrade()
			stopMovement()
			releaseInteract()
			Features.Changed("hop")
			paintHop()
			tryServer(1)
			return true
		end

		-- Roblox reports a refused teleport here, not from the call itself.
		track(TeleportService.TeleportInitFailed:Connect(function(failedPlayer, result, message)
			if failedPlayer ~= player or not Hop.Busy then
				return
			end
			local text = (type(message) == "string" and message ~= "") and message or tostring(result)
			Hop.Fail("Roblox refused the teleport: " .. text, Hop.Target, RETRYABLE[result] == true)
		end))

		-- THE TIMER ---------------------------------------------------------
		-- One loop, one second per tick, only alive while Auto Server Hop is
		-- on. It can start a hop at most once per due time: Start sets Busy and
		-- clears NextAt, and a failure pushes NextAt out by a growing delay, so
		-- nothing here can fire a teleport every frame.
		local function startLoop()
			loopToken = loopToken + 1
			local mine = loopToken
			task.spawn(function()
				while State.AutoHop and loopToken == mine and screen.Parent do
					task.wait(1)
					if State.AutoHop and loopToken == mine and Gate.Authenticated and not Hop.Busy then
						if not Hop.NextAt then
							Hop.NextAt = os.clock() + State.HopMinutes * 60
						elseif os.clock() >= Hop.NextAt then
							Hop.Start("auto")
						end
					end
					paintHop()
				end
			end)
		end

		local hopFeature = Features.ByKey.hop
		hopFeature.Get = function()
			return State.AutoHop == true
		end
		hopFeature.Set = function(enabled)
			enabled = enabled == true
			if State.AutoHop == enabled then
				return
			end
			State.AutoHop = enabled
			Hop.Retry = RETRY_MIN
			if enabled then
				Hop.NextAt = os.clock() + State.HopMinutes * 60 -- the timer starts now
				startLoop()
				notify("Auto server hop on", "Success",
					string.format("Next hop in %d min.", State.HopMinutes))
			else
				loopToken = loopToken + 1
				Hop.NextAt = nil
				notify("Auto server hop off", "Info", "Staying in this server.")
			end
			paintHop()
		end

		-- UI ----------------------------------------------------------------
		local server = Section(autoColumn, "Server hop")
		InfoRow(server, "What it does", "Rejoins this game on a different server", Theme.Color.TextMid)
		Button(server, {
			Text = "Server Hop Now",
			Icon = "server",
			Style = "Danger",
			Callback = function()
				Hop.Start("manual")
			end,
		})
		Toggle(server, {
			Text = "Auto server hop",
			Description = "Hop to a new server on a timer, then pick up where you left off",
			Default = DEFAULTS.AutoHop,
			Shared = "hop",
		})
		local interval = Slider(server, {
			Text = "Hop interval",
			Min = 1, Max = 60, Default = DEFAULTS.HopMinutes, Step = 1, Suffix = " min",
			Callback = function(value)
				State.HopMinutes = value
				-- A new interval restarts the countdown from now.
				if State.AutoHop and not Hop.Busy then
					Hop.NextAt = os.clock() + value * 60
					paintHop()
				end
			end,
		})
		local presets = ButtonGrid(server, 3)
		for _, minutes in ipairs({ 1, 2, 5, 10, 15, 30 }) do
			Button(presets, {
				Text = minutes .. " min",
				Style = "Secondary",
				Callback = function()
					interval.Set(minutes)
				end,
			})
		end
		nextRow = InfoRow(server, "Next server hop", "Auto hop is off", Theme.Color.TextLow)

		-- Whether the new server can start this script again by itself.
		local canQueue = queue_on_teleport ~= nil
			or (type(syn) == "table" and syn.queue_on_teleport ~= nil)
			or (type(fluxus) == "table" and fluxus.queue_on_teleport ~= nil)
		local resumeText, resumeColor
		if not (type(writefile) == "function" and type(readfile) == "function") then
			resumeText, resumeColor = "Needs file access to carry settings over", Theme.Color.Caution
		elseif CONFIG.ReloadUrl ~= "" or CONFIG.ReloadFile ~= "" then
			if canQueue then
				resumeText, resumeColor = "Script re-runs itself after a hop", Theme.Color.Positive
			else
				resumeText, resumeColor = "Executor cannot queue the script", Theme.Color.Caution
			end
		else
			resumeText, resumeColor = "Set CONFIG.ReloadUrl / ReloadFile, or auto-execute", Theme.Color.Caution
		end
		resumeRow = InfoRow(server, "Resume after hop", resumeText, resumeColor)
		paintHop()
		Features.Changed("hop")

		stopServerHop = function()
			loopToken = loopToken + 1
			Hop.Token = Hop.Token + 1
			Hop.Busy = false
		end
	end

	-- UTILITIES -------------------------------------------------------------
	-- Kept last on the page: these are the run-and-leave things, not the ones
	-- you reach for while collecting.
	local util = Section(autoColumn, "Utilities")
	local afkConnection = nil
	Toggle(util, {
		Text = "Anti-AFK",
		Description = "Stops the idle kick while this panel is running",
		Default = false,
		Callback = function(enabled)
			if afkConnection then
				afkConnection:Disconnect()
				afkConnection = nil
			end
			if enabled then
				afkConnection = player.Idled:Connect(function()
					pcall(function()
						local virtualUser = game:GetService("VirtualUser")
						virtualUser:CaptureController()
						virtualUser:ClickButton2(Vector2.new())
					end)
				end)
			end
		end,
	})
	track({
		Disconnect = function()
			if afkConnection then
				afkConnection:Disconnect()
				afkConnection = nil
			end
		end,
	})
	local utilGrid = ButtonGrid(util, 2)
	Button(utilGrid, {
		Text = "Rejoin server",
		Icon = "refresh",
		Callback = function()
			notify("Rejoining", "Info", "Reconnecting to this server.")
			pcall(function()
				game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
			end)
		end,
	})
	Button(utilGrid, {
		Text = "Copy Job ID",
		Icon = "copy",
		Callback = function()
			if type(setclipboard) == "function" and pcall(setclipboard, game.JobId) then
				notify("Copied", "Success", "This server's Job ID is on your clipboard.")
			else
				notify("Clipboard unavailable", "Warning", "Job ID: " .. game.JobId)
			end
		end,
	})

	-- ESP toggles are added last so they read as the finishing controls.
	local esp = Section(column, "Overlay")
	Toggle(esp, {
		Text = "Egg ESP",
		Description = "Name and distance above every egg, at any range",
		Default = DEFAULTS.EggsESP,
		Callback = function(enabled)
			State.EggsESP = enabled
			Eggs.GlobalESP = enabled
			refreshESPState()
		end,
	})
	Toggle(esp, {
		Text = "Highlight outline",
		Description = "Glow around each egg, coloured by rarity",
		Default = DEFAULTS.EggsHighlight,
		Callback = function(enabled)
			State.EggsHighlight = enabled
			Eggs.ShowHighlight = enabled
			for model, data in pairs(Eggs.ESPs) do
				if enabled and not data.Highlight then
					local ok, highlight = pcall(buildHighlight, model, data.Color, false)
					if ok then
						data.Highlight = highlight
						if data.Visible then
							highlight.Enabled = true
							TweenService:Create(highlight, FADE, {
								FillTransparency = HL_FILL,
								OutlineTransparency = HL_OUTLINE,
							}):Play()
						end
					end
				elseif not enabled and data.Highlight then
					data.Highlight:Destroy()
					data.Highlight = nil
				end
			end
		end,
	})

	-- Farm status text, assigned once the page exists. This is the single
	-- place the farm's visible state is written, so the toggle, the status
	-- row, the Home card and State cannot drift apart. Repainting is skipped
	-- while the interface is being torn down, because the controls are on
	-- their way out.
	--
	-- `phase` is what the Home card keys its styling off: off / waiting /
	-- listening / farming. `target`, `rarity` and `distance` are the details
	-- the card shows, so nothing has to re-measure an egg to fill them in.
	setFarmStatus = function(text, phase, detail, target, rarity, distance, step)
		Eggs.FarmState = text
		local card = Eggs.Card
		-- What the overlay calls the state: Searching / Moving / Picking Up /
		-- Returning / Waiting. The phase gives a default; the farm refines it.
		card.Step = step
			or (phase == "farming" and "Moving")
			or ((phase == "listening" or phase == "waiting") and "Waiting")
			or nil
		card.Active = Eggs.FarmActive
		card.Phase = phase or (Eggs.FarmActive and "listening" or "off")
		card.Message = detail or text
		card.Target = target
		card.Rarity = rarity
		card.Distance = distance
		if publishEggs then
			publishEggs()
		end
		if not Eggs.Running or not farmInfo then
			return
		end
		if farmInfo.Text ~= text then
			farmInfo.Text = text
		end
		if text:find("Farming") then
			farmInfo.TextColor3 = Theme.Color.Positive
		elseif text:find("Waiting") or text:find("Pick") then
			farmInfo.TextColor3 = Theme.Color.Caution
		else
			farmInfo.TextColor3 = Theme.Color.TextMid
		end
	end

	paintFarm = function(active)
		active = active == true
		State.EggsAutoFarm = active
		if not Eggs.Running then
			return
		end
		if active then
			setFarmStatus("ON / Waiting for Eggs", "listening", "Listening for a matching egg", nil, nil, nil, "Searching")
		else
			setFarmStatus("Idle", "off", "Auto farm is off")
		end
		if autoFarmToggle and autoFarmToggle.Get() ~= active then
			-- Silent, so the Toggle does not call back into the farm.
			autoFarmToggle.Set(active, true)
		end
		Features.Changed("farm")
	end
	-- The placer's mirror of setFarmStatus: one writer for its visible state.
	setPlaceStatus = function(text, phase, detail, target, rarity, distance)
		if not Eggs.Running or not placeRows.Status then
			return
		end
		if placeRows.Status.Text ~= text then
			placeRows.Status.Text = text
		end
		if text:find("Placing") then
			placeRows.Status.TextColor3 = Theme.Color.Positive
		elseif text:find("Waiting") or text:find("Pick") then
			placeRows.Status.TextColor3 = Theme.Color.Caution
		else
			placeRows.Status.TextColor3 = Theme.Color.TextMid
		end

		-- The two rows that are not just a status string: what the plot allows
		-- and how full it is right now. Both are cheap enough to keep live.
		local holder = Eggs.PlaceHolder
		if placeRows.Folder then
			if Eggs.PlaceHolder and Eggs.PlaceHolder.Parent then
				placeRows.Folder.Text = holder.Name
				placeRows.Folder.TextColor3 = Theme.Color.Positive
			elseif Eggs.PlaceActive then
				placeRows.Folder.Text = "Not found yet"
				placeRows.Folder.TextColor3 = Theme.Color.Caution
			else
				placeRows.Folder.Text = "Not checked"
				placeRows.Folder.TextColor3 = Theme.Color.TextLow
			end
		end
		if placeRows.Limit then
			local _, total, unlocked = nestSlots()
			if Eggs.PlaceDiscovered then
				if total > 0 then
					placeRows.Limit.Text = string.format("%d of %d unlocked", unlocked, total)
				else
					placeRows.Limit.Text = tostring(Eggs.PlaceLimit) .. (Eggs.PlaceLimit == 1 and " nest" or " nests")
				end
				placeRows.Limit.TextColor3 = Theme.Color.TextHi
			else
				placeRows.Limit.Text = "Not checked"
				placeRows.Limit.TextColor3 = Theme.Color.TextLow
			end
		end
		if placeRows.Slots and holder and holder.Parent then
			local filled = #holder:GetChildren()
			placeRows.Slots.Text = string.format("%d of %d used", filled, Eggs.PlaceSlots)
			placeRows.Slots.TextColor3 = filled >= Eggs.PlaceSlots and Theme.Color.Positive or Theme.Color.TextHi
		end
		publishEggs()
	end

	paintPlace = function(active)
		active = active == true
		State.EggsAutoPlace = active
		if not Eggs.Running then
			return
		end
		if active then
			setPlaceStatus("On / Looking for a matching egg", "listening", "Listening for a rarity you selected")
		else
			setPlaceStatus("Off", "off", "Auto place is off")
		end
		if autoPlaceToggle and autoPlaceToggle.Get() ~= active then
			-- Silent, so the Toggle does not call back into the placer.
			autoPlaceToggle.Set(active, true)
		end
		Features.Changed("place")
	end

	-- WATCHERS ------------------------------------------------------------

	-- New eggs can appear at any time, so the folder is watched as soon as
	-- it exists rather than only being scanned once.
	local watched = nil

	track(UserInputService.InputBegan:Connect(function(input, processed)
		-- The panel is the only way in, but the shortcut listens globally, so
		-- it has to be refused before the password is accepted.
		if not Gate.Authenticated then
			Eggs.Listening = false
			return
		end
		if Eggs.Listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				Eggs.Listening = false
				Eggs.HomeKey = input.KeyCode
				if homeKeyInfo then
					homeKeyInfo.Text = string.upper(Eggs.HomeKey.Name)
				end
			end
			return
		end
		if processed or isOpen or searchBox:IsFocused() then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Eggs.HomeKey then
			teleportHome(false)
		end
	end))

	-- Tracked in Eggs.WatchConns and disconnected before a replacement folder
	-- is watched, so a re-created RenderedEggs never leaves two listeners.
	ensureWatched = function()
		if watched and watched.Parent then
			return
		end
		local folder = Eggs.Folder
		if not folder or not folder.Parent then
			folder = workspace:FindFirstChild("RenderedEggs")
		end
		if not folder then
			return
		end
		for _, connection in ipairs(Eggs.WatchConns) do
			connection:Disconnect()
		end
		table.clear(Eggs.WatchConns)
		Eggs.Folder = folder
		watched = folder
		table.insert(Eggs.WatchConns, folder.DescendantAdded:Connect(function(object)
			if not object:IsA("Model") then
				return
			end
			-- Joined the registry the moment it appears, before any of the
			-- waiting below. The farm and the placer can start moving towards
			-- it while the list is still waiting for its parts to stream in.
			liveAdd(object)
			task.defer(function()
				-- An egg model is built over a few frames, so registration
				-- waits briefly for it to gain a usable part.
				local deadline = os.clock() + 2
				repeat
					if not Gate.Authenticated or not object.Parent or not object:IsDescendantOf(folder) then
						return
					end
					if getRootPart(object) then
						break
					end
					task.wait(0.05)
				until os.clock() >= deadline
				if not object.Parent or Eggs.Entries[object] then
					return
				end
				registerEgg(object)
				applyFilter()
				applySort()
				recountLive()
				publishEggs()
			end)
		end))
		-- Eggs that leave take their row and overlay immediately, instead of
		-- waiting for the next sweep.
		table.insert(Eggs.WatchConns, folder.DescendantRemoving:Connect(function(object)
			-- Dropped right away so anything parked on the registry re-targets
			-- this frame rather than after its timeout.
			liveDrop(object)
			if not Eggs.Entries[object] and not Eggs.ESPs[object] then
				return
			end
			task.defer(function()
				if (Eggs.Entries[object] or Eggs.ESPs[object]) and not object:IsDescendantOf(folder) then
					removeEgg(object)
					applyFilter()
					applySort()
				end
			end)
		end))
		-- A folder that is destroyed and rebuilt (a plot reload, a teleport) is
		-- picked up on the spot instead of at the next sweep.
		table.insert(Eggs.WatchConns, workspace.ChildAdded:Connect(function(child)
			if child.Name == "RenderedEggs" and child ~= watched then
				task.defer(function()
					if watched and watched.Parent then
						return
					end
					ensureWatched()
					for _, egg in ipairs(child:GetDescendants()) do
						if egg:IsA("Model") then
							liveAdd(egg)
						end
					end
					recountLive()
					publishEggs()
				end)
			end
		end))
	end
	local warnedUnavailable = false

	-- One pass of the scanner: updates distances, prunes removed eggs and
	-- keeps the overlay in sync. Split out of the loop so a whole pass can be
	-- skipped before the password is accepted.
	local function tick()
		ensureWatched()

		local folder = Eggs.Folder
		local plots = plotsFolder()
		if not (folder and folder.Parent) then
			folderRow.Text = "Not found"
			folderRow.TextColor3 = Theme.Color.Caution
		else
			folderRow.Text = "Ready"
			folderRow.TextColor3 = Theme.Color.Positive
		end
		if not (plots and plots.Parent) then
			plotsRow.Text = "Not found"
			plotsRow.TextColor3 = Theme.Color.Caution
		else
			plotsRow.Text = "Ready"
			plotsRow.TextColor3 = Theme.Color.Positive
		end
		-- Reported once. A folder that has not streamed in yet is a loading
		-- state, not something to keep shouting about on every tick.
		if not warnedUnavailable and (not (folder and folder.Parent) or not (plots and plots.Parent)) then
			warnedUnavailable = true
			warn("[Eggs] workspace.RenderedEggs or workspace.Plots is missing; scanner features are limited.")
		end

		local total = 0
		if folder and folder.Parent then
			for _, egg in ipairs(folder:GetDescendants()) do
				if egg:IsA("Model") then
					-- Catches anything the events missed. Cheap, because the
					-- registry check is a single table lookup and the walk was
					-- happening for the list anyway.
					liveAdd(egg)
					if not Eggs.Entries[egg] then
						registerEgg(egg)
					end
					if Eggs.Entries[egg] then
						total = total + 1
						if not Eggs.ESPs[egg] then
							createESP(egg)
						end
					end
				end
			end
		end
		Eggs.Total = total
		recountLive()

		-- Anything that left the folder takes its row and overlay with it.
		local stale = nil
		for model in pairs(Eggs.Entries) do
			if not model.Parent or not folder or not model:IsDescendantOf(folder) then
				stale = stale or {}
				table.insert(stale, model)
			end
		end
		if stale then
			for _, model in ipairs(stale) do
				removeEgg(model)
			end
			applyFilter()
			applySort()
		end

		-- The registry is normally pruned by the removal event, so this only
		-- ever catches the rare egg that disappeared without firing one.
		-- Walked separately because the registry also holds models that never
		-- made it into the list (no parts yet, or a late register).
		local orphaned = nil
		for model in pairs(Eggs.Live) do
			if not model.Parent then
				orphaned = orphaned or {}
				table.insert(orphaned, model)
			end
		end
		if orphaned then
			for _, model in ipairs(orphaned) do
				liveDrop(model)
			end
		end

		-- Recomputed from scratch, otherwise each group's distance could only
		-- ever fall and the ordering would go stale as the player moved.
		for _, group in pairs(Eggs.Groups) do
			group.Distance = nil
		end

		local root = characterRoot()
		for model, entry in pairs(Eggs.Entries) do
			local distance = nil
			if root then
				local part = getRootPart(model)
				if part then
					distance = (root.Position - part.Position).Magnitude
				end
			end
			entry.Distance = distance
			local group = Eggs.Groups[model.Name]
			if group and distance and (group.Distance == nil or distance < group.Distance) then
				group.Distance = distance
			end
			if distance then
				entry.Label.Text = string.format("%s   %d studs", model.Name, math.floor(distance + 0.5))
			else
				entry.Label.Text = model.Name
			end
		end

		if Eggs.SortBy == "Nearest" then
			applySort()
		end

		Eggs.Diag.LastScan = os.clock()

		-- Pushed after the sweep so the Home page's "Eggs detected" figure
		-- reflects the pass that just finished.
		publishEggs()
	end

	-- Runs until the interface is destroyed. Each pass is protected, so one
	-- bad egg can no longer end the loop and freeze every distance for good,
	-- and the ESP driver is restarted if its connection ever goes quiet.
	local loopErrors = 0
	task.spawn(function()
		while Eggs.Running and screen.Parent do
			-- Nothing is scanned, watched or shortcut-bound until the
			-- password has been accepted.
			if Gate.Authenticated then
				local ok, err = pcall(tick)
				if not ok then
					loopErrors = loopErrors + 1
					if loopErrors <= 3 then
						warn("[Eggs] scan pass failed: " .. tostring(err))
					end
				end
				if not Driver.Conn or not Driver.Conn.Connected or os.clock() - Driver.Last > 3 then
					startESPDriver()
				end
			end
			task.wait(UPDATE_RATE)
		end
	end)
	-- Keeps the indicator's "ago" figure ticking between scan passes. Only
	-- runs its paint while someone can see it (this tab, or Debug Mode).
	task.spawn(function()
		while Eggs.Running and screen.Parent do
			local page = pages.Eggs
			local visible = page and page.Group and page.Group.Visible
			if Gate.Authenticated and (visible or State.DebugMode) then
				pcall(Eggs.Diag.Paint)
			end
			task.wait(0.2)
		end
	end)
	-- A respawn replaces the character, so distances and the plot's baseplate
	-- are both stale. Everything character-bound is reset here: the ESP driver
	-- is reconnected (one connection, never stacked), leftover movement is
	-- released, and the list is re-scanned once the new character is actually
	-- in the world rather than on the event itself.
	local respawnToken = 0
	track(player.CharacterAdded:Connect(function(character)
		respawnToken = respawnToken + 1
		local token = respawnToken
		Eggs.CachedPlot = nil
		Eggs.CachedBaseplate = nil
		stopMovement()
		releaseInteract()
		for _, esp in pairs(Eggs.ESPs) do
			esp.LastShown = nil
		end
		startESPDriver()
		task.spawn(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if token ~= respawnToken or not Eggs.Running or not screen.Parent or not rootPart then
				return
			end
			if Gate.Authenticated then
				fullRescan()
				startESPDriver()
			end
		end)
	end))
	track(player.CharacterRemoving:Connect(function()
		-- The old character is gone: drop anything tied to it.
		stopMovement()
		releaseInteract()
		for _, esp in pairs(Eggs.ESPs) do
			esp.LastShown = nil
		end
	end))

	-- Everything this page owns is released with the interface.
	track(screen.Destroying:Connect(function()
		Eggs.Running = false
		-- Releases anything parked on the registry, so no loop is left waiting
		-- on a version that will never change again.
		liveWake()
		stopAutoFarm(true)
		stopAutoPlace(true)
		stopAutoUpgrade()
		-- The hop's 6-second re-arm timer checks this, so it goes quiet here
		-- instead of notifying against a destroyed interface.
		if stopServerHop then
			stopServerHop()
		end
		stopMovement()
		releaseInteract()
		stopESPDriver()
		for _, connection in ipairs(Eggs.WatchConns) do
			connection:Disconnect()
		end
		table.clear(Eggs.WatchConns)
		for model in pairs(Eggs.ESPs) do
			destroyESP(model)
		end
		table.clear(Eggs.ESPs)
		table.clear(Eggs.Live)
	end))

	-- Config hooks: what lives in this page and is not a plain toggle/slider.
	-- The auto place switch, the slot slider and the per-rarity checkboxes are
	-- ordinary registered controls, so they are saved and restored by the normal
	-- control pass. Only the page's own set data needs a hand-written hook.
	Config.Extra = {
		Collect = function()
			local farmTypes, espOff = {}, {}
			for name in pairs(Eggs.FarmTypes) do
				table.insert(farmTypes, name)
			end
			for name in pairs(Eggs.TypeESPOff) do
				table.insert(espOff, name)
			end
			table.sort(farmTypes)
			table.sort(espOff)
			return {
				sort = Eggs.SortBy,
				farmTypes = farmTypes,
				espOff = espOff,
				homeKey = Eggs.HomeKey.Name,
				overlay = QuickOverlay.Collect(),
				pinnedTabs = Stats.Nav.Collect(),
				fab = Stats.Fab and Stats.Fab.Collect() or nil,
			}
		end,
		Apply = function(extra)
			if type(extra.fab) == "table" and Stats.Fab then
				Stats.Fab.Apply(extra.fab)
			end
			if type(extra.pinnedTabs) == "table" then
				Stats.Nav.Set(extra.pinnedTabs)
			end
			if type(extra.overlay) == "table" then
				QuickOverlay.Apply(extra.overlay)
			end
			if type(extra.sort) == "string" and validSort(extra.sort) then
				selectSort(extra.sort)
			end
			if type(extra.farmTypes) == "table" then
				Eggs.FarmTypes = {}
				for _, name in ipairs(extra.farmTypes) do
					if type(name) == "string" then
						Eggs.FarmTypes[name] = true
					end
				end
				Eggs.Processed = {}
				for name, group in pairs(Eggs.Groups) do
					if group.FarmPill then
						group.FarmPill.Set(Eggs.FarmTypes[name] == true)
					end
				end
			end
			if type(extra.espOff) == "table" then
				Eggs.TypeESPOff = {}
				for _, name in ipairs(extra.espOff) do
					if type(name) == "string" then
						Eggs.TypeESPOff[name] = true
					end
				end
				for name, group in pairs(Eggs.Groups) do
					group.TypeESP = Eggs.TypeESPOff[name] ~= true
					if group.EspPill then
						group.EspPill.Set(group.TypeESP)
					end
				end
				refreshESPState()
			end
			if type(extra.homeKey) == "string" then
				local ok, key = pcall(function()
					return Enum.KeyCode[extra.homeKey]
				end)
				if ok and key then
					Eggs.HomeKey = key
					homeKeyInfo.Text = string.upper(key.Name)
				end
			end
		end,
	}
	-- The auto farm toggle registers itself in resettables, and its callback
	-- stops a running farm when it is reset to false, so nothing extra is
	-- needed here.

	-- Publishes every egg-derived figure to the Home page in one go. The Home
	-- page owns the widgets; this page owns the data. Both sides are looked up
	-- through Stats.Hub, which is created by whichever runs first, so the order
	-- the pages are built in does not matter.
	publishEggs = function()
		local hub = Stats.Hub
		if not hub then
			return
		end
		-- Read fresh rather than caching, so the Home figure cannot drift from
		-- what the placer is actually looking at.
		local holder = Eggs.PlaceHolder
		local filled = 0
		if holder and holder.Parent then
			filled = #holder:GetChildren()
		end
		Features.Publish(Eggs.Card, { Discovered = Eggs.PlaceDiscovered, Filled = filled, Slots = Eggs.PlaceSlots }, Eggs.Counters)
		if hub.OnEggs then
			pcall(hub.OnEggs, Eggs.Card, Eggs.Counters, {
				Limit = Eggs.PlaceLimit,
				Slots = Eggs.PlaceSlots,
				Filled = filled,
				Discovered = Eggs.PlaceDiscovered,
			})
		end
	end

	-- The farm's finer-grained state for the overlay. Only publishes when the
	-- step actually changes.
	Eggs.SetStep = function(step)
		local card = Eggs.Card
		if card.Step ~= step then
			card.Step = step
			publishEggs()
		end
	end

	-- The handle the Home page drives. Set on Stats.Hub so the quick actions
	-- there flip the same state the egg page owns, rather than keeping a second
	-- copy that could disagree.
	local hub = Stats.Hub or {}
	Stats.Hub = hub
	-- Rarity lookup, so the Home card colours its target and orders its
	-- breakdown with the same table the egg page uses.
	hub.RarityColor = rarityColor
	Stats.RarityColor = rarityColor -- Home reads it from Stats, not from the hub
	hub.RarityRank = function(rarity)
		return RARITY_RANK[rarity] or 0
	end
	hub.IsFarmActive = function()
		return Eggs.FarmActive
	end
	-- One snapshot of every part of the farm pipeline, for Debug Mode. Each
	-- check reads the real state, so a row can only say OK when it is.
	hub.Debug = function()
		local function check(kind, text)
			return { Kind = kind, Text = text }
		end
		local scannerOk, present, watching = Eggs.Diag.Health()
		local scanner
		if scannerOk then
			scanner = check("ok", "Connected")
		elseif not present then
			scanner = check("bad", "RenderedEggs not found")
		elseif not watching then
			scanner = check("bad", "No event connection")
		else
			scanner = check("bad", "Not running")
		end
		local farmState
		if Eggs.FarmActive and not Eggs.FarmThread then
			farmState = check("bad", "ON but its thread is gone")
		elseif Eggs.FarmActive then
			farmState = check("ok", "ON")
		else
			farmState = check("off", "OFF")
		end
		local placeState
		if Eggs.PlaceActive and not Eggs.PlaceThread then
			placeState = check("bad", "ON but its thread is gone")
		elseif Eggs.PlaceActive then
			placeState = check("ok", "ON")
		else
			placeState = check("off", "OFF")
		end
		local espState
		if not State.EggsESP then
			espState = check("off", "OFF")
		elseif Driver.Conn and Driver.Conn.Connected and os.clock() - Driver.Last <= 3 then
			espState = check("ok", "ON")
		else
			espState = check("bad", "ON but the driver is silent")
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = characterRoot()
		local characterState
		if not character then
			characterState = check("bad", "No character")
		elseif not root then
			characterState = check("bad", "No root part")
		elseif not humanoid or humanoid.Health <= 0 then
			characterState = check("bad", "Dead")
		else
			characterState = check("ok", "Ready")
		end
		local card = Eggs.Card
		return {
			Scanner = scanner,
			Farm = farmState,
			Place = placeState,
			ESP = espState,
			Character = characterState,
			Detected = Eggs.Counters.Detected or 0,
			Listed = Eggs.Total or 0,
			Candidates = Eggs.Diag.Candidates(),
			Target = Eggs.FarmActive and card.Target or nil,
			Step = Eggs.FarmActive and (card.Step or "Searching") or "Idle",
			LastDetection = Eggs.Diag.Age(Eggs.Diag.LastDetection),
			LastScan = Eggs.Diag.Age(Eggs.Diag.LastScan),
			Recoveries = Eggs.Diag.Recoveries or 0,
			LastRecoveryWhy = Eggs.Diag.LastRecoveryWhy,
		}
	end
	-- Live distance to the egg being collected, for the overlay.
	hub.FarmDistance = function()
		local egg = Eggs.FarmTarget
		if egg and egg.Parent and Eggs.FarmActive then
			return distanceTo(egg)
		end
		return nil
	end
	hub.SetFarm = function(enabled)
		if enabled == Eggs.FarmActive then
			return
		end
		if enabled then
			if not startAutoFarm() then
				paintFarm(false)
			end
		else
			stopAutoFarm()
		end
		publishEggs()
	end
	hub.IsPlaceActive = function()
		return Eggs.PlaceActive
	end
	hub.SetPlace = function(enabled)
		if enabled == Eggs.PlaceActive then
			return
		end
		if enabled then
			if not startAutoPlace() then
				paintPlace(false)
			end
		else
			stopAutoPlace()
		end
		publishEggs()
	end
	-- A full re-scan, for when the list looks out of date. Deliberately cheap:
	-- it re-runs the same pass the 0.2s loop already runs, and wakes anything
	-- parked so the farm and placer re-target at once.
	hub.Rescan = function()
		ensureWatched()
		recountLive()
		liveWake()
		publishEggs()
	end
	Stats.RarityRank = hub.RarityRank
	applyFilter()
	applySort()
	paintSort()
	-- One publish on build, so the Home page shows real numbers rather than
	-- zeroes until the first scan pass lands.
	publishEggs()
end
Config.BuildConfigs()
buildToolsPage()

--------------------------------------------------------------------------
-- FLOATING BUTTON
--------------------------------------------------------------------------

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- With the logo loaded the button is the Lumen mark itself on a rounded card
-- (the logo already carries the LUMEN wordmark). Without it, the original
-- accent-gradient circle with the grid glyph is kept.
local fabLogo = CONFIG.ResolvedLogo ~= nil
local fab = New("TextButton", {
	Name = "Fab",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = fabLogo and Theme.Color.Surface or Theme.Color.White,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	-- Bottom-right on desktop; mid-right on touch so it clears the jump button.
	AnchorPoint = touchOnly and Vector2.new(1, 0.5) or Vector2.new(1, 1),
	Position = touchOnly and UDim2.new(1, -20, 0.5, 0) or UDim2.new(1, -24, 1, -24),
	Size = fabLogo and UDim2.fromOffset(64, 64) or UDim2.fromOffset(52, 52),
	Visible = false, -- shown only after loading + password (see the access gate)
	ZIndex = 5,
	Parent = screen,
})
if fabLogo then
	Round(fab, Theme.Radius.LG)
	local fabStroke = Stroke(fab, 0.45, Accent.Color, 1.5)
	bindAccent(function()
		fabStroke.Color = Accent.Color
	end)
	-- Soft accent halo: a faint, larger rounded plate under the logo.
	local halo = New("Frame", {
		Name = "Halo",
		BackgroundColor3 = Accent.Color,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = fab.ZIndex + 1,
		Parent = fab,
	})
	Round(halo, Theme.Radius.MD)
	bindAccent(function()
		halo.BackgroundColor3 = Accent.Color
	end)
	Brandmark(fab, 54, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = fab.ZIndex + 2,
	})
else
	Round(fab, Theme.Radius.Pill)
	AccentGradient(fab, 45)
	Stroke(fab, 0.7)
	Icon(fab, "grid", 22, Theme.Color.White, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
end
local fabScale = New("UIScale", { Parent = fab })
-- One UIScale only (several under one parent do not multiply), shared by the
-- hover/press feedback here and the show/hide animation in showFab().
attachFeedback(fab, {
	Rest = 0.05,
	Hover = 0,
	Press = 0.2,
	OnState = function(hovered, pressed)
		if not isOpen then
			local s = 1
			if pressed then
				s = 0.94
			elseif hovered then
				s = 1.08
			end
			play(fabScale, Motion.Swift, "Out", { Scale = s })
		end
	end,
})
-- The button can be dragged anywhere on screen and remembers where it was left
-- (saved with configs). A press that moves more than a few pixels is a drag and
-- never opens the panel; a still press is the normal click. The position is
-- kept as a fraction of the screen, so it stays on screen if the window resizes.
Stats.Fab = { Moved = false }
do
	local DRAG_PIXELS = 6
	local pressed, startMouse, startAnchor, dragMoved = false, nil, nil, false

	local function place(fx, fy)
		fx = math.clamp(fx, 0, 1)
		fy = math.clamp(fy, 0, 1)
		Stats.Fab.X, Stats.Fab.Y = fx, fy
		fab.Position = UDim2.fromScale(fx, fy)
	end

	-- Keeps the whole button visible whatever the anchor is.
	local function clampPixels(x, y)
		local size = fab.Size
		local w, h = size.X.Offset, size.Y.Offset
		local view = screen.AbsoluteSize
		local ax, ay = fab.AnchorPoint.X, fab.AnchorPoint.Y
		local pad = 6
		return math.clamp(x, w * ax + pad, view.X - w * (1 - ax) - pad),
			math.clamp(y, h * ay + pad, view.Y - h * (1 - ay) - pad)
	end

	fab.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			pressed, dragMoved = true, false
			startMouse = Vector2.new(input.Position.X, input.Position.Y)
			-- The anchor point's screen position does not change with the
			-- hover scale, so it is the stable thing to measure from.
			startAnchor = fab.AbsolutePosition + fab.AnchorPoint * fab.AbsoluteSize
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if not pressed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - startMouse
		if not dragMoved and delta.Magnitude >= DRAG_PIXELS then
			dragMoved = true
			Stats.Fab.Moved = true
		end
		if dragMoved then
			local view = screen.AbsoluteSize
			local x, y = clampPixels(startAnchor.X + delta.X, startAnchor.Y + delta.Y)
			place(x / view.X, y / view.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if pressed and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			pressed = false
			-- Activated fires on this same release; the flag is cleared after it.
			task.delay(0.12, function()
				Stats.Fab.Moved = false
			end)
		end
	end))

	function Stats.Fab.Collect()
		if Stats.Fab.X then
			return { x = Stats.Fab.X, y = Stats.Fab.Y }
		end
		return nil
	end
	function Stats.Fab.Apply(saved)
		if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
			place(saved.x, saved.y)
		end
	end
	-- Back to the corner it starts in.
	function Stats.Fab.Reset()
		Stats.Fab.X, Stats.Fab.Y = nil, nil
		fab.Position = touchOnly and UDim2.new(1, -20, 0.5, 0) or UDim2.new(1, -24, 1, -24)
	end
end
fab.Activated:Connect(function()
	if Stats.Fab.Moved then
		return -- that press was a drag
	end
	setOpen(true)
end)
Tip(fab, "Open panel (drag to move)")

local function showFab(show)
	if show then
		fab.Visible = true
		fabScale.Scale = 0.6
		play(fabScale, Motion.Base, "Back", { Scale = 1 })
	else
		play(fabScale, Motion.Quick, "In", { Scale = 0.6 })
		local token = openToken
		task.delay(scaledTime(Motion.Quick) + 0.05, function()
			if isOpen and openToken == token then
				fab.Visible = false
			end
		end)
	end
end

--------------------------------------------------------------------------
-- RESPONSIVE HANDLING
--------------------------------------------------------------------------

local layout = { Scale = 1, Compact = false }

local function setCompactLabels(compact)
	Stats.Nav.Compact = compact
	for _, item in ipairs(navButtons) do
		item.Label.Visible = not compact
		item.PaintPin()
	end
	brandText.Visible = not compact
	userLabel.Visible = not compact
end

-- Fits the fixed-design panel to the current viewport. The panel's layout
-- size shrinks first (content scrolls), and only tiny viewports scale down.
applyLayout = function()
	local viewport = screen.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end
	local margin = 16
	local availableWidth = viewport.X - margin * 2
	local availableHeight = viewport.Y - margin * 2

	local scale = math.min(
		State.UIScale,
		availableWidth / CONFIG.MinPanelSize.X,
		availableHeight / CONFIG.MinPanelSize.Y
	)
	local width = math.min(CONFIG.PanelSize.X, availableWidth / scale)
	local height = math.min(CONFIG.PanelSize.Y, availableHeight / scale)
	local compact = width < CONFIG.CompactBelow

	layout.Scale = scale
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
	if isOpen then
		-- The panel may have been dragged outside the new viewport, so the
		-- stored offset is re-clamped against the resized panel and holder.
		drag.X, drag.Y = clampDragOffset(drag.X, drag.Y)
		panel.Position = panelHome()
		if panelTween then
			panelTween:Cancel()
			panelTween = nil
		end
		panelScale.Scale = scale
	end

	local sidebarWidth = compact and CONFIG.SidebarCompact or CONFIG.SidebarWide
	local bodyOffset = 10 + sidebarWidth + 16
	local sidebarGoal = { Size = UDim2.new(0, sidebarWidth, 1, -20) }
	local bodyGoal = {
		Position = UDim2.fromOffset(bodyOffset, 0),
		Size = UDim2.new(1, -bodyOffset - 18, 1, 0),
	}
	if compact ~= layout.Compact then
		layout.Compact = compact
		setCompactLabels(compact)
		play(sidebar, Motion.Base, "Out", sidebarGoal)
		play(body, Motion.Base, "Out", bodyGoal)
	else
		sidebar.Size = sidebarGoal.Size
		body.Position = bodyGoal.Position
		body.Size = bodyGoal.Size
	end
end

--------------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------------

-- First-person games hold the cursor locked and hidden while a menu is up.
-- Modal used to free it, but a modal GuiObject also makes every other GuiObject
-- in the same ScreenGui non-interactive, so the panel's own controls died and
-- clicks fell through to the scrim. Driving MouseBehavior releases the cursor
-- without touching interactivity, and the previous value is restored so the
-- host game keeps its own mouse handling.
local savedMouseBehavior = nil

local function captureMouse()
	if savedMouseBehavior == nil then
		savedMouseBehavior = UserInputService.MouseBehavior
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function releaseMouse()
	if savedMouseBehavior == nil then
		return
	end
	UserInputService.MouseBehavior = savedMouseBehavior
	savedMouseBehavior = nil
end

setOpen = function(open)
	-- Nothing may open the panel before loading and the password are done.
	if open and not Gate.Authenticated then
		return
	end
	-- Opening the panel is also a way out of AFK mode.
	if open and State.Afk then
		Features.Set("afk", false)
	end
	if open == isOpen then
		return
	end
	isOpen = open
	openToken = openToken + 1
	local token = openToken
	if panelTween then
		panelTween:Cancel()
	end
	-- Any drag in progress is ended first so its render listener stops
	-- writing Position before the reveal / recede tween below takes over.
	if dragInput then
		stopDrag()
	end

	if open then
		scrim.Visible = true
		captureMouse()
		holder.Visible = true
		-- A resize while the panel was closed can leave the stored offset
		-- outside the new viewport, so re-clamp before revealing it.
		drag.X, drag.Y = clampDragOffset(drag.X, drag.Y)
		panelScale.Scale = layout.Scale * 0.94
		-- Reveal from slightly below wherever the panel was last left.
		panel.Position = UDim2.new(0.5, drag.X, 0.5, drag.Y + 16)
		panelTween = play(panelScale, Motion.Reveal, "Back", { Scale = layout.Scale })
		play(panel, Motion.Reveal, "Out", { Position = panelHome() })
		play(scrim, Motion.Base, "Out", { BackgroundTransparency = 0.5 })
		showFab(false)
	else
		-- Minimize: the panel recedes toward the floating button's corner and
		-- only once it is gone does the button arrive, so the two read as one
		-- motion rather than a panel vanishing under a separate pop-in.
		-- The recede leans toward the button it is about to become.
		local towardX, towardY = 0, 26
		if fab.Parent then
			local viewport = screen.AbsoluteSize
			towardX = (fab.AbsolutePosition.X + fab.AbsoluteSize.X / 2 - viewport.X / 2 - drag.X) * 0.12
			towardY = (fab.AbsolutePosition.Y + fab.AbsoluteSize.Y / 2 - viewport.Y / 2 - drag.Y) * 0.12
		end
		panelTween = play(panelScale, Motion.Base, "Sine", { Scale = layout.Scale * 0.88 })
		play(panel, Motion.Base, "Sine", { Position = UDim2.new(0.5, drag.X + towardX, 0.5, drag.Y + towardY) })
		play(scrim, Motion.Quick, "In", { BackgroundTransparency = 1 })
		releaseMouse()
		task.delay(scaledTime(Motion.Base), function()
			-- A newer open/close supersedes this hide.
			if openToken == token then
				holder.Visible = false
				scrim.Visible = false
				showFab(true)
				Ambient.refresh()
			end
		end)
	end

	Ambient.refresh()
	refreshBlur()
	Metrics.refresh()
end

--------------------------------------------------------------------------

-- The scrim intentionally has no Activated handler: closing is limited to the
-- close button, the floating toggle, the hotkey, Escape and the Roblox menu.

--------------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------------

track(UserInputService.InputBegan:Connect(function(input, processed)
	-- Escape is delivered as "processed" (it opens the Roblox menu), so it is
	-- handled before the processed check.
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		setOpen(false)
		return
	end
	if processed then
		return
	end
	if input.KeyCode == CONFIG.ToggleKey then
		setOpen(not isOpen)
	end
end))

track(GuiService.MenuOpened:Connect(function()
	if isOpen then
		setOpen(false)
	end
end))

track(Players.PlayerAdded:Connect(function(other)
	Stats.Players.Set(tostring(#Players:GetPlayers()), #Players:GetPlayers() / math.max(Players.MaxPlayers, 1))
	if serverSizeLabel then
		serverSizeLabel.Text = playerCountText()
	end
	if Stats.GamePlayers then
		Stats.GamePlayers.Text = playerCountText()
	end
	logActivity(other.DisplayName .. " joined", "Server population changed", "Success")
end))

track(Players.PlayerRemoving:Connect(function(other)
	-- PlayerRemoving fires before the player leaves the list.
	local remaining = math.max(#Players:GetPlayers() - 1, 0)
	Stats.Players.Set(tostring(remaining), remaining / math.max(Players.MaxPlayers, 1))
	if serverSizeLabel then
		serverSizeLabel.Text = tostring(remaining) .. " / " .. tostring(Players.MaxPlayers)
	end
	if Stats.GamePlayers then
		Stats.GamePlayers.Text = tostring(remaining) .. " / " .. tostring(Players.MaxPlayers)
	end
	logActivity(other.DisplayName .. " left", "Server population changed", "Warning")
end))

track(screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))

pcall(function()
	track(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		systemReducedMotion = GuiService.ReducedMotionEnabled == true
		Ambient.refresh()
	end))
end)

--------------------------------------------------------------------------
-- ACCESS GATE  (loading screen -> password screen -> main GUI)
--
-- setOpen() refuses to open the panel until Gate.Authenticated is true.
-- Only unlockGate() sets it, and only after loading has finished and the
-- password matched CONFIG.Password exactly.
--------------------------------------------------------------------------

do
	-- Own function = own register budget. The gate builds dozens of locals, and
	-- keeping them in the main chunk pushed it to the 200-local limit.
	local function buildGate()
	-- The gate used to be an opaque Theme.Color.Cover frame spanning the whole
	-- screen, which was the black wall behind the loading and password cards.
	-- It is now fully transparent so the game stays visible while loading; the
	-- cards carry their own surface so the text remains readable, and the
	-- Blocker underneath still swallows clicks and frees the mouse.
	local gate = New("Frame", {
		Name = "Gate",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = screen,
	})
	-- Swallows clicks while the gate is up. The mouse is freed through
	-- MouseBehavior (captureMouse), not Modal, which would make the rest of the
	-- ScreenGui non-interactive.
	local blocker = New("TextButton", {
		Name = "Blocker",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gate,
	})

	-- The decorative glow that used to sit behind the loading and password
	-- cards has been removed along with the opaque Cover backdrop, so the game
	-- is visible through the gate and nothing else is drawn behind the card.

	-- A card is a CanvasGroup (so it fades as one piece) around a styled frame.
	local function makeCard(name, height, transparency)
		local group = New("CanvasGroup", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 0, 0, height),
			GroupTransparency = 1,
			Visible = false,
			Parent = gate,
		})
		New("UISizeConstraint", { MaxSize = Vector2.new(400, math.huge), Parent = group })
		local card = New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.Color.Surface,
			BackgroundTransparency = transparency or 0.2,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = group,
		})
		Round(card, Theme.Radius.XL)
		Stroke(card, 0.86)
		return group, card
	end

	-- The gate draws the same brand mark as the sidebar and the About hero, so a
	-- CONFIG.Logo asset shows up everywhere at once. When it is empty, Brandmark
	-- falls back to the accent gradient and sparkle.
	local function makeMark(parent, size, y)
		local mark = Brandmark(parent, size, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
		})
		mark.Name = "Mark"
		return mark
	end

	local CENTER = Enum.TextXAlignment.Center

	-- LOADING CARD ---------------------------------------------------------
	-- With the logo the card grows to give it room as the main visual; without
	-- it every position below is the original one (LD = 0).
	local LOGO_ON = CONFIG.ResolvedLogo ~= nil
	local LD = LOGO_ON and 44 or 0
	local loadingGroup, loadingCard = makeCard("Loading", 290 + LD, 0.42)
	local loadMark = makeMark(loadingCard, 64 + LD, LOGO_ON and 22 or 30)
	local loadMarkScale = New("UIScale", { Parent = loadMark })
	Text(loadingCard, CONFIG.Title, Theme.Type.Display, "Bold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(28, 106 + LD),
		Size = UDim2.new(1, -56, 0, 30),
		TextXAlignment = CENTER,
	})
	Text(loadingCard, "by " .. CONFIG.Author .. "  -  v" .. CONFIG.Version, Theme.Type.Caption, "Medium",
		Theme.Color.TextLow, {
			Position = UDim2.fromOffset(28, 138 + LD),
			Size = UDim2.new(1, -56, 0, 16),
			TextXAlignment = CENTER,
		})

	-- Spinner: a ring whose stroke gradient rotates.
	local spinner = New("Frame", {
		Name = "Spinner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 172 + LD),
		Size = UDim2.fromOffset(34, 34),
		Parent = loadingCard,
	})
	local spinnerTrack = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = spinner })
	Round(spinnerTrack, Theme.Radius.Pill)
	Stroke(spinnerTrack, 0.9, Theme.Color.White, 3)
	local spinnerArc = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = spinner })
	Round(spinnerArc, Theme.Radius.Pill)
	local arcStroke = Stroke(spinnerArc, 0, Theme.Color.White, 3)
	local arcGradient = AccentGradient(arcStroke, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	}))

	-- Progress bar + status.
	local barTrack = New("Frame", {
		Name = "BarTrack",
		BackgroundColor3 = Theme.Color.White,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(28, 226 + LD),
		Size = UDim2.new(1, -56, 0, 6),
		Parent = loadingCard,
	})
	Round(barTrack, Theme.Radius.Pill)
	local barFill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = barTrack,
	})
	Round(barFill, Theme.Radius.Pill)
	AccentGradient(barFill, 0)
	local statusLabel = Text(loadingCard, "Starting...", Theme.Type.Caption, "Medium", Theme.Color.TextMid, {
		Position = UDim2.fromOffset(28, 242 + LD),
		Size = UDim2.new(1, -110, 0, 16),
	})
	local percentLabel = Text(loadingCard, "0%", Theme.Type.Caption, "SemiBold", Theme.Color.TextHi, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 242 + LD),
		Size = UDim2.fromOffset(60, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- PASSWORD CARD --------------------------------------------------------
	-- "Remember me" keeps the password in a plain text file inside the
	-- executor's own workspace, so later runs of the script open straight to the
	-- panel. It is deliberately not obfuscated: anyone with access to that
	-- workspace file can read it, so the checkbox says so on hover. Without file
	-- access (some executors) the option hides itself rather than pretending.
	local REMEMBER_PATH = "ModernGui/remember.txt"
	local canStore = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local storedPassword = nil
	if canStore and pcall(isfile, REMEMBER_PATH) and isfile(REMEMBER_PATH) then
		local ok, value = pcall(readfile, REMEMBER_PATH)
		if ok and type(value) == "string" then
			storedPassword = string.match(value, "^%s*(.-)%s*$")
			if storedPassword == "" then
				storedPassword = nil
			end
		end
	end
	local function rememberPassword(value)
		if not canStore then
			return
		end
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" then
				if not isfolder("ModernGui") then
					makefolder("ModernGui")
				end
			end
		end)
		if value and value ~= "" then
			pcall(writefile, REMEMBER_PATH, value)
		else
			-- Unticking has to clear the old value, or the next run would still
			-- skip the prompt the user just asked to see again.
			if type(delfile) == "function" then
				pcall(delfile, REMEMBER_PATH)
			elseif type(removefile) == "function" then
				pcall(removefile, REMEMBER_PATH)
			end
		end
	end

	local AD = LOGO_ON and 30 or 0
	local authGroup, authCard = makeCard("Password", 356 + AD, 0.16)
	makeMark(authCard, 52 + AD, 24)
	-- A padlock beside the mark: the card is the one place in the interface that
	-- asks for something, and the glyph says so before the words do.
	if not LOGO_ON then
		Icon(authCard, "lock", 16, Theme.Color.TextLow, {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0.5, 24, 0, 40),
		})
	end
	Text(authCard, "Welcome Back", Theme.Type.Display, "Bold", Theme.Color.TextHi, {
		Position = UDim2.fromOffset(28, 90 + AD),
		Size = UDim2.new(1, -56, 0, 30),
		TextXAlignment = CENTER,
	})
	Text(authCard, "Enter your password", Theme.Type.Caption, "Regular",
		Theme.Color.TextMid, {
			Wrap = true,
			Position = UDim2.fromOffset(28, 122 + AD),
			Size = UDim2.new(1, -56, 0, 16),
			TextXAlignment = CENTER,
		})

	local inputFrame = New("Frame", {
		Name = "Input",
		BackgroundColor3 = Theme.Color.Alt,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(28, 168 + AD),
		Size = UDim2.new(1, -56, 0, 46),
		Parent = authCard,
	})
	Round(inputFrame, Theme.Radius.SM)
	local inputStroke = Stroke(inputFrame, 0.85)
	local passBox = New("TextBox", {
		Name = "PasswordBox",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		ClearTextOnFocus = false,
		PlaceholderText = "Password",
		PlaceholderColor3 = Theme.Color.TextLow,
		Text = "",
		TextColor3 = Theme.Color.TextHi,
		TextSize = Theme.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = inputFrame,
	})
	applyFont(passBox, "Medium")

	local messageLabel = Text(authCard, "", Theme.Type.Caption, "Medium", Theme.Color.TextLow, {
		Position = UDim2.fromOffset(28, 222 + AD),
		Size = UDim2.new(1, -56, 0, 16),
		TextXAlignment = CENTER,
	})

	local rememberRow
	if canStore then
		rememberRow = Checkbox(authCard, {
			Text = "Remember me",
			Default = storedPassword ~= nil,
		})
		-- authCard positions its children by hand rather than by a list layout,
		-- so the control's automatic size is replaced with a fixed slot.
		rememberRow.Instance.Position = UDim2.fromOffset(28, 244 + AD)
		rememberRow.Instance.Size = UDim2.new(1, -56, 0, 30)
		Tip(rememberRow.Instance,
			"Saves the password as plain text in ModernGui/remember.txt in this executor's workspace. "
				.. "Anyone who can read that file can read the password.")
	else
		-- Silent disappearance would look broken, so the reason is stated in the
		-- space the checkbox would have used.
		local noStore = Text(authCard,
			"This executor has no file access, so the password cannot be remembered.",
			Theme.Type.Micro, "Regular", Theme.Color.TextLow, {
			Position = UDim2.fromOffset(28, 244 + AD),
			Size = UDim2.new(1, -56, 0, 30),
			TextXAlignment = CENTER,
			Wrap = true,
		})
		Padding(noStore, 0, 2, 0, 0)
	end

	local attempts, lockedUntil, unlocking, messageIsError = 0, 0, false, false

	local function paintInput(kind)
		local color, alpha = Theme.Color.White, 0.85
		if kind == "focus" then
			color, alpha = Accent.Color, 0.35
		elseif kind == "error" then
			color, alpha = Theme.Color.Negative, 0.2
		elseif kind == "success" then
			color, alpha = Theme.Color.Positive, 0.2
		end
		play(inputStroke, Motion.Quick, "Out", { Color = color, Transparency = alpha })
	end

	local function setMessage(text, color, isError)
		messageLabel.Text = text
		messageLabel.TextColor3 = color
		messageIsError = isError
	end

	local function shake()
		task.spawn(function()
			for _, dx in ipairs({ -10, 10, -6, 6, 0 }) do
				if not authGroup.Parent then
					return
				end
				play(authGroup, 0.05, "Sine", { Position = UDim2.new(0.5, dx, 0.5, 0) })
				task.wait(0.055)
			end
		end)
	end

	-- Called once the password has been accepted. Only place that opens the way.
	local function revealMain()
		fab.Visible = true
		-- An overlay that was switched on in a saved config shows now, not before
		-- the password: it reports what the tool is doing.
		QuickOverlay.Refresh()
		fabScale.Scale = 0.6
		play(fabScale, Motion.Reveal, "Back", { Scale = 1 })
		logActivity("Access granted", "Password accepted", "Success")
		-- The interface has finished loading, so take one full pass at the egg
		-- folder instead of waiting for the scanner's next incremental tick.
		if Config.Rescan then
			pcall(Config.Rescan)
		end
		-- Startup config, then whatever a server hop left behind. Deferred a
		-- moment so the first egg scan has landed and the Features records the
		-- automation reads from exist.
		if Config.RunStartup then
			task.delay(0.6, function()
				if screen.Parent then
					pcall(Config.RunStartup)
				end
			end)
		end
		if CONFIG.AutoOpen then
			task.delay(0.35, function()
				setOpen(true)
			end)
		end
	end

	local function unlockGate()
		unlocking = true
		Gate.Authenticated = true
		-- Saved only on success, and only if the box is ticked, so a wrong guess
		-- can never end up on disk.
		if rememberRow and rememberRow:Get() then
			rememberPassword(CONFIG.Password)
		else
			-- Unticking has to clear a value that was saved on an earlier run, and
			-- an executor with no checkbox has nothing to tick, so both land here.
			-- rememberPassword already does nothing when file access is missing.
			rememberPassword(nil)
		end
		passBox:ReleaseFocus()
		paintInput("success")
		setMessage("Access granted", Theme.Color.Positive, false)
		task.delay(0.55, function()
			if not gate.Parent then
				return
			end
			play(authGroup, Motion.Quick, "In", { GroupTransparency = 1 })
			task.delay(scaledTime(Motion.Quick) + 0.05, function()
				if not gate.Parent then
					return
				end
				-- The gate is finished: hide it and remove its input blocker
				-- so nothing full-screen is left above the panel (a lingering
				-- blocker swallowed every click, drags included).
				gate.Visible = false
				blocker:Destroy()
				releaseMouse()
				revealMain()
			end)
		end)
	end
	local function submitPassword()
		if Gate.Authenticated or unlocking or not Gate.Loaded then
			return
		end
		if os.clock() < lockedUntil then
			return
		end
		-- Only stray leading/trailing whitespace (mobile keyboards add it) is ignored.
		local entered = string.match(passBox.Text, "^%s*(.-)%s*$") or ""
		if entered == "" then
			setMessage("Please enter the password.", Theme.Color.Caution, true)
			paintInput("error")
			return
		end
		if entered == CONFIG.Password then
			unlockGate()
			return
		end

		attempts = attempts + 1
		passBox.Text = ""
		paintInput("error")
		shake()
		if attempts >= CONFIG.MaxAttempts then
			attempts = 0
			lockedUntil = os.clock() + CONFIG.LockSeconds
			task.spawn(function()
				while os.clock() < lockedUntil and gate.Parent do
					setMessage(
						string.format("Too many attempts. Try again in %ds.", math.ceil(lockedUntil - os.clock())),
						Theme.Color.Negative, true
					)
					task.wait(0.25)
				end
				if gate.Parent and not Gate.Authenticated then
					setMessage("You can try again now.", Theme.Color.TextMid, false)
					paintInput("idle")
				end
			end)
		else
			setMessage(
				string.format("Incorrect password. %d attempt(s) left before a short lock.",
					CONFIG.MaxAttempts - attempts),
				Theme.Color.Negative, true
			)
		end
	end

	local unlockButton = Button(authCard, {
		Text = "Unlock",
		Icon = "check",
		Style = "Primary",
		Callback = submitPassword,
	})
	unlockButton.Instance.Position = UDim2.fromOffset(28, 286 + AD)
	unlockButton.Instance.Size = UDim2.new(1, -56, 0, 46)

	passBox.Focused:Connect(function()
		if os.clock() >= lockedUntil then
			paintInput("focus")
		end
	end)
	passBox.FocusLost:Connect(function(enterPressed)
		if not Gate.Authenticated and not messageIsError then
			paintInput("idle")
		end
		if enterPressed then
			submitPassword()
		end
	end)
	passBox:GetPropertyChangedSignal("Text"):Connect(function()
		if messageIsError and passBox.Text ~= "" and os.clock() >= lockedUntil then
			setMessage("", Theme.Color.TextLow, false)
			paintInput(passBox:IsFocused() and "focus" or "idle")
		end
	end)

	-- LOADING STEPS --------------------------------------------------------
	local function waitForGame()
		local startedAt = os.clock()
		while not game:IsLoaded() and os.clock() - startedAt < 10 do
			task.wait(0.1)
		end
	end

	local function loadAvatar()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok and type(content) == "string" and content ~= "" and Stats.Avatar then
			Stats.Avatar.Image = content
			if Stats.AvatarInitial then
				Stats.AvatarInitial.Visible = false
			end
		end
	end

	local function loadPlaceName()
		local name = game.Name
		if game.PlaceId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfo(game.PlaceId)
			end)
			if ok and type(result) == "table" and type(result.Name) == "string" and result.Name ~= "" then
				name = result.Name
			end
		end
		if Stats.PlaceLabel then
			Stats.PlaceLabel.Text = name
		end
	end

	local STEPS = {
		{ Text = "Connecting to game...", Run = waitForGame },
		{ Text = "Loading your profile...", Run = loadAvatar },
		{ Text = "Reading game info...", Run = loadPlaceName },
		{ Text = "Preparing interface...", Run = function() task.wait(0.3) end },
	}
	local MIN_STEP_TIME = 0.45

	-- START ----------------------------------------------------------------
	function Gate.Start()
		-- Looping indicator tweens use TweenService directly so the spinner
		-- keeps moving whatever the animation settings are.
		local spin = TweenService:Create(
			arcGradient,
			TweenInfo.new(1.05, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Rotation = 360 }
		)
		local pulse = TweenService:Create(
			loadMarkScale,
			TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.07 }
		)
		spin:Play()
		pulse:Play()
		Gate.Tweens = { spin, pulse }

		captureMouse()
		loadingGroup.Visible = true
		play(loadingGroup, Motion.Reveal, "Out", { GroupTransparency = 0 })

		-- Smoothly chase the real progress; the connection lives only while loading.
		local target, shown = 0, 0
		Gate.Connection = RunService.Heartbeat:Connect(function(dt)
			shown = shown + (target - shown) * math.min(1, dt * 5)
			if target - shown < 0.002 then
				shown = target
			end
			barFill.Size = UDim2.fromScale(shown, 1)
			percentLabel.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
		end)

		task.spawn(function()
			for index, step in ipairs(STEPS) do
				if not gate.Parent then
					return
				end
				statusLabel.Text = step.Text
				target = math.max(target, (index - 1) / #STEPS + 0.4 / #STEPS)
				local startedAt = os.clock()
				pcall(step.Run)
				local remaining = MIN_STEP_TIME - (os.clock() - startedAt)
				if remaining > 0 then
					task.wait(remaining)
				end
				target = index / #STEPS
			end
			statusLabel.Text = "Ready"
			target = 1
			local waited = 0
			while shown < 0.995 and waited < 1.5 and gate.Parent do
				task.wait(0.05)
				waited = waited + 0.05
			end
			task.wait(0.25)
			if not gate.Parent then
				return
			end

			Gate.Loaded = true
			if Gate.Connection then
				Gate.Connection:Disconnect()
				Gate.Connection = nil
			end
			play(loadingGroup, Motion.Quick, "In", { GroupTransparency = 1 })
			task.wait(scaledTime(Motion.Quick) + 0.05)
			if not gate.Parent then
				return
			end
			loadingGroup.Visible = false
			for _, tween in ipairs(Gate.Tweens) do
				tween:Cancel()
			end
			table.clear(Gate.Tweens)

			authGroup.Position = UDim2.new(0.5, 0, 0.5, 14)
			authGroup.Visible = true
			play(authGroup, Motion.Reveal, "Out", {
				GroupTransparency = 0,
				Position = UDim2.fromScale(0.5, 0.5),
			})
			if not touchOnly then
				task.delay(0.3, function()
					if gate.Parent and not Gate.Authenticated then
						passBox:CaptureFocus()
					end
				end)
			end

			-- Remembered password: the box arrives already filled and submits on
			-- its own, so a returning user does not retype anything. The delay
			-- lets the card finish revealing first, so the grant animation is
			-- visible rather than skipped.
			if storedPassword then
				passBox.Text = storedPassword
				task.delay(0.75, function()
					if gate.Parent and Gate.Loaded and not Gate.Authenticated then
						submitPassword()
					end
				end)
			end
		end)
	end
	end
	buildGate()
end

--------------------------------------------------------------------------
-- INITIALISATION
--------------------------------------------------------------------------

local function cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, tween in ipairs(Ambient.Tweens) do
		tween:Cancel()
	end
	table.clear(Ambient.Tweens)
	if Metrics.Connection then
		Metrics.Connection:Disconnect()
		Metrics.Connection = nil
	end
	if Features.AFK then
		Features.AFK.Release() -- the world is drawn again and the cover is gone
	end
	QuickOverlay.Release()
	Features.Clear()
	if Gate.Connection then
		Gate.Connection:Disconnect()
		Gate.Connection = nil
	end
	for _, tween in ipairs(Gate.Tweens) do
		tween:Cancel()
	end
	table.clear(Gate.Tweens)
	if Stats.ClearHealth then
		Stats.ClearHealth()
	end
	Boost.release() -- puts every suppressed effect, texture and lighting setting back
	-- A drag in progress owns live InputChanged / RenderStepped listeners that
	-- are not part of the tracked service connections, so they are released
	-- here rather than left pointing at a destroyed panel.
	if dragInput or dragMove or dragEnd or dragStep then
		stopDrag()
	end
	if dragSettle then
		dragSettle:Cancel()
		dragSettle = nil
	end
	releaseMouse() -- never leave the cursor forced free if we were torn down mid-open
	if blurEffect then
		blurEffect:Destroy()
		blurEffect = nil
	end
end
screen.Destroying:Connect(cleanup)

applyAccent()
refreshCorners()
applyLayout()
setCompactLabels(layout.Compact)
setPage("Home", true)
moveIndicator(false)
panelScale.Scale = layout.Scale * 0.94

-- The panel and floating button stay hidden until the gate has finished
-- loading and the password has been accepted; the gate then opens the panel.
Gate.Start()

notify("Interface ready", "Success", "Press " .. string.upper(CONFIG.ToggleKey.Name) .. " any time to open or close the panel.")
