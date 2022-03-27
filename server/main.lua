-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}

-----------------------
----   Threads     ----
-----------------------
MySQL.ready(function ()
    local races = MySQL.Sync.fetchAll('SELECT * FROM race_tracks', {})
    if races[1] ~= nil then
        for _, v in pairs(races) do
            local Records = {}
            if v.records ~= nil then
                Records = json.decode(v.records)
            end
            Races[v.raceid] = {
                RaceName = v.name,
                Checkpoints = json.decode(v.checkpoints),
                Records = Records,
                Creator = v.creatorid,
                CreatorName = v.creatorname,
                RaceId = v.raceid,
                Started = false,
                Waiting = false,
                Distance = v.distance,
                LastLeaderboard = {},
                Racers = {}
            }
        end
    end
end)

-----------------------
---- Server Events ----
-----------------------
RegisterNetEvent('qb-racing:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local RacerName = RaceData.RacerName
    local PlayersFinished = 0
    local AmountOfRacers = 0

    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        if v.Finished then
            PlayersFinished = PlayersFinished + 1
        end
        AmountOfRacers = AmountOfRacers + 1
    end
    local BLap = 0
    if TotalLaps < 2 then
        BLap = TotalTime
    else
        BLap = BestLap
    end

    if LastRaces[RaceData.RaceId] ~= nil then
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] =  {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = RacerName
        }
    else
        LastRaces[RaceData.RaceId] = {}
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] =  {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = RacerName
        }
    end
    if Races[RaceData.RaceId].Records ~= nil and next(Races[RaceData.RaceId].Records) ~= nil then
        if BLap < Races[RaceData.RaceId].Records.Time then
            Races[RaceData.RaceId].Records = {
                Time = BLap,
                Holder = RacerName
            }
            MySQL.Async.execute('UPDATE race_tracks SET records = ? WHERE raceid = ?',
                {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
                TriggerClientEvent('QBCore:Notify', src, string.format(Lang:t("success.race_record"), RaceData.RaceName, SecondsToClock(BLap)), 'success')
        end
    else
        Races[RaceData.RaceId].Records = {
            Time = BLap,
            Holder = RacerName
        }
        MySQL.Async.execute('UPDATE race_tracks SET records = ? WHERE raceid = ?',
            {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
            TriggerClientEvent('QBCore:Notify', src, string.format(Lang:t("success.race_record"), RaceData.RaceName, SecondsToClock(BLap)), 'success')
    end
    AvailableRaces[AvailableKey].RaceData = Races[RaceData.RaceId]
    TriggerClientEvent('qb-racing:client:PlayerFinish', -1, RaceData.RaceId, PlayersFinished, RacerName)
    if PlayersFinished == AmountOfRacers then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceData.RaceId] ~= nil and
            next(NotFinished[RaceData.RaceId]) ~= nil then
            for k, v in pairs(NotFinished[RaceData.RaceId]) do
                LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId]+1] = {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = v.Holder
                }
            end
        end
        Races[RaceData.RaceId].LastLeaderboard = LastRaces[RaceData.RaceId]
        Races[RaceData.RaceId].Racers = {}
        Races[RaceData.RaceId].Started = false
        Races[RaceData.RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceData.RaceId] = nil
        NotFinished[RaceData.RaceId] = nil
    end
end)

RegisterNetEvent('qb-racing:server:CreateLapRace', function(RaceName, RacerName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if IsPermissioned(Player.PlayerData.citizenid, 'create') then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('qb-racing:client:StartRaceEditor', source, RaceName, RacerName)
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("primary.race_name_exists"), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("primary.no_permission"), 'error')
    end
end)

RegisterNetEvent('qb-racing:server:JoinRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local RaceName = RaceData.RaceData.RaceName
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local CurrentRace = GetCurrentRace(Player.PlayerData.citizenid)
    local RacerName = RaceData.RacerName

    if CurrentRace ~= nil then
        local AmountOfRacers = 0
        PreviousRaceKey = GetOpenedRaceKey(CurrentRace)
        for _,_ in pairs(Races[CurrentRace].Racers) do
            AmountOfRacers = AmountOfRacers + 1
        end
        Races[CurrentRace].Racers[Player.PlayerData.citizenid] = nil
        if (AmountOfRacers - 1) == 0 then
            Races[CurrentRace].Racers = {}
            Races[CurrentRace].Started = false
            Races[CurrentRace].Waiting = false
            table.remove(AvailableRaces, PreviousRaceKey)
            TriggerClientEvent('QBCore:Notify', src, Lang:t("primary.race_last_person"))
            TriggerClientEvent('qb-racing:client:LeaveRace', src, Races[CurrentRace])
        else
            AvailableRaces[PreviousRaceKey].RaceData = Races[CurrentRace]
            TriggerClientEvent('qb-racing:client:LeaveRace', src, Races[CurrentRace])
        end
    else
        Races[RaceId].OrganizerCID = Player.PlayerData.citizenid
    end

    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.PlayerData.citizenid] = {
        Checkpoint = 0,
        Lap = 1,
        Finished = false,
        RacerName = RacerName,
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('qb-racing:client:JoinRace', src, Races[RaceId], RaceData.Laps, RacerName)
    TriggerClientEvent('qb-racing:client:UpdateRaceRacers', src, RaceId, Races[RaceId].Racers)
    local creatorsource = QBCore.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId).PlayerData.source
    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('QBCore:Notify', creatorsource, Lang:t("primary.race_someone_joined"))
    end
end)

RegisterNetEvent('qb-racing:server:LeaveRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local RacerName = RaceData.RacerName
    local RaceName = RaceData.RaceName
    if RaceData.RaceData then
        RaceName = RaceData.RaceData.RaceName
    end

    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local creatorsource = QBCore.Functions.GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId).PlayerData.source

    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('QBCore:Notify', creatorsource, Lang:t("primary.race_someone_left"))
    end

    local AmountOfRacers = 0
    for k, v in pairs(Races[RaceData.RaceId].Racers) do
        AmountOfRacers = AmountOfRacers + 1
    end
    if NotFinished[RaceData.RaceId] ~= nil then
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId]+1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = RacerName
        }
    else
        NotFinished[RaceData.RaceId] = {}
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId]+1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = RacerName
        }
    end
    Races[RaceId].Racers[Player.PlayerData.citizenid] = nil
    if (AmountOfRacers - 1) == 0 then
        if NotFinished ~= nil and next(NotFinished) ~= nil and NotFinished[RaceId] ~= nil and next(NotFinished[RaceId]) ~=
            nil then
            for k, v in pairs(NotFinished[RaceId]) do
                if LastRaces[RaceId] ~= nil then
                    LastRaces[RaceId][#LastRaces[RaceId]+1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                else
                    LastRaces[RaceId] = {}
                    LastRaces[RaceId][#LastRaces[RaceId]+1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                end
            end
        end
        Races[RaceId].LastLeaderboard = LastRaces[RaceId]
        Races[RaceId].Racers = {}
        Races[RaceId].Started = false
        Races[RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        TriggerClientEvent('QBCore:Notify', src, Lang:t("primary.race_last_person"))
        TriggerClientEvent('qb-racing:client:LeaveRace', src, Races[RaceId])
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    else
        AvailableRaces[AvailableKey].RaceData = Races[RaceId]
        TriggerClientEvent('qb-racing:client:LeaveRace', src, Races[RaceId])
    end
    TriggerClientEvent('qb-racing:client:UpdateRaceRacers', src, RaceId, Races[RaceId].Racers)
end)

RegisterNetEvent('qb-racing:server:SetupRace', function(RaceId, Laps, RacerName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Races[RaceId] ~= nil then
        if not Races[RaceId].Waiting then
            if not Races[RaceId].Started then
                Races[RaceId].Waiting = true
                local allRaceData = {
                    RaceData = Races[RaceId],
                    Laps = Laps,
                    RaceId = RaceId,
                    SetupCitizenId = Player.PlayerData.citizenid,
                    SetupRacerName = RacerName
                }
                AvailableRaces[#AvailableRaces+1] = allRaceData
                TriggerClientEvent('QBCore:Notify', src,  Lang:t("success.race_created"), 'success')
                TriggerClientEvent('qb-racing:server:ReadyJoinRace', src, allRaceData)

                CreateThread(function()
                    local count = 0
                    while Races[RaceId].Waiting do
                        Wait(1000)
                        if count < 5 * 60 then
                            count = count + 1
                        else
                            local AvailableKey = GetOpenedRaceKey(RaceId)
                            for cid, _ in pairs(Races[RaceId].Racers) do
                                local RacerData = QBCore.Functions.GetPlayerByCitizenId(cid)
                                if RacerData ~= nil then
                                    TriggerClientEvent('QBCore:Notify', RacerData.PlayerData.source, Lang:t("error.race_timed_out"), 'error')
                                    TriggerClientEvent('qb-racing:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                                end
                            end
                            table.remove(AvailableRaces, AvailableKey)
                            Races[RaceId].LastLeaderboard = {}
                            Races[RaceId].Racers = {}
                            Races[RaceId].Started = false
                            Races[RaceId].Waiting = false
                            LastRaces[RaceId] = nil
                        end
                    end
                end)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.race_already_started"), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.race_already_started"), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.race_doesnt_exist"), 'error')
    end
end)

RegisterNetEvent('qb-racing:server:UpdateRaceState', function(RaceId, Started, Waiting)
    Races[RaceId].Waiting = Waiting
    Races[RaceId].Started = Started
end)

RegisterNetEvent('qb-racing:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid

    Races[RaceId].Racers[CitizenId].Checkpoint = Checkpoint
    Races[RaceId].Racers[CitizenId].Lap = Lap
    Races[RaceId].Racers[CitizenId].Finished = Finished

    TriggerClientEvent('qb-racing:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterNetEvent('qb-racing:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = QBCore.Functions.GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)

    if not RaceId then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_in_race"), 'error')
        return
    end

    if AvailableRaces[AvailableKey].RaceData.Started then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.race_already_started"), 'error')
        return
    end

    AvailableRaces[AvailableKey].RaceData.Started = true
    AvailableRaces[AvailableKey].RaceData.Waiting = false
    for CitizenId, _ in pairs(Races[RaceId].Racers) do
        local Player = QBCore.Functions.GetPlayerByCitizenId(CitizenId)
        if Player ~= nil then
            TriggerClientEvent('qb-racing:client:RaceCountdown', Player.PlayerData.source)
        end
    end
end)

RegisterNetEvent('qb-racing:server:SaveRace', function(RaceData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for k, v in pairs(RaceData.Checkpoints) do
        Checkpoints[k] = {
            offset = v.offset,
            coords = v.coords
        }
    end

    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.PlayerData.citizenid,
        CreatorName = RaceData.RacerName,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {}
    }
    MySQL.Async.insert('INSERT INTO race_tracks (name, checkpoints, creatorid, creatorname, distance, raceid) VALUES (?, ?, ?, ?, ?, ?)',
        {RaceData.RaceName, json.encode(Checkpoints), Player.PlayerData.citizenid, RaceData.RacerName, RaceData.RaceDistance, RaceId})
end)

-----------------------
----   Functions   ----
-----------------------

function SecondsToClock(seconds)
    local seconds = tonumber(seconds)
    local retval = 0
    if seconds <= 0 then
        retval = "00:00:00";
    else
        hours = string.format("%02.f", math.floor(seconds / 3600));
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
        secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60));
        retval = hours .. ":" .. mins .. ":" .. secs
    end
    return retval
end


function IsPermissioned(CitizenId, type)
    local Player = QBCore.Functions.GetPlayerByCitizenId(CitizenId)

    local HasMaster = Player.Functions.GetItemsByName('fob_racing_master')
    if HasMaster then
        for _, item in ipairs(HasMaster) do
            if item.info.owner == CitizenId and Config.Permissions['fob_racing_master'][type] then
                return true
            end
        end
    end

    local HasBasic = Player.Functions.GetItemsByName('fob_racing_basic')
    if HasBasic then
        for _, item in ipairs(HasBasic) do
            if item.info.owner == CitizenId and Config.Permissions['fob_racing_basic'][type] then
                return true
            end
        end
    end
end

function IsNameAvailable(RaceName)
    local retval = true
    for RaceId, _ in pairs(Races) do
        if Races[RaceId].RaceName == RaceName then
            retval = false
            break
        end
    end
    return retval
end

function HasOpenedRace(CitizenId)
    local retval = false
    for k, v in pairs(AvailableRaces) do
        if v.SetupCitizenId == CitizenId then
            retval = true
        end
    end
    return retval
end

function GetOpenedRaceKey(RaceId)
    local retval = nil
    for k, v in pairs(AvailableRaces) do
        if v.RaceId == RaceId then
            retval = k
            break
        end
    end
    return retval
end

function GetCurrentRace(MyCitizenId)
    local retval = nil
    for RaceId, _ in pairs(Races) do
        for cid, _ in pairs(Races[RaceId].Racers) do
            if cid == MyCitizenId then
                retval = RaceId
                break
            end
        end
    end
    return retval
end

function GetRaceId(name)
    local retval = nil
    for k, v in pairs(Races) do
        if v.RaceName == name then
            retval = k
            break
        end
    end
    return retval
end

function GenerateRaceId()
    local RaceId = "LR-" .. math.random(1111, 9999)
    while Races[RaceId] ~= nil do
        RaceId = "LR-" .. math.random(1111, 9999)
    end
    return RaceId
end

function UseRacingFob(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid

    if item.info.owner == citizenid then
        TriggerClientEvent('qb-racing:Client:OpenMainMenu', source, { type = item.name, name = item.info.name})
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.unowned_dongle"), "error")
    end
end

QBCore.Functions.CreateCallback('qb-racing:server:GetRacingLeaderboards', function(source, cb)
    local Leaderboard = {}
    for RaceId, RaceData in pairs(Races) do
        Leaderboard[RaceData.RaceName] = RaceData.Records
    end
    cb(Leaderboard)
end)

QBCore.Functions.CreateCallback('qb-racing:server:GetRaces', function(source, cb)
    cb(AvailableRaces)
end)

QBCore.Functions.CreateCallback('qb-racing:server:GetListedRaces', function(source, cb)
    cb(Races)
end)

QBCore.Functions.CreateCallback('qb-racing:server:GetRacingData', function(source, cb, RaceId)
    cb(Races[RaceId])
end)

QBCore.Functions.CreateCallback('qb-racing:server:HasCreatedRace', function(source, cb)
    cb(HasOpenedRace(QBCore.Functions.GetPlayer(source).PlayerData.citizenid))
end)

QBCore.Functions.CreateCallback('qb-racing:server:IsAuthorizedToCreateRaces', function(source, cb, TrackName)
    cb(IsPermissioned(QBCore.Functions.GetPlayer(source).PlayerData.citizenid, 'create'), IsNameAvailable(TrackName))
end)

QBCore.Functions.CreateCallback('qb-racing:server:GetTrackData', function(source, cb, RaceId)
    local result = MySQL.Sync.fetchAll('SELECT * FROM players WHERE citizenid = ?', {Races[RaceId].Creator})
    if result[1] ~= nil then
        result[1].charinfo = json.decode(result[1].charinfo)
        cb(Races[RaceId], result[1])
    else
        cb(Races[RaceId], {
            charinfo = {
                firstname = "Unknown",
                lastname = "Unknown"
            }
        })
    end
end)

QBCore.Commands.Add(Lang:t("commands.create_racing_fob_command"), Lang:t("commands.create_racing_fob_description"), { {name='type', help='Basic/Master'}, {name='identifier', help='CitizenID or ID'}, {name='Racer Name', help='Racer Name to associate with Fob'} }, true, function(source, args)
    local type = args[1]
    local citizenid = args[2]

    local name = {}
    for i = 3, #args do
        name[#name+1] = args[i]
    end
    name = table.concat(name, ' ')

    local fobTypes = {
        ['basic'] = "fob_racing_basic",
        ['master'] = "fob_racing_master"
    }

    if fobTypes[type:lower()] then
        type = fobTypes[type:lower()]
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_fob_type"), "error")
        return
    end

    if tonumber(citizenid) then
        local Player = QBCore.Functions.GetPlayer(tonumber(citizenid))
        if Player then
            citizenid = Player.PlayerData.citizenid
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.id_not_found"), "error")
            return
        end
    end

    if #name >= Config.MaxRacerNameLength then
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.name_too_short"), "error")
        return
    end

    if #name <= Config.MinRacerNameLength then
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.name_too_long"), "error")
        return
    end

    QBCore.Functions.GetPlayer(source).Functions.AddItem(type, 1, nil, { owner = citizenid, name = name })
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[type], 'add', 1)
end, 'admin')

QBCore.Functions.CreateUseableItem("fob_racing_basic", function(source, item)
    UseRacingFob(source, item)
end)

QBCore.Functions.CreateUseableItem("fob_racing_master", function(source, item)
    UseRacingFob(source, item)
end)
