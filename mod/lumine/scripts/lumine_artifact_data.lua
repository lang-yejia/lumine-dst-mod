local M = {}

M.DROP_CHANCE = .06
M.SLOTS = {
    {id="flower", name="生之花", stat="受伤减少 2%"},
    {id="plume", name="死之羽", stat="造成伤害 +2%"},
    {id="sands", name="时之沙", stat="饥饿消耗 -3%"},
    {id="goblet", name="空之杯", stat="元素力自然回复 +1/分钟"},
    {id="circlet", name="理之冠", stat="移动速度 +2%"},
}
M.SETS = {
    {id="wilson", name="威尔逊·科学家的遗珍", short="威尔逊", colour={.73,.76,.57,1},
        parts={"瓶中生之花","测绘之羽","实验沙漏","试剂量杯","学者护目镜"},
        ability="四件：使用威尔逊的基础转换配方，材料与科技照原版。"},
    {id="wickerbottom", name="薇克巴顿·博闻的遗珍", short="奶奶", colour={.64,.72,.86,1},
        parts={"书页押花","墨羽笔","藏书沙漏","博闻茶杯","博闻花冠"},
        ability="四件：制作并阅读薇克巴顿的书籍，读书消耗照原版。"},
    {id="warly", name="沃利·主厨的遗珍", short="大厨", colour={.91,.63,.47,1},
        parts={"香草花束","调味羽笔","主厨沙漏","铜制盛杯","主厨高帽"},
        ability="四件：制作和使用沃利的便携厨具、调味品及料理。"},
}

M.ALL, M.BY_ID, M.BY_PREFAB, M.BY_SET = {}, {}, {}, {}
for set_index, set in ipairs(M.SETS) do
    M.BY_SET[set.id] = set
    for slot_index, slot in ipairs(M.SLOTS) do
        local piece = {
            id=set.id.."_"..slot_index, prefab="lumine_relic_"..set.id.."_"..slot_index,
            name=set.parts[slot_index], set=set.id, set_index=set_index,
            slot=slot.id, slot_index=slot_index, stat=slot.stat,
        }
        M.ALL[#M.ALL+1] = piece
        M.BY_ID[piece.id] = piece
        M.BY_PREFAB[piece.prefab] = piece
    end
end

return M
