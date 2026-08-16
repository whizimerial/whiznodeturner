local block_func = dofile(minetest.get_modpath("whiznodeturner") .. "/function.lua")
local sitting_players = {}

local function make_player_sit(player, parent_obj, y_offset_pixels, sit_dir_deg)
    local name = player:get_player_name()
    local pos = parent_obj:get_pos()
    
    if sitting_players[name] then return end

    local pixel_offset = (y_offset_pixels or 0) * (1 / 16)
    local base_yaw = parent_obj:get_yaw() or 0
    local extra_rad = math.rad(sit_dir_deg or 0)
    local final_yaw = base_yaw + extra_rad
    
    player:set_look_horizontal(final_yaw)

    local seat_obj = minetest.add_entity(pos, "whiznodeturner:sit_entity")
    if not seat_obj then return end
    
    seat_obj:set_yaw(final_yaw)

    player:set_attach(
        seat_obj, 
        "", 
        {x = 0, y = pixel_offset + 0.15, z = 0}, 
        {x = 0, y = 0, z = 0},
        true,
        {x = 1, y = 1, z = 1}
    )
    
    sitting_players[name] = {
        chair_obj = parent_obj,
        seat_obj = seat_obj,
        old_physics = player:get_physics_override() or {}
    }
    
    player:set_physics_override({
        speed = 0,
        jump = 0,
        gravity = 0
    })
    
    if player_api and player_api.set_animation then
        player_api.set_animation(player, "sit")
    elseif default and default.player_set_animation then
        default.player_set_animation(player, "sit")
    end
end

local function make_player_stand(player)
    if not player then return end
    local name = player:get_player_name()
    local data = sitting_players[name]
    
    player:set_detach()
    
    if data then
        if data.seat_obj and data.seat_obj:get_pos() then
            data.seat_obj:remove()
        end
        
        local pos = player:get_pos()
        if pos then
            pos.y = pos.y + 0.1
            player:set_pos(pos)
        end

        if data.old_physics then
            player:set_physics_override({
                speed = data.old_physics.speed or 1,
                jump = data.old_physics.jump or 1,
                gravity = data.old_physics.gravity or 1
            })
        else
            player:set_physics_override({speed = 1, jump = 1, gravity = 1})
        end
    else
        player:set_physics_override({speed = 1, jump = 1, gravity = 1})
    end
    
    sitting_players[name] = nil
    
    if player_api and player_api.set_animation then
        player_api.set_animation(player, "stand")
    elseif default and default.player_set_animation then
        default.player_set_animation(player, "stand")
    end
end

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if sitting_players[name] then
        local data = sitting_players[name]
        if data.seat_obj and data.seat_obj:get_pos() then
            data.seat_obj:remove()
        end
        sitting_players[name] = nil
    end
end)

core.register_entity("whiznodeturner:sit_entity", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "cube",
        textures = {"empty.png", "empty.png", "empty.png", "empty.png", "empty.png", "empty.png"},
        visual_size = {x = 1, y = 1, z = 1},
    },
})

core.register_entity("whiznodeturner:block_entity", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        pointable = true,
        show_selectionbox = false,
        hp_max = 1,
        armor_groups = {immortal = 1},
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "wielditem",
        textures = {""},
        visual_size = {x = 0.675, y = 0.675, z = 0.675},
        backface_culling = true,
    },

    on_activate = function(self, staticdata)
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self.nodename = data.nodename
                self.param2 = data.param2
                self.meta = data.meta
                self._visual = data.visual
                self._mesh = data.mesh
                self._textures = data.textures
                self._collisionbox = data.collisionbox
                self._wield_item = data.wield_item
                self._visual_size = data.visual_size
                self._is_chair = data.is_chair
                self._sit_offset = data.sit_offset or 0
                self._sit_dir = data.sit_dir or 0
                self._no_rightclick = data.no_rightclick
                self._has_gravity = data.has_gravity
                self._no_collide = data.no_collide
                self._rotation = data.rotation

                if data.rotation then
                    self.object:set_rotation(data.rotation)
                end

                local is_physical = not self._no_collide
                local props = {
                    visual = data.visual or "cube",
                    mesh = data.mesh,
                    textures = data.textures,
                    collisionbox = data.collisionbox or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
                    wield_item = data.wield_item or "",
                    visual_size = data.visual_size or {x = 0.675, y = 0.675, z = 0.675},
                    physical = is_physical,
                    collide_with_objects = is_physical,
                    show_selectionbox = false
                }

                if data.visual == "wielditem" and data.wield_item then
                    props.textures = {data.wield_item}
                end

                self.object:set_properties(props)

                if self.nodename then
                    local def = minetest.registered_nodes[self.nodename]
                    if def and def.mesh and def.animation then
                        self.object:set_animation(
                            def.animation.range or {x = 0, y = 30},
                            def.animation.speed or 15,
                            def.animation.blend or 0,
                            def.animation.loop ~= false
                        )
                    end
                end

                if self._has_gravity then
                    self.object:set_acceleration({x=0, y=-9.81, z=0})
                end
            end
        end
    end,

    get_staticdata = function(self)
        local props = self.object:get_properties()
        return minetest.serialize({
            nodename = self.nodename,
            param2 = self.param2,
            meta = self.meta,
            visual = self._visual or props.visual,
            mesh = self._mesh or props.mesh,
            textures = self._textures or props.textures,
            collisionbox = self._collisionbox or props.collisionbox,
            wield_item = self._wield_item or props.wield_item,
            visual_size = self._visual_size or props.visual_size,
            is_chair = self._is_chair,
            sit_offset = self._sit_offset,
            sit_dir = self._sit_dir,
            no_rightclick = self._no_rightclick,
            has_gravity = self._has_gravity,
            no_collide = self._no_collide,
            rotation = self.object:get_rotation()
        })
    end,

    on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir)
        return true 
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end
        
        local wielded = clicker:get_wielded_item()
        
        if wielded:get_name() == "whiznodeturner:struct_tool" then
            if self.nodename then
                local pos = self.object:get_pos()
                local target_pos = {
                    x = math.floor(pos.x + 0.5), 
                    y = math.floor(pos.y + 0.5), 
                    z = math.floor(pos.z + 0.5)
                }
                
                minetest.set_node(target_pos, {name = self.nodename, param2 = self.param2 or 0})
                
                if self.meta then
                    local meta_data = self.meta
                    minetest.after(0.02, function()
                        local meta = minetest.get_meta(target_pos)
                        if meta then
                            meta:from_table(meta_data)
                        end
                    end)
                end
            end
            self.object:remove()
            return
        end

        if wielded:get_name() == "whiznodeturner:property_tool" then
            block_func.open_property_menu(clicker, self.object)
            return
        end

        if self._is_chair then
            local name = clicker:get_player_name()
            if sitting_players[name] then
                make_player_stand(clicker)
            else
                make_player_sit(clicker, self.object, self._sit_offset, self._sit_dir)
            end
            return
        end

        if self._no_rightclick then return end
        if not wielded:is_empty() then return end

        if self.nodename then
            local def = minetest.registered_nodes[self.nodename]
            local is_container = def and (def.allow_metadata_inventory_put or def.on_metadata_inventory_put or def.groups.chest or def.drawtype == "mesh")
            if def and is_container then
                local player_name = clicker:get_player_name()
                local inv_id = "whiznodeturner_container_" .. tostring(self.object):gsub("[^%w]", "")            
                
                local slot_count = 32
                if self.meta and self.meta.inventory and self.meta.inventory.main then
                    slot_count = #self.meta.inventory.main
                end

                local inv = minetest.create_detached_inventory(inv_id, {
                    allow_put = function(inv, listname, index, stack, player) return stack:get_count() end,
                    allow_take = function(inv, listname, index, stack, player) return stack:get_count() end,
                    allow_move = function(inv, from_list, from_index, to_list, to_index, count, player) return count end,
                    on_change = function(inv)
                        self.meta = self.meta or {}
                        local saved_lists = {}
                        for list_name, list in pairs(inv:get_lists()) do
                            saved_lists[list_name] = {}
                            for i, itemstack in ipairs(list) do
                                saved_lists[list_name][i] = itemstack:to_string()
                            end
                        end
                        self.meta.inventory = saved_lists
                    end,
                })

                if inv:get_size("main") == 0 then
                    inv:set_size("main", slot_count)
                    if self.meta and self.meta.inventory then
                        inv:set_lists(self.meta.inventory)
                    end
                end

                local formspec = nil
                if type(def.get_formspec) == "function" then
                    formspec = def.get_formspec({x=0, y=0, z=0})
                elseif def.formspec then
                    formspec = def.formspec
                end

                if not formspec then
                    formspec = "size[8,9]" ..
                        "list[detached:" .. inv_id .. ";main;0,0.3;8,4;]" ..
                        "list[current_player;main;0,4.85;8,1;]" ..
                        "list[current_player;main;0,6.08;8,3;8]" ..
                        "listring[detached:" .. inv_id .. ";main]" ..
                        "listring[current_player;main]"
                else
                    formspec = formspec:gsub("nodemeta:%d+,%d+,%d+", "detached:" .. inv_id)
                    formspec = formspec:gsub("context:", "detached:" .. inv_id .. ":")
                end

                minetest.show_formspec(player_name, "whiznodeturner:container_ui", formspec)
            end
        end
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if not formname:find("whiznodeturner:property_ui_") then return end

    local player_name = player:get_player_name()

    for _, obj in pairs(minetest.luaentities) do
        if obj.name == "whiznodeturner:block_entity" and obj._property_user == player_name then
            if fields.toggle_chair then
                obj._is_chair = not obj._is_chair
                block_func.open_property_menu(player, obj.object)
            elseif fields.toggle_nocollide then
                obj._no_collide = not obj._no_collide
                local is_physical = not obj._no_collide
                obj.object:set_properties({
                    physical = is_physical,
                    collide_with_objects = is_physical
                })
                block_func.open_property_menu(player, obj.object)
            elseif fields.toggle_norc then
                obj._no_rightclick = not obj._no_rightclick
                block_func.open_property_menu(player, obj.object)
            elseif fields.toggle_gravity then
                obj._has_gravity = not obj._has_gravity
                if obj._has_gravity then
                    obj.object:set_acceleration({x=0, y=-9.81, z=0})
                else
                    obj.object:set_acceleration({x=0, y=0, z=0})
                    obj.object:set_velocity({x=0, y=0, z=0})
                end
                block_func.open_property_menu(player, obj.object)
            elseif fields.save_props or fields.key_enter then
                local num_offset = tonumber(fields.sit_offset)
                if num_offset then obj._sit_offset = num_offset end
                
                local num_dir = tonumber(fields.sit_dir)
                if num_dir then obj._sit_dir = num_dir end

                obj._property_user = nil
            elseif fields.delete_ent then
                obj.object:remove()
            end
            break
        end
    end
end)

minetest.register_globalstep(function(dtime)
    for name, data in pairs(sitting_players) do
        local player = minetest.get_player_by_name(name)
        if player then
            local ctrl = player:get_player_control()
            if ctrl.sneak then
                make_player_stand(player)
            else
                if player_api and player_api.set_animation then
                    player_api.set_animation(player, "sit")
                elseif default and default.player_set_animation then
                    default.player_set_animation(player, "sit")
                end
            end
        else
            sitting_players[name] = nil
        end
    end
end)
