--[[
    HunterSuite - spell data
    Every rank ID we know for each hunter ability (vanilla ranks plus the TBC
    ranks), with lookups by ID and by localized name. Forever uses vanilla
    ranks; names are resolved from the client so other locales match too.
]]

local _, HS = ...
local C, L = HS.Compat, HS.L

local S = {}
HS.Spells = S

S.AUTO_SHOT = 75
S.FEED_PET = 6991
S.FEED_PET_EFFECT = { 1539 }
S.MEND_PET = { 136, 3111, 3661, 3662, 13542, 13543, 13544, 27046 }
S.CALL_PET = { 883 }
S.REVIVE_PET = { 982 }
S.DISMISS_PET = { 2641 }
S.RAPTOR_STRIKE = { 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014 }
S.WING_CLIP = { 2974, 14267, 14268 }
S.ARCANE_SHOT = { 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 14288, 27019 }
S.STEADY_SHOT = { 34120 }
S.FEIGN_DEATH = { 5384 }
S.GROWL = { 2649, 14916, 14917, 14918, 14919, 14920, 14921, 27047 }

-- Aspects. `movement` marks the ones that daze you when hit (bad in combat).
-- Forever IDs from its SpellName table (build 1.60.1) are included.
S.ASPECTS = {
    { key = "hawk",    ids = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044 } },
    { key = "monkey",  ids = { 13163 } },
    { key = "cheetah", ids = { 5118 },  movement = true },
    { key = "pack",    ids = { 13159 }, movement = true },
    { key = "beast",   ids = { 13161, 1299445, 1299446, 1299447 } },
    { key = "wild",    ids = { 20043, 20190, 27045 } },
    { key = "viper",   ids = { 34074, 415423, 415424, 415718 } },
}

-- Traps: the placed spell and the effect it leaves on whatever it catches.
S.TRAPS = {
    { key = "freezing",  place = { 1499, 14310, 14311 },        effect = { 3355, 14308, 14309 }, cc = true },
    { key = "frost",     place = { 13809 },                     effect = { 13810 } },
    { key = "immolation", place = { 13795, 14302, 14303, 14304, 14305, 27023 }, effect = { 13797, 14298, 14299, 14300, 14301, 27024 } },
    { key = "explosive", place = { 13813, 14316, 14317, 27025 }, effect = { 13812, 14314, 14315, 27026 } },
    { key = "snake",     place = { 34600 },                     effect = {} },
}

-- Debuffs worth a nameplate timer. `duration` is the base length, used when
-- the client will not tell us (aura data is secret in combat on Forever).
S.STINGS = {
    { key = "serpent", duration = 15, ids = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, 27016 } },
    { key = "scorpid", duration = 20, ids = { 3043, 14275, 14276, 14277, 27060 } },
    { key = "viper",   duration = 8,  ids = { 3034, 14279, 14280, 27018 } },
    { key = "wyvern",  duration = 12, ids = { 19386, 24132, 24133, 27068 } },
}
S.HUNTERS_MARK = { 1130, 14323, 14324, 14325 }
S.HUNTERS_MARK_DURATION = 120

S.TRACKING = {
    beasts = 1494, humanoids = 19883, undead = 19884, hidden = 19885,
    elementals = 19880, demons = 19878, giants = 19882, dragonkin = 19879,
}

-- Locale keys for names used when the client cannot resolve an ID.
local SPELL_KEYS = {
    [75] = "AUTO_SHOT", [6991] = "FEED_PET", [1539] = "FEED_PET_EFFECT", [136] = "MEND_PET",
    [883] = "CALL_PET", [982] = "REVIVE_PET", [2649] = "GROWL", [5384] = "FEIGN_DEATH",
    [13165] = "ASPECT_OF_THE_HAWK", [13163] = "ASPECT_OF_THE_MONKEY", [5118] = "ASPECT_OF_THE_CHEETAH",
    [13159] = "ASPECT_OF_THE_PACK", [13161] = "ASPECT_OF_THE_BEAST", [20043] = "ASPECT_OF_THE_WILD",
    [34074] = "ASPECT_OF_THE_VIPER", [1499] = "FREEZING_TRAP", [13809] = "FROST_TRAP",
    [13795] = "IMMOLATION_TRAP", [13813] = "EXPLOSIVE_TRAP", [34600] = "SNAKE_TRAP",
    [3355] = "FREEZING_TRAP_EFFECT", [13810] = "FROST_TRAP_AURA", [13797] = "IMMOLATION_TRAP_EFFECT",
    [13812] = "EXPLOSIVE_TRAP_EFFECT", [1978] = "SERPENT_STING", [3043] = "SCORPID_STING",
    [3034] = "VIPER_STING", [19386] = "WYVERN_STING", [1130] = "HUNTERS_MARK", [19883] = "TRACK_HUMANOIDS",
    [2973] = "RAPTOR_STRIKE", [2974] = "WING_CLIP", [3044] = "ARCANE_SHOT", [34120] = "STEADY_SHOT",
}

local nameCache = {}
function S.Name(id)
    if type(id) == "table" then id = id[1] end
    if not id then return nil end
    local cached = nameCache[id]
    if cached then return cached end
    local name = C.GetSpellName(id)
    if name then
        nameCache[id] = name
        return name
    end
    return L[SPELL_KEYS[id]]
end

function S.Icon(id)
    if type(id) == "table" then id = id[1] end
    return C.GetSpellTexture(id)
end

-- Build {id=true} and {localizedName=true} sets from a list of rank IDs.
function S.Sets(ids)
    local idSet, nameSet = {}, {}
    for i = 1, #ids do
        idSet[ids[i]] = true
    end
    local name = S.Name(ids)
    if name then nameSet[name] = true end
    local english = HS.L_DEFAULTS[SPELL_KEYS[ids[1]]]
    if english then nameSet[english] = true end
    return idSet, nameSet
end

-- Does a cast (spellID from UNIT_SPELLCAST_*) belong to this rank list?
function S.Matches(ids, spellID)
    if not spellID then return false end
    for i = 1, #ids do
        if ids[i] == spellID then return true end
    end
    local name = C.GetSpellName(spellID)
    return name ~= nil and name == S.Name(ids)
end

function S.Known(ids)
    if C.KnowsAny(ids) then return true end
    -- Forever's rank scheme may use new IDs; fall back to a name lookup.
    local name = S.Name(ids)
    return name ~= nil and C.GetSpellID(name) ~= nil
end
