local vec = require('vector')
world = { width = 2000, height = 2000 }

playerPolygonPoints = { vec(-15,-15), vec(25,0), vec(-15,15) }
-- player is a triangle, a bit centered
player = { pos = vec(400, 400), speed = vec(0, 0), rotation = 0 }
asteroids = {}
bullets = {}

function lerp(start, finish, percentage)
    return start + (finish - start) * percentage
end
function clamp(val, min, max) return (val < min) and min or (val > max) and max or val end

-- Polygon collision testing using SAT theorem
-- polygon = { pos, points }
function checkCollisionSAT(polygon1, polygon2)
    local normals = {}
    for i = 1, #polygon1.points do
	local j = (i % #polygon1.points) + 1
	local p1 = polygon1.points[i] + polygon1.pos
	local p2 = polygon1.points[j] + polygon1.pos
	table.insert(normals, vec(-(p2.y-p1.y), p2.x-p1.x):norm())
    end
    for i, normal in pairs(normals) do
	local x1, x2 = calcProjection(normal, polygon1.points, polygon1.pos)
	local y1, y2 = calcProjection(normal, polygon2.points, polygon2.pos)
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
-- pos is offset position of polygon, so each point is actually the sum of both
function calcProjection(normal, points, pos)
    local min = normal:dot(points[1] + pos)
    local max = min
    for i = 2, #points do
	local p = normal:dot(points[i] + pos)
	if p < min then 
	    min = p
	elseif p > max then
	    max = p
        end
    end
    return min, max
end
-- Spawn an asteroid with random values
function spawnAsteroid()
    -- Make a random position outside a circle centered at (400,400) and radius 100 
    local pos = vec(400, 400) + vec.fromAngle(math.random()*2*math.pi)*(100 + math.random()*500)
    local speed = vec.fromAngle(math.random()*2*math.pi):setmag(10 + math.random()*140)
    local ang_speed = math.random()*math.pi
    local radius = 20 + math.random()*35
    local num_points = math.random(3, 7)
    local points = {}
    for i = 1, num_points do
	local v = vec.fromAngle(i*2*math.pi/num_points)*radius
	table.insert(points, v)
    end	
    table.insert(asteroids, { pos = pos, speed = speed, rotation = 0, ang_speed = ang_speed, points = points })
end
function drawPlayer(x, y, rotation)
    drawPolygon(x, y, rotation, playerPolygonPoints, {r = 0, g = 0.25, b = 0.75})
end
function drawAsteroid(x, y, rotation, points)
    drawPolygon(x, y, rotation, points, {r = 0.5, g = 0.75, b = 0})
end
function drawPolygon(x, y, rotation, points, color)
    love.graphics.setColor(color.r, color.g, color.b)
    local pos = vec(x, y)
    local first_point = pos + points[1]:clone():rotate(rotation)
    local before_point = first_point 
    for i = 2, #points do
	local point = pos + points[i]:clone():rotate(rotation)
	love.graphics.line(before_point.x, before_point.y, point.x, point.y)
	before_point = point
    end
    local last_point = pos + points[#points]:clone():rotate(rotation)
    love.graphics.line(last_point.x, last_point.y, first_point.x, first_point.y)
end

function love.load()
    math.randomseed(100)
    for i = 1,20 do
        spawnAsteroid()
    end
end

function love.update(dt)
    if love.keyboard.isDown('escape') then
	love.event.push('quit')
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
    player.speed:limit(250)
    player.rotation = player.rotation % (2*math.pi)
    -- update position according speed
    player.pos = player.pos + player.speed*dt
    player.pos.x = player.pos.x % world.width
    player.pos.y = player.pos.y % world.height
    -- asteroids
    for i, asteroid in pairs(asteroids) do
        asteroid.pos = asteroid.pos + asteroid.speed*dt
	asteroid.rotation = (asteroid.rotation + asteroid.ang_speed*dt) % (2*math.pi)
	asteroid.pos.x = asteroid.pos.x % world.width
	asteroid.pos.y = asteroid.pos.y % world.height
    end
    -- Check collisions
    for i, asteroid in pairs(asteroids) do
	if checkCollisionSAT(asteroid, { pos = player.pos, points = playerPolygonPoints }) then
	    print('collision with player!')
	end
    end
end

function love.draw(dt)
    local camPosition = vec(-400, -400) + player.pos:clone()
    drawPlayer(player.pos.x - camPosition.x, player.pos.y - camPosition.y, player.rotation)
    for i, asteroid in pairs(asteroids) do
	drawAsteroid(asteroid.pos.x - camPosition.x, asteroid.pos.y - camPosition.y, 
		     asteroid.rotation, asteroid.points)
    end
end

