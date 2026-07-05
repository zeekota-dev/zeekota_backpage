ZeeKotaClients = ZeeKotaClients or {}

local function normalizeClient(row)
    if not row then return nil end

    local metadata = ZeeKotaUtils.SafeDecode(row.metadata, {})
    local tier = ZeeKotaUtils.CalculateTier(tonumber(row.loyalty) or 0, Config.Loyalty.Tiers)

    return {
        id = row.id,
        identifier = row.identifier,
        customerKey = row.customer_key,
        alias = row.alias,
        avatar = row.avatar or 'ZK',
        archetypeId = row.archetype_id,
        archetypeLabel = row.archetype_label or row.archetype_id,
        loyalty = tonumber(row.loyalty) or 0,
        tier = tier and tier.label or 'New Contact',
        tierId = tier and tier.id or 'new_contact',
        preferredDrug = row.preferred_drug,
        totalPurchases = tonumber(row.total_purchases) or 0,
        totalSpent = tonumber(row.total_spent) or 0,
        lastPurchase = tonumber(row.last_purchase_at) or 0,
        averageOrderSize = tonumber(row.average_order_size) or 0,
        reliability = tonumber(row.reliability) or 100,
        riskRating = tonumber(row.risk_rating) or 0,
        status = row.status or 'active',
        blocked = row.blocked == 1 or row.blocked == true,
        metadata = metadata
    }
end

function ZeeKotaClients.GetAll(identifier)
    local rows = ZeeKotaDB.Query(('SELECT * FROM %s WHERE identifier = ? ORDER BY blocked ASC, loyalty DESC, alias ASC'):format(ZeeKotaDB.Table('clients')), { identifier })
    local clients = {}
    for _, row in ipairs(rows) do
        clients[#clients + 1] = normalizeClient(row)
    end
    return clients
end

function ZeeKotaClients.Get(identifier, customerKey)
    local row = ZeeKotaDB.Single(('SELECT * FROM %s WHERE identifier = ? AND customer_key = ? LIMIT 1'):format(ZeeKotaDB.Table('clients')), {
        identifier,
        customerKey
    })
    return normalizeClient(row)
end

function ZeeKotaClients.SelectExisting(identifier)
    local clients = ZeeKotaClients.GetAll(identifier)
    local weighted = {}
    for _, client in ipairs(clients) do
        if not client.blocked then
            local tier = ZeeKotaUtils.CalculateTier(client.loyalty, Config.Loyalty.Tiers)
            local weight = math.max(1, math.floor((tier and tier.requestWeight or 1.0) * 10))
            client.weight = weight
            weighted[#weighted + 1] = client
        end
    end
    return ZeeKotaUtils.Weighted(weighted)
end

function ZeeKotaClients.CreateFromRequest(identifier, request, tx)
    if not identifier or not request then return nil end

    local existing = ZeeKotaClients.Get(identifier, request.customerKey)
    if existing then
        return ZeeKotaClients.UpdateAfterSale(identifier, request.customerKey, tx)
    end

    local loyalty = ZeeKotaUtils.Clamp((request.archetype and request.archetype.loyaltyGain or 0) + (tx and tx.loyaltyChange or 0), Config.Loyalty.Min, Config.Loyalty.Max)
    local preferredDrug = request.drug and request.drug.id or request.drugId
    local risk = request.risk or (request.archetype and request.archetype.risk) or 0

    ZeeKotaDB.Insert(([[
        INSERT INTO %s
            (identifier, customer_key, alias, avatar, archetype_id, archetype_label, loyalty, preferred_drug,
             total_purchases, total_spent, last_purchase_at, average_order_size, reliability, risk_rating,
             status, blocked, metadata, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 100, ?, 'active', 0, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
    ]]):format(ZeeKotaDB.Table('clients')), {
        identifier,
        request.customerKey,
        request.alias,
        request.avatar or 'ZK',
        request.archetypeId,
        request.archetype and request.archetype.label or request.archetypeId,
        loyalty,
        preferredDrug,
        tx and tx.paidQuantity or 0,
        tx and tx.payment or 0,
        os.time(),
        tx and tx.paidQuantity or 0,
        risk,
        ZeeKotaUtils.SafeEncode({
            gainedFromDrug = preferredDrug,
            gainedFromAction = tx and tx.action or 'sale',
            firstRequestId = request.id
        })
    })

    TriggerEvent(ZeeKotaBackpage.Events.ClientGained, identifier, request.customerKey)
    return ZeeKotaClients.Get(identifier, request.customerKey)
end

function ZeeKotaClients.UpdateAfterSale(identifier, customerKey, tx)
    local client = ZeeKotaClients.Get(identifier, customerKey)
    if not client then return nil end

    local paidQuantity = math.max(0, tonumber(tx and tx.paidQuantity) or 0)
    local payment = math.max(0, tonumber(tx and tx.payment) or 0)
    local loyaltyChange = math.floor(tonumber(tx and tx.loyaltyChange) or 0)
    local reliabilityChange = math.floor(tonumber(tx and tx.reliabilityChange) or 0)

    local totalPurchases = client.totalPurchases + paidQuantity
    local totalSpent = client.totalSpent + payment
    local metadata = client.metadata or {}
    metadata.transactionCount = (metadata.transactionCount or 0) + ((tx and tx.outcome == 'success') and 1 or 0)
    metadata.lastOutcome = tx and tx.outcome or 'unknown'
    local averageOrder = totalPurchases > 0 and ZeeKotaUtils.Round(totalPurchases / math.max(1, metadata.transactionCount or 1)) or 0

    ZeeKotaDB.Execute(([[
        UPDATE %s
        SET loyalty = ?,
            total_purchases = ?,
            total_spent = ?,
            last_purchase_at = ?,
            average_order_size = ?,
            reliability = ?,
            status = ?,
            metadata = ?,
            updated_at = UNIX_TIMESTAMP()
        WHERE identifier = ? AND customer_key = ?
    ]]):format(ZeeKotaDB.Table('clients')), {
        ZeeKotaUtils.Clamp(client.loyalty + loyaltyChange, Config.Loyalty.Min, Config.Loyalty.Max),
        totalPurchases,
        totalSpent,
        os.time(),
        averageOrder,
        ZeeKotaUtils.Clamp(client.reliability + reliabilityChange, 0, 100),
        tx and tx.status or 'active',
        ZeeKotaUtils.SafeEncode(metadata),
        identifier,
        customerKey
    })

    return ZeeKotaClients.Get(identifier, customerKey)
end

function ZeeKotaClients.AdjustLoyalty(identifier, customerKey, amount, reason)
    local client = ZeeKotaClients.Get(identifier, customerKey)
    if not client then return nil end
    local value = ZeeKotaUtils.Clamp(client.loyalty + (tonumber(amount) or 0), Config.Loyalty.Min, Config.Loyalty.Max)
    ZeeKotaDB.Execute(('UPDATE %s SET loyalty = ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ? AND customer_key = ?'):format(ZeeKotaDB.Table('clients')), {
        value,
        identifier,
        customerKey
    })
    return ZeeKotaClients.Get(identifier, customerKey)
end

function ZeeKotaClients.SetBlocked(identifier, customerKey, blocked)
    ZeeKotaDB.Execute(('UPDATE %s SET blocked = ?, status = ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ? AND customer_key = ?'):format(ZeeKotaDB.Table('clients')), {
        blocked and 1 or 0,
        blocked and 'blocked' or 'active',
        identifier,
        customerKey
    })
    return ZeeKotaClients.Get(identifier, customerKey)
end

function ZeeKotaClients.Remove(identifier, customerKey)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE identifier = ? AND customer_key = ?'):format(ZeeKotaDB.Table('clients')), {
        identifier,
        customerKey
    })
end

function ZeeKotaClients.Reset(identifier)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE identifier = ?'):format(ZeeKotaDB.Table('clients')), { identifier })
end
