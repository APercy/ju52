dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_global_definitions.lua")

--------------
-- Manual --
--------------

function ju52.getPlaneFromPlayer(player)
    local seat = player:get_attach()
    local plane = nil
    if seat then
        plane = seat:get_attach()
    end
    return plane
end

function ju52.pax_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,5]",
	}, "")

	basic_form = basic_form.."button[1,1.0;4,1;new_seat;Change Seat]"
	basic_form = basic_form.."button[1,2.5;4,1;go_out;Go Offboard]"

    minetest.show_formspec(name, "ju52:passenger_main", basic_form)
end

function ju52.pilot_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,12]",
	}, "")

    local player = minetest.get_player_by_name(name)
    local plane_obj = ju52.getPlaneFromPlayer(player)
    if plane_obj == nil then
        return
    end
    local ent = plane_obj:get_luaentity()

    local pass_list = ""
    for k, v in pairs(ent._passengers) do
        pass_list = pass_list .. v .. ","
    end

    local copilot_name = "test"
	basic_form = basic_form.."button[1,1.0;4,1;turn_on;Start/Stop Engines]"
    basic_form = basic_form.."button[1,2.0;4,1;hud;Show/Hide Gauges]"
    basic_form = basic_form.."button[1,3.0;4,1;turn_auto_pilot_on;Auto Pilot]"
    basic_form = basic_form.."button[1,4.0;4,1;pass_control;Pass the Control]"
    basic_form = basic_form.."button[1,5.4;4,1;open_door;Open the Door]"
    basic_form = basic_form.."button[1,6.4;4,1;close_door;Close the Door]"
    basic_form = basic_form.."button[1,7.8;4,1;go_out;Go Offboard]"
    basic_form = basic_form.."label[1,10;Bring a copilot:]"
    basic_form = basic_form.."dropdown[1,10.2;4,1;copilot;"..pass_list..";0;false]"

    minetest.show_formspec(name, "ju52:pilot_main", basic_form)
end

function ju52.paint_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[4.0, 4.2]",
    },"")

    basic_form = basic_form.."image_button[0.5,0.5;3,1;ju52_p_lufthansa.png;lufthansa;Lufthansa;false;true;]"
    basic_form = basic_form.."image_button[0.5,1.6;3,1;ju52_p_lufthansa.png;lufthansa2;Lufthansa 2;false;true;]"
    basic_form = basic_form.."image_button[0.5,2.7;3,1;ju52_p_luftwaffe.png;luftwaffe;Luftwaffe;false;true;]"
    --basic_form = basic_form.."image_button[1,4.3;3,1;ju52_white.png^[multiply:#2b2b2b;black;Black;false;true;]"    

    minetest.show_formspec(name, "ju52:paint", basic_form)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "ju52:paint" then
        local name = player:get_player_name()
        local plane_obj = ju52.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:paint")
            return
        end
        local ent = plane_obj:get_luaentity()
        
        ent.initial_properties.textures = ju52.textures_copy() --reset the textures first
        local search_string = ju52.skin_texture --then set to find the defaults

        if fields.lufthansa then ju52.set_skin(plane_obj, "ju52_skin_lufthansa.png", search_string) end
        if fields.lufthansa2 then ju52.set_skin(plane_obj, "ju52_skin_lufthansa2.png", search_string) end
        if fields.luftwaffe then ju52.set_skin(plane_obj, "ju52_skin_luftwaffe.png", search_string) end

        minetest.close_formspec(name, "ju52:paint")
	end
	if formname == "ju52:passenger_main" then
        local name = player:get_player_name()
        local plane_obj = ju52.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:passenger_main")
            return
        end
        local ent = plane_obj:get_luaentity()
		if fields.new_seat then
            ju52.dettach_pax(ent, player)
            ju52.attach_pax(ent, player)
		end
		if fields.go_out then
            ju52.dettach_pax(ent, player)
		end
        minetest.close_formspec(name, "ju52:passenger_main")
	end
    if formname == "ju52:pilot_main" then
        local name = player:get_player_name()
        local plane_obj = ju52.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:pilot_main")
            return
        end
        local ent = plane_obj:get_luaentity()
		if fields.turn_on then
            ju52.start_engine(ent)
		end
        if fields.hud then
            if ent._show_hud == true then
                ent._show_hud = false
            else
                ent._show_hud = true
            end
        end
		if fields.turn_auto_pilot_on then
            --
		end
		if fields.pass_control then
            if ent._command_is_given == true then
				--take the control
				airutils.transfer_control(ent, false)
            else
				--trasnfer the control to student
				airutils.transfer_control(ent, true)
            end
		end
		if fields.open_door then
            ent.object:set_bone_position("door", {x=-11.35, y=32.65, z=9.87}, {x=88.5, y=0, z=0})
		end
		if fields.close_door then
            ent.object:set_bone_position("door", {x=-11.35, y=32.65, z=9.87}, {x=91.5, y=0, z=180})
		end
		if fields.go_out then
            --=========================
            --  dettach player
            --=========================
            -- eject passenger if the plane is on ground
            local touching_ground, liquid_below = airutils.check_node_below(plane_obj, 2.5)
            if ent.isinliquid or touching_ground then --isn't flying?
                --ok, remove pax
                local passenger = nil
                if ent._passenger then
                    passenger = minetest.get_player_by_name(ent._passenger)
                    if passenger then ju52.dettach_pax(ent, passenger) end
                end
                for i = 10,1,-1 
                do 
                    if ent._passengers[i] then
                        passenger = minetest.get_player_by_name(ent._passengers[i])
                        if passenger then
                            ju52.dettach_pax(ent, passenger)
                            --minetest.chat_send_all('saiu')
                        end
                    end
                end
            else
                --give the control to the pax
                if ent._passenger then
                    ent._autopilot = false
                    airutils.transfer_control(ent, true)
                end
            end
            ent._instruction_mode = false
            ju52.dettachPlayer(ent, player)
		end
		if fields.copilot then
            --look for a free seat first
            local is_there_a_free_seat = false
            for i = 10,1,-1 
            do 
                if ent._passengers[i] == nil then
                    is_there_a_free_seat = true
                    break
                end
            end
            --then move the current copilot to a free seat
            if ent._passenger and is_there_a_free_seat then
                local copilot_player_obj = minetest.get_player_by_name(ent._passenger)
                if copilot_player_obj then
                    ju52.dettach_pax(ent, copilot_player_obj)
                    ju52.attach_pax(ent, copilot_player_obj)
                else
                    ent._passenger = nil
                end
            end
            --so bring the new copilot
            if ent._passenger == nil then
                local new_copilot_player_obj = minetest.get_player_by_name(fields.copilot)
                if new_copilot_player_obj then
                    ju52.dettach_pax(ent, new_copilot_player_obj)
                    ju52.attach_pax(ent, new_copilot_player_obj, true)
                end
            end
		end
        minetest.close_formspec(name, "ju52:pilot_main")
    end
end)
