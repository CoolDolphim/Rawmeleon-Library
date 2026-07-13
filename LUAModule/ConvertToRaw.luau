local RawmeleonLibrary = {}

function CustomNetLib.ConvertToRaw(sentence: string, x: number, y: number, z: number, targetInstance: Instance)
	local totalLetters = string.len(sentence)

	local punctuationCount = 0
	for _ in string.gmatch(sentence, "[%p]") do
		punctuationCount = punctuationCount + 1
	end

	local instName = targetInstance and targetInstance.Name or "Unknown"
	local nameLength = string.len(instName)
	local transparency = (targetInstance and targetInstance:IsA("BasePart")) and targetInstance.Transparency or 0
	local canCollide = (targetInstance and targetInstance:IsA("BasePart")) and (targetInstance.CanCollide and 1 or 0) or 1

	local color = (targetInstance and targetInstance:IsA("BasePart")) and targetInstance.Color or Color3.new(1,1,1)

	local staticHeaderSize = 15 + 2 + 4 + 1 + 12
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
	buffer.writef32(b, 30, color.Z)          -- Position 30-33 (4 bytes)

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
	local canCollide = buffer.readu8(b, 21) == 1 and true or false

	local r = buffer.readf32(b, 22)
	local g = buffer.readf32(b, 26)
	local colorZ = buffer.readf32(b, 30)

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
			Color = Color3.new(r, g, colorZ)
		}
	}
end


function CustomNetLib.GetPlayerRawData(player: Player)
	if not player then return buffer.create(0) end

	local name = player.Name
	local nameLen = string.len(name)
	local userId = player.UserId
	local age = player.AccountAge
	local membership = player.MembershipType.Value

	local b = buffer.create(15 + nameLen)

	buffer.writef64(b, 0, userId)
	buffer.writef32(b, 8, age)
	buffer.writeu8(b, 12, membership)
	buffer.writeu16(b, 13, nameLen)
	buffer.writestring(b, 15, name)

	return b
end

function CustomNetLib.GetPlayerPropertiesRaw(player: Player)
	if not player then return buffer.create(0) end

	local hasVerifiedBadge = player.HasVerifiedBadge and 1 or 0
	local isFriendsWithHost = 0
	pcall(function()
		-- Some executors block async calls inside packers; wrap in pcall
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

function CustomNetLib.GetPlayerCharacterRaw(player: Player)
	local char = player and player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	local health = humanoid and humanoid.Health or 0
	local maxHealth = humanoid and humanoid.MaxHealth or 100
	local walkSpeed = humanoid and humanoid.WalkSpeed or 16

	local pos = rootPart and rootPart.Position or Vector3.new(0, 0, 0)
	local vel = rootPart and rootPart.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
	local look = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, 1)

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

function CustomNetLib.GetScriptRawData(targetScript: LuaSourceContainer)
	if not targetScript then return buffer.create(0) end

	local name = targetScript.Name
	local nameLen = string.len(name)
	local isLocal = targetScript:IsA("LocalScript") and 1 or 0
	local isEnabled = 0

	
	pcall(function()
		if not targetScript:IsA("ModuleScript") and not targetScript.Disabled then
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
		ClassName = isLocal and "LocalScript" or "ModuleScript/Script",
		Enabled = isEnabled
	}
end

function CustomNetLib.GetRemoteFunctionRaw(remoteFunc: RemoteFunction)
	if not remoteFunc then return buffer.create(0) end

	local name = remoteFunc.Name
	local nameLen = string.len(name)

	local hasCallback = remoteFunc.OnClientInvoke and 1 or 0

	local b = buffer.create(3 + nameLen)
	buffer.writeu8(b, 0, hasCallback)
	buffer.writeu16(b, 1, nameLen)
	buffer.writestring(b, 3, name)

	return b
end

function CustomNetLib.GetRemoteEventRaw(remoteEvent: RemoteEvent)
	if not remoteEvent then return buffer.create(0) end

	local name = remoteEvent.Name
	local nameLen = string.len(name)

	-- Layout: 2 bytes (NameLen) + Name String
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


	for i = 0, length - 1 do
		local originalByte = buffer.readu8(b, i)

		local maskedByte = bit32.bxor(originalByte, cipherKey)
		buffer.writeu8(blockedBuffer, i, maskedByte)
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


function CustomNetLib.PackDynamic(dataLayout: table, ...)
	local args = {...}
	local totalRequiredSize = 0
	local stringLengths = {} 


	for index, expectedType in ipairs(dataLayout) do
		local val = args[index]
		if expectedType == "u8" then
			totalRequiredSize = totalRequiredSize + 1
		elseif expectedType == "u16" then
			totalRequiredSize = totalRequiredSize + 2
		elseif expectedType == "f32" then
			totalRequiredSize = totalRequiredSize + 4
		elseif expectedType == "f64" then
			totalRequiredSize = totalRequiredSize + 8
		elseif expectedType == "string" then
			local strVal = tostring(val or "")
			local strLen = string.len(strVal)
			stringLengths[index] = strLen

			totalRequiredSize = totalRequiredSize + 2 + strLen 
		end
	end

	local b = buffer.create(totalRequiredSize)
	local cursor = 0


	for index, expectedType in ipairs(dataLayout) do
		local val = args[index]
		if expectedType == "u8" then
			buffer.writeu8(b, cursor, math.clamp(tonumber(val) or 0, 0, 255))
			cursor = cursor + 1
		elseif expectedType == "u16" then
			buffer.writeu16(b, cursor, math.clamp(tonumber(val) or 0, 0, 65535))
			cursor = cursor + 2
		elseif expectedType == "f32" then
			buffer.writef32(b, cursor, tonumber(val) or 0)
			cursor = cursor + 4
		elseif expectedType == "f64" then
			buffer.writef64(b, cursor, tonumber(val) or 0)
			cursor = cursor + 8
		elseif expectedType == "string" then
			local strVal = tostring(val or "")
			local strLen = stringLengths[index] or string.len(strVal)

			buffer.writeu16(b, cursor, strLen) -- Frame length boundary marker
			buffer.writestring(b, cursor + 2, strVal)
			cursor = cursor + 2 + strLen
		end
	end

	return b
end

function CustomNetLib.GetTableRawData(targetTable: table)
	if type(targetTable) ~= "table" then return buffer.create(0) end


	local dynamicLayout = {}
	local elementCount = #targetTable

	for i = 1, elementCount do
		local element = targetTable[i]
		local elType = type(element)

		if elType == "number" then

			if element % 1 == 0 and element >= 0 and element <= 255 then
				table.insert(dynamicLayout, "u8")
			else
				table.insert(dynamicLayout, "f32") 
			end
		elseif elType == "string" then
			table.insert(dynamicLayout, "string")
		elseif elType == "boolean" then
			table.insert(dynamicLayout, "u8")
		else
			table.insert(dynamicLayout, "string")
		end
	end

	return CustomNetLib.PackDynamic(dynamicLayout, unpack(targetTable))
end


function CustomNetLib.ReturnRawData(b: buffer)
	local bytes = {}
	for i = 0, buffer.len(b) - 1 do
		table.insert(bytes, string.format("%02X", buffer.readu8(b, i)))
	end
	return table.concat(bytes, " ")
end

return RawmeleonLibrary
