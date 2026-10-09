local MOD = SMODS.current_mod

PlusJoker = {
	ui = {
		count_text = 'Selected: 0',
		hint_text = '',
		enabled_text = 'ON',
	},
	areas = {},
	cols = 5,
	rows = 2,
}

local RARITY_FALLBACK = { 'Common', 'Uncommon', 'Rare', 'Legendary' }
local RARITY_KEYS = { 'k_common', 'k_uncommon', 'k_rare', 'k_legendary' }

local function rarity_name(rarity)
	local key = RARITY_KEYS[rarity]
	local fallback = RARITY_FALLBACK[rarity] or 'Joker'
	if type(localize) ~= 'function' then return fallback end
	local ok, text = pcall(localize, key)
	if ok and type(text) == 'string' and text ~= '' and text ~= key then
		return text
	end
	return fallback
end

function PlusJoker.pool(rarity)
	local list = {}
	local pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker or {}
	for _, center in ipairs(pool) do
		if center and center.set == 'Joker' and not center.mod and center.rarity == rarity then
			list[#list + 1] = center
		end
	end
	table.sort(list, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
	return list
end

function PlusJoker.selected_keys()
	local selected = (MOD.config and MOD.config.selected) or {}
	local keys = {}
	for rarity = 1, 4 do
		for _, center in ipairs(PlusJoker.pool(rarity)) do
			if selected[center.key] then
				keys[#keys + 1] = center.key
			end
		end
	end
	return keys
end

function PlusJoker.refresh_ui()
	local n = #PlusJoker.selected_keys()
	local enabled = MOD.config and MOD.config.enabled
	PlusJoker.ui.count_text = 'Selected: ' .. tostring(n)
	PlusJoker.ui.enabled_text = enabled and 'ON' or 'OFF'
	if not enabled then
		PlusJoker.ui.hint_text = 'Off. Your picks stay saved.'
	elseif n == 0 then
		PlusJoker.ui.hint_text = 'Click Jokers to pick more than one. Each Ante adds 1 copy of every pick, and 1 slot per copy.'
	else
		PlusJoker.ui.hint_text = 'Ante 1 starts with ' .. n .. '. Every Ante adds ' .. n .. ' more. Antimatter and Ectoplasm still add room.'
	end
end

function PlusJoker.save()
	if SMODS.save_mod_config then
		SMODS.save_mod_config(MOD)
	end
end

function PlusJoker.toggle(key, card)
	MOD.config.selected = MOD.config.selected or {}
	local now = not MOD.config.selected[key]
	if now then
		MOD.config.selected[key] = true
		play_sound('card1', 0.95, 0.5)
	else
		MOD.config.selected[key] = nil
		play_sound('cardSlide2', 0.95, 0.4)
	end
	if card then
		card.highlighted = now
		card:juice_up(0.3, 0.2)
	end
	PlusJoker.refresh_ui()
	PlusJoker.save()
end

function PlusJoker.fill_page(rarity, page)
	local areas = PlusJoker.areas
	if not areas or not areas[1] then return end
	local pool = PlusJoker.pool(rarity)
	local page_size = PlusJoker.cols * #areas
	page = page or 1
	for _, area in ipairs(areas) do
		for i = #area.cards, 1, -1 do
			local card = area:remove_card(area.cards[i])
			if card then card:remove() end
		end
	end
	if G.GAME and not G.GAME.used_jokers then
		G.GAME.used_jokers = {}
	end
	for col = 1, PlusJoker.cols do
		for row = 1, #areas do
			local index = col + (row - 1) * PlusJoker.cols + page_size * (page - 1)
			local center = pool[index]
			if center then
				local area = areas[row]
				local card = Card(
					area.T.x + area.T.w / 2,
					area.T.y,
					G.CARD_W,
					G.CARD_H,
					G.P_CARDS.empty,
					center,
					{
						bypass_discovery_center = true,
						bypass_discovery_ui = true,
						bypass_lock = true,
					}
				)
				card.plusjoker_pick = true
				card.states.drag.can = false
				area:emplace(card)
				if MOD.config.selected and MOD.config.selected[center.key] then
					card.highlighted = true
				end
			end
		end
	end
end

local function page_labels(count, page_size)
	local pages = math.max(1, math.ceil(count / page_size))
	local options = {}
	local page_word = 'Page'
	if type(localize) == 'function' then
		local ok, text = pcall(localize, 'k_page')
		if ok and type(text) == 'string' and text ~= '' and text ~= 'k_page' then
			page_word = text
		end
	end
	for i = 1, pages do
		options[i] = page_word .. ' ' .. tostring(i) .. '/' .. tostring(pages)
	end
	return options
end

function PlusJoker.rarity_tab(rarity)
	PlusJoker.areas = {}
	local rows = {}
	for row = 1, PlusJoker.rows do
		local area = CardArea(
			G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
			G.ROOM.T.h,
			PlusJoker.cols * G.CARD_W,
			0.95 * G.CARD_H,
			{ card_limit = PlusJoker.cols, type = 'title', highlight_limit = 0, collection = true }
		)
		PlusJoker.areas[row] = area
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = 'cm', padding = 0.07, no_fill = true },
			nodes = {
				{ n = G.UIT.O, config = { object = area } },
			},
		}
	end

	local pool = PlusJoker.pool(rarity)
	local options = page_labels(#pool, PlusJoker.cols * PlusJoker.rows)
	PlusJoker.fill_page(rarity, 1)

	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = 'cm', r = 0.1, colour = G.C.BLACK, emboss = 0.05, padding = 0.05 },
				nodes = rows,
			},
			{
				n = G.UIT.R,
				config = { align = 'cm' },
				nodes = {
					create_option_cycle({
						options = options,
						w = 4.5,
						cycle_shoulders = true,
						opt_callback = 'plusjoker_page',
						current_option = 1,
						colour = (G.C.RARITY and G.C.RARITY[rarity]) or G.C.RED,
						no_pips = true,
						focus_args = { snap_to = true, nav = 'wide' },
						plusjoker_rarity = rarity,
					}),
				},
			},
		},
	}
end

function PlusJoker.overlay()
	PlusJoker.refresh_ui()
	local tabs = {}
	for rarity = 1, 4 do
		local this_rarity = rarity
		tabs[rarity] = {
			label = rarity_name(this_rarity),
			chosen = this_rarity == 1,
			tab_definition_function = function()
				return PlusJoker.rarity_tab(this_rarity)
			end,
		}
	end

	return create_UIBox_generic_options({
		back_func = 'plusjoker_back',
		contents = {
			{
				n = G.UIT.R,
				config = { align = 'cm' },
				nodes = {
					{ n = G.UIT.T, config = { text = 'PLUS JOKER', scale = 0.55, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				},
			},
			{
				n = G.UIT.R,
				config = { align = 'cm', padding = 0.05 },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							ref_table = PlusJoker.ui,
							ref_value = 'count_text',
							scale = 0.38,
							colour = G.C.GOLD,
							shadow = true,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = 'cm', padding = 0.04, minw = 10 },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							ref_table = PlusJoker.ui,
							ref_value = 'hint_text',
							scale = 0.28,
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = 'cm', padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = 'cm',
							minw = 2.4,
							minh = 0.7,
							padding = 0.1,
							r = 0.1,
							hover = true,
							shadow = true,
							colour = G.C.GREEN,
							button = 'plusjoker_toggle_enabled',
							func = 'plusjoker_enabled_colour',
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									ref_table = PlusJoker.ui,
									ref_value = 'enabled_text',
									scale = 0.4,
									colour = G.C.UI.TEXT_LIGHT,
									shadow = true,
								},
							},
						},
					},
					{
						n = G.UIT.C,
						config = { align = 'cm', minw = 0.25 },
						nodes = {},
					},
					UIBox_button({
						button = 'plusjoker_clear',
						minw = 2.4,
						minh = 0.7,
						scale = 0.4,
						colour = G.C.RED,
						label = { 'Clear' },
						col = true,
					}),
				},
			},
			{
				n = G.UIT.R,
				config = { align = 'cm' },
				nodes = {
					create_tabs({
						snap_to_nav = true,
						colour = G.C.RED,
						tabs = tabs,
					}),
				},
			},
		},
	})
end

local function adjust_slots(count, ante)
	if not G.jokers or count <= 0 then return end
	local limits = G.jokers.config.card_limits
	local base = limits.base or (G.GAME.starting_params and G.GAME.starting_params.joker_slots) or 5
	local mod = limits.mod or 0
	local applied = G.GAME.plusjoker_applied or 0
	local other = mod - applied
	local want = count * ante - 5
	local projected = base + other + want
	if projected < count * ante then
		want = want + (count * ante - projected)
	end
	local delta = want - applied
	if delta ~= 0 then
		G.jokers:change_size(delta)
	end
	G.GAME.plusjoker_applied = want
end

local function grant_copy(key)
	if not G.P_CENTERS[key] or not G.jokers then return end
	local card = add_joker(key, nil, true)
	if not card then return end
	card.ability.plusjoker_granted = true
end

local function remove_granted(key, amount)
	if amount <= 0 or not G.jokers then return end
	local removed = 0
	for i = #G.jokers.cards, 1, -1 do
		if removed >= amount then break end
		local card = G.jokers.cards[i]
		if card and card.ability and card.ability.plusjoker_granted and not card.plusjoker_removing and card.config and card.config.center and card.config.center.key == key then
			card.plusjoker_removing = true
			local kept = card:start_dissolve(nil, true)
			if kept == false then
				card.plusjoker_removing = nil
			else
				removed = removed + 1
			end
		end
	end
end

function PlusJoker.sync_run(silent)
	if not G.GAME or not G.GAME.plusjoker_on or not G.jokers then return end
	local keys = G.GAME.plusjoker_keys or {}
	local count = #keys
	if count == 0 then return end
	local ante = math.max(1, math.floor(G.GAME.round_resets.ante or 1))
	local previous = G.GAME.plusjoker_synced_ante or 0
	if ante == previous then return end

	adjust_slots(count, ante)
	local delta = ante - previous
	if delta > 0 then
		for _ = 1, delta do
			for _, key in ipairs(keys) do
				grant_copy(key)
			end
		end
		if not silent then
			attention_text({
				text = '+' .. tostring(delta * count),
				scale = 0.9,
				hold = 0.8,
				major = G.jokers,
				backdrop_colour = G.C.RED,
				align = 'cm',
			})
			play_sound('timpani', 0.9, 0.6)
		end
	else
		for _, key in ipairs(keys) do
			remove_granted(key, -delta)
		end
	end
	G.GAME.plusjoker_synced_ante = ante
end

function PlusJoker.begin_run()
	if not G.GAME or not G.jokers then return end
	local keys = {}
	if MOD.config and MOD.config.enabled then
		keys = PlusJoker.selected_keys()
	end
	G.GAME.plusjoker_keys = keys
	G.GAME.plusjoker_on = #keys > 0
	G.GAME.plusjoker_synced_ante = 0
	G.GAME.plusjoker_applied = 0
	if G.GAME.plusjoker_on then
		PlusJoker.sync_run(true)
	end
end

MOD.reset_game_globals = function(run_start)
	if run_start then
		PlusJoker.begin_run()
	else
		-- Boss cashout queues this after ease_ante has applied the new ante.
		PlusJoker.sync_run(false)
	end
end

local card_click = Card.click
function Card:click()
	if self.plusjoker_pick and self.config and self.config.center and self.config.center.key then
		PlusJoker.toggle(self.config.center.key, self)
		return
	end
	return card_click(self)
end

local ease_ante_ref = ease_ante
function ease_ante(mod)
	ease_ante_ref(mod)
	-- Stay behind ease_ante's own event. A non-blockable event runs during
	-- the pre-ante delay, sees the old ante, and skips the new copies.
	G.E_MANAGER:add_event(Event({
		trigger = 'immediate',
		func = function()
			PlusJoker.sync_run(false)
			return true
		end,
	}))
end

G.FUNCS.plusjoker_open = function(e)
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({
		definition = PlusJoker.overlay(),
	})
end

G.FUNCS.plusjoker_back = function(e)
	PlusJoker.save()
	G.FUNCS.options(e)
end

G.FUNCS.plusjoker_page = function(args)
	if not args or not args.cycle_config then return end
	PlusJoker.fill_page(args.cycle_config.plusjoker_rarity, args.cycle_config.current_option)
end

G.FUNCS.plusjoker_toggle_enabled = function(e)
	MOD.config.enabled = not MOD.config.enabled
	PlusJoker.refresh_ui()
	PlusJoker.save()
	play_sound('button', 0.9, 0.5)
end

G.FUNCS.plusjoker_enabled_colour = function(e)
	if MOD.config and MOD.config.enabled then
		e.config.colour = G.C.GREEN
	else
		e.config.colour = G.C.RED
	end
end

G.FUNCS.plusjoker_clear = function(e)
	MOD.config.selected = {}
	if PlusJoker.areas then
		for _, area in ipairs(PlusJoker.areas) do
			for _, card in ipairs(area.cards or {}) do
				card.highlighted = false
			end
		end
	end
	PlusJoker.refresh_ui()
	PlusJoker.save()
	play_sound('cardSlide2', 0.9, 0.5)
end

local create_options_ref = create_UIBox_options
function create_UIBox_options()
	local contents = create_options_ref()
	local list = contents
		and contents.nodes
		and contents.nodes[1]
		and contents.nodes[1].nodes
		and contents.nodes[1].nodes[1]
		and contents.nodes[1].nodes[1].nodes
		and contents.nodes[1].nodes[1].nodes[1]
		and contents.nodes[1].nodes[1].nodes[1].nodes
	if list then
		table.insert(list, 2, UIBox_button({
			id = 'plusjoker_button',
			label = { 'Plus Joker' },
			button = 'plusjoker_open',
			minw = 5,
			colour = G.C.RED,
		}))
	end
	return contents
end
