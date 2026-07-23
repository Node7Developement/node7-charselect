var slots = [];
var labels = {};
var pendingDelete = null;
var activeCreateSlot = null;
var activeSetupCitizenId = '';
var resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';

function nuiPost(name, data, done) {
    try {
        $.post('https://' + resourceName + '/' + name, JSON.stringify(data || {}), function(response) {
            if (done) done(response || {});
        });
    } catch (e) {
        if (done) done({ ok: false, error: 'NUI callback failed' });
    }
}

function escapeHtml(value) {
    return String(value == null ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function showMessage(text) {
    var box = $('#message');
    if (!text) {
        box.hide().text('');
        return;
    }
    box.text(text).fadeIn(120);
    setTimeout(function() { box.fadeOut(180); }, 4500);
}

function setBusy(state, text) {
    if (state) {
        $('#busyText').text(text || 'Working...');
        $('#busy').removeClass('hidden');
    } else {
        $('#busy').addClass('hidden');
    }
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
    if (Array.isArray(payload)) return payload;
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
                    '<div class="ctext">Create New Character</div>' +
                    '<div class="actions"><button class="createnew" data-create="' + escapeHtml(slotNumber) + '">' + escapeHtml(labels.create || 'Create') + '</button></div>' +
                '</div>' +
            '</div>';
    }

    var c = slot.character || {};
    var name = c.name || ((c.firstname || 'Unknown') + ' ' + (c.lastname || 'Unknown'));
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
                    (isSetup ? '<button class="create" data-setup="' + escapeHtml(slotNumber) + '" data-citizenid="' + escapeHtml(c.citizenid || '') + '">' + escapeHtml(labels.setup || 'Setup') + '</button>' : '<button class="create" data-play="' + escapeHtml(c.citizenid || '') + '">' + escapeHtml(labels.play || 'Select') + '</button>') +
                    '<button class="delete" data-delete="' + escapeHtml(c.citizenid || '') + '" data-name="' + escapeHtml(name) + '">' + escapeHtml(labels.delete || 'Delete') + '</button>' +
                '</div>' +
            '</div>' +
        '</div>';
}

function loadCharacters(payload) {
    slots = normalizeSlots(payload);
    var html = '';
    for (var i = 0; i < slots.length; i++) {
        html += renderCharacter(slots[i], i);
    }
    $('#characters').html(html);
    $('#main').fadeIn(180);
}

function refreshCharacters() {
    setBusy(true, 'Loading characters...');
    nuiPost('refresh', {}, function(response) {
        setBusy(false);
        loadCharacters(response);
    });
}

function openCreator(slot, citizenid) {
    activeCreateSlot = Number(slot || 1);
    activeSetupCitizenId = citizenid || '';
    $('#slot').val(activeCreateSlot);
    $('#citizenid').val(activeSetupCitizenId);
    $('#creatorTitle').text(activeSetupCitizenId ? 'Finish Character Setup' : 'Create Character');
    $('#createBtn').text(activeSetupCitizenId ? 'Save' : 'Create');
    $('#name').val('');
    $('#lastname').val('');
    $('#birthdate').val('');
    $('#gender').val('male');
    $('#nationality').val('');
    $('#backstory').val('');
    $('#main').fadeOut(120);
    $('#creator').fadeIn(140);
    nuiPost('previewGender', { gender: 'male' });
}

function createNewCharacter() {
    openCreator(activeCreateSlot || 1, '');
}

function confirmNewCharacter() {
    var slot = Number($('#slot').val() || activeCreateSlot || 1);
    var citizenid = $('#citizenid').val() || '';
    var charinfo = {
        firstname: $.trim($('#name').val()),
        lastname: $.trim($('#lastname').val()),
        birthdate: $.trim($('#birthdate').val()),
        gender: $('#gender').val() || 'male',
        nationality: $.trim($('#nationality').val()),
        backstory: $.trim($('#backstory').val())
    };

    if (!charinfo.firstname || !charinfo.lastname || !charinfo.birthdate || !charinfo.nationality) {
        showMessage('Fill out first name, last name, birthdate, and nationality.');
        return;
    }

    $('#creator').fadeOut(120);
    setBusy(true, citizenid ? 'Saving character...' : 'Creating character...');
    nuiPost(citizenid ? 'finishSetup' : 'create', { slot: slot, citizenid: citizenid, charinfo: charinfo }, function(response) {
        setBusy(false);
        if (!response || !response.ok) {
            showMessage((response && response.error) || 'Character create failed');
            $('#main').fadeIn(140);
        }
    });
}

function cancel() {
    $('#creator').fadeOut(120);
    $('#main').fadeIn(140);
    nuiPost('cancelNew', {});
}

function selectByCitizen(citizenid) {
    if (!citizenid) return;
    $('#main').fadeOut(120);
    setBusy(true, 'Loading last location...');
    nuiPost('play', { citizenid: citizenid }, function(response) {
        setBusy(false);
        if (!response || !response.ok) {
            showMessage((response && response.error) || 'Character load failed');
            $('#main').fadeIn(140);
        }
    });
}

function select(id, pedid) {
    var slot = slots[(Number(id) || 1) - 1];
    var c = slot && slot.character;
    if (c && c.citizenid) selectByCitizen(c.citizenid);
}

function confirmDelete(citizenid, name) {
    pendingDelete = citizenid;
    $('#remover').html('' +
        '<div id="pewien">Delete ' + escapeHtml(name || citizenid) + '? This action cannot be undone.</div>' +
        '<button id="confirm">Confirm</button>' +
        '<button id="cancelDeletion">Cancel</button>'
    ).fadeIn(140);
}

function confirm(id) {
    var slot = slots[(Number(id) || 1) - 1];
    var c = slot && slot.character;
    if (c && c.citizenid) confirmDelete(c.citizenid, c.name);
}

function cancelDeletion() {
    pendingDelete = null;
    $('#remover').fadeOut(120).empty();
}

function delet(id) {
    if (!pendingDelete) return;
    var citizenid = pendingDelete;
    cancelDeletion();
    setBusy(true, 'Deleting character...');
    nuiPost('delete', { citizenid: citizenid }, function(response) {
        setBusy(false);
        if (!response || !response.ok) {
            showMessage((response && response.error) || 'Delete failed');
            return;
        }
        refreshCharacters();
    });
}

$(function() {
    $('#main').hide();
    $('#creator').hide();
    $('#loading').hide();
    $('#remover').hide();

    $('#refresh').bind('click', refreshCharacters);
    $('#createBtn').bind('click', confirmNewCharacter);
    $('#cancelBtn').bind('click', cancel);
    $('#gender').bind('change', function() {
        nuiPost('previewGender', { gender: $(this).val() || 'male' });
    });

    $('#characters').delegate('button', 'click', function() {
        var btn = $(this);
        if (btn.attr('data-create')) return openCreator(btn.attr('data-create'), '');
        if (btn.attr('data-setup')) return openCreator(btn.attr('data-setup'), btn.attr('data-citizenid'));
        if (btn.attr('data-play')) return selectByCitizen(btn.attr('data-play'));
        if (btn.attr('data-delete')) return confirmDelete(btn.attr('data-delete'), btn.attr('data-name'));
    });

    $('#characters').delegate('.char', 'mouseenter', function() {
        nuiPost('previewSlot', { slot: Number($(this).attr('data-slot') || 1) });
    });

    $('#remover').delegate('#confirm', 'click', delet);
    $('#remover').delegate('#cancelDeletion', 'click', cancelDeletion);

    window.addEventListener('message', function(event) {
        var data = event.data || {};

        if (data.version) {
            $('#version').html('version ' + data.version);
            setTimeout(function() { $('#loadingtext').html('Verifying character data...'); }, 1000);
            setTimeout(function() { $('#loadingtext').html('Loading server data...'); }, 2800);
            setTimeout(function() { $('#loadingtext').html('Starting scripts...'); }, 4400);
        }

        if (data.loading === true) {
            var randomnum = Math.floor(Math.random() * 3) + 1;
            $('#loadingPanel').css('background-image', 'url(rdr2' + randomnum + '.png)');
            $('#loading').fadeIn(180);
        }

        if (data.loading === false) {
            $('#loading').fadeOut(180);
        }

        if (data.action === 'show' || data.type === 3) {
            labels = data.labels || labels || {};
            $('#body').show();
            $('#main').fadeIn(180);
        }

        if (data.action === 'hide' || data.type === 2) {
            $('#main').fadeOut(120);
            $('#creator').fadeOut(120);
            $('#remover').fadeOut(120);
            setBusy(false);
        }

        if (data.action === 'setCharacters') {
            loadCharacters(data.data);
        }

        if (data.type === 1) {
            loadCharacters(data.list);
        }

        if (data.new === true) {
            createNewCharacter();
        }
    });

    nuiPost('ready', {});
});
