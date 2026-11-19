local M = {}

local function IsWilsonRecipe(inst, recipe)
    if inst == nil or not inst:HasTag("lumine") or recipe == nil
        or type(recipe.builder_skill) ~= "string"
        or recipe.name == nil or recipe.name:sub(1,10) ~= "transmute_"
        or recipe.builder_skill:sub(1,15) ~= "wilson_alchemy_" then return false end
    local artifacts = inst.components.lumineartifacts
    if artifacts ~= nil then
        local inv = inst.components.inventory
        local item = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.LUMINE_RELIC_CODEX) or nil
        return item ~= nil and item.prefab == "lumine_relic_codex"
            and artifacts.active == "wilson" and artifacts:IsComplete("wilson")
    end
    local net = inst._lumine_artifacts
    if net == nil then return false end
    local replica = inst.replica.inventory
    local item = replica ~= nil and replica:GetEquippedItem(EQUIPSLOTS.LUMINE_RELIC_CODEX) or nil
    if item == nil or item.prefab ~= "lumine_relic_codex" then return false end
    local bits = net:value()
    if bits:sub(17,17) ~= "1" then return false end
    local count = 0
    for index = 1,5 do if bits:sub(index,index) == "1" then count=count+1 end end
    return count >= 4
end

local function Wrap(builder, method)
    local original = builder[method]
    builder[method] = function(self, recipe, ...)
        local actual = type(recipe) == "string" and GetValidRecipe(recipe) or recipe
        if not IsWilsonRecipe(self.inst, actual) then return original(self, recipe, ...) end
        local skill = actual.builder_skill
        actual.builder_skill = nil
        local ok, a, b, c = pcall(original, self, recipe, ...)
        actual.builder_skill = skill
        if not ok then error(a) end
        return a, b, c
    end
end

function M.Install(AddClassPostConstruct)
    for _, path in ipairs({"components/builder", "components/builder_replica"}) do
        AddClassPostConstruct(path, function(builder)
            Wrap(builder, "KnowsRecipe")
            Wrap(builder, "CanLearn")
        end)
    end
end

return M
