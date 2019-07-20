--// Initialization

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local IsClient = RunService:IsClient()

local Module = {}
local CollectionMetatable = {}

--// Variables

local DebugPrint = false

local RetrievalSets = {
	["RemoteEvent"] = "RemoteEvent",
	["RemoteFunction"] = "RemoteFunction",
	["BindableEvent"] = "BindableEvent",
	["BindableFunction"] = "BindableFunction",
}

--// Functions

local function printd(...)
	if DebugPrint then
		return print(...)
	end
end

local function Retrieve(InstanceName, InstanceClass, InstanceParent)
	--/ Finds an Instance by name and creates a new one if it doesen't exist
	
	local SearchInstance = nil
	local InstanceCreated = false
	
	if InstanceParent:FindFirstChild(InstanceName) then
		SearchInstance = InstanceParent[InstanceName]
	else
		InstanceCreated = true
		SearchInstance = Instance.new(InstanceClass)
		SearchInstance.Name = InstanceName
		SearchInstance.Parent = InstanceParent
	end
	
	return SearchInstance, InstanceCreated
end

local function BindToTag(Tag, Callback)
	CollectionService:GetInstanceAddedSignal(Tag):Connect(Callback)
	
	for _, TaggedItem in next, CollectionService:GetTagged(Tag) do
		Callback(TaggedItem)
	end
end

function CollectionMetatable:__newindex(Index, Value)
	rawset(self, Index, Value)
	if Index:sub(1, 1) == "_" then return end
	
	for Thread, ExpectedIndex in next, self._WaitCache do
		if Index == ExpectedIndex then
			coroutine.resume(Thread, require(Value))
		end
	end
end

do Module.Libraries = setmetatable({}, CollectionMetatable)
	Module.Libraries._Folder = Retrieve("Libraries", "Folder", ReplicatedStorage)
	Module.Libraries._WaitCache = {}
	
	BindToTag("oLibrary", function(Object)
		Module.Libraries[Object.Name] = Object
		
		if CollectionService:HasTag(Object, "ForceReplicate") then
			Object.Parent = Module.Libraries._Folder
		end
	end)
	
	function Module:LoadLibrary(Index)
		if self.Libraries[Index] then
			return require(self.Libraries[Index])
		else
			assert(IsClient, "The library \"" .. Index .. "\" does not exist!")
			printd("The client is yielding for the library \"" .. Index .. "\".")
			
			self.Libraries._WaitCache[coroutine.running()] = Index
			return coroutine.yield()
		end
	end
end

for SetName, SetClass in next, RetrievalSets do
	local SetFolder = Retrieve(SetName, "Folder", ReplicatedStorage)
	
	Module["GetLocal" .. SetName] = function(self, ItemName)
		return Retrieve(ItemName, SetClass, SetFolder)
	end
	
	Module["WaitFor" .. SetName] = function(self, ItemName)
		return SetFolder:WaitForChild(ItemName, math.huge)
	end
	
	Module["Get" .. SetName] = function(self, ItemName)
		local Item = SetFolder:FindFirstChild(ItemName)
		if Item then return Item end
		
		if IsClient then
			return SetFolder:WaitForChild(ItemName)
		else
			return self["GetLocal" .. SetName](self, ItemName)
		end
	end
end

if not IsClient then
	BindToTag("StarterCharacterScripts", function(Object)
		Object.Parent = StarterPlayer.StarterCharacterScripts
		CollectionService:RemoveTag(Object, "StarterCharacterScripts")
	end)
	
	BindToTag("StarterPlayerScripts", function(Object)
		Object.Parent = StarterPlayer.StarterPlayerScripts
		CollectionService:RemoveTag(Object, "StarterPlayerScripts")
	end)
end

return Module
