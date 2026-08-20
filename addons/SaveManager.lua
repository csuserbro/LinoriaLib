local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage) 
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            return (if success then data else false)
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            return (if success then data else false)
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            return (if success then data else {})
        end
    end
end

local SaveManager = {} do
    SaveManager.Folder = "LinoriaLibSettings"
    SaveManager.SubFolder = ""
    SaveManager.Ignore = {}
    SaveManager.Library = nil
    SaveManager.Positions = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = 'Toggle', idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Toggles[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValue({ data.key, data.mode, data.modifiers })
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.text and type(data.text) == 'string' then
                    SaveManager.Library.Options[idx]:SetValue(data.text)
                end
            end,
        },
        PlayerManager = {
            Save = function(idx, object)
                local function encode(value)
                    if typeof(value) == 'Color3' then
                        return { __linoriaType = 'Color3', value = value:ToHex() }
                    elseif type(value) == 'table' then
                        local out = {}
                        for key, item in pairs(value) do
                            out[key] = encode(item)
                        end
                        return out
                    end
                    return value
                end
                return {
                    type = 'PlayerManager',
                    idx = idx,
                    states = encode(object:GetStates())
                }
            end,
            Load = function(idx, data)
                local function decode(value)
                    if type(value) == 'table' then
                        if value.__linoriaType == 'Color3' and type(value.value) == 'string' then
                            local ok, color = pcall(Color3.fromHex, value.value)
                            return ok and color or Color3.new(1, 1, 1)
                        end
                        local out = {}
                        for key, item in pairs(value) do
                            out[key] = decode(item)
                        end
                        return out
                    end
                    return value
                end
                local object = SaveManager.Library.Options[idx]
                if object and object.SetStates then
                    object:SetStates(decode(type(data.states) == 'table' and data.states or {}))
                end
            end,
        },
    }

    function SaveManager:GetViewportSize()
        local camera = workspace.CurrentCamera
        local size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        if size.X <= 0 or size.Y <= 0 then
            return Vector2.new(1920, 1080)
        end
        return size
    end

    function SaveManager:RegisterPosition(idx, getPosition, setPosition, getSize, padding)
        assert(typeof(idx) == 'string' and idx ~= '', 'RegisterPosition -> idx must be a non-empty string')
        assert(typeof(getPosition) == 'function', 'RegisterPosition -> getPosition must be a function')
        assert(typeof(setPosition) == 'function', 'RegisterPosition -> setPosition must be a function')
        self.Positions[idx] = {
            Get = getPosition,
            Set = setPosition,
            Size = typeof(getSize) == 'function' and getSize or nil,
            Padding = tonumber(padding) or 0,
        }
        return self.Positions[idx]
    end

    function SaveManager:UnregisterPosition(idx)
        self.Positions[idx] = nil
    end

    function SaveManager:GetPositionData(entry)
        local okPosition, position = pcall(entry.Get)
        if not okPosition or typeof(position) ~= 'Vector2' then
            return nil
        end

        local size = Vector2.zero
        if entry.Size then
            local okSize, value = pcall(entry.Size)
            if okSize and typeof(value) == 'Vector2' then
                size = value
            end
        end

        local viewport = self:GetViewportSize()
        local padding = math.max(entry.Padding, 0)
        local spanX = math.max(viewport.X - size.X - padding * 2, 1)
        local spanY = math.max(viewport.Y - size.Y - padding * 2, 1)
        local x = math.clamp((position.X - padding) / spanX, 0, 1)
        local y = math.clamp((position.Y - padding) / spanY, 0, 1)

        return { x = x, y = y }
    end

    function SaveManager:ApplyPositionData(entry, data)
        if type(data) ~= 'table' or type(data.x) ~= 'number' or type(data.y) ~= 'number' then
            return
        end

        local size = Vector2.zero
        if entry.Size then
            local okSize, value = pcall(entry.Size)
            if okSize and typeof(value) == 'Vector2' then
                size = value
            end
        end

        local viewport = self:GetViewportSize()
        local padding = math.max(entry.Padding, 0)
        local spanX = math.max(viewport.X - size.X - padding * 2, 1)
        local spanY = math.max(viewport.Y - size.Y - padding * 2, 1)
        local position = Vector2.new(
            padding + math.clamp(data.x, 0, 1) * spanX,
            padding + math.clamp(data.y, 0, 1) * spanY
        )

        pcall(entry.Set, position)
    end

    function SaveManager:SetLibrary(library)
        self.Library = library
        library.SaveManager = self

        self:RegisterPosition('LibraryWindow', function()
            local holder = library.Window and library.Window.Holder
            return holder and holder.AbsolutePosition or nil
        end, function(position)
            local holder = library.Window and library.Window.Holder
            if holder then
                local target = Vector2.new(
                    position.X + holder.AbsoluteSize.X * holder.AnchorPoint.X,
                    position.Y + holder.AbsoluteSize.Y * holder.AnchorPoint.Y
                )
                if library.ConstrainDraggableWindow then
                    target = library:ConstrainDraggableWindow(holder, target)
                end
                holder.Position = UDim2.fromOffset(target.X, target.Y)
            end
        end, function()
            local holder = library.Window and library.Window.Holder
            return holder and holder.AbsoluteSize or Vector2.zero
        end, 4)

        self:RegisterPosition('KeybindMenu', function()
            local holder = library.KeybindFrame
            return holder and holder.AbsolutePosition or nil
        end, function(position)
            local holder = library.KeybindFrame
            if holder then
                local target = Vector2.new(
                    position.X + holder.AbsoluteSize.X * holder.AnchorPoint.X,
                    position.Y + holder.AbsoluteSize.Y * holder.AnchorPoint.Y
                )
                if library.ConstrainDraggableWindow then
                    target = library:ConstrainDraggableWindow(holder, target)
                end
                holder.Position = UDim2.fromOffset(target.X, target.Y)
            end
        end, function()
            local holder = library.KeybindFrame
            return holder and holder.AbsoluteSize or Vector2.zero
        end, 4)

        self:RegisterPosition('Watermark', function()
            local holder = library.Watermark
            return holder and holder.AbsolutePosition or nil
        end, function(position)
            local holder = library.Watermark
            if holder then
                local target = Vector2.new(
                    position.X + holder.AbsoluteSize.X * holder.AnchorPoint.X,
                    position.Y + holder.AbsoluteSize.Y * holder.AnchorPoint.Y
                )
                if library.ConstrainDraggableWindow then
                    target = library:ConstrainDraggableWindow(holder, target)
                end
                holder.Position = UDim2.fromOffset(target.X, target.Y)
            end
        end, function()
            local holder = library.Watermark
            return holder and holder.AbsoluteSize or Vector2.zero
        end, 4)

        for idx, provider in pairs(library.FloatingPositionProviders or {}) do
            if type(provider) == 'table' and typeof(provider.Get) == 'function' and typeof(provider.Set) == 'function' then
                self:RegisterPosition(idx .. 'Window', provider.Get, provider.Set, provider.Size, provider.Padding)
            end
        end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
            "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
            "VideoLink",
        })
    end

    --// Folders \\--
    function SaveManager:CheckSubFolder(createFolder)
        if typeof(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end

        if createFolder == true then
            if not isfolder(self.Folder .. "/settings/" .. self.SubFolder) then
                makefolder(self.Folder .. "/settings/" .. self.SubFolder)
            end
        end

        return true
    end

    function SaveManager:GetPaths()
        local paths = {}

        local parts = self.Folder:split('/')
        for idx = 1, #parts do
            local path = table.concat(parts, '/', 1, idx)
            if not table.find(paths, path) then paths[#paths + 1] = path end
        end

        paths[#paths + 1] = self.Folder .. '/themes'
        paths[#paths + 1] = self.Folder .. '/settings'

        if self:CheckSubFolder(false) then
            local subFolder = self.Folder .. "/settings/" .. self.SubFolder
            parts = subFolder:split('/')

            for idx = 1, #parts do
                local path = table.concat(parts, '/', 1, idx)
                if not table.find(paths, path) then paths[#paths + 1] = path end
            end
        end

        return paths
    end

    function SaveManager:BuildFolderTree()
        local paths = self:GetPaths()

        for i = 1, #paths do
            local str = paths[i]
            if isfolder(str) then continue end

            makefolder(str)
        end
    end

    function SaveManager:CheckFolderTree()
        if isfolder(self.Folder) then return end
        SaveManager:BuildFolderTree()

        task.wait(0.1)
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder;
        self:BuildFolderTree()
    end

    --// Save, Load, Delete, Refresh \\--
    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            fullPath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        local data = {
            objects = {},
            positions = {}
        }

        for idx, toggle in next, self.Library.Toggles do
            if toggle.Transient then continue end
            if not toggle.Type then continue end
            if not self.Parser[toggle.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, self.Library.Options do
            if option.Transient then continue end
            if not option.Type then continue end
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end

        for idx, entry in next, self.Positions do
            if self.Ignore[idx] then continue end
            local positionData = self:GetPositionData(entry)
            if positionData then
                data.positions[idx] = positionData
            end
        end

        local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not success then return false, 'decode error' end

        for _, option in next, decoded.objects or {} do
            if not option.type then continue end
            if not self.Parser[option.type] then continue end
            if self.Ignore[option.idx] then continue end

            task.spawn(self.Parser[option.type].Load, option.idx, option) -- task.spawn() so the config loading wont get stuck.
        end

        for idx, positionData in next, decoded.positions or {} do
            local entry = self.Positions[idx]
            if entry and not self.Ignore[idx] then
                self:ApplyPositionData(entry, positionData)
            end
        end

        return true
    end

    function SaveManager:Delete(name)
        if (not name) then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success = pcall(delfile, file)
        if not success then return false, 'delete file error' end

        return true
    end

    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            SaveManager:CheckFolderTree()

            local list = {}
            local out = {}

            if SaveManager:CheckSubFolder(true) then
                list = listfiles(self.Folder .. "/settings/" .. self.SubFolder)
            else
                list = listfiles(self.Folder .. "/settings")
            end
            if typeof(list) ~= "table" then list = {} end

            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then
                    -- i hate this but it has to be done ...

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end

            return out
        end)

        if (not success) then
            if self.Library then
                self.Library:Notify('Failed to load config list: ' .. tostring(data))
            else
                warn('Failed to load config list: ' .. tostring(data))
            end

            return {}
        end

        return data
    end

    --// Auto Load \\--
    function SaveManager:GetAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                return "none"
            end

            name = tostring(name)
            return if name == "" then "none" else name
        end

        return "none"
    end

    function SaveManager:LoadAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                self.Library:Notify('Failed to load autoload config: write file error')
                return
            end

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:SaveAutoloadConfig(name)
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(writefile, autoLoadPath, name)
        if not success then return false, 'write file error' end

        return true, ""
    end

    function SaveManager:DeleteAutoLoadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(delfile, autoLoadPath)
        if not success then return false, 'delete file error' end

        return true, ""
    end

    --// GUI \\--
    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'SaveManager:BuildConfigSection -> Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
        section:AddButton('Create config', function()
            local name = self.Library.Options.SaveManager_ConfigName.Value

            if name:gsub(' ', '') == '' then
                self.Library:Notify('Invalid config name (empty)', 2)
                return
            end

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to create config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Created config %q', name))

            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddDivider()

        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
        section:AddButton('Load config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Loaded config %q', name))
        end)
        section:AddButton('Overwrite config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to overwrite config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Overwrote config %q', name))
        end)

        section:AddButton('Delete config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Delete(name)
            if not success then
                self.Library:Notify('Failed to delete config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Deleted config %q', name))
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Refresh list', function()
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Set as autoload', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:SaveAutoloadConfig(name)
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Set %q to auto load', name))
            self.AutoloadConfigLabel:SetText('Current autoload config: ' .. name)
        end)
        section:AddButton('Reset autoload', function()
            local success, err = self:DeleteAutoLoadConfig()
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify('Set autoload to none')
            self.AutoloadConfigLabel:SetText('Current autoload config: none')
        end)

        self.AutoloadConfigLabel = section:AddLabel("Current autoload config: " .. self:GetAutoloadConfig(), true)

        -- self:LoadAutoloadConfig()
        self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager
