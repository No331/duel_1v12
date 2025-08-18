print("^2[DUEL] Client script chargé^7")

local isMenuOpen = false
local inDuel = false
local currentInstanceId = nil
local originalCoords = nil
local currentArena = nil
local selectedWeapon = nil
local currentRounds = {
    currentRound = 0,
    maxRounds = 5,
    myScore = 0,
    opponentScore = 0,
    showCounter = false
}
local isWaitingForRespawn = false

-- Point d'interaction
local interactionPoint = vector3(256.3, -776.82, 30.88)

-- Coordonnées des arènes
local arenas = {
    aeroport = {
        center = vector3(-1037.0, -2737.0, 20.0),
        radius = 50.0,
        name = "AEROPORT",
        spawns = {
            vector3(-1050.0, -2750.0, 20.0),
            vector3(-1024.0, -2724.0, 20.0)
        }
    },
    ["dans l'eau"] = {
        center = vector3(-1308.0, 6636.0, 5.0),
        radius = 50.0,
        name = "DANS L'EAU",
        spawns = {
            vector3(-1320.0, 6650.0, 5.0),
            vector3(-1296.0, 6622.0, 5.0)
        }
    },
    foret = {
        center = vector3(-1617.0, 4445.0, 3.0),
        radius = 50.0,
        name = "FORET",
        spawns = {
            vector3(-1630.0, 4460.0, 3.0),
            vector3(-1604.0, 4430.0, 3.0)
        }
    },
    hippie = {
        center = vector3(2450.0, 3757.0, 41.0),
        radius = 50.0,
        name = "HIPPIE",
        spawns = {
            vector3(2435.0, 3770.0, 41.0),
            vector3(2465.0, 3744.0, 41.0)
        }
    }
}

-- Thread principal pour le marker
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - interactionPoint)
        
        -- Afficher le marker si pas en duel et proche
        if not inDuel and distance < 100.0 then
            DrawMarker(1, interactionPoint.x, interactionPoint.y, interactionPoint.z - 1.0, 
                      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                      3.0, 3.0, 1.0, 
                      0, 150, 255, 200, 
                      false, true, 2, false, nil, nil, false)
        end
        
        -- Interaction proche
        if not inDuel and distance < 3.0 then
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de duel")
            EndTextCommandDisplayHelp(0, false, false, -1)
            
            if IsControlJustPressed(1, 38) and not isMenuOpen then
                openDuelMenu()
            end
        end
        
        Citizen.Wait(0)
    end
end)

-- Thread pour vérifier les limites de zone en duel
Citizen.CreateThread(function()
    while true do
        if inDuel and currentArena then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local arena = arenas[currentArena]
            
            if arena then
                local distance = #(playerCoords - arena.center)
                
                -- Dessiner les limites de la zone
                DrawMarker(1, arena.center.x, arena.center.y, arena.center.z - 1.0,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 1.0,
                          255, 0, 0, 100,
                          false, true, 2, false, nil, nil, false)
                
                DrawMarker(25, arena.center.x, arena.center.y, arena.center.z,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 2.0,
                          255, 0, 0, 80,
                          false, true, 2, false, nil, nil, false)
                
                -- Téléporter si hors limite
                if distance > arena.radius then
                    SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
                    
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        args = {"[DUEL]", "Vous avez dépassé la zone de combat !"}
                    })
                end
                
                -- Afficher le message pour quitter
                if not isWaitingForRespawn then
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour quitter le duel")
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
                
                -- Afficher le compteur de manches
                if currentRounds.showCounter then
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextScale(0.8, 0.8)
                    SetTextColour(255, 255, 255, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextRightJustify(true)
                    SetTextWrap(0.0, 0.95)
                    SetTextEntry("STRING")
                    
                    local scoreText = "MANCHE " .. currentRounds.currentRound .. "/" .. currentRounds.maxRounds .. "~n~MON SCORE: " .. currentRounds.myScore .. "-" .. currentRounds.opponentScore
                    
                    AddTextComponentString(scoreText)
                    DrawText(0.95, 0.85)
                end
            end
        end
        
        Citizen.Wait(0)
    end
end)

-- Thread pour gérer la touche E pour quitter le duel
Citizen.CreateThread(function()
    while true do
        if inDuel and not isWaitingForRespawn then
            if IsControlJustPressed(1, 38) then
                quitDuel()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Thread pour gérer la mort et le respawn automatique
Citizen.CreateThread(function()
    while true do
        if inDuel then
            local playerPed = PlayerPedId()
            
            -- Détecter la mort
            if (IsPedDeadOrDying(playerPed, true) or GetEntityHealth(playerPed) <= 100) and not isWaitingForRespawn then
                isWaitingForRespawn = true
                
                -- Trouver qui a tué le joueur
                local killer = GetPedSourceOfDeath(playerPed)
                local killerPlayerId = nil
                
                if killer ~= 0 and killer ~= playerPed then
                    -- Chercher le joueur correspondant au killer
                    for i = 0, 255 do
                        if NetworkIsPlayerActive(i) then
                            local otherPed = GetPlayerPed(i)
                            if otherPed == killer then
                                killerPlayerId = i
                                break
                            end
                        end
                    end
                end
                
                -- Signaler la mort au serveur
                TriggerServerEvent('duel:playerDied', killerPlayerId)
                
                -- Attendre avant de respawn
                Citizen.SetTimeout(2500, function()
                    if inDuel then
                        respawnPlayer()
                    end
                end)
            end
        end
        
        Citizen.Wait(100)
    end
end)

-- Fonction pour respawn le joueur
function respawnPlayer()
    if not inDuel or not currentArena then return end
    
    local arena = arenas[currentArena]
    if not arena then return end
    
    local playerPed = PlayerPedId()
    
    -- Choisir un spawn aléatoire
    local spawnIndex = math.random(1, #arena.spawns)
    local spawnPos = arena.spawns[spawnIndex]
    
    -- Forcer la résurrection
    NetworkResurrectLocalPlayer(spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    
    Citizen.Wait(100)
    
    local newPed = PlayerPedId()
    SetEntityCoords(newPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
    
    -- Heal complet + kevlar max
    SetEntityHealth(newPed, 200)
    SetPedArmour(newPed, 100)
    ClearPedBloodDamage(newPed)
    
    -- Redonner l'arme
    local weapons = {
        pistol = "WEAPON_PISTOL",
        combat_pistol = "WEAPON_COMBATPISTOL",
        heavy_pistol = "WEAPON_HEAVYPISTOL",
        vintage_pistol = "WEAPON_VINTAGEPISTOL"
    }
    
    RemoveAllPedWeapons(newPed, true)
    local weaponHash = GetHashKey(weapons[selectedWeapon] or weapons.pistol)
    GiveWeaponToPed(newPed, weaponHash, 250, false, true)
    SetCurrentPedWeapon(newPed, weaponHash, true)
    
    isWaitingForRespawn = false
end

-- Fonction pour ouvrir le menu
function openDuelMenu()
    local playerPed = PlayerPedId()
    originalCoords = GetEntityCoords(playerPed)
    
    isMenuOpen = true
    SetNuiFocus(true, true)
    
    TriggerServerEvent('duel:getAvailableArenas')
    
    SendNUIMessage({
        type = "openMenu"
    })
end

-- Fonction pour fermer le menu
function closeDuelMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Fonction pour quitter le duel
function quitDuel()
    -- Enlever le kevlar
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 0)
    
    enablePlayerPermissions()
    
    TriggerServerEvent('duel:quitArena')
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    currentRounds.showCounter = false
    
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        args = {"[DUEL]", "Vous avez quitté l'arène."}
    })
end

-- Fonction pour désactiver les permissions du joueur
function disablePlayerPermissions()
    Citizen.CreateThread(function()
        while inDuel do
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 288, true) -- F1
            DisableControlAction(0, 289, true) -- F2
            DisableControlAction(0, 170, true) -- F3
            DisableControlAction(0, 167, true) -- F6
            DisableControlAction(0, 166, true) -- F5
            DisableControlAction(0, 199, true) -- P
            DisableControlAction(0, 75, true)  -- F
            DisableControlAction(0, 23, true)  -- F
            DisableControlAction(0, 47, true)  -- G
            DisableControlAction(0, 74, true)  -- H
            DisableControlAction(0, 245, true) -- T
            DisableControlAction(0, 244, true) -- M
            
            Citizen.Wait(0)
        end
    end)
end

-- Fonction pour réactiver les permissions du joueur
function enablePlayerPermissions()
    -- Les permissions sont automatiquement réactivées quand la boucle se termine
end

-- Callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    closeDuelMenu()
    cb('ok')
end)

RegisterNUICallback('createArena', function(data, cb)
    if not data.weapon or not data.map then
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    closeDuelMenu()
    TriggerServerEvent('duel:createArena', data.weapon, data.map)
    cb('ok')
end)

RegisterNUICallback('joinSpecificArena', function(data, cb)
    if not data.arenaId or not data.weapon then
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    closeDuelMenu()
    TriggerServerEvent('duel:joinSpecificArena', data.arenaId, data.weapon)
    cb('ok')
end)

-- Échapper pour fermer le menu
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            if IsControlJustPressed(1, 322) then
                closeDuelMenu()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Event reçu quand une instance est créée
RegisterNetEvent('duel:instanceCreated')
AddEventHandler('duel:instanceCreated', function(instanceId, weapon, map)
    inDuel = true
    currentInstanceId = instanceId
    currentArena = map
    isWaitingForRespawn = false
    
    disablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    local arena = arenas[map]
    
    if arena then
        -- Spawn à la première position
        local spawnPos = arena.spawns[1]
        SetEntityCoords(playerPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
        
        -- Heal complet + kevlar max
        SetEntityHealth(playerPed, 200)
        SetPedArmour(playerPed, 100)
        
        local weapons = {
            pistol = "WEAPON_PISTOL",
            combat_pistol = "WEAPON_COMBATPISTOL",
            heavy_pistol = "WEAPON_HEAVYPISTOL",
            vintage_pistol = "WEAPON_VINTAGEPISTOL"
        }
        
        RemoveAllPedWeapons(playerPed, true)
        local weaponHash = GetHashKey(weapons[weapon] or weapons.pistol)
        GiveWeaponToPed(playerPed, weaponHash, 250, false, true)
        
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            args = {"[DUEL]", "Vous êtes dans l'arène " .. arena.name .. " ! En attente d'un adversaire..."}
        })
    end
end)

-- Event reçu quand une instance est supprimée
RegisterNetEvent('duel:instanceDeleted')
AddEventHandler('duel:instanceDeleted', function()
    enablePlayerPermissions()
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    currentRounds.showCounter = false
    
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 0)
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        args = {"[DUEL]", "Vous avez quitté l'arène."}
    })
end)

-- Event reçu pour mettre à jour la liste des arènes disponibles
RegisterNetEvent('duel:updateAvailableArenas')
AddEventHandler('duel:updateAvailableArenas', function(arenas)
    SendNUIMessage({
        type = "updateArenas",
        arenas = arenas
    })
end)

-- Event reçu quand un adversaire rejoint
RegisterNetEvent('duel:opponentJoined')
AddEventHandler('duel:opponentJoined', function(opponentName)
    -- Activer l'affichage du compteur
    currentRounds.showCounter = true
    currentRounds.currentRound = 0
    currentRounds.myScore = 0
    currentRounds.opponentScore = 0
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        args = {"[DUEL]", opponentName .. " a rejoint l'arène ! Le duel commence dans 3 secondes..."}
    })
    
    -- Compte à rebours
    local countdownMessages = {"3...", "2...", "1...", "GO !"}
    local countdownColors = {{255, 165, 0}, {255, 165, 0}, {255, 165, 0}, {255, 0, 0}}
    
    for i, message in ipairs(countdownMessages) do
        Citizen.SetTimeout((i-1) * 1000, function()
            TriggerEvent('chat:addMessage', {
                color = countdownColors[i],
                args = {"[DUEL]", message}
            })
            
            -- Affichage grand écran
            Citizen.CreateThread(function()
                local startTime = GetGameTimer()
                local duration = i == 4 and 1500 or 1000
                local scale = i == 4 and 4.0 or 3.0
                local color = i == 4 and {255, 0, 0} or {255, 255, 255}
                
                while GetGameTimer() - startTime < duration do
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextScale(scale, scale)
                    SetTextColour(color[1], color[2], color[3], 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextCentre(true)
                    SetTextEntry("STRING")
                    AddTextComponentString(message)
                    DrawText(0.5, 0.4)
                    Citizen.Wait(0)
                end
            end)
        end)
    end
end)

-- Event reçu pour les résultats de manche
RegisterNetEvent('duel:roundResult')
AddEventHandler('duel:roundResult', function(roundData)
    -- Mettre à jour les scores locaux
    currentRounds.currentRound = roundData.currentRound
    currentRounds.maxRounds = roundData.maxRounds
    currentRounds.myScore = roundData.myScore
    currentRounds.opponentScore = roundData.opponentScore
    
    local playerPed = PlayerPedId()
    
    -- Heal + Kevlar après chaque manche
    Citizen.SetTimeout(1000, function()
        if inDuel then
            SetEntityHealth(playerPed, 200)
            SetPedArmour(playerPed, 100)
        end
    end)
    
    -- Message de résultat de manche
    local roundMessage = ""
    local messageColor = {255, 165, 0}
    
    if roundData.amIWinner then
        roundMessage = "🏆 Vous gagnez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.myScore .. "-" .. roundData.opponentScore
        messageColor = {0, 255, 0}
    else
        roundMessage = "💀 Vous perdez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.myScore .. "-" .. roundData.opponentScore
        messageColor = {255, 165, 0}
    end
    
    TriggerEvent('chat:addMessage', {
        color = messageColor,
        args = {"[DUEL]", roundMessage}
    })
    
    -- Si le duel est terminé
    if roundData.duelFinished then
        currentRounds.showCounter = false
        
        local finalMessage = ""
        local finalColor = {255, 255, 0}
        
        if roundData.winner then
            if roundData.amIWinner then
                finalMessage = "🏆 VICTOIRE FINALE ! Vous avez gagné le duel " .. roundData.myScore .. "-" .. roundData.opponentScore .. " !"
                finalColor = {0, 255, 0}
            else
                finalMessage = "💀 DÉFAITE FINALE ! " .. roundData.winnerName .. " a gagné " .. roundData.opponentScore .. "-" .. roundData.myScore
                finalColor = {255, 0, 0}
            end
        else
            finalMessage = "🤝 ÉGALITÉ ! Duel terminé " .. roundData.myScore .. "-" .. roundData.opponentScore
        end
        
        TriggerEvent('chat:addMessage', {
            color = finalColor,
            args = {"[DUEL]", finalMessage}
        })
    end
end)

print("^2[DUEL] Client script initialisé^7")