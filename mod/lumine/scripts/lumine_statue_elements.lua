local M = {
    order = {"wind", "geo", "electro", "dendro", "hydro", "pyro", "cryo"},
    bonus = {health = 20, sanity = 10, hunger = 10},
}

M.wind = {name="风", rgb={101,197,183}, use="wind", emblem="wind-emblem", playable=true}
M.geo = {name="岩", rgb={217,169,78}, use="geo", emblem="geo-emblem", playable=true}
M.electro = {name="雷", rgb={169,139,232}, gem="purple", material="purplegem", emblem="electro-emblem", playable=true}
M.dendro = {name="草", rgb={131,185,92}, gem="green", material="greengem", emblem="dendro-emblem", playable=true}
M.hydro = {name="水", rgb={88,169,220}, gem="blue", material="bluegem", emblem="hydro-emblem", playable=true}
M.pyro = {name="火", rgb={227,110,77}, gem="red", material="redgem", emblem="pyro-emblem", playable=true}
M.cryo = {name="冰", rgb={155,217,231}, gem="blue", material="ice", emblem="cryo-emblem", playable=true}

M.by_item, M.by_wire = {}, {}
for index, id in ipairs(M.order) do
    local element = M[id]
    element.item = "lumine_" .. id .. "_essence"
    element.wire, element.bit = index, 2 ^ (index - 1)
    M.by_wire[index], M.by_item[element.item] = id, id
end

function M.Has(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

function M.EssenceIcon(id)
    local element = M[id]
    if element.emblem then
        return "images/inventoryimages/" .. element.item .. ".xml", element.item
    end
    return "images/inventoryimages.xml", element.material
end

function M.Merge(a, b)
    for _, id in ipairs(M.order) do
        local bit = M[id].bit
        if M.Has(b, bit) and not M.Has(a, bit) then a = a + bit end
    end
    return a
end

function M.Count(mask)
    local count = 0
    for _, id in ipairs(M.order) do
        if M.Has(mask, M[id].bit) then count = count + 1 end
    end
    return count
end

function M.LegacyElement(data)
    if not data then return nil end
    if data.fixed_version then
        return type(data.element) == "string" and M.by_item["lumine_" .. data.element .. "_essence"] or nil
    end
    if data.last_element == "wind" or data.last_element == "geo" then return data.last_element end
    local offered = data.offered
    if type(offered) == "table" and (offered.wind == true) ~= (offered.geo == true) then
        return offered.wind == true and "wind" or "geo"
    end
end

function M.Tint(id)
    local rgb = id and M[id].rgb
    if not rgb then return 1, 1, 1, 1 end
    return .24 + .76 * rgb[1] / 255, .24 + .76 * rgb[2] / 255, .24 + .76 * rgb[3] / 255, 1
end

return M
