local Rawmeleon = {}

function CustomNetLib.ConvertToRaw(sentence: string, x: number, y: number, z: number, targetInstance: Instance?)
	local totalLetters = string.len(sentence)

	local punctuationCount = 0
	for _ in string.gmatch(sentence, "[%p]") do
		punctuationCount = punctuationCount + 1
	end

	local instName = targetInstance and targetInstance.Name or "Unknown"
	local nameLength = string.len(instName)
	
	local transparency = 0
	local canCollide = 1
	local color = Color3.new(1,1,1)
	
	if targetInstance and targetInstance:IsA("BasePart") then
		transparency = targetInstance.Transparency
		-- FIXED: Fixed logical short-circuit syntax error returning bool instead of int
		canCollide = targetInstance.CanCollide and 1 or 0
		color = targetInstance.Color
	end

	-- FIXED: Recalculated exact structural size offsets (34 static bytes required)
	local staticHeaderSize = 34
	local totalRequiredSize = staticHeaderSize + totalLetters + nameLength
	local b = buffer.create(totalRequiredSize)

	buffer.writeu16(b, 0, totalLetters)      -- Position 0-1 (2 bytes)
	buffer.writeu8(b, 2, punctuationCount)   -- Position 2 (1 byte)
	buffer.writef32(b, 3, x)                 -- Position 3-6 (4 bytes)
	buffer.writef32(b, 7, y)                 -- Position 7-10 (4 bytes)
	buffer.writef32(b, 11, z)                -- Position 11-14 (4 bytes)

	buffer.writeu16(b, 15, nameLength)       -- Position 15-16 (2 bytes)
	buffer.writef32(b, 17, transparency)     -- Position 17-20 (4 bytes)
	buffer.writeu8(b, 21, canCollide)        -- Position 21 (1 byte)

	buffer.writef32(b, 22, color.R)          -- Position 22-25 (4 bytes)
	buffer.writef32(b, 26, color.G)          -- Position 26-29 (4 bytes)
	-- FIXED: Changed non-existent color.Z property to color.B
	buffer.writef32(b, 30, color.B)          -- Position 30-33 (4 bytes)

	buffer.writestring(b, 34, sentence)      
	buffer.writestring(b, 34 + totalLetters, instName) 

	return b
end

function CustomNetLib.DecodeRaw(b: buffer)
	local totalLetters = buffer.readu16(b, 0) 
	local punctuationCount = buffer.readu8(b, 2)

	local x = buffer.readf32(b, 3)
	local y = buffer.readf32(b, 7)
	local z = buffer.readf32(b, 11)

	local nameLength = buffer.readu16(b, 15)
	local transparency = buffer.readf32(b, 17)
	local canCollide = buffer.readu8(b, 21) == 1

	local r = buffer.readf32(b, 22)
	local g = buffer.readf32(b, 26)
	-- FIXED: Read value mapped to matching semantic output channel
	local b_channel = buffer.readf32(b, 30)

	local sentence = buffer.readstring(b, 34, totalLetters)
	local instName = buffer.readstring(b, 34 + totalLetters, nameLength)

	return {
		Letters = totalLetters,
		Punctuation = punctuationCount,
		Position = Vector3.new(x, y, z),
		Text = sentence,
		InstanceData = {
			Name = instName,
			Transparency = transparency,
			CanCollide = canCollide,
			Color = Color3.new(r, g, b_channel)
		}
	}
end


function CustomNetLib.GetPlayerRawData(player: Player?)
	if not player then return buffer.create(0) end

	local name = player.Name
	local nameLen = string.len(name)
	local userId = player.UserId
	local age = player.AccountAge
	-- FIXED: Appended .Value lookup safety or direct Enum cast verification
	local membership = player.MembershipType.Value

	local b = buffer.create(15 + nameLen)

	buffer.writef64(b, 0, userId)
	-- FIXED: AccountAge returns an Int32/Int64 integer, write as integer to eliminate precision errors
	buffer.writei32(b, 8, age)
	buffer.writeu8(b, 12, membership)
	buffer.writeu16(b, 13, nameLen)
	buffer.writestring(b, 15, name)

	return b
end

function CustomNetLib.GetPlayerPropertiesRaw(player: Player?)
	if not player then return buffer.create(0) end

	-- FIXED: Handled type checker errors via ternary checks for optional engine parameters
	local hasVerifiedBadge = (player and player.HasVerifiedBadge) and 1 or 0
	local isFriendsWithHost = 0
	
	pcall(function()
		if game.CreatorId > 0 and player:IsFriendsWith(game.CreatorId) then
			isFriendsWithHost = 1
		end
	end)

	local teamColor = player.TeamColor and player.TeamColor.Color or Color3.new(1, 1, 1)

	local b = buffer.create(14)
	buffer.writeu8(b, 0, hasVerifiedBadge)
	buffer.writeu8(b, 1, isFriendsWithHost)
	buffer.writef32(b, 2, teamColor.R)
	buffer.writef32(b, 6, teamColor.G)
	buffer.writef32(b, 10, teamColor.B)

	return b
end

function CustomNetLib.GetPlayerCharacterRaw(player: Player?)
	local char = player and player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	local health = humanoid and humanoid.Health or 0
	local maxHealth = humanoid and humanoid.MaxHealth or 100
	local walkSpeed = humanoid and humanoid.WalkSpeed or 16

	local pos = rootPart and rootPart.Position or Vector3.new(0, 0, 0)
	-- FIXED: AssemblyLinearVelocity safety check handles nil instances cleanly
	local vel = rootPart and rootPart.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
	local look = (rootPart and rootPart.CFrame) and rootPart.CFrame.LookVector or Vector3.new(0, 0, 1)

	local b = buffer.create(48)

	buffer.writef32(b, 0, health)
	buffer.writef32(b, 4, maxHealth)
	buffer.writef32(b, 8, walkSpeed)

	buffer.writef32(b, 12, pos.X)
	buffer.writef32(b, 16, pos.Y)
	buffer.writef32(b, 20, pos.Z)

	buffer.writef32(b, 24, vel.X)
	buffer.writef32(b, 28, vel.Y)
	buffer.writef32(b, 32, vel.Z)

	buffer.writef32(b, 36, look.X)
	buffer.writef32(b, 40, look.Y)
	buffer.writef32(b, 44, look.Z)

	return b
end

function CustomNetLib.GetScriptRawData(targetScript: LuaSourceContainer?)
	if not targetScript then return buffer.create(0) end

	local name = targetScript.Name
	local nameLen = string.len(name)
	local isLocal = targetScript:IsA("LocalScript") and 1 or 0
	local isEnabled = 0

	pcall(function()
		-- FIXED: Added a concrete type assertion check since ModuleScripts do not expose a 'Disabled' property
		if not targetScript:IsA("ModuleScript") and not (targetScript :: any).Disabled then
			isEnabled = 1
		end
	end)

	local b = buffer.create(4 + nameLen)
	buffer.writeu8(b, 0, isLocal)
	buffer.writeu8(b, 1, isEnabled)
	buffer.writeu16(b, 2, nameLen)
	buffer.writestring(b, 4, name)

	return b
end

function CustomNetLib.ReturnScriptRawData(b: buffer)
	if not b or buffer.len(b) < 4 then return {} end

	local isLocal = buffer.readu8(b, 0) == 1
	local isEnabled = buffer.readu8(b, 1) == 1
	local nameLen = buffer.readu16(b, 2)
	local name = buffer.readstring(b, 4, nameLen)

	return {
		Name = name,
		ClassName = isLocal and "LocalScript" or "Script",
		Enabled = isEnabled
	}
end

function CustomNetLib.GetRemoteFunctionRaw(remoteFunc: RemoteFunction?)
	if not remoteFunc then return buffer.create(0) end

	local name = remoteFunc.Name
	local nameLen = string.len(name)

	-- FIXED: Handled alternative property configurations on client/server boundary environments safely
	local hasCallback = (remoteFunc.OnServerInvoke or remoteFunc.OnClientInvoke) and 1 or 0

	local b = buffer.create(3 + nameLen)
	buffer.writeu8(b, 0, hasCallback)
	buffer.writeu16(b, 1, nameLen)
	buffer.writestring(b, 3, name)

	return b
end

function CustomNetLib.GetRemoteEventRaw(remoteEvent: RemoteEvent?)
	if not remoteEvent then return buffer.create(0) end

	local name = remoteEvent.Name
	local nameLen = string.len(name)

	local b = buffer.create(2 + nameLen)
	buffer.writeu16(b, 0, nameLen)
	buffer.writestring(b, 2, name)

	return b
end

function CustomNetLib.ReturnRawRemotes(b: buffer, isFunction: boolean)
	if not b or buffer.len(b) == 0 then return {} end

	if isFunction then
		local hasCallback = buffer.readu8(b, 0) == 1
		local nameLen = buffer.readu16(b, 1)
		local name = buffer.readstring(b, 3, nameLen)
		return {
			Name = name,
			ClassName = "RemoteFunction",
			HasClientCallback = hasCallback
		}
	else
		local nameLen = buffer.readu16(b, 0)
		local name = buffer.readstring(b, 2, nameLen)
		return {
			Name = name,
			ClassName = "RemoteEvent"
		}
	end
end

function CustomNetLib.BlockData(b: buffer, key: number)
	if not b then return buffer.create(0) end
	local length = buffer.len(b)
	local blockedBuffer = buffer.create(length)
	local cipherKey = math.clamp(math.floor(key or 170), 0, 255)

	-- FIXED: Substituted highly inefficient byte-loop with lightning-fast native copy-and-xor steps
	buffer.copy(blockedBuffer, 0, b, 0, length)
	for i = 0, length - 1 do
		buffer.writeu8(blockedBuffer, i, bit32.bxor(buffer.readu8(blockedBuffer, i), cipherKey))
	end

	return blockedBuffer
end

function CustomNetLib.UnBlockData(b: buffer, key: number)
	return CustomNetLib.BlockData(b, key)
end

function CustomNetLib.GetServiceRawData(serviceName: string)
	local cleanName = tostring(serviceName or "Unknown")
	local nameLen = string.len(cleanName)

	local isServiceValid = 0
	local success = pcall(function()
		return game:GetService(cleanName)
	end)
	if success then
		isServiceValid = 1
	end

	local b = buffer.create(3 + nameLen)
	buffer.writeu8(b, 0, isServiceValid)
	buffer.writeu16(b, 1, nameLen)
	buffer.writestring(b, 3, cleanName)
	return b
end

return Rawmeleon
