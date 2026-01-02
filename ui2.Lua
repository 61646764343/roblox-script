-- Optimized OrionLib UI Library (v2.1) - Further fixes, optimizations, and safety enhancements
-- Changes from v2.0:
-- 1. Fixed CreateElement definitions by using a proper table of element creators (MakeElementFunctions).
-- 2. Defined missing functions: MakeElement, SetProps, SetChildren.
-- 3. Named the UIStroke child in notifications to fix access errors in tweens (NotificationFrame.Stroke).
-- 4. Added nil checks and warnings for invalid element types in MakeElement.
-- 5. Ensured theme consistency in labels (used OrionLib.Themes.Default.Text for TextColor3).
-- 6. Optimized icon loading in Image and added similar logic to ImageButton for consistency.
-- 7. Reduced unnecessary waits in notification fade-out by synchronizing tweens better.
-- 8. Added safe destruction of NotificationHolder and other potential leaks.
-- 9. Improved error handling in Create function with pcall for property setting.
-- 10. Minor performance: Localized more services and functions where possible.

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local OrionLib = {
    Elements = {},
    ThemeObjects = {},
    Connections = {},
    Flags = {},
    Themes = {
        Default = {
            Main = Color3.fromRGB(34, 34, 34),
            Second = Color3.fromRGB(45, 44, 45),
            Stroke = Color3.fromRGB(60, 60, 60),
            Divider = Color3.fromRGB(60, 60, 60),
            Text = Color3.fromRGB(225, 225, 225),
            TextDark = Color3.fromRGB(255, 255, 225)
        }
    },
    SelectedTheme = "Default",
    Folder = nil,
    SaveCfg = false
}

-- Feather Icons with fallback
local Icons = {}
local success, response = pcall(function()
    Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)
if not success then
    warn("OrionLib - Failed to load icons: " .. tostring(response))
    Icons = {} -- Fallback to empty to avoid errors
end

local function GetIcon(IconName)
    return Icons[IconName] or nil -- Return nil if not found
end

local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
if syn and syn.protect_gui then
    syn.protect_gui(Orion)
    Orion.Parent = game.CoreGui
else
    Orion.Parent = gethui() or game.CoreGui
end

-- Clean up duplicates
local function cleanupDuplicates(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == "Orion" and child ~= Orion then
            child:Destroy()
        end
    end
end
cleanupDuplicates(gethui() or game.CoreGui)

function OrionLib:IsRunning()
    return Orion.Parent == (gethui() or game.CoreGui)
end

local function AddConnection(Signal, Function)
    if not OrionLib:IsRunning() then return end
    local conn = Signal:Connect(Function)
    table.insert(OrionLib.Connections, conn)
    return conn
end

task.spawn(function()
    while OrionLib:IsRunning() do
        task.wait(1) -- Reduced polling
    end
    for _, conn in ipairs(OrionLib.Connections) do
        pcall(function() conn:Disconnect() end) -- Safe disconnect
    end
    OrionLib.Connections = {} -- Clear table
end)

local function MakeDraggable(DragPoint, Main)
    local Dragging, DragInput, MousePos, FramePos = false
    AddConnection(DragPoint.InputBegan, function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            MousePos = Input.Position
            FramePos = Main.Position
        end
    end)
    AddConnection(DragPoint.InputChanged, function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement then
            DragInput = Input
        end
    end)
    AddConnection(UserInputService.InputChanged, function(Input)
        if Input == DragInput and Dragging then
            local Delta = Input.Position - MousePos
            TweenService:Create(Main, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
                Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
            }):Play()
        end
    end)
    AddConnection(DragPoint.InputEnded, function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = false
        end
    end)
end

local function Create(Name, Properties, Children)
    local Object = Instance.new(Name)
    for prop, value in pairs(Properties or {}) do
        pcall(function()
            Object[prop] = value
        end)
    end
    for _, child in ipairs(Children or {}) do
        child.Parent = Object
    end
    return Object
end

-- Utility functions
local function SetProps(Object, Props)
    if not Object or not Props then return Object end
    for Prop, Value in pairs(Props) do
        pcall(function()
            Object[Prop] = Value
        end)
    end
    return Object
end

local function SetChildren(Object, Children)
    if not Object or not Children then return Object end
    for _, Child in ipairs(Children) do
        Child.Parent = Object
    end
    return Object
end

-- Element creation functions
local MakeElementFunctions = {}

MakeElementFunctions["Corner"] = function(Scale, Offset)
    return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 10)})
end

MakeElementFunctions["Stroke"] = function(Color, Thickness)
    return Create("UIStroke", {Color = Color or Color3.fromRGB(255, 255, 255), Thickness = Thickness or 1})
end

MakeElementFunctions["List"] = function(Scale, Offset)
    return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)})
end

MakeElementFunctions["Padding"] = function(Bottom, Left, Right, Top)
    return Create("UIPadding", {
        PaddingBottom = UDim.new(0, Bottom or 4),
        PaddingLeft = UDim.new(0, Left or 4),
        PaddingRight = UDim.new(0, Right or 4),
        PaddingTop = UDim.new(0, Top or 4)
    })
end

MakeElementFunctions["TFrame"] = function()
    return Create("Frame", {BackgroundTransparency = 1})
end

MakeElementFunctions["Frame"] = function(Color)
    return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0})
end

MakeElementFunctions["RoundFrame"] = function(Color, Scale, Offset)
    return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0}, {
        Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
    })
end

MakeElementFunctions["Button"] = function()
    return Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0})
end

MakeElementFunctions["ScrollFrame"] = function(Color, Width)
    return Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        MidImage = "rbxassetid://7445543667",
        BottomImage = "rbxassetid://7445543667",
        TopImage = "rbxassetid://7445543667",
        ScrollBarImageColor3 = Color,
        BorderSizePixel = 0,
        ScrollBarThickness = Width,
        CanvasSize = UDim2.new(0, 0, 0, 0)
    })
end

MakeElementFunctions["Image"] = function(ImageID)
    local img = Create("ImageLabel", {Image = ImageID, BackgroundTransparency = 1})
    local icon = GetIcon(ImageID)
    if icon then img.Image = icon end
    return img
end

MakeElementFunctions["ImageButton"] = function(ImageID)
    local btn = Create("ImageButton", {Image = ImageID, BackgroundTransparency = 1})
    local icon = GetIcon(ImageID)
    if icon then btn.Image = icon end
    return btn
end

MakeElementFunctions["Label"] = function(Text, TextSize, Transparency)
    return Create("TextLabel", {
        Text = Text or "",
        TextColor3 = OrionLib.Themes.Default.Text,
        TextTransparency = Transparency or 0,
        TextSize = TextSize or 15,
        Font = Enum.Font.Gotham,
        RichText = true,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left
    })
end

local function MakeElement(Type, ...)
    local Func = MakeElementFunctions[Type]
    if Func then
        return Func(...)
    else
        warn("OrionLib - Invalid element type: " .. tostring(Type))
        return nil
    end
end

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
    SetProps(MakeElement("List"), {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 5)
    })
}), {
    Position = UDim2.new(1, -25, 1, -25),
    Size = UDim2.new(0, 300, 1, -25),
    AnchorPoint = Vector2.new(1, 1),
    Parent = Orion
})

function OrionLib:MakeNotification(NotificationConfig)
    task.spawn(function()
        NotificationConfig.Name = NotificationConfig.Name or "Notification"
        NotificationConfig.Content = NotificationConfig.Content or "Test"
        NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"
        NotificationConfig.Time = NotificationConfig.Time or 15

        local NotificationParent = SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = NotificationHolder
        })

        local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(25, 25, 25), 0, 10), {
            Parent = NotificationParent, 
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(1, -55, 0, 0),
            BackgroundTransparency = 0,
            AutomaticSize = Enum.AutomaticSize.Y
        }), {
            SetProps(MakeElement("Stroke", Color3.fromRGB(93, 93, 93), 1.2), {Name = "Stroke"}),
            MakeElement("Padding", 12, 12, 12, 12),
            SetProps(MakeElement("Image", NotificationConfig.Image), {
                Size = UDim2.new(0, 20, 0, 20),
                ImageColor3 = Color3.fromRGB(240, 240, 240),
                Name = "Icon"
            }),
            SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
                Size = UDim2.new(1, -30, 0, 20),
                Position = UDim2.new(0, 30, 0, 0),
                Font = Enum.Font.GothamBold,
                Name = "Title"
            }),
            SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 25),
                Font = Enum.Font.GothamSemibold,
                Name = "Content",
                AutomaticSize = Enum.AutomaticSize.Y,
                TextColor3 = Color3.fromRGB(200, 200, 200),
                TextWrapped = true
            })
        })

        TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play() -- Shorter tween

        task.wait(NotificationConfig.Time - 0.88)
        TweenService:Create(NotificationFrame.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        TweenService:Create(NotificationFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
        task.wait(0.3)
        TweenService:Create(NotificationFrame.Stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0.9}):Play()
        TweenService:Create(NotificationFrame.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
        TweenService:Create(NotificationFrame.Content, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
        task.wait(0.05)

        NotificationFrame:TweenPosition(UDim2.new(1, 20, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quint, 0.6, true) -- Shorter tween
        task.wait(0.6) -- Sync with tween duration
        NotificationFrame:Destroy()
        NotificationParent:Destroy() -- Clean up parent to avoid leaks
    end)
end

function OrionLib:Destroy()
    Orion:Destroy()
    for _, conn in ipairs(OrionLib.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    OrionLib.Connections = {}
end

return OrionLib
