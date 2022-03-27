-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local Countdown = 10
local ToFarCountdown = 10
local FinishedUITimeout = false

local RaceData = {
    InCreator = false,
    InRace = false,
    ClosestCheckpoint = 0,
}

local CreatorData = {
    RaceName = nil,
    RacerName = nil,
    Checkpoints = {},
    TireDistance = 3.0,
    ConfirmDelete = false,
}

local CurrentRaceData = {
    RaceId = nil,
    RaceName = nil,
    RacerName = nil,
    Checkpoints = {},
    Started = false,
    CurrentCheckpoint = nil,
    TotalLaps = 0,
    Lap = 0,
}


-----------------------
----   Functions   ----
-----------------------

function LoadModel(model)
    while not HasModelLoaded(model) do
          RequestModel(model)
          Wait(10)
    end
end

function DeleteClosestObject(coords, model)
    local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, model, 0, 0, 0)
    DeleteObject(Obj)
    ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
end

function CreatePile(offset, model)
    ClearAreaOfObjects(offset.x, offset.y, offset.z, 50.0, 0)
    LoadModel(model)

    local Obj = CreateObject(model, offset.x, offset.y, offset.z, 0, 0, 0)
    PlaceObjectOnGroundProperly(Obj)
    FreezeEntityPosition(Obj, 1)
    SetEntityAsMissionEntity(Obj, 1, 1)

    return Obj
end

function DeleteAllCheckpoints()
    for k, v in pairs(CreatorData.Checkpoints) do
        local CurrentCheckpoint = CreatorData.Checkpoints[k]

        if CurrentCheckpoint then
            local LeftPile = CurrentCheckpoint.pileleft
            local RightPile = CurrentCheckpoint.pileright

            if LeftPile then
                DeleteClosestObject(CurrentCheckpoint.offset.left, Config.CheckpointPileModel)
                LeftPile = nil
            end
            if RightPile then
                DeleteClosestObject(CurrentCheckpoint.offset.right, Config.CheckpointPileModel)
                RightPile = nil
            end
        end
    end

    for k, v in pairs(CurrentRaceData.Checkpoints) do
        local CurrentCheckpoint = CurrentRaceData.Checkpoints[k]

        if CurrentCheckpoint then
            local LeftPile = CurrentCheckpoint.pileleft
            local RightPile = CurrentCheckpoint.pileright

            if LeftPile then
                DeleteClosestObject(CurrentRaceData.Checkpoints[k].offset.left, Config.CheckpointPileModel)
                LeftPile = nil
            end

            if RightPile then
                DeleteClosestObject(CurrentRaceData.Checkpoints[k].offset.right, Config.CheckpointPileModel)
                RightPile = nil
            end
        end
    end
end

function DeleteCheckpoint()
    local NewCheckpoints = {}
    if RaceData.ClosestCheckpoint ~= 0 then
        local ClosestCheckpoint = CreatorData.Checkpoints[RaceData.ClosestCheckpoint]

        if ClosestCheckpoint then
            local Blip = ClosestCheckpoint.blip
            if Blip then
                RemoveBlip(Blip)
                Blip = nil
            end

            local PileLeft = ClosestCheckpoint.pileleft
            if PileLeft then
                DeleteClosestObject(ClosestCheckpoint.offset.left, Config.CheckpointPileModel)
                PileLeft = nil
            end

            local PileRight = ClosestCheckpoint.pileright
            if PileRight then
                DeleteClosestObject(ClosestCheckpoint.offset.right, Config.CheckpointPileModel)
                PileRight = nil
            end

            for id, data in pairs(CreatorData.Checkpoints) do
                if id ~= RaceData.ClosestCheckpoint then
                    NewCheckpoints[#NewCheckpoints+1] = data
                end
            end
            CreatorData.Checkpoints = NewCheckpoints
        else
            QBCore.Functions.Notify(Lang:t("error.slow_down"), 'error')
        end
    else
        QBCore.Functions.Notify(Lang:t("error.slow_down"), 'error')
    end
end

function DeleteCreatorCheckpoints()
    for id,_ in pairs(CreatorData.Checkpoints) do
        local CurrentCheckpoint = CreatorData.Checkpoints[id]

        local Blip = CurrentCheckpoint.blip
        if Blip then
            RemoveBlip(Blip)
            Blip = nil
        end

        if CurrentCheckpoint then
            local PileLeft = CurrentCheckpoint.pileleft
            if PileLeft then
                DeleteClosestObject(CurrentCheckpoint.offset.left, Config.CheckpointPileModel)
                PileLeft = nil
            end

            local PileRight = CurrentCheckpoint.pileright
            if PileRight then
                DeleteClosestObject(CurrentCheckpoint.offset.right, Config.CheckpointPileModel)
                PileRight = nil
            end
        end
    end
end

function SetupPiles()
    for k, v in pairs(CreatorData.Checkpoints) do
        if not CreatorData.Checkpoints[k].pileleft then
            CreatorData.Checkpoints[k].pileleft = CreatePile(v.offset.left, Config.CheckpointPileModel)
        end

        if not CreatorData.Checkpoints[k].pileright then
            CreatorData.Checkpoints[k].pileright = CreatePile(v.offset.right, Config.CheckpointPileModel)
        end
    end
end

function SaveRace()
    local RaceDistance = 0

    for k, v in pairs(CreatorData.Checkpoints) do
        if k + 1 <= #CreatorData.Checkpoints then
            local checkpointdistance = #(vector3(v.coords.x, v.coords.y, v.coords.z) - vector3(CreatorData.Checkpoints[k + 1].coords.x, CreatorData.Checkpoints[k + 1].coords.y, CreatorData.Checkpoints[k + 1].coords.z))
            RaceDistance = RaceDistance + checkpointdistance
        end
    end

    CreatorData.RaceDistance = RaceDistance

    TriggerServerEvent('qb-racing:server:SaveRace', CreatorData)
    Lang:t("error.slow_down")
    QBCore.Functions.Notify(Lang:t("success.race_saved")..'('..CreatorData.RaceName..')', 'success')

    DeleteCreatorCheckpoints()

    RaceData.InCreator = false
    CreatorData.RaceName = nil
    CreatorData.RacerName = nil
    CreatorData.Checkpoints = {}
end

function GetClosestCheckpoint()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    for id,_ in pairs(CreatorData.Checkpoints) do
        if current ~= nil then
            if #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z)) < dist then
                current = id
                dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            end
        else
            dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            current = id
        end
    end
    RaceData.ClosestCheckpoint = current
end

function CreatorUI()
    CreateThread(function()
        while true do
            if RaceData.InCreator then
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = true,
                })
            else
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = false,
                })
                break
            end
            Wait(200)
        end
    end)
end

function AddCheckpoint()
    local PlayerPed = PlayerPedId()
    local PlayerPos = GetEntityCoords(PlayerPed)
    local PlayerVeh = GetVehiclePedIsIn(PlayerPed)
    local Offset = {
        left = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).z,
        },
        right = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).z,
        }
    }

    CreatorData.Checkpoints[#CreatorData.Checkpoints+1] = {
        coords = {
            x = PlayerPos.x,
            y = PlayerPos.y,
            z = PlayerPos.z,
        },
        offset = Offset,
    }


    for id, CheckpointData in pairs(CreatorData.Checkpoints) do
        if CheckpointData.blip ~= nil then
            RemoveBlip(CheckpointData.blip)
        end

        CheckpointData.blip = CreateCheckpointBlip(CheckpointData.coords, id)
    end
end

function CreateCheckpointBlip(coords, id)
    local Blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(Blip, 1)
    SetBlipDisplay(Blip, 4)
    SetBlipScale(Blip, 0.8)
    SetBlipAsShortRange(Blip, true)
    SetBlipColour(Blip, 26)
    ShowNumberOnBlip(Blip, id)
    SetBlipShowCone(Blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Checkpoint: "..id)
    EndTextCommandSetBlipName(Blip)

    return Blip
end

function CreatorLoop()
    CreateThread(function()
        while RaceData.InCreator do
            local PlayerPed = PlayerPedId()
            local PlayerVeh = GetVehiclePedIsIn(PlayerPed)

            if PlayerVeh ~= 0 then
                if IsControlJustPressed(0, 161) or IsDisabledControlJustPressed(0, 161) then
                    AddCheckpoint()
                end

                if IsControlJustPressed(0, 162) or IsDisabledControlJustPressed(0, 162) then
                    if CreatorData.Checkpoints and next(CreatorData.Checkpoints) then
                        DeleteCheckpoint()
                    else
                        QBCore.Functions.Notify(Lang:t("error.no_checkpoints_to_delete"), 'error')
                    end
                end

                if IsControlJustPressed(0, 311) or IsDisabledControlJustPressed(0, 311) then
                    if CreatorData.Checkpoints and #CreatorData.Checkpoints >= Config.MinimumCheckpoints then
                        SaveRace()
                    else
                        QBCore.Functions.Notify(Lang:t("error.not_enough_checkpoints")..'('..Config.MinimumCheckpoints..')', 'error')
                    end
                end

                if IsControlJustPressed(0, 40) or IsDisabledControlJustPressed(0, 40) then
                    if CreatorData.TireDistance < Config.MaxTireDistance then
                        CreatorData.TireDistance = CreatorData.TireDistance + 1.0
                    else
                        QBCore.Functions.Notify(Lang:t("error.max_tire_distance")..Config.MaxTireDistance)
                    end
                end

                if IsControlJustPressed(0, 39) or IsDisabledControlJustPressed(0, 39) then
                    if CreatorData.TireDistance > Config.MinTireDistance then
                        CreatorData.TireDistance = CreatorData.TireDistance - 1.0
                    else
                        QBCore.Functions.Notify(Lang:t("error.min_tire_distance")..Config.MinTireDistance)
                    end
                end
            else
                local coords = GetEntityCoords(PlayerPedId())
                DrawText3Ds(coords.x, coords.y, coords.z, Lang:t("text.get_in_vehicle"))
            end

            if IsControlJustPressed(0, 163) or IsDisabledControlJustPressed(0, 163) then
                if not CreatorData.ConfirmDelete then
                    CreatorData.ConfirmDelete = true
                    QBCore.Functions.Notify(Lang:t("error.editor_confirm"), 'error')
                else
                    DeleteCreatorCheckpoints()

                    RaceData.InCreator = false
                    CreatorData.RaceName = nil
                    CreatorData.Checkpoints = {}
                    QBCore.Functions.Notify(Lang:t("error.editor_canceled"), 'error')
                    CreatorData.ConfirmDelete = false
                end
            end
            Wait(0)
        end
    end)
end

function RaceUI()
    CreateThread(function()
        while true do
            if CurrentRaceData.Checkpoints ~= nil and next(CurrentRaceData.Checkpoints) ~= nil then
                if CurrentRaceData.Started then
                    CurrentRaceData.RaceTime = CurrentRaceData.RaceTime + 1
                    CurrentRaceData.TotalTime = CurrentRaceData.TotalTime + 1
                end
                SendNUIMessage({
                    action = "Update",
                    type = "race",
                    data = {
                        CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint,
                        TotalCheckpoints = #CurrentRaceData.Checkpoints,
                        TotalLaps = CurrentRaceData.TotalLaps,
                        CurrentLap = CurrentRaceData.Lap,
                        RaceStarted = CurrentRaceData.Started,
                        RaceName = CurrentRaceData.RaceName,
                        Time = CurrentRaceData.RaceTime,
                        TotalTime = CurrentRaceData.TotalTime,
                        BestLap = CurrentRaceData.BestLap,
                    },
                    racedata = RaceData,
                    active = true,
                })
            else
                if not FinishedUITimeout then
                    FinishedUITimeout = true
                    SetTimeout(10000, function()
                        FinishedUITimeout = false
                        SendNUIMessage({
                            action = "Update",
                            type = "race",
                            data = {},
                            racedata = RaceData,
                            active = false,
                        })
                    end)
                end
                break
            end
            Wait(12)
        end
    end)
end

function SetupRace(RaceData, Laps)
    RaceData.RaceId = RaceData.RaceId
    CurrentRaceData = {
        RaceId = RaceData.RaceId,
        Creator = RaceData.Creator,
        OrganizerCID = RaceData.OrganizerCID,
        RacerName = RaceData.RacerName,
        RaceName = RaceData.RaceName,
        Checkpoints = RaceData.Checkpoints,
        Started = false,
        CurrentCheckpoint = 1,
        TotalLaps = Laps,
        Lap = 1,
        RaceTime = 0,
        TotalTime = 0,
        BestLap = 0,
        Racers = {}
    }

    for k, v in pairs(CurrentRaceData.Checkpoints) do
        CurrentRaceData.Checkpoints[k].pileleft = CreatePile(v.offset.left, Config.CheckpointPileModel)
        CurrentRaceData.Checkpoints[k].pileright = CreatePile(v.offset.right, Config.CheckpointPileModel)
        ClearAreaOfObjects(v.offset.right.x, v.offset.right.y, v.offset.right.z, 50.0, 0)

        CurrentRaceData.Checkpoints[k].blip = CreateCheckpointBlip(v.coords, k)
    end

    RaceUI()
end

function showNonLoopParticle(dict, particleName, coords, scale, time)
    while not HasNamedPtfxAssetLoaded(dict) do
        RequestNamedPtfxAsset(dict)
        Wait(0)
    end

    UseParticleFxAssetNextCall(dict)
    local particleHandle = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, scale, false, false, false)
    SetParticleFxLoopedColour(particleHandle, 0, 255, 0 ,0)
    return particleHandle
end

function DoPilePfx()
    if CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint] ~= nil then
        local Timeout = 500
        local Size = 2.0
        local left = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.left, Size)
        local right = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.right, Size)

        SetTimeout(Timeout, function()
            StopParticleFxLooped(left, false)
            StopParticleFxLooped(right, false)
        end)
    end
end

local

function GetMaxDistance(OffsetCoords)
    local Distance = #(vector3(OffsetCoords.left.x, OffsetCoords.left.y, OffsetCoords.left.z) - vector3(OffsetCoords.right.x, OffsetCoords.right.y, OffsetCoords.right.z))
    local Retval = 7.5
    if Distance > 20.0 then
        Retval = 12.5
    end
    return Retval
end

function SecondsToClock(seconds)
    local seconds = tonumber(seconds)
    local retval = 0
    if seconds <= 0 then
        retval = "00:00:00";
    else
        hours = string.format("%02.f", math.floor(seconds/3600));
        mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
        secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
        retval = hours..":"..mins..":"..secs
    end
    return retval
end

function DeleteCurrentRaceCheckpoints()
    for k, v in pairs(CurrentRaceData.Checkpoints) do
        local CurrentCheckpoint = CurrentRaceData.Checkpoints[k]
        local Blip = CurrentCheckpoint.blip
        if Blip then
            RemoveBlip(Blip)
            Blip = nil
        end

        DeleteClosestObject(CurrentCheckpoint.offset.left, Config.CheckpointPileModel)
        PileLeft = nil

        local PileLeft = CurrentCheckpoint.pileleft
        if PileLeft then
            DeleteClosestObject(CurrentCheckpoint.offset.left, Config.CheckpointPileModel)
            PileLeft = nil
        end

        local PileRight = CurrentCheckpoint.pileright
        if PileRight then
            DeleteClosestObject(CurrentCheckpoint.offset.right, Config.CheckpointPileModel)
            PileRight = nil
        end
    end

    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.RaceId = nil
    CurrentRaceData.RacerName = nil
    RaceData.InRace = false
end

function FinishRace()
    TriggerServerEvent('qb-racing:server:FinishPlayer', CurrentRaceData, CurrentRaceData.TotalTime, CurrentRaceData.TotalLaps, CurrentRaceData.BestLap)
    QBCore.Functions.Notify(Lang:t("success.race_finished")..SecondsToClock(CurrentRaceData.TotalTime), 'success')
    if CurrentRaceData.BestLap ~= 0 then
        QBCore.Functions.Notify(Lang:t("success.race_best_lap")..SecondsToClock(CurrentRaceData.BestLap), 'success')
    end

    DeleteCurrentRaceCheckpoints()
end

function Info()
    local PlayerPed = PlayerPedId()
    local plyVeh = GetVehiclePedIsIn(PlayerPed, false)
    local IsDriver = GetPedInVehicleSeat(plyVeh, -1) == PlayerPed
    local returnValue = plyVeh ~= 0 and plyVeh ~= nil and IsDriver
    return returnValue, plyVeh
end

exports('IsInRace', IsInRace)
function IsInRace()
    local retval = false
    if RaceData.InRace then
        retval = true
    end
    return retval
end

exports('IsInEditor', IsInEditor)
function IsInEditor()
    local retval = false
    if RaceData.InCreator then
        retval = true
    end
    return retval
end

function DrawText3Ds(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-----------------------
----   Threads     ----
-----------------------

CreateThread(function()
    while true do
        if RaceData.InCreator then
            GetClosestCheckpoint()
            SetupPiles()
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local Driver, plyVeh = Info()
        if Driver then
            if GetVehicleCurrentGear(plyVeh) < 3 and GetVehicleCurrentRpm(plyVeh) == 1.0 and math.ceil(GetEntitySpeed(plyVeh) * 2.236936) > 50 then
              while GetVehicleCurrentRpm(plyVeh) > 0.6 do
                  SetVehicleCurrentRpm(plyVeh, 0.3)
                  Wait(0)
              end
              Wait(800)
            end
        end
        Wait(500)
    end
end)

CreateThread(function()
    while true do

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if CurrentRaceData.RaceName ~= nil then
            if CurrentRaceData.Started then
                local cp = 0
                if CurrentRaceData.CurrentCheckpoint + 1 > #CurrentRaceData.Checkpoints then
                    cp = 1
                else
                    cp = CurrentRaceData.CurrentCheckpoint + 1
                end
                local data = CurrentRaceData.Checkpoints[cp]
                local CheckpointDistance = #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
                local MaxDistance = GetMaxDistance(CurrentRaceData.Checkpoints[cp].offset)

                if CheckpointDistance < MaxDistance then
                    if CurrentRaceData.TotalLaps == 0 then
                        if CurrentRaceData.CurrentCheckpoint + 1 < #CurrentRaceData.Checkpoints then
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                            TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
                        else
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true)
                            FinishRace()
                        end
                    else
                        if CurrentRaceData.CurrentCheckpoint + 1 > #CurrentRaceData.Checkpoints then
                            if CurrentRaceData.Lap + 1 > CurrentRaceData.TotalLaps then
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                                CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                                TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true)
                                FinishRace()
                            else
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                                if CurrentRaceData.RaceTime < CurrentRaceData.BestLap then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                elseif CurrentRaceData.BestLap == 0 then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                end
                                CurrentRaceData.RaceTime = 0
                                CurrentRaceData.Lap = CurrentRaceData.Lap + 1
                                CurrentRaceData.CurrentCheckpoint = 1
                                SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                                TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                            end
                        else
                            CurrentRaceData.CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint + 1
                            if CurrentRaceData.CurrentCheckpoint ~= #CurrentRaceData.Checkpoints then
                                SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
                                TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                                SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                                SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
                            else
                                SetNewWaypoint(CurrentRaceData.Checkpoints[1].coords.x, CurrentRaceData.Checkpoints[1].coords.y)
                                TriggerServerEvent('qb-racing:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                                SetBlipScale(CurrentRaceData.Checkpoints[#CurrentRaceData.Checkpoints].blip, 0.6)
                                SetBlipScale(CurrentRaceData.Checkpoints[1].blip, 1.0)
                            end
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
                        end
                    end
                end
            else
                local data = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint]
                DrawMarker(4, data.coords.x, data.coords.y, data.coords.z + 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9, 1.5, 1.5, 255, 255, 255, 255, 0, 1, 0, 0, 0, 0, 0)
            end
        else
            Wait(1000)
        end

        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if RaceData.InCreator then
            local PlayerPed = PlayerPedId()
            local PlayerVeh = GetVehiclePedIsIn(PlayerPed)

            if PlayerVeh ~= 0 then
                local Offset = {
                    left = {
                        x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).x,
                        y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).y,
                        z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).z,
                    },
                    right = {
                        x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).x,
                        y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).y,
                        z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).z,
                    }
                }

                DrawText3Ds(Offset.left.x, Offset.left.y, Offset.left.z, Lang:t("text.checkpoint_left"))
                DrawText3Ds(Offset.right.x, Offset.right.y, Offset.right.z, Lang:t("text.checkpoint_right"))
            end
        end
        Wait(0)
    end
end)

-----------------------
---- Client Events ----
-----------------------

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        DeleteAllCheckpoints()
    end
end)

RegisterNetEvent('qb-racing:server:ReadyJoinRace', function(RaceData)
    RaceData.RacerName = RaceData.SetupRacerName
    TriggerServerEvent('qb-racing:server:JoinRace', RaceData)
end)

RegisterNetEvent('qb-racing:client:StartRaceEditor', function(RaceName, RacerName)
    if not RaceData.InCreator then
        CreatorData.RaceName = RaceName
        CreatorData.RacerName = RacerName
        RaceData.InCreator = true
        CreatorUI()
        CreatorLoop()
    else
        QBCore.Functions.Notify(Lang:t("error.already_making_race"), 'error')
    end
end)

RegisterNetEvent('qb-racing:client:UpdateRaceRacerData', function(RaceId, RaceData)
    if (CurrentRaceData.RaceId ~= nil) and CurrentRaceData.RaceId == RaceId then
        CurrentRaceData.Racers = RaceData.Racers
    end
end)

RegisterNetEvent('qb-racing:client:JoinRace', function(Data, Laps, RacerName)
    if not RaceData.InRace then
        Data.RacerName = RacerName
        RaceData.InRace = true
        SetupRace(Data, Laps)
        QBCore.Functions.Notify(Lang:t("primary.race_joined"))
        TriggerServerEvent('qb-racing:server:UpdateRaceState', CurrentRaceData.RaceId, false, true)
    else
        QBCore.Functions.Notify(Lang:t("error.already_in_race"), 'error')
    end
end)

RegisterNetEvent('qb-racing:client:UpdateRaceRacers', function(RaceId, Racers)
    if CurrentRaceData.RaceId == RaceId then
        CurrentRaceData.Racers = Racers
    end
end)

RegisterNetEvent('qb-racing:client:LeaveRace', function(data)
    DeleteCurrentRaceCheckpoints()
    FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), false), false)
end)

RegisterNetEvent('qb-racing:client:RaceCountdown', function()
    TriggerServerEvent('qb-racing:server:UpdateRaceState', CurrentRaceData.RaceId, true, false)
    if CurrentRaceData.RaceId ~= nil then
        while Countdown ~= 0 do
            if CurrentRaceData.RaceName ~= nil then
                if Countdown == 10 then
                    QBCore.Functions.Notify(Lang:t("primary.race_will_start"), 'primary', 2500)
                    PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", 0, 0, 1)
                elseif Countdown <= 5 then
                    QBCore.Functions.Notify(Countdown, 'error', 500)
                    PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", 0, 0, 1)
                end
                Countdown = Countdown - 1
                FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), true)
            else
                break
            end
            Wait(1000)
        end
        if CurrentRaceData.RaceName ~= nil then
            SetNewWaypoint(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.x, CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].coords.y)
            QBCore.Functions.Notify(Lang:t("success.race_go"), 'success', 1000)
            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1].blip, 1.0)
            FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), false)
            DoPilePfx()
            CurrentRaceData.Started = true
            Countdown = 10
        else
            FreezeEntityPosition(GetVehiclePedIsIn(PlayerPedId(), true), false)
            Countdown = 10
        end
    else
        QBCore.Functions.Notify(Lang:t("error.already_in_race"), 'error')
    end
end)

RegisterNetEvent('qb-racing:client:PlayerFinish', function(RaceId, Place, RacerName)
    if CurrentRaceData.RaceId ~= nil then
        if CurrentRaceData.RaceId == RaceId then
            QBCore.Functions.Notify(RacerName..Lang:t("primary.racer_finished_place")..Place, 'primary', 3500)
        end
    end
end)

RegisterNetEvent('qb-racing:client:WaitingDistanceCheck', function()
    Wait(1000)
    CreateThread(function()
        while true do
            if not CurrentRaceData.Started then
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if CurrentRaceData.Checkpoints[1] ~= nil then
                    local cpcoords = CurrentRaceData.Checkpoints[1].coords
                    local dist = #(pos - vector3(cpcoords.x, cpcoords.y, cpcoords.z))
                    if dist > 115.0 then
                        if ToFarCountdown ~= 0 then
                            ToFarCountdown = ToFarCountdown - 1
                            QBCore.Functions.Notify(Lang:t("error.return_to_start")..ToFarCountdown..'s', 'error', 500)
                        else
                            TriggerServerEvent('qb-racing:server:LeaveRace', CurrentRaceData)
                            ToFarCountdown = 10
                            break
                        end
                        Wait(1000)
                    else
                        if ToFarCountdown ~= 10 then
                            ToFarCountdown = 10
                        end
                    end
                end
            else
                break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent("qb-racing:Client:OpenMainMenu", function(data)
    local type = data.type
    local name = data.name

    exports['qb-menu']:openMenu({
        {
            header = Lang:t("menu.ready_to_race")..name..'?',
            isMenuHeader = true
        },
        {
            header = Lang:t("menu.current_race"),
            txt = Lang:t("menu.current_race_txt"),
            disabled = (CurrentRaceData.RaceId == nil),
            params = {
                event = "qb-racing:Client:CurrentRaceMenu",
                args = { type = type, name = name }
            }
        },
        {
            header = Lang:t("menu.available_races"),
            txt = Lang:t("menu.available_races"),
            disabled = not Config.Permissions[type].join,
            params = {
                event = "qb-racing:Client:AvailableRacesMenu",
                args = { type = type, name = name }
            }
        },
        {
            header = Lang:t("menu.race_records"),
            txt = Lang:t("menu.race_records_txt"),
            disabled = not Config.Permissions[type].records,
            params = {
                event = "qb-racing:Client:RaceRecordsMenu",
                args = { type = type, name = name }
            }
        },
        {
            header = Lang:t("menu.setup_race"),
            txt = "",
            disabled = not Config.Permissions[type].setup,
            params = {
                event = "qb-racing:Client:SetupRaceMenu",
                args = { type = type, name = name }
            }
        },
        {
            header = Lang:t("menu.create_race"),
            txt = "",
            disabled = not Config.Permissions[type].create,
            params = {
                event = "qb-racing:Client:CreateRaceMenu",
                args = { type = type, name = name }
            }
        },
        {
            header = Lang:t("menu.close"),
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        },
    })

end)

RegisterNetEvent("qb-racing:Client:CurrentRaceMenu", function(data)
    if not CurrentRaceData.RaceId then
        return
    end

    local racers = 0
    for _ in pairs(CurrentRaceData.Racers) do racers = racers + 1 end

    exports['qb-menu']:openMenu({
        {
            header = CurrentRaceData.RaceName..' | '..racers..Lang:t("menu.racers"),
            isMenuHeader = true
        },
        {
            header = Lang:t("menu.start_race"),
            txt = "",
            disabled = (not (CurrentRaceData.OrganizerCID == QBCore.Functions.GetPlayerData().citizenid) or CurrentRaceData.Started),
            params = {
                isServer = true,
                event = "qb-racing:server:StartRace",
                args = CurrentRaceData.RaceId
            }
        },
        {
            header = Lang:t("menu.leave_race"),
            txt = "",
            params = {
                isServer = true,
                event = "qb-racing:server:LeaveRace",
                args = CurrentRaceData
            }
        },
        {
            header = Lang:t("menu.go_back"),
            params = {
                event = "qb-racing:Client:OpenMainMenu",
                args = { type = data.type, name = data.name }
            }
        },
    })
end)

RegisterNetEvent("qb-racing:Client:AvailableRacesMenu", function(data)
    QBCore.Functions.TriggerCallback('qb-racing:server:GetRaces', function(Races)
        local menu = {
            {
                header = Lang:t("menu.available_races"),
                isMenuHeader = true
            },
        }

        for _,race in ipairs(Races) do
            local RaceData = race.RaceData
            local racers = 0

            for _ in pairs(RaceData.Racers) do racers = racers + 1 end

            race.RacerName = data.name

            menu[#menu+1] = {
                header = RaceData.RaceName,
                txt = string.format(Lang:t("menu.race_info"), race.Laps, RaceData.Distance, racers),
                disabled = CurrentRaceData.RaceId == RaceData.RaceId,
                params = {
                    isServer = true,
                    event = "qb-racing:server:JoinRace",
                    args = race
                }
            }
        end

        menu[#menu+1] = {
            header = Lang:t("menu.go_back"),
            params = {
                event = "qb-racing:Client:OpenMainMenu",
                args = { type = data.type, name = data.name }
            }
        }

        if #menu == 2 then
            QBCore.Functions.Notify(Lang:t("primary.no_pending_races"))
            TriggerEvent('qb-racing:Client:OpenMainMenu', { type = data.type, name = data.name })
            return
        end

        exports['qb-menu']:openMenu(menu)
    end)
end)


RegisterNetEvent("qb-racing:Client:RaceRecordsMenu", function(data)
    QBCore.Functions.TriggerCallback('qb-racing:server:GetRacingLeaderboards', function(Races)
        local menu = {
            {
                header = Lang:t("menu.race_records"),
                isMenuHeader = true
            },
        }

        for RaceName,RecordData in pairs(Races) do
            local text = Lang:t("menu.unclaimed")
            if next(RecordData) then text = string.format("%s | %s ", RecordData.Holder, SecondsToClock(RecordData.Time)) end

            menu[#menu+1] = {
                header = RaceName,
                txt = text,
                disabled = true,
            }
        end

        menu[#menu+1] = {
            header = Lang:t("menu.go_back"),
            params = {
                event = "qb-racing:Client:OpenMainMenu",
                args = { type = data.type, name = data.name }
            }
        }

        if #menu == 2 then
            QBCore.Functions.Notify(Lang:t("primary.no_races_exist"))
            TriggerEvent('qb-racing:Client:OpenMainMenu', { type = data.type, name = data.name })
            return
        end

        exports['qb-menu']:openMenu(menu)
    end)
end)

RegisterNetEvent("qb-racing:Client:SetupRaceMenu", function(data)
    QBCore.Functions.TriggerCallback('qb-racing:server:GetListedRaces', function(Races)
        local tracks = { { value = "none", text = Lang:t("menu.choose_a_track") } }
        for id,track in pairs(Races) do
            if not track.Waiting then
                tracks[#tracks+1] = {  value = id, text = string.format("%s | %s | %sm", track.RaceName, track.CreatorName, track.Distance) }
            end
        end

        if #tracks == 1 then
            QBCore.Functions.Notify(Lang:t("primary.no_available_tracks"))
            TriggerEvent('qb-racing:Client:OpenMainMenu', { type = data.type, name = data.name })
            return
        end

        local dialog = exports['qb-input']:ShowInput({
            header = Lang:t("menu.racing_setup"),
            submitText = "✓",
            inputs = {
                {
                    text = Lang:t("menu.select_track"),
                    name = "track",
                    type = "select",
                    options = tracks
                },
                {
                    text = Lang:t("menu.number_laps"),
                    name = "laps",
                    type = "number",
                    isRequired = true
                },
            },
        })

        if not dialog or dialog.track == "none" then
            TriggerEvent('qb-racing:Client:OpenMainMenu', { type = data.type, name = data.name })
            return
        end

        TriggerServerEvent('qb-racing:server:SetupRace', dialog.track, tonumber(dialog.laps), data.name)
    end)
end)

RegisterNetEvent("qb-racing:Client:CreateRaceMenu", function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t("menu.name_track_question"),
        submitText = "✓",
        inputs = {
            {
                text = Lang:t("menu.name_track"),
                name = "trackname",
                type = "text",
                isRequired = true
            }
        },
    })

    if not dialog then
        TriggerEvent('qb-racing:Client:OpenMainMenu', { type = data.type, name = data.name })
        return
    end

    if #dialog.trackname < Config.MinTrackNameLength then
        QBCore.Functions.Notify(Lang:t("error.name_too_short"), "error")
        TriggerEvent("qb-racing:Client:CreateRaceMenu", { type = data.type, name = data.name })
        return
    end

    if #dialog.trackname > Config.MaxTrackNameLength then
        QBCore.Functions.Notify(Lang:t("error.name_too_long"), "error")
        TriggerEvent("qb-racing:Client:CreateRaceMenu", { type = data.type, name = data.name })
        return
    end

    QBCore.Functions.TriggerCallback('qb-racing:server:IsAuthorizedToCreateRaces', function(IsAuthorized, NameAvailable)
        if not IsAuthorized then return end
        if not NameAvailable then
            QBCore.Functions.Notify(Lang:t("error.race_name_exists"), "error")
            TriggerEvent("qb-racing:Client:CreateRaceMenu", { type = data.type, name = data.name })
            return
        end

        TriggerServerEvent('qb-racing:server:CreateLapRace', dialog.trackname, data.name)
    end, dialog.trackname)
end)