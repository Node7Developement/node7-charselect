var selectedChar = null;
var WelcomePercentage = "30vh";
var qbMultiCharacters = {};
var Loaded = false;
var NChar = null;
var selectedGender = 0;
var createSubmitting = false;

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'node7-charselect';
const nui = (route, payload) => $.post(`https://${resourceName}/${route}`, JSON.stringify(payload || {}));

function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>'"/]/g, function (character) {
        return ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            "'": '&#39;',
            '"': '&quot;',
            '/': '&#x2F;'
        })[character];
    });
}

function validName(value) {
    return /^[A-Za-z][A-Za-z' -]{1,29}$/.test(value.trim());
}

function validBirthdate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const parts = value.split('-').map(Number);
    const year = parts[0];
    const month = parts[1];
    const day = parts[2];
    if (year < 1800 || year > 1911 || month < 1 || month > 12 || day < 1 || day > 31) return false;
    const parsed = new Date(Date.UTC(year, month - 1, day));
    return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day;
}

function fieldValue(field) {
    return $(`#${field}`).val().trim();
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

function validateCreateForm(showInvalid) {
    const valid = ['firstname', 'lastname', 'birthdate', 'nationality']
        .map(field => validateField(field, showInvalid))
        .every(Boolean);

    $('#create').toggleClass('disabled', !valid || createSubmitting);
    return valid;
}

function resetCreateForm() {
    createSubmitting = false;
    selectedGender = 0;
    $('#firstname, #lastname, #birthdate').val('');
    $('#nationality').val('American');
    $('.gender-button').removeClass('selected');
    $('.gender-button[data-gender="0"]').addClass('selected');
    $('.form-submit-feedback').text('');
    $('.form-field').removeClass('valid invalid');
    $('#create').removeClass('submitting').addClass('disabled');
    validateCreateForm(false);
}

function showCreateResult(message) {
    createSubmitting = false;
    $('#create').removeClass('submitting');
    $('.form-submit-feedback').text(message || 'Character could not be created.');
    validateCreateForm(false);
}

$(document).ready(function () {
    window.addEventListener('message', function (event) {
        const data = event.data || {};

        if (data.action === 'ui') {
            NChar = data.nChar;
            if (data.toggle) {
                $('.container').show();
                $('.welcomescreen').fadeIn(150);
                qbMultiCharacters.resetAll();

                let originalText = 'Retrieving player data';
                let loadingProgress = 0;
                let loadingDots = 0;
                $('#loading-text').html(originalText);
                const dotsInterval = setInterval(function () {
                    $('#loading-text').append('.');
                    loadingDots++;
                    loadingProgress++;
                    if (loadingProgress === 3) originalText = 'Validating player data';
                    if (loadingProgress === 4) originalText = 'Retrieving characters';
                    if (loadingProgress === 6) originalText = 'Validating characters';
                    if (loadingDots === 4) {
                        $('#loading-text').html(originalText);
                        loadingDots = 0;
                    }
                }, 500);

                setTimeout(function () {
                    setCharactersList();
                    nui('setupCharacters');
                    setTimeout(function () {
                        clearInterval(dotsInterval);
                        $('.welcomescreen').fadeOut(150);
                        qbMultiCharacters.fadeInDown('.character-info', '20%', 400);
                        qbMultiCharacters.fadeInDown('.characters-list', '20%', 400);
                        nui('removeBlur');
                    }, 2000);
                }, 2000);
            } else {
                $('.container').fadeOut(250);
                qbMultiCharacters.resetAll();
                resetCreateForm();
            }
        }

        if (data.action === 'setupCharacters') setupCharacters(data.characters || []);
        if (data.action === 'setupCharInfo') setupCharInfo(data.chardata);
        if (data.action === 'createResult' && data.success === false) showCreateResult(data.message);
        if (data.action === 'deleteResult') {
            $('.character-delete').fadeOut(150);
            if (data.success) refreshCharacters();
        }
    });

    $(document).on('input', '.char-reg-input', function () {
        validateField(this.id, false);
        $('.form-submit-feedback').text('');
        validateCreateForm(false);
    });


    $(document).on('click', '.gender-button', function (event) {
        event.preventDefault();
        selectedGender = Number($(this).data('gender')) === 1 ? 1 : 0;
        $('.gender-button').removeClass('selected');
        $(this).addClass('selected');
        validateCreateForm(false);
    });

    resetCreateForm();
});

$('.disconnect-btn').click(function (event) {
    event.preventDefault();
    nui('closeUI');
    nui('disconnectButton');
});

function setupCharInfo(cData) {
    if (cData === 'empty') {
        $('.character-info-valid').html('<span id="no-char">The selected character slot is not in use yet.<br><br>This character does not have information yet.</span>');
        return;
    }

    $('.character-info-valid').html(
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-user"> <span id="info-label">NAME :</i> </span><span class="char-info-js">' + escapeHtml(cData.charinfo.firstname) + ' ' + escapeHtml(cData.charinfo.lastname) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-calendar"> <span id="info-label">BIRTH DATE :</i> </span><span class="char-info-js">' + escapeHtml(cData.charinfo.birthdate) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-address-card"> <span id="info-label">NATIONALITY :</i> </span><span class="char-info-js">' + escapeHtml(cData.charinfo.nationality) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-briefcase"> <span id="info-label">JOB :</i> </span><span class="char-info-js">' + escapeHtml(cData.job.label) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-users"> <span id="info-label">GANG :</i> </span><span class="char-info-js">' + escapeHtml(cData.gang.label) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-wallet"> <span id="info-label">CASH :</i> </span><span class="char-info-js">&#36; ' + Number(cData.money.cash || 0).toFixed(2) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-piggy-bank"> <span id="info-label">BANK :</i> </span><span class="char-info-js">&#36; ' + Number(cData.money.bank || 0).toFixed(2) + '</span></div>' +
        '<div class="character-info-box"><span id="info-label"><i class="fas fa-money-bill-alt"> <span id="info-label">BLOODMONEY :</i> </span><span class="char-info-js">&#36; ' + Number(cData.money.bloodmoney || 0).toFixed(2) + '</span></div>'
    );
}

function setupCharacters(characters) {
    $.each(characters, function (_, character) {
        const slot = Number(character.slot || character.cid || 1);
        const element = $('#char-' + slot);
        element.html('');
        element.data('citizenid', character.citizenid);
        element.data('cData', character);
        element.data('cid', slot);
        element.html('<span id="slot-name">' + escapeHtml(character.charinfo.firstname) + ' ' + escapeHtml(character.charinfo.lastname) + '<span id="cid">' + escapeHtml(character.citizenid) + '</span></span>');
    });
}

$(document).on('click', '.character', function (event) {
    event.preventDefault();
    const cDataPed = $(this).data('cData');

    if (selectedChar !== null && $(selectedChar).attr('id') === $(this).attr('id')) return;
    if (selectedChar !== null) $(selectedChar).removeClass('char-selected');

    selectedChar = $(this);
    $(selectedChar).addClass('char-selected');

    if ($(selectedChar).data('cid') === '') {
        setupCharInfo('empty');
        $('#play-text').html('Create');
        $('#play').css({ display: 'block' });
        $('#delete').css({ display: 'none' });
    } else {
        setupCharInfo($(this).data('cData'));
        $('#play-text').html('Play');
        $('#delete-text').html('Delete');
        $('#play').css({ display: 'block' });
        $('#delete').css({ display: 'block' });
    }

    nui('cDataPed', { cData: cDataPed });
});

$(document).on('click', '#create', function (event) {
    event.preventDefault();
    if (createSubmitting || !validateCreateForm(true) || selectedChar === null) return;

    createSubmitting = true;
    $('#create').addClass('submitting disabled');
    $('.form-submit-feedback').text('Creating character...');

    nui('createNewCharacter', {
        cid: Number($(selectedChar).attr('id').replace('char-', '')),
        firstname: fieldValue('firstname'),
        lastname: fieldValue('lastname'),
        birthdate: fieldValue('birthdate'),
        nationality: fieldValue('nationality'),
        gender: selectedGender
    }).fail(function () {
        showCreateResult('The game client did not accept the creation request.');
    });
});

$(document).on('click', '#accept-delete', function (event) {
    event.preventDefault();
    if (!selectedChar) return;
    nui('removeCharacter', { citizenid: $(selectedChar).data('citizenid') });
});

$(document).on('click', '#cancel-delete', function (event) {
    event.preventDefault();
    $('.character-delete').fadeOut(150);
});

function setCharactersList() {
    let htmlResult = '<div class="character-list-header"><p>My Characters</p></div>';
    for (let i = 1; i <= NChar; i++) {
        htmlResult += '<div class="character" id="char-' + i + '" data-cid=""><span id="slot-name">Empty Slot<span id="cid"></span></span></div>';
    }
    htmlResult += '<div class="character-btn" id="play"><p id="play-text">Select a character</p></div><div class="character-btn" id="delete"><p id="delete-text">Select a character</p></div>';
    $('.characters-list').html(htmlResult);
}

function refreshCharacters() {
    setCharactersList();
    setTimeout(function () {
        if (selectedChar) $(selectedChar).removeClass('char-selected');
        selectedChar = null;
        nui('setupCharacters');
        $('#delete').css({ display: 'none' });
        $('#play').css({ display: 'none' });
        $('.character-info-valid').html('<span id="no-char">Select a character slot to see all information about your character.</span>');
    }, 100);
}

$('#close-reg').click(function (event) {
    event.preventDefault();
    $('.characters-list').css('filter', 'none');
    $('.character-info').css('filter', 'none');
    qbMultiCharacters.fadeOutDown('.character-register', '125%', 400);
    resetCreateForm();
});

$(document).on('click', '#play', function (event) {
    event.preventDefault();
    if (selectedChar === null) return;

    const charData = $(selectedChar).data('cid');
    if (charData !== '') {
        nui('selectCharacter', { cData: $(selectedChar).data('cData') });
        setTimeout(function () {
            qbMultiCharacters.fadeOutDown('.characters-list', '-40%', 400);
            qbMultiCharacters.fadeOutDown('.character-info', '-40%', 400);
            qbMultiCharacters.resetAll();
        }, 1500);
    } else {
        resetCreateForm();
        $('.characters-list').css('filter', 'blur(2px)');
        $('.character-info').css('filter', 'blur(2px)');
        qbMultiCharacters.fadeInDown('.character-register', '25%', 400);
        setTimeout(function () { $('#firstname').trigger('focus'); }, 450);
    }
});

$(document).on('click', '#delete', function (event) {
    event.preventDefault();
    if (selectedChar !== null && $(selectedChar).data('cid') !== '') {
        $('.character-delete').fadeIn(250);
    }
});

qbMultiCharacters.fadeOutUp = function (element, time) {
    $(element).css({ display: 'block' }).animate({ top: '-80.5%' }, time, function () {
        $(element).css({ display: 'none' });
    });
};

qbMultiCharacters.fadeOutDown = function (element, percent, time) {
    const target = percent !== undefined ? percent : '103.5%';
    $(element).css({ display: 'block' }).animate({ top: target }, time, function () {
        $(element).css({ display: 'none' });
    });
};

qbMultiCharacters.fadeInDown = function (element, percent, time) {
    $(element).css({ display: 'block' }).animate({ top: percent }, time);
};

qbMultiCharacters.resetAll = function () {
    $('.characters-list').hide().css('top', '-40');
    $('.character-info').hide().css('top', '-40');
    $('.welcomescreen').css('top', WelcomePercentage);
    $('.server-log').show().css('top', '25%');
};
