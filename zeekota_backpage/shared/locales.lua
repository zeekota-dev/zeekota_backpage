Locales = Locales or {}

ZeeKotaLocale = ZeeKotaLocale or {}

function ZeeKotaLocale.Get(locale)
    locale = locale or (Config and Config.Locale) or 'en'
    return Locales[locale] or Locales.en or {}
end

function ZeeKotaLocale.T(key, replacements)
    local locale = ZeeKotaLocale.Get()
    local phrase = locale[key]
    if phrase == nil and type(key) == 'string' then
        local cursor = locale
        for part in key:gmatch('[^%.]+') do
            cursor = type(cursor) == 'table' and cursor[part] or nil
            if cursor == nil then break end
        end
        phrase = cursor
    end
    phrase = type(phrase) == 'string' and phrase or key

    for name, value in pairs(replacements or {}) do
        phrase = phrase:gsub(('%%{%s%%}'):format(name), tostring(value))
    end

    return phrase
end
