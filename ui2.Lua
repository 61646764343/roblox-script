local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
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

-- Feather Icons
local Icons = {}

local Success, Response = pcall(function()
    Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)

if not Success then
    warn("\nOrion Library - Failed to load Feather Icons. Error code: " .. Response .. "\n")
end    

local function GetIcon(IconName)
    if Icons[IconName] ~= nil then
        return Icons[IconName]
    else
        return nil
    end
end   

local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
if syn then
    syn.protect_gui(Orion)
    Orion.Parent = game.CoreGui
else
    Orion.Parent = gethui() or game.CoreGui
end

-- Prevent duplicate instances of Orion
if gethui then
    for _, Interface in ipairs(gethui():GetChildren()) do
        if Interface.Name == Orion.Name and Interface ~= Orion then
            Interface:Destroy()
        end
    end
else
    for _, Interface in ipairs(game.CoreGui:GetChildren()) do
        if Interface.Name == Orion.Name and Interface ~= Orion then
            Interface:Destroy()
        end
    end
end

-- Check if Orion is running
function OrionLib:IsRunning()
    if gethui then
        return Orion.Parent == gethui()
    else
        return Orion.Parent == game:GetService("CoreGui")
    end
end

local function AddConnection(Signal, Function)
    if (not OrionLib:IsRunning()) then
        return
    end
    local SignalConnect = Signal:Connect(Function)
    table.insert(OrionLib.Connections, SignalConnect)
    return SignalConnect
end

task.spawn(function()
    while (OrionLib:IsRunning()) do
        task.wait(0.1)  -- Optimized performance by adding wait
    end

    for _, Connection in next, OrionLib.Connections do
        Connection:Disconnect()
    end
end)

-- Make the UI draggable with optimized input handling
local function MakeDraggable(DragPoint, Main)
    pcall(function()
        local Dragging, DragInput, MousePos, FramePos = false
        AddConnection(DragPoint.InputBegan, function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Dragging = true
                MousePos = Input.Position
                FramePos = Main.Position

                Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
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
                Main.Position  = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
            end
        end)
    end)
end    

-- Create and modify UI elements
local function Create(Name, Properties, Children)
    local Object = Instance.new(Name)
    for i, v in next, Properties or {} do
        Object[i] = v
    end
    for i, v in next, Children or {} do
        v.Parent = Object
    end
    return Object
end

-- Create Element Function
local function CreateElement(ElementName, ElementFunction)
    OrionLib.Elements[ElementName] = function(...)
        return ElementFunction(...)
    end
end

-- Make Element function
local function MakeElement(ElementName, ...)
    local NewElement = OrionLib.Elements[ElementName](...)
    return NewElement
end

-- Add padding to ensure spacing between UI elements
CreateElement("Padding", function(Top, Left, Right, Bottom)
    local Padding = Create("UIPadding", {
        PaddingTop = UDim.new(0, Top or 10),
        PaddingLeft = UDim.new(0, Left or 10),
        PaddingRight = UDim.new(0, Right or 10),
        PaddingBottom = UDim.new(0, Bottom or 10)
    })
    return Padding
end)

-- Add button with fixed properties to prevent accidental clicks
CreateElement("Button", function()
    local Button = Create("TextButton", {
        Text = "",
        AutoButtonColor = true,  -- Ensure the button reacts to hover/click
        BackgroundTransparency = 0.5,  -- Semi-transparent for better visibility
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- Set visible button color
    })
    return Button
end)

-- Function to round numbers
local function Round(Number, Factor)
    local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
    if Result < 0 then
        Result = Result + Factor
    end
    return Result
end

-- Optimized notification creation
function OrionLib:MakeNotification(NotificationConfig)
    spawn(function()
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
            MakeElement("Stroke", Color3.fromRGB(93, 93, 93), 1.2),
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

        TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()

        wait(NotificationConfig.Time - 0.88)
        TweenService:Create(NotificationFrame.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
        wait(0.3)
        TweenService:Create(NotificationFrame.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0.9}):Play()
        TweenService:Create(NotificationFrame.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
        TweenService:Create(NotificationFrame.Content, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
        wait(0.05)

        NotificationFrame:TweenPosition(UDim2.new(1, 20, 0, 0), 'In', 'Quint', 0.8, true)
        wait(1.35)
        NotificationFrame:Destroy()
    end)
end    

return OrionLib
