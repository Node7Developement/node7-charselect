Translations = Translations or {
    notifications = {
        ["char_deleted"] = "Karakter kitörölve!",
        ["deleted_other_char"] = "Kitörölted ezt a Citizen ID-t: %{citizenid}.",
        ["forgot_citizenid"] = "Elfelejtetted megadni a következöt: citizen id!",
    },

    commands = {
        -- /deletechar
        ["deletechar_description"] = "Játékos törlése",
        ["citizenid"] = "Citizen ID",
        ["citizenid_help"] = "Citizen ID megadása a karakter törléséhez",

        -- /logout
        ["logout_description"] = "Kijelentkezés (Admin Only)",

        -- /closeNUI
        ["closeNUI_description"] = "Bezárás: Multi NUI"
    },

    misc = {
        ["droppedplayer"] = "Lekapcsolódtál a szerverröl. Várunk vissza! 🤠"
    },

    ui = {
        -- Main
        characters_header = "Karaktereim",
        emptyslot = "Üres",
        play_button = "Játék",
        create_button = "Karakter készítése",
        delete_button = "Karakter törlése",

        -- Character Information
        charinfo_header = "Karakter információ",
        charinfo_description = "Válassz ki egy karaktert, hogy megtekinthess minden információt róla.",
        name = "Név",
        male = "Férfi",
        female = "Nő",
        firstname = "Keresztnév",
        lastname = "Vezetéknév",
        nationality = "Nemzetiség",
        gender = "Neme",
        birthdate = "Születésnap",
        job = "Munkahely",
        jobgrade = "Beosztás",
        cash = "Készpénz",
        bank = "Bank vagyon",
        phonenumber = "Telefonszám",
        accountnumber = "Számlaszám",

        chardel_header = "Új karakter készítés, mehet?",

        -- Delete character
        deletechar_header = "Karakter törlése",
        deletechar_description = "Biztos vagy benne, hogy ki szeretnéd törölni?",

        -- Buttons
        cancel = "Vissza",
        confirm = "Elfogad",

        -- Loading Text
        retrieving_playerdata = "Adatok lekérése",
        validating_playerdata = "Adatok hitelesítése",
        retrieving_characters = "Karakterek lekérése",
        validating_characters = "Karakterek hitelesítése",

        -- Notifications
        ran_into_issue = "Problémába ütköztünk..",
        profanity = "Úgy tünik, hogy káromkodást/rossz szavakat próbáltál használni a nevedben vagy nemzetiségedben!",
        forgotten_field = "Úgy tünik, hogy elfelejtettél kitölteni egy vagy több mezőt!"
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
