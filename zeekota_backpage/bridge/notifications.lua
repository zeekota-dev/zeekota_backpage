ZeeKotaNotify = ZeeKotaNotify or {}

local function normalize(data, replacements)
    if type(data) == 'string' then
        data = {
            title = ZeeKotaLocale.T('resource_name'),
            description = ZeeKotaLocale.T(data, replacements),
            type = 'inform'
        }
    end

    data = data or {}
    data.title = data.title or ZeeKotaLocale.T('resource_name')
    data.description = data.description or data.message or ''
    data.type = data.type or 'inform'
    data.duration = data.duration or Config.Notifications.Duration
    data.position = data.position or Config.Notifications.Position
    return data
end

function ZeeKotaNotify.Send(target, data, replacements)
    data = normalize(data, replacements)

    if IsDuplicityVersion() then
        TriggerClientEvent(ZeeKotaBackpage.Events.Notify, target, data)
        return
    end

    if Config.Notifications.Provider == 'custom' and Config.Notifications.CustomEvent ~= '' then
        TriggerEvent(Config.Notifications.CustomEvent, data)
        return
    end

    if Config.Notifications.Provider == 'ox_lib' and GetResourceState('ox_lib') == 'started' and lib and lib.notify then
        lib.notify({
            title = data.title,
            description = data.description,
            type = data.type,
            duration = data.duration,
            position = data.position
        })
        return
    end

    local ESX = ZeeKotaFramework.GetObject()
    if Config.Notifications.Provider == 'esx' and ESX and ESX.ShowNotification then
        ESX.ShowNotification(data.description)
        return
    end

    SendNUIMessage({
        action = 'toast',
        payload = data
    })
end

RegisterNetEvent(ZeeKotaBackpage.Events.Notify, function(data)
    ZeeKotaNotify.Send(nil, data)
end)
