ZeeKotaDB = ZeeKotaDB or {}

local prefix = Config.Database.Prefix or 'zeekota_backpage'

function ZeeKotaDB.Table(name)
    return ('%s_%s'):format(prefix, name)
end

local function mysqlReady()
    return MySQL and MySQL.query and MySQL.query.await
end

function ZeeKotaDB.Query(query, params)
    if not mysqlReady() then
        print(('[%s] oxmysql is not ready; query skipped.'):format(Config.ResourceName))
        return {}
    end

    local ok, result = pcall(function()
        return MySQL.query.await(query, params or {})
    end)

    if not ok then
        print(('[%s] Database query failed: %s'):format(Config.ResourceName, result))
        return {}
    end

    return result or {}
end

function ZeeKotaDB.Single(query, params)
    local rows = ZeeKotaDB.Query(query, params)
    return rows and rows[1] or nil
end

function ZeeKotaDB.Scalar(query, params)
    if not mysqlReady() then return nil end

    local ok, result = pcall(function()
        return MySQL.scalar.await(query, params or {})
    end)

    if ok then return result end
    local row = ZeeKotaDB.Single(query, params)
    if not row then return nil end
    for _, value in pairs(row) do return value end
    return nil
end

function ZeeKotaDB.Execute(query, params)
    if not mysqlReady() then return 0 end

    local ok, result = pcall(function()
        return MySQL.update.await(query, params or {})
    end)

    if not ok then
        print(('[%s] Database update failed: %s'):format(Config.ResourceName, result))
        return 0
    end

    return result or 0
end

function ZeeKotaDB.Insert(query, params)
    if not mysqlReady() then return nil end

    local ok, result = pcall(function()
        return MySQL.insert.await(query, params or {})
    end)

    if not ok then
        print(('[%s] Database insert failed: %s'):format(Config.ResourceName, result))
        return nil
    end

    return result
end

function ZeeKotaDB.Transaction(queries)
    if not mysqlReady() then return false end
    if not MySQL.transaction or not MySQL.transaction.await then return false end

    local ok, result = pcall(function()
        return MySQL.transaction.await(queries)
    end)

    return ok and result == true
end

function ZeeKotaDB.EnsureSettingsVersion()
    ZeeKotaDB.Execute(([[
        INSERT INTO %s (`key`, `value`, `type`, updated_at)
        VALUES ('database_version', ?, 'number', UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE value = VALUES(value), updated_at = UNIX_TIMESTAMP()
    ]]):format(ZeeKotaDB.Table('settings')), { tostring(Config.Database.Version or 1) })
end

function ZeeKotaDB.SeedDefaults()
    if Config.Database.SeedDefaults == false then return end

    ZeeKotaDB.EnsureSettingsVersion()

    for _, drug in ipairs(Config.Drugs or {}) do
        ZeeKotaDB.Execute(([[
            INSERT INTO %s
                (id, item, label, icon, enabled, min_quantity, max_quantity, min_price, max_price,
                 sample_quantity, sample_bonus, extra_bonus, max_extra_units, reputation_requirement,
                 risk, supported_archetypes, data, created_at, updated_at)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
            ON DUPLICATE KEY UPDATE updated_at = updated_at
        ]]):format(ZeeKotaDB.Table('drugs')), {
            drug.id,
            drug.item,
            drug.label,
            drug.icon or '',
            drug.enabled ~= false and 1 or 0,
            drug.minQuantity or 1,
            drug.maxQuantity or 1,
            drug.minPrice or 0,
            drug.maxPrice or 0,
            drug.sampleQuantity or 1,
            drug.sampleClientChanceBonus or 0,
            drug.extraUnitBonus or 0,
            drug.maxExtraUnits or 0,
            drug.reputationRequirement or 0,
            drug.risk or 0,
            ZeeKotaUtils.SafeEncode(drug.supportedArchetypes or {}),
            ZeeKotaUtils.SafeEncode(drug)
        })
    end

    for _, archetype in ipairs(Config.CustomerArchetypes or {}) do
        ZeeKotaDB.Execute(([[
            INSERT INTO %s
                (id, label, enabled, ped_models, preferred_drugs, data, created_at, updated_at)
            VALUES
                (?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
            ON DUPLICATE KEY UPDATE updated_at = updated_at
        ]]):format(ZeeKotaDB.Table('archetypes')), {
            archetype.id,
            archetype.label,
            archetype.enabled ~= false and 1 or 0,
            ZeeKotaUtils.SafeEncode(archetype.pedModels or {}),
            ZeeKotaUtils.SafeEncode(archetype.preferredDrugs or {}),
            ZeeKotaUtils.SafeEncode(archetype)
        })
    end

    for _, location in ipairs(Config.Meetups.Locations or {}) do
        ZeeKotaDB.Execute(([[
            INSERT INTO %s
                (id, label, area, x, y, z, heading, enabled, risk, data, created_at, updated_at)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())
            ON DUPLICATE KEY UPDATE updated_at = updated_at
        ]]):format(ZeeKotaDB.Table('locations')), {
            location.id,
            location.label,
            location.area or '',
            location.x,
            location.y,
            location.z,
            location.heading or 0.0,
            location.enabled ~= false and 1 or 0,
            location.risk or 0,
            ZeeKotaUtils.SafeEncode(location)
        })
    end
end

function ZeeKotaDB.Log(category, source, identifier, action, metadata)
    if not Config.Logging.Console and not Config.Logging.DiscordWebhook then
        return
    end

    identifier = identifier or (source and ZeeKotaFramework.GetIdentifier(source)) or 'system'
    local playerName = source and ZeeKotaFramework.GetPlayerName(source) or 'System'
    local payload = metadata or {}

    if Config.Logging.Console then
        print(('[%s] [%s] %s %s %s'):format(Config.ResourceName, category or 'log', playerName, action or '', ZeeKotaUtils.SafeEncode(payload)))
    end

    ZeeKotaDB.Execute(([[
        INSERT INTO %s
            (category, action, identifier, player_name, server_id, metadata, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
    ]]):format(ZeeKotaDB.Table('admin_logs')), {
        category or 'log',
        action or '',
        identifier,
        playerName,
        source or 0,
        ZeeKotaUtils.SafeEncode(payload)
    })

    if Config.Logging.DiscordWebhook and Config.Logging.DiscordWebhook ~= '' then
        PerformHttpRequest(Config.Logging.DiscordWebhook, function() end, 'POST', json.encode({
            username = 'ZeeKota Backpage',
            embeds = {
                {
                    title = category or 'Log',
                    description = action or 'Event',
                    color = 3447039,
                    fields = {
                        { name = 'Player', value = playerName, inline = true },
                        { name = 'Server ID', value = tostring(source or 0), inline = true },
                        { name = 'Identifier', value = Config.Logging.IncludeIdentifiers and tostring(identifier) or 'hidden', inline = false },
                        { name = 'Metadata', value = ('```json\n%s\n```'):format(ZeeKotaUtils.SafeEncode(payload):sub(1, 900)), inline = false }
                    },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
                }
            }
        }), { ['Content-Type'] = 'application/json' })
    end
end

function ZeeKotaDB.Prune()
    local retention = math.max(1, tonumber(Config.Database.MessageRetentionDays) or 30)
    local cutoff = os.time() - (retention * 86400)
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE deleted = 1 AND updated_at < ?'):format(ZeeKotaDB.Table('conversations')), { cutoff })
    ZeeKotaDB.Execute(('DELETE FROM %s WHERE created_at < ?'):format(ZeeKotaDB.Table('messages')), { cutoff })
end
