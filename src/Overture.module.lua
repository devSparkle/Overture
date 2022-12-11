--!nonstrict
--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts"):: Folder

local Module = {}
local LibraryThreadCache = {}
local Libraries: {[string]: ModuleScript} = {}

--// Functions

local function Retrieve(InstanceName: string, InstanceClass: string, InstanceParent: Instance, ForceWait: boolean?): Instance
	if ForceWait then
		return InstanceParent:WaitForChild(InstanceName)
	end
	
	local SearchInstance = InstanceParent:FindFirstChild(InstanceName)
	
	if not SearchInstance then
		SearchInstance = Instance.new(InstanceClass)
		SearchInstance.Name = InstanceName
		SearchInstance.Parent = InstanceParent
	end
	
	return SearchInstance
end

function Module._BindFunction(Function: (Instance) -> (), Event: RBXScriptSignal, Existing: {Instance}): RBXScriptConnection
	if Existing then
		for _, Value in next, Existing do
			task.spawn(Function, Value)
		end
	end
	
	return Event:Connect(Function)
end

function Module._BindToTag(Tag: string, Function: (Instance) -> ())
	return Module._BindFunction(Function, CollectionService:GetInstanceAddedSignal(Tag), CollectionService:GetTagged(Tag))
end

function Module:LoadLibrary(Index: string)
	if Libraries[Index] then
		return require(Libraries[Index])
	else
		assert(not RunService:IsServer(), "The library \"" .. Index .. "\" does not exist!")
		
		table.insert(LibraryThreadCache, {Thread = coroutine.running(), RequestedIndex = Index, RequestedAt = time()})
		return require(coroutine.yield())
	end
end

function Module:LoadLibraryOnClient(...)
	if RunService:IsClient() then
		return self:LoadLibrary(...)
	end
end

function Module:LoadLibraryOnServer(...)
	if RunService:IsServer() then
		return self:LoadLibrary(...)
	end
end

function Module:GetLocal(InstanceClass: string, InstanceName: string): Instance
	return Retrieve(InstanceName, InstanceClass, (Retrieve("Local" .. InstanceClass, "Folder", script)))
end

function Module:WaitFor(InstanceClass: string, InstanceName: string): Instance
	return Retrieve(InstanceClass, "Folder", script, RunService:IsClient()):WaitForChild(InstanceName, math.huge)
end

function Module:Get(InstanceClass: string, InstanceName: string): Instance
	local SetFolder = Retrieve(InstanceClass, "Folder", script, RunService:IsClient())
	local Item = SetFolder:FindFirstChild(InstanceName)
	
	if Item then
		return Item
	elseif RunService:IsClient() then
		return SetFolder:WaitForChild(InstanceName)
	else
		return Retrieve(InstanceName, InstanceClass, SetFolder)
	end
end

Module._BindToTag("oLibrary", function(Object)
	Libraries[Object.Name] = Object
	
	for _, Cached in next, LibraryThreadCache do
		if Object.Name == Cached.RequestedIndex then
			task.defer(Cached.Thread, Object)
			task.delay(1, function()
				table.remove(LibraryThreadCache, table.find(LibraryThreadCache, Cached))
			end)
		end
	end
end)

task.spawn(function()
	while script:GetAttribute("Debug") do
		task.wait(1)
		
		for _, Cached in next, LibraryThreadCache do
			if Cached.WarningEmitted then continue end
			if (time() - Cached.RequestedAt) > 5 then
				warn(string.format([[Infinite yield possible on Overture:LoadLibrary("%s").]], Cached.RequestedIndex))
				Cached.WarningEmitted = true
			end
		end
	end
end)

local function Initialize()
	if RunService:IsServer() then
		if script:GetAttribute("ServerHandled") then
			return
		end
		
		script:SetAttribute("ServerHandled", true)
		
		local oStarterPlayerScripts = Retrieve("StarterPlayerScripts", "Folder", script)
		local oStarterCharacterScripts = Retrieve("StarterCharacterScripts", "Folder", script)
		local function Reparent(Child, NewParent)
			if Child:IsA("LocalScript") and not Child.Disabled then
				Child:SetAttribute("EnableOnceReady", true)
				Child.Disabled = true
			end
			
			Child.Parent = Retrieve(NewParent, "Folder", script)
		end
		
		Module._BindToTag("oHandled", function(LuaSourceContainer: Instance)
			local RunsOn = LuaSourceContainer:GetAttribute("RunsOn") or "Empty"
			
			if LuaSourceContainer:IsA("LocalScript") then
				if RunsOn == "Player" then
					task.defer(Reparent, LuaSourceContainer, "StarterPlayerScripts")
				elseif RunsOn == "Character" then
					task.defer(Reparent, LuaSourceContainer, "StarterCharacterScripts")
				else
					warn(string.format([[Unknown RunsOn type "%s" on %s]], RunsOn, LuaSourceContainer:GetFullName()))
				end
			elseif LuaSourceContainer:IsA("Script") then
				if RunsOn == "Player" then
					warn(string.format([[Invalid RunsOn type "%s" on %s]], RunsOn, LuaSourceContainer:GetFullName()))
				elseif RunsOn == "Character" then
					LuaSourceContainer.Parent = StarterCharacterScripts
					
					for _, Player in next, PlayerService:GetPlayers() do
						if Player.Character then
							LuaSourceContainer:Clone().Parent = Player.Character
						end
					end
				else
					warn(string.format([[Unknown RunsOn type "%s" on %s]], RunsOn, LuaSourceContainer:GetFullName()))
				end
			elseif LuaSourceContainer:IsA("ModuleScript") then
				warn(string.format([[Invalid tag "oHandled" applied to %s]], LuaSourceContainer:GetFullName()))
			end
		end)
		
		Module._BindToTag("oLibrary", function(LuaSourceContainer: Instance)
			if LuaSourceContainer:GetAttribute("ForceReplicate") then
				LuaSourceContainer.Parent = Retrieve("Libraries", "Folder", script)
			end
		end)
		
		Module._BindToTag("ForceReplicate", function(LuaSourceContainer: Instance)
			LuaSourceContainer.Parent = Retrieve("Libraries", "Folder", script)
		end)
		
		Module._BindToTag("StarterPlayerScripts", function(LuaSourceContainer: Instance)
			if LuaSourceContainer:IsA("LocalScript") then
				task.defer(Reparent, LuaSourceContainer, "StarterPlayerScripts")
			else
				warn(string.format([[Invalid tag "StarterPlayerScripts" applied to %s]], LuaSourceContainer:GetFullName()))
			end
		end)
		
		Module._BindToTag("StarterCharacterScripts", function(LuaSourceContainer: Instance)
			if LuaSourceContainer:IsA("LocalScript") then
				task.defer(Reparent, LuaSourceContainer, "StarterCharacterScripts")
			elseif LuaSourceContainer:IsA("Script") then
				LuaSourceContainer.Parent = StarterCharacterScripts
				
				for _, Player in next, PlayerService:GetPlayers() do
					if Player.Character then
						LuaSourceContainer:Clone().Parent = Player.Character
					end
				end
			else
				warn(string.format([[Invalid tag "StarterCharacterScripts" applied to %s]], LuaSourceContainer:GetFullName()))
			end
		end)
	elseif RunService:IsClient() then
		if script:GetAttribute("ClientHandled") then
			return
		end
		
		script:SetAttribute("ClientHandled", true)
		
		local Player = PlayerService.LocalPlayer
		local PlayerScripts = Player:WaitForChild("PlayerScripts")
		local oStarterPlayerScripts = script:WaitForChild("StarterPlayerScripts")
		local oStarterCharacterScripts = script:WaitForChild("StarterCharacterScripts")
		local function Reparent(Child, NewParent)
			Child.Parent = NewParent
			
			if Child:IsA("LocalScript") and Child:GetAttribute("EnableOnceReady") then
				Child.Disabled = false
			end
		end
		
		if script:FindFirstAncestorWhichIsA("PlayerGui") then
			task.defer(Reparent, script:Clone(), PlayerScripts)
			task.wait()
			
			script.Disabled = true
			script:Destroy()
			
			return
		end
		
		Module._BindFunction(function(Child: Instance)
			task.defer(Reparent, Child, PlayerScripts)
		end, oStarterPlayerScripts.ChildAdded, oStarterPlayerScripts:GetChildren())
		
		Module._BindFunction(function(Child: Instance)
			if Player.Character then
				task.defer(Reparent, Child:Clone(), Player.Character)
			end
		end, oStarterCharacterScripts.ChildAdded, oStarterCharacterScripts:GetChildren())
		
		Module._BindFunction(function(Character: Instance)
			for _, Child in next, oStarterCharacterScripts:GetChildren() do
				task.spawn(Reparent, Child:Clone(), Character)
			end
		end, Player.CharacterAdded, {Player.Character})
	end
end

--// Triggers

task.defer(Initialize)

return Module
