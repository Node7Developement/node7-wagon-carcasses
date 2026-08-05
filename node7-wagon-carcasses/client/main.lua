local Node7Core = exports['node7-core']:GetCoreObject()

local Zones = {}
local Managed = {}
local RestoreRequested = {}
local CurrentMenus = {}
local CarryCache = { entity = 0, model = 0, lastSeen = 0 }
local UnloadingEntities = {}

local function debugPrint(message)
    if Config.Debug then
        print(('[node7-wagon-carcasses] %s'):format(tostring(message)))
    end
end

local function notify(message, kind)
    if Node7Core and Node7Core.Functions and Node7Core.Functions.Notify then
        Node7Core.Functions.Notify({
            title = 'Wagon Carcasses',
            description = tostring(message),
            type = kind or 'info',
            duration = 5000,
        })
    end
end

local function targetStarted()
    return GetResourceState('ox_target') == 'started'
end

local function menuStarted()
    return GetResourceState('node7-menu') == 'started'
end

local function entityType(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0 end

    if type(GetEntityType) == 'function' then
        local ok, value = pcall(GetEntityType, entity)
        if ok then return tonumber(value) or 0 end
    end

    if type(IsEntityAPed) == 'function' and IsEntityAPed(entity) then return 1 end
    if type(IsEntityAnObject) == 'function' and IsEntityAnObject(entity) then return 3 end
    return 0
end

local function getPedTypeSafe(ped)
    if entityType(ped) ~= 1 then return -1 end

    if type(GetPedType) == 'function' then
        local ok, value = pcall(GetPedType, ped)
        if ok and tonumber(value) then return tonumber(value) end
    end

    local ok, value = pcall(function()
        return Citizen.InvokeNative(0xFF059E1E4C01E63C, ped, Citizen.ResultAsInteger())
    end)
    if ok and tonumber(value) then return tonumber(value) end

    local fallbackOk, fallback = pcall(function()
        return Citizen.InvokeNative(0xFF059E1E4C01E63C, ped)
    end)
    return fallbackOk and tonumber(fallback) or -1
end

local function isHumanPed(ped)
    if entityType(ped) ~= 1 then return false end
    if IsPedAPlayer(ped) then return true end

    if type(IsPedHuman) == 'function' then
        local ok, human = pcall(IsPedHuman, ped)
        if ok and human == true then return true end
    end

    local ok, human = pcall(function()
        return Citizen.InvokeNative(0xB980061DA992779D, ped, Citizen.ResultAsInteger())
    end)
    if ok and (human == true or tonumber(human) == 1) then return true end

    local fallbackOk, fallbackHuman = pcall(function()
        return Citizen.InvokeNative(0xB980061DA992779D, ped)
    end)
    if fallbackOk and (fallbackHuman == true or tonumber(fallbackHuman) == 1) then return true end

    local pedType = getPedTypeSafe(ped)
    return pedType == 4 or pedType == 5
end

local function isWhitelistedAnimalPed(entity)
    if entityType(entity) ~= 1 then return false end
    if IsPedAPlayer(entity) or isHumanPed(entity) then return false end

    local model = GetEntityModel(entity)
    if Node7Carcasses.IsAnimalModel(model) ~= true then return false end

    local pedType = getPedTypeSafe(entity)
    return pedType == -1 or pedType == 28
end

local function getCarrier(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0 end

    -- RedM exposes two carrier lookups. The local MP player is normally
    -- returned by the human variant, while some carry states resolve through
    -- the generic ped variant.
    local okHuman, humanCarrier = pcall(function()
        return Citizen.InvokeNative(0x79443D56C8DF45EE, entity, Citizen.ResultAsInteger())
    end)
    if okHuman and tonumber(humanCarrier) and tonumber(humanCarrier) ~= 0 then
        return tonumber(humanCarrier)
    end

    local fallbackHumanOk, fallbackHuman = pcall(function()
        return Citizen.InvokeNative(0x79443D56C8DF45EE, entity)
    end)
    if fallbackHumanOk and tonumber(fallbackHuman) and tonumber(fallbackHuman) ~= 0 then
        return tonumber(fallbackHuman)
    end

    local okPed, pedCarrier = pcall(function()
        return Citizen.InvokeNative(0x09B83E68DE004CD4, entity, Citizen.ResultAsInteger())
    end)
    if okPed and tonumber(pedCarrier) and tonumber(pedCarrier) ~= 0 then
        return tonumber(pedCarrier)
    end

    local fallbackPedOk, fallbackPed = pcall(function()
        return Citizen.InvokeNative(0x09B83E68DE004CD4, entity)
    end)
    if fallbackPedOk and tonumber(fallbackPed) and tonumber(fallbackPed) ~= 0 then
        return tonumber(fallbackPed)
    end

    return 0
end

local function isCarriedByLocalPlayer(entity)
    return getCarrier(entity) == PlayerPedId()
end

local function isDeadAnimalCarcass(entity, allowLocalCarry)
    if not isWhitelistedAnimalPed(entity) then return false end

    if allowLocalCarry and isCarriedByLocalPlayer(entity) then
        -- While Rockstar's shoulder-carry task is active, some RedM builds do
        -- not consistently report IsPedDeadOrDying even though the animal is a
        -- carcass. A whitelisted animal physically carried by the local player
        -- is therefore accepted as the same native carcass entity.
        return true
    end

    if type(IsPedDeadOrDying) == 'function' then
        local ok, result = pcall(IsPedDeadOrDying, entity, true)
        if ok and result == true then return true end
    end

    if type(IsPedFatallyInjured) == 'function' then
        local ok, result = pcall(IsPedFatallyInjured, entity)
        if ok and result == true then return true end
    end

    if type(IsEntityDead) == 'function' then
        local ok, result = pcall(IsEntityDead, entity)
        if ok and result == true then return true end
    end

    if type(GetEntityHealth) == 'function' then
        local ok, health = pcall(GetEntityHealth, entity)
        if ok and tonumber(health) and tonumber(health) <= 0 then return true end
    end

    return false
end

local function isValidAnimalCarcass(entity)
    return isDeadAnimalCarcass(entity, true)
end

local function getCarriedEntity()
    local playerPed = PlayerPedId()

    -- Do not gate this lookup behind IS_PED_CARRYING_SOMETHING. That boolean
    -- is not consistent for every native carcass carry configuration.
    local ok, entity = pcall(function()
        return Citizen.InvokeNative(0xD806CD2A4F2C2996, playerPed, Citizen.ResultAsInteger())
    end)
    entity = ok and tonumber(entity) or 0

    -- Match the working node7-hunting path as a fallback for runtimes that
    -- already coerce entity return values without an explicit result marker.
    if entity == 0 then
        local fallbackOk, fallback = pcall(function()
            return Citizen.InvokeNative(0xD806CD2A4F2C2996, playerPed)
        end)
        entity = fallbackOk and tonumber(fallback) or 0
    end

    if entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return 0
end

local function requestControl(entity, attempts)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    for _ = 1, attempts or 20 do
        NetworkRequestControlOfEntity(entity)
        Wait(40)
        if NetworkHasControlOfEntity(entity) then return true end
    end

    return NetworkHasControlOfEntity(entity)
end

local function ensureNetworkId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0 end

    if not NetworkGetEntityIsNetworked(entity) then
        pcall(function()
            SetEntityAsMissionEntity(entity, true, true)
            NetworkRegisterEntityAsNetworked(entity)
        end)
        Wait(0)
    end

    return tonumber(NetworkGetNetworkIdFromEntity(entity)) or 0
end

local function headingDifference(a, b)
    local difference = math.abs((a or 0.0) - (b or 0.0)) % 360.0
    return difference > 180.0 and (360.0 - difference) or difference
end

local function getWagonRearCoords(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local settings = Config.Interaction or {}
    local rearOffset = tonumber(settings.rearFallback) or -2.2
    local rearHeight = tonumber(settings.rearHeight) or 0.45
    local rearExtra = tonumber(settings.rearExtra) or 0.35

    if type(GetModelDimensions) == 'function' then
        local ok, minimum, maximum = pcall(GetModelDimensions, GetEntityModel(entity))
        if ok and minimum and maximum and minimum.y then
            rearOffset = minimum.y - rearExtra
            local height = math.max(0.0, (maximum.z or 1.0) - (minimum.z or 0.0))
            rearHeight = math.max(0.30, math.min(1.10, height * 0.28))
        end
    end

    return GetOffsetFromEntityInWorldCoords(entity, 0.0, rearOffset, rearHeight)
end

local function getUnloadCoords(wagon)
    local rear = getWagonRearCoords(wagon)
    if not rear then return nil end

    local behind = GetOffsetFromEntityInWorldCoords(wagon, 0.0, -3.2, 0.25)
    return vector3(behind.x, behind.y, behind.z)
end

local function getSlotTransform(wagon, slot)
    local minimum = vector3(-1.0, -2.0, -0.2)
    local maximum = vector3(1.0, 2.0, 1.8)

    if type(GetModelDimensions) == 'function' then
        local ok, minValue, maxValue = pcall(GetModelDimensions, GetEntityModel(wagon))
        if ok and minValue and maxValue then
            minimum, maximum = minValue, maxValue
        end
    end

    local hidden = Config.HiddenStorage or {}
    if hidden.enabled ~= false then
        local slotIndex = math.max(1, math.floor(tonumber(slot) or 1))
        return {
            x = tonumber(hidden.x) or 0.0,
            y = minimum.y + (tonumber(hidden.rearInset) or 0.10),
            z = minimum.z
                + (tonumber(hidden.bottomLift) or 0.34)
                + ((slotIndex - 1) * (tonumber(hidden.slotSpacing) or 0.015)),
            rx = tonumber(hidden.pitch) or 0.0,
            ry = tonumber(hidden.roll) or 0.0,
            rz = tonumber(hidden.yaw) or 0.0,
        }
    end

    local layout = (Config.SlotLayout or {})[tonumber(slot) or 1] or (Config.SlotLayout or {})[1]
    layout = layout or { x = 0.5, y = 0.25, z = 0.6, rz = 90.0 }

    local width = math.max(0.8, maximum.x - minimum.x)
    local length = math.max(1.6, maximum.y - minimum.y)
    local height = math.max(0.8, maximum.z - minimum.z)

    return {
        x = minimum.x + width * (tonumber(layout.x) or 0.5),
        y = minimum.y + length * (tonumber(layout.y) or 0.25),
        z = minimum.z + height * (tonumber(layout.z) or 0.6),
        rx = tonumber(layout.rx) or 0.0,
        ry = tonumber(layout.ry) or 0.0,
        rz = tonumber(layout.rz) or 90.0,
    }
end

local function setCarcassState(entity, recordId, wagonid)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    UnloadingEntities[entity] = nil
    pcall(function()
        Entity(entity).state:set('node7CarcassRecord', tonumber(recordId), true)
        Entity(entity).state:set('node7CarcassWagonId', tostring(wagonid), true)
        Entity(entity).state:set('node7CarcassHidden', true, true)
    end)
end

local function clearCarcassState(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    pcall(function()
        -- Replicate an explicit false first. Clearing the key directly could
        -- leave a streamed client holding the previous true value.
        Entity(entity).state:set('node7CarcassHidden', false, true)
        Entity(entity).state:set('node7CarcassRecord', nil, true)
        Entity(entity).state:set('node7CarcassWagonId', nil, true)
    end)
end

local function entityIsInUnloadGrace(entity)
    local expires = UnloadingEntities[entity]
    if not expires then return false end
    if GetGameTimer() >= expires then
        UnloadingEntities[entity] = nil
        return false
    end
    return true
end

local function isAttachedToWagon(entity, wagon)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) then return false end

    local nativeOk, parent = pcall(function()
        return Citizen.InvokeNative(0x56D713888A566481, entity, Citizen.ResultAsInteger())
    end)
    if nativeOk and tonumber(parent) == tonumber(wagon) then return true end

    if type(GetEntityAttachedTo) == 'function' then
        local ok, wrapperParent = pcall(GetEntityAttachedTo, entity)
        if ok and tonumber(wrapperParent) == tonumber(wagon) then return true end
    end

    if type(IsEntityAttachedToEntity) == 'function' then
        local ok, result = pcall(IsEntityAttachedToEntity, entity, wagon)
        if ok and result == true then return true end
    end

    return false
end

local function setStoredVisibility(entity, hidden)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if hidden then
        if type(SetEntityVisible) == 'function' then
            pcall(function() SetEntityVisible(entity, false, false) end)
        end
        if type(SetEntityAlpha) == 'function' then
            pcall(function() SetEntityAlpha(entity, 0, false) end)
        end
    else
        if type(ResetEntityAlpha) == 'function' then
            pcall(function() ResetEntityAlpha(entity) end)
        elseif type(SetEntityAlpha) == 'function' then
            pcall(function() SetEntityAlpha(entity, 255, false) end)
        end
        if type(SetEntityVisible) == 'function' then
            pcall(function() SetEntityVisible(entity, true, false) end)
        end
    end
end

local function setStoredPhysics(entity, stored)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if stored then
        pcall(function() SetEntityAsMissionEntity(entity, true, true) end)
        pcall(function() SetEntityVelocity(entity, 0.0, 0.0, 0.0) end)
        pcall(function() SetEntityAngularVelocity(entity, 0.0, 0.0, 0.0) end)
        pcall(function() SetEntityCollision(entity, false, false) end)
        pcall(function() SetEntityHasGravity(entity, false) end)
        pcall(function() SetEntityDynamic(entity, false) end)
        pcall(function() SetEntityInvincible(entity, true) end)
        pcall(function() SetPedCanRagdoll(entity, false) end)
        pcall(function() FreezeEntityPosition(entity, false) end)
        setStoredVisibility(entity, (Config.HiddenStorage or {}).hidden ~= false)
    else
        setStoredVisibility(entity, false)
        pcall(function() SetEntityDynamic(entity, true) end)
        pcall(function() SetEntityHasGravity(entity, true) end)
        pcall(function() SetEntityCollision(entity, true, true) end)
        pcall(function() SetEntityInvincible(entity, false) end)
        pcall(function() SetPedCanRagdoll(entity, true) end)
        pcall(function() FreezeEntityPosition(entity, false) end)
    end
end

local function restoreUnloadedCarcass(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    -- Keep stale replicated hidden states from re-hiding this carcass while
    -- ownership migrates immediately after it is detached from the wagon.
    UnloadingEntities[entity] = GetGameTimer() + 4000
    setStoredPhysics(entity, false)
    setStoredVisibility(entity, false)

    pcall(function() SetEntityAlpha(entity, 255, false) end)
    pcall(function() ResetEntityAlpha(entity) end)
    pcall(function() SetEntityVisible(entity, true, false) end)
    pcall(function() SetEntityCollision(entity, true, true) end)
    pcall(function() SetEntityHasGravity(entity, true) end)
    pcall(function() SetEntityDynamic(entity, true) end)
    pcall(function() SetEntityInvincible(entity, false) end)
    pcall(function() SetEntityCanBeDamaged(entity, true) end)
    pcall(function() SetPedCanRagdoll(entity, true) end)
    pcall(function() FreezeEntityPosition(entity, false) end)
end

if type(AddStateBagChangeHandler) == 'function' and type(GetEntityFromStateBagName) == 'function' then
    local function applyHiddenStateBag(bagName, value, attempt)
        local entity = GetEntityFromStateBagName(bagName)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            if value == true and not entityIsInUnloadGrace(entity) then
                -- Never hide a loose world carcass. A carcass is only hidden
                -- while it is still physically attached to a wagon.
                local parent = 0
                local nativeOk, nativeParent = pcall(function()
                    return Citizen.InvokeNative(0x56D713888A566481, entity, Citizen.ResultAsInteger())
                end)
                if nativeOk then parent = tonumber(nativeParent) or 0 end

                if parent == 0 and type(GetEntityAttachedTo) == 'function' then
                    local ok, attachedTo = pcall(GetEntityAttachedTo, entity)
                    if ok then parent = tonumber(attachedTo) or 0 end
                end

                if parent ~= 0 and DoesEntityExist(parent) then
                    setStoredPhysics(entity, true)
                else
                    setStoredPhysics(entity, false)
                end
            else
                setStoredPhysics(entity, false)
            end
            return
        end

        attempt = (tonumber(attempt) or 0) + 1
        if value == true and attempt <= 8 then
            SetTimeout(250, function()
                applyHiddenStateBag(bagName, value, attempt)
            end)
        end
    end

    AddStateBagChangeHandler('node7CarcassHidden', nil, function(bagName, _, value)
        applyHiddenStateBag(bagName, value, 0)
    end)
end

local function releaseCarcassFromPlayer(entity, wagon, transform)
    local playerPed = PlayerPedId()
    if getCarrier(entity) ~= playerPed then return true end

    -- Use Rockstar's proper carried-entity placement task. Clearing or
    -- forcibly releasing the carry state first makes the carcass fall before
    -- the wagon attachment can take ownership of it.
    local world = GetOffsetFromEntityInWorldCoords(
        wagon,
        transform.x,
        transform.y,
        transform.z + 0.15
    )

    pcall(function()
        Citizen.InvokeNative(
            0xC7F0B43DCDC57E3D, -- TASK_PLACE_CARRIED_ENTITY_AT_COORD
            playerPed,
            entity,
            world.x,
            world.y,
            world.z,
            1.0,
            5
        )
    end)

    local timeout = GetGameTimer() + 1800
    while GetGameTimer() < timeout do
        if not DoesEntityExist(entity) then return false end
        if getCarrier(entity) ~= playerPed then return true end
        Wait(25)
    end

    -- Last-resort task clear only after the proper placement task timed out.
    -- The entity is attached immediately afterward in the same client tick.
    pcall(function() ClearPedTasks(playerPed) end)
    Wait(50)
    return DoesEntityExist(entity)
end

local function pinCarcassToWagon(entity, wagon, record)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) then return false end

    if not requestControl(entity, 30) then return false end
    requestControl(wagon, 12)

    local transform = getSlotTransform(wagon, record.slot)
    local world = GetOffsetFromEntityInWorldCoords(wagon, transform.x, transform.y, transform.z)

    pcall(function() DetachEntity(entity, true, true) end)
    setStoredPhysics(entity, true)
    pcall(function()
        SetEntityCoordsNoOffset(entity, world.x, world.y, world.z, false, false, false)
    end)

    -- A dead animal ped can take a few frames to leave Rockstar's carriable
    -- controller. Reapply the same root attachment until it is confirmed and
    -- remains confirmed, rather than treating one native call as success.
    for _ = 1, 8 do
        pcall(function()
            Citizen.InvokeNative(
                0x6B9BBD38AB0796DF, -- ATTACH_ENTITY_TO_ENTITY
                entity,
                wagon,
                0,
                transform.x,
                transform.y,
                transform.z,
                transform.rx,
                transform.ry,
                transform.rz,
                false,
                false,
                false,
                true,
                2,
                true
            )
        end)

        Wait(75)
        if isAttachedToWagon(entity, wagon) then
            Wait(175)
            if isAttachedToWagon(entity, wagon) then
                return true
            end
        end

        pcall(function() DetachEntity(entity, true, true) end)
        pcall(function()
            SetEntityCoordsNoOffset(entity, world.x, world.y, world.z, false, false, false)
        end)
        setStoredPhysics(entity, true)
    end

    return false
end

local function attachCarcass(entity, wagon, record)
    if not isValidAnimalCarcass(entity) or not wagon or wagon == 0 or not DoesEntityExist(wagon) then
        return false
    end

    if not requestControl(entity, 30) then return false end
    requestControl(wagon, 12)

    local transform = getSlotTransform(wagon, record.slot)
    if not releaseCarcassFromPlayer(entity, wagon, transform) then return false end

    -- Do not use the old forced carriable-release native here. It detached the
    -- animal from the player and let physics drop it before attachment.
    if not pinCarcassToWagon(entity, wagon, record) then return false end

    setCarcassState(entity, record.id, record.wagonid)
    Managed[tonumber(record.id)] = {
        entity = entity,
        wagon = wagon,
        wagonid = tostring(record.wagonid),
        model = tonumber(record.model),
        slot = tonumber(record.slot),
    }

    CarryCache.entity = 0
    CarryCache.model = 0
    CarryCache.lastSeen = 0
    return true
end

local function enumerateVehicles()
    if type(GetGamePool) == 'function' then
        local ok, result = pcall(GetGamePool, 'CVehicle')
        if ok and type(result) == 'table' then return result end
    end

    local vehicles = {}
    if type(FindFirstVehicle) ~= 'function' then return vehicles end
    local handle, vehicle = FindFirstVehicle()
    if not handle or handle == -1 then return vehicles end

    local success = true
    repeat
        if vehicle and vehicle ~= 0 then vehicles[#vehicles + 1] = vehicle end
        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return vehicles
end

local function enumeratePeds()
    if type(GetGamePool) == 'function' then
        local ok, result = pcall(GetGamePool, 'CPed')
        if ok and type(result) == 'table' then return result end
    end

    local peds = {}
    if type(FindFirstPed) ~= 'function' then return peds end
    local handle, ped = FindFirstPed()
    if not handle or handle == -1 then return peds end

    local success = true
    repeat
        if ped and ped ~= 0 then peds[#peds + 1] = ped end
        success, ped = FindNextPed(handle)
    until not success

    EndFindPed(handle)
    return peds
end

local function rememberCarriedAnimal(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) and isWhitelistedAnimalPed(entity) then
        CarryCache.entity = entity
        CarryCache.model = GetEntityModel(entity)
        CarryCache.lastSeen = GetGameTimer()
    end
end

local function cachedCarriedAnimal()
    local entity = tonumber(CarryCache.entity) or 0
    if entity == 0 or GetGameTimer() - (tonumber(CarryCache.lastSeen) or 0) > 2500 then
        return 0
    end

    if not DoesEntityExist(entity) or GetEntityModel(entity) ~= tonumber(CarryCache.model) then
        CarryCache.entity = 0
        CarryCache.model = 0
        CarryCache.lastSeen = 0
        return 0
    end

    if isDeadAnimalCarcass(entity, true) then return entity end
    return 0
end

local function findCarriedAnimalCarcass()
    local playerPed = PlayerPedId()

    -- Primary native path. This is the exact entity Rockstar currently has in
    -- the player's carry slot.
    local direct = getCarriedEntity()
    if direct ~= 0 and isDeadAnimalCarcass(direct, true) then
        rememberCarriedAnimal(direct)
        return direct
    end

    -- Query every attached carriable. The previous build used the wrong
    -- indexed-item conversion native, so valid carcass peds were never
    -- recovered from this itemset path.
    local itemset = 0
    local created, value = pcall(function()
        return Citizen.InvokeNative(0xA1AF16083320065A, true, Citizen.ResultAsInteger())
    end)
    if created then itemset = tonumber(value) or 0 end

    if itemset ~= 0 then
        pcall(Citizen.InvokeNative, 0x20A4BF0E09BEE146, itemset)
        pcall(Citizen.InvokeNative, 0xB5ACE8B23A438EC0, playerPed, itemset)

        local size = 0
        local sizeOk, sizeValue = pcall(function()
            return Citizen.InvokeNative(0x55F2E375AC6018A9, itemset, Citizen.ResultAsInteger())
        end)
        if sizeOk then size = tonumber(sizeValue) or 0 end

        for index = 0, size - 1 do
            local itemOk, item = pcall(function()
                return Citizen.InvokeNative(0x275A2E2C0FAB7612, index, itemset, Citizen.ResultAsInteger())
            end)
            item = itemOk and tonumber(item) or 0

            if item ~= 0 then
                local entityOk, entity = pcall(function()
                    return Citizen.InvokeNative(0x3FFB15534067DCD4, item, Citizen.ResultAsInteger())
                end)
                entity = entityOk and tonumber(entity) or 0

                if entity ~= 0 and isDeadAnimalCarcass(entity, true) then
                    rememberCarriedAnimal(entity)
                    pcall(Citizen.InvokeNative, 0x712BC69F10549B92, itemset)
                    return entity
                end
            end
        end

        pcall(Citizen.InvokeNative, 0x712BC69F10549B92, itemset)
    end

    -- ox_target selection can briefly make the direct carry lookup return zero.
    -- Reuse the carcass observed immediately before selection rather than
    -- losing the native entity at the exact moment Store is pressed.
    local cached = cachedCarriedAnimal()
    if cached ~= 0 then return cached end

    -- Final fallback: find a nearby whitelisted animal whose carrier is the
    -- local player. This remains strict animal-only and cannot match human NPCs.
    local playerCoords = GetEntityCoords(playerPed)
    for _, ped in ipairs(enumeratePeds()) do
        if ped ~= playerPed and isWhitelistedAnimalPed(ped) then
            local closeEnough = #(GetEntityCoords(ped) - playerCoords) <= 4.0
            if closeEnough and isCarriedByLocalPlayer(ped) and isDeadAnimalCarcass(ped, true) then
                rememberCarriedAnimal(ped)
                return ped
            end
        end
    end

    return 0
end

-- Keep a tiny carry cache so opening ox_target cannot erase the native carry
-- result before the Store option executes. This loop sleeps and performs one
-- native lookup; it does not enumerate world peds.
CreateThread(function()
    while true do
        Wait(150)

        local entity = getCarriedEntity()
        if entity ~= 0 and isWhitelistedAnimalPed(entity) then
            rememberCarriedAnimal(entity)
        elseif GetGameTimer() - (tonumber(CarryCache.lastSeen) or 0) > 2500 then
            CarryCache.entity = 0
            CarryCache.model = 0
            CarryCache.lastSeen = 0
        end
    end
end)

local function findGroundCarcassAtWagon(wagon)
    if (Config.Interaction or {}).allowGroundLoad == false then return 0 end

    local rear = getWagonRearCoords(wagon)
    if not rear then return 0 end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local maximumDistance = tonumber((Config.Interaction or {}).groundLoadDistance) or 3.25
    local nearest, nearestDistance = 0, maximumDistance + 0.001

    for _, ped in ipairs(enumeratePeds()) do
        if isValidAnimalCarcass(ped) then
            local stateOk, state = pcall(function() return Entity(ped).state end)
            local alreadyStored = stateOk and state and tonumber(state.node7CarcassRecord) ~= nil
            if not alreadyStored then
                local coords = GetEntityCoords(ped)
                local rearDistance = #(coords - rear)
                local playerDistance = #(coords - playerCoords)
                if rearDistance <= maximumDistance and playerDistance <= 4.5 and rearDistance < nearestDistance then
                    nearest = ped
                    nearestDistance = rearDistance
                end
            end
        end
    end

    return nearest
end

local function findLoadableCarcass(wagon)
    local carried = findCarriedAnimalCarcass()
    if carried ~= 0 then return carried, true end

    local ground = findGroundCarcassAtWagon(wagon)
    if ground ~= 0 then return ground, false end

    return 0, false
end

local function findEntityByRecord(recordId)
    recordId = tonumber(recordId)
    if not recordId then return 0 end

    local managed = Managed[recordId]
    if managed and managed.entity and DoesEntityExist(managed.entity) then
        return managed.entity
    end

    for _, ped in ipairs(enumeratePeds()) do
        if DoesEntityExist(ped) then
            local ok, state = pcall(function() return Entity(ped).state end)
            if ok and state and tonumber(state.node7CarcassRecord) == recordId then
                return ped
            end
        end
    end

    return 0
end

local function createDeadAnimal(model, coords, heading)
    model = tonumber(model) or 0
    if model == 0 or not Node7Carcasses.IsAnimalModel(model) then return 0 end

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(20)
    end

    if not HasModelLoaded(model) then return 0 end

    local ped = CreatePed(model, coords.x, coords.y, coords.z, heading or 0.0, true, true, false, false)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(model)
        return 0
    end

    SetEntityAsMissionEntity(ped, true, true)
    pcall(function() NetworkRegisterEntityAsNetworked(ped) end)
    pcall(function() SetEntityHealth(ped, 0) end)
    pcall(function() ApplyDamageToPed(ped, 9999, false, true, true) end)
    pcall(function() SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false) end)
    Wait(100)

    SetModelAsNoLongerNeeded(model)
    return ped
end

local function wagonState(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local ok, state = pcall(function() return Entity(entity).state end)
    if not ok or not state then return nil end

    local wagonid = state.node7WagonId
    if not wagonid or tostring(wagonid) == '' then return nil end

    return {
        wagonid = tostring(wagonid),
        owner = state.node7WagonOwner and tostring(state.node7WagonOwner) or nil,
        networkId = ensureNetworkId(entity),
    }
end

local function removeZone(key)
    local zone = Zones[key]
    if not zone then return end

    if zone.zoneId and targetStarted() then
        pcall(function() exports['ox_target']:removeZone(zone.zoneId) end)
    end

    Zones[key] = nil
end

local function currentWagonFromData(data)
    data = type(data) == 'table' and data or {}
    local wagon = tonumber(data.entity) or 0

    if wagon == 0 and tonumber(data.networkId) and NetworkDoesNetworkIdExist(tonumber(data.networkId)) then
        wagon = NetworkGetEntityFromNetworkId(tonumber(data.networkId))
    end

    if wagon == 0 or not DoesEntityExist(wagon) then return nil, nil end
    local state = wagonState(wagon)
    if not state or state.wagonid ~= tostring(data.wagonid or state.wagonid) then return nil, nil end

    return wagon, state
end

local function openCarcassMenu(records, wagonid, networkId, wagonEntity)
    if not menuStarted() then
        notify('node7-menu is not running.', 'error')
        return
    end

    if type(records) ~= 'table' or #records == 0 then
        notify('This wagon has no stored carcasses.', 'info')
        return
    end

    local items = {}
    for _, record in ipairs(records) do
        local header = tostring(record.label or 'Animal Carcass')
        local group = tostring(record.group_name or 'animal'):gsub('^%l', string.upper)
        local slot = tonumber(record.slot) or 0

        items[#items + 1] = {
            header = header,
            txt = ('Type: %s | Wagon slot: %s'):format(group, slot),
            badge = 'STORED',
            submenu = {
                {
                    header = 'Unload Carcass',
                    txt = 'Place this physical carcass on the ground behind the wagon.',
                    variant = 'warning',
                    params = {
                        event = 'node7-wagon-carcasses:client:requestUnload',
                        args = {
                            id = tonumber(record.id),
                            wagonid = tostring(wagonid),
                            networkId = tonumber(networkId),
                            entity = tonumber(wagonEntity),
                        },
                    },
                },
            },
        }
    end

    exports['node7-menu']:openMenu({
        title = 'Stored Carcasses',
        subtitle = ('%s carcass%s stored'):format(#records, #records == 1 and '' or 'es'),
        categories = {
            {
                label = 'Carcasses',
                items = items,
            },
        },
    })
end

local function loadCarriedIntoWagon(wagon, state)
    local carcass, wasCarried = findLoadableCarcass(wagon)
    if carcass == 0 then
        notify('Carry a dead animal to the rear, or place it on the ground beside the rear target.', 'error')
        return
    end

    if not isValidAnimalCarcass(carcass) then
        notify('Only dead whitelisted animal carcasses can be stored.', 'error')
        return
    end

    if not requestControl(carcass, 30) then
        notify('Could not take control of the carried carcass yet. Try Store once more.', 'error')
        return
    end

    local carcassNetId = ensureNetworkId(carcass)
    if carcassNetId == 0 or state.networkId == 0 then
        notify('The carried carcass is not network-ready yet. Try Store once more.', 'error')
        return
    end

    debugPrint(('reserving %s carcass entity=%s net=%s wagon=%s'):format(
        wasCarried and 'carried' or 'ground', carcass, carcassNetId, state.wagonid
    ))

    TriggerServerEvent('node7-wagon-carcasses:server:reserveLoad', {
        wagonid = state.wagonid,
        wagonNetId = state.networkId,
        carcassNetId = carcassNetId,
        animalModel = GetEntityModel(carcass),
        wasCarried = wasCarried == true,
    })
end

RegisterNetEvent('node7-wagon-carcasses:client:loadCarried', function(data)
    local wagon, state = currentWagonFromData(data)
    if not wagon then
        notify('The wagon could not be identified.', 'error')
        return
    end
    loadCarriedIntoWagon(wagon, state)
end)

RegisterNetEvent('node7-wagon-carcasses:client:viewStored', function(data)
    local wagon, state = currentWagonFromData(data)
    if not wagon then
        notify('The wagon could not be identified.', 'error')
        return
    end

    CurrentMenus[state.wagonid] = {
        wagon = wagon,
        networkId = state.networkId,
    }

    TriggerServerEvent('node7-wagon-carcasses:server:list', state.wagonid, state.networkId)
end)

RegisterNetEvent('node7-wagon-carcasses:client:requestUnload', function(data)
    local wagon, state = currentWagonFromData(data)
    if not wagon then
        notify('The wagon could not be identified.', 'error')
        return
    end

    TriggerServerEvent('node7-wagon-carcasses:server:requestUnload', {
        id = tonumber(data.id),
        wagonid = state.wagonid,
        wagonNetId = state.networkId,
    })
end)

RegisterNetEvent('node7-wagon-carcasses:client:list', function(records, wagonid, networkId)
    local menu = CurrentMenus[tostring(wagonid)]
    if not menu or tonumber(menu.networkId) ~= tonumber(networkId) then return end
    if not menu.wagon or not DoesEntityExist(menu.wagon) then return end

    openCarcassMenu(records, wagonid, networkId, menu.wagon)
end)

RegisterNetEvent('node7-wagon-carcasses:client:attachReserved', function(record)
    record = type(record) == 'table' and record or {}

    local wagonNetId = tonumber(record.wagonNetId) or 0
    local carcassNetId = tonumber(record.carcassNetId) or 0
    if wagonNetId == 0 or carcassNetId == 0 then
        TriggerServerEvent('node7-wagon-carcasses:server:loadFailed', tonumber(record.id), 'missing_network_id')
        return
    end

    local wagon = NetworkDoesNetworkIdExist(wagonNetId) and NetworkGetEntityFromNetworkId(wagonNetId) or 0
    local carcass = NetworkDoesNetworkIdExist(carcassNetId) and NetworkGetEntityFromNetworkId(carcassNetId) or 0

    if wagon == 0 or carcass == 0 or not DoesEntityExist(wagon) or not DoesEntityExist(carcass) then
        TriggerServerEvent('node7-wagon-carcasses:server:loadFailed', tonumber(record.id), 'entity_missing')
        return
    end

    if not isValidAnimalCarcass(carcass) then
        TriggerServerEvent('node7-wagon-carcasses:server:loadFailed', tonumber(record.id), 'invalid_animal_carcass')
        return
    end

    -- The server has already validated this exact network entity. Accept it
    -- when it remains beside the player and the rear of the selected wagon,
    -- whether it is still in Rockstar's carry state or was placed down.
    local rear = getWagonRearCoords(wagon)
    local carcassCoords = GetEntityCoords(carcass)
    local closeToPlayer = #(carcassCoords - GetEntityCoords(PlayerPedId())) <= 4.5
    local closeToRear = rear and #(carcassCoords - rear) <= ((tonumber((Config.Interaction or {}).groundLoadDistance) or 3.25) + 1.0)
    if not closeToPlayer or not closeToRear then
        TriggerServerEvent('node7-wagon-carcasses:server:loadFailed', tonumber(record.id), 'carcass_moved_away')
        return
    end

    requestControl(carcass, 25)

    if attachCarcass(carcass, wagon, record) then
        local liveNetId = ensureNetworkId(carcass)
        TriggerServerEvent('node7-wagon-carcasses:server:confirmLoaded', tonumber(record.id), liveNetId)
    else
        local drop = getUnloadCoords(wagon) or GetEntityCoords(PlayerPedId())
        pcall(function() DetachEntity(carcass, true, true) end)
        setStoredPhysics(carcass, false)
        pcall(function() SetEntityCoordsNoOffset(carcass, drop.x, drop.y, drop.z, false, false, false) end)
        pcall(function() PlaceEntityOnGroundProperly(carcass) end)
        TriggerServerEvent('node7-wagon-carcasses:server:loadFailed', tonumber(record.id), 'attach_failed')
    end
end)

RegisterNetEvent('node7-wagon-carcasses:client:restore', function(records, wagonid, wagonNetId)
    wagonNetId = tonumber(wagonNetId) or 0
    if wagonNetId == 0 or not NetworkDoesNetworkIdExist(wagonNetId) then return end

    local wagon = NetworkGetEntityFromNetworkId(wagonNetId)
    if wagon == 0 or not DoesEntityExist(wagon) then return end

    for _, record in ipairs(records or {}) do
        local entity = findEntityByRecord(record.id)

        if entity == 0 and tonumber(record.live_net_id) and tonumber(record.live_net_id) ~= 0
            and NetworkDoesNetworkIdExist(tonumber(record.live_net_id)) then
            local candidate = NetworkGetEntityFromNetworkId(tonumber(record.live_net_id))
            if candidate ~= 0 and DoesEntityExist(candidate)
                and GetEntityModel(candidate) == tonumber(record.model)
                and isValidAnimalCarcass(candidate) then
                local stateOk, state = pcall(function() return Entity(candidate).state end)
                if stateOk and state and tonumber(state.node7CarcassRecord) == tonumber(record.id) then
                    entity = candidate
                end
            end
        end

        if entity == 0 then
            local spawn = GetEntityCoords(wagon)
            entity = createDeadAnimal(tonumber(record.model), spawn, GetEntityHeading(wagon))
        end

        if entity ~= 0 and attachCarcass(entity, wagon, record) then
            TriggerServerEvent(
                'node7-wagon-carcasses:server:updateLiveEntity',
                tonumber(record.id),
                ensureNetworkId(entity),
                tostring(wagonid),
                wagonNetId
            )
        end

        Wait(100)
    end
end)

RegisterNetEvent('node7-wagon-carcasses:client:unload', function(record, wagonNetId)
    record = type(record) == 'table' and record or {}
    wagonNetId = tonumber(wagonNetId) or 0

    if wagonNetId == 0 or not NetworkDoesNetworkIdExist(wagonNetId) then
        TriggerServerEvent('node7-wagon-carcasses:server:unloadFailed', tonumber(record.id), 'wagon_missing')
        return
    end

    local wagon = NetworkGetEntityFromNetworkId(wagonNetId)
    if wagon == 0 or not DoesEntityExist(wagon) then
        TriggerServerEvent('node7-wagon-carcasses:server:unloadFailed', tonumber(record.id), 'wagon_missing')
        return
    end

    local entity = findEntityByRecord(record.id)

    if entity == 0 and tonumber(record.live_net_id) and tonumber(record.live_net_id) ~= 0
        and NetworkDoesNetworkIdExist(tonumber(record.live_net_id)) then
        local candidate = NetworkGetEntityFromNetworkId(tonumber(record.live_net_id))
        if candidate ~= 0 and DoesEntityExist(candidate)
            and GetEntityModel(candidate) == tonumber(record.model)
            and isValidAnimalCarcass(candidate) then
            local stateOk, state = pcall(function() return Entity(candidate).state end)
            if stateOk and state and tonumber(state.node7CarcassRecord) == tonumber(record.id) then
                entity = candidate
            end
        end
    end

    local recreated = false
    if entity == 0 then
        local spawn = getUnloadCoords(wagon)
        if not spawn then
            TriggerServerEvent('node7-wagon-carcasses:server:unloadFailed', tonumber(record.id), 'no_unload_position')
            return
        end
        entity = createDeadAnimal(tonumber(record.model), spawn, GetEntityHeading(wagon))
        recreated = entity ~= 0
    end

    if entity == 0 or not DoesEntityExist(entity) then
        TriggerServerEvent('node7-wagon-carcasses:server:unloadFailed', tonumber(record.id), 'carcass_missing')
        return
    end

    requestControl(entity, 25)

    local drop = getUnloadCoords(wagon)
    if not drop then
        TriggerServerEvent('node7-wagon-carcasses:server:unloadFailed', tonumber(record.id), 'no_unload_position')
        return
    end

    local recordId = tonumber(record.id)

    -- Remove it from the stored registry before any detach/visibility change.
    -- This prevents the one-second resecure loop from hiding it again.
    Managed[recordId] = nil
    UnloadingEntities[entity] = GetGameTimer() + 4000
    clearCarcassState(entity)

    pcall(function() DetachEntity(entity, true, true) end)
    restoreUnloadedCarcass(entity)
    pcall(function() SetEntityCoordsNoOffset(entity, drop.x, drop.y, drop.z, false, false, false) end)
    pcall(function() SetEntityHeading(entity, GetEntityHeading(wagon)) end)
    pcall(function() PlaceEntityOnGroundProperly(entity) end)

    -- Reassert normal visibility briefly after network ownership/state updates.
    for _, delay in ipairs({ 150, 450, 900, 1800 }) do
        SetTimeout(delay, function()
            if DoesEntityExist(entity) and entityIsInUnloadGrace(entity) then
                restoreUnloadedCarcass(entity)
            end
        end)
    end

    TriggerServerEvent('node7-wagon-carcasses:server:confirmUnloaded', recordId, recreated == true)
end)

-- Keep only stored carcasses pinned. This sleeps for one second and touches
-- only records already loaded into a wagon; it does not scan world entities.
CreateThread(function()
    while true do
        Wait(tonumber((Config.HiddenStorage or {}).resecureInterval) or 1000)

        for recordId, managed in pairs(Managed) do
            local entity = tonumber(managed.entity) or 0
            local wagon = tonumber(managed.wagon) or 0

            if entity == 0 or wagon == 0 or not DoesEntityExist(entity) or not DoesEntityExist(wagon) then
                Managed[recordId] = nil
            elseif entityIsInUnloadGrace(entity) then
                Managed[recordId] = nil
                restoreUnloadedCarcass(entity)
            elseif not isAttachedToWagon(entity, wagon) then
                pinCarcassToWagon(entity, wagon, {
                    id = recordId,
                    wagonid = managed.wagonid,
                    model = managed.model,
                    slot = managed.slot,
                })
            else
                -- Keep only confirmed attached/registered carcasses hidden.
                setStoredPhysics(entity, true)
            end
        end
    end
end)

local function registerOrUpdateZone(wagon, state)
    if not targetStarted() or not state or state.networkId == 0 then return end

    local key = tostring(state.wagonid)
    local rear = getWagonRearCoords(wagon)
    if not rear then return end

    local heading = GetEntityHeading(wagon)
    local existing = Zones[key]
    local settings = Config.Interaction or {}

    if existing then
        local moved = #(rear - existing.coords)
        local turned = headingDifference(heading, existing.heading)
        if moved < (tonumber(settings.moveThreshold) or 0.65)
            and turned < (tonumber(settings.headingThreshold) or 8.0)
            and existing.entity == wagon then
            return
        end
        removeZone(key)
    end

    local wagonEntity = wagon
    local wagonId = state.wagonid
    local wagonNetId = state.networkId
    local zoneRadius = tonumber(settings.zoneRadius) or 1.55
    local targetDistance = tonumber(settings.targetDistance) or 3.0

    local zoneId = exports['ox_target']:addSphereZone({
        name = ('node7_carcass_rear_%s'):format(wagonId),
        coords = rear,
        radius = zoneRadius,
        debug = Config.Debug == true,
        drawSprite = settings.drawSprite ~= false,
        options = {
            {
                name = ('node7_carcass_load_%s'):format(wagonId),
                label = 'Store Animal Carcass',
                icon = 'fa-solid fa-paw',
                distance = targetDistance,
                canInteract = function()
                    return DoesEntityExist(wagonEntity) and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                onSelect = function()
                    TriggerEvent('node7-wagon-carcasses:client:loadCarried', {
                        entity = wagonEntity,
                        wagonid = wagonId,
                        networkId = wagonNetId,
                    })
                end,
            },
            {
                name = ('node7_carcass_list_%s'):format(wagonId),
                label = 'Stored Carcasses',
                icon = 'fa-solid fa-list',
                distance = targetDistance,
                canInteract = function()
                    return DoesEntityExist(wagonEntity) and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                onSelect = function()
                    TriggerEvent('node7-wagon-carcasses:client:viewStored', {
                        entity = wagonEntity,
                        wagonid = wagonId,
                        networkId = wagonNetId,
                    })
                end,
            },
        },
    })

    Zones[key] = {
        zoneId = zoneId,
        entity = wagon,
        networkId = state.networkId,
        coords = rear,
        heading = heading,
        lastSeen = GetGameTimer(),
    }

    local restoreKey = ('%s:%s'):format(wagonId, state.networkId)
    local lastRequest = RestoreRequested[restoreKey] or 0
    if GetGameTimer() - lastRequest >= (tonumber(Config.RestoreRequestCooldown) or 10000) then
        RestoreRequested[restoreKey] = GetGameTimer()
        TriggerServerEvent('node7-wagon-carcasses:server:requestRestore', wagonId, state.networkId)
    end
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local seen = {}
        local maxDistance = tonumber((Config.Interaction or {}).scanDistance) or 40.0

        if targetStarted() then
            for _, vehicle in ipairs(enumerateVehicles()) do
                if DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - playerCoords) <= maxDistance then
                    local state = wagonState(vehicle)
                    if state and state.networkId ~= 0 then
                        seen[state.wagonid] = true
                        registerOrUpdateZone(vehicle, state)
                        if Zones[state.wagonid] then Zones[state.wagonid].lastSeen = GetGameTimer() end
                    end
                end
            end
        end

        for key, zone in pairs(Zones) do
            if not seen[key] or not zone.entity or not DoesEntityExist(zone.entity)
                or GetGameTimer() - (zone.lastSeen or 0) > 2500 then
                removeZone(key)
            end
        end

        Wait(tonumber((Config.Interaction or {}).zoneUpdateInterval) or 700)
    end
end)

local function clearPhysicalForMissingWagon()
    for recordId, data in pairs(Managed) do
        if not data.wagon or data.wagon == 0 or not DoesEntityExist(data.wagon) then
            local entity = data.entity
            if entity and entity ~= 0 and DoesEntityExist(entity) and requestControl(entity, 8) then
                clearCarcassState(entity)
                SetEntityAsMissionEntity(entity, true, true)
                pcall(function()
                    if type(DeletePed) == 'function' then DeletePed(entity) end
                end)
                if DoesEntityExist(entity) then
                    pcall(function() DeleteEntity(entity) end)
                end
            end

            TriggerServerEvent('node7-wagon-carcasses:server:markOffline', recordId)
            Managed[recordId] = nil
        end
    end
end

RegisterNetEvent('node7-wagons:client:despawn', function()
    SetTimeout(0, clearPhysicalForMissingWagon)
end)

RegisterNetEvent('node7-wagons:client:forceReplace', function()
    SetTimeout(0, clearPhysicalForMissingWagon)
end)

RegisterNetEvent('node7-wagons:client:spawn', function()
    SetTimeout(250, clearPhysicalForMissingWagon)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for key in pairs(Zones) do removeZone(key) end
end)

exports('GetCarriedAnimalCarcass', function()
    return findCarriedAnimalCarcass()
end)
