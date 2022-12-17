--!nonstrict
--// Initialization

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

--[=[
	@class Overture
]=]
local Overture = {}
local LibraryThreadCache = {}
local Libraries: {[string]: ModuleScript} = {}

--// Functions

--[=[
	@within Overture
	
	@ignore
	@return Instance
]=]
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

--[=[
	@within Overture
	@ignore
	
	@param Tag -- The CollectionService tag
	@param Function -- The function to call
	@return any?
]=]
local function BindToTag(Tag: string, Function: (Instance) -> ()): RBXScriptConnection
	for _, Value in next, CollectionService:GetTagged(Tag) do
		task.spawn(Function, Value)
	end
	
	return CollectionService:GetInstanceAddedSignal(Tag):Connect(Function)
end

--[=[
	Finds a ModuleScript with the CollectionService `oLibrary` tag,
	and returns the value that was returned by the given ModuleScript,
	running it if it has not been run yet.
	
	A tagged ModuleScript will only be required when LoadLibrary is called on it.
	
	:::caution
	This method will yield when called on the client, but only if the library has not been replicated and indexed yet.
	:::
	
	:::danger
	If the library cannot be found when called on the server, this method will error.
	:::
	
	@yields
	@param Index -- The name of the ModuleScript
	@return any?
]=]
function Overture:LoadLibrary(Index: string)
	if Libraries[Index] then
		return require(Libraries[Index])
	else
		assert(not RunService:IsServer(), "The library \"" .. Index .. "\" does not exist!")
		
		table.insert(LibraryThreadCache, {Thread = coroutine.running(), RequestedIndex = Index, RequestedAt = time()})
		return require(coroutine.yield())
	end
end

--[=[
	See [Overture:LoadLibrary] for the arguments to this method.
	This function will return nil when called on the server, regradless if the ModuleScript exists.
	
	Sugar for:
	```lua
		if RunService:IsClient() then
			Overture:LoadLibrary(...)
		end
	```	
	
	@yields
	@client
	@param ... any
	@return any?
]=]
function Overture:LoadLibraryOnClient(...)
	if RunService:IsClient() then
		return self:LoadLibrary(...)
	end
end

--[=[
	See [Overture:LoadLibrary] for the arguments to this method.
	This function will return nil when called on the client, regradless if the ModuleScript exists.
	
	Sugar for:
	```lua
		if RunService:IsServer() then
			Overture:LoadLibrary(...)
		end
	```	
	
	@server
	@param ... any
	@return any?
]=]
function Overture:LoadLibraryOnServer(...)
	if RunService:IsServer() then
		return self:LoadLibrary(...)
	end
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, a new one will be created.
	
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@return InstanceClass
]=]
function Overture:GetLocal(InstanceClass: string, InstanceName: string): Instance
	return Retrieve(InstanceName, InstanceClass, (Retrieve("Local" .. InstanceClass, "Folder", script)))
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, the method will yield until one exists.
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@return InstanceClass
]=]
function Overture:WaitFor(InstanceClass: string, InstanceName: string): Instance
	return Retrieve(InstanceClass, "Folder", script, RunService:IsClient()):WaitForChild(InstanceName, math.huge)
end

--[=[
	Returns an instance of the specified class.
	
	If an instance of the same class and name already exists, it will be returned.
	Otherwise, when called from the client, the method will yield until one exists; if called from the server, a new one will be created.
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@return InstanceClass
]=]
function Overture:Get(InstanceClass: string, InstanceName: string): Instance
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

task.spawn(BindToTag, "oLibrary", function(Object)
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

return Overture
