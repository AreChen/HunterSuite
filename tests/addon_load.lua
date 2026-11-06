-- Smoke-test the TOC load order with minimal WoW API stubs; run with Lua 5.1.
local expected = { enUS = "Overview", zhCN = "总览", zhTW = "總覽", deDE = "Overview" }
local expectedMeat = { enUS = "Meat", zhCN = "肉", zhTW = "肉", deDE = "Meat" }
local expectedFish = { enUS = "Fish", zhCN = "鱼", zhTW = "魚", deDE = "Fish" }
local files = {}
for line in io.lines("HunterSuite.toc") do
    local path = line:match("^%s*([^#].-%.lua)%s*$")
    if path then files[#files + 1] = path:gsub("\\", "/") end
end
assert(#files > 0, "TOC did not contain Lua files")

local frame = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return frame end
UIParent = { CreateTexture = function() return frame end }
GetBuildInfo = function() return "1.60.1", "", "", 16001 end
STANDARD_TEXT_FONT = "game-font"
local media = {
    IsValid = function(_, kind, name) return kind == "font" and name == "Expressway" end,
    Fetch = function() return "shared-latin-font" end,
}
LibStub = function(name) if name == "LibSharedMedia-3.0" then return media end end
wipe = function(t) for key in pairs(t) do t[key] = nil end end
GetTime = function() return 100 end
UnitIsDeadOrGhost = function() return false end
UnitOnTaxi = function() return false end
IsMounted = function() return false end
UnitAffectingCombat = function() return true end
SlashCmdList = {}
StaticPopupDialogs = {}

for locale, overview in pairs(expected) do
    GetLocale = function() return locale end
    local addon = {}
    for _, path in ipairs(files) do
        local chunk, err = loadfile(path)
        assert(chunk, path .. ": " .. tostring(err))
        -- Embedded third-party libraries are unchanged and need real WoW APIs.
        if not path:match("^Libs/") then
            local ok, loadError = pcall(chunk, "HunterSuite", addon)
            assert(ok, locale .. " " .. path .. ": " .. tostring(loadError))
        end
    end
    assert(addon.Options.pages[1].title == overview, locale .. ": incorrect page title")
    assert(addon.Spells.Name(75) == addon.L.AUTO_SHOT, locale .. ": incorrect spell fallback")
    local expectedFont = (locale == "enUS" or locale == "deDE") and "shared-latin-font" or "game-font"
    assert(addon.UI:FontPath() == expectedFont, locale .. ": incorrect automatic font")

    -- Exercise actual dynamic aspect alerts and client-provided spell names.
    local displayed = {}
    addon.Alerts = {
        Set = function(_, key, value) displayed[key] = value end,
        Clear = function(_, key) displayed[key] = nil end,
    }
    addon.Compat.GetSpellName = function(id) if id == 5118 then return "client aspect" end end
    addon.Compat.GetSpellTexture = function() return 1 end
    local hasAspect = true
    addon.Compat.ForEachAura = function(_, _, callback)
        if hasAspect then callback({ spellId = 5118 }) end
        return true
    end
    local aspects = addon:GetModule("aspects")
    aspects.db = { warnMovementInCombat = true }
    aspects:OnInitialize()
    aspects:Scan()
    aspects:Evaluate()
    assert(displayed["aspect.movement"].title == addon.L.S_IN_COMBAT:format("client aspect"), locale .. ": aspect title")
    hasAspect = false
    aspects:Scan()
    aspects:Evaluate()
    assert(displayed["aspect.none"].tooltip == addon.L.CAST_AN_ASPECT_E_G_S:format(addon.L.ASPECT_OF_THE_HAWK), locale .. ": aspect tooltip")

    -- When diet APIs return no names, use the language-neutral family ID.
    addon.Compat.GetPetFoodTypes = function() return {} end
    UnitCreatureFamily = function() return "localized family", 2 end -- Cat
    local pet = addon:GetModule("petBar")
    local diet, mask = pet:GetDiet()
    assert(mask == 3, locale .. ": localized pet family diet")
    assert(diet[1] == expectedMeat[locale] and diet[2] == expectedFish[locale], locale .. ": localized diet labels")

    -- Older clients can resolve the localized family name through their API.
    UnitCreatureFamily = function() return "localized family" end
    C_CreatureInfo = { GetCreatureFamilyInfo = function(id)
        if id == 2 then return { name = "localized family" } end
    end }
    diet, mask = pet:GetDiet()
    assert(mask == 3 and diet[1] == expectedMeat[locale], locale .. ": localized family lookup")
    C_CreatureInfo = nil

    -- Check references in every addon source, including lazy UI paths.
    for _, path in ipairs(files) do
        if not path:match("^Libs/") then
            local file = assert(io.open(path, "rb"))
            local source = file:read("*a")
            file:close()
            for key in source:gmatch("%f[%w_]L%.([A-Z][A-Z0-9_]*)") do
                assert(addon.L_DEFAULTS[key], path .. ": undefined localization key " .. key)
            end
        end
    end
end

print("TOC load order and Lua syntax passed for four locales")
