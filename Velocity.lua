local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/katnaa-debug/SolarisUI/refs/heads/main/Library1.lua"))()

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer

local customPingMs = 60
local currentRealPing = (customPingMs + 10) / 1000
local GLOBAL_PARRY_COOLDOWN = 0
local CLASH_DISTANCE = 18.0
local CURVE_DOT_THRESHOLD = -0.15
local SLOW_BALL_RADIUS = 22.0
local BASE_ETA_THRESHOLD = 0.30
local HIGH_SPEED_THRESHOLD = 200.0
local EMERGENCY_DISTANCE = 11.0
local PARRY_SAFETY_BUFFER = 0.045

local isScriptLoaded = false
local autoParryEnabled = false
local autoParryMode = "Smart (Pro)"
local manualClickerEnabled = false
local autoClashDetectorEnabled = false
local autoClashActive = false
local targetCPS = 30
local autoClashThreshold = 4

local movementModifiersEnabled = false
local customWalkSpeed = 36
local defaultGameWalkSpeed = 16

local id_lastBallVelocity = Vector3.zero
local id_lastBallAcceleration = Vector3.zero
local id_lastVelocityTime = 0
local id_furyCounterActive = false
local id_timeHoleLock = false

local autoAbilitiesEnabled = false
local lastAbilityTime = 0

local autoDodgeEnabled = false
local dodgeBoxVisible = false
local dodgeOrigin = Vector3.zero
local dodgeLocalPos = Vector3.zero
local dodgeVel = Vector3.zero
local dodgeSpeed = 500
local dodgeBoxWidth = 30
local dodgeBoxHeight = 60
local dodgeBoxThickness = 20
local dodgeBoxPart = nil
local dodgeBoxSelection = nil

local dodgeCamAnchor = Instance.new("Part")
dodgeCamAnchor.Name = "Velocity_CamAnchor"
dodgeCamAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
dodgeCamAnchor.Transparency = 1
dodgeCamAnchor.CanCollide = false
dodgeCamAnchor.CanTouch = false
dodgeCamAnchor.CanQuery = false
dodgeCamAnchor.Anchored = true
dodgeCamAnchor.Parent = workspace

local botEnabled = false
local botAutoAdaptEnabled = false
local botMoveDir = Vector3.new(1, 0, 0)
local changeDirTimer = 0

local lastParryTime = 0
local parryHistory = {}
local lastClashActivity = 0
local parriedBalls = {}
local ballBillboards = {}

local fovValue = 70
local unlockZoomEnabled = false
local ballInfoEnabled = false
local lineToTargetEnabled = false

local targetLine = Instance.new("LineHandleAdornment")
targetLine.Name = "Velocity_TargetLine"
targetLine.Color3 = Color3.fromRGB(255, 60, 60)
targetLine.Thickness = 3
targetLine.AlwaysOnTop = true
targetLine.ZIndex = 5

local noEffectsEnabled = false
local storedEffects = {}
local effectConn1 = nil
local effectConn2 = nil

local customFogEnabled = false
local customFogColor = Color3.fromRGB(180, 180, 180)
local customFogStart = 0
local customFogEnd = 1000
local defaultFogColor = nil
local defaultFogStart = nil
local defaultFogEnd = nil

local playerEspEnabled = false
local playerEspMode = "With Outline"
local playerEspFillColor = Color3.fromRGB(255, 255, 255)
local playerEspOutlineColor = Color3.fromRGB(255, 255, 255)

local PLATFORM_NAME = "Velocity_Fly_Platform"
local oldPlat = workspace:FindFirstChild(PLATFORM_NAME)
if oldPlat then 
    pcall(function() oldPlat:Destroy() end) 
end

local isFlying = false
local flySpeed = 65
local platform = nil
local heartbeatConn = nil
local anchorConn = nil
local charConn = nil

local mobileUp = false
local mobileDown = false

local currentVelocity = Vector3.zero
local currentPitch = 0
local currentRoll = 0
local baseFOV = 70
pcall(function() baseFOV = Camera.FieldOfView end)

local flightVFX = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function GetOrCreateDodgeBox()
    if dodgeBoxPart and dodgeBoxPart.Parent then
        dodgeBoxPart.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
        return dodgeBoxPart
    end
    local part = Instance.new("Part")
    part.Name = "Velocity_DodgeBox"
    part.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
    part.Transparency = 1
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Anchored = true
    part.Material = Enum.Material.ForceField
    part.Color = Color3.fromRGB(0, 240, 255)
    part.Parent = workspace

    local sel = Instance.new("SelectionBox")
    sel.Name = "Velocity_DodgeBoxOutline"
    sel.Adornee = part
    sel.Color3 = Color3.fromRGB(0, 240, 255)
    sel.LineThickness = 0.05
    sel.Visible = false
    sel.Parent = part

    dodgeBoxPart = part
    dodgeBoxSelection = sel
    return dodgeBoxPart
end

local function GetOrCreatePlatform()
    if platform and platform.Parent then
        return platform
    end
    local p = Instance.new("Part")
    p.Name = PLATFORM_NAME
    p.Size = Vector3.new(4, 0.2, 4)
    p.Transparency = 1
    p.CanCollide = true
    p.CanTouch = false
    p.CanQuery = true
    p.Anchored = true
    p.Material = Enum.Material.SmoothPlastic
    p.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
    p.Parent = workspace
    platform = p
    return platform
end

local function CreateFlightVFX(hrp)
    if flightVFX.trail then return end

    local att0 = Instance.new("Attachment")
    att0.Name = "Velocity_TrailAtt0"
    att0.Position = Vector3.new(-0.85, -2.2, 0.3)
    att0.Parent = hrp

    local att1 = Instance.new("Attachment")
    att1.Name = "Velocity_TrailAtt1"
    att1.Position = Vector3.new(0.85, -2.2, 0.3)
    att1.Parent = hrp

    local trail = Instance.new("Trail")
    trail.Name = "Velocity_FlightTrail"
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.32
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(0.6, 0.4),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 70, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 180))
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(1, 0)
    })
    trail.Enabled = false
    trail.Parent = hrp

    flightVFX.att0 = att0
    flightVFX.att1 = att1
    flightVFX.trail = trail
end

local function RemoveFlightVFX()
    for _, item in pairs(flightVFX) do
        if item and item.Parent then
            pcall(function() item:Destroy() end)
        end
    end
    flightVFX = {}
end

local function GetRawMoveDirection()
    local cam = workspace.CurrentCamera
    if not cam then return Vector3.zero end
    
    local dir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        dir = dir + cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        dir = dir - cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        dir = dir + cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        dir = dir - cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or mobileUp then
        dir = dir + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or mobileDown then
        dir = dir - Vector3.new(0, 1, 0)
    end

    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if dir.Magnitude < 0.05 and hum and hum.MoveDirection.Magnitude > 0.05 then
        local camLook = cam.CFrame.LookVector
        local camRight = cam.CFrame.RightVector
        local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
        local flatRight = Vector3.new(camRight.X, 0, camRight.Z)
        local fL = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
        local fR = flatRight.Magnitude > 0.01 and flatRight.Unit or Vector3.new(1, 0, 0)
        dir = (fR * hum.MoveDirection.X) + (fL * -hum.MoveDirection.Z)
    end

    return dir
end

local function StartFly()
    isFlying = true
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    pcall(function() baseFOV = Camera.FieldOfView end)

    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    if hrp then
        hrp.Anchored = false
        CreateFlightVFX(hrp)

        if anchorConn then anchorConn:Disconnect() end
        anchorConn = hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
            if isFlying and hrp.Anchored then
                hrp.Anchored = false
            end
        end)
    end

    currentVelocity = Vector3.zero
    currentPitch = 0
    currentRoll = 0

    if heartbeatConn then heartbeatConn:Disconnect() end
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        if not isFlying then return end

        local c = Player.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        local humanoid = c and c:FindFirstChildOfClass("Humanoid")
        if not (c and root and humanoid and humanoid.Health > 0) then return end

        if root.Anchored then
            root.Anchored = false
        end

        local rawDir = GetRawMoveDirection()
        local plat = GetOrCreatePlatform()
        local cam = workspace.CurrentCamera

        local targetVelocity = (rawDir.Magnitude > 0.05) and (rawDir.Unit * flySpeed) or Vector3.zero
        currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(dt * 7.5, 0, 1))

        local speedRatio = currentVelocity.Magnitude / math.max(flySpeed, 1)

        if flightVFX.trail then
            flightVFX.trail.Enabled = (speedRatio > 0.15)
        end

        if cam then
            local targetFOV = baseFOV + (speedRatio * 5.5)
            cam.FieldOfView = lerp(cam.FieldOfView, targetFOV, math.clamp(dt * 6, 0, 1))
        end

        local idleBob = 0
        if speedRatio < 0.1 then
            idleBob = math.sin(os.clock() * 2.8) * 0.22
        end

        local targetPitch = 0
        local targetRoll = 0

        if cam and speedRatio > 0.05 then
            local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
            local flatRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
            
            local forwardDot = currentVelocity.Unit:Dot(flatLook)
            local rightDot = currentVelocity.Unit:Dot(flatRight)

            targetPitch = -forwardDot * math.rad(24 * speedRatio)
            targetRoll = -rightDot * math.rad(20 * speedRatio)
        end

        currentPitch = lerp(currentPitch, targetPitch, math.clamp(dt * 6, 0, 1))
        currentRoll = lerp(currentRoll, targetRoll, math.clamp(dt * 6, 0, 1))

        if cam then
            local camLook = cam.CFrame.LookVector
            local yawAngle = math.atan2(-camLook.X, -camLook.Z)
            root.CFrame = CFrame.new(root.Position) 
                * CFrame.Angles(0, yawAngle, 0) 
                * CFrame.Angles(currentPitch, 0, currentRoll)
        end

        local yOffset = 3.12 - idleBob
        if currentVelocity.Y < -5 then
            yOffset = 3.75
        end
        plat.CFrame = CFrame.new(root.Position.X, root.Position.Y - yOffset, root.Position.Z)

        if speedRatio > 0.03 then
            root.AssemblyLinearVelocity = currentVelocity
        else
            root.AssemblyLinearVelocity = Vector3.new(0, idleBob * 4 - 0.35, 0)
        end
    end)
end

local function StopFly()
    isFlying = false
    if heartbeatConn then 
        heartbeatConn:Disconnect() 
        heartbeatConn = nil 
    end
    if anchorConn then 
        anchorConn:Disconnect() 
        anchorConn = nil 
    end

    RemoveFlightVFX()

    if platform and platform.Parent then
        pcall(function() platform:Destroy() end)
        platform = nil
    end

    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local flatYaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, flatYaw, 0)
    end

    pcall(function()
        Camera.FieldOfView = baseFOV
    end)
end

local function ToggleFly()
    if isFlying then
        StopFly()
    else
        StartFly()
    end
end

local function SetPhantomEvade(state)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if state then
        if not (char and hrp and hum and hum.Health > 0) then return end
        dodgeOrigin = hrp.Position
        dodgeCamAnchor.CFrame = CFrame.new(dodgeOrigin)
        Camera.CameraSubject = dodgeCamAnchor
        dodgeLocalPos = Vector3.zero
        local vx = (math.random(60, 100) / 100) * (math.random() > 0.5 and 1 or -1)
        local vy = (math.random(60, 100) / 100) * (math.random() > 0.5 and 1 or -1)
        local vz = (math.random(60, 100) / 100) * (math.random() > 0.5 and 1 or -1)
        dodgeVel = Vector3.new(vx, vy, vz).Unit * dodgeSpeed
        autoDodgeEnabled = true
    else
        autoDodgeEnabled = false
        if hum then
            Camera.CameraSubject = hum
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            if dodgeOrigin ~= Vector3.zero then
                hrp.CFrame = CFrame.new(dodgeOrigin.X, hrp.Position.Y, dodgeOrigin.Z) * hrp.CFrame.Rotation
            end
        end
    end
    if isScriptLoaded then
        Library:Notify({
            Title = "Velocity", 
            Content = state and "Phantom Evade: Active" or "Phantom Evade: Deactivated", 
            Duration = 2
        })
    end
end

charConn = Player.CharacterAdded:Connect(function()
    if isFlying then
        StopFly()
    end
    SetPhantomEvade(false)
    local c = Player.Character
    local h = c and c:WaitForChild("Humanoid", 3)
    if h then
        Camera.CameraSubject = h
    end
end)

task.spawn(function()
    while true do
        if isScriptLoaded then
            currentRealPing = (customPingMs + 10) / 1000
        end
        task.wait(0.5)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not isScriptLoaded then return end

    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if movementModifiersEnabled and hum and hum.WalkSpeed ~= customWalkSpeed then
        hum.WalkSpeed = customWalkSpeed
    end

    if autoDodgeEnabled and char and hum and hrp and hum.Health > 0 and not isFlying then
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:ChangeState(Enum.HumanoidStateType.Running)

        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.05 then
            local moveSpeed = movementModifiersEnabled and customWalkSpeed or defaultGameWalkSpeed
            dodgeOrigin = dodgeOrigin + (Vector3.new(moveDir.X, 0, moveDir.Z).Unit * (moveSpeed * dt))
        end

        dodgeCamAnchor.CFrame = CFrame.new(dodgeOrigin)
        if Camera.CameraSubject ~= dodgeCamAnchor then
            Camera.CameraSubject = dodgeCamAnchor
        end

        dodgeLocalPos = dodgeLocalPos + (dodgeVel * dt)

        local halfW = dodgeBoxWidth / 2
        local halfH = dodgeBoxHeight / 2
        local halfT = dodgeBoxThickness / 2

        local minX, maxX = -halfW, halfW
        local minY, maxY = -halfH, halfH
        local minZ, maxZ = -halfT, halfT

        if dodgeLocalPos.X >= maxX then
            dodgeLocalPos = Vector3.new(maxX, dodgeLocalPos.Y, dodgeLocalPos.Z)
            dodgeVel = Vector3.new(-math.abs(dodgeVel.X), dodgeVel.Y, dodgeVel.Z)
        elseif dodgeLocalPos.X <= minX then
            dodgeLocalPos = Vector3.new(minX, dodgeLocalPos.Y, dodgeLocalPos.Z)
            dodgeVel = Vector3.new(math.abs(dodgeVel.X), dodgeVel.Y, dodgeVel.Z)
        end

        if dodgeLocalPos.Y >= maxY then
            dodgeLocalPos = Vector3.new(dodgeLocalPos.X, maxY, dodgeLocalPos.Z)
            dodgeVel = Vector3.new(dodgeVel.X, -math.abs(dodgeVel.Y), dodgeVel.Z)
        elseif dodgeLocalPos.Y <= minY then
            dodgeLocalPos = Vector3.new(dodgeLocalPos.X, minY, dodgeLocalPos.Z)
            dodgeVel = Vector3.new(dodgeVel.X, math.abs(dodgeVel.Y), dodgeVel.Z)
        end

        if dodgeLocalPos.Z >= maxZ then
            dodgeLocalPos = Vector3.new(dodgeLocalPos.X, dodgeLocalPos.Y, maxZ)
            dodgeVel = Vector3.new(dodgeVel.X, dodgeVel.Y, -math.abs(dodgeVel.Z))
        elseif dodgeLocalPos.Z <= minZ then
            dodgeLocalPos = Vector3.new(dodgeLocalPos.X, dodgeLocalPos.Y, minZ)
            dodgeVel = Vector3.new(dodgeVel.X, dodgeVel.Y, math.abs(dodgeVel.Z))
        end

        local rot = hrp.CFrame.Rotation
        local cam = workspace.CurrentCamera
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and cam then
            local camLook = cam.CFrame.LookVector
            local yaw = math.atan2(-camLook.X, -camLook.Z)
            rot = CFrame.Angles(0, yaw, 0)
        end

        hrp.CFrame = CFrame.new(dodgeOrigin + dodgeLocalPos) * rot
        hrp.AssemblyLinearVelocity = dodgeVel

        local box = GetOrCreateDodgeBox()
        box.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
        box.CFrame = CFrame.new(dodgeOrigin)
        if dodgeBoxVisible then
            box.Transparency = 0.82
            if dodgeBoxSelection then
                dodgeBoxSelection.Visible = true
            end
        else
            box.Transparency = 1
            if dodgeBoxSelection then
                dodgeBoxSelection.Visible = false
            end
        end
    else
        if Camera.CameraSubject == dodgeCamAnchor and hum then
            Camera.CameraSubject = hum
        end
        if dodgeBoxPart then
            dodgeBoxPart.Transparency = 1
            if dodgeBoxSelection then
                dodgeBoxSelection.Visible = false
            end
        end
    end
end)

local function GetActiveBall()
    local folder = workspace:FindFirstChild("Balls")
    if folder then
        for _, ball in ipairs(folder:GetChildren()) do
            if ball:IsA("BasePart") and ball:FindFirstChild("zoomies") and ball:GetAttribute("realBall") == true then
                return ball
            end
        end
    end
    
    local training = workspace:FindFirstChild("TrainingBalls")
    if training then
        for _, ball in ipairs(training:GetChildren()) do
            if ball:IsA("BasePart") and ball:FindFirstChild("zoomies") then
                return ball
            end
        end
    end
    return nil
end

local function rotateVectorHorizontally(vec, angleDeg)
    local rad = math.rad(angleDeg)
    local cosAngle = math.cos(rad)
    local sinAngle = math.sin(rad)
    return Vector3.new(
        vec.X * cosAngle - vec.Z * sinAngle, 
        0, 
        vec.X * sinAngle + vec.Z * cosAngle
    ).Unit
end

task.spawn(function()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    while true do
        local dt = task.wait(0.1)
        
        if not (isScriptLoaded and botEnabled) then
            continue
        end

        local myChar = Player.Character
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local ball = GetActiveBall()
        
        if not (hum and hrp and hum.Health > 0) then
            continue
        end

        local filter = {myChar}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then 
                table.insert(filter, p.Character) 
            end
        end
        if ball then 
            table.insert(filter, ball) 
        end
        rayParams.FilterDescendantsInstances = filter

        changeDirTimer = changeDirTimer - dt

        local ballPos = ball and ball.Position
        local distToBall = ballPos and (hrp.Position - ballPos).Magnitude or math.huge

        local center = Vector3.zero
        local count = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local eHum = p.Character:FindFirstChildOfClass("Humanoid")
                if eHum and eHum.Health > 0 then
                    center = center + p.Character.HumanoidRootPart.Position
                    count = count + 1
                end
            end
        end
        
        if count > 0 then 
            center = center / count 
        else 
            center = hrp.Position 
        end

        local distToCenter = (hrp.Position - center).Magnitude

        if distToBall < 40 and ballPos then
            local awayFromBall = (hrp.Position - ballPos)
            botMoveDir = Vector3.new(awayFromBall.X, 0, awayFromBall.Z).Unit
            changeDirTimer = 0.5
            
        elseif distToCenter > 60 then
            local toCenter = (center - hrp.Position)
            botMoveDir = Vector3.new(toCenter.X, 0, toCenter.Z).Unit
            changeDirTimer = 0.5
            
        elseif changeDirTimer <= 0 then
            local randomOffset = math.random(-60, 60)
            botMoveDir = rotateVectorHorizontally(botMoveDir, randomOffset)
            changeDirTimer = math.random(10, 25) / 10 
        end

        local rayStartPos = hrp.Position + Vector3.new(0, 2, 0)
        local function checkWhisker(angle)
            local dir = rotateVectorHorizontally(botMoveDir, angle)
            return workspace:Raycast(rayStartPos, dir * 15, rayParams)
        end

        local hitFront = checkWhisker(0)
        local hitLeft = checkWhisker(45)
        local hitRight = checkWhisker(-45)

        if hitFront then
            if not hitRight then
                botMoveDir = rotateVectorHorizontally(botMoveDir, -60) 
            elseif not hitLeft then
                botMoveDir = rotateVectorHorizontally(botMoveDir, 60)  
            else
                botMoveDir = rotateVectorHorizontally(botMoveDir, 180) 
            end
            changeDirTimer = 0.5
        elseif hitLeft then
            botMoveDir = rotateVectorHorizontally(botMoveDir, -30) 
        elseif hitRight then
            botMoveDir = rotateVectorHorizontally(botMoveDir, 30)  
        end

        local targetRunPos = hrp.Position + (botMoveDir * 20)
        hum:MoveTo(targetRunPos)

        if math.random(1, 100) <= 5 then
            hum.Jump = true
            pcall(function() 
                hum:ChangeState(Enum.HumanoidStateType.Jumping) 
            end)
        end
    end
end)

local lastFlickTime = 0
local cachedFlickTarget = nil

local function FlickCameraToRandomPlayer()
    if not botEnabled then 
        return 
    end
    
    pcall(function()
        local now = os.clock()
        
        if now - lastFlickTime > 0.2 or not cachedFlickTarget or not cachedFlickTarget.Parent then
            local alive = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local h = p.Character:FindFirstChildOfClass("Humanoid")
                    if h and h.Health > 0 then 
                        table.insert(alive, p) 
                    end
                end
            end
            
            if #alive > 0 then 
                cachedFlickTarget = alive[math.random(1, #alive)].Character.HumanoidRootPart
            else
                cachedFlickTarget = nil
            end
            lastFlickTime = now
        end

        if not cachedFlickTarget then 
            return 
        end
        
        local targetPos = cachedFlickTarget.Position
        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local lookVec = cam.CFrame.LookVector

        local clampedY = math.clamp(lookVec.Y, -0.99, 0.99)
        local currentPitch = math.asin(clampedY)

        local dx = targetPos.X - camPos.X
        local dz = targetPos.Z - camPos.Z
        local targetYaw = math.atan2(-dx, -dz)

        cam.CFrame = CFrame.new(camPos) * CFrame.Angles(0, targetYaw, 0) * CFrame.Angles(currentPitch, 0, 0)
    end)
end

local function SendVIMKey(key)
    pcall(function()
        local VIM = (type(cloneref) == "function" and cloneref(game:GetService("VirtualInputManager"))) or game:GetService("VirtualInputManager")
        if VIM then
            VIM:SendKeyEvent(true, key, false, game)
            VIM:SendKeyEvent(false, key, false, game)
        end
    end)
end

local function TriggerParryInput()
    FlickCameraToRandomPlayer()

    pcall(function()
        if type(mouse1click) == "function" then 
            mouse1click() 
        else 
            SendVIMKey(Enum.KeyCode.F) 
        end
    end)
end

task.spawn(function()
    while true do
        if manualClickerEnabled or (autoClashDetectorEnabled and autoClashActive) then
            local safeCPS = math.clamp(targetCPS, 5, 150)
            local interval = 1 / safeCPS
            TriggerParryInput()
            task.wait(interval)
        else
            task.wait(0.05)
        end
    end
end)

local function IsAbilityOnCooldown()
    local pGui = Player:FindFirstChild("PlayerGui")
    if not pGui then return false end
    for _, desc in ipairs(pGui:GetDescendants()) do
        if desc:IsA("GuiObject") and (desc.Name:lower():find("ability") or desc.Name:lower():find("skill")) then
            local cdText = desc:FindFirstChild("Cooldown", true) or desc:FindFirstChild("Timer", true)
            if cdText and cdText:IsA("TextLabel") and cdText.Visible and cdText.Text ~= "" and cdText.Text ~= "0" then
                return true
            end
            local cdFrame = desc:FindFirstChild("CooldownFrame", true)
            if cdFrame and cdFrame:IsA("GuiObject") and cdFrame.Visible and cdFrame.Size.Y.Scale > 0.05 then
                return true
            end
        end
    end
    return false
end

local function TriggerAbilityDefend()
    local now = os.clock()
    if (now - lastAbilityTime) < 7.0 then return end
    lastAbilityTime = now
    
    task.defer(function()
        pcall(function()
            if type(keyclick) == "function" then
                keyclick(Enum.KeyCode.Q)
            elseif type(keypress) == "function" and type(keyrelease) == "function" then
                keypress(0x51)
                task.delay(0.04, function()
                    pcall(function() keyrelease(0x51) end)
                end)
            else
                local VIM = (type(cloneref) == "function" and cloneref(game:GetService("VirtualInputManager"))) or game:GetService("VirtualInputManager")
                if VIM then
                    VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, nil)
                    task.delay(0.04, function()
                        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, nil) end)
                    end)
                end
            end
        end)
    end)
end

local function ClearAllBallBillboards()
    for ball, bbg in pairs(ballBillboards) do
        if bbg then 
            pcall(function() 
                bbg:Destroy() 
            end) 
        end
    end
    ballBillboards = {}
end

local function UpdateBallTrackers(ball)
    if not ballInfoEnabled or not ball then 
        ClearAllBallBillboards()
        return 
    end

    local bbg = ballBillboards[ball]
    if not bbg or not bbg.Parent then
        bbg = Instance.new("BillboardGui")
        bbg.Name = "Velocity_BallTracker"
        bbg.Size = UDim2.fromOffset(150, 45)
        bbg.StudsOffset = Vector3.new(0, 3.2, 0)
        bbg.AlwaysOnTop = true
        bbg.Adornee = ball

        local lbl = Instance.new("TextLabel")
        lbl.Name = "InfoLabel"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Roboto
        lbl.TextSize = 14
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0.1
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Parent = bbg

        local parentGui = (type(gethui) == "function" and gethui()) or Player:FindFirstChild("PlayerGui") or ball
        bbg.Parent = parentGui
        ballBillboards[ball] = bbg
    end

    local lbl = bbg:FindFirstChild("InfoLabel")
    if lbl then
        local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or "None"
        local vel = ball.AssemblyLinearVelocity
        local speed = math.floor((vel and vel.Magnitude > 0.1 and vel.Magnitude) or ball.Velocity.Magnitude or 0)
        
        lbl.Text = string.format("Target: %s\nSpeed: %d", (target ~= "" and target or "None"), speed)
        if target == Player.Name then
            lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
        else
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

local function UpdateTargetLine(ball)
    if not lineToTargetEnabled or not ball then
        targetLine.Visible = false
        targetLine.Parent = nil
        return
    end
    local targetName = ball:GetAttribute("target") or ball:GetAttribute("Target")
    if not targetName or targetName == "" then 
        targetLine.Visible = false
        targetLine.Parent = nil
        return 
    end
    local targetPlr = Players:FindFirstChild(targetName)
    local char = targetPlr and targetPlr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        if not targetLine.Parent then
            targetLine.Parent = workspace.Terrain
        end
        targetLine.Adornee = ball
        targetLine.Length = (hrp.Position - ball.Position).Magnitude
        targetLine.CFrame = CFrame.lookAt(Vector3.zero, hrp.Position - ball.Position)
        targetLine.Visible = true
    else
        targetLine.Visible = false
        targetLine.Parent = nil
    end
end

local function ApplyFog()
    if not isScriptLoaded then 
        return 
    end
    
    if not defaultFogColor then
        pcall(function() 
            defaultFogColor = Lighting.FogColor
            defaultFogStart = Lighting.FogStart
            defaultFogEnd = Lighting.FogEnd
        end)
    end
    
    if customFogEnabled then 
        Lighting.FogColor = customFogColor
        Lighting.FogStart = customFogStart
        Lighting.FogEnd = customFogEnd
    elseif defaultFogColor then 
        Lighting.FogColor = defaultFogColor
        Lighting.FogStart = defaultFogStart
        Lighting.FogEnd = defaultFogEnd
    end
end

local function IsPostEffect(instance) 
    return instance:IsA("PostEffect") 
        or instance:IsA("BloomEffect") 
        or instance:IsA("BlurEffect") 
        or instance:IsA("ColorCorrectionEffect") 
        or instance:IsA("SunRaysEffect") 
        or instance:IsA("DepthOfFieldEffect") 
end

local function HandleNewEffect(effect)
    if noEffectsEnabled and IsPostEffect(effect) then
        task.wait()
        if storedEffects[effect] == nil then 
            storedEffects[effect] = effect.Enabled 
        end
        effect.Enabled = false
    end
end

local function ApplyNoEffects(state)
    if not isScriptLoaded then 
        return 
    end
    noEffectsEnabled = state
    
    local containers = {Lighting, Camera}
    for _, container in ipairs(containers) do
        for _, effect in ipairs(container:GetChildren()) do
            if IsPostEffect(effect) then
                if state then
                    if storedEffects[effect] == nil then 
                        storedEffects[effect] = effect.Enabled 
                    end
                    effect.Enabled = false
                elseif storedEffects[effect] ~= nil then 
                    effect.Enabled = storedEffects[effect] 
                end
            end
        end
    end
    
    if state then
        if not effectConn1 then 
            effectConn1 = Lighting.ChildAdded:Connect(HandleNewEffect) 
        end
        if not effectConn2 then 
            effectConn2 = Camera.ChildAdded:Connect(HandleNewEffect) 
        end
    else
        if effectConn1 then 
            effectConn1:Disconnect() 
            effectConn1 = nil 
        end
        if effectConn2 then 
            effectConn2:Disconnect() 
            effectConn2 = nil 
        end
    end
end

local function UpdateCharacterESP(char, plr)
    if not char or plr == Player then 
        return 
    end
    local hl = char:FindFirstChild("Velocity_PlayerESP")
    
    if playerEspEnabled then
        if not hl then 
            hl = Instance.new("Highlight") 
            hl.Name = "Velocity_PlayerESP" 
            hl.Adornee = char
            hl.Parent = char 
        end
        hl.FillColor = playerEspFillColor
        hl.OutlineColor = playerEspOutlineColor
        hl.FillTransparency = 0.5
        if playerEspMode == "With Outline" then
            hl.OutlineTransparency = 0
        else
            hl.OutlineTransparency = 1
        end
        hl.Enabled = true
    else
        if hl then 
            hl:Destroy() 
        end 
    end
end

local function ClearAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then 
            local hl = plr.Character:FindFirstChild("Velocity_PlayerESP") 
            if hl then 
                hl:Destroy() 
            end 
        end
    end
end

task.spawn(function()
    while true do
        if playerEspEnabled and isScriptLoaded then
            for _, plr in ipairs(Players:GetPlayers()) do 
                if plr ~= Player and plr.Character then 
                    UpdateCharacterESP(plr.Character, plr) 
                end 
            end
            task.wait(1.5)
        else 
            task.wait(0.5) 
        end
    end
end)

local function RegisterParryAttempt(now)
    table.insert(parryHistory, now)
    lastClashActivity = now
    
    while #parryHistory > 0 and (now - parryHistory[1]) > 0.75 do 
        table.remove(parryHistory, 1) 
    end
    
    if #parryHistory >= autoClashThreshold then
        if autoClashDetectorEnabled and not autoClashActive then
            autoClashActive = true
            Library:Notify({
                Title = "Velocity", 
                Content = "Auto Clash Clicker: Activated", 
                Duration = 1.0
            })
        end
    end
end

local function CheckClashDeactivation(now, ball, hrp)
    if not autoClashActive then 
        return 
    end
    
    while #parryHistory > 0 and (now - parryHistory[1]) > 0.8 do 
        table.remove(parryHistory, 1) 
    end
    
    local shouldInstantlyKill = false
    
    if ball and hrp then
        local dist = (hrp.Position - ball.Position).Magnitude
        if dist > 35 then 
            shouldInstantlyKill = true 
        end
    else 
        shouldInstantlyKill = true 
    end

    if (now - lastClashActivity) > 0.6 then 
        shouldInstantlyKill = true 
    end

    if #parryHistory < 2 and (now - lastClashActivity) > 0.35 then
        shouldInstantlyKill = true
    end

    if shouldInstantlyKill then
        autoClashActive = false
        parryHistory = {}
        Library:Notify({
            Title = "Velocity", 
            Content = "Auto Clash Clicker: Deactivated", 
            Duration = 1.0
        })
    end
end

local function UpdateGeneralVisuals()
    if not isScriptLoaded then 
        return 
    end
    Camera.FieldOfView = fovValue
    
    if unlockZoomEnabled then
        Player.CameraMaxZoomDistance = 10000
    end
end

local lastBallSpd = 0 
local function ProcessSmartParry(ball, hrp, now)
    local playerPos = hrp.Position
    local playerVel = hrp.AssemblyLinearVelocity
    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    local speed = ballVel.Magnitude
    
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ""
    if target ~= Player.Name then 
        return 
    end 
    
    if speed < 0.1 then 
        return 
    end

    local calc_BASE_ETA = BASE_ETA_THRESHOLD
    local calc_CLASH_DIST = CLASH_DISTANCE
    local calc_SLOW_RADIUS = SLOW_BALL_RADIUS
    local calc_EMERGENCY = EMERGENCY_DISTANCE

    if botAutoAdaptEnabled then
        calc_BASE_ETA = 0.25 + math.clamp(currentRealPing, 0, 0.1)
        calc_CLASH_DIST = 16.0 + math.clamp(speed / 30, 0, 10)
        calc_SLOW_RADIUS = 18.0 + math.clamp(speed / 40, 0, 15)
        calc_EMERGENCY = 8.0 + math.clamp(speed / 50, 0, 6)
    end
    
    local toPlayer = playerPos - ballPos
    local dist = toPlayer.Magnitude
    local toPlayerUnit = (dist > 0.01) and toPlayer.Unit or Vector3.new(0, 1, 0)
    
    local rawApproachSpeed = (ballVel - playerVel):Dot(toPlayerUnit)
    local isRetreating = rawApproachSpeed < -2 
    
    local approachSpeed = rawApproachSpeed
    if approachSpeed <= 0 and not isRetreating then 
        approachSpeed = speed * 0.35
    elseif approachSpeed <= 0 and isRetreating then 
        approachSpeed = 0.1 
    end
    
    local acceleration = math.max(0, speed - lastBallSpd)
    lastBallSpd = speed
    
    local realETA = dist / math.max(approachSpeed, 1)
    local pingFactor = currentRealPing + (speed * 0.0002)
    local adjustedETA = realETA - pingFactor - PARRY_SAFETY_BUFFER
    
    local speedEtaBonus = 0
    if speed <= 70 then
        speedEtaBonus = 0.15
    elseif speed <= 150 then
        speedEtaBonus = 0.08
    elseif speed <= 300 then
        speedEtaBonus = ((speed - 150) / 150) * 0.10
    else
        speedEtaBonus = 0.10 + math.clamp((speed - 300) / 500, 0, 0.25)
    end
    
    local currentBaseETA = calc_BASE_ETA + speedEtaBonus
    
    if acceleration > 40 then 
        currentBaseETA = currentBaseETA + 0.15 
    end

    local dot = ballVel.Unit:Dot(toPlayerUnit)
    local isCurvingHard = (dot < 0.25) and (dot > -0.25) and not isRetreating
    local shouldParry = false
    local MIN_SAFE_DIST = 16.0 

    if dist <= calc_CLASH_DIST and (not isRetreating or dist <= 14) then 
        shouldParry = true
    elseif dist <= calc_EMERGENCY then 
        shouldParry = true
    elseif speed < 70 and dist <= MIN_SAFE_DIST and not isRetreating then
        shouldParry = true
    elseif isCurvingHard then
        if speed < 65 then 
            if dist <= math.max(18.5, calc_SLOW_RADIUS * 0.75) then 
                shouldParry = true 
            end
        else 
            if dist <= (calc_SLOW_RADIUS + (speed * 0.12)) then 
                shouldParry = true 
            end 
        end
    elseif speed >= HIGH_SPEED_THRESHOLD and adjustedETA <= (currentBaseETA + 0.1) and not isRetreating then 
        shouldParry = true
    elseif adjustedETA <= currentBaseETA and dist < (speed * 0.6 + 30) and not isRetreating then
        if speed < 50 and dist > 21 then 
            shouldParry = false 
        else 
            shouldParry = true 
        end
    end
    
    if shouldParry then
        if (now - lastParryTime) < 0.06 and not autoClashActive then 
            return 
        end
        parriedBalls[ball] = true
        lastParryTime = now
        RegisterParryAttempt(now)
        TriggerParryInput()

        if autoAbilitiesEnabled and speed >= 120 then
            task.delay(0.06, TriggerAbilityDefend)
        end
    end
end

local function ProcessIdenticalParry(ball, hrp, now)
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ""
    if target ~= Player.Name then 
        return 
    end

    local velocity = ball.AssemblyLinearVelocity
    local zoomies = ball:FindFirstChild("zoomies")
    if zoomies then
        if zoomies:IsA("LinearVelocity") or zoomies:IsA("VectorForce") then
            velocity = zoomies.VectorVelocity
        elseif zoomies:IsA("BodyVelocity") then
            velocity = zoomies.Velocity
        end
    end
    
    local speed = velocity.Magnitude
    if speed <= 0.1 then
        speed = ball.Velocity.Magnitude
        velocity = ball.Velocity
    end
    if speed < 0.1 then 
        return 
    end

    local playerPos = hrp.Position
    local ballPos = ball.Position
    local distance = (playerPos - ballPos).Magnitude

    if speed <= 2 and (ball:FindFirstChild("TimeHole") or ball:GetAttribute("TimeHole") or workspace:FindFirstChild("TimeHole")) then
        id_timeHoleLock = true
        return
    elseif id_timeHoleLock and speed > 10 then
        id_timeHoleLock = false
        speed = speed * 1.35
    end

    local dtVel = math.clamp(now - id_lastVelocityTime, 0.001, 0.050)
    id_lastVelocityTime = now
    local deltaV = (velocity - id_lastBallVelocity).Magnitude
    local rawAccel = (velocity - id_lastBallVelocity) / dtVel
    id_lastBallVelocity = velocity
    id_lastBallAcceleration = rawAccel

    if deltaV > 45 and distance < (CLASH_DISTANCE + 10) then
        id_furyCounterActive = true
    else
        id_furyCounterActive = false
    end

    local directionToPlayer = (distance > 0.01) and (playerPos - ballPos).Unit or Vector3.new(0, 1, 0)
    local velocityDirection = velocity.Unit
    local dot = directionToPlayer:Dot(velocityDirection)
    local rootVel = hrp.AssemblyLinearVelocity or Vector3.zero
    local relVelocity = velocity - rootVel
    local approachSpeed = relVelocity:Dot(directionToPlayer)

    if Camera then
        local camLook = Camera.CFrame.LookVector
        local camDot = camLook:Dot(velocityDirection)
        dot = (dot + (camDot * 0.35)) / 1.35
    end

    local isRealClash = (distance <= CLASH_DISTANCE) or id_furyCounterActive

    if approachSpeed < -2 and not isRealClash then
        return
    end

    local pingSec = currentRealPing
    local dtStep = 0.016
    local baseHorizon = 0.45 * 0.08
    local speedScaledHorizon = baseHorizon + math.clamp((speed - 150) * 0.0003, 0, 0.12)
    local totalTransitDelay = (pingSec * 0.50) + (dtStep * 0.50) + (1 / 60) + speedScaledHorizon

    local futurePlayerPos = playerPos + (rootVel * totalTransitDelay)
    local curveCompensation = 0.5 * id_lastBallAcceleration * (totalTransitDelay ^ 2)
    if curveCompensation.Magnitude > 15 then
        curveCompensation = curveCompensation.Unit * 15
    end

    local futureBallPos = ballPos + (velocity * totalTransitDelay) + curveCompensation
    local futureDistance = (futurePlayerPos - futureBallPos).Magnitude

    local baseRadius = 16.0
    local transitDistance = speed * (pingSec * 0.5 + 1 / 60)
    local serverInterceptionRadius = baseRadius + math.clamp(transitDistance, 0, 22)

    local shouldParry = false

    if distance <= baseRadius and (dot > 0.05 or approachSpeed > -5) then
        shouldParry = true
    elseif futureDistance <= serverInterceptionRadius and (approachSpeed > -10 or dot > 0.05) then
        shouldParry = true
    end

    if shouldParry then
        if (now - lastParryTime) < 0.06 and not autoClashActive then 
            return 
        end
        parriedBalls[ball] = true
        lastParryTime = now
        RegisterParryAttempt(now)
        TriggerParryInput()

        if autoAbilitiesEnabled and speed >= 120 then
            task.delay(0.06, TriggerAbilityDefend)
        end
    end
end

local function ProcessUltraLowLatency(ball, hrp, now)
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ""
    if target ~= Player.Name then 
        return 
    end

    local playerPos = hrp.Position
    local playerVel = hrp.AssemblyLinearVelocity
    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity
    local speed = ballVel.Magnitude

    if speed < 0.1 then 
        return 
    end

    local toPlayer = playerPos - ballPos
    local dist = toPlayer.Magnitude
    local toPlayerUnit = (dist > 0.01) and toPlayer.Unit or Vector3.new(0, 1, 0)
    
    local rawApproachSpeed = (ballVel - playerVel):Dot(toPlayerUnit)
    local isRetreating = rawApproachSpeed < -2

    if isRetreating and dist > 12.0 then
        return
    end

    local approachSpeed = rawApproachSpeed
    if approachSpeed <= 0 and not isRetreating then
        approachSpeed = speed * 0.40
    elseif approachSpeed <= 0 and isRetreating then
        approachSpeed = 0.1
    end

    local realETA = dist / math.max(approachSpeed, 1)
    local adjustedETA = realETA - currentRealPing - PARRY_SAFETY_BUFFER

    local baseETA = 0.24 + math.clamp(currentRealPing * 0.4, 0, 0.10)
    if speed >= 180 then
        baseETA = baseETA + math.clamp((speed - 180) * 0.0004, 0, 0.15)
    end

    local dot = ballVel.Unit:Dot(toPlayerUnit)
    local shouldParry = false

    if dist <= CLASH_DISTANCE and (not isRetreating or dist <= 13.0) then
        shouldParry = true
    elseif dist <= EMERGENCY_DISTANCE then
        shouldParry = true
    elseif dot < 0.25 and dot > -0.2 and (dist <= (SLOW_BALL_RADIUS + (speed * 0.1))) and not isRetreating then
        shouldParry = true
    elseif adjustedETA <= baseETA and not isRetreating then
        shouldParry = true
    end

    if shouldParry then
        if (now - lastParryTime) < 0.06 and not autoClashActive then 
            return 
        end
        parriedBalls[ball] = true
        lastParryTime = now
        RegisterParryAttempt(now)
        TriggerParryInput()

        if autoAbilitiesEnabled and speed >= 120 then
            task.delay(0.06, TriggerAbilityDefend)
        end
    end
end

local function ProcessAutoParry()
    local now = os.clock()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local ball = GetActiveBall()
    
    CheckClashDeactivation(now, ball, hrp)
    UpdateBallTrackers(ball)
    UpdateTargetLine(ball)
    UpdateGeneralVisuals()
    
    if not autoParryEnabled or not hrp or not ball then 
        lastBallSpd = 0 
        return 
    end
    
    local target = ball:GetAttribute("target") or ball:GetAttribute("Target") or ""
    
    if target ~= Player.Name then 
        parriedBalls[ball] = nil 
        lastBallSpd = 0 
        return 
    end
    
    if parriedBalls[ball] then 
        return 
    end
    
    if autoParryMode == "Smart (Pro)" then 
        ProcessSmartParry(ball, hrp, now) 
    elseif autoParryMode == "Identical" then
        ProcessIdenticalParry(ball, hrp, now)
    elseif autoParryMode == "Ultra Low Latency" then
        ProcessUltraLowLatency(ball, hrp, now)
    end
end

local Window = Library:CreateWindow({
    Title = "Velocity", 
    Theme = { 
        Font = "Roboto", 
        ImageTransparency = 0, 
        BGTransparency = 75, 
        BackgroundID = "104549579743427",
        Main = Color3.fromRGB(0, 0, 0), 
        Second = Color3.fromRGB(15, 15, 15), 
        ElementAccent = Color3.fromRGB(255, 255, 255), 
        TextColor = Color3.fromRGB(255, 255, 255), 
        GradientStart = Color3.fromRGB(255, 255, 255), 
        GradientEnd = Color3.fromRGB(70, 70, 70), 
        CornerRadius = 20, 
        HudTransparency = 10 
    }, 
    ToggleKey = Enum.KeyCode.LeftAlt, 
    Transparency = 0.1, 
    ShowWatermark = {
        Enabled = false
    }, 
    ConfigFolder = "Velocity_SafeConfigV5", 
    CornerRadius = 20, 
    UiScale = 1.0
})

local MainTab = Window:CreateTab("Main", true)
local ProtectionTab = Window:CreateTab("Protection", true)
local BotTab = Window:CreateTab("Bot", true)
local VisualsTab = Window:CreateTab("Visuals", true)

local LeftBlockCombat = MainTab:CreateBlock({
    Name = "Combat Modules", 
    Side = "Left"
})
local LeftBlockMovement = MainTab:CreateBlock({
    Name = "Movement Modifiers", 
    Side = "Left"
})
local RightBlockCore = MainTab:CreateBlock({
    Name = "Parry Tuning (Core)", 
    Side = "Right"
})
local RightBlockPhysics = MainTab:CreateBlock({
    Name = "Advanced Physics & Curve", 
    Side = "Right"
})

LeftBlockCombat:CreateDropdown({
    Name = "Auto Parry Mode", 
    Items = {"Smart (Pro)", "Identical", "Ultra Low Latency"}, 
    Default = "Smart (Pro)", 
    Flag = "AutoParryModeDrop", 
    Callback = function(Mode) 
        autoParryMode = Mode 
    end
})

local ParryToggle = LeftBlockCombat:CreateToggle({
    Name = "Auto Parry", 
    Default = false, 
    Flag = "AutoParry", 
    Callback = function(State) 
        autoParryEnabled = State 
    end
})

LeftBlockCombat:CreateKeybind({
    Name = "Auto Parry Bind", 
    Default = Enum.KeyCode.C, 
    Flag = "ParryKeybind", 
    Callback = function() 
        autoParryEnabled = not autoParryEnabled 
        pcall(function() 
            ParryToggle:Set(autoParryEnabled) 
        end)
    end
})

local AutoClashToggle = LeftBlockCombat:CreateToggle({
    Name = "Auto Clash Clicker", 
    Default = false, 
    Flag = "AutoClashClicker", 
    Callback = function(State) 
        autoClashDetectorEnabled = State 
        if not State and autoClashActive then 
            autoClashActive = false 
        end 
    end
})

LeftBlockCombat:CreateToggle({
    Name = "Auto Abilities [BETA]", 
    Default = false, 
    Flag = "AutoAbilitiesBetaToggle", 
    Callback = function(State) 
        autoAbilitiesEnabled = State 
        if isScriptLoaded then
            Library:Notify({
                Title = "Velocity", 
                Content = State and "Auto Abilities [BETA]: Enabled" or "Auto Abilities [BETA]: Disabled", 
                Duration = 2
            })
        end
    end
})

LeftBlockCombat:CreateKeybind({
    Name = "Fly Keybind", 
    Default = Enum.KeyCode.X, 
    Flag = "FlyKeybind", 
    Callback = function() 
        ToggleFly()
    end
})

LeftBlockCombat:CreateSlider({
    Name = "Fly Speed", 
    Min = 20, 
    Max = 200, 
    Default = 65, 
    Flag = "FlySpeedSlider", 
    Callback = function(Value) 
        flySpeed = math.floor(Value)
    end
})

local ClickerToggle = LeftBlockCombat:CreateToggle({
    Name = "Manual Autoclicker", 
    Default = false, 
    Flag = "Autoclicker", 
    Callback = function(State) 
        manualClickerEnabled = State 
    end
})

LeftBlockCombat:CreateKeybind({
    Name = "Manual Clicker Bind", 
    Default = Enum.KeyCode.V, 
    Flag = "ClickerKeybind", 
    Callback = function() 
        manualClickerEnabled = not manualClickerEnabled 
        pcall(function() 
            ClickerToggle:Set(manualClickerEnabled) 
        end)
    end
})

LeftBlockCombat:CreateSlider({
    Name = "Clicker Speed (CPS)", 
    Min = 5, 
    Max = 150, 
    Default = 30, 
    Flag = "ClickerCPS", 
    Callback = function(Value) 
        targetCPS = Value 
    end
})

LeftBlockCombat:CreateSlider({
    Name = "Auto Clash Detect Threshold", 
    Min = 1, 
    Max = 10, 
    Default = 4, 
    Flag = "ClashDetectThreshold", 
    Callback = function(Value) 
        autoClashThreshold = Value 
    end
})

LeftBlockMovement:CreateToggle({
    Name = "Movement Modifiers", 
    Default = false, 
    Flag = "MovementModifiersToggle", 
    Callback = function(State) 
        movementModifiersEnabled = State 
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and not State then
            hum.WalkSpeed = defaultGameWalkSpeed
        end
    end
})

LeftBlockMovement:CreateSlider({
    Name = "WalkSpeed", 
    Min = 16, 
    Max = 120, 
    Default = 36, 
    Flag = "CustomWalkSpeedSlider", 
    Callback = function(Value) 
        customWalkSpeed = math.floor(Value)
        if movementModifiersEnabled and Player.Character then
            local hum = Player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = customWalkSpeed
            end
        end
    end
})

local ProtMainBlock = ProtectionTab:CreateBlock({
    Name = "Phantom Evade Modules", 
    Side = "Left"
})

local ProtConfigBlock = ProtectionTab:CreateBlock({
    Name = "Box & Physics Tuning", 
    Side = "Right"
})

local PhantomToggle = ProtMainBlock:CreateToggle({
    Name = "Phantom Evade [BETA]", 
    Default = false, 
    Flag = "PhantomEvadeToggle", 
    Callback = function(State) 
        SetPhantomEvade(State)
    end
})

ProtMainBlock:CreateKeybind({
    Name = "Phantom Evade Bind", 
    Default = Enum.KeyCode.Z, 
    Flag = "PhantomEvadeKeybind", 
    Callback = function() 
        if PhantomToggle then
            PhantomToggle:Set(not autoDodgeEnabled)
        end
    end
})

ProtMainBlock:CreateToggle({
    Name = "Show Evade Box", 
    Default = false, 
    Flag = "ShowEvadeBoxToggle", 
    Callback = function(State) 
        dodgeBoxVisible = State
        if dodgeBoxPart then
            if State and autoDodgeEnabled then
                dodgeBoxPart.Transparency = 0.82
                if dodgeBoxSelection then dodgeBoxSelection.Visible = true end
            else
                dodgeBoxPart.Transparency = 1
                if dodgeBoxSelection then dodgeBoxSelection.Visible = false end
            end
        end
    end
})

ProtConfigBlock:CreateSlider({
    Name = "Evade Speed", 
    Min = 100, 
    Max = 10000, 
    Default = 500, 
    Flag = "EvadeSpeedSlider", 
    Callback = function(Value) 
        dodgeSpeed = Value
        if dodgeVel.Magnitude > 0.1 then
            dodgeVel = dodgeVel.Unit * dodgeSpeed
        end
    end
})

ProtConfigBlock:CreateSlider({
    Name = "Box Width (X)", 
    Min = 5, 
    Max = 150, 
    Default = 30, 
    Flag = "BoxWidthSlider", 
    Callback = function(Value) 
        dodgeBoxWidth = Value
        if dodgeBoxPart then
            dodgeBoxPart.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
        end
    end
})

ProtConfigBlock:CreateSlider({
    Name = "Box Height (Y)", 
    Min = 10, 
    Max = 200, 
    Default = 60, 
    Flag = "BoxHeightSlider", 
    Callback = function(Value) 
        dodgeBoxHeight = Value
        if dodgeBoxPart then
            dodgeBoxPart.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
        end
    end
})

ProtConfigBlock:CreateSlider({
    Name = "Box Thickness (Z)", 
    Min = 5, 
    Max = 150, 
    Default = 20, 
    Flag = "BoxThicknessSlider", 
    Callback = function(Value) 
        dodgeBoxThickness = Value
        if dodgeBoxPart then
            dodgeBoxPart.Size = Vector3.new(dodgeBoxWidth, dodgeBoxHeight, dodgeBoxThickness)
        end
    end
})

local ClashDistSlider
local CurveSlider
local SlowRadiusSlider
local BaseEtaSlider
local HighSpeedSlider
local EmergencyDistSlider

local Presets = {
    ["Competitive (Balanced)"] = {
        ClashDist = 18.0, 
        Curve = -0.15, 
        SlowRadius = 22.0, 
        BaseETA = 0.30, 
        HighSpeed = 200.0, 
        EmergencyDist = 10.0
    },
    ["Maximum Stability (Safe)"] = {
        ClashDist = 16.0, 
        Curve = -0.20, 
        SlowRadius = 25.0, 
        BaseETA = 0.35, 
        HighSpeed = 180.0, 
        EmergencyDist = 11.0
    },
    ["High Speed / Snipes"] = {
        ClashDist = 20.0, 
        Curve = -0.10, 
        SlowRadius = 24.0, 
        BaseETA = 0.28, 
        HighSpeed = 160.0, 
        EmergencyDist = 8.0
    },
    ["Clash Duelist"] = {
        ClashDist = 22.0, 
        Curve = 0.00, 
        SlowRadius = 18.0, 
        BaseETA = 0.30, 
        HighSpeed = 220.0, 
        EmergencyDist = 9.0
    },
    ["Anti-Curve Defense"] = {
        ClashDist = 17.0, 
        Curve = -0.25, 
        SlowRadius = 26.0, 
        BaseETA = 0.32, 
        HighSpeed = 200.0, 
        EmergencyDist = 10.0
    }
}

RightBlockCore:CreateDropdown({
    Name = "Parry Preset", 
    Items = {
        "Competitive (Balanced)", 
        "Maximum Stability (Safe)", 
        "High Speed / Snipes", 
        "Clash Duelist", 
        "Anti-Curve Defense"
    }, 
    Default = "Competitive (Balanced)", 
    Flag = "ParryPresetDrop", 
    Callback = function(Selected)
        local cfg = Presets[Selected]
        if cfg then
            GLOBAL_PARRY_COOLDOWN = 0
            CLASH_DISTANCE = cfg.ClashDist
            CURVE_DOT_THRESHOLD = cfg.Curve
            SLOW_BALL_RADIUS = cfg.SlowRadius
            BASE_ETA_THRESHOLD = cfg.BaseETA
            HIGH_SPEED_THRESHOLD = cfg.HighSpeed
            EMERGENCY_DISTANCE = cfg.EmergencyDist
            
            if ClashDistSlider then 
                pcall(function() 
                    ClashDistSlider:Set(cfg.ClashDist) 
                end) 
            end
            if CurveSlider then 
                pcall(function() 
                    CurveSlider:Set(cfg.Curve) 
                end) 
            end
            if SlowRadiusSlider then 
                pcall(function() 
                    SlowRadiusSlider:Set(cfg.SlowRadius) 
                end) 
            end
            if BaseEtaSlider then 
                pcall(function() 
                    BaseEtaSlider:Set(cfg.BaseETA) 
                end) 
            end
            if HighSpeedSlider then 
                pcall(function() 
                    HighSpeedSlider:Set(cfg.HighSpeed) 
                end) 
            end
            if EmergencyDistSlider then 
                pcall(function() 
                    EmergencyDistSlider:Set(cfg.EmergencyDist) 
                end) 
            end
        end
    end
})

RightBlockCore:CreateSlider({
    Name = "Custom Ping (ms)", 
    Min = 0, 
    Max = 350, 
    Default = 60, 
    Flag = "CustomPingSlider", 
    Callback = function(Value) 
        customPingMs = math.floor(Value)
        currentRealPing = (customPingMs + 10) / 1000
    end
})

ClashDistSlider = RightBlockPhysics:CreateSlider({
    Name = "Clash Distance", 
    Min = 10.0, 
    Max = 30.0, 
    Default = 18.0, 
    Flag = "ClashDist", 
    Callback = function(Value) 
        CLASH_DISTANCE = Value 
    end
})

CurveSlider = RightBlockPhysics:CreateSlider({
    Name = "Curve / Dot Sensitivity", 
    Min = -0.30, 
    Max = 0.30, 
    Default = -0.15, 
    Flag = "CurveSensitivity", 
    Callback = function(Value) 
        CURVE_DOT_THRESHOLD = Value 
    end
})

SlowRadiusSlider = RightBlockPhysics:CreateSlider({
    Name = "Slow Ball Radius", 
    Min = 15.0, 
    Max = 40.0, 
    Default = 22.0, 
    Flag = "SlowRadius", 
    Callback = function(Value) 
        SLOW_BALL_RADIUS = Value 
    end
})

BaseEtaSlider = RightBlockPhysics:CreateSlider({
    Name = "Base ETA Threshold", 
    Min = 0.20, 
    Max = 0.45, 
    Default = 0.30, 
    Flag = "BaseETAThreshold", 
    Callback = function(Value) 
        BASE_ETA_THRESHOLD = Value 
    end
})

HighSpeedSlider = RightBlockPhysics:CreateSlider({
    Name = "High Speed Threshold", 
    Min = 150.0, 
    Max = 400.0, 
    Default = 200.0, 
    Flag = "HighSpeedThreshold", 
    Callback = function(Value) 
        HIGH_SPEED_THRESHOLD = Value 
    end
})

EmergencyDistSlider = RightBlockPhysics:CreateSlider({
    Name = "Emergency Panic Distance", 
    Min = 3.0, 
    Max = 15.0, 
    Default = 10.0, 
    Flag = "EmergencyDistance", 
    Callback = function(Value) 
        EMERGENCY_DISTANCE = Value 
    end
})

BotMainBlock = BotTab:CreateBlock({
    Name = "Bot Settings", 
    Side = "Left"
})

BotMainBlock:CreateToggle({
    Name = "Enable Bot (Runs & Auto Aims)", 
    Default = false, 
    Flag = "BotEnableToggle",
    Callback = function(State)
        botEnabled = State
        if State then
            if not autoParryEnabled then
                autoParryEnabled = true
                if ParryToggle then 
                    pcall(function() 
                        ParryToggle:Set(true) 
                    end) 
                end
            end
            if not autoClashDetectorEnabled then
                autoClashDetectorEnabled = true
                if AutoClashToggle then 
                    pcall(function() 
                        AutoClashToggle:Set(true) 
                    end) 
                end
            end
        end
        if isScriptLoaded then 
            Library:Notify({
                Title = "Velocity", 
                Content = State and "Bot Activated" or "Bot Deactivated", 
                Duration = 2
            }) 
        end
    end
})

BotMainBlock:CreateToggle({
    Name = "Auto-Adapt Parameters (Overrides Sliders)", 
    Default = false, 
    Flag = "BotAutoAdaptToggle",
    Callback = function(State)
        botAutoAdaptEnabled = State
        if State and isScriptLoaded then 
            Library:Notify({
                Title = "Velocity", 
                Content = "Auto-Adapt ON: Parameters will shift dynamically!", 
                Duration = 2.5
            }) 
        end
    end
})

local VisualsCamera = VisualsTab:CreateBlock({
    Name = "Camera & ESP", 
    Side = "Left"
})

local VisualsSkinchanger = VisualsTab:CreateBlock({
    Name = "Skinchanger", 
    Side = "Left"
})

local VisualsLighting = VisualsTab:CreateBlock({
    Name = "Lighting & Atmosphere", 
    Side = "Right"
})

VisualsSkinchanger:CreateButton({
    Name = "Apply skinchanger",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastebin.com/raw/JRAiyHPx"))()
        end)
        
        if success then
            if isScriptLoaded then
                Library:Notify({
                    Title = "Velocity", 
                    Content = "Skinchanger Loaded Successfully!", 
                    Duration = 3
                })
            end
        else
            if isScriptLoaded then
                Library:Notify({
                    Title = "Velocity Error", 
                    Content = "Failed to load Skinchanger.", 
                    Duration = 3
                })
            end
            warn("Skinchanger Error: " .. tostring(err))
        end
    end
})

VisualsCamera:CreateSlider({
    Name = "Camera FOV", 
    Min = 70, 
    Max = 120, 
    Default = 70, 
    Flag = "CamFOV", 
    Callback = function(Value) 
        fovValue = Value 
        if isScriptLoaded then 
            Camera.FieldOfView = Value 
        end 
    end
})

VisualsCamera:CreateToggle({
    Name = "Unlock Camera Zoom Distance", 
    Default = false, 
    Flag = "UnlockZoom", 
    Callback = function(State) 
        unlockZoomEnabled = State 
        if isScriptLoaded then 
            Player.CameraMaxZoomDistance = State and 10000 or 128 
        end 
    end
})

VisualsCamera:CreateToggle({
    Name = "Ball Target & Speed Info", 
    Default = false, 
    Flag = "BallInfo", 
    Callback = function(State) 
        ballInfoEnabled = State 
        if not State then 
            ClearAllBallBillboards() 
        end 
    end
})

VisualsCamera:CreateToggle({
    Name = "Line to Target", 
    Default = false, 
    Flag = "LineToTarget", 
    Callback = function(State) 
        lineToTargetEnabled = State 
        if not State then
            targetLine.Visible = false
            targetLine.Parent = nil
        end
    end
})

VisualsCamera:CreateToggle({
    Name = "Player ESP", 
    Default = false, 
    Flag = "PlayerESPToggle", 
    Callback = function(State) 
        playerEspEnabled = State 
        if not State then 
            ClearAllESP() 
        end 
    end
})

VisualsCamera:CreateDropdown({
    Name = "Player ESP Mode", 
    Items = {"With Outline", "No Outline"}, 
    Default = "With Outline", 
    Flag = "PlayerESPMode", 
    Callback = function(Mode) 
        playerEspMode = Mode 
    end
})

VisualsCamera:CreateColorPicker({
    Name = "Player ESP Fill Color", 
    Default = Color3.fromRGB(255, 255, 255), 
    Flag = "PlayerESPFillColor", 
    Callback = function(Color) 
        playerEspFillColor = Color 
    end
})

VisualsCamera:CreateColorPicker({
    Name = "Player ESP Outline Color", 
    Default = Color3.fromRGB(255, 255, 255), 
    Flag = "PlayerESPOutlineColor", 
    Callback = function(Color) 
        playerEspOutlineColor = Color 
    end
})

VisualsLighting:CreateSlider({
    Name = "World Brightness", 
    Min = 0.0, 
    Max = 10.0, 
    Default = 2.0, 
    Flag = "WorldBrightness", 
    Callback = function(Value) 
        if isScriptLoaded then 
            Lighting.Brightness = Value 
        end 
    end
})

VisualsLighting:CreateSlider({
    Name = "Time of Day (ClockTime)", 
    Min = 0.0, 
    Max = 24.0, 
    Default = 14.0, 
    Flag = "TimeOfDay", 
    Callback = function(Value) 
        if isScriptLoaded then 
            Lighting.ClockTime = Value 
        end 
    end
})

VisualsLighting:CreateColorPicker({
    Name = "Ambient Color", 
    Default = Color3.fromRGB(128, 128, 128), 
    Flag = "AmbientColorPicker", 
    Callback = function(Color) 
        if isScriptLoaded then 
            Lighting.Ambient = Color 
            Lighting.OutdoorAmbient = Color 
        end 
    end
})

VisualsLighting:CreateToggle({
    Name = "No Effects", 
    Default = false, 
    Flag = "NoEffectsToggle", 
    Callback = function(State) 
        ApplyNoEffects(State) 
    end
})

VisualsLighting:CreateToggle({
    Name = "Custom Fog", 
    Default = false, 
    Flag = "CustomFogToggle", 
    Callback = function(State) 
        customFogEnabled = State 
        ApplyFog() 
    end
})

VisualsLighting:CreateColorPicker({
    Name = "Fog Color", 
    Default = Color3.fromRGB(180, 180, 180), 
    Flag = "CustomFogColor", 
    Callback = function(Color) 
        customFogColor = Color 
        if customFogEnabled then 
            ApplyFog() 
        end 
    end
})

VisualsLighting:CreateSlider({
    Name = "Fog Start Distance", 
    Min = 0, 
    Max = 5000, 
    Default = 0, 
    Flag = "CustomFogStart", 
    Callback = function(Value) 
        customFogStart = Value 
        if customFogEnabled then 
            ApplyFog() 
        end 
    end
})

VisualsLighting:CreateSlider({
    Name = "Fog End Distance", 
    Min = 50, 
    Max = 10000, 
    Default = 1000, 
    Flag = "CustomFogEnd", 
    Callback = function(Value) 
        customFogEnd = Value 
        if customFogEnabled then 
            ApplyFog() 
        end 
    end
})

RunService.PreSimulation:Connect(function()
    if not isScriptLoaded then 
        return 
    end
    if not autoParryEnabled and not (autoClashDetectorEnabled and autoClashActive) and not ballInfoEnabled and not botEnabled and not lineToTargetEnabled then 
        return 
    end
    ProcessAutoParry()
end)

isScriptLoaded = true

Library:Notify({
    Title = "Velocity", 
    Content = "Script Loaded! Press [Left Alt] to Toggle UI", 
    Duration = 3.5
})
