ZeeKotaRequests = ZeeKotaRequests or {
    Active = {}
}

local function randomEntry(list)
    if not list or #list == 0 then return nil end
    return list[math.random(1, #list)]
end

local function template(group)
    return randomEntry(Config.MessageTemplates[group] or Config.MessageTemplates.NewCustomer) or 'You active right now?'
end

local function applyTokens(text, tokens)
    text = tostring(text or '')
    if not tokens then return text end
    return (text:gsub('{([%w_]+)}', function(key)
        local value = tokens[key]
        if value == nil then return '' end
        return tostring(value)
    end))
end

local function requestTemplate(group, tokens)
    return applyTokens(template(group), tokens)
end

local function requestPreview(isClient, drug, quantity)
    local drugLabel = drug and (drug.label or drug.id) or 'product'
    local preview = requestTemplate(isClient and 'ExistingClient' or 'NewCustomer', {
        drug = drugLabel,
        quantity = quantity or 1
    })

    if isClient and not preview:lower():find(tostring(drugLabel):lower(), 1, true) then
        preview = ('%s I need %s.'):format(preview, drugLabel)
    end

    return preview
end

local function avatar()
    return randomEntry(Config.ProfileAvatars) or 'ZK'
end

local function alias()
    return randomEntry(Config.CustomerAliases) or ('No Caller %s'):format(math.random(100, 999))
end

local function activeRequestCount(source)
    local count = 0
    for _, request in pairs(ZeeKotaRequests.Active) do
        if request.source == source and (request.status == ZeeKotaBackpage.RequestState.Pending or request.status == ZeeKotaBackpage.RequestState.Accepted) then
            count = count + 1
        end
    end
    return count
end

local function drugSupportsArchetype(drug, archetype)
    local supported = drug.supportedArchetypes or {}
    return not archetype or #supported == 0 or ZeeKotaUtils.Contains(supported, archetype.id)
end

local function canUseDrug(source, drug, reputation)
    if not drug or drug.enabled == false then return false end
    local hasInventory = not Config.Session.RequireDrugInventory or ZeeKotaInventory.HasItem(source, drug.item, 1)
    local reputationOk = (tonumber(reputation) or 0) >= (tonumber(drug.reputationRequirement) or 0)
    return hasInventory and reputationOk
end

local function archetypeHasEligibleDrug(source, archetype, reputation)
    for _, drug in ipairs(ZeeKotaConfig.GetDrugs()) do
        if canUseDrug(source, drug, reputation) and drugSupportsArchetype(drug, archetype) then
            return true
        end
    end
    return false
end

function ZeeKotaRequests.HasEligibleDrug(source, identifier)
    local stats = identifier and ZeeKotaStats.Get(identifier) or nil
    local reputation = stats and tonumber(stats.reputation) or 0

    for _, archetype in ipairs(ZeeKotaConfig.GetArchetypes()) do
        if archetype.enabled and (tonumber(reputation) or 0) >= (tonumber(archetype.reputationRequirement) or 0) and archetypeHasEligibleDrug(source, archetype, reputation) then
            return true
        end
    end

    return false
end

local function chooseArchetype(source, reputation)
    local eligible = {}
    for _, archetype in ipairs(ZeeKotaConfig.GetArchetypes()) do
        if archetype.enabled and (tonumber(reputation) or 0) >= (tonumber(archetype.reputationRequirement) or 0) and archetypeHasEligibleDrug(source, archetype, reputation) then
            eligible[#eligible + 1] = archetype
        end
    end
    return ZeeKotaUtils.Weighted(eligible)
end

local function chooseDrug(source, archetype, reputation)
    local allDrugs = ZeeKotaConfig.GetDrugs()
    local candidates = {}

    for _, drug in ipairs(allDrugs) do
        if canUseDrug(source, drug, reputation) and drugSupportsArchetype(drug, archetype) then
            local copy = ZeeKotaUtils.Copy(drug)
            if archetype and ZeeKotaUtils.Contains(archetype.preferredDrugs or {}, drug.id) then
                copy.weight = (copy.weight or 10) + 20
            end
            candidates[#candidates + 1] = copy
        end
    end

    local selected = ZeeKotaUtils.Weighted(candidates)
    if selected then return selected end

    for _, drug in ipairs(allDrugs) do
        if canUseDrug(source, drug, reputation) then
            candidates[#candidates + 1] = ZeeKotaUtils.Copy(drug)
        end
    end

    return ZeeKotaUtils.Weighted(candidates)
end

local function chooseQuantity(drug, archetype, client)
    local min = math.max(drug.minQuantity or 1, archetype and archetype.minQuantity or 1)
    local max = math.min(drug.maxQuantity or min, archetype and archetype.maxQuantity or drug.maxQuantity or min)
    if max < min then max = min end

    local quantity = ZeeKotaUtils.RandomBetween(min, max)
    if client then
        local tier = ZeeKotaUtils.CalculateTier(client.loyalty, Config.Loyalty.Tiers)
        quantity = math.max(1, math.floor(quantity * (tier and tier.quantityMultiplier or 1.0)))
    end

    return ZeeKotaUtils.Clamp(quantity, drug.minQuantity or 1, math.max(drug.maxQuantity or quantity, quantity))
end

local function calculatePrice(drug, quantity, archetype, client, location)
    local unit = ZeeKotaUtils.RandomBetween(drug.minPrice or 0, drug.maxPrice or drug.minPrice or 0)
    local multiplier = archetype and archetype.budgetMultiplier or 1.0

    if client then
        local tier = ZeeKotaUtils.CalculateTier(client.loyalty, Config.Loyalty.Tiers)
        multiplier = multiplier * (tier and tier.priceMultiplier or 1.0)
    end

    if location and location.priceMultiplier then
        multiplier = multiplier * location.priceMultiplier
    end

    return math.max(0, ZeeKotaUtils.Round(unit * quantity * multiplier))
end

function ZeeKotaRequests.AddMessage(identifier, conversationId, sender, body, kind, metadata, expiresAt)
    body = ZeeKotaSecurity.String(body, 240, '')
    if body == '' then return nil end

    local id = ZeeKotaDB.Insert(([[
        INSERT INTO %s
            (conversation_id, identifier, sender, body, kind, metadata, expires_at, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
    ]]):format(ZeeKotaDB.Table('messages')), {
        conversationId,
        identifier,
        sender or 'customer',
        body,
        kind or 'message',
        ZeeKotaUtils.SafeEncode(metadata or {}),
        expiresAt or 0
    })

    ZeeKotaDB.Execute(('UPDATE %s SET last_message = ?, unread_count = unread_count + ?, updated_at = UNIX_TIMESTAMP() WHERE id = ?'):format(ZeeKotaDB.Table('conversations')), {
        body,
        sender == 'customer' and 1 or 0,
        conversationId
    })

    return id
end

function ZeeKotaRequests.EnsureConversation(identifier, request)
    local existing = ZeeKotaDB.Single(([[
        SELECT * FROM %s
        WHERE identifier = ? AND customer_key = ? AND deleted = 0
        LIMIT 1
    ]]):format(ZeeKotaDB.Table('conversations')), { identifier, request.customerKey })

    if existing then
        ZeeKotaDB.Execute(([[
            UPDATE %s
            SET alias = ?, avatar = ?, is_client = ?, status = ?, request_id = ?, expires_at = ?,
                active_meetup = 0, updated_at = UNIX_TIMESTAMP()
            WHERE id = ?
        ]]):format(ZeeKotaDB.Table('conversations')), {
            request.alias,
            request.avatar,
            request.isClient and 1 or 0,
            request.status,
            request.id,
            request.expiresAt,
            existing.id
        })
        return existing.id
    end

    return ZeeKotaDB.Insert(([[
        INSERT INTO %s
            (identifier, customer_key, alias, avatar, is_client, status, request_id, last_message,
             unread_count, active_meetup, expires_at, deleted, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, '', 0, 0, ?, 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
    ]]):format(ZeeKotaDB.Table('conversations')), {
        identifier,
        request.customerKey,
        request.alias,
        request.avatar,
        request.isClient and 1 or 0,
        request.status,
        request.id,
        request.expiresAt
    })
end

local function buildRequest(source, identifier, session, existingClient)
    local stats = ZeeKotaStats.Get(identifier)
    local reputation = stats and tonumber(stats.reputation) or 0
    local client = existingClient
    local archetype = client and ZeeKotaConfig.GetArchetype(client.archetypeId) or chooseArchetype(source, reputation)
    if not archetype then return nil, 'no_archetype' end

    local drug = chooseDrug(source, archetype, reputation)
    if not drug then return nil, 'no_drug' end

    drug.label = ZeeKotaInventory.GetItemLabel(drug.item, drug.label or drug.id)

    local quantity = chooseQuantity(drug, archetype, client)
    local requestId = ZeeKotaUtils.MakeId('req')
    local customerKey = client and client.customerKey or ZeeKotaUtils.MakeId('cust')
    local customerAlias = client and client.alias or alias()
    local customerAvatar = client and client.avatar or avatar()
    local expiresAt = os.time() + (Config.Session.RequestExpiration or 600)
    local urgency = ZeeKotaUtils.RandomBetween(1, 5)
    local risk = ZeeKotaUtils.Clamp((drug.risk or 0) + (archetype.risk or 0), 0, 100)
    local preview = requestPreview(client ~= nil, drug, quantity)
    local patience = math.min(archetype.patience or Config.Meetups.Timeout, Config.Meetups.Timeout)

    local request = {
        id = requestId,
        source = source,
        identifier = identifier,
        customerKey = customerKey,
        alias = customerAlias,
        avatar = customerAvatar,
        isClient = client ~= nil,
        client = client,
        clientDbId = client and client.id or nil,
        archetypeId = archetype.id,
        archetype = archetype,
        drugId = drug.id,
        drug = drug,
        quantity = quantity,
        price = calculatePrice(drug, quantity, archetype, client),
        urgency = urgency,
        preview = preview,
        expiresAt = expiresAt,
        meetupArea = 'Nearby',
        risk = risk,
        patience = patience,
        loyalty = client and client.loyalty or 0,
        status = ZeeKotaBackpage.RequestState.Pending,
        createdAt = os.time(),
        sampleGiven = false,
        offerAttempts = 0,
        acceptedAt = 0,
        arrivalDeadline = 0
    }

    request.conversationId = ZeeKotaRequests.EnsureConversation(identifier, request)
    ZeeKotaRequests.AddMessage(identifier, request.conversationId, 'customer', preview, 'request', {
        requestId = request.id,
        drug = drug.id,
        drugLabel = drug.label,
        quantity = quantity,
        price = request.price,
        expiresAt = expiresAt
    }, expiresAt)

    return request
end

function ZeeKotaRequests.Generate(source)
    source = tonumber(source)
    local session = ZeeKotaSessions.Get(source)
    if not session or not session.live then return nil, 'not_live' end
    if activeRequestCount(source) >= (Config.Session.MaxSimultaneousRequests or 4) then return nil, 'request_limit' end

    local identifier = session.identifier or ZeeKotaFramework.GetIdentifier(source)
    local roll = math.random(100)
    local existingChance = Config.Session.ExistingClientChance or 45
    local noChance = Config.Session.NoRequestChance or 10
    local existingClient

    if roll <= noChance then
        return nil, 'no_request'
    end

    if roll <= noChance + existingChance then
        existingClient = ZeeKotaClients.SelectExisting(identifier)
    end

    local request, reason = buildRequest(source, identifier, session, existingClient)
    if not request then return nil, reason end

    ZeeKotaRequests.Active[request.id] = request
    session.pendingRequests[request.id] = true
    session.lastRequestAt = os.time()

    ZeeKotaStats.RecordCustomerContact(identifier)

    TriggerClientEvent(ZeeKotaBackpage.Events.NewRequest, source, ZeeKotaRequests.ClientPayload(request))
    ZeeKotaNotify.Send(source, 'notify_new_message')
    return request
end

function ZeeKotaRequests.ClientPayload(request)
    if not request then return nil end
    return {
        id = request.id,
        customerKey = request.customerKey,
        alias = request.alias,
        avatar = request.avatar,
        isClient = request.isClient,
        clientDbId = request.clientDbId,
        archetype = request.archetype and request.archetype.label or request.archetypeId,
        drugId = request.drugId,
        drugLabel = request.drug and request.drug.label or request.drugId,
        quantity = request.quantity,
        price = request.price,
        urgency = request.urgency,
        preview = request.preview,
        expiresAt = request.expiresAt,
        meetupArea = request.meetupArea,
        risk = request.risk,
        patience = request.patience,
        loyalty = request.loyalty,
        status = request.status,
        conversationId = request.conversationId,
        acceptedAt = request.acceptedAt,
        arrivalDeadline = request.arrivalDeadline,
        sampleGiven = request.sampleGiven
    }
end

function ZeeKotaRequests.Get(source, requestId)
    local request = ZeeKotaRequests.Active[requestId]
    if not request or request.source ~= tonumber(source) then return nil end
    return request
end

local function chooseLocation(source, request)
    local ped = GetPlayerPed(source)
    local playerCoords = ped and ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local eligible = {}

    for _, location in ipairs(ZeeKotaConfig.GetLocations()) do
        if location.enabled then
            local distance = ZeeKotaUtils.Distance(playerCoords, location)
            local reputation = (ZeeKotaStats.Get(request.identifier) or {}).reputation or 0
            local archetypeOk = #location.supportedArchetypes == 0 or ZeeKotaUtils.Contains(location.supportedArchetypes, request.archetypeId)
            if distance >= Config.Meetups.MinDistance and distance <= Config.Meetups.MaxDistance and reputation >= (location.minimumReputation or 0) and archetypeOk then
                local copy = ZeeKotaUtils.Copy(location)
                copy.weight = math.max(1, 100 - (copy.risk or 0))
                eligible[#eligible + 1] = copy
            end
        end
    end

    return ZeeKotaUtils.Weighted(eligible) or eligible[1]
end

function ZeeKotaRequests.Accept(source, requestId)
    if not ZeeKotaSecurity.RateLimit(source, 'accept_request', 5, 10) then return { ok = false, error = 'rate_limited' } end

    local request = ZeeKotaRequests.Get(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end
    if request.status ~= ZeeKotaBackpage.RequestState.Pending then return { ok = false, error = 'invalid_state' } end
    if os.time() >= request.expiresAt then
        ZeeKotaRequests.Expire(request.id, 'expired')
        return { ok = false, error = 'expired' }
    end

    if Config.Meetups.OneActiveMeetup and ZeeKotaSessions.HasActiveMeetup(source) then
        return { ok = false, error = 'active_meetup' }
    end

    local location = chooseLocation(source, request)
    if not location then return { ok = false, error = 'no_location' } end

    request.status = ZeeKotaBackpage.RequestState.Accepted
    request.location = location
    request.locationId = location.id
    request.acceptedAt = os.time()
    request.arrivalDeadline = os.time() + math.min(request.patience or Config.Meetups.Timeout, Config.Meetups.Timeout)

    ZeeKotaDB.Execute(('UPDATE %s SET status = ?, active_meetup = 1, updated_at = UNIX_TIMESTAMP() WHERE id = ?'):format(ZeeKotaDB.Table('conversations')), {
        request.status,
        request.conversationId
    })
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'dealer', template('Accepted'), 'system', { requestId = request.id }, request.arrivalDeadline)
    ZeeKotaStats.RecordRequest(request.identifier, 'accepted')
    ZeeKotaSessions.AssignMeetup(source, request)

    TriggerClientEvent(ZeeKotaBackpage.Events.MeetupStarted, source, {
        request = ZeeKotaRequests.ClientPayload(request),
        location = location,
        archetype = request.archetype,
        drug = request.drug,
        config = {
            timeout = Config.Meetups.Timeout,
            interactionDistance = Config.Meetups.InteractionDistance,
            arrivalDistance = Config.Meetups.ArrivalDistance,
            blip = Config.Meetups.Blip,
            customer = Config.Meetups.Customer
        }
    })

    ZeeKotaNotify.Send(source, 'notify_request_accepted')
    return { ok = true, request = ZeeKotaRequests.ClientPayload(request), location = location }
end

function ZeeKotaRequests.Decline(source, requestId)
    local request = ZeeKotaRequests.Get(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end
    if request.status ~= ZeeKotaBackpage.RequestState.Pending then return { ok = false, error = 'invalid_state' } end

    request.status = ZeeKotaBackpage.RequestState.Declined
    ZeeKotaDB.Execute(('UPDATE %s SET status = ?, updated_at = UNIX_TIMESTAMP() WHERE id = ?'):format(ZeeKotaDB.Table('conversations')), {
        request.status,
        request.conversationId
    })
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'dealer', template('Declined'), 'system', { requestId = request.id }, 0)
    ZeeKotaStats.RecordRequest(request.identifier, 'declined')
    if request.isClient then
        ZeeKotaClients.AdjustLoyalty(request.identifier, request.customerKey, Config.Loyalty.DeclinedRequest or -4, 'declined')
    end
    ZeeKotaRequests.Active[request.id] = nil
    ZeeKotaSessions.RemovePendingRequest(source, request.id)
    return { ok = true }
end

function ZeeKotaRequests.Expire(requestId, reason)
    local request = ZeeKotaRequests.Active[requestId]
    if not request then return end
    if request.status == ZeeKotaBackpage.RequestState.Completed then return end

    request.status = ZeeKotaBackpage.RequestState.Expired
    ZeeKotaDB.Execute(('UPDATE %s SET status = ?, active_meetup = 0, updated_at = UNIX_TIMESTAMP() WHERE id = ?'):format(ZeeKotaDB.Table('conversations')), {
        request.status,
        request.conversationId
    })
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'customer', template('Failed'), 'system', { reason = reason or 'expired' }, 0)
    ZeeKotaStats.RecordRequest(request.identifier, 'expired')
    if request.isClient then
        ZeeKotaClients.AdjustLoyalty(request.identifier, request.customerKey, Config.Loyalty.FailedMeetup or -12, 'expired')
    end

    TriggerClientEvent(ZeeKotaBackpage.Events.RequestUpdated, request.source, ZeeKotaRequests.ClientPayload(request))
    TriggerClientEvent(ZeeKotaBackpage.Events.MeetupEnded, request.source, { requestId = request.id, reason = reason or 'expired' })
    ZeeKotaNotify.Send(request.source, 'notify_request_expired')
    ZeeKotaSessions.ClearMeetup(request.source, request.id)
    ZeeKotaSessions.RemovePendingRequest(request.source, request.id)
    ZeeKotaRequests.Active[request.id] = nil
end

function ZeeKotaRequests.Complete(request, outcome)
    if not request then return end
    request.status = outcome == 'success' and ZeeKotaBackpage.RequestState.Completed or ZeeKotaBackpage.RequestState.Failed
    ZeeKotaDB.Execute(('UPDATE %s SET status = ?, active_meetup = 0, updated_at = UNIX_TIMESTAMP() WHERE id = ?'):format(ZeeKotaDB.Table('conversations')), {
        request.status,
        request.conversationId
    })
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'customer', outcome == 'success' and template('Completed') or template('Failed'), 'system', {
        requestId = request.id,
        outcome = outcome
    }, 0)
    TriggerClientEvent(ZeeKotaBackpage.Events.RequestUpdated, request.source, ZeeKotaRequests.ClientPayload(request))
    TriggerClientEvent(ZeeKotaBackpage.Events.MeetupEnded, request.source, { requestId = request.id, reason = outcome })
    ZeeKotaSessions.ClearMeetup(request.source, request.id)
    ZeeKotaSessions.RemovePendingRequest(request.source, request.id)
    ZeeKotaRequests.Active[request.id] = nil
end

function ZeeKotaRequests.GetConversations(identifier)
    local rows = ZeeKotaDB.Query(([[
        SELECT * FROM %s
        WHERE identifier = ? AND deleted = 0
        ORDER BY updated_at DESC
        LIMIT 60
    ]]):format(ZeeKotaDB.Table('conversations')), { identifier })

    local out = {}
    for _, row in ipairs(rows) do
        local messages = ZeeKotaDB.Query(([[
            SELECT id, sender, body, kind, metadata, expires_at, created_at
            FROM %s
            WHERE conversation_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]]):format(ZeeKotaDB.Table('messages')), { row.id, Config.Database.MaxConversationMessages or 80 })

        local ordered = {}
        for i = #messages, 1, -1 do
            local message = messages[i]
            ordered[#ordered + 1] = {
                id = message.id,
                sender = message.sender,
                body = message.body,
                kind = message.kind,
                metadata = ZeeKotaUtils.SafeDecode(message.metadata, {}),
                expiresAt = tonumber(message.expires_at) or 0,
                createdAt = tonumber(message.created_at) or 0
            }
        end

        out[#out + 1] = {
            id = row.id,
            customerKey = row.customer_key,
            alias = row.alias,
            avatar = row.avatar or 'ZK',
            isClient = row.is_client == 1,
            status = row.status,
            requestId = row.request_id,
            lastMessage = row.last_message,
            unreadCount = tonumber(row.unread_count) or 0,
            activeMeetup = row.active_meetup == 1,
            expiresAt = tonumber(row.expires_at) or 0,
            updatedAt = tonumber(row.updated_at) or 0,
            messages = ordered,
            request = row.request_id and ZeeKotaRequests.ClientPayload(ZeeKotaRequests.Active[row.request_id]) or nil
        }
    end

    return out
end

function ZeeKotaRequests.MarkRead(identifier, conversationId)
    ZeeKotaDB.Execute(('UPDATE %s SET unread_count = 0, updated_at = UNIX_TIMESTAMP() WHERE id = ? AND identifier = ?'):format(ZeeKotaDB.Table('conversations')), {
        conversationId,
        identifier
    })
end

function ZeeKotaRequests.DeleteConversation(identifier, conversationId)
    ZeeKotaDB.Execute(('UPDATE %s SET deleted = 1, updated_at = UNIX_TIMESTAMP() WHERE id = ? AND identifier = ?'):format(ZeeKotaDB.Table('conversations')), {
        conversationId,
        identifier
    })
end
