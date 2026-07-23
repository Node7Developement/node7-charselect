var slots = [];
var labels = {};
var pendingDelete = null;
var activeCreateSlot = null;
var activeSetupCitizenId = '';
var busy = false;
var resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';

function byId(id) { return document.getElementById(id); }

function show(el) { if (el) el.style.display = 'block'; }
function hide(el) { if (el) el.style.display = 'none'; }

function setText(id, value) {
    var el = byId(id);
    if (el) el.textContent = value == null ? '' : String(value);
}

function setValue(id, value) {
    var el = byId(id);
    if (el) el.value = value == null ? '' : String(value);
}

function getValue(id) {
    var el = byId(id);
    return el && el.value ? String(el.value).replace(/^\s+|\s+$/g, '') : '';
}

function nuiPost(name, data, done) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'https://' + resourceName + '/' + name, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== 4) return;
        var response = {};
        try { response = xhr.responseText ? JSON.parse(xhr.responseText) : {}; } catch (e) { response = {}; }
        if (done) done(response || {});
    };
    xhr.onerror = function() {
        if (done) done({ ok: false, error: 'NUI callback failed' });
    };
    xhr.send(JSON.stringify(data || {}));
}

function escapeHtml(value) {
    return String(value == null ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/\"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function showMessage(text) {
    var box = byId('message');
    if (!box) return;
    if (!text) {
        box.textContent = '';
        hide(box);
        return;
    }
    box.textContent = text;
    show(box);
    setTimeout(function() { hide(box); }, 3500);
}

function setButtonsDisabled(state) {
    var buttons = document.getElementsByTagName('button');
    for (var i = 0; i < buttons.length; i++) buttons[i].disabled = state === true;
}

function setBusy(state) {
    busy = state === true;
    setButtonsDisabled(busy);
}

function normalizeSlots(payload) {
    if (!payload) return [];
    if (payload.ok === false) {
        showMessage(payload.error || 'Character list failed');
        return [];
    }
    labels = payload.labels || labels || {};
    if (payload.slots) return payload.slots;
    if (payload.list) return payload.list;
    if (Object.prototype.toString.call(payload) === '[object Array]') return payload;
    return [];
}

function moneyLine(c) {
    c = c || {};
    var cash = Number(c.cash || 0);
    var bank = Number(c.bank || 0);
    var gold = Number(c.gold || 0);
    return '$' + cash + ' / Bank $' + bank + ' / Gold ' + gold;
}

function renderCharacter(slot, index) {
    var slotNumber = slot.slot || slot.cid || (index + 1);
    if (slot.empty || !slot.character) {
        return '' +
            '<div class="char empty" data-slot="' + escapeHtml(slotNumber) + '">' +
                '<div class="char-content">' +
                    '<div class="slot-num">SLOT ' + escapeHtml(slotNumber) + '</div>' +
                    '<div class="ctext">Create Character</div>' +
                    '<div class="actions"><button class="createnew" type="button" data-create="' + escapeHtml(slotNumber) + '">' + escapeHtml(labels.create || 'Create') + '</button></div>' +
                '</div>' +
            '</div>';
    }

    var c = slot.character || {};
    var charinfo = c.charinfo || {};
    var first = c.firstname || charinfo.firstname || 'Unknown';
    var last = c.lastname || charinfo.lastname || 'Unknown';
    var name = c.name || (first + ' ' + last);
    var isSetup = c.requires_setup === true;
    return '' +
        '<div class="char" data-slot="' + escapeHtml(slotNumber) + '">' +
            '<div class="char-content">' +
                '<div class="slot-num">SLOT ' + escapeHtml(slotNumber) + '</div>' +
                '<div class="fname">' + escapeHtml(name) + '</div>' +
                '<div class="cid">' + escapeHtml(c.citizenid || '') + '</div>' +
                '<div class="money">' + escapeHtml(c.job || 'unemployed') + '</div>' +
                '<div class="gold">' + escapeHtml(moneyLine(c)) + '</div>' +
                '<div class="actions">' +
                    (isSetup ? '<button class="create" type="button" data-setup="' + escapeHtml(slotNumber) + '" data-citizenid="' + escapeHtml(c.citizenid || '') + '">' + escapeHtml(labels.setup || 'Setup') + '</button>' : '<button class="create" type="button" data-play="' + escapeHtml(c.citizenid || '') + '">' + escapeHtml(labels.play || 'Play') + '</button>') +
                    '<button class="delete" type="button" data-delete="' + escapeHtml(c.citizenid || '') + '" data-name="' + escapeHtml(name) + '">' + escapeHtml(labels.delete || 'Delete') + '</button>' +
                '</div>' +
            '</div>' +
        '</div>';
}

function loadCharacters(payload) {
    slots = normalizeSlots(payload);
    var html = '';
    for (var i = 0; i < slots.length; i++) html += renderCharacter(slots[i], i);
    var list = byId('characters');
    if (list) list.innerHTML = html;
    show(byId('main'));
}

function refreshCharacters() {
    if (busy) return;
    setBusy(true);
    nuiPost('refresh', {}, function(response) {
        setBusy(false);
        loadCharacters(response);
    });
}

function openCreator(slot, citizenid) {
    activeCreateSlot = Number(slot || 1);
    activeSetupCitizenId = citizenid || '';
    setValue('slot', activeCreateSlot);
    setValue('citizenid', activeSetupCitizenId);
    setText('creatorTitle', activeSetupCitizenId ? 'Finish Character' : 'Create Character');
    setText('createBtn', activeSetupCitizenId ? 'Save' : 'Create');
    setValue('name', '');
    setValue('lastname', '');
    setValue('birthdate', '');
    setValue('gender', 'male');
    setValue('nationality', '');
    setValue('backstory', '');
    show(byId('creator'));
}

function createNewCharacter() {
    openCreator(activeCreateSlot || 1, '');
}

function confirmNewCharacter() {
    if (busy) return;
    var slot = Number(getValue('slot') || activeCreateSlot || 1);
    var citizenid = getValue('citizenid');
    var charinfo = {
        firstname: getValue('name'),
        lastname: getValue('lastname'),
        birthdate: getValue('birthdate'),
        gender: getValue('gender') || 'male',
        nationality: getValue('nationality'),
        backstory: getValue('backstory')
    };

    if (!charinfo.firstname || !charinfo.lastname || !charinfo.birthdate || !charinfo.nationality) {
        showMessage('Fill required fields.');
        return;
    }

    hide(byId('creator'));
    setBusy(true);
    nuiPost(citizenid ? 'finishSetup' : 'create', { slot: slot, citizenid: citizenid, charinfo: charinfo }, function(response) {
        if (!response || !response.ok) {
            setBusy(false);
            showMessage((response && response.error) || 'Create failed');
            show(byId('creator'));
        }
    });
}

function cancel() {
    hide(byId('creator'));
    nuiPost('cancelNew', {});
}

function selectByCitizen(citizenid) {
    if (!citizenid || busy) return;
    hide(byId('creator'));
    setBusy(true);
    nuiPost('play', { citizenid: citizenid }, function(response) {
        if (!response || !response.ok) {
            setBusy(false);
            showMessage((response && response.error) || 'Character load failed');
        }
    });
}

function confirmDelete(citizenid, name) {
    if (busy) return;
    pendingDelete = citizenid;
    var box = byId('remover');
    if (!box) return;
    box.innerHTML = '' +
        '<div id="pewien">Delete ' + escapeHtml(name || citizenid) + '?</div>' +
        '<button id="confirm" type="button">Confirm</button>' +
        '<button id="cancelDeletion" type="button">Cancel</button>';
    show(box);
}

function cancelDeletion() {
    pendingDelete = null;
    hide(byId('remover'));
    var box = byId('remover');
    if (box) box.innerHTML = '';
}

function deletePending() {
    if (!pendingDelete || busy) return;
    var citizenid = pendingDelete;
    cancelDeletion();
    setBusy(true);
    nuiPost('delete', { citizenid: citizenid }, function(response) {
        setBusy(false);
        if (!response || !response.ok) {
            showMessage((response && response.error) || 'Delete failed');
            return;
        }
        refreshCharacters();
    });
}

function handleCharacterClick(event) {
    var target = event.target || event.srcElement;
    while (target && target !== byId('characters') && String(target.tagName).toLowerCase() !== 'button') target = target.parentNode;
    if (!target || target === byId('characters')) return;

    if (target.getAttribute('data-create')) return openCreator(target.getAttribute('data-create'), '');
    if (target.getAttribute('data-setup')) return openCreator(target.getAttribute('data-setup'), target.getAttribute('data-citizenid'));
    if (target.getAttribute('data-play')) return selectByCitizen(target.getAttribute('data-play'));
    if (target.getAttribute('data-delete')) return confirmDelete(target.getAttribute('data-delete'), target.getAttribute('data-name'));
}

function handleRemoveClick(event) {
    var target = event.target || event.srcElement;
    if (!target || !target.id) return;
    if (target.id === 'confirm') return deletePending();
    if (target.id === 'cancelDeletion') return cancelDeletion();
}

function hideAll() {
    hide(byId('main'));
    hide(byId('creator'));
    hide(byId('remover'));
    setBusy(false);
}

window.addEventListener('message', function(event) {
    var data = event.data || {};

    if (data.action === 'show' || data.type === 3) {
        labels = data.labels || labels || {};
        show(byId('main'));
        return;
    }

    if (data.action === 'hide' || data.type === 2) {
        hideAll();
        return;
    }


    if (data.action === 'setCharacters') {
        loadCharacters(data.data);
        return;
    }

    if (data.type === 1) {
        loadCharacters(data.list);
        return;
    }

    if (data.new === true) createNewCharacter();
});

document.addEventListener('DOMContentLoaded', function() {
    hideAll();

    var refresh = byId('refresh');
    var createBtn = byId('createBtn');
    var cancelBtn = byId('cancelBtn');
    var chars = byId('characters');
    var remover = byId('remover');

    if (refresh) refresh.addEventListener('click', refreshCharacters, false);
    if (createBtn) createBtn.addEventListener('click', confirmNewCharacter, false);
    if (cancelBtn) cancelBtn.addEventListener('click', cancel, false);
    if (chars) chars.addEventListener('click', handleCharacterClick, false);
    if (remover) remover.addEventListener('click', handleRemoveClick, false);

    nuiPost('ready', {});
});
