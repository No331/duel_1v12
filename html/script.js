console.log('[DUEL] Script JS chargé');

let selectedWeapon = null;
let selectedMap = null;
let availableArenas = [];
let arenaListModal = null;

// Écouter les messages du client Lua
window.addEventListener('message', function(event) {
    const data = event.data;
    console.log('[DUEL] Message reçu:', data);
    
    switch(data.type) {
        case 'openMenu':
            openMenu();
            break;
        case 'closeMenu':
            closeMenu();
            break;
        case 'updateArenas':
            updateAvailableArenas(data.arenas);
            break;
    }
});

function openMenu() {
    console.log('[DUEL] Ouverture du menu');
    const app = document.getElementById('app');
    app.classList.remove('hidden');
}

function closeMenu() {
    console.log('[DUEL] Fermeture du menu');
    const app = document.getElementById('app');
    app.classList.add('hidden');
    
    // Reset des sélections
    selectedWeapon = null;
    selectedMap = null;
    updateJoinButton();
    
    // Reset de l'affichage
    const selectedWeaponSpan = document.getElementById('selectedWeapon');
    const selectedMapSpan = document.getElementById('selectedMap');
    if (selectedWeaponSpan) selectedWeaponSpan.textContent = 'Aucun';
    if (selectedMapSpan) selectedMapSpan.textContent = 'Aucune';
    
    // Retirer toutes les sélections visuelles
    document.querySelectorAll('.weapon-card.selected').forEach(card => {
        card.classList.remove('selected');
    });
    document.querySelectorAll('.map-card.selected').forEach(card => {
        card.classList.remove('selected');
    });
}

function updateJoinButton() {
    const createBtn = document.getElementById('createBtn');
    const joinBtn = document.getElementById('joinBtn');
    const selectedWeaponSpan = document.getElementById('selectedWeapon');
    const selectedMapSpan = document.getElementById('selectedMap');
    const playersCountSpan = document.getElementById('playersCount');
    
    // Mettre à jour l'affichage des sélections
    if (selectedWeaponSpan) {
        selectedWeaponSpan.textContent = selectedWeapon ? selectedWeapon.toUpperCase() : 'Aucun';
    }
    if (selectedMapSpan) {
        selectedMapSpan.textContent = selectedMap ? selectedMap.toUpperCase() : 'Aucune';
    }
    
    // Mettre à jour le compteur de joueurs
    if (playersCountSpan) {
        playersCountSpan.textContent = availableArenas.length + '/2';
    }
    
    // Activer le bouton créer si au moins une arme et une map sont sélectionnées
    if (selectedWeapon && selectedMap) {
        createBtn.disabled = false;
    } else {
        createBtn.disabled = true;
    }
    
    // Le bouton rejoindre est toujours actif
    joinBtn.disabled = false;
}

// Event listeners
document.addEventListener('DOMContentLoaded', function() {
    console.log('[DUEL] DOM chargé');
    
    // Sélection des armes
    const weaponCards = document.querySelectorAll('.weapon-card');
    weaponCards.forEach(card => {
        card.addEventListener('click', function() {
            // Retirer la sélection précédente
            weaponCards.forEach(c => c.classList.remove('selected'));
            // Ajouter la sélection à la carte cliquée
            this.classList.add('selected');
            selectedWeapon = this.dataset.weapon;
            console.log('[DUEL] Arme sélectionnée:', selectedWeapon);
            updateJoinButton();
        });
    });
    
    // Sélection des maps
    const mapCards = document.querySelectorAll('.map-card');
    mapCards.forEach(card => {
        card.addEventListener('click', function() {
            // Retirer la sélection précédente
            mapCards.forEach(c => c.classList.remove('selected'));
            // Ajouter la sélection à la carte cliquée
            this.classList.add('selected');
            selectedMap = this.dataset.map;
            console.log('[DUEL] Map sélectionnée:', selectedMap);
            updateJoinButton();
        });
    });
    
    // Bouton créer l'arène
    const createBtn = document.getElementById('createBtn');
    if (createBtn) {
        createBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton créer cliqué');
            
            if (selectedWeapon && selectedMap) {
                console.log('[DUEL] Créer l\'arène avec:', selectedWeapon, selectedMap);
                
                const payload = {
                    weapon: selectedWeapon,
                    map: selectedMap
                };
                
                fetch(`https://duel_1v1/createArena`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(payload)
                }).then(response => {
                    console.log('[DUEL] Réponse créer arène - Status:', response.status);
                    return response.text();
                }).then(text => {
                    console.log('[DUEL] Réponse texte:', text);
                }).catch(err => {
                    console.log('[DUEL] Erreur créer arène:', err);
                });
            }
        });
    }
    
    // Bouton rejoindre une arène
    const joinBtn = document.getElementById('joinBtn');
    if (joinBtn) {
        joinBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton rejoindre cliqué');
            
            // Toujours permettre de voir la liste des arènes
            showArenaList();
        });
    }
    
    // Bouton fermer
    const closeBtn = document.getElementById('closeBtn');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton fermer cliqué');
            fetch(`https://duel_1v1/closeMenu`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            }).then(response => {
                console.log('[DUEL] Menu fermé');
            }).catch(err => {
                console.log('[DUEL] Erreur fermeture:', err);
            });
        });
    }
    
    // Bouton fermer modal
    const closeModalBtn = document.getElementById('closeModalBtn');
    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', function() {
            hideArenaList();
        });
    }
    
    // Fermer modal en cliquant à l'extérieur
    arenaListModal = document.getElementById('arenaListModal');
    if (arenaListModal) {
        arenaListModal.addEventListener('click', function(e) {
            if (e.target === arenaListModal) {
                hideArenaList();
            }
        });
    }
});

// Fermer avec Échap
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        console.log('[DUEL] Échap pressé');
        fetch(`https://duel_1v1/closeMenu`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }).catch(err => console.log('[DUEL] Erreur:', err));
    }
});

function updateAvailableArenas(arenas) {
    console.log('[DUEL] Mise à jour des arènes disponibles:', arenas);
    availableArenas = arenas || [];
    
    // Ajouter les noms des créateurs pour l'affichage
    availableArenas.forEach(arena => {
        if (!arena.creatorName) {
            arena.creatorName = `Joueur ${arena.creator}`;
        }
    });
    
    updateJoinButton();
}

function showArenaList() {
    console.log('[DUEL] Affichage de la liste des arènes');
    
    // Afficher TOUTES les arènes disponibles
    const compatibleArenas = availableArenas || [];
    
    const arenaList = document.getElementById('arenaList');
    const noArenas = document.getElementById('noArenas');
    const modal = document.getElementById('arenaListModal');
    
    // Vider la liste
    arenaList.innerHTML = '';
    
    if (compatibleArenas.length === 0) {
        arenaList.classList.add('hidden');
        noArenas.classList.remove('hidden');
    } else {
        arenaList.classList.remove('hidden');
        noArenas.classList.add('hidden');
        
        compatibleArenas.forEach(arena => {
            const arenaItem = document.createElement('div');
            arenaItem.className = 'arena-item';
            arenaItem.dataset.arenaId = arena.id;
            
            arenaItem.innerHTML = `
                <div class="arena-item-header">
                    <span class="arena-name">${arena.arena}</span>
                    <span class="arena-weapon">${arena.weapon}</span>
                </div>
                <div class="arena-info">
                    <span class="arena-creator">Créé par: ${arena.creatorName}</span>
                    <span class="arena-players">${arena.players}/${arena.maxPlayers} joueurs</span>
                </div>
            `;
            
            arenaItem.addEventListener('click', function() {
                joinSpecificArena(arena.id, arena.weapon);
            });
            
            arenaList.appendChild(arenaItem);
        });
    }
    
    modal.classList.remove('hidden');
}

function hideArenaList() {
    console.log('[DUEL] Masquage de la liste des arènes');
    const modal = document.getElementById('arenaListModal');
    modal.classList.add('hidden');
}

function joinSpecificArena(arenaId, arenaWeapon) {
    console.log('[DUEL] Rejoindre l\'arène spécifique:', arenaId);
    
    hideArenaList();
    
    const payload = {
        arenaId: arenaId,
        weapon: arenaWeapon
    };
    
    fetch(`https://duel_1v1/joinSpecificArena`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    }).then(response => {
        console.log('[DUEL] Réponse rejoindre arène spécifique - Status:', response.status);
        return response.text();
    }).then(text => {
        console.log('[DUEL] Réponse texte:', text);
    }).catch(err => {
        console.log('[DUEL] Erreur rejoindre arène spécifique:', err);
    });
}