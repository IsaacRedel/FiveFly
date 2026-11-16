
FiveFly.Prop = {
    entity = nil,
    netId = nil
}

function FiveFly.Prop.GetModel()
    return Config.Prop.Model
end

local function loadModel(modelName)
    local modelHash = type(modelName) == "string" and GetHashKey(modelName) or modelName

    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return nil
    end

    RequestModel(modelHash)

    local timeoutAt = GetGameTimer() + 8000

    while not HasModelLoaded(modelHash) do
        Wait(10)

        if GetGameTimer() > timeoutAt then
            return nil
        end
    end

    return modelHash
end

local function attachToPlayer(entity)
    local ped = PlayerPedId()
    local attach = Config.Prop.Attach

    AttachEntityToEntity(
        entity,
        ped,
        GetPedBoneIndex(ped, Config.Prop.Bone),
        attach.x,
        attach.y,
        attach.z,
        attach.rx,
        attach.ry,
        attach.rz,
        true,
        true,
        false,
        true,
        1,
        true
    )
end

function FiveFly.Prop.Exists()
    return FiveFly.Prop.entity and DoesEntityExist(FiveFly.Prop.entity)
end

function FiveFly.Prop.Ensure()
    if FiveFly.Prop.Exists() then
        if not IsEntityAttached(FiveFly.Prop.entity) then
            attachToPlayer(FiveFly.Prop.entity)
        end

        return FiveFly.Prop.entity, FiveFly.Prop.netId
    end

    local modelHash = loadModel(Config.Prop.Model)

    if not modelHash then
        return nil, nil
    end

    local coords = GetEntityCoords(PlayerPedId())
    local entity = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)

    if not entity or entity == 0 then
        return nil, nil
    end

    SetEntityAsMissionEntity(entity, true, true)
    attachToPlayer(entity)

    FiveFly.Prop.entity = entity
    FiveFly.Prop.netId = NetworkGetNetworkIdFromEntity(entity)

    return FiveFly.Prop.entity, FiveFly.Prop.netId
end

function FiveFly.Prop.GetCoords()
    if not FiveFly.Prop.Exists() then
        return nil
    end

    return GetEntityCoords(FiveFly.Prop.entity)
end

function FiveFly.Prop.Delete()
    if FiveFly.Prop.Exists() then
        DeleteEntity(FiveFly.Prop.entity)
    end

    FiveFly.Prop.entity = nil
    FiveFly.Prop.netId = nil
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    FiveFly.Prop.Delete()
end)
