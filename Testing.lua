local UIsuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Modules = {}
local function customRequire(module)
    if not module then return nil end
    local s, r = pcall(require, module)
    if s then return r end
    local clone = module:Clone()
    clone.Parent = nil
    local s2, r2 = pcall(require, clone)
    if s2 then return r2 end
    return nil
end

local ok = pcall(function()
    local Controllers = ReplicatedStorage:WaitForChild("Controllers", 20)
    local NetFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net", 20)
    local Shared = ReplicatedStorage:WaitForChild("Shared", 20)

    Modules.Replion = customRequire(ReplicatedStorage.Packages.Replion)
    Modules.ItemUtility = customRequire(Shared.ItemUtility)
    Modules.FishingController = customRequire(Controllers.FishingController)

    Modules.EquipToolEvent = NetFolder["RE/EquipToolFromHotbar"]
    Modules.ChargeRodFunc = NetFolder["RF/ChargeFishingRod"]
    Modules.StartMinigameFunc = NetFolder["RF/RequestFishingMinigameStarted"]
    Modules.CompleteFishingEvent = NetFolder["RE/FishingCompleted"]
end)

if not ok then
    return
end

task.wait(1)

local Window = WindUI:CreateWindow({
    Title = "X5 Lexs Hub",
    Icon = "star",
    Author = "Premium | Lexs Hub",
    Size = UDim2.fromOffset(450, 280),
    Folder = "Lexs_Hub",
    Transparent = true,
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.G,
    SideBarWidth = 140
})

local FishingSection = Window:Section({ Title = "X5 Speed Auto Fishing", Opened = true })
local FishingTab = FishingSection:Tab({ Title = "Fish Menu", Icon = "fish", ShowTabTitle = true })

local Config = Window.ConfigManager:CreateConfig("InstantFishingSettings")

local featureState = {
    AutoFish = false,
    Instant_ChargeDelay = 0.01,
    Instant_SpamCount = 25,
    Instant_WorkerCount = 5,
    Instant_StartDelay = 0.50,
    Instant_CatchTimeout = 0,
    Instant_CycleDelay = 0,
    Instant_ResetCount = 8,
    Instant_ResetPause = 0
}

local fishingTrove = {}
local fishCaughtBindable = Instance.new("BindableEvent")

local function equipFishingRod()
    if Modules.EquipToolEvent then
        pcall(Modules.EquipToolEvent.FireServer, Modules.EquipToolEvent, 1)
    end
end

task.spawn(function()
    local lastFish = ""
    while task.wait(0.25) do
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then continue end
        local gui = pg:FindFirstChild("Small Notification")
        if gui and gui.Enabled then
            local disp = gui:FindFirstChild("Display", true)
            local cont = disp and disp:FindFirstChild("Container", true)
            if cont then
                local item = cont:FindFirstChild("ItemName")
                if item and item.Text ~= "" and item.Text ~= lastFish then
                    lastFish = item.Text
                    fishCaughtBindable:Fire()
                end
            end
        else
            lastFish = ""
        end
    end
end)

local function stopAutoFish()
    featureState.AutoFish = false
    for _, v in ipairs(fishingTrove) do
        if typeof(v) == "RBXScriptConnection" then v:Disconnect() end
        if typeof(v) == "thread" then task.cancel(v) end
    end
    fishingTrove = {}
    pcall(function()
        if Modules.FishingController and Modules.FishingController.RequestClientStopFishing then
            Modules.FishingController:RequestClientStopFishing(true)
        end
    end)
end

local function startAutoFish()
    if not (Modules.ChargeRodFunc and Modules.StartMinigameFunc and Modules.CompleteFishingEvent) then
        return
    end

    featureState.AutoFish = true
    local chargeCount = 0
    local isReset = false
    local lock = false

    local function worker()
        while featureState.AutoFish and player do
            if isReset or chargeCount >= featureState.Instant_ResetCount then break end

            local ok = pcall(function()
                while lock do task.wait() end
                lock = true
                if chargeCount < featureState.Instant_ResetCount then
                    chargeCount += 1
                else
                    lock = false
                    return
                end
                lock = false

                Modules.ChargeRodFunc:InvokeServer(nil, nil, nil, workspace:GetServerTimeNow())
                task.wait(featureState.Instant_ChargeDelay)

                Modules.StartMinigameFunc:InvokeServer(-139, 1, workspace:GetServerTimeNow())
                task.wait(featureState.Instant_StartDelay)

                for _ = 1, featureState.Instant_SpamCount do
                    if not featureState.AutoFish or isReset then break end
                    Modules.CompleteFishingEvent:FireServer()
                    task.wait()
                end

                local got = false
                local connection = fishCaughtBindable.Event:Connect(function()
                    got = true
                    if connection.Connected then connection:Disconnect() end
                end)

                local t = 0
                while not got and t < featureState.Instant_CatchTimeout do
                    task.wait()
                    t += task.wait()
                end

                if connection and connection.Connected then connection:Disconnect() end

                if Modules.FishingController and Modules.FishingController.RequestClientStopFishing then
                    Modules.FishingController:RequestClientStopFishing(true)
                end
            end)

            if not ok then task.wait() end
            if not featureState.AutoFish then break end
            task.wait(featureState.Instant_CycleDelay)
        end
    end

    local mainThread = task.spawn(function()
        while featureState.AutoFish do
            chargeCount = 0
            isReset = false
            local batch = {}

            for i = 1, featureState.Instant_WorkerCount do
                local th = task.spawn(worker)
                table.insert(batch, th)
                table.insert(fishingTrove, th)
            end

            while featureState.AutoFish and chargeCount < featureState.Instant_ResetCount do
                task.wait()
            end

            isReset = true

            for _, th in ipairs(batch) do
                task.cancel(th)
            end

            task.wait(featureState.Instant_ResetPause)
        end
        stopAutoFish()
    end)

    table.insert(fishingTrove, mainThread)
end

local function toggleAutoFish(v)
    if v then
        stopAutoFish()
        featureState.AutoFish = true
        equipFishingRod()
        task.wait(0.01)
        startAutoFish()
    else
        stopAutoFish()
    end
end

FishingTab:Section({ Title = "Settings", Opened = true })

FishingTab:Slider({
    Title = "Delay Recast",
    Desc = "",
    Value = { Min = 0, Max = 5, Default = featureState.Instant_StartDelay },
    Precise = 2,
    Step = 0.01,
    Callback = function(v)
        featureState.Instant_StartDelay = tonumber(v)
    end
})

FishingTab:Slider({
    Title = "Spam Finish",
    Desc = "",
    Value = { Min = 5, Max = 50, Default = featureState.Instant_ResetCount },
    Precise = 0,
    Step = 1,
    Callback = function(v)
        featureState.Instant_ResetCount = math.floor(v)
    end
})

FishingTab:Section({ Title = "AutoFish X5 Extreme", Opened = true })

FishingTab:Toggle({
    Title = "AutoFish",
    Desc = "",
    Value = false,
    Callback = toggleAutoFish
})

local stopAnimConnections = {}
local function setAnim(v)
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    for _, c in ipairs(stopAnimConnections) do c:Disconnect() end
    stopAnimConnections = {}

    if v then
        for _, t in ipairs(hum:FindFirstChildOfClass("Animator"):GetPlayingAnimationTracks()) do
            t:Stop(0)
        end
        local c = hum:FindFirstChildOfClass("Animator").AnimationPlayed:Connect(function(t)
            task.defer(function() t:Stop(0) end)
        end)
        table.insert(stopAnimConnections, c)
    else
        for _, c in ipairs(stopAnimConnections) do c:Disconnect() end
        stopAnimConnections = {}
    end
end

FishingTab:Toggle({
    Title = "No Animation",
    Desc = "",
    Value = false,
    Callback = setAnim
})

local ConfigSection = Window:Section({ Title = "Settings", Opened = true })
local ConfigTab = ConfigSection:Tab({ Title = "Config Menu", Icon = "save", ShowTabTitle = true })

ConfigTab:Button({
    Title = "Save Config",
    Desc = "",
    Icon = "save",
    Callback = function()
        local s = pcall(Config.Save, Config)
        if s then
            WindUI:Notify({ Title = "Success", Content = "Configuration saved.", Duration = 3, Icon = "check-circle" })
        end
    end
})

ConfigTab:Button({
    Title = "Load Config",
    Desc = "",
    Icon = "upload-cloud",
    Callback = function()
        local s = pcall(Config.Load, Config)
        if s then
            WindUI:Notify({ Title = "Success", Content = "Configuration loaded.", Duration = 3, Icon = "check-circle" })
        end
    end
})

Window:SelectTab(1)
WindUI:Notify({
    Title = "X5 Extreme Ready",
    Content = "Speed Extreme Loaded!",
    Duration = 5,
    Icon = "zap"
})
