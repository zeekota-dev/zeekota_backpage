ZeeKotaAdminClient = ZeeKotaAdminClient or {}

function ZeeKotaAdminClient.CurrentLocationPayload(label)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return {
        id = ('custom_%s'):format(math.floor(GetGameTimer())),
        label = label or 'Custom Meetup',
        area = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped),
        enabled = true,
        risk = 20,
        supportedArchetypes = {}
    }
end

function ZeeKotaAdminClient.Teleport(location)
    if not location then return false end
    local ped = PlayerPedId()
    DoScreenFadeOut(250)
    Wait(300)
    SetEntityCoords(ped, location.x + 0.0, location.y + 0.0, location.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, location.heading or 0.0)
    Wait(250)
    DoScreenFadeIn(250)
    return true
end

function ZeeKotaAdminClient.TestSpawn(location, archetype)
    if not location then return false end
    local fakeRequest = { id = ('admin_%s'):format(GetGameTimer()) }
    local ped = ZeeKotaPeds.SpawnCustomer(fakeRequest, location, archetype or { pedModels = { 'a_m_y_stwhi_02' } })
    if ped then
        SetTimeout(12000, function()
            ZeeKotaPeds.Cleanup(fakeRequest.id)
        end)
        return true
    end
    return false
end
