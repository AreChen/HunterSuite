--[[
    HunterSuite - aspect reminder
    Warns when no aspect is up, and when Cheetah or Pack is still on in
    combat (you get dazed). Aura data is secret in combat on Forever, so the
    active aspect comes from an aura scan whenever reads are allowed and is
    kept current in combat from your own aspect casts.
]]

local _, HS = ...
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Aspects = HS:NewModule("aspects", { title = "Aspect Reminder" })

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
        local name = S.Name(current.ids) or "Movement aspect"
        HS.Alerts:Set("aspect.movement", {
            title = name .. " in combat",
            text = "You will be dazed when hit",
            icon = S.Icon(current.ids),
            color = "danger", glow = true, priority = 9,
            sound = SOUNDKIT and SOUNDKIT.RAID_WARNING,
            tooltip = "Switch to Aspect of the Hawk or Monkey.",
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
            title = "No aspect active",
            text = inCombat and "You are fighting without an aspect" or "Right-click to snooze",
            icon = S.Icon(hawk.ids) or 136076,
            color = inCombat and "danger" or "warn", priority = 6,
            tooltip = "Cast an aspect, e.g. " .. (S.Name(hawk.ids) or "Aspect of the Hawk") .. ".",
            dismissHint = ("Right-click to snooze for %ds"):format(db.snooze or 60),
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
