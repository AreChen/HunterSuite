--[[
    HunterSuite - sting timers on nameplates
    Serpent / Scorpid / Viper (and optionally Hunter's Mark) countdowns above
    enemy nameplates. Aura data is secret in combat on Forever, so timers
    start from your own casts and are corrected from real auras whenever the
    client lets us read them.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Stings = HS:NewModule("stings", { title = L.STING_TIMERS_2 })

local tracked = {}        -- spellID -> { key, duration, ids }
local byName = {}         -- localized name -> entry
local timers = {}         -- plate -> { [key] = { expires, duration, icon } }
local holders = {}        -- plate -> holder frame
local pool = {}

local function BuildLookups(showMark)
    wipe(tracked)
    wipe(byName)
    local function add(key, ids, duration)
        local entry = { key = key, ids = ids, duration = duration }
        for _, id in ipairs(ids) do tracked[id] = entry end
        local name = S.Name(ids)
        if name then byName[name] = entry end
    end
    for _, sting in ipairs(S.STINGS) do add(sting.key, sting.ids, sting.duration) end
    if showMark then add("mark", S.HUNTERS_MARK, S.HUNTERS_MARK_DURATION) end
end

local function Lookup(spellID, name)
    return (spellID and tracked[spellID]) or (name and byName[name])
end

local function PlateFor(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------

local function AcquireHolder(plate)
    local h = holders[plate]
    if h then return h end
    h = table.remove(pool) or CreateFrame("Frame")
    local ok = pcall(h.SetParent, h, plate)
    if not ok then
        table.insert(pool, h)
        return nil
    end
    h:ClearAllPoints()
    h:SetPoint("BOTTOM", plate, "TOP", 0, Stings.db.offsetY or 6)
    h:SetSize(1, 1)
    h.icons = h.icons or {}
    holders[plate] = h
    h:Show()
    return h
end

local function ReleaseHolder(plate)
    local h = holders[plate]
    if not h then return end
    holders[plate] = nil
    h:Hide()
    for _, icon in ipairs(h.icons) do icon:Hide() end
    h:SetParent(nil)
    table.insert(pool, h)
end

local function GetIcon(h, i)
    local icon = h.icons[i]
    if icon then return icon end
    local size = Stings.db.size or 22
    icon = UI:Icon(h, size, { cooldown = true })
    icon.text = UI:Text(icon.cooldown or icon, { size = math.floor(size * 0.5), flags = "OUTLINE" })
    icon.text:SetPoint("CENTER", 0, 0)
    h.icons[i] = icon
    return icon
end

local function Render(plate)
    local list = timers[plate]
    local now = GetTime()
    local entries = {}
    if list then
        for key, t in pairs(list) do
            if t.expires > now then
                entries[#entries + 1] = t
            else
                list[key] = nil
            end
        end
    end
    if #entries == 0 then
        timers[plate] = nil
        ReleaseHolder(plate)
        return
    end
    table.sort(entries, function(a, b) return a.expires < b.expires end)
    local h = AcquireHolder(plate)
    if not h then return end
    local size = Stings.db.size or 22
    local gap = 3
    local total = #entries * size + (#entries - 1) * gap
    for i, t in ipairs(entries) do
        local icon = GetIcon(h, i)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", h, "BOTTOM", -total / 2 + (i - 1) * (size + gap), 0)
        icon.icon:SetTexture(t.icon)
        if icon.cooldown and icon.cdStart ~= t.expires - t.duration then
            icon.cdStart = t.expires - t.duration
            icon.cooldown:SetCooldown(icon.cdStart, t.duration)
        end
        icon.expires = t.expires
        icon:Show()
    end
    for i = #entries + 1, #h.icons do h.icons[i]:Hide() end
end

local function SetTimer(plate, entry, icon, expires, duration)
    timers[plate] = timers[plate] or {}
    timers[plate][entry.key] = { expires = expires, duration = duration, icon = icon }
    Render(plate)
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------

-- Replace a plate's timers with the real auras, when they can be read.
local function ScanPlate(unit)
    if C.IsSecret(unit) or not unit then return end
    local plate = PlateFor(unit)
    if not plate then return end
    local found = {}
    local scanned = C.ForEachAura(unit, "HARMFUL|PLAYER", function(aura)
        local entry = Lookup(aura.spellId, aura.name)
        if entry then
            local duration, expires = C.AuraTimes(aura)
            if duration and duration > 0 then
                found[entry.key] = { expires = expires, duration = duration, icon = aura.icon }
            end
        end
    end)
    if not scanned then return end
    timers[plate] = next(found) and found or nil
    Render(plate)
end

function Stings:OnCast(spellID)
    local entry = Lookup(spellID, C.GetSpellName(spellID))
    if not entry then return end
    local plate = PlateFor("target")
    if not plate then return end
    local now = GetTime()
    SetTimer(plate, entry, C.GetSpellTexture(spellID) or S.Icon(entry.ids), now + entry.duration, entry.duration)
    -- When reads are allowed the real aura replaces the estimate.
    C_Timer.After(0.3, function() ScanPlate("target") end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Stings:OnInitialize()
    BuildLookups(self.db.showMark)
    self.events = HS:Events(self)
    local ticker = CreateFrame("Frame")
    local accum = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum < 0.1 then return end
        accum = 0
        local now = GetTime()
        for plate, h in pairs(holders) do
            local expired = false
            for _, icon in ipairs(h.icons) do
                if icon:IsShown() and icon.expires then
                    local left = icon.expires - now
                    if left <= 0 then
                        expired = true
                    elseif Stings.db.showText then
                        icon.text:SetText(left >= 10 and tostring(math.floor(left)) or ("%.1f"):format(left))
                    else
                        icon.text:SetText("")
                    end
                end
            end
            if expired then Render(plate) end
        end
    end)
    ticker:Hide()
    self.ticker = ticker
end

function Stings:OnEnable()
    local ev = self.events
    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        spellID = C.Readable(spellID)
        if spellID then self:OnCast(spellID) end
    end, "player")
    ev:On("NAME_PLATE_UNIT_ADDED", function(_, _, unit) ScanPlate(unit) end)
    ev:On("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
        if C.IsSecret(unit) then return end
        local plate = PlateFor(unit)
        if plate then
            timers[plate] = nil
            ReleaseHolder(plate)
        end
    end)
    ev:On("UNIT_AURA", function(_, _, unit)
        if C.IsSecret(unit) or type(unit) ~= "string" then return end
        if unit:find("^nameplate") then ScanPlate(unit) end
    end)
    ev:On("PLAYER_REGEN_ENABLED", function()
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = plate.namePlateUnitToken
                if unit and not C.IsSecret(unit) then ScanPlate(unit) end
            end
        end
    end)
    self.ticker:Show()
end

function Stings:OnDisable()
    self.events:OffAll()
    self.ticker:Hide()
    for plate in pairs(holders) do ReleaseHolder(plate) end
    wipe(timers)
end

function Stings:Refresh()
    BuildLookups(self.db.showMark)
    for plate, h in pairs(holders) do
        h:ClearAllPoints()
        h:SetPoint("BOTTOM", plate, "TOP", 0, self.db.offsetY or 6)
        for _, icon in ipairs(h.icons) do
            UI:SetTextSize(icon.text, math.floor((self.db.size or 22) * 0.5), "OUTLINE")
        end
        Render(plate)
    end
end
