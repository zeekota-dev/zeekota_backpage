ZeeKotaTransactions = ZeeKotaTransactions or {
    Locks = {}
}

local function lockKey(source, requestId)
    return ('%s:%s'):format(source, requestId or 'none')
end

local function acquire(source, requestId)
    local key = lockKey(source, requestId)
    if ZeeKotaTransactions.Locks[key] then return false end
    ZeeKotaTransactions.Locks[key] = true
    return true
end

local function release(source, requestId)
    ZeeKotaTransactions.Locks[lockKey(source, requestId)] = nil
end

local function validateInteraction(source, requestId)
    local request = ZeeKotaRequests.Get(source, requestId)
    if not request then return nil, 'invalid_request' end
    if request.status ~= ZeeKotaBackpage.RequestState.Accepted then return nil, 'invalid_state' end
    if os.time() >= request.arrivalDeadline then
        ZeeKotaRequests.Expire(request.id, 'missed_meetup')
        return nil, 'expired'
    end
    if not request.location then return nil, 'missing_location' end

    local near, distance = ZeeKotaSecurity.CheckDistance(source, request.location, Config.Meetups.InteractionDistance + 1.25)
    if not near then
        ZeeKotaSecurity.Suspicious(source, 'distance_sale', { requestId = requestId, distance = distance })
        return nil, 'too_far'
    end

    return request
end

local function acquisitionChance(source, request, extraQuantity, action)
    local stats = ZeeKotaStats.Get(request.identifier)
    local reputation = stats and tonumber(stats.reputation) or 0
    local chance = Config.ClientAcquisition.BaseChance
        + Config.ClientAcquisition.SuccessfulSaleBonus
        + math.floor(reputation / math.max(1, Config.ClientAcquisition.ReputationDivisor))
        + (request.archetype and request.archetype.acquisitionModifier or 0)

    if request.sampleGiven then
        chance = chance + (request.drug.sampleClientChanceBonus or Config.ClientAcquisition.SampleBonus or 0)
    end

    if extraQuantity and extraQuantity > 0 then
        chance = chance + math.min(Config.ClientAcquisition.MaxExtraBonus or 14, extraQuantity * (request.drug.extraUnitBonus or Config.ClientAcquisition.ExtraUnitBonus or 0))
    end

    if action == 'sell_requested' then
        chance = chance + (Config.ClientAcquisition.CorrectRequestBonus or 0)
    end

    if request.acceptedAt > 0 and os.time() - request.acceptedAt <= (Config.ClientAcquisition.FastArrivalSeconds or 180) then
        chance = chance + (Config.ClientAcquisition.FastArrivalBonus or 0)
    end

    if request.offerAttempts and request.offerAttempts > 0 then
        chance = chance - ((Config.ClientAcquisition.RejectionPenalty or 0) * request.offerAttempts)
    end

    return ZeeKotaUtils.Clamp(chance, Config.ClientAcquisition.MinChance, Config.ClientAcquisition.MaxChance)
end

local function maybeGainClient(source, request, tx, extraQuantity, action)
    if request.isClient then
        ZeeKotaClients.UpdateAfterSale(request.identifier, request.customerKey, {
            paidQuantity = tx.paidQuantity + (tx.extraQuantity or 0),
            payment = tx.payment,
            loyaltyChange = tx.loyaltyChange,
            reliabilityChange = 2,
            outcome = 'success',
            status = 'active'
        })
        return false, acquisitionChance(source, request, extraQuantity, action)
    end

    local chance = acquisitionChance(source, request, extraQuantity, action)
    if math.random(100) <= chance then
        tx.clientGained = true
        ZeeKotaClients.CreateFromRequest(request.identifier, request, tx)
        ZeeKotaStats.AddReputation(request.identifier, Config.Reputation.ClientGained or 0, 'client_gained')
        ZeeKotaNotify.Send(source, 'notify_client_gained')
        return true, chance
    end

    return false, chance
end

local function saleResponse(request, tx, chance)
    return {
        ok = true,
        requestId = request.id,
        transaction = tx,
        acquisitionChance = Config.ClientAcquisition.RevealExactChance and chance or nil,
        impression = tx.clientGained and 'outcome_positive'
            or (chance >= 45 and 'outcome_positive')
            or (chance >= 20 and 'outcome_neutral')
            or 'outcome_poor'
    }
end

local function messageTemplate(group)
    local list = Config.MessageTemplates[group] or Config.MessageTemplates.Failed or {}
    if #list == 0 then return '' end
    return list[math.random(1, #list)]
end

function ZeeKotaTransactions.RegisterCustomerPed(source, requestId, netId)
    local request = ZeeKotaRequests.Get(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end
    request.customerNetId = tonumber(netId) or 0
    return { ok = true }
end

function ZeeKotaTransactions.GiveSample(source, data)
    local requestId = data and data.requestId
    local request = validateInteraction(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end
    if request.sampleGiven then return { ok = false, error = 'sample_used' } end
    if not ZeeKotaSecurity.RateLimit(source, 'sample', 4, 15) then return { ok = false, error = 'rate_limited' } end

    local quantity = request.drug.sampleQuantity or 1
    if not ZeeKotaInventory.RemoveItem(source, request.drug.item, quantity, nil) then
        ZeeKotaNotify.Send(source, 'notify_missing_drugs')
        return { ok = false, error = 'missing_drugs' }
    end

    request.sampleGiven = true
    local loyaltyChange = (request.drug.sampleLoyaltyBonus or Config.Loyalty.Sample or 0)
    if request.isClient then
        ZeeKotaClients.AdjustLoyalty(request.identifier, request.customerKey, loyaltyChange, 'sample')
    end

    ZeeKotaStats.RecordTransaction(source, {
        transactionId = ZeeKotaUtils.MakeId('sample'),
        identifier = request.identifier,
        customerKey = request.customerKey,
        requestId = request.id,
        drugId = request.drug.id,
        drugLabel = request.drug.label,
        paidQuantity = 0,
        sampleQuantity = quantity,
        extraQuantity = 0,
        payment = 0,
        paymentType = Config.Payment.Type,
        outcome = 'sample',
        loyaltyChange = loyaltyChange,
        reputationChange = Config.Reputation.Sample or 0,
        locationId = request.locationId,
        metadata = { action = 'sample' }
    })
    ZeeKotaStats.AddReputation(request.identifier, Config.Reputation.Sample or 0, 'sample')
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'dealer', messageTemplate('Sample'), 'system', { requestId = request.id }, 0)
    ZeeKotaNotify.Send(source, 'notify_sample_given')

    return { ok = true, request = ZeeKotaRequests.ClientPayload(request) }
end

function ZeeKotaTransactions.OfferDifferentDrug(source, data)
    local requestId = data and data.requestId
    local offeredDrugId = data and data.drugId
    local request = validateInteraction(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end
    if not ZeeKotaSecurity.RateLimit(source, 'offer_drug', 4, 20) then return { ok = false, error = 'rate_limited' } end
    if request.offerAttempts >= 2 then return { ok = false, error = 'offer_limit' } end

    local offered = ZeeKotaConfig.GetDrug(offeredDrugId)
    if not offered or not offered.enabled then return { ok = false, error = 'invalid_drug' } end
    if not ZeeKotaInventory.HasItem(source, offered.item, 1) then return { ok = false, error = 'missing_drugs' } end

    request.offerAttempts = request.offerAttempts + 1

    local stats = ZeeKotaStats.Get(request.identifier)
    local reputation = stats and tonumber(stats.reputation) or 0
    local tolerance = request.archetype and request.archetype.negotiationTolerance or 50
    local preferred = request.archetype and ZeeKotaUtils.Contains(request.archetype.preferredDrugs or {}, offered.id)
    local loyaltyBoost = request.isClient and math.floor((request.loyalty or 0) / 25) or 0
    local score = tolerance + (preferred and 18 or -12) + math.floor(reputation / 35) + loyaltyBoost - (request.offerAttempts * 8)

    if math.random(100) <= ZeeKotaUtils.Clamp(score, 5, 92) then
        request.drug = offered
        request.drugId = offered.id
        request.quantity = ZeeKotaUtils.Clamp(request.quantity, offered.minQuantity, math.max(offered.maxQuantity, request.quantity))
        request.price = ZeeKotaUtils.Round(request.price * 0.88)
        ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'customer', messageTemplate('OfferAccepted'), 'system', {
            requestId = request.id,
            drug = offered.id,
            price = request.price
        }, request.arrivalDeadline)
        return { ok = true, accepted = true, request = ZeeKotaRequests.ClientPayload(request) }
    end

    ZeeKotaStats.RecordTransaction(source, {
        transactionId = ZeeKotaUtils.MakeId('reject'),
        identifier = request.identifier,
        customerKey = request.customerKey,
        requestId = request.id,
        drugId = offered.id,
        drugLabel = offered.label,
        outcome = 'rejected',
        metadata = { action = 'offer_different', attempts = request.offerAttempts }
    })
    ZeeKotaRequests.AddMessage(request.identifier, request.conversationId, 'customer', messageTemplate('OfferRejected'), 'system', {
        requestId = request.id,
        drug = offered.id
    }, request.arrivalDeadline)
    ZeeKotaNotify.Send(source, 'notify_customer_rejected')
    return { ok = true, accepted = false, request = ZeeKotaRequests.ClientPayload(request) }
end

function ZeeKotaTransactions.CompleteSale(source, data)
    local requestId = data and data.requestId
    if not acquire(source, requestId) then return { ok = false, error = 'locked' } end

    local request, err = validateInteraction(source, requestId)
    if not request then
        release(source, requestId)
        return { ok = false, error = err or 'invalid_request' }
    end

    local extraQuantity = math.floor(tonumber(data and data.extraQuantity) or 0)
    extraQuantity = ZeeKotaUtils.Clamp(extraQuantity, 0, request.drug.maxExtraUnits or 0)
    local totalQuantity = request.quantity + extraQuantity

    if not ZeeKotaInventory.RemoveItem(source, request.drug.item, totalQuantity, nil) then
        release(source, requestId)
        ZeeKotaNotify.Send(source, 'notify_missing_drugs')
        return { ok = false, error = 'missing_drugs' }
    end

    local paid = math.floor(request.price)
    local paidOk = ZeeKotaFramework.AddMoney(source, Config.Payment.Type, Config.Payment.Account, Config.Payment.Item, paid, 'zeekota_backpage_sale')
    if not paidOk then
        ZeeKotaInventory.AddItem(source, request.drug.item, totalQuantity, nil)
        release(source, requestId)
        ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Error, source, request.identifier, 'payment_failed', { requestId = request.id, amount = paid })
        return { ok = false, error = 'payment_failed' }
    end

    local action = extraQuantity > 0 and 'extra_product' or 'sell_requested'
    local loyaltyChange = (Config.Loyalty.Sale or 0) + (extraQuantity * (Config.Loyalty.ExtraUnit or 0)) + (request.archetype and request.archetype.loyaltyGain or 0)
    local reputationChange = Config.Reputation.Sale or 0
    local tx = {
        transactionId = ZeeKotaUtils.MakeId('tx'),
        identifier = request.identifier,
        customerKey = request.customerKey,
        requestId = request.id,
        drugId = request.drug.id,
        drugLabel = request.drug.label,
        drug = request.drug,
        paidQuantity = request.quantity,
        sampleQuantity = request.sampleGiven and (request.drug.sampleQuantity or 1) or 0,
        extraQuantity = extraQuantity,
        payment = paid,
        paymentType = Config.Payment.Type,
        clientGained = false,
        loyaltyChange = loyaltyChange,
        reputationChange = reputationChange,
        locationId = request.locationId,
        outcome = 'success',
        action = action,
        metadata = {
            archetype = request.archetypeId,
            risk = request.risk,
            sampleGiven = request.sampleGiven,
            offerAttempts = request.offerAttempts
        }
    }

    local gained, chance = maybeGainClient(source, request, tx, extraQuantity, action)
    tx.clientGained = gained

    ZeeKotaStats.RecordTransaction(source, tx)
    ZeeKotaStats.AddReputation(request.identifier, reputationChange, 'sale')
    ZeeKotaDispatch.Alert(source, request, request.location, 'sale_completed')
    ZeeKotaRequests.Complete(request, 'success')
    ZeeKotaNotify.Send(source, 'notify_sale_completed')
    TriggerEvent(ZeeKotaBackpage.Events.SaleCompleted, source, tx)

    release(source, requestId)
    return saleResponse(request, tx, chance)
end

function ZeeKotaTransactions.DeclineSale(source, data)
    local requestId = data and data.requestId
    local request = validateInteraction(source, requestId)
    if not request then return { ok = false, error = 'invalid_request' } end

    ZeeKotaStats.RecordTransaction(source, {
        transactionId = ZeeKotaUtils.MakeId('fail'),
        identifier = request.identifier,
        customerKey = request.customerKey,
        requestId = request.id,
        drugId = request.drug.id,
        drugLabel = request.drug.label,
        outcome = 'failed',
        metadata = { action = 'decline_sale' }
    })
    if request.isClient then
        ZeeKotaClients.AdjustLoyalty(request.identifier, request.customerKey, Config.Loyalty.DeclinedRequest or -4, 'decline_sale')
    end
    ZeeKotaStats.AddReputation(request.identifier, Config.Reputation.DeclinedRequest or -1, 'decline_sale')
    ZeeKotaRequests.Complete(request, 'failed')
    return { ok = true }
end
