name = "Lumine (Journey Preview)"
description = "Local preview: Lumine journey, elemental skills, Paimon, gear reforging and survivor relic pages."
author = "Local Development"
version = "0.45.1"
forumthread = ""
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
all_clients_require_mod = true
icon_atlas = "modicon.xml"
icon = "modicon.tex"
server_filter_tags = { "character" }

configuration_options = {
    {
        name = "statue_test_refill",
        label = "神像测试补能",
        hover = "允许房主和管理员在七天神像界面补满自身元素力并清除元素技能冷却。",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false},
        },
        default = true,
    },
    {
        name = "relic_codex_key",
        label = "圣遗物界面按键",
        hover = "携带星辉圣匣时，按此键打开圣遗物界面。",
        options = {
            {description = "H", data = "H"},
            {description = "J", data = "J"},
            {description = "K", data = "K"},
            {description = "L", data = "L"},
        },
        default = "H",
    },
    {
        name = "element_skill_1_key",
        label = "元素技能 1 按键",
        options = {
            {description = "Z", data = "Z"},
            {description = "X", data = "X"},
            {description = "C", data = "C"},
            {description = "V", data = "V"},
        },
        default = "Z",
    },
    {
        name = "element_skill_2_key",
        label = "元素技能 2 按键",
        options = {
            {description = "X", data = "X"},
            {description = "Z", data = "Z"},
            {description = "C", data = "C"},
            {description = "V", data = "V"},
        },
        default = "X",
    },
}

-- Local development only. Enable together with the DST dev branch.
journey_dev_tools = false
