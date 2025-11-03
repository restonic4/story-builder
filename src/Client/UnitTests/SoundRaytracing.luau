local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local InstanceFactory = require(ReplicatedStorage.Shared.Libs.InstanceFactory)
local SoundRaytracing = require(StarterPlayer.StarterPlayerScripts.Client.Libs.SoundRaytracing)
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

local Tests = {}

function Tests.RegisterUnitTests()
	UnitTest.describe("SoundRaytracing", function()

		UnitTest.it("setup the basic sound raytracing settings", function()
            SoundRaytracing.SetDebug(true)
            SoundRaytracing.SetSamples(256)

			UnitTest.assert.equal(SoundRaytracing.Settings.DEBUG, true)
            UnitTest.assert.equal(SoundRaytracing.Settings.SAMPLES, 256)
		end)

        UnitTest.it("check static sound raytracing settings", function()
			UnitTest.assert.equal(SoundRaytracing.Settings.DEBUG, true)
            UnitTest.assert.equal(SoundRaytracing.Settings.SAMPLES, 256)
		end)

        local emitter: BasePart
        UnitTest.it("create and register emitter", function(done)
			emitter = InstanceFactory.Create({
                Class = "Part",
                Name = "Emitter",
                Parent = workspace,
                Properties = {
					Archivable = false,
                    Anchored = true,
                    Position = Vector3.new(0, 10, 0)
				},
                Children = {
					{
                        Class = "Sound",
                        Properties = {
                            Archivable = false
                        }
                    }
				}
            })

            local walls = InstanceFactory.Create({
                Class = "Folder",
                Name = "Walls",
                Parent = workspace,
                Properties = {
					Archivable = false
				},
                Children = {
					{
                        Class = "Part",
                        Name = "Floor",
                        Properties = {
                            Archivable = false,
                            Anchored = true,
                            Position = Vector3.new(0, 0, 0),
                            Size = Vector3.new(100, 1, 100)
                        }
                    },
                    {
                        Class = "Part",
                        Name = "Wall",
                        Properties = {
                            Archivable = false,
                            Anchored = true,
                            Position = Vector3.new(-25, 5, 0),
                            Size = Vector3.new(1, 10, 50)
                        }
                    }
				}
            })

            SoundRaytracing.RegisterEmitter(emitter)

            local player = Players.LocalPlayer
            local character: Model = player.Character or player.CharacterAdded:Wait()

            character:PivotTo(emitter.CFrame * CFrame.new(0, -5, 0))

		end, { async = true, timeout = -1, onAsyncFinish = function(passed) emitter:Destroy() end })
		
	end)
end

return Tests