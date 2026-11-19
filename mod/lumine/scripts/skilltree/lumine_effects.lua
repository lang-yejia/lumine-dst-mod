local M = {}

-- Handlers run on the server. They must be reversible and safe on save reload.
M.handlers = {
    unlock_element = function(tree, key, enabled)
        tree.elements[key] = enabled or nil
    end,
    unlock_recipe = function(tree, key, enabled)
        tree.recipes[key] = enabled or nil
    end,
    unlock_feature = function(tree, key, enabled)
        tree.features[key] = enabled or nil
    end,
    passive_modifier = function(tree, key, enabled)
        local modifier = assert(M.modifiers[key], key)
        modifier(tree.inst, enabled)
    end,
}
M.modifiers = {}

function M.Apply(tree, node, enabled)
    local effect = node.effect
    if effect ~= nil then
        M.handlers[effect.type](tree, effect.key, enabled)
    end
end

function M.CanBuildRecipe(recipe, owner)
    local tree = owner.components.lumineskilltree
    return tree ~= nil and tree.recipes[recipe.name] == true
end

return M
