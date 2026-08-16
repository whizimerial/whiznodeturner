local block_func = {}

function block_func.convert_node_to_entity(pos, player)
    local node = minetest.get_node(pos)
    if node.name == "air" or node.name == "ignore" then return end

    local def = minetest.registered_nodes[node.name]
    if not def then return end

    local meta = minetest.get_meta(pos):to_table()

    local visual = "cube"
    local mesh = nil
    local box = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
    local v_size = {x = 1, y = 1, z = 1}
    local wield_item = ""

    -- Preserve node drawtypes (2D plants, wallmounted, nodeboxes, meshes)
    if def.drawtype == "mesh" and def.mesh then
        visual = "mesh"
        v_size = {x = 10, y = 10, z = 10}
        mesh = def.mesh
    elseif def.drawtype == "plantlike" or def.drawtype == "signlike" or def.drawtype == "torchlike" or def.node_box then
        visual = "wielditem"
        wield_item = node.name
        v_size = {x = 0.675, y = 0.675, z = 0.675}
        if def.node_box and def.node_box.fixed then
            local f = def.node_box.fixed
            if type(f[1]) == "number" then
                box = f
            elseif type(f[1]) == "table" then
                local minx, miny, minz = 99, 99, 99
                local maxx, maxy, maxz = -99, -99, -99
                for _, subbox in ipairs(f) do
                    if type(subbox) == "table" and #subbox == 6 then
                        minx = math.min(minx, subbox[1])
                        miny = math.min(miny, subbox[2])
                        minz = math.min(minz, subbox[3])
                        maxx = math.max(maxx, subbox[4])
                        maxy = math.max(maxy, subbox[5])
                        maxz = math.max(maxz, subbox[6])
                    end
                end
                if minx <= maxx then box = {minx, miny, minz, maxx, maxy, maxz} end
            end
        end
    end    

    local tiles = def.tiles or {"default_stone.png"}
    local textures = {}
    for i = 1, 6 do
        local tile = tiles[i] or tiles[1]
        textures[i] = type(tile) == "table" and tile.name or tile
    end

    local spawn_pos = {x = pos.x, y = pos.y, z = pos.z}
    local ent = minetest.add_entity(spawn_pos, "whiznodeturner:block_entity")

    if ent then
        local luaentity = ent:get_luaentity()
        luaentity.nodename = node.name
        luaentity.param2 = node.param2
        luaentity.meta = meta

        local initial_yaw = 0
        if node.param2 then
            local facedir_yaw = {
                [0] = 0,
                [1] = math.rad(90),
                [2] = math.rad(180),
                [3] = math.rad(270),
            }
            if facedir_yaw[node.param2 % 4] then
                initial_yaw = facedir_yaw[node.param2 % 4]
            end
        end
        ent:set_yaw(initial_yaw)

        ent:set_properties({
            visual = visual,
            mesh = mesh,
            textures = textures,
            collisionbox = box,
            wield_item = wield_item ~= "" and wield_item or node.name,
            visual_size = v_size,
        })

        luaentity._visual = visual
        luaentity._mesh = mesh
        luaentity._textures = textures
        luaentity._collisionbox = box
        luaentity._wield_item = wield_item ~= "" and wield_item or node.name
        luaentity._visual_size = v_size

        minetest.after(0.05, function()
            minetest.remove_node(pos)
        end)
    end
end

function block_func.handle_displacement(user, pointed_thing, click_type)
    if not user then return end
    local target_entity = nil
    if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
        local obj = pointed_thing.ref
        if obj and obj:get_luaentity() and obj:get_luaentity().name == "whiznodeturner:block_entity" then
            target_entity = obj
        end
    end

    if not target_entity then return end

    local ctrl = user:get_player_control()
    local is_crouched = ctrl.sneak
    local pixel = 1 / 16
    local pos = target_entity:get_pos()
    
    if is_crouched then
        pos.y = click_type == "left" and (pos.y + pixel) or (pos.y - pixel)
    else
        local dir = user:get_look_dir()
        local ax, az = 0, 0
        if math.abs(dir.x) > math.abs(dir.z) then
            ax = dir.x > 0 and 1 or -1
        else
            az = dir.z > 0 and 1 or -1
        end

        local multiplier = click_type == "right" and -pixel or pixel
        pos.x = pos.x + (ax * multiplier)
        pos.z = pos.z + (az * multiplier)
    end

    target_entity:set_pos(pos)
end

function block_func.handle_rotation(user, pointed_thing, click_type)
    if not user then return end
    
    if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
        local obj = pointed_thing.ref
        if obj and obj:get_luaentity() and obj:get_luaentity().name == "whiznodeturner:block_entity" then
            local step = math.rad(22.5) 
            local rot = obj:get_rotation() or {x = 0, y = 0, z = 0}

            if click_type == "left" then
                rot.x = rot.x + step
            else
                rot.y = rot.y + step
            end

            obj:set_rotation(rot)
            
            local luaent = obj:get_luaentity()
            if luaent then
                luaent._rotation = rot
            end
        end
    end
end

-- Updated UI Property Menu Logic with missing options added
function block_func.open_property_menu(player, entity)
    local player_name = player:get_player_name()
    local luaent = entity:get_luaentity()
    if not luaent then return end

    luaent._property_user = player_name
    
    local is_chair = luaent._is_chair and "[ENABLED]" or "[DISABLED]"
    local no_rc = luaent._no_rightclick and "[ENABLED]" or "[DISABLED]"
    local gravity = luaent._has_gravity and "[ENABLED]" or "[DISABLED]"
    local no_collide = luaent._no_collide and "[ENABLED]" or "[DISABLED]"
    local sit_dir = luaent._sit_dir or 0
    local sit_y = luaent._sit_offset or 0

    local formspec = "size[6,8.5]" ..
        "label[0.5,0.3;Block Entity Properties]" ..
        "button[0.5,0.9;5,0.7;toggle_chair;Chair Mode: " .. is_chair .. "]" ..
        "field[0.8,2.0;4.6,0.7;sit_offset;Sitting Y Offset (pixels); " .. tostring(sit_y) .. "]" ..
        "field[0.8,3.1;4.6,0.7;sit_dir;Player Sit Facing Dir (deg); " .. tostring(sit_dir) .. "]" ..
        "button[0.5,4.0;5,0.7;toggle_nocollide;No Collision: " .. no_collide .. "]" ..
        "button[0.5,4.9;5,0.7;toggle_norc;No Rightclick: " .. no_rc .. "]" ..
        "button[0.5,5.8;5,0.7;toggle_gravity;Gravity: " .. gravity .. "]" ..
        "button_exit[0.5,7.0;2.3,0.8;save_props;Save]" ..
        "button_exit[3.2,7.0;2.3,0.8;delete_ent;DELETE]"

    minetest.show_formspec(player_name, "whiznodeturner:property_ui_" .. tostring(entity:get_guid() or math.random(1000,9999)), formspec)
end

return block_func
