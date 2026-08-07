let selectedSlot = null;
let characterLimit = 0;
let charactersBySlot = {};
let selectedGender = 0;
let createSubmitting = false;
let characterLoading = false;
let loadRequestPending = false;
let currentView = 'roster';
let currentCreateStep = 0;
let rosterIndex = 0;
let actionIndex = 0;
let createTargetIndex = 0;

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';
const nui = (route, payload) => $.post(`https://${resourceName}/${route}`, JSON.stringify(payload || {}));
const createStepTitles = ['Name', 'Background', 'Gender', 'Review'];
let nuiReadyRetry = null;

function announceNuiReady() {
    nui('nuiReady')
        .done(() => {
            if (nuiReadyRetry) clearTimeout(nuiReadyRetry);
            nuiReadyRetry = null;
        })
        .fail(() => {
            if (nuiReadyRetry) clearTimeout(nuiReadyRetry);
            nuiReadyRetry = setTimeout(announceNuiReady, 400);
        });
}

function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>'"/]/g, (character) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;', '/': '&#x2F;'
    })[character]);
}

function money(value) {
    return `$ ${Number(value || 0).toFixed(2)}`;
}

function validName(value) {
    return /^[A-Za-z][A-Za-z' -]{1,29}$/.test(value.trim());
}

function validBirthdate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const [year, month, day] = value.split('-').map(Number);
    if (year < 1800 || year > 1911 || month < 1 || month > 12 || day < 1 || day > 31) return false;
    const parsed = new Date(Date.UTC(year, month - 1, day));
    return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day;
}

function fieldValue(field) {
    return String($(`#${field}`).val() || '').trim();
}

function validateField(field, showInvalid) {
    const value = fieldValue(field);
    let valid = false;
    let feedback = '';

    if (field === 'firstname' || field === 'lastname') {
        valid = validName(value);
        feedback = valid ? 'Looks good.' : 'Use 2–30 letters, spaces, apostrophes, or hyphens.';
    } else if (field === 'birthdate') {
        valid = validBirthdate(value);
        feedback = valid ? 'Valid birthdate.' : 'Use a real date between 1800 and 1911: YYYY-MM-DD.';
    } else if (field === 'nationality') {
        valid = value.length >= 2 && value.length <= 40;
        feedback = valid ? 'Looks good.' : 'Enter a nationality.';
    }

    const wrapper = $(`.form-field[data-field="${field}"]`);
    wrapper.toggleClass('valid', valid);
    wrapper.toggleClass('invalid', !valid && (showInvalid || value.length > 0));
    wrapper.find('.field-feedback').text(feedback);
    return valid;
}

function validateCreateStep(step, showInvalid) {
    if (step === 0) {
        return ['firstname', 'lastname'].map((field) => validateField(field, showInvalid)).every(Boolean);
    }
    if (step === 1) {
        return ['birthdate', 'nationality'].map((field) => validateField(field, showInvalid)).every(Boolean);
    }
    return true;
}

function validateCreateForm(showInvalid) {
    return [0, 1].map((step) => validateCreateStep(step, showInvalid)).every(Boolean);
}

function resetCreateForm() {
    selectedGender = 0;
    createSubmitting = false;
    currentCreateStep = 0;
    createTargetIndex = 0;
    $('#firstname, #lastname, #birthdate').val('');
    $('#nationality').val('American');
    $('.gender-choice').removeClass('selected nav-selected');
    $('.gender-choice[data-gender="0"]').addClass('selected');
    $('.form-field').removeClass('valid invalid');
    $('#create-feedback').text('');
    validateCreateForm(false);
}

function setView(view) {
    currentView = view;
    actionIndex = 0;
    createTargetIndex = 0;
    $('.nested-view').removeClass('active');
    $(`#${view}-view`).addClass('active');
    $('.nav-selected').removeClass('nav-selected');

    if (view === 'roster') {
        applyRosterSelection(false);
    } else if (view === 'character') {
        applyActionSelection('#character-actions', 0, false);
    } else if (view === 'delete') {
        applyActionSelection('#delete-actions', 0, false);
    } else if (view === 'create') {
        renderCreateStep(false);
    }
}

function unlockInterface() {
    $('.flow-action, .gender-choice, .character-slot, #create-next, #create-previous').prop('disabled', false);
    $('#create-next span:first').text(currentCreateStep === 3 ? 'Create Character' : 'Continue');
    $('#create-next .action-arrow').text(currentCreateStep === 3 ? '✓' : '›');
}

function hardResetInterface() {
    characterLoading = false;
    loadRequestPending = false;
    createSubmitting = false;
    $('.character-loading-overlay').stop(true, true).hide().attr('aria-hidden', 'true');
    $('.container').removeClass('interface-locked');
    $('#character-feedback, #create-feedback, #delete-feedback').text('');
    unlockInterface();
    resetSelection();
}

function resetSelection() {
    selectedSlot = null;
    createSubmitting = false;
    loadRequestPending = false;
    rosterIndex = 0;
    actionIndex = 0;
    currentCreateStep = 0;
    createTargetIndex = 0;
    $('#character-feedback, #create-feedback, #delete-feedback').text('');
    unlockInterface();
    resetCreateForm();
    setView('roster');
}

function renderSlots() {
    const list = $('#characters-list');
    let occupied = 0;
    list.empty();
    list.css('--slot-total', Math.max(1, characterLimit));

    for (let slot = 1; slot <= characterLimit; slot += 1) {
        const character = charactersBySlot[slot];
        if (character) occupied += 1;
        const name = character
            ? `${character.charinfo?.firstname || ''} ${character.charinfo?.lastname || ''}`.trim()
            : 'Empty Slot';
        const meta = character
            ? `${character.job?.label || 'Civilian'} · ${character.citizenid || ''}`
            : 'Begin a new story';

        list.append(`
            <button type="button" class="character-slot" data-slot="${slot}">
                <span class="slot-number">${String(slot).padStart(2, '0')}</span>
                <span class="slot-copy">
                    <span class="slot-name">${escapeHtml(name)}</span>
                    <span class="slot-meta">${escapeHtml(meta)}</span>
                </span>
                <span class="slot-state">›</span>
            </button>
        `);
    }

    $('#slot-count').text(`${occupied} / ${characterLimit}`);
    rosterIndex = Math.min(rosterIndex, Math.max(0, characterLimit - 1));
    applyRosterSelection(false);
}

function detailCard(label, value) {
    return `<div class="detail-card"><span class="detail-label">${escapeHtml(label)}</span><strong class="detail-value">${escapeHtml(value)}</strong></div>`;
}

function showExistingCharacter(character) {
    const fullName = `${character.charinfo?.firstname || ''} ${character.charinfo?.lastname || ''}`.trim() || 'Character';
    $('#selected-slot-label').text(`Selected Slot ${String(selectedSlot).padStart(2, '0')}`);
    $('#selected-character-name').text(fullName);
    $('#selected-character-summary').text(`${character.citizenid || 'County record'} · ${character.job?.label || 'Civilian'}`);
    $('#character-details').html(
        detailCard('Birthdate', character.charinfo?.birthdate || 'Unknown') +
        detailCard('Nationality', character.charinfo?.nationality || 'Unknown') +
        detailCard('Job', character.job?.label || 'Civilian') +
        detailCard('Gang', character.gang?.label || 'No Gang') +
        detailCard('Cash', money(character.money?.cash)) +
        detailCard('Bank', money(character.money?.bank))
    );
    $('#character-feedback').text('');
    $('#character-actions .flow-action').prop('disabled', false);
    setView('character');
}

function showCreateCharacter(slot) {
    resetCreateForm();
    $('#create-slot-label').text(`Empty Slot ${String(slot).padStart(2, '0')}`);
    setView('create');
}

function selectSlot(slot) {
    if (characterLoading || loadRequestPending) return;
    selectedSlot = Number(slot);
    rosterIndex = Math.max(0, selectedSlot - 1);
    const character = charactersBySlot[selectedSlot];
    if (character) showExistingCharacter(character);
    else showCreateCharacter(selectedSlot);
}

function applyRosterSelection(focusElement) {
    const slots = $('.character-slot');
    if (!slots.length) return;
    rosterIndex = ((rosterIndex % slots.length) + slots.length) % slots.length;
    slots.removeClass('nav-selected');
    const selected = slots.eq(rosterIndex).addClass('nav-selected');
    selectedSlot = Number(selected.data('slot')) || 1;
    if (focusElement) selected.trigger('focus');
}

function visibleActions(containerSelector) {
    return $(`${containerSelector} .flow-action:visible:not(:disabled)`);
}

function applyActionSelection(containerSelector, index, focusElement) {
    const actions = visibleActions(containerSelector);
    if (!actions.length) return;
    actionIndex = ((index % actions.length) + actions.length) % actions.length;
    actions.removeClass('nav-selected');
    const selected = actions.eq(actionIndex).addClass('nav-selected');
    if (focusElement) selected.trigger('focus');
}

function activeCreateTargets() {
    if (currentCreateStep === 0 || currentCreateStep === 1) {
        return $(`.create-step[data-step="${currentCreateStep}"] .char-reg-input`);
    }
    if (currentCreateStep === 2) {
        return $('.create-step[data-step="2"] .gender-choice');
    }
    return $('.create-actions .flow-action:visible:not(:disabled)');
}

function applyCreateTarget(index, focusElement) {
    const targets = activeCreateTargets();
    if (!targets.length) return;
    createTargetIndex = ((index % targets.length) + targets.length) % targets.length;
    targets.removeClass('nav-selected');
    const selected = targets.eq(createTargetIndex).addClass('nav-selected');
    if (focusElement) selected.trigger('focus');
}

function updateCreationReview() {
    const fullName = `${fieldValue('firstname')} ${fieldValue('lastname')}`.trim();
    $('#creation-review').html(
        detailCard('Name', fullName || 'Not entered') +
        detailCard('Birthdate', fieldValue('birthdate') || 'Not entered') +
        detailCard('Nationality', fieldValue('nationality') || 'Not entered') +
        detailCard('Gender', selectedGender === 1 ? 'Female' : 'Male')
    ).find('.detail-card').addClass('review-card').removeClass('detail-card');
}

function renderCreateStep(focusElement) {
    currentCreateStep = Math.max(0, Math.min(3, currentCreateStep));
    $('.create-step').removeClass('active');
    $(`.create-step[data-step="${currentCreateStep}"]`).addClass('active');
    $('#create-step-title').text(createStepTitles[currentCreateStep]);
    $('#create-step-count').text(`${currentCreateStep + 1} / 4`);
    $('.step-dot').each(function (index) {
        $(this).toggleClass('active', index === currentCreateStep);
        $(this).toggleClass('complete', index < currentCreateStep);
    });

    $('#create-previous').toggle(currentCreateStep > 0);
    $('#create-next span:first').text(currentCreateStep === 3 ? 'Create Character' : 'Continue');
    $('#create-next .action-arrow').text(currentCreateStep === 3 ? '✓' : '›');
    $('#create-feedback').text('');

    if (currentCreateStep === 3) updateCreationReview();
    createTargetIndex = 0;
    applyCreateTarget(0, focusElement);
}

function previousCreateStep() {
    if (characterLoading || loadRequestPending) return;
    if (currentCreateStep === 0) {
        setView('roster');
        return;
    }
    currentCreateStep -= 1;
    renderCreateStep(true);
}

function nextCreateStep() {
    if (characterLoading || loadRequestPending || createSubmitting) return;
    if (currentCreateStep < 3) {
        if (!validateCreateStep(currentCreateStep, true)) {
            $('#create-feedback').text('Complete the current page before continuing.');
            applyCreateTarget(0, true);
            return;
        }
        currentCreateStep += 1;
        renderCreateStep(true);
        return;
    }
    submitCreateCharacter();
}

function submitCreateCharacter() {
    if (!selectedSlot || createSubmitting || loadRequestPending || !validateCreateForm(true)) {
        $('#create-feedback').text('Complete every identity field before creating the character.');
        return;
    }

    createSubmitting = true;
    loadRequestPending = true;
    $('#create-next').prop('disabled', true).find('span:first').text('Creating...');
    $('#create-feedback').text('Creating character...');

    nui('createNewCharacter', {
        cid: selectedSlot,
        firstname: fieldValue('firstname'),
        lastname: fieldValue('lastname'),
        birthdate: fieldValue('birthdate'),
        nationality: fieldValue('nationality'),
        gender: selectedGender
    }).fail(() => {
        createSubmitting = false;
        loadRequestPending = false;
        $('#create-next').prop('disabled', false).find('span:first').text('Create Character');
        $('#create-feedback').text('The game client did not accept the creation request.');
    });
}

function enterCounty() {
    const character = charactersBySlot[selectedSlot];
    if (!character || characterLoading || loadRequestPending) return;
    loadRequestPending = true;
    $('#character-feedback').text('Loading character...');
    visibleActions('#character-actions').prop('disabled', true);
    nui('selectCharacter', { cData: character }).fail(() => {
        loadRequestPending = false;
        visibleActions('#character-actions').prop('disabled', false);
        $('#character-feedback').text('The game client did not accept the load request.');
        applyActionSelection('#character-actions', 0, false);
    });
}

function openDeleteView() {
    const character = charactersBySlot[selectedSlot];
    if (!character || characterLoading || loadRequestPending) return;
    const fullName = `${character.charinfo?.firstname || ''} ${character.charinfo?.lastname || ''}`.trim() || 'This character';
    $('#delete-character-name').text(`${fullName} and all saved data will be permanently removed.`);
    $('#delete-feedback').text('');
    setView('delete');
}

function confirmDelete() {
    const character = charactersBySlot[selectedSlot];
    if (!character || characterLoading || loadRequestPending) return;
    loadRequestPending = true;
    $('#delete-feedback').text('Deleting character...');
    visibleActions('#delete-actions').prop('disabled', true);
    nui('removeCharacter', { citizenid: character.citizenid }).fail(() => {
        loadRequestPending = false;
        visibleActions('#delete-actions').prop('disabled', false);
        $('#delete-feedback').text('The game client did not accept the delete request.');
        applyActionSelection('#delete-actions', 0, false);
    });
}

function refreshCharacters() {
    selectedSlot = null;
    charactersBySlot = {};
    rosterIndex = 0;
    renderSlots();
    setView('roster');
    nui('setupCharacters');
}

function runAction(action) {
    if (action === 'back-roster') setView('roster');
    else if (action === 'enter-county') enterCounty();
    else if (action === 'open-delete') openDeleteView();
    else if (action === 'cancel-delete') showExistingCharacter(charactersBySlot[selectedSlot]);
    else if (action === 'confirm-delete') confirmDelete();
    else if (action === 'create-back') previousCreateStep();
    else if (action === 'create-next') nextCreateStep();
}

function handleRosterKeys(event) {
    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
        event.preventDefault();
        rosterIndex += event.key === 'ArrowDown' ? 1 : -1;
        applyRosterSelection(true);
    } else if (event.key === 'Enter' || event.key === 'ArrowRight') {
        event.preventDefault();
        const slot = Number($('.character-slot').eq(rosterIndex).data('slot'));
        if (slot) selectSlot(slot);
    }
}

function handleActionKeys(event, containerSelector, backAction) {
    const actions = visibleActions(containerSelector);
    if (!actions.length) return;
    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
        event.preventDefault();
        actionIndex += event.key === 'ArrowDown' ? 1 : -1;
        applyActionSelection(containerSelector, actionIndex, true);
    } else if (event.key === 'Enter' || event.key === 'ArrowRight') {
        event.preventDefault();
        actions.eq(actionIndex).trigger('click');
    } else if (event.key === 'ArrowLeft' || event.key === 'Escape' || event.key === 'Backspace') {
        event.preventDefault();
        runAction(backAction);
    }
}

function handleCreateKeys(event) {
    const target = $(event.target);
    const isTextInput = target.hasClass('char-reg-input');

    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
        event.preventDefault();
        createTargetIndex += event.key === 'ArrowDown' ? 1 : -1;
        applyCreateTarget(createTargetIndex, true);
        if (currentCreateStep === 2) activeCreateTargets().eq(createTargetIndex).trigger('click');
        return;
    }

    if (currentCreateStep === 2 && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')) {
        event.preventDefault();
        createTargetIndex += event.key === 'ArrowRight' ? 1 : -1;
        applyCreateTarget(createTargetIndex, true);
        activeCreateTargets().eq(createTargetIndex).trigger('click');
        return;
    }

    if (event.key === 'Enter') {
        event.preventDefault();
        if (currentCreateStep === 2) {
            activeCreateTargets().eq(createTargetIndex).trigger('click');
            nextCreateStep();
        } else if (currentCreateStep === 3) {
            activeCreateTargets().eq(createTargetIndex).trigger('click');
        } else {
            nextCreateStep();
        }
        return;
    }

    if (event.key === 'Escape' || (!isTextInput && (event.key === 'ArrowLeft' || event.key === 'Backspace'))) {
        event.preventDefault();
        previousCreateStep();
    }
}

$(document).ready(() => {
    resetSelection();

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (data.action === 'hardReset') {
            hardResetInterface();
        }

        if (data.action === 'ui') {
            characterLimit = Number(data.nChar) || 5;
            if (data.toggle) {
                hardResetInterface();
                charactersBySlot = {};
                $('.container').stop(true, true).show().attr('aria-hidden', 'false');
                $('#selector-content').stop(true, true).hide();
                $('#selector-loading').stop(true, true).show();
                renderSlots();
                nui('setupCharacters');
            } else {
                $('.container').stop(true, true).hide().attr('aria-hidden', 'true');
                hardResetInterface();
            }
        }

        if (data.action === 'selectionReset') {
            hardResetInterface();
        }

        if (data.action === 'setupCharacters') {
            charactersBySlot = {};
            Object.values(data.characters || {}).forEach((character) => {
                const slot = Number(character.slot || character.cid || 1);
                charactersBySlot[slot] = character;
            });
            renderSlots();
            $('#selector-loading').hide();
            $('#selector-content').fadeIn(140);
            setView('roster');
        }

        if (data.action === 'characterLoading') {
            if (data.toggle) {
                characterLoading = true;
                loadRequestPending = false;
                $('#character-loading-title').text(data.title || 'YOU ARE WAKING UP');
                $('#character-loading-message').text(data.message || 'Returning to your last location...');
                $('.character-loading-overlay').fadeIn(160).attr('aria-hidden', 'false');
            } else {
                characterLoading = false;
                loadRequestPending = false;
                $('.character-loading-overlay').fadeOut(160).attr('aria-hidden', 'true');
            }
        }

        if (data.action === 'characterLoadFailed') {
            characterLoading = false;
            loadRequestPending = false;
            $('.character-loading-overlay').hide().attr('aria-hidden', 'true');
            unlockInterface();
            visibleActions('#character-actions').prop('disabled', false);
            if (selectedSlot && charactersBySlot[selectedSlot]) showExistingCharacter(charactersBySlot[selectedSlot]);
            $('#character-feedback').text(data.message || 'Character could not be loaded.');
        }

        if (data.action === 'createResult' && data.success === false) {
            createSubmitting = false;
            loadRequestPending = false;
            $('#create-next').prop('disabled', false).find('span:first').text('Create Character');
            $('#create-feedback').text(data.message || 'Character could not be created.');
        }

        if (data.action === 'deleteResult') {
            loadRequestPending = false;
            visibleActions('#delete-actions').prop('disabled', false);
            if (data.success) refreshCharacters();
            else {
                $('#delete-feedback').text(data.message || 'Character could not be deleted.');
                applyActionSelection('#delete-actions', 0, false);
            }
        }
    });

    $(document).on('click', '.character-slot', function () {
        rosterIndex = $(this).index();
        selectSlot($(this).data('slot'));
    });

    $(document).on('click', '[data-action]', function () {
        runAction($(this).data('action'));
    });

    $(document).on('input', '.char-reg-input', function () {
        validateField(this.id, false);
        $('#create-feedback').text('');
    });

    $(document).on('focus', '.char-reg-input', function () {
        const targets = activeCreateTargets();
        createTargetIndex = Math.max(0, targets.index(this));
        targets.removeClass('nav-selected');
        $(this).addClass('nav-selected');
    });

    $(document).on('click', '.gender-choice', function () {
        selectedGender = Number($(this).data('gender')) === 1 ? 1 : 0;
        $('.gender-choice').removeClass('selected nav-selected');
        $(this).addClass('selected nav-selected');
        createTargetIndex = $('.gender-choice').index(this);
    });

    $(document).on('focus mouseenter', '.flow-action', function () {
        const container = $(this).closest('.action-list, .create-actions');
        const actions = container.find('.flow-action:visible:not(:disabled)');
        actionIndex = Math.max(0, actions.index(this));
        actions.removeClass('nav-selected');
        $(this).addClass('nav-selected');
    });

    $(document).on('keydown', (event) => {
        if (!$('.container').is(':visible') || characterLoading || loadRequestPending) return;
        if (currentView === 'roster') handleRosterKeys(event);
        else if (currentView === 'character') handleActionKeys(event, '#character-actions', 'back-roster');
        else if (currentView === 'delete') handleActionKeys(event, '#delete-actions', 'cancel-delete');
        else if (currentView === 'create') handleCreateKeys(event);
    });

    announceNuiReady();

    $('#disconnect').on('click', () => {
        nui('closeUI');
        nui('disconnectButton');
    });
});
