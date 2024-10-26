export type MovementParams = {
	origin: CFrame,
	velocity: Vector3,
	acceleration: Vector3,
	lifetime: number,
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

--[[
one projectile:
  20:43:47.201  0.000023099999907572055  -  Server - ActiveCast:418
  20:43:47.218  0.000025299999833805487  -  Server - ActiveCast:418
  20:43:47.236  0.000027099999897473026  -  Server - ActiveCast:418
  20:43:47.251  0.00002679999988686177  -  Server - ActiveCast:418
  20:43:47.269  0.00002300000005561742  -  Server - ActiveCast:418
  20:43:47.284  0.000027999999929306796  -  Server - ActiveCast:418

  20:45:47.779  0.00002189999986512703  -  Server - ParametricMovement:128
  20:45:47.796  0.00001990000009755022  -  Server - ParametricMovement:128
  20:45:47.813  0.000019600000086938962  -  Server - ParametricMovement:128
  20:45:47.830  0.0000175999998646148  -  Server - ParametricMovement:128
  20:45:47.846  0.000018799999907059828  -  Server - ParametricMovement:128
  20:45:47.863  0.00001920000022437307  -  Server - ParametricMovement:128

  many self._projectiles
  09:59:14.063  0.0010320000000092477  -  Server - ParametricMovement:195
  09:59:14.079  0.0010421000000633285  -  Server - ParametricMovement:195
  09:59:14.096  0.001042399999960253  -  Server - ParametricMovement:195
  09:59:14.113  0.00115589999995791  -  Server - ParametricMovement:195
  09:59:14.129  0.0010244000000056985  -  Server - ParametricMovement:195
  09:59:14.146  0.0010380999999597407  -  Server - ParametricMovement:195

  10:01:03.024  0.0010295999999243577  -  Server - ParametricMovement:190
  10:01:03.040  0.0010452999999870372  -  Server - ParametricMovement:190
  10:01:03.058  0.0010548999999855369  -  Server - ParametricMovement:190
  10:01:03.074  0.0009311999999681575  -  Server - ParametricMovement:190
  10:01:03.090  0.0010577000000466796  -  Server - ParametricMovement:190
  10:01:03.108  0.0010280999999849882  -  Server - ParametricMovement:190
  10:01:03.124  0.0010241999999607287  -  Server - ParametricMovement:190
  10:01:03.141  0.0011514000000261149  -  Server - ParametricMovement:190

  10:03:51.117  0.0011108000001058826  -  Server - ParametricMovement:195
  10:03:51.134  0.001119799999969473  -  Server - ParametricMovement:195
  10:03:51.151  0.0012526999998954125  -  Server - ParametricMovement:195
  10:03:51.168  0.0012828999999783264  -  Server - ParametricMovement:195
  10:03:51.184  0.001288300000169329  -  Server - ParametricMovement:195
  10:03:51.202  0.001115999999910855  -  Server - ParametricMovement:195

  10:07:32.109  0.0011684999999488355  -  Server - ParametricMovement:146
  10:07:32.127  0.0013627999999243912  -  Server - ParametricMovement:146
  10:07:32.143  0.0011325000000397267  -  Server - ParametricMovement:146
  10:07:32.159  0.0011557999998785817  -  Server - ParametricMovement:146
  10:07:32.176  0.001274999999850479  -  Server - ParametricMovement:146
  10:07:32.192  0.001126399999975547  -  Server - ParametricMovement:146
  10:07:32.208  0.0012408000000050379  -  Server - ParametricMovement:146
  10:07:32.225  0.00112659999990683  -  Server - ParametricMovement:146
  10:07:32.242  0.0013417000000117696  -  Server - ParametricMovement:146

  10:15:17.438  0.012545599999839396  -  Server - ParametricMovement:132
  10:15:17.459  0.016392699999869365  -  Server - ParametricMovement:132
  10:15:17.474  0.012364800000113974  -  Server - ParametricMovement:132
  10:15:17.493  0.014752999999927852  -  Server - ParametricMovement:132
  10:15:17.514  0.012602900000047157  -  Server - ParametricMovement:132
  v1
]]

function ParametricMovement:_start()
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
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

			local result = workspace:Raycast(lastPoint, rayDirection, projectile.castParams)

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
end

return ParametricMovement
