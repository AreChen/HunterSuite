--[[
    HunterSuite - aspect reminder
    Warns when no aspect is up, and when Cheetah or Pack is still on in
    combat (you get dazed). Aura data is secret in combat on Forever, so the
    active aspect comes from an aura scan whenever reads are allowed and is
    kept current in combat from your own aspect casts.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Aspects = HS:NewModule("aspects", { title = L.ASPECT_REMINDER })

local idToAspect, nameToAspect = {}, {}
local current            -- aspect entry or nil
local snoozedUntil = 0

local function BuildLookups()
    wipe(idToAspect)
    wipe(nameToAspect)
    for _, aspect in ipairs(S.ASPECTS) do
        for _, id in ipairs(aspect.ids) do idToAspect[id] = aspect end
        local name = S.Name(aspect.ids)
        if name then nameToAspect[name] = aspect end
    end
end

function Aspects:IsSupported()
    for _, aspect in ipairs(S.ASPECTS) do
        if S.Known(aspect.ids) then return true end
    end
    return false
end

function Aspects:Scan()
    local found
    local scanned = C.ForEachAura("player", "HELPFUL|PLAYER", function(aura)
        local a = idToAspect[aura.spellId] or (aura.name and nameToAspect[aura.name])
        if a then
            found = a
            return true
        end
    end)
    if scanned then current = found end
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") or IsMounted() then return true end
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return true end
    return false
end

function Aspects:Evaluate()
    local db = self.db
    local inCombat = UnitAffectingCombat("player")
    local now = GetTime()

    -- Cheetah / Pack in combat.
    if current and current.movement and inCombat and db.warnMovementInCombat and not Suppressed() then
        local name = S.Name(current.ids) or L.MOVEMENT_ASPECT
        HS.Alerts:Set("aspect.movement", {
            title = L.S_IN_COMBAT:format(name),
            text = L.YOU_WILL_BE_DAZED_WHEN_HIT,
            icon = S.Icon(current.ids),
            color = "danger", glow = true, priority = 9,
            sound = SOUNDKIT and SOUNDKIT.RAID_WARNING,
            tooltip = L.SWITCH_TO_ASPECT_OF_THE_HAWK_OR_MONKEY,
        })
    else
        HS.Alerts:Clear("aspect.movement")
    end

    -- No aspect at all.
    local want = not current and not Suppressed() and now >= snoozedUntil
    if want and not inCombat then
        want = not db.onlyInCombat and not IsResting()
    end
    if want then
        local hawk = S.ASPECTS[1]
        HS.Alerts:Set("aspect.none", {
            title = L.NO_ASPECT_ACTIVE,
            text = inCombat and L.YOU_ARE_FIGHTING_WITHOUT_AN_ASPECT or L.RIGHT_CLICK_TO_SNOOZE,
            icon = S.Icon(hawk.ids) or 136076,
            color = inCombat and "danger" or "warn", priority = 6,
            tooltip = L.CAST_AN_ASPECT_E_G_S:format(S.Name(hawk.ids) or L.ASPECT_OF_THE_HAWK),
            dismissHint = (L.RIGHT_CLICK_TO_SNOOZE_FOR_DS):format(db.snooze or 60),
            onDismiss = function() Aspects:Snooze() end,
        })
    else
        HS.Alerts:Clear("aspect.none")
    end
end

function Aspects:Snooze()
    snoozedUntil = GetTime() + (self.db.snooze or 60)
    C_Timer.After((self.db.snooze or 60) + 0.1, function()
        if Aspects.enabled then Aspects:Evaluate() end
    end)
end

function Aspects:OnInitialize()
    BuildLookups()
    self.events = HS:Events(self)
end

function Aspects:OnEnable()
    local ev = self.events
    local function rescan()
        self:Scan()
        self:Evaluate()
    end
    ev:On("UNIT_AURA", rescan, "player")
    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        spellID = C.Readable(spellID)
        local a = spellID and idToAspect[spellID]
        if not a and spellID then
            local name = C.GetSpellName(spellID)
            a = name and nameToAspect[name]
        end
        if a then
            current = a
            self:Evaluate()
        end
    end, "player")
    ev:On("PLAYER_DEAD", function() current = nil; self:Evaluate() end)
    ev:On("PLAYER_ENTERING_WORLD", rescan)
    ev:On("PLAYER_REGEN_ENABLED", rescan)
    ev:On("PLAYER_REGEN_DISABLED", function() self:Evaluate() end)
    ev:On("PLAYER_ALIVE", rescan)
    ev:On("PLAYER_UNGHOST", rescan)
    ev:On("PLAYER_UPDATE_RESTING", function() self:Evaluate() end)
    ev:On("PLAYER_MOUNT_DISPLAY_CHANGED", function() self:Evaluate() end)
    ev:On("PLAYER_CONTROL_LOST", function() self:Evaluate() end)
    ev:On("PLAYER_CONTROL_GAINED", function() self:Evaluate() end)
    rescan()
end

function Aspects:OnDisable()
    self.events:OffAll()
    HS.Alerts:Clear("aspect.none")
    HS.Alerts:Clear("aspect.movement")
end

function Aspects:Refresh()
    BuildLookups()
    self:Scan()
    self:Evaluate()
end

function Aspects:GetCurrent()
    return current
end
