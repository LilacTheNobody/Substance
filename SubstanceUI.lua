-- Substance UI Library
-- purple themed ui framework


local SubstanceUI = {}
SubstanceUI.__index = SubstanceUI

-- Theme Configuration
local Theme = {
    -- Primary purple gradient stops
    Primary = Color3.fromRGB(138, 43, 226),      -- BlueViolet
    PrimaryDark = Color3.fromRGB(75, 0, 130),     -- Indigo
    PrimaryLight = Color3.fromRGB(186, 85, 255),  -- Light purple
    Accent = Color3.fromRGB(200, 130, 255),        -- Soft lavender accent

    -- Backgrounds
    Background = Color3.fromRGB(15, 12, 25),       -- Deep dark purple-black
    BackgroundSecondary = Color3.fromRGB(22, 18, 35), -- Slightly lighter
    BackgroundTertiary = Color3.fromRGB(30, 24, 48),  -- Card bg

    -- Surfaces
    Surface = Color3.fromRGB(35, 28, 55),
    SurfaceHover = Color3.fromRGB(45, 36, 70),
    SurfaceActive = Color3.fromRGB(55, 44, 85),

    -- Text
    TextPrimary = Color3.fromRGB(240, 235, 255),
    TextSecondary = Color3.fromRGB(160, 145, 190),
    TextMuted = Color3.fromRGB(100, 88, 130),

    -- Stroke / Border
    Stroke = Color3.fromRGB(80, 60, 120),
    StrokeHover = Color3.fromRGB(138, 43, 226),

    -- Status
    Success = Color3.fromRGB(80, 220, 120),
    Warning = Color3.fromRGB(255, 200, 60),
    Error = Color3.fromRGB(255, 80, 80),

    -- Misc
    Shadow = Color3.fromRGB(0, 0, 0),
    CornerRadius = UDim.new(0, 10),
    CornerRadiusSmall = UDim.new(0, 6),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontSemibold = Enum.Font.GothamSemibold,
}

SubstanceUI.Theme = Theme

-- Utility Functions
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function tween(obj, props, duration, style, dir)
    duration = duration or 0.3
    style = style or Enum.EasingStyle.Quart
    dir = dir or Enum.EasingDirection.Out
    local t = TweenService:Create(obj, TweenInfo.new(duration, style, dir), props)
    t:Play()
    return t
end

local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius or Theme.CornerRadius
    corner.Parent = parent
    return corner
end

local function createStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Stroke
    stroke.Thickness = thickness or 1.5
    stroke.Transparency = transparency or 0.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function createPadding(parent, t, b, l, r)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, t or 8)
    pad.PaddingBottom = UDim.new(0, b or 8)
    pad.PaddingLeft = UDim.new(0, l or 10)
    pad.PaddingRight = UDim.new(0, r or 10)
    pad.Parent = parent
    return pad
end

local function createGradient(parent, colorStart, colorEnd, rotation)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorStart or Theme.PrimaryDark),
        ColorSequenceKeypoint.new(1, colorEnd or Theme.Primary),
    })
    grad.Rotation = rotation or 45
    grad.Parent = parent
    return grad
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local targetPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            tween(frame, { Position = targetPos }, 0.08, Enum.EasingStyle.Quad)
        end
    end)
end

-- Ripple Effect
local function createRipple(button)
    button.ClipsDescendants = true
    button.MouseButton1Click:Connect(function()
        local mouse = Players.LocalPlayer:GetMouse()
        local ripple = Instance.new("Frame")
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.BackgroundColor3 = Color3.new(1, 1, 1)
        ripple.BackgroundTransparency = 0.7
        ripple.BorderSizePixel = 0
        ripple.Position = UDim2.new(0, mouse.X - button.AbsolutePosition.X, 0, mouse.Y - button.AbsolutePosition.Y)
        ripple.Size = UDim2.fromOffset(0, 0)
        ripple.Parent = button
        createCorner(ripple, UDim.new(1, 0))

        local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
        local t = tween(ripple, {
            Size = UDim2.fromOffset(maxSize, maxSize),
            BackgroundTransparency = 1
        }, 0.6, Enum.EasingStyle.Quad)
        t.Completed:Connect(function()
            ripple:Destroy()
        end)
    end)
end

-- Notification System
local notificationContainer

local function ensureNotifContainer()
    if notificationContainer and notificationContainer.Parent then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SubstanceNotifications"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    notificationContainer = Instance.new("Frame")
    notificationContainer.Name = "Container"
    notificationContainer.AnchorPoint = Vector2.new(1, 1)
    notificationContainer.Position = UDim2.new(1, -20, 1, -20)
    notificationContainer.Size = UDim2.new(0, 280, 1, -40)
    notificationContainer.BackgroundTransparency = 1
    notificationContainer.Parent = screenGui

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = notificationContainer
end

function SubstanceUI:Notify(config)
    config = config or {}
    ensureNotifContainer()

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 60)
    card.BackgroundColor3 = Theme.BackgroundTertiary
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = notificationContainer
    createCorner(card, Theme.CornerRadiusSmall)
    createStroke(card, Theme.Stroke, 1, 0.6)

    -- Purple accent bar on left
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.BackgroundColor3 = config.Color or Theme.Primary
    accentBar.BorderSizePixel = 0
    accentBar.Parent = card

    local title = Instance.new("TextLabel")
    title.Text = config.Title or "Substance"
    title.Font = Theme.FontBold
    title.TextSize = 13
    title.TextColor3 = Theme.TextPrimary
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 14, 0, 8)
    title.Size = UDim2.new(1, -20, 0, 16)
    title.Parent = card

    local desc = Instance.new("TextLabel")
    desc.Text = config.Description or ""
    desc.Font = Theme.Font
    desc.TextSize = 11
    desc.TextColor3 = Theme.TextSecondary
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.new(0, 14, 0, 26)
    desc.Size = UDim2.new(1, -20, 0, 28)
    desc.Parent = card

    -- Slide in
    card.Position = UDim2.new(1, 0, 0, 0)
    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.4, Enum.EasingStyle.Back)

    -- Auto dismiss
    task.delay(config.Duration or 4, function()
        tween(card, { Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1 }, 0.4)
        task.wait(0.5)
        pcall(function() card:Destroy() end)
    end)
end

-- Window Creation
function SubstanceUI:CreateWindow(config)
    config = config or {}
    local Window = {}
    Window.Tabs = {}
    Window.ActiveTab = nil

    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Substance"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    Window.ScreenGui = screenGui

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = config.Size or UDim2.fromOffset(550, 400)
    main.BackgroundColor3 = Theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    createCorner(main, UDim.new(0, 12))
    createStroke(main, Theme.PrimaryDark, 2, 0.3)

    -- Drop shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.ZIndex = -1
    shadow.Parent = main

    Window.Main = main

        local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundColor3 = Theme.BackgroundSecondary
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    createCorner(titleBar, UDim.new(0, 12))

    -- Fix bottom corners of title bar
    local titleBarFix = Instance.new("Frame")
    titleBarFix.Size = UDim2.new(1, 0, 0, 12)
    titleBarFix.Position = UDim2.new(0, 0, 1, -12)
    titleBarFix.BackgroundColor3 = Theme.BackgroundSecondary
    titleBarFix.BorderSizePixel = 0
    titleBarFix.Parent = titleBar

    -- Gradient on title bar
    createGradient(titleBar, Theme.PrimaryDark, Color3.fromRGB(20, 15, 35), 90)

    makeDraggable(main, titleBar)

    -- Title text
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = (config.Title or "Substance"):upper()
    titleLabel.Font = Theme.FontBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = Theme.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 16, 0, 0)
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Parent = titleBar

    -- Subtitle
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Text = config.Subtitle or ""
    subtitleLabel.Font = Theme.Font
    subtitleLabel.TextSize = 11
    subtitleLabel.TextColor3 = Theme.TextMuted
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Position = UDim2.new(0, 16, 0, 28)
    subtitleLabel.Size = UDim2.new(0.5, 0, 0, 14)
    subtitleLabel.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Font = Theme.FontBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Theme.TextSecondary
    closeBtn.BackgroundTransparency = 1
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -8, 0.5, 0)
    closeBtn.Size = UDim2.fromOffset(30, 30)
    closeBtn.Parent = titleBar

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { TextColor3 = Theme.Error }, 0.2)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { TextColor3 = Theme.TextSecondary }, 0.2)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        tween(main, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.wait(0.4)
        screenGui:Destroy()
    end)

    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Text = "─"
    minimizeBtn.Font = Theme.FontBold
    minimizeBtn.TextSize = 16
    minimizeBtn.TextColor3 = Theme.TextSecondary
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
    minimizeBtn.Position = UDim2.new(1, -38, 0.5, 0)
    minimizeBtn.Size = UDim2.fromOffset(30, 30)
    minimizeBtn.Parent = titleBar

    local minimized = false
    local originalSize = config.Size or UDim2.fromOffset(550, 400)

    minimizeBtn.MouseEnter:Connect(function()
        tween(minimizeBtn, { TextColor3 = Theme.Warning }, 0.2)
    end)
    minimizeBtn.MouseLeave:Connect(function()
        tween(minimizeBtn, { TextColor3 = Theme.TextSecondary }, 0.2)
    end)
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tween(main, { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 42) }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        else
            tween(main, { Size = originalSize }, 0.35, Enum.EasingStyle.Back)
        end
    end)

        local body = Instance.new("Frame")
    body.Name = "Body"
    body.Position = UDim2.new(0, 0, 0, 42)
    body.Size = UDim2.new(1, 0, 1, -42)
    body.BackgroundTransparency = 1
    body.Parent = main

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 145, 1, 0)
    sidebar.BackgroundColor3 = Theme.BackgroundSecondary
    sidebar.BackgroundTransparency = 0.3
    sidebar.BorderSizePixel = 0
    sidebar.Parent = body

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    createPadding(sidebar, 8, 8, 8, 8)

    -- Sidebar divider line
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Position = UDim2.new(0, 145, 0, 0)
    divider.Size = UDim2.new(0, 1, 1, 0)
    divider.BackgroundColor3 = Theme.Stroke
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.Parent = body

    -- Content area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Position = UDim2.new(0, 146, 0, 0)
    content.Size = UDim2.new(1, -146, 1, 0)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = body

    Window.Sidebar = sidebar
    Window.Content = content

        main.Size = UDim2.fromOffset(0, 0)
    main.BackgroundTransparency = 1
    task.defer(function()
        tween(main, { Size = originalSize, BackgroundTransparency = 0 }, 0.5, Enum.EasingStyle.Back)
    end)

        function Window:CreateTab(tabConfig)
        tabConfig = tabConfig or {}
        local Tab = {}
        Tab.Name = tabConfig.Name or "Tab"
        Tab.Elements = {}

        -- Tab button in sidebar
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = Tab.Name
        tabBtn.Text = ""
        tabBtn.Size = UDim2.new(1, 0, 0, 36)
        tabBtn.BackgroundColor3 = Theme.Surface
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = sidebar
        createCorner(tabBtn, Theme.CornerRadiusSmall)

        -- Tab icon (optional)
        if tabConfig.Icon then
            local icon = Instance.new("ImageLabel")
            icon.Image = tabConfig.Icon
            icon.Size = UDim2.fromOffset(18, 18)
            icon.Position = UDim2.new(0, 8, 0.5, -9)
            icon.BackgroundTransparency = 1
            icon.ImageColor3 = Theme.TextSecondary
            icon.Parent = tabBtn
            Tab.Icon = icon
        end

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Text = Tab.Name
        tabLabel.Font = Theme.FontSemibold
        tabLabel.TextSize = 13
        tabLabel.TextColor3 = Theme.TextSecondary
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.BackgroundTransparency = 1
        tabLabel.Position = UDim2.new(0, tabConfig.Icon and 32 or 10, 0, 0)
        tabLabel.Size = UDim2.new(1, -(tabConfig.Icon and 40 or 16), 1, 0)
        tabLabel.Parent = tabBtn
        Tab.Label = tabLabel

        -- Active indicator bar
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0.5, 0)
        indicator.Position = UDim2.new(0, 0, 0.25, 0)
        indicator.BackgroundColor3 = Theme.Primary
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.Parent = tabBtn
        createCorner(indicator, UDim.new(0, 2))
        Tab.Indicator = indicator

        -- Content page for this tab
        local page = Instance.new("ScrollingFrame")
        page.Name = Tab.Name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.Primary
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = content
        Tab.Page = page

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 6)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        createPadding(page, 10, 10, 12, 12)

        -- Tab switching
        local function activateTab()
            -- Deactivate all
            for _, t in ipairs(Window.Tabs) do
                tween(t.Label, { TextColor3 = Theme.TextSecondary }, 0.2)
                tween(t.Indicator, { BackgroundTransparency = 1 }, 0.2)
                if t.Icon then tween(t.Icon, { ImageColor3 = Theme.TextSecondary }, 0.2) end
                if t.Button then tween(t.Button, { BackgroundTransparency = 1 }, 0.2) end
                t.Page.Visible = false
            end
            -- Activate this one
            tween(tabLabel, { TextColor3 = Theme.TextPrimary }, 0.2)
            tween(indicator, { BackgroundTransparency = 0 }, 0.2)
            if Tab.Icon then tween(Tab.Icon, { ImageColor3 = Theme.PrimaryLight }, 0.2) end
            tween(tabBtn, { BackgroundTransparency = 0.7 }, 0.2)
            page.Visible = true
            Window.ActiveTab = Tab
        end

        Tab.Button = tabBtn
        Tab.Activate = activateTab

        tabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                tween(tabBtn, { BackgroundTransparency = 0.85 }, 0.15)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                tween(tabBtn, { BackgroundTransparency = 1 }, 0.15)
            end
        end)
        tabBtn.MouseButton1Click:Connect(activateTab)

        table.insert(Window.Tabs, Tab)

        -- Auto-activate first tab
        if #Window.Tabs == 1 then
            task.defer(activateTab)
        end

        
        -- Section header
        function Tab:CreateSection(sectionConfig)
            local label = Instance.new("TextLabel")
            label.Text = (sectionConfig.Name or "Section"):upper()
            label.Font = Theme.FontBold
            label.TextSize = 11
            label.TextColor3 = Theme.TextMuted
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 0, 24)
            label.Parent = page
            return label
        end

        -- Button
        function Tab:CreateButton(btnConfig)
            local btn = Instance.new("TextButton")
            btn.Text = ""
            btn.Size = UDim2.new(1, 0, 0, 38)
            btn.BackgroundColor3 = Theme.Surface
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Parent = page
            createCorner(btn, Theme.CornerRadiusSmall)
            createStroke(btn, Theme.Stroke, 1, 0.7)
            createRipple(btn)

            local btnLabel = Instance.new("TextLabel")
            btnLabel.Text = btnConfig.Name or "Button"
            btnLabel.Font = Theme.FontSemibold
            btnLabel.TextSize = 13
            btnLabel.TextColor3 = Theme.TextPrimary
            btnLabel.TextXAlignment = Enum.TextXAlignment.Left
            btnLabel.BackgroundTransparency = 1
            btnLabel.Position = UDim2.new(0, 12, 0, 0)
            btnLabel.Size = UDim2.new(1, -24, 1, 0)
            btnLabel.Parent = btn

            btn.MouseEnter:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.SurfaceHover }, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.Surface }, 0.15)
            end)
            btn.MouseButton1Click:Connect(function()
                if btnConfig.Callback then
                    btnConfig.Callback()
                end
            end)

            return btn
        end

        -- Toggle
        function Tab:CreateToggle(toggleConfig)
            local toggled = toggleConfig.Default or false

            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 38)
            container.BackgroundColor3 = Theme.Surface
            container.BorderSizePixel = 0
            container.Parent = page
            createCorner(container, Theme.CornerRadiusSmall)
            createStroke(container, Theme.Stroke, 1, 0.7)

            local label = Instance.new("TextLabel")
            label.Text = toggleConfig.Name or "Toggle"
            label.Font = Theme.FontSemibold
            label.TextSize = 13
            label.TextColor3 = Theme.TextPrimary
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 0)
            label.Size = UDim2.new(1, -65, 1, 0)
            label.Parent = container

            local track = Instance.new("Frame")
            track.AnchorPoint = Vector2.new(1, 0.5)
            track.Position = UDim2.new(1, -10, 0.5, 0)
            track.Size = UDim2.fromOffset(40, 22)
            track.BackgroundColor3 = toggled and Theme.Primary or Theme.BackgroundTertiary
            track.BorderSizePixel = 0
            track.Parent = container
            createCorner(track, UDim.new(1, 0))

            local ball = Instance.new("Frame")
            ball.Size = UDim2.fromOffset(16, 16)
            ball.Position = toggled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            ball.BackgroundColor3 = Color3.new(1, 1, 1)
            ball.BorderSizePixel = 0
            ball.Parent = track
            createCorner(ball, UDim.new(1, 0))

            local clickBtn = Instance.new("TextButton")
            clickBtn.Text = ""
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Parent = container

            clickBtn.MouseButton1Click:Connect(function()
                toggled = not toggled
                tween(track, { BackgroundColor3 = toggled and Theme.Primary or Theme.BackgroundTertiary }, 0.25)
                tween(ball, { Position = toggled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }, 0.25, Enum.EasingStyle.Back)
                if toggleConfig.Callback then
                    toggleConfig.Callback(toggled)
                end
            end)

            local toggleObj = {}
            function toggleObj:Set(val)
                toggled = val
                tween(track, { BackgroundColor3 = toggled and Theme.Primary or Theme.BackgroundTertiary }, 0.25)
                tween(ball, { Position = toggled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }, 0.25, Enum.EasingStyle.Back)
                if toggleConfig.Callback then toggleConfig.Callback(toggled) end
            end
            return toggleObj
        end

        -- Slider
        function Tab:CreateSlider(sliderConfig)
            local min = sliderConfig.Min or 0
            local max = sliderConfig.Max or 100
            local current = sliderConfig.Default or min

            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 52)
            container.BackgroundColor3 = Theme.Surface
            container.BorderSizePixel = 0
            container.Parent = page
            createCorner(container, Theme.CornerRadiusSmall)
            createStroke(container, Theme.Stroke, 1, 0.7)

            local label = Instance.new("TextLabel")
            label.Text = sliderConfig.Name or "Slider"
            label.Font = Theme.FontSemibold
            label.TextSize = 13
            label.TextColor3 = Theme.TextPrimary
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 4)
            label.Size = UDim2.new(1, -60, 0, 20)
            label.Parent = container

            local valueLabel = Instance.new("TextLabel")
            valueLabel.Text = tostring(current)
            valueLabel.Font = Theme.Font
            valueLabel.TextSize = 12
            valueLabel.TextColor3 = Theme.Accent
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.BackgroundTransparency = 1
            valueLabel.Position = UDim2.new(1, -50, 0, 4)
            valueLabel.Size = UDim2.new(0, 38, 0, 20)
            valueLabel.Parent = container

            local trackBg = Instance.new("Frame")
            trackBg.Position = UDim2.new(0, 12, 0, 30)
            trackBg.Size = UDim2.new(1, -24, 0, 6)
            trackBg.BackgroundColor3 = Theme.BackgroundTertiary
            trackBg.BorderSizePixel = 0
            trackBg.Parent = container
            createCorner(trackBg, UDim.new(1, 0))

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((current - min) / (max - min), 0, 1, 0)
            fill.BackgroundColor3 = Theme.Primary
            fill.BorderSizePixel = 0
            fill.Parent = trackBg
            createCorner(fill, UDim.new(1, 0))
            createGradient(fill, Theme.PrimaryDark, Theme.PrimaryLight, 0)

            local knob = Instance.new("Frame")
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.Position = UDim2.new((current - min) / (max - min), 0, 0.5, 0)
            knob.Size = UDim2.fromOffset(14, 14)
            knob.BackgroundColor3 = Color3.new(1, 1, 1)
            knob.BorderSizePixel = 0
            knob.Parent = trackBg
            createCorner(knob, UDim.new(1, 0))

            local inputArea = Instance.new("TextButton")
            inputArea.Text = ""
            inputArea.Size = UDim2.new(1, 0, 1, 0)
            inputArea.BackgroundTransparency = 1
            inputArea.Parent = container

            local sliding = false

            local function updateSlider(inputX)
                local relX = math.clamp((inputX - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                current = math.floor(min + (max - min) * relX + 0.5)
                valueLabel.Text = tostring(current)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                knob.Position = UDim2.new(relX, 0, 0.5, 0)
                if sliderConfig.Callback then sliderConfig.Callback(current) end
            end

            inputArea.MouseButton1Down:Connect(function()
                sliding = true
                local mouse = Players.LocalPlayer:GetMouse()
                updateSlider(mouse.X)
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end)

            RunService.RenderStepped:Connect(function()
                if sliding then
                    local mouse = Players.LocalPlayer:GetMouse()
                    updateSlider(mouse.X)
                end
            end)

            local sliderObj = {}
            function sliderObj:Set(val)
                current = math.clamp(val, min, max)
                local relX = (current - min) / (max - min)
                valueLabel.Text = tostring(current)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                knob.Position = UDim2.new(relX, 0, 0.5, 0)
                if sliderConfig.Callback then sliderConfig.Callback(current) end
            end
            return sliderObj
        end

        -- Label
        function Tab:CreateLabel(labelConfig)
            local label = Instance.new("TextLabel")
            label.Text = labelConfig.Text or "Label"
            label.Font = Theme.Font
            label.TextSize = 13
            label.TextColor3 = Theme.TextSecondary
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextWrapped = true
            label.AutomaticSize = Enum.AutomaticSize.Y
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 0, 22)
            label.Parent = page

            local labelObj = {}
            function labelObj:Set(text) label.Text = text end
            return labelObj
        end

        -- Textbox
        function Tab:CreateTextbox(tbConfig)
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 38)
            container.BackgroundColor3 = Theme.Surface
            container.BorderSizePixel = 0
            container.Parent = page
            createCorner(container, Theme.CornerRadiusSmall)
            createStroke(container, Theme.Stroke, 1, 0.7)

            local label = Instance.new("TextLabel")
            label.Text = tbConfig.Name or "Input"
            label.Font = Theme.FontSemibold
            label.TextSize = 13
            label.TextColor3 = Theme.TextPrimary
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 0)
            label.Size = UDim2.new(0.4, 0, 1, 0)
            label.Parent = container

            local textbox = Instance.new("TextBox")
            textbox.PlaceholderText = tbConfig.Placeholder or "Type here..."
            textbox.Text = tbConfig.Default or ""
            textbox.Font = Theme.Font
            textbox.TextSize = 13
            textbox.TextColor3 = Theme.TextPrimary
            textbox.PlaceholderColor3 = Theme.TextMuted
            textbox.TextXAlignment = Enum.TextXAlignment.Right
            textbox.BackgroundColor3 = Theme.BackgroundTertiary
            textbox.BackgroundTransparency = 0.5
            textbox.BorderSizePixel = 0
            textbox.AnchorPoint = Vector2.new(1, 0.5)
            textbox.Position = UDim2.new(1, -8, 0.5, 0)
            textbox.Size = UDim2.new(0.5, -8, 0, 26)
            textbox.ClearTextOnFocus = false
            textbox.Parent = container
            createCorner(textbox, UDim.new(0, 4))

            textbox.FocusLost:Connect(function(enterPressed)
                if enterPressed and tbConfig.Callback then
                    tbConfig.Callback(textbox.Text)
                end
            end)

            return textbox
        end

        -- Dropdown
        function Tab:CreateDropdown(ddConfig)
            local options = ddConfig.Options or {}
            local selected = ddConfig.Default or (options[1] or "")
            local opened = false

            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 38)
            container.BackgroundColor3 = Theme.Surface
            container.BorderSizePixel = 0
            container.ClipsDescendants = true
            container.Parent = page
            createCorner(container, Theme.CornerRadiusSmall)
            createStroke(container, Theme.Stroke, 1, 0.7)

            local label = Instance.new("TextLabel")
            label.Text = ddConfig.Name or "Dropdown"
            label.Font = Theme.FontSemibold
            label.TextSize = 13
            label.TextColor3 = Theme.TextPrimary
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 0)
            label.Size = UDim2.new(0.5, 0, 0, 38)
            label.Parent = container

            local selectedLabel = Instance.new("TextButton")
            selectedLabel.Text = selected .. " ▾"
            selectedLabel.Font = Theme.Font
            selectedLabel.TextSize = 12
            selectedLabel.TextColor3 = Theme.Accent
            selectedLabel.TextXAlignment = Enum.TextXAlignment.Right
            selectedLabel.BackgroundTransparency = 1
            selectedLabel.AnchorPoint = Vector2.new(1, 0)
            selectedLabel.Position = UDim2.new(1, -12, 0, 0)
            selectedLabel.Size = UDim2.new(0.4, 0, 0, 38)
            selectedLabel.Parent = container

            local optionsFrame = Instance.new("Frame")
            optionsFrame.Position = UDim2.new(0, 0, 0, 38)
            optionsFrame.Size = UDim2.new(1, 0, 0, #options * 30)
            optionsFrame.BackgroundTransparency = 1
            optionsFrame.Parent = container

            local optLayout = Instance.new("UIListLayout")
            optLayout.SortOrder = Enum.SortOrder.LayoutOrder
            optLayout.Parent = optionsFrame

            for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Text = opt
                optBtn.Font = Theme.Font
                optBtn.TextSize = 12
                optBtn.TextColor3 = Theme.TextSecondary
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.BackgroundColor3 = Theme.SurfaceHover
                optBtn.BackgroundTransparency = 0.5
                optBtn.BorderSizePixel = 0
                optBtn.Size = UDim2.new(1, 0, 0, 30)
                optBtn.AutoButtonColor = false
                optBtn.Parent = optionsFrame
                createPadding(optBtn, 0, 0, 12, 0)

                optBtn.MouseEnter:Connect(function()
                    tween(optBtn, { BackgroundTransparency = 0.2, TextColor3 = Theme.TextPrimary }, 0.15)
                end)
                optBtn.MouseLeave:Connect(function()
                    tween(optBtn, { BackgroundTransparency = 0.5, TextColor3 = Theme.TextSecondary }, 0.15)
                end)
                optBtn.MouseButton1Click:Connect(function()
                    selected = opt
                    selectedLabel.Text = selected .. " ▾"
                    opened = false
                    tween(container, { Size = UDim2.new(1, 0, 0, 38) }, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                    if ddConfig.Callback then ddConfig.Callback(selected) end
                end)
            end

            selectedLabel.MouseButton1Click:Connect(function()
                opened = not opened
                if opened then
                    tween(container, { Size = UDim2.new(1, 0, 0, 38 + #options * 30) }, 0.3, Enum.EasingStyle.Back)
                else
                    tween(container, { Size = UDim2.new(1, 0, 0, 38) }, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                end
            end)

            local ddObj = {}
            function ddObj:Set(val)
                selected = val
                selectedLabel.Text = selected .. " ▾"
                if ddConfig.Callback then ddConfig.Callback(selected) end
            end
            return ddObj
        end

        -- Separator
        function Tab:CreateSeparator()
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(1, 0, 0, 1)
            sep.BackgroundColor3 = Theme.Stroke
            sep.BackgroundTransparency = 0.5
            sep.BorderSizePixel = 0
            sep.Parent = page
            return sep
        end

        return Tab
    end

        function Window:Destroy()
        tween(main, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.wait(0.4)
        screenGui:Destroy()
    end

    function Window:SetTitle(text)
        titleLabel.Text = text:upper()
    end

    function Window:SetSubtitle(text)
        subtitleLabel.Text = text
    end

    return Window
end

return SubstanceUI
