ZeeKotaAdmin = ZeeKotaAdmin or {}

local function overview()
    return {
        liveDealers = ZeeKotaDB.Scalar(('SELECT COUNT(*) FROM %s WHERE 1 = 0'):format(ZeeKotaDB.Table('players'))) or 0,
        activeMeetups = 0,
        pendingRequests = 0,
        configuredDrugs = #ZeeKotaConfig.GetDrugs(),
        totalCustomers = ZeeKotaDB.Scalar(('SELECT COUNT(*) FROM %s'):format(ZeeKotaDB.Table('conversations'))) or 0,
        permanentClients = ZeeKotaDB.Scalar(('SELECT COUNT(*) FROM %s'):format(ZeeKotaDB.Table('clients'))) or 0,
        recentTransactions = ZeeKotaDB.Query(('SELECT * FROM %s ORDER BY created_at DESC LIMIT 8'):format(ZeeKotaDB.Table('transactions'))),
        serverMoney = ZeeKotaDB.Scalar(('SELECT COALESCE(SUM(payment), 0) FROM %s WHERE outcome = "success"'):format(ZeeKotaDB.Table('transactions'))) or 0,
        scriptStatus = 'online'
    }
end

local function runtimeCounts(payload)
    local live, meetups, pending = 0, 0, 0
    for _, session in pairs(ZeeKotaSessions.Active) do
        if session.live then live = live + 1 end
        if session.activeMeetup then meetups = meetups + 1 end
        for _ in pairs(session.pendingRequests or {}) do pending = pending + 1 end
    end
    payload.liveDealers = live
    payload.activeMeetups = meetups
    payload.pendingRequests = pending
    return payload
end

function ZeeKotaAdmin.Dashboard(source)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    return {
        ok = true,
        config = ZeeKotaConfig.SafeClientConfig(),
        overview = runtimeCounts(overview()),
        drugs = ZeeKotaConfig.GetDrugs(),
        archetypes = ZeeKotaConfig.GetArchetypes(),
        locations = ZeeKotaConfig.GetLocations(),
        settings = {
            session = Config.Session,
            interaction = Config.Interaction,
            payment = Config.Payment,
            dispatch = Config.Dispatch,
            notifications = Config.Notifications,
            risk = Config.Risk
        },
        logs = ZeeKotaAdmin.Logs(source, 1).logs
    }
end

function ZeeKotaAdmin.Logs(source, page)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    page = math.max(1, tonumber(page) or 1)
    local limit = 40
    local offset = (page - 1) * limit
    return {
        ok = true,
        logs = ZeeKotaDB.Query(('SELECT * FROM %s ORDER BY created_at DESC LIMIT ? OFFSET ?'):format(ZeeKotaDB.Table('admin_logs')), { limit, offset })
    }
end

function ZeeKotaAdmin.SaveDrug(source, data)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    return { ok = true, drug = ZeeKotaConfig.SaveDrug(source, data or {}) }
end

function ZeeKotaAdmin.DeleteDrug(source, id)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    ZeeKotaConfig.DeleteDrug(source, id)
    return { ok = true }
end

function ZeeKotaAdmin.SaveArchetype(source, data)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    return { ok = true, archetype = ZeeKotaConfig.SaveArchetype(source, data or {}) }
end

function ZeeKotaAdmin.DeleteArchetype(source, id)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    ZeeKotaConfig.DeleteArchetype(source, id)
    return { ok = true }
end

function ZeeKotaAdmin.SaveLocation(source, data)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    return { ok = true, location = ZeeKotaConfig.SaveLocation(source, data or {}) }
end

function ZeeKotaAdmin.DeleteLocation(source, id)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    ZeeKotaConfig.DeleteLocation(source, id)
    return { ok = true }
end

function ZeeKotaAdmin.SaveSetting(source, data)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    if not data or not data.key then return { ok = false, error = 'missing_key' } end
    return { ok = ZeeKotaConfig.SaveSetting(source, data.key, data.value, data.type) }
end

function ZeeKotaAdmin.TestItem(source, item)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    item = ZeeKotaSecurity.Id(item, '')
    return { ok = true, exists = ZeeKotaInventory.ItemExists(item), item = item }
end

function ZeeKotaAdmin.SearchPlayer(source, query)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    query = ZeeKotaSecurity.String(query, 64, '')
    if query == '' then return { ok = true, players = {} } end

    local rows
    if tonumber(query) then
        local target = tonumber(query)
        local identifier = target and ZeeKotaFramework.GetIdentifier(target)
        rows = identifier and ZeeKotaDB.Query(('SELECT * FROM %s WHERE identifier = ? LIMIT 10'):format(ZeeKotaDB.Table('players')), { identifier }) or {}
    else
        rows = ZeeKotaDB.Query(('SELECT * FROM %s WHERE identifier LIKE ? OR display_name LIKE ? OR handle LIKE ? ORDER BY updated_at DESC LIMIT 20'):format(ZeeKotaDB.Table('players')), {
            '%' .. query .. '%',
            '%' .. query .. '%',
            '%' .. query .. '%'
        })
    end

    local players = {}
    for _, row in ipairs(rows) do
        players[#players + 1] = {
            identifier = row.identifier,
            displayName = row.display_name,
            handle = row.handle,
            reputation = tonumber(row.reputation) or 0,
            stats = ZeeKotaStats.BuildPayload(row.identifier),
            clients = ZeeKotaClients.GetAll(row.identifier)
        }
    end

    return { ok = true, players = players }
end

local function sourceByIdentifier(identifier)
    for _, playerSource in ipairs(GetPlayers()) do
        if ZeeKotaFramework.GetIdentifier(tonumber(playerSource)) == identifier then
            return tonumber(playerSource)
        end
    end
    return nil
end

function ZeeKotaAdmin.PlayerAction(source, data)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    data = data or {}
    local identifier = ZeeKotaSecurity.String(data.identifier, 96, '')
    local action = ZeeKotaSecurity.String(data.action, 40, '')
    if identifier == '' or action == '' then return { ok = false, error = 'missing_data' } end

    if action == 'reset_reputation' then
        ZeeKotaDB.Execute(('UPDATE %s SET reputation = ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players')), { Config.Reputation.Starting or 0, identifier })
    elseif action == 'set_reputation' then
        local value = ZeeKotaUtils.Clamp(data.value or 0, Config.Reputation.Min, Config.Reputation.Max)
        ZeeKotaDB.Execute(('UPDATE %s SET reputation = ?, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('players')), { value, identifier })
    elseif action == 'reset_clients' then
        ZeeKotaClients.Reset(identifier)
    elseif action == 'remove_client' then
        ZeeKotaClients.Remove(identifier, data.customerKey)
    elseif action == 'clear_messages' then
        ZeeKotaDB.Execute(('UPDATE %s SET deleted = 1, updated_at = UNIX_TIMESTAMP() WHERE identifier = ?'):format(ZeeKotaDB.Table('conversations')), { identifier })
    elseif action == 'reset_statistics' then
        ZeeKotaDB.Execute(([[
            UPDATE %s
            SET total_drugs_sold = 0, total_transactions = 0, total_money_made = 0,
                total_samples_given = 0, total_customers_contacted = 0, total_clients_gained = 0,
                requests_accepted = 0, requests_declined = 0, successful_sales = 0,
                failed_sales = 0, rejected_offers = 0, expired_requests = 0,
                average_sale_value = 0, largest_sale = 0, total_live_time = 0,
                drug_stats = '{}', updated_at = UNIX_TIMESTAMP()
            WHERE identifier = ?
        ]]):format(ZeeKotaDB.Table('players')), { identifier })
    elseif action == 'cancel_session' then
        local target = tonumber(data.serverId) or sourceByIdentifier(identifier)
        if target then ZeeKotaSessions.End(target, 'admin') end
    elseif action == 'cancel_meetup' then
        local target = tonumber(data.serverId) or sourceByIdentifier(identifier)
        if target then ZeeKotaSessions.CancelMeetup(target) end
    else
        return { ok = false, error = 'unknown_action' }
    end

    ZeeKotaDB.Log(ZeeKotaBackpage.LogCategory.Admin, source, identifier, action, data)
    return { ok = true }
end

function ZeeKotaAdmin.Refresh(source)
    if not ZeeKotaSecurity.RequireAdmin(source) then return { ok = false, error = 'denied' } end
    ZeeKotaConfig.Load()
    ZeeKotaSessions.SyncAllSafeConfig()
    return ZeeKotaAdmin.Dashboard(source)
end

local function openAdminCommand(source)
    if source <= 0 then return end
    if not ZeeKotaSecurity.RequireAdmin(source) then return end
    TriggerClientEvent(ZeeKotaBackpage.Events.OpenAdmin, source)
end

RegisterCommand(Config.Admin.Command, openAdminCommand, false)
for _, alias in ipairs(Config.Admin.Aliases or {}) do
    RegisterCommand(alias, openAdminCommand, false)
end
