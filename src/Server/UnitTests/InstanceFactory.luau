local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTest = require(ReplicatedStorage.Shared.Libs.UnitTest)
local InstanceFactory = require(ReplicatedStorage.Shared.Libs.InstanceFactory)

local Tests = {}

function Tests.RegisterUnitTests()
	UnitTest.describe("InstanceFactory", function()

		UnitTest.it("creates a basic instance and applies simple properties", function()
			local inst = InstanceFactory.Create{
				"Folder", -- shorthand className (spec[1])
				Name = "UT_TestFolder_Simple",
			}

			UnitTest.assert.equal(inst.ClassName, "Folder")
			UnitTest.assert.equal(inst.Name, "UT_TestFolder_Simple")

			-- cleanup
			inst:Destroy()
		end)

		UnitTest.it("sets properties via the Properties table and ignores unknown properties safely", function()
			-- test Properties table
			local inst = InstanceFactory.Create{
				Class = "Folder",
				Properties = {
					Archivable = false
				},
				-- unknown property that should be ignored (must not error)
				NonExistentProp = "should be ignored"
			}

			UnitTest.assert.equal(inst.Archivable, false)

			-- creating with an unknown property shouldn't error (creation succeeded)
			UnitTest.assert.truthy(inst)

			inst:Destroy()
		end)

		UnitTest.it("sets and reads Attributes", function()
			local inst = InstanceFactory.Create{
				Class = "Folder",
				Name = "UT_WithAttributes",
				Attributes = {
					owner = "Tester",
					version = 1
				}
			}

			UnitTest.assert.equal(inst:GetAttribute("owner"), "Tester")
			UnitTest.assert.equal(inst:GetAttribute("version"), 1)

			inst:Destroy()
		end)

		UnitTest.it("creates nested children and ensures child's Parent is overwritten to the created parent", function()
			local parent = InstanceFactory.Create{
				Class = "Folder",
				Name = "UT_Parent",
				Children = {
					-- child requests an explicit Parent (which should be overwritten by the factory)
					{ Class = "Folder", Name = "ChildThatAskedParent", Parent = workspace },
					-- shorthand child
					{ "Folder", Name = "ShorthandChild" }
				}
			}

			local child1 = parent:FindFirstChild("ChildThatAskedParent")
			local child2 = parent:FindFirstChild("ShorthandChild")

			UnitTest.assert.truthy(child1, "Expected first child to exist under parent")
			UnitTest.assert.truthy(child2, "Expected shorthand child to exist under parent")

			-- ensure parent's overwrite happened (child.Parent must equal the created parent)
			UnitTest.assert.equal(child1.Parent, parent)
			UnitTest.assert.equal(child2.Parent, parent)

			parent:Destroy()
		end)

		local bindableEvent: BindableEvent
		UnitTest.it("connects events and handlers (BindableEvent) and uses spy to verify callCount", function(done)
			-- create a BindableEvent with an Events handler that is a spy
			local spy = UnitTest.spy.create(function(...) 
				--warn(...)
			end)

			bindableEvent = InstanceFactory.Create{
				Class = "BindableEvent",
				Name = "UT_Bindable",
				Events = {
					Event = spy.fn
				}
			}

			task.spawn(function()
				bindableEvent.Event:Wait()
				task.wait()

				UnitTest.assert.equal(spy.callCount(), 1)
				UnitTest.assert.truthy(spy.called())

				local callArgs = spy.getCall(1)
				UnitTest.assert.equal(callArgs[1], "arg1")

				done()
			end)

			bindableEvent:Fire("arg1")
		end, { async = true, timeout = 5, onAsyncFinish = function(passed) bindableEvent:Destroy() end })

		UnitTest.it("ensures children and events are wired before Init, and Parent is assigned after Init", function()
			local sawChildInInit = false
			local eventSpy = UnitTest.spy.create(function() end)

			-- Create a BindableEvent; connect a handler (eventSpy), create a child, and in Init:
			--  * verify the child exists
			--  * verify the Event connection exists by firing the event inside Init
			--  * capture the value of Parent inside Init (should be nil because Parent assignment is last)
			local initSawParentValue = "unset"

			local bindableEventWithChilds: BindableEvent = InstanceFactory.Create{
				Class = "BindableEvent",
				Name = "UT_InitOrdering",
				Events = {
					Event = eventSpy.fn
				},
				Children = {
					{ Class = "Folder", Name = "InitChild" }
				},
				Init = function(self)
					-- child should already exist
					sawChildInInit = self:FindFirstChild("InitChild") ~= nil

					-- Parent should not yet be assigned (factory assigns Parent at the end)
					initSawParentValue = self.Parent
				end,
				Parent = workspace -- give it a parent — but Init should have seen nil
			}

			-- assertions
			UnitTest.assert.truthy(sawChildInInit, "Init should see created children")
			UnitTest.assert.equal(initSawParentValue, nil, "Parent should be nil during Init (assigned after Init)")

			-- after creation parent should be assigned
			UnitTest.assert.equal(bindableEventWithChilds.Parent, workspace)

			bindableEventWithChilds:Destroy()
		end)

		UnitTest.it("returns error (pcall false) when trying to create an invalid class", function()
			-- InstanceFactory.new uses a pcall around Instance.new and asserts on the result.
			-- We use pcall here to verify that trying to create a non-existent class fails.
			local ok, result = pcall(function()
				InstanceFactory.new("ThisClassDoesNotExist", {})
			end)
			-- pcall should catch the assertion and return false (creation errored)
			UnitTest.assert.equal(ok, false)
		end)

		UnitTest.it("creates a basic instance and exports it", function()
			local instanceData = {
				Class = "Folder",
				Name = "UT_TestFolder_Simple",
				Parent = workspace,
				Properties = {
					Archivable = false
				},
				Children = {
					{
						Class = "Part",
						Name = "HelloWorld",
						Properties = {
							Anchored = true,
							CanCollide = false,
							CanQuery = false,
							CanTouch = false,
							Transparency = 0.5
						}
					}
				}
			}

			local inst = InstanceFactory.Create(instanceData)
			local exportedData = InstanceFactory.Export(inst)

			UnitTest.assert.equal(exportedData.Class, instanceData.Class)
			UnitTest.assert.equal(exportedData.Name, instanceData.Name)
			UnitTest.assert.equal(exportedData.ParentPath, instanceData.Parent:GetFullName())
			UnitTest.assert.equal(exportedData.Properties.Archivable, instanceData.Properties.Archivable)
			UnitTest.assert.equal(#exportedData.Children, #instanceData.Children)

			-- cleanup
			inst:Destroy()
		end)
	end)
end

return Tests