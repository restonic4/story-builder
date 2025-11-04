local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local InstanceFactory = require(ReplicatedStorage.Shared.Libs.InstanceFactory)
local SoundRaytracing = require(StarterPlayer.StarterPlayerScripts.Client.Libs.SoundRaytracing)
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)

local Tests = {}

function Tests.RegisterUnitTests()
	UnitTest.describe("SoundRaytracing", function()

		UnitTest.it("setup the basic sound raytracing settings", function()
            SoundRaytracing.SetDebug(true)
            SoundRaytracing.SetSkyComputes(true)
            SoundRaytracing.SetSamples(256)

			UnitTest.assert.equal(SoundRaytracing.Settings.DEBUG, true)
            UnitTest.assert.equal(SoundRaytracing.Settings.SAMPLES, 256)
		end)

        UnitTest.it("check static sound raytracing settings", function()
			UnitTest.assert.equal(SoundRaytracing.Settings.DEBUG, true)
            UnitTest.assert.equal(SoundRaytracing.Settings.SAMPLES, 256)
		end)

        local testInstances: Folder
        UnitTest.it("create and register emitter", function(done)
            testInstances = InstanceFactory.Create({
                Class = "Folder",
                Name = "SoundRaytracingTest",
                Parent = workspace
            })

			local emitter = InstanceFactory.Create({
                Class = "Part",
                Name = "Emitter",
                Parent = testInstances,
                Properties = {
					Archivable = false,
                    Anchored = true,
                    Position = Vector3.new(0, 10, 0)
				},
                Children = {
					{
                        Class = "Sound",
                        Properties = {
                            Archivable = false,
                            SoundId = "rbxassetid://1837810583",
                            Looped = true,
                            RollOffMaxDistance = 100
                        }
                    }
				}
            })

            emitter.Sound:Play()

            local listener: BasePart = InstanceFactory.Create({
                Class = "Part",
                Name = "Listener",
                Parent = testInstances,
                Properties = {
					Archivable = false,
                    Anchored = true,
                    Position = Vector3.new(-37.5, 5, 0)
				}
            })

            SoundRaytracing.SetListenerObject(listener)

            local walls = InstanceFactory.Create({
                Class = "Folder",
                Name = "Walls",
                Parent = testInstances,
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
                    },
                    {
                        Class = "Part",
                        Name = "Wall",
                        Properties = {
                            Archivable = false,
                            Anchored = true,
                            Position = Vector3.new(-50, 5, 0),
                            Size = Vector3.new(1, 10, 50)
                        }
                    },
                    {
                        Class = "Part",
                        Name = "Wall",
                        Properties = {
                            Archivable = false,
                            Anchored = true,
                            Position = Vector3.new(-37.5, 5, -25),
                            Size = Vector3.new(25, 10, 1)
                        }
                    },
                    {
                        Class = "Part",
                        Name = "Roof",
                        Properties = {
                            Archivable = false,
                            Anchored = true,
                            Position = Vector3.new(-37.5, 10, 0),
                            Size = Vector3.new(25, 1, 50)
                        }
                    }
				}
            })

            SoundRaytracing.RegisterEmitter(emitter)

            task.spawn(function()
                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()

                UnitTest.assert.near(emitter.Sound.Volume, 0.07, 0.01)

                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()

                listener.Position = Vector3.new(0, 30, 0)
                
                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()

                UnitTest.assert.near(emitter.Sound.Volume, 0.5, 0.01)

                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()
                
                done()
            end)

		end, { async = true, timeout = -1, onAsyncFinish = function(passed)
            testInstances:Destroy()
            SoundRaytracing.ResetSettings()
        end })
		
	end)
end

return Tests