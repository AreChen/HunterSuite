-- Run from the repository root with Lua 5.1 or a compatible interpreter.
local function load(path, addon)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    chunk("HunterSuite", addon)
end

local function addonFor(locale)
    GetLocale = function() return locale end
    local addon = { UI = { tex = { logo = 1 } }, moduleOrder = {} }
    load("Locales/enUS.lua", addon)
    load("Locales/zhCN.lua", addon)
    load("Locales/zhTW.lua", addon)
    return addon
end

local expected = {
    enUS = { overview = "Overview", pet = "Pet", shot = "Auto Shot" },
    deDE = { overview = "Overview", pet = "Pet", shot = "Auto Shot" },
    zhCN = { overview = "总览", pet = "宠物", shot = "自动射击" },
    zhTW = { overview = "總覽", pet = "寵物", shot = "自動射擊" },
}

for locale, want in pairs(expected) do
    local addon = addonFor(locale)
    load("UI/Options.lua", addon)
    local pages = addon.Options.pages
    assert(pages[1].title == want.overview, locale .. ": overview")
    assert(pages[2].title == want.pet, locale .. ": pet")
    assert(pages[3].title == want.shot, locale .. ": auto shot")
    assert(pages[2].sections[1].items[1].values[1][1] == "smart", locale .. ": saved option value changed")
    assert(pages[2].sections[1].items[1].values[1][2] ~= "", locale .. ": option label missing")
end

-- Spell IDs use the client's names first; unavailable data still gets a
-- localized fallback, while English names remain in the compatibility set.
do
    local addon = addonFor("zhCN")
    addon.Compat = { GetSpellName = function(id) if id == 6991 then return "客户端技能名" end end }
    load("Data/Spells.lua", addon)
    assert(addon.Spells.Name(6991) == "客户端技能名", "client spell name takes precedence")
    assert(addon.Spells.Name(75) == "自动射击", "missing spell data needs a localized fallback")
    local _, names = addon.Spells.Sets({ 75 })
    assert(names["自动射击"] and names["Auto Shot"], "spell matching retains both names")
end

local defaults = getmetatable(addonFor("enUS").L).__index
local function formats(value)
    local result = {}
    value = value:gsub("%%%%", "")
    for spec in value:gmatch("%%[-+ #0]*%d*%.?%d*[cdeEfgGiouxXsq]") do
        result[#result + 1] = spec
    end
    return table.concat(result, "|")
end

for _, locale in ipairs({ "zhCN", "zhTW" }) do
    local addon = addonFor(locale)
    for key, english in pairs(defaults) do
        local translated = rawget(addon.L, key)
        assert(type(translated) == "string" and translated ~= "", locale .. ": missing " .. key)
        assert(formats(translated) == formats(english), locale .. ": format mismatch for " .. key)
    end
    for key in pairs(addon.L) do
        assert(defaults[key] ~= nil, locale .. ": unknown key " .. key)
    end
end

print("Localization behavior and translation coverage passed")
