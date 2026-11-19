local M = {}

M.swords = {
    {name = "lumine_dull_blade", damage = 34, uses = 150},
    {name = "lumine_harbinger_of_dawn", damage = 53, uses = 200},
    {name = "lumine_prototype_rancour", damage = 78, uses = 250, speed = 1.1, faction_bonus = 1.1},
    {name = "lumine_aquila_favonia", damage = 78, uses = 400, speed = 1.1, faction_bonus = 1.1, planar = 18},
}

M.armor = {
    {name="lumine_traveler_head", slot="HEAD", durability=180, absorption=.55},
    {name="lumine_traveler_body", slot="BODY", durability=300, absorption=.70},
    {name="lumine_dawn_head", slot="HEAD", durability=400, absorption=.80},
    {name="lumine_dawn_body", slot="BODY", durability=500, absorption=.80},
    {name="lumine_stone_head", slot="HEAD", durability=650, absorption=.85},
    {name="lumine_stone_body", slot="BODY", durability=750, absorption=.85},
    {name="lumine_celestial_head", slot="HEAD", durability=800, absorption=.90},
    {name="lumine_celestial_body", slot="BODY", durability=1150, absorption=.90},
}

M.by_name = {}
for _, group in ipairs({M.swords, M.armor}) do
    for _, item in ipairs(group) do M.by_name[item.name] = item end
end

return M
