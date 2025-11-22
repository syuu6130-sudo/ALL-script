--// Murderers vs Sheriffs 2 - 究極最適化版 Part 1/3 //--
-- 作者: @syu_u0316 --
-- 7つのスクリプトから最適な機能を統合 --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ========== サービス ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== グローバル設定 ==========
_G.HeadSize = 20
_G.Disabled = true

local config = {
    -- エイム
    softAimEnabled = false,
    autoAimEnabled = false,
    silentAimEnabled = false,
    lockTargetEnabled = false,
    aimStrength = 0.35,
    aimPart = "Head",
    aimFOV = 200,
    wallCheck = true,
    teamCheck = true,
    
    -- 射撃
    autoShootEnabled = false,
    triggerBotEnabled = false,
    autoEquipEnabled = false,
    shootDelay = 0.1,
    burstCount = 1,
    rapidFire = false,
    
    -- ヒットボックス
    hitboxEnabled = false,
    hitboxSize = 20,
    hitboxTransparency = 0.7,
    
    -- ESP
    espEnabled = false,
    espBoxes = false,
    espNames = false,
    espDistance = false,
    espHealth = false,
    espTracers = false,
    
    -- 視覚効果
    fovCircleEnabled = false,
    fovCircleRadius = 100,
    rainbowCircle = false,
    
    -- 移動
    flyEnabled = false,
    flySpeed = 50,
    noClipEnabled = false,
    speedEnabled = false,
    walkSpeed = 16,
    jumpPower = 50,
}

local state = {
    currentTarget = nil,
    lastShootTime = 0,
    isShootingActive = false,
    currentWeapon = nil,
    weaponRemotes = {},
    espObjects = {},
    bodyVelocity = nil,
}

-- ========== デバッグシステム ==========
local debugLog = {}
local function log(msg)
    local timestamp = os.date("%H:%M:%S")
    local logMsg = "[" .. timestamp .. "] " .. msg
    table.insert(debugLog, logMsg)
    if #debugLog > 100 then
        table.remove(debugLog, 1)
    end
    print(logMsg)
end

-- ========== ユーティリティ関数 ==========
local function isAlive(plr)
    if not plr or not plr.Character then return false end
    local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function isEnemy(plr)
    if not config.teamCheck then return true end
    if not player.Team or not plr.Team then return true end
    return plr.Team ~= player.Team
end

local function isVisible(targetPart)
    if not config.wallCheck then return true end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * 1000
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {player.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, rayParams)
    
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getScreenPosition(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function isInFOV(screenPos)
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    local distance = (Vector2.new(centerX, centerY) - screenPos).Magnitude
    return distance <= config.fovCircleRadius
end

-- ========== 武器検出システム (7つのスクリプトから統合) ==========
local function scanWeapon(tool)
    log("🔍 武器スキャン: " .. tool.Name)
    state.weaponRemotes = {}
    
    -- RemoteEvent/RemoteFunction検索
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            table.insert(state.weaponRemotes, desc)
            log("✅ Remote: " .. desc.Name)
        end
    end
    
    -- ReplicatedStorageも検索
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            local name = remote.Name:lower()
            if name:find("fire") or name:find("shoot") or name:find("gun") or name:find("weapon") then
                table.insert(state.weaponRemotes, remote)
                log("✅ RS Remote: " .. remote.Name)
            end
        end
    end
    
    log("📊 検出結果: " .. #state.weaponRemotes .. "個のRemote")
end

local function getEquippedWeapon()
    if not player.Character then return nil end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    
    if tool and tool ~= state.currentWeapon then
        state.currentWeapon = tool
        scanWeapon(tool)
    end
    
    return tool
end

local function autoEquipWeapon()
    if not config.autoEquipEnabled then return getEquippedWeapon() end
    
    if not getEquippedWeapon() then
        for _, item in ipairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:EquipTool(item)
                    task.wait(0.1)
                    return item
                end
            end
        end
    end
    
    return getEquippedWeapon()
end

-- ========== 超高密度射撃システム (10層統合版) ==========
local shootMethods = {}

-- 方法1: Tool:Activate()
shootMethods[1] = function(tool)
    return pcall(function() tool:Activate() end)
end

-- 方法2: RemoteEvent:FireServer() (全パターン)
shootMethods[2] = function(tool)
    local success = false
    for _, remote in ipairs(state.weaponRemotes) do
        if remote:IsA("RemoteEvent") then
            pcall(function()
                remote:FireServer()
                remote:FireServer(mouse.Hit.Position)
                remote:FireServer(mouse.Hit)
                remote:FireServer(true)
                remote:FireServer(mouse.Target)
                success = true
            end)
        end
    end
    return success
end

-- 方法3: RemoteFunction:InvokeServer()
shootMethods[3] = function(tool)
    local success = false
    for _, remote in ipairs(state.weaponRemotes) do
        if remote:IsA("RemoteFunction") then
            pcall(function()
                remote:InvokeServer()
                remote:InvokeServer(mouse.Hit.Position)
                remote:InvokeServer(mouse.Hit)
                success = true
            end)
        end
    end
    return success
end

-- 方法4: VirtualInputManager
shootMethods[4] = function(tool)
    return pcall(function()
        local pos = UserInputService:GetMouseLocation()
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
end

-- 方法5: mouse1press/release
shootMethods[5] = function(tool)
    return pcall(function()
        mouse1press()
        task.wait(0.05)
        mouse1release()
    end)
end

-- 方法6: Tool.Activated イベント
shootMethods[6] = function(tool)
    return pcall(function()
        for _, connection in ipairs(getconnections(tool.Activated)) do
            connection:Fire()
        end
    end)
end

-- 方法7: Handle.Touched
shootMethods[7] = function(tool)
    local handle = tool:FindFirstChild("Handle")
    if handle then
        return pcall(function()
            for _, connection in ipairs(getconnections(handle.Touched)) do
                connection:Fire()
            end
        end)
    end
    return false
end

-- 方法8: Mouse.Button1Down
shootMethods[8] = function(tool)
    return pcall(function()
        for _, connection in ipairs(getconnections(mouse.Button1Down)) do
            connection:Fire()
        end
    end)
end

-- 方法9: BindableEvent発火
shootMethods[9] = function(tool)
    local success = false
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("BindableEvent") then
            pcall(function()
                v:Fire()
                success = true
            end)
        end
    end
    return success
end

-- 方法10: 全Connection発火
shootMethods[10] = function(tool)
    local success = false
    for _, remote in ipairs(state.weaponRemotes) do
        if remote:IsA("RemoteEvent") then
            pcall(function()
                for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                    conn:Fire()
                    success = true
                end
            end)
        end
    end
    return success
end

local function shootWeapon()
    if state.isShootingActive then return false end
    state.isShootingActive = true
    
    local tool = getEquippedWeapon()
    if not tool then
        state.isShootingActive = false
        return false
    end
    
    local successCount = 0
    
    -- ラピッドファイアモード
    if config.rapidFire then
        for i = 1, math.min(#shootMethods, 5) do
            task.spawn(function()
                if shootMethods[i](tool) then
                    successCount = successCount + 1
                end
            end)
        end
    else
        -- 通常モード（効率的な方法のみ）
        for i = 1, 5 do
            if shootMethods[i](tool) then
                successCount = successCount + 1
                break
            end
        end
    end
    
    task.wait(0.05)
    state.isShootingActive = false
    
    return successCount > 0
end

-- ========== ターゲット取得システム ==========
local function getClosestEnemy()
    local closest = nil
    local shortestDistance = config.aimFOV
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isAlive(plr) and isEnemy(plr) then
            local character = plr.Character
            local targetPart = character:FindFirstChild(config.aimPart) or character:FindFirstChild("Head")
            
            if targetPart then
                local screenPos, onScreen = getScreenPosition(targetPart.Position)
                
                if onScreen then
                    local distance = (Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) - screenPos).Magnitude
                    
                    if distance < shortestDistance then
                        if config.wallCheck then
                            if isVisible(targetPart) then
                                closest = character
                                shortestDistance = distance
                            end
                        else
                            closest = character
                            shortestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closest
end

log("========================================")
log("  Part 1/3 読み込み完了")
log("  基本システム・武器検出・射撃システム")
log("========================================")

-- Part 2に続く...
--// Murderers vs Sheriffs 2 - 究極最適化版 Part 2/3 //--
-- Part 1の続き：ビジュアルシステム・エイム・移動 --

-- ========== ヒットボックス拡大 (TbaoHub方式) ==========
local function updateHitboxes()
    if not config.hitboxEnabled then return end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isAlive(plr) and isEnemy(plr) then
            local character = plr.Character
            local hrp = character:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                pcall(function()
                    hrp.Size = Vector3.new(config.hitboxSize, config.hitboxSize, config.hitboxSize)
                    hrp.Transparency = config.hitboxTransparency
                    hrp.BrickColor = BrickColor.new("Really red")
                    hrp.Material = Enum.Material.Neon
                    hrp.CanCollide = false
                    hrp.Massless = true
                end)
            end
        end
    end
end

-- ========== ESP システム (ImpHub方式) ==========
local function createESP(character)
    local espFolder = Instance.new("Folder")
    espFolder.Name = "ESP_" .. character.Name
    espFolder.Parent = game.CoreGui
    
    if config.espBoxes then
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "ESP"
        billboardGui.Adornee = character:FindFirstChild("HumanoidRootPart")
        billboardGui.Size = UDim2.new(4, 0, 5, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = espFolder
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 0.7
        frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        frame.BorderSizePixel = 2
        frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
        frame.Parent = billboardGui
    end
    
    if config.espNames then
        local nameLabel = Instance.new("BillboardGui")
        nameLabel.Name = "NameESP"
        nameLabel.Adornee = character:FindFirstChild("Head")
        nameLabel.Size = UDim2.new(0, 200, 0, 50)
        nameLabel.StudsOffset = Vector3.new(0, 2, 0)
        nameLabel.AlwaysOnTop = true
        nameLabel.Parent = espFolder
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = character.Name
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextSize = 16
        textLabel.Parent = nameLabel
    end
    
    if config.espDistance then
        local distLabel = Instance.new("BillboardGui")
        distLabel.Name = "DistanceESP"
        distLabel.Adornee = character:FindFirstChild("HumanoidRootPart")
        distLabel.Size = UDim2.new(0, 200, 0, 30)
        distLabel.StudsOffset = Vector3.new(0, -2, 0)
        distLabel.AlwaysOnTop = true
        distLabel.Parent = espFolder
        
        local distText = Instance.new("TextLabel")
        distText.Size = UDim2.new(1, 0, 1, 0)
        distText.BackgroundTransparency = 1
        distText.TextColor3 = Color3.fromRGB(255, 255, 0)
        distText.TextStrokeTransparency = 0
        distText.Font = Enum.Font.SourceSans
        distText.TextSize = 14
        distText.Parent = distLabel
        
        -- 距離更新
        task.spawn(function()
            while distLabel.Parent do
                local dist = (character:FindFirstChild("HumanoidRootPart").Position - player.Character.HumanoidRootPart.Position).Magnitude
                distText.Text = math.floor(dist) .. " studs"
                task.wait(0.1)
            end
        end)
    end
    
    if config.espTracers then
        local attachment = Instance.new("Attachment")
        attachment.Parent = character:FindFirstChild("HumanoidRootPart")
        
        local beam = Instance.new("Beam")
        beam.Attachment0 = Camera:FindFirstChild("CameraAttachment") or Instance.new("Attachment", Camera)
        beam.Attachment1 = attachment
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.FaceCamera = true
        beam.Width0 = 0.5
        beam.Width1 = 0.5
        beam.Parent = espFolder
    end
    
    state.espObjects[character] = espFolder
end

local function updateESP()
    if not config.espEnabled then
        for _, espFolder in pairs(state.espObjects) do
            if espFolder then
                espFolder:Destroy()
            end
        end
        state.espObjects = {}
        return
    end
    
    -- 既存ESPをクリーンアップ
    for character, espFolder in pairs(state.espObjects) do
        if not character or not character.Parent or not isAlive(Players:GetPlayerFromCharacter(character)) then
            espFolder:Destroy()
            state.espObjects[character] = nil
        end
    end
    
    -- 新しいESPを作成
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isAlive(plr) and isEnemy(plr) then
            local character = plr.Character
            if not state.espObjects[character] then
                createESP(character)
            end
        end
    end
end

-- ========== Silent Aim (メタテーブルフック) ==========
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if config.silentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if typeof(args[1]) == "Vector3" then
                    args[1] = targetPart.Position
                elseif typeof(args[1]) == "CFrame" then
                    args[1] = targetPart.CFrame
                elseif typeof(args[1]) == "Instance" then
                    args[1] = targetPart
                end
            end
        end
    end
    
    return oldNamecall(self, unpack(args))
end)

mt.__index = newcclosure(function(self, key)
    if config.silentAimEnabled and (key == "Hit" or key == "Target") then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if key == "Hit" then
                    return targetPart.CFrame
                else
                    return targetPart
                end
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- ========== FOV円描画 ==========
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 50
fovCircle.Radius = config.fovCircleRadius
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.ZIndex = 999
fovCircle.Transparency = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)

local function updateFOVCircle()
    if config.fovCircleEnabled then
        fovCircle.Visible = true
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = config.fovCircleRadius
        
        if config.rainbowCircle then
            local hue = (tick() % 5) / 5
            fovCircle.Color = Color3.fromHSV(hue, 1, 1)
        end
    else
        fovCircle.Visible = false
    end
end

-- ========== 飛行システム ==========
local function toggleFly()
    if config.flyEnabled then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not state.bodyVelocity then
                state.bodyVelocity = Instance.new("BodyVelocity")
                state.bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                state.bodyVelocity.Parent = player.Character.HumanoidRootPart
                log("✈️ 飛行: 有効")
            end
        end
    else
        if state.bodyVelocity then
            state.bodyVelocity:Destroy()
            state.bodyVelocity = nil
            log("✈️ 飛行: 無効")
        end
    end
end

local function updateFly()
    if config.flyEnabled and state.bodyVelocity then
        local moveDir = Vector3.zero
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then 
            moveDir = moveDir + Camera.CFrame.LookVector 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then 
            moveDir = moveDir - Camera.CFrame.LookVector 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
            moveDir = moveDir - Camera.CFrame.RightVector 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
            moveDir = moveDir + Camera.CFrame.RightVector 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 
            moveDir = moveDir + Vector3.new(0, 1, 0) 
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 
            moveDir = moveDir - Vector3.new(0, 1, 0) 
        end
        
        state.bodyVelocity.Velocity = moveDir * config.flySpeed
    end
end

-- ========== NoClip ==========
local function updateNoClip()
    if config.noClipEnabled and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

-- ========== 速度変更 ==========
local function updateSpeed()
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if config.speedEnabled then
                humanoid.WalkSpeed = config.walkSpeed
                humanoid.JumpPower = config.jumpPower
            end
        end
    end
end

-- ========== メインループ ==========
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
    -- エイムアシスト
    if config.softAimEnabled or config.autoAimEnabled or config.lockTargetEnabled then
        local target = getClosestEnemy()
        
        if target then
            local targetPart = target:FindFirstChild(config.aimPart) or target:FindFirstChild("Head")
            
            if targetPart then
                state.currentTarget = target
                
                if config.softAimEnabled then
                    local targetCF = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(targetCF, config.aimStrength)
                end
                
                if config.autoAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
                
                -- 自動射撃
                if config.autoShootEnabled and currentTime - state.lastShootTime > config.shootDelay then
                    if config.autoEquipEnabled then
                        autoEquipWeapon()
                    end
                    
                    task.spawn(function()
                        for i = 1, config.burstCount do
                            if shootWeapon() then
                                state.lastShootTime = currentTime
                            end
                            if config.burstCount > 1 then
                                task.wait(0.05)
                            end
                        end
                    end)
                end
            end
        else
            state.currentTarget = nil
        end
    end
    
    -- トリガーボット
    if config.triggerBotEnabled then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(config.aimPart) or target:FindFirstChild("Head")
            if targetPart then
                local screenPos, onScreen = getScreenPosition(targetPart.Position)
                if onScreen and isInFOV(screenPos) then
                    if currentTime - state.lastShootTime > config.shootDelay then
                        if config.autoEquipEnabled then
                            autoEquipWeapon()
                        end
                        
                        if shootWeapon() then
                            state.lastShootTime = currentTime
                        end
                    end
                end
            end
        end
    end
    
    -- その他の更新
    updateHitboxes()
    updateESP()
    updateFOVCircle()
    updateFly()
    updateNoClip()
    updateSpeed()
end)

log("========================================")
log("  Part 2/3 読み込み完了")
log("  ESP・ヒットボックス・エイム・移動")
log("========================================")

-- Part 3に続く...
--// Murderers vs Sheriffs 2 - 究極最適化版 Part 3/3 //--
-- Part 2の続き：Rayfield UIシステム --

-- ========== Rayfieldウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
    Name = "🎯 Murderers vs Sheriffs 2 Ultimate",
    LoadingTitle = "究極最適化版 v3.0",
    LoadingSubtitle = "by @syu_u0316",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MVS2_Ultimate",
        FileName = "config"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false
})

-- ========== タブ作成 ==========
local CombatTab = Window:CreateTab("⚔️ 戦闘", nil)
local ShootTab = Window:CreateTab("🔫 射撃", nil)
local VisualTab = Window:CreateTab("👁️ ビジュアル", nil)
local MovementTab = Window:CreateTab("🏃 移動", nil)
local MiscTab = Window:CreateTab("⚙️ その他", nil)

-- ========== 戦闘タブ ==========
CombatTab:CreateSection("エイムアシスト")

CombatTab:CreateToggle({
    Name = "ソフトエイム (スムーズ)",
    CurrentValue = false,
    Flag = "SoftAim",
    Callback = function(Value)
        config.softAimEnabled = Value
        log("ソフトエイム: " .. tostring(Value))
    end,
})

CombatTab:CreateToggle({
    Name = "自動エイム (ロックオン)",
    CurrentValue = false,
    Flag = "AutoAim",
    Callback = function(Value)
        config.autoAimEnabled = Value
        log("自動エイム: " .. tostring(Value))
    end,
})

CombatTab:CreateToggle({
    Name = "サイレントエイム (見えない)",
    CurrentValue = false,
    Flag = "SilentAim",
    Callback = function(Value)
        config.silentAimEnabled = Value
        log("サイレントエイム: " .. tostring(Value))
    end,
})

CombatTab:CreateSlider({
    Name = "エイム強度",
    Range = {0.1, 1},
    Increment = 0.05,
    CurrentValue = 0.35,
    Flag = "AimStrength",
    Callback = function(Value)
        config.aimStrength = Value
    end,
})

CombatTab:CreateDropdown({
    Name = "狙う部位",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    CurrentOption = "Head",
    Flag = "AimPart",
    Callback = function(Option)
        config.aimPart = Option
        log("狙う部位: " .. Option)
    end,
})

CombatTab:CreateSection("エイム設定")

CombatTab:CreateToggle({
    Name = "壁判定 (壁越しを無視)",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(Value)
        config.wallCheck = Value
    end,
})

CombatTab:CreateToggle({
    Name = "チーム判定",
    CurrentValue = true,
    Flag = "TeamCheck",
    Callback = function(Value)
        config.teamCheck = Value
    end,
})

CombatTab:CreateSlider({
    Name = "視野角 (FOV)",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = 200,
    Flag = "AimFOV",
    Callback = function(Value)
        config.aimFOV = Value
    end,
})

-- ========== 射撃タブ ==========
ShootTab:CreateSection("自動射撃")

ShootTab:CreateToggle({
    Name = "自動射撃",
    CurrentValue = false,
    Flag = "AutoShoot",
    Callback = function(Value)
        config.autoShootEnabled = Value
        log("自動射撃: " .. tostring(Value))
    end,
})

ShootTab:CreateToggle({
    Name = "トリガーボット (照準時のみ)",
    CurrentValue = false,
    Flag = "TriggerBot",
    Callback = function(Value)
        config.triggerBotEnabled = Value
        log("トリガーボット: " .. tostring(Value))
    end,
})

ShootTab:CreateToggle({
    Name = "武器自動装備",
    CurrentValue = false,
    Flag = "AutoEquip",
    Callback = function(Value)
        config.autoEquipEnabled = Value
    end,
})

ShootTab:CreateToggle({
    Name = "ラピッドファイア (超高速)",
    CurrentValue = false,
    Flag = "RapidFire",
    Callback = function(Value)
        config.rapidFire = Value
        log("ラピッドファイア: " .. tostring(Value))
    end,
})

ShootTab:CreateSlider({
    Name = "射撃間隔 (秒)",
    Range = {0.05, 1},
    Increment = 0.01,
    CurrentValue = 0.1,
    Flag = "ShootDelay",
    Callback = function(Value)
        config.shootDelay = Value
    end,
})

ShootTab:CreateSlider({
    Name = "バースト射撃数",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Flag = "BurstCount",
    Callback = function(Value)
        config.burstCount = Value
    end,
})

ShootTab:CreateSection("テスト")

ShootTab:CreateButton({
    Name = "手動射撃テスト",
    Callback = function()
        log("🎯 手動射撃実行")
        if config.autoEquipEnabled then
            autoEquipWeapon()
        end
        shootWeapon()
    end,
})

ShootTab:CreateButton({
    Name = "武器再スキャン",
    Callback = function()
        local tool = getEquippedWeapon()
        if tool then
            scanWeapon(tool)
            Rayfield:Notify({
                Title = "スキャン完了",
                Content = "Remote: " .. #state.weaponRemotes .. "個検出",
                Duration = 3,
            })
        else
            Rayfield:Notify({
                Title = "エラー",
                Content = "武器が装備されていません",
                Duration = 3,
            })
        end
    end,
})

-- ========== ビジュアルタブ ==========
VisualTab:CreateSection("ESP (透視)")

VisualTab:CreateToggle({
    Name = "ESP有効",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(Value)
        config.espEnabled = Value
        log("ESP: " .. tostring(Value))
    end,
})

VisualTab:CreateToggle({
    Name = "ボックス表示",
    CurrentValue = false,
    Flag = "ESPBoxes",
    Callback = function(Value)
        config.espBoxes = Value
    end,
})

VisualTab:CreateToggle({
    Name = "名前表示",
    CurrentValue = false,
    Flag = "ESPNames",
    Callback = function(Value)
        config.espNames = Value
    end,
})

VisualTab:CreateToggle({
    Name = "距離表示",
    CurrentValue = false,
    Flag = "ESPDistance",
    Callback = function(Value)
        config.espDistance = Value
    end,
})

VisualTab:CreateToggle({
    Name = "トレーサー (線)",
    CurrentValue = false,
    Flag = "ESPTracers",
    Callback = function(Value)
        config.espTracers = Value
    end,
})

VisualTab:CreateSection("ヒットボックス拡大")

VisualTab:CreateToggle({
    Name = "ヒットボックス有効",
    CurrentValue = false,
    Flag = "Hitbox",
    Callback = function(Value)
        config.hitboxEnabled = Value
        log("ヒットボックス: " .. tostring(Value))
    end,
})

VisualTab:CreateSlider({
    Name = "ヒットボックスサイズ",
    Range = {5, 50},
    Increment = 1,
    CurrentValue = 20,
    Flag = "HitboxSize",
    Callback = function(Value)
        config.hitboxSize = Value
    end,
})

VisualTab:CreateSlider({
    Name = "透明度",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0.7,
    Flag = "HitboxTransparency",
    Callback = function(Value)
        config.hitboxTransparency = Value
    end,
})

VisualTab:CreateSection("FOV円")

VisualTab:CreateToggle({
    Name = "FOV円を表示",
    CurrentValue = false,
    Flag = "FOVCircle",
    Callback = function(Value)
        config.fovCircleEnabled = Value
    end,
})

VisualTab:CreateToggle({
    Name = "虹色エフェクト",
    CurrentValue = false,
    Flag = "RainbowCircle",
    Callback = function(Value)
        config.rainbowCircle = Value
    end,
})

VisualTab:CreateSlider({
    Name = "円の半径",
    Range = {50, 300},
    Increment = 10,
    CurrentValue = 100,
    Flag = "CircleRadius",
    Callback = function(Value)
        config.fovCircleRadius = Value
    end,
})

-- ========== 移動タブ ==========
MovementTab:CreateSection("飛行")

MovementTab:CreateToggle({
    Name = "飛行",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(Value)
        config.flyEnabled = Value
        toggleFly()
    end,
})

MovementTab:CreateSlider({
    Name = "飛行速度",
    Range = {10, 200},
    Increment = 5,
    CurrentValue = 50,
    Flag = "FlySpeed",
    Callback = function(Value)
        config.flySpeed = Value
    end,
})

MovementTab:CreateSection("移動設定")

MovementTab:CreateToggle({
    Name = "NoClip (壁抜け)",
    CurrentValue = false,
    Flag = "NoClip",
    Callback = function(Value)
        config.noClipEnabled = Value
        log("NoClip: " .. tostring(Value))
    end,
})

MovementTab:CreateToggle({
    Name = "速度変更",
    CurrentValue = false,
    Flag = "Speed",
    Callback = function(Value)
        config.speedEnabled = Value
    end,
})

MovementTab:CreateSlider({
    Name = "歩行速度",
    Range = {16, 200},
    Increment = 2,
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(Value)
        config.walkSpeed = Value
    end,
})

MovementTab:CreateSlider({
    Name = "ジャンプ力",
    Range = {50, 200},
    Increment = 5,
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(Value)
        config.jumpPower = Value
    end,
})

-- ========== その他タブ ==========
MiscTab:CreateSection("情報")

local StatusLabel = MiscTab:CreateLabel("ステータス: 待機中")

MiscTab:CreateButton({
    Name = "ステータス更新",
    Callback = function()
        local tool = getEquippedWeapon()
        local target = getClosestEnemy()
        
        local status = string.format(
            "武器: %s\nRemote: %d個\nターゲット: %s",
            tool and tool.Name or "なし",
            #state.weaponRemotes,
            target and "検出" or "なし"
        )
        
        StatusLabel:Set(status)
    end,
})

MiscTab:CreateSection("デバッグ")

local LogLabel = MiscTab:CreateLabel("ログは下のボタンで表示")

MiscTab:CreateButton({
    Name = "最新ログを表示",
    Callback = function()
        local logText = "=== 最新10件 ===\n"
        for i = math.max(1, #debugLog - 9), #debugLog do
            logText = logText .. debugLog[i] .. "\n"
        end
        LogLabel:Set(logText)
    end,
})

MiscTab:CreateButton({
    Name = "ログをクリア",
    Callback = function()
        debugLog = {}
        LogLabel:Set("ログをクリアしました")
        log("ログリセット")
    end,
})

MiscTab:CreateSection("クイック設定")

MiscTab:CreateButton({
    Name = "🔥 フルコンバット (推奨)",
    Callback = function()
        config.softAimEnabled = true
        config.autoShootEnabled = true
        config.autoEquipEnabled = true
        config.hitboxEnabled = true
        config.triggerBotEnabled = true
        
        Rayfield:Notify({
            Title = "設定適用",
            Content = "フルコンバットモード有効",
            Duration = 3,
        })
        log("🔥 フルコンバットモード")
    end,
})

MiscTab:CreateButton({
    Name = "👻 ステルスモード",
    Callback = function()
        config.silentAimEnabled = true
        config.autoShootEnabled = false
        config.espEnabled = false
        config.hitboxEnabled = false
        
        Rayfield:Notify({
            Title = "設定適用",
            Content = "ステルスモード有効",
            Duration = 3,
        })
        log("👻 ステルスモード")
    end,
})

MiscTab:CreateButton({
    Name = "🛡️ 安全モード (全て無効)",
    Callback = function()
        config.softAimEnabled = false
        config.autoAimEnabled = false
        config.silentAimEnabled = false
        config.autoShootEnabled = false
        config.triggerBotEnabled = false
        config.espEnabled = false
        config.hitboxEnabled = false
        config.flyEnabled = false
        config.noClipEnabled = false
        config.speedEnabled = false
        
        toggleFly()
        
        Rayfield:Notify({
            Title = "設定適用",
            Content = "全機能を無効化しました",
            Duration = 3,
        })
        log("🛡️ 安全モード")
    end,
})

MiscTab:CreateSection("クレジット")

MiscTab:CreateLabel("作者: @syu_u0316")
MiscTab:CreateLabel("ゲーム: Murderers vs Sheriffs 2")
MiscTab:CreateLabel("バージョン: 3.0 Ultimate")
MiscTab:CreateLabel("統合元: 7つのスクリプト")

-- ========== 起動通知 ==========
Rayfield:Notify({
    Title = "✅ 読み込み完了",
    Content = "Murderers vs Sheriffs 2 Ultimate v3.0",
    Duration = 5,
})

log("========================================")
log("  ✅ 全システム起動完了")
log("  Murderers vs Sheriffs 2 Ultimate")
log("  Version 3.0 - 究極最適化版")
log("  作者: @syu_u0316")
log("========================================")
log("")
log("📋 使用方法:")
log("1. 武器を装備してください")
log("2. エイムと射撃を有効にしてください")
log("3. 必要に応じてESPやヒットボックスを有効化")
log("4. 問題があれば「武器再スキャン」を実行")
log("")
log("⚠️ 注意: 検出リスクがあります")
log("========================================")

-- ========== 自動更新ループ ==========
task.spawn(function()
    while task.wait(3) do
        if config.autoEquipEnabled and not getEquippedWeapon() then
            autoEquipWeapon()
        end
    end
end)

-- ========== キャラクター再読み込み対応 ==========
player.CharacterAdded:Connect(function(character)
    task.wait(2)
    log("🔄 キャラクター再読み込み")
    state.currentWeapon = nil
    state.weaponRemotes = {}
    
    if config.flyEnabled then
        task.wait(1)
        toggleFly()
    end
end)
