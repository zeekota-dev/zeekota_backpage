ZeeKotaInteractions = ZeeKotaInteractions or {
    promptVisible = false,
    interactionOpen = false
}

function ZeeKotaInteractions.ShowPrompt(text)
    if ZeeKotaInteractions.promptVisible and ZeeKotaInteractions.promptText == text then return end
    ZeeKotaInteractions.promptVisible = true
    ZeeKotaInteractions.promptText = text
    SendNUIMessage({
        action = 'showPrompt',
        payload = {
            key = Config.Interaction.KeyLabel or 'E',
            text = text or ZeeKotaLocale.T('ui.speak_customer')
        }
    })
end

function ZeeKotaInteractions.HidePrompt()
    if not ZeeKotaInteractions.promptVisible then return end
    ZeeKotaInteractions.promptVisible = false
    ZeeKotaInteractions.promptText = nil
    SendNUIMessage({ action = 'hidePrompt' })
end

function ZeeKotaInteractions.OpenInteraction()
    local payload = ZeeKotaMeetups.GetInteractionPayload()
    if not payload then return end

    ZeeKotaInteractions.interactionOpen = true
    ZeeKotaInteractions.HidePrompt()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInteraction',
        payload = payload
    })
end

function ZeeKotaInteractions.CloseInteraction()
    ZeeKotaInteractions.interactionOpen = false
    if not (ZeeKotaPhone and ZeeKotaPhone.IsOpen()) then
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'closeInteraction' })
end

CreateThread(function()
    while true do
        local wait = 800
        local active = ZeeKotaMeetups.GetActive()

        if active and active.ped and DoesEntityExist(active.ped) and not ZeeKotaInteractions.interactionOpen and not (ZeeKotaPhone and ZeeKotaPhone.IsOpen()) then
            local playerPed = PlayerPedId()
            local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(active.ped))

            if distance <= (Config.Interaction.PromptDistance or 2.7) then
                wait = 0
                ZeeKotaInteractions.ShowPrompt(Config.Interaction.Text)
                if distance <= (Config.Interaction.Distance or 2.0) and IsControlJustPressed(0, Config.Interaction.Key or 38) then
                    ZeeKotaInteractions.OpenInteraction()
                end
            else
                ZeeKotaInteractions.HidePrompt()
                wait = distance < 12.0 and 200 or 900
            end
        else
            ZeeKotaInteractions.HidePrompt()
        end

        Wait(wait)
    end
end)
