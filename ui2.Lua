-- Orion Library - 优化版本
-- 修复了多个bug并进行了性能优化

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
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

-- 安全检查
if not LocalPlayer then
    warn("Orion Library: 无法获取本地玩家，请在游戏中运行")
    return OrionLib
end

-- Feather Icons - 添加错误处理
local Icons = {}
local IconsLoaded = false

local function LoadIcons()
    local Success, Response = pcall(function()
        Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
        IconsLoaded = true
    end)
    
    if not Success then
        warn("Orion Library - 无法加载Feather图标，使用备用方案。错误: " .. Response)
        -- 使用内置图标作为备用
        Icons = {
            ["search"] = "rbxassetid://7072720870",
            ["settings"] = "rbxassetid://7072719338",
            ["x"] = "rbxassetid://7072725342",
            ["check"] = "rbxassetid://3944680095"
        }
    end
end

task.spawn(LoadIcons)

local function GetIcon(IconName)
    if not IconsLoaded then
        return nil
    end
    
    if Icons[IconName] ~= nil then
        return Icons[IconName]
    else
        return nil
    end
end

-- 创建主界面
local Orion = Instance.new("ScreenGui")
Orion.Name = "OrionLib_" .. HttpService:GenerateGUID(false):sub(1, 8)
Orion.ResetOnSpawn = false
Orion.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- GUI保护
local function ProtectGUI(gui)
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
        gui.Parent = game:GetService("CoreGui")
    elseif gethui then
        gui.Parent = gethui()
    else
        gui.Parent = game:GetService("CoreGui")
    end
end

ProtectGUI(Orion)

-- 清理重复的UI
local function CleanupDuplicateUI()
    local coreGui = game:GetService("CoreGui")
    for _, gui in ipairs(coreGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name:match("^OrionLib_") and gui ~= Orion then
            gui:Destroy()
        end
    end
end

CleanupDuplicateUI()

function OrionLib:IsRunning()
    return Orion and Orion.Parent ~= nil
end

-- 连接管理
local function AddConnection(Signal, Function)
    if not OrionLib:IsRunning() then
        return nil
    end
    
    local SignalConnect = Signal:Connect(Function)
    table.insert(OrionLib.Connections, SignalConnect)
    return SignalConnect
end

task.spawn(function()
    while OrionLib:IsRunning() do
        task.wait()
    end
    
    for _, Connection in ipairs(OrionLib.Connections) do
        if Connection.Connected then
            Connection:Disconnect()
        end
    end
    OrionLib.Connections = {}
end)

-- 拖拽功能
local function MakeDraggable(DragPoint, Main)
    local Dragging, DragInput, MousePos, FramePos = false
    
    local function UpdatePosition()
        if Dragging and DragInput then
            local Delta = DragInput.Position - MousePos
            Main.Position = UDim2.new(
                FramePos.X.Scale, 
                FramePos.X.Offset + Delta.X,
                FramePos.Y.Scale, 
                FramePos.Y.Offset + Delta.Y
            )
        end
    end
    
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
            UpdatePosition()
        end
    end)
end

-- 辅助函数
local function Create(Name, Properties, Children)
    local Object = Instance.new(Name)
    
    if Properties then
        for i, v in pairs(Properties) do
            Object[i] = v
        end
    end
    
    if Children then
        for i, v in ipairs(Children) do
            v.Parent = Object
        end
    end
    
    return Object
end

local function CreateElement(ElementName, ElementFunction)
    OrionLib.Elements[ElementName] = function(...)
        return ElementFunction(...)
    end
end

local function MakeElement(ElementName, ...)
    local elementFunc = OrionLib.Elements[ElementName]
    if elementFunc then
        return elementFunc(...)
    else
        warn("Orion Library: 未知元素类型: " .. tostring(ElementName))
        return nil
    end
end

local function SetProps(Element, Props)
    if Element and Props then
        for Property, Value in pairs(Props) do
            Element[Property] = Value
        end
    end
    return Element
end

local function SetChildren(Element, Children)
    if Element and Children then
        for _, Child in ipairs(Children) do
            Child.Parent = Element
        end
    end
    return Element
end

local function Round(Number, Factor)
    if Factor <= 0 then return Number end
    local Result = math.floor(Number / Factor + 0.5) * Factor
    return Result
end

local function ReturnProperty(Object)
    if Object:IsA("Frame") or Object:IsA("TextButton") then
        return "BackgroundColor3"
    elseif Object:IsA("ScrollingFrame") then
        return "ScrollBarImageColor3"
    elseif Object:IsA("UIStroke") then
        return "Color"
    elseif Object:IsA("TextLabel") or Object:IsA("TextBox") then
        return "TextColor3"
    elseif Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
        return "ImageColor3"
    end
    return nil
end

-- 主题管理
local function AddThemeObject(Object, Type)
    if not Object then return Object end
    
    local prop = ReturnProperty(Object)
    if not prop then return Object end
    
    if not OrionLib.ThemeObjects[Type] then
        OrionLib.ThemeObjects[Type] = {}
    end
    
    table.insert(OrionLib.ThemeObjects[Type], Object)
    
    if OrionLib.Themes[OrionLib.SelectedTheme] and OrionLib.Themes[OrionLib.SelectedTheme][Type] then
        Object[prop] = OrionLib.Themes[OrionLib.SelectedTheme][Type]
    end
    
    return Object
end

local function SetTheme()
    for Name, Objects in pairs(OrionLib.ThemeObjects) do
        for _, Object in ipairs(Objects) do
            local prop = ReturnProperty(Object)
            if prop and OrionLib.Themes[OrionLib.SelectedTheme] and OrionLib.Themes[OrionLib.SelectedTheme][Name] then
                Object[prop] = OrionLib.Themes[OrionLib.SelectedTheme][Name]
            end
        end
    end
end

-- 配置管理
local function PackColor(Color)
    if not Color then return {R = 255, G = 255, B = 255} end
    return {
        R = math.floor(Color.R * 255),
        G = math.floor(Color.G * 255),
        B = math.floor(Color.B * 255)
    }
end

local function UnpackColor(Color)
    if not Color then return Color3.new(1, 1, 1) end
    return Color3.fromRGB(Color.R or 255, Color.G or 255, Color.B or 255)
end

local function LoadCfg(Config)
    local success, data = pcall(function()
        return HttpService:JSONDecode(Config)
    end)
    
    if not success or not data then return end
    
    for key, value in pairs(data) do
        if OrionLib.Flags[key] then
            task.spawn(function()
                if OrionLib.Flags[key].Type == "Colorpicker" then
                    OrionLib.Flags[key]:Set(UnpackColor(value))
                else
                    OrionLib.Flags[key]:Set(value)
                end
            end)
        end
    end
end

local function SaveCfg(Name)
    if not OrionLib.SaveCfg or not OrionLib.Folder or not writefile then return end
    
    local Data = {}
    for key, value in pairs(OrionLib.Flags) do
        if value.Save then
            if value.Type == "Colorpicker" then
                Data[key] = PackColor(value.Value)
            else
                Data[key] = value.Value
            end
        end
    end
    
    local success, result = pcall(function()
        local fileName = OrionLib.Folder .. "/" .. (Name or "config") .. ".json"
        writefile(fileName, HttpService:JSONEncode(Data))
    end)
    
    if not success then
        warn("Orion Library: 保存配置失败", result)
    end
end

-- 输入检查
local WhitelistedMouse = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3
}

local BlacklistedKeys = {
    Enum.KeyCode.Unknown,
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.Up,
    Enum.KeyCode.Left,
    Enum.KeyCode.Down,
    Enum.KeyCode.Right,
    Enum.KeyCode.Slash,
    Enum.KeyCode.Tab,
    Enum.KeyCode.Backspace,
    Enum.KeyCode.Escape
}

local function CheckKey(Table, Key)
    for _, v in ipairs(Table) do
        if v == Key then
            return true
        end
    end
    return false
end

-- 基础元素
CreateElement("Corner", function(Scale, Offset)
    return Create("UICorner", {
        CornerRadius = UDim.new(Scale or 0, Offset or 8)
    })
end)

CreateElement("Stroke", function(Color, Thickness)
    return Create("UIStroke", {
        Color = Color or Color3.fromRGB(255, 255, 255),
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
end)

CreateElement("List", function(Scale, Offset)
    return Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(Scale or 0, Offset or 4)
    })
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
    return Create("UIPadding", {
        PaddingBottom = UDim.new(0, Bottom or 4),
        PaddingLeft = UDim.new(0, Left or 4),
        PaddingRight = UDim.new(0, Right or 4),
        PaddingTop = UDim.new(0, Top or 4)
    })
end)

CreateElement("TFrame", function()
    return Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    })
end)

CreateElement("Frame", function(Color)
    return Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    })
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
    return SetChildren(Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    }), {
        MakeElement("Corner", Scale, Offset)
    })
end)

CreateElement("Button", function()
    return Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextTransparency = 1
    })
end)

CreateElement("ScrollFrame", function(Color, Width)
    return Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color or Color3.fromRGB(255, 255, 255),
        ScrollBarThickness = Width or 4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollingDirection = Enum.ScrollingDirection.Y
    })
end)

CreateElement("Image", function(ImageID)
    local image = Create("ImageLabel", {
        Image = ImageID or "",
        BackgroundTransparency = 1
    })
    
    local icon = GetIcon(ImageID)
    if icon then
        image.Image = icon
    end
    
    return image
end)

CreateElement("ImageButton", function(ImageID)
    local image = Create("ImageButton", {
        Image = ImageID or "",
        BackgroundTransparency = 1,
        AutoButtonColor = false
    })
    
    local icon = GetIcon(ImageID)
    if icon then
        image.Image = icon
    end
    
    return image
end)

CreateElement("Label", function(Text, TextSize, Transparency)
    return Create("TextLabel", {
        Text = Text or "",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextTransparency = Transparency or 0,
        TextSize = TextSize or 14,
        Font = Enum.Font.Gotham,
        RichText = true,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true
    })
end)

-- 通知系统
local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
    SetProps(MakeElement("List"), {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 8)
    })
}), {
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.new(0, 300, 1, -40),
    AnchorPoint = Vector2.new(1, 1),
    Parent = Orion
})

function OrionLib:MakeNotification(NotificationConfig)
    NotificationConfig = NotificationConfig or {}
    
    task.spawn(function()
        NotificationConfig.Name = NotificationConfig.Name or "通知"
        NotificationConfig.Content = NotificationConfig.Content or "内容"
        NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"
        NotificationConfig.Time = NotificationConfig.Time or 5
        
        local NotificationParent = SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = NotificationHolder
        })
        
        local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(25, 25, 25), 0, 8), {
            Parent = NotificationParent,
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(1, 10, 0, 0),
            BackgroundTransparency = 0,
            AutomaticSize = Enum.AutomaticSize.Y
        }), {
            MakeElement("Stroke", Color3.fromRGB(93, 93, 93), 1),
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
        
        -- 进入动画
        TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        
        -- 等待时间
        task.wait(NotificationConfig.Time)
        
        -- 离开动画
        TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(1, 10, 0, 0)
        }):Play()
        
        task.wait(0.3)
        NotificationParent:Destroy()
    end)
end

-- 窗口系统
function OrionLib:MakeWindow(WindowConfig)
    WindowConfig = WindowConfig or {}
    WindowConfig.Name = WindowConfig.Name or "Orion Library"
    WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or "OrionLib_Configs"
    WindowConfig.SaveConfig = WindowConfig.SaveConfig or false
    WindowConfig.HidePremium = WindowConfig.HidePremium or false
    WindowConfig.IntroEnabled = WindowConfig.IntroEnabled == nil and true or WindowConfig.IntroEnabled
    WindowConfig.IntroText = WindowConfig.IntroText or "Orion Library"
    WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
    WindowConfig.ShowIcon = WindowConfig.ShowIcon or false
    WindowConfig.Icon = WindowConfig.Icon or "rbxassetid://8834748103"
    WindowConfig.IntroIcon = WindowConfig.IntroIcon or "rbxassetid://8834748103"
    
    OrionLib.Folder = WindowConfig.ConfigFolder
    OrionLib.SaveCfg = WindowConfig.SaveConfig
    
    -- 创建配置文件夹
    if WindowConfig.SaveConfig and makefolder then
        local success = pcall(function()
            if not isfolder(WindowConfig.ConfigFolder) then
                makefolder(WindowConfig.ConfigFolder)
            end
        end)
        
        if not success then
            warn("Orion Library: 无法创建配置文件夹")
            OrionLib.SaveCfg = false
        end
    end
    
    local FirstTab = true
    local Minimized = false
    local UIHidden = false
    
    -- 标签页容器
    local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 4), {
        Size = UDim2.new(1, 0, 1, -60),
        Position = UDim2.new(0, 0, 0, 0)
    }), {
        MakeElement("List"),
        MakeElement("Padding", 8, 8, 8, 8)
    }), "Divider")
    
    AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
    end)
    
    -- 控制按钮
    local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "x"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size = UDim2.new(0, 18, 0, 18)
        }), "Text")
    })
    
    local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "settings"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size = UDim2.new(0, 18, 0, 18),
            Name = "Ico"
        }), "Text")
    })
    
    local DragPoint = SetProps(MakeElement("TFrame"), {
        Size = UDim2.new(1, 0, 0, 40)
    })
    
    -- 侧边栏
    local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
        Size = UDim2.new(0, 180, 1, -50),
        Position = UDim2.new(0, 0, 0, 50)
    }), {
        AddThemeObject(SetProps(MakeElement("Frame"), {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 0)
        }), "Stroke"),
        AddThemeObject(SetProps(MakeElement("Frame"), {
            Size = UDim2.new(0, 1, 1, 0),
            Position = UDim2.new(1, -1, 0, 0)
        }), "Stroke"),
        TabHolder,
        SetChildren(SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(1, 0, 0, 60),
            Position = UDim2.new(0, 0, 1, -60)
        }), {
            AddThemeObject(SetProps(MakeElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 0, 0)
            })), "Stroke"),
            AddThemeObject(SetChildren(SetProps(MakeElement("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Size = UDim2.new(0, 36, 0, 36),
                Position = UDim2.new(0, 12, 0.5, 0)
            }), {
                SetProps(MakeElement("Image", 
                    "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
                ), {
                    Size = UDim2.new(1, 0, 1, 0),
                    ScaleType = Enum.ScaleType.Crop
                }),
                MakeElement("Corner", 1)
            }), "Divider"),
            AddThemeObject(SetProps(MakeElement("Label", LocalPlayer.DisplayName or LocalPlayer.Name, 14), {
                Size = UDim2.new(1, -60, 0, 18),
                Position = UDim2.new(0, 56, 0, 12),
                Font = Enum.Font.GothamBold,
                ClipsDescendants = true
            }), "Text"),
            AddThemeObject(SetProps(MakeElement("Label", "@" .. LocalPlayer.Name, 12), {
                Size = UDim2.new(1, -60, 0, 14),
                Position = UDim2.new(0, 56, 0, 30),
                Visible = not WindowConfig.HidePremium
            }), "TextDark")
        })
    }), "Second")
    
    local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 18), {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 40, 0, 0),
        Font = Enum.Font.GothamBold
    }), "Text")
    
    local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1)
    }), "Stroke")
    
    -- 主窗口
    local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
        Parent = Orion,
        Position = UDim2.new(0.5, -320, 0.5, -180),
        Size = UDim2.new(0, 640, 0, 360),
        ClipsDescendants = true,
        Active = true
    }), {
        SetChildren(SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(1, 0, 0, 40),
            Name = "TopBar"
        }), {
            WindowName,
            WindowTopBarLine,
            AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                Size = UDim2.new(0, 80, 0, 32),
                Position = UDim2.new(1, -92, 0, 4)
            }), {
                AddThemeObject(MakeElement("Stroke"), "Stroke"),
                AddThemeObject(SetProps(MakeElement("Frame"), {
                    Size = UDim2.new(0, 1, 1, 0),
                    Position = UDim2.new(0.5, 0, 0, 0)
                }), "Stroke"),
                CloseBtn,
                MinimizeBtn
            }), "Second"),
        }),
        DragPoint,
        WindowStuff
    }), "Main")
    
    -- 窗口图标
    if WindowConfig.ShowIcon then
        local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(0, 12, 0, 8)
        })
        WindowIcon.Parent = MainWindow.TopBar
    end
    
    -- 拖拽功能
    MakeDraggable(DragPoint, MainWindow)
    
    -- 关闭按钮事件
    AddConnection(CloseBtn.MouseButton1Click, function()
        MainWindow.Visible = false
        UIHidden = true
        OrionLib:MakeNotification({
            Name = "UI已隐藏",
            Content = "按左Shift键重新打开界面",
            Time = 3
        })
        WindowConfig.CloseCallback()
    end)
    
    -- 显示/隐藏热键
    AddConnection(UserInputService.InputBegan, function(Input)
        if Input.KeyCode == Enum.KeyCode.LeftShift and UIHidden then
            MainWindow.Visible = true
            UIHidden = false
        end
    end)
    
    -- 最小化按钮事件
    AddConnection(MinimizeBtn.MouseButton1Click, function()
        Minimized = not Minimized
        
        if Minimized then
            MainWindow.ClipsDescendants = true
            WindowTopBarLine.Visible = false
            MinimizeBtn.Ico.Image = GetIcon("search") or "rbxassetid://7072720870"
            
            TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, WindowName.TextBounds.X + 160, 0, 40)
            }):Play()
            
            task.wait(0.1)
            WindowStuff.Visible = false
        else
            MinimizeBtn.Ico.Image = GetIcon("settings") or "rbxassetid://7072719338"
            WindowStuff.Visible = true
            WindowTopBarLine.Visible = true
            
            TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, 640, 0, 360)
            }):Play()
            
            task.wait(0.1)
            MainWindow.ClipsDescendants = false
        end
    end)
    
    -- 加载动画
    local function LoadSequence()
        if not WindowConfig.IntroEnabled then return end
        
        MainWindow.Visible = false
        
        local LoadSequenceLogo = SetProps(MakeElement("Image", WindowConfig.IntroIcon), {
            Parent = Orion,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.4, 0),
            Size = UDim2.new(0, 32, 0, 32),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ImageTransparency = 1
        })
        
        local LoadSequenceText = SetProps(MakeElement("Label", WindowConfig.IntroText, 18), {
            Parent = Orion,
            Size = UDim2.new(0, 0, 0, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.6, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.XY
        })
        
        -- 动画序列
        TweenService:Create(LoadSequenceLogo, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            ImageTransparency = 0
        }):Play()
        
        task.wait(0.3)
        
        TweenService:Create(LoadSequenceLogo, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0.5, -(LoadSequenceText.TextBounds.X / 2 + 20), 0.5, 0)
        }):Play()
        
        TweenService:Create(LoadSequenceText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            TextTransparency = 0,
            Position = UDim2.new(0.5, 20, 0.5, 0)
        }):Play()
        
        task.wait(1)
        
        TweenService:Create(LoadSequenceLogo, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            ImageTransparency = 1
        }):Play()
        
        TweenService:Create(LoadSequenceText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            TextTransparency = 1
        }):Play()
        
        task.wait(0.3)
        
        LoadSequenceLogo:Destroy()
        LoadSequenceText:Destroy()
        MainWindow.Visible = true
    end
    
    task.spawn(LoadSequence)
    
    -- 标签页功能
    local TabFunction = {}
    
    function TabFunction:MakeTab(TabConfig)
        TabConfig = TabConfig or {}
        TabConfig.Name = TabConfig.Name or "标签页"
        TabConfig.Icon = TabConfig.Icon or ""
        TabConfig.PremiumOnly = TabConfig.PremiumOnly or false
        
        local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
            Size = UDim2.new(1, -16, 0, 36),
            Parent = TabHolder,
            BackgroundTransparency = 1
        }), {
            AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
                AnchorPoint = Vector2.new(0, 0.5),
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 12, 0.5, 0),
                ImageTransparency = 0.4,
                Name = "Ico"
            }), "Text"),
            AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
                Size = UDim2.new(1, -40, 1, 0),
                Position = UDim2.new(0, 40, 0, 0),
                Font = Enum.Font.GothamSemibold,
                TextTransparency = 0.4,
                Name = "Title"
            }), "Text")
        })
        
        local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 5), {
            Size = UDim2.new(1, -180, 1, -50),
            Position = UDim2.new(0, 180, 0, 50),
            Parent = MainWindow,
            Visible = false,
            Name = "ItemContainer"
        }), {
            MakeElement("List", 0, 8),
            MakeElement("Padding", 12, 12, 12, 12)
        }), "Divider")
        
        AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            Container.CanvasSize = UDim2.new(0, 0, 0, Container.UIListLayout.AbsoluteContentSize.Y + 24)
        end)
        
        -- 设置第一个标签页为激活状态
        if FirstTab then
            FirstTab = false
            TabFrame.Ico.ImageTransparency = 0
            TabFrame.Title.TextTransparency = 0
            TabFrame.Title.Font = Enum.Font.GothamBold
            Container.Visible = true
        end
        
        -- 标签页点击事件
        AddConnection(TabFrame.MouseButton1Click, function()
            -- 隐藏所有标签页内容
            for _, child in ipairs(MainWindow:GetChildren()) do
                if child.Name == "ItemContainer" then
                    child.Visible = false
                end
            end
            
            -- 重置所有标签页样式
            for _, tab in ipairs(TabHolder:GetChildren()) do
                if tab:IsA("TextButton") then
                    tab.Title.Font = Enum.Font.GothamSemibold
                    TweenService:Create(tab.Ico, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        ImageTransparency = 0.4
                    }):Play()
                    TweenService:Create(tab.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        TextTransparency = 0.4
                    }):Play()
                end
            end
            
            -- 设置当前标签页为激活状态
            TweenService:Create(TabFrame.Ico, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                ImageTransparency = 0
            }):Play()
            TweenService:Create(TabFrame.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                TextTransparency = 0
            }):Play()
            TabFrame.Title.Font = Enum.Font.GothamBold
            Container.Visible = true
        end)
        
        -- 元素创建函数
        local function GetElements(ItemParent)
            local ElementFunction = {}
            
            function ElementFunction:AddLabel(Text)
                local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundTransparency = 0.8,
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
                        Size = UDim2.new(1, -16, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke")
                }), "Second")
                
                local LabelFunction = {}
                function LabelFunction:Set(ToChange)
                    if LabelFrame and LabelFrame:FindFirstChild("Content") then
                        LabelFrame.Content.Text = ToChange
                    end
                end
                return LabelFunction
            end
            
            function ElementFunction:AddParagraph(Text, Content)
                Text = Text or "标题"
                Content = Content or "内容"
                
                local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 60),
                    BackgroundTransparency = 0.8,
                    Parent = ItemParent,
                    AutomaticSize = Enum.AutomaticSize.Y
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
                        Size = UDim2.new(1, -16, 0, 20),
                        Position = UDim2.new(0, 12, 0, 8),
                        Font = Enum.Font.GothamBold,
                        Name = "Title"
                    }), "Text"),
                    AddThemeObject(SetProps(MakeElement("Label", Content, 13), {
                        Size = UDim2.new(1, -24, 0, 0),
                        Position = UDim2.new(0, 12, 0, 32),
                        Font = Enum.Font.GothamSemibold,
                        Name = "Content",
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y
                    }), "TextDark"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke")
                }), "Second")
                
                AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("TextBounds"), function()
                    ParagraphFrame.Size = UDim2.new(1, 0, 0, ParagraphFrame.Content.TextBounds.Y + 40)
                end)
                
                ParagraphFrame.Content.Text = Content
                
                local ParagraphFunction = {}
                function ParagraphFunction:Set(ToChange)
                    if ParagraphFrame and ParagraphFrame:FindFirstChild("Content") then
                        ParagraphFrame.Content.Text = ToChange
                    end
                end
                return ParagraphFunction
            end
            
            function ElementFunction:AddButton(ButtonConfig)
                ButtonConfig = ButtonConfig or {}
                ButtonConfig.Name = ButtonConfig.Name or "按钮"
                ButtonConfig.Callback = ButtonConfig.Callback or function() end
                ButtonConfig.Icon = ButtonConfig.Icon or ""
                
                local Button = {}
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 36),
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
                        Size = UDim2.new(1, -12, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    Click
                }), "Second")
                
                if ButtonConfig.Icon and ButtonConfig.Icon ~= "" then
                    local icon = AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
                        Size = UDim2.new(0, 20, 0, 20),
                        Position = UDim2.new(1, -32, 0, 8),
                    }), "TextDark")
                    icon.Parent = ButtonFrame
                end
                
                -- 悬停效果
                AddConnection(Click.MouseEnter, function()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = Color3.fromRGB(
                            OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 5,
                            OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 5,
                            OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 5
                        )
                    }):Play()
                end)
                
                AddConnection(Click.MouseLeave, function()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second
                    }):Play()
                end)
                
                AddConnection(Click.MouseButton1Click, function()
                    ButtonConfig.Callback()
                end)
                
                function Button:Set(ButtonText)
                    if ButtonFrame and ButtonFrame:FindFirstChild("Content") then
                        ButtonFrame.Content.Text = ButtonText
                    end
                end
                
                return Button
            end
            
            function ElementFunction:AddToggle(ToggleConfig)
                ToggleConfig = ToggleConfig or {}
                ToggleConfig.Name = ToggleConfig.Name or "开关"
                ToggleConfig.Default = ToggleConfig.Default or false
                ToggleConfig.Callback = ToggleConfig.Callback or function() end
                ToggleConfig.Color = ToggleConfig.Color or Color3.fromRGB(9, 99, 195)
                ToggleConfig.Flag = ToggleConfig.Flag or nil
                ToggleConfig.Save = ToggleConfig.Save or false
                
                local Toggle = {Value = ToggleConfig.Default, Type = "Toggle", Save = ToggleConfig.Save}
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local ToggleBox = SetChildren(SetProps(MakeElement("RoundFrame", ToggleConfig.Color, 0, 4), {
                    Size = UDim2.new(0, 24, 0, 24),
                    Position = UDim2.new(1, -32, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5)
                }), {
                    SetProps(MakeElement("Stroke"), {
                        Color = ToggleConfig.Color,
                        Name = "Stroke",
                        Transparency = 0.5
                    }),
                    SetProps(MakeElement("Image", "check"), {
                        Size = UDim2.new(0, 16, 0, 16),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        ImageColor3 = Color3.fromRGB(255, 255, 255),
                        Name = "Ico",
                        ImageTransparency = 1
                    }),
                })
                
                local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 40),
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
                        Size = UDim2.new(1, -48, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    ToggleBox,
                    Click
                }), "Second")
                
                function Toggle:Set(Value)
                    self.Value = Value
                    
                    local targetColor = Toggle.Value and ToggleConfig.Color or Color3.fromRGB(100, 100, 100)
                    local targetSize = Toggle.Value and UDim2.new(0, 16, 0, 16) or UDim2.new(0, 8, 0, 8)
                    local targetTransparency = Toggle.Value and 0 or 1
                    
                    TweenService:Create(ToggleBox, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = targetColor
                    }):Play()
                    
                    TweenService:Create(ToggleBox.Stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        Color = targetColor
                    }):Play()
                    
                    TweenService:Create(ToggleBox.Ico, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        ImageTransparency = targetTransparency,
                        Size = targetSize
                    }):Play()
                    
                    ToggleConfig.Callback(Toggle.Value)
                end
                
                Toggle:Set(Toggle.Value)
                
                AddConnection(Click.MouseButton1Click, function()
                    Toggle:Set(not Toggle.Value)
                    if OrionLib.SaveCfg then
                        SaveCfg("auto_save")
                    end
                end)
                
                if ToggleConfig.Flag then
                    OrionLib.Flags[ToggleConfig.Flag] = Toggle
                end
                
                return Toggle
            end
            
            function ElementFunction:AddSlider(SliderConfig)
                SliderConfig = SliderConfig or {}
                SliderConfig.Name = SliderConfig.Name or "滑块"
                SliderConfig.Min = SliderConfig.Min or 0
                SliderConfig.Max = SliderConfig.Max or 100
                SliderConfig.Increment = SliderConfig.Increment or 1
                SliderConfig.Default = SliderConfig.Default or 50
                SliderConfig.Callback = SliderConfig.Callback or function() end
                SliderConfig.ValueName = SliderConfig.ValueName or ""
                SliderConfig.Color = SliderConfig.Color or Color3.fromRGB(9, 149, 98)
                SliderConfig.Flag = SliderConfig.Flag or nil
                SliderConfig.Save = SliderConfig.Save or false
                
                local Slider = {Value = SliderConfig.Default, Type = "Slider", Save = SliderConfig.Save}
                local Dragging = false
                
                local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 6), {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundTransparency = 0.3
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", "value", 12), {
                        Size = UDim2.new(1, -8, 0, 14),
                        Position = UDim2.new(0, 4, 0, 5),
                        Font = Enum.Font.GothamBold,
                        Name = "Value",
                        TextTransparency = 0
                    }), "Text")
                })
                
                local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 6), {
                    Size = UDim2.new(1, -24, 0, 24),
                    Position = UDim2.new(0, 12, 0, 30),
                    BackgroundTransparency = 0.9
                }), {
                    SetProps(MakeElement("Stroke"), {
                        Color = SliderConfig.Color
                    }),
                    SliderDrag
                })
                
                local ValueLabel = AddThemeObject(SetProps(MakeElement("Label", "", 13), {
                    Size = UDim2.new(1, -24, 0, 14),
                    Position = UDim2.new(0, 12, 0, 8),
                    Font = Enum.Font.GothamBold,
                    Name = "Value",
                    TextTransparency = 0.8,
                    TextXAlignment = Enum.TextXAlignment.Right
                }), "Text")
                
                local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 65),
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
                        Size = UDim2.new(1, -12, 0, 14),
                        Position = UDim2.new(0, 12, 0, 10),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    ValueLabel,
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    SliderBar
                }), "Second")
                
                function Slider:Set(Value)
                    self.Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
                    local percent = (self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
                    
                    TweenService:Create(SliderDrag, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        Size = UDim2.new(percent, 0, 1, 0)
                    }):Play()
                    
                    local displayValue = tostring(self.Value)
                    if SliderConfig.ValueName ~= "" then
                        displayValue = displayValue .. " " .. SliderConfig.ValueName
                    end
                    
                    SliderBar.Value.Text = displayValue
                    ValueLabel.Text = displayValue
                    
                    SliderConfig.Callback(self.Value)
                end
                
                -- 拖动事件
                local function UpdateSliderFromMouse()
                    if not Dragging then return end
                    
                    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
                    local barAbsPos = SliderBar.AbsolutePosition
                    local barAbsSize = SliderBar.AbsoluteSize
                    
                    local relativeX = math.clamp((mousePos.X - barAbsPos.X) / barAbsSize.X, 0, 1)
                    local value = SliderConfig.Min + (SliderConfig.Max - SliderConfig.Min) * relativeX
                    
                    Slider:Set(value)
                end
                
                AddConnection(SliderBar.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = true
                        UpdateSliderFromMouse()
                    end
                end)
                
                AddConnection(SliderBar.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = false
                        if OrionLib.SaveCfg then
                            SaveCfg("auto_save")
                        end
                    end
                end)
                
                AddConnection(game:GetService("UserInputService").InputChanged, function(input)
                    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        UpdateSliderFromMouse()
                    end
                end)
                
                Slider:Set(Slider.Value)
                
                if SliderConfig.Flag then
                    OrionLib.Flags[SliderConfig.Flag] = Slider
                end
                
                return Slider
            end
            
            function ElementFunction:AddDropdown(DropdownConfig)
                DropdownConfig = DropdownConfig or {}
                DropdownConfig.Name = DropdownConfig.Name or "下拉框"
                DropdownConfig.Options = DropdownConfig.Options or {}
                DropdownConfig.Default = DropdownConfig.Default or ""
                DropdownConfig.Callback = DropdownConfig.Callback or function() end
                DropdownConfig.Flag = DropdownConfig.Flag or nil
                DropdownConfig.Save = DropdownConfig.Save or false
                
                local Dropdown = {
                    Value = DropdownConfig.Default,
                    Options = DropdownConfig.Options,
                    Buttons = {},
                    Toggled = false,
                    Type = "Dropdown",
                    Save = DropdownConfig.Save
                }
                
                if not table.find(Dropdown.Options, Dropdown.Value) and #Dropdown.Options > 0 then
                    Dropdown.Value = Dropdown.Options[1]
                elseif #Dropdown.Options == 0 then
                    Dropdown.Value = "无选项"
                end
                
                local DropdownList = MakeElement("List")
                
                local DropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(40, 40, 40), 4), {
                    DropdownList
                }), {
                    Parent = ItemParent,
                    Position = UDim2.new(0, 0, 0, 40),
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ScrollBarImageTransparency = 0.5
                }), "Divider")
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 40),
                    Parent = ItemParent,
                    ClipsDescendants = true
                }), {
                    DropdownContainer,
                    SetProps(SetChildren(MakeElement("TFrame"), {
                        AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {
                            Size = UDim2.new(1, -48, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font = Enum.Font.GothamBold,
                            Name = "Content"
                        }), "Text"),
                        AddThemeObject(SetProps(MakeElement("Image", "chevron-down"), {
                            Size = UDim2.new(0, 20, 0, 20),
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, -12, 0.5, 0),
                            Name = "Ico"
                        }), "TextDark"),
                        AddThemeObject(SetProps(MakeElement("Label", Dropdown.Value, 13), {
                            Size = UDim2.new(1, -48, 1, 0),
                            Font = Enum.Font.Gotham,
                            Name = "Selected",
                            TextXAlignment = Enum.TextXAlignment.Right
                        }), "TextDark"),
                        Click
                    }), {
                        Size = UDim2.new(1, 0, 0, 40),
                        ClipsDescendants = true,
                        Name = "Header"
                    }),
                    AddThemeObject(MakeElement("Stroke"), "Stroke")
                }), "Second")
                
                AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                    DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownList.AbsoluteContentSize.Y)
                end)
                
                local function AddOptions(Options)
                    for _, Option in ipairs(Options) do
                        local OptionBtn = AddThemeObject(SetChildren(SetProps(MakeElement("Button"), {
                            Parent = DropdownContainer,
                            Size = UDim2.new(1, -8, 0, 32),
                            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                            BackgroundTransparency = 1,
                            AutoButtonColor = false
                        }), {
                            MakeElement("Corner", 0, 4),
                            AddThemeObject(SetProps(MakeElement("Label", Option, 13), {
                                Position = UDim2.new(0, 8, 0, 0),
                                Size = UDim2.new(1, -8, 1, 0),
                                Name = "Title"
                            }), "Text")
                        }), "Divider")
                        
                        AddConnection(OptionBtn.MouseButton1Click, function()
                            Dropdown:Set(Option)
                            if OrionLib.SaveCfg then
                                SaveCfg("auto_save")
                            end
                        end)
                        
                        Dropdown.Buttons[Option] = OptionBtn
                    end
                end
                
                function Dropdown:Refresh(Options, Delete)
                    if Delete then
                        for _, v in pairs(Dropdown.Buttons) do
                            v:Destroy()
                        end
                        Dropdown.Buttons = {}
                    end
                    
                    Dropdown.Options = Options or {}
                    
                    if #Dropdown.Options > 0 and not table.find(Dropdown.Options, Dropdown.Value) then
                        Dropdown.Value = Dropdown.Options[1]
                    end
                    
                    AddOptions(Dropdown.Options)
                end
                
                function Dropdown:Set(Value)
                    if not table.find(Dropdown.Options, Value) then
                        return
                    end
                    
                    Dropdown.Value = Value
                    DropdownFrame.Header.Selected.Text = Dropdown.Value
                    
                    for option, btn in pairs(Dropdown.Buttons) do
                        btn.BackgroundTransparency = option == Value and 0.2 or 1
                    end
                    
                    DropdownConfig.Callback(Dropdown.Value)
                end
                
                AddConnection(Click.MouseButton1Click, function()
                    Dropdown.Toggled = not Dropdown.Toggled
                    
                    if Dropdown.Toggled then
                        DropdownContainer.Visible = true
                        local height = math.min(#Dropdown.Options * 36, 200)
                        DropdownContainer.Size = UDim2.new(1, 0, 0, height)
                        TweenService:Create(DropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                            Size = UDim2.new(1, 0, 0, 40 + height)
                        }):Play()
                    else
                        TweenService:Create(DropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                            Size = UDim2.new(1, 0, 0, 40)
                        }):Play()
                        task.wait(0.2)
                        DropdownContainer.Visible = false
                    end
                end)
                
                Dropdown:Refresh(Dropdown.Options, false)
                Dropdown:Set(Dropdown.Value)
                
                if DropdownConfig.Flag then
                    OrionLib.Flags[DropdownConfig.Flag] = Dropdown
                end
                
                return Dropdown
            end
            
            function ElementFunction:AddBind(BindConfig)
                BindConfig = BindConfig or {}
                BindConfig.Name = BindConfig.Name or "快捷键"
                BindConfig.Default = BindConfig.Default or Enum.KeyCode.Unknown
                BindConfig.Hold = BindConfig.Hold or false
                BindConfig.Callback = BindConfig.Callback or function() end
                BindConfig.Flag = BindConfig.Flag or nil
                BindConfig.Save = BindConfig.Save or false
                
                local Bind = {
                    Value = BindConfig.Default,
                    Binding = false,
                    Type = "Bind",
                    Save = BindConfig.Save
                }
                local Holding = false
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
                    Size = UDim2.new(0, 80, 0, 28),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5)
                }), {
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
                        Size = UDim2.new(1, 0, 1, 0),
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        Name = "Value"
                    }), "Text")
                }), "Main")
                
                local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 40),
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {
                        Size = UDim2.new(1, -100, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    BindBox,
                    Click
                }), "Second")
                
                AddConnection(Click.MouseButton1Click, function()
                    if Bind.Binding then return end
                    
                    Bind.Binding = true
                    BindBox.Value.Text = "[...]"
                end)
                
                local function SetBind(Key)
                    Bind.Binding = false
                    Bind.Value = Key
                    local keyName = tostring(Key):gsub("Enum.KeyCode.", "")
                    BindBox.Value.Text = keyName
                end
                
                AddConnection(UserInputService.InputBegan, function(input)
                    if Bind.Binding then
                        local key = input.KeyCode
                        if key ~= Enum.KeyCode.Unknown then
                            SetBind(key)
                            if OrionLib.SaveCfg then
                                SaveCfg("auto_save")
                            end
                        end
                    elseif input.KeyCode == Bind.Value then
                        if BindConfig.Hold then
                            Holding = true
                            BindConfig.Callback(true)
                        else
                            BindConfig.Callback()
                        end
                    end
                end)
                
                AddConnection(UserInputService.InputEnded, function(input)
                    if input.KeyCode == Bind.Value and BindConfig.Hold and Holding then
                        Holding = false
                        BindConfig.Callback(false)
                    end
                end)
                
                function Bind:Set(Key)
                    SetBind(Key)
                end
                
                Bind:Set(BindConfig.Default)
                
                if BindConfig.Flag then
                    OrionLib.Flags[BindConfig.Flag] = Bind
                end
                
                return Bind
            end
            
            function ElementFunction:AddTextbox(TextboxConfig)
                TextboxConfig = TextboxConfig or {}
                TextboxConfig.Name = TextboxConfig.Name or "文本框"
                TextboxConfig.Default = TextboxConfig.Default or ""
                TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
                TextboxConfig.Callback = TextboxConfig.Callback or function() end
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local TextboxActual = AddThemeObject(Create("TextBox", {
                    Size = UDim2.new(0, 120, 0, 28),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    PlaceholderColor3 = Color3.fromRGB(180, 180, 180),
                    PlaceholderText = "输入...",
                    Font = Enum.Font.GothamSemibold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextSize = 14,
                    ClearTextOnFocus = false,
                    Text = TextboxConfig.Default
                }), "Text")
                
                local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
                    Size = UDim2.new(0, 120, 0, 28),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5)
                }), {
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    TextboxActual
                }), "Main")
                
                local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 40),
                    Parent = ItemParent
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {
                        Size = UDim2.new(1, -140, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    TextContainer,
                    Click
                }), "Second")
                
                AddConnection(TextboxActual.FocusLost, function(enterPressed)
                    TextboxConfig.Callback(TextboxActual.Text)
                    if TextboxConfig.TextDisappear then
                        TextboxActual.Text = ""
                    end
                end)
                
                AddConnection(Click.MouseButton1Click, function()
                    TextboxActual:CaptureFocus()
                end)
                
                return TextboxActual
            end
            
            function ElementFunction:AddColorpicker(ColorpickerConfig)
                ColorpickerConfig = ColorpickerConfig or {}
                ColorpickerConfig.Name = ColorpickerConfig.Name or "颜色选择器"
                ColorpickerConfig.Default = ColorpickerConfig.Default or Color3.fromRGB(255, 255, 255)
                ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
                ColorpickerConfig.Flag = ColorpickerConfig.Flag or nil
                ColorpickerConfig.Save = ColorpickerConfig.Save or false
                
                local Colorpicker = {
                    Value = ColorpickerConfig.Default,
                    Toggled = false,
                    Type = "Colorpicker",
                    Save = ColorpickerConfig.Save
                }
                
                local ColorBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", ColorpickerConfig.Default, 0, 4), {
                    Size = UDim2.new(0, 28, 0, 28),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5)
                }), {
                    AddThemeObject(MakeElement("Stroke"), "Stroke")
                }), "Main")
                
                local Click = SetProps(MakeElement("Button"), {
                    Size = UDim2.new(1, 0, 1, 0)
                })
                
                local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 6), {
                    Size = UDim2.new(1, 0, 0, 40),
                    Parent = ItemParent,
                    ClipsDescendants = true
                }), {
                    AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 15), {
                        Size = UDim2.new(1, -48, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font = Enum.Font.GothamBold,
                        Name = "Content"
                    }), "Text"),
                    AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    ColorBox,
                    Click
                }), "Second")
                
                -- 简化的颜色选择器
                AddConnection(Click.MouseButton1Click, function()
                    -- 这里可以扩展为完整的颜色选择器
                    -- 目前只显示当前颜色
                    OrionLib:MakeNotification({
                        Name = "颜色选择器",
                        Content = "当前颜色: " .. tostring(math.floor(Colorpicker.Value.R * 255)) .. ", " .. 
                                  tostring(math.floor(Colorpicker.Value.G * 255)) .. ", " .. 
                                  tostring(math.floor(Colorpicker.Value.B * 255)),
                        Time = 3
                    })
                end)
                
                function Colorpicker:Set(Value)
                    Colorpicker.Value = Value
                    ColorBox.BackgroundColor3 = Value
                    ColorpickerConfig.Callback(Value)
                    
                    if OrionLib.SaveCfg then
                        SaveCfg("auto_save")
                    end
                end
                
                Colorpicker:Set(Colorpicker.Value)
                
                if ColorpickerConfig.Flag then
                    OrionLib.Flags[ColorpickerConfig.Flag] = Colorpicker
                end
                
                return Colorpicker
            end
            
            return ElementFunction
        end
        
        local ElementFunction = {}
        local elements = GetElements(Container)
        
        for name, func in pairs(elements) do
            ElementFunction[name] = func
        end
        
        if TabConfig.PremiumOnly then
            -- 清除所有元素函数
            for name, _ in pairs(ElementFunction) do
                ElementFunction[name] = function() end
            end
            
            -- 显示Premium提示
            Container:ClearAllChildren()
            
            SetChildren(SetProps(MakeElement("TFrame"), {
                Size = UDim2.new(1, 0, 1, 0),
                Parent = Container
            }), {
                AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {
                    Size = UDim2.new(0, 24, 0, 24),
                    Position = UDim2.new(0.5, -12, 0.3, 0),
                    AnchorPoint = Vector2.new(0.5, 0)
                }), "Text"),
                AddThemeObject(SetProps(MakeElement("Label", "高级功能", 16), {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.new(0, 0, 0.4, 0),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Font = Enum.Font.GothamBold
                }), "Text"),
                AddThemeObject(SetProps(MakeElement("Label", "此功能需要Premium版本", 14), {
                    Size = UDim2.new(1, -40, 0, 40),
                    Position = UDim2.new(0, 20, 0.5, 0),
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Center
                }), "TextDark")
            })
        end
        
        return ElementFunction
    end
    
    return TabFunction
end

-- 销毁函数
function OrionLib:Destroy()
    if Orion then
        Orion:Destroy()
    end
    
    for _, connection in ipairs(OrionLib.Connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    
    OrionLib.Connections = {}
    OrionLib.Flags = {}
    OrionLib.ThemeObjects = {}
end

return OrionLib
