local vec = require('vector')
world = { width = 2000, height = 2000 }

playerPolygonPoints = { vec(-15,-15), vec(25,0), vec(-15,15) }
-- player is a triangle, a bit centered
player = { 
    pos = vec(400, 400),
    speed = vec(0, 0),
    rotation = 0,
    isAlive = true,
    startPos = vec(400, 400),
    score = 0
}
viewport = { cameraPos = vec(0,0), scale = vec(1,1), rotation = 0, size = nil }

asteroidTotalMinimumRadius = 25
asteroidTotalMaximumRadius = 60
asteroidNumCategories = 3

asteroids = {}
bullets = {}

bulletTimerMax = 0.1
bulletTimer = 0
bulletPolygonPoints = { vec(-2,-1), vec(2,-1), vec(2, 1), vec(-2,1)  }
bulletCounter = 0

asteroidHitTimerMax = 0.75
asteroidBlinkTimes = 7
asteroidColors = { {r = 0.5, g = 0.75, b = 0}, {r = 0.7, g = 0.9, b = 0.2}, 
                   {r = 0.6, g = 0.6, b = 0.1}, {r = 0.8, g = 0.9, b = 0.5}, 
                   {r = 0.7, g = 0.8, b = 0.8}, {r = 0.3, g = 0.8, b = 0.6} }
asteroidInitialCount = 20
asteroidCount = nil

-- sounds
shootSound = nil
explosionSounds = {}
hitSounds = {}
backgroundSound = nil
loseSound = {}

explosionParticle = nil
hitExplosionSystem = nil
asteroidExplosionSystem = nil
explosions = {}

function lerp(start, finish, percentage)
    return start + (finish - start) * percentage
end
function clamp(val, min, max) return (val < min) and min or (val > max) and max or val end
function vecInWorld(v) 
    local x = v.x % world.width
    local y = v.y % world.height
    return vec(x, y)
end

-- **********************************************************************
-- **********************************************************************
-- * Camera & Viewport
function intoRect(p, x0, y0, x1, y1)
    return p.x >= x0 and p.x < x1 and p.y >= y0 and p.y < y1
end
function toScreen(worldPos)
    local vorigin = viewportOrigin()
    return worldPos - vorigin
end
function initViewport()
    viewport.size = vec(love.graphics.getWidth(), love.graphics.getHeight())
    viewport.cameraPos = player.pos:clone()
end
function viewportOrigin()
    return vecInWorld(viewport.cameraPos - viewport.size*0.5)
end
function updateViewport(dt)
    -- simply chase player
    viewport.cameraPos = player.pos:clone()
end
-- returns a vector if its visible, false in other case
-- the vector must be added to asteroid position to call toScreen and get screen coordinates
function isVisibleAsteroid(asteroid)
    local R = asteroid.maxRadius
    local ax1, ax2 = asteroid.pos.x - R, asteroid.pos.x + R
    local ay1, ay2 = asteroid.pos.y - R, asteroid.pos.y + R
    local vorigin = viewportOrigin()
    local x1, x2 = vorigin.x, vorigin.x + viewport.size.x
    local y1, y2 = vorigin.y, vorigin.y + viewport.size.y
    return (segmentOverlap(ax1, ax2, x1, x2) and vec(0, 0)) or
           (segmentOverlap(ay1, ay2, y1, y2) and vec(0, 0)) or
           -- wrap world cases, not very clear, i know :/
           (x2 + R > world.width and segmentOverlap(ax1, ax2, x1 - world.width, x2 - world.width) and vec(world.width, 0)) or
           (y2 + R > world.height and segmentOverlap(ay1, ay2, y1 - world.height, y2 - world.height) and vec(0, world.height)) or
           (x1 < R and segmentOverlap(ax1 - world.width, ax2 - world.width, x1, x2) and vec(-world.width, 0)) or
           (y1 < R and segmentOverlap(ay1 - world.height, ay2 - world.height, y1, y2) and vec(0, -world.height)) or
           (x2 + R > world.width and y2 + R > world.height and 
                (segmentOverlap(ax1, ax2, x1 - world.width, x2 - world.width) and 
                 segmentOverlap(ay1, ay2, y1 - world.height, y2 - world.height)) and vec(world.width, world.height)) or
           (x1 < R and y1 < R and 
                (segmentOverlap(ax1 - world.width, ax2 - world.width, x1, x2) and
                 segmentOverlap(ay1 - world.height, ay2 - world.height, y1, y2)) and vec(-world.width, -world.height))
end

-- Check if two horizontal segments overlap
--  x1..........x2      <- segment x
--       y1.........y2  <- segment y
function segmentOverlap(x1, x2, y1, y2)
    -- read as: if x1 inside y; x2 inside y ...
    return not (not ((x1 > y1 and x1 < y2) or 
    (x2 > y1 and x2 < y2) or 
    (y1 > x1 and y1 < x2)))
end
-- Polygon collision testing using SAT theorem
-- polygon = { pos, rotation, points }
function checkCollisionSAT(polygon1, polygon2)
    local normals = {}
    for i = 1, #polygon1.points do
        local j = (i % #polygon1.points) + 1
        local p1 = (polygon1.points[i] + polygon1.pos):rotate(polygon1.rotation)
        local p2 = (polygon1.points[j] + polygon1.pos):rotate(polygon1.rotation)
        table.insert(normals, vec(-(p2.y-p1.y), p2.x-p1.x):norm())
    end
    for i, normal in pairs(normals) do
        local x1, x2 = calcProjection(normal, polygon1.points, polygon1.pos, polygon1.rotation)
        local y1, y2 = calcProjection(normal, polygon2.points, polygon2.pos, polygon2.rotation)
        -- check if *not* overlap in the axis
        if not segmentOverlap(x1, x2, y1, y2) then
            -- not overlap! === no collision
            return false
        end -- else we have to keep checking
    end
    return true -- all axis overlap
end
-- Calculate projection of polygon (as points) into axis (as its normal)
-- points are referenced from a point inside of the polygon
-- so the global position must be computed from a position and a rotation
function calcProjection(normal, points, pos, rotation)
    local min = normal:dot(points[1]:clone():rotate(rotation) + pos)
    local max = min
    for i = 2, #points do
        local p = normal:dot(points[i]:clone():rotate(rotation) + pos)
        if p < min then 
            min = p
        elseif p > max then
            max = p
        end
    end
    return min, max
end
function ellipse(angle, a, b)
    local x = a*math.sin(angle)
    local y = b*math.cos(angle)
    return vec(x, y)
end
-- Spawn an asteroid with random values
function spawnInitialAsteroid()
    -- Make a random position outside a circle centered at player start position and radius 100 
    local pos = player.startPos + vec.fromAngle(math.random()*2*math.pi)*(100 + math.random()*(world.width/2 - 100))
    local speed = vec.fromAngle(math.random()*2*math.pi):setmag(10 + math.random()*140)
    local ang_speed = math.random()*math.pi
    spawnAsteroid(pos, speed, ang_speed, 1 + math.floor(math.random()*3))
end
function asteroidRadius(category)
    local min, max = asteroidTotalMinimumRadius, asteroidTotalMaximumRadius
    max = min + (max - min)*category/asteroidNumCategories
    local b = min + math.random()*(max - min)
    local a = b + math.random()*(max - b)
    return a, b
end
function spawnAsteroid(pos, speed, ang_speed, category)
    -- semi-major and semi-minor axis of the ellipse
    local a, b = asteroidRadius(category)
    local angle_points = {}
    for i = 1, math.random(7, 13) do
        table.insert(angle_points, math.random()*2*math.pi)
    end
    table.sort(angle_points)
    local points = {}
    for i, p in pairs(angle_points) do
        local point = ellipse(p, a, b)
        table.insert(points, point)
    end 
    table.insert(asteroids, { pos = pos, speed = speed, maxRadius = a,
    rotation = 0, ang_speed = ang_speed, points = points, 
    hit = false, category = category, numberOfHits = 0 })
end
function startNewGame()
    player.pos = player.startPos
    player.rotation = 0
    player.speed = vec(0, 0)
    player.isAlive = true
    player.score = 0
    bullets = {}
    asteroids = {}
    explosions = {}
    spawnInitialAsteroids()
end
function spawnInitialAsteroids()
    for i = 1,asteroidInitialCount do
        spawnInitialAsteroid()
    end
    asteroidCount = asteroidInitialCount
end
function drawPlayer(pos, rotation)
    drawPolygon(vec(pos.x % world.width, pos.y % world.height), rotation, playerPolygonPoints, {r = 0, g = 0.25, b = 0.75})
end
function drawAsteroid(pos, asteroid)
    -- blink alterning fill and line modes
    local blinkTime = asteroidHitTimerMax / (2*asteroidBlinkTimes - 1)
    local asteroidBlink = asteroid.hit and (asteroid.hitTimer % (2*blinkTime)) <= blinkTime
    local mode = asteroidBlink and 'fill' or 'line'
    local color = asteroidBlink and asteroidColors[math.random(2, #asteroidColors)] or asteroidColors[1]
    drawPolygon(vec(pos.x % world.width, pos.y % world.height), asteroid.rotation, asteroid.points, color, mode)
end
function drawBullet(pos, rotation)
    drawPolygon(vec(pos.x % world.width, pos.y % world.height), rotation, bulletPolygonPoints, {r = 1, g = 1, b = 1}, 'fill')
end
function drawPolygon(pos, rotation, points, color, mode)
    mode = mode or 'line'
    love.graphics.setColor(color.r, color.g, color.b)
    local vertices = {}
    for i, p in ipairs(points) do
        local pp = p:clone():rotate(rotation) + pos
        table.insert(vertices, pp.x)
        table.insert(vertices, pp.y)
    end
    love.graphics.polygon(mode, vertices)
end
function playRandomExplosionSound()
    explosionSounds[math.random(1, #explosionSounds)]:clone():play()
end
function playRandomHitSound()
    hitSounds[math.random(1, #hitSounds)]:clone():play()
end

function love.load()
    math.randomseed(100)
    initViewport()
    shootSound = love.audio.newSource('sounds/laser.wav', 'static')
    backgroundSound = love.audio.newSource('sounds/background-noise.wav', 'static')
    backgroundSound:setLooping(true)
    backgroundSound:play()
    love.graphics.setLineWidth(2)
    for i = 1, 5 do
        local explosionSound = love.audio.newSource(string.format('sounds/explosion%d.wav', i), 'static')
        local hitSound = love.audio.newSource(string.format('sounds/hit%d.wav', i), 'static')
        table.insert(explosionSounds, explosionSound)
        table.insert(hitSounds, hitSound)
    end
    loseSound = love.audio.newSource('sounds/lose.wav', 'static')
    -- particle system for explosion effects
    local explosionImageData = love.image.newImageData(3, 3)
    for i = 0, 2 do
        for j = 0, 2 do
            explosionImageData:setPixel(i, j, 0.95, 1, 0.07, 1)
        end
    end
    explosionParticle = love.graphics.newImage(explosionImageData)
    initExplosionSystems()
    startNewGame()
end

function spawnHitExplosion(pos, speed)
    local explosionSystem = hitExplosionSystem:clone()
    table.insert(explosions, { pos = pos:clone(), speed = speed, system = explosionSystem})
    explosionSystem:emit(32)
end
function spawnAsteroidExplosion(pos, speed)
    local explosionSystem = asteroidExplosionSystem:clone()
    table.insert(explosions, { pos = pos:clone(), speed = speed, system = explosionSystem})
    explosionSystem:emit(256)
end

function initExplosionSystems()
    hitExplosionSystem = love.graphics.newParticleSystem(explosionParticle, 16)
    hitExplosionSystem:setParticleLifetime(0.75, 1.75)
    hitExplosionSystem:setEmitterLifetime(0.25)
    hitExplosionSystem:setEmissionRate(5)
    hitExplosionSystem:setSizeVariation(1)
    hitExplosionSystem:setLinearAcceleration(-20, -20, 20, 20)
    hitExplosionSystem:setColors(1, 1, 1, 1, 1, 1, 1, 0)

    asteroidExplosionSystem = love.graphics.newParticleSystem(explosionParticle, 16)
    asteroidExplosionSystem:setParticleLifetime(1, 2)
    asteroidExplosionSystem:setEmitterLifetime(0.5)
    asteroidExplosionSystem:setEmissionRate(512)
    asteroidExplosionSystem:setSizeVariation(0)
    asteroidExplosionSystem:setLinearAcceleration(-20, -20, 20, 20)
    asteroidExplosionSystem:setSpeed(400, 700)
    asteroidExplosionSystem:setSpread(2*math.pi)
    asteroidExplosionSystem:setColors(1, 1, 1, 1, 1, 1, 1, 0)
end

function love.update(dt)
    if love.keyboard.isDown('escape') then
        love.event.push('quit')
    end
    if not player.isAlive then
        if love.keyboard.isDown('r') then
            startNewGame()
        else
            return
        end
    end
    if love.keyboard.isDown('w','up') then
        player.speed = player.speed + vec.fromAngle(player.rotation)*100*dt
    else
        player.speed = player.speed - player.speed:clone():setmag(25)*dt
    end
    if love.keyboard.isDown('d','right') then
        player.rotation = player.rotation - 2*dt
    elseif love.keyboard.isDown('a','left') then
        player.rotation = player.rotation + 2*dt
    end
    -- shoot
    if love.keyboard.isDown('space') and bulletTimer == 0 then
        bulletCounter = bulletCounter + 1
        local m = math.random(3,9)
        local ds = vec(player.pos.y, -player.pos.x):norm() * m * (bulletCounter % 2 == 0 and 1 or -1)
        local bullet = { pos = vecInWorld(player.pos + ds), speed = vec.fromAngle(player.rotation)*300, rotation = player.rotation, live = 0 }
        table.insert(bullets, bullet)
        shootSound:clone():play()
        bulletTimer = bulletTimerMax
    end
    player.speed:limit(250)
    player.rotation = player.rotation % (2*math.pi)
    -- update position according speed
    player.pos = vecInWorld(player.pos + player.speed*dt)
    -- asteroids
    for i = #asteroids, 1, -1 do
        asteroid = asteroids[i]
        asteroid.pos = vecInWorld(asteroid.pos + asteroid.speed*dt)
        asteroid.rotation = (asteroid.rotation + asteroid.ang_speed*dt) % (2*math.pi)

        -- asteroid hit in the recent time?
        if asteroid.hit then
            asteroid.hitTimer = asteroid.hitTimer - dt -- update countdown timer
            if asteroid.hitTimer <= 0 then
                asteroid.hit = false -- deactivate hit state
                -- reached hits needed to break/destroy the asteroid?
                if asteroid.numberOfHits >= 1 + math.floor(asteroid.category * 1.5) then
                    asteroidCount = asteroidCount - 1
                    playRandomExplosionSound()
                    spawnAsteroidExplosion(asteroid.pos, vec(0, 0))
                    player.score = player.score + asteroid.category * 10
                    table.remove(asteroids, i)
                    if asteroid.category > 1 then -- split new smaller asteroids
                        local numAsteroids = asteroid.category
                        asteroidCount = asteroidCount + numAsteroids
                        for j = 1, numAsteroids do
                            local ang = 3*math.pi/8 + math.random(2*math.pi - 2*3*math.pi/8)
                            local mag = asteroid.speed:getmag()*(math.random()*0.75 + 1.5)
                            local speed = asteroid.speed:clone():norm():rotate(ang)*mag
                            spawnAsteroid(vecInWorld(asteroid.pos + speed*0.25), speed, math.random()*math.pi*1.5, asteroid.category - 1)
                        end
                    end
                end
            end
        end
    end
    -- bullets
    bulletTimer = clamp(bulletTimer - dt, 0, bulletTimerMax)
    for i, bullet in pairs(bullets) do
        bullet.live = bullet.live + dt
        if bullet.live > 2.5 then
            table.remove(bullets, i)
        end
        bullet.pos = vecInWorld(bullet.pos + bullet.speed*dt)
    end
    -- Check collisions
    for i, asteroid in pairs(asteroids) do
        if checkCollisionSAT(asteroid, { pos = player.pos, rotation = player.rotation, points = playerPolygonPoints }) then
            -- collision asteroid x player
            player.isAlive = false
            loseSound:play()
        end
        for i, bullet in pairs(bullets) do
            if checkCollisionSAT(asteroid, { pos = bullet.pos, rotation = bullet.rotation, points = bulletPolygonPoints }) then
                -- collision bullet x asteroid
                playRandomHitSound()
                spawnHitExplosion(bullet.pos, asteroid.speed)
                table.remove(bullets, i)
                player.score = player.score + 5
                asteroid.hit = true
                asteroid.numberOfHits = asteroid.numberOfHits + 1
                if asteroid.numberOfHits <= 1 + math.floor(asteroid.category * 1.5) then
                    asteroid.hitTimer = asteroidHitTimerMax
                end
            end
        end
    end
    -- effects of explosions 
    for i = #explosions, 1, -1 do
        local explosion = explosions[i]
        explosion.system:update(dt)
        explosion.pos = vecInWorld(explosion.pos + explosion.speed*dt)
        if explosion.system:getCount() == 0 then
            table.remove(explosions, i)
        end
    end
    updateViewport(dt)
end

function love.draw(dt)
    if not player.isAlive then
        love.graphics.setColor(0.75, 0, 0)
        love.graphics.print('Died! Press R to start again!',
        love.graphics.getWidth()/2 - 250,
        love.graphics.getHeight()/2 - 100,
        0, 2.5)
    end
    love.graphics.setColor(1, 0.75, 0)
    love.graphics.print(string.format("Score: %d", player.score), 0, 0, 0, 1.5)
    love.graphics.print(string.format("Asteroids: %d", asteroidCount), 0, 20, 0, 1.5)
    drawPlayer(toScreen(player.pos), player.rotation)
    for i, asteroid in pairs(asteroids) do
        local ds = isVisibleAsteroid(asteroid)
        if ds then
            drawAsteroid(toScreen(asteroid.pos + ds), asteroid)
        end
    end
    for i, bullet in pairs(bullets) do
        drawBullet(toScreen(bullet.pos), bullet.rotation)
    end
    for i, explosion in pairs(explosions) do
        local explosionPos = toScreen(explosion.pos)
        love.graphics.draw(explosion.system, explosionPos.x, explosionPos.y)
    end
end

