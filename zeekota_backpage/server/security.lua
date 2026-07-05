ZeeKotaSecurity = ZeeKotaSecurity or {}

local buckets = {}

function ZeeKotaSecurity.RateLimit(source, action, limit, window)
    source = tonumber(source) or 0
    limit = tonumber(limit) or 8
    window = tonumber(window) or 5

    local key = ('%s:%s'):format(source, action)
    local now = GetGameTimer()
    local bucket = buckets[key]
    if not bucket or now > bucket.reset then
        buckets[key] = { count = 1, reset = now + (window * 1000) }
        return true
    end

    bucket.count = bucket.count + 1
    if bucket.count > limit then
        ZeeKotaSecurity.Suspicious(source, 'rate_limit', { action = action, count = bucket.count })
        return false
    end

    return true
end

function ZeeKotaSecurity.Suspicious(source, reason, metadata)
    if not Config.Logging.LogSuspiciousEvents then return end
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Suspicious, source, nil, reason, metadata or {})
end

function ZeeKotaSecurity.Number(value, min, max, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return ZeeKotaUtils.Clamp(value, min, max)
end

function ZeeKotaSecurity.String(value, maxLength, fallback)
    return ZeeKotaUtils.SanitizeString(value, maxLength or 64, fallback or '')
end

function ZeeKotaSecurity.Id(value, fallback)
    return ZeeKotaUtils.SanitizeId(value, fallback)
end

function ZeeKotaSecurity.CheckDistance(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    local distance = ZeeKotaUtils.Distance(playerCoords, coords)
    return distance <= (maxDistance or Config.Meetups.InteractionDistance or 2.0), distance
end

function ZeeKotaSecurity.RequireAdmin(source)
    if ZeeKotaFramework.IsAdmin(source) then return true end
    ZeeKotaSecurity.Suspicious(source, 'admin_denied', {})
    ZeeKotaNotify.Send(source, 'notify_not_admin')
    return false
end

function ZeeKotaSecurity.RequirePhone(source)
    if ZeeKotaInventory.HasBurnerPhone(source) then return true end
    ZeeKotaNotify.Send(source, 'notify_missing_phone')
    return false
end

function ZeeKotaSecurity.ValidPayment(amount)
    amount = math.floor(tonumber(amount) or 0)
    return amount >= 0 and amount <= 5000000
end
