ZeeKotaDispatch = ZeeKotaDispatch or {}

local function shouldAlert(request, location)
    if not Config.Risk.EnablePoliceAlerts then return false end
    if ZeeKotaFramework.GetPoliceCount() < (Config.Dispatch.MinimumPolice or 0) then return false end

    local chance = tonumber(Config.Dispatch.AlertChance) or 0
    if request and request.drug and request.drug.risk then
        chance = chance + math.floor((tonumber(request.drug.risk) or 0) * 0.2)
    end
    if request and request.archetype and request.archetype.policeAlertChance then
        chance = chance + tonumber(request.archetype.policeAlertChance)
    end
    if location and location.risk then
        chance = chance + math.floor((tonumber(location.risk) or 0) * 0.15)
    end

    return math.random(100) <= ZeeKotaUtils.Clamp(chance, 0, 100)
end

function ZeeKotaDispatch.Alert(source, request, location, reason)
    if Config.Dispatch.Provider == 'disabled' or not shouldAlert(request, location) then
        return false
    end

    local coords = location and vector3(location.x, location.y, location.z) or GetEntityCoords(GetPlayerPed(source))
    local dispatchCoords = coords
    if not Config.Dispatch.ExposeExactCoords then
        local angle = math.random() * math.pi * 2.0
        local distance = math.random(25, math.floor(Config.Dispatch.BlipRadius or 85.0))
        dispatchCoords = vector3(coords.x + math.cos(angle) * distance, coords.y + math.sin(angle) * distance, coords.z)
    end

    local payload = {
        coords = dispatchCoords,
        message = Config.Dispatch.Message,
        code = Config.Dispatch.Code,
        radius = Config.Dispatch.BlipRadius,
        duration = Config.Dispatch.BlipDuration,
        reason = reason or 'deal',
        drug = request and request.drug and request.drug.label or nil
    }

    CreateThread(function()
        Wait(ZeeKotaUtils.RandomBetween(Config.Dispatch.AlertDelay.min, Config.Dispatch.AlertDelay.max) * 1000)

        if Config.Dispatch.Provider == 'custom' and Config.Dispatch.CustomEvent ~= '' then
            TriggerEvent(Config.Dispatch.CustomEvent, payload)
        elseif Config.Dispatch.Provider == 'cd_dispatch' and GetResourceState('cd_dispatch') == 'started' then
            TriggerClientEvent('cd_dispatch:AddNotification', -1, {
                job_table = Config.Dispatch.PoliceJobs,
                coords = payload.coords,
                title = payload.code,
                message = payload.message,
                flash = 0,
                unique_id = tostring(math.random(100000, 999999)),
                sound = 1,
                blip = {
                    sprite = 51,
                    scale = 1.0,
                    colour = 3,
                    flashes = false,
                    text = payload.code,
                    time = payload.duration,
                    radius = payload.radius
                }
            })
        elseif Config.Dispatch.Provider == 'qs-dispatch' and GetResourceState('qs-dispatch') == 'started' then
            TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
                job = Config.Dispatch.PoliceJobs,
                callLocation = payload.coords,
                callCode = { code = payload.code, snippet = payload.message },
                message = payload.message,
                blip = { sprite = 51, scale = 1.0, colour = 3, radius = payload.radius, time = payload.duration }
            })
        elseif Config.Dispatch.Provider == 'ps-dispatch' and GetResourceState('ps-dispatch') == 'started' then
            TriggerEvent('ps-dispatch:server:notify', {
                dispatchcodename = 'zeekotabackpage',
                dispatchCode = payload.code,
                firstStreet = payload.message,
                coords = payload.coords,
                radius = payload.radius,
                priority = 2,
                origin = payload.coords,
                job = Config.Dispatch.PoliceJobs
            })
        else
            for _, playerSource in ipairs(GetPlayers()) do
                local job = ZeeKotaFramework.GetJob(tonumber(playerSource))
                if job and ZeeKotaUtils.Contains(Config.Dispatch.PoliceJobs, job) then
                    TriggerClientEvent(ZeeKotaBackpage.Events.Notify, tonumber(playerSource), {
                        title = payload.code,
                        description = payload.message,
                        type = 'warning'
                    })
                end
            end
        end
    end)

    return true
end
