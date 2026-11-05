--[[
    HunterSuite - API compatibility
    One place that knows which API generation the client speaks. Forever runs
    the 12.x engine (C_Spell, C_UnitAuras, C_Container, C_Item, secret values);
    the TBC Anniversary client still has most of the classic globals.
]]

local _, HS = ...

local C = {}
HS.Compat = C

local _G = _G
local type, select, pcall = type, select, pcall
local C_Spell, C_UnitAuras, C_Container, C_Item = C_Spell, C_UnitAuras, C_Container, C_Item

---------------------------------------------------------------------------
-- Secret values (12.x). A secret can be passed around but not compared or
-- used in arithmetic, so anything we compute with goes through Readable().
---------------------------------------------------------------------------

-- Never compare or boolean-test a value that might be secret before asking
-- issecretvalue: on 12.x either is a hard Lua error.
local issecretvalue = _G.issecretvalue
function C.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

function C.Readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local Readable = C.Readable

-- Are aura reads restricted right now (combat, encounters, PvP matches)?
-- While they are, an index scan can throw, so callers keep their last answer.
local C_Secrets = _G.C_Secrets
function C.AurasRestricted()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and res == true then return true end
        if ok then return false end
    end
    if issecretvalue and InCombatLockdown() then return true end
    return false
end

function C.CooldownsRestricted()
    if C_Secrets and C_Secrets.ShouldCooldownsBeSecret then
        local ok, res = pcall(C_Secrets.ShouldCooldownsBeSecret)
        if ok then return res == true end
    end
    return false
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

local legacyGetSpellInfo = _G.GetSpellInfo

function C.GetSpellName(spell)
    if not spell then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spell)
        if ok and name then return name end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spell)
        if ok and type(info) == "table" then return info.name end
    end
    if legacyGetSpellInfo then
        return (legacyGetSpellInfo(spell))
    end
end

function C.GetSpellTexture(spell)
    if not spell then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
        if ok and tex then return tex end
    end
    if _G.GetSpellTexture then
        return _G.GetSpellTexture(spell)
    end
    if legacyGetSpellInfo then
        return select(3, legacyGetSpellInfo(spell))
    end
end

-- Returns a spell ID for a spell the player can cast, looked up by name or ID.
function C.GetSpellID(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spell)
        if ok and type(info) == "table" then return info.spellID end
    end
    if legacyGetSpellInfo then
        return select(7, legacyGetSpellInfo(spell))
    end
end

function C.IsKnown(spellID)
    if not spellID then return false end
    if _G.IsPlayerSpell and _G.IsPlayerSpell(spellID) then return true end
    if _G.IsSpellKnown and _G.IsSpellKnown(spellID) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    return false
end

-- True when any rank of the spell is known. `ids` is a list of rank IDs.
function C.KnowsAny(ids)
    for i = 1, #ids do
        if C.IsKnown(ids[i]) then return true, ids[i] end
    end
    return false
end

-- start, duration (seconds) of a spell cooldown; nil when unreadable.
function C.GetSpellCooldown(spell)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
        if ok and type(info) == "table" then
            return Readable(info.startTime), Readable(info.duration)
        end
        return nil
    end
    if _G.GetSpellCooldown then
        local start, duration = _G.GetSpellCooldown(spell)
        return start, duration
    end
end

-- The global cooldown. Forever reports nothing on 61304 and uses the classic
-- reference spell 29515, so try both and keep whichever answers.
local GCD_SPELLS = { 61304, 29515 }
function C.GetGCD()
    for i = 1, #GCD_SPELLS do
        local start, duration = C.GetSpellCooldown(GCD_SPELLS[i])
        if start and duration and start > 0 and duration > 0 and duration <= 2 then
            return start, duration
        end
    end
    return 0, 0
end

-- true / false / nil (nil = the check does not apply to this unit)
function C.IsSpellInRange(spell, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, res = pcall(C_Spell.IsSpellInRange, spell, unit)
        if ok then
            res = Readable(res)
            if res == nil then return nil end
            return res == true or res == 1
        end
        return nil
    end
    if _G.IsSpellInRange then
        local name = type(spell) == "number" and C.GetSpellName(spell) or spell
        if not name then return nil end
        local res = _G.IsSpellInRange(name, unit)
        if res == nil then return nil end
        return res == 1
    end
end

function C.IsAutoRepeat(spell)
    if C_Spell and C_Spell.IsAutoRepeatSpell then
        local ok, res = pcall(C_Spell.IsAutoRepeatSpell, spell)
        if ok then return res and true or false end
    end
    if _G.IsAutoRepeatSpell then
        local name = type(spell) == "number" and C.GetSpellName(spell) or spell
        return name and _G.IsAutoRepeatSpell(name) and true or false
    end
    return false
end

---------------------------------------------------------------------------
-- Auras
---------------------------------------------------------------------------

local SCAN_FAILED = {}
local unpackAura
if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local GetAuraDataByIndex = C_UnitAuras.GetAuraDataByIndex
    unpackAura = function(unit, index, filter)
        local ok, aura = pcall(GetAuraDataByIndex, unit, index, filter)
        if ok then return aura end
        return SCAN_FAILED
    end
elseif _G.UnitAura then
    local UnitAura = _G.UnitAura
    unpackAura = function(unit, index, filter)
        local name, icon, count, dispel, duration, expiration, source, _, _, spellId = UnitAura(unit, index, filter)
        if not name then return nil end
        return {
            name = name, icon = icon, applications = count, dispelName = dispel,
            duration = duration, expirationTime = expiration, sourceUnit = source,
            spellId = spellId,
        }
    end
end

-- Calls fn(aura, index) for each aura; fn returns true to stop. Auras whose
-- identifying fields are secret are skipped: we cannot tell what they are.
-- Returns true only when every aura could be read. False means the client
-- refused (restricted) or hid some auras, so callers keep their last answer.
function C.ForEachAura(unit, filter, fn)
    if not unpackAura or not unit then return false end
    if C.AurasRestricted() then return false end
    local complete = true
    for i = 1, 40 do
        local aura = unpackAura(unit, i, filter)
        if aura == SCAN_FAILED then return false end
        if not aura then return complete end
        if C.IsSecret(aura.spellId) or C.IsSecret(aura.name) then
            complete = false
        elseif fn(aura, i) then
            return true -- a match is reliable even if other auras were hidden
        end
    end
    return complete
end

-- First aura whose spellId is in `ids` (a set) or whose name is in `names`.
-- Second return is false when auras could not be read at all.
function C.FindAura(unit, filter, ids, names)
    local found
    local scanned = C.ForEachAura(unit, filter, function(aura)
        if (ids and ids[aura.spellId]) or (names and aura.name and names[aura.name]) then
            found = aura
            return true
        end
    end)
    return found, scanned
end

-- duration/expiration in plain numbers, or nil when the client hides them.
function C.AuraTimes(aura)
    if not aura then return nil end
    local duration, expiration = Readable(aura.duration), Readable(aura.expirationTime)
    if not duration or not expiration then return nil end
    return duration, expiration
end

-- Did the player cast this aura? Handles the "player"/"pet" source tokens.
function C.IsFromPlayer(aura)
    local src = Readable(aura.sourceUnit)
    if src == "player" or src == "vehicle" then return true end
    if Readable(aura.isFromPlayerOrPlayerPet) and src ~= "pet" then return true end
    return false
end

---------------------------------------------------------------------------
-- Items and bags
---------------------------------------------------------------------------

C.NUM_BAGS = _G.NUM_BAG_SLOTS or 4

function C.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return _G.GetContainerNumSlots and _G.GetContainerNumSlots(bag) or 0
end

function C.GetContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return _G.GetContainerItemID and _G.GetContainerItemID(bag, slot)
end

function C.GetContainerItemCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.stackCount or 0
    end
    if _G.GetContainerItemInfo then
        local _, count = _G.GetContainerItemInfo(bag, slot)
        return count or 0
    end
    return 0
end

-- Iterate every occupied bag slot: fn(bag, slot, itemID).
function C.ForEachBagItem(fn)
    for bag = 0, C.NUM_BAGS do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local itemID = C.GetContainerItemID(bag, slot)
            if itemID then
                if fn(bag, slot, itemID) then return end
            end
        end
    end
end

function C.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end
    return _G.GetItemInfo(item)
end

function C.GetItemInfoInstant(item)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(item)
    end
    return _G.GetItemInfoInstant(item)
end

function C.GetItemCount(item)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(item) or 0
    end
    return _G.GetItemCount and _G.GetItemCount(item) or 0
end

function C.GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    return _G.GetItemIcon and _G.GetItemIcon(itemID)
end

-- Ask the client to load item data; cb runs when it is available.
function C.RequestItem(itemID, cb)
    if Item and Item.CreateFromItemID then
        local item = Item:CreateFromItemID(itemID)
        if item and not item:IsItemEmpty() then
            item:ContinueOnItemLoad(cb)
            return
        end
    end
    cb()
end

---------------------------------------------------------------------------
-- Tracking (minimap). On Forever the hunter trackers are also self-buffs,
-- so callers check both.
---------------------------------------------------------------------------

function C.GetNumTracking()
    if C_Minimap and C_Minimap.GetNumTrackingTypes then
        return C_Minimap.GetNumTrackingTypes() or 0
    end
    return _G.GetNumTrackingTypes and _G.GetNumTrackingTypes() or 0
end

-- name, active, spellID
function C.GetTrackingInfo(i)
    if C_Minimap and C_Minimap.GetTrackingInfo then
        local info = C_Minimap.GetTrackingInfo(i)
        if type(info) == "table" then
            return info.name, info.active, info.spellID
        end
        -- some builds return multiple values
        local name, _, active = C_Minimap.GetTrackingInfo(i)
        return name, active
    end
    if _G.GetTrackingInfo then
        local name, _, active = _G.GetTrackingInfo(i)
        return name, active
    end
end

-- Classic-era single-tracking API (GetTrackingTexture) for completeness.
function C.GetActiveTrackingTexture()
    return _G.GetTrackingTexture and _G.GetTrackingTexture()
end

---------------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------------

function C.HasHunterPet()
    local hasUI, isHunterPet = HasPetUI()
    return hasUI and isHunterPet and true or false
end

-- Forever moved the pet globals into C_PetInfo (GetPetFoodTypes now returns
-- a table); TBC Anniversary still has the globals.
local C_PetInfo = _G.C_PetInfo

-- happiness (1-3), damage percent, loyalty rate. nil when unavailable.
function C.GetPetHappiness()
    local happiness, damage, loyalty
    if C_PetInfo and C_PetInfo.GetPetHappiness then
        happiness, damage, loyalty = C_PetInfo.GetPetHappiness()
    elseif _G.GetPetHappiness then
        happiness, damage, loyalty = _G.GetPetHappiness()
    end
    return Readable(happiness), Readable(damage), Readable(loyalty)
end

-- List of diet names ("Meat", "Fish", ...), possibly empty.
function C.GetPetFoodTypes()
    local out = {}
    if C_PetInfo and C_PetInfo.GetPetFoodTypes then
        local list = C_PetInfo.GetPetFoodTypes()
        if type(list) == "table" then
            for i = 1, #list do out[#out + 1] = list[i] end
        end
        return out
    end
    if _G.GetPetFoodTypes then
        local values = { _G.GetPetFoodTypes() }
        for i = 1, #values do
            -- some clients return one comma separated string
            for name in tostring(values[i]):gmatch("[^,]+") do
                out[#out + 1] = name:match("^%s*(.-)%s*$")
            end
        end
    end
    return out
end

function C.GetPetLoyalty()
    if C_PetInfo and C_PetInfo.GetPetLoyalty then
        return Readable(C_PetInfo.GetPetLoyalty())
    end
    if _G.GetPetLoyalty then
        return Readable(_G.GetPetLoyalty())
    end
end

-- true/false when the client can tell, nil when we must guess from our table.
function C.CanPetEat(itemID)
    if C_PetInfo and C_PetInfo.CanPetEatItem then
        local ok, res = pcall(C_PetInfo.CanPetEatItem, itemID)
        if ok then return Readable(res) end
    end
    return nil
end

function C.UnitHealthFraction(unit)
    local hp, max = Readable(UnitHealth(unit)), Readable(UnitHealthMax(unit))
    if not hp or not max or max <= 0 then return nil end
    return hp / max
end

-- name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
-- in the modern return order (the 3.x addon misread these on TBC Anniversary).
-- Pre-2019 clients put a rank subtext second and returned 7 values.
local function PackPetAction(...)
    if select("#", ...) >= 8 then
        return ...
    end
    local name, _, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = ...
    return name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, nil
end

function C.GetPetActionInfo(index)
    local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = PackPetAction(GetPetActionInfo(index))
    if isToken and name and _G[name] then name = _G[name] end
    return name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
end

---------------------------------------------------------------------------
-- Swing timer (Forever ships Blizzard_SwingTimer and C_SwingTimer)
---------------------------------------------------------------------------

C.HasSwingAPI = (_G.C_SwingTimer ~= nil and _G.Enum ~= nil and _G.Enum.PlayerSwingType ~= nil)
C.SwingType = C.HasSwingAPI and _G.Enum.PlayerSwingType or { MainHand = 0, OffHand = 1, Ranged = 2 }

function C.EnableSwingRangeCheck(swingType)
    if C.HasSwingAPI and C_SwingTimer.EnableRangeCheck then
        pcall(C_SwingTimer.EnableRangeCheck, swingType, true)
    end
end

-- true/false, or nil when the client cannot tell.
function C.IsInSwingRange(swingType)
    if C.HasSwingAPI and C_SwingTimer.IsTargetWithinSwingRange then
        local ok, res = pcall(C_SwingTimer.IsTargetWithinSwingRange, swingType)
        if ok then return Readable(res) end
    end
    return nil
end

---------------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------------

function C.GetLatency()
    local _, _, home, world = GetNetStats()
    return math.max(home or 0, world or 0) / 1000
end

function C.IsInPvP()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

function C.IsInGroupInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

function C.CanMark()
    if IsInRaid and IsInRaid() then
        if UnitIsGroupLeader then
            return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        end
        return (_G.IsRaidLeader and _G.IsRaidLeader()) or (_G.IsRaidOfficer and _G.IsRaidOfficer())
    end
    return true
end

function C.PlaySound(kit)
    if not HS.db or not HS.db.appearance.sounds then return end
    if type(kit) == "number" then
        PlaySound(kit, "Master")
    elseif type(kit) == "string" then
        PlaySoundFile(kit, "Master")
    end
end

-- Report which interesting APIs exist on this client (for /hs diag).
function C.Inventory()
    local function has(path)
        local node = _G
        for key in path:gmatch("[^%.]+") do
            node = type(node) == "table" and node[key] or nil
            if node == nil then return false end
        end
        return true
    end
    local list = {
        "C_SwingTimer.IsTargetWithinSwingRange", "C_Spell.GetSpellCooldown", "C_Spell.IsSpellInRange",
        "C_UnitAuras.GetAuraDataByIndex", "C_Container.GetContainerItemInfo", "C_Item.GetItemInfo",
        "GetPetHappiness", "GetPetFoodTypes", "GetPetLoyalty", "GetSpellInfo", "UnitAura", "UnitBuff",
        "CombatLogGetCurrentEventInfo", "issecretvalue", "C_Minimap.GetTrackingInfo", "GetTrackingTexture",
        "Settings.RegisterCanvasLayoutCategory", "InterfaceOptions_AddCategory", "C_DurationUtil.CreateDuration",
    }
    local out = {}
    for _, path in ipairs(list) do
        out[#out + 1] = { path, has(path) }
    end
    return out
end
