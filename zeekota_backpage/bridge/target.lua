ZeeKotaTarget = ZeeKotaTarget or {}

function ZeeKotaTarget.AddCustomer(entity, label, onSelect)
    if not Config.Interaction.TargetSupport or Config.Interaction.Type ~= 'target' then return false end
    if GetResourceState(Config.Interaction.TargetResource or 'ox_target') ~= 'started' then return false end

    local ok = pcall(function()
        exports[Config.Interaction.TargetResource]:addLocalEntity(entity, {
            {
                name = 'zeekota_backpage_customer',
                label = label or ZeeKotaLocale.T('ui.speak_customer'),
                icon = 'fa-solid fa-comment',
                distance = Config.Interaction.Distance or 2.0,
                onSelect = onSelect
            }
        })
    end)

    return ok
end

function ZeeKotaTarget.RemoveCustomer(entity)
    if GetResourceState(Config.Interaction.TargetResource or 'ox_target') ~= 'started' then return end
    pcall(function()
        exports[Config.Interaction.TargetResource]:removeLocalEntity(entity, 'zeekota_backpage_customer')
    end)
end
