print("^2[DUEL] Client script chargé^7")

local isMenuOpen = false
local inDuel = false
local currentInstanceId = nil
local originalCoords = nil
local currentArena = nil
local selectedWeapon = nil
local currentRounds = {
    player1Score = 0,
    player2Score = 0,
    currentRound = 0,
    maxRounds = 5,
    showRoundCounter = false
}
local isWaitingForRespawn = false

-- Point d'interaction
local interactionPoint = vector3(256.3, -776.82, 30.88)

-- Coordonnées des arènes avec zones limitées (50m de rayon)
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
    print("^2[DUEL] Thread marker démarré^7")
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
            -- Affichage permanent du message E
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de duel")
            EndTextCommandDisplayHelp(0, false, false, -1)
            
            if IsControlJustPressed(1, 38) and not isMenuOpen then
                print("^3[DUEL] Touche E pressée^7")
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
                
                -- Dessiner le cercle de limite en rouge permanent et visible
                DrawMarker(1, arena.center.x, arena.center.y, arena.center.z - 1.0,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 1.0,
                          255, 0, 0, 100,
                          false, true, 2, false, nil, nil, false)
                
                -- Dessiner aussi un cercle au sol pour bien voir la limite
                DrawMarker(25, arena.center.x, arena.center.y, arena.center.z,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 2.0,
                          255, 0, 0, 80,
                          false, true, 2, false, nil, nil, false)
                
                -- Si le joueur dépasse la limite
                if distance > arena.radius then
                    print("^1[DUEL] Joueur hors limite, téléportation au centre^7")
                    SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
                    
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"[DUEL]", "Vous avez dépassé la zone de combat ! Retour au centre."}
                    })
                end
                
                -- Afficher le message pour quitter (permanent)
                if not isWaitingForRespawn then
                    BeginTextCommandDisplayHelp("STRING")
                    AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour quitter le duel")
                    EndTextCommandDisplayHelp(0, false, false, -1)
                end
                
                -- Afficher le compteur de manches en bas à droite
                if currentRounds.showRoundCounter then
                    SetTextFont(0)
                    SetTextProportional(1)
                    SetTextScale(0.8, 0.8)
                    SetTextColour(255, 255, 255, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(2, 0, 0, 0, 150)
                    SetTextRightJustify(true)
                    SetTextWrap(0.0, 0.95)
                    SetTextEntry("STRING")
                    
                    -- Afficher le score selon ma perspective
                    local playerId = PlayerId()
                    local scoreText = ""
                    if playerId and currentRounds.player1Id and playerId == currentRounds.player1Id then
                        -- Je suis joueur 1
                        scoreText = "MANCHE " .. currentRounds.currentRound .. "/" .. currentRounds.maxRounds .. "~n~MON SCORE: " .. currentRounds.player1Score .. "-" .. currentRounds.player2Score
                    elseif playerId and currentRounds.player2Id and playerId == currentRounds.player2Id then
                        -- Je suis joueur 2
                        scoreText = "MANCHE " .. currentRounds.currentRound .. "/" .. currentRounds.maxRounds .. "~n~MON SCORE: " .. currentRounds.player2Score .. "-" .. currentRounds.player1Score
                    else
                        -- Fallback
                        scoreText = "MANCHE " .. currentRounds.currentRound .. "/" .. currentRounds.maxRounds .. "~n~SCORE: " .. currentRounds.player1Score .. "-" .. currentRounds.player2Score
                    end
                    
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
                print("^3[DUEL] Touche E pressée pour quitter le duel^7")
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
            
            -- Détecter la mort (santé <= 0 ou IsPedDeadOrDying)
            if (IsPedDeadOrDying(playerPed, true) or GetEntityHealth(playerPed) <= 100) and not isWaitingForRespawn then
                print("^1[DUEL] Joueur mort détecté - Santé: " .. GetEntityHealth(playerPed) .. "^7")
                isWaitingForRespawn = true
                
                -- Trouver qui a tué le joueur
                local killer = GetPedSourceOfDeath(playerPed)
                local killerPlayerId = nil
                
                print("^1[DUEL] Killer entity: " .. tostring(killer) .. "^7")
                
                if killer ~= 0 and killer ~= playerPed then
                    -- Chercher le joueur correspondant au killer
                    for i = 0, 255 do
                        if NetworkIsPlayerActive(i) then
                            local otherPed = GetPlayerPed(i)
                            if otherPed == killer then
                                killerPlayerId = i
                                print("^2[DUEL] Killer trouvé: Joueur " .. i .. "^7")
                                break
                            end
                        end
                    end
                else
                    print("^1[DUEL] Pas de killer valide trouvé^7")
                end
                
                -- Signaler la mort au serveur
                print("^1[DUEL] Envoi de la mort au serveur - Killer: " .. tostring(killerPlayerId) .. "^7")
                print("^1[DUEL] Mon ID: " .. PlayerId() .. ", Instance: " .. tostring(currentInstanceId) .. "^7")
                TriggerServerEvent('duel:playerDied', killerPlayerId)
                
                -- Vérifier que l'event est bien envoyé
                print("^2[DUEL] Event 'duel:playerDied' envoyé avec killerPlayerId: " .. tostring(killerPlayerId) .. "^7")
                
                -- Attendre 2-3 secondes (temps de ragdoll)
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
    local playerId = PlayerId()
    
    -- Choisir un spawn aléatoire
    local spawnIndex = math.random(1, #arena.spawns)
    local spawnPos = arena.spawns[spawnIndex]
    
    -- Forcer la résurrection
    NetworkResurrectLocalPlayer(spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    
    -- Attendre que le joueur soit respawné
    Citizen.Wait(100)
    
    local newPed = PlayerPedId()
    SetEntityCoords(newPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
    
    -- Heal complet + kevlar max
    SetEntityHealth(newPed, 200)
    SetPedArmour(newPed, 100)
    ClearPedBloodDamage(newPed)
    
    -- Redonner l'arme avec les bonnes munitions
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
    
    print("^2[DUEL] Joueur respawné dans l'arène^7")
end

-- Fonction pour ouvrir le menu
function openDuelMenu()
    print("^3[DUEL] Ouverture du menu^7")
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
    print("^3[DUEL] Fermeture du menu^7")
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Fonction pour quitter le duel
function quitDuel()
    print("^3[DUEL] Quitter le duel^7")
    
    -- Enlever le kevlar
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 0)
    
    enablePlayerPermissions()
    
    TriggerServerEvent('duel:quitArena')
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    
    RemoveAllPedWeapons(playerPed, true)
    
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté l'arène et êtes retourné au point de départ."}
    })
end

-- Fonction pour désactiver les permissions du joueur
function disablePlayerPermissions()
    print("^1[DUEL] Désactivation des permissions^7")
    
    Citizen.CreateThread(function()
        while inDuel do
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 288, true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            DisableControlAction(0, 166, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 74, true)
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 244, true)
            
            Citizen.Wait(0)
        end
    end)
end

-- Fonction pour réactiver les permissions du joueur
function enablePlayerPermissions()
    print("^2[DUEL] Réactivation des permissions^7")
end

-- Callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    print("^2[DUEL] Callback closeMenu reçu^7")
    closeDuelMenu()
    cb('ok')
end)

RegisterNUICallback('createArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK CREATEARENA ==========^7")
    print("^3[DUEL] Données reçues: weapon=" .. tostring(data.weapon) .. ", map=" .. tostring(data.map) .. "^7")
    
    if not data.weapon or not data.map then
        print("^1[DUEL] Données manquantes^7")
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour créer l'arène^7")
    TriggerServerEvent('duel:createArena', data.weapon, data.map)
    
    cb('ok')
end)

RegisterNUICallback('joinSpecificArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK JOIN SPECIFIC ARENA ==========^7")
    print("^3[DUEL] Données reçues: arenaId=" .. tostring(data.arenaId) .. ", weapon=" .. tostring(data.weapon) .. "^7")
    
    if not data.arenaId or not data.weapon then
        print("^1[DUEL] Données manquantes^7")
        cb('error')
        return
    end
    
    selectedWeapon = data.weapon
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour rejoindre l'arène spécifique^7")
    TriggerServerEvent('duel:joinSpecificArena', data.arenaId, data.weapon)
    
    cb('ok')
end)

-- Échapper pour fermer le menu
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            if IsControlJustPressed(1, 322) then
                print("^3[DUEL] ESC pressé^7")
                closeDuelMenu()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Event reçu quand une instance est créée
RegisterNetEvent('duel:instanceCreated')
AddEventHandler('duel:instanceCreated', function(instanceId, weapon, map)
    print("^2[DUEL] Instance " .. tostring(instanceId) .. " créée pour arène '" .. tostring(map) .. "'^7")
    
    inDuel = true
    currentInstanceId = instanceId
    currentArena = map
    isWaitingForRespawn = false
    
    disablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    local arena = arenas[map]
    
    if arena then
        -- Spawn à une position spécifique selon l'ordre d'arrivée
        local spawnPos = arena.spawns[1] -- Premier spawn par défaut
        SetEntityCoords(playerPed, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
        
        -- Heal complet + kevlar max à l'entrée
        SetEntityHealth(playerPed, 200)
        SetPedArmour(playerPed, 100)
        
        print("^2[DUEL] Téléportation vers " .. arena.name .. " avec heal et kevlar^7")
        
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
            multiline = true,
            args = {"[DUEL]", "Vous êtes dans l'arène " .. arena.name .. " ! En attente d'un adversaire..."}
        })
    else
        print("^1[DUEL] Arène '" .. tostring(map) .. "' non trouvée dans la liste des arènes^7")
        print("^1[DUEL] Arènes disponibles: aeroport, dans l'eau, foret, hippie^7")
    end
end)

-- Event reçu quand une instance est supprimée
RegisterNetEvent('duel:instanceDeleted')
AddEventHandler('duel:instanceDeleted', function()
    print("^1[DUEL] Instance supprimée^7")
    
    enablePlayerPermissions()
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    isWaitingForRespawn = false
    
    -- Enlever le kevlar à la sortie
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
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté votre instance privée et êtes retourné au point de départ."}
    })
end)

-- Event reçu pour mettre à jour la liste des arènes disponibles
RegisterNetEvent('duel:updateAvailableArenas')
AddEventHandler('duel:updateAvailableArenas', function(arenas)
    print("^3[DUEL] Mise à jour des arènes disponibles: " .. #arenas .. " arène(s)^7")
    
    SendNUIMessage({
        type = "updateArenas",
        arenas = arenas
    })
end)

-- Event reçu quand un adversaire rejoint
RegisterNetEvent('duel:opponentJoined')
AddEventHandler('duel:opponentJoined', function(opponentName)
    print("^2[DUEL] Adversaire rejoint: " .. tostring(opponentName) .. "^7")
    
    -- Activer l'affichage du compteur de manches
    currentRounds.showRoundCounter = true
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", opponentName .. " a rejoint l'arène ! Le duel commence dans 3 secondes..."}
    })
    
    -- Compte à rebours avec affichage à l'écran
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        args = {"[DUEL]", "3..."}
    })
    
    -- Affichage grand écran pour le compte à rebours
    Citizen.CreateThread(function()
        -- 3
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 1000 do
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(3.0, 3.0)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString("3")
            DrawText(0.5, 0.4)
            Citizen.Wait(0)
        end
    end)
    
    Citizen.SetTimeout(1000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "2..."}
        })
        
        -- Affichage grand écran pour 2
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1000 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(3.0, 3.0)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("2")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
    
    Citizen.SetTimeout(2000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "1..."}
        })
        
        -- Affichage grand écran pour 1
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1000 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(3.0, 3.0)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("1")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
    
    Citizen.SetTimeout(3000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            args = {"[DUEL]", "GO !"}
        })
        
        -- Affichage grand écran pour GO
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 1500 do
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(4.0, 4.0)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("GO !")
                DrawText(0.5, 0.4)
                Citizen.Wait(0)
            end
        end)
    end)
end)

-- Event reçu pour les résultats de manche
RegisterNetEvent('duel:roundResult')
AddEventHandler('duel:roundResult', function(roundData)
    print("^3[DUEL] === RÉSULTAT DE MANCHE CLIENT ===^7")
    print("^3[DUEL] Manche: " .. roundData.currentRound .. "/" .. roundData.maxRounds .. "^7")
    print("^3[DUEL] Score Joueur 1: " .. roundData.player1Score .. "^7")
    print("^3[DUEL] Score Joueur 2: " .. roundData.player2Score .. "^7")
    print("^3[DUEL] Mon ID: " .. PlayerId() .. "^7")
    print("^3[DUEL] Joueur 1 ID: " .. roundData.player1Id .. "^7")
    print("^3[DUEL] Joueur 2 ID: " .. roundData.player2Id .. "^7")
    print("^3[DUEL] Tueur: " .. roundData.killerPlayerId .. "^7")
    
    currentRounds = {
        player1Score = roundData.player1Score,
        player2Score = roundData.player2Score,
        currentRound = roundData.currentRound,
        maxRounds = roundData.maxRounds,
        showRoundCounter = true,
        player1Id = roundData.player1Id,
        player2Id = roundData.player2Id
    }
    
    local playerId = PlayerId()
    local playerPed = PlayerPedId()
    
    -- HEAL + KEVLAR pour TOUS LES JOUEURS à la fin de chaque manche (avec délai)
    Citizen.SetTimeout(1000, function()
        if inDuel then
            SetEntityHealth(playerPed, 200)
            SetPedArmour(playerPed, 100)
            print("^2[DUEL] Heal + Kevlar appliqué au joueur " .. playerId .. "^7")
        end
    end)
    
    -- Déterminer qui je suis et afficher le bon message
    local amIPlayer1 = (playerId == roundData.player1Id)
    local roundWinner = ""
    local roundMessage = ""
    
    if playerId == roundData.player1Id then
        -- Je suis le joueur 1
        if roundData.killerPlayerId == playerId then
            roundMessage = "🏆 Vous gagnez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.player1Score .. "-" .. roundData.player2Score
        else
            roundMessage = "💀 Vous perdez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.player1Score .. "-" .. roundData.player2Score
        end
    else
        -- Je suis le joueur 2
        if roundData.killerPlayerId == playerId then
            roundMessage = "🏆 Vous gagnez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.player2Score .. "-" .. roundData.player1Score
        else
            roundMessage = "💀 Vous perdez la manche " .. roundData.currentRound .. " ! Score: " .. roundData.player2Score .. "-" .. roundData.player1Score
        end
    end
    
    TriggerEvent('chat:addMessage', {
        color = roundData.killerPlayerId == playerId and {0, 255, 0} or {255, 165, 0},
        multiline = true,
        args = {"[DUEL]", roundMessage}
    })
    
    -- Si le duel est terminé
    if roundData.duelFinished then
        currentRounds.showRoundCounter = false
        
        local finalMessage = ""
        local finalColor = {255, 255, 0} -- Jaune par défaut (égalité)
        
        if roundData.winner then
            if roundData.winner == playerId then
                -- Je gagne
                if playerId == roundData.player1Id then
                    finalMessage = "🏆 VICTOIRE FINALE ! Vous avez gagné le duel " .. roundData.player1Score .. "-" .. roundData.player2Score .. " !"
                else
                    finalMessage = "🏆 VICTOIRE FINALE ! Vous avez gagné le duel " .. roundData.player2Score .. "-" .. roundData.player1Score .. " !"
                end
                finalColor = {0, 255, 0} -- Vert
            else
                -- Je perds
                if playerId == roundData.player1Id then
                    finalMessage = "💀 DÉFAITE FINALE ! " .. roundData.winnerName .. " a gagné " .. roundData.player2Score .. "-" .. roundData.player1Score
                else
                    finalMessage = "💀 DÉFAITE FINALE ! " .. roundData.winnerName .. " a gagné " .. roundData.player1Score .. "-" .. roundData.player2Score
                end
                finalColor = {255, 0, 0} -- Rouge
            end
        else
            -- Égalité
            if playerId == roundData.player1Id then
                finalMessage = "🤝 ÉGALITÉ ! Duel terminé " .. roundData.player1Score .. "-" .. roundData.player2Score
            else
                finalMessage = "🤝 ÉGALITÉ ! Duel terminé " .. roundData.player2Score .. "-" .. roundData.player1Score
            end
        end
        
        TriggerEvent('chat:addMessage', {
            color = finalColor,
            multiline = true,
            args = {"[DUEL]", finalMessage}
        })
        
        -- Quitter automatiquement après 3 secondes
        Citizen.SetTimeout(3000, function()
            if inDuel then
                quitDuel()
            end
        end)
    end
end)

print("^2[DUEL] Client script complètement initialisé^7")