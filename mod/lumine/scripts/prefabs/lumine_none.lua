local assets =

{

	Asset( "ANIM", "anim/lumine.zip" ),

	Asset( "ANIM", "anim/ghost_esctemplate_build.zip" ),

}



local skins =

{

	normal_skin = "lumine",

	ghost_skin = "ghost_esctemplate_build",

}



return CreatePrefabSkin("lumine_none",

{

	base_prefab = "lumine",

	type = "base",

	assets = assets,

	skins = skins, 

	skin_tags = {"LUMINE", "CHARACTER", "BASE"},

	build_name_override = "lumine",

	rarity = "Character",

})