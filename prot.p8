pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-- main --

-- y points down
-- x points right
gravity = -.3
max_air_vel = 7
cmr_lim = 32

block_width = 8

front = 1
inside = 2
backface = 3
front_far = 4
single = 14

NIL = -1

-- game state --
--[[
    let's think about the map. it must be easily iterable and I should be
    able to access block's neighbors quickly (given the same x and y coords)

    solution #1 - two tables:

    - flat list of object's meta data, e.g. position, sprite, etc
    - lookup table <uniqid>: 1st list index

    pros:
    - easy to build, reason about. especially if unique id works out
    cons:
    - two structures

    solutions #2 - one table:

    { [z]:[y]:[y]:object }

    this sucks - too complicated

    solution #3 - two tables

    - flat list, see #1
    - 3-dimensional array with indices, refs to the fist list

    pros:
    - simplicity
    - can quickly find neigbors
    - can quickly find object at specific world position

    this one seems the best for now
]]

collision_map = {} -- static object list

--[[
   ---------  slice n - 1
   ---------  slice n
       ^
       |
     camera
]]

world_positions = {} -- <x, y, z>: idx>
objects = {}
lookup = {}
function lookup.__index(self, i) return self.proto[i] end

-- controls
btn_jump = 2
btn_slice = 4
prev_slice_btn_state = false
prev_jmp_state = false
prev_o_button_state = false

function _init()
    -- fill map with nils to avoid unnecessary checks later
    for z=0, lr_h - 1 do
        world_positions[z] = {}
        for y = 0, lr_count - 1 do
            world_positions[z][y] = {}
            for x = 0, lr_w - 1 do
                world_positions[z][y][x] = NIL
            end
        end
    end

    i_lvl()
    i_plr()
    camera = { x = 0, 0 }
end


function _update()
    u_plr()
    u_camera()
end


function draw_dithered_gradient()
end


function _draw()
    cls()

    draw_dithered_gradient()

    -- for r=1, max_radius do
    --     draw_dithered_circle(64, 64, r)
    -- end
    d_lvl(camera.x, camera.y) -- todo: pass camera
    d_plr(camera)

    display_debug_info()
end

function display_debug_info()
    local cpu_load = stat(1) * 100
    local memory_used = stat(0) * 4

    print(
        "CPU: " .. flr(cpu_load) .. "% "
                .. "RAM: " .. memory_used .. " bytes", 0, 0, 7
    )
    print("SLICE: " .. plr.z + 1, 0, 7, 7)
    print("PLR: " .. tostring(plr.on_ground) .. " " .. plr.vel_y, 0, 14, 7)
end

function u_camera()
    -- if btn(➡️) then
    -- 	camera.x = min(camera.x+1, cmr_lim)
    -- end
    -- if btn(⬅️) then
    -- 	camera.x = max(camera.x-1, -cmr_lim)
    -- end
end



-->8
-- player --
local frames_since_jump = 0
local player_x_velocity = 1.4
local state = {
    -- state enum
    IDLE = 0,
    RUN = 1,
    JUMP = 2,
    FALL = 3
}

local animations = {
    [state.IDLE] = { 48, 2, 2 },
    [state.RUN] = { 53, 4, 6 },
    [state.FALL] = { 50, 2, 4 },
    [state.JUMP] = { 50, 1, 1 }
}

function i_plr()
    plr = create_obj(48, 0, 0, 0)

    plr.coll_h = 8
    plr.sprt_idx = 48
    plr.state = IDLE
    plr.on_ground = false
end

function get_plr_state()
    if not plr.on_ground and plr.vel_y < 0 then
        return state.JUMP
    elseif not plr.on_ground then
        return state.FALL
    elseif plr.vel_x ~= 0 then
        return state.RUN
    else
        return state.IDLE
    end
end

function u_slice()
    local current_slice_btn_state = btn(btn_slice)
    if current_slice_btn_state and not prev_slice_btn_state then
        plr.z = (plr.z - 1) % lr_h
    end

    prev_slice_btn_state = current_slice_btn_state

    -- local current_o_button_state = btn(4)
    -- if current_o_button_state and not prev_o_button_state then
    --     plr.z = (plr.z - 1) % lr_h
    -- end

    -- prev_o_button_state = current_o_button_state
end

function u_plr()
    plr.on_ground = collides(plr, 0, 1)

    if not plr.on_ground then
        plr.vel_y -= gravity
        plr.vel_y = min(plr.vel_y, max_air_vel)
    else
        -- plr.vel_y = 0
    end

    -- controls --
    if btn(➡️) then
        plr.proto.vel_x = player_x_velocity
        plr.proto.f_y = false
    elseif btn(⬅️) then
        plr.proto.vel_x = -player_x_velocity
        plr.proto.f_y = true
    else
        plr.proto.vel_x = 0
    end

    u_slice()

    -- SECTION: jump
    local current_jmp_state = btn(btn_jump)
    if current_jmp_state then
        if frames_since_jump < 4 then
            plr.vel_y = -3.5 -- jump velocity
        end

        if not prev_jmp_state then
            frames_since_jump = 0
        end
    end

    prev_jmp_state = current_jmp_state
    frames_since_jump += 1
    -- SECTION_END: jump

    move_obj_x(plr, plr.vel_x)
    move_obj_y(
        plr, plr.vel_y, function()
            plr.vel_y = 0
        end
    )

    -- reset position
    if plr.y > 200 then plr.y = 0 end
    if plr.x >= 127 then plr.x = -7 end
    if plr.x < -7 then plr.x = 127 end

    plr.state = get_plr_state()

    local animation = animations[plr.state]
    plr.sprt = animation[1] + time() * animation[3] % animation[2]
end

function draw_player_collider(obj)
    rect(
        obj.x + obj.coll_x, obj.y + obj.coll_y,
        obj.x + obj.coll_x + obj.coll_w, obj.y + obj.coll_y + obj.coll_h,
        11
    )
end

function d_plr(camera)
    spr(
        plr.sprt,
        plr.x - camera.x, plr.y,
        1, 1,
        plr.proto.f_y
    )
    -- draw_player_collider(plr)
end

-->8
-- collisiions --

function collides(o, dx, dy)
    dx = dx or 0
    dy = dy or 0

    local top = o.y + o.coll_y
    local btm = top + o.coll_h - 1
    local left = o.x + o.coll_x
    local right = o.x + o.coll_x + o.coll_w - 1
    local corners = {
        -- top-left
        { left, top },
        -- top-right
        { right, top },
        -- bottom-left
        { left, btm },
        -- bottom-right
        { right, btm }
    }

    printh("l: " .. corners[1][1] .. ", " .. corners[1][2]
            .. " -- r: " .. corners[2][1] .. ", " .. corners[2][2])

    for i, corner in ipairs(corners) do
        -- these are world positions, represented in sprite positions
        -- e.g. squares of 8x8
        local target_point_x = flr((corner[1] + dx) / 8)
        local target_point_y = flr((corner[2] + dy) / 8)
        local target_point_z = plr.z

        -- CLEANUP: one of the places to improve performance if
        -- needed later
        for k, entry in pairs(collision_map) do
            if entry.x == target_point_x
                    and entry.y == target_point_y
                    and entry.z == target_point_z then
                return true
            end
        end
    end

    return false
end

-->8
--level--
lr_count = 16

lr_w = 16
lr_h = 8

function create_layer()
    local layer = {}

    for x = 1, lr_w do
        layer[x] = {}
        for i = 1, lr_h do
            layer[x][i] = 14
        end
    end

    return layer
end

function make_obj_key(x, y, z)
    local key = ""
    return key .. "" .. x .. "-" .. y .. "-" .. z
end

function add_block(x, y, z, idx)
    -- printh("add_block - x: "..x ..", y:"..y..", z:"..z)
    world_positions[z][y][x] = idx
end

function get_block(x, y, z)
    -- printh("get_block - x: "..x ..", y:"..y..", z:"..z)
    if world_positions[z][y] == nil then
        return nil
    end

    local out = world_positions[z][y][x]

    if out ~= NIL then
        return out
    else
        return nil
    end
end


function prc_layer(li)
    --[[
        0 1 2 3       {{0, 4, 5}
        4 x x 5  -->   {1, x, 7}
        6 7 8 9        {2, x, 8}
                       {3, 5, 9}}
    ]]
    local layer = create_layer()

    for x = 0, lr_w - 1 do
        for y = 0, lr_h - 1 do
            local pi = y * lr_w + x
            local pxl = get_layer_pxl(li, pi)

            layer[x + 1][y + 1] = pxl
        end
    end

    -- write world positions
    -- y from layer index
    local y = 15 - li
    -- from 0 to

    local list_idx = 0
    -- x from col_idx coords of the texture
    -- z from y coords of the texture
    for x = 0, lr_w - 1 do
        -- for each column
        for z = 0, lr_h - 1 do
            local obj_key = make_obj_key(x, y, z)

            local pixel_data = layer[x + 1][z + 1]

            -- printh(obj_key)

            if pixel_data ~= 0 then
                -- todo: proper spirte ?? sprite optional
                add(collision_map, create_obj(1, x, y, z))

                add_block(x, y, z, list_idx)

                list_idx += 1
            end
        end
    end
end

function i_lvl()
    -- local pxl=get_sprt_pxl(64,0)

    for li = 0, lr_count - 1 do
        prc_layer(li)
    end
end

local scr_btm = 128
local colors_by_depth = {
    6,
    13
}

function d_lvl(cmr_x, cmr_y)
    -- process current slice
    local front_slice_idx = (plr.z + 1) % lr_h
    local back_slice_idx = (plr.z - 1) % lr_h
    local back_slice_idx_2 = (plr.z - 2) % lr_h

    -- each cell of the current slice
    for y, row in pairs(world_positions[plr.z]) do
        for x, obj_idx in pairs(row) do
            local pos_x = x * 8
            local pos_y = y * 8

            -- next
            if obj_idx == NIL and get_block(x, y, back_slice_idx) ~= nil then
                printh("hello")
                spr(37, pos_x, pos_y)

            -- last block
            elseif (
                obj_idx ~= NIL and
                get_block(x, y, back_slice_idx) == nil and
                get_block(x, y, front_slice_idx) ~= nil
            ) then
                spr(35, pos_x, pos_y)
            -- in slice
            elseif (
                obj_idx ~= NIL and
                get_block(x, y, back_slice_idx) ~= nil and
                get_block(x, y, front_slice_idx) ~= nil
            ) then
                spr(34, pos_x, pos_y)
            -- only curr
            elseif obj_idx ~= NIL then
                spr(33, pos_x, pos_y)
            end
        end
    end

end

local lvl_start_x = 0 --level start x on the spritesheet
local lvl_start_y = 32 --level start x on the spritesheet

-- read pixel data from layer
function get_layer_pxl(li, pi)
    local sy = lvl_start_y + li * 8
    --map start y

    local px = lvl_start_x + pi % lr_w
    local py = sy + flr(pi / lr_w)

    return sget(px, py)
end

-->8
-- object --

-- declaring object base --
object = {}
object.vel_x = 0
object.vel_y = 0
object.remainder_x = 0
object.remainder_y = 0
-- collider --
object.coll_x = 0
object.coll_y = 0
object.coll_w = 8
object.coll_h = 8
object.f_y = 1

function create_obj(sprt, x, y, z)
    local obj = {}
    obj.proto = object
    obj.sprt = sprt

    obj.x = x
    obj.y = y
    obj.z = z

    setmetatable(obj, lookup)
    add(objects, obj)

    return obj
end

function move_obj_x(o, x, collide_cb)
    print(x, 10, 10)
    o.remainder_x += x

    local int_mv_delta = flr(o.remainder_x + .5)
    -- mx == floor(1.9)
    o.remainder_x -= int_mv_delta
    -- remainder becomes .9

    local total = int_mv_delta
    -- total distance to travel 1
    local mxs = sgn(int_mv_delta)
    -- movement direction
    while int_mv_delta != 0 do
        if collides(o, mxs, 0) then
            if collide_cb ~= nil then collide_cb() end
            return true
        else
            o.x += mxs -- move by 1 pixel
            int_mv_delta -= mxs
        end
    end

    return false
end

function move_obj_y(o, y, collide_cb)
    o.remainder_y += y
    local int_y_delta = flr(o.remainder_y + .5)
    o.remainder_y -= int_y_delta

    local total = int_y_delta
    local mys = sgn(int_y_delta)
    while int_y_delta != 0 do
        if collides(o, 0, mys) then
            collide_cb()
            return true
        else
            o.y += mys -- move by 1 pixel
            int_y_delta -= mys
        end
    end

    return false
end

__gfx__
000000000666606606600660666666660dddd0dd0000000000000000000000000dddd0dd0d00ddd0077777700000000000000000000000000000000000000000
00000000666600606600660060000006dddd00d0000000000000000000000000dddd00d0d00ddd00777777000000000000000000000000000000000000000000
00000000600060606006600660000006d000d0d0000000000000000000000000d000d0d0000d0000700000000000000000000000000000000000000000000000
00000000000000000066006660000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000600666006600660600000060d00ddd00000000000000000000000000d00ddd00dddd0d0000000000000000000000000000000000000000000000000
00000000000666006600660060000006000ddd00000000000000000000000000000ddd000dd000dd000000000000000000000000000000000000000000000000
00000000600600006006600660000006d00d0000000000000000000000000000d00d00000d0000dd000000000000000000000000000000000000000000000000
000000000000000b00660069666666680000000b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001111110011111100000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011000011110000110000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010011111111110010000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010100000000001010000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010100000000001010000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010100000000001010000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011100000000001110000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001100000000001100000000000000000000000000000000000000000000000000000000000000000
00000000066666600666666006666660000000000111111001100000000001101100001100000000000000000000000000000000000000000000000000000000
00000000660000666606006666000066000000001100001110100000000001011000000100000000000000000000000000000000000000000000000000000000
00000000600660066060060660011006000000001001100110100000000001011000000100000000000000000000000000000000000000000000000000000000
00000000606006066600600660100106000000001010010110100000000001011000000100000000000000000000000000000000000000000000000000000000
00000000606006066006006660100106000000001010010110100000000001011000000100000000000000000000000000000000000000000000000000000000
00000000600660066060060660011006000000001001100110100000000001011000000100000000000000000000000000000000000000000000000000000000
00000000660000666600606666000066000000001100001111100000000001111100001100000000000000000000000000000000000000000000000000000000
00000000066666600666666006666660000000000111111001100000000001101100001100000000000000000000000000000000000000000000000000000000
00000000000000000000000000600000000000000066600000000000006660000000000000000000000000000000000000000000000000000000000000000000
00666000000000000066600000666000000000000066660000666000006666000066600000000000000000000000000000000000000000000000000000000000
00666600006660000066660000666600000000000661616000666600066161600066660000000000000000000000000000000000000000000000000000000000
06616160006666000661616006616160000000000661616006616160066161600661616000000000000000000000000000000000000000000000000000000000
06666660066161600661616006616160000000000066660006666660006666000666666000000000000000000000000000000000000000000000000000000000
00666600066666600066660000666600000000000066060000666600006006600066660000000000000000000000000000000000000000000000000000000000
00600600006666000066060000660600000000000000600000606600060000000660060000000000000000000000000000000000000000000000000000000000
00600600006006000000600000006000000000000000000000600000000000000000060000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0025252525252525252525250000050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0025161725160517252525250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0025262725260527252525250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0025252525260536252528250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0022222222222222222222220500000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
