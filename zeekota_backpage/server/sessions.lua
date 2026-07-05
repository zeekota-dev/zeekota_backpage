ZeeKotaSessions = ZeeKotaSessions or {
    Active = {},
    Cooldowns = {}
}

function ZeeKotaSessions.Get(source)
    return ZeeKotaSessions.Active[tonumber(source)]
end

function ZeeKotaSessions.IsLive(source)
    local session = ZeeKotaSessions.Get(source)
    return session and session.live == true
end

local function sessionPayload(source)
    local session = ZeeKotaSessions.Get(source)
    if not session then
        return {
            live = false,
            startedAt = 0,
            endsAt = 0,
            nextRequestAt = 0,
            pendingMeetups = 0,
            pendingRequests = 0,
            cooldownEndsAt = ZeeKotaSessions.Cooldowns[source] or 0
        }
    end

    local requestCount = 0
    for _ in pairs(session.pendingRequests or {}) do requestCount = requestCount + 1 end

    return {
        live = session.live,
        startedAt = session.startedAt,
        endsAt = session.endsAt,
        nextRequestAt = session.nextRequestAt,
        lastRequestAt = session.lastRequestAt,
        pendingMeetups = session.activeMeetup and 1 or 0,
        pendingRequests = requestCount,
        cooldownEndsAt = ZeeKotaSessions.Cooldowns[source] or 0,
        area = session.area or 'Unknown'
    }
end

function ZeeKotaSessions.BuildDashboard(source)
    local identifier = ZeeKotaStats.EnsurePlayer(source)
    if not identifier then return { ok = false, error = 'missing_identifier' } end

    return {
        ok = true,
        config = ZeeKotaConfig.SafeClientConfig(),
        session = sessionPayload(source),
        stats = ZeeKotaStats.BuildPayload(identifier),
        clients = ZeeKotaClients.GetAll(identifier),
        conversations = ZeeKotaRequests.GetConversations(identifier),
        serverTime = os.time()
    }
end

function ZeeKotaSessions.Sync(source)
    TriggerClientEvent(ZeeKotaBackpage.Events.SyncState, source, ZeeKotaSessions.BuildDashboard(source))
end

function ZeeKotaSessions.SyncAllSafeConfig()
    for _, source in ipairs(GetPlayers()) do
        TriggerClientEvent(ZeeKotaBackpage.Events.SyncState, tonumber(source), ZeeKotaSessions.BuildDashboard(tonumber(source)))
    end
end

local function canStartSession(source)
    if not ZeeKotaSecurity.RateLimit(source, 'go_live', 4, 15) then
        return false, 'rate_limited'
    end

    if not ZeeKotaSecurity.RequirePhone(source) then
        return false, 'missing_phone'
    end

    if ZeeKotaSessions.IsLive(source) then
        return false, 'already_live'
    end

    local cooldown = ZeeKotaSessions.Cooldowns[source] or 0
    if cooldown > os.time() then
        return false, 'cooldown'
    end

    if Config.Session.RequiredPolice > 0 and ZeeKotaFramework.GetPoliceCount() < Config.Session.RequiredPolice then
        return false, 'police'
    end

    local identifier = ZeeKotaStats.EnsurePlayer(source)
    if not identifier then
        return false, 'missing_identifier'
    end

    if not ZeeKotaRequests.HasEligibleDrug(source, identifier) then
        return false, 'no_eligible_drugs'
    end

    if Config.Session.AllowInVehicles == false then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 then
            return false, 'vehicle'
        end
    end

    return true
end

function ZeeKotaSessions.Start(source, area)
    source = tonumber(source)
    local ok, reason = canStartSession(source)
    if not ok then
        if reason == 'cooldown' then ZeeKotaNotify.Send(source, 'notify_cooldown') end
        if reason == 'police' then ZeeKotaNotify.Send(source, 'notify_police') end
        if reason == 'missing_drugs' then ZeeKotaNotify.Send(source, 'notify_missing_drugs') end
        if reason == 'no_eligible_drugs' then ZeeKotaNotify.Send(source, 'notify_no_eligible_drugs') end
        if reason == 'rate_limited' then ZeeKotaNotify.Send(source, 'notify_rate_limited') end
        return { ok = false, error = reason }
    end

    local identifier = ZeeKotaStats.EnsurePlayer(source)
    local now = os.time()
    ZeeKotaSessions.Active[source] = {
        source = source,
        identifier = identifier,
        live = true,
        startedAt = now,
        endsAt = now + (Config.Session.Duration or 2700),
        nextRequestAt = now + ZeeKotaUtils.RandomBetween(Config.Session.MinFirstRequestDelay, Config.Session.MaxFirstRequestDelay),
        lastRequestAt = 0,
        pendingRequests = {},
        activeMeetup = nil,
        area = area or 'Unknown'
    }

    TriggerEvent(ZeeKotaBackpage.Events.DealerLive, source, identifier)
    ZeeKotaNotify.Send(source, 'notify_session_started')
    ZeeKotaSessions.Sync(source)
    return { ok = true, session = sessionPayload(source) }
end

function ZeeKotaSessions.End(source, reason)
    source = tonumber(source)
    local session = ZeeKotaSessions.Active[source]
    if not session then return { ok = true } end

    if session.activeMeetup and Config.Session.AllowEndWithMeetup == false then
        return { ok = false, error = 'active_meetup' }
    end

    local now = os.time()
    ZeeKotaStats.RecordLiveTime(session.identifier, math.max(0, now - session.startedAt))
    ZeeKotaSessions.Cooldowns[source] = now + (Config.Session.Cooldown or 600)
    session.live = false
    ZeeKotaSessions.Active[source] = nil

    TriggerEvent(ZeeKotaBackpage.Events.DealerOffline, source, session.identifier, reason or 'manual')
    ZeeKotaNotify.Send(source, 'notify_session_ended')
    ZeeKotaSessions.Sync(source)
    return { ok = true, cooldownEndsAt = ZeeKotaSessions.Cooldowns[source] }
end

function ZeeKotaSessions.RemovePendingRequest(source, requestId)
    local session = ZeeKotaSessions.Get(source)
    if session and session.pendingRequests then
        session.pendingRequests[requestId] = nil
    end
end

function ZeeKotaSessions.AssignMeetup(source, request)
    local session = ZeeKotaSessions.Get(source)
    if not session then return end
    session.activeMeetup = {
        requestId = request.id,
        startedAt = os.time(),
        deadline = request.arrivalDeadline,
        location = request.location
    }
end

function ZeeKotaSessions.HasActiveMeetup(source)
    local session = ZeeKotaSessions.Get(source)
    return session and session.activeMeetup ~= nil
end

function ZeeKotaSessions.ClearMeetup(source, requestId)
    local session = ZeeKotaSessions.Get(source)
    if session and session.activeMeetup and (not requestId or session.activeMeetup.requestId == requestId) then
        session.activeMeetup = nil
    end
end

function ZeeKotaSessions.CancelMeetup(source, requestId)
    local session = ZeeKotaSessions.Get(source)
    if not session or not session.activeMeetup then return { ok = false, error = 'no_meetup' } end
    local activeRequestId = requestId or session.activeMeetup.requestId
    ZeeKotaRequests.Expire(activeRequestId, 'cancelled')
    return { ok = true }
end

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        for requestId, request in pairs(ZeeKotaRequests.Active) do
            if request.status == ZeeKotaBackpage.RequestState.Pending and now >= request.expiresAt then
                ZeeKotaRequests.Expire(requestId, 'expired')
            elseif request.status == ZeeKotaBackpage.RequestState.Accepted and request.arrivalDeadline > 0 and now >= request.arrivalDeadline then
                ZeeKotaRequests.Expire(requestId, 'missed_meetup')
            end
        end

        for source, session in pairs(ZeeKotaSessions.Active) do
            if not GetPlayerName(source) then
                ZeeKotaSessions.Active[source] = nil
            elseif session.live then
                if now >= session.endsAt then
                    ZeeKotaSessions.End(source, 'duration')
                elseif (not Config.Session.PauseDuringMeetup or not session.activeMeetup) and now >= session.nextRequestAt then
                    local ok, request, reason = pcall(ZeeKotaRequests.Generate, source)
                    if not ok then
                        reason = 'server_error'
                        if Config.Debug then
                            ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Error, source, session.identifier, 'request_generation_error', { error = request })
                        end
                        request = nil
                    end

                    if request then
                        session.nextRequestAt = now + ZeeKotaUtils.RandomBetween(Config.Session.MinRequestDelay, Config.Session.MaxRequestDelay)
                    elseif reason == 'request_limit' then
                        session.nextRequestAt = now + ZeeKotaUtils.RandomBetween(Config.Session.MinRequestDelay, Config.Session.MaxRequestDelay)
                    else
                        session.nextRequestAt = now + (Config.Session.FailedRequestRetryDelay or 15)
                        if Config.Debug then
                            ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Error, source, session.identifier, 'request_generation_failed', { reason = reason or 'unknown' })
                        end
                    end
                    ZeeKotaSessions.Sync(source)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    ZeeKotaSessions.End(source, 'disconnect')
    for requestId, request in pairs(ZeeKotaRequests.Active) do
        if request.source == source then
            ZeeKotaRequests.Active[requestId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for source in pairs(ZeeKotaSessions.Active) do
        TriggerClientEvent(ZeeKotaBackpage.Events.ForceClose, source, 'resource_stop')
    end
end)
