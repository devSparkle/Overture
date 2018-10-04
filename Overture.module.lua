--// Initialization

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local IsClient = RunService:IsClient()

local Module = {}
local CollectionMetatable = {}

--// Variables

local DebugPrint = false
local RetrievalSets = {
	"RemoteEvents" = "RemoteEvent",
	"RemoteFunctions" = "RemoteFunction"
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

do Module.Classes = setmetatable({}, CollectionMetatable)
	Module.Classes._WaitCache = {}

	BindToTag("oClass", function(Object)
		Module.Classes[Object.Name] = Object
	end)

	function Module:GetClass(Index)
		if self.Classes[Index] then
			return require(self.Classes[Index])
		else
			assert(IsClient, "The class \"" .. Index .. "\" does not exist!")
			printd("The client is yielding for the class \"" .. Index .. "\".")

			self.Classes._WaitCache[coroutine.status()] = Index
			return coroutine.yield()
		end
	end
end

do Module.Libraries = setmetatable({}, CollectionMetatable)
	Module.Libraries._WaitCache = {}

	BindToTag("oLibrary", function(Object)
		Module.Libraries[Object.Name] = Object
	end)

	function Module:GetLibrary(Index)
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

	function Module["GetLocal" .. SetName](self, ItemName)
		return Retrieve(ItemName, SetClass, SetFolder)
	end

	function Module["WaitFor" .. SetName](self, ItemName)
		return SetFolder:WaitForChild(ItemName)
	end

	function Module["Get" .. SetName](self, ItemName)
		local Item = SetFolder:FindFirstChild(ItemName)
		if Item then return Item end
		
		if IsClient then
			return self["WaitFor" .. SetName](self, ItemName)
		else
			return self["GetLocal" .. SetName](self, ItemName)
		end
	end
end

return Module