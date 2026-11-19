local assets = { Asset("ANIM", "anim/lumine_element_energy.zip") }

local function MakeEnergy(name, animation)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("lumine_element_energy")
        inst.AnimState:SetBuild("lumine_element_energy")
        inst.AnimState:PlayAnimation(animation, true)
        inst.Transform:SetScale(.82, .82, .82)
        inst:AddTag("lumine_element_energy")
        if animation ~= "particle" then inst:AddTag("lumine_element_orb") end
        MakeInventoryFloatable(inst, "small", .1, .7)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = "images/inventoryimages/" .. name .. ".xml"
        inst.components.inventoryitem.imagename = name
        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM
        inst:DoPeriodicTask(.25, function()
            local holder = inst.components.inventoryitem:GetGrandOwner()
            local player = holder ~= nil and holder:HasTag("lumine") and holder or nil
            if player == nil and not inst:HasTag("INLIMBO") then
                local x, y, z = inst.Transform:GetWorldPosition()
                for _, candidate in ipairs(TheSim:FindEntities(x, y, z, 2.3, {"lumine"}, {"playerghost", "INLIMBO"})) do
                    player = candidate
                    break
                end
            end
            if player == nil or player.components.lumineenergy == nil then return end
            local energy = player.components.lumineenergy
            if energy.current >= 100 then return end
            energy:Add(animation == "particle" and 5 or 20)
            if inst.components.stackable:StackSize() > 1 then
                local one = inst.components.stackable:Get()
                if one ~= nil then one:Remove() end
            else
                inst:Remove()
            end
        end)
        MakeHauntableLaunch(inst)
        return inst
    end
    return Prefab(name, fn, assets)
end

return MakeEnergy("lumine_element_particle", "particle"),
    MakeEnergy("lumine_element_orb", "orb"),
    MakeEnergy("lumine_wind_orb", "orb"),
    MakeEnergy("lumine_geo_orb", "orb")
