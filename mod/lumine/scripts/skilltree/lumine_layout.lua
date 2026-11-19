-- Coordinates in the native SkillTreeWidget, before the popup's UI scaling.
local M = {
    builder_y = -50,
    native_offset = -30,
    groups = {
        lumine_elements = {-155, 158},
        lumine_workshop = {22, 151},
        lumine_combat = {177, 151},
        lumine_partners = {32, 43},
        lumine_survival = {177, 43},
    },
    nodes = {
        lumine_element_foundation = {-155, 50},
        lumine_element_wind = {-211, 105},
        lumine_element_geo = {-99, 105},
        lumine_element_electro = {-155, 124},
        lumine_element_dendro = {-77, 50},
        lumine_element_hydro = {-99, -4},
        lumine_element_pyro = {-155, -26},
        lumine_element_cryo = {-211, -4},
        lumine_element_mastery = {-233, 50},

        lumine_workshop_codex = {-26, 112},
        lumine_workshop_relic_study = {22, 112},
        lumine_workshop_relic_curation = {69, 112},
        lumine_workshop_reforge = {-34, 67},

        lumine_partners_hut = {-26, 7},
        lumine_partners_garden = {22, 7},
        lumine_partners_hearth = {69, 7},
        lumine_partners_paimon = {-26, -39},

        lumine_combat_sword = {126, 105},
        lumine_combat_ward = {116, 62},
        lumine_combat_resolve = {176, 105},
        lumine_combat_lunar = {226, 121},
        lumine_combat_shadow = {226, 77},

        lumine_survival_rations = {126, 13},
        lumine_survival_stride = {176, 13},
        lumine_survival_navigation = {226, 13},
        lumine_survival_weather = {126, -37},
        lumine_survival_firstaid = {176, -37},
    },
}

function M.NativePosition(position)
    return {position[1], position[2] - M.builder_y - M.native_offset}
end

return M
