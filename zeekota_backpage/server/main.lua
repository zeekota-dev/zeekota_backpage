local callbacks = {}

local function registerCallback(name, handler)
    callbacks[name] = handler
end

RegisterNetEvent(ZeeKotaBackpage.Events.CallbackRequest, function(requestId, name, payload)
    local source = source
    requestId = tostring(requestId or '')
    name = tostring(name or '')

    local handler = callbacks[name]
    local response

    if not handler then
        response = { ok = false, error = 'unknown_callback' }
    else
        local ok, result = pcall(handler, source, payload or {})
        if ok then
            response = result or { ok = true }
        else
            response = { ok = false, error = 'server_error' }
            ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Error, source, nil, 'callback_error', { name = name, error = result })
        end
    end

    TriggerClientEvent(ZeeKotaBackpage.Events.CallbackResponse, source, requestId, response)
end)

RegisterNetEvent('zeekota_backpage:server:useBurnerPhone', function(playerSource)
    playerSource = tonumber(playerSource) or source
    if not playerSource or playerSource <= 0 then return end
    if not ZeeKotaSecurity.RequirePhone(playerSource) then return end
    TriggerClientEvent(ZeeKotaBackpage.Events.OpenPhoneFromItem, playerSource)
end)

local function openPhoneFromUsable(source)
    if not ZeeKotaSecurity.RequirePhone(source) then return end
    TriggerClientEvent(ZeeKotaBackpage.Events.OpenPhoneFromItem, source)
end

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
    ZeeKotaConfig.Load()
    ZeeKotaInventory.RegisterBurnerPhoneUse(openPhoneFromUsable)

    while true do
        Wait((Config.Database.CleanupIntervalMinutes or 30) * 60000)
        ZeeKotaDB.Prune()
    end
end)

registerCallback('getDashboard', function(source)
    if not ZeeKotaSecurity.RequirePhone(source) then return { ok = false, error = 'missing_phone' } end
    return ZeeKotaSessions.BuildDashboard(source)
end)

registerCallback('goLive', function(source, payload)
    return ZeeKotaSessions.Start(source, payload and payload.area)
end)

registerCallback('endSession', function(source)
    return ZeeKotaSessions.End(source, 'manual')
end)

registerCallback('acceptRequest', function(source, payload)
    return ZeeKotaRequests.Accept(source, payload and payload.requestId)
end)

registerCallback('declineRequest', function(source, payload)
    return ZeeKotaRequests.Decline(source, payload and payload.requestId)
end)

registerCallback('cancelMeetup', function(source, payload)
    return ZeeKotaSessions.CancelMeetup(source, payload and payload.requestId)
end)

registerCallback('markRead', function(source, payload)
    local identifier = ZeeKotaFramework.GetIdentifier(source)
    ZeeKotaRequests.MarkRead(identifier, tonumber(payload and payload.conversationId))
    return { ok = true }
end)

registerCallback('deleteConversation', function(source, payload)
    local identifier = ZeeKotaFramework.GetIdentifier(source)
    ZeeKotaRequests.DeleteConversation(identifier, tonumber(payload and payload.conversationId))
    return { ok = true }
end)

registerCallback('blockClient', function(source, payload)
    local identifier = ZeeKotaFramework.GetIdentifier(source)
    local client = ZeeKotaClients.SetBlocked(identifier, payload and payload.customerKey, true)
    return { ok = true, client = client }
end)

registerCallback('unblockClient', function(source, payload)
    local identifier = ZeeKotaFramework.GetIdentifier(source)
    local client = ZeeKotaClients.SetBlocked(identifier, payload and payload.customerKey, false)
    return { ok = true, client = client }
end)

registerCallback('registerCustomerPed', function(source, payload)
    return ZeeKotaTransactions.RegisterCustomerPed(source, payload and payload.requestId, payload and payload.netId)
end)

registerCallback('completeSale', function(source, payload)
    return ZeeKotaTransactions.CompleteSale(source, payload)
end)

registerCallback('giveSample', function(source, payload)
    return ZeeKotaTransactions.GiveSample(source, payload)
end)

registerCallback('offerDifferentDrug', function(source, payload)
    return ZeeKotaTransactions.OfferDifferentDrug(source, payload)
end)

registerCallback('declineSale', function(source, payload)
    return ZeeKotaTransactions.DeclineSale(source, payload)
end)

registerCallback('admin:getDashboard', function(source)
    return ZeeKotaAdmin.Dashboard(source)
end)

registerCallback('admin:saveDrug', function(source, payload)
    return ZeeKotaAdmin.SaveDrug(source, payload)
end)

registerCallback('admin:deleteDrug', function(source, payload)
    return ZeeKotaAdmin.DeleteDrug(source, payload and payload.id)
end)

registerCallback('admin:saveArchetype', function(source, payload)
    return ZeeKotaAdmin.SaveArchetype(source, payload)
end)

registerCallback('admin:deleteArchetype', function(source, payload)
    return ZeeKotaAdmin.DeleteArchetype(source, payload and payload.id)
end)

registerCallback('admin:saveLocation', function(source, payload)
    return ZeeKotaAdmin.SaveLocation(source, payload)
end)

registerCallback('admin:deleteLocation', function(source, payload)
    return ZeeKotaAdmin.DeleteLocation(source, payload and payload.id)
end)

registerCallback('admin:saveSetting', function(source, payload)
    return ZeeKotaAdmin.SaveSetting(source, payload)
end)

registerCallback('admin:testItem', function(source, payload)
    return ZeeKotaAdmin.TestItem(source, payload and payload.item)
end)

registerCallback('admin:searchPlayer', function(source, payload)
    return ZeeKotaAdmin.SearchPlayer(source, payload and payload.query)
end)

registerCallback('admin:playerAction', function(source, payload)
    return ZeeKotaAdmin.PlayerAction(source, payload)
end)

registerCallback('admin:getLogs', function(source, payload)
    return ZeeKotaAdmin.Logs(source, payload and payload.page)
end)

registerCallback('admin:refreshCache', function(source)
    return ZeeKotaAdmin.Refresh(source)
end)

exports('GetDealerReputation', function(identifier)
    local stats = ZeeKotaStats.Get(identifier)
    return stats and tonumber(stats.reputation) or 0
end)

exports('GetDealerClients', function(identifier)
    return ZeeKotaClients.GetAll(identifier)
end)

exports('IsDealerLive', function(source)
    return ZeeKotaSessions.IsLive(source)
end)

exports('CancelDealerSession', function(source)
    return ZeeKotaSessions.End(source, 'export')
end)

exports('AddDealerReputation', function(identifier, amount, reason)
    return ZeeKotaStats.AddReputation(identifier, amount, reason or 'export')
end)
