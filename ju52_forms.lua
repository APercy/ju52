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
        "size[6,11.5]",
	}, "")

    local copilot_name = "test"
	basic_form = basic_form.."button[1,1.0;4,1;turn_on;Start/Stop Engines]"
    basic_form = basic_form.."button[1,2.0;4,1;hud;Show/Hide Gauges]"
    basic_form = basic_form.."button[1,3.0;4,1;turn_auto_pilot_on;Auto Pilot]"
    basic_form = basic_form.."button[1,4.0;4,1;pass_control;Pass the Control]"
    basic_form = basic_form.."button[1,5.4;4,1;open_door;Open the Door]"
    basic_form = basic_form.."button[1,6.4;4,1;close_door;Close the Door]"
    basic_form = basic_form.."button[1,7.8;4,1;go_out;Go Offboard]"
    basic_form = basic_form.."button[1,9.5;4,1;eject_copilot;Eject copilot]"
    

    minetest.show_formspec(name, "ju52:pilot_main", basic_form)
end

function ju52.paint_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[8.1, 11.8]",
    },"")

    basic_form = basic_form.."image_button[1,1.0;3,1;ju52_p_lufthansa.png;lufthansa;Lufthansa;false;true;]"
    basic_form = basic_form.."image_button[1,2.1;3,1;ju52_p_lufthansa.png;lufthansa2;Lufthansa 2;false;true;]"
    basic_form = basic_form.."image_button[1,3.2;3,1;ju52_p_luftwaffe.png;luftwaffe;Luftwaffe;false;true;]"
    basic_form = basic_form.."image_button[1,4.3;3,1;ju52_white.png^[multiply:#2b2b2b;black;Black;false;true;]"
    basic_form = basic_form.."image_button[1,5.4;3,1;ju52_white.png^[multiply:#0063b0;blue;Blue;false;true;]"
    basic_form = basic_form.."image_button[1,6.5;3,1;ju52_white.png^[multiply:#8c5922;brown;Brown;false;true;]"
    basic_form = basic_form.."image_button[1,7.6;3,1;ju52_white.png^[multiply:#07B6BC;cyan;Cyan;false;true;]"
    basic_form = basic_form.."image_button[1,8.7;3,1;ju52_white.png^[multiply:#567a42;dark_green;Dark Green;false;true;]"
    basic_form = basic_form.."image_button[1,9.8;3,1;ju52_white.png^[multiply:#6d6d6d;dark_grey;Dark Gray;false;true;]"

    basic_form = basic_form.."image_button[4.1,1.0;3,1;ju52_white.png^[multiply:#4ee34c;green;Green;false;true;]"
    basic_form = basic_form.."image_button[4.1,2.1;3,1;ju52_white.png^[multiply:#9f9f9f;grey;Gray;false;true;]"
    basic_form = basic_form.."image_button[4.1,3.2;3,1;ju52_white.png^[multiply:#ff0098;magenta;Magenta;false;true;]"
    basic_form = basic_form.."image_button[4.1,4.3;3,1;ju52_white.png^[multiply:#ff8b0e;orange;Orange;false;true;]"
    basic_form = basic_form.."image_button[4.1,5.4;3,1;ju52_white.png^[multiply:#ff62c6;pink;Pink;false;true;]"
    basic_form = basic_form.."image_button[4.1,6.5;3,1;ju52_white.png^[multiply:#dc1818;red;Red;false;true;]"
    basic_form = basic_form.."image_button[4.1,7.6;3,1;ju52_white.png^[multiply:#a437ff;violet;Violet;false;true;]"
    basic_form = basic_form.."image_button[4.1,8.7;3,1;ju52_white.png^[multiply:#ffe400;yellow;Yellow;false;true;]"
    basic_form = basic_form.."image_button[4.1,9.8;3,1;ju52_white.png^[multiply:#ffffff;white;White;false;true;]"
    
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

		if fields.black then ju52.paint(plane_obj, "#2b2b2b", search_string) end
        if fields.blue then ju52.paint(plane_obj, "#0063b0", search_string) end
        if fields.brown then ju52.paint(plane_obj, "#8c5922", search_string) end
        if fields.cyan then ju52.paint(plane_obj, "#07B6BC", search_string) end
        if fields.dark_green then ju52.paint(plane_obj, "#567a42", search_string) end
        if fields.dark_grey then ju52.paint(plane_obj, "#6d6d6d", search_string) end
        if fields.green then ju52.paint(plane_obj, "#4ee34c", search_string) end

        if fields.grey then ju52.paint(plane_obj, "#9f9f9f", search_string) end
        if fields.magenta then ju52.paint(plane_obj, "#ff0098", search_string) end
        if fields.orange then ju52.paint(plane_obj, "#ff8b0e", search_string) end
        if fields.pink then ju52.paint(plane_obj, "#ff62c6", search_string) end
        if fields.red then ju52.paint(plane_obj, "#dc1818", search_string) end
        if fields.violet then ju52.paint(plane_obj, "#a437ff", search_string) end
        if fields.yellow then ju52.paint(plane_obj, "#ffe400", search_string) end
        if fields.white then ju52.paint(plane_obj, "#ffffff", search_string) end
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
				ju52.transfer_control(ent, false)
            else
				--trasnfer the control to student
				ju52.transfer_control(ent, true)
            end
		end
		if fields.open_door then
            --
		end
		if fields.close_door then
            --
		end
		if fields.go_out then
            --=========================
            --  dettach player
            --=========================
            -- eject passenger if the plane is on ground
            local touching_ground, liquid_below = ju52.check_node_below(plane_obj)
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
                    ju52.transfer_control(ent, true)
                end
            end
            ent._instruction_mode = false
            ju52.dettachPlayer(ent, player)
		end
		if fields.accept_copilot then
            --
		end
        minetest.close_formspec(name, "ju52:pilot_main")
    end
end)
