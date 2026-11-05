--[[
    HunterSuite - tracking reminder
    Battlegrounds: remind to Track Humanoids. "Always" mode: remind when no
    tracking is active at all. Forever makes hunter trackers self-buffs, so
    both the minimap tracking list and the player's buffs are checked.
]]

local _, HS = ...
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Tracking = HS:NewModule("tracking", { title = "Tracking Reminder" })

local trackIDs, trackNames = {}, {}
local humanoidID = S.TRACKING.humanoids
local lastCast        -- tracking spell cast while auras were unreadable

function Tracking:IsSupported()
    for _, id in pairs(S.TRACKING) do
        if C.IsKnown(id) then return true end
    end
    return false
end

-- Returns active tracking spell IDs/names (set), or nil when unreadable.
function Tracking:ActiveSet()
    local active = {}
    for i = 1, C.GetNumTracking() do
        local name, isActive, spellID = C.GetTrackingInfo(i)
        if C.Readable(isActive) then
            if spellID then active[spellID] = true end
            if name then active[name] = true end
        end
    end
    local scanned = C.ForEachAura("player", "HELPFUL|PLAYER", function(aura)
        if trackIDs[aura.spellId] or (aura.name and trackNames[aura.name]) then
            active[aura.spellId] = true
            if aura.name then active[aura.name] = true end
        end
    end)
    if scanned then
        lastCast = nil
    elseif lastCast then
        -- Battlegrounds hide auras; trust the tracking the player just cast.
        active[lastCast] = true
        local name = S.Name(lastCast)
        if name then active[name] = true end
    elseif not next(active) then
        return nil
    end
    return active
end

function Tracking:Evaluate()
    local db = self.db
    local active = self:ActiveSet()
    if active == nil then return end -- keep whatever we showed until reads are allowed

    local show, title, text, icon
    if db.mode == "pvp" then
        local humanoidName = S.Name(humanoidID)
        if C.IsInPvP() and C.IsKnown(humanoidID) and not (active[humanoidID] or (humanoidName and active[humanoidName])) then
            show, title, text = true, "Track Humanoids", "You are in a battleground"
            icon = S.Icon(humanoidID)
        end
    elseif db.mode == "always" then
        local any = false
        for key in pairs(active) do
            if trackIDs[key] or trackNames[key] then any = true break end
        end
        if not any and not IsResting() then
            show, title, text = true, "No tracking active", "Pick a tracking from your spellbook"
            icon = S.Icon(S.TRACKING.beasts)
        end
    end

    if show then
        HS.Alerts:Set("tracking", {
            title = title, text = text, icon = icon or 132328,
            color = "info", priority = 4,
            tooltip = "Hunters can track one creature type at a time.",
        })
    else
        HS.Alerts:Clear("tracking")
    end
end

function Tracking:OnInitialize()
    for _, id in pairs(S.TRACKING) do
        trackIDs[id] = true
        local name = S.Name(id)
        if name then trackNames[name] = true end
    end
    self.events = HS:Events(self)
end

function Tracking:OnEnable()
    local ev = self.events
    local function update() self:Evaluate() end
    ev:On("MINIMAP_UPDATE_TRACKING", update)
    ev:On("UNIT_AURA", update, "player")
    ev:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, update) end)
    ev:On("ZONE_CHANGED_NEW_AREA", update)
    ev:On("PLAYER_REGEN_ENABLED", update)
    ev:On("PLAYER_UPDATE_RESTING", update)
    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        spellID = C.Readable(spellID)
        if spellID and trackIDs[spellID] then
            lastCast = spellID
            update()
        end
    end, "player")
    update()
end

function Tracking:OnDisable()
    self.events:OffAll()
    HS.Alerts:Clear("tracking")
end

function Tracking:Refresh()
    self:Evaluate()
end
