ZeeKotaConfig = ZeeKotaConfig or {}

local cache = {
    loaded = false,
    drugs = {},
    archetypes = {},
    locations = {},
    settings = {}
}

local function decodeRowData(row, fallback)
    local data = ZeeKotaUtils.SafeDecode(row.data, fallback or {})
    for key, value in pairs(row) do
        if key ~= 'data' then data[key] = value end
    end
    data.enabled = data.enabled == true or data.enabled == 1
    return data
end

local function normalizeDrug(data)
    data = ZeeKotaUtils.Merge({}, data or {})
    data.id = ZeeKotaSecurity.Id(data.id, data.item or 'drug')
    data.item = ZeeKotaSecurity.Id(data.item, data.id)
    data.label = ZeeKotaSecurity.String(data.label, 64, data.id)
    data.icon = ZeeKotaSecurity.String(data.icon, 32, 'box')
    data.enabled = data.enabled ~= false and data.enabled ~= 0
    data.minQuantity = math.max(1, math.floor(tonumber(data.minQuantity or data.min_quantity) or 1))
    data.maxQuantity = math.max(data.minQuantity, math.floor(tonumber(data.maxQuantity or data.max_quantity) or data.minQuantity))
    data.minPrice = math.max(0, math.floor(tonumber(data.minPrice or data.min_price) or 0))
    data.maxPrice = math.max(data.minPrice, math.floor(tonumber(data.maxPrice or data.max_price) or data.minPrice))
    data.sampleQuantity = math.max(1, math.floor(tonumber(data.sampleQuantity or data.sample_quantity) or 1))
    data.sampleClientChanceBonus = math.floor(tonumber(data.sampleClientChanceBonus or data.sample_bonus) or 0)
    data.extraUnitBonus = math.floor(tonumber(data.extraUnitBonus or data.extra_bonus) or 0)
    data.maxExtraUnits = math.max(0, math.floor(tonumber(data.maxExtraUnits or data.max_extra_units) or 0))
    data.reputationRequirement = math.floor(tonumber(data.reputationRequirement or data.reputation_requirement) or 0)
    data.risk = ZeeKotaUtils.Clamp(data.risk or 0, 0, 100)
    data.supportedArchetypes = type(data.supportedArchetypes) == 'table' and data.supportedArchetypes or ZeeKotaUtils.SafeDecode(data.supported_archetypes, {})
    data.weight = math.max(1, math.floor(tonumber(data.weight) or 10))
    return data
end

local function normalizeArchetype(data)
    data = ZeeKotaUtils.Merge({}, data or {})
    data.id = ZeeKotaSecurity.Id(data.id, 'archetype')
    data.label = ZeeKotaSecurity.String(data.label, 64, data.id)
    data.enabled = data.enabled ~= false and data.enabled ~= 0
    data.pedModels = type(data.pedModels) == 'table' and data.pedModels or ZeeKotaUtils.SafeDecode(data.ped_models, {})
    data.preferredDrugs = type(data.preferredDrugs) == 'table' and data.preferredDrugs or ZeeKotaUtils.SafeDecode(data.preferred_drugs, {})
    data.minQuantity = math.max(1, math.floor(tonumber(data.minQuantity or data.min_quantity) or 1))
    data.maxQuantity = math.max(data.minQuantity, math.floor(tonumber(data.maxQuantity or data.max_quantity) or data.minQuantity))
    data.budgetMultiplier = tonumber(data.budgetMultiplier or data.budget_multiplier) or 1.0
    data.loyaltyGain = math.floor(tonumber(data.loyaltyGain or data.loyalty_gain) or 0)
    data.reputationRequirement = math.floor(tonumber(data.reputationRequirement or data.reputation_requirement) or 0)
    data.patience = math.max(120, math.floor(tonumber(data.patience) or Config.Meetups.Timeout))
    data.rejectionChance = ZeeKotaUtils.Clamp(data.rejectionChance or data.rejection_chance or 0, 0, 100)
    data.policeAlertChance = ZeeKotaUtils.Clamp(data.policeAlertChance or data.police_alert_chance or 0, 0, 100)
    data.robberyChance = ZeeKotaUtils.Clamp(data.robberyChance or data.robbery_chance or 0, 0, 100)
    data.scamChance = ZeeKotaUtils.Clamp(data.scamChance or data.scam_chance or 0, 0, 100)
    data.negotiationTolerance = ZeeKotaUtils.Clamp(data.negotiationTolerance or data.negotiation_tolerance or 50, 0, 100)
    data.acquisitionModifier = math.floor(tonumber(data.acquisitionModifier or data.acquisition_modifier) or 0)
    data.repeatOrderFrequency = tonumber(data.repeatOrderFrequency or data.repeat_order_frequency) or 1.0
    data.risk = ZeeKotaUtils.Clamp(data.risk or 0, 0, 100)
    data.weight = math.max(1, math.floor(tonumber(data.weight) or 10))
    return data
end

local function normalizeLocation(data)
    data = ZeeKotaUtils.Merge({}, data or {})
    data.id = ZeeKotaSecurity.Id(data.id, 'location')
    data.label = ZeeKotaSecurity.String(data.label, 72, data.id)
    data.area = ZeeKotaSecurity.String(data.area, 48, 'Unknown')
    data.x = tonumber(data.x) or 0.0
    data.y = tonumber(data.y) or 0.0
    data.z = tonumber(data.z) or 0.0
    data.heading = tonumber(data.heading) or 0.0
    data.enabled = data.enabled ~= false and data.enabled ~= 0
    data.risk = ZeeKotaUtils.Clamp(data.risk or 0, 0, 100)
    data.minimumReputation = math.floor(tonumber(data.minimumReputation or data.minimum_reputation) or 0)
    data.supportedArchetypes = type(data.supportedArchetypes) == 'table' and data.supportedArchetypes or ZeeKotaUtils.SafeDecode(data.supported_archetypes, {})
    return data
end

function ZeeKotaConfig.Load()
    ZeeKotaDB.SeedDefaults()

    cache.drugs = {}
    cache.archetypes = {}
    cache.locations = {}
    cache.settings = ZeeKotaUtils.Merge({}, Config)

    for _, row in ipairs(ZeeKotaDB.Query(('SELECT * FROM %s ORDER BY label ASC'):format(ZeeKotaDB.Table('drugs')))) do
        cache.drugs[#cache.drugs + 1] = normalizeDrug(decodeRowData(row, {}))
    end

    for _, row in ipairs(ZeeKotaDB.Query(('SELECT * FROM %s ORDER BY label ASC'):format(ZeeKotaDB.Table('archetypes')))) do
        cache.archetypes[#cache.archetypes + 1] = normalizeArchetype(decodeRowData(row, {}))
    end

    for _, row in ipairs(ZeeKotaDB.Query(('SELECT * FROM %s ORDER BY area ASC, label ASC'):format(ZeeKotaDB.Table('locations')))) do
        cache.locations[#cache.locations + 1] = normalizeLocation(decodeRowData(row, {}))
    end

    for _, row in ipairs(ZeeKotaDB.Query(('SELECT `key`, `value`, `type` FROM %s'):format(ZeeKotaDB.Table('settings')))) do
        if row.key ~= 'database_version' then
            local value = row.value
            if row.type == 'json' then value = ZeeKotaUtils.SafeDecode(row.value, nil) end
            if row.type == 'number' then value = tonumber(row.value) or 0 end
            if row.type == 'boolean' then value = row.value == 'true' or row.value == '1' end
            cache.settings[row.key] = value

            local sectionMap = {
                session = 'Session',
                interaction = 'Interaction',
                payment = 'Payment',
                dispatch = 'Dispatch',
                notifications = 'Notifications',
                risk = 'Risk'
            }
            local configSection = sectionMap[row.key]
            if configSection and type(value) == 'table' and type(Config[configSection]) == 'table' then
                Config[configSection] = ZeeKotaUtils.Merge(Config[configSection], value)
            end
        end
    end

    cache.loaded = true
    return cache
end

function ZeeKotaConfig.Ensure()
    if not cache.loaded then ZeeKotaConfig.Load() end
    return cache
end

function ZeeKotaConfig.SafeClientConfig()
    ZeeKotaConfig.Ensure()
    return {
        interaction = Config.Interaction,
        phone = {
            closeControls = Config.Phone.CloseControls,
            disableControls = Config.Phone.DisableControls
        },
        audio = Config.Audio,
        loyaltyTiers = Config.Loyalty.Tiers,
        revealExactChance = Config.ClientAcquisition.RevealExactChance,
        locale = ZeeKotaLocale.Get(Config.Locale).ui or {},
        drugs = cache.drugs
    }
end

function ZeeKotaConfig.GetDrugs()
    ZeeKotaConfig.Ensure()
    return cache.drugs
end

function ZeeKotaConfig.GetDrug(idOrItem)
    ZeeKotaConfig.Ensure()
    for _, drug in ipairs(cache.drugs) do
        if drug.id == idOrItem or drug.item == idOrItem then return drug end
    end
    return nil
end

function ZeeKotaConfig.GetArchetypes()
    ZeeKotaConfig.Ensure()
    return cache.archetypes
end

function ZeeKotaConfig.GetArchetype(id)
    ZeeKotaConfig.Ensure()
    return ZeeKotaUtils.FindById(cache.archetypes, id)
end

function ZeeKotaConfig.GetLocations()
    ZeeKotaConfig.Ensure()
    return cache.locations
end

function ZeeKotaConfig.SaveDrug(source, data)
    data = normalizeDrug(data)
    ZeeKotaDB.Execute(([[
        INSERT INTO %s
            (id, item, label, icon, enabled, min_quantity, max_quantity, min_price, max_price,
             sample_quantity, sample_bonus, extra_bonus, max_extra_units, reputation_requirement,
             risk, supported_archetypes, data, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE
            item = VALUES(item), label = VALUES(label), icon = VALUES(icon), enabled = VALUES(enabled),
            min_quantity = VALUES(min_quantity), max_quantity = VALUES(max_quantity),
            min_price = VALUES(min_price), max_price = VALUES(max_price),
            sample_quantity = VALUES(sample_quantity), sample_bonus = VALUES(sample_bonus),
            extra_bonus = VALUES(extra_bonus), max_extra_units = VALUES(max_extra_units),
            reputation_requirement = VALUES(reputation_requirement), risk = VALUES(risk),
            supported_archetypes = VALUES(supported_archetypes), data = VALUES(data), updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('drugs')), {
        data.id, data.item, data.label, data.icon, data.enabled and 1 or 0,
        data.minQuantity, data.maxQuantity, data.minPrice, data.maxPrice,
        data.sampleQuantity, data.sampleClientChanceBonus, data.extraUnitBonus,
        data.maxExtraUnits, data.reputationRequirement, data.risk,
        ZeeKotaUtils.SafeEncode(data.supportedArchetypes), ZeeKotaUtils.SafeEncode(data)
    })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'save_drug', data)
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
    return data
end

function ZeeKotaConfig.DeleteDrug(source, id)
    id = ZeeKotaSecurity.Id(id)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE id = ?'):format(ZeeKotaDB.Table('drugs')), { id })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'delete_drug', { id = id })
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
end

function ZeeKotaConfig.SaveArchetype(source, data)
    data = normalizeArchetype(data)
    ZeeKotaDB.Execute(([[
        INSERT INTO %s
            (id, label, enabled, ped_models, preferred_drugs, data, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE
            label = VALUES(label), enabled = VALUES(enabled), ped_models = VALUES(ped_models),
            preferred_drugs = VALUES(preferred_drugs), data = VALUES(data), updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('archetypes')), {
        data.id, data.label, data.enabled and 1 or 0,
        ZeeKotaUtils.SafeEncode(data.pedModels), ZeeKotaUtils.SafeEncode(data.preferredDrugs),
        ZeeKotaUtils.SafeEncode(data)
    })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'save_archetype', data)
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
    return data
end

function ZeeKotaConfig.DeleteArchetype(source, id)
    id = ZeeKotaSecurity.Id(id)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE id = ?'):format(ZeeKotaDB.Table('archetypes')), { id })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'delete_archetype', { id = id })
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
end

function ZeeKotaConfig.SaveLocation(source, data)
    data = normalizeLocation(data)
    ZeeKotaDB.Execute(([[
        INSERT INTO %s
            (id, label, area, x, y, z, heading, enabled, risk, data, created_at, updated_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE
            label = VALUES(label), area = VALUES(area), x = VALUES(x), y = VALUES(y), z = VALUES(z),
            heading = VALUES(heading), enabled = VALUES(enabled), risk = VALUES(risk),
            data = VALUES(data), updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('locations')), {
        data.id, data.label, data.area, data.x, data.y, data.z, data.heading, data.enabled and 1 or 0, data.risk,
        ZeeKotaUtils.SafeEncode(data)
    })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'save_location', data)
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
    return data
end

function ZeeKotaConfig.DeleteLocation(source, id)
    id = ZeeKotaSecurity.Id(id)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE id = ?'):format(ZeeKotaDB.Table('locations')), { id })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'delete_location', { id = id })
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
end

function ZeeKotaConfig.SaveSetting(source, key, value, valueType)
    key = ZeeKotaSecurity.String(key, 80, '')
    if key == '' or key == 'database_version' then return false end
    valueType = valueType or (type(value) == 'table' and 'json' or type(value))
    if valueType == 'json' then value = ZeeKotaUtils.SafeEncode(value) else value = tostring(value) end

    ZeeKotaDB.Execute(([[
        INSERT INTO %s (`key`, `value`, `type`, updated_at)
        VALUES (?, ?, ?, UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE value = VALUES(value), type = VALUES(type), updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('settings')), { key, value, valueType })
    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Config, source, nil, 'save_setting', { key = key, type = valueType })
    ZeeKotaConfig.Load()
    if ZeeKotaSessions and ZeeKotaSessions.SyncAllSafeConfig then ZeeKotaSessions.SyncAllSafeConfig() end
    return true
end
