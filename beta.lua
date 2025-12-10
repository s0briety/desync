-- Class addon --

local function class(base, init)
    local c = {}
    if base then
        for i, v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end
    c.__index = c
    local mt = {}
    mt.__call = function(class_tbl, ...)
        local obj = {}
        setmetatable(obj, c)
        local ctor = class_tbl.init or init or (base and base.init)
        if ctor then ctor(obj, ...) end
        return obj
    end
    c.init = init
    setmetatable(c, mt)
    return c
end   

-- Begin script --

local Services = {
    RunService = game:GetService("RunService"),
    HTTPService = game:GetService("HttpService"),
    TeleportService = game:GetService("TeleportService"),
    MarketplaceService = game:GetService("MarketplaceService"),
}

-- Hooking --

local Hook = class()

function Hook:init(name)
    self.name = name
    self.callbacks = {}
    self.connections = {}
    self.enabled = true
end

function Hook:Add(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function", 2)
    end
    
    table.insert(self.callbacks, callback)
    return callback
end

function Hook:Connect(signal)
    if not self.enabled then return end
    
    local connection = signal:Connect(function(...)
        if self.enabled then
            for _, callback in ipairs(self.callbacks) do
                if callback then
                    callback(...)
                end
            end
        end
    end)
    
    table.insert(self.connections, connection)
    return connection
end

function Hook:Remove(callback)
    for i, cb in ipairs(self.callbacks) do
        if cb == callback then
            table.remove(self.callbacks, i)
            return true
        end
    end
    return false
end

function Hook:Disconnect()
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    self.callbacks = {}
end

function Hook:Enable()
    self.enabled = true
end

function Hook:Disable()
    self.enabled = false
end

local HookRegistry = class()

function HookRegistry:init()
    self.hooks = {}
    self.callbackCounter = 0
    
    local function createSignal(name)
        local signal = {}
        signal._name = name
        signal._connections = {}
        
        function signal:Connect(callback)
            local connection = {
                Connected = true,
                Disconnect = function(self)
                    self.Connected = false
                    for i, conn in ipairs(signal._connections) do
                        if conn == self then
                            table.remove(signal._connections, i)
                            break
                        end
                    end
                end
            }
            connection._callback = callback
            table.insert(signal._connections, connection)
            return connection
        end
        
        function signal:Fire(...)
            for _, connection in ipairs(self._connections) do
                if connection.Connected then
                    connection._callback(...)
                end
            end
        end
        
        return signal
    end
    
    self.eventSignals = {
        onInit = createSignal("onInit"),
        onRenderStepped = createSignal("onRenderStepped"),
        onHeartbeat = createSignal("onHeartbeat"),
        onPlayerAdded = createSignal("onPlayerAdded"),
        onPlayerRemoving = createSignal("onPlayerRemoving"),
        onCustom = {}
    }
    self.initialized = false
end

function HookRegistry:_CreateSignal(name)
    local signal = {}
    signal._name = name
    signal._connections = {}
    
    function signal:Connect(callback)
        local connection = {
            Connected = true,
            Disconnect = function(self)
                self.Connected = false
                for i, conn in ipairs(signal._connections) do
                    if conn == self then
                        table.remove(signal._connections, i)
                        break
                    end
                end
            end
        }
        connection._callback = callback
        table.insert(signal._connections, connection)
        return connection
    end
    
    function signal:Fire(...)
        for _, connection in ipairs(self._connections) do
            if connection.Connected then
                connection._callback(...)
            end
        end
    end
    
    return signal
end

function HookRegistry:_EnsureState()
    -- Defensive initializer in case construction was skipped or state was cleared
    if self.hooks and self.eventSignals then return end

    self.hooks = self.hooks or {}
    self.callbackCounter = self.callbackCounter or 0
    if not self.eventSignals then
        self.eventSignals = {
            onInit = self:_CreateSignal("onInit"),
            onRenderStepped = self:_CreateSignal("onRenderStepped"),
            onHeartbeat = self:_CreateSignal("onHeartbeat"),
            onPlayerAdded = self:_CreateSignal("onPlayerAdded"),
            onPlayerRemoving = self:_CreateSignal("onPlayerRemoving"),
            onCustom = {}
        }
    end

    if self.initialized == nil then
        self.initialized = false
    end
end

function HookRegistry:Register(eventName, callback, name)
    self:_EnsureState()

    if not self.hooks[eventName] then
        self.hooks[eventName] = {}
    end

    if not name then
        self.callbackCounter = self.callbackCounter + 1
        name = "callback_" .. self.callbackCounter
    end
    
    if not self.hooks[eventName][name] then
        self.hooks[eventName][name] = Hook(name)
        if self.eventSignals[eventName] then
            self.hooks[eventName][name]:Connect(self.eventSignals[eventName])
        end
    end
    
    return self.hooks[eventName][name]:Add(callback)
end

function HookRegistry:RegisterCustom(customEventName, callback, name)
    self:_EnsureState()

    if not name then
        self.callbackCounter = self.callbackCounter + 1
        name = "callback_" .. self.callbackCounter
    end
    
    if not self.eventSignals.onCustom[customEventName] then
        self.eventSignals.onCustom[customEventName] = self:_CreateSignal(customEventName)
    end
    
    if not self.hooks.onCustom then
        self.hooks.onCustom = {}
    end
    
    if not self.hooks.onCustom[customEventName] then
        self.hooks.onCustom[customEventName] = {}
    end
    
    if not self.hooks.onCustom[customEventName][name] then
        self.hooks.onCustom[customEventName][name] = Hook(name)
        self.hooks.onCustom[customEventName][name]:Connect(self.eventSignals.onCustom[customEventName])
    end
    
    return self.hooks.onCustom[customEventName][name]:Add(callback)
end

function HookRegistry:Fire(eventName, ...)
    self:_EnsureState()

    if self.eventSignals[eventName] then
        self.eventSignals[eventName]:Fire(...)
    end
end

function HookRegistry:FireCustom(customEventName, ...)
    self:_EnsureState()

    if self.eventSignals.onCustom[customEventName] then
        self.eventSignals.onCustom[customEventName]:Fire(...)
    end
end

function HookRegistry:Get(eventName, hookName)
    if self.hooks[eventName] and self.hooks[eventName][hookName] then
        return self.hooks[eventName][hookName]
    end
end

function HookRegistry:Remove(eventName, hookName, callback)
    if self.hooks[eventName] and self.hooks[eventName][hookName] then
        if callback then
            return self.hooks[eventName][hookName]:Remove(callback)
        else
            self.hooks[eventName][hookName]:Disconnect()
            self.hooks[eventName][hookName] = nil
            return true
        end
    end
    return false
end

function HookRegistry:Initialize()
    self:_EnsureState()

    if self.initialized then return end
    self.initialized = true

    self:Fire("onInit")
    
    Services.RunService.RenderStepped:Connect(function()
        self:Fire("onRenderStepped")
    end)
    
    Services.RunService.Heartbeat:Connect(function()
        self:Fire("onHeartbeat")
    end)
    
    game.Players.PlayerAdded:Connect(function(player)
        self:Fire("onPlayerAdded", player)
    end)
    
    game.Players.PlayerRemoving:Connect(function(player)
        self:Fire("onPlayerRemoving", player)
    end)
end

_DEBUG = true

local Metadata = {
    cheat = "desync",
    build = _DEBUG and "beta" or "dev",
    version = "1.0.0",
    game = "Unknown",
    user = {
        name = game.Players.LocalPlayer.Name or "N/A",
        id = game.Players.LocalPlayer.UserId or 0
    },
}

local GameMap = {
    ["2788229376"] = "Da Hood",
}

local Utility = {
    ResolveGame = function(place_id)
        local mps = Services.MarketplaceService
        local isSuccessful, info = pcall(mps.GetProductInfoAsync, mps, place_id)

        if isSuccessful and info.Name ~= nil then
            if GameMap[tostring(place_id)] ~= nil then
                return GameMap[tostring(place_id)]
            elseif string.match(tostring(info.Name):lower(), "hood") then
                return "Da Hood"
            end
        end

        return "Universal"
    end
}

local UI, Clock = nil, nil

local OnLoad = function()
    Metadata.game = Utility.ResolveGame(game.PlaceId)
    local version_str = Metadata.version
    local build = Metadata.build

    if build ~= "release" then
        version_str = version_str .. " [" .. build .. "]"    
    end

    UI, Clock = loadstring(game:HttpGet("https://raw.githubusercontent.com/s0briety/desync/refs/heads/main/ui.lua"))({
        cheatname = Metadata.cheat,
        version = version_str,
        gamename = Metadata.game,
    }), os.clock()
end

local CreateMenu = function()
    UI:init()

    local MainWindow  = UI.NewWindow({
        title = string.format("%s | %s", Metadata.cheat, Metadata.build),
        size = UDim2.new(0, 510, 0.6, 6
    )})

    local LegitTab = MainWindow:AddTab("Legit")
    local RageTab = MainWindow:AddTab("Rage")
    local VisualsTab = MainWindow:AddTab("Visuals")
    local WorldTab = MainWindow:AddTab("World")
    local OtherTab = MainWindow:AddTab("Other")
    local SettingsTab = UI:CreateSettingsTab(MainWindow)

    local Legitbot = {
        Section = LegitTab:AddSection("Legitbot", 1)
    }

    Legitbot.Toggle = Legitbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle legitbot features",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    Legitbot.Bind = Legitbot.Toggle:AddBind({
        enabled = true,
        text = "Key",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "ToggleKey_1",
        state = false,
        risky = false,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    Legitbot.Bindmode = Legitbot.Section:AddList({
        enabled = true,
        text = "Bind Mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            Legitbot.Bind:SetMode(v:lower())
        end
    })

    -- Legit Tab --

    local LegitAimbot = {
        Section = LegitTab:AddSection("Aimbot", 1)
    }

    LegitAimbot.Toggle = LegitAimbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle legit aimbot",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    LegitAimbot.Bind = LegitAimbot.Toggle:AddBind({
        enabled = true,
        text = "aimbot",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "ToggleKey_1",
        state = false,
        risky = false,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    LegitAimbot.Bindmode = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Bind Mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitAimbot.Bind:SetMode(v:lower())
        end
    })

    LegitAimbot.Section:AddSeparator({})

    LegitAimbot.Aimbotmode = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Aimbot Mode", 
        tooltip = "Select an aimbot mode",
        selected = "Camera",
        multi = false,
        open = false,
        values = {"Camera", "Mouse", "Silent"},
        risky = false,
        callback = function(v)

        end
    })

    LegitAimbot.FOV = LegitAimbot.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aimbot field of view",
        flag = "Slider_1",
        suffix = "°",
        dragging = true,
        focused = false,
        min = 1,
        max = 180,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    LegitAimbot.Smoothing = LegitAimbot.Section:AddSlider({
        enabled = true,
        text = "Smoothing",
        tooltip = "Adjust aimbot smoothing; Does not affect silent aim",
        flag = "Slider_1",
        dragging = true,
        focused = false,
        min = 0.01,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    LegitAimbot.Accuracy = LegitAimbot.Section:AddSlider({
        enabled = true,
        text = "Accuracy",
        tooltip = "Adjust aimbot accuracy",
        flag = "Slider_1",
        suffix = "%",
        dragging = true,
        focused = false,
        min = 1,
        max = 100,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    local LegitAimbotTargeting = {
        Section = LegitTab:AddSection("Targeting", 1)
    }

    LegitAimbotTargeting.Hitboxes = LegitAimbotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Hitboxes", 
        tooltip = "Configure aimbot hitboxes",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs", "Feet"},
        risky = false,
        callback = function(v)

        end
    })

    LegitAimbotTargeting.PreferredHitboxes = LegitAimbotTargeting.Section:AddList({
        enabled = true,
        text = "Hitbox Priority", 
        tooltip = "Configure preferred aimbot hitboxes",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs", "Feet"},
        risky = false,
        callback = function(v)

        end
    })

    LegitAimbotTargeting.Priority = LegitAimbotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Priority", 
        tooltip = "Choose target selection",
        selected = "Closest",
        multi = false,
        open = false,
        values = {"Closest", "Crosshair", "Least HP", "Most HP"},
        risky = false,
        callback = function(v)

        end
    })

    LegitAimbotTargeting.Conditions = LegitAimbotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Conditions", 
        tooltip = "Configure aimbot conditions",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check", "Visibility Check"},
        risky = false,
        callback = function(v)

        end
    })

    local LegitTriggerbot = {
        Section = LegitTab:AddSection("Triggerbot", 2)
    }

    LegitTriggerbot.Toggle = LegitTriggerbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle triggerbot",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    LegitTriggerbot.Bind = LegitTriggerbot.Toggle:AddBind({
        enabled = true,
        text = "triggerbot",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "ToggleKey_1",
        state = false,
        risky = false,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    LegitTriggerbot.Bindmode = LegitTriggerbot.Section:AddList({
        enabled = true,
        text = "Bind Mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitTriggerbot.Bind:SetMode(v:lower())
        end
    })

    LegitTriggerbot.FOV = LegitTriggerbot.Section:AddSlider({
        enabled = true,
        text = "Sensitivity",
        tooltip = "Adjust triggerbot sensitivity",
        flag = "Slider_1",
        dragging = true,
        focused = false,
        min = 0.01,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    LegitTriggerbot.Conditions = LegitTriggerbot.Section:AddList({
        enabled = true,
        text = "Triggerbot Conditions", 
        tooltip = "Configure triggerbot conditions",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check", "Visibility Check"},
        risky = false,
        callback = function(v)

        end
    })

    local LegitAimAssist = {
        Section = LegitTab:AddSection("Assist", 2)
    }

    LegitAimAssist.Toggle = LegitAimAssist.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle aim assist",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    LegitAimAssist.Bind = LegitAimAssist.Toggle:AddBind({
        enabled = true,
        text = "assist",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "ToggleKey_1",
        state = false,
        risky = false,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    LegitAimAssist.Bindmode = LegitAimAssist.Section:AddList({
        enabled = true,
        text = "Bind Mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitAimAssist.Bind:SetMode(v:lower())
        end
    })

    LegitAimAssist.FOV = LegitAimAssist.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aim assist field of view",
        flag = "Slider_1",
        suffix = "°",
        dragging = true,
        focused = false,
        min = 1,
        max = 180,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    LegitAimAssist.Strength = LegitAimAssist.Section:AddSlider({
        enabled = true,
        text = "Strength",
        tooltip = "Adjust aim assist strength",
        flag = "Slider_1",
        dragging = true,
        focused = false,
        min = 0.01,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    local LegitOther = {
        Section = LegitTab:AddSection("Other", 2)
    }

    LegitOther.AimbotFOV = LegitOther.Section:AddToggle({
        text = "FOV",
        state = false,
        tooltip = "Toggle aimbot FOV visualization",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    LegitOther.AimbotFOVColor = LegitOther.AimbotFOV:AddColor({
        enabled = true,
        text = "Color",
        tooltip = "Aimbot FOV color",
        color = Color3.fromRGB(255, 255, 255),
        flag = "Color_1",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    LegitOther.TriggerbotFOV = LegitOther.Section:AddToggle({
        text = "Triggerbot FOV",
        state = false,
        tooltip = "Toggle triggerbot FOV visualization",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    LegitOther.TriggerbotFOVColor = LegitOther.TriggerbotFOV:AddColor({
        enabled = true,
        text = "Color",
        tooltip = "Triggerbot FOV color",
        color = Color3.fromRGB(255, 255, 255),
        flag = "Color_1",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    LegitOther.AimAssistFOV = LegitOther.Section:AddToggle({
        text = "Assist FOV",
        state = false,
        tooltip = "Toggle aim assist FOV visualization",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    LegitOther.AimAssistFOVColor = LegitOther.AimAssistFOV:AddColor({
        enabled = true,
        text = "Color",
        tooltip = "Aim assist FOV color",
        color = Color3.fromRGB(255, 255, 255),
        flag = "Color_1",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    -- Rage Tab --

    local Ragebot = {
        Section = RageTab:AddSection("Ragebot", 1)
    }

    Ragebot.Toggle = Ragebot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle ragebot features",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    Ragebot.Bind = Ragebot.Toggle:AddBind({
        enabled = true,
        text = "ragebot",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "ToggleKey_1",
        state = false,
        risky = false,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    Ragebot.Bindmode = Ragebot.Section:AddList({
        enabled = true,
        text = "Bind Mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            Ragebot.Bind:SetMode(v:lower())
        end
    })

    Ragebot.Section:AddSeparator({})

    Ragebot.AutoFire = Ragebot.Section:AddToggle({
        text = "Auto Fire",
        state = false,
        tooltip = "Toggle ragebot auto firing (auto shoot)",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    Ragebot.AimbotMode = Ragebot.Section:AddList({
        enabled = true,
        text = "Aimbot Mode", 
        tooltip = "Select an aimbot mode",
        selected = "Camera",
        multi = false,
        open = false,
        values = {"Camera", "Silent"},
        risky = false,
        callback = function(v)

        end
    })

    Ragebot.FOV = Ragebot.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aimbot field of view",
        flag = "Slider_1",
        suffix = "°",
        dragging = true,
        focused = false,
        min = 1,
        max = 180,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    local RagebotTargeting = {
        Section = RageTab:AddSection("Targeting", 1)
    }

    RagebotTargeting.Hitboxes = RagebotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Hitboxes", 
        tooltip = "Configure aimbot hitboxes",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs", "Feet"},
        risky = false,
        callback = function(v)

        end
    })

    RagebotTargeting.PreferredHitboxes = RagebotTargeting.Section:AddList({
        enabled = true,
        text = "Hitbox Priority", 
        tooltip = "Configure preferred aimbot hitboxes",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs", "Feet"},
        risky = false,
        callback = function(v)

        end
    })

    RagebotTargeting.Priority = RagebotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Priority", 
        tooltip = "Choose target selection",
        selected = "Closest",
        multi = false,
        open = false,
        values = {"Closest", "Crosshair", "Least HP", "Most HP"},
        risky = false,
        callback = function(v)

        end
    })

    RagebotTargeting.Conditions = RagebotTargeting.Section:AddList({
        enabled = true,
        text = "Aimbot Conditions", 
        tooltip = "Configure aimbot conditions",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check", "Visibility Check"},
        risky = false,
        callback = function(v)

        end
    })

    local RagebotAntiAim = {
        Section = RageTab:AddSection("Anti-Aim", 2)
    }

    RagebotAntiAim.Toggle = RagebotAntiAim.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle ragebot anti-aim",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    RagebotAntiAim.Pitch = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Pitch Mode", 
        tooltip = "Configure anti-aim pitch",
        multi = false,
        open = false,
        values = {"None", "Up", "Down", "Random"},
        risky = false,
        callback = function(v)

        end
    })

    RagebotAntiAim.Yaw = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Yaw Mode", 
        tooltip = "Configure anti-aim yaw",
        multi = false,
        open = false,
        values = {"None", "Spin", "Jitter", "Random"},
        risky = false,
        callback = function(v)

        end
    })

    RagebotAntiAim.Desync = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Desync Mode", 
        tooltip = "Configure anti-aim desync",
        multi = false,
        open = false,
        values = {"None", "Null", "Beneath", "Break", "Random"},
        risky = false,
        callback = function(v)

        end
    })

    local RagebotExploits = {
        Section = RageTab:AddSection("Exploits", 2)
    }

    RagebotExploits.ExtendedHitboxes = RagebotExploits.Section:AddToggle({
        text = "Extended Hitboxes",
        state = false,
        tooltip = "Extend enemy hitboxes",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    RagebotExploits.HitboxSize = RagebotExploits.ExtendedHitboxes:AddSlider({
        enabled = true,
        text = "Hitbox Size",
        tooltip = "Adjust enemy hitbox sizes",
        flag = "Slider_1",
        dragging = true,
        focused = false,
        min = 1,
        max = 100,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    RagebotExploits.RapidFire = RagebotExploits.Section:AddToggle({
        text = "Rapid Fire",
        state = false,
        tooltip = "Increases fire rate",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })

    RagebotExploits.FireRate = RagebotExploits.RapidFire:AddSlider({
        enabled = true,
        text = "Fire Rate",
        tooltip = "Adjust fire rate",
        flag = "Slider_1",
        dragging = true,
        focused = false,
        min = 1,
        max = 6,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    RagebotExploits.Reloadind = RagebotExploits.Section:AddList({
        enabled = true,
        text = "Reload", 
        tooltip = "Configure weapon reload exploits",
        multi = true,
        open = false,
        values = {"Auto Reload", "Spam Reload", "Rifle Reload"},
        risky = false,
        callback = function(v)

        end
    })

end

local Hooks = HookRegistry()

OnLoad()
CreateMenu()

Hooks:Register("onInit", function()
    local Time = (string.format("%."..tostring(4).."f", os.clock() - Clock))
    UI:SendNotification(("Loaded In "..tostring(Time)), 6)
end)

Hooks:Register("onRenderStepped", function()

end)

Hooks:Initialize()