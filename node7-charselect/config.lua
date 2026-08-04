Config = {}

Config.DefaultNumberOfCharacters = 5
Config.PlayersNumberOfCharacters = {
    -- { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 5 },
}

Config.DefaultSpawn = vector4(-264.5182, 794.3061, 118.4721, 286.0)
Config.DefaultNationality = 'American'
Config.AllowDelete = true
Config.DisconnectMessage = 'You have disconnected from NODE7.'

Config.Identity = {
    firstNameMin = 2,
    firstNameMax = 30,
    lastNameMin = 2,
    lastNameMax = 30,
    nationalityMax = 40,
    minimumBirthYear = 1800,
    maximumBirthYear = 1911,
}

Config.DefaultAppearance = {
    male = {
        sex = 1,
        model = 'mp_male',
    },
    female = {
        sex = 2,
        model = 'mp_female',
    },
}

Config.UseSelectionWeather = false
Config.SelectionWeatherResource = 'weathersync'
Config.SelectionHour = 21
Config.SelectionWeather = 'sunny'
