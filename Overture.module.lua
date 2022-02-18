--!nonstrict
--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

local OvertureYield = script:WaitForChild("OvertureYield")
local oStarterPlayerScripts = script:WaitForChild("StarterPlayerScripts"):: Folder
local oStarterCharacterScripts = script:WaitForChild("StarterCharacterScripts"):: Folder
local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts"):: Folder

local Module = {}
local LibraryThreadCache: {[thread]: string} = {}
local Libraries: {[string]: ModuleScript} = {}

--// Functions

local function Reparent(Child, NewParent)
	if Child:IsA("LocalScript") and not Child.Disabled then
		Child:SetAttribute("EnableOnceReady", true)
		Child.Disabled = true
	end

	Child.Parent = NewParent
end

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

function Module._CountLibrariesIn(Parent: Instance, CountLocally: boolean?): number
	local StoredCount = Parent:GetAttribute("LibrariesIn")

	if StoredCount then
		return StoredCount
	end

	if RunService:IsClient() and not CountLocally then
		return OvertureYield:InvokeServer(Parent)
	else
		local Count = 0

		for _, Descendant in next, Parent:GetDescendants() do
			if Descendant:IsA("ModuleScript") then
				Count += 1
			end
		end

		if RunService:IsServer() then
			Parent:SetAttribute("LibrariesIn", Count)
		end

		return Count
	end
end

function Module:_LoadServer()
	if script:GetAttribute("ServerLoaded") then
		return warn("Attempted to load Overture multiple times.")
	else
		script:SetAttribute("ServerLoaded", true)
	end

	function OvertureYield.OnServerInvoke(_, Parent: Instance)
		return Module._CountLibrariesIn(Parent)
	end

	self._BindToTag("oHandled", function(LuaSourceContainer: LuaSourceContainer)
		local RunsOn = LuaSourceContainer:GetAttribute("RunsOn") or "Empty"

		if LuaSourceContainer:IsA("LocalScript") then
			if RunsOn == "Player" then
				task.defer(Reparent, LuaSourceContainer, oStarterPlayerScripts)
			elseif RunsOn == "Character" then
				task.defer(Reparent, LuaSourceContainer, oStarterCharacterScripts)
			else
				warn(string.format([[Unknown RunsOn type "%s" on %s]], RunsOn, LuaSourceContainer:GetFullName()))
			end
		elseif LuaSourceContainer:IsA("Script") then
			if RunsOn == "Player" then
				warn(string.format([[Invalid RunsOn type "%s" on %s]], RunsOn, LuaSourceContainer:GetFullName()))
			elseif RunsOn == "Character" then
				task.defer(Reparent, LuaSourceContainer, StarterCharacterScripts)

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

	self._BindToTag("oLibrary", function(LuaSourceContainer: LuaSourceContainer)
		if LuaSourceContainer:GetAttribute("ForceReplicate") then
			LuaSourceContainer.Parent = Retrieve("Libraries", "Folder", script)
		end
	end)

	self._BindToTag("ForceReplicate", function(LuaSourceContainer: LuaSourceContainer)
		LuaSourceContainer.Parent = Retrieve("Libraries", "Folder", script)
	end)

	self._BindToTag("StarterPlayerScripts", function(LuaSourceContainer: LuaSourceContainer)
		if LuaSourceContainer:IsA("LocalScript") then
			task.defer(Reparent, LuaSourceContainer, oStarterPlayerScripts)
		else
			warn(string.format([[Invalid tag "StarterPlayerScripts" applied to %s]], LuaSourceContainer:GetFullName()))
		end
	end)

	self._BindToTag("StarterCharacterScripts", function(LuaSourceContainer: LuaSourceContainer)
		if LuaSourceContainer:IsA("LocalScript") then
			task.defer(Reparent, LuaSourceContainer, oStarterCharacterScripts)
		elseif LuaSourceContainer:IsA("Script") then
			task.defer(Reparent, LuaSourceContainer, StarterCharacterScripts)

			for _, Player in next, PlayerService:GetPlayers() do
				if Player.Character then
					LuaSourceContainer:Clone().Parent = Player.Character
				end
			end
		else
			warn(string.format([[Invalid tag "StarterCharacterScripts" applied to %s]], LuaSourceContainer:GetFullName()))
		end
	end)
end

function Module:YieldForLibrariesIn(Parent: Instance)
	local ServerCount = OvertureYield:InvokeServer(Parent)
	local ClientCount do
		repeat
			if ClientCount ~= nil then
				Parent.DescendantAdded:Wait()
			end

			ClientCount = self._CountLibrariesIn(Parent, true)
		until ClientCount >= ServerCount
	end
end

function Module:LoadLibrary(Index: string)
	if Libraries[Index] then
		return require(Libraries[Index])
	else
		assert(not RunService:IsServer(), "The library \"" .. Index .. "\" does not exist!")

		LibraryThreadCache[coroutine.running()] = Index
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

	for Thread, WantedName in next, LibraryThreadCache do
		if Object.Name == WantedName then
			LibraryThreadCache[Thread] = nil
			task.spawn(Thread, Object)
		end
	end
end)

return Module
