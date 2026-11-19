local MakePlayerCharacter = require "prefabs/player_common"
local Glider = require("flight/lumine_glider")
local SkillTreeBridge = require("skilltree/lumine_bridge")



local assets = {

    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),

    Asset("ANIM", "anim/lumine.zip"),

}



-- Your character's stats

TUNING.LUMINE_HEALTH = 150

TUNING.LUMINE_HUNGER = 150

TUNING.LUMINE_SANITY = 200



-- Custom starting inventory

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.LUMINE = {
	"lumine_journal",
	"lumine_dull_blade",
	"lumine_traveler_head",
	"lumine_traveler_body",

	"flint",

	"flint",

	"twigs",

	"twigs",

}



local start_inv = {}

for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do

    start_inv[string.lower(k)] = v.LUMINE

end

local prefabs = FlattenTree(start_inv, true)
prefabs[#prefabs + 1] = "brilliance_projectile_fx"
prefabs[#prefabs + 1] = "lumine_electro_sparks"
prefabs[#prefabs + 1] = "lumine_electro_immune_sparks"
prefabs[#prefabs + 1] = "lunarplanttentacle"
prefabs[#prefabs + 1] = "sleepcloud_lunar"
prefabs[#prefabs + 1] = "lumine_dendro_roots"
prefabs[#prefabs + 1] = "lumine_dendro_sporebomb"
prefabs[#prefabs + 1] = "lumine_hydro_drop"
prefabs[#prefabs + 1] = "lumine_hydro_stream"
prefabs[#prefabs + 1] = "lumine_hydro_bubble"
prefabs[#prefabs + 1] = "lumine_pyro_ring_fx"
prefabs[#prefabs + 1] = "lumine_pyro_burst_fx"
prefabs[#prefabs + 1] = "lumine_pyro_fireball"
prefabs[#prefabs + 1] = "lumine_pyro_scorch_fx"
prefabs[#prefabs + 1] = "staffcastfx"
prefabs[#prefabs + 1] = "deerclops_icespike_fx"
prefabs[#prefabs + 1] = "forcefieldfx"
prefabs[#prefabs + 1] = "lumine_cryo_meteor"
prefabs[#prefabs + 1] = "lumine_cryo_impact"
prefabs[#prefabs + 1] = "lumine_cryo_field"
prefabs[#prefabs + 1] = "lumine_cryo_weapon_fx"
prefabs[#prefabs + 1] = "lumine_cryo_shield_crystal"



-- When the character is revived from human

local function onbecamehuman(inst)

	-- Set speed when not a ghost (optional)
	if inst.components.luminejourney ~= nil then
		inst.components.luminejourney:ApplySkills()
	else
		inst.components.locomotor:SetExternalSpeedMultiplier(inst, "lumine_speed_mod", 1)
	end

end



local function onbecameghost(inst)

	-- Remove speed modifier when becoming a ghost

   inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "lumine_speed_mod")

end



-- When loading or spawning the character

local function onload(inst)

    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)

    inst:ListenForEvent("ms_becameghost", onbecameghost)



    if inst:HasTag("playerghost") then

        onbecameghost(inst)

    else

        onbecamehuman(inst)

    end

end





-- This initializes for both the server and client. Tags can be added here.

local common_postinit = function(inst) 
	inst:AddTag("lumine")
	for _, kind in ipairs({"weapon", "head", "body"}) do
		for stage = 2, 4 do
			inst:AddTag("lumine_insight_" .. kind .. "_" .. stage .. "_upgradeuser")
		end
	end
	inst._lumine_wind_skills = net_tinybyte(inst.GUID, "lumine.wind.skills")
	inst._lumine_wind_dash_ready = net_float(inst.GUID, "lumine.wind.dash_ready")
	inst._lumine_wind_tornado_ready = net_float(inst.GUID, "lumine.wind.tornado_ready")
	inst._lumine_geo_skills = net_tinybyte(inst.GUID, "lumine.geo.skills")
	inst._lumine_geo_shield_ready = net_float(inst.GUID, "lumine.geo.shield_ready")
	inst._lumine_geo_field_ready = net_float(inst.GUID, "lumine.geo.field_ready")
	inst._lumine_geo_shield_left = net_float(inst.GUID, "lumine.geo.shield_left")
	inst._lumine_electro_infused = net_bool(inst.GUID, "lumine.electro.infused")
	inst._lumine_electro_ready = net_float(inst.GUID, "lumine.electro.ready")
	inst._lumine_electro_burst = net_float(inst.GUID, "lumine.electro.burst")
	inst._lumine_dendro_root_ready = net_float(inst.GUID, "lumine.dendro.root_ready")
	inst._lumine_dendro_field_ready = net_float(inst.GUID, "lumine.dendro.field_ready")
	inst._lumine_dendro_field_until = net_float(inst.GUID, "lumine.dendro.field_until")
	inst._lumine_hydro_stream_ready = net_float(inst.GUID, "lumine.hydro.stream_ready")
	inst._lumine_hydro_bubble_ready = net_float(inst.GUID, "lumine.hydro.bubble_ready")
	inst._lumine_hydro_bubble_until = net_float(inst.GUID, "lumine.hydro.bubble_until")
	inst._lumine_hydro_bubble_hp = net_ushortint(inst.GUID, "lumine.hydro.bubble_hp")
	inst._lumine_pyro_ring_ready = net_float(inst.GUID, "lumine.pyro.ring_ready")
	inst._lumine_pyro_burst = net_bool(inst.GUID, "lumine.pyro.burst")
	inst._lumine_pyro_streak = net_tinybyte(inst.GUID, "lumine.pyro.streak")
	inst._lumine_cryo_shield = net_bool(inst.GUID, "lumine.cryo.shield")
	inst._lumine_cryo_shield_ready = net_float(inst.GUID, "lumine.cryo.shield_ready")
	inst._lumine_cryo_charges = net_tinybyte(inst.GUID, "lumine.cryo.charges")
	inst._lumine_cryo_infusion_ready = net_float(inst.GUID, "lumine.cryo.infusion_ready")
	inst._lumine_cryo_meteor_ready = net_float(inst.GUID, "lumine.cryo.meteor_ready")
	inst._lumine_cryo_field_until = net_float(inst.GUID, "lumine.cryo.field_until")
	inst._lumine_element_active = net_tinybyte(inst.GUID, "lumine.element.active")
	inst._lumine_energy = net_float(inst.GUID, "lumine.energy.current")
	inst._lumine_gear_progress = net_string(inst.GUID, "lumine.gear.progress", "lumine_gear_progress_dirty")
	inst._lumine_journal_status = net_string(inst.GUID, "lumine.journal.status")
	inst._lumine_artifacts = net_string(inst.GUID, "lumine.artifacts", "lumine_artifacts_dirty")
	inst._lumine_skilltree = net_string(inst.GUID, "lumine.skilltree.state", "lumine_skilltree_dirty")
	inst._lumine_insight_exchange = net_string(inst.GUID, "lumine.skilltree.exchange", "lumine_insight_exchange_dirty")
	SkillTreeBridge.Attach(inst)
	inst:ListenForEvent("lumine_artifacts_dirty", function() inst:PushEvent("unlockrecipe") end)
	Glider.CommonInit(inst)

	-- Minimap icon

	inst.MiniMapEntity:SetIcon( "lumine.tex" )
	inst.AnimState:SetBuild("lumine")

end



-- This initializes for the server only. Components are added here.

local master_postinit = function(inst)
	inst:AddComponent("luminejourney")
	inst:AddComponent("luminewind")
	inst:AddComponent("luminegeo")
	inst:AddComponent("lumineenergy")
	inst:AddComponent("lumineelectro")
	inst:AddComponent("luminedendro")
	inst:AddComponent("luminehydro")
	inst:AddComponent("luminepyro")
	inst:AddComponent("luminecryo")
	inst:AddComponent("lumineartifacts")
	inst:AddComponent("lumineskilltree")

	-- Set starting inventory

    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

	

	-- choose which sounds this character will play

	inst.soundsname = "willow"

	

	-- Uncomment if "wathgrithr"(Wigfrid) or "webber" voice is used

    --inst.talker_path_override = "dontstarve_DLC001/characters/"

	

	-- Stats	

	inst.components.health:SetMaxHealth(TUNING.LUMINE_HEALTH)

	inst.components.hunger:SetMax(TUNING.LUMINE_HUNGER)

	inst.components.sanity:SetMax(TUNING.LUMINE_SANITY)
	inst:AddComponent("luminestatuebonus")

	

	-- Damage multiplier (optional)

    inst.components.combat.damagemultiplier = 1

	

	-- Hunger rate (optional)

	inst.components.hunger.hungerrate = 1 * TUNING.WILSON_HUNGER_RATE

	

	inst.OnLoad = onload

    inst.OnNewSpawn = onload
	Glider.MasterInit(inst)
    inst.OnDespawn = function(player)
        player.components.luminepyro:ClearCombat()
        player.components.luminecryo:Clear()
    end

	

end



return MakePlayerCharacter("lumine", prefabs, assets, common_postinit, master_postinit, prefabs)

