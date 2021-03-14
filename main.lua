local vec = require('vector')
world = { width = 2000, height = 2000 }

-- player is a triangle, centered
function drawPlayer(x, y, rotation) 
    love.graphics.setColor(0, 0.25, 0.75)
    local p1 = vec(x,y) + vec(-15,-15):rotate(rotation)
    local p2 = vec(x,y) + vec(25,0):rotate(rotation)
    local p3 = vec(x,y) + vec(-15,15):rotate(rotation)
    love.graphics.line(p1.x,p1.y,p2.x,p2.y,p3.x,p3.y,p1.x,p1.y)
end
player = { pos = vec(400, 400), speed = vec(0, 0), rotation = 0 }
asteroids = {}
bullets = {}

function lerp(start, finish, percentage)
    return start + (finish - start) * percentage
end
function clamp(val, min, max) return (val < min) and min or (val > max) and max or val end

function spawnAsteroid()
    local pos = vec(400, 400) + vec.fromAngle(math.random()*2*math.pi)*(100 + math.random()*500)
    local speed = vec.fromAngle(math.random()*2*math.pi):setmag(10 + math.random()*140)
    local ang_speed = math.random()*math.pi
    local radius = 20 + math.random()*35
    local num_corners = math.random(3, 7)
    local corners = {}
    for i = 1, num_corners do
	local v = vec.fromAngle(i*2*math.pi/num_corners)*radius
	table.insert(corners, v)
    end	
    table.insert(asteroids, { pos = pos, speed = speed, rotation = 0, ang_speed = ang_speed, corners = corners })
end
function drawAsteroid(x, y, rotation, corners)
    love.graphics.setColor(0.5,0.75,0)
    local pos = vec(x, y)
    local first_point = pos + corners[1]:clone():rotate(rotation)
    local before_point = first_point 
    for i = 2, #corners do
	local point = pos + corners[i]:clone():rotate(rotation)
	love.graphics.line(before_point.x, before_point.y, point.x, point.y)
	before_point = point
    end
    local last_point = pos + corners[#corners]:clone():rotate(rotation)
    love.graphics.line(last_point.x, last_point.y, first_point.x, first_point.y)
end

function love.load()
    math.randomseed(100)
    for i = 1,10 do
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
end

function love.draw(dt)
    drawPlayer(player.pos.x, player.pos.y, player.rotation)
    for i, asteroid in pairs(asteroids) do
	drawAsteroid(asteroid.pos.x, asteroid.pos.y, asteroid.rotation, asteroid.corners)
    end
end

