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
        lastSpamTime = 0,
    }
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

    center_pad = function(str, total_length, pad_char)
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

local CreateMenu = function()
    UI:init()

    local MainWindow = UI.NewWindow({
        title = string.format("%s | %s", Metadata.cheat, Metadata.build),
        size = UDim2.new(0, 510, 0.6, 6)
    })

    local LegitTab = MainWindow:AddTab(Utility.center_pad("Legit", 8))
    local RageTab = MainWindow:AddTab(Utility.center_pad("Rage", 8))
    local VisualsTab = MainWindow:AddTab(Utility.center_pad("Visuals", 8))
    local WorldTab = MainWindow:AddTab(Utility.center_pad("World", 8))
    local OtherTab = MainWindow:AddTab(Utility.center_pad("Other", 8))
    local SettingsTab = UI:CreateSettingsTab(MainWindow)

    ---
    --- LEGIT TAB (Column 1)
    ---

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

    LegitAimbot.Aimbotmode = LegitAimbot.Section:AddList({
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

    LegitAimbot.DrawFOV = LegitAimbot.Section:AddToggle({
        text = "Draw FOV Circle",
        state = false,
        tooltip = "Display the aimbot field of view on screen",
        flag = "LegitAimbot_DrawFOV",
        callback = function(v)
            return
        end
    })

    LegitAimbot.FOVColor = LegitAimbot.DrawFOV:AddColor({
        enabled = true,
        text = "FOV Circle Color",
        tooltip = "Color of the FOV circle",
        color = Color3.fromRGB(255, 255, 255),
        flag = "LegitAimbot_FOVColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    LegitAimbot.FOVThickness = LegitAimbot.DrawFOV:AddSlider({
        enabled = true,
        text = "FOV Line Thickness",
        tooltip = "Thickness of the FOV circle border",
        flag = "LegitAimbot_FOVThickness",
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

    Menu["LegitAimbot"] = LegitAimbot

    -- Targeting Section for Aimbot (Legit Tab - Column 1)
    local LegitAimbotTargeting = {
        Section = LegitTab:AddSection("Targeting", 1)
    }

    LegitAimbotTargeting.Hitboxes = LegitAimbotTargeting.Section:AddList({
        enabled = true,
        text = "Enabled Hitboxes",
        tooltip = "Hitboxes the aimbot can target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    LegitAimbotTargeting.PreferredHitboxes = LegitAimbotTargeting.Section:AddList({
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

    LegitAimbotTargeting.Priority = LegitAimbotTargeting.Section:AddList({
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

    LegitAimbotTargeting.Conditions = LegitAimbotTargeting.Section:AddList({
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

    Menu["LegitAimbotTargeting"] = LegitAimbotTargeting

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

    local Ragebot = {
        Section = RageTab:AddSection("Ragebot", 1)
    }

    Ragebot.Toggle = Ragebot.Section:AddToggle({
        text = "Toggle",
        state = false,
        tooltip = "Toggle ragebot features",
        flag = "Ragebot_Toggle",
        callback = function(v)
            return
        end
    })

    Ragebot.Bind = Ragebot.Toggle:AddBind({
        enabled = true,
        text = "Rage Key",
        tooltip = "Toggle on key press",
        mode = "toggle",
        bind = "None",
        flag = "Ragebot_BindKey",
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
        tooltip = "Select a bind mode (Toggle/Hold)",
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
        flag = "Ragebot_AutoFire",
        callback = function(v)
            return
        end
    })

    Ragebot.AutoFireBind = Ragebot.AutoFire:AddBind({
        enabled = true,
        text = "Auto Fire Key",
        tooltip = "Only auto fire when key is held",
        mode = "hold",
        bind = "None",
        flag = "Ragebot_AutoFireBindKey",
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

    Ragebot.AutoFireBindmode = Ragebot.Section:AddList({
        enabled = true,
        text = "Bind Mode",
        tooltip = "Select a bind mode (Toggle/Hold)",
        selected = "Toggle",
        multi = false,
        open = false,
        values = {"None", "Toggle", "Hold"},
        risky = false,
        callback = function(v)
            Ragebot.AutoFireBindmode:SetMode(v:lower())
        end
    })

    if Metadata.game ~= "Da Hood" then
        Ragebot.AutoWall = Ragebot.Section:AddToggle({
            text = "Auto Wall",
            state = false,
            tooltip = "Allows aiming and shooting through materials/walls",
            flag = "Ragebot_AutoWall_Toggle",
            risky = true,
            callback = function(v)
                return
            end
        })

        Ragebot.AutoWallMinDamage = Ragebot.AutoWall:AddSlider({
            enabled = true,
            text = "Min Wall Damage",
            tooltip = "Minimum required damage through a wall to shoot",
            flag = "Ragebot_AutoWallMinDamage",
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

    Ragebot.AimbotMode = Ragebot.Section:AddList({
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

    Ragebot.FOV = Ragebot.Section:AddSlider({
        enabled = true,
        text = "FOV",
        tooltip = "Adjust aimbot field of view (Silent Aim ignores this)",
        flag = "Ragebot_FOV",
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

    Ragebot.Prediction = Ragebot.Section:AddSlider({
        enabled = true,
        text = "Prediction",
        tooltip = "Compensate for target movement/ping",
        flag = "Ragebot_Prediction",
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

    Menu["Ragebot"] = Ragebot

    -- Ragebot Targeting (Column 1)
    local RagebotTargeting = {
        Section = RageTab:AddSection("Targeting", 1)
    }

    RagebotTargeting.Hitboxes = RagebotTargeting.Section:AddList({
        enabled = true,
        text = "Enabled Hitboxes",
        tooltip = "Hitboxes the ragebot can target",
        multi = true,
        open = false,
        values = {"Head", "Upper Torso", "Lower Torso", "Upper Arms", "Lower Arms", "Hands", "Upper Legs", "Lower Legs",
                  "Feet"},
        risky = false,
        callback = function(v)
        end
    })

    RagebotTargeting.PreferredHitboxes = RagebotTargeting.Section:AddList({
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

    RagebotTargeting.Priority = RagebotTargeting.Section:AddList({
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

    RagebotTargeting.Conditions = RagebotTargeting.Section:AddList({
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

    Menu["RagebotTargeting"] = RagebotTargeting

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
        text = "Toggle",
        state = false,
        tooltip = "Toggle all ESP features",
        flag = "VisualsESP_Toggle",
        callback = function(v)
            return
        end
    })

    VisualsESP.MaxDistance = VisualsESP.Toggle:AddSlider({
        enabled = true,
        text = "Max Distance",
        tooltip = "Adjust ESP max view distance in studs",
        flag = "VisualsESP_MaxDistance",
        dragging = true,
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
        tooltip = "Draw a 2D or 3D box around targets",
        flag = "VisualsESP_Box",
        callback = function(v)
            return
        end
    })

    VisualsESP.BoxType = VisualsESP.Box:AddList({
        enabled = true,
        text = "Box Type",
        tooltip = "Select Box Style",
        selected = "2D",
        multi = false,
        open = false,
        values = {"2D", "Corner", "3D", "Bounding"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsESP.BoxFill = VisualsESP.Box:AddColor({
        enabled = true,
        text = "Box Fill Color",
        tooltip = "Inner fill color for the box (0% opacity for outline only)",
        color = Color3.fromRGB(20, 20, 20),
        flag = "VisualsESP_BoxFillColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsESP.Outline = VisualsESP.Section:AddToggle({
        text = "Outline/Stroke",
        state = false,
        tooltip = "Draw an outline/stroke around the box",
        flag = "VisualsESP_BoxOutline",
        callback = function(v)
            return
        end
    })

    VisualsESP.Tracers = VisualsESP.Section:AddToggle({
        text = "Tracers",
        state = false,
        tooltip = "Draw lines from screen center/bottom to targets",
        flag = "VisualsESP_Tracers",
        callback = function(v)
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

    VisualsESP.NameSize = VisualsESP.Name:AddSlider({
        enabled = true,
        text = "Font Size",
        tooltip = "Adjust the size of the displayed name text",
        flag = "VisualsESP_NameSize",
        dragging = true,
        focused = false,
        min = 8,
        max = 24,
        increment = 1,
        risky = false,
        callback = function(v)
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

    VisualsESP.Distance = VisualsESP.Section:AddToggle({
        text = "Distance",
        state = false,
        tooltip = "Display distance to target",
        flag = "VisualsESP_Distance",
        callback = function(v)
            return
        end
    })

    Menu["VisualsESP"] = VisualsESP

    -- Visuals Chams/Models (Column 2)
    local VisualsChams = {
        Section = VisualsTab:AddSection("Chams & Models", 2)
    }

    VisualsChams.Chams = VisualsChams.Section:AddToggle({
        text = "Chams",
        state = false,
        tooltip = "Change material/color of models (e.g., targets, weapons)",
        flag = "VisualsChams_Toggle",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsChams.ChamsType = VisualsChams.Chams:AddList({
        enabled = true,
        text = "Chams Type",
        tooltip = "Select Chams Style",
        selected = "Flat",
        multi = false,
        open = false,
        values = {"Flat", "Pulse", "Glow", "Wireframe", "Shine"},
        risky = false,
        callback = function(v)
        end
    })

    VisualsChams.TargetColor = VisualsChams.Chams:AddColor({
        enabled = true,
        text = "Target Color (Enemy)",
        tooltip = "Color of enemy models",
        color = Color3.fromRGB(255, 0, 0),
        flag = "VisualsChams_EnemyColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsChams.TeamColor = VisualsChams.Chams:AddColor({
        enabled = true,
        text = "Team Color (Friendly)",
        tooltip = "Color of friendly models",
        color = Color3.fromRGB(0, 255, 0),
        flag = "VisualsChams_TeamColor",
        open = false,
        risky = false,
        callback = function()
            return
        end
    })

    VisualsChams.Transparency = VisualsChams.Chams:AddSlider({
        enabled = true,
        text = "Transparency",
        tooltip = "Adjust the transparency of the chams material",
        flag = "VisualsChams_Transparency",
        dragging = true,
        focused = false,
        min = 0,
        max = 1,
        increment = 0.05,
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsChams.ThroughWalls = VisualsChams.Section:AddToggle({
        text = "Through Walls",
        state = false,
        tooltip = "Render target models through objects (requires Chams)",
        flag = "VisualsChams_ThroughWalls",
        risky = false,
        callback = function(v)
            return
        end
    })

    VisualsChams.Weapon = VisualsChams.Section:AddToggle({
        text = "Weapon ESP",
        state = false,
        tooltip = "Display enemy current weapon name",
        flag = "VisualsChams_Weapon",
        callback = function(v)
            return
        end
    })

    Menu["VisualsChams"] = VisualsChams

    -- Visuals Effects (Column 2)
    local VisualsEffects = {
        Section = VisualsTab:AddSection("Effects", 2)
    }

    VisualsEffects.Ambient = VisualsEffects.Section:AddToggle({
        text = "Full Bright",
        state = false,
        tooltip = "Increases the environment brightness",
        flag = "VisualsEffects_FullBright",
        callback = function(v)
            return
        end
    })

    VisualsEffects.NoSky = VisualsEffects.Section:AddToggle({
        text = "No Sky",
        state = false,
        tooltip = "Removes the skybox for clarity/visibility",
        flag = "VisualsEffects_NoSky",
        callback = function(v)
            return
        end
    })

    VisualsEffects.NoPost = VisualsEffects.Section:AddToggle({
        text = "Remove Post Processing",
        state = false,
        tooltip = "Removes blurring, color correction, and screen effects",
        flag = "VisualsEffects_NoPost",
        callback = function(v)
            return
        end
    })

    Menu["VisualsEffects"] = VisualsEffects

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

    Menu["WorldExploits"] = WorldExploits

    local WorldVisuals = {
        Section = WorldTab:AddSection("Visuals", 1)
    }

    WorldVisuals.TimeOfDayToggle = WorldVisuals.Section:AddToggle({
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

    WorldVisuals.TimeOfDaySlider = WorldVisuals.TimeOfDayToggle:AddSlider({
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
            if WorldVisuals.TimeOfDayToggle.state then
                Services.Lighting.ClockTime = v
            end
        end
    })

    WorldVisuals.Fog = WorldVisuals.Section:AddSlider({
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

    WorldVisuals.CameraFOV = WorldVisuals.Section:AddSlider({
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

    Menu["WorldVisuals"] = WorldVisuals

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
        min = 0.5,
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
    local Time = (string.format("%." .. tostring(4) .. "f", os.clock() - Clock))
    UI:SendNotification(("Loaded In " .. tostring(Time)), 6)
end

local onRenderStepped = function()
    
end

OnLoad()
CreateMenu()

Hooks:Register("onInit", onInit)
Hooks:Register("onRenderStepped", onRenderStepped)
Hooks:RegisterCustom("Unload", onUnload)

Hooks:Initialize()
