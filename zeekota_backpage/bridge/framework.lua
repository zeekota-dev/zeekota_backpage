ZeeKotaFramework = ZeeKotaFramework or {}

local frameworkObject

local function resourceStarted(name)
    return GetResourceState(name) == 'started' or GetResourceState(name) == 'starting'
end

function ZeeKotaFramework.GetObject()
    if frameworkObject then return frameworkObject end

    if Config.Framework == 'esx' or resourceStarted('es_extended') then
        local ok, object = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and object then
            frameworkObject = object
            return frameworkObject
        end
    end

    return nil
end

function ZeeKotaFramework.GetPlayer(source)
    local ESX = ZeeKotaFramework.GetObject()
    if not ESX or not source then return nil end
    return ESX.GetPlayerFromId(tonumber(source))
end

local function fallbackIdentifier(source)
    source = tonumber(source)
    if not source then return nil end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:find('license:', 1, true) then
            return identifier
        end
    end

    return GetPlayerIdentifier(source, 0)
end

function ZeeKotaFramework.GetIdentifier(source)
    local player = ZeeKotaFramework.GetPlayer(source)
    if player then
        return player.identifier or (player.getIdentifier and player.getIdentifier()) or fallbackIdentifier(source)
    end
    return fallbackIdentifier(source)
end

function ZeeKotaFramework.GetPlayerName(source)
    local player = ZeeKotaFramework.GetPlayer(source)
    if player then
        if player.getName then return player.getName() end
        if player.name then return player.name end
    end
    return GetPlayerName(source) or 'Unknown'
end

function ZeeKotaFramework.GetGroup(source)
    local player = ZeeKotaFramework.GetPlayer(source)
    if not player then return 'user' end
    if player.getGroup then return player.getGroup() end
    return player.group or 'user'
end

function ZeeKotaFramework.IsAdmin(source)
    local group = ZeeKotaFramework.GetGroup(source)
    return Config.Admin.Groups[group] == true or group == 'admin'
end

function ZeeKotaFramework.GetJob(source)
    local player = ZeeKotaFramework.GetPlayer(source)
    if not player then return nil, false end

    local job = player.getJob and player.getJob() or player.job
    if not job then return nil, false end
    return job.name, job.onDuty ~= false
end

function ZeeKotaFramework.GetPoliceCount()
    local count = 0
    for _, playerSource in ipairs(GetPlayers()) do
        local job, onDuty = ZeeKotaFramework.GetJob(tonumber(playerSource))
        if job and ZeeKotaUtils.Contains(Config.Session.PoliceJobs, job) and onDuty then
            count = count + 1
        end
    end
    return count
end

function ZeeKotaFramework.AddMoney(source, paymentType, account, item, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if paymentType == 'item' then
        return ZeeKotaInventory.AddItem(source, item, amount, nil)
    end

    local player = ZeeKotaFramework.GetPlayer(source)
    if not player then return false end

    if paymentType == 'cash' then
        if player.addMoney then
            player.addMoney(amount, reason or Config.ResourceName)
            return true
        end
        return false
    end

    if player.addAccountMoney then
        player.addAccountMoney(account or Config.Payment.Account or 'black_money', amount, reason or Config.ResourceName)
        return true
    end

    return false
end

function ZeeKotaFramework.RemoveMoney(source, paymentType, account, item, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if paymentType == 'item' then
        return ZeeKotaInventory.RemoveItem(source, item, amount, nil)
    end

    local player = ZeeKotaFramework.GetPlayer(source)
    if not player then return false end

    if paymentType == 'cash' then
        local balance = player.getMoney and player.getMoney() or 0
        if balance < amount then return false end
        player.removeMoney(amount, reason or Config.ResourceName)
        return true
    end

    if player.getAccount and player.removeAccountMoney then
        local accountData = player.getAccount(account or Config.Payment.Account or 'black_money')
        if not accountData or (accountData.money or 0) < amount then return false end
        player.removeAccountMoney(account or Config.Payment.Account or 'black_money', amount, reason or Config.ResourceName)
        return true
    end

    return false
end
