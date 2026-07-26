(() => {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';
    const state = { slots: 4, characters: [], selectedSlot: null, selectedCharacter: null, gender: 'male' };

    const $ = (id) => document.getElementById(id);
    const app = $('app');
    const characterList = $('characterList');
    const emptyPanel = $('emptyPanel');
    const infoPanel = $('infoPanel');
    const createPanel = $('createPanel');
    const deletePanel = $('deletePanel');
    const infoBody = $('infoBody');
    const playButton = $('playButton');
    const deleteButton = $('deleteButton');
    const slotCounter = $('slotCounter');
    const createSlotBadge = $('createSlotBadge');
    const characterTitle = $('characterTitle');
    const characterSubtitle = $('characterSubtitle');
    const characterInitials = $('characterInitials');
    const deleteMessage = $('deleteMessage');
    const toast = $('toast');
    const transitionOverlay = $('transitionOverlay');
    const transitionKicker = $('transitionKicker');
    const transitionTitle = $('transitionTitle');
    const transitionName = $('transitionName');
    const transitionStage = $('transitionStage');
    const transitionHint = $('transitionHint');
    const transitionProgress = $('transitionProgress');
    const locationCard = $('locationCard');
    const locationKicker = $('locationKicker');
    const locationTitle = $('locationTitle');
    const locationSubtitle = $('locationSubtitle');
    const locationTime = $('locationTime');

    function post(name, data = {}) {
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).then((response) => response.json()).catch(() => ({ ok: false, error: 'nui_failed' }));
    }

    function setTransition(data = {}) {
        transitionKicker.textContent = data.kicker || 'NODE7 FRONTIER';
        transitionTitle.textContent = data.title || 'LOADING CHARACTER';
        transitionName.textContent = data.name || 'Preparing your story';
        transitionStage.textContent = data.stage || 'Retrieving character data';
        transitionHint.textContent = data.hint || 'Please remain patient while the frontier is prepared.';
        transitionProgress.style.width = `${Math.max(0, Math.min(100, Number(data.progress || 0)))}%`;
        clearTimeout(hideTransition.timer);
        transitionOverlay.classList.remove('hidden', 'closing');
    }

    function hideTransition() {
        clearTimeout(hideTransition.timer);
        transitionOverlay.classList.add('closing');
        hideTransition.timer = setTimeout(() => {
            transitionOverlay.classList.add('hidden');
            transitionOverlay.classList.remove('closing');
            transitionProgress.style.width = '0%';
        }, 320);
    }

    function showLocation(data = {}) {
        locationKicker.textContent = data.kicker || 'RETURNING TO';
        locationTitle.textContent = data.title || 'THE FRONTIER';
        locationSubtitle.textContent = data.subtitle || 'Your last known location';
        locationTime.textContent = data.time || '';
        locationCard.classList.remove('hidden');
        clearTimeout(showLocation.timer);
        showLocation.timer = setTimeout(() => locationCard.classList.add('hidden'), Number(data.duration || 4200));
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

    function showToast(message) {
        toast.textContent = friendlyError(message);
        toast.classList.remove('hidden');
        clearTimeout(showToast.timer);
        showToast.timer = setTimeout(() => toast.classList.add('hidden'), 2800);
    }

    function escapeHtml(value) {
        return String(value ?? '').replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
    }

    function fullName(character) {
        const info = character?.charinfo || {};
        return `${info.firstname || 'Unknown'} ${info.lastname || 'Unknown'}`.trim();
    }

    function initials(character) {
        const info = character?.charinfo || {};
        return `${String(info.firstname || 'N').trim().charAt(0)}${String(info.lastname || '7').trim().charAt(0)}`.toUpperCase();
    }

    function genderLabel(value) {
        value = String(value ?? '').toLowerCase();
        return value === 'female' || value === 'woman' || value === '0' ? 'Female' : 'Male';
    }

    function moneyValue(value) { return Number(value || 0).toLocaleString('en-US'); }
    function getCharacterBySlot(slot) { return state.characters.find((character) => Number(character.slot || character.cid) === Number(slot)); }

    function setView(name) {
        emptyPanel.classList.toggle('hidden', name !== 'empty');
        infoPanel.classList.toggle('hidden', name !== 'info');
        createPanel.classList.toggle('hidden', name !== 'create');
    }

    function updateCounter() { slotCounter.textContent = `${state.characters.length} / ${state.slots} CHARACTERS`; }

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
                button.innerHTML = `<span class="slot-number">${String(slot).padStart(2, '0')}</span><span class="character-copy"><span class="character-name">${escapeHtml(fullName(character))}</span><span class="character-meta">${escapeHtml(job.label || job.name || 'Unemployed')} · ${escapeHtml(genderLabel(info.gender))}</span></span><span class="character-state">›</span>`;
            } else {
                button.innerHTML = `<span class="slot-number">${String(slot).padStart(2, '0')}</span><span class="character-copy"><span class="character-name">Empty Record</span><span class="character-meta">Begin a new story</span></span><span class="character-state">+</span>`;
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
            ['Bank', `$${moneyValue(money.bank)}`, true],
            ['Gold', moneyValue(money.gold), true],
            ['Citizen ID', character.citizenid || 'Unknown']
        ];
        infoBody.innerHTML = details.map(([label, value, accent]) => `<div class="detail-row${accent ? ' accent' : ''}"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`).join('');
    }

    function setGender(gender) {
        state.gender = gender === 'female' ? 'female' : 'male';
        document.querySelectorAll('.gender-option').forEach((button) => button.classList.toggle('selected', button.dataset.gender === state.gender));
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
            setGender(state.gender);
            setView('create');
            setTimeout(() => $('firstName').focus(), 80);
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
        const first = state.characters[0];
        const initialSlot = first ? Number(first.slot || first.cid || 1) : 1;
        setTimeout(() => selectSlot(initialSlot), 70);
    }

    function sanitizeCreateData() {
        return {
            slot: state.selectedSlot,
            charinfo: {
                firstname: $('firstName').value.trim(),
                lastname: $('lastName').value.trim(),
                birthdate: $('birthdate').value,
                nationality: $('nationality').value.trim() || 'American',
                gender: state.gender
            }
        };
    }

    async function enterWorld(character, button) {
        if (!character?.citizenid) {
            if (button) button.disabled = false;
            showToast('No character selected.');
            return false;
        }
        if (button) button.disabled = true;
        app.classList.add('leaving');
        setTransition({ title: 'LOADING CHARACTER', name: fullName(character), stage: 'Retrieving character record', progress: 8 });
        const result = await post('selectCharacter', { citizenid: character.citizenid });
        if (!result.ok) {
            hideTransition();
            app.classList.remove('leaving');
            if (button) button.disabled = false;
            showToast(result.error || 'Character load failed.');
            return false;
        }
        return true;
    }

    async function createCharacter() {
        if (!state.selectedSlot) return showToast('Select a slot first.');
        const payload = sanitizeCreateData();
        if (!payload.charinfo.firstname || !payload.charinfo.lastname || !payload.charinfo.birthdate) return showToast('Fill in first name, last name, and birthdate.');
        const button = $('createConfirmButton');
        button.disabled = true;
        const result = await post('createCharacter', payload);
        button.disabled = false;
        if (!result.ok) return showToast(result.error || 'Character create failed.');
        await enterWorld(result.character, button);
    }

    async function deleteCharacter() {
        if (!state.selectedCharacter?.citizenid) return;
        const button = $('deleteConfirmButton');
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
    playButton.addEventListener('click', () => state.selectedCharacter ? enterWorld(state.selectedCharacter, playButton) : setView('create'));
    deleteButton.addEventListener('click', () => { if (state.selectedCharacter) deletePanel.classList.remove('hidden'); });
    $('disconnectButton').addEventListener('click', () => post('disconnect'));
    $('createBackButton').addEventListener('click', () => {
        const first = state.characters[0];
        if (first) selectSlot(Number(first.slot || first.cid || 1));
        else { state.selectedSlot = null; state.selectedCharacter = null; renderCharacters(); setView('empty'); }
    });
    $('createConfirmButton').addEventListener('click', createCharacter);
    $('deleteCancelButton').addEventListener('click', () => deletePanel.classList.add('hidden'));
    $('deleteConfirmButton').addEventListener('click', deleteCharacter);
    document.querySelectorAll('.gender-option').forEach((button) => button.addEventListener('click', () => setGender(button.dataset.gender)));

    window.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !deletePanel.classList.contains('hidden')) deletePanel.classList.add('hidden');
    });

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.action === 'open') {
            hideTransition();
            locationCard.classList.add('hidden');
            state.slots = Number(data.slots || state.slots || 4);
            app.classList.remove('hidden', 'leaving');
            setCharacters([], state.slots);
            post('ready');
            return;
        }
        if (data.action === 'transition') return setTransition(data);
        if (data.action === 'transitionClose') return hideTransition();
        if (data.action === 'location') { hideTransition(); showLocation(data); return; }
        if (data.action === 'hideLocation') { locationCard.classList.add('hidden'); return; }
        if (data.action === 'characters') { if (data.error) showToast(data.error); setCharacters(data.characters || [], data.slots || state.slots); return; }
        if (data.action === 'close') { app.classList.add('hidden'); app.classList.remove('leaving'); deletePanel.classList.add('hidden'); }
    });
})();
