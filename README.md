# ParametricMovement
ParametricMovement is a projectile manager with an emphasis on speed.

ParametricMovement is around 2-3 times faster than FastCast at the sacrifice of bits of functionality. The limits of performance are now mostly within the hands of the Roblox engine.

ParametricMovement can sustain (on my computer) up to 4,200 projectiles at 60 FPS, while FastCast can only get near 1,700.

## Installation

```bash
ParametricMovement = "iminversed/parametricmovement@1.0.0"
```

## Code Example

```lua
local container = ParametricMovement.new(template, workspace.Folder, 1000)

container:onMovementStart(function(instance) end)

container:onMovementUpdate(function(instances, cframes, raycasts)
	workspace:BulkMoveTo(instances, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

container:onMovementEnd(function(instance, raycast) end)

local rng = Random.new()

while true do
	local velocity = 100
	local direction = rng:NextUnitVector()

	container:launchProjectile({
		origin = CFrame.new(0, 10, 0),
		velocity = direction * velocity,
		acceleration = Vector3.new(0, -workspace.Gravity, 0),
		lifetime = 1,
		raycastParams = raycastParams,
	})

	task.wait()
end
```

## Things that could be better

I may or may not have plans for:
 - adding methods to update movement parameters while the projectile is alive
 - proper library typing