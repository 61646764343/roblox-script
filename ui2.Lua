-- mspaint_fixed.lua
-- 说明：经过全面检查和修复的脚本。已修复的要点见文件顶部注释。

-- 主要修复：
-- 1) 使用 safeLoad 对远程加载做完整保护（pcall HttpGet、loadstring、执行）
--    并在失败时抛出带有明确信息的错误，便于快速定位问题。
-- 2) 多选下拉 SetValue 使用了实际选项文本作为键（修复英文键导致无效的问题）。
-- 3) DisabledValues 与 Values 保持一致（修复因为字符串不匹配导致无效的禁用项）。
-- 4) Label ID 唯一化，避免重复 Id 导致覆盖/冲突。
-- 5) Checkbox 的 OnChanged 事件使用兼容写法（先尝试 Toggles，再尝试 Options），避免在不同库分支上 nil 报错。
-- 6) 在访问 Options/Toggles 的成员前做存在性检查，若缺失则友好 warn，而不是直接 nil 报错。
-- 7) 保留原结构与 API 调用方式，尽量不改动你的业务逻辑，仅修复会导致运行/逻辑错误的问题。

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

-- safeLoad: 安全加载远程模块
-- 如果失败，会 error(…) 抛出明确错误信息（你可以按需把 error 改为 warn 并返回 nil 以实现非致命降级）
local function safeLoad(path)
    local url = repo .. path
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then
        error(("safeLoad: HttpGet failed for %s : %s"):format(url, tostring(body)))
    end
    if not body or body == "" then
        error(("safeLoad: empty body from %s"):format(url))
    end
    local fn, loadErr = loadstring(body)
    if not fn then
        error(("safeLoad: loadstring failed for %s : %s"):format(url, tostring(loadErr)))
    end
    local ok2, res = pcall(fn)
    if not ok2 then
        error(("safeLoad: execution failed for %s : %s"):format(url, tostring(res)))
    end
    return res
end

-- 加载库（若你希望非致命，可把 safeLoad 替换为一个返回 nil 的版本）
local Library = safeLoad("Library.lua")
local ThemeManager = safeLoad("addons/ThemeManager.lua")
local SaveManager = safeLoad("addons/SaveManager.lua")

-- 基本存在性检查（友好提示）
if type(Library) ~= "table" then
    error("Library did not return a table. Aborting.")
end
if type(ThemeManager) ~= "table" then
    error("ThemeManager did not return a table. Aborting.")
end
if type(SaveManager) ~= "table" then
    error("SaveManager did not return a table. Aborting.")
end

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "mspaint",
    Footer = "版本: 示例",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab("主界面", "user"),
    Key = Window:AddKeyTab("密钥系统"),
    ["UI Settings"] = Window:AddTab("UI设置", "settings"),
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox("组框", "boxes")

LeftGroupBox:AddToggle("MyToggle", {
    Text = "这是一个开关",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Default = true,
    Disabled = false,
    Visible = true,
    Risky = false,
    Callback = function(Value)
        print("[回调] MyToggle 更改为:", Value)
    end,
})
    :AddColorPicker("ColorPicker1", {
        Default = Color3.new(1, 0, 0),
        Title = "颜色选择器1",
        Transparency = 0,
        Callback = function(Value)
            print("[回调] 颜色已更改！", Value)
        end,
    })
    :AddColorPicker("ColorPicker2", {
        Default = Color3.new(0, 1, 0),
        Title = "颜色选择器2",
        Callback = function(Value)
            print("[回调] 颜色已更改！", Value)
        end,
    })

-- Toggles/MyToggle 绑定（若 Toggles 存在）
if Toggles and Toggles.MyToggle then
    Toggles.MyToggle:OnChanged(function()
        print("MyToggle 更改为:", Toggles.MyToggle.Value)
    end)
else
    -- 兼容性提示
    if Options and Options.MyToggle then
        Options.MyToggle:OnChanged(function()
            print("MyToggle 更改为:", Options.MyToggle.Value)
        end)
    else
        warn("Warning: MyToggle object not found in Toggles or Options. Skipping OnChanged hookup.")
    end
end

-- 建立初始状态（仅在对象存在时设置）
if Toggles and Toggles.MyToggle and Toggles.MyToggle.SetValue then
    Toggles.MyToggle:SetValue(false)
elseif Options and Options.MyToggle and Options.MyToggle.SetValue then
    Options.MyToggle:SetValue(false)
end

-- Checkbox
LeftGroupBox:AddCheckbox("MyCheckbox", {
    Text = "这是一个复选框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Default = true,
    Disabled = false,
    Visible = true,
    Risky = false,
    Callback = function(Value)
        print("[回调] MyCheckbox 更改为:", Value)
    end,
})

-- 兼容地绑定 Checkbox 的 OnChanged（有些分支将 checkbox 放在 Toggles，有些放在 Options）
if Toggles and Toggles.MyCheckbox and type(Toggles.MyCheckbox.OnChanged) == "function" then
    Toggles.MyCheckbox:OnChanged(function()
        print("MyCheckbox 更改为:", Toggles.MyCheckbox.Value)
    end)
elseif Options and Options.MyCheckbox and type(Options.MyCheckbox.OnChanged) == "function" then
    Options.MyCheckbox:OnChanged(function()
        print("MyCheckbox 更改为:", Options.MyCheckbox.Value)
    end)
else
    warn("Warning: MyCheckbox object not found or does not expose OnChanged. Skipping.")
end

local MyButton = LeftGroupBox:AddButton({
    Text = "按钮",
    Func = function()
        print("您点击了一个按钮！")
    end,
    DoubleClick = false,
    Tooltip = "这是主按钮",
    DisabledTooltip = "我已禁用！",
    Disabled = false,
    Visible = true,
    Risky = false,
})

local MyButton2 = MyButton:AddButton({
    Text = "子按钮",
    Func = function()
        print("您点击了一个子按钮！")
    end,
    DoubleClick = true,
    Tooltip = "这是子按钮",
    DisabledTooltip = "我已禁用！",
})

local MyDisabledButton = LeftGroupBox:AddButton({
    Text = "禁用按钮",
    Func = function()
        print("您竟然点击了一个禁用的按钮！")
    end,
    DoubleClick = false,
    Tooltip = "这是一个禁用按钮",
    DisabledTooltip = "我已禁用！",
    Disabled = true,
})

LeftGroupBox:AddLabel("这是一个标签")
LeftGroupBox:AddLabel("这是一个自动换行的标签！\n\n它会自动换行文本", true)
LeftGroupBox:AddLabel("这是一个暴露给Labels的标签", true, "TestLabel")

-- 唯一化 label id，避免覆盖
LeftGroupBox:AddLabel("SecondTestLabel1", {
    Text = "这是一个使用表格选项和索引创建的标签",
    DoesWrap = true,
})

LeftGroupBox:AddLabel("SecondTestLabel2", {
    Text = "这是一个不自动换行的标签",
    DoesWrap = false,
})

LeftGroupBox:AddDivider()

LeftGroupBox:AddSlider("MySlider", {
    Text = "这是我的滑块！",
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Callback = function(Value)
        print("[回调] MySlider 已更改！新值:", Value)
    end,
    Tooltip = "我是一个滑块！",
    DisabledTooltip = "我已禁用！",
    Disabled = false,
    Visible = true,
})

if Options and Options.MySlider and type(Options.MySlider.OnChanged) == "function" then
    Options.MySlider:OnChanged(function()
        print("MySlider 已更改！新值:", Options.MySlider.Value)
    end)
end

if Options and Options.MySlider and type(Options.MySlider.SetValue) == "function" then
    Options.MySlider:SetValue(3)
end

LeftGroupBox:AddSlider("MySlider2", {
    Text = "这是我的自定义显示滑块！",
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 0,
    Compact = false,
    FormatDisplayValue = function(slider, value)
        if value == slider.Max then return '全部' end
        if value == slider.Min then return '无' end
    end,
    Tooltip = "我是一个滑块！",
    DisabledTooltip = "我已禁用！",
    Disabled = false,
    Visible = true,
})

LeftGroupBox:AddInput("MyTextbox", {
    Default = "我的文本框！",
    Numeric = false,
    Finished = false,
    ClearTextOnFocus = true,
    Text = "这是一个文本框",
    Tooltip = "这是一个工具提示",
    Placeholder = "占位文本",
    Callback = function(Value)
        print("[回调] 文本已更新。新文本:", Value)
    end,
})

if Options and Options.MyTextbox and type(Options.MyTextbox.OnChanged) == "function" then
    Options.MyTextbox:OnChanged(function()
        print("文本已更新。新文本:", Options.MyTextbox.Value)
    end)
end

local DropdownGroupBox = Tabs.Main:AddRightGroupbox("下拉框")

DropdownGroupBox:AddDropdown("MyDropdown", {
    Values = { "这个", "是", "一个", "下拉框" },
    Default = 1,
    Multi = false,
    Text = "一个下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Searchable = false,
    Callback = function(Value)
        print("[回调] 下拉框已更改。新值:", Value)
    end,
    Disabled = false,
    Visible = true,
})

if Options and Options.MyDropdown and type(Options.MyDropdown.OnChanged) == "function" then
    Options.MyDropdown:OnChanged(function()
        print("下拉框已更改。新值:", Options.MyDropdown.Value)
    end)
end

if Options and Options.MyDropdown and type(Options.MyDropdown.SetValue) == "function" then
    Options.MyDropdown:SetValue("这个")
end

DropdownGroupBox:AddDropdown("MySearchableDropdown", {
    Values = { "这个", "是", "一个", "可搜索的", "下拉框" },
    Default = 1,
    Multi = false,
    Text = "一个可搜索的下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Searchable = true,
    Callback = function(Value)
        print("[回调] 下拉框已更改。新值:", Value)
    end,
    Disabled = false,
    Visible = true,
})

DropdownGroupBox:AddDropdown("MyDisplayFormattedDropdown", {
    Values = { "这个", "是", "一个", "格式化的", "下拉框" },
    Default = 1,
    Multi = false,
    Text = "一个显示格式化的下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    FormatDisplayValue = function(Value)
        if Value == "formatted" then
            return "显示格式化的"
        end
        return Value
    end,
    Searchable = false,
    Callback = function(Value)
        print("[回调] 显示格式化的下拉框已更改。新值:", Value)
    end,
    Disabled = false,
    Visible = true,
})

-- 多选下拉框：修正 SetValue 使用实际选项文本作为键
DropdownGroupBox:AddDropdown("MyMultiDropdown", {
    Values = { "这个", "是", "一个", "下拉框" },
    Default = 1,
    Multi = true,
    Text = "一个多选下拉框",
    Tooltip = "这是一个工具提示",
    Callback = function(Value)
        print("[回调] 多选下拉框已更改:")
        if Options and Options.MyMultiDropdown and Options.MyMultiDropdown.Value then
            for key, value in next, Options.MyMultiDropdown.Value do
                print(key, value)
            end
        else
            print("(无可读的 Value)")
        end
    end,
})

-- 用实际选项文本作为键（修复原来使用英文 This/is 导致无效的问题）
if Options and Options.MyMultiDropdown and type(Options.MyMultiDropdown.SetValue) == "function" then
    Options.MyMultiDropdown:SetValue({ ["这个"] = true, ["是"] = true })
end

DropdownGroupBox:AddDropdown("MyDisabledDropdown", {
    Values = { "这个", "是", "一个", "下拉框" },
    Default = 1,
    Multi = false,
    Text = "一个禁用的下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Callback = function(Value)
        print("[回调] 禁用的下拉框已更改。新值:", Value)
    end,
    Disabled = true,
    Visible = true,
})

DropdownGroupBox:AddDropdown("MyDisabledValueDropdown", {
    Values = { "这个", "是", "一个", "下拉框", "带有", "禁用的", "值" },
    -- 修复 DisabledValues 与 Values 对齐
    DisabledValues = { "禁用的" },
    Default = 1,
    Multi = false,
    Text = "一个带有禁用值的下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Callback = function(Value)
        print("[回调] 带有禁用值的下拉框已更改。新值:", Value)
    end,
    Disabled = false,
    Visible = true,
})

DropdownGroupBox:AddDropdown("MyVeryLongDropdown", {
    Values = {
        "这个","是","一个","非常","长的","下拉框","带有","很多","值","但","你","可以","看到","超过","8","个","值",
    },
    Default = 1,
    Multi = false,
    MaxVisibleDropdownItems = 12,
    Text = "一个非常长的下拉框",
    Tooltip = "这是一个工具提示",
    DisabledTooltip = "我已禁用！",
    Searchable = false,
    Callback = function(Value)
        print("[回调] 非常长的下拉框已更改。新值:", Value)
    end,
    Disabled = false,
    Visible = true,
})

DropdownGroupBox:AddDropdown("MyPlayerDropdown", {
    SpecialType = "Player",
    ExcludeLocalPlayer = true,
    Text = "一个玩家下拉框",
    Tooltip = "这是一个工具提示",
    Callback = function(Value)
        print("[回调] 玩家下拉框已更改:", Value)
    end,
})

DropdownGroupBox:AddDropdown("MyTeamDropdown", {
    SpecialType = "Team",
    Text = "一个队伍下拉框",
    Tooltip = "这是一个工具提示",
    Callback = function(Value)
        print("[回调] 队伍下拉框已更改:", Value)
    end,
})

LeftGroupBox:AddLabel("颜色"):AddColorPicker("ColorPicker", {
    Default = Color3.new(0, 1, 0),
    Title = "颜色选择器",
    Transparency = 0,
    Callback = function(Value)
        print("[回调] 颜色已更改！", Value)
    end,
})

if Options and Options.ColorPicker and type(Options.ColorPicker.OnChanged) == "function" then
    Options.ColorPicker:OnChanged(function()
        print("颜色已更改！", Options.ColorPicker.Value)
        print("透明度已更改！", Options.ColorPicker.Transparency)
    end)
end

if Options and Options.ColorPicker and type(Options.ColorPicker.SetValueRGB) == "function" then
    Options.ColorPicker:SetValueRGB(Color3.fromRGB(0, 255, 140))
end

LeftGroupBox:AddLabel("快捷键绑定"):AddKeyPicker("KeyPicker", {
    Default = "MB2",
    SyncToggleState = false,
    Mode = "Toggle",
    Text = "自动解锁保险箱",
    NoUI = false,
    Callback = function(Value)
        print("[回调] 快捷键绑定已点击！", Value)
    end,
    ChangedCallback = function(NewKey, NewModifiers)
        print("[回调] 快捷键绑定已更改！", NewKey, table.unpack(NewModifiers or {}))
    end,
})

if Options and Options.KeyPicker and type(Options.KeyPicker.OnClick) == "function" then
    Options.KeyPicker:OnClick(function()
        print("快捷键绑定已点击！", Options.KeyPicker:GetState())
    end)
end

if Options and Options.KeyPicker and type(Options.KeyPicker.OnChanged) == "function" then
    Options.KeyPicker:OnChanged(function()
        print("快捷键绑定已更改！", Options.KeyPicker.Value, table.unpack(Options.KeyPicker.Modifiers or {}))
    end)
end

-- 监听 KeyPicker 状态（若存在）
if Options and Options.KeyPicker then
    task.spawn(function()
        while task.wait(1) do
            if Options.KeyPicker.GetState and Options.KeyPicker:GetState() then
                print("KeyPicker正被按住")
            end
            if Library.Unloaded then break end
        end
    end)

    if type(Options.KeyPicker.SetValue) == "function" then
        Options.KeyPicker:SetValue({ "MB2", "Hold" })
    end
end

local KeybindNumber = 0

LeftGroupBox:AddLabel("按下快捷键绑定"):AddKeyPicker("KeyPicker2", {
    Default = "X",
    Mode = "Press",
    WaitForCallback = false,
    Text = "增加数字",
    Callback = function()
        KeybindNumber = KeybindNumber + 1
        print("[回调] 快捷键绑定已点击！数字增加到:", KeybindNumber)
    end
})

local LeftGroupBox2 = Tabs.Main:AddLeftGroupbox("组框 #2")
LeftGroupBox2:AddLabel(
    "这个标签跨越多行！我们将用完UI空间...\n开玩笑的！向下滚动！\n\n\n从下面向您问好！",
    true
)

local TabBox = Tabs.Main:AddRightTabbox()
local Tab1 = TabBox:AddTab("选项卡 1")
Tab1:AddToggle("Tab1Toggle", { Text = "选项卡1开关" })

local Tab2 = TabBox:AddTab("选项卡 2")
Tab2:AddToggle("Tab2Toggle", { Text = "选项卡2开关" })

Library:OnUnload(function()
    print("已卸载！")
end)

Tabs.Key:AddLabel({
    Text = "密钥: Banana",
    DoesWrap = true,
    Size = 16,
})

Tabs.Key:AddKeyBox("Banana", function(Success, ReceivedKey)
    print("预期密钥: Banana - 收到密钥:", ReceivedKey, "| 成功:", Success)
    Library:Notify({
        Title = "预期密钥: Banana",
        Description = "收到密钥: " .. ReceivedKey .. "\n成功: " .. tostring(Success),
        Time = 4,
    })
end)

Tabs.Key:AddLabel({
    Text = "无密钥",
    DoesWrap = true,
    Size = 16,
})

Tabs.Key:AddKeyBox(function(Success, ReceivedKey)
    print("预期密钥: 无 | 成功:", Success)
    Library:Notify("成功: " .. tostring(Success), 4)
end)

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("菜单", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = (Library.KeybindFrame and Library.KeybindFrame.Visible) or false,
    Text = "打开快捷键绑定菜单",
    Callback = function(value)
        if Library.KeybindFrame then Library.KeybindFrame.Visible = value end
    end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "自定义光标",
    Default = true,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})
MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "通知显示位置",
    Callback = function(Value)
        if Library.SetNotifySide then Library:SetNotifySide(Value) end
    end,
})
MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI缩放比例",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        if DPI and Library.SetDPIScale then Library:SetDPIScale(DPI) end
    end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("菜单快捷键绑定")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "菜单快捷键绑定" })

MenuGroup:AddButton("卸载", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options and Options.MenuKeybind or nil

-- 插件管理
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- 忽略 Theme 设置以避免配置污染
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

-- 文件夹设置（可选）
ThemeManager:SetFolder("我的脚本中心")
SaveManager:SetFolder("我的脚本中心/特定游戏")
SaveManager:SetSubFolder("特定地点")

-- 构建界面（存在这些方法时调用）
if SaveManager.BuildConfigSection then
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
end
if ThemeManager.ApplyToTab then
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
end

-- 自动加载配置（若存在）
if SaveManager.LoadAutoloadConfig then
    SaveManager:LoadAutoloadConfig()
end

-- 完成
print("mspaint_fixed.lua loaded — 修复点已应用。")
