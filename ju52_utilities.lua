dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_global_definitions.lua")
dofile(minetest.get_modpath("ju52") .. DIR_DELIM .. "ju52_hud.lua")

function ju52.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

function ju52.dot(v1,v2)
	return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
end

function ju52.sign(n)
	return n>=0 and 1 or -1
end

function ju52.minmax(v,m)
	return math.min(math.abs(v),m)*ju52.sign(v)
end

--lift
local function pitchroll2pitchyaw(aoa,roll)
	if roll == 0.0 then return aoa,0 end
	-- assumed vector x=0,y=0,z=1
	local p1 = math.tan(aoa)
	local y = math.cos(roll)*p1
	local x = math.sqrt(p1^2-y^2)
	local pitch = math.atan(y)
	local yaw=math.atan(x)*math.sign(roll)
	return pitch,yaw
end

function ju52.getLiftAccel(self, velocity, accel, longit_speed, roll, curr_pos)
    --lift calculations
    -----------------------------------------------------------
    local max_height = 20000
    
    local retval = accel
    if longit_speed > 1 then
        local angle_of_attack = math.rad(self._angle_of_attack + self._wing_configuration)
        local lift = ju52.lift
        --local acc = 0.8
        local daoa = deg(angle_of_attack)

        --to decrease the lift coefficient at hight altitudes
        local curr_percent_height = (100 - ((curr_pos.y * 100) / max_height))/100

	    local rotation=self.object:get_rotation()
	    local vrot = mobkit.dir_to_rot(velocity,rotation)
	    
	    local hpitch,hyaw = pitchroll2pitchyaw(angle_of_attack,roll)

	    local hrot = {x=vrot.x+hpitch,y=vrot.y-hyaw,z=roll}
	    local hdir = mobkit.rot_to_dir(hrot) --(hrot)
	    local cross = vector.cross(velocity,hdir)
	    local lift_dir = vector.normalize(vector.cross(cross,hdir))

        local lift_coefficient = (0.24*abs(daoa)*(1/(0.025*daoa+3))^4*math.sign(angle_of_attack))
        local lift_val = math.abs((lift*(vector.length(velocity)^2)*lift_coefficient)*curr_percent_height)
        --minetest.chat_send_all('lift: '.. lift_val)

        local lift_acc = vector.multiply(lift_dir,lift_val)
        --lift_acc=vector.add(vector.multiply(minetest.yaw_to_dir(rotation.y),acc),lift_acc)

        retval = vector.add(retval,lift_acc)
    end
    -----------------------------------------------------------
    -- end lift
    return retval
end


function ju52.get_gauge_angle(value, initial_angle)
    initial_angle = initial_angle or 90
    local angle = value * 18
    angle = angle - initial_angle
    angle = angle * -1
	return angle
end

-- attach player
function ju52.attach(self, player)
    local name = player:get_player_name()
    self.driver_name = name

    -- attach the driver
    player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 1, z = -30})
    player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    -- make the driver sit
    minetest.after(0.2, function()
        player = minetest.get_player_by_name(name)
        if player then
	        player_api.set_animation(player, "sit")
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

function ju52.dettachPlayer(self, player)
    local name = self.driver_name
    ju52.setText(self)

    --self._engine_running = false

    -- driver clicked the object => driver gets off the vehicle
    self.driver_name = nil

    if self._engine_running then
	    self._engine_running = false
        self.engine:set_animation_frame_speed(0)
    end
    -- sound and animation
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    -- detach the player
    if player then
        ju52.remove_hud(player)

        player:set_detach()
        player_api.player_attached[name] = nil
        player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
        player_api.set_animation(player, "stand")
    end
    self.driver = nil
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function ju52.check_passenger_is_attached(self, name)
    local is_attached = false
    if self._passenger == name then is_attached = true end
    if is_attached == false then
        for i = 10,1,-1 
        do 
            if self._passengers[i] == name then
                is_attached = true
                break
            end
        end
    end
    return is_attached
end


-- attach passenger
function ju52.attach_pax(self, player, is_copilot)
    local is_copilot = is_copilot or false
    local name = player:get_player_name()

    if is_copilot == true then
        if self._passenger == nil then
            self._passenger = name

            -- attach the driver
            player:set_attach(self.co_pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 3, z = -30})
            player_api.player_attached[name] = true
            -- make the driver sit
            minetest.after(0.2, function()
                player = minetest.get_player_by_name(name)
                if player then
	                player_api.set_animation(player, "sit")
                    --apply_physics_override(player, {speed=0,gravity=0,jump=0})
                end
            end)
        end
    else
        --randomize the seat
        local t = {1,2,3,4,5,6,7,8,9,10}
        for i = 1, #t*2 do
            local a = math.random(#t)
            local b = math.random(#t)
            t[a],t[b] = t[b],t[a]
        end

        --for i = 1,10,1 do
        for k,v in ipairs(t) do
            i = t[k]
            if self._passengers[i] == nil then
                --minetest.chat_send_all(self.driver_name)
                self._passengers[i] = name
                player:set_attach(self._passengers_base[i], "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
                if i > 2 then
                    player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 3, z = -30})
                else
                    player:set_eye_offset({x = 0, y = -4, z = 0}, {x = 0, y = 3, z = -30})
                end
                player_api.player_attached[name] = true
                -- make the driver sit
                minetest.after(0.2, function()
                    player = minetest.get_player_by_name(name)
                    if player then
	                    player_api.set_animation(player, "sit")
                        --apply_physics_override(player, {speed=0,gravity=0,jump=0})
                    end
                end)
                break
            end
        end

    end
end

function ju52.dettach_pax(self, player)
    local name = player:get_player_name() --self._passenger

    -- passenger clicked the object => driver gets off the vehicle
    if self._passenger == name then
        self._passenger = nil
    else
        for i = 10,1,-1 
        do 
            if self._passengers[i] == name then
                self._passengers[i] = nil
                break
            end
        end
    end

    -- detach the player
    player:set_detach()
    player_api.player_attached[name] = nil
    player_api.set_animation(player, "stand")
    player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function ju52.checkAttach(self, player)
    if player then
        local player_attach = player:get_attach()
        if player_attach then
            if player_attach == self.pilot_seat_base or player_attach == self.co_pilot_seat_base then
                return true
            end
        end
    end
    return false
end

--painting
function ju52.paint(object, colstr, search_string)
    if colstr then
        local entity = object:get_luaentity()
        entity._color = colstr
        entity._skin = ju52.skin_texture
        local l_textures = ju52.textures_copy()
        for _, texture in ipairs(l_textures) do
            local indx = texture:find(search_string)
            if indx then
                l_textures[_] = search_string .."^[multiply:".. colstr
            end
        end
        object:set_properties({textures=l_textures})
    end
end

function ju52.set_skin(object, skin_image_name, search_string)
    if skin_image_name then
        local entity = object:get_luaentity()
        entity._color = nil
        entity._skin = skin_image_name
        local l_textures = ju52.textures_copy()
        for _, texture in ipairs(l_textures) do
            local indx = texture:find(search_string)
            if indx then
                l_textures[_] = skin_image_name
                --minetest.chat_send_all(l_textures[_])
            end
        end
        object:set_properties({textures=l_textures})
    end
end

function ju52.start_engine(self)
    if self._engine_running then
	    self._engine_running = false
        -- sound and animation
        if self.sound_handle then
            minetest.sound_stop(self.sound_handle)
            self.sound_handle = nil
        end
        self.engine:set_animation_frame_speed(0)
        self._power_lever = 0 --zero power
    elseif self._engine_running == false and self._energy > 0 then
	    self._engine_running = true
        -- sound and animation
        ju52.engineSoundPlay(self)
        self.engine:set_animation_frame_speed(60)
    end
end

-- destroy the boat
function ju52.destroy(self)
    if self._engine_running then
	    self._engine_running = false
        self.engine:set_animation_frame_speed(0)
    end
    -- sound and animation
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self.driver_name then
        -- detach the driver
        local player = minetest.get_player_by_name(self.driver_name)
        ju52.dettachPlayer(self, player)
    end

    local pos = self.object:get_pos()
    if self.engine then self.engine:remove() end
    if self.pilot_seat_base then self.pilot_seat_base:remove() end
    if self.co_pilot_seat_base then self.co_pilot_seat_base:remove() end

    if self._passengers_base[10] then self._passengers_base[10]:remove() end
    if self._passengers_base[9]  then self._passengers_base[9]:remove() end
    if self._passengers_base[8]  then self._passengers_base[8]:remove() end
    if self._passengers_base[7]  then self._passengers_base[7]:remove() end
    if self._passengers_base[6]  then self._passengers_base[6]:remove() end
    if self._passengers_base[5]  then self._passengers_base[5]:remove() end
    if self._passengers_base[4]  then self._passengers_base[4]:remove() end
    if self._passengers_base[3]  then self._passengers_base[3]:remove() end
    if self._passengers_base[2]  then self._passengers_base[2]:remove() end
    if self._passengers_base[1]  then self._passengers_base[1]:remove() end

    if self.stick then self.stick:remove() end

    self.object:remove()

    pos.y=pos.y+2
    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'ju52:wings')

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,4 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:wood')
    end

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
    end

    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'ju52:ju52')
end

function ju52.check_node_below(obj)
    local pos_below = obj:get_pos()
    if pos_below then
        pos_below.y = pos_below.y - 2.5
        local node_below = minetest.get_node(pos_below).name
        local nodedef = minetest.registered_nodes[node_below]
        local touching_ground = not nodedef or -- unknown nodes are solid
		        nodedef.walkable or false
        local liquid_below = not touching_ground and nodedef.liquidtype ~= "none"
        return touching_ground, liquid_below
    end
    return nil, nil
end

function ju52.setText(self)
    local properties = self.object:get_properties()
    local formatted = string.format(
       "%.2f", self.hp_max
    )
    if properties then
        properties.infotext = "Nice Ju52 of " .. self.owner .. ". Current hp: " .. formatted
        self.object:set_properties(properties)
    end
end

function ju52.testImpact(self, velocity, position)
    local p = position --self.object:get_pos()
    local collision = false
    if self._last_vel == nil then return end
    --lets calculate the vertical speed, to avoid the bug on colliding on floor with hard lag
    if abs(velocity.y - self._last_vel.y) > 4 then
		local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
		    collision = true
	    else
            self.object:set_velocity(self._last_vel)
            --self.object:set_acceleration(self._last_accell)
        end
    end
    local impact = abs(ju52.get_hipotenuse_value(velocity, self._last_vel))
    --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
    if impact > 2 then
        --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
		local nodeu = mobkit.nodeatpos(mobkit.pos_shift(p,{y=1}))
		local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
        local nodel = mobkit.nodeatpos(mobkit.pos_shift(p,{x=-1}))
        local noder = mobkit.nodeatpos(mobkit.pos_shift(p,{x=1}))
        local nodef = mobkit.nodeatpos(mobkit.pos_shift(p,{z=1}))
        local nodeb = mobkit.nodeatpos(mobkit.pos_shift(p,{z=-1}))
		if (nodeu and nodeu.drawtype ~= 'airlike') or
            (nodef and nodef.drawtype ~= 'airlike') or
            (nodeb and nodeb.drawtype ~= 'airlike') or
            (noder and noder.drawtype ~= 'airlike') or
            (nodel and nodel.drawtype ~= 'airlike') then
			collision = true
		end
    end

    if impact > 1 and self._longit_speed > 2 then
        local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
            minetest.sound_play("ju52_touch", {
                --to_player = self.driver_name,
                object = self.object,
                max_hear_distance = 15,
                gain = 1.0,
                fade = 0.0,
                pitch = 1.0,
            }, true)
	    end
    end

    if collision then
        --self.object:set_velocity({x=0,y=0,z=0})
        local damage = impact / 2
        self.hp_max = self.hp_max - damage --subtract the impact value directly to hp meter
        minetest.sound_play("ju52_collision", {
            --to_player = self.driver_name,
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 1.0,
        }, true)

        if self.driver_name then
            local player_name = self.driver_name
            ju52.setText(self)

            --minetest.chat_send_all('damage: '.. damage .. ' - hp: ' .. self.hp_max)
            if self.hp_max < 0 then --if acumulated damage is greater than 50, adieu
                ju52.destroy(self)
            end

            local player = minetest.get_player_by_name(player_name)
            if player then
		        if player:get_hp() > 0 then
			        player:set_hp(player:get_hp()-(damage/2))
		        end
            end
            if self._passenger ~= nil then
                local passenger = minetest.get_player_by_name(self._passenger)
                if passenger then
		            if passenger:get_hp() > 0 then
			            passenger:set_hp(passenger:get_hp()-(damage/2))
		            end
                end
            end
        end

    end
end

function ju52.checkattachBug(self)
    -- for some engine error the player can be detached from the submarine, so lets set him attached again
    if self.owner and self.driver_name then
        -- attach the driver again
        local player = minetest.get_player_by_name(self.owner)
        if player then
		    if player:get_hp() > 0 then
                ju52.attach(self, player)
            else
                ju52.dettachPlayer(self, player)
		    end
        else
            if self._passenger ~= nil and self._command_is_given == false then
                self._autopilot = false
                ju52.transfer_control(self, true)
            end
        end
    end
end

function ju52.check_is_under_water(obj)
	local pos_up = obj:get_pos()
	pos_up.y = pos_up.y + 0.1
	local node_up = minetest.get_node(pos_up).name
	local nodedef = minetest.registered_nodes[node_up]
	local liquid_up = nodedef.liquidtype ~= "none"
	return liquid_up
end

function ju52.transfer_control(self, status)
    if status == false then
        self._command_is_given = false
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#ff0000', " >>> The captain got the control."))
        end
        if self.driver_name then
            minetest.chat_send_player(self.driver_name,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
    else
        self._command_is_given = true
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
        if self.driver_name then minetest.chat_send_player(self.driver_name," >>> The control was given.") end
    end
end

function ju52.flap_on(self)
    self._wing_configuration = 3
    self.object:set_bone_position("l_flap1", {x=-40.5, y=2.3, z=1}, {x=6, y=8, z=96.2}) --recolhido {x=6, y=-8, z=94.4}  extendido {x=6, y=8, z=96.2}
    --self.object:set_bone_position("l_flap2", {x=0, y=9, z=0}, {x=6, y=8, z=96.2}) --recolhido {x=2.4, y=0, z=91}  extendido {x=6, y=8, z=96.2}

    self.object:set_bone_position("r_flap1", {x=40.5, y=2.3, z=1}, {x=347, y=242, z=275.8}) --recolhido {x=338,y=254,z=286}  extendido {x=347, y=242, z=275.8}
    --self.object:set_bone_position("r_flap2", {x=0, y=9, z=0}, {x=145, y=290, z=122}) --recolhido {x=58, y=283, z=213}  extendido {x=145, y=290, z=122}

end

function ju52.flap_off(self)
    self._wing_configuration = ju52.wing_angle_of_attack
    self.object:set_bone_position("l_flap1", {x=-40.5, y=2.3, z=1}, {x=6, y=-8, z=94.4}) --recolhido {x=6, y=-8, z=94.4}  extendido {x=6, y=8, z=96.2}
    --self.object:set_bone_position("l_flap2", {x=0, y=9, z=0}, {x=2.4, y=4, z=91}) --recolhido {x=2.4, y=0, z=91}  extendido {x=6, y=8, z=96.2}

    self.object:set_bone_position("r_flap1", {x=40.5, y=2.3, z=1}, {x=338,y=254,z=286}) --recolhido {x=338,y=254,z=286}  extendido {x=347, y=242, z=275.8}
    --self.object:set_bone_position("r_flap2", {x=0, y=9, z=0}, {x=58, y=283, z=212}) --recolhido {x=58, y=283, z=213}  extendido {x=145, y=290, z=122}

end

function ju52.flap_operate(self, player)
    if self._flap == false then
        minetest.chat_send_player(player:get_player_name(), ">>> Flap down")
        self._flap = true
        ju52.flap_on(self)
        minetest.sound_play("ju52_collision", {
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 0.5,
        }, true)
    else
        minetest.chat_send_player(player:get_player_name(), ">>> Flap up")
        self._flap = false
        ju52.flap_off(self)
        minetest.sound_play("ju52_collision", {
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 0.7,
        }, true)
    end
end

--xyz = {x=66, y=283, z=205}

function ju52.flightstep(self)
    local velocity = self.object:get_velocity()
    local curr_pos = self.object:get_pos()
    
    self._last_time_command = self._last_time_command + self.dtime
    local player = nil
    if self.driver_name then player = minetest.get_player_by_name(self.driver_name) end
    local passenger = nil
    if self._passenger then passenger = minetest.get_player_by_name(self._passenger) end

    if player then
        local ctrl = player:get_player_control()

        --[[ --debug bones
        local scale = 1
        if ctrl.left then --ctrl.up or ctrl.down or ctrl.right or ctrl.left
            if ctrl.sneak then --ctrl.up or ctrl.down or ctrl.right or ctrl.left
                xyz.x = xyz.x - scale
                if xyz.x < 0 then xyz.x = xyz.x + 360 end
            else
                xyz.x = xyz.x + scale
                if xyz.x > 360 then xyz.x = xyz.x - 360 end
            end
        end
        if ctrl.down then
            if ctrl.sneak then
                xyz.y = xyz.y - scale
                if xyz.y < 0 then xyz.y = xyz.y + 360 end
            else
                xyz.y = xyz.y + scale
                if xyz.y > 360 then xyz.y = xyz.y - 360 end
            end
        end
        if ctrl.right then
            if ctrl.sneak then
                xyz.z = xyz.z - scale
                if xyz.z < 0 then xyz.z = xyz.z + 360 end
            else
                xyz.z = xyz.z + scale
                if xyz.z > 360 then xyz.z = xyz.z - 360 end
            end
        end]]--
        
        ---------------------
        -- change the driver
        ---------------------
        if passenger and self._last_time_command >= 1 then
            if self._command_is_given == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    --take the control
                    ju52.transfer_control(self, false)
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    --trasnfer the control to student
                    ju52.transfer_control(self, true)
                end
            end
        end
        -----------
        --autopilot
        -----------
        if self._last_time_command >= 1 then
            if self._autopilot == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    self._autopilot = false
                    minetest.chat_send_player(self.driver_name," >>> Autopilot deactivated")
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    self._autopilot = true
                    self._auto_pilot_altitude = curr_pos.y
                    minetest.chat_send_player(self.driver_name,core.colorize('#00ff00', " >>> Autopilot on"))
                end
            end
        end
    end

    local accel_y = self.object:get_acceleration().y
    local rotation = self.object:get_rotation()
    local yaw = rotation.y
	local newyaw=yaw
    local pitch = rotation.x
	local roll = rotation.z
	local newroll=roll
    if newroll > 360 then newroll = newroll - 360 end
    if newroll < -360 then newroll = newroll + 360 end

    local hull_direction = mobkit.rot_to_dir(rotation) --minetest.yaw_to_dir(yaw)
    local nhdir = {x=hull_direction.z,y=0,z=-hull_direction.x}		-- lateral unit vector

    local longit_speed = vector.dot(velocity,hull_direction)
    self._longit_speed = longit_speed
    local longit_drag = vector.multiply(hull_direction,longit_speed*
            longit_speed*JU52_LONGIT_DRAG_FACTOR*-1*ju52.sign(longit_speed))
	local later_speed = ju52.dot(velocity,nhdir)
    --minetest.chat_send_all('later_speed: '.. later_speed)
	local later_drag = vector.multiply(nhdir,later_speed*later_speed*
            JU52_LATER_DRAG_FACTOR*-1*ju52.sign(later_speed))
    local accel = vector.add(longit_drag,later_drag)
    local stop = false

    local is_flying = true
    if self.isonground then is_flying = false end
    --if is_flying then minetest.chat_send_all('is flying') end

    local is_attached = ju52.checkAttach(self, player)

    --ajustar angulo de ataque
    local percentage = math.abs(((longit_speed * 100)/(ju52.min_speed + 5))/100)
    if percentage > 1.5 then percentage = 1.5 end
    self._angle_of_attack = self._angle_of_attack - ((self._elevator_angle / 20)*percentage)
    if self._angle_of_attack < -0.5 then
        self._angle_of_attack = -0.1
        self._elevator_angle = self._elevator_angle - 0.1
    end --limiting the negative angle]]--
    if self._angle_of_attack > 20 then
        self._angle_of_attack = 20
        self._elevator_angle = self._elevator_angle + 0.1
    end --limiting the very high climb angle due to strange behavior]]--

    --minetest.chat_send_all(self._angle_of_attack)

    -- pitch
    local speed_factor = 0
    if longit_speed > ju52.min_speed + 1 then speed_factor = (velocity.y * math.rad(2)) end
    local newpitch = math.rad(self._angle_of_attack) + speed_factor

    -- new yaw
	if math.abs(self._rudder_angle)>1 then
        local turn_rate = math.rad(12)
        local turn = math.rad(self._rudder_angle) * turn_rate
        local yaw_turn = self.dtime * (turn * ju52.sign(longit_speed) * math.abs(longit_speed/2))
		newyaw = yaw + yaw_turn
	end

    --roll adjust
    ---------------------------------
    local delta = 0.002
    if is_flying then
        local roll_reference = newyaw
        local sdir = minetest.yaw_to_dir(roll_reference)
        local snormal = {x=sdir.z,y=0,z=-sdir.x}	-- rightside, dot is negative
        local prsr = ju52.dot(snormal,nhdir)
        local rollfactor = -90
        local roll_rate = math.rad(12)
        newroll = (prsr*math.rad(rollfactor)) * (later_speed * roll_rate) * ju52.sign(longit_speed)
        --minetest.chat_send_all('newroll: '.. newroll)
    else
        delta = 0.2
        if roll > 0 then
            newroll = roll - delta
            if newroll < 0 then newroll = 0 end
        end
        if roll < 0 then
            newroll = roll + delta
            if newroll > 0 then newroll = 0 end
        end
    end

    ---------------------------------
    -- end roll

	if not is_attached then
        -- for some engine error the player can be detached from the machine, so lets set him attached again
        ju52.checkattachBug(self)
    end

    local pilot = player
    if self._command_is_given and passenger then
        pilot = passenger
    else
        self._command_is_given = false
    end

    ------------------------------------------------------
    --accell calculation block
    ------------------------------------------------------
    if is_attached or passenger then
        accel, stop = ju52.control(self, self.dtime, hull_direction,
            longit_speed, longit_drag, later_speed, later_drag, accel, pilot, is_flying)
    end

    --end accell

    if accel == nil then accel = {x=0,y=0,z=0} end

    --lift calculation
    --accel.y = accel_y
    accel.y = accel.y + mobkit.gravity

    --lets apply some bob in water
	if self.isinliquid then
        local bob = ju52.minmax(ju52.dot(accel,hull_direction),0.4)	-- vertical bobbing
        accel.y = accel.y + bob
        local max_pitch = 6
        local h_vel_compensation = (((longit_speed * 4) * 100)/max_pitch)/100
        if h_vel_compensation < 0 then h_vel_compensation = 0 end
        if h_vel_compensation > max_pitch then h_vel_compensation = max_pitch end
        newpitch = newpitch + (velocity.y * math.rad(max_pitch - h_vel_compensation))
    end

    local new_accel = accel
    if longit_speed > ju52.min_speed / 2 then
        new_accel = ju52.getLiftAccel(self, velocity, new_accel, longit_speed, roll, curr_pos)
    end
    -- end lift

    if stop ~= true then
        self._last_accell = new_accel
	    self.object:set_pos(curr_pos)
        self.object:set_velocity(velocity)
        mobkit.set_acceleration(self.object, new_accel)
    elseif stop == true then
        self._last_accell = {x=0, y=0, z=0}
        self.object:set_velocity({x=0,y=0,z=0})
    end
    ------------------------------------------------------
    -- end accell
    ------------------------------------------------------

    --adjust climb indicator
    local climb_rate = velocity.y -- * 1.5
    if climb_rate > 5 then climb_rate = 5 end
    if climb_rate < -5 then
        climb_rate = -5
    end

    --is an stall, force a recover
    if self._angle_of_attack > 5 and climb_rate < -3 then
        self._elevator_angle = 0
        self._angle_of_attack = -1
        newpitch = math.rad(self._angle_of_attack)
    end

    --minetest.chat_send_all('rate '.. climb_rate)
    local climb_angle = ju52.get_gauge_angle(climb_rate)

    local indicated_speed = longit_speed
    if indicated_speed < 0 then indicated_speed = 0 end
    local speed_angle = ju52.get_gauge_angle(indicated_speed, -45)
    --adjust power indicator
    local power_indicator_angle = ju52.get_gauge_angle(self._power_lever/10) + 90
    local energy_indicator_angle = ju52.get_gauge_angle((JU52_MAX_FUEL - self._energy)/3) - 90

    if is_attached then
        if self._show_hud then
            ju52.update_hud(player, climb_angle, speed_angle, power_indicator_angle, energy_indicator_angle)
        else
            ju52.remove_hud(player)
        end
    end

    -- adjust pitch at ground
    local tail_lift_min_speed = 3
    local tail_lift_max_speed = 12
    local tail_angle = 17.4
    if math.abs(longit_speed) > tail_lift_min_speed then
        if math.abs(longit_speed) < tail_lift_max_speed then
            --minetest.chat_send_all(math.abs(longit_speed))
            local speed_range = tail_lift_max_speed - tail_lift_min_speed
            percentage = 1-((math.abs(longit_speed) - tail_lift_min_speed)/speed_range)
            if percentage > 1 then percentage = 1 end
            if percentage < 0 then percentage = 0 end
            local angle = tail_angle * percentage
            local calculated_newpitch = math.rad(angle)
            if newpitch < calculated_newpitch then newpitch = calculated_newpitch end --ja aproveita o pitch atual se ja estiver cerrto
            if newpitch > math.rad(tail_angle) then newpitch = math.rad(tail_angle) end --não queremos arrastar o cauda no chão
        end
    else
        if math.abs(longit_speed) < tail_lift_min_speed then newpitch = math.rad(tail_angle) end
    end

    if is_flying == false then --isn't flying?
        --animate wheels
        self.object:set_animation_frame_speed(longit_speed * 10)
    else
        --stop wheels
        self.object:set_animation_frame_speed(0)
    end

    --apply rotations
	if newyaw~=yaw or newpitch~=pitch or newroll~=roll then
        self.object:set_rotation({x=newpitch,y=newyaw,z=newroll})
    end

    self.object:set_bone_position("speed1", {x=-6.5, y=-40.6, z=16.6}, {x=0, y=-speed_angle, z=0})
    self.object:set_bone_position("speed2", {x=6.5, y=-40.6, z=16.6}, {x=0, y=-speed_angle, z=0})
    self.object:set_bone_position("climber1", {x=-9.5, y=-40.6, z=16.6}, {x=0, y=-(climb_angle-90), z=0})
    self.object:set_bone_position("climber2", {x=3.5, y=-40.6, z=16.6}, {x=0, y=-(climb_angle-90), z=0})
    self.object:set_bone_position("fuel", {x=0, y=-40.6, z=15.35}, {x=0, y=(energy_indicator_angle+180), z=0})
    self.object:set_bone_position("compass", {x=0, y=-40.55, z=18.2}, {x=0, y=(math.deg(newyaw)), z=0})

    --altimeters
    --[[lets adopt a convention here... The minetest clouds are very low
        in a normal situation I would consider 1000 feet as 320 blocks, but in minetest I could
        divide it by 4
     ]]--
    local altitude = (curr_pos.y * 4) / 320
    local hour, minutes = math.modf( altitude )
    hour = math.fmod (hour, 10)
    minutes = math.floor(minutes * 100)
    minutes = (minutes * 100) / 100
    local minute_angle = (minutes*-360)/100
    local hour_angle = (hour*-360)/10 + ((minute_angle*36)/360)

    self.object:set_bone_position("altimeter_p1_1", {x=-3.5, y=-40.6, z=16.6}, {x=0, y=-(hour_angle), z=0})
    self.object:set_bone_position("altimeter_p2_1", {x=-3.5, y=-41.1, z=16.6}, {x=0, y=-(minute_angle), z=0})

    self.object:set_bone_position("altimeter_p1_2", {x=9.5, y=-40.6, z=16.6}, {x=0, y=-(hour_angle), z=0})
    self.object:set_bone_position("altimeter_p2_2", {x=9.5, y=-41.1, z=16.6}, {x=0, y=-(minute_angle), z=0})

    --power
    local power_angle = ((self._power_lever*1.5)/4.5)
    self.object:set_bone_position("power", {x=1, y=-37.4, z=14}, {x=0, y=-(power_angle - 20), z=90}) --(power_indicator_angle-45)

    --adjust elevator pitch (3d model)
    self.object:set_bone_position("elevator", {x=0, y=77.5, z=23}, {x=-self._elevator_angle*1.2, y=0, z=0})
    self.object:set_bone_position("rudder", {x=0, y=82.1, z=26.4}, {x=1.4, y=180, z=self._rudder_angle})


    if self._wing_configuration == ju52.wing_angle_of_attack and self._flap then
        ju52.flap_on(self)
    end
    if self._wing_configuration ~= ju52.wing_angle_of_attack and self._flap == false then
        ju52.flap_off(self)
    end

    --self.object:set_bone_position("l_aileron", {x=-93.79, y=4.8, z=6.5}, {x=6.7, y=0, z=97.25})
    --local l_aileron_rotation = {x=1, y=1, z=-2}
    --local l_aileron_rotation = vector.rotate_around_axis({x=6.7, y=5, z=97.25}, l_aileron_rotation, math.rad(30))
    --minetest.chat_send_all("x: " .. l_aileron_rotation.x .. " - y: " .. l_aileron_rotation.y .. " - z: " .. l_aileron_rotation.z)
    --self.object:set_bone_position("l_aileron", {x=-93.79, y=4.8, z=6.5}, l_aileron_rotation)


    -- calculate energy consumption --
    ju52.consumptionCalc(self, accel)

    --test collision
    ju52.testImpact(self, velocity, curr_pos)

    --saves last velocity for collision detection (abrupt stop)
    self._last_vel = self.object:get_velocity()
end

