# pixel3d.lua

You can render 3D objects in Love2D! Use this Lua file to turn pixel art images into 3D voxel representations with real-time rotation and shading.

All functionality exists in `pixel3d.lua` - that's all you need for your project! The `main.lua` provides a great example of how to use pixel3d to render 3D images, and you can run this repo as a Love2D game to see it in action.

## How to use pixel3d.lua

Copy `pixel3d.lua` into your Love2D project, and use it to create image3d instances:

```lua
pixel3d = require("pixel3d") -- factory for image3d instances

function love.load()
    -- Create a 3D image from a PNG file
    image3d = pixel3d.fromImage("sword.png", 20)  -- 20 = voxel size
    image3d:setPosition(400, 300)
end

function love.update(dt)
    image3d:update(dt)  -- Handle auto-rotation
end

function love.draw()
    image3d:draw()  -- Render the 3D model
end
```

That's it! The module handles everything else automatically.

## Available Functions

Once you have an `image3d` instance, you can call these functions:

```lua
-- Positioning
image3d:setPosition(x, y)          -- Set screen position

-- Manual rotation
image3d:rotateLeft(amount)         -- Rotate left by amount
image3d:rotateRight(amount)        -- Rotate right by amount
image3d:rotateUp(amount)           -- Rotate up by amount
image3d:rotateDown(amount)         -- Rotate down by amount
image3d:rollLeft(amount)           -- Roll left by amount
image3d:rollRight(amount)          -- Roll right by amount

-- Direct rotation setters
image3d:setRotationX(angle)        -- Set X rotation directly
image3d:setRotationY(angle)        -- Set Y rotation directly
image3d:setRotationZ(angle)        -- Set Z rotation directly
image3d:setRotation(x, y, z)       -- Set all rotations at once

-- Zoom controls
image3d:zoomIn(amount)             -- Zoom in by amount
image3d:zoomOut(amount)            -- Zoom out by amount
image3d:setZoom(level)             -- Set zoom level directly

-- Auto-rotation
image3d:setAutoRotation(x, y, z)   -- Set auto-rotation speeds per axis
image3d:toggleAutoRotate()         -- Toggle auto-rotation on/off

-- Visual toggles
image3d:toggleWireframe()          -- Toggle wireframe mode
image3d:toggleShade()              -- Toggle shading/lighting

-- Utility
image3d:resetRotation()            -- Reset all rotations to 0
image3d:getSettings()              -- Get current state (zoom, rotation, etc.)
image3d:update(dt)                 -- Call in love.update() for auto-rotation
image3d:draw()                     -- Call in love.draw() to render
```
