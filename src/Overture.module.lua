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

--// Triggers

return Module
