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
asteroids = {}
bullets = {}

bulletTimerMax = 0.25
bulletTimer = 0
bulletPolygonPoints = { vec(-2,-1), vec(2,-1), vec(2, 1), vec(-2,1)  }

asteroidHitTimerMax = 0.75
asteroidHits = {}

-- sounds
shoot = nil

function lerp(start, finish, percentage)
    return start + (finish - start) * percentage
end
function clamp(val, min, max) return (val < min) and min or (val > max) and max or val end

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
	-- read as: if x1 inside y; x2 inside y ...
	if not ((x1 > y1 and x1 < y2) or (x2 > y1 and x2 < y2)
	or (y1 > x1 and y1 < x2)) then
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
    local pos = player.startPos + vec.fromAngle(math.random()*2*math.pi)*(100 + math.random()*500)
    local speed = vec.fromAngle(math.random()*2*math.pi):setmag(10 + math.random()*140)
    local ang_speed = math.random()*math.pi
    spawnAsteroid(pos, speed, ang_speed, 1 + math.floor(math.random()*3))
end
function asteroidRadius(category)
    local min, max = 25, 60
    max = 25 + (60 - 25)*category/3
    local a = min + math.random()*(max - min)
    local b = a + math.random()*(max - a)
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
    table.insert(asteroids, { pos = pos, speed = speed, rotation = 0, ang_speed = ang_speed, points = points, hit = false, category = category, numberOfHits = 0 })
end
function startNewGame()
    player.pos = player.startPos
    player.rotation = 0
    player.speed = vec(0, 0)
    player.isAlive = true
    player.score = 0
    bullets = {}
    asteroids = {}
    spawnInitialAsteroids()
end
function spawnInitialAsteroids()
    for i = 1,20 do
        spawnInitialAsteroid()
    end
end
function drawPlayer(x, y, rotation)
    drawPolygon(x, y, rotation, playerPolygonPoints, {r = 0, g = 0.25, b = 0.75})
end
function drawAsteroid(cam, asteroid)
    -- blink alterning fill and line modes
    local mode = asteroid.hit and (asteroid.hitTimer % 0.2) < 0.1 and 'fill' or 'line'
    drawPolygon(asteroid.pos.x - cam.x, asteroid.pos.y - cam.y,
                asteroid.rotation, asteroid.points, {r = 0.5, g = 0.75, b = 0},
		mode)
end
function drawBullet(x, y, rotation)
    drawPolygon(x, y, rotation, bulletPolygonPoints, {r = 1, g = 1, b = 1})
end
function drawPolygon(x, y, rotation, points, color, mode)
    mode = mode or 'line'
    love.graphics.setColor(color.r, color.g, color.b)
    local pos = vec(x, y)
    local vertices = {}
    for i, p in ipairs(points) do
	local pp = p:clone():rotate(rotation) + pos
	table.insert(vertices, pp.x)
	table.insert(vertices, pp.y)
    end
    love.graphics.polygon(mode, vertices)
end

function love.load()
    math.randomseed(100)
    shoot = love.audio.newSource('sounds/laser.wav', 'static')
    shoot:setVolume(0.1)
    startNewGame()
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
	local bullet = { pos = player.pos:clone(), speed = vec.fromAngle(player.rotation)*300, rotation = player.rotation, live = 0 }
	table.insert(bullets, bullet)
	shoot:play()
	bulletTimer = bulletTimerMax
    end
    player.speed:limit(250)
    player.rotation = player.rotation % (2*math.pi)
    -- update position according speed
    player.pos = player.pos + player.speed*dt
    player.pos.x = player.pos.x % world.width
    player.pos.y = player.pos.y % world.height
    -- asteroids
    for i = #asteroids, 1, -1 do
	asteroid = asteroids[i]
        asteroid.pos = asteroid.pos + asteroid.speed*dt
	asteroid.rotation = (asteroid.rotation + asteroid.ang_speed*dt) % (2*math.pi)
	asteroid.pos.x = asteroid.pos.x % world.width
	asteroid.pos.y = asteroid.pos.y % world.height

	-- asteroid hit in the recent time?
	if asteroid.hit then
	    asteroid.hitTimer = asteroid.hitTimer - dt -- update countdown timer
	    if asteroid.hitTimer <= 0 then
		asteroid.hit = false -- deactivate hit state
                -- reached hits needed to break/destroy the asteroid?
		if asteroid.numberOfHits >= 1 + math.floor(asteroid.category * 1.5) then
		    player.score = player.score + asteroid.category * 10
		    table.remove(asteroids, i)
		    if asteroid.category > 1 then -- split new smaller asteroids
			local numAsteroids = asteroid.category
			for j = 1, numAsteroids do
			    local ang = 3*math.pi/8 + math.random(2*math.pi - 2*3*math.pi/8)
			    local mag = asteroid.speed:getmag()*(math.random()*0.75 + 1.5)
			    local speed = asteroid.speed:clone():norm():rotate(ang)*mag
			    spawnAsteroid(asteroid.pos + speed*0.25, speed, math.random()*math.pi*1.5, asteroid.category - 1)
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
        bullet.pos = bullet.pos + bullet.speed*dt
	bullet.pos.x = bullet.pos.x % world.width
	bullet.pos.y = bullet.pos.y % world.height
    end
    -- Check collisions
    for i, asteroid in pairs(asteroids) do
	if checkCollisionSAT(asteroid, { pos = player.pos, rotation = player.rotation, points = playerPolygonPoints }) then
	    -- collision asteroid x player
	    player.isAlive = false
	end
	for i, bullet in pairs(bullets) do
	    if checkCollisionSAT(asteroid, { pos = bullet.pos, rotation = bullet.rotation, points = bulletPolygonPoints }) then
		-- collision bullet x asteroid
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
    local cam = vec(-400, -400) + player.pos:clone()
    drawPlayer(player.pos.x - cam.x, player.pos.y - cam.y, player.rotation)
    for i, asteroid in pairs(asteroids) do
	drawAsteroid(cam, asteroid) 
    end
    for i, bullet in pairs(bullets) do
        drawBullet(bullet.pos.x - cam.x, bullet.pos.y - cam.y, bullet.rotation)
    end
end

