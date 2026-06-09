--[[
    FatherV4 Platinum - Bedfight
    Modules: KillAura, AimAssist, ESP, ProjectileAura
    Folder-based GUI with sliders. RightShift to hide.
--]]

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local userInput = game:GetService("UserInputService")

-- ===== CONFIGURATION =====
local config = {
    KillAura = {
        enabled = true,
        range = 8.0,           -- studs
        maxAngle = 180,        -- degrees
        hitChance = 100,       -- percentage
        swingCooldown = 0.1,   -- seconds
        maxTargets = 1,
    },
    AimAssist = {
        enabled = true,
        smoothness = 0.25,
        fov = 150,             -- pixels
        deadzone = 8,          -- pixels
        requireMouseDown = true, -- only when holding left click
    },
    ESP = {
        enabled = true,
        box = true,
        name = true,
        health = true,
        color = Color3.fromRGB(255, 50, 50),
        transparency = 0.5,
    },
    ProjectileAura = {
        enabled = true,
    },
}

-- ===== UTILITIES =====
local function getCharacter(plr)
    return plr.Character or (plr.CharacterAdded and plr.CharacterAdded:Wait() and plr.Character)
end

local function isAlive(plr)
    local char = getCharacter(plr)
    local hum = char and char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function moveMouse(dx, dy)
    if mousemoverel then
        mousemoverel(dx, dy)
    elseif syn and syn.input then
        syn.input.mouse_move(dx, dy)
    end
end

-- Find attack remote (Bedfight specific)
local attackRemote = nil
local remoteNames = {"Attack", "DealDamage", "Hit", "Melee", "Swing"}
for _, name in ipairs(remoteNames) do
    local remote = replicatedStorage:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        attackRemote = remote
        break
    end
end
if not attackRemote then
    for _, child in pairs(replicatedStorage:GetChildren()) do
        if child:IsA("RemoteEvent") and (child.Name:lower():find("attack") or child.Name:lower():find("damage")) then
            attackRemote = child
            break
        end
    end
end

-- ===== KILL AURA =====
local lastAttack = 0

local function getTargetsInRange()
    local origin = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not origin then return {} end
    local targets = {}
    local lookVector = camera.CFrame.LookVector

    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= player and isAlive(plr) then
            local hrp = getCharacter(plr):FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - origin.Position).Magnitude
                if dist <= config.KillAura.range then
                    local dirToTarget = (hrp.Position - origin.Position).Unit
                    local angle = math.deg(math.acos(lookVector:Dot(dirToTarget)))
                    if angle <= config.KillAura.maxAngle / 2 then
                        table.insert(targets, { plr = plr, hrp = hrp, dist = dist })
                    end
                end
            end
        end
    end

    table.sort(targets, function(a, b) return a.dist < b.dist end)
    return targets
end

runService.RenderStepped:Connect(function()
    if not config.KillAura.enabled then return end
    if tick() - lastAttack < config.KillAura.swingCooldown then return end

    local targets = getTargetsInRange()
    local count = 0
    for _, t in ipairs(targets) do
        if count >= config.KillAura.maxTargets then break end
        if config.KillAura.hitChance < 100 and math.random(1, 100) > config.KillAura.hitChance then
            goto skip
        end
        local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
        if tool and attackRemote then
            attackRemote:FireServer(t.hrp, tool)
            lastAttack = tick()
            count = count + 1
        end
        ::skip::
    end
end)

-- ===== AIM ASSIST =====
local function getAimTarget()
    local best, bestFOV = nil, config.AimAssist.fov
    local center = Vector2.new(mouse.X, mouse.Y)

    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= player and isAlive(plr) then
            local hrp = getCharacter(plr):FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos, onScreen = camera:WorldToScreenPoint(hrp.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestFOV then
                        bestFOV = dist
                        best = hrp
                    end
                end
            end
        end
    end
    return best
end

runService.RenderStepped:Connect(function()
    if not config.AimAssist.enabled then return end
    if config.AimAssist.requireMouseDown and not userInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return
    end
    local target = getAimTarget()
    if target then
        local pos = camera:WorldToScreenPoint(target.Position)
        local dx = pos.X - mouse.X
        local dy = pos.Y - mouse.Y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > config.AimAssist.deadzone then
            moveMouse(dx * config.AimAssist.smoothness, dy * config.AimAssist.smoothness)
        end
    end
end)

-- ===== ESP =====
local espFolder = nil

local function refreshESP()
    if espFolder then espFolder:Destroy() end
    if not config.ESP.enabled then return end

    espFolder = Instance.new("Folder")
    espFolder.Name = "FatherV4_ESP"
    pcall(function() espFolder.Parent = game.CoreGui end)
    if not espFolder.Parent then
        espFolder.Parent = player:WaitForChild("PlayerGui")
    end

    local function addESP(plr)
        if plr == player then return end
        local char = getCharacter(plr)
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if not hrp then return end

        if config.ESP.box then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "ESPBox_" .. plr.Name
            box.Adornee = hrp
            box.Size = Vector3.new(3, 4, 3)
            box.Color3 = config.ESP.color
            box.Transparency = config.ESP.transparency
            box.AlwaysOnTop = true
            box.Parent = espFolder
        end

        if config.ESP.name then
            local bill = Instance.new("BillboardGui")
            bill.Name = "ESPName_" .. plr.Name
            bill.Adornee = hrp
            bill.Size = UDim2.new(0, 100, 0, 20)
            bill.AlwaysOnTop = true
            local text = Instance.new("TextLabel", bill)
            text.Text = plr.Name
            text.TextColor3 = Color3.new(1, 1, 1)
            text.BackgroundTransparency = 1
            text.Size = UDim2.new(1, 0, 1, 0)
            bill.Parent = espFolder
        end

        if config.ESP.health then
            local healthBill = Instance.new("BillboardGui")
            healthBill.Name = "ESPHealth_" .. plr.Name
            healthBill.Adornee = hrp
            healthBill.Size = UDim2.new(0, 50, 0, 10)
            healthBill.AlwaysOnTop = true
            local healthText = Instance.new("TextLabel", healthBill)
            healthText.Text = "100"
            healthText.TextColor3 = Color3.fromRGB(0, 255, 0)
            healthText.BackgroundTransparency = 1
            healthText.Size = UDim2.new(1, 0, 1, 0)
            healthBill.Parent = espFolder

            local function updateHealth()
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    healthText.Text = tostring(math.floor(hum.Health))
                    healthText.TextColor3 = (hum.Health > 50) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                else
                    healthText.Text = "0"
                end
            end
            updateHealth()
            if char:FindFirstChild("Humanoid") then
                char.Humanoid.HealthChanged:Connect(updateHealth)
            end
        end
    end

    for _, plr in pairs(players:GetPlayers()) do
        addESP(plr)
    end
    players.PlayerAdded:Connect(addESP)
    players.PlayerRemoving:Connect(function(plr)
        for _, obj in pairs(espFolder:GetChildren()) do
            if obj.Name:find(plr.Name) then
                obj:Destroy()
            end
        end
    end)
end

refreshESP()

-- ===== PROJECTILE AURA =====
if config.ProjectileAura.enabled then
    local function redirectProjectile(proj)
        local nearest, bestDist = nil, math.huge
        for _, plr in pairs(players:GetPlayers()) do
            if plr ~= player and isAlive(plr) then
                local hrp = getCharacter(plr):FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - proj.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        nearest = hrp
                    end
                end
            end
        end
        if nearest then
            local direction = (nearest.Position - proj.Position).Unit
            local velocity = proj.AssemblyLinearVelocity or proj.Velocity
            if velocity then
                proj.AssemblyLinearVelocity = direction * velocity.Magnitude
            end
        end
    end

    workspace.DescendantAdded:Connect(function(obj)
        local name = obj.Name:lower()
        if name:find("arrow") or name:find("snowball") or name:find("projectile") or name:find("egg") or obj:IsA("Projectile") then
            task.wait(0.05)
            runService.Heartbeat:Connect(function()
                if obj and obj.Parent then
                    redirectProjectile(obj)
                end
            end)
        end
    end)
end

-- ===== GUI: Folder-Based (Vape Style) =====
local guiParent = pcall(function() return game.CoreGui end) and game.CoreGui or player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FatherV4_Platinum"
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 350)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 35)
title.Text = "FatherV4 Platinum"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18

local folderList = Instance.new("ScrollingFrame", mainFrame)
folderList.Size = UDim2.new(1, 0, 1, -40)
folderList.Position = UDim2.new(0, 0, 0, 35)
folderList.BackgroundTransparency = 1
folderList.CanvasSize = UDim2.new(0, 0, 0, 300)
folderList.ScrollBarThickness = 4

local folderLayout = Instance.new("UIListLayout", folderList)
folderLayout.Padding = UDim.new(0, 8)

local currentPanel = nil

local function closePanel()
    if currentPanel then currentPanel:Destroy() end
    currentPanel = nil
end

local function openPanel(moduleName, settingsTable)
    closePanel()

    local panel = Instance.new("Frame", mainFrame)
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    panel.BackgroundTransparency = 0.05

    local backBtn = Instance.new("TextButton", panel)
    backBtn.Size = UDim2.new(0, 60, 0, 25)
    backBtn.Position = UDim2.new(0, 5, 0, 5)
    backBtn.Text = "< Back"
    backBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    backBtn.TextColor3 = Color3.new(1, 1, 1)
    backBtn.Parent = panel
    backBtn.MouseButton1Click:Connect(function()
        closePanel()
        mainFrame.Visible = true
        folderList.Visible = true
        title.Visible = true
    end)

    local titleLabel = Instance.new("TextLabel", panel)
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Text = moduleName
    titleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold

    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size = UDim2.new(1, 0, 1, -40)
    scroll.Position = UDim2.new(0, 0, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0, 0, 0, 400)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 8)

    local function addToggle(text, key)
        local container = Instance.new("Frame", scroll)
        container.Size = UDim2.new(1, -20, 0, 32)
        container.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        container.BackgroundTransparency = 0.3
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)

        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Text = text
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Padding = UDim.new(0, 8)

        local btn = Instance.new("TextButton", container)
        btn.Size = UDim2.new(0, 60, 0, 26)
        btn.Position = UDim2.new(1, -68, 0, 3)
        btn.Text = settingsTable[key] and "ON" or "OFF"
        btn.BackgroundColor3 = settingsTable[key] and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        btn.TextColor3 = Color3.new(0, 0, 0)
        btn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            settingsTable[key] = not settingsTable[key]
            btn.Text = settingsTable[key] and "ON" or "OFF"
            btn.BackgroundColor3 = settingsTable[key] and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
            if moduleName == "ESP" and key == "enabled" then
                refreshESP()
            end
        end)
    end

    local function addSlider(text, key, minVal, maxVal, decimals)
        local container = Instance.new("Frame", scroll)
        container.Size = UDim2.new(1, -20, 0, 55)
        container.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        container.BackgroundTransparency = 0.3
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)

        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Text = text .. ": " .. tostring(settingsTable[key])
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundTransparency = 1

        local bg = Instance.new("Frame", container)
        bg.Size = UDim2.new(0.9, 0, 0, 8)
        bg.Position = UDim2.new(0.05, 0, 0, 28)
        bg.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", bg)
        fill.Size = UDim2.new((settingsTable[key] - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local valDisplay = Instance.new("TextLabel", container)
        valDisplay.Size = UDim2.new(0, 50, 0, 20)
        valDisplay.Position = UDim2.new(1, -55, 0, 28)
        valDisplay.Text = tostring(settingsTable[key])
        valDisplay.TextColor3 = Color3.new(1, 1, 1)
        valDisplay.BackgroundTransparency = 1
        valDisplay.TextSize = 12

        local dragging = false
        bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                local function update(mouseX)
                    local rel = (mouseX - bg.AbsolutePosition.X) / bg.AbsoluteSize.X
                    local val = math.clamp(minVal + rel * (maxVal - minVal), minVal, maxVal)
                    if decimals == 0 then
                        val = math.floor(val)
                    end
                    settingsTable[key] = val
                    fill.Size = UDim2.new((val - minVal) / (maxVal - minVal), 0, 1, 0)
                    local display = (decimals == 0 and tostring(val)) or string.format("%.2f", val)
                    valDisplay.Text = display
                    label.Text = text .. ": " .. display
                end
                update(input.Position.X)

                local conn = userInput.InputChanged:Connect(function(i2)
                    if i2.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                        update(i2.Position.X)
                    end
                end)
                local release = userInput.InputEnded:Connect(function(i2)
                    if i2.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                        conn:Disconnect()
                        release:Disconnect()
                    end
                end)
            end
        end)
    end

    -- Build module-specific controls
    if moduleName == "KillAura" then
        addToggle("Enabled", "enabled")
        addSlider("Range (studs)", "range", 3, 12, 1)
        addSlider("Max Angle (deg)", "maxAngle", 30, 180, 0)
        addSlider("Hit Chance %", "hitChance", 1, 100, 0)
        addSlider("Swing Cooldown (s)", "swingCooldown", 0.05, 0.3, 2)
        addSlider("Max Targets", "maxTargets", 1, 5, 0)
    elseif moduleName == "AimAssist" then
        addToggle("Enabled", "enabled")
        addToggle("Require Mouse Down", "requireMouseDown")
        addSlider("Smoothness", "smoothness", 0, 0.8, 2)
        addSlider("FOV (pixels)", "fov", 30, 200, 0)
        addSlider("Deadzone (pixels)", "deadzone", 0, 50, 0)
    elseif moduleName == "ESP" then
        addToggle("Enabled", "enabled")
        addToggle("Box ESP", "box")
        addToggle("Name ESP", "name")
        addToggle("Health ESP", "health")
    elseif moduleName == "ProjectileAura" then
        addToggle("Enabled", "enabled")
    end

    currentPanel = panel
    mainFrame.Visible = false
    folderList.Visible = false
    title.Visible = false
end

-- Create folder buttons
local folders = { "KillAura", "AimAssist", "ESP", "ProjectileAura" }
for _, name in ipairs(folders) do
    local btn = Instance.new("TextButton", folderList)
    btn.Size = UDim2.new(1, -20, 0, 42)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        openPanel(name, config[name])
    end)
end

-- GUI toggle (RightShift)
local guiVisible = true
userInput.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        guiVisible = not guiVisible
        screenGui.Enabled = guiVisible
    end
end)

print("FatherV4 Platinum loaded. Click folders to adjust settings. RightShift hides GUI.")
