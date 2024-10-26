export type MovementParams = {
	origin: CFrame,
	velocity: Vector3,
	acceleration: Vector3,
	lifetime: number,
	rayraycastParams: RaycastParams,
}

local RunService = game:GetService("RunService")

local instanceCacher = require(script.instanceCacher)

local function getPositionAtTime(t: number, origin: Vector3, initialVelocity: Vector3, acceleration: Vector3): Vector3
	return origin + (initialVelocity * t) + acceleration * t * t * 0.5
end

local function getVelocityAtTime(t: number, initialVelocity: Vector3, acceleration: Vector3): Vector3
	return initialVelocity + acceleration * t
end

local ParametricMovement = {}
ParametricMovement.__index = ParametricMovement

function ParametricMovement.new(modelTemplate: Model | BasePart, parent: Instance?, instanceCacheAmount: number?)
	local self = setmetatable({}, ParametricMovement)

	self._template = modelTemplate
	self._instanceCacheAmount = instanceCacheAmount
	self._movementStarts = {}
	self._movementUpdates = {}
	self._movementEnds = {}
	self._instanceCacher = instanceCacher(modelTemplate, parent, instanceCacheAmount or 10)

	self._instances = {}
	self._cframes = {}
	self._raycasts = {}
	self._projectiles = {}

	self:_start()

	return self
end

function ParametricMovement:_start()
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		debug.profilebegin("ara ara")
		for index = #self._projectiles, 1, -1 do
			local projectile = self._projectiles[index]

			local lastPoint = getPositionAtTime(
				projectile.totalDelta,
				projectile.origin.Position,
				projectile.velocity,
				projectile.acceleration
			)

			projectile.totalDelta += deltaTime

			local segmentVelocity =
				getVelocityAtTime(projectile.totalDelta, projectile.velocity, projectile.acceleration)
			local currentPoint = lastPoint + segmentVelocity * deltaTime

			local displacement = currentPoint - lastPoint
			local rayDirection = displacement.Unit * segmentVelocity.Magnitude * deltaTime

			local result = workspace:Raycast(lastPoint, rayDirection, projectile.raycastParams)

			self._raycasts[index] = result
			self._cframes[index] = CFrame.lookAt(currentPoint, lastPoint)

			if projectile.totalDelta > 1 then
				for _, callback in self._movementEnds do
					local instance = self._instances[index]

					self._instanceCacher.returnInstance(instance)

					pcall(callback, instance, result)
				end

				table.remove(self._cframes, index)
				table.remove(self._instances, index)
				table.remove(self._raycasts, index)
				table.remove(self._projectiles, index)
			end
		end

		-- yeah that's right im not afraid of you, error all you want
		for _, callback in self._movementUpdates do
			callback(self._instances, self._cframes, self._raycasts)
		end
		debug.profileend()
	end)
end

function ParametricMovement:launchProjectile(movementParams: MovementParams)
	local instance = self._instanceCacher.getInstance()

	-- mixed soa and aos structure
	-- does aos improve performance on its own here? no
	table.insert(self._cframes, movementParams.origin)
	table.insert(self._instances, instance)
	table.insert(self._projectiles, {
		totalDelta = 0,
		acceleration = movementParams.acceleration,
		lifetime = movementParams.lifetime,
		velocity = movementParams.velocity,
		origin = movementParams.origin,
		raycastParams = movementParams.rayraycastParams,
	})

	for _, movementStart in self._movementStarts do
		movementStart(instance, movementParams)
	end
end

function ParametricMovement:onMovementStart(callback: (instance: Instance, movementParams: MovementParams) -> ())
	table.insert(self._movementStarts, callback)
end

function ParametricMovement:onMovementUpdate(callback: (
	instances: { Instance },
	cframes: { CFrame },
	raycasts: { RaycastResult }
) -> ())
	table.insert(self._movementUpdates, callback)
end

function ParametricMovement:onMovementEnd(callback: (instance: Instance, raycast: RaycastResult) -> ())
	table.insert(self._movementEnds, callback)
end

-- why would you ever call this function
-- im going to bet bad code practice if you call this
function ParametricMovement:destroy()
	self._heartbeatConnection:Disconnect()
	self._instanceCacher.clearInstances()
	self._instances = {}
end

return ParametricMovement
