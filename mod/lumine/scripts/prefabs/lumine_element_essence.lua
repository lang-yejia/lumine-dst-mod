local Elements = require("lumine_statue_elements")
local assets = {
    Asset("ANIM", "anim/gems.zip"),
    Asset("IMAGE", "images/inventoryimages/lumine_wind_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_wind_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_geo_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_geo_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_electro_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_electro_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_dendro_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_dendro_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_hydro_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_hydro_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_pyro_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_pyro_essence.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_cryo_essence.tex"),
    Asset("ATLAS", "images/inventoryimages/lumine_cryo_essence.xml"),
}

local function MakeEssence(name, gem, atlas, image, tint)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("gems")
        inst.AnimState:SetBuild("gems")
        inst.AnimState:PlayAnimation(gem .. "gem_idle", true)
        inst.AnimState:SetMultColour(unpack(tint))
        inst:AddTag("lumine_element_essence")
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = atlas
        inst.components.inventoryitem.imagename = image
        return inst
    end
    return Prefab(name, fn, assets)
end

local prefabs = {
    MakeEssence(Elements.wind.item, "blue", "images/inventoryimages/lumine_wind_essence.xml",
        Elements.wind.item, {.62, 1, .86, 1}),
    MakeEssence(Elements.geo.item, "orange", "images/inventoryimages/lumine_geo_essence.xml",
        Elements.geo.item, {1, .84, .52, 1}),
}
for _, id in ipairs(Elements.order) do
    local element = Elements[id]
    if element.gem then
        local atlas, image = Elements.EssenceIcon(id)
        prefabs[#prefabs + 1] = MakeEssence(element.item, element.gem, atlas, image, {Elements.Tint(id)})
    end
end
return unpack(prefabs)
