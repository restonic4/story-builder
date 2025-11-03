local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
print("Hello world, from client!")

RunService.RenderStepped:Connect(function(deltaTime: number)
    print(deltaTime)
end)

