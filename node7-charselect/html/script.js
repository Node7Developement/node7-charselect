(() => {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';

    const state = {
        slots: 4,
        characters: [],
        selectedSlot: null,
        selectedCharacter: null
    };

    const app = document.getElementById('app');
    const characterList = document.getElementById('characterList');
    const emptyPanel = document.getElementById('emptyPanel');
    const infoPanel = document.getElementById('infoPanel');
    const createPanel = document.getElementById('createPanel');
    const deletePanel = document.getElementById('deletePanel');
    const infoBody = document.getElementById('infoBody');
    const playButton = document.getElementById('playButton');
    const deleteButton = document.getElementById('deleteButton');
    const slotCounter = document.getElementById('slotCounter');
    const createSlotBadge = document.getElementById('createSlotBadge');
    const characterTitle = document.getElementById('characterTitle');
    const characterSubtitle = document.getElementById('characterSubtitle');
    const characterInitials = document.getElementById('characterInitials');
    const deleteMessage = document.getElementById('deleteMessage');
    const toast = document.getElementById('toast');

    function post(name, data = {}) {
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).then((response) => response.json()).catch(() => ({ ok: false, error: 'nui_failed' }));
    }

    function showToast(message) {
        toast.textContent = friendlyError(message);
        toast.classList.remove('hidden');
        window.clearTimeout(showToast.timer);
        showToast.timer = window.setTimeout(() => toast.classList.add('hidden'), 2800);
    }

    function friendlyError(value) {
        const raw = String(value || 'Something went wrong.');
        const messages = {
            server_timeout: 'The server did not respond in time.',
            missing_slot: 'Select a character slot first.',
            missing_character: 'No character was selected.',
            create_failed: 'Character creation failed.',
            delete_failed: 'Character deletion failed.',
            nui_failed: 'The interface could not contact the resource.'
        };
        return messages[raw] || raw.replace(/_/g, ' ');
    }

    function escapeHtml(value) {
        return String(value ?? '').replace(/[&<>'"]/g, (char) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
        }[char]));
    }

    function fullName(character) {
        const info = character?.charinfo || {};
        return `${info.firstname || 'Unknown'} ${info.lastname || 'Unknown'}`.trim();
    }

    function initials(character) {
        const info = character?.charinfo || {};
        const first = String(info.firstname || 'N').trim().charAt(0);
        const last = String(info.lastname || '7').trim().charAt(0);
        return `${first}${last}`.toUpperCase();
    }

    function genderLabel(value) {
        value = String(value || '').toLowerCase();
        return value === 'female' || value === 'woman' || value === '0' ? 'Female' : 'Male';
    }

    function moneyValue(value) {
        return Number(value || 0).toLocaleString('en-US');
    }

    function getCharacterBySlot(slot) {
        return state.characters.find((character) => Number(character.slot || character.cid) === Number(slot));
    }

    function setView(name) {
        emptyPanel.classList.toggle('hidden', name !== 'empty');
        infoPanel.classList.toggle('hidden', name !== 'info');
        createPanel.classList.toggle('hidden', name !== 'create');
    }

    function updateCounter() {
        slotCounter.textContent = `${state.characters.length} / ${state.slots} Characters`;
    }

    function renderCharacters() {
        characterList.innerHTML = '';
        for (let slot = 1; slot <= state.slots; slot += 1) {
            const character = getCharacterBySlot(slot);
            const button = document.createElement('button');
            button.type = 'button';
            button.className = `character${character ? '' : ' empty'}`;
            button.dataset.slot = String(slot);
            if (state.selectedSlot === slot) button.classList.add('selected');

            if (character) {
                const info = character.charinfo || {};
                const job = character.job || {};
                button.innerHTML = `
                    <span class="slot-number">${String(slot).padStart(2, '0')}</span>
                    <span class="character-copy">
                        <span class="character-name">${escapeHtml(fullName(character))}</span>
                        <span class="character-meta">${escapeHtml(job.label || job.name || 'Unemployed')} · ${escapeHtml(genderLabel(info.gender))}</span>
                    </span>
                    <span class="character-state">›</span>
                `;
            } else {
                button.innerHTML = `
                    <span class="slot-number">${String(slot).padStart(2, '0')}</span>
                    <span class="character-copy">
                        <span class="character-name">Empty Slot</span>
                        <span class="character-meta">Create a new character</span>
                    </span>
                    <span class="character-state">+</span>
                `;
            }
            characterList.appendChild(button);
        }
        updateCounter();
    }

    function renderInfo(character) {
        const info = character?.charinfo || {};
        const money = character?.money || {};
        const job = character?.job || {};

        characterTitle.textContent = fullName(character);
        characterSubtitle.textContent = `Slot ${state.selectedSlot} · ${character.citizenid || 'Citizen record'}`;
        characterInitials.textContent = initials(character);
        deleteMessage.textContent = `${fullName(character)} and all associated progress will be permanently removed.`;

        const details = [
            ['Birthdate', info.birthdate || 'Unknown'],
            ['Gender', genderLabel(info.gender)],
            ['Nationality', info.nationality || 'Unknown'],
            ['Occupation', job.label || job.name || 'Unemployed'],
            ['Cash', `$${moneyValue(money.cash)}`, true],
            ['Citizen ID', character.citizenid || 'Unknown']
        ];

        infoBody.innerHTML = details.map(([label, value, accent]) => `
            <div class="detail-card${accent ? ' accent' : ''}">
                <span>${escapeHtml(label)}</span>
                <strong>${escapeHtml(value)}</strong>
            </div>
        `).join('');
    }

    function selectSlot(slot) {
        state.selectedSlot = Number(slot);
        state.selectedCharacter = getCharacterBySlot(slot) || null;

        renderCharacters();
        playButton.disabled = false;

        if (state.selectedCharacter) {
            deleteButton.disabled = false;
            deleteButton.classList.remove('hidden');
            renderInfo(state.selectedCharacter);
            setView('info');
        } else {
            deleteButton.disabled = true;
            deleteButton.classList.add('hidden');
            createSlotBadge.textContent = `Slot ${state.selectedSlot}`;
            setView('create');
            window.setTimeout(() => document.getElementById('firstName').focus(), 80);
        }
    }

    function setCharacters(characters, slots) {
        state.characters = Array.isArray(characters) ? characters : [];
        state.slots = Number(slots || state.slots || 4);
        state.selectedSlot = null;
        state.selectedCharacter = null;
        playButton.disabled = true;
        deleteButton.disabled = true;
        deleteButton.classList.add('hidden');
        renderCharacters();
        setView('empty');
    }

    function sanitizeCreateData() {
        return {
            slot: state.selectedSlot,
            charinfo: {
                firstname: document.getElementById('firstName').value.trim(),
                lastname: document.getElementById('lastName').value.trim(),
                birthdate: document.getElementById('birthdate').value,
                nationality: document.getElementById('nationality').value.trim() || 'American',
                gender: document.getElementById('gender').value
            }
        };
    }

    async function enterWorld(character, button) {
        if (!character || !character.citizenid) {
            if (button) button.disabled = false;
            showToast('No character selected.');
            return false;
        }

        if (button) button.disabled = true;
        const result = await post('selectCharacter', {
            citizenid: character.citizenid
        });

        if (!result.ok) {
            if (button) button.disabled = false;
            showToast(result.error || 'Character load failed.');
            return false;
        }

        return true;
    }

    async function createCharacter() {
        if (!state.selectedSlot) return showToast('Select a slot first.');
        const payload = sanitizeCreateData();
        if (!payload.charinfo.firstname || !payload.charinfo.lastname || !payload.charinfo.birthdate) {
            return showToast('Fill in first name, last name, and birthdate.');
        }

        const button = document.getElementById('createConfirmButton');
        button.disabled = true;
        const result = await post('createCharacter', payload);
        button.disabled = false;

        if (!result.ok) {
            button.disabled = false;
            return showToast(result.error || 'Character create failed.');
        }

        await enterWorld(result.character, button);
    }

    async function deleteCharacter() {
        if (!state.selectedCharacter?.citizenid) return;

        const button = document.getElementById('deleteConfirmButton');
        button.disabled = true;
        const result = await post('deleteCharacter', { citizenid: state.selectedCharacter.citizenid });
        button.disabled = false;

        if (!result.ok) return showToast(result.error || 'Delete failed.');
        deletePanel.classList.add('hidden');
        const refresh = await post('refresh');
        if (refresh.ok) setCharacters(refresh.characters, refresh.slots);
    }

    characterList.addEventListener('click', (event) => {
        const item = event.target.closest('.character');
        if (item) selectSlot(Number(item.dataset.slot));
    });


    playButton.addEventListener('click', () => {
        if (!state.selectedSlot) return;
        if (state.selectedCharacter) enterWorld(state.selectedCharacter, playButton);
        else setView('create');
    });

    deleteButton.addEventListener('click', () => {
        if (state.selectedCharacter) deletePanel.classList.remove('hidden');
    });

    document.getElementById('disconnectButton').addEventListener('click', () => post('disconnect'));
    document.getElementById('createBackButton').addEventListener('click', () => {
        state.selectedSlot = null;
        state.selectedCharacter = null;
        renderCharacters();
        setView('empty');
    });
    document.getElementById('createConfirmButton').addEventListener('click', createCharacter);
    document.getElementById('deleteCancelButton').addEventListener('click', () => deletePanel.classList.add('hidden'));
    document.getElementById('deleteConfirmButton').addEventListener('click', deleteCharacter);

    window.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !deletePanel.classList.contains('hidden')) {
            deletePanel.classList.add('hidden');
        }
    });

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.action === 'open') {
            state.slots = Number(data.slots || state.slots || 4);
            app.classList.remove('hidden');
            setCharacters([], state.slots);
            post('ready');
            return;
        }
        if (data.action === 'characters') {
            if (data.error) showToast(data.error);
            setCharacters(data.characters || [], data.slots || state.slots);
            return;
        }
        if (data.action === 'close') {
            app.classList.add('hidden');
            deletePanel.classList.add('hidden');
        }
    });
})();
