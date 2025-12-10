-- Hooking --

local class = loadstring(game:HttpGet("https://raw.githubusercontent.com/s0briety/desync/refs/heads/main/modules/class.lua"))()
local Hook = class()

local gs = function(s) return game:GetService(s) end

local Services = {
    RunService = gs("RunService"),
    HTTPService = gs("HttpService"),
    TeleportService = gs("TeleportService"),
    MarketplaceService = gs("MarketplaceService"),
    TextChatService = gs("TextChatService"),
    Lighting = gs("Lighting"),
    Players = gs("Players")
}

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

return HookRegistry