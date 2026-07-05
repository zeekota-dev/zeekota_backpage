ZeeKotaInventory = ZeeKotaInventory or {}

local function ox()
    if GetResourceState(Config.Inventory or 'ox_inventory') ~= 'started' then return nil end
    return exports[Config.Inventory or 'ox_inventory']
end

function ZeeKotaInventory.GetItemCount(source, item)
    if not item or item == '' then return 0 end
    local inventory = ox()
    if not inventory then return 0 end

    local ok, count = pcall(function()
        return inventory:Search(source, 'count', item)
    end)

    return ok and tonumber(count) or 0
end

function ZeeKotaInventory.HasItem(source, item, amount)
    return ZeeKotaInventory.GetItemCount(source, item) >= math.max(1, tonumber(amount) or 1)
end

function ZeeKotaInventory.HasBurnerPhone(source)
    return ZeeKotaInventory.HasItem(source, Config.RequiredItem, 1)
end

function ZeeKotaInventory.CanCarryItem(source, item, amount, metadata)
    local inventory = ox()
    if not inventory then return false end

    local ok, result = pcall(function()
        return inventory:CanCarryItem(source, item, amount, metadata)
    end)

    return ok and result == true
end

function ZeeKotaInventory.AddItem(source, item, amount, metadata)
    if not item or item == '' or (tonumber(amount) or 0) <= 0 then return true end
    local inventory = ox()
    if not inventory then return false end

    local ok, result = pcall(function()
        return inventory:AddItem(source, item, amount, metadata)
    end)

    return ok and result ~= false
end

function ZeeKotaInventory.RemoveItem(source, item, amount, metadata)
    if not item or item == '' or (tonumber(amount) or 0) <= 0 then return true end
    local inventory = ox()
    if not inventory then return false end

    if ZeeKotaInventory.GetItemCount(source, item) < amount then return false end

    local ok, result = pcall(function()
        return inventory:RemoveItem(source, item, amount, metadata)
    end)

    return ok and result ~= false
end

function ZeeKotaInventory.GetItemData(item)
    if not item or item == '' then return nil end
    local inventory = ox()
    if not inventory then return nil end

    local ok, data = pcall(function()
        if inventory.Items then
            local items = inventory:Items()
            return items and items[item]
        end
        return nil
    end)

    return ok and data or nil
end

function ZeeKotaInventory.GetItemLabel(item, fallback)
    local data = ZeeKotaInventory.GetItemData(item)
    if type(data) == 'table' and data.label and data.label ~= '' then
        return data.label
    end
    return fallback or item
end

function ZeeKotaInventory.ItemExists(item)
    return ZeeKotaInventory.GetItemData(item) ~= nil
end

function ZeeKotaInventory.GetAvailableConfiguredDrugs(source, drugs)
    local available = {}
    for _, drug in ipairs(drugs or {}) do
        if drug.enabled ~= false and ZeeKotaInventory.HasItem(source, drug.item, 1) then
            available[#available + 1] = drug
        end
    end
    return available
end

function ZeeKotaInventory.RegisterBurnerPhoneUse(handler)
    if not IsDuplicityVersion() then return false end

    local registered = false
    local inventory = ox()
    if inventory then
        local ok = pcall(function()
            inventory:RegisterUsableItem(Config.RequiredItem, function(source, item)
                handler(source, item)
            end)
        end)
        registered = ok or registered
    end

    local ESX = ZeeKotaFramework.GetObject()
    if ESX and ESX.RegisterUsableItem then
        ESX.RegisterUsableItem(Config.RequiredItem, function(source, item)
            handler(source, item)
        end)
        registered = true
    end

    return registered
end

exports('useBurnerPhone', function(event, item, inventory, slot, data)
    if not IsDuplicityVersion() then
        TriggerEvent(ZeeKotaBackpage.Events.OpenPhoneFromItem)
        return
    end

    local source = source
    if type(inventory) == 'table' then
        source = inventory.id or inventory.source or source
    elseif tonumber(inventory) then
        source = tonumber(inventory)
    end

    if source and (event == nil or event == 'usingItem' or event == 'usedItem') then
        TriggerEvent('zeekota_backpage:server:useBurnerPhone', tonumber(source), slot, data)
    end
end)
