-- aimbot_full_v3.lua
-- Мобильный executor. ScreenGui. ESP только игроков.
-- UI: квадратный, неоновое свечение, анимации, кнопки свернуть/закрыть.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ========== КОНФИГ ==========
local Config = {
    Enabled = false,
    TeamCheck = true,
    WallCheck = true,
    KillCheck = true,
    TargetMode = "Players", -- "Players" | "FPV"
    FOV = 250,
    Smoothness = 0.35,
    AimPart = "Head",
}

local ESP = {
    Enabled = false,
    ShowName = true,
    ShowDistance = true,
    ShowHealth = true,
    ShowDrones = true,
}

-- ========== РОДИТЕЛЬ GUI ==========
local parentUI
pcall(function() parentUI = gethui() end)
if not parentUI then parentUI = LP:WaitForChild("PlayerGui") end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimUI_" .. tostring(math.random(1000, 9999))
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentUI

-- ========== FOV КРУГ ==========
local FOVFrame = Instance.new("Frame")
FOVFrame.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
FOVFrame.Position = UDim2.new(0.5, -Config.FOV, 0.5, -Config.FOV)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Parent = ScreenGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVFrame

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Color3.fromRGB(120, 80, 255)
FOVStroke.Thickness = 1.5
FOVStroke.Transparency = 0.5
FOVStroke.Parent = FOVFrame

-- ========== ХЕЛПЕРЫ UI ==========
local C = {
    Accent    = Color3.fromRGB(140, 90, 255),
    Accent2   = Color3.fromRGB(0, 220, 255),
    Bg        = Color3.fromRGB(12, 12, 18),
    Header    = Color3.fromRGB(18, 18, 28),
    BtnOff    = Color3.fromRGB(26, 26, 40),
    BtnHover  = Color3.fromRGB(36, 36, 58),
    BtnOn     = Color3.fromRGB(48, 32, 100),
    StrokeOff = Color3.fromRGB(60, 60, 95),
    Text      = Color3.fromRGB(200, 200, 230),
    Dim       = Color3.fromRGB(70, 70, 100),
    Danger    = Color3.fromRGB(255, 70, 100),
}

local MENU_W, FULL_H, MIN_H = 220, 262, 36

local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local loopTweens = {}
local function loop(obj, time, props, style, reverses)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time, style or Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, reverses or false),
        props
    )
    t:Play()
    table.insert(loopTweens, t)
    return t
end

-- ========== МЕНЮ ==========
-- Holder двигается/сворачивается, свечение и меню следуют за ним
local Holder = Instance.new("Frame")
Holder.Name = "Holder"
Holder.Size = UDim2.new(0, MENU_W, 0, 0) -- растёт в интро
Holder.Position = UDim2.new(0, 20, 0, 100)
Holder.BackgroundTransparency = 1
Holder.Parent = ScreenGui

-- Свечение: квадратные слои-рамки, чем дальше от меню — тем прозрачнее
local glowStrokes = {}
for k = 1, 5 do
    local g = Instance.new("Frame")
    g.Name = "Glow" .. k
    g.Size = UDim2.new(1, k * 4, 1, k * 4)
    g.Position = UDim2.new(0, -k * 2, 0, -k * 2)
    g.BackgroundTransparency = 1
    g.BorderSizePixel = 0
    g.Parent = Holder

    local s = Instance.new("UIStroke")
    s.Color = C.Accent
    s.Thickness = 2
    s.Transparency = 1
    s.Parent = g

    glowStrokes[k] = { stroke = s, base = 0.45 + k * 0.1 }
end

local Menu = Instance.new("Frame")
Menu.Name = "Menu"
Menu.Size = UDim2.new(1, 0, 1, 0)
Menu.BackgroundColor3 = C.Bg
Menu.BorderSizePixel = 0
Menu.Active = true
Menu.ClipsDescendants = true
Menu.Parent = Holder

-- Бегущая градиентная рамка
local MenuStroke = Instance.new("UIStroke")
MenuStroke.Color = Color3.new(1, 1, 1)
MenuStroke.Thickness = 2
MenuStroke.Parent = Menu

local MenuGradient = Instance.new("UIGradient")
MenuGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.Accent),
    ColorSequenceKeypoint.new(0.5, C.Accent2),
    ColorSequenceKeypoint.new(1, C.Accent),
})
MenuGradient.Parent = MenuStroke

-- ===== Шапка =====
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, MIN_H)
Header.BackgroundColor3 = C.Header
Header.BorderSizePixel = 0
Header.Parent = Menu

local Marker = Instance.new("Frame")
Marker.Size = UDim2.new(0, 6, 0, 6)
Marker.AnchorPoint = Vector2.new(0, 0.5)
Marker.Position = UDim2.new(0, 12, 0.5, -1)
Marker.BackgroundColor3 = C.Accent2
Marker.BorderSizePixel = 0
Marker.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.new(0, 26, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "AIM"
Title.TextColor3 = Color3.fromRGB(200, 200, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Бегущий блик под шапкой
local Line = Instance.new("Frame")
Line.Size = UDim2.new(1, 0, 0, 2)
Line.Position = UDim2.new(0, 0, 1, -2)
Line.BackgroundColor3 = Color3.new(1, 1, 1)
Line.BorderSizePixel = 0
Line.Parent = Header

local LineGrad = Instance.new("UIGradient")
LineGrad.Color = ColorSequence.new(C.Accent, C.Accent2)
LineGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 1),
})
LineGrad.Offset = Vector2.new(-1, 0)
LineGrad.Parent = Line

-- Квадратные кнопки шапки
local function makeHeaderBtn(xFromRight)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -xFromRight, 0.5, -1)
    b.BackgroundColor3 = C.BtnOff
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = Header

    local s = Instance.new("UIStroke")
    s.Color = C.StrokeOff
    s.Thickness = 1
    s.Parent = b
    return b, s
end

local function makeBar(parent, w, h, rot)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(0, w, 0, h)
    f.Rotation = rot
    f.BackgroundColor3 = C.Text
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

local CloseBtn, CloseStroke = makeHeaderBtn(4)
local MinBtn, MinStroke = makeHeaderBtn(36)

local CloseA = makeBar(CloseBtn, 14, 2, 45)
local CloseB = makeBar(CloseBtn, 14, 2, -45)

-- Иконка "свернуть": линия, при сворачивании превращается в квадрат
local MinIcon = makeBar(MinBtn, 12, 2, 0)
local MinIconStroke = Instance.new("UIStroke")
MinIconStroke.Color = C.Text
MinIconStroke.Thickness = 2
MinIconStroke.Transparency = 1
MinIconStroke.Parent = MinIcon

local function hoverHeaderBtn(btn, stroke, bars, hoverColor, extraStroke)
    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = C.BtnHover })
        tween(stroke, 0.15, { Color = hoverColor })
        for _, bar in ipairs(bars) do tween(bar, 0.15, { BackgroundColor3 = hoverColor }) end
        if extraStroke then tween(extraStroke, 0.15, { Color = hoverColor }) end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = C.BtnOff })
        tween(stroke, 0.15, { Color = C.StrokeOff })
        for _, bar in ipairs(bars) do tween(bar, 0.15, { BackgroundColor3 = C.Text }) end
        if extraStroke then tween(extraStroke, 0.15, { Color = C.Text }) end
    end)
end
hoverHeaderBtn(MinBtn, MinStroke, { MinIcon }, C.Accent2, MinIconStroke)
hoverHeaderBtn(CloseBtn, CloseStroke, { CloseA, CloseB }, C.Danger)

-- ===== Тело меню =====
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, 0, 0, FULL_H - MIN_H)
Body.Position = UDim2.new(0, 0, 0, MIN_H)
Body.BackgroundTransparency = 1
Body.Parent = Menu

local items = {}

-- Квадратная кнопка с индикатором, ховером и анимацией нажатия
local function makeButton(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -24, 0, 32)
    b.Position = UDim2.new(0, 12, 0, y)
    b.BackgroundColor3 = C.BtnOff
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = C.Text
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = Body

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.Parent = b

    local stroke = Instance.new("UIStroke")
    stroke.Color = C.StrokeOff
    stroke.Thickness = 1
    stroke.Parent = b

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.AnchorPoint = Vector2.new(1, 0.5)
    dot.Position = UDim2.new(1, -10, 0.5, 0)
    dot.BackgroundColor3 = C.Dim
    dot.BorderSizePixel = 0
    dot.Parent = b

    local dotGlow = Instance.new("UIStroke")
    dotGlow.Color = C.Accent2
    dotGlow.Thickness = 3
    dotGlow.Transparency = 1
    dotGlow.Parent = dot

    local state = { on = false, hover = false }

    local function refresh()
        local active = state.on or state.hover
        tween(b, 0.2, { BackgroundColor3 = state.on and C.BtnOn or (state.hover and C.BtnHover or C.BtnOff) })
        tween(stroke, 0.2, { Color = active and C.Accent or C.StrokeOff })
        tween(dot, 0.2, { BackgroundColor3 = state.on and C.Accent2 or C.Dim })
        tween(dotGlow, 0.2, { Transparency = state.on and 0.55 or 1 })
    end

    b.MouseEnter:Connect(function()
        state.hover = true
        refresh()
    end)

    local function release()
        tween(b, 0.18, {
            Size = UDim2.new(1, -24, 0, 32),
            Position = UDim2.new(0, 12, 0, y),
        }, Enum.EasingStyle.Back)
    end

    b.MouseLeave:Connect(function()
        state.hover = false
        refresh()
        release()
    end)
    b.MouseButton1Down:Connect(function()
        tween(b, 0.08, {
            Size = UDim2.new(1, -28, 0, 28),
            Position = UDim2.new(0, 14, 0, y + 2),
        })
    end)
    b.MouseButton1Up:Connect(release)

    table.insert(items, { btn = b, y = y, stroke = stroke, dot = dot })

    return b, function(on)
        state.on = on
        refresh()
    end
end

local ModeBtn, setMode = makeButton("Target: Players", 12)
local ToggleBtn, setToggle = makeButton("Aimbot: OFF", 52)
local WallBtn, setWall = makeButton("Wall Check: ON", 92)
local ESPBtn, setESP = makeButton("ESP: OFF", 132)

-- ========== DRAG ==========
local conns = {}
local dragging = false
local dragStart, startPos

table.insert(conns, Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Holder.Position
    end
end))

table.insert(conns, UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Holder.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

table.insert(conns, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

-- ========== FOV ПОЛЗУНОК ==========
local FOV_MIN, FOV_MAX = 30, 500
local fovPreview = false   -- пока тянем ползунок, круг FOV виден даже при выключенном аимботе
local sliderActive = false
local sliderInput

local SliderRow = Instance.new("CanvasGroup")
SliderRow.Name = "FOVSlider"
SliderRow.Size = UDim2.new(1, -24, 0, 42)
SliderRow.Position = UDim2.new(0, 12, 0, 172)
SliderRow.BackgroundTransparency = 1
SliderRow.BorderSizePixel = 0
SliderRow.Parent = Body

local FOVLabel = Instance.new("TextLabel")
FOVLabel.Size = UDim2.new(0.5, 0, 0, 14)
FOVLabel.BackgroundTransparency = 1
FOVLabel.Text = "FOV"
FOVLabel.TextColor3 = C.Text
FOVLabel.TextSize = 12
FOVLabel.Font = Enum.Font.Gotham
FOVLabel.TextXAlignment = Enum.TextXAlignment.Left
FOVLabel.Parent = SliderRow

local FOVValue = Instance.new("TextLabel")
FOVValue.Size = UDim2.new(0.5, 0, 0, 14)
FOVValue.Position = UDim2.new(0.5, 0, 0, 0)
FOVValue.BackgroundTransparency = 1
FOVValue.Text = tostring(Config.FOV)
FOVValue.TextColor3 = C.Accent2
FOVValue.TextSize = 12
FOVValue.Font = Enum.Font.GothamBold
FOVValue.TextXAlignment = Enum.TextXAlignment.Right
FOVValue.Parent = SliderRow

-- большая невидимая зона нажатия (удобно пальцем)
local SliderHit = Instance.new("TextButton")
SliderHit.Size = UDim2.new(1, 0, 0, 24)
SliderHit.Position = UDim2.new(0, 0, 0, 18)
SliderHit.BackgroundTransparency = 1
SliderHit.AutoButtonColor = false
SliderHit.Text = ""
SliderHit.Parent = SliderRow

local SliderBar = Instance.new("Frame")
SliderBar.Position = UDim2.new(0, 6, 0.5, -3)
SliderBar.Size = UDim2.new(1, -12, 0, 6)
SliderBar.BackgroundColor3 = C.BtnOff
SliderBar.BorderSizePixel = 0
SliderBar.Parent = SliderHit

local SliderBarStroke = Instance.new("UIStroke")
SliderBarStroke.Color = C.StrokeOff
SliderBarStroke.Thickness = 1
SliderBarStroke.Parent = SliderBar

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.new(1, 1, 1)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBar

local SliderFillGrad = Instance.new("UIGradient")
SliderFillGrad.Color = ColorSequence.new(C.Accent, C.Accent2)
SliderFillGrad.Parent = SliderFill

local SliderHandle = Instance.new("Frame")
SliderHandle.Size = UDim2.new(0, 10, 0, 18)
SliderHandle.AnchorPoint = Vector2.new(0.5, 0.5)
SliderHandle.Position = UDim2.new(0, 0, 0.5, 0)
SliderHandle.BackgroundColor3 = C.Text
SliderHandle.BorderSizePixel = 0
SliderHandle.ZIndex = 2
SliderHandle.Parent = SliderBar

local HandleStroke = Instance.new("UIStroke")
HandleStroke.Color = C.Accent2
HandleStroke.Thickness = 2
HandleStroke.Transparency = 0.7
HandleStroke.Parent = SliderHandle

local function setFOV(value)
    value = math.clamp(math.floor(value + 0.5), FOV_MIN, FOV_MAX)
    Config.FOV = value
    local a = (value - FOV_MIN) / (FOV_MAX - FOV_MIN)
    SliderFill.Size = UDim2.new(a, 0, 1, 0)
    SliderHandle.Position = UDim2.new(a, 0, 0.5, 0)
    FOVValue.Text = tostring(value)
end

local function setFOVFromX(x)
    local w = SliderBar.AbsoluteSize.X
    if w <= 0 then return end
    local a = math.clamp((x - SliderBar.AbsolutePosition.X) / w, 0, 1)
    setFOV(FOV_MIN + a * (FOV_MAX - FOV_MIN))
end

local function setSliderActive(on)
    sliderActive = on
    fovPreview = on
    tween(SliderHandle, 0.12, { Size = on and UDim2.new(0, 12, 0, 22) or UDim2.new(0, 10, 0, 18) })
    tween(HandleStroke, 0.12, { Transparency = on and 0.2 or 0.7 })
    tween(SliderBarStroke, 0.12, { Color = on and C.Accent or C.StrokeOff })
end

setFOV(Config.FOV)

table.insert(conns, SliderHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        sliderInput = input
        setSliderActive(true)
        setFOVFromX(input.Position.X)
    end
end))

table.insert(conns, UserInputService.InputChanged:Connect(function(input)
    if sliderActive and (input.UserInputType == Enum.UserInputType.MouseMovement
       or (input.UserInputType == Enum.UserInputType.Touch and input == sliderInput)) then
        setFOVFromX(input.Position.X)
    end
end))

table.insert(conns, UserInputService.InputEnded:Connect(function(input)
    if sliderActive and (input.UserInputType == Enum.UserInputType.MouseButton1
       or input == sliderInput) then
        setSliderActive(false)
    end
end))

-- ========== КНОПКИ ==========
ToggleBtn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    ToggleBtn.Text = "Aimbot: " .. (Config.Enabled and "ON" or "OFF")
    setToggle(Config.Enabled)
end)

WallBtn.MouseButton1Click:Connect(function()
    Config.WallCheck = not Config.WallCheck
    WallBtn.Text = "Wall Check: " .. (Config.WallCheck and "ON" or "OFF")
    setWall(Config.WallCheck)
end)

ModeBtn.MouseButton1Click:Connect(function()
    if Config.TargetMode == "Players" then
        Config.TargetMode = "FPV"
        ModeBtn.Text = "Target: FPV Drones"
    else
        Config.TargetMode = "Players"
        ModeBtn.Text = "Target: Players"
    end
    setMode(Config.TargetMode == "FPV")
end)

-- ========== АНИМАЦИИ: ИНТРО + ЦИКЛЫ ==========
setWall(Config.WallCheck)

-- кнопки стартуют прозрачными и сдвинутыми
for _, it in ipairs(items) do
    it.btn.BackgroundTransparency = 1
    it.btn.TextTransparency = 1
    it.btn.Position = UDim2.new(0, -14, 0, it.y)
    it.stroke.Transparency = 1
    it.dot.BackgroundTransparency = 1
end

-- меню "вырастает" вниз
tween(Holder, 0.5, { Size = UDim2.new(0, MENU_W, 0, FULL_H) }, Enum.EasingStyle.Back)

-- свечение загорается слоями
for k, g in ipairs(glowStrokes) do
    task.delay(0.15 + k * 0.06, function()
        tween(g.stroke, 0.4, { Transparency = g.base })
    end)
end

-- кнопки выезжают по очереди
for i, it in ipairs(items) do
    task.delay(0.25 + i * 0.08, function()
        tween(it.btn, 0.35, {
            BackgroundTransparency = 0,
            TextTransparency = 0,
            Position = UDim2.new(0, 12, 0, it.y),
        }, Enum.EasingStyle.Quint)
        tween(it.stroke, 0.35, { Transparency = 0 })
        tween(it.dot, 0.35, { BackgroundTransparency = 0 })
    end)
end

-- ползунок FOV появляется после кнопок
SliderRow.GroupTransparency = 1
SliderRow.Position = UDim2.new(0, -14, 0, 172)
task.delay(0.25 + (#items + 1) * 0.08, function()
    tween(SliderRow, 0.35, {
        GroupTransparency = 0,
        Position = UDim2.new(0, 12, 0, 172),
    }, Enum.EasingStyle.Quint)
end)

-- бесконечные анимации стартуют после интро
task.delay(1.1, function()
    loop(MenuGradient, 4, { Rotation = 360 })
    loop(LineGrad, 1.8, { Offset = Vector2.new(1, 0) })
    loop(Marker, 0.9, { BackgroundTransparency = 0.7 }, Enum.EasingStyle.Sine, true)
    for k, g in ipairs(glowStrokes) do
        loop(g.stroke, 1.4 + k * 0.15, { Transparency = math.min(1, g.base + 0.2) }, Enum.EasingStyle.Sine, true)
        loop(g.stroke, 3, { Color = C.Accent2 }, Enum.EasingStyle.Sine, true)
    end
end)

-- ========== KILL CHECK ==========
local function isAlive(character)
    if not character then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

-- ========== WALL CHECK ==========
local function hasLineOfSight(targetPart, targetCharacter)
    if not Config.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(
        Camera.CFrame.Position,
        targetPart.Position - Camera.CFrame.Position,
        params
    )
    if not result then return true end
    return result.Instance:IsDescendantOf(targetCharacter)
end

-- ========== ЦЕЛИ: ИГРОКИ ==========
local function getPlayerTarget()
    local closest, dist = nil, Config.FOV
    local center = Camera.ViewportSize / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            if Config.KillCheck and not isAlive(plr.Character) then
                -- мёртв
            else
                if Config.TeamCheck and plr.Team ~= nil and plr.Team == LP.Team then
                    -- свой
                else
                    local part = plr.Character:FindFirstChild(Config.AimPart)
                    if not part then part = plr.Character:FindFirstChild("HumanoidRootPart") end
                    if not part then part = plr.Character:FindFirstChild("Head") end
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen and screenPos.Z > 0 then
                            local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if d < dist and hasLineOfSight(part, plr.Character) then
                                closest, dist = part, d
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ========== ЦЕЛИ: ДРОНЫ ==========
local function getFPVTarget()
    local closest, dist = nil, Config.FOV
    local center = Camera.ViewportSize / 2

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("fpv") or name:find("drone") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if Config.KillCheck and hum and hum.Health <= 0 then
                    -- уничтожен
                else
                    local part = obj:FindFirstChild("HumanoidRootPart")
                        or obj:FindFirstChild("Head")
                        or obj.PrimaryPart
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen and screenPos.Z > 0 then
                            local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if d < dist and hasLineOfSight(part, obj) then
                                closest, dist = part, d
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ========== ESP GUI ==========
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "ESP_" .. tostring(math.random(1000, 9999))
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 998
ESPGui.Parent = parentUI

local espCache = {}

-- ========== ESP: ПОДСВЕТКА ИГРОКОВ ==========
local ESP_ENEMY_COLOR = Color3.fromRGB(150, 100, 255)
local ESP_TEAM_COLOR  = Color3.fromRGB(80, 220, 120)

local function getESPColor(plr)
    if plr.Team ~= nil and plr.Team == LP.Team then
        return ESP_TEAM_COLOR
    end
    return ESP_ENEMY_COLOR
end

local function createESP(character, adornee, color, labelText)
    local entry = { adornee = adornee, color = color }

    -- Контур + заливка всего тела, видно сквозь стены
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_HL"
    hl.Adornee = character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 1
    hl.OutlineTransparency = 1
    hl.Parent = ESPGui
    TweenService:Create(hl, TweenInfo.new(0.35), {
        FillTransparency = 0.7,
        OutlineTransparency = 0,
    }):Play()
    entry.highlight = hl

    -- Инфо над головой: имя, дистанция, здоровье
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Info"
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 120, 0, 44)
    bb.StudsOffset = Vector3.new(0, 2.6, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1000
    bb.Parent = ESPGui
    entry.billboard = bb

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = labelText
    nameLabel.TextColor3 = color
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = bb
    entry.nameLabel = nameLabel

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = ""
    distLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    distLabel.TextSize = 11
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = bb
    entry.distLabel = distLabel

    local healthBg = Instance.new("Frame")
    healthBg.AnchorPoint = Vector2.new(0.5, 0)
    healthBg.Position = UDim2.new(0.5, 0, 0, 34)
    healthBg.Size = UDim2.new(0, 70, 0, 5)
    healthBg.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    healthBg.BorderSizePixel = 0
    healthBg.Parent = bb
    entry.healthBg = healthBg

    local healthStroke = Instance.new("UIStroke")
    healthStroke.Color = Color3.fromRGB(0, 0, 0)
    healthStroke.Thickness = 1
    healthStroke.Parent = healthBg

    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg
    entry.healthFill = healthFill

    return entry
end

local function destroyESP(entry)
    if entry.highlight then entry.highlight:Destroy() end
    if entry.billboard then entry.billboard:Destroy() end
end

-- ========== ESP: ДРОНЫ ==========
local ESP_DRONE_COLOR = Color3.fromRGB(0, 220, 255)

local function isDroneName(name)
    name = name:lower()
    return name:find("fpv") ~= nil or name:find("drone") ~= nil
end

-- Принимает Model или любой объект внутри дрона (в том числе BasePart).
-- Если имя самого объекта не подходит, проверяется родитель (obj.Parent) и выше до Workspace.
-- Возвращает модель дрона или nil.
local function isDrone(obj)
    local cur = obj
    while cur and cur ~= Workspace do
        if cur:IsA("Model") and isDroneName(cur.Name) then
            return cur
        end
        cur = cur.Parent
    end
    return nil
end

local function getDronePart(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function refreshDroneESP(seen)
    for _, obj in ipairs(Workspace:GetChildren()) do
        local model = isDrone(obj)
        -- персонажей игроков пропускаем (ник может содержать "drone")
        if model and not Players:GetPlayerFromCharacter(model) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not (hum and hum.Health <= 0) then
                local adornee = getDronePart(model)
                if adornee then
                    seen[model] = true

                    local entry = espCache[model]
                    if entry and entry.adornee ~= adornee then
                        destroyESP(entry)
                        entry = nil
                    end
                    if not entry then
                        entry = createESP(model, adornee, ESP_DRONE_COLOR, model.Name)
                        espCache[model] = entry
                    end

                    entry.nameLabel.Text = ESP.ShowName and model.Name or ""

                    local dist = (Camera.CFrame.Position - adornee.Position).Magnitude
                    entry.distLabel.Text = ESP.ShowDistance and (math.floor(dist) .. "m") or ""

                    -- полоска здоровья только если у дрона есть Humanoid
                    entry.healthBg.Visible = ESP.ShowHealth and hum ~= nil
                    if hum then
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        entry.healthFill.Size = UDim2.new(ratio, 0, 1, 0)
                        entry.healthFill.BackgroundColor3 =
                            Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 220, 120), ratio)
                    end
                end
            end
        end
    end
end

-- ========== ESP ИГРОКИ (тик 0.1с) ==========
local playerTick = 0
local function refreshPlayerESP(dt)
    playerTick = playerTick + dt
    if playerTick < 0.1 then return end
    playerTick = 0

    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        if plr ~= LP and character then
            local hum = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            if hum and hum.Health > 0 and hrp then
                local adornee = head or hrp
                seen[character] = true

                local entry = espCache[character]
                if entry and entry.adornee ~= adornee then
                    destroyESP(entry)
                    entry = nil
                end
                if not entry then
                    entry = createESP(character, adornee, getESPColor(plr), plr.Name)
                    espCache[character] = entry
                end

                -- цвет может поменяться вместе с командой
                local color = getESPColor(plr)
                if entry.color ~= color then
                    entry.color = color
                    entry.highlight.FillColor = color
                    entry.highlight.OutlineColor = color
                    entry.nameLabel.TextColor3 = color
                end

                entry.nameLabel.Text = ESP.ShowName and plr.Name or ""

                local dist = (Camera.CFrame.Position - adornee.Position).Magnitude
                entry.distLabel.Text = ESP.ShowDistance and (math.floor(dist) .. "m") or ""

                entry.healthBg.Visible = ESP.ShowHealth
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                entry.healthFill.Size = UDim2.new(ratio, 0, 1, 0)
                entry.healthFill.BackgroundColor3 =
                    Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 220, 120), ratio)
            end
        end
    end

    if ESP.ShowDrones then
        refreshDroneESP(seen)
    end

    -- убрать подсветку у тех, кто умер, вышел или сменил персонажа
    for character, entry in pairs(espCache) do
        if not seen[character] then
            destroyESP(entry)
            espCache[character] = nil
        end
    end
end

ESPBtn.MouseButton1Click:Connect(function()
    ESP.Enabled = not ESP.Enabled
    ESPBtn.Text = "ESP: " .. (ESP.Enabled and "ON" or "OFF")
    setESP(ESP.Enabled)
    if not ESP.Enabled then
        for _, entry in pairs(espCache) do
            destroyESP(entry)
        end
        espCache = {}
    end
end)

-- ========== ОСНОВНОЙ ЦИКЛ ==========
local MainConn = RunService.RenderStepped:Connect(function(dt)
    FOVFrame.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
    FOVFrame.Position = UDim2.new(0.5, -Config.FOV, 0.5, -Config.FOV)
    FOVFrame.Visible = Config.Enabled or fovPreview

    if ESP.Enabled then
        refreshPlayerESP(dt)
    end

    if not Config.Enabled then return end
    if not Camera then return end

    local target
    if Config.TargetMode == "FPV" then
        target = getFPVTarget()
    else
        target = getPlayerTarget()
    end

    if not target then
        FOVStroke.Color = Color3.fromRGB(120, 80, 255)
        return
    end

    FOVStroke.Color = Color3.fromRGB(255, 80, 120)

    local current = Camera.CFrame
    local desired = CFrame.new(current.Position, target.Position)
    local alpha = math.clamp(Config.Smoothness * (dt * 60), 0.01, 1)
    Camera.CFrame = current:Lerp(desired, alpha)
end)

-- ========== СВЕРНУТЬ / ЗАКРЫТЬ ==========
local closing = false
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    if closing then return end
    minimized = not minimized
    tween(Holder, 0.35, {
        Size = UDim2.new(0, MENU_W, 0, minimized and MIN_H or FULL_H),
    }, Enum.EasingStyle.Quint)
    -- линия превращается в квадрат (и обратно)
    tween(MinIcon, 0.25, {
        Size = minimized and UDim2.new(0, 8, 0, 8) or UDim2.new(0, 12, 0, 2),
        BackgroundTransparency = minimized and 1 or 0,
    })
    tween(MinIconStroke, 0.25, { Transparency = minimized and 0 or 1 })
end)

CloseBtn.MouseButton1Click:Connect(function()
    if closing then return end
    closing = true

    -- полная остановка: выключаем функции, отключаем циклы и события
    Config.Enabled = false
    ESP.Enabled = false
    FOVFrame.Visible = false
    if MainConn then MainConn:Disconnect() end
    for _, c in ipairs(conns) do c:Disconnect() end
    for _, t in ipairs(loopTweens) do t:Cancel() end

    -- анимация закрытия: крестик крутится, свечение гаснет, меню схлопывается
    tween(CloseA, 0.3, { Rotation = 135 })
    tween(CloseB, 0.3, { Rotation = 45 })
    tween(MenuStroke, 0.25, { Transparency = 1 })
    for _, g in ipairs(glowStrokes) do
        tween(g.stroke, 0.25, { Transparency = 1 })
    end
    local closeTween = tween(Holder, 0.3, {
        Size = UDim2.new(0, MENU_W, 0, 0),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    closeTween.Completed:Wait()

    ESPGui:Destroy()
    ScreenGui:Destroy()
end)
