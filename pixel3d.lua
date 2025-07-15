-- Pixel3D - 3D Pixel Art Image3D Renderer Factory
-- Creates image3d instances from pixel art images

local pixel3d = {}

-- Default configuration
local DEFAULT_VOXEL_SIZE = 20
local DEFAULT_CAMERA_DISTANCE = 300
local DEFAULT_PROJECTION_DISTANCE = 800

-- Image3D class
local Image3D = {}
Image3D.__index = Image3D

-- 3D Math utilities
function Image3D:rotateX(x, y, z, angle)
    local cos_a, sin_a = math.cos(angle), math.sin(angle)
    return x * cos_a + z * sin_a, y, -x * sin_a + z * cos_a
end

function Image3D:rotateY(x, y, z, angle)
    local cos_a, sin_a = math.cos(angle), math.sin(angle)
    return x, y * cos_a - z * sin_a, y * sin_a + z * cos_a
end

function Image3D:rotateZ(x, y, z, angle)
    local cos_a, sin_a = math.cos(angle), math.sin(angle)
    return x * cos_a - y * sin_a, x * sin_a + y * cos_a, z
end

-- Project 3D point to 2D screen coordinates
function Image3D:project(x, y, z, centerX, centerY, distance)
    distance = distance or DEFAULT_PROJECTION_DISTANCE
    if z <= -distance then return nil, nil end -- Behind camera
    local scale = distance / (distance + z)
    return centerX + x * scale, centerY - y * scale -- Flip Y-axis for correct orientation
end

-- Calculate normal vector for a face
function Image3D:calculateNormal(v1, v2, v3)
    local ax, ay, az = v2[1] - v1[1], v2[2] - v1[2], v2[3] - v1[3]
    local bx, by, bz = v3[1] - v1[1], v3[2] - v1[2], v3[3] - v1[3]
    
    local nx = ay * bz - az * by
    local ny = az * bx - ax * bz
    local nz = ax * by - ay * bx
    
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length > 0 then
        nx, ny, nz = nx / length, ny / length, nz / length
    end
    
    return nx, ny, nz
end

-- Create a single image3d block (cube) at given position with given color
-- Pre-calculated face data for better performance
local FACE_DATA = {
    -- Each face has vertices, shade, and direction
    {indices = {1, 2, 3}, shade = 1.0, dir = {0, 0, -1}},   -- Front triangle 1
    {indices = {1, 3, 4}, shade = 1.0, dir = {0, 0, -1}},   -- Front triangle 2
    {indices = {5, 7, 6}, shade = 0.6, dir = {0, 0, 1}},    -- Back triangle 1
    {indices = {5, 8, 7}, shade = 0.6, dir = {0, 0, 1}},    -- Back triangle 2
    {indices = {1, 4, 8}, shade = 0.8, dir = {-1, 0, 0}},   -- Left triangle 1
    {indices = {1, 8, 5}, shade = 0.8, dir = {-1, 0, 0}},   -- Left triangle 2
    {indices = {2, 6, 7}, shade = 0.9, dir = {1, 0, 0}},    -- Right triangle 1
    {indices = {2, 7, 3}, shade = 0.9, dir = {1, 0, 0}},    -- Right triangle 2
    {indices = {3, 7, 8}, shade = 0.7, dir = {0, 1, 0}},    -- Top triangle 1
    {indices = {3, 8, 4}, shade = 0.7, dir = {0, 1, 0}},    -- Top triangle 2
    {indices = {1, 5, 6}, shade = 0.5, dir = {0, -1, 0}},   -- Bottom triangle 1
    {indices = {1, 6, 2}, shade = 0.5, dir = {0, -1, 0}}    -- Bottom triangle 2
}

function Image3D:createVoxel(x, y, z, size, color)
    local s = size / 2
    local faces = {}
    
    -- Create faces using pre-calculated data
    for i, faceData in ipairs(FACE_DATA) do
        faces[i] = {
            faceData.indices[1], faceData.indices[2], faceData.indices[3],
            shade = faceData.shade,
            dir = faceData.dir
        }
    end
    
    return {
        position = {x, y, z},
        color = color,
        size = size,
        vertices = {
            {x-s, y-s, z-s}, {x+s, y-s, z-s}, {x+s, y+s, z-s}, {x-s, y+s, z-s}, -- Front face
            {x-s, y-s, z+s}, {x+s, y-s, z+s}, {x+s, y+s, z+s}, {x-s, y+s, z+s}  -- Back face
        },
        faces = faces
    }
end

-- Create a lookup table for image3d block positions for fast neighbor checking
function Image3D:createVoxelMap(voxels)
    local voxelMap = {}
    for _, voxel in ipairs(voxels) do
        local x, y, z = voxel.position[1], voxel.position[2], voxel.position[3]
        local key = x .. "," .. y .. "," .. z
        voxelMap[key] = true
    end
    return voxelMap
end

-- Check if an image3d block exists at given position
function Image3D:hasVoxelAt(voxelMap, x, y, z)
    local key = x .. "," .. y .. "," .. z
    return voxelMap[key] == true
end

-- Get only visible faces (faces not touching another image3d block)
-- Pre-calculated face check data for better performance
local FACE_CHECKS = {
    {dir = {0, 0, -1}, faceIndices = {1, 2}},   -- Front faces
    {dir = {0, 0, 1}, faceIndices = {3, 4}},    -- Back faces
    {dir = {-1, 0, 0}, faceIndices = {5, 6}},   -- Left faces
    {dir = {1, 0, 0}, faceIndices = {7, 8}},    -- Right faces
    {dir = {0, 1, 0}, faceIndices = {9, 10}},   -- Top faces
    {dir = {0, -1, 0}, faceIndices = {11, 12}}  -- Bottom faces
}

function Image3D:getVisibleFaces(voxel, voxelMap)
    local visibleFaces = {}
    local pos = voxel.position
    local size = voxel.size
    
    for _, check in ipairs(FACE_CHECKS) do
        local neighborX = pos[1] + check.dir[1] * size
        local neighborY = pos[2] + check.dir[2] * size
        local neighborZ = pos[3] + check.dir[3] * size
        
        -- If no neighbor voxel in this direction, the face is visible
        if not self:hasVoxelAt(voxelMap, neighborX, neighborY, neighborZ) then
            for _, faceIndex in ipairs(check.faceIndices) do
                visibleFaces[#visibleFaces + 1] = voxel.faces[faceIndex]
            end
        end
    end
    
    return visibleFaces
end

-- Image3D Constructor
function Image3D:new(imagePath, voxelSize)
    local obj = setmetatable({}, Image3D)
    
    -- Initialize properties
    obj.voxelSize = voxelSize or DEFAULT_VOXEL_SIZE
    obj.voxels = {}
    obj.facesRendered = 0
    
    -- Rendering settings
    obj.rotationX = 0
    obj.rotationY = 0
    obj.rotationZ = 0
    obj.zoom = 1.0
    obj.centerX = love.graphics.getWidth() / 2
    obj.centerY = love.graphics.getHeight() / 2
    obj.cameraDistance = DEFAULT_CAMERA_DISTANCE
    obj.wireframe = false
    obj.shadeEnabled = false
    obj.autoRotate = false
    obj.autoRotationX = 0
    obj.autoRotationY = 0
    obj.autoRotationZ = 0
    obj.loadedFromImage = false  -- Track if we successfully loaded from image
    
    -- Load image3d data
    if imagePath then
        obj:loadFromImage(imagePath)
    else
        obj:loadDefaultCube()
    end
    
    return obj
end

-- Load and process image into image3d blocks
function Image3D:loadFromImage(imagePath)
    self.voxels = {}
    
    -- Try to load the image data directly
    local success, imageData = pcall(love.image.newImageData, imagePath)
    if not success then
        print("Error: Could not load image '" .. imagePath .. "'")
        self:loadDefaultCube()
        return
    end
    
    local imgWidth = imageData:getWidth()
    local imgHeight = imageData:getHeight()
    
    -- Calculate offset to center the image
    local offsetX = -imgWidth * self.voxelSize / 2
    local offsetY = -imgHeight * self.voxelSize / 2
    
    -- Convert each pixel to an image3d block
    for y = 0, imgHeight - 1 do
        for x = 0, imgWidth - 1 do
            local r, g, b, a = imageData:getPixel(x, y)
            
            -- Only create image3d block if pixel is not transparent
            if a > 0.1 then
                local voxelX = offsetX + x * self.voxelSize
                local voxelY = offsetY + (imgHeight - 1 - y) * self.voxelSize -- Flip Y for correct orientation
                local voxelZ = 0
                
                table.insert(self.voxels, self:createVoxel(voxelX, voxelY, voxelZ, self.voxelSize, {r, g, b, a}))
            end
        end
    end
    
    self.loadedFromImage = true  -- Mark as successfully loaded from image
    print("Loaded " .. #self.voxels .. " image3d blocks from " .. imagePath)
end

-- Create a default cube when no image is provided
function Image3D:loadDefaultCube()
    self.voxels = {}
    
    -- Create a simple 3x3x3 cube with different colors for each face
    local colors = {
        {1, 0, 0, 1},    -- Red
        {0, 1, 0, 1},    -- Green
        {0, 0, 1, 1},    -- Blue
        {1, 1, 0, 1},    -- Yellow
        {1, 0, 1, 1},    -- Magenta
        {0, 1, 1, 1},    -- Cyan
        {1, 0.5, 0, 1},  -- Orange
        {0.5, 0, 1, 1},  -- Purple
        {1, 1, 1, 1}     -- White
    }
    
    local colorIndex = 1
    for x = -1, 1 do
        for y = -1, 1 do
            for z = -1, 1 do
                local voxelX = x * self.voxelSize
                local voxelY = y * self.voxelSize
                local voxelZ = z * self.voxelSize
                
                table.insert(self.voxels, self:createVoxel(voxelX, voxelY, voxelZ, self.voxelSize, colors[colorIndex]))
                colorIndex = colorIndex % #colors + 1
            end
        end
    end
    
    print("Loaded default cube with " .. #self.voxels .. " image3d blocks")
end

-- Set screen center position
function Image3D:setPosition(x, y)
    self.centerX = x
    self.centerY = y
end

-- Update auto-rotation and handle input
function Image3D:update(dt)
    if self.autoRotate then
        self.rotationX = self.rotationX + self.autoRotationX * dt
        self.rotationY = self.rotationY + self.autoRotationY * dt
        self.rotationZ = self.rotationZ + self.autoRotationZ * dt
    end
end

-- Individual rotation functions
function Image3D:rotateLeft(amount)
    self.rotationX = self.rotationX + amount
end

function Image3D:rotateRight(amount)
    self.rotationX = self.rotationX - amount
end

function Image3D:rotateUp(amount)
    self.rotationY = self.rotationY - amount
end

function Image3D:rotateDown(amount)
    self.rotationY = self.rotationY + amount
end

function Image3D:rollLeft(amount)
    self.rotationZ = self.rotationZ - amount
end

function Image3D:rollRight(amount)
    self.rotationZ = self.rotationZ + amount
end

-- Direct rotation setters
function Image3D:setRotationX(angle)
    self.rotationX = angle
end

function Image3D:setRotationY(angle)
    self.rotationY = angle
end

function Image3D:setRotationZ(angle)
    self.rotationZ = angle
end

function Image3D:setRotation(x, y, z)
    self.rotationX = x or self.rotationX
    self.rotationY = y or self.rotationY
    self.rotationZ = z or self.rotationZ
end

-- Individual zoom functions (consolidated with bounds checking)
function Image3D:zoomIn(amount)
    self.zoom = self.zoom + amount
end

function Image3D:zoomOut(amount)
    self.zoom = math.max(0.1, self.zoom - amount)
end

function Image3D:setZoom(zoomLevel)
    self.zoom = math.max(0.1, zoomLevel)
end

-- Reset rotation
function Image3D:resetRotation()
    self.rotationX = 0
    self.rotationY = 0
    self.rotationZ = 0
end

-- Toggle settings
function Image3D:toggleAutoRotate()
    self.autoRotate = not self.autoRotate
end

-- Set auto-rotation for each axis
function Image3D:setAutoRotation(x, y, z)
    self.autoRotationX = x
    self.autoRotationY = y
    self.autoRotationZ = z
    self.autoRotate = true
end

function Image3D:toggleWireframe()
    self.wireframe = not self.wireframe
end

function Image3D:toggleShade()
    self.shadeEnabled = not self.shadeEnabled
end

-- Get current settings for UI display
function Image3D:getSettings()
    return {
        zoom = self.zoom,
        autoRotate = self.autoRotate,
        wireframe = self.wireframe,
        shadeEnabled = self.shadeEnabled,
        rotationX = self.rotationX,
        rotationY = self.rotationY,
        rotationZ = self.rotationZ,
        voxelCount = #self.voxels,
        facesRendered = self.facesRendered,
        loadedFromImage = self.loadedFromImage
    }
end

-- Render image3d blocks to screen (optimized)
function Image3D:draw()
    local allFaces = {}
    local faceCount = 0
    
    -- Create image3d block map for efficient neighbor checking
    local voxelMap = self:createVoxelMap(self.voxels)
    
    -- Process all image3d blocks
    for _, voxel in ipairs(self.voxels) do
        local vertices = voxel.vertices
        local color = voxel.color
        
        -- Get only visible faces (not touching other image3d blocks)
        local visibleFaces = self:getVisibleFaces(voxel, voxelMap)
        
        -- Transform vertices once per voxel
        local transformedVertices = {}
        for i = 1, 8 do
            local vertex = vertices[i]
            local x, y, z = vertex[1], vertex[2], vertex[3]
            
            -- Apply scaling
            x, y, z = x * self.zoom, y * self.zoom, z * self.zoom
            
            -- Apply rotations
            x, y, z = self:rotateX(x, y, z, self.rotationX)
            x, y, z = self:rotateY(x, y, z, self.rotationY)
            x, y, z = self:rotateZ(x, y, z, self.rotationZ)
            
            -- Move away from camera
            z = z + self.cameraDistance
            
            transformedVertices[i] = {x, y, z}
        end
        
        -- Process only visible faces
        for _, face in ipairs(visibleFaces) do
            local v1 = transformedVertices[face[1]]
            local v2 = transformedVertices[face[2]]
            local v3 = transformedVertices[face[3]]
            
            -- Skip if any vertex is behind the camera
            if v1[3] > 0 and v2[3] > 0 and v3[3] > 0 then
                -- Calculate normal for backface culling
                local nx, ny, nz = self:calculateNormal(v1, v2, v3)
                
                -- Backface culling
                if nz >= 0 then
                    -- Project to screen
                    local s1x, s1y = self:project(v1[1], v1[2], v1[3], self.centerX, self.centerY)
                    local s2x, s2y = self:project(v2[1], v2[2], v2[3], self.centerX, self.centerY)
                    local s3x, s3y = self:project(v3[1], v3[2], v3[3], self.centerX, self.centerY)
                    
                    if s1x and s2x and s3x then
                        -- Calculate shade intensity
                        local shadeIntensity = self.shadeEnabled and (face.shade or 1.0) or 1.0
                        
                        -- Calculate average depth for sorting
                        local avgZ = (v1[3] + v2[3] + v3[3]) / 3
                        
                        faceCount = faceCount + 1
                        allFaces[faceCount] = {
                            vertices = {{s1x, s1y}, {s2x, s2y}, {s3x, s3y}},
                            color = color,
                            shadeIntensity = shadeIntensity,
                            avgZ = avgZ
                        }
                    end
                end
            end
        end
    end
    
    -- Sort faces by depth (back to front)
    table.sort(allFaces, function(a, b) return a.avgZ > b.avgZ end)
    
    -- Render all faces
    for i = 1, faceCount do
        local face = allFaces[i]
        local v1, v2, v3 = face.vertices[1], face.vertices[2], face.vertices[3]
        local r, g, b = face.color[1], face.color[2], face.color[3]
        local shadeIntensity = face.shadeIntensity
        
        if self.wireframe then
            love.graphics.setColor(1, 1, 1)
            love.graphics.line(v1[1], v1[2], v2[1], v2[2])
            love.graphics.line(v2[1], v2[2], v3[1], v3[2])
            love.graphics.line(v3[1], v3[2], v1[1], v1[2])
        else
            love.graphics.setColor(r * shadeIntensity, g * shadeIntensity, b * shadeIntensity)
            love.graphics.polygon("fill", v1[1], v1[2], v2[1], v2[2], v3[1], v3[2])
        end
    end
    
    -- Store faces rendered for UI display
    self.facesRendered = faceCount
end

-- Factory functions for creating Image3D instances
function pixel3d.new(imagePath, voxelSize)
    return Image3D:new(imagePath, voxelSize)
end

function pixel3d.fromImage(imagePath, voxelSize)
    return Image3D:new(imagePath, voxelSize)
end

function pixel3d.defaultCube(voxelSize)
    return Image3D:new(nil, voxelSize)
end

return pixel3d
