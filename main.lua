local DEBUG = false

local function flow(tag)
	if DEBUG then
		print("[Ashleng on Top] -> " .. tag)
	end
end
flow("Script Loaded")

local function monitor(name, fn)
	return function(...)
		flow(name .. " START")
		
		local ok, result = pcall(fn, ...)
		
		if ok then
			flow(name .. " SUCCESS")
		else
			warn(name .. " ERROR: " .. tostring(result))
		end
		
		return result
	end
end

_G.__A9F31KZ = _G.__A9F31KZ or false
if _G.__A9F31KZ then return end
_G.__A9F31KZ = true

local lastDeposit = 0

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Networking")
local SpawnMachineRemote = Net:WaitForChild("RF/SpawnMachineAction")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local function onCharacterAdded(char)
	character = char
end

player.CharacterAdded:Connect(onCharacterAdded)

-- Remove old GUI safely
local oldGui = player.PlayerGui:FindFirstChild("MainUtilityGUI")
if oldGui then oldGui:Destroy() end

-- ================= SETTINGS =================

local brainrotsList = {
	"Galactio Fantasma",
	"Cupitron Consoletron",
	"Freezeti Cobretti",
}

local SELECTED_PETS_FOR_DEPOSIT = {
	"Colossal Freezeti Cobretti",
	"Colossal Galactio Fantasma",
	"Colossal Cupitron Consoletron",
	"Big Freezeti Cobretti",
	"Big Galactio Fantasma",
	"Big Cupitron Consoletron"
}

local Config = {
	autoEquipEnabled = false,
	removeVIPEnabled = false,
	autoATMEnabled = true,
	atmTeleportEnabled = true,
	autoCombineEnabled = true,
	godModeEnabled = true
}

local EQUIP_DELAY = 0.6

local ATM_POSITION = Vector3.new(909.410645, 3.532636, 32.877258)
local BLACKHOLE_POSITION = Vector3.new(894.619934, 3.614657, 6.723338)
local ARCADE_POSITION = Vector3.new(901.143799, 3.372710, -15.076845)
local VALENTINES_POSITION = Vector3.new(900.504883, 3.595896, -28.093462)
local DOOM_POSITION = Vector3.new(899.169189453125, 3.669783353805542, -45.32243728637695)

-- ================= FUNCTIONS =================

local function isBrainrot(petName)
	for _, name in ipairs(brainrotsList) do
		if name == petName then
			return true
		end
	end
	return false
end

local function getHeldPetName()
	local hrp = character and character:WaitForChild("HumanoidRootPart", 2)
	if not hrp then return nil end

	local debris = Workspace:WaitForChild("Debris")
	local closestPet = nil
	local closestDist = math.huge

	for _, obj in ipairs(debris:GetChildren()) do
		if obj:IsA("BasePart") and obj.Name == "BillboardTemplate" then
			local gui = obj:FindFirstChildWhichIsA("SurfaceGui") or obj:FindFirstChildWhichIsA("BillboardGui")
			if gui then
				local nameLabel = gui:FindFirstChild("BrainrotName", true)
				if nameLabel then
					local distance = (hrp.Position - obj.Position).Magnitude
					if distance < closestDist then
						closestDist = distance
						closestPet = nameLabel.Text
					end
				end
			end
		end
	end

	return closestPet
end

local function isSelectedPetEquipped()
	local held = getHeldPetName()
	return held and table.find(SELECTED_PETS_FOR_DEPOSIT, held)
end

local function getMachine()
	local go = Workspace:FindFirstChild("GameObjects")
	if not go then return nil end
	
	local ps = go:FindFirstChild("PlaceSpecific")
	if not ps then return nil end
	
	local root = ps:FindFirstChild("root")
	if not root then return nil end
	
	local sm = root:FindFirstChild("SpawnMachines")
	if not sm then return nil end

	if sm:FindFirstChild("Blackhole") then
		return sm.Blackhole, "BLACKHOLE"
	elseif sm:FindFirstChild("ATM") then
		return sm.ATM, "ATM"
	elseif sm:FindFirstChild("Arcade") then
		return sm.Arcade, "ARCADE"
	elseif sm:FindFirstChild("Valentines") then
		return sm.Valentines, "VALENTINES"
	elseif sm:FindFirstChild("Doom") then
		return sm.Doom, "DOOM"
	end

	return nil, nil
end

local function machineHasPet(machine)
	if not machine then return false end
	
	local main = machine:FindFirstChild("Main")
	if not main then return false end
	
	local billboard = main:FindFirstChild("Billboard")
	if not billboard then return false end
	
	local gui = billboard:FindFirstChild("BillboardGui")
	if not gui then return false end
	
	local frame = gui:FindFirstChild("Frame")
	if not frame then return false end
	
	local brainrots = frame:FindFirstChild("Brainrots")
	if not brainrots then return false end
	
	return brainrots:FindFirstChild("Line_1") ~= nil
end


-- ================= GOD MODE =================

local godConnection

local function enableGodMode(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.MaxHealth = 10000
	humanoid.Health = 10000

	if godConnection then godConnection:Disconnect() end

	godConnection = humanoid.HealthChanged:Connect(function()
		if humanoid.Health <= 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

local function onGodCharacterAdded(char)
	if Config.godModeEnabled then
		wait(0.35)
		enableGodMode(char)
	end
end

player.CharacterAdded:Connect(onGodCharacterAdded)

-- ================= MAIN CONTROLLER LOOP =================

local function safeDeposit(m)
	if SpawnMachineRemote then
	pcall(function()
		SpawnMachineRemote:InvokeServer("Deposit", m)
	end)
end
end

local function safeCombine(m)
	if SpawnMachineRemote then
	pcall(function()
		SpawnMachineRemote:InvokeServer("Combine", m)
	end)
end
end

safeDeposit = monitor("safeDeposit", safeDeposit)
safeCombine = monitor("safeCombine", safeCombine)

spawn(function()
	while wait(0.15) do
		flow("Main Loop Tick")

		local machine, kind = getMachine()
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local char = character

		-- Auto Equip Logic (event-based)
		if machine then
			Config.autoEquipEnabled = true
		else
			Config.autoEquipEnabled = false
		end

		if Config.autoEquipEnabled and not isSelectedPetEquipped() then
			local backpack = player:FindFirstChild("Backpack")
			local hum = char and char:FindFirstChild("Humanoid")

			if backpack and hum then
				for _, tool in ipairs(backpack:GetChildren()) do
					if tool:IsA("Tool") then
						hum:EquipTool(tool)
						wait(0.15)
						if isSelectedPetEquipped() then
							break
						end
					end
				end
			end
		end

		-- Teleport
if machine and Config.atmTeleportEnabled and hrp and isSelectedPetEquipped() then
	if kind == "BLACKHOLE" then
		hrp.CFrame = CFrame.new(BLACKHOLE_POSITION)
	elseif kind == "ATM" then
		hrp.CFrame = CFrame.new(ATM_POSITION)
	elseif kind == "ARCADE" then
		hrp.CFrame = CFrame.new(ARCADE_POSITION)
	elseif kind == "VALENTINES" then
		hrp.CFrame = CFrame.new(VALENTINES_POSITION)
	elseif kind == "DOOM" then
		hrp.CFrame = CFrame.new(DOOM_POSITION)
	end
end

		-- Deposit (only Big or Colossal Freezeti Cobretti)
if machine and Config.autoATMEnabled then
	local heldPetName = getHeldPetName() -- scan debris for currently held pet
	if heldPetName and table.find(SELECTED_PETS_FOR_DEPOSIT, heldPetName) then
		if not machineHasPet(machine) and tick() - lastDeposit > 1 then
			lastDeposit = tick()
        pcall(safeDeposit, machine)
		end
	end
end



		-- Combine
		if machine and Config.autoCombineEnabled then
	pcall(safeCombine, machine)
       end
	end
end)

-- ================= LIGHTWEIGHT VIP REMOVER =================

if Config.removeVIPEnabled then
	local vip = Workspace:FindFirstChild("VIPWalls", true)
	if vip then vip:Destroy() end
end

-- ================= GUI =================

local gui = Instance.new("ScreenGui")
gui.Name = "MainUtilityGUI"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 300)
frame.Position = UDim2.new(0.03, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Ashleng on Top! (Optimized)"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1,1,1)
title.Parent = frame

local function createToggle(text, yPos, variableName)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 34)
	btn.Position = UDim2.new(0.05, 0, 0, yPos)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local function update()
		btn.Text = text .. ": " .. (Config[variableName] and "ON" or "OFF")
	end

	btn.MouseButton1Click:Connect(function()
		Config[variableName] = not Config[variableName]
		update()
	end)

	update()
end

local y = 60

createToggle("Auto Teleport", y, "atmTeleportEnabled")
y = y + 40

createToggle("Auto Deposit", y, "autoATMEnabled")
y = y + 40

createToggle("Auto Combine", y, "autoCombineEnabled")

spawn(function()
	while wait(5) do
		flow("Heartbeat Alive")
	end
end)

-- ================= LOAD CONFIRMATION SCRIPT =================
-- Place this at the end of your main script (after GUI creation)

spawn(function()
    print("Ashleng on Top! Script Started")

    -- Wait for character to load
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    print("Character Loaded:", character.Name)

    -- Check Humanoid
    local humanoid = character:WaitForChild("Humanoid")
    print("Humanoid Loaded")

    -- Check Debris folder
    local debris = game:GetService("Workspace"):WaitForChild("Debris")
    print("Debris Loaded")

    -- Check SpawnMachines
    local spawnMachines = game:GetService("Workspace"):FindFirstChild("GameObjects"):FindFirstChild("PlaceSpecific"):FindFirstChild("root"):FindFirstChild("SpawnMachines")
    print("SpawnMachines Loaded")

    -- Check Remote
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Networking")
    local spawnMachineRemote = net:WaitForChild("RF/SpawnMachineAction")
    print("Remote Functions Ready")

    -- Confirm Config
    print("Auto Equip Enabled:", Config.autoEquipEnabled)
    print("Auto Deposit Enabled:", Config.autoATMEnabled)
    print("Auto Teleport Enabled:", Config.atmTeleportEnabled)
    print("Auto Combine Enabled:", Config.autoCombineEnabled)
    print("God Mode Enabled:", Config.godModeEnabled)

    -- GUI Loaded
    local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainUtilityGUI")
    print("GUI Loaded:", gui.Name)

    -- Optional: Confirm main loop is running
    spawn(function()
        while true do
            wait(1)
            print("Main Loop Alive:", tick())
        end
    end)

    print("Ashleng on Top! Script Fully Loaded ✅")
end)
