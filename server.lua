print("^2[DUEL] Server script chargé^7")

-- Debug pour vérifier l'enregistrement des events
print("^2[DUEL] Enregistrement de l'event duel:playerDied^7")

-- Système d'instances
local instances = {}
local nextInstanceId = 1

-- Configuration du système de manches
local MAX_ROUNDS = 5 -- Maximum 5 manches
local ROUNDS_TO_WIN = 3 -- Premier à 3 manches gagne

-- Fonction pour créer une nouvelle instance
function createInstance(playerId, arenaType, weapon)
    local instanceId = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    
    instances[instanceId] = {
        id = instanceId,
        creator = playerId,
        arena = arenaType,
        weapon = weapon,
        players = {playerId},
        maxPlayers = 2,
        status = "waiting", -- waiting, full, active
        created = os.time(),
        rounds = {
            player1Score = 0,
            player2Score = 0,
            currentRound = 0,
            maxRounds = 5,
            roundsToWin = ROUNDS_TO_WIN
        }
    }
    
    print("^3[DUEL] Instance " .. instanceId .. " créée par le joueur " .. playerId .. " (arène: " .. arenaType .. ", arme: " .. weapon .. ")^7")
    return instanceId
end

-- Fonction pour supprimer une instance
function deleteInstance(instanceId)
    if instances[instanceId] then
        local instance = instances[instanceId]
        print("^1[DUEL] Instance " .. instanceId .. " supprimée (créateur: " .. instance.creator .. ", arène: " .. instance.arena .. ")^7")
        instances[instanceId] = nil
    else
        print("^1[DUEL] Tentative de suppression d'une instance inexistante: " .. instanceId .. "^7")
    end
end

-- Fonction pour obtenir l'instance d'un joueur
function getPlayerInstance(playerId)
    for instanceId, instance in pairs(instances) do
        for _, pid in ipairs(instance.players) do
            if pid == playerId then
                return instanceId, instance
            end
        end
    end
    return nil, nil
end

-- Fonction pour obtenir les arènes disponibles (en attente de joueurs)
function getAvailableArenas()
    local available = {}
    for instanceId, instance in pairs(instances) do
        if instance.status == "waiting" and #instance.players < instance.maxPlayers then
            local creatorName = GetPlayerName(instance.creator) or ("Joueur " .. instance.creator)
            table.insert(available, {
                id = instanceId,
                creator = instance.creator,
                creatorName = creatorName,
                arena = instance.arena,
                weapon = instance.weapon,
                players = #instance.players,
                maxPlayers = instance.maxPlayers
            })
        end
    end
    return available
end

-- Fonction pour ajouter un joueur à une instance
function addPlayerToInstance(instanceId, playerId)
    local instance = instances[instanceId]
    if not instance then
        return false, "Instance non trouvée"
    end
    
    if #instance.players >= instance.maxPlayers then
        return false, "Instance pleine"
    end
    
    -- Vérifier que le joueur n'est pas déjà dans l'instance
    for _, pid in ipairs(instance.players) do
        if pid == playerId then
            return false, "Joueur déjà dans l'instance"
        end
    end
    
    table.insert(instance.players, playerId)
    
    -- Si l'instance est maintenant pleine, changer le statut
    if #instance.players >= instance.maxPlayers then
        instance.status = "full"
    end
    
    return true, "Joueur ajouté avec succès"
end

-- Fonction pour gérer la mort d'un joueur
function handlePlayerDeath(instanceId, deadPlayerId, killerPlayerId)
    local instance = instances[instanceId]
    if not instance then 
        print("^1[DUEL] ERREUR: Instance " .. instanceId .. " non trouvée^7")
        return 
    end
    
    -- Vérifier qu'on a bien 2 joueurs
    if #instance.players < 2 then
        print("^1[DUEL] ERREUR: Pas assez de joueurs dans l'instance (" .. #instance.players .. "/2)^7")
        return
    end
    
    -- Vérifier qu'on a un tueur valide et différent du mort
    if not killerPlayerId or killerPlayerId == deadPlayerId or killerPlayerId == 0 then
        print("^1[DUEL] ERREUR: Mort sans tueur valide, pas de point marqué^7")
        print("^1[DUEL] KillerPlayerId: " .. tostring(killerPlayerId) .. ", DeadPlayerId: " .. tostring(deadPlayerId) .. "^7")
        return
    end
    
    -- Déterminer qui est le joueur 1 et qui est le joueur 2
    local player1Id = instance.players[1]
    local player2Id = instance.players[2]
    
    print("^2[DUEL] === ANALYSE DE LA MANCHE ===^7")
    print("^3[DUEL] Joueur 1 (créateur): " .. player1Id .. "^7")
    print("^3[DUEL] Joueur 2: " .. player2Id .. "^7")
    print("^3[DUEL] Tueur: " .. killerPlayerId .. "^7")
    print("^3[DUEL] Mort: " .. deadPlayerId .. "^7")
    
    -- Vérifier que le tueur est bien un des 2 joueurs du duel
    if killerPlayerId ~= player1Id and killerPlayerId ~= player2Id then
        print("^1[DUEL] ERREUR: Le tueur (" .. killerPlayerId .. ") n'est pas un joueur du duel^7")
        return
    end
    
    -- Incrémenter le round
    instance.rounds.currentRound = instance.rounds.currentRound + 1
    print("^2[DUEL] NOUVELLE MANCHE: " .. instance.rounds.currentRound .. "/" .. MAX_ROUNDS .. "^7")
    
    -- Incrémenter le score du tueur selon son index dans la liste
    if killerPlayerId == player1Id then
        instance.rounds.player1Score = instance.rounds.player1Score + 1
        print("^2[DUEL] ✅ JOUEUR 1 (" .. GetPlayerName(player1Id) .. ") gagne la manche " .. instance.rounds.currentRound .. " !^7")
        print("^2[DUEL] Score actuel: " .. instance.rounds.player1Score .. "-" .. instance.rounds.player2Score .. "^7")
    elseif killerPlayerId == player2Id then
        instance.rounds.player2Score = instance.rounds.player2Score + 1
        print("^2[DUEL] ✅ JOUEUR 2 (" .. GetPlayerName(player2Id) .. ") gagne la manche " .. instance.rounds.currentRound .. " !^7")
        print("^2[DUEL] Score actuel: " .. instance.rounds.player1Score .. "-" .. instance.rounds.player2Score .. "^7")
    else
        print("^1[DUEL] ERREUR: Le tueur n'est ni joueur 1 ni joueur 2^7")
        return
    end
    
    -- Vérifier si quelqu'un a gagné
    local winner = nil
    local winnerName = ""
    local loserName = ""
    local duelFinished = false
    
    -- Vérifier si quelqu'un a gagné (3 manches) OU si on a atteint 5 manches
    if instance.rounds.player1Score >= ROUNDS_TO_WIN then
        winner = instance.players[1]
        winnerName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
        loserName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
        duelFinished = true
        print("^2[DUEL] Joueur 1 gagne le duel !^7")
    elseif instance.rounds.player2Score >= ROUNDS_TO_WIN then
        winner = instance.players[2]
        winnerName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
        loserName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
        duelFinished = true
        print("^2[DUEL] Joueur 2 gagne le duel !^7")
    elseif instance.rounds.currentRound >= MAX_ROUNDS then
        -- Si on a fait 5 manches, celui avec le plus de points gagne
        if instance.rounds.player1Score > instance.rounds.player2Score then
            winner = instance.players[1]
            winnerName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
            loserName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
            print("^2[DUEL] Joueur 1 gagne aux points !^7")
        elseif instance.rounds.player2Score > instance.rounds.player1Score then
            winner = instance.players[2]
            winnerName = GetPlayerName(instance.players[2]) or "Joueur " .. instance.players[2]
            loserName = GetPlayerName(instance.players[1]) or "Joueur " .. instance.players[1]
            print("^2[DUEL] Joueur 2 gagne aux points !^7")
        else
            -- Égalité - pas de gagnant
            winner = nil
            winnerName = "Égalité"
            print("^3[DUEL] Duel terminé en égalité !^7")
        end
        duelFinished = true
    end
    
    print("^3[DUEL] Envoi des scores - Manche " .. instance.rounds.currentRound .. "/" .. MAX_ROUNDS .. " - Score: " .. instance.rounds.player1Score .. "-" .. instance.rounds.player2Score .. "^7")
    
    -- Envoyer les scores aux joueurs
    for _, playerId in ipairs(instance.players) do
        TriggerClientEvent('duel:roundResult', playerId, {
            player1Score = instance.rounds.player1Score,
            player2Score = instance.rounds.player2Score,
            currentRound = instance.rounds.currentRound,
            maxRounds = MAX_ROUNDS,
            winner = winner,
            winnerName = winnerName,
            loserName = loserName,
            killerPlayerId = killerPlayerId,
            deadPlayerId = deadPlayerId,
            duelFinished = duelFinished,
            player1Id = player1Id,
            player2Id = player2Id
        })
    end
    
    -- Si quelqu'un a gagné, terminer le duel
    if duelFinished then
        if winner then
            print("^2[DUEL] " .. winnerName .. " a gagné le duel " .. instance.rounds.player1Score .. "-" .. instance.rounds.player2Score .. "^7")
        else
            print("^3[DUEL] Duel terminé en égalité " .. instance.rounds.player1Score .. "-" .. instance.rounds.player2Score .. "^7")
        end
        
        -- Attendre 3 secondes puis supprimer l'instance
        Citizen.SetTimeout(3000, function()
            deleteInstance(instanceId)
        end)
    end
end

-- Event pour signaler une mort
print("^2[DUEL] === ENREGISTREMENT EVENT PLAYERDIED ===^7")
RegisterNetEvent('duel:playerDied')
AddEventHandler('duel:playerDied', function(killerPlayerId)
    local source = source
    local deadPlayerName = GetPlayerName(source) or "Joueur " .. source
    local killerPlayerName = GetPlayerName(killerPlayerId) or "Joueur " .. killerPlayerId
    
    print("^2[DUEL] ========== EVENT PLAYERDIED RECU ==========^7")
    print("^2[DUEL] Source (mort): " .. source .. " (" .. deadPlayerName .. ")^7")
    print("^2[DUEL] Killer: " .. tostring(killerPlayerId) .. " (" .. killerPlayerName .. ")^7")
    
    -- Trouver l'instance du joueur mort
    local instanceId, instance = getPlayerInstance(source)
    if instanceId and instance then
        print("^2[DUEL] Instance " .. instanceId .. " trouvée avec " .. #instance.players .. " joueurs^7")
        print("^2[DUEL] Joueurs dans l'instance: " .. table.concat(instance.players, ", ") .. "^7")
        handlePlayerDeath(instanceId, source, killerPlayerId)
    else
        print("^1[DUEL] ERREUR: Aucune instance trouvée pour le joueur mort " .. source .. "^7")
        -- Debug: lister toutes les instances
        print("^1[DUEL] Instances actives:^7")
        for id, inst in pairs(instances) do
            print("^1[DUEL]   Instance " .. id .. ": joueurs " .. table.concat(inst.players, ", ") .. "^7")
        end
    end
    print("^2[DUEL] ========== FIN EVENT PLAYERDIED ==========^7")
end)
print("^2[DUEL] Event duel:playerDied enregistré avec succès^7")

-- Commande de test pour vérifier la communication client-serveur
print("^2[DUEL] Enregistrement de la commande testduel^7")
RegisterCommand('testduel', function(source, args, rawCommand)
    local playerName = GetPlayerName(source) or "Joueur " .. source
    print("^2[DUEL] Commande testduel reçue de " .. playerName .. " (ID: " .. source .. ")^7")
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DUEL]", "Communication serveur OK !"}
        })
    end
end, false)

-- Event pour rejoindre une arène (créer une instance)
print("^2[DUEL] Enregistrement de l'event duel:createArena^7")
RegisterNetEvent('duel:createArena')
AddEventHandler('duel:createArena', function(weapon, map)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^2[DUEL] ========== EVENT CREATEARENA SERVEUR ==========^7")
    print("^2[DUEL] Joueur: " .. playerName .. " (ID: " .. source .. ")^7")
    print("^2[DUEL] Paramètres reçus:^7")
    print("^2[DUEL]   weapon = " .. tostring(weapon) .. " (type: " .. type(weapon) .. ")^7")
    print("^2[DUEL]   map = " .. tostring(map) .. " (type: " .. type(map) .. ")^7")
    
    -- Vérifier que les paramètres sont valides
    if not weapon or not map then
        print("^1[DUEL] Paramètres invalides - weapon: " .. tostring(weapon) .. ", map: " .. tostring(map) .. "^7")
        return
    end
    
    print("^2[DUEL] Paramètres valides, vérification instance existante^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur " .. source .. " déjà dans l'instance " .. currentInstanceId .. "^7")
        -- Supprimer l'ancienne instance et en créer une nouvelle
        deleteInstance(currentInstanceId)
    else
        print("^2[DUEL] Aucune instance existante pour le joueur^7")
    end
    
    print("^2[DUEL] Création de la nouvelle instance d'arène^7")
    -- Créer une nouvelle instance en attente
    local instanceId = createInstance(source, map, weapon)
    
    print("^2[DUEL] Instance " .. instanceId .. " créée avec succès pour " .. playerName .. "^7")
    print("^2[DUEL] Joueurs dans la nouvelle instance: " .. table.concat(instances[instanceId].players, ", ") .. "^7")
    print("^2[DUEL] Envoi de l'event duel:instanceCreated au client^7")
    
    -- Confirmer au client
    TriggerClientEvent('duel:instanceCreated', source, instanceId, weapon, map)
    
    -- Notifier tous les clients de la mise à jour des arènes disponibles
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
    
    print("^2[DUEL] ========== FIN EVENT CREATEARENA ==========^7")
end)
print("^2[DUEL] Event duel:createArena enregistré avec succès^7")

-- Event pour rejoindre une arène existante
print("^2[DUEL] Enregistrement de l'event duel:joinArena^7")
RegisterNetEvent('duel:joinArena')
AddEventHandler('duel:joinArena', function(weapon)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^2[DUEL] ========== EVENT JOINARENA SERVEUR ==========^7")
    print("^2[DUEL] Joueur: " .. playerName .. " (ID: " .. source .. ") veut rejoindre une arène^7")
    print("^2[DUEL] Arme sélectionnée: " .. tostring(weapon) .. "^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur " .. source .. " déjà dans l'instance " .. currentInstanceId .. "^7")
        return
    end
    
    -- Trouver une arène disponible avec la même arme
    local targetInstanceId = nil
    for instanceId, instance in pairs(instances) do
        if instance.status == "waiting" and instance.weapon == weapon and #instance.players < instance.maxPlayers then
            targetInstanceId = instanceId
            break
        end
    end
    
    if not targetInstanceId then
        print("^1[DUEL] Aucune arène disponible avec l'arme " .. weapon .. "^7")
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Aucune arène disponible avec cette arme. Créez votre propre arène !"}
        })
        return
    end
    
    -- Ajouter le joueur à l'instance
    local success, message = addPlayerToInstance(targetInstanceId, source)
    if not success then
        print("^1[DUEL] Impossible d'ajouter le joueur à l'instance: " .. message .. "^7")
        return
    end
    
    local instance = instances[targetInstanceId]
    print("^2[DUEL] Joueur " .. source .. " ajouté à l'instance " .. targetInstanceId .. "^7")
    
    -- Téléporter le joueur vers l'arène
    TriggerClientEvent('duel:instanceCreated', source, targetInstanceId, weapon, instance.arena)
    
    -- Notifier le créateur qu'un adversaire a rejoint
    local creatorName = GetPlayerName(instance.creator) or "Joueur " .. instance.creator
    TriggerClientEvent('duel:opponentJoined', instance.creator, playerName)
    TriggerClientEvent('duel:opponentJoined', source, creatorName)
    
    -- Mettre à jour la liste des arènes disponibles pour tous
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
    
    print("^2[DUEL] ========== FIN EVENT JOINARENA ==========^7")
end)
print("^2[DUEL] Event duel:joinArena enregistré avec succès^7")

-- Event pour rejoindre une arène spécifique
print("^2[DUEL] Enregistrement de l'event duel:joinSpecificArena^7")
RegisterNetEvent('duel:joinSpecificArena')
AddEventHandler('duel:joinSpecificArena', function(arenaId, weapon)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^2[DUEL] ========== EVENT JOIN SPECIFIC ARENA ==========^7")
    print("^2[DUEL] Joueur: " .. playerName .. " (ID: " .. source .. ") veut rejoindre l'arène " .. arenaId .. "^7")
    print("^2[DUEL] Arme sélectionnée: " .. tostring(weapon) .. "^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur " .. source .. " déjà dans l'instance " .. currentInstanceId .. "^7")
        return
    end
    
    -- Vérifier que l'arène existe
    local targetInstance = instances[arenaId]
    if not targetInstance then
        print("^1[DUEL] Arène " .. arenaId .. " non trouvée^7")
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Cette arène n'existe plus !"}
        })
        return
    end
    
    -- Vérifier que l'arène est disponible
    if targetInstance.status ~= "waiting" or #targetInstance.players >= targetInstance.maxPlayers then
        print("^1[DUEL] Arène " .. arenaId .. " non disponible (statut: " .. targetInstance.status .. ", joueurs: " .. #targetInstance.players .. ")^7")
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Cette arène n'est plus disponible !"}
        })
        return
    end
    
    -- Vérifier que l'arme correspond
    if targetInstance.weapon ~= weapon then
        print("^1[DUEL] Arme incompatible pour l'arène " .. arenaId .. " (attendu: " .. targetInstance.weapon .. ", reçu: " .. weapon .. ")^7")
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"[DUEL]", "Arme incompatible avec cette arène !"}
        })
        return
    end
    
    -- Ajouter le joueur à l'instance
    local success, message = addPlayerToInstance(arenaId, source)
    if not success then
        print("^1[DUEL] Impossible d'ajouter le joueur à l'instance: " .. message .. "^7")
        return
    end
    
    print("^2[DUEL] Joueur " .. source .. " ajouté à l'arène " .. arenaId .. "^7")
    
    -- Téléporter le joueur vers l'arène
    TriggerClientEvent('duel:instanceCreated', source, arenaId, weapon, targetInstance.arena)
    
    -- Notifier le créateur qu'un adversaire a rejoint
    local creatorName = GetPlayerName(targetInstance.creator) or "Joueur " .. targetInstance.creator
    TriggerClientEvent('duel:opponentJoined', targetInstance.creator, playerName)
    TriggerClientEvent('duel:opponentJoined', source, creatorName)
    
    -- Mettre à jour la liste des arènes disponibles pour tous
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
    
    print("^2[DUEL] ========== FIN EVENT JOIN SPECIFIC ARENA ==========^7")
end)
print("^2[DUEL] Event duel:joinSpecificArena enregistré avec succès^7")

-- Event pour obtenir les arènes disponibles
RegisterNetEvent('duel:getAvailableArenas')
AddEventHandler('duel:getAvailableArenas', function()
    local source = source
    local availableArenas = getAvailableArenas()
    print("^3[DUEL] Envoi de " .. #availableArenas .. " arène(s) disponible(s) au joueur " .. source .. "^7")
    TriggerClientEvent('duel:updateAvailableArenas', source, availableArenas)
end)

-- Event pour quitter une arène (supprimer l'instance)
RegisterNetEvent('duel:quitArena')
AddEventHandler('duel:quitArena', function()
    local source = source
    local playerName = GetPlayerName(source) or "Joueur " .. source
    
    print("^3[DUEL] " .. playerName .. " (ID: " .. source .. ") quitte son arène^7")
    
    -- Trouver et supprimer l'instance du joueur
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        print("^3[DUEL] Suppression de l'instance " .. instanceId .. " pour le joueur " .. source .. "^7")
        deleteInstance(instanceId)
        TriggerClientEvent('duel:instanceDeleted', source)
    else
        print("^1[DUEL] Aucune instance trouvée pour le joueur " .. source .. "^7")
    end
end)

-- Nettoyer les instances quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur inconnu"
    
    print("^1[DUEL] " .. playerName .. " s'est déconnecté, nettoyage de son instance^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        print("^1[DUEL] Suppression de l'instance " .. instanceId .. " suite à déconnexion de " .. playerName .. "^7")
        deleteInstance(instanceId)
    else
        print("^3[DUEL] Aucune instance à nettoyer pour " .. playerName .. "^7")
    end
end)

-- Commande admin pour voir les instances actives
RegisterCommand('duel_instances', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, "command.duel_instances") then
        print("^2[DUEL] Instances actives:^7")
        local count = 0
        for instanceId, instance in pairs(instances) do
            count = count + 1
            local creatorName = GetPlayerName(instance.creator) or "Joueur déconnecté"
            local timeElapsed = os.time() - instance.created
            print("^3  Instance " .. instanceId .. ": " .. creatorName .. " (" .. instance.creator .. ") - Arène: " .. instance.arena .. " - Arme: " .. instance.weapon .. "^7")
            print("^3    Joueurs: " .. #instance.players .. "/" .. instance.maxPlayers .. " - Statut: " .. instance.status .. " - Créée il y a " .. timeElapsed .. " secondes^7")
        end
        if count == 0 then
            print("^1  Aucune instance active^7")
        end
        
        if source ~= 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"[DUEL]", count .. " instance(s) active(s). Voir console F8 pour détails."}
            })
        end
    end
end, false)

-- Nettoyage automatique des instances anciennes (toutes les 2 heures)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(7200000) -- 2 heures
        
        local currentTime = os.time()
        local toDelete = {}
        
        for instanceId, instance in pairs(instances) do
            -- Supprimer les instances de plus de 2 heures
            if currentTime - instance.created > 7200 then
                table.insert(toDelete, instanceId)
            end
        end
        
        for _, instanceId in ipairs(toDelete) do
            print("^1[DUEL] Instance " .. instanceId .. " supprimée automatiquement (trop ancienne - plus de 2h)^7")
            -- Informer le joueur que son instance a été supprimée
            local instance = instances[instanceId]
            if instance and instance.creator then
                TriggerClientEvent('duel:instanceDeleted', instance.creator)
            end
            deleteInstance(instanceId)
        end
    end
end)

print("^2[DUEL] Server script complètement initialisé^7")