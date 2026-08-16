local block_func = dofile(minetest.get_modpath("whiznodeturner") .. "/function.lua")

minetest.register_tool("whiznodeturner:struct_tool", {
    description = "Node Struct Tool",
    inventory_image = "whiznodeturner_struct.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            block_func.convert_node_to_entity(pointed_thing.under, user)
        end
    end,
})

minetest.register_tool("whiznodeturner:mover_tool", {
    description = "Node Displacer Tool",
    inventory_image = "whiznodeturner_mover.png",
    on_use = function(itemstack, user, pointed_thing)
        block_func.handle_displacement(user, pointed_thing, "left")
        return itemstack
    end,
    on_place = function(itemstack, user, pointed_thing)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        block_func.handle_displacement(user, pointed_thing, "right")
        return itemstack
    end,
})

minetest.register_tool("whiznodeturner:rotator_tool", {
    description = "Node Rotator Tool",
    inventory_image = "whiznodeturner_rotator.png",
    on_use = function(itemstack, user, pointed_thing)
        block_func.handle_rotation(user, pointed_thing, "left")
        return itemstack
    end,
    on_place = function(itemstack, user, pointed_thing)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        block_func.handle_rotation(user, pointed_thing, "right")
        return itemstack
    end,
})

minetest.register_tool("whiznodeturner:property_tool", {
    description = "Node-Ent Modifier Tool",
    inventory_image = "whiznodeturner_property.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing and pointed_thing.type == "object" and pointed_thing.ref then
            local obj = pointed_thing.ref
            if obj:get_luaentity() and obj:get_luaentity().name == "whiznodeturner:block_entity" then
                block_func.open_property_menu(user, obj)
            end
        end
        return itemstack
    end,
})
