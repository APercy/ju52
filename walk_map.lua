ju52.ideal_step = 0.02
ju52.total_seats = 12

local function do_attach(self, player, slot)
    if slot == 0 then return end
    if self._passengers[slot] == nil then
        local name = player:get_player_name()
        --minetest.chat_send_all(self.driver_name)
        self._passengers[slot] = name
        player:set_attach(self._passengers_base[slot], "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        if airutils.is_minetest then
            player_api.player_attached[name] = true
        elseif airutils.is_mcl then
            mcl_player.player_attached[name] = true
        end
        self._passenger_is_sit[slot] = 0
    end
end

function ju52.table_copy(table_here)
    local tablecopy = {}
    for k, v in pairs(table_here) do
      tablecopy[k] = v
    end
    return tablecopy
end

function ju52.copy_vector(original_vector)
    local tablecopy = {}
    for k, v in pairs(original_vector) do
      tablecopy[k] = v
    end
    return tablecopy
end

function ju52.clamp(value, min, max)
    local retVal = value
    if value < min then retVal = min end
    if value > max then retVal = max end
    --core.chat_send_all(value .. " - " ..retVal)
    return retVal
end

function ju52.reclamp(value, min, max)
    local retVal = value
    local mid = (max-min)/2
    if value > min and value <= (min+mid) then retVal = min end
    if value < max and value > (max-mid) then retVal = max end
    --core.chat_send_all(value .. " - return: " ..retVal .. " - mid: " .. mid)
    return retVal
end

local function is_obstacle_zone(pos, start_point, end_point)
    local retVal = ju52.table_copy(pos)

    local min_x = 0
    local min_z = 0
    local max_x = 0
    local max_z = 0

    if start_point.x <= end_point.x then min_x = start_point.x else min_x = end_point.x end
    if start_point.z <= end_point.z then min_z = start_point.z else min_z = end_point.z end
    if start_point.x > end_point.x then max_x = start_point.x else max_x = end_point.x end
    if start_point.z > end_point.z then max_z = start_point.z else max_z = end_point.z end

    local mid_x = (max_x - min_x)/2
    local mid_z = (max_z - min_z)/2

    if pos.x < max_x and pos.x > min_x+mid_x and
            pos.z < max_z and pos.z > min_z then
        retVal.x = max_x + 1
        return retVal
    end
    if pos.x > min_x and pos.x <= min_x+mid_x and
            pos.z < max_z and pos.z > min_z then
        retVal.x = min_x - 1
        return retVal
    end

    local death_zone = 1.5 --to avoid the "slip" when colliding in y direction
    if pos.z < max_z + death_zone and pos.z > min_z+mid_z and
            pos.x > min_x and pos.x < max_x then
        retVal.z = max_z + 1
        return retVal
    end
    if pos.z > min_z - death_zone and pos.z <= min_z+mid_z and
            pos.x > min_x and pos.x < max_x then
        retVal.z = min_z - 1
        return retVal
    end

    return retVal
end

function ju52.cabin_map(self, pos, dpos)
    local orig_pos = ju52.copy_vector(pos)
    local position = ju52.copy_vector(dpos)
    local new_pos = ju52.copy_vector(dpos)

    for i = #self._seats,3,-1 
    do
        --new_pos = is_obstacle_zone(new_pos, {x=12, z=153}, {x=2.5, z=143})
        local posA = {x=self._seats[i].x - 3, z=self._seats[i].z - 5}
        local posB = {x=self._seats[i].x + 3, z=self._seats[i].z + 5}
        new_pos = is_obstacle_zone(new_pos, posA, posB)
    end

    --limit to the cabin
    new_pos.y = 3.2

    --limiting deck
    if pos.z < -50 then --corridor to exit
        new_pos.z = ju52.clamp(new_pos.z, -60, -45)
        new_pos.x = ju52.clamp(new_pos.x, -2, 2)
    else
        new_pos.z = ju52.clamp(new_pos.z, -60, 10)
        new_pos.x = ju52.clamp(new_pos.x, -6, 6)
    end


    --core.chat_send_all("x: "..new_pos.x.." - z: "..new_pos.z)
    return new_pos
end

function ju52.navigate_deck(self, pos, dpos, player)
    local pos_d = dpos

    if player then
        pos_d = ju52.cabin_map(self, pos, dpos)
    end
    --core.chat_send_all(dump(pos_d))

    return pos_d
end

--note: index variable just for the walk
--this function was improved by Auri Collings on steampunk_blimp
local function get_result_pos(self, player, index)
    local pos = nil
    if player then
        local ctrl = player:get_player_control()

        local direction = player:get_look_horizontal()
        local rotation = self.object:get_rotation()
        local parent_obj = self.object:get_attach()
        if parent_obj then
            rotation = parent_obj:get_rotation()
        end

        direction = direction - rotation.y

        pos = vector.new()

        local y_rot = -math.deg(direction)
        pos.y = y_rot --okay, this is strange to keep here, but as I dont use it anyway...


        if ctrl.up or ctrl.down or ctrl.left or ctrl.right then
            if airutils.is_minetest then
                player_api.set_animation(player, "walk", 30)
            elseif airutils.is_mcl then
                mcl_player.player_set_animation(player, "walk")
            end

            local speed = 0.4

            dir = vector.new(ctrl.up and -1 or ctrl.down and 1 or 0, 0, ctrl.left and 1 or ctrl.right and -1 or 0)
            dir = vector.normalize(dir)
            dir = vector.rotate(dir, {x = 0, y = -direction, z = 0})

            local time_correction = (self.dtime/ju52.ideal_step)
            local move = speed * time_correction

            pos.x = move * dir.x
            pos.z = move * dir.z

            --lets fake walk sound
            if self._passengers_base_pos[index].dist_moved == nil then self._passengers_base_pos[index].dist_moved = 0 end
            self._passengers_base_pos[index].dist_moved = self._passengers_base_pos[index].dist_moved + move;
            if math.abs(self._passengers_base_pos[index].dist_moved) > 5 then
                self._passengers_base_pos[index].dist_moved = 0
                core.sound_play({name = "default_wood_footstep"},
                    {object = player, gain = 0.1,
                        max_hear_distance = 5,
                        ephemeral = true,})
            end
        else
            if airutils.is_minetest then
                player_api.set_animation(player, "stand")
            elseif airutils.is_mcl then
                mcl_player.player_set_animation(player, "stand")
            end
        end
    end
    return pos
end

function ju52.sit_player(self, player, value, target)
    local y_rot = 0
    if value == 1 then y_rot = 0 end
    if value == 2 then y_rot = 90 end
    if value == 3 then y_rot = 180 end
    if value == 4 then y_rot = 270 end
    player:set_attach(target, "", {x = 0, y = 3.6, z = 0}, {x = 0, y = y_rot, z = 0})

    local eye_y = -4
    player:set_eye_offset({x = 0, y = eye_y, z = 2}, {x = 0, y = 1, z = -30})

    airutils.sit(player)
end

function ju52.move_persons(self)
    --self._passenger = nil
    
    if self.object == nil then return end
    
    local max_pos = #self._seats
    --core.chat_send_all(dump(max_pos))
    for i = max_pos,1,-1 
    do
        local player = nil
        if self._passengers[i] then player = core.get_player_by_name(self._passengers[i]) end

        if self.driver_name and self._passengers[i] == self.driver_name then
            --clean driver if it's nil
            if player == nil then
                self._passengers[i] = nil
                self.driver_name = nil
            end
        else
            if self._passengers[i] ~= nil then
                --core.chat_send_all("pass: "..dump(self._passengers[i]))
                --the rest of the passengers
                if player then
                    if self._passenger_is_sit[i] == 0 then
                        local result_pos = get_result_pos(self, player, i)
                        local y_rot = 0
                        y_rot = result_pos.y -- the only field that returns a rotation
                        local new_pos = ju52.copy_vector(self._passengers_base_pos[i])
                        new_pos.x = new_pos.x - result_pos.z
                        new_pos.z = new_pos.z - result_pos.x
                        --core.chat_send_all(dump(new_pos))
                        local pos_d = ju52.navigate_deck(self, self._passengers_base_pos[i], new_pos, player)
                        --core.chat_send_all(dump(height))
                        if self._passengers_base_pos[i].x ~= pos_d.x or self._passengers_base_pos[i].z ~= pos_d.z or self._passengers_base_pos[i].y ~= pos_d.y then
                            --core.chat_send_all(dump(self.dtime))
                            self._passengers_base_pos[i] = ju52.copy_vector(pos_d)
                            self._passengers_base[i]:set_attach(self.object,'',self._passengers_base_pos[i],{x=0,y=0,z=0})
                        end
                        --core.chat_send_all(dump(self._passengers_base_pos[i]))
                        player:set_attach(self._passengers_base[i], "", {x = 0, y = 0, z = 0}, {x = 0, y = y_rot, z = 0})
                    end
                else
                    --self._passengers[i] = nil
                end
            end
        end
    end
end


-- ==================================================================================================
-- SPECIAL FOR ATTACHS
-- ==================================================================================================

function ju52.initialize(self)
    if not self._passenger_is_sit then
        self._passenger_is_sit = {}
        self._passengers_base_pos = {}
        self._chairs = {}
        
        local max_pos = #self._seats
        local pos = self.object:get_pos()
        for i = 1,max_pos,1 
        do
            local seat = vector.new(self._seats[i])
            self._passengers_base_pos[i] = {x=seat.x, y = seat.y, z = seat.z}
            self._passenger_is_sit[i] = 0
            
            if i > 2 then
                local chair=core.add_entity(pos,'ju52:chair_interactor')
                local seat_attach = vector.new(self._passengers_base_pos[i])
                seat_attach.y = seat_attach.y - 1.5
                chair:set_attach(self.object,'',seat_attach,{x=0,y=0,z=0})
                self._chairs[i] = chair
            else
                self._chairs[i] = nil
            end
        end
        local door=core.add_entity(pos,'ju52:door_interactor')
        door:set_attach(self.object,'',{x=-6.5,y=6.7,z=-48.0},{x=0,y=0,z=0})
        self._door = door
    end
end

function ju52.get_passenger_seat_index(self, name)
    local index = 0
    for i = #self._seats,1,-1 
    do
        if self._passengers[i] == name then
            index = i
            break
        end
    end

    return index
end

local function find_chair_index(self, curr_seat)
    for i = #self._seats,1,-1 
    do
        if self._chairs[i] == curr_seat then
            return i
        end
    end
    return 0
end

local function right_click_chair(self, clicker)
    local message = ""
	if not clicker or not clicker:is_player() then
		return
	end

    local name = clicker:get_player_name()
    local ship_self = nil

    local is_attached = false
    local seat = clicker:get_attach()
    if seat then
        ship_attach = seat:get_attach()
        if ship_attach then
            ship_self = ship_attach:get_luaentity()
            is_attached = true
        end
    end

    if is_attached then
        local index = ju52.get_passenger_seat_index(ship_self, name)
        if index > 0 then
            local chair_index = find_chair_index(ship_self, self.object)
            --minetest.chat_send_all("index: "..chair_index)
            if ship_self._passenger_is_sit[index] == 0 and chair_index then
                local dest_pos = vector.new(ship_self._seats[chair_index])
                if dest_pos then
                    dest_pos.y = dest_pos.y
                    ship_self._passengers_base_pos[index] = dest_pos
                    ship_self._passengers_base[index]:set_attach(ship_self.object,'',ship_self._passengers_base_pos[index],{x=0,y=0,z=0})
                    ship_self._passenger_is_sit[index] = 1
                    ju52.sit_player(ship_self, clicker, ship_self._passenger_is_sit[index], ship_self._passengers_base[index])
                end
            else
                ship_self._passenger_is_sit[index] = 0
                if airutils.is_minetest then
                    player_api.set_animation(clicker, "walk", 30)
                elseif airutils.is_mcl then
                    mcl_player.player_set_animation(clicker, "walk")
                end
                clicker:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            end
        end
    end
end

local function right_click_exit(self, clicker)
    local name = clicker:get_player_name()
    if name then ju52.pax_formspec(name) end
end

-- and item just to run the sit function
core.register_entity('ju52:chair_interactor',{
    initial_properties = {
	    physical = false,
	    collide_with_objects=true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1, 0.3},
	    pointable=true,
	    visual = "mesh",
	    mesh = "airutils_seat_base.b3d",
        textures = {"airutils_alpha.png",},
	},
    dist_moved = 0,
	
    on_activate = function(self,std)
	    self.sdata = minetest.deserialize(std) or {}
        self.object:set_armor_groups({immortal=1})
	    if self.sdata.remove then self.object:remove() end
    end,
	    
    get_staticdata=function(self)
      self.sdata.remove=true
      return minetest.serialize(self.sdata)
    end,

    on_rightclick = right_click_chair,
})

core.register_entity('ju52:door_interactor',{
    initial_properties = {
	    physical = false,
	    collide_with_objects=false,
        collisionbox = {-0.5, 0, -0.5, 0.5, 1.5, 0.5},
	    pointable=true,
	    visual = "mesh",
	    mesh = "airutils_seat_base.b3d",
        textures = {"airutils_alpha.png",},
	},
    dist_moved = 0,
	
    on_activate = function(self,std)
	    self.sdata = minetest.deserialize(std) or {}
        self.object:set_armor_groups({immortal=1})
	    if self.sdata.remove then self.object:remove() end
    end,
	    
    get_staticdata=function(self)
      self.sdata.remove=true
      return minetest.serialize(self.sdata)
    end,

    on_rightclick = right_click_exit,
})

-- attach passenger
function ju52.attach_pax(self, player, slot)
    slot = slot or 0
    local name = player:get_player_name()

    --verify if is locked to non-owners
    if self._passengers_locked == true then
        local can_bypass = core.check_player_privs(player, {protection_bypass=true})
        local is_shared = false
        if name == self.owner or can_bypass then is_shared = true end
        for k, v in pairs(self._shared_owners) do
            if v == name then
                is_shared = true
                break
            end
        end
        if is_shared == false then
            core.chat_send_player(name,core.colorize('#ff0000', " >>> This airship is currently locked for non-owners"))
            return
        end
    end


    if slot > 0 then
        do_attach(self, player, slot)
        return
    end
    --core.chat_send_all(dump(self._passengers))

    --now yes, lets attach the player
    --randomize the seat
    local t = {1,2,3,4,5,6,7,8,9,10,11,12}
    for i = 1, #t*2 do
        local a = math.random(#t)
        local b = math.random(#t)
        t[a],t[b] = t[b],t[a]
    end

    --core.chat_send_all(dump(t))

    local i=0
    for k,v in ipairs(t) do
        i = t[k]
        if self._passengers[i] == nil then
            do_attach(self, player, i)
            if name == self.owner then
                --put the owner on cabin directly
                self._passengers_base_pos[i] = {x=0,y=3.2,z=-45}
                self._passengers_base[i]:set_attach(self.object,'',self._passengers_base_pos[i],{x=0,y=0,z=0})
            end
            break
        end
    end
end

function ju52.check_passenger_is_attached(self, name)
    local is_attached = false
    local max_pos = #self._seats
    if is_attached == false then
        for i = max_pos,1,-1 
        do 
            if self._passengers[i] == name then
                is_attached = true
                break
            end
        end
    end
    return is_attached
end

function ju52.pax_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,3]",
	}, "")

    basic_form = basic_form.."label[1,1.0;Disembark:]"
    basic_form = basic_form.."button[1,1.2;4,1;go_out;Click to disembark]"

    minetest.show_formspec(name, "ju52:passenger_main", basic_form)
end

function ju52.copilot_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,3]",
	}, "")

    basic_form = basic_form.."label[1,1.0;Leave seat:]"
    basic_form = basic_form.."button[1,1.2;4,1;go_out;Click to leave the seat]"

    minetest.show_formspec(name, "ju52:copilot_main", basic_form)
end

function ju52.owner_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,4.2]",
	}, "")

	basic_form = basic_form.."button[1,1.0;4,1;take;Take the Control Now]"

    minetest.show_formspec(name, "ju52:owner_main", basic_form)
end

function ju52.right_click_function(self, clicker)
    local message = ""
	if not clicker or not clicker:is_player() then
		return
	end

    local name = clicker:get_player_name()

    local touching_ground, liquid_below = airutils.check_node_below(self.object, 2.5)
    local is_on_ground = self.isinliquid or touching_ground or liquid_below
    local is_under_water = airutils.check_is_under_water(self.object)

    --core.chat_send_all('passengers: '.. dump(self._passengers))
    --=========================
    --  form to pilot
    --=========================
    local is_attached = false
    local seat = clicker:get_attach()
    if seat then
        local plane = seat:get_attach()
        if plane == self.object then is_attached = true end
    end

    --check error after being shot for any other mod
    local max_pos = #self._seats
    if is_attached == false then
        for i = max_pos,1,-1 
        do 
            if self._passengers[i] == name then
                self._passengers[i] = nil --clear the wrong information
                break
            end
        end
    end

    --shows pilot formspec
    if name ~= self.driver_name then
        local pass_is_attached = ju52.check_passenger_is_attached(self, name)

        if pass_is_attached then
            --[[local can_bypass = core.check_player_privs(clicker, {protection_bypass=true})
            if clicker:get_player_control().aux1 == true then --lets see the inventory
                local is_shared = false
                if name == self.owner or can_bypass then is_shared = true end
                for k, v in pairs(self._shared_owners) do
                    if v == name then
                        is_shared = true
                        break
                    end
                end
                if is_shared then
                    airutils.show_vehicle_trunk_formspec(self, clicker, ju52.trunk_slots)
                end
            else
                ju52.pax_formspec(name)
            end]]--
        else
            --first lets clean the boat slots
            --note that when it happens, the "rescue" function will lost the historic
            for i = max_pos,1,-1 
            do 
                if self._passengers[i] ~= nil then
                    local old_player = core.get_player_by_name(self._passengers[i])
                    if not old_player then self._passengers[i] = nil end
                end
            end
            --attach normal passenger
            --if self._door_closed == false then
                ju52.attach_pax(self, clicker)
            --end
        end
    end

end

function ju52.set_player_sit(self, player, player_name, chair_index)
    --self._at_control = true
    for i = ju52.total_seats,1,-1 
    do 
        if self._passengers[i] == player_name then
            local index = ju52.get_passenger_seat_index(self, player_name)
            if index > 0 then
                if chair_index then
                    local dest_pos = vector.new(self._seats[chair_index])
                    if dest_pos then
                        dest_pos.y = dest_pos.y
                        self._passengers_base_pos[index] = dest_pos
                        self._passengers_base[index]:set_attach(self.object,'',self._passengers_base_pos[index],{x=0,y=0,z=0})
                        self._passenger_is_sit[index] = 1
                        ju52.sit_player(self, player, self._passenger_is_sit[index], self._passengers_base[index])
                    end
                    break
                end
            end
        end
    end --end for
end

function ju52.bring_copilot(self, copilot_name)
    local new_copilot_player_obj = core.get_player_by_name(copilot_name)
    if new_copilot_player_obj and self then
        --then move the current copilot to a free seat
        if self.co_pilot then
            local index = ju52.get_passenger_seat_index(self, self.co_pilot)
            self.co_pilot = nil
            if index > 0 then
                self._passenger_is_sit[index] = 0
                if airutils.is_minetest then
                    player_api.set_animation(new_copilot_player_obj, "walk", 30)
                elseif airutils.is_mcl then
                    mcl_player.player_set_animation(new_copilot_player_obj, "walk")
                end
            end
        end
        
        --so bring the new copilot
        self.co_pilot = copilot_name

        ju52.set_player_sit(self, new_copilot_player_obj, copilot_name, 2)
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "ju52:passenger_main" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:passenger_main")
            return
        end
        local ent = plane_obj:get_luaentity()
        if ent then
            if fields.go_out then
                local touching_ground, _ = airutils.check_node_below(plane_obj, 2.5)
                if ent.isinliquid or touching_ground then --isn't flying?
                    airutils.dettach_pax(ent, player)
                else
                    airutils.go_out_confirmation_formspec(name)
                end
            end
        end
        minetest.close_formspec(name, "ju52:passenger_main")
	end
	if formname == "ju52:copilot_main" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:copilot_main")
            return
        end
        local ent = plane_obj:get_luaentity()
        if ent then
            if fields.go_out then
                local index = ju52.get_passenger_seat_index(ent, name)
                if index > 0 then
                    ent._passenger_is_sit[index] = 0
                    if airutils.is_minetest then
                        player_api.set_animation(player, "walk", 30)
                    elseif airutils.is_mcl then
                        mcl_player.player_set_animation(player, "walk")
                    end
                    player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})

                    core.close_formspec(name, "ju52:copilot_main")
                    return true --stop and dont call the original method
                end
            end
        end
        minetest.close_formspec(name, "ju52:copilot_main")
	end
    if formname == "ju52:owner_main" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            minetest.close_formspec(name, "ju52:owner_main")
            return
        end
        local ent = plane_obj:get_luaentity()
        if ent then
		    if fields.take then
                ent._at_control = true
                ent.driver_name = name
                minetest.close_formspec(name, "ju52:owner_main")
                airutils.pilot_formspec(name)
                ju52.set_player_sit(ent, player, name, 1)
                return
		    end
        end
        minetest.close_formspec(name, "ju52:owner_main")
    end
    if formname == "lib_planes:pilot_main" then --yes, it's a method overwriting
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj then
            local ent = plane_obj:get_luaentity()
            if fields.go_out then
                local index = ju52.get_passenger_seat_index(ent, name)
                if index > 0 then
                    ent.driver_name = ""

                    ent._passenger_is_sit[index] = 0
                    if airutils.is_minetest then
                        player_api.set_animation(player, "walk", 30)
                    elseif airutils.is_mcl then
                        mcl_player.player_set_animation(player, "walk")
                    end
                    player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})

                    core.close_formspec(name, "lib_planes:pilot_main")
                    return true --stop and dont call the original method
                end
            end
        end
        core.close_formspec(name, "lib_planes:pilot_main")
    end
    if formname == "lib_planes:manage_copilot" then
        local name = player:get_player_name()
        local plane_obj = airutils.getPlaneFromPlayer(player)
        if plane_obj == nil then
            core.close_formspec(name, "lib_planes:manage_copilot")
            return true
        end
        local ent = plane_obj:get_luaentity()

        if fields.copilot then
            ju52.bring_copilot(ent, fields.copilot)
            minetest.close_formspec(name, "lib_planes:manage_copilot")
            return true
        end
        core.close_formspec(name, "lib_planes:manage_copilot")
    end

end)

