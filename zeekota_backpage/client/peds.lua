ZeeKotaPeds = ZeeKotaPeds or {}

local spawned = {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(hash), hash
end

function ZeeKotaPeds.SpawnCustomer(request, location, archetype)
    local models = archetype and archetype.pedModels or {}
    local model = models[math.random(1, math.max(1, #models))] or 'a_m_y_stwhi_02'
    local ok, hash = loadModel(model)
    if not ok then return nil end

    local ped = CreatePed(4, hash, location.x, location.y, location.z - 1.0, location.heading or 0.0, true, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, true)
    SetEntityInvincible(ped, Config.Meetups.Customer.Protect == true)
    FreezeEntityPosition(ped, Config.Meetups.Customer.FreezeWhileWaiting == true)
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1000)

    local idle = Config.Meetups.Customer.IdleAnimations[math.random(1, #Config.Meetups.Customer.IdleAnimations)]
    if idle then
        CreateThread(function()
            ZeeKotaAnimations.Play(idle, ped)
        end)
    end

    SetModelAsNoLongerNeeded(hash)
    spawned[request.id] = ped
    return ped
end

function ZeeKotaPeds.Cleanup(requestId)
    local ped = requestId and spawned[requestId] or nil
    if requestId then spawned[requestId] = nil end

    if ped and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetTimeout(Config.Meetups.Customer.CleanupDelay or 5000, function()
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end)
    end
end

function ZeeKotaPeds.CleanupAll()
    for requestId in pairs(spawned) do
        ZeeKotaPeds.Cleanup(requestId)
    end
end

function ZeeKotaPeds.Get(requestId)
    return spawned[requestId]
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, ped in pairs(spawned) do
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end
        spawned = {}
    end
end)
