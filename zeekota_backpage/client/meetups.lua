ZeeKotaMeetups = ZeeKotaMeetups or {
    active = nil,
    nearbyNotified = false
}

local function createBlip(location)
    if not Config.Meetups.Blip.Enabled then return nil end
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, Config.Meetups.Blip.Sprite or 280)
    SetBlipColour(blip, Config.Meetups.Blip.Color or 38)
    SetBlipScale(blip, Config.Meetups.Blip.Scale or 0.78)
    SetBlipAsShortRange(blip, Config.Meetups.Blip.ShortRange == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(ZeeKotaLocale.T('notify_meetup_marked'))
    EndTextCommandSetBlipName(blip)
    if Config.Meetups.Blip.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.Meetups.Blip.Color or 38)
    end
    return blip
end

function ZeeKotaMeetups.HasActiveMeetup()
    return ZeeKotaMeetups.active ~= nil
end

function ZeeKotaMeetups.GetActive()
    return ZeeKotaMeetups.active
end

function ZeeKotaMeetups.GetInteractionPayload()
    local active = ZeeKotaMeetups.active
    if not active then return nil end
    return {
        request = active.request,
        drug = active.drug,
        location = active.location,
        customer = {
            alias = active.request.alias,
            archetype = active.request.archetype,
            patience = active.request.patience,
            status = active.request.status
        },
        drugs = ZeeKotaClient.dashboard and ZeeKotaClient.dashboard.config and ZeeKotaClient.dashboard.config.drugs or {}
    }
end

function ZeeKotaMeetups.Cleanup(reason)
    local active = ZeeKotaMeetups.active
    if active then
        if active.blip and DoesBlipExist(active.blip) then
            SetBlipRoute(active.blip, false)
            RemoveBlip(active.blip)
        end
        ZeeKotaTarget.RemoveCustomer(active.ped)
        ZeeKotaPeds.Cleanup(active.request.id)
    end
    ZeeKotaMeetups.active = nil
    ZeeKotaMeetups.nearbyNotified = false
    ZeeKotaInteractions.HidePrompt()
    SendNUIMessage({ action = 'meetupEnded', payload = { reason = reason or 'cleanup' } })
end

RegisterNetEvent(ZeeKotaBackpage.Events.MeetupStarted, function(payload)
    ZeeKotaMeetups.Cleanup('new_meetup')

    local request = payload.request
    local location = payload.location
    local archetype = payload.archetype
    local ped = ZeeKotaPeds.SpawnCustomer(request, location, archetype)
    local blip = createBlip(location)

    ZeeKotaMeetups.active = {
        request = request,
        location = location,
        archetype = archetype,
        drug = payload.drug,
        ped = ped,
        blip = blip,
        startedAt = GetGameTimer()
    }

    if ped and DoesEntityExist(ped) then
        local netId = NetworkGetNetworkIdFromEntity(ped)
        ZeeKotaClient.AwaitServer('registerCustomerPed', { requestId = request.id, netId = netId }, 5000)
        ZeeKotaTarget.AddCustomer(ped, ZeeKotaLocale.T('ui.speak_customer'), function()
            ZeeKotaInteractions.OpenInteraction()
        end)
    end

    SetNewWaypoint(location.x, location.y)
    ZeeKotaNotify.Send(nil, 'notify_meetup_marked')
    SendNUIMessage({ action = 'meetupStarted', payload = ZeeKotaMeetups.GetInteractionPayload() })
end)

RegisterNetEvent(ZeeKotaBackpage.Events.MeetupEnded, function(payload)
    ZeeKotaMeetups.Cleanup(payload and payload.reason or 'ended')
end)

CreateThread(function()
    while true do
        local wait = 750
        local active = ZeeKotaMeetups.active

        if active and active.location then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local distance = #(coords - vector3(active.location.x, active.location.y, active.location.z))

            if distance <= Config.Meetups.ArrivalDistance and not ZeeKotaMeetups.nearbyNotified then
                ZeeKotaMeetups.nearbyNotified = true
                ZeeKotaNotify.Send(nil, 'notify_customer_nearby')
            end

            if active.ped and DoesEntityExist(active.ped) then
                if IsEntityDead(active.ped) then
                    ZeeKotaMeetups.Cleanup('customer_dead')
                elseif distance < 12.0 then
                    TaskTurnPedToFaceEntity(active.ped, ped, 300)
                end
            end

            wait = distance < 60.0 and 250 or 1000
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ZeeKotaMeetups.Cleanup('resource_stop')
    end
end)
