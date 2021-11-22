dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_global_definitions.lua")

--------------
-- Manual --
--------------

function ju52.getPlaneFromPlayer(player)
    local seat = player:get_attach()
    local plane = seat:get_attach()
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

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "ju52:passenger_main" then
        local name = player:get_player_name()
        local plane_obj = ju52.getPlaneFromPlayer(player)
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
            --
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
