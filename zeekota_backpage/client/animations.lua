ZeeKotaAnimations = ZeeKotaAnimations or {}

local phoneProp

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(hash), hash
end

function ZeeKotaAnimations.Play(anim, ped)
    ped = ped or PlayerPedId()
    if not anim or not anim.dict or not anim.name then return false end
    if not loadAnimDict(anim.dict) then return false end

    TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, anim.duration or -1, anim.flag or 49, 0.0, false, false, false)
    if anim.duration and anim.duration > 0 then
        Wait(anim.duration)
    end
    return true
end

function ZeeKotaAnimations.AttachPhone()
    ZeeKotaAnimations.DeletePhone()

    local ok, hash = loadModel(Config.Phone.Prop)
    if not ok then return nil end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    phoneProp = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    local offset = Config.Phone.Offset or { x = 0.0, y = 0.0, z = 0.0 }
    local rotation = Config.Phone.Rotation or { x = 0.0, y = 0.0, z = 0.0 }
    AttachEntityToEntity(phoneProp, ped, GetPedBoneIndex(ped, Config.Phone.Bone or 28422), offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return phoneProp
end

function ZeeKotaAnimations.DeletePhone()
    if phoneProp and DoesEntityExist(phoneProp) then
        DetachEntity(phoneProp, true, true)
        DeleteEntity(phoneProp)
    end
    phoneProp = nil
end

function ZeeKotaAnimations.PhoneIn()
    ZeeKotaAnimations.Play(Config.Phone.Animations.Pullout)
    ZeeKotaAnimations.AttachPhone()
    ZeeKotaAnimations.Play(Config.Phone.Animations.Hold)
end

function ZeeKotaAnimations.PhoneOut()
    ClearPedTasks(PlayerPedId())
    ZeeKotaAnimations.Play(Config.Phone.Animations.Putaway)
    ZeeKotaAnimations.DeletePhone()
    ClearPedTasks(PlayerPedId())
end

function ZeeKotaAnimations.Handoff(customerPed)
    CreateThread(function()
        ZeeKotaAnimations.Play(Config.Animations.Handoff, PlayerPedId())
    end)

    if customerPed and DoesEntityExist(customerPed) then
        CreateThread(function()
            ZeeKotaAnimations.Play(Config.Animations.Money, customerPed)
        end)
    end
end

function ZeeKotaAnimations.CustomerReact(customerPed, kind)
    if not customerPed or not DoesEntityExist(customerPed) then return end
    if kind == 'reject' then
        ZeeKotaAnimations.Play(Config.Animations.Reject, customerPed)
    elseif kind == 'inspect' then
        ZeeKotaAnimations.Play(Config.Animations.Inspect, customerPed)
    else
        ZeeKotaAnimations.Play(Config.Animations.Greeting, customerPed)
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ZeeKotaAnimations.DeletePhone()
    end
end)
