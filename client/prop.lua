
FiveFY.Prop = {
    entity = nil,
    netId = nil
}

function FiveFY.Prop.GetModel()
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

function FiveFY.Prop.Exists()
    return FiveFY.Prop.entity and DoesEntityExist(FiveFY.Prop.entity)
end

function FiveFY.Prop.Ensure()
    if FiveFY.Prop.Exists() then
        if not IsEntityAttached(FiveFY.Prop.entity) then
            attachToPlayer(FiveFY.Prop.entity)
        end

        return FiveFY.Prop.entity, FiveFY.Prop.netId
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

    FiveFY.Prop.entity = entity
    FiveFY.Prop.netId = NetworkGetNetworkIdFromEntity(entity)

    return FiveFY.Prop.entity, FiveFY.Prop.netId
end

function FiveFY.Prop.GetCoords()
    if not FiveFY.Prop.Exists() then
        return nil
    end

    return GetEntityCoords(FiveFY.Prop.entity)
end

function FiveFY.Prop.Delete()
    if FiveFY.Prop.Exists() then
        DeleteEntity(FiveFY.Prop.entity)
    end

    FiveFY.Prop.entity = nil
    FiveFY.Prop.netId = nil
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    FiveFY.Prop.Delete()
end)
