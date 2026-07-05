ZeeKotaPhone = ZeeKotaPhone or {
    open = false,
    mode = 'dealer',
    opening = false
}

local function invalidState()
    local ped = PlayerPedId()
    if Config.BlockingStates.Dead and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then return true end
    if Config.BlockingStates.Cuffed and (IsPedCuffed(ped) or LocalPlayer.state.isCuffed or LocalPlayer.state.cuffed or LocalPlayer.state.restrained) then return true end
    if Config.BlockingStates.Swimming and IsPedSwimming(ped) then return true end
    if Config.BlockingStates.Falling and IsPedFalling(ped) then return true end
    if Config.BlockingStates.Ragdoll and IsPedRagdoll(ped) then return true end
    if Config.BlockingStates.Vehicle and IsPedInAnyVehicle(ped, false) then return true end
    return false
end

local function hasLocalPhone()
    local ok, count = pcall(function()
        return exports[Config.Inventory]:Search('count', Config.RequiredItem)
    end)
    if not ok then return true end
    return (tonumber(count) or 0) > 0
end

function ZeeKotaPhone.IsOpen()
    return ZeeKotaPhone.open == true
end

function ZeeKotaPhone.Refresh()
    if not ZeeKotaPhone.open then return nil end

    local callback = ZeeKotaPhone.mode == 'admin' and 'admin:getDashboard' or 'getDashboard'
    local result = ZeeKotaClient.AwaitServer(callback, {}, 15000)
    if result and result.ok then
        ZeeKotaClient.dashboard = result
        SendNUIMessage({
            action = 'sync',
            payload = result
        })
    end
    return result
end

function ZeeKotaPhone.Open(mode)
    if ZeeKotaPhone.opening then return end
    mode = mode or 'dealer'

    if mode ~= 'admin' and invalidState() then
        ZeeKotaNotify.Send(nil, 'notify_invalid_state')
        return
    end

    ZeeKotaPhone.opening = true
    local callback = mode == 'admin' and 'admin:getDashboard' or 'getDashboard'
    local dashboard = ZeeKotaClient.AwaitServer(callback, {}, 15000)
    if not dashboard or not dashboard.ok then
        ZeeKotaPhone.opening = false
        ZeeKotaNotify.Send(nil, dashboard and dashboard.error == 'missing_phone' and 'notify_missing_phone' or 'notify_error')
        return
    end

    ZeeKotaPhone.mode = mode
    ZeeKotaClient.dashboard = dashboard
    ZeeKotaAnimations.PhoneIn()
    ZeeKotaPhone.open = true
    ZeeKotaPhone.opening = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'open',
        payload = {
            mode = mode,
            dashboard = dashboard
        }
    })
end

function ZeeKotaPhone.Close(reason)
    if not ZeeKotaPhone.open and not ZeeKotaInteractions.interactionOpen then return end

    ZeeKotaPhone.open = false
    ZeeKotaInteractions.interactionOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'close',
        payload = { reason = reason or 'closed' }
    })
    ZeeKotaAnimations.PhoneOut()
end

local function withRefresh(result)
    if result and result.ok then
        ZeeKotaPhone.Refresh()
    end
    return result or { ok = false, error = 'no_response' }
end

RegisterNUICallback('close', function(_, cb)
    ZeeKotaPhone.Close('nui')
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(ZeeKotaPhone.Refresh() or { ok = false })
end)

RegisterNUICallback('goLive', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local area = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    cb(withRefresh(ZeeKotaClient.AwaitServer('goLive', { area = area }, 15000)))
end)

RegisterNUICallback('endSession', function(_, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('endSession', {}, 15000)))
end)

RegisterNUICallback('acceptRequest', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('acceptRequest', { requestId = data and data.requestId }, 15000)))
end)

RegisterNUICallback('declineRequest', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('declineRequest', { requestId = data and data.requestId }, 15000)))
end)

RegisterNUICallback('cancelMeetup', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('cancelMeetup', { requestId = data and data.requestId }, 15000)))
end)

RegisterNUICallback('markRead', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('markRead', { conversationId = data and data.conversationId }, 10000)))
end)

RegisterNUICallback('deleteConversation', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('deleteConversation', { conversationId = data and data.conversationId }, 10000)))
end)

RegisterNUICallback('blockClient', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('blockClient', { customerKey = data and data.customerKey }, 10000)))
end)

RegisterNUICallback('unblockClient', function(data, cb)
    cb(withRefresh(ZeeKotaClient.AwaitServer('unblockClient', { customerKey = data and data.customerKey }, 10000)))
end)

RegisterNUICallback('leaveInteraction', function(_, cb)
    ZeeKotaInteractions.CloseInteraction()
    cb({ ok = true })
end)

RegisterNUICallback('completeSale', function(data, cb)
    local active = ZeeKotaMeetups.GetActive()
    ZeeKotaAnimations.Handoff(active and active.ped)
    local result = ZeeKotaClient.AwaitServer('completeSale', {
        requestId = data and data.requestId,
        extraQuantity = data and data.extraQuantity or 0
    }, 20000)
    if result and result.ok then ZeeKotaInteractions.CloseInteraction() end
    cb(withRefresh(result))
end)

RegisterNUICallback('giveSample', function(data, cb)
    local active = ZeeKotaMeetups.GetActive()
    ZeeKotaAnimations.Handoff(active and active.ped)
    local result = ZeeKotaClient.AwaitServer('giveSample', { requestId = data and data.requestId }, 16000)
    cb(withRefresh(result))
end)

RegisterNUICallback('offerDifferentDrug', function(data, cb)
    local active = ZeeKotaMeetups.GetActive()
    local result = ZeeKotaClient.AwaitServer('offerDifferentDrug', {
        requestId = data and data.requestId,
        drugId = data and data.drugId
    }, 16000)
    if active and active.ped then
        ZeeKotaAnimations.CustomerReact(active.ped, result and result.accepted and 'inspect' or 'reject')
    end
    cb(withRefresh(result))
end)

RegisterNUICallback('declineSale', function(data, cb)
    local active = ZeeKotaMeetups.GetActive()
    if active and active.ped then ZeeKotaAnimations.CustomerReact(active.ped, 'reject') end
    local result = ZeeKotaClient.AwaitServer('declineSale', { requestId = data and data.requestId }, 12000)
    if result and result.ok then ZeeKotaInteractions.CloseInteraction() end
    cb(withRefresh(result))
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb(ZeeKotaClient.AwaitServer('admin:getDashboard', {}, 15000))
end)

RegisterNUICallback('adminSaveDrug', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:saveDrug', data or {}, 15000))
end)

RegisterNUICallback('adminDeleteDrug', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:deleteDrug', { id = data and data.id }, 15000))
end)

RegisterNUICallback('adminSaveArchetype', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:saveArchetype', data or {}, 15000))
end)

RegisterNUICallback('adminDeleteArchetype', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:deleteArchetype', { id = data and data.id }, 15000))
end)

RegisterNUICallback('adminSaveLocation', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:saveLocation', data or {}, 15000))
end)

RegisterNUICallback('adminDeleteLocation', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:deleteLocation', { id = data and data.id }, 15000))
end)

RegisterNUICallback('adminAddCurrentLocation', function(data, cb)
    local payload = ZeeKotaAdminClient.CurrentLocationPayload(data and data.label)
    cb(ZeeKotaClient.AwaitServer('admin:saveLocation', payload, 15000))
end)

RegisterNUICallback('adminGetCurrentLocation', function(data, cb)
    cb({
        ok = true,
        location = ZeeKotaAdminClient.CurrentLocationPayload(data and data.label)
    })
end)

RegisterNUICallback('adminTeleportLocation', function(data, cb)
    cb({ ok = ZeeKotaAdminClient.Teleport(data and data.location) })
end)

RegisterNUICallback('adminTestSpawn', function(data, cb)
    cb({ ok = ZeeKotaAdminClient.TestSpawn(data and data.location, data and data.archetype) })
end)

RegisterNUICallback('adminSaveSetting', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:saveSetting', data or {}, 15000))
end)

RegisterNUICallback('adminTestItem', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:testItem', { item = data and data.item }, 10000))
end)

RegisterNUICallback('adminSearchPlayer', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:searchPlayer', { query = data and data.query }, 15000))
end)

RegisterNUICallback('adminPlayerAction', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:playerAction', data or {}, 15000))
end)

RegisterNUICallback('adminGetLogs', function(data, cb)
    cb(ZeeKotaClient.AwaitServer('admin:getLogs', { page = data and data.page or 1 }, 15000))
end)

RegisterNUICallback('adminRefreshCache', function(_, cb)
    cb(ZeeKotaClient.AwaitServer('admin:refreshCache', {}, 20000))
end)

CreateThread(function()
    while true do
        if ZeeKotaPhone.open then
            for _, control in ipairs(Config.Phone.DisableControls or {}) do
                DisableControlAction(0, control, true)
            end
            for _, control in ipairs(Config.Phone.CloseControls or {}) do
                if IsControlJustPressed(0, control) then
                    ZeeKotaPhone.Close('control')
                    break
                end
            end
            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        if ZeeKotaPhone.open then
            if Config.Phone.CloseOnInvalidState and ZeeKotaPhone.mode ~= 'admin' and invalidState() then
                ZeeKotaPhone.Close('invalid_state')
            elseif ZeeKotaPhone.mode ~= 'admin' and not hasLocalPhone() then
                ZeeKotaPhone.Close('missing_phone')
            end
            Wait(1000)
        else
            Wait(1500)
        end
    end
end)
