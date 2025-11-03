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
				}
            })

            
		end, { async = true, timeout = -1, onAsyncFinish = function(passed) emitter:Destroy() end })
		
	end)
end

return Tests