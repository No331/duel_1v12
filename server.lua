print("^2[DUEL] Server script chargé^7")

-- Système d'instances
local instances = {}
local nextInstanceId = 1

-- Configuration du système de manches
local MAX_ROUNDS = 5
local ROUNDS_TO_WIN = 3

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
        status = "waiting",
        created = os.time(),
        rounds = {
            currentRound = 0,
            maxRounds = MAX_ROUNDS,
            scores = {},
            isActive = false
        }
    }
    
    print("^3[DUEL] Instance " .. instanceId .. " créée par le joueur " .. playerId .. " (arène: " .. arenaType .. ", arme: " .. weapon .. ")^7")
    return instanceId
end

-- Fonction pour supprimer une instance
function deleteInstance(instanceId)
    if instances[instanceId] then
        local instance = instances[instanceId]
        
        -- Notifier tous les joueurs de l'instance
        for _, playerId in ipairs(instance.players) do
            TriggerClientEvent('duel:instanceDeleted', playerId)
        end
        
        print("^1[DUEL] Instance " .. instanceId .. " supprimée^7")
        instances[instanceId] = nil
        
        -- Mettre à jour la liste des arènes disponibles
        local availableArenas = getAvailableArenas()
        TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
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

-- Fonction pour obtenir les arènes disponibles
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
    
    -- Initialiser le score du joueur
    instance.rounds.scores[playerId] = 0
    
    -- Si l'instance est maintenant pleine, changer le statut et activer les manches
    if #instance.players >= instance.maxPlayers then
        instance.status = "active"
        instance.rounds.isActive = true
        
        -- Initialiser les scores pour tous les joueurs
        for _, pid in ipairs(instance.players) do
            instance.rounds.scores[pid] = 0
        end
        
        print("^2[DUEL] Instance " .. instanceId .. " maintenant active avec " .. #instance.players .. " joueurs^7")
    end
    
    return true, "Joueur ajouté avec succès"
end

-- Fonction pour gérer la mort d'un joueur
function handlePlayerDeath(instanceId, deadPlayerId, killerPlayerId)
    local instance = instances[instanceId]
    if not instance then 
        print("^1[DUEL] Instance " .. instanceId .. " non trouvée^7")
        return 
    end
    
    -- Vérifier que l'instance est active
    if not instance.rounds.isActive then
        print("^1[DUEL] Instance " .. instanceId .. " non active^7")
        return
    end
    
    -- Vérifier qu'on a bien 2 joueurs
    if #instance.players ~= 2 then
        print("^1[DUEL] Instance " .. instanceId .. " n'a pas exactement 2 joueurs^7")
        return
    end
    
    -- Vérifier que le tueur est valide et différent du mort
    if not killerPlayerId or killerPlayerId == deadPlayerId then
        print("^1[DUEL] Tueur invalide ou suicide - pas de point^7")
        return
    end
    
    -- Vérifier que le tueur fait partie du duel
    local killerInDuel = false
    for _, pid in ipairs(instance.players) do
        if pid == killerPlayerId then
            killerInDuel = true
            break
        end
    end
    
    if not killerInDuel then
        print("^1[DUEL] Le tueur " .. killerPlayerId .. " ne fait pas partie du duel^7")
        return
    end
    
    -- Incrémenter la manche
    instance.rounds.currentRound = instance.rounds.currentRound + 1
    
    -- Ajouter un point au tueur
    instance.rounds.scores[killerPlayerId] = (instance.rounds.scores[killerPlayerId] or 0) + 1
    
    local killerScore = instance.rounds.scores[killerPlayerId]
    local deadScore = instance.rounds.scores[deadPlayerId] or 0
    
    print("^2[DUEL] Manche " .. instance.rounds.currentRound .. "/" .. MAX_ROUNDS .. " - Tueur: " .. killerPlayerId .. " (Score: " .. killerScore .. ") - Mort: " .. deadPlayerId .. " (Score: " .. deadScore .. ")^7")
    
    -- Vérifier les conditions de fin
    local duelFinished = false
    local winner = nil
    local winnerName = ""
    
    -- Quelqu'un a atteint le nombre de manches pour gagner
    if killerScore >= ROUNDS_TO_WIN then
        duelFinished = true
        winner = killerPlayerId
        winnerName = GetPlayerName(killerPlayerId) or ("Joueur " .. killerPlayerId)
        print("^2[DUEL] " .. winnerName .. " gagne le duel avec " .. killerScore .. " manches !^7")
    -- On a atteint le maximum de manches
    elseif instance.rounds.currentRound >= MAX_ROUNDS then
        duelFinished = true
        
        -- Trouver le joueur avec le plus de points
        local maxScore = 0
        local winners = {}
        
        for playerId, score in pairs(instance.rounds.scores) do
            if score > maxScore then
                maxScore = score
                winners = {playerId}
            elseif score == maxScore then
                table.insert(winners, playerId)
            end
        end
        
        if #winners == 1 then
            winner = winners[1]
            winnerName = GetPlayerName(winner) or ("Joueur " .. winner)
            print("^2[DUEL] " .. winnerName .. " gagne aux points avec " .. maxScore .. " manches !^7")
        else
            print("^3[DUEL] Égalité parfaite !^7")
        end
    end
    
    -- Envoyer les résultats aux joueurs
    for _, playerId in ipairs(instance.players) do
        local playerScore = instance.rounds.scores[playerId] or 0
        local opponentId = nil
        local opponentScore = 0
        
        -- Trouver l'adversaire
        for _, pid in ipairs(instance.players) do
            if pid ~= playerId then
                opponentId = pid
                opponentScore = instance.rounds.scores[pid] or 0
                break
            end
        end
        
        TriggerClientEvent('duel:roundResult', playerId, {
            currentRound = instance.rounds.currentRound,
            maxRounds = MAX_ROUNDS,
            myScore = playerScore,
            opponentScore = opponentScore,
            killerPlayerId = killerPlayerId,
            deadPlayerId = deadPlayerId,
            duelFinished = duelFinished,
            winner = winner,
            winnerName = winnerName,
            amIWinner = (winner == playerId)
        })
    end
    
    -- Si le duel est terminé, supprimer l'instance après un délai
    if duelFinished then
        instance.rounds.isActive = false
        
        Citizen.SetTimeout(5000, function()
            deleteInstance(instanceId)
        end)
    end
end

-- Event pour signaler une mort
RegisterNetEvent('duel:playerDied')
AddEventHandler('duel:playerDied', function(killerPlayerId)
    local source = source
    
    print("^2[DUEL] Mort signalée - Mort: " .. source .. ", Tueur: " .. tostring(killerPlayerId) .. "^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId and instance then
        handlePlayerDeath(instanceId, source, killerPlayerId)
    else
        print("^1[DUEL] Aucune instance trouvée pour le joueur mort " .. source .. "^7")
    end
end)

-- Event pour créer une arène
RegisterNetEvent('duel:createArena')
AddEventHandler('duel:createArena', function(weapon, map)
    local source = source
    local playerName = GetPlayerName(source) or ("Joueur " .. source)
    
    print("^2[DUEL] " .. playerName .. " crée une arène - Arme: " .. weapon .. ", Map: " .. map .. "^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        deleteInstance(currentInstanceId)
    end
    
    -- Créer une nouvelle instance
    local instanceId = createInstance(source, map, weapon)
    
    -- Confirmer au client
    TriggerClientEvent('duel:instanceCreated', source, instanceId, weapon, map)
    
    -- Mettre à jour la liste des arènes disponibles
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
end)

-- Event pour rejoindre une arène spécifique
RegisterNetEvent('duel:joinSpecificArena')
AddEventHandler('duel:joinSpecificArena', function(arenaId, weapon)
    local source = source
    local playerName = GetPlayerName(source) or ("Joueur " .. source)
    
    print("^2[DUEL] " .. playerName .. " rejoint l'arène " .. arenaId .. "^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur déjà dans une instance^7")
        return
    end
    
    -- Vérifier que l'arène existe et est disponible
    local targetInstance = instances[arenaId]
    if not targetInstance or targetInstance.status ~= "waiting" or #targetInstance.players >= targetInstance.maxPlayers then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {"[DUEL]", "Cette arène n'est plus disponible !"}
        })
        return
    end
    
    -- Vérifier la compatibilité de l'arme
    if targetInstance.weapon ~= weapon then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {"[DUEL]", "Arme incompatible avec cette arène !"}
        })
        return
    end
    
    -- Ajouter le joueur à l'instance
    local success, message = addPlayerToInstance(arenaId, source)
    if not success then
        print("^1[DUEL] Erreur: " .. message .. "^7")
        return
    end
    
    -- Téléporter le joueur vers l'arène
    TriggerClientEvent('duel:instanceCreated', source, arenaId, weapon, targetInstance.arena)
    
    -- Notifier les joueurs qu'un adversaire a rejoint
    local creatorName = GetPlayerName(targetInstance.creator) or ("Joueur " .. targetInstance.creator)
    TriggerClientEvent('duel:opponentJoined', targetInstance.creator, playerName)
    TriggerClientEvent('duel:opponentJoined', source, creatorName)
    
    -- Mettre à jour la liste des arènes disponibles
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', -1, availableArenas)
end)

-- Event pour obtenir les arènes disponibles
RegisterNetEvent('duel:getAvailableArenas')
AddEventHandler('duel:getAvailableArenas', function()
    local source = source
    local availableArenas = getAvailableArenas()
    TriggerClientEvent('duel:updateAvailableArenas', source, availableArenas)
end)

-- Event pour quitter une arène
RegisterNetEvent('duel:quitArena')
AddEventHandler('duel:quitArena', function()
    local source = source
    local playerName = GetPlayerName(source) or ("Joueur " .. source)
    
    print("^3[DUEL] " .. playerName .. " quitte son arène^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
    end
end)

-- Nettoyer les instances quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source) or "Joueur inconnu"
    
    print("^1[DUEL] " .. playerName .. " s'est déconnecté^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
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
            print("^3  Instance " .. instanceId .. ": " .. creatorName .. " - Arène: " .. instance.arena .. " - Statut: " .. instance.status .. "^7")
            print("^3    Joueurs: " .. #instance.players .. "/" .. instance.maxPlayers .. " - Manche: " .. instance.rounds.currentRound .. "/" .. instance.rounds.maxRounds .. "^7")
        end
        if count == 0 then
            print("^1  Aucune instance active^7")
        end
        
        if source ~= 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"[DUEL]", count .. " instance(s) active(s). Voir console F8 pour détails."}
            })
        end
    end
end, false)

print("^2[DUEL] Server script initialisé^7")