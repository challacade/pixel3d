function love.load()    
    -- pixel3d creates image3d instances from images
    pixel3d = require("pixel3d")
    
    imageName = "sword.png"  -- Change to your image file
    showInstructions = true  -- Toggle to show/hide instructions
    width, height = 800, 600  -- Default window size
    
    -- Create an image3d instance
    image3d = pixel3d.fromImage(imageName, 20)
    image3d:setPosition(width / 2, height / 2)
    image3d:setAutoRotation(1.25, 0, 0)  -- Slow auto-rotation on X only

    love.window.setMode(width, height, {resizable = true})
    love.graphics.setBackgroundColor(0.25, 0.25, 0.5)
end

function love.update(dt)
    -- Update image3d (handles auto-rotation)
    image3d:update(dt)
    
    -- Manual rotation controls
    local rotationAmount = 2 * dt
    if love.keyboard.isDown("left") then image3d:rotateLeft(rotationAmount) end
    if love.keyboard.isDown("right") then image3d:rotateRight(rotationAmount) end
    if love.keyboard.isDown("up") then image3d:rotateUp(rotationAmount) end
    if love.keyboard.isDown("down") then image3d:rotateDown(rotationAmount) end
    if love.keyboard.isDown("q") then image3d:rollLeft(rotationAmount) end
    if love.keyboard.isDown("e") then image3d:rollRight(rotationAmount) end
    
    -- Zoom controls
    local zoomAmount = 2 * dt
    if love.keyboard.isDown("=") or love.keyboard.isDown("+") then image3d:zoomIn(zoomAmount) end
    if love.keyboard.isDown("-") then image3d:zoomOut(zoomAmount) end
end

function love.draw()
    -- Draw gradient background
    drawGradientBackground()
    
    -- Render the image3d instance
    image3d:draw()
    
    -- Draw the overlay UI (only if instructions are enabled)
    if showInstructions then drawInstructions() end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        image3d:toggleAutoRotate()
    elseif key == "w" then
        image3d:toggleWireframe()
    elseif key == "s" then
        image3d:toggleShade()
    elseif key == "r" then
        image3d:resetRotation()
    elseif key == "h" then
        showInstructions = not showInstructions
    end
end

function love.resize(w, h)
    width, height = w, h
    image3d:setPosition(width / 2, height / 2)
end

function drawInstructions()
    -- Get current settings for display
    local settings = image3d:getSettings()
    
    -- Draw UI
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("3D Pixel Art Renderer", 10, 10)
    love.graphics.print("Controls:", 10, 30)
    love.graphics.print("Arrow Keys - Manual rotation", 10, 50)
    love.graphics.print("Q/E - Roll rotation", 10, 70)
    love.graphics.print("Space - Toggle auto rotation", 10, 90)
    love.graphics.print("+/- - Zoom in/out", 10, 110)
    love.graphics.print("W - Toggle wireframe", 10, 130)
    love.graphics.print("S - Toggle shade", 10, 150)
    love.graphics.print("R - Reset rotation", 10, 170)
    love.graphics.print("H - Hide/Show instructions", 10, 190)
    love.graphics.print("ESC - Quit", 10, 210)
    
    love.graphics.print("Image3D blocks: " .. settings.voxelCount, 10, 230)
    love.graphics.print("Faces rendered: " .. settings.facesRendered, 10, 250)
    love.graphics.print("Zoom: " .. string.format("%.1f", settings.zoom), 10, 270)
    love.graphics.print("Auto rotate: " .. (settings.autoRotate and "ON" or "OFF"), 10, 290)
    love.graphics.print("Wireframe: " .. (settings.wireframe and "ON" or "OFF"), 10, 310)
    love.graphics.print("Shade: " .. (settings.shadeEnabled and "ON" or "OFF"), 10, 330)
    
    -- Instructions
    local displayText = "Displaying: " .. imageName .. " as 3D image3d (or default cube if not found)"
    love.graphics.print(displayText, 10, height - 20)
end

function drawGradientBackground()
    -- Create a simple vertical gradient with more contrast and moderate saturation
    local mesh = love.graphics.newMesh({
        {0, 0, 0, 0, 0.45, 0.5, 0.65, 1},        -- Top left - lighter blue with more saturation
        {width, 0, 0, 0, 0.45, 0.5, 0.65, 1},    -- Top right - lighter blue with more saturation
        {width, height, 0, 0, 0.15, 0.2, 0.35, 1}, -- Bottom right - much darker blue
        {0, height, 0, 0, 0.15, 0.2, 0.35, 1}    -- Bottom left - much darker blue
    }, "fan")
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color to white
    love.graphics.draw(mesh, 0, 0)
end
