
FiveFly.Vehicle = {
    lastVehicle = nil,
    connectedVehicle = nil,
    connectedVehicleNetId = nil
}

local function isVehicleValid(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

local function tableHasValue(values, value)
    if type(values) ~= "table" or value == nil then
        return false
    end

    local stringValue = tostring(value):lower()

    if values[value] == true or values[stringValue] == true then
        return true
    end

    for _, entry in pairs(values) do
        if tostring(entry):lower() == stringValue then
            return true
        end
    end

    return false
end

local function modelMatches(models, model, displayName)
    if type(models) ~= "table" or not model then
        return false
    end

    local safeDisplayName = tostring(displayName or ""):lower()

    if models[model] == true or models[tostring(model)] == true or models[safeDisplayName] == true then
        return true
    end

    for key, entry in pairs(models) do
        local candidate = entry == true and key or entry
        local safeCandidate = tostring(candidate or ""):lower()

        if safeCandidate ~= "" then
            if safeCandidate == safeDisplayName then
                return true
            end

            if GetHashKey(safeCandidate) == model then
                return true
            end
        end
    end

    return false
end

local function displayNameMatches(patterns, displayName)
    if type(patterns) ~= "table" or not displayName then
        return false
    end

    local safeDisplayName = tostring(displayName):lower()

    for _, pattern in pairs(patterns) do
        local safePattern = tostring(pattern or ""):lower()

        if safePattern ~= "" and safeDisplayName:find(safePattern, 1, true) then
            return true
        end
    end

    return false
end

local function getAudioProfile(vehicle)
    local vehicleConfig = Config.Range and Config.Range.vehicle or {}
    local defaultConfig = type(vehicleConfig) == "table" and vehicleConfig.default or {}
    local classProfiles = type(vehicleConfig) == "table" and vehicleConfig.classProfiles or {}
    local soundConfig = type(vehicleConfig) == "table" and vehicleConfig.soundSystem or nil
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local vehicleClass = GetVehicleClass(vehicle)
    local isSoundSystem = false

    if type(soundConfig) == "table" then
        isSoundSystem = modelMatches(soundConfig.models, model, displayName)
            or tableHasValue(soundConfig.classes, vehicleClass)
            or displayNameMatches(soundConfig.namePatterns, displayName)
    end

    local classProfile = type(classProfiles) == "table" and (classProfiles[vehicleClass] or classProfiles[tostring(vehicleClass)]) or nil
    local profile = defaultConfig
    local profileId = "default"

    if isSoundSystem then
        profile = soundConfig
        profileId = "soundSystem"
    elseif type(classProfile) == "table" then
        profile = classProfile
        profileId = "class:" .. tostring(vehicleClass)
    end

    return {
        range = tonumber(profile and profile.range) or 24.0,
        volume = tonumber(profile and profile.volume) or 82.0,
        profile = profileId,
        soundSystem = isSoundSystem,
        vehicleModel = model,
        vehicleClass = vehicleClass,
        vehicleDisplayName = displayName
    }
end

local function connectAudioVehicle(vehicle)
    -- Native trailers are separate vehicles: only sound-system trailers replace the car.
    local attached, trailer = GetVehicleTrailerVehicle(vehicle)

    if attached and isVehicleValid(trailer) and getAudioProfile(trailer).soundSystem then
        vehicle = trailer
    end

    -- Keep the selected emitter after detaching, until disconnect or entity removal.
    FiveFly.Vehicle.connectedVehicle = vehicle
    FiveFly.Vehicle.connectedVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

    return vehicle
end

function FiveFly.Vehicle.GetCurrent()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if isVehicleValid(vehicle) then
        FiveFly.Vehicle.lastVehicle = vehicle
        return vehicle
    end

    return nil
end

function FiveFly.Vehicle.GetLast()
    if isVehicleValid(FiveFly.Vehicle.lastVehicle) then
        return FiveFly.Vehicle.lastVehicle
    end

    return nil
end

function FiveFly.Vehicle.ConnectCurrent()
    local vehicle = FiveFly.Vehicle.GetCurrent() or FiveFly.Vehicle.GetLast()

    if not isVehicleValid(vehicle) then
        return false
    end

    connectAudioVehicle(vehicle)
    FiveFly.Vehicle.lastVehicle = vehicle

    return true
end

function FiveFly.Vehicle.ClearConnected()
    FiveFly.Vehicle.connectedVehicle = nil
    FiveFly.Vehicle.connectedVehicleNetId = nil
end

function FiveFly.Vehicle.GetConnected()
    if isVehicleValid(FiveFly.Vehicle.connectedVehicle) then
        return connectAudioVehicle(FiveFly.Vehicle.connectedVehicle)
    end

    local netId = tonumber(FiveFly.Vehicle.connectedVehicleNetId or 0)

    if netId > 0 then
        local vehicle = NetworkGetEntityFromNetworkId(netId)

        if isVehicleValid(vehicle) then
            return connectAudioVehicle(vehicle)
        end
    end

    FiveFly.Vehicle.ClearConnected()
    return nil
end

function FiveFly.Vehicle.GetOwnerDistance()
    local vehicle = FiveFly.Vehicle.GetConnected()

    if not vehicle then
        return nil
    end

    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle))
end

function FiveFly.Vehicle.IsOwnerTooFar()
    local vehicleConfig = Config.Range and Config.Range.vehicle or {}
    local maxDistance = tonumber(vehicleConfig.ownerMaxDistance) or 80.0
    local distance = FiveFly.Vehicle.GetOwnerDistance()

    return distance ~= nil and distance > maxDistance
end

function FiveFly.Vehicle.GetOutputTarget()
    local vehicle = FiveFly.Vehicle.GetConnected()

    if not vehicle then
        return nil
    end

    local profile = getAudioProfile(vehicle)

    return {
        sourceType = "vehicle",
        sourceCoords = GetEntityCoords(vehicle),
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
        range = profile.range,
        volume = profile.volume,
        profile = profile.profile,
        soundSystem = profile.soundSystem,
        vehicleModel = profile.vehicleModel,
        vehicleClass = profile.vehicleClass,
        vehicleDisplayName = profile.vehicleDisplayName
    }
end
