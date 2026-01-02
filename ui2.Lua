-- Orion UI Library - 优化完整版
-- 作者: 397510573
-- 版本: 2.0 (优化版)

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

-- 安全检查
if not LocalPlayer then
    warn("Orion Library: LocalPlayer not found!")
    return nil
end

-- 主库对象
local OrionLib = {
    Elements = {},
    ThemeObjects = {},
    Connections = {},
    Flags = {},
    ColorpickerConnections = {},
    Windows = {},
    ActiveColorpickers = {},
    Themes = {
        Default = {
            Main = Color3.fromRGB(34, 34, 34),
            Second = Color3.fromRGB(45, 44, 45),
            Stroke = Color3.fromRGB(60, 60, 60),
            Divider = Color3.fromRGB(60, 60, 60),
            Text = Color3.fromRGB(225, 225, 225),
            TextDark = Color3.fromRGB(180, 180, 180)
        },
        Dark = {
            Main = Color3.fromRGB(20, 20, 20),
            Second = Color3.fromRGB(30, 30, 30),
            Stroke = Color3.fromRGB(50, 50, 50),
            Divider = Color3.fromRGB(40, 40, 40),
            Text = Color3.fromRGB(240, 240, 240),
            TextDark = Color3.fromRGB(200, 200, 200)
        },
        Light = {
            Main = Color3.fromRGB(240, 240, 240),
            Second = Color3.fromRGB(220, 220, 220),
            Stroke = Color3.fromRGB(180, 180, 180),
            Divider = Color3.fromRGB(200, 200, 200),
            Text = Color3.fromRGB(40, 40, 40),
            TextDark = Color3.fromRGB(80, 80, 80)
        }
    },
    SelectedTheme = "Default",
    Folder = "OrionConfig",
    SaveCfg = false,
    Version = "2.0.1",
    Debug = false
}

-- 性能监控
local Performance = {
    FPS = 60,
    LastUpdate = tick(),
    UpdateCount = 0
}

-- 图标缓存
local IconCache = {}
local function GetIcon(IconName)
    if IconCache[IconName] then
        return IconCache[IconName]
    end
    
    -- 内置图标映射
    local BuiltinIcons = {
        ["close"] = "rbxassetid://7072725342",
        ["minimize"] = "rbxassetid://7072719338",
        ["maximize"] = "rbxassetid://7072720870",
        ["dropdown"] = "rbxassetid://7072706796",
        ["check"] = "rbxassetid://3944680095",
        ["settings"] = "rbxassetid://4384403532",
        ["user"] = "rbxassetid://4031889928",
        ["premium"] = "rbxassetid://3610239960",
        ["lock"] = "rbxassetid://4483345875",
        ["refresh"] = "rbxassetid://7072723653"
    }
    
    local icon = BuiltinIcons[IconName:lower()]
    if icon then
        IconCache[IconName] = icon
        return icon
    end
    
    -- 尝试获取在线图标
    local success, result = pcall(function()
        local url = "https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json"
        local response = game:HttpGetAsync(url, true)
        local icons = HttpService:JSONDecode(response).icons
        if icons and icons[IconName] then
            return icons[IconName]
        end
    end)
    
    if success and result then
        IconCache[IconName] = result
        return result
    end
    
    return IconName -- 如果不是内置图标，直接返回输入
end

-- 创建GUI
local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion_" .. HttpService:GenerateGUID(false):sub(1, 8)
Orion.ResetOnSpawn = false
Orion.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Orion.DisplayOrder = 999
Orion.IgnoreGuiInset = true

-- GUI保护
local function ProtectGUI(gui)
    local success, result = pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
            return true
        elseif gethui then
            return true
        end
        return false
    end)
    return success
end

local guiParent
if gethui then
    guiParent = gethui()
elseif game.CoreGui then
    guiParent = game.CoreGui
else
    guiParent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
end

ProtectGUI(Orion)
Orion.Parent = guiParent

-- 清理旧实例
task.spawn(function()
    wait(0.5)
    for _, child in ipairs(guiParent:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name:match("^Orion_") and child ~= Orion then
            pcall(function() child:Destroy() end)
        end
    end
end)

-- 连接管理器
local ConnectionManager = {
    Connections = {},
    ColorpickerConnections = {},
    Running = true
}

function ConnectionManager:Add(signal, callback)
    if not self.Running then return nil end
    local conn = signal:Connect(callback)
    table.insert(self.Connections, conn)
    return conn
end

function ConnectionManager:AddColorpicker(id, connection)
    if not self.ColorpickerConnections[id] then
        self.ColorpickerConnections[id] = {}
    end
    table.insert(self.ColorpickerConnections[id], connection)
end

function ConnectionManager:CleanupColorpicker(id)
    if self.ColorpickerConnections[id] then
        for _, conn in ipairs(self.ColorpickerConnections[id]) do
            if conn.Connected then
                conn:Disconnect()
            end
        end
        self.ColorpickerConnections[id] = nil
    end
end

function ConnectionManager:DisconnectAll()
    self.Running = false
    
    for _, conn in ipairs(self.Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(self.Connections)
    
    for id, connections in pairs(self.ColorpickerConnections) do
        for _, conn in ipairs(connections) do
            if conn.Connected then
                conn:Disconnect()
            end
        end
    end
    table.clear(self.ColorpickerConnections)
end

-- 元素创建工具函数
local function Create(name, properties, children)
    local object = Instance.new(name)
    
    if properties then
        for key, value in pairs(properties) do
            local success = pcall(function()
                object[key] = value
            end)
            if not success and OrionLib.Debug then
                warn(string.format("Failed to set property %s on %s", tostring(key), name))
            end
        end
    end
    
    if children then
        for _, child in ipairs(children) do
            if child then
                child.Parent = object
            end
        end
    end
    
    return object
end

-- 圆角
local function CreateCorner(radius)
    return Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6)
    })
end

-- 描边
local function CreateStroke(color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round
    })
end

-- 内边距
local function CreatePadding(padding)
    padding = padding or {top = 4, bottom = 4, left = 4, right = 4}
    return Create("UIPadding", {
        PaddingTop = UDim.new(0, padding.top),
        PaddingBottom = UDim.new(0, padding.bottom),
        PaddingLeft = UDim.new(0, padding.left),
        PaddingRight = UDim.new(0, padding.right)
    })
end

-- 布局
local function CreateListLayout(padding, sortOrder, horizontalAlignment)
    return Create("UIListLayout", {
        SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding or 4),
        HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left
    })
end

-- 按钮
local function CreateButton()
    return Create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.new(1, 0, 1, 0)
    })
end

-- 标签
local function CreateLabel(text, size, options)
    options = options or {}
    return Create("TextLabel", {
        Text = text or "",
        TextColor3 = options.color or Color3.new(1, 1, 1),
        TextSize = size or 14,
        TextTransparency = options.transparency or 0,
        Font = options.font or Enum.Font.Gotham,
        TextXAlignment = options.xAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = options.yAlignment or Enum.TextYAlignment.Center,
        TextWrapped = options.wrapped or false,
        BackgroundTransparency = 1,
        Size = options.size or UDim2.new(1, 0, 0, 20)
    })
end

-- 输入框
local function CreateTextBox(placeholder, options)
    options = options or {}
    return Create("TextBox", {
        PlaceholderText = placeholder or "Input...",
        Text = options.text or "",
        TextColor3 = options.color or Color3.new(1, 1, 1),
        PlaceholderColor3 = options.placeholderColor or Color3.fromRGB(180, 180, 180),
        TextSize = options.size or 14,
        Font = options.font or Enum.Font.Gotham,
        BackgroundTransparency = 1,
        ClearTextOnFocus = options.clearOnFocus or false,
        Size = options.sizeUDim2 or UDim2.new(1, 0, 1, 0)
    })
end

-- 滚动框
local function CreateScrollFrame()
    return Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        ScrollBarImageColor3 = Color3.new(1, 1, 1),
        ScrollBarThickness = 4,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
end

-- 图像
local function CreateImage(imageId, size, options)
    options = options or {}
    return Create("ImageLabel", {
        Image = GetIcon(imageId) or imageId,
        ImageColor3 = options.color or Color3.new(1, 1, 1),
        ImageTransparency = options.transparency or 0,
        Size = size or UDim2.new(0, 20, 0, 20),
        BackgroundTransparency = 1,
        ScaleType = options.scaleType or Enum.ScaleType.Fit
    })
end

-- 框架
local function CreateFrame(color, options)
    options = options or {}
    local frame = Create("Frame", {
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BackgroundTransparency = options.transparency or 0,
        BorderSizePixel = 0,
        Size = options.size or UDim2.new(1, 0, 1, 0),
        Position = options.position or UDim2.new(0, 0, 0, 0)
    })
    
    if options.cornerRadius then
        CreateCorner(options.cornerRadius).Parent = frame
    end
    
    if options.stroke then
        CreateStroke(options.stroke.color, options.stroke.thickness, options.stroke.transparency).Parent = frame
    end
    
    return frame
end

-- 鼠标悬停效果
local function AddHoverEffect(frame, normalColor, hoverColor, clickColor)
    if not frame or not frame:IsA("GuiObject") then return end
    
    local currentColor = normalColor or frame.BackgroundColor3
    
    ConnectionManager:Add(frame.MouseEnter, function()
        TweenService:Create(frame, TweenInfo.new(0.15), {
            BackgroundColor3 = hoverColor or Color3.fromRGB(
                math.min(currentColor.R * 255 + 10, 255),
                math.min(currentColor.G * 255 + 10, 255),
                math.min(currentColor.B * 255 + 10, 255)
            )
        }):Play()
    end)
    
    ConnectionManager:Add(frame.MouseLeave, function()
        TweenService:Create(frame, TweenInfo.new(0.15), {
            BackgroundColor3 = currentColor
        }):Play()
    end)
    
    if clickColor then
        ConnectionManager:Add(frame.MouseButton1Down, function()
            TweenService:Create(frame, TweenInfo.new(0.1), {
                BackgroundColor3 = clickColor
            }):Play()
        end)
        
        ConnectionManager:Add(frame.MouseButton1Up, function()
            TweenService:Create(frame, TweenInfo.new(0.1), {
                BackgroundColor3 = hoverColor or Color3.fromRGB(
                    math.min(currentColor.R * 255 + 10, 255),
                    math.min(currentColor.G * 255 + 10, 255),
                    math.min(currentColor.B * 255 + 10, 255)
                )
            }):Play()
        end)
    end
end

-- 可拖动窗口
local function MakeDraggable(dragPoint, mainFrame)
    if not dragPoint or not mainFrame then return end
    
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    local function Update(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X,
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end
    
    ConnectionManager:Add(dragPoint.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    ConnectionManager:Add(dragPoint.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    ConnectionManager:Add(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            Update(input)
        end
    end)
end

-- 主题系统
local ThemeSystem = {}

function ThemeSystem:AddObject(object, themeType)
    if not OrionLib.ThemeObjects[themeType] then
        OrionLib.ThemeObjects[themeType] = {}
    end
    
    -- 确定属性
    local property
    if object:IsA("Frame") or object:IsA("TextButton") or object:IsA("ScrollingFrame") then
        property = "BackgroundColor3"
    elseif object:IsA("UIStroke") then
        property = "Color"
    elseif object:IsA("TextLabel") or object:IsA("TextBox") then
        property = "TextColor3"
    elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
        property = "ImageColor3"
    else
        return object
    end
    
    -- 设置初始颜色
    if OrionLib.Themes[OrionLib.SelectedTheme] and OrionLib.Themes[OrionLib.SelectedTheme][themeType] then
        object[property] = OrionLib.Themes[OrionLib.SelectedTheme][themeType]
    end
    
    table.insert(OrionLib.ThemeObjects[themeType], {object = object, property = property})
    return object
end

function ThemeSystem:UpdateTheme(themeName)
    if not OrionLib.Themes[themeName] then
        warn(string.format("Theme '%s' does not exist!", themeName))
        return
    end
    
    OrionLib.SelectedTheme = themeName
    
    for themeType, objects in pairs(OrionLib.ThemeObjects) do
        local color = OrionLib.Themes[themeName][themeType]
        if color then
            for _, data in ipairs(objects) do
                if data.object and data.property then
                    pcall(function()
                        data.object[data.property] = color
                    end)
                end
            end
        end
    end
end

function ThemeSystem:CreateTheme(name, colors)
    OrionLib.Themes[name] = colors
end

-- 配置系统
local ConfigSystem = {}

function ConfigSystem:PackColor(color)
    return {
        R = math.floor(color.R * 255),
        G = math.floor(color.G * 255),
        B = math.floor(color.B * 255)
    }
end

function ConfigSystem:UnpackColor(colorTable)
    if colorTable and colorTable.R and colorTable.G and colorTable.B then
        return Color3.fromRGB(colorTable.R, colorTable.G, colorTable.B)
    end
    return Color3.fromRGB(255, 255, 255)
end

function ConfigSystem:Save(name)
    if not OrionLib.SaveCfg or not writefile then return false end
    
    local data = {}
    
    for flagName, flagData in pairs(OrionLib.Flags) do
        if flagData and flagData.Save ~= false then
            if flagData.Type == "Colorpicker" then
                data[flagName] = self:PackColor(flagData.Value)
            elseif flagData.Type == "Bind" then
                data[flagName] = tostring(flagData.Value)
            elseif flagData.Type == "Dropdown" then
                data[flagName] = {value = flagData.Value, options = flagData.Options}
            else
                data[flagName] = flagData.Value
            end
        end
    end
    
    local success, result = pcall(function()
        local json = HttpService:JSONEncode(data)
        if not isfolder(OrionLib.Folder) then
            makefolder(OrionLib.Folder)
        end
        writefile(OrionLib.Folder .. "/" .. name .. ".json", json)
        return true
    end)
    
    return success
end

function ConfigSystem:Load(name)
    if not isfile or not readfile then return false end
    
    local path = OrionLib.Folder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    
    local success, data = pcall(function()
        local content = readfile(path)
        return HttpService:JSONDecode(content)
    end)
    
    if not success then
        warn("Failed to load config: " .. tostring(data))
        return false
    end
    
    -- 延迟加载避免UI阻塞
    task.spawn(function()
        for flagName, value in pairs(data) do
            local flag = OrionLib.Flags[flagName]
            if flag then
                task.wait(0.01) -- 防止卡顿
                
                if flag.Type == "Colorpicker" then
                    flag:Set(self:UnpackColor(value))
                elseif flag.Type == "Bind" then
                    local keyCode = Enum.KeyCode[value] or flag.Value
                    flag:Set(keyCode)
                elseif flag.Type == "Dropdown" then
                    if type(value) == "table" then
                        flag:Refresh(value.options or {})
                        flag:Set(value.value or flag.Value)
                    else
                        flag:Set(value)
                    end
                else
                    flag:Set(value)
                end
            end
        end
    end)
    
    return true
end

-- 通知系统
local NotificationSystem = {}

NotificationSystem.Holder = Create("Frame", {
    Name = "NotificationHolder",
    Parent = Orion,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.new(0, 350, 1, -20),
    AnchorPoint = Vector2.new(1, 1),
    ZIndex = 1000
}, {
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom
    })
})

function NotificationSystem:Create(notificationConfig)
    notificationConfig = notificationConfig or {}
    
    local notificationId = HttpService:GenerateGUID(false)
    local lifeTime = notificationConfig.Time or 5
    
    -- 创建通知容器
    local notification = Create("Frame", {
        Name = "Notification_" .. notificationId,
        Parent = self.Holder,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        ZIndex = 1001
    }, {
        CreateCorner(8),
        CreateStroke(Color3.fromRGB(80, 80, 80), 1),
        CreatePadding({top = 15, bottom = 15, left = 15, right = 15}),
        CreateListLayout(8, Enum.SortOrder.LayoutOrder)
    })
    
    -- 顶部栏
    local topBar = Create("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = 1
    }, {
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10)
        })
    })
    
    -- 图标
    local icon = CreateImage(notificationConfig.Image or "settings", UDim2.new(0, 20, 0, 20), {
        color = Color3.fromRGB(220, 220, 220)
    })
    icon.Parent = topBar
    
    -- 标题
    local title = CreateLabel(notificationConfig.Name or "Notification", 16, {
        font = Enum.Font.GothamBold,
        color = Color3.fromRGB(240, 240, 240),
        size = UDim2.new(1, -30, 1, 0)
    })
    title.Parent = topBar
    
    -- 关闭按钮
    local closeBtn = CreateButton()
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -20, 0, 2)
    closeBtn.ZIndex = 1002
    closeBtn.Parent = topBar
    
    local closeIcon = CreateImage("close", UDim2.new(1, 0, 1, 0), {
        color = Color3.fromRGB(200, 200, 200)
    })
    closeIcon.Parent = closeBtn
    
    -- 内容
    local content = CreateLabel(notificationConfig.Content or "Content", 14, {
        color = Color3.fromRGB(200, 200, 200),
        wrapped = true,
        size = UDim2.new(1, 0, 0, 0),
        transparency = 0
    })
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.LayoutOrder = 2
    content.Parent = notification
    
    topBar.Parent = notification
    
    -- 动画进入
    notification.Position = UDim2.new(1, 10, 0, 0)
    TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    
    -- 关闭函数
    local function Close()
        TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(1, 10, 0, 0),
            BackgroundTransparency = 1
        }):Play()
        
        TweenService:Create(icon, TweenInfo.new(0.2), {
            ImageTransparency = 1
        }):Play()
        
        TweenService:Create(title, TweenInfo.new(0.2), {
            TextTransparency = 1
        }):Play()
        
        TweenService:Create(content, TweenInfo.new(0.2), {
            TextTransparency = 1
        }):Play()
        
        TweenService:Create(closeIcon, TweenInfo.new(0.2), {
            ImageTransparency = 1
        }):Play()
        
        task.wait(0.3)
        notification:Destroy()
    end
    
    -- 关闭按钮事件
    ConnectionManager:Add(closeBtn.MouseButton1Click, Close)
    
    -- 自动关闭
    if lifeTime > 0 then
        task.delay(lifeTime, Close)
    end
    
    -- 悬停效果
    AddHoverEffect(closeBtn, Color3.new(0, 0, 0), Color3.fromRGB(40, 40, 40), Color3.fromRGB(60, 60, 60))
    
    return {
        Close = Close,
        Instance = notification
    }
end

-- 窗口系统
function OrionLib:MakeWindow(windowConfig)
    windowConfig = windowConfig or {}
    
    -- 验证配置
    assert(windowConfig.Name, "Window name is required")
    
    local windowId = HttpService:GenerateGUID(false):sub(1, 8)
    
    -- 检查重复窗口
    if self.Windows[windowConfig.Name] then
        self.Windows[windowConfig.Name]:Destroy()
    end
    
    -- 创建主窗口
    local mainWindow = Create("Frame", {
        Name = "Window_" .. windowId,
        Parent = Orion,
        BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Main,
        Position = UDim2.new(0.5, -307, 0.5, -172),
        Size = UDim2.new(0, 615, 0, 344),
        ClipsDescendants = true,
        Active = true,
        ZIndex = 10
    })
    
    ThemeSystem:AddObject(mainWindow, "Main")
    
    -- 添加圆角和描边
    CreateCorner(10).Parent = mainWindow
    local stroke = CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 2)
    stroke.Parent = mainWindow
    ThemeSystem:AddObject(stroke, "Stroke")
    
    -- 顶部栏
    local topBar = Create("Frame", {
        Name = "TopBar",
        BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
        Size = UDim2.new(1, 0, 0, 40),
        ZIndex = 11
    }, {
        CreateCorner(10),
        CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
        CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
    })
    ThemeSystem:AddObject(topBar, "Second")
    topBar.Parent = mainWindow
    
    -- 窗口标题
    local title = CreateLabel(windowConfig.Name, 18, {
        font = Enum.Font.GothamBold,
        size = UDim2.new(0, 0, 1, 0),
        xAlignment = Enum.TextXAlignment.Left
    })
    ThemeSystem:AddObject(title, "Text")
    title.Parent = topBar
    
    -- 更新标题大小
    local function UpdateTitleSize()
        local textSize = TextService:GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(1000, 1000))
        title.Size = UDim2.new(0, textSize.X + 10, 1, 0)
    end
    UpdateTitleSize()
    ConnectionManager:Add(title:GetPropertyChangedSignal("Text"), UpdateTitleSize)
    
    -- 控制按钮容器
    local controlButtons = Create("Frame", {
        Name = "ControlButtons",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -80, 0, 0)
    }, {
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8)
        })
    })
    controlButtons.Parent = topBar
    
    -- 最小化按钮
    local minimizeBtn = CreateButton()
    minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
    minimizeBtn.ZIndex = 12
    minimizeBtn.Parent = controlButtons
    
    local minimizeIcon = CreateImage("minimize", UDim2.new(1, 0, 1, 0))
    ThemeSystem:AddObject(minimizeIcon, "Text")
    minimizeIcon.Parent = minimizeBtn
    
    -- 关闭按钮
    local closeBtn = CreateButton()
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.ZIndex = 12
    closeBtn.Parent = controlButtons
    
    local closeIcon = CreateImage("close", UDim2.new(1, 0, 1, 0))
    ThemeSystem:AddObject(closeIcon, "Text")
    closeIcon.Parent = closeBtn
    
    -- 标签容器
    local tabContainer = Create("Frame", {
        Name = "TabContainer",
        BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
        Size = UDim2.new(0, 150, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        ZIndex = 10
    }, {
        CreateCorner(10),
        CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
        CreateScrollFrame(),
        CreatePadding({top = 10, bottom = 10, left = 8, right = 8})
    })
    ThemeSystem:AddObject(tabContainer, "Second")
    tabContainer.Parent = mainWindow
    
    -- 标签滚动框
    local tabScroll = tabContainer:FindFirstChildWhichIsA("ScrollingFrame")
    if tabScroll then
        tabScroll.Size = UDim2.new(1, 0, 1, 0)
        tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabScroll.ScrollBarThickness = 3
        ThemeSystem:AddObject(tabScroll, "Divider")
    end
    
    -- 内容容器
    local contentContainer = Create("Frame", {
        Name = "ContentContainer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -150, 1, -50),
        Position = UDim2.new(0, 150, 0, 50),
        ZIndex = 10
    })
    contentContainer.Parent = mainWindow
    
    -- 底部栏
    local bottomBar = Create("Frame", {
        Name = "BottomBar",
        BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 1, -40),
        ZIndex = 10
    }, {
        CreateCorner(10),
        CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
        CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
    })
    ThemeSystem:AddObject(bottomBar, "Second")
    bottomBar.Parent = mainWindow
    
    -- 用户信息
    local userText = CreateLabel(LocalPlayer.Name, 14, {
        font = Enum.Font.GothamSemibold,
        size = UDim2.new(1, 0, 1, 0),
        xAlignment = Enum.TextXAlignment.Left
    })
    ThemeSystem:AddObject(userText, "Text")
    userText.Parent = bottomBar
    
    -- 窗口状态
    local windowState = {
        Instance = mainWindow,
        Tabs = {},
        ActiveTab = nil,
        IsMinimized = false,
        IsVisible = true,
        Elements = {}
    }
    
    -- 标签管理
    local tabManager = {}
    
    function tabManager:CreateTab(tabConfig)
        tabConfig = tabConfig or {}
        tabConfig.Name = tabConfig.Name or "Tab"
        tabConfig.Icon = tabConfig.Icon or ""
        
        local tabId = HttpService:GenerateGUID(false):sub(1, 8)
        
        -- 创建标签按钮
        local tabButton = CreateButton()
        tabButton.Size = UDim2.new(1, 0, 0, 36)
        tabButton.BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second
        tabButton.ZIndex = 11
        
        ThemeSystem:AddObject(tabButton, "Second")
        AddHoverEffect(tabButton, 
            OrionLib.Themes[self.SelectedTheme].Second,
            Color3.fromRGB(
                OrionLib.Themes[self.SelectedTheme].Second.R * 255 + 15,
                OrionLib.Themes[self.SelectedTheme].Second.G * 255 + 15,
                OrionLib.Themes[self.SelectedTheme].Second.B * 255 + 15
            )
        )
        
        CreateCorner(6).Parent = tabButton
        
        -- 标签内容
        local tabContent = Create("Frame", {
            Name = "TabContent_" .. tabId,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 150, 0, 50),
            Visible = false,
            ZIndex = 10
        }, {
            CreateScrollFrame(),
            CreatePadding({top = 15, bottom = 15, left = 15, right = 15})
        })
        tabContent.Parent = contentContainer
        
        local contentScroll = tabContent:FindFirstChildWhichIsA("ScrollingFrame")
        if contentScroll then
            contentScroll.Size = UDim2.new(1, 0, 1, 0)
            contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            contentScroll.ScrollBarThickness = 3
            ThemeSystem:AddObject(contentScroll, "Divider")
        end
        
        -- 标签布局
        local tabLayout = Create("Frame", {
            Name = "TabLayout",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0)
        }, {
            CreateListLayout(6, Enum.SortOrder.LayoutOrder)
        })
        tabLayout.Parent = tabButton
        
        -- 图标
        if tabConfig.Icon and tabConfig.Icon ~= "" then
            local icon = CreateImage(tabConfig.Icon, UDim2.new(0, 20, 0, 20))
            icon.Position = UDim2.new(0, 10, 0.5, 0)
            icon.AnchorPoint = Vector2.new(0, 0.5)
            ThemeSystem:AddObject(icon, "Text")
            icon.Parent = tabLayout
        end
        
        -- 标题
        local tabTitle = CreateLabel(tabConfig.Name, 14, {
            font = Enum.Font.GothamSemibold,
            size = UDim2.new(1, -30, 1, 0),
            position = UDim2.new(0, 30, 0, 0)
        })
        ThemeSystem:AddObject(tabTitle, "Text")
        tabTitle.Parent = tabLayout
        
        tabButton.Parent = tabScroll
        
        -- 标签功能
        local tabFunctions = {}
        
        function tabFunctions:Select()
            -- 隐藏所有标签内容
            for _, tab in pairs(windowState.Tabs) do
                if tab.Content then
                    tab.Content.Visible = false
                end
                if tab.Button then
                    TweenService:Create(tab.Button, TweenInfo.new(0.2), {
                        BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second
                    }):Play()
                end
            end
            
            -- 显示当前标签
            tabContent.Visible = true
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 30,
                    OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 30,
                    OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 30
                )
            }):Play()
            
            windowState.ActiveTab = tabId
        end
        
        -- 点击切换标签
        ConnectionManager:Add(tabButton.MouseButton1Click, function()
            tabFunctions:Select()
        end)
        
        -- 存储标签
        windowState.Tabs[tabId] = {
            Id = tabId,
            Button = tabButton,
            Content = tabContent,
            Functions = tabFunctions
        }
        
        -- 如果是第一个标签，自动选择
        if not windowState.ActiveTab then
            tabFunctions:Select()
        end
        
        -- 元素创建器
        local elementCreator = {}
        
        function elementCreator:CreateButton(buttonConfig)
            buttonConfig = buttonConfig or {}
            buttonConfig.Name = buttonConfig.Name or "Button"
            buttonConfig.Callback = buttonConfig.Callback or function() end
            
            local buttonId = HttpService:GenerateGUID(false):sub(1, 8)
            
            local buttonFrame = Create("Frame", {
                Name = "Button_" .. buttonId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(buttonFrame, "Second")
            
            local buttonLabel = CreateLabel(buttonConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, 0, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(buttonLabel, "Text")
            buttonLabel.Parent = buttonFrame
            
            local clickButton = CreateButton()
            clickButton.Parent = buttonFrame
            
            -- 悬停效果
            AddHoverEffect(buttonFrame,
                OrionLib.Themes[self.SelectedTheme].Second,
                Color3.fromRGB(
                    OrionLib.Themes[self.SelectedTheme].Second.R * 255 + 20,
                    OrionLib.Themes[self.SelectedTheme].Second.G * 255 + 20,
                    OrionLib.Themes[self.SelectedTheme].Second.B * 255 + 20
                ),
                Color3.fromRGB(
                    OrionLib.Themes[self.SelectedTheme].Second.R * 255 + 30,
                    OrionLib.Themes[self.SelectedTheme].Second.G * 255 + 30,
                    OrionLib.Themes[self.SelectedTheme].Second.B * 255 + 30
                )
            )
            
            -- 点击事件
            ConnectionManager:Add(clickButton.MouseButton1Click, function()
                local success, result = pcall(buttonConfig.Callback)
                if not success then
                    warn("Button callback error: " .. tostring(result))
                end
            end)
            
            buttonFrame.Parent = contentScroll
            
            local buttonObj = {
                Instance = buttonFrame,
                SetText = function(text)
                    buttonLabel.Text = text or ""
                end,
                SetCallback = function(callback)
                    if type(callback) == "function" then
                        buttonConfig.Callback = callback
                    end
                end
            }
            
            table.insert(windowState.Elements, buttonObj)
            return buttonObj
        end
        
        function elementCreator:CreateToggle(toggleConfig)
            toggleConfig = toggleConfig or {}
            toggleConfig.Name = toggleConfig.Name or "Toggle"
            toggleConfig.Default = toggleConfig.Default or false
            toggleConfig.Callback = toggleConfig.Callback or function() end
            toggleConfig.Flag = toggleConfig.Flag or nil
            toggleConfig.Save = toggleConfig.Save or false
            
            local toggleId = HttpService:GenerateGUID(false):sub(1, 8)
            local toggleState = toggleConfig.Default
            
            local toggleFrame = Create("Frame", {
                Name = "Toggle_" .. toggleId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(toggleFrame, "Second")
            
            local toggleLabel = CreateLabel(toggleConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, -40, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(toggleLabel, "Text")
            toggleLabel.Parent = toggleFrame
            
            -- 切换框
            local toggleBox = Create("Frame", {
                Name = "ToggleBox",
                BackgroundColor3 = toggleState and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80),
                Size = UDim2.new(0, 24, 0, 24),
                Position = UDim2.new(1, -30, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5)
            }, {
                CreateCorner(12),
                CreateStroke(toggleState and Color3.fromRGB(0, 140, 225) or Color3.fromRGB(100, 100, 100), 1)
            })
            toggleBox.Parent = toggleFrame
            
            local toggleIndicator = Create("Frame", {
                Name = "Indicator",
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = toggleState and UDim2.new(0, 10, 0, 10) or UDim2.new(0, 4, 0, 4),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5)
            }, {
                CreateCorner(5)
            })
            toggleIndicator.Parent = toggleBox
            
            local clickButton = CreateButton()
            clickButton.Parent = toggleFrame
            
            -- 更新状态
            local function UpdateState()
                TweenService:Create(toggleBox, TweenInfo.new(0.2), {
                    BackgroundColor3 = toggleState and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
                }):Play()
                
                TweenService:Create(toggleBox.UIStroke, TweenInfo.new(0.2), {
                    Color = toggleState and Color3.fromRGB(0, 140, 225) or Color3.fromRGB(100, 100, 100)
                }):Play()
                
                TweenService:Create(toggleIndicator, TweenInfo.new(0.2), {
                    Size = toggleState and UDim2.new(0, 10, 0, 10) or UDim2.new(0, 4, 0, 4)
                }):Play()
            end
            
            -- 点击事件
            ConnectionManager:Add(clickButton.MouseButton1Click, function()
                toggleState = not toggleState
                UpdateState()
                
                local success, result = pcall(toggleConfig.Callback, toggleState)
                if not success then
                    warn("Toggle callback error: " .. tostring(result))
                end
                
                if OrionLib.SaveCfg and toggleConfig.Save ~= false then
                    ConfigSystem:Save(windowConfig.Name)
                end
            end)
            
            UpdateState()
            
            local toggleObj = {
                Instance = toggleFrame,
                Value = toggleState,
                Type = "Toggle",
                Save = toggleConfig.Save,
                Set = function(value)
                    toggleState = value or false
                    UpdateState()
                end,
                Get = function()
                    return toggleState
                end
            }
            
            if toggleConfig.Flag then
                OrionLib.Flags[toggleConfig.Flag] = toggleObj
            end
            
            table.insert(windowState.Elements, toggleObj)
            toggleFrame.Parent = contentScroll
            return toggleObj
        end
        
        function elementCreator:CreateSlider(sliderConfig)
            sliderConfig = sliderConfig or {}
            sliderConfig.Name = sliderConfig.Name or "Slider"
            sliderConfig.Min = sliderConfig.Min or 0
            sliderConfig.Max = sliderConfig.Max or 100
            sliderConfig.Default = sliderConfig.Default or 50
            sliderConfig.Callback = sliderConfig.Callback or function() end
            sliderConfig.Flag = sliderConfig.Flag or nil
            sliderConfig.Save = sliderConfig.Save or false
            
            local sliderId = HttpService:GenerateGUID(false):sub(1, 8)
            local sliderValue = math.clamp(sliderConfig.Default, sliderConfig.Min, sliderConfig.Max)
            
            local sliderFrame = Create("Frame", {
                Name = "Slider_" .. sliderId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 60),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(sliderFrame, "Second")
            
            local topRow = Create("Frame", {
                Name = "TopRow",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20)
            })
            topRow.Parent = sliderFrame
            
            local sliderLabel = CreateLabel(sliderConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(0.7, 0, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(sliderLabel, "Text")
            sliderLabel.Parent = topRow
            
            local valueLabel = CreateLabel(tostring(sliderValue), 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(0.3, 0, 1, 0),
                position = UDim2.new(0.7, 0, 0, 0),
                xAlignment = Enum.TextXAlignment.Right
            })
            ThemeSystem:AddObject(valueLabel, "Text")
            valueLabel.Parent = topRow
            
            -- 滑动条背景
            local sliderBackground = Create("Frame", {
                Name = "SliderBackground",
                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                Size = UDim2.new(1, 0, 0, 4),
                Position = UDim2.new(0, 0, 1, -12),
                AnchorPoint = Vector2.new(0, 1)
            }, {
                CreateCorner(2)
            })
            sliderBackground.Parent = sliderFrame
            
            -- 滑动条填充
            local sliderFill = Create("Frame", {
                Name = "SliderFill",
                BackgroundColor3 = Color3.fromRGB(0, 170, 255),
                Size = UDim2.new((sliderValue - sliderConfig.Min) / (sliderConfig.Max - sliderConfig.Min), 0, 1, 0)
            }, {
                CreateCorner(2)
            })
            sliderFill.Parent = sliderBackground
            
            -- 滑块
            local sliderButton = Create("Frame", {
                Name = "SliderButton",
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((sliderValue - sliderConfig.Min) / (sliderConfig.Max - sliderConfig.Min), 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5)
            }, {
                CreateCorner(6),
                CreateStroke(Color3.fromRGB(100, 100, 100), 1)
            })
            sliderButton.Parent = sliderBackground
            
            local dragging = false
            
            local function UpdateSlider(value)
                sliderValue = math.clamp(value, sliderConfig.Min, sliderConfig.Max)
                local percent = (sliderValue - sliderConfig.Min) / (sliderConfig.Max - sliderConfig.Min)
                
                valueLabel.Text = string.format("%.1f", sliderValue)
                sliderFill.Size = UDim2.new(percent, 0, 1, 0)
                sliderButton.Position = UDim2.new(percent, 0, 0.5, 0)
                
                local success, result = pcall(sliderConfig.Callback, sliderValue)
                if not success then
                    warn("Slider callback error: " .. tostring(result))
                end
            end
            
            -- 鼠标事件
            local function GetSliderValue(input)
                local sliderWidth = sliderBackground.AbsoluteSize.X
                local mouseX = input.Position.X - sliderBackground.AbsolutePosition.X
                local percent = math.clamp(mouseX / sliderWidth, 0, 1)
                return sliderConfig.Min + (percent * (sliderConfig.Max - sliderConfig.Min))
            end
            
            ConnectionManager:Add(sliderBackground.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    UpdateSlider(GetSliderValue(input))
                end
            end)
            
            ConnectionManager:Add(sliderBackground.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                    if OrionLib.SaveCfg and sliderConfig.Save ~= false then
                        ConfigSystem:Save(windowConfig.Name)
                    end
                end
            end)
            
            ConnectionManager:Add(UserInputService.InputChanged, function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateSlider(GetSliderValue(input))
                end
            end)
            
            local sliderObj = {
                Instance = sliderFrame,
                Value = sliderValue,
                Type = "Slider",
                Save = sliderConfig.Save,
                Set = function(value)
                    UpdateSlider(value)
                end,
                Get = function()
                    return sliderValue
                end
            }
            
            if sliderConfig.Flag then
                OrionLib.Flags[sliderConfig.Flag] = sliderObj
            end
            
            table.insert(windowState.Elements, sliderObj)
            sliderFrame.Parent = contentScroll
            return sliderObj
        end
        
        function elementCreator:CreateDropdown(dropdownConfig)
            dropdownConfig = dropdownConfig or {}
            dropdownConfig.Name = dropdownConfig.Name or "Dropdown"
            dropdownConfig.Options = dropdownConfig.Options or {}
            dropdownConfig.Default = dropdownConfig.Default or (dropdownConfig.Options[1] or "")
            dropdownConfig.Callback = dropdownConfig.Callback or function() end
            dropdownConfig.Flag = dropdownConfig.Flag or nil
            dropdownConfig.Save = dropdownConfig.Save or false
            
            local dropdownId = HttpService:GenerateGUID(false):sub(1, 8)
            local dropdownOpen = false
            local selectedValue = dropdownConfig.Default
            
            local dropdownFrame = Create("Frame", {
                Name = "Dropdown_" .. dropdownId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren(),
                ClipsDescendants = true
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(dropdownFrame, "Second")
            
            local dropdownLabel = CreateLabel(dropdownConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, -40, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(dropdownLabel, "Text")
            dropdownLabel.Parent = dropdownFrame
            
            local dropdownIcon = CreateImage("dropdown", UDim2.new(0, 20, 0, 20), {
                position = UDim2.new(1, -25, 0.5, 0),
                anchorPoint = Vector2.new(1, 0.5)
            })
            ThemeSystem:AddObject(dropdownIcon, "Text")
            dropdownIcon.Parent = dropdownFrame
            
            local valueLabel = CreateLabel(selectedValue, 14, {
                font = Enum.Font.Gotham,
                size = UDim2.new(1, -40, 1, 0),
                xAlignment = Enum.TextXAlignment.Right
            })
            ThemeSystem:AddObject(valueLabel, "TextDark")
            valueLabel.Parent = dropdownFrame
            
            -- 选项容器
            local optionsFrame = Create("Frame", {
                Name = "OptionsContainer",
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Main,
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 1, 2),
                Visible = false,
                ClipsDescendants = true
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreateScrollFrame(),
                CreatePadding({top = 4, bottom = 4, left = 4, right = 4})
            })
            ThemeSystem:AddObject(optionsFrame, "Main")
            optionsFrame.Parent = dropdownFrame
            
            local optionsScroll = optionsFrame:FindFirstChildWhichIsA("ScrollingFrame")
            if optionsScroll then
                optionsScroll.Size = UDim2.new(1, 0, 1, 0)
                optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
                optionsScroll.ScrollBarThickness = 3
                ThemeSystem:AddObject(optionsScroll, "Divider")
            end
            
            local clickButton = CreateButton()
            clickButton.Parent = dropdownFrame
            
            local function UpdateOptions()
                -- 清空现有选项
                if optionsScroll then
                    for _, child in ipairs(optionsScroll:GetChildren()) do
                        if child:IsA("Frame") then
                            child:Destroy()
                        end
                    end
                end
                
                -- 创建新选项
                for i, option in ipairs(dropdownConfig.Options) do
                    local optionButton = Create("Frame", {
                        Name = "Option_" .. i,
                        BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                        Size = UDim2.new(1, 0, 0, 30),
                        LayoutOrder = i
                    }, {
                        CreateCorner(4),
                        CreatePadding({top = 4, bottom = 4, left = 8, right = 8})
                    })
                    ThemeSystem:AddObject(optionButton, "Second")
                    
                    local optionLabel = CreateLabel(option, 14, {
                        font = Enum.Font.Gotham,
                        size = UDim2.new(1, 0, 1, 0),
                        xAlignment = Enum.TextXAlignment.Left
                    })
                    ThemeSystem:AddObject(optionLabel, "Text")
                    optionLabel.Parent = optionButton
                    
                    local optionClick = CreateButton()
                    optionClick.Parent = optionButton
                    
                    -- 悬停效果
                    AddHoverEffect(optionButton,
                        OrionLib.Themes[self.SelectedTheme].Second,
                        Color3.fromRGB(
                            OrionLib.Themes[self.SelectedTheme].Second.R * 255 + 20,
                            OrionLib.Themes[self.SelectedTheme].Second.G * 255 + 20,
                            OrionLib.Themes[self.SelectedTheme].Second.B * 255 + 20
                        )
                    )
                    
                    -- 选择选项
                    ConnectionManager:Add(optionClick.MouseButton1Click, function()
                        selectedValue = option
                        valueLabel.Text = selectedValue
                        dropdownOpen = false
                        
                        TweenService:Create(dropdownFrame, TweenInfo.new(0.2), {
                            Size = UDim2.new(1, 0, 0, 36)
                        }):Play()
                        
                        TweenService:Create(optionsFrame, TweenInfo.new(0.2), {
                            Size = UDim2.new(1, 0, 0, 0)
                        }):Play()
                        
                        task.wait(0.2)
                        optionsFrame.Visible = false
                        
                        local success, result = pcall(dropdownConfig.Callback, selectedValue)
                        if not success then
                            warn("Dropdown callback error: " .. tostring(result))
                        end
                        
                        if OrionLib.SaveCfg and dropdownConfig.Save ~= false then
                            ConfigSystem:Save(windowConfig.Name)
                        end
                    end)
                    
                    optionButton.Parent = optionsScroll
                end
            end
            
            -- 切换下拉菜单
            ConnectionManager:Add(clickButton.MouseButton1Click, function()
                dropdownOpen = not dropdownOpen
                
                if dropdownOpen then
                    UpdateOptions()
                    optionsFrame.Visible = true
                    
                    local optionCount = math.min(#dropdownConfig.Options, 5)
                    local optionsHeight = optionCount * 30 + 8
                    
                    TweenService:Create(dropdownFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 36 + optionsHeight + 4)
                    }):Play()
                    
                    TweenService:Create(optionsFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, optionsHeight)
                    }):Play()
                    
                    TweenService:Create(dropdownIcon, TweenInfo.new(0.2), {
                        Rotation = 180
                    }):Play()
                else
                    TweenService:Create(dropdownFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 36)
                    }):Play()
                    
                    TweenService:Create(optionsFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 0)
                    }):Play()
                    
                    TweenService:Create(dropdownIcon, TweenInfo.new(0.2), {
                        Rotation = 0
                    }):Play()
                    
                    task.wait(0.2)
                    optionsFrame.Visible = false
                end
            end)
            
            UpdateOptions()
            
            local dropdownObj = {
                Instance = dropdownFrame,
                Value = selectedValue,
                Options = dropdownConfig.Options,
                Type = "Dropdown",
                Save = dropdownConfig.Save,
                Set = function(value)
                    if table.find(dropdownConfig.Options, value) then
                        selectedValue = value
                        valueLabel.Text = selectedValue
                    end
                end,
                Get = function()
                    return selectedValue
                end,
                Refresh = function(options)
                    dropdownConfig.Options = options or {}
                    UpdateOptions()
                end
            }
            
            if dropdownConfig.Flag then
                OrionLib.Flags[dropdownConfig.Flag] = dropdownObj
            end
            
            table.insert(windowState.Elements, dropdownObj)
            dropdownFrame.Parent = contentScroll
            return dropdownObj
        end
        
        function elementCreator:CreateLabel(labelConfig)
            labelConfig = labelConfig or {}
            labelConfig.Text = labelConfig.Text or "Label"
            
            local labelId = HttpService:GenerateGUID(false):sub(1, 8)
            
            local labelFrame = Create("Frame", {
                Name = "Label_" .. labelId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 30),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(labelFrame, "Second")
            
            local label = CreateLabel(labelConfig.Text, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, 0, 1, 0),
                xAlignment = labelConfig.Alignment or Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(label, "Text")
            label.Parent = labelFrame
            
            local labelObj = {
                Instance = labelFrame,
                SetText = function(text)
                    label.Text = text or ""
                end
            }
            
            table.insert(windowState.Elements, labelObj)
            labelFrame.Parent = contentScroll
            return labelObj
        end
        
        function elementCreator:CreateTextBox(textboxConfig)
            textboxConfig = textboxConfig or {}
            textboxConfig.Name = textboxConfig.Name or "TextBox"
            textboxConfig.Placeholder = textboxConfig.Placeholder or "Enter text..."
            textboxConfig.Default = textboxConfig.Default or ""
            textboxConfig.Callback = textboxConfig.Callback or function() end
            
            local textboxId = HttpService:GenerateGUID(false):sub(1, 8)
            
            local textboxFrame = Create("Frame", {
                Name = "Textbox_" .. textboxId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(textboxFrame, "Second")
            
            local textboxLabel = CreateLabel(textboxConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, 0, 0, 16),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(textboxLabel, "Text")
            textboxLabel.Parent = textboxFrame
            
            local textbox = CreateTextBox(textboxConfig.Placeholder, {
                text = textboxConfig.Default,
                color = OrionLib.Themes[self.SelectedTheme].Text,
                placeholderColor = OrionLib.Themes[self.SelectedTheme].TextDark,
                size = 14,
                font = Enum.Font.Gotham,
                sizeUDim2 = UDim2.new(1, 0, 0, 20),
                position = UDim2.new(0, 0, 1, -20)
            })
            ThemeSystem:AddObject(textbox, "Text")
            textbox.Parent = textboxFrame
            
            ConnectionManager:Add(textbox.FocusLost, function(enterPressed)
                local success, result = pcall(textboxConfig.Callback, textbox.Text, enterPressed)
                if not success then
                    warn("Textbox callback error: " .. tostring(result))
                end
            end)
            
            local textboxObj = {
                Instance = textboxFrame,
                Value = textboxConfig.Default,
                SetText = function(text)
                    textbox.Text = text or ""
                    textbox.Value = text or ""
                end,
                GetText = function()
                    return textbox.Text
                end
            }
            
            table.insert(windowState.Elements, textboxObj)
            textboxFrame.Parent = contentScroll
            return textboxObj
        end
        
        function elementCreator:CreateColorpicker(colorpickerConfig)
            colorpickerConfig = colorpickerConfig or {}
            colorpickerConfig.Name = colorpickerConfig.Name or "Colorpicker"
            colorpickerConfig.Default = colorpickerConfig.Default or Color3.new(1, 1, 1)
            colorpickerConfig.Callback = colorpickerConfig.Callback or function() end
            colorpickerConfig.Flag = colorpickerConfig.Flag or nil
            colorpickerConfig.Save = colorpickerConfig.Save or false
            
            local colorpickerId = HttpService:GenerateGUID(false):sub(1, 8)
            local colorOpen = false
            local currentColor = colorpickerConfig.Default
            
            local colorpickerFrame = Create("Frame", {
                Name = "Colorpicker_" .. colorpickerId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren(),
                ClipsDescendants = true
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(colorpickerFrame, "Second")
            
            local colorpickerLabel = CreateLabel(colorpickerConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, -60, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(colorpickerLabel, "Text")
            colorpickerLabel.Parent = colorpickerFrame
            
            -- 颜色预览
            local colorPreview = Create("Frame", {
                Name = "ColorPreview",
                BackgroundColor3 = currentColor,
                Size = UDim2.new(0, 40, 0, 20),
                Position = UDim2.new(1, -45, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5)
            }, {
                CreateCorner(4),
                CreateStroke(Color3.new(1, 1, 1), 1)
            })
            colorPreview.Parent = colorpickerFrame
            
            local clickButton = CreateButton()
            clickButton.Parent = colorpickerFrame
            
            -- 颜色选择器面板
            local colorPanel = Create("Frame", {
                Name = "ColorPanel",
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Main,
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 1, 2),
                Visible = false,
                ClipsDescendants = true
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 12, bottom = 12, left = 12, right = 12})
            })
            ThemeSystem:AddObject(colorPanel, "Main")
            colorPanel.Parent = colorpickerFrame
            
            -- 颜色值输入
            local hexInput = CreateTextBox("Hex Color", {
                text = string.format("#%02X%02X%02X", 
                    math.floor(currentColor.R * 255),
                    math.floor(currentColor.G * 255),
                    math.floor(currentColor.B * 255)
                ),
                size = 14,
                sizeUDim2 = UDim2.new(1, 0, 0, 30)
            })
            ThemeSystem:AddObject(hexInput, "Text")
            hexInput.Parent = colorPanel
            
            -- 切换颜色面板
            ConnectionManager:Add(clickButton.MouseButton1Click, function()
                colorOpen = not colorOpen
                
                if colorOpen then
                    colorPanel.Visible = true
                    TweenService:Create(colorpickerFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 36 + 54)
                    }):Play()
                    
                    TweenService:Create(colorPanel, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 54)
                    }):Play()
                else
                    TweenService:Create(colorpickerFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 36)
                    }):Play()
                    
                    TweenService:Create(colorPanel, TweenInfo.new(0.2), {
                        Size = UDim2.new(1, 0, 0, 0)
                    }):Play()
                    
                    task.wait(0.2)
                    colorPanel.Visible = false
                end
            end)
            
            -- HEX输入处理
            ConnectionManager:Add(hexInput.FocusLost, function()
                local hex = hexInput.Text:gsub("#", "")
                if #hex == 6 then
                    local r = tonumber(hex:sub(1, 2), 16) or 255
                    local g = tonumber(hex:sub(3, 4), 16) or 255
                    local b = tonumber(hex:sub(5, 6), 16) or 255
                    
                    currentColor = Color3.fromRGB(r, g, b)
                    colorPreview.BackgroundColor3 = currentColor
                    
                    local success, result = pcall(colorpickerConfig.Callback, currentColor)
                    if not success then
                        warn("Colorpicker callback error: " .. tostring(result))
                    end
                    
                    if OrionLib.SaveCfg and colorpickerConfig.Save ~= false then
                        ConfigSystem:Save(windowConfig.Name)
                    end
                end
            end)
            
            local colorpickerObj = {
                Instance = colorpickerFrame,
                Value = currentColor,
                Type = "Colorpicker",
                Save = colorpickerConfig.Save,
                Set = function(color)
                    currentColor = color or Color3.new(1, 1, 1)
                    colorPreview.BackgroundColor3 = currentColor
                    hexInput.Text = string.format("#%02X%02X%02X", 
                        math.floor(currentColor.R * 255),
                        math.floor(currentColor.G * 255),
                        math.floor(currentColor.B * 255)
                    )
                end,
                Get = function()
                    return currentColor
                end
            }
            
            if colorpickerConfig.Flag then
                OrionLib.Flags[colorpickerConfig.Flag] = colorpickerObj
            end
            
            table.insert(windowState.Elements, colorpickerObj)
            colorpickerFrame.Parent = contentScroll
            return colorpickerObj
        end
        
        function elementCreator:CreateKeybind(keybindConfig)
            keybindConfig = keybindConfig or {}
            keybindConfig.Name = keybindConfig.Name or "Keybind"
            keybindConfig.Default = keybindConfig.Default or Enum.KeyCode.Unknown
            keybindConfig.Callback = keybindConfig.Callback or function() end
            keybindConfig.Flag = keybindConfig.Flag or nil
            keybindConfig.Save = keybindConfig.Save or false
            
            local keybindId = HttpService:GenerateGUID(false):sub(1, 8)
            local currentKey = keybindConfig.Default
            local listening = false
            
            local keybindFrame = Create("Frame", {
                Name = "Keybind_" .. keybindId,
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Second,
                Size = UDim2.new(1, 0, 0, 36),
                LayoutOrder = #tabContent:GetChildren()
            }, {
                CreateCorner(6),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1),
                CreatePadding({top = 8, bottom = 8, left = 12, right = 12})
            })
            ThemeSystem:AddObject(keybindFrame, "Second")
            
            local keybindLabel = CreateLabel(keybindConfig.Name, 14, {
                font = Enum.Font.GothamSemibold,
                size = UDim2.new(1, -100, 1, 0),
                xAlignment = Enum.TextXAlignment.Left
            })
            ThemeSystem:AddObject(keybindLabel, "Text")
            keybindLabel.Parent = keybindFrame
            
            local keybindButton = Create("TextButton", {
                Name = "KeybindButton",
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Main,
                TextColor3 = OrionLib.Themes[self.SelectedTheme].Text,
                TextSize = 14,
                Font = Enum.Font.Gotham,
                Text = tostring(currentKey.Name):gsub("Enum.KeyCode.", ""),
                Size = UDim2.new(0, 80, 0, 24),
                Position = UDim2.new(1, -85, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                AutoButtonColor = false
            }, {
                CreateCorner(4),
                CreateStroke(OrionLib.Themes[self.SelectedTheme].Stroke, 1)
            })
            ThemeSystem:AddObject(keybindButton, "Main")
            ThemeSystem:AddObject(keybindButton, "Text")
            keybindButton.Parent = keybindFrame
            
            AddHoverEffect(keybindButton,
                OrionLib.Themes[self.SelectedTheme].Main,
                Color3.fromRGB(
                    OrionLib.Themes[self.SelectedTheme].Main.R * 255 + 20,
                    OrionLib.Themes[self.SelectedTheme].Main.G * 255 + 20,
                    OrionLib.Themes[self.SelectedTheme].Main.B * 255 + 20
                )
            )
            
            local function UpdateKeybind(key)
                currentKey = key
                keybindButton.Text = tostring(key.Name):gsub("Enum.KeyCode.", "")
                
                local success, result = pcall(keybindConfig.Callback, key)
                if not success then
                    warn("Keybind callback error: " .. tostring(result))
                end
                
                if OrionLib.SaveCfg and keybindConfig.Save ~= false then
                    ConfigSystem:Save(windowConfig.Name)
                end
            end
            
            ConnectionManager:Add(keybindButton.MouseButton1Click, function()
                listening = true
                keybindButton.Text = "..."
            end)
            
            ConnectionManager:Add(UserInputService.InputBegan, function(input)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    UpdateKeybind(input.KeyCode)
                end
            end)
            
            local keybindObj = {
                Instance = keybindFrame,
                Value = currentKey,
                Type = "Keybind",
                Save = keybindConfig.Save,
                Set = function(key)
                    UpdateKeybind(key)
                end,
                Get = function()
                    return currentKey
                end
            }
            
            if keybindConfig.Flag then
                OrionLib.Flags[keybindConfig.Flag] = keybindObj
            end
            
            table.insert(windowState.Elements, keybindObj)
            keybindFrame.Parent = contentScroll
            return keybindObj
        end
        
        function elementCreator:CreateSection(sectionConfig)
            sectionConfig = sectionConfig or {}
            sectionConfig.Name = sectionConfig.Name or "Section"
            
            local sectionId = HttpService:GenerateGUID(false):sub(1, 8)
            
            local sectionFrame = Create("Frame", {
                Name = "Section_" .. sectionId,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                LayoutOrder = #tabContent:GetChildren()
            })
            
            local sectionLabel = CreateLabel(sectionConfig.Name, 16, {
                font = Enum.Font.GothamBold,
                size = UDim2.new(1, 0, 0, 20),
                color = OrionLib.Themes[self.SelectedTheme].Text,
                position = UDim2.new(0, 0, 0, 10)
            })
            ThemeSystem:AddObject(sectionLabel, "Text")
            sectionLabel.Parent = sectionFrame
            
            local sectionLine = Create("Frame", {
                Name = "SectionLine",
                BackgroundColor3 = OrionLib.Themes[self.SelectedTheme].Stroke,
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 0, 35)
            })
            ThemeSystem:AddObject(sectionLine, "Stroke")
            sectionLine.Parent = sectionFrame
            
            table.insert(windowState.Elements, sectionFrame)
            sectionFrame.Parent = contentScroll
            
            return {
                Instance = sectionFrame,
                SetText = function(text)
                    sectionLabel.Text = text or ""
                end
            }
        end
        
        -- 返回元素创建器
        return elementCreator
    end
    
    -- 窗口控制功能
    function windowState:Minimize()
        if self.IsMinimized then
            -- 恢复
            TweenService:Create(self.Instance, TweenInfo.new(0.3), {
                Size = UDim2.new(0, 615, 0, 344)
            }):Play()
            minimizeIcon.Image = GetIcon("minimize")
            self.IsMinimized = false
        else
            -- 最小化
            TweenService:Create(self.Instance, TweenInfo.new(0.3), {
                Size = UDim2.new(0, 300, 0, 40)
            }):Play()
            minimizeIcon.Image = GetIcon("maximize")
            self.IsMinimized = true
        end
    end
    
    function windowState:Close()
        TweenService:Create(self.Instance, TweenInfo.new(0.3), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        
        task.wait(0.3)
        
        if windowConfig.CloseCallback then
            local success, result = pcall(windowConfig.CloseCallback)
            if not success then
                warn("Window close callback error: " .. tostring(result))
            end
        end
        
        self.Instance:Destroy()
        self.Windows[windowConfig.Name] = nil
    end
    
    function windowState:Show()
        self.Instance.Visible = true
        self.IsVisible = true
    end
    
    function windowState:Hide()
        self.Instance.Visible = false
        self.IsVisible = false
    end
    
    function windowState:Destroy()
        self:Close()
    end
    
    -- 按钮事件
    AddHoverEffect(minimizeBtn, Color3.new(0, 0, 0), Color3.fromRGB(40, 40, 40), Color3.fromRGB(60, 60, 60))
    AddHoverEffect(closeBtn, Color3.new(0, 0, 0), Color3.fromRGB(40, 40, 40), Color3.fromRGB(60, 60, 60))
    
    ConnectionManager:Add(minimizeBtn.MouseButton1Click, function()
        windowState:Minimize()
    end)
    
    ConnectionManager:Add(closeBtn.MouseButton1Click, function()
        windowState:Close()
    end)
    
    -- 使窗口可拖动
    MakeDraggable(topBar, mainWindow)
    
    -- 存储窗口
    self.Windows[windowConfig.Name] = windowState
    
    -- 配置保存
    if windowConfig.SaveConfig then
        OrionLib.SaveCfg = true
        OrionLib.Folder = windowConfig.ConfigFolder or "OrionConfig"
        
        -- 自动保存配置
        game:GetService("Players").PlayerRemoving:Connect(function()
            if OrionLib.SaveCfg then
                ConfigSystem:Save(windowConfig.Name)
            end
        end)
    end
    
    -- 返回窗口接口
    return {
        Instance = mainWindow,
        Tabs = windowState.Tabs,
        Minimize = function() windowState:Minimize() end,
        Close = function() windowState:Close() end,
        Show = function() windowState:Show() end,
        Hide = function() windowState:Hide() end,
        Destroy = function() windowState:Destroy() end,
        CreateTab = function(tabConfig)
            return tabManager:CreateTab(tabConfig)
        end,
        LoadConfig = function(configName)
            return ConfigSystem:Load(configName or windowConfig.Name)
        end,
        SaveConfig = function(configName)
            return ConfigSystem:Save(configName or windowConfig.Name)
        end
    }
end

-- 库方法
function OrionLib:MakeNotification(config)
    return NotificationSystem:Create(config)
end

function OrionLib:SetTheme(themeName)
    ThemeSystem:UpdateTheme(themeName)
end

function OrionLib:CreateTheme(name, colors)
    ThemeSystem:CreateTheme(name, colors)
end

function OrionLib:Destroy()
    ConnectionManager:DisconnectAll()
    
    for _, window in pairs(self.Windows) do
        if window and window.Destroy then
            window:Destroy()
        end
    end
    table.clear(self.Windows)
    
    table.clear(self.Flags)
    table.clear(self.ThemeObjects)
    
    if Orion and Orion.Parent then
        Orion:Destroy()
    end
end

function OrionLib:IsRunning()
    return Orion and Orion.Parent ~= nil
end

function OrionLib:GetWindow(windowName)
    return self.Windows[windowName]
end

function OrionLib:HideAll()
    for _, window in pairs(self.Windows) do
        if window and window.Hide then
            window:Hide()
        end
    end
end

function OrionLib:ShowAll()
    for _, window in pairs(self.Windows) do
        if window and window.Show then
            window:Show()
        end
    end
end

-- 添加全局热键
local uiVisible = true
ConnectionManager:Add(UserInputService.InputBegan, function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        uiVisible = not uiVisible
        if uiVisible then
            OrionLib:ShowAll()
        else
            OrionLib:HideAll()
        end
    end
end)

-- 性能监控
task.spawn(function()
    while OrionLib:IsRunning() do
        local currentTime = tick()
        Performance.UpdateCount = Performance.UpdateCount + 1
        
        if currentTime - Performance.LastUpdate >= 1 then
            Performance.FPS = Performance.UpdateCount
            Performance.UpdateCount = 0
            Performance.LastUpdate = currentTime
            
            if OrionLib.Debug then
                print(string.format("Orion UI FPS: %d", Performance.FPS))
            end
        end
        
        wait(1/60)
    end
end)

-- 内存清理
game:GetService("RunService").Heartbeat:Connect(function()
    collectgarbage("step", 64)
end)

-- 初始化通知
task.spawn(function()
    wait(1)
    OrionLib:MakeNotification({
        Name = "Orion UI Library",
        Content = string.format("Version %s loaded successfully!", OrionLib.Version),
        Time = 3
    })
end)

return OrionLib
