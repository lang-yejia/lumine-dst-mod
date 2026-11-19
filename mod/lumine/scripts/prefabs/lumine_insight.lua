local prefabs = {}
local kinds = {"weapon", "head", "body"}
local stages = {2, 3, 4}

for _, kind in ipairs(kinds) do
    for _, stage in ipairs(stages) do
        local name = "lumine_insight_" .. kind .. "_" .. stage
        local atlas = "images/inventoryimages/" .. name .. ".xml"
        local assets = {
            Asset("ANIM", "anim/" .. name .. ".zip"),
            Asset("ATLAS", atlas),
            Asset("IMAGE", "images/inventoryimages/" .. name .. ".tex"),
        }

        local function fn()
            local inst = CreateEntity()
            inst.entity:AddTransform()
            inst.entity:AddAnimState()
            inst.entity:AddNetwork()
            MakeInventoryPhysics(inst)
            inst.AnimState:SetBank(name)
            inst.AnimState:SetBuild(name)
            inst.AnimState:PlayAnimation("idle")
            inst.AnimState:SetScale(1.6, 1.6)
            inst:AddTag("lumine_insight")
            MakeInventoryFloatable(inst, "small", .1, .75)
            inst.entity:SetPristine()
            if not TheWorld.ismastersim then return inst end
            inst:AddComponent("inspectable")
            inst:AddComponent("inventoryitem")
            inst.components.inventoryitem.atlasname = atlas
            inst.components.inventoryitem.imagename = name
            -- Legacy insight items are redeemed into permanent records at the table.
            return inst
        end

        prefabs[#prefabs + 1] = Prefab(name, fn, assets)
    end
end

return unpack(prefabs)
