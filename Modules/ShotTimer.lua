--[[
    HunterSuite - Auto Shot timer
    Forever has no combat log for addons, but ships a native swing timer:
    PLAYER_SWING(duration, swingType) fires as each shot leaves. Auto Shot
    needs the hunter to stand still for the last ~0.5s (the aim), so the bar
    shows where to stop, warns when you are still moving, projects casts onto
    the swing to show clipping, and draws the GCD underneath.
    On clients without C_SwingTimer the bar falls back to Auto Shot casts.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Shot = HS:NewModule("shotTimer", { title = L.AUTO_SHOT_TIMER_2 })

local RANGED = C.SwingType.Ranged
local OVERDUE_GRACE = 0.15
local IDLE_LINGER = 1.2
local GCD_EXCLUDE = {}

local state = {
    start = 0, duration = 0, active = false,
    autoRepeat = false, moving = false,
    castStart = 0, castEnd = 0, castGUID = nil,
    gcdStart = 0, gcdDuration = 0,
    delay = 0, delayAt = 0, lastShot = 0,
}
Shot.state = state

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

function Shot:Build()
    local db = self.db
    local f = UI:Element("HunterSuiteShotTimer", db, L.AUTO_SHOT)
    f:SetSize(db.width, db.height + 6)
    self.frame = f

    local bar = UI:Bar(f, { height = db.height })
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    f.bar = bar
    UI:Shadow(bar, 8)

    -- Aim window shading and its start marker.
    local aim = bar.bar:CreateTexture(nil, "ARTWORK", nil, 2)
    aim:SetTexture(UI.tex.white)
    aim:SetPoint("TOP")
    aim:SetPoint("BOTTOM")
    aim:SetPoint("RIGHT")
    f.aimZone = aim
    local marker = bar.bar:CreateTexture(nil, "OVERLAY", nil, 3)
    marker:SetTexture(UI.tex.white)
    marker:SetWidth(2)
    marker:SetPoint("TOP", 0, 2)
    marker:SetPoint("BOTTOM", 0, -2)
    f.aimMarker = marker

    -- Cast projected onto the swing.
    local cast = bar.bar:CreateTexture(nil, "OVERLAY", nil, 1)
    cast:SetTexture(UI.tex.white)
    cast:SetPoint("TOP")
    cast:SetPoint("BOTTOM")
    cast:Hide()
    f.cast = cast

    f.label = UI:Text(bar.bar, { size = 10, flags = "OUTLINE", color = "text" })
    f.label:SetPoint("LEFT", 5, 0)
    f.time = UI:Text(bar.bar, { size = 10, flags = "OUTLINE", color = "text" })
    f.time:SetPoint("RIGHT", -5, 0)

    -- GCD line.
    local gcd = UI:Bar(f, { height = 3, spark = false, border = false, track = { 0, 0, 0, 0.5 } })
    gcd:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
    gcd:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
    gcd:SetFillColor(0.85, 0.87, 0.9)
    gcd:Hide()
    f.gcd = gcd

    f.delay = UI:Text(f, { size = 10, flags = "OUTLINE", color = "warn" })
    f.delay:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -6)
    f.delay:Hide()

    f:SetScript("OnUpdate", function(_, elapsed) Shot:OnUpdate(elapsed) end)
    f:Hide()

    HS.Movers:Register(f, { label = L.AUTO_SHOT, defaultPath = "shotTimer.position", module = "shotTimer" })
end

function Shot:Layout()
    local f, db = self.frame, self.db
    f:SetSize(db.width, db.height + 6)
    f.bar:SetHeight(db.height)
    if f.bar.spark then f.bar.spark:SetHeight(db.height + 8) end
    UI:ApplyPosition(f)
    local r, g, b = UI:Color("warn")
    f.aimZone:SetVertexColor(r, g, b, 0.16)
    f.aimMarker:SetVertexColor(r, g, b, 0.9)
end

---------------------------------------------------------------------------
-- Swing bookkeeping
---------------------------------------------------------------------------

local function AimTime(db)
    local t = db.aimTime or 0.5
    if db.latency then t = t + C.GetLatency() end
    return t
end

function Shot:OnSwing(duration)
    local now = GetTime()
    if state.active and state.duration > 0 then
        local late = now - (state.start + state.duration)
        if late > 0.05 and late < 3 then
            state.delay, state.delayAt = late, now
        end
    end
    state.start, state.duration, state.active = now, duration, true
    state.lastShot = now
    if self.db.flashOnShot and self.frame:IsShown() then
        UI:Flash(self.frame.bar, 1, 1, 1, 0.35, 0.22)
    end
    self:Show()
end

function Shot:Show()
    local f = self.frame
    UI:StopTween(f)
    f:SetAlpha(self:TargetAlpha())
    f:Show()
end

function Shot:TargetAlpha()
    if HS.state.editMode or UnitAffectingCombat("player") then return 1 end
    return self.db.oocAlpha or 0.45
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function SetZone(tex, bar, from, to)
    local w = bar:GetWidth()
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", bar, "TOPLEFT", w * from, 0)
    tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", w * from, 0)
    tex:SetWidth(math.max(1, w * (to - from)))
end

function Shot:OnUpdate()
    local f, db = self.frame, self.db
    local now = GetTime()

    if HS.state.editMode then
        self:DrawPreview(now)
        return
    end

    local bar = f.bar
    local duration = state.duration
    local elapsed = now - state.start
    local swinging = state.active and duration > 0 and elapsed <= duration + OVERDUE_GRACE

    -- Idle: fade away unless the player keeps auto shot on.
    if not swinging and not state.autoRepeat then
        state.active = false
        state.idleSince = state.idleSince or now
        if db.hideIdle then
            if now - state.idleSince > IDLE_LINGER and f:GetAlpha() > 0 and not f.fading then
                f.fading = true
                UI:FadeTo(f, 0, 0.3, function() f.fading = false; f:Hide() end)
            end
        else
            bar:SetRange(0, 1)
            bar:SetValueNow(0)
            bar:SetFillColor(UI:Color("textMute"))
            f.label:SetText(L.AUTO_SHOT)
            f.time:SetText("")
            f.aimZone:Hide(); f.aimMarker:Hide(); f.cast:Hide()
        end
        self:DrawGCD(now)
        return
    end
    state.idleSince = nil
    if f.fading then
        f.fading = false
        UI:StopTween(f)
        f:SetAlpha(self:TargetAlpha())
    end

    local aim = math.min(AimTime(db), duration > 0 and duration * 0.9 or 0.5)
    local aimStart = duration - aim

    if swinging then
        bar:SetRange(0, duration)
        bar:SetValueNow(math.min(elapsed, duration))
        local inAim = elapsed >= aimStart
        if inAim and state.moving then
            bar:SetFillColor(UI:Color("danger"))
            f.label:SetText(L.STOP_MOVING)
        elseif inAim then
            bar:SetFillColor(UI:Color("warn"))
            f.label:SetText(L.HOLD_STILL)
        else
            bar:SetFillColor(UI:Accent())
            f.label:SetText(db.showLabel and L.AUTO_SHOT or "")
        end
        f.time:SetFormattedText("%.1f", math.max(0, duration - elapsed))
    else
        -- Auto Shot is on but the shot has not gone off: moving, casting or out of range.
        bar:SetRange(0, 1)
        bar:SetValueNow(1)
        bar:SetFillColor(UI:Color("purple"))
        if state.moving then
            f.label:SetText(L.STOP_TO_SHOOT)
        elseif state.castEnd > now then
            f.label:SetText(L.CASTING)
        elseif C.IsInSwingRange(RANGED) == false then
            f.label:SetText(L.OUT_OF_RANGE)
        else
            f.label:SetText(L.WAITING)
        end
        f.time:SetText("")
    end

    -- Aim zone.
    if db.showAimMarker and swinging and duration > 0 then
        local from = math.max(0, aimStart / duration)
        SetZone(f.aimZone, bar.bar, from, 1)
        f.aimZone:Show()
        f.aimMarker:ClearAllPoints()
        f.aimMarker:SetPoint("TOP", bar.bar, "TOPLEFT", bar.bar:GetWidth() * from, 2)
        f.aimMarker:SetPoint("BOTTOM", bar.bar, "BOTTOMLEFT", bar.bar:GetWidth() * from, -2)
        f.aimMarker:Show()
    else
        f.aimZone:Hide()
        f.aimMarker:Hide()
    end

    -- Cast overlay: red when the cast runs into the aim window (clips the shot).
    if db.showCastOverlay and swinging and state.castEnd > now and duration > 0 then
        local from = math.max(0, (state.castStart - state.start) / duration)
        local to = math.min(1, (state.castEnd - state.start) / duration)
        if to > from then
            SetZone(f.cast, bar.bar, from, to)
            local clips = state.castEnd > state.start + aimStart
            local r, g, b = UI:Color(clips and "danger" or "info")
            f.cast:SetVertexColor(r, g, b, 0.45)
            f.cast:Show()
        else
            f.cast:Hide()
        end
    else
        f.cast:Hide()
    end

    -- Delay readout.
    if db.showDelay and state.delay > 0 and now - state.delayAt < 2.5 then
        f.delay:SetFormattedText("+%.2fs", state.delay)
        f.delay:SetAlpha(math.min(1, 2.5 - (now - state.delayAt)))
        f.delay:Show()
    else
        f.delay:Hide()
    end

    self:DrawGCD(now)
end

function Shot:DrawGCD(now)
    local f = self.frame
    if not self.db.showGCD then f.gcd:Hide() return end
    local start, duration = state.gcdStart, state.gcdDuration
    if not C.CooldownsRestricted() then
        local s, d = C.GetGCD()
        if d and d > 0 then start, duration = s, d end
    end
    local left = start + duration - now
    if duration > 0 and left > 0 then
        f.gcd:SetRange(0, duration)
        f.gcd:SetValueNow(left)
        f.gcd:Show()
    else
        f.gcd:Hide()
    end
end

function Shot:DrawPreview(now)
    local f = self.frame
    local duration = 2.8
    local t = now % (duration + 0.6)
    local bar = f.bar
    f:SetAlpha(1)
    f:Show()
    bar:SetRange(0, duration)
    bar:SetValueNow(math.min(t, duration))
    local aimStart = duration - 0.5
    if t >= aimStart then
        bar:SetFillColor(UI:Color("warn"))
        f.label:SetText(L.HOLD_STILL)
    else
        bar:SetFillColor(UI:Accent())
        f.label:SetText(L.AUTO_SHOT)
    end
    f.time:SetFormattedText("%.1f", math.max(0, duration - t))
    SetZone(f.aimZone, bar.bar, aimStart / duration, 1)
    f.aimZone:Show()
    f.aimMarker:ClearAllPoints()
    f.aimMarker:SetPoint("TOP", bar.bar, "TOPLEFT", bar.bar:GetWidth() * aimStart / duration, 2)
    f.aimMarker:SetPoint("BOTTOM", bar.bar, "BOTTOMLEFT", bar.bar:GetWidth() * aimStart / duration, -2)
    f.aimMarker:Show()
    f.cast:Hide()
    f.gcd:SetRange(0, 1.5)
    f.gcd:SetValueNow(1.5 - (t % 1.5))
    f.gcd:SetShown(self.db.showGCD)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function IsAutoShot(spellID)
    return spellID == S.AUTO_SHOT
end

function Shot:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
    for _, id in ipairs(S.RAPTOR_STRIKE) do GCD_EXCLUDE[id] = true end
    GCD_EXCLUDE[S.AUTO_SHOT] = true
    GCD_EXCLUDE[5019] = true   -- Shoot (wand)
    GCD_EXCLUDE[6603] = true   -- Auto Attack
end

function Shot:OnEnable()
    local ev = self.events

    if C.HasSwingAPI then
        ev:On("PLAYER_SWING", function(_, _, duration, swingType)
            if swingType == RANGED and duration then self:OnSwing(duration) end
        end)
        C.EnableSwingRangeCheck(RANGED)
    end

    ev:On("START_AUTOREPEAT_SPELL", function()
        state.autoRepeat = true
        self:Show()
    end)
    ev:On("STOP_AUTOREPEAT_SPELL", function()
        state.autoRepeat = false
    end)

    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, castGUID, spellID)
        spellID = C.Readable(spellID)
        if not spellID then return end
        if IsAutoShot(spellID) then
            -- Fallback timing when the client has no swing API.
            if not C.HasSwingAPI then
                local speed = C.Readable(UnitRangedDamage("player"))
                if speed and speed > 0 then self:OnSwing(speed) end
            end
            return
        end
        if C.Readable(castGUID) and castGUID == state.castGUID then
            state.castGUID = nil
            return
        end
        if not GCD_EXCLUDE[spellID] then
            state.gcdStart, state.gcdDuration = GetTime(), 1.5
        end
    end, "player")

    local function castStart(_, _, _, castGUID, spellID)
        local _, _, _, startMs, endMs = UnitCastingInfo("player")
        if not startMs then
            _, _, _, startMs, endMs = UnitChannelInfo("player")
        end
        startMs, endMs = C.Readable(startMs), C.Readable(endMs)
        if startMs and endMs then
            state.castStart, state.castEnd = startMs / 1000, endMs / 1000
        end
        state.castGUID = C.Readable(castGUID)
        spellID = C.Readable(spellID)
        if spellID and not GCD_EXCLUDE[spellID] then
            state.gcdStart, state.gcdDuration = GetTime(), 1.5
        end
    end
    local function castStop()
        state.castStart, state.castEnd = 0, 0
    end
    ev:On("UNIT_SPELLCAST_START", castStart, "player")
    ev:On("UNIT_SPELLCAST_CHANNEL_START", castStart, "player")
    ev:On("UNIT_SPELLCAST_STOP", castStop, "player")
    ev:On("UNIT_SPELLCAST_CHANNEL_STOP", castStop, "player")
    ev:On("UNIT_SPELLCAST_INTERRUPTED", castStop, "player")
    ev:On("UNIT_SPELLCAST_FAILED", castStop, "player")

    ev:On("PLAYER_STARTED_MOVING", function() state.moving = true end)
    ev:On("PLAYER_STOPPED_MOVING", function() state.moving = false end)

    ev:On("PLAYER_REGEN_DISABLED", function()
        if self.frame:IsShown() and not self.frame.fading then self.frame:SetAlpha(1) end
    end)
    ev:On("PLAYER_REGEN_ENABLED", function()
        if self.frame:IsShown() and not self.frame.fading then self.frame:SetAlpha(self:TargetAlpha()) end
    end)

    state.autoRepeat = C.IsAutoRepeat(S.AUTO_SHOT)
    local speed = C.Readable(GetUnitSpeed("player"))
    state.moving = speed ~= nil and speed > 0
    self:Layout()
    if state.autoRepeat or not self.db.hideIdle then self:Show() end
end

function Shot:OnDisable()
    self.events:OffAll()
    self.frame:Hide()
end

function Shot:Refresh()
    self:Layout()
    if not self.db.hideIdle then self:Show() end
end

HS:On("EDIT_MODE", function(on)
    if not Shot.enabled then return end
    if on then
        Shot.frame:Show()
        Shot.frame:SetAlpha(1)
    else
        Shot.frame.fading = false
        if not state.autoRepeat and Shot.db.hideIdle then Shot.frame:Hide() end
    end
end)
