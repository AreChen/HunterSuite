-- Run from the repository root with Lua 5.1 or a compatible interpreter.
local function load(path, addon)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    chunk("HunterSuite", addon)
end

local function rotationFor(talentName, rank, aura, weave)
    GetLocale = function() return "zhTW" end
    GetTime = function() return 100 end
    GetNumTalents = function() return 1 end
    GetTalentInfo = function() return talentName, nil, nil, nil, rank end
    UnitRangedDamage = function() return 2.5 end

    local addon = {
        UI = {},
        Spells = {},
        state = { editMode = false },
        Compat = {
            Readable = function(value) return value end,
            GetSpellName = function(id)
                if id == 34466 then return "蛇之迅捷" end
                if id == 6150 then return "快速射擊" end
            end,
            ForEachAura = function(_, _, callback)
                if aura then callback(aura) end
            end,
        },
    }
    function addon:NewModule(_, info) self.weaving = info; return info end
    function addon:On() end
    load("Locales/enUS.lua", addon)
    load("Locales/zhCN.lua", addon)
    load("Locales/zhTW.lua", addon)
    load("Modules/WeavingBar.lua", addon)

    local title
    local module = addon.weaving
    module.db = { weave = weave, hideIdle = false }
    module.frame = {
        title = { SetText = function(_, value) title = value end },
        ews = { SetFormattedText = function() end },
        hint = { Hide = function() end },
    }
    module.Render = function() end
    module:ScanBuffs()
    module:DetectSpec()
    module:SelectRotation()
    module:OnUpdate(0.3)
    return title, addon.L
end

local title, L = rotationFor("蛇之迅捷", 5, nil, false)
assert(title == L.FRENCH_5_5_1_1, "localized beast mastery talent must select the beast mastery rotation")

title, L = rotationFor("蛇之迅捷", 0, nil, false)
assert(title == L.SHORT_FRENCH_5_4_1_1, "unlearned beast mastery talent must not select the beast mastery rotation")

title, L = rotationFor("蛇之迅捷", 5, { spellId = 6150, name = "快速射擊", expirationTime = 120 }, true)
assert(title == L.TEXT_1_1_HALF_WEAVE, "localized Quick Shots aura must affect the weaving rotation")

print("Localized weaving talent and aura detection passed")
