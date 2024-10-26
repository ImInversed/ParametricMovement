local OUT_OF_RENDER_CFRAME = CFrame.new(10e7, 0, 0)
local INSTANCE_COUNT = 10

local function instanceCacher(template: Instance, parent: Instance?, instanceCount: number)
	local inUse = {}
	local instances = {}

	local function _createInstances(amount)
		for _ = 1, amount do
			local newInstance = template:Clone()
			newInstance:PivotTo(OUT_OF_RENDER_CFRAME)
			newInstance.Parent = parent or workspace

			table.insert(instances, newInstance)
		end
	end

	_createInstances(instanceCount)

	local function getInstance(): Instance
		local index = #instances

		if index == 0 then
			_createInstances(INSTANCE_COUNT)

			index = #instances
		end

		local instance = instances[index]

		table.remove(instances, index)
		table.insert(inUse, instance)

		return instance
	end

	local function returnInstance(instance: Instance)
		local index = table.find(inUse, instance)

		table.insert(instances, instance)
		table.remove(inUse, index)

		if instance:IsA("BasePart") then
			instance.CFrame = OUT_OF_RENDER_CFRAME
		elseif instance:IsA("Model") then
			instance:PivotTo(OUT_OF_RENDER_CFRAME)
		end
	end

	local function clearInstances()
		for _, instance in instances do
			instance:Destroy()
		end
	end

	return {
		getInstance = getInstance,
		returnInstance = returnInstance,
		clearInstances = clearInstances,
	}
end

return instanceCacher
