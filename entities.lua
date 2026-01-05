
--
-- entity
--

ju52.vector_up = vector.new(0, 1, 0)

local function right_click_controls(self, clicker)
    local message = ""
	if not clicker or not clicker:is_player() then
		return
	end

    local name = clicker:get_player_name()
    local ship_self = nil

    local is_attached = false
    local p_pos = clicker:get_attach()
    if p_pos then
        ship_attach = p_pos:get_attach()
        if ship_attach then
            ship_self = ship_attach:get_luaentity()
            is_attached = true
        end
    end


    if is_attached then
        --core.chat_send_all('passengers: '.. dump(ship_self._passengers))
        --=========================
        --  form to pilot
        --=========================
        if ship_self.owner == "" then
            ship_self.owner = name
        end
        local can_bypass = minetest.check_player_privs(clicker, {protection_bypass=true})
        --core.chat_send_all(dump(ship_self.driver_name))
        if ship_self.driver_name ~= nil and ship_self.driver_name ~= "" then
            --shows pilot formspec
            if name == ship_self.driver_name or (name == ship_self.co_pilot and ship_self._command_is_given == true) then
                airutils.pilot_formspec(name)
                return
            end
            --the copilot wants to walk a bit
            if name == ship_self.co_pilot and ship_self._command_is_given == false then
                ju52.copilot_formspec(name)
                return
            end
            --lets take the control by force
            if name == ship_self.owner or can_bypass then
                --require the pilot position now
                ju52.owner_formspec(name)
                return
            else
                ju52.pax_formspec(name)
                return
            end
        else
            --We are counting on copilot now
            if name == ship_self.co_pilot and (ship_self.driver_name == "" or ship_self.driver_name == nil) then
                ship_self.driver_name = name
                airutils.pilot_formspec(name)
                ju52.bring_copilot(ship_self, name)
                return
            end
            --I donw want to diiiieeeee
            --[[if (ship_self.co_pilot == "" or ship_self.co_pilot == nil) and (ship_self.driver_name == "" or ship_self.driver_name == nil) then
                ship_self.driver_name = name
                airutils.pilot_formspec(name)
                ju52.bring_copilot(ship_self, name)
                return
            end]]--
            --lets take the control by force
            if name == ship_self.owner or can_bypass then
                --require the pilot position now
                ju52.owner_formspec(name)
                return
            else
                --Adeus!
                ju52.pax_formspec(name)
            end
        end
    end


    --[[on_rightclick = function(self, clicker)
        local name = clicker:get_player_name()
        local parent_obj = self.object:get_attach()
        if not parent_obj then return end
        local parent_self = parent_obj:get_luaentity()
        local copilot_name = nil
        if parent_self.co_pilot and parent_self._have_copilot then
            copilot_name = parent_self.co_pilot
        end

        if name == parent_self.driver_name then
            local itmstck=clicker:get_wielded_item()
            local item_name = ""
            if itmstck then item_name = itmstck:get_name() end
            --adf program function
            if (item_name == "compassgps:cgpsmap_marked") then
                local meta = minetest.deserialize(itmstck:get_metadata())
                if meta then
                    parent_self._adf_destiny = {x=meta["x"], z=meta["z"]}
                end
            else
                --formspec of the plane
                if not parent_self._custom_pilot_formspec then
                    airutils.pilot_formspec(name)
                else
                    parent_self._custom_pilot_formspec(name)
                end
                airutils.sit(clicker)
            end
        --=========================
        --  detach copilot
        --=========================
        elseif name == copilot_name then
            if parent_self._command_is_given then
                --open the plane menu for the copilot
                --formspec of the plane
                if not parent_self._custom_pilot_formspec then
                    airutils.pilot_formspec(name)
                else
                    parent_self._custom_pilot_formspec(name)
                end
            else
                airutils.pax_formspec(name)
            end
        end
    end,]]--
end


minetest.register_entity('ju52:wheels',{
initial_properties = {
	physical = false,
	collide_with_objects=false,
	pointable=false,
	visual = "mesh",
    backface_culling = false,
	mesh = "ju52_wheels.b3d",
	textures = {
            "airutils_metal.png", --suporte bequilha
            ju52.skin_texture, --suporte trem
            "airutils_black.png", --pneu bequilha
            "airutils_metal.png", --roda bequilha
            "airutils_black.png", --pneu trem
            "airutils_metal.png", --roda trem
        },
	},

    on_activate = function(self,std)
	    self.sdata = minetest.deserialize(std) or {}
	    if self.sdata.remove then self.object:remove() end
    end,

    get_staticdata=function(self)
      self.sdata.remove=true
      return minetest.serialize(self.sdata)
    end,

})

minetest.register_entity('ju52:cabin_interactor',{
    initial_properties = {
	    physical = true,
	    collide_with_objects=true,
        collisionbox = {-1, 0, -1, 1, 3, 1},
	    visual = "mesh",
	    mesh = "airutils_seat_base.b3d",
        textures = {"airutils_alpha.png",},
	},
    dist_moved = 0,
    max_hp = 65535,

    on_activate = function(self,std)
        self.object:set_armor_groups({immortal=1})
	    self.sdata = minetest.deserialize(std) or {}
	    if self.sdata.remove then self.object:remove() end
    end,

    get_staticdata=function(self)
      self.sdata.remove=true
      return minetest.serialize(self.sdata)
    end,

    on_punch = function(self, puncher, ttime, toolcaps, dir, damage)
        return
        --minetest.chat_send_all("punch")
        --[[if not puncher or not puncher:is_player() then
            return
        end]]--
    end,

    on_rightclick = right_click_controls,

})

minetest.register_entity('ju52:ju52',
    airutils.properties_copy(ju52.plane_properties)
)

