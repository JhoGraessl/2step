local QBCore = exports['qb-core']:GetCoreObject()

local isAntiLagEnabled = false
local originalLowSpeedLoss = nil
local lastVeh = 0
local last_2step_active_in_cycle = false
local lcChargeStart = 0
local lastBackfireTime = 0

-- NUI State Tracking (verhindert NUI-Spam im Wait(0) Loop)
local isNuiVisible = false
local lastNuiState = ""

local antilag_state_key = 'has_antilag_installed'
local reverse = 0

-- FX-Konfiguration
local exhausts = { "exhaust", "exhaust_2", "exhaust_3", "exhaust_4" }
local fxName = "veh_nitrous"
local fxGroup = "veh_xs_vehicle_mods"
local fxName_short = "veh_backfire"
local fxGroup_short = "core"

local function startGripResetTimer(veh, originalLoss)
    local vehNetId = VehToNet(veh)
    CreateThread(function()
        Wait(1500)
        if NetworkDoesEntityExistWithNetworkId(vehNetId) then
            local currentVeh = NetToVeh(vehNetId)
            if DoesEntityExist(currentVeh) and GetVehicleHandlingFloat(currentVeh, 'CHandlingData', 'fLowSpeedTractionLossMult') ~= originalLoss then
                SetVehicleHandlingFloat(currentVeh, 'CHandlingData', 'fLowSpeedTractionLossMult', originalLoss)
            end
        end
    end)
end

local function resetVehicleGrip(veh)
    if veh ~= 0 and DoesEntityExist(veh) and originalLowSpeedLoss ~= nil then
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fLowSpeedTractionLossMult', originalLowSpeedLoss)
    end
    originalLowSpeedLoss = nil
    lcChargeStart = 0
    last_2step_active_in_cycle = false
end

local function updateNuiVisibility(show)
    if isNuiVisible ~= show then
        isNuiVisible = show
        SendNUIMessage({
            transactionType = 'toggleNUI',
            display = show,
            isEnabled = isAntiLagEnabled
        })
        if not show then
            lastNuiState = ""
        end
    end
end

RegisterCommand("antilag", function()
    isAntiLagEnabled = not isAntiLagEnabled
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
end, false)

-- ===================================================================
-- HAUPT-THREAD
-- ===================================================================
CreateThread(function()
    while true do
        local sleep = 1000
        local player = PlayerPedId()
        local veh = GetVehiclePedIsIn(player, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == player then
            local is_installed = Entity(veh).state[antilag_state_key] or false

            if is_installed then
                sleep = 0
                lastVeh = veh
                updateNuiVisibility(true)

                local currentTime = GetGameTimer()
                local RPM = GetVehicleCurrentRpm(veh)
                local gear = GetVehicleCurrentGear(veh)
                local is_2step_active_in_cycle = false

                if originalLowSpeedLoss == nil then
                    originalLowSpeedLoss = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fLowSpeedTractionLossMult')
                end

                local shiftPressed = IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21)
                local gasOrBrakePressed = IsControlPressed(0, 71) or IsControlPressed(0, 72)

                if gear ~= reverse and not IsEntityInAir(veh) then
                    -- *******************************************
                    -- ** LAUNCH CONTROL (2-STEP) LOGIK **
                    -- *******************************************
                    if shiftPressed and gasOrBrakePressed then
                        is_2step_active_in_cycle = true

                        if lcChargeStart == 0 then
                            lcChargeStart = currentTime
                        end

                        SetVehicleHandbrake(veh, true)

                        if originalLowSpeedLoss ~= nil and GetVehicleHandlingFloat(veh, 'CHandlingData', 'fLowSpeedTractionLossMult') ~= originalLowSpeedLoss then
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fLowSpeedTractionLossMult', originalLowSpeedLoss)
                        end

                        SetVehicleTurboPressure(veh, 25.0)
                        SetVehicleCurrentRpm(veh, Config.LaunchRPM / 8000.0)

                        if currentTime - lastBackfireTime >= math.random(60, 140) then
                            lastBackfireTime = currentTime
                            TriggerServerEvent("short_flames", VehToNet(veh))
                            TriggerServerEvent("sound_server:PlayWithinDistance", 25.0, tostring(math.random(12, 18)), 0.9)
                        end

                    -- *******************************************
                    -- ** NORMALE ANTILAG LOGIK **
                    -- *******************************************
                    elseif isAntiLagEnabled and not IsControlPressed(0, 71) and RPM > Config.RPM then
                        lcChargeStart = 0

                        if currentTime - lastBackfireTime >= math.random(40, Config.explosionSpeed) then
                            lastBackfireTime = currentTime
                            TriggerServerEvent("short_flames", VehToNet(veh))
                            TriggerServerEvent("sound_server:PlayWithinDistance", 25.0, tostring(math.random(12, 18)), 0.9)

                            SetTimeout(90, function()
                                if DoesEntityExist(veh) then
                                    TriggerServerEvent("flames", VehToNet(veh))
                                    TriggerServerEvent("sound_server:PlayWithinDistance", 25.0, tostring(8), 0.9)
                                end
                            end)
                            SetVehicleTurboPressure(veh, 25.0)
                        end
                    end

                    -- *******************************************
                    -- ** VERARBEITUNG BEIM LOSLASSEN DER LC **
                    -- *******************************************
                    if not is_2step_active_in_cycle and last_2step_active_in_cycle then
                        local chargeTime = currentTime - lcChargeStart
                        if chargeTime >= 2000 and originalLowSpeedLoss ~= nil then
                            local boostedLoss = originalLowSpeedLoss * 0.1
                            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fLowSpeedTractionLossMult', boostedLoss)
                            startGripResetTimer(veh, originalLowSpeedLoss)
                        end
                        lcChargeStart = 0
                    end
                end

                -- *******************************************
                -- ** NUI STATUS (NUR BEI ZUSTANDSÄNDERUNG) **
                -- *******************************************
                if is_2step_active_in_cycle then
                    local chargeStatus = (currentTime - lcChargeStart) >= 2000
                    local newState = chargeStatus and "LAUNCH_GREEN" or "LAUNCH_RED"

                    if lastNuiState ~= newState then
                        lastNuiState = newState
                        SendNUIMessage({
                            transactionType = 'set2StepStatus',
                            status = true,
                            isCharged = chargeStatus
                        })
                    end
                else
                    SetVehicleHandbrake(veh, false)
                    local newState = isAntiLagEnabled and "ON" or "OFF"

                    if lastNuiState ~= newState then
                        lastNuiState = newState
                        SendNUIMessage({
                            transactionType = 'set2StepStatus',
                            status = false,
                            isEnabled = isAntiLagEnabled
                        })
                    end
                end

                last_2step_active_in_cycle = is_2step_active_in_cycle
            else
                updateNuiVisibility(false)
                if lastVeh ~= 0 then
                    resetVehicleGrip(lastVeh)
                    lastVeh = 0
                end
            end
        else
            updateNuiVisibility(false)
            if lastVeh ~= 0 then
                resetVehicleGrip(lastVeh)
                lastVeh = 0
            end
        end

        Wait(sleep)
    end
end)

-- ===================================================================
-- KLIENT: INSTALLATIONS-HANDLER
-- ===================================================================
RegisterNetEvent('antilag:client:attemptInstall', function()
    local player = PlayerPedId()
    local veh = GetVehiclePedIsIn(player, false)

    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= player then
        return QBCore.Functions.Notify("Du musst auf dem Fahrersitz sitzen, um das Kit zu installieren.", "error")
    end

    if Entity(veh).state[antilag_state_key] then
        return QBCore.Functions.Notify("Dieses Fahrzeug hat bereits ein Antilag Kit installiert.", "error")
    end

    TriggerServerEvent('antilag:server:finalizeInstall', VehToNet(veh))
end)

-- ===================================================================
-- SOUND / FLAMMEN NET EVENTS
-- ===================================================================
RegisterNetEvent('sound_client:PlayWithinDistance', function(coords, disMax, audioFile, audioVol)
    local entityCoords = GetEntityCoords(PlayerPedId())
    local distance = #(entityCoords - coords)

    if distance <= disMax then
        local maxVolume = 0.4
        local volumeRatio = math.max(0.0, 1.0 - (distance / disMax))
        local adjustedVolume = maxVolume * volumeRatio * (audioVol or 1.0)

        SendNUIMessage({
            transactionType = 'playSound',
            transactionFile = audioFile,
            transactionVolume = adjustedVolume
        })
    end
end)

RegisterNetEvent("client_short_flames", function(vehicle)
    if NetworkDoesEntityExistWithNetworkId(vehicle) then
        local vehHandle = NetToVeh(vehicle)
        if not DoesEntityExist(vehHandle) then return end

        for _, bones in pairs(exhausts) do
            local boneIndex = GetEntityBoneIndexByName(vehHandle, bones)
            if boneIndex ~= -1 then
                UseParticleFxAssetNextCall(fxGroup_short)
                local startParticle = StartParticleFxLoopedOnEntityBone(
                    fxName_short, vehHandle,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    boneIndex, Config.flameSize * 1.3,
                    false, false, false
                )
                SetTimeout(50, function()
                    StopParticleFxLooped(startParticle, true)
                end)
            end
        end
    end
end)

RegisterNetEvent("client_flames", function(vehicle)
    if NetworkDoesEntityExistWithNetworkId(vehicle) then
        local vehHandle = NetToVeh(vehicle)
        if not DoesEntityExist(vehHandle) then return end

        for _, bones in pairs(exhausts) do
            local boneIndex = GetEntityBoneIndexByName(vehHandle, bones)
            if boneIndex ~= -1 then
                UseParticleFxAssetNextCall(fxGroup)
                local startParticle = StartParticleFxLoopedOnEntityBone(
                    fxName, vehHandle,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    boneIndex, Config.flameSize,
                    false, false, false
                )
                SetTimeout(Config.flameDuration, function()
                    StopParticleFxLooped(startParticle, true)
                end)
            end
        end
    end
end)
