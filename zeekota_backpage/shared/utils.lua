ZeeKotaUtils = ZeeKotaUtils or {}

function ZeeKotaUtils.Now()
    return os.time()
end

function ZeeKotaUtils.Clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

function ZeeKotaUtils.Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function ZeeKotaUtils.Contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then return true end
    end
    return false
end

function ZeeKotaUtils.TableHasKey(map, key)
    return type(map) == 'table' and map[key] ~= nil
end

function ZeeKotaUtils.Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = ZeeKotaUtils.Copy(v)
    end
    return out
end

function ZeeKotaUtils.Merge(base, override)
    local out = ZeeKotaUtils.Copy(base or {})
    for key, value in pairs(override or {}) do
        if type(value) == 'table' and type(out[key]) == 'table' then
            out[key] = ZeeKotaUtils.Merge(out[key], value)
        else
            out[key] = ZeeKotaUtils.Copy(value)
        end
    end
    return out
end

function ZeeKotaUtils.SafeDecode(value, fallback)
    if type(value) == 'table' then return value end
    if not value or value == '' then return fallback or {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded then return decoded end
    return fallback or {}
end

function ZeeKotaUtils.SafeEncode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

function ZeeKotaUtils.MakeId(prefix)
    local left = math.random(100000, 999999)
    local right = math.random(100000, 999999)
    return ('%s_%s_%s'):format(prefix or 'id', left, right)
end

function ZeeKotaUtils.SanitizeString(value, maxLength, fallback)
    value = tostring(value or fallback or '')
    value = value:gsub('[%c]', ''):gsub('^%s*(.-)%s*$', '%1')
    maxLength = tonumber(maxLength) or 64
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

function ZeeKotaUtils.SanitizeId(value, fallback)
    value = tostring(value or fallback or ''):lower()
    value = value:gsub('[^%w_%-]', '_')
    if value == '' then value = fallback or ZeeKotaUtils.MakeId('entry') end
    return value
end

function ZeeKotaUtils.RandomBetween(min, max)
    min = math.floor(tonumber(min) or 0)
    max = math.floor(tonumber(max) or min)
    if max < min then max = min end
    return math.random(min, max)
end

function ZeeKotaUtils.RandomFloat()
    return math.random(0, 10000) / 10000
end

function ZeeKotaUtils.Weighted(list, weightKey)
    local total = 0
    weightKey = weightKey or 'weight'
    for _, entry in ipairs(list or {}) do
        if entry.enabled ~= false then
            total = total + math.max(0, tonumber(entry[weightKey]) or 1)
        end
    end

    if total <= 0 then return nil end

    local roll = ZeeKotaUtils.RandomFloat() * total
    local cursor = 0
    for _, entry in ipairs(list or {}) do
        if entry.enabled ~= false then
            cursor = cursor + math.max(0, tonumber(entry[weightKey]) or 1)
            if roll <= cursor then return entry end
        end
    end

    return list and list[#list] or nil
end

function ZeeKotaUtils.FindById(list, id)
    for _, entry in ipairs(list or {}) do
        if tostring(entry.id) == tostring(id) then return entry end
    end
    return nil
end

function ZeeKotaUtils.Distance(a, b)
    if not a or not b then return 999999.0 end
    local ax, ay, az = a.x or a[1] or 0.0, a.y or a[2] or 0.0, a.z or a[3] or 0.0
    local bx, by, bz = b.x or b[1] or 0.0, b.y or b[2] or 0.0, b.z or b[3] or 0.0
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function ZeeKotaUtils.FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return ('%02d:%02d'):format(mins, secs)
end

function ZeeKotaUtils.CalculateTier(loyalty, tiers)
    local selected = tiers and tiers[1] or nil
    for _, tier in ipairs(tiers or {}) do
        if (tonumber(loyalty) or 0) >= (tonumber(tier.loyalty) or 0) then
            selected = tier
        end
    end
    return selected
end
