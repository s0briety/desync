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
        if init then
            init(obj, ...)
        elseif base and base.init then
            base.init(obj, ...)
        end
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

function HookRegistry:Register(eventName, callback, name)
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
    if self.eventSignals[eventName] then
        self.eventSignals[eventName]:Fire(...)
    end
end

function HookRegistry:FireCustom(customEventName, ...)
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

local Metadata = {
    cheat = "desync",
    build = "beta",
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
            print(info.Name)

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

    UI, Clock = loadstring(game:HttpGet("https://raw.githubusercontent.com/s0briety/desync/refs/heads/main/ui.lua"))({
        cheatname = Metadata.cheat,
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
    local SettingsTab = UI:CreateSettingsTab(MainWindow)

    local LegitMain = {
        Section = LegitTab:AddSection("Main", 1)
    }

    LegitMain.Toggle = LegitMain.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle legit features",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    LegitMain.Bind = LegitMain.Toggle:AddBind({
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

    LegitMain.Bindmode = LegitMain.Section:AddList({
        enabled = true,
        text = "Bind mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitMain.Bind.mode = v.lower()
        end
    })

    -- LegitMain.Section:AddSeparator({})

    local LegitAimbot = {
        Section = LegitTab:AddSection("Aimbot", 1)
    }

    LegitAimbot.Toggle = LegitAimbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle legit features",
        flag = "Toggle_1",
        callback = function(v)
            return
        end
    })
    
    LegitAimbot.Bind = LegitAimbot.Toggle:AddBind({
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

    LegitAimbot.Bindmode = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Bind mode", 
        tooltip = "Select a bind mode",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitAimbot.Bind.mode = v.lower()
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

    -- [[
    -- Section1:AddColor({
    --     enabled = true,
    --     text = "Color1",
    --     tooltip = "tooltip1",
    --     color = Color3.fromRGB(255, 255, 255),
    --     flag = "Color_1",
    --     trans = 0,
    --     open = false,
    --     risky = false,
    --     callback = function(v)
    --         return
    --     end
    -- })
    -- ]]
end

OnLoad()
CreateMenu()

local Hooks = HookRegistry()

Hooks:Register("onInit", function()
    local Time = (string.format("%."..tostring(4).."f", os.clock() - Clock))
    UI:SendNotification(("Loaded In "..tostring(Time)), 6)
end)

Hooks:Register("onRenderStepped", function()

end)

Hooks:Initialize()