ZeeKotaClient = ZeeKotaClient or {
    callbacks = {},
    requestId = 0,
    dashboard = nil
}

function ZeeKotaClient.NextRequestId()
    ZeeKotaClient.requestId = ZeeKotaClient.requestId + 1
    return ('cb_%s_%s'):format(GetGameTimer(), ZeeKotaClient.requestId)
end

function ZeeKotaClient.AwaitServer(name, payload, timeout)
    local requestId = ZeeKotaClient.NextRequestId()
    local p = promise.new()
    ZeeKotaClient.callbacks[requestId] = p

    TriggerServerEvent(ZeeKotaBackpage.Events.CallbackRequest, requestId, name, payload or {})

    SetTimeout(timeout or 12000, function()
        if ZeeKotaClient.callbacks[requestId] then
            ZeeKotaClient.callbacks[requestId] = nil
            p:resolve({ ok = false, error = 'timeout' })
        end
    end)

    return Citizen.Await(p)
end

RegisterNetEvent(ZeeKotaBackpage.Events.CallbackResponse, function(requestId, response)
    local p = ZeeKotaClient.callbacks[requestId]
    if not p then return end
    ZeeKotaClient.callbacks[requestId] = nil
    p:resolve(response or { ok = false, error = 'empty_response' })
end)

RegisterNetEvent(ZeeKotaBackpage.Events.SyncState, function(payload)
    ZeeKotaClient.dashboard = payload
    SendNUIMessage({
        action = 'sync',
        payload = payload
    })
end)

RegisterNetEvent(ZeeKotaBackpage.Events.NewRequest, function(request)
    SendNUIMessage({
        action = 'newRequest',
        payload = request
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent(ZeeKotaBackpage.Events.RequestUpdated, function(request)
    SendNUIMessage({
        action = 'requestUpdated',
        payload = request
    })
end)

RegisterNetEvent(ZeeKotaBackpage.Events.ForceClose, function(reason)
    if ZeeKotaPhone then ZeeKotaPhone.Close(reason or 'forced') end
    if ZeeKotaMeetups then ZeeKotaMeetups.Cleanup(reason or 'forced') end
end)

RegisterNetEvent(ZeeKotaBackpage.Events.OpenPhoneFromItem, function()
    ZeeKotaPhone.Open('dealer')
end)

RegisterNetEvent(ZeeKotaBackpage.Events.OpenAdmin, function()
    ZeeKotaPhone.Open('admin')
end)

exports('OpenBackpage', function()
    ZeeKotaPhone.Open('dealer')
end)

exports('CloseBackpage', function()
    ZeeKotaPhone.Close('export')
end)

exports('IsBackpageOpen', function()
    return ZeeKotaPhone and ZeeKotaPhone.IsOpen() or false
end)

exports('HasActiveMeetup', function()
    return ZeeKotaMeetups and ZeeKotaMeetups.HasActiveMeetup() or false
end)
