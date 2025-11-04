local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InstanceFactory = require(ReplicatedStorage.Shared.Libs.InstanceFactory)
local Gizmos = require(script.Parent.Gizmos)

local SoundRaytracing = {}
SoundRaytracing.Defaults = {}
SoundRaytracing.Settings = {}

local RED = Color3.new(1, 0, 0)
local GREEN = Color3.new(0, 1, 0)
local BLUE = Color3.new(0, 0, 1)
local WHITE = Color3.new(1, 1, 1)

SoundRaytracing.Defaults.SAMPLES = 256
SoundRaytracing.Defaults.RAYBACK_OFFSET = 0.1
SoundRaytracing.Defaults.MIN_VOLUME = 0
SoundRaytracing.Defaults.MAX_ATTENUATION = 1 - SoundRaytracing.Defaults.MIN_VOLUME
SoundRaytracing.Defaults.SKY_COMPUTES = true
SoundRaytracing.Defaults.DEBUG = false

SoundRaytracing.Settings.SAMPLES = SoundRaytracing.Defaults.SAMPLES
SoundRaytracing.Settings.RAYBACK_OFFSET = SoundRaytracing.Defaults.RAYBACK_OFFSET
SoundRaytracing.Settings.MIN_VOLUME = SoundRaytracing.Defaults.MIN_VOLUME
SoundRaytracing.Settings.MAX_ATTENUATION = SoundRaytracing.Defaults.MAX_ATTENUATION
SoundRaytracing.Settings.SKY_COMPUTES = SoundRaytracing.Defaults.SKY_COMPUTES
SoundRaytracing.Settings.DEBUG = SoundRaytracing.Defaults.DEBUG

--[[

TODO:
- Use different samples depending on the user's quality and FPS
- Unit tests

]]

SoundRaytracing.DebugGui = nil
SoundRaytracing.DEBUG = {}

function createGui()
	SoundRaytracing.DebugGui = InstanceFactory.Create({
		Class = "ScreenGui",
		Name = "SoundRaytracingDebugGui",
		Parent = Players.LocalPlayer.PlayerGui,
		Properties = {
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			Enabled = false
		},
		Children = {
			{
				Class = "Frame",
				Name = "Container",
				Properties = {
					BackgroundColor3 = Color3.new(0.105882, 0.105882, 0.105882),
					Position = UDim2.new(0.807578027, -5, 0.62559998, -5),
					Size = UDim2.new(0.192421973, 0, 0.37440002, 0),
					BorderSizePixel = 0
				},
				Children = {
					{
						Class = "UIPadding",
						Properties = {
							PaddingBottom = UDim.new(0, 5),
							PaddingLeft = UDim.new(0, 5),
							PaddingRight = UDim.new(0, 5),
							PaddingTop = UDim.new(0, 5)
						}
					},
					{
						Class = "UICorner",
						Properties = {
							CornerRadius = UDim.new(0, 8)
						}
					},
					{
						Class = "TextLabel",
						Name = "Title",
						Properties = {
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 0, 0, 0),
							Size = UDim2.new(1, 0, 0.123931624, 0),
							Text = "SoundRaytracing debug stats",
							TextColor3 = Color3.new(1, 1, 1)
						}
					},
					{
						Class = "Frame",
						Name = "Line",
						Properties = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(0.152941, 0.152941, 0.152941),
							Position = UDim2.new(0.5, 0, 0.150000006, 0),
							Size = UDim2.new(0.75, 0, 0, 1),
							BorderSizePixel = 0   
						}
					},
					{
						Class = "ScrollingFrame",
						Name = "EmittersStats",
						Properties = {
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							Position = UDim2.new(0.5, 0, 1, 0),
							Size = UDim2.new(1, 0, 0.8, 0),
							BorderSizePixel = 0,
							ScrollBarThickness = 6
						},
						Children = {
							{
								Class = "UIGridLayout",
								Properties = {
									CellSize = UDim2.new(1, 0, 0, 25),
									CellPadding = UDim2.new(0, 0, 0, 5)
								}
							}
						}
					}
				}
			}
		}
	})
end

function updateDebugUI()
	if SoundRaytracing.Settings.DEBUG then
		if not SoundRaytracing.DebugGui then
			createGui()
		end

		for i, textLabel in SoundRaytracing.DebugGui.Container.EmittersStats:GetChildren() do
			if textLabel:IsA("TextLabel") then
				
			end
		end

		SoundRaytracing.DebugGui.Enabled = true
	elseif SoundRaytracing.DebugGui then
		SoundRaytracing.DebugGui.Enabled = false
	end
end

function updateDebugStat(ID, state: number)
	if not SoundRaytracing.DEBUG[ID] then
		SoundRaytracing.DEBUG[ID] = {}
	end

	table.insert(SoundRaytracing.DEBUG[ID], state)
end

function castSphereRays(origin: Vector3, rayCount: number, maxDistance: number, raycastParams: RaycastParams, ID: string, dedupeRadius: number?)
	rayCount = math.max(1, rayCount or 100)
	maxDistance = maxDistance or 100
	dedupeRadius = dedupeRadius or 0.5
	raycastParams = raycastParams or RaycastParams.new()

	local hits = {}
	local hitPositions = {} -- for dedupe checks

	local goldenAngle = math.pi * (3 - math.sqrt(5)) -- golden angle

	for i = 0, rayCount - 1 do
		local t = 0
		if rayCount == 1 then
			t = 0.5
		else
			t = i / (rayCount - 1)
		end

		local y = 1 - 2 * t -- y in [-1,1]
		local radius = math.sqrt(math.max(0, 1 - y * y))
		local theta = goldenAngle * i
		local x = math.cos(theta) * radius
		local z = math.sin(theta) * radius

		local direction = Vector3.new(x, y, z) -- unit vector pointing outward
		local result = workspace:Raycast(origin, direction * maxDistance, raycastParams)

		if result then
			local pos = result.Position
			-- deduplicate hits that are within dedupeRadius
			local isDuplicate = false
			for _, p in ipairs(hitPositions) do
				if (p - pos).Magnitude <= dedupeRadius then
					isDuplicate = true
					break
				end
			end
			
			local dirUnit = direction.Unit
			local hitDistance = (pos - origin).Magnitude
			
			local beforeDistance = math.max(0, hitDistance - SoundRaytracing.Settings.RAYBACK_OFFSET)
			local posBefore = origin + dirUnit * beforeDistance

			if not isDuplicate then
				if SoundRaytracing.Settings.DEBUG then
					Gizmos:SetColor(BLUE)
					Gizmos:DrawLine(origin, pos)
				end
				
				table.insert(hitPositions, pos)
				table.insert(hits, {
					Position = pos,
					PositionBefore = posBefore,
					Normal = result.Normal,
					Instance = result.Instance,
					Material = result.Material,
					Distance = (pos - origin).Magnitude,
					Direction = direction,
				})
			end
		else
			if SoundRaytracing.Settings.SKY_COMPUTES then
				local pos = origin + direction * maxDistance

				table.insert(hits, {
					Position = pos,
					PositionBefore = pos,
					Distance = (pos - origin).Magnitude,
					Direction = direction,
				})
			end

			if SoundRaytracing.Settings.DEBUG then
				Gizmos:SetColor(WHITE)
				Gizmos:DrawLine(origin, origin + direction * maxDistance)
			end
		end
	end

	return hits
end

local function castCollisionToCamera(origin: Vector3, camera: Camera | BasePart, raycastParams: RaycastParams, ID: string)
	-- Ensure valid inputs
	if not (origin and camera and camera.CFrame) then
		warn("Invalid origin or camera provided.")
		return false
	end

	-- Calculate direction from origin to camera
	local direction = (camera.CFrame.Position - origin).Unit
	local distance = (camera.CFrame.Position - origin).Magnitude

	-- Perform the raycast
	local result = workspace:Raycast(origin, direction * distance, raycastParams)

	-- If result is nil, no collision occurred
	if result == nil then
		if SoundRaytracing.Settings.DEBUG then
			Gizmos:SetColor(GREEN)
			Gizmos:DrawLine(origin, (origin + direction.Unit * distance) - Vector3.new(0, 0.1, 0))
		end
		
		return false
	end
	
	if SoundRaytracing.Settings.DEBUG then
		Gizmos:SetColor(RED)
		Gizmos:DrawLine(origin, (origin + direction.Unit * distance) - Vector3.new(0, 0.1, 0))
		--updateDebugStat(ID, 0)
	end

	-- Otherwise, a collision was detected
	return true, result
end

local emitters = {}

local function registerEmitterLoop(player: Player, emitter: BasePart)
    local ID = getNextID()
    emitter:SetAttribute("RaytracingID", ID)
    emitters[ID] = {
        id = ID,
        emitter = emitter,
        sounds = {},
        connection = nil
    }

    local emitterData = emitters[ID]

    for i, sound in emitter:GetChildren() do
        if sound:IsA("Sound") then
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
	        emitterData.sounds[sound] = {
                OriginalVolume = sound.Volume
            }
        end
    end
	
	emitterData.connection = RunService.RenderStepped:Connect(function()
		if emitter == nil or emitter.Parent == nil then
			warn("Emitter destroyed!")
			SoundRaytracing.UnRegister(emitter)
            return
		end

		--updateDebugUI()

		local camera = SoundRaytracing.Settings.LISTENER or workspace.CurrentCamera

		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = { emitter, player.Character, camera }
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.IgnoreWater = true
		
        -- Check all sounds on the emitter
        for sound, soundData in emitterData.sounds do
			-- Discard if not playing
			if not sound.IsPlaying then
				continue
			end

            -- Dicard if out of reach
            if (camera.CFrame.Position - emitter.Position).Magnitude > sound.RollOffMaxDistance then
			    continue
		    end

            local cleanRays = 0

            -- Cast directly to cam first to save resources, if obstructed, we caculate the spehere rays
            local directObstruction = castCollisionToCamera(emitter.Position, camera, rp, ID)
            if directObstruction then
                local hits = castSphereRays(emitter.Position, SoundRaytracing.Settings.SAMPLES, sound.RollOffMaxDistance, rp, ID)
                for i, hit in hits do
                    local hitRp = RaycastParams.new()
                    hitRp.FilterDescendantsInstances = { emitter, player.Character, camera }
                    hitRp.FilterType = Enum.RaycastFilterType.Exclude
                    hitRp.IgnoreWater = true

                    local obstructed = castCollisionToCamera(hit.PositionBefore, camera, hitRp, ID)
                    if not obstructed then
                        cleanRays += 1
                    end
                end
            else
                cleanRays = SoundRaytracing.Settings.SAMPLES -- Max value, direct view
            end

            local ratio = cleanRays / SoundRaytracing.Settings.SAMPLES
            local attenuation = 1 - (SoundRaytracing.Settings.MAX_ATTENUATION * (1 - math.sqrt(ratio)))
            
            local newVolume = soundData.OriginalVolume * attenuation
            sound.Volume = newVolume
        end
	end)
end

SoundRaytracing._currentID = 0
function getNextID()
	SoundRaytracing._currentID += 1
	return SoundRaytracing._currentID
end

-- Public API

function SoundRaytracing.SetSamples(samples: number)
	SoundRaytracing.Settings.SAMPLES = samples
end

function SoundRaytracing.SetRayBackOffset(raybackOffset: number)
	SoundRaytracing.Settings.RAYBACK_OFFSET = raybackOffset
end

function SoundRaytracing.SetMinVolume(volume: number)
	SoundRaytracing.Settings.MIN_VOLUME = volume
end

function SoundRaytracing.SetMaxAttenuation(attenuation: number)
	SoundRaytracing.Settings.MAX_ATTENUATION = attenuation
end

function SoundRaytracing.SetSkyComputes(skyComputes: boolean)
	SoundRaytracing.Settings.SKY_COMPUTES = skyComputes
end

function SoundRaytracing.SetDebug(debug: boolean)
	SoundRaytracing.Settings.DEBUG = debug
end

function SoundRaytracing.SetListenerObject(object: BasePart | Camera)
	SoundRaytracing.Settings.LISTENER = object
end

function SoundRaytracing.ResetSettings()
	SoundRaytracing.Settings.SAMPLES = SoundRaytracing.Defaults.SAMPLES
	SoundRaytracing.Settings.RAYBACK_OFFSET = SoundRaytracing.Defaults.RAYBACK_OFFSET
	SoundRaytracing.Settings.MIN_VOLUME = SoundRaytracing.Defaults.MIN_VOLUME
	SoundRaytracing.Settings.MAX_ATTENUATION = SoundRaytracing.Defaults.MAX_ATTENUATION
	SoundRaytracing.Settings.SKY_COMPUTES = SoundRaytracing.Defaults.SKY_COMPUTES
	SoundRaytracing.Settings.DEBUG = SoundRaytracing.Defaults.DEBUG
end

function SoundRaytracing.RegisterEmitter(emitter: BasePart)
    local emitterID: number = emitter:GetAttribute("RaytracingID") or getNextID()
	if emitters[emitterID] then
		warn("This emitter is already registered!")
		return
	end
	
	local player = game.Players.LocalPlayer
    registerEmitterLoop(player, emitter)
end

function SoundRaytracing.UnRegister(emitter: BasePart)
    local ID = emitter:GetAttribute("RaytracingID")
    local emitterData = emitters[ID]
    if not emitterData then
        warn("Could not un-register emitter, not registered!")
        return
    end

    emitterData.connection:Disconnect()
    for sound, soundData in emitterData.sounds do
        sound.Volume = soundData.OriginalVolume
    end
    emitterData[ID] = nil
end

return SoundRaytracing
