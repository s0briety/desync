-- Begin script --
_DEBUG = true

local repo = "https://raw.githubusercontent.com/s0briety/desync/refs/heads/main"

local ls, gs, lp = function(u, d)
    return loadstring(game:HttpGet(u))(d)
end, function(s)
    return game:GetService(s)
end, game.Players.LocalPlayer

local Signal = ls(repo .. '/modules/signal.lua')
local HookRegistry = ls(repo .. '/modules/hooking.lua')

local Hooks = HookRegistry()

local Services = {
    RunService = gs("RunService"),
    HTTPService = gs("HttpService"),
    TeleportService = gs("TeleportService"),
    MarketplaceService = gs("MarketplaceService"),
    TextChatService = gs("TextChatService"),
    Lighting = gs("Lighting"),
    Players = gs("Players")
}

local Metadata = {
    cheat = "desync",
    build = _DEBUG and "beta" or "dev",
    version = "1.0.0",
    game = "Unknown",
    user = {
        name = game.Players.LocalPlayer.Name or "N/A",
        id = game.Players.LocalPlayer.UserId or 0
    }
}

local GameMap = {
    ["2788229376"] = "Da Hood"
}

local Cache = {
    chat = {
        lastSpamTime = 0
    },
    afk = {
        interval = 25,
        max_time = 30 * 60
    }
}

local PlayerStorage = {
    PlayerGui = lp:WaitForChild("PlayerGui")
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
    end,

    createGuiElement = function(el)
        local element = Instance.new(el.class)
        element.Name = el.name
        element.ZIndex = el.zindex or 9999999
        element.BackgroundTransparency = 1
        element.Parent = el.parent
        return element
    end,

    getCharacterBounds = function(character)
        local head = character:FindFirstChild("Head")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if not head or not hrp or not humanoid then
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        local headPos, headOnScreen = camera:WorldToScreenPoint(head.Position + Vector3.new(0, 0.5, 0))
        local feetPos, feetOnScreen = camera:WorldToScreenPoint(hrp.Position - Vector3.new(0, humanoid.HipHeight, 0))

        if not headOnScreen or not feetOnScreen then
            return
        end

        local height = feetPos.Y - headPos.Y
        local center = Vector2.new(headPos.X, headPos.Y + height / 2)
        local width = height * 0.4

        local topLeft = Vector2.new(center.X - width / 2, headPos.Y)
        local size = Vector2.new(width, height)

        return topLeft, size, headPos, feetPos
    end,

    getPlayerWeapon = function(targetPlayer)
        local backpack = targetPlayer:FindFirstChild("Backpack")
        local character = targetPlayer.Character

        local tool
        if backpack then
            tool = backpack:FindFirstChildOfClass("Tool")
        end
        if not tool and character then
            tool = character:FindFirstChildOfClass("Tool")
        end

        return tool and tool.Name or "None"
    end,

    CenterPad = function(str, total_length, pad_char)
        pad_char = pad_char or " "

        local current_length = #str

        if current_length >= total_length then
            return str
        end

        local padding_needed = total_length - current_length

        local left_padding_size = math.floor(padding_needed / 2)

        local right_padding_size = padding_needed - left_padding_size

        local left_padding = string.rep(pad_char, left_padding_size)
        local right_padding = string.rep(pad_char, right_padding_size)

        return left_padding .. str .. right_padding
    end
}

local UI, Clock = nil, nil
local Menu = {}

-- Function Calls --

local OnLoad = function()
    Metadata.game = Utility.ResolveGame(game.PlaceId)
    local version_str = Metadata.version
    local build = Metadata.build

    if build ~= "release" then
        version_str = version_str .. " [" .. build .. "]"
    end

    UI, Clock = ls(repo .. '/modules/ui.lua', {
        cheatname = Metadata.cheat,
        version = version_str,
        gamename = Metadata.game
    }), os.clock()

    UI.unloaded:Connect(function()
        Hooks:FireCustom("Unload")
    end)
end

local onUnload = function()
    if UI and UI.unloaded and UI.unloaded.Destroy then
        UI.unloaded:Destroy()
    end
    if Hooks and Hooks.Destroy then
        Hooks:Destroy()
    end
end

-- Cheat Functions --

local General = {
    ToggleNoclip = function(state)
        local character = lp.Character
        if not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not state
            end
        end
    end,

    AntiAFKLoop = function()
        local function AntiAFK()
            local character = lp.Character

            if not character or not character:FindFirstChild("HumanoidRootPart") then
                return
            end

            local HRP = character.HumanoidRootPart

            local originalPosition = HRP.CFrame

            HRP.CFrame = originalPosition + Vector3.new(0, 0, 0.001)

            wait(0.005)
            HRP.CFrame = originalPosition
        end

        while true do
            wait(Cache.afk.interval)
            if Menu["WorldExploits"].AntiAfk.state then
                AntiAFK()
            end
        end
    end,

    ChatSpam = function(curTime)
        local chatSettings = Menu["OtherChat"]

        if not chatSettings or not chatSettings.Text or not chatSettings.Text.input or not chatSettings.Delay or
            not chatSettings.Delay.value then
            return
        end

        local delay = tonumber(chatSettings.Delay.value)

        if delay == nil or delay < 0 then
            delay = 1
        end

        local lastSpamTime = Cache.chat.lastSpamTime or 0
        local timeElapsed = curTime - lastSpamTime

        if timeElapsed >= delay then
            Services.TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(chatSettings.Text.input)

            Cache.chat.lastSpamTime = curTime
        end
    end
}

-- Menu Creation --

local CreateMenu = function()
    UI:init()

    local MainWindow = UI.NewWindow({
        title = string.format("%s | %s", Metadata.cheat, Metadata.build),
        size = UDim2.new(0, 510, 0.6, 6)
    })

    local LegitTab = MainWindow:AddTab(Utility.CenterPad("Legit", 8))
    local RageTab = MainWindow:AddTab(Utility.CenterPad("Rage", 8))
    local VisualsTab = MainWindow:AddTab(Utility.CenterPad("Visuals", 8))
    local WorldTab = MainWindow:AddTab(Utility.CenterPad("World", 8))
    local OtherTab = MainWindow:AddTab(Utility.CenterPad("Other", 8))
    local SettingsTab = UI:CreateSettingsTab(MainWindow)

    ---
    --- LEGIT TAB (Column 1)
    ---

    local LegitMain = {
        Section = LegitTab:AddSection("Main", 1)
    }

    LegitMain.Toggle = LegitMain.Section:AddToggle({
        text = "Enable",
        state = false,
        tooltip = "Enable legitbot",
        flag = "LegitBot_Toggle",
        callback = function(v)
            if v and Menu["RageMain"].Toggle.state then
                Menu["RageMain"].Toggle:SetState(false, true)
            end
        end
    })

    Menu["LegitMain"] = LegitMain

    local LegitAimbot = {
        Section = LegitTab:AddSection("Aimbot", 1)
    }

    LegitAimbot.Toggle = LegitAimbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle legit aimbot",
        flag = "LegitAimbot_Toggle",
        callback = function(v)
            return
        end
    })

    LegitAimbot.Bind = LegitAimbot.Toggle:AddBind({
        enabled = true,
        text = "Aimbot Key",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "LegitAimbot_BindKey",
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
        tooltip = "Select a bind mode (Toggle/Hold)",
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

    LegitAimbot.FOV = LegitAimbot.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aimbot field of view",
        flag = "LegitAimbot_FOV",
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
        tooltip = "Adjust aimbot smoothing; Does not affect Silent Aim",
        flag = "LegitAimbot_Smoothing",
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
        tooltip = "Adjust aimbot accuracy (how close it aims to the center of the hitbox)",
        flag = "LegitAimbot_Accuracy",
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

    LegitAimbot.Mode = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Mode",
        tooltip = "Select an aimbot mode (Camera/Mouse/Silent)",
        selected = "Camera",
        multi = false,
        open = false,
        values = {"Camera", "Mouse", "Silent"},
        risky = false,
        callback = function(v)
        end
    })

    -- Targeting Section for Aimbot
    LegitAimbot.Section:AddSeparator({
        text = "Targeting"
    })

    LegitAimbot.Hitboxes = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Enabled Hitboxes",
        tooltip = "Hitboxes that aimbot can target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    LegitAimbot.PreferredHitboxes = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Hitbox Priority",
        tooltip = "Order of preferred hitboxes to target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    LegitAimbot.Priority = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Target Priority",
        tooltip = "Choose target selection (Closest, Crosshair, etc.)",
        selected = "Closest",
        multi = false,
        open = false,
        values = {"Closest", "Crosshair", "Least HP", "Most HP"},
        risky = false,
        callback = function(v)
        end
    })

    LegitAimbot.Conditions = LegitAimbot.Section:AddList({
        enabled = true,
        text = "Conditions",
        tooltip = "Conditions a target must meet to be aimed at",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check", "Visibility Check", "Team Check", "Is Moving"},
        risky = false,
        callback = function(v)
        end
    })

    Menu["LegitAimbot"] = LegitAimbot

    ---
    --- LEGIT TAB (Column 2)
    ---

    -- Triggerbot Section (Legit Tab - Column 2)
    local LegitTriggerbot = {
        Section = LegitTab:AddSection("Triggerbot", 2)
    }

    LegitTriggerbot.Toggle = LegitTriggerbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle triggerbot (automatically shoots when target is under crosshair)",
        flag = "LegitTriggerbot_Toggle",
        callback = function(v)
            return
        end
    })

    LegitTriggerbot.Bind = LegitTriggerbot.Toggle:AddBind({
        enabled = true,
        text = "Trigger Key",
        tooltip = "Toggle or Hold on key press",
        mode = "toggle",
        bind = "None",
        flag = "LegitTriggerbot_BindKey",
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
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitTriggerbot.Bind:SetMode(v:lower())
        end
    })

    LegitTriggerbot.Section:AddSeparator({})

    LegitTriggerbot.Hitboxes = LegitTriggerbot.Section:AddList({
        enabled = true,
        text = "Trigger Hitboxes",
        tooltip = "Hitboxes that will trigger the shot",
        multi = true,
        open = false,
        values = {"Head", "Torso", "Limb"},
        risky = false,
        callback = function(v)
        end
    })

    LegitTriggerbot.Delay = LegitTriggerbot.Section:AddSlider({
        enabled = true,
        text = "Pre-Shot Delay",
        tooltip = "Time (in seconds) to wait before firing",
        flag = "LegitTriggerbot_Delay",
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

    LegitTriggerbot.MinDamage = LegitTriggerbot.Section:AddSlider({
        enabled = true,
        text = "Min Damage",
        tooltip = "Minimum expected damage to trigger a shot",
        flag = "LegitTriggerbot_MinDamage",
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

    LegitTriggerbot.Conditions = LegitTriggerbot.Section:AddList({
        enabled = true,
        text = "Conditions",
        tooltip = "Conditions a target must meet to trigger a shot",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check"},
        risky = false,
        callback = function(v)
        end
    })

    Menu["LegitTriggerbot"] = LegitTriggerbot

    -- Aim Assist Section (Legit Tab - Column 2)
    local LegitAimAssist = {
        Section = LegitTab:AddSection("Assist", 2)
    }

    LegitAimAssist.Toggle = LegitAimAssist.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle mouse aim assist (snaps/slows mouse to target)",
        flag = "LegitAimAssist_Toggle",
        callback = function(v)
            return
        end
    })

    LegitAimAssist.Bind = LegitAimAssist.Toggle:AddBind({
        enabled = true,
        text = "Assist Key",
        tooltip = "Toggle or Hold on key press",
        mode = "toggle",
        bind = "None",
        flag = "LegitAimAssist_BindKey",
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
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            LegitAimAssist.Bind:SetMode(v:lower())
        end
    })

    LegitAimAssist.Section:AddSeparator({})

    LegitAimAssist.FOV = LegitAimAssist.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aim assist field of view",
        flag = "LegitAimAssist_FOV",
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
        tooltip = "Adjust aim assist strength (how hard it pulls/slows)",
        flag = "LegitAimAssist_Strength",
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

    LegitAimAssist.RCS = LegitAimAssist.Section:AddToggle({
        text = "Recoil Control (RCS)",
        state = false,
        tooltip = "Automatically compensates for weapon recoil",
        flag = "LegitAimAssist_RCS_Toggle",
        callback = function(v)
            return
        end
    })

    LegitAimAssist.RCSStrengthX = LegitAimAssist.RCS:AddSlider({
        enabled = true,
        text = "Horizontal Strength",
        tooltip = "Horizontal compensation factor (0.0 to 1.0)",
        flag = "LegitAimAssist_RCSStrengthX",
        dragging = true,
        focused = false,
        min = 0,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    LegitAimAssist.RCSStrengthY = LegitAimAssist.RCS:AddSlider({
        enabled = true,
        text = "Vertical Strength",
        tooltip = "Vertical compensation factor (0.0 to 1.0)",
        flag = "LegitAimAssist_RCSStrengthY",
        dragging = true,
        focused = false,
        min = 0,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    Menu["LegitAimAssist"] = LegitAimAssist

    ---
    --- RAGE TAB (Column 1)
    ---

    local RageMain = {
        Section = RageTab:AddSection("Main", 1)
    }

    RageMain.Toggle = RageMain.Section:AddToggle({
        text = "Enable",
        state = false,
        tooltip = "Enable ragebot",
        flag = "RageBot_Toggle",
        callback = function(v)
            if v and LegitMain.Toggle.state then
                LegitMain.Toggle:SetState(false, true)
            end
        end
    })

    Menu["RageMain"] = RageMain

    local RageAimbot = {
        Section = RageTab:AddSection("Aimbot", 1)
    }

    RageAimbot.Toggle = RageAimbot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle aimbot features",
        flag = "RagebotAimbot_Toggle",
        callback = function(v)
            return
        end
    })

    RageAimbot.Bind = RageAimbot.Toggle:AddBind({
        enabled = true,
        text = "Aimbot Key",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "RagebotAimbot_BindKey",
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

    RageAimbot.Bindmode = RageAimbot.Section:AddList({
        enabled = true,
        text = "Bind Mode",
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            RageAimbot.Bind:SetMode(v:lower())
        end
    })

    RageAimbot.Section:AddSeparator({})

    RageAimbot.AutoFire = RageAimbot.Section:AddToggle({
        text = "Auto Fire",
        state = false,
        tooltip = "Toggle ragebot auto firing (auto shoot)",
        flag = "RagebotAimbot_AutoFire",
        callback = function(v)
            return
        end
    })

    RageAimbot.AutoFireBind = RageAimbot.AutoFire:AddBind({
        enabled = true,
        text = "Auto Fire Key",
        tooltip = "Only auto fire when key is held",
        mode = "hold",
        bind = "None",
        flag = "RagebotAimbot_AutoFireBindKey",
        state = false,
        risky = false,
        noindicator = true,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    RageAimbot.AutoFireBindmode = RageAimbot.Section:AddList({
        enabled = true,
        text = "Bind Mode",
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            RageAimbot.AutoFireBindmode:SetMode(v:lower())
        end
    })

    RageAimbot.Section:AddSeparator({})

    if Metadata.game ~= "Da Hood" then
        RageAimbot.AutoWall = RageAimbot.Section:AddToggle({
            text = "Auto Wall",
            state = false,
            tooltip = "Allows aiming and shooting through materials/walls",
            flag = "RagebotAimbot_AutoWall_Toggle",
            risky = true,
            callback = function(v)
                return
            end
        })

        RageAimbot.AutoWallMinDamage = RageAimbot.AutoWall:AddSlider({
            enabled = true,
            text = "Min Wall Damage",
            tooltip = "Minimum required damage through a wall to shoot",
            flag = "RagebotAimbot_AutoWallMinDamage",
            dragging = true,
            focused = false,
            min = 1,
            max = 100,
            increment = 1,
            risky = true,
            callback = function(v)
                return
            end
        })
    end

    RageAimbot.AimbotMode = RageAimbot.Section:AddList({
        enabled = true,
        text = "Mode",
        tooltip = "Select an aimbot mode (Camera/Silent)",
        selected = "Silent",
        multi = false,
        open = false,
        values = {"Camera", "Silent"},
        risky = false,
        callback = function(v)
        end
    })

    RageAimbot.FOV = RageAimbot.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aimbot field of view (Silent Aim ignores this)",
        flag = "RagebotAimbot_FOV",
        suffix = "°",
        dragging = true,
        focused = false,
        min = 1,
        max = 360, -- Maxed for Rage
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    RageAimbot.Prediction = RageAimbot.Section:AddSlider({
        enabled = true,
        text = "Prediction",
        tooltip = "Compensate for target movement/ping",
        flag = "RagebotAimbot_Prediction",
        dragging = true,
        focused = false,
        min = 0,
        max = 1,
        increment = 0.01,
        risky = false,
        callback = function(v)
            return
        end
    })

    -- Ragebot Targeting
    RageAimbot.Section:AddSeparator({
        text = "Targeting"
    })

    RageAimbot.Hitboxes = RageAimbot.Section:AddList({
        enabled = true,
        text = "Enabled Hitboxes",
        tooltip = "Hitboxes that aimbot can target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    RageAimbot.PreferredHitboxes = RageAimbot.Section:AddList({
        enabled = true,
        text = "Hitbox Priority",
        tooltip = "Order of preferred hitboxes to target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    RageAimbot.Priority = RageAimbot.Section:AddList({
        enabled = true,
        text = "Target Priority",
        tooltip = "Choose target selection (Closest, Crosshair, etc.)",
        selected = "Closest",
        multi = false,
        open = false,
        values = {"Closest", "Furthest", "Crosshair", "Least HP", "Most HP"},
        risky = false,
        callback = function(v)
        end
    })

    RageAimbot.Conditions = RageAimbot.Section:AddList({
        enabled = true,
        text = "Conditions",
        tooltip = "Conditions a target must meet to be aimed at",
        multi = true,
        open = false,
        values = {"Target Alive", "Immunity Check", "Visibility Check", "Team Check"},
        risky = false,
        callback = function(v)
        end
    })

    Menu["RageAimbot"] = RageAimbot

    ---
    --- RAGE TAB (Column 2)
    ---

    -- Anti-Aim Section (Rage Tab - Column 2)
    local RagebotAntiAim = {
        Section = RageTab:AddSection("Anti-Aim", 2)
    }

    RagebotAntiAim.Toggle = RagebotAntiAim.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle ragebot anti-aim (for third-person/server view)",
        flag = "RageAA_Toggle",
        risky = true,
        callback = function(v)
            return
        end
    })

    RagebotAntiAim.Pitch = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Pitch Mode",
        tooltip = "Configure anti-aim pitch (up/down rotation)",
        multi = false,
        open = false,
        values = {"None", "Up", "Down", "Fake Down", "Random"},
        risky = true,
        callback = function(v)
        end
    })

    RagebotAntiAim.Yaw = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Yaw Mode",
        tooltip = "Configure anti-aim yaw (horizontal rotation)",
        multi = false,
        open = false,
        values = {"None", "Spin", "Jitter", "Random", "Backwards", "Static"},
        risky = true,
        callback = function(v)
        end
    })

    RagebotAntiAim.Desync = RagebotAntiAim.Section:AddList({
        enabled = true,
        text = "Desync Mode",
        tooltip = "Configure anti-aim desync (hides real hitbox location)",
        multi = false,
        open = false,
        values = {"None", "Break", "Roll", "Beneath"},
        risky = true,
        callback = function(v)
        end
    })

    RagebotAntiAim.DesyncAmount = RagebotAntiAim.Section:AddSlider({
        enabled = true,
        text = "Desync Yaw Amount",
        tooltip = "Maximum angle offset for desyncing yaw",
        flag = "RageAA_DesyncAmount",
        dragging = true,
        focused = false,
        min = 1,
        max = 180,
        increment = 5,
        risky = true,
        callback = function(v)
            return
        end
    })

    Menu["RagebotAntiAim"] = RagebotAntiAim

    local RagebotExploits = {
        Section = RageTab:AddSection("Exploits", 2)
    }

    RagebotExploits.ExtendedHitboxes = RagebotExploits.Section:AddToggle({
        text = "Extended Hitboxes",
        state = false,
        tooltip = "Extend enemy hitboxes for easier targeting",
        flag = "RageExploits_ExtendedHitboxes",
        risky = true,
        callback = function(v)
            return
        end
    })

    RagebotExploits.HitboxSize = RagebotExploits.ExtendedHitboxes:AddSlider({
        enabled = true,
        text = "Multiplier",
        tooltip = "Adjust enemy hitbox size multiplier",
        flag = "RageExploits_HitboxSize",
        dragging = true,
        focused = false,
        min = 1,
        max = 10,
        increment = 0.5,
        risky = true,
        callback = function(v)
            return
        end
    })

    RagebotExploits.RapidFire = RagebotExploits.Section:AddToggle({
        text = "Rapid Fire",
        state = false,
        tooltip = "Increases fire rate beyond normal limits",
        flag = "RageExploits_RapidFire",
        risky = true,
        callback = function(v)
            return
        end
    })

    RagebotExploits.FireRate = RagebotExploits.RapidFire:AddSlider({
        enabled = true,
        text = "Rate Multiplier",
        tooltip = "Adjust fire rate multiplier",
        flag = "RageExploits_FireRate",
        dragging = true,
        focused = false,
        min = 1,
        max = 10,
        increment = 1,
        risky = true,
        callback = function(v)
            return
        end
    })

    RagebotExploits.Reloading = RagebotExploits.Section:AddList({
        enabled = true,
        text = "Reload",
        tooltip = "Configure weapon reload exploits (Instant, Spam, etc.)",
        multi = true,
        open = false,
        values = {"Instant Reload", "Auto Reload", "Infinite Ammo", "Ghost Ammo"},
        risky = true,
        callback = function(v)
        end
    })

    Menu["RagebotExploits"] = RagebotExploits

    ---
    --- VISUALS TAB (Column 1 & 2)
    ---

    local VisualsESP = {
        Section = VisualsTab:AddSection("ESP", 1)
    }

    VisualsESP.Toggle = VisualsESP.Section:AddToggle({
        text = "Enable",
        state = false,
        tooltip = "Enable ESP features",
        flag = "VisualsESP_Toggle",
        callback = function(v)
            return
        end
    })

    VisualsESP.PlayerTypes = VisualsESP.Toggle:AddList({
        enabled = true,
        text = "Player Types",
        tooltip = "Select Player Types",
        selected = nil,
        multi = true,
        open = false,
        values = {"Local", "Friendly", "Enemy"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsESP.MaxDistance = VisualsESP.Toggle:AddSlider({
        enabled = true,
        text = "Max Distance",
        tooltip = "Adjust ESP max view distance",
        flag = "VisualsESP_MaxDistance",
        dragging = true,
        suffix = "s",
        focused = false,
        min = 1,
        max = 10000,
        increment = 10,
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsESP.Section:AddSeparator({})

    VisualsESP.Box = VisualsESP.Section:AddToggle({
        text = "Box",
        state = false,
        tooltip = "Draw a box around targets",
        flag = "VisualsESP_Box",
        callback = function(v)
            return
        end
    })

    VisualsESP.BoxType = VisualsESP.Box:AddList({
        enabled = true,
        text = "Box Type",
        tooltip = "Select Box Style",
        selected = "Outline",
        multi = false,
        open = false,
        values = {"Outline", "Static", "Corner", "Bounding"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsESP.BoxColor = VisualsESP.Box:AddColor({
        enabled = true,
        text = "Box Color",
        tooltip = "Color for the box",
        color = Color3.fromRGB(255, 255, 255),
        flag = "VisualsESP_BoxColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.Name = VisualsESP.Section:AddToggle({
        text = "Name",
        state = false,
        tooltip = "Display target player name",
        flag = "VisualsESP_Name",
        callback = function(v)
            return
        end
    })

    VisualsESP.NameColor = VisualsESP.Name:AddColor({
        enabled = true,
        text = "Name Color",
        tooltip = "Color for the name",
        color = Color3.fromRGB(255, 255, 255),
        flag = "VisualsESP_NameColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.Health = VisualsESP.Section:AddToggle({
        text = "Health",
        state = false,
        tooltip = "Display target player health bar/text",
        flag = "VisualsESP_Health",
        callback = function(v)
            return
        end
    })

    VisualsESP.HighHealthColor = VisualsESP.Health:AddColor({
        enabled = true,
        text = "High Health Color",
        tooltip = "Color to indicate high health",
        color = Color3.fromRGB(0, 255, 0),
        flag = "VisualsESP_HighHealthColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.LowHealthColor = VisualsESP.Health:AddColor({
        enabled = true,
        text = "Low Health Color",
        tooltip = "Color to indicate low health",
        color = Color3.fromRGB(255, 0, 0),
        flag = "VisualsESP_LowHealthColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.Distance = VisualsESP.Section:AddToggle({
        text = "Distance",
        state = false,
        tooltip = "Display distance to target",
        flag = "VisualsESP_Distance",
        callback = function(v)
            return
        end
    })

    VisualsESP.DistanceColor = VisualsESP.Distance:AddColor({
        enabled = true,
        text = "Distance Color",
        tooltip = "Color for the distance",
        color = Color3.fromRGB(255, 255, 255),
        flag = "VisualsESP_DistanceColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.Weapon = VisualsESP.Section:AddToggle({
        text = "Weapon",
        state = false,
        tooltip = "Display enemy current weapon name",
        flag = "VisualsChams_Weapon",
        callback = function(v)
            return
        end
    })

    VisualsESP.WeaponColor = VisualsESP.Weapon:AddColor({
        enabled = true,
        text = "Weapon Color",
        tooltip = "Color for the weapon",
        color = Color3.fromRGB(255, 255, 255),
        flag = "VisualsESP_WeaponColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.FontSize = VisualsESP.Section:AddSlider({
        enabled = true,
        text = "Font Size",
        tooltip = "Adjust the size of ESP text",
        flag = "VisualsESP_FontSize",
        dragging = true,
        suffix = "px",
        focused = false,
        min = 1,
        max = 6,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    Menu["VisualsESP"] = VisualsESP

    local VisualsModels = {
        Section = VisualsTab:AddSection("Models", 1)
    }

    VisualsModels.OverrideModels = VisualsModels.Section:AddToggle({
        text = "Override Models",
        state = false,
        tooltip = "Change material/color of models",
        flag = "VisualsModel_Toggle",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.Section:AddSeparator({
        text = "Local"
    })

    VisualsModels.LocalModel = VisualsModels.Section:AddToggle({
        text = "Always",
        state = false,
        tooltip = "Change material/color of the local model",
        flag = "VisualsLocalModel_Toggle",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.LocalColor = VisualsModels.LocalModel:AddColor({
        enabled = true,
        text = "Color",
        tooltip = "Color of the local model",
        color = Color3.fromRGB(255, 255, 255),
        flag = "VisualsModels_LocalColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsModels.LocalMaterial = VisualsModels.Section:AddList({
        enabled = true,
        text = "Material",
        tooltip = "Select Material Style",
        selected = "Flat",
        multi = false,
        open = false,
        values = {"Flat", "Pulse", "Glow", "Wireframe", "Shine"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsModels.Section:AddSeparator({
        text = "Friendly"
    })

    VisualsModels.FriendlyVisible = VisualsModels.Section:AddToggle({
        text = "Visible",
        state = false,
        tooltip = "Change material/color of visible friendly models",
        flag = "VisualsFriendlyModel_Visible",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.FriendlyVisibleColor = VisualsModels.FriendlyVisible:AddColor({
        enabled = true,
        text = "Color (Visible)",
        tooltip = "Color of visible friendly models",
        color = Color3.fromRGB(255, 0, 0),
        flag = "VisualsChams_VisibleFriendlyColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsModels.FriendlyHidden = VisualsModels.Section:AddToggle({
        text = "Hidden",
        state = false,
        tooltip = "Change material/color of hidden friendly models",
        flag = "VisualsFriendlyModel_Hidden",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.FriendlyHiddenColor = VisualsModels.FriendlyHidden:AddColor({
        enabled = true,
        text = "Color (Hidden)",
        tooltip = "Color of hidden friendly models",
        color = Color3.fromRGB(0, 255, 0),
        flag = "VisualsChams_HiddenFriendlyColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsModels.FriendlyMaterial = VisualsModels.Section:AddList({
        enabled = true,
        text = "Material",
        tooltip = "Select Material Style",
        selected = "Flat",
        multi = false,
        open = false,
        values = {"Flat", "Pulse", "Glow", "Wireframe", "Shine"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsModels.Section:AddSeparator({
        text = "Enemy"
    })

    VisualsModels.EnemyVisible = VisualsModels.Section:AddToggle({
        text = "Visible",
        state = false,
        tooltip = "Change material/color of visible enemy models",
        flag = "VisualsEnemyModel_Visible",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.EnemyVisibleColor = VisualsModels.EnemyVisible:AddColor({
        enabled = true,
        text = "Color (Visible)",
        tooltip = "Color of visible enemy models",
        color = Color3.fromRGB(255, 0, 0),
        flag = "VisualsChams_VisibleEnemyColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsModels.EnemyHidden = VisualsModels.Section:AddToggle({
        text = "Hidden",
        state = false,
        tooltip = "Change material/color of hidden enemy models",
        flag = "VisualsEnemyModel_Hidden",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsModels.EnemyHiddenColor = VisualsModels.EnemyHidden:AddColor({
        enabled = true,
        text = "Color (Hidden)",
        tooltip = "Color of hidden enemy models",
        color = Color3.fromRGB(0, 255, 0),
        flag = "VisualsChams_HiddenEnemyColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsModels.EnemyMaterial = VisualsModels.Section:AddList({
        enabled = true,
        text = "Material",
        tooltip = "Select Material Style",
        selected = "Flat",
        multi = false,
        open = false,
        values = {"Flat", "Pulse", "Glow", "Wireframe", "Shine"},
        risky = false,
        callback = function(v)
        end
    })

    Menu["VisualsModels"] = VisualsModels

    -- Visuals Indicators (Column 2)
    local VisualsIndicators = {
        Section = VisualsTab:AddSection("Indicators", 2)
    }

    VisualsIndicators.Section:AddToggle({
        text = 'Watermark',
        flag = 'watermark_enabled',
        state = true
    })

    VisualsIndicators.Section:AddSlider({
        text = 'Custom X',
        flag = 'watermark_x',
        suffix = '%',
        min = 0,
        max = 100,
        increment = 0.1,
        value = 6
    })

    VisualsIndicators.Section:AddSlider({
        text = 'Custom Y',
        flag = 'watermark_y',
        suffix = '%',
        min = 0,
        max = 100,
        increment = 0.1,
        value = 1
    })

    VisualsIndicators.Section:AddSeparator({})

    VisualsIndicators.Section:AddToggle({
        text = 'Keybinds',
        flag = 'keybind_indicator',
        state = true,
        callback = function(bool)
            UI.keyIndicator:SetEnabled(bool);
        end
    })

    VisualsIndicators.Section:AddSlider({
        text = 'Position X',
        flag = 'keybind_indicator_x',
        min = 0,
        max = 100,
        increment = 0.1,
        value = 0.5,
        callback = function()
            UI.keyIndicator:SetPosition(UDim2.new(UI.flags.keybind_indicator_x / 100, 0,
                UI.flags.keybind_indicator_y / 100, 0));
        end
    })

    VisualsIndicators.Section:AddSlider({
        text = 'Position Y',
        flag = 'keybind_indicator_y',
        min = 0,
        max = 100,
        increment = 0.1,
        value = 30,
        callback = function()
            UI.keyIndicator:SetPosition(UDim2.new(UI.flags.keybind_indicator_x / 100, 0,
                UI.flags.keybind_indicator_y / 100, 0));
        end
    })

    VisualsIndicators.Section:AddSeparator({})

    VisualsIndicators.DrawFOV = VisualsIndicators.Section:AddToggle({
        text = "Draw FOV Circle",
        state = false,
        tooltip = "Display the aimbot field of view on screen",
        flag = "Aimbot_DrawFOV",
        callback = function(v)
            return
        end
    })

    VisualsIndicators.FOVColor = VisualsIndicators.DrawFOV:AddColor({
        enabled = true,
        text = "FOV Circle Color",
        tooltip = "Color of the FOV circle",
        color = Color3.fromRGB(255, 255, 255),
        flag = "Aimbot_FOVColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsIndicators.FOVThickness = VisualsIndicators.DrawFOV:AddSlider({
        enabled = true,
        text = "FOV Line Thickness",
        tooltip = "Thickness of the FOV circle border",
        flag = "Aimbot_FOVThickness",
        dragging = true,
        focused = false,
        min = 1,
        max = 5,
        increment = 1,
        risky = false,
        callback = function(v)
            return
        end
    })

    -- World Visuals (Column 2)
    local VisualsWorld = {
        Section = VisualsTab:AddSection("World", 2)
    }

    VisualsWorld.Ambient = VisualsWorld.Section:AddToggle({
        text = "Full Bright",
        state = false,
        tooltip = "Increases the world's brightness",
        flag = "VisualsWorld_FullBright",
        callback = function(v)
            return
        end
    })

    VisualsWorld.NoSky = VisualsWorld.Section:AddToggle({
        text = "No Sky",
        state = false,
        tooltip = "Removes the skybox for clarity/visibility",
        flag = "VisualsWorld_NoSky",
        callback = function(v)
            return
        end
    })

    VisualsWorld.NoPost = VisualsWorld.Section:AddToggle({
        text = "Remove Post Processing",
        state = false,
        tooltip = "Removes blurring, color correction, and screen effects",
        flag = "VisualsWorld_NoPost",
        callback = function(v)
            return
        end
    })

    VisualsWorld.Tracers = VisualsWorld.Section:AddToggle({
        text = "Bullet Tracers",
        state = false,
        tooltip = "Draw bullet tracers",
        flag = "VisualsWorld_BulletTracers",
        callback = function(v)
            return
        end
    })

    VisualsWorld.TimeOfDayToggle = VisualsWorld.Section:AddToggle({
        text = "Time of Day",
        state = false,
        tooltip = "Override the time of day in the game",
        flag = "WorldVisuals_TimeToggle",
        risky = false,
        callback = function(v)
            if not v then
                Services.Lighting.ClockTime = 12
            end
        end
    })

    VisualsWorld.TimeOfDaySlider = VisualsWorld.TimeOfDayToggle:AddSlider({
        enabled = true,
        text = "Clock Time",
        tooltip = "Set the in-game time (e.g., 0 for midnight, 12 for noon)",
        flag = "WorldVisuals_TimeOfDay",
        dragging = true,
        focused = false,
        min = 0,
        max = 24,
        increment = 1,
        risky = false,
        callback = function(v)
            if VisualsWorld.TimeOfDayToggle.state then
                Services.Lighting.ClockTime = v
            end
        end
    })

    VisualsWorld.Fog = VisualsWorld.Section:AddSlider({
        enabled = true,
        text = "Fog End",
        tooltip = "Adjust the distance at which fog ends",
        flag = "WorldVisuals_FogEnd",
        dragging = true,
        focused = false,
        min = 100,
        max = 100000,
        value = Services.Lighting.FogEnd or 100000,
        increment = 100,
        risky = false,
        callback = function(v)
            Services.Lighting.FogEnd = v
        end
    })

    VisualsWorld.CameraFOV = VisualsWorld.Section:AddSlider({
        enabled = true,
        text = "Camera FOV",
        tooltip = "Adjust your personal camera field of view",
        flag = "WorldVisuals_CameraFOV",
        suffix = "°",
        dragging = true,
        focused = false,
        min = 1,
        max = 120,
        value = game.Workspace.CurrentCamera.FieldOfView or 70,
        increment = 1,
        risky = false,
        callback = function(v)
            if game.Workspace.CurrentCamera then
                game.Workspace.CurrentCamera.FieldOfView = v
            end
        end
    })

    Menu["VisualsWorld"] = VisualsWorld

    ---
    --- WORLD TAB (Column 1)
    ---

    local WorldExploits = {
        Section = WorldTab:AddSection("Exploits", 1)
    }

    WorldExploits.Walkspeed = WorldExploits.Section:AddSlider({
        enabled = true,
        text = "Walk Speed",
        tooltip = "Adjust your character's walk speed",
        flag = "WorldExploits_Walkspeed",
        dragging = true,
        focused = false,
        min = 16,
        max = 100,
        increment = 1,
        risky = true,
        callback = function(v)
            return
        end
    })

    WorldExploits.Jumppower = WorldExploits.Section:AddSlider({
        enabled = true,
        text = "Jump Power",
        tooltip = "Adjust your character's jump power",
        flag = "WorldExploits_JumpPower",
        dragging = true,
        focused = false,
        min = 50,
        max = 500,
        increment = 10,
        risky = true,
        callback = function(v)
            return
        end
    })

    WorldExploits.Gravity = WorldExploits.Section:AddSlider({
        enabled = true,
        text = "Gravity Multiplier",
        tooltip = "Adjust the world gravity level (0 for fly, 1 for normal)",
        flag = "WorldExploits_Gravity",
        dragging = true,
        focused = false,
        min = 0,
        max = 2,
        increment = 0.05,
        risky = true,
        callback = function(v)
            return
        end
    })

    WorldExploits.AntiAfk = WorldExploits.Section:AddToggle({
        text = "Anti AFK",
        state = false,
        tooltip = "Prevents you from being kicked for inactivity",
        flag = "WorldExploits_AntiAFK",
        risky = false,
        callback = function(v)
            return
        end
    })

    WorldExploits.Noclip = WorldExploits.Section:AddToggle({
        text = "No Clip",
        state = false,
        tooltip = "Allows you to pass through walls and objects",
        flag = "WorldExploits_NoClip",
        risky = true,
        callback = function(v)
            return
        end
    })

    WorldExploits.NoclipBind = WorldExploits.Noclip:AddBind({
        enabled = true,
        text = "Noclip Key",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "WorldExploits_NoClipBindKey",
        state = false,
        risky = true,
        noindicator = false,
        callback = function(v)
            return
        end,
        keycallback = function(v)
            return
        end
    })

    WorldExploits.NoclipBindmode = WorldExploits.Section:AddList({
        enabled = true,
        text = "Bind Mode",
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = true,
        callback = function(v)
            WorldExploits.NoclipBind:SetMode(v:lower())
        end
    })

    Menu["WorldExploits"] = WorldExploits

    ---
    --- OTHER TAB (Column 1)
    ---

    local OtherUtility = {
        Section = OtherTab:AddSection("Utility", 1)
    }

    OtherUtility.LocalPlayerTP = OtherUtility.Section:AddToggle({
        text = "Local Player Teleport",
        state = false,
        tooltip = "Teleport to nearest player when key is pressed",
        flag = "OtherUtility_LPTP",
        risky = true,
        callback = function(v)
            return
        end
    })

    OtherUtility.ServerHop = OtherUtility.Section:AddToggle({
        text = "Server Hop",
        state = false,
        tooltip = "Automatically teleport to a new server",
        flag = "OtherUtility_ServerHop",
        risky = false,
        callback = function(v)
            return
        end
    })

    Menu["OtherUtility"] = OtherUtility

    local OtherChat = {
        Section = OtherTab:AddSection("Chat", 1)
    }

    OtherChat.Spammer = OtherChat.Section:AddToggle({
        text = "Chat Spammer",
        state = false,
        tooltip = "Toggle spamming a message in chat",
        flag = "OtherChat_SpammerToggle",
        risky = false,
        callback = function(v)
            Cache.chat.lastSpamTime = 0
        end
    })

    OtherChat.Text = OtherChat.Section:AddBox({
        enabled = true,
        text = "Spam Message",
        flag = "OtherChat_SpamMessage",
        callback = function(v)
            return
        end
    })

    OtherChat.Delay = OtherChat.Spammer:AddSlider({
        enabled = true,
        text = "Spam Delay",
        tooltip = "Time (in seconds) between each message",
        flag = "OtherChat_SpamDelay",
        dragging = true,
        focused = false,
        min = 0.1,
        max = 10,
        increment = 0.1,
        risky = false,
        callback = function(v)
            return
        end
    })

    Menu["OtherChat"] = OtherChat

    local OtherTrolling = {
        Section = OtherTab:AddSection("Trolling", 1)
    }

    OtherTrolling.KickPlayer = OtherTrolling.Section:AddButton({
        text = "Kick Nearest Player",
        tooltip = "Attempt to kick the nearest player (Exploit)",
        flag = "OtherTrolling_KickNearest",
        risky = true,
        callback = function()
            -- Logic to attempt a kick
        end
    })

    OtherTrolling.CrashServer = OtherTrolling.Section:AddButton({
        text = "Crash Server",
        tooltip = "Attempt to crash the entire server (Extremely Risky)",
        flag = "OtherTrolling_CrashServer",
        risky = true,
        callback = function()
            -- Logic to attempt a server crash
        end
    })

    Menu["OtherTrolling"] = OtherTrolling
end

local onInit = function()
    Cache.esp.screengui.Name = "ESP_LAYER"
    Cache.esp.screengui.ResetOnSpawn = false
    Cache.esp.screengui.Parent = PlayerStorage.PlayerGui

    local Time = (string.format("%." .. tostring(4) .. "f", os.clock() - Clock))
    UI:SendNotification(("Loaded In " .. tostring(Time)), 6)

    spawn(General.AntiAFKLoop)
end

local onStepped = function()
    local curTime = os.time()

    if Menu["OtherChat"].Spammer.state then
        General.ChatSpam(curTime)
    end

    if Menu["WorldExploits"].Noclip.state then
        local bind = Menu["WorldExploits"].NoclipBind

        if not bind or bind.bind == 'None' or bind.state then
            General.ToggleNoclip(true)
        end
    end
end

local onRenderStepped = function()
    local curTime = os.time()
end

OnLoad()
CreateMenu()

Hooks:Register("onInit", onInit)
Hooks:Register("OnStepped", onStepped)
Hooks:Register("onRenderStepped", onRenderStepped)
Hooks:RegisterCustom("Unload", onUnload)

Hooks:Initialize()
