--!nonstrict
--// Initialization

const RunService = game:GetService("RunService")
const CollectionService = game:GetService("CollectionService")

--[=[
	@class Overture
	
	The core of Overture revolves around the management of libraries.
	
	In Overture, a library is any ModuleScript which is tagged with the CollectionService `oLibrary` tag.
	Overture itself will make no effort to replicate ModuleScripts, so remember to ensure that they are
	accessible to both the server and the client; when this behavior is desired.
	
	:::info
	Remember, all library names in Overture must be unique!
	:::
]=]
const Overture = {}

const LibrarySignalCache: {[string]: {BindableEvent}} = {}
const Libraries: {[string]: ModuleScript} = {}

const IsClient = RunService:IsClient()
local IsDebug = (script:GetAttribute("Debug") == true)

--// Variables

const YIELD_WARN_DELAY = 5

--// Functions

--[=[
	@within Overture
	@ignore
]=]
const function Retrieve(
	InstanceName: string,
	InstanceClass: string,
	InstanceParent: Instance,
	ForceWait: boolean?
): Instance
	if ForceWait and RunService:IsRunning() then
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
]=]
const function BindToTag(Tag: string, Function: (Instance) -> ()): RBXScriptConnection
	for _, Value in CollectionService:GetTagged(Tag) do
		task.spawn(Function, Value)
	end
	
	return CollectionService:GetInstanceAddedSignal(Tag):Connect(Function)
end

--[=[
	@within Overture
	@ignore
	
	@param Module -- The ModuleScript to require
	@param NamedImports -- When provided, returns the named variables instead of the entire ModuleScript
]=]
const function RequireModule(Module: ModuleScript, NamedImports: { string }?): any?
	if NamedImports then
		const Exports = require(Module)
		const Imports = {}
		
		for ImportIndex, ImportName in ipairs(NamedImports) do
			Imports[ImportIndex] = Exports[ImportName]
		end
		
		return unpack(Imports)
	else
		return require(Module)
	end
end

--[=[
	Finds a ModuleScript with the CollectionService `oLibrary` tag,
	and returns the value that was returned by the given ModuleScript,
	running it if it has not been run yet.
	
	A tagged ModuleScript will only be required when LoadLibrary is called on it.
	
	The behaviour of this function differs between the server and the client.
	In the server, if no ModuleScript is found with the name provided in `Index`,
	an error is thrown. This is because **modules are expected to be tagged
	before runtime**. In the client, if no ModuleScript is found in the initial
	search, the function will yield until a ModuleScript with a matching name is
	tagged or replicated.
	
	This function makes use of coroutines and Roblox's task library to yield its
	own thread. This eliminates the processing implications of periodically
	polling every time a module is not yet present in the client, and speeds up
	the process of requiring a library once it is replicated.
	
	:::caution
	This method will yield when called on the client, but only if the library has
	not been replicated and indexed yet.
	:::
	
	:::danger
	If the library cannot be found when called on the server, this method will error.
	:::
	
	@tag Library Management
	
	@yields
	@param Index -- The name of the ModuleScript
	@param NamedImports -- When provided, returns the named variables instead of the entire ModuleScript
	
	@error The library `Index` does not exist! -- Thrown on the server, if no ModuleScript exists with the given name.
]=]
function Overture:LoadLibrary(Index: string, NamedImports: {string}?): any?
	if Libraries[Index] then
		return RequireModule(Libraries[Index], NamedImports)
	else
		assert(IsClient, `The library "{Index}" does not exist!`)
		
		LibrarySignalCache[Index] = (LibrarySignalCache[Index] or {})
		const Signal = Instance.new("BindableEvent")
		table.insert(LibrarySignalCache[Index], Signal)
		
		const CallStack = `{debug.traceback("Stack Begin")}Stack End`
		local DebugThread: thread? do
			if IsDebug then
				DebugThread = task.delay(YIELD_WARN_DELAY, function()
					warn(`Infinite yield possible on 'Overture:LoadLibrary("{Index}")'`)
					
					for _, line in CallStack:split("\n") do
						print(`{line}`)
					end
				end)
			end
		end
		
		local Object = Signal.Event:Wait()
		
		if DebugThread then
			pcall(task.cancel, DebugThread)
		end
		
		return RequireModule(Object, NamedImports)
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
	
	@tag Library Management
	
	@yields
	@client
	@param ... any
]=]
function Overture:LoadLibraryOnClient(...): any?
	return if IsClient then self:LoadLibrary(...) else nil
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
	
	@tag Library Management
	
	@server
	@param ... any
]=]
function Overture:LoadLibraryOnServer(...): any?
	return if IsClient then nil else self:LoadLibrary(...)
end

--[=[
	Returns an instance of the specified class.
	
	If an instance of the same class and name already exists, it will be returned.
	Otherwise, when called from the client, the method will yield until one exists; if called from the server, a new one will be created.
	
	@tag Instance Retrieval
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:Get(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	const SetFolder = (Parent or Retrieve(InstanceClass, "Folder", script, IsClient))
	const Item = SetFolder:FindFirstChild(InstanceName)
	
	if Item then
		return Item
	elseif not IsClient or not RunService:IsRunning() then
		return Retrieve(InstanceName, InstanceClass, SetFolder)
	else
		return SetFolder:WaitForChild(InstanceName)
	end
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, a new one will be created.
	
	This function can be particularly useful to create and manage BindableEvent and BindableFunction instances for client-side communication.
	
	:::info
	Note that instances created by this function in the client will not replicate to the server, or other clients.
	:::
	
	@tag Instance Retrieval
	
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:GetLocal(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	return Retrieve(InstanceName, InstanceClass, (Parent or Retrieve("Local" .. InstanceClass, "Folder", script)))
end

--[=[
	Returns an instance of the specified class.
	If an instance of the same class and name already exists, it will be returned. Otherwise, the method will yield until one exists.
	
	@tag Instance Retrieval
	
	@yields
	@param InstanceClass -- The class of the Instance
	@param InstanceName -- The name of the Instance
	@param Parent -- An optional override parent Instance. Useful for retrieving dependencies.
]=]
function Overture:WaitFor(InstanceClass: string, InstanceName: string, Parent: Instance?): Instance
	return (Parent or Retrieve(InstanceClass, "Folder", script, IsClient) :: any) --// silence linter
		:WaitForChild(InstanceName, if IsClient then math.huge else nil) :: Instance
end

task.spawn(BindToTag, "oLibrary", function(Object)
	Libraries[Object.Name] = Object
	
	if not LibrarySignalCache[Object.Name] then
		return
	end
	
	for _, Signal in LibrarySignalCache[Object.Name] do
		Signal:Fire(Object)
	end
	
	LibrarySignalCache[Object.Name] = nil
end)

--// Triggers

script:GetAttributeChangedSignal("Debug"):Connect(function()
	IsDebug = (script:GetAttribute("Debug") == true)
end)

return Overture
