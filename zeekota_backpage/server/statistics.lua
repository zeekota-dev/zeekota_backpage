ZeeKotaStats = ZeeKotaStats or {}

local function defaultDrugStats(drug)
    return {
        id = drug.id,
        label = drug.label,
        unitsSold = 0,
        revenue = 0,
        transactions = 0,
        samplesGiven = 0,
        clientsGained = 0,
        averageUnits = 0,
        averageSale = 0,
        lastSale = 0
    }
end

function ZeeKotaStats.EnsurePlayer(source)
    local identifier = ZeeKotaFramework.GetIdentifier(source)
    if not identifier then return nil end

    ZeeKotaDB.Execute(([[
        INSERT INTO %s
            (identifier, display_name, handle, reputation, drug_stats, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE
            display_name = VALUES(display_name),
            updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('players')), {
        identifier,
        ZeeKotaFramework.GetPlayerName(source),
        ('bp_%s'):format(math.random(10000, 99999)),
        Config.Reputation.Starting or 0,
        ZeeKotaUtils.SafeEncode({})
    })

    return identifier
end

function ZeeKotaStats.Get(identifier)
    if not identifier then return nil end
    local row = ZeeKotaDB.Single(('SELECT * FROM %s WHERE identifier = ? LIMIT 1'):format(ZeeKotaDB.Table('players')), { identifier })
    if not row then return nil end

    row.drugStatsRaw = ZeeKotaUtils.SafeDecode(row.drug_stats, {})
    return row
end

function ZeeKotaStats.GetForSource(source)
    local identifier = ZeeKotaStats.EnsurePlayer(source)
    return ZeeKotaStats.Get(identifier), identifier
end

function ZeeKotaStats.GetDrugStats(identifier)
    local stats = ZeeKotaStats.Get(identifier)
    local raw = stats and stats.drugStatsRaw or {}
    local out = {}

    for _, drug in ipairs(ZeeKotaConfig.GetDrugs()) do
        local entry = raw[drug.id] or defaultDrugStats(drug)
        entry.id = drug.id
        entry.label = drug.label
        out[#out + 1] = entry
    end

    return out
end

function ZeeKotaStats.AddReputation(identifier, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 or not identifier then return 0 end

    local stats = ZeeKotaStats.Get(identifier)
    if not stats then return 0 end

    local current = tonumber(stats.reputation) or Config.Reputation.Starting or 0
    local nextValue = ZeeKotaUtils.Clamp(current + amount, Config.Reputation.Min or -500, Config.Reputation.Max or 10000)

    ZeeKotaDB.Execute(('UPDATE %s SET reputation = ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players')), {
        nextValue,
        identifier
    })

    TriggerEvent(ZeeKotaBackpage.Events.ReputationChanged, identifier, nextValue, amount, reason)
    return nextValue
end

function ZeeKotaStats.RecordLiveTime(identifier, seconds)
    if not identifier or (tonumber(seconds) or 0) <= 0 then return end
    ZeeKotaDB.Execute(('UPDATE %s SET total_live_time = total_live_time + ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players')), {
        math.floor(seconds),
        identifier
    })
end

function ZeeKotaStats.RecordRequest(identifier, action)
    if not identifier then return end
    local column = action == 'accepted' and 'requests_accepted'
        or action == 'declined' and 'requests_declined'
        or action == 'expired' and 'expired_requests'
        or nil
    if not column then return end
    ZeeKotaDB.Execute(('UPDATE %s SET %s = %s + 1, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players'), column, column), { identifier })
end

function ZeeKotaStats.RecordCustomerContact(identifier)
    ZeeKotaDB.Execute(('UPDATE %s SET total_customers_contacted = total_customers_contacted + 1, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players')), { identifier })
end

function ZeeKotaStats.RecordTransaction(source, tx)
    local identifier = tx.identifier or ZeeKotaFramework.GetIdentifier(source)
    if not identifier then return false end

    local stats = ZeeKotaStats.Get(identifier)
    if not stats then return false end

    local drugId = tx.drugId or (tx.drug and tx.drug.id) or 'unknown'
    local drugLabel = tx.drugLabel or (tx.drug and tx.drug.label) or drugId
    local drugStats = ZeeKotaUtils.SafeDecode(stats.drug_stats, {})
    local current = drugStats[drugId] or {
        id = drugId,
        label = drugLabel,
        unitsSold = 0,
        revenue = 0,
        transactions = 0,
        samplesGiven = 0,
        clientsGained = 0,
        averageUnits = 0,
        averageSale = 0,
        lastSale = 0
    }

    local paidQuantity = math.max(0, math.floor(tonumber(tx.paidQuantity) or 0))
    local extraQuantity = math.max(0, math.floor(tonumber(tx.extraQuantity) or 0))
    local sampleQuantity = math.max(0, math.floor(tonumber(tx.sampleQuantity) or 0))
    local payment = math.max(0, math.floor(tonumber(tx.payment) or 0))
    local successful = tx.outcome == 'success'

    if successful then
        current.unitsSold = (tonumber(current.unitsSold) or 0) + paidQuantity + extraQuantity
        current.revenue = (tonumber(current.revenue) or 0) + payment
        current.transactions = (tonumber(current.transactions) or 0) + 1
        current.lastSale = os.time()
        current.averageUnits = current.transactions > 0 and ZeeKotaUtils.Round(current.unitsSold / current.transactions) or 0
        current.averageSale = current.transactions > 0 and ZeeKotaUtils.Round(current.revenue / current.transactions) or 0
    end

    current.samplesGiven = (tonumber(current.samplesGiven) or 0) + sampleQuantity
    if tx.clientGained then
        current.clientsGained = (tonumber(current.clientsGained) or 0) + 1
    end

    drugStats[drugId] = current

    local totalTransactions = (tonumber(stats.total_transactions) or 0) + (successful and 1 or 0)
    local totalMoney = (tonumber(stats.total_money_made) or 0) + (successful and payment or 0)
    local averageSale = totalTransactions > 0 and ZeeKotaUtils.Round(totalMoney / totalTransactions) or 0
    local largestSale = math.max(tonumber(stats.largest_sale) or 0, successful and payment or 0)

    ZeeKotaDB.Execute(([[
        UPDATE %s
        SET total_drugs_sold = total_drugs_sold + ?,
            total_transactions = ?,
            total_money_made = ?,
            total_samples_given = total_samples_given + ?,
            total_clients_gained = total_clients_gained + ?,
            successful_sales = successful_sales + ?,
            failed_sales = failed_sales + ?,
            rejected_offers = rejected_offers + ?,
            average_sale_value = ?,
            largest_sale = ?,
            drug_stats = ?,
            updated_at = UNIX_TIMESTAMP()
        WHERE identifier = ?
    ]]):format(ZeeKotaDB.Table('players')), {
        successful and (paidQuantity + extraQuantity) or 0,
        totalTransactions,
        totalMoney,
        sampleQuantity,
        tx.clientGained and 1 or 0,
        successful and 1 or 0,
        tx.outcome == 'failed' and 1 or 0,
        tx.outcome == 'rejected' and 1 or 0,
        averageSale,
        largestSale,
        ZeeKotaUtils.SafeEncode(drugStats),
        identifier
    })

    ZeeKotaDB.Insert(([[
        INSERT INTO %s
            (transaction_id, identifier, customer_key, request_id, drug, paid_quantity, sample_quantity,
             extra_quantity, payment, payment_type, client_gained, loyalty_change, reputation_change,
             meetup_location, outcome, metadata, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
    ]]):format(ZeeKotaDB.Table('transactions')), {
        tx.transactionId or ZeeKotaUtils.MakeId('tx'),
        identifier,
        tx.customerKey or '',
        tx.requestId or '',
        drugId,
        paidQuantity,
        sampleQuantity,
        extraQuantity,
        payment,
        tx.paymentType or Config.Payment.Type,
        tx.clientGained and 1 or 0,
        tx.loyaltyChange or 0,
        tx.reputationChange or 0,
        tx.locationId or '',
        tx.outcome or 'unknown',
        ZeeKotaUtils.SafeEncode(tx.metadata or {})
    })

    return true
end

function ZeeKotaStats.BuildPayload(identifier)
    local stats = ZeeKotaStats.Get(identifier)
    if not stats then return nil end

    local highestTier = 'New Contact'
    local clients = ZeeKotaClients.GetAll(identifier)
    for _, client in ipairs(clients) do
        local tier = ZeeKotaUtils.CalculateTier(client.loyalty or 0, Config.Loyalty.Tiers)
        if tier then highestTier = tier.label end
    end

    return {
        handle = stats.handle,
        reputation = tonumber(stats.reputation) or 0,
        totalDrugsSold = tonumber(stats.total_drugs_sold) or 0,
        totalTransactions = tonumber(stats.total_transactions) or 0,
        totalMoneyMade = tonumber(stats.total_money_made) or 0,
        totalSamplesGiven = tonumber(stats.total_samples_given) or 0,
        totalCustomersContacted = tonumber(stats.total_customers_contacted) or 0,
        totalClientsGained = tonumber(stats.total_clients_gained) or 0,
        requestsAccepted = tonumber(stats.requests_accepted) or 0,
        requestsDeclined = tonumber(stats.requests_declined) or 0,
        successfulSales = tonumber(stats.successful_sales) or 0,
        failedSales = tonumber(stats.failed_sales) or 0,
        rejectedOffers = tonumber(stats.rejected_offers) or 0,
        expiredRequests = tonumber(stats.expired_requests) or 0,
        averageSaleValue = tonumber(stats.average_sale_value) or 0,
        largestSale = tonumber(stats.largest_sale) or 0,
        highestClientTier = highestTier,
        totalLiveTime = tonumber(stats.total_live_time) or 0,
        drugStats = ZeeKotaStats.GetDrugStats(identifier)
    }
end
