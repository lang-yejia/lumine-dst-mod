-- Configure before loading any presentation modules. Text is fixed until rejoin;
-- gameplay identifiers, RPCs and save keys never depend on the selected language.
local M = { language = "zh" }
local english

function M.Resolve(choice, code)
    if choice == "zh" or choice == "en" then return choice end
    if choice ~= "auto" then return "zh" end
    return (code == "zh" or code == "zhr" or code == "zht") and "zh" or "en"
end

function M.Configure(choice, globals)
    local loc = globals and globals.LOC
    local code = loc and loc.GetLocaleCode and loc.GetLocaleCode() or "en"
    M.language = M.Resolve(choice or "zh", code)
end

function M.For(scope)
    return function(key, chinese)
        if M.language ~= "en" then return chinese end
        english = english or require("languages/lumine_en")
        local section = english[scope]
        return section and section[key] or chinese
    end
end

return M
