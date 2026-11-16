--- Runs every tests/lua/*_test.lua file. Usage (from the repository root): lua tests/lua/run.lua
package.path = "./tests/lua/?.lua;" .. package.path

local tests = {
    "utils_test",
    "parser_test",
    "media_test",
    "bridge_test",
    "sessions_test",
    "sync_test",
    "dispatch_test",
    "vehicle_test"
}

local failed = 0
local total = 0
local realPrint = print

for _, name in ipairs(tests) do
    local cases = dofile(("tests/lua/%s.lua"):format(name))

    for _, case in ipairs(cases) do
        total = total + 1
        local ok, err = pcall(case.run)
        print = realPrint

        if ok then
            print(("  ok   %s > %s"):format(name, case.name))
        else
            failed = failed + 1
            print(("  FAIL %s > %s\n       %s"):format(name, case.name, tostring(err)))
        end
    end
end

print(("\n%d tests, %d failed"):format(total, failed))
os.exit(failed == 0 and 0 or 1)
