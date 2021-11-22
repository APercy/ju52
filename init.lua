ju52={}
ju52.fuel = {['biofuel:biofuel'] = 1,['biofuel:bottle_fuel'] = 1,
                ['biofuel:phial_fuel'] = 0.25, ['biofuel:fuel_can'] = 10}
ju52.gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.8
ju52.wing_angle_of_attack = 1.5
ju52.min_speed = 5
ju52.max_engine_acc = 9 --5
ju52.lift = 11 --12

dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_global_definitions.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_crafts.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_control.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_fuel_management.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_custom_physics.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_utilities.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_entities.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_forms.lua")

--
-- helpers and co.
--

--
-- items
--

-- add chatcommand to eject from demoiselle

minetest.register_chatcommand("ju52_eject", {
	params = "",
	description = "Ejects from ju52",
	privs = {interact = true},
	func = function(name, param)
        local colorstring = core.colorize('#ff0000', " >>> you are not inside your ju52")
        local player = minetest.get_player_by_name(name)
        local attached_to = player:get_attach()

		if attached_to ~= nil then
            local parent = attached_to:get_attach()
            if parent ~= nil then
                local entity = parent:get_luaentity()
                if entity.driver_name == name and entity.name == "ju52:ju52" then
                    ju52.dettachPlayer(entity, player)
                else
			        minetest.chat_send_player(name,colorstring)
                end
            end
		else
			minetest.chat_send_player(name,colorstring)
		end
	end
})


