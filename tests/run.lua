local suites = {quick = {"data"}, core = {"recording"},
    full = {"data", "recording", "flow", "skilltree", "statue", "wind_dash", "electro", "dendro", "hydro", "pyro", "cryo"}}

return function(level, module)
    local passed, failed = 0, 0
    for _, name in ipairs(module and {module} or suites[level]) do
        local function test(description, fn)
            local output, original_print = {}, print
            print = function(message) output[#output + 1] = tostring(message) end
            local ok, err = pcall(fn)
            print = original_print
            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                print("FAIL " .. name .. " / " .. description .. " — " .. tostring(err))
                if #output > 0 then print("  Last diagnostic: " .. output[#output]) end
            end
        end
        local ok, suite = pcall(require, name .. "_test")
        if ok then
            suite(test)
        else
            test("load suite", function() error(suite, 0) end)
        end
    end
    print(string.format("Tests: %d total, %d passed, %d failed", passed + failed, passed, failed))
    return failed == 0 and 0 or 1
end
