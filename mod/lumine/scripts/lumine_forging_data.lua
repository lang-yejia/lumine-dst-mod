local M = {}
M.STAGES = {
    {kind="weapon",stage=2,old="lumine_dull_blade",new="lumine_harbinger_of_dawn",items={"spear","hambat","tentaclespike"},materials={{"goldnugget",4}},energy=15},
    {kind="weapon",stage=3,old="lumine_harbinger_of_dawn",new="lumine_prototype_rancour",items={"ruins_bat","nightsword","glasscutter"},materials={{"thulecite",4}},energy=30},
    {kind="weapon",stage=4,old="lumine_prototype_rancour",new="lumine_aquila_favonia",items={"sword_lunarplant","voidcloth_scythe"},materials={{"purebrilliance",2},{"horrorfuel",2}},energy=45},
    {kind="head",stage=2,old="lumine_traveler_head",new="lumine_dawn_head",items={"footballhat","cookiecutterhat","beehat"},materials={{"goldnugget",4}},energy=15},
    {kind="head",stage=3,old="lumine_dawn_head",new="lumine_stone_head",items={"ruinshat","eyemaskhat","dreadstonehat"},materials={{"thulecite",4}},energy=30},
    {kind="head",stage=4,old="lumine_stone_head",new="lumine_celestial_head",items={"lunarplanthat","voidclothhat"},materials={{"purebrilliance",2},{"horrorfuel",2}},energy=45},
    {kind="body",stage=2,old="lumine_traveler_body",new="lumine_dawn_body",items={"armorwood","armormarble","armor_sanity"},materials={{"goldnugget",4}},energy=15},
    {kind="body",stage=3,old="lumine_dawn_body",new="lumine_stone_body",items={"armorruins","armordragonfly","armordreadstone"},materials={{"thulecite",4}},energy=30},
    {kind="body",stage=4,old="lumine_stone_body",new="lumine_celestial_body",items={"armor_lunarplant","armor_voidcloth"},materials={{"purebrilliance",2},{"horrorfuel",2}},energy=45},
}
M.BY_OLD, M.BY_INSIGHT, M.BY_ITEM = {}, {}, {}
M.ORDER = {}
for _, stage in ipairs(M.STAGES) do
    stage.insight = "lumine_insight_" .. stage.kind .. "_" .. stage.stage
    M.BY_OLD[stage.old], M.BY_INSIGHT[stage.insight] = stage, stage
    for _, item in ipairs(stage.items) do
        M.BY_ITEM[item] = stage
        M.ORDER[#M.ORDER+1] = item
    end
end
return M
