local QBCore = exports['qb-core']:GetCoreObject()

local antilag_state_key = 'has_antilag_installed'
local antilag_kit_item = 'antilag_kit'

-- ===================================================================
-- ITEM REGISTRIERUNG & INSTALLATION
-- ===================================================================
QBCore.Functions.CreateUseableItem(antilag_kit_item, function(source, item)
    TriggerClientEvent('antilag:client:attemptInstall', source)
end)

RegisterNetEvent('antilag:server:finalizeInstall', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    -- Security-Check: Sitzt der Spieler wirklich als Fahrer in diesem Auto?
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return
    end

    -- Prüfen, ob bereits installiert
    if Entity(vehicle).state[antilag_state_key] then
        TriggerClientEvent('QBCore:Notify', src, 'Dieses Fahrzeug hat bereits ein Antilag Kit installiert.', 'error')
        return
    end

    local rawPlate = GetVehicleNumberPlateText(vehicle)
    if not rawPlate then return end
    local plate = QBCore.Shared.Trim(string.upper(rawPlate))

    -- Item entfernen und Status speichern
    if Player.Functions.RemoveItem(antilag_kit_item, 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[antilag_kit_item], 'remove')

        -- State Bag setzen (wird von FiveM automatisch an alle Clients synchronisiert)
        Entity(vehicle).state:set(antilag_state_key, true, true)

        -- Permanent in die Datenbank schreiben (falls das Fahrzeug in player_vehicles existiert)
        exports.oxmysql:update('UPDATE player_vehicles SET antilag_installed = ? WHERE TRIM(UPPER(plate)) = ?', { 1, plate })

        TriggerClientEvent('QBCore:Notify', src, 'Antilag & 2-Step Kit erfolgreich installiert!', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Fehler: Antilag Kit nicht im Inventar gefunden.', 'error')
    end
end)

-- ===================================================================
-- VISUELLE UND AKUSTISCHE HANDLER
-- ===================================================================
RegisterNetEvent("flames", function(entity)
    if type(entity) ~= "number" then return end
    TriggerClientEvent("client_flames", -1, entity)
end)

RegisterNetEvent("short_flames", function(entity)
    if type(entity) ~= "number" then return end
    TriggerClientEvent("client_short_flames", -1, entity)
end)

RegisterNetEvent('sound_server:PlayWithinDistance', function(disMax, audioFile, audioVol)
    local src = source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    TriggerClientEvent('sound_client:PlayWithinDistance', -1, GetEntityCoords(ped), disMax, audioFile, audioVol)
end)