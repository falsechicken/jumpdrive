
local has_travelnet_mod = minetest.get_modpath("travelnet")
local has_technic_mod = minetest.get_modpath("technic")
local has_elevator_mod = minetest.get_modpath("elevator")


minetest.register_node("jumpdrive:engine", {
	description = "Jumpdrive",
	tiles = {"jumpdrive.png"},
	light_source = 13,
	groups = {cracky=3,oddly_breakable_by_hand=3,technic_machine = 1, technic_hv = 1},
	drop = "jumpdrive:engine",
	sounds = default.node_sound_glass_defaults(),

	mesecons = {effector = {
		action_on = function (pos, node)
			jumpdrive.execute_jump(pos)
		end
	}},

	connects_to = {"group:technic_hv_cable"},
	connect_sides = {"bottom", "top", "left", "right", "front", "back"},

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
	end,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_int("x", pos.x)
		meta:set_int("y", pos.y)
		meta:set_int("z", pos.z)
		meta:set_int("radius", 5)
		meta:set_int("powerstorage", 0)
		meta:set_int("cascade", 0)

		local inv = meta:get_inventory()
		inv:set_size("main", 8)

		if has_technic_mod then
			meta:set_int("HV_EU_input", 0)
			meta:set_int("HV_EU_demand", 0)
		end

		jumpdrive.update_formspec(meta)
	end,

	technic_run = function(pos, node)
		local meta = minetest.get_meta(pos)
		local eu_input = meta:get_int("HV_EU_input")
		local demand = meta:get_int("HV_EU_demand")
		local store = meta:get_int("powerstorage")

		meta:set_string("infotext", "Power: " .. eu_input .. "/" .. demand .. " Store: " .. store)

		if store < jumpdrive.config.powerstorage then
			-- charge
			meta:set_int("HV_EU_demand", jumpdrive.config.powerrequirement)
			store = store + eu_input
			meta:set_int("powerstorage", store)
		else
			-- charged
			meta:set_int("HV_EU_demand", 0)
		end
	end,

	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,

	on_receive_fields = function(pos, formname, fields, sender)

		local meta = minetest.get_meta(pos);

		if fields.toggle_cascade then
			local cascade = meta:get_int("cascade");
			if cascade == 0 or cascade == nil then
				cascade = 1
			else
				cascade = 0
			end

			meta:set_int("cascade", cascade)

			-- update form
			jumpdrive.update_formspec(meta)
			return
		end

		if fields.read_book then
			jumpdrive.read_from_book(pos)
			return
		end

		if fields.reset then
			jumpdrive.reset_coordinates(pos)
			return
		end

		if fields.write_book then
			jumpdrive.write_to_book(pos, sender)
			return
		end

		local x = tonumber(fields.x);
		local y = tonumber(fields.y);
		local z = tonumber(fields.z);
		local radius = tonumber(fields.radius);

		if x == nil or y == nil or z == nil or radius == nil or radius < 1 then
			return
		end

		local max_radius = jumpdrive.config.max_radius

		if radius > max_radius then
			minetest.chat_send_player(sender:get_player_name(), "Invalid jump: max-radius=" .. max_radius)
			return
		end

		local minjumpdistance = radius * 2

		if math.abs(x - pos.x) <= minjumpdistance and math.abs(y - pos.y) <= minjumpdistance and math.abs(z - pos.z) <= minjumpdistance then
			minetest.chat_send_player(sender:get_player_name(), "Jump too short")
			return
		end



		-- update coords
		meta:set_int("x", x)
		meta:set_int("y", y)
		meta:set_int("z", z)
		meta:set_int("radius", radius)
		jumpdrive.update_formspec(meta)

		if fields.jump then
			local start = os.clock()
			jumpdrive.execute_jump(pos, sender)

			local diff = os.clock() - start	
			minetest.chat_send_player(sender:get_player_name(), "Jump executed in " .. diff .. " s")
		end

		if fields.show then
			local stats = jumpdrive.simulate_jump(pos)
			minetest.chat_send_player(sender:get_player_name(), "Jump-Stats: engine-count: " .. stats.enginecount)
		end
		
	end
})

if has_technic_mod then
	technic.register_machine("HV", "jumpdrive:engine", technic.receiver)
end

minetest.register_craft({
	output = 'jumpdrive:engine',
	recipe = {
		{'', 'default:mese_crystal_fragment', ''},
		{'default:diamond', 'default:mese_block', 'default:diamond'},
		{'', 'default:mese_crystal', ''}
	}
})


