local vRP

--- vRP's lib/Proxy.lua relies on globals from @vrp/lib/utils.lua: `module`, `async` and `table.maxn`.
--- FiveFly does not list vRP in its manifest, so when vRP is used it runs vRP's own utils.lua (matching the
--- fork installed on the server) and only falls back to equivalent polyfills when that file is missing.
local function loadVrpUtils()
    local code = LoadResourceFile("vrp", "lib/utils.lua")

    if not code then
        return false
    end

    local chunk = load(code, "@vrp/lib/utils.lua")

    if not chunk then
        return false
    end

    local ok, err = pcall(chunk)

    if not ok then
        FiveFly.Log("warn", FiveFly.T("log.vrp_utils_failed", tostring(err)))
    end

    return ok
end

local function ensurePolyfills()
    if type(table.maxn) ~= "function" then
        function table.maxn(t) ---@diagnostic disable-line: duplicate-set-field
            local max = 0

            for key in pairs(t) do
                local number = tonumber(key)

                if number and number > max then
                    max = number
                end
            end

            return max
        end
    end

    if type(async) ~= "function" then
        local function wait(self)
            local rets = Citizen.Await(self.p) or self.r
            return table.unpack(rets, 1, table.maxn(rets))
        end

        local function resolve(self, ...)
            self.r = { ... }
            self.p:resolve(self.r)
        end

        function async(func) ---@diagnostic disable-line: lowercase-global
            if func then
                Citizen.CreateThreadNow(func)
                return nil
            end

            return setmetatable({ wait = wait, p = promise.new() }, { __call = resolve })
        end
    end
end

local function ensureModuleLoader()
    if type(module) ~= "function" or type(async) ~= "function" or type(table.maxn) ~= "function" then
        loadVrpUtils()
    end

    ensurePolyfills()

    if type(module) == "function" then
        return
    end

    local modules = {}

    function module(rsc, path) ---@diagnostic disable-line: lowercase-global
        if path == nil then
            path = rsc
            rsc = "vrp"
        end

        local key = rsc .. path

        if modules[key] then
            return modules[key]
        end

        local code = LoadResourceFile(rsc, path .. ".lua")

        if not code then
            error(("resource file %s/%s.lua not found"):format(rsc, path))
        end

        local chunk, parseError = load(code, ("@%s/%s.lua"):format(rsc, path))

        if not chunk then
            error(parseError)
        end

        modules[key] = chunk()
        return modules[key]
    end
end

local function firstText(...)
    for i = 1, select("#", ...) do
        local value = FiveFly.Utils.Trim(tostring(select(i, ...) or ""))

        if value ~= "" and value ~= "nil" then
            return value
        end
    end

    return ""
end

local function getUserId(source)
    local userId = vRP.getUserId(source)
    return tonumber(userId)
end

FiveFly.Bridge.Register({
    name = "vrp",
    resource = "vrp",

    Init = function()
        ensureModuleLoader()
        local Proxy = module("vrp", "lib/Proxy")
        vRP = Proxy.getInterface("vRP")
        return vRP ~= nil
    end,

    GetIdentifier = function(source)
        local userId = getUserId(source)
        return userId and userId > 0 and ("vrp:" .. userId) or nil
    end,

    GetDisplayName = function(source)
        local userId = getUserId(source)

        if not userId or type(vRP.getUserIdentity) ~= "function" then
            return nil
        end

        local identity = vRP.getUserIdentity(userId)

        if type(identity) ~= "table" then
            return nil
        end

        -- Classic vRP: firstname = first name, name = surname. Brazilian forks: nome/sobrenome or name/lastname.
        if identity.firstname ~= nil then
            return FiveFly.Utils.Trim(firstText(identity.firstname) .. " " .. firstText(identity.name))
        end

        local firstName = firstText(identity.nome, identity.name, identity.firstName)
        local lastName = firstText(identity.sobrenome, identity.lastname, identity.lastName)

        return FiveFly.Utils.Trim(firstName .. " " .. lastName)
    end,

    HasPermission = function(source, permission)
        local userId = getUserId(source)
        return userId ~= nil and vRP.hasPermission(userId, permission) == true
    end
})
