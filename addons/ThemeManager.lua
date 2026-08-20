local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.Folder = "LinoriaLibSettings"
ThemeManager.Library = nil
ThemeManager.DefaultTheme = "Default"
ThemeManager.BuiltInThemes = {
    ["Default"] = { 1, { FontColor = "ffffff", MainColor = "1c1c1c", AccentColor = "0055ff", BackgroundColor = "141414", OutlineColor = "323232" } },
    ["BBot"] = { 2, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414" } },
    ["Fatality"] = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
    ["Jester"] = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Mint"] = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Tokyo Night"] = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
    ["Ubuntu"] = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
    ["Quartz"] = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
}

function ThemeManager:SetLibrary(Library)
    self.Library = Library
end

function ThemeManager:BuildFolderTree()
    local Paths = {}
    local Parts = self.Folder:split("/")

    for Index = 1, #Parts do
        Paths[#Paths + 1] = table.concat(Parts, "/", 1, Index)
    end

    Paths[#Paths + 1] = self.Folder .. "/themes"
    Paths[#Paths + 1] = self.Folder .. "/settings"

    for _, Path in ipairs(Paths) do
        if not isfolder(Path) then
            makefolder(Path)
        end
    end
end

function ThemeManager:SetFolder(Folder)
    self.Folder = Folder
    self:BuildFolderTree()
end

function ThemeManager:GetCustomTheme(Name)
    if typeof(Name) ~= "string" or Name == "" then
        return nil
    end

    local FileName = Name:sub(-5) == ".json" and Name or (Name .. ".json")
    local Path = self.Folder .. "/themes/" .. FileName

    if not isfile(Path) then
        return nil
    end

    local Success, Data = pcall(HttpService.JSONDecode, HttpService, readfile(Path))
    return Success and type(Data) == "table" and Data or nil
end

function ThemeManager:ThemeUpdate()
    if not self.Library then
        return
    end

    local Options = self.Library.Options
    for _, Field in ipairs({ "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }) do
        if Options and Options[Field] then
            self.Library[Field] = Options[Field].Value
        end
    end

    if self.Library.GetDarkerColor then
        self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
    end

    self.Library:UpdateColorsUsingRegistry()
end

function ThemeManager:ApplyTheme(Name)
    if not self.Library or typeof(Name) ~= "string" then
        return
    end

    local Custom = self:GetCustomTheme(Name)
    local BuiltIn = self.BuiltInThemes[Name]
    local Scheme = Custom or (BuiltIn and BuiltIn[2])

    if not Scheme then
        return
    end

    local Options = self.Library.Options
    for Field, Hex in pairs(Scheme) do
        local Color = Color3.fromHex(Hex)
        self.Library[Field] = Color
        if Options and Options[Field] then
            Options[Field]:SetValueRGB(Color)
        end
    end

    self:ThemeUpdate()
end

function ThemeManager:SaveDefault(Name)
    self:BuildFolderTree()
    writefile(self.Folder .. "/themes/default.txt", tostring(Name or "Default"))
end

function ThemeManager:LoadDefault()
    if not self.Library then
        return
    end

    local Name = self.DefaultTheme or "Default"
    local Path = self.Folder .. "/themes/default.txt"

    if isfile(Path) then
        local Success, Value = pcall(readfile, Path)
        if Success and typeof(Value) == "string" and Value ~= "" then
            Name = Value
        end
    end

    local Options = self.Library.Options
    if self.BuiltInThemes[Name] and Options and Options.ThemeManager_ThemeList then
        Options.ThemeManager_ThemeList:SetValue(Name)
    else
        self:ApplyTheme(Name)
    end
end

function ThemeManager:SaveCustomTheme(Name)
    if not self.Library or typeof(Name) ~= "string" or Name:gsub("%s", "") == "" then
        if self.Library then
            self.Library:Notify("Invalid file name for theme (empty)", 3)
        end
        return false
    end

    self:BuildFolderTree()

    local Options = self.Library.Options
    local Theme = {}
    for _, Field in ipairs({ "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }) do
        local Value = Options and Options[Field] and Options[Field].Value or self.Library[Field]
        Theme[Field] = Value:ToHex()
    end

    local SafeName = Name:gsub("[\\/:*?\"<>|]", "_")
    writefile(self.Folder .. "/themes/" .. SafeName .. ".json", HttpService:JSONEncode(Theme))
    return true
end

function ThemeManager:ReloadCustomThemes()
    self:BuildFolderTree()

    local Output = {}
    local Success, Files = pcall(listfiles, self.Folder .. "/themes")
    if not Success or typeof(Files) ~= "table" then
        return Output
    end

    for _, File in ipairs(Files) do
        local Name = tostring(File):match("([^/\\]+)%.json$")
        if Name then
            Output[#Output + 1] = Name
        end
    end

    table.sort(Output)
    return Output
end

function ThemeManager:CreateThemeManager(Groupbox)
    assert(self.Library, "Must set ThemeManager.Library first!")

    local Options = self.Library.Options

    Groupbox:AddLabel("Background color"):AddColorPicker("BackgroundColor", { Default = self.Library.BackgroundColor })
    Groupbox:AddLabel("Main color"):AddColorPicker("MainColor", { Default = self.Library.MainColor })
    Groupbox:AddLabel("Accent color"):AddColorPicker("AccentColor", { Default = self.Library.AccentColor })
    Groupbox:AddLabel("Outline color"):AddColorPicker("OutlineColor", { Default = self.Library.OutlineColor })
    Groupbox:AddLabel("Font color"):AddColorPicker("FontColor", { Default = self.Library.FontColor })

    local Themes = {}
    for Name in pairs(self.BuiltInThemes) do
        Themes[#Themes + 1] = Name
    end
    table.sort(Themes, function(A, B)
        return self.BuiltInThemes[A][1] < self.BuiltInThemes[B][1]
    end)

    Groupbox:AddDivider()
    Groupbox:AddDropdown("ThemeManager_ThemeList", { Text = "Theme list", Values = Themes, Default = self.DefaultTheme or "Default" })
    Groupbox:AddButton("Set as default", function()
        self:SaveDefault(Options.ThemeManager_ThemeList.Value)
        self.Library:Notify(string.format("Set default theme to %q", Options.ThemeManager_ThemeList.Value))
    end)

    Options.ThemeManager_ThemeList:OnChanged(function(Value)
        self:ApplyTheme(Value)
    end)

    Groupbox:AddDivider()
    Groupbox:AddInput("ThemeManager_CustomThemeName", { Text = "Custom theme name" })
    Groupbox:AddDropdown("ThemeManager_CustomThemeList", { Text = "Custom themes", Values = self:ReloadCustomThemes(), AllowNull = true })
    Groupbox:AddDivider()

    Groupbox:AddButton("Save theme", function()
        if self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value) then
            Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
            Options.ThemeManager_CustomThemeList:SetValue(nil)
        end
    end):AddButton("Load theme", function()
        if Options.ThemeManager_CustomThemeList.Value then
            self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value)
        end
    end)

    Groupbox:AddButton("Refresh list", function()
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end)

    Groupbox:AddButton("Set as default", function()
        local Value = Options.ThemeManager_CustomThemeList.Value
        if Value and Value ~= "" then
            self:SaveDefault(Value)
            self.Library:Notify(string.format("Set default theme to %q", Value))
        end
    end)

    local function UpdateTheme()
        self:ThemeUpdate()
    end

    Options.BackgroundColor:OnChanged(UpdateTheme)
    Options.MainColor:OnChanged(UpdateTheme)
    Options.AccentColor:OnChanged(UpdateTheme)
    Options.OutlineColor:OnChanged(UpdateTheme)
    Options.FontColor:OnChanged(UpdateTheme)

    self:LoadDefault()
end

function ThemeManager:CreateGroupBox(Tab)
    assert(self.Library, "Must set ThemeManager.Library first!")
    return Tab:AddLeftGroupbox("Themes")
end

function ThemeManager:ApplyToTab(Tab)
    local Groupbox = self:CreateGroupBox(Tab)
    self:CreateThemeManager(Groupbox)
end

function ThemeManager:ApplyToGroupbox(Groupbox)
    assert(self.Library, "Must set ThemeManager.Library first!")
    self:CreateThemeManager(Groupbox)
end

ThemeManager:BuildFolderTree()
return ThemeManager
