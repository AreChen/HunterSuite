--[[
    HunterSuite - Weaving Bar (TBC clients)
    Scrolling rotation guide for Steady Shot weaving, based on diziet559's
    rotationtools (https://diziet559.github.io/rotationtools/). WoW Forever
    has no Steady Shot, so the module stays off there.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local WB = HS:NewModule("weavingBar", { title = L.WEAVING_BAR_2 })

function WB:IsSupported()
    return not HS.IS_FOREVER and S.Known(S.STEADY_SHOT)
end

local GCD = 1.5
local STEADY_CAST = 1.5
local MULTI_CAST = 0.5
local ARCANE_CAST = 0.5
local WEAVE_TIME = 0.3

local ABILITY_INFO = {
    auto   = { color = { 0.33, 0.85, 0.52 }, label = L.WEAVE_AUTO_SHORT,   icon = 132369, melee = false },
    steady = { color = { 0.36, 0.67, 1.00 }, label = L.WEAVE_STEADY_SHORT, icon = 132213, melee = false },
    multi  = { color = { 1.00, 0.74, 0.28 }, label = L.WEAVE_MULTI_SHORT,  icon = 132330, melee = false },
    arcane = { color = { 0.70, 0.52, 1.00 }, label = L.WEAVE_ARCANE_SHORT, icon = 132218, melee = false },
    raptor = { color = { 0.97, 0.36, 0.36 }, label = L.WEAVE_RAPTOR_SHORT, icon = 132223, melee = true },
    melee  = { color = { 1.00, 0.60, 0.20 }, label = L.WEAVE_MELEE_SHORT,  icon = 132223, melee = true },
    weave  = { color = { 1.00, 0.55, 0.20 }, label = L.WEAVE_MELEE_SHORT,  icon = 132223, melee = true },
}

-- ============================================================================
-- Rotation Definitions
-- ============================================================================

-- Each rotation is a function that takes eWS and returns:
--   sequence: array of {t=time, ability=string, duration=number}
--   cycleDuration: total cycle length in seconds
local ROTATIONS = {}

-- 1:1 - Bread and butter high haste rotation
ROTATIONS["1:1"] = {
    name = "1:1",
    notation = "as",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,   ability = "auto",   duration = 0 },
            { t = 0,   ability = "steady", duration = STEADY_CAST },
        }, eWS
    end,
}

-- French Rotation 5:5:1:1 - THE core rotation
ROTATIONS["french"] = {
    name = L.FRENCH_5_5_1_1,
    notation = "asmasasAasas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS + 0.5,   ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS*3 + 0.5, ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 5
    end,
}

-- Short French 5:4:1:1 - SV without Serpent's Swiftness
ROTATIONS["short_french"] = {
    name = L.SHORT_FRENCH_5_4_1_1,
    notation = "asmasasAas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS + 0.5,   ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 4
    end,
}

-- Long French 5:6:1:1 - BM with Imp. Hawk proc
ROTATIONS["long_french"] = {
    name = L.LONG_FRENCH_5_6_1_1,
    notation = "asAamasasasas",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = GCD,         ability = "arcane", duration = ARCANE_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS,         ability = "multi",  duration = MULTI_CAST },
            { t = eWS + 0.5,   ability = "auto",   duration = 0 },
            { t = eWS*2,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS*2 + 0.5, ability = "steady", duration = STEADY_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 6
    end,
}

-- Skipping Rotation 5:9:1:1
ROTATIONS["skipping"] = {
    name = L.SKIPPING_5_9_1_1,
    notation = "asasamaasasaAaasa",
    hasWeaving = false,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,             ability = "auto",   duration = 0 },
            { t = 0,             ability = "steady", duration = STEADY_CAST },
            { t = eWS,           ability = "auto",   duration = 0 },
            { t = eWS * 2,       ability = "auto",   duration = 0 },
            { t = eWS * 2,       ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD,   ability = "multi",  duration = MULTI_CAST },
            { t = eWS * 3,       ability = "auto",   duration = 0 },
            { t = eWS * 4,       ability = "auto",   duration = 0 },
            { t = eWS * 4,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 5,       ability = "auto",   duration = 0 },
            { t = eWS * 5,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 6,       ability = "auto",   duration = 0 },
            { t = eWS*6,         ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 7,       ability = "auto",   duration = 0 },
            { t = eWS * 7,       ability = "steady", duration = STEADY_CAST },
            { t = eWS * 8,       ability = "auto",   duration = 0 },
        }
        return seq, eWS * 9
    end,
}

-- 1:2 - Extreme haste
ROTATIONS["1:2"] = {
    name = "1:2",
    notation = "aas",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,       ability = "auto",   duration = 0 },
            { t = eWS,     ability = "auto",   duration = 0 },
            { t = eWS,     ability = "steady", duration = STEADY_CAST },
        }, eWS * 2
    end,
}

-- 2:3 - Transitional between 1:1 and 1:2
ROTATIONS["2:3"] = {
    name = "2:3",
    notation = "asaas",
    hasWeaving = false,
    buildSequence = function(eWS)
        return {
            { t = 0,       ability = "auto",   duration = 0 },
            { t = 0,       ability = "steady", duration = STEADY_CAST },
            { t = eWS,     ability = "auto",   duration = 0 },
            { t = eWS * 2, ability = "auto",   duration = 0 },
            { t = eWS * 2, ability = "steady", duration = STEADY_CAST },
        }, eWS * 3
    end,
}

-- ============================================================================
-- Melee Weaving Rotations
-- ============================================================================

-- French Weaving 5:5:1:1 3w
ROTATIONS["french_weave"] = {
    name = L.FRENCH_WEAVE_5_5_1_1_3W,
    notation = "asmasasAasas +3w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,               ability = "auto",   duration = 0 },
            { t = 0,               ability = "steady", duration = STEADY_CAST },
            { t = GCD,             ability = "multi",  duration = MULTI_CAST },
            { t = GCD + MULTI_CAST,ability = "weave",  duration = WEAVE_TIME },
            { t = eWS,             ability = "auto",   duration = 0 },
            { t = eWS + 0.5,       ability = "steady", duration = STEADY_CAST },
            { t = eWS + GCD + 0.5, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 2,         ability = "auto",   duration = 0 },
            { t = eWS * 2,         ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD,     ability = "arcane", duration = ARCANE_CAST },
            { t = eWS*2 + GCD + ARCANE_CAST, ability = "weave", duration = WEAVE_TIME },
            { t = eWS * 3,         ability = "auto",   duration = 0 },
            { t = eWS*3 + 0.5,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,         ability = "auto",   duration = 0 },
            { t = eWS * 4,         ability = "steady", duration = STEADY_CAST },
        }
        return seq, eWS * 5
    end,
}

-- 1:1 Half-Weave 2:2 1w - THE sweet spot
ROTATIONS["half_weave"] = {
    name = L.TEXT_1_1_HALF_WEAVE,
    notation = "aswas",
    hasWeaving = true,
    buildSequence = function(eWS)
        return {
            { t = 0,                       ability = "auto",   duration = 0 },
            { t = 0,                       ability = "steady", duration = STEADY_CAST },
            { t = STEADY_CAST,             ability = "weave",  duration = WEAVE_TIME },
            { t = eWS,                     ability = "auto",   duration = 0 },
            { t = eWS,                     ability = "steady", duration = STEADY_CAST },
        }, eWS * 2
    end,
}

-- 6:9:1:1 3w - Rapid Fire active
ROTATIONS["rf_weave"] = {
    name = "6:9:1:1 3w",
    notation = "6:9:1:1 3w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS,         ability = "steady", duration = STEADY_CAST },
            { t = eWS + GCD,   ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "multi",  duration = MULTI_CAST },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 3,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*4 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
            { t = eWS * 5,     ability = "steady", duration = STEADY_CAST },
            { t = eWS * 6,     ability = "auto",   duration = 0 },
            { t = eWS * 6,     ability = "arcane", duration = ARCANE_CAST },
            { t = eWS * 7,     ability = "auto",   duration = 0 },
            { t = eWS * 7,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*7 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 8,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 9
    end,
}

-- 3:7 2w - Maximum haste weaving
ROTATIONS["max_weave"] = {
    name = "3:7 2w",
    notation = "3:7 2w",
    hasWeaving = true,
    buildSequence = function(eWS)
        local seq = {
            { t = 0,           ability = "auto",   duration = 0 },
            { t = 0,           ability = "steady", duration = STEADY_CAST },
            { t = eWS,         ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "auto",   duration = 0 },
            { t = eWS * 2,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*2 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 3,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "auto",   duration = 0 },
            { t = eWS * 4,     ability = "steady", duration = STEADY_CAST },
            { t = eWS*4 + GCD, ability = "weave",  duration = WEAVE_TIME },
            { t = eWS * 5,     ability = "auto",   duration = 0 },
            { t = eWS * 6,     ability = "auto",   duration = 0 },
        }
        return seq, eWS * 7
    end,
}


---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local state = {
    eWS = 3, isBM = false,
    rapidFire = 0, quickShots = 0, bloodlust = 0, drums = 0,
    rotation = nil, sequence = nil, cycle = 0,
    lastAuto = 0, cycleStart = 0, autoRepeat = false,
    changedAt = 0,
}

local HASTE = {
    rapidFire = { ids = { [3045] = true }, name = "Rapid Fire" },
    quickShots = { ids = { [6150] = true }, name = "Quick Shots" },
    bloodlust = { ids = { [2825] = true, [32182] = true }, name = "Bloodlust", alt = "Heroism" },
    drums = { ids = { [35476] = true }, name = "Drums of Battle" },
}

function WB:ScanBuffs()
    for key in pairs(HASTE) do state[key] = 0 end
    C.ForEachAura("player", "HELPFUL", function(aura)
        for key, spec in pairs(HASTE) do
            if (spec.ids and spec.ids[aura.spellId]) or aura.name == spec.name or (spec.alt and aura.name == spec.alt) then
                state[key] = C.Readable(aura.expirationTime) or 0
            end
        end
    end)
    local speed = C.Readable(UnitRangedDamage("player"))
    state.eWS = (speed and speed > 0) and speed or 3
end

function WB:DetectSpec()
    state.isBM = false
    if not GetNumTalents then return end
    local talentName = C.GetSpellName(34466) or "Serpent's Swiftness"
    for i = 1, GetNumTalents(1) or 0 do
        local name, _, _, _, rank = GetTalentInfo(1, i)
        if name == talentName then
            state.isBM = (rank or 0) > 0
            return
        end
    end
end

local function Active(key) return state[key] > GetTime() end

function WB:SelectRotation()
    local eWS, weave, bm = state.eWS, self.db.weave, state.isBM
    local pick
    if weave then
        if bm then
            if eWS < 0.94 then pick = "max_weave"
            elseif Active("rapidFire") then
                pick = (Active("bloodlust") or (Active("quickShots") and Active("drums"))) and "max_weave" or "rf_weave"
            elseif Active("quickShots") or Active("bloodlust") then pick = "half_weave"
            else pick = "french_weave" end
        else
            pick = eWS < 2.0 and "half_weave" or "french_weave"
        end
    else
        if bm then
            if eWS >= 2.0 then pick = "french"
            elseif eWS >= 1.8 then pick = "long_french"
            elseif eWS >= 1.3 then pick = "1:1"
            elseif eWS >= 1.0 then pick = "skipping"
            elseif eWS >= 0.8 then pick = "2:3"
            else pick = "1:2" end
        else
            if eWS > 2.4 then pick = "short_french"
            elseif eWS >= 2.0 then pick = "french"
            elseif eWS >= 1.3 then pick = "1:1"
            elseif eWS >= 1.0 then pick = "skipping"
            elseif eWS >= 0.8 then pick = "2:3"
            else pick = "1:2" end
        end
    end
    local rot = ROTATIONS[pick]
    if not rot then return end
    if state.rotation and state.rotation ~= pick then state.changedAt = GetTime() end
    state.rotation = pick
    state.sequence, state.cycle = rot.buildSequence(eWS)
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local MAX_BLOCKS = 40

function WB:Build()
    local db = self.db
    local f = UI:Element("HunterSuiteWeavingBar", db, L.WEAVING_BAR_2)
    f:SetSize(db.width, db.height + 30)
    UI:Surface(f, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })

    f.title = UI:Text(f, { size = 11, color = "accent" })
    f.title:SetPoint("TOPLEFT", 8, -6)
    f.ews = UI:Text(f, { size = 10, color = "textDim" })
    f.ews:SetPoint("TOPRIGHT", -8, -7)

    local tl = CreateFrame("Frame", nil, f)
    tl:SetPoint("TOPLEFT", 6, -22)
    tl:SetPoint("BOTTOMRIGHT", -6, 6)
    tl:SetClipsChildren(true)
    local bg = tl:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(UI:Color("track"))
    local nowLine = tl:CreateTexture(nil, "OVERLAY", nil, 7)
    nowLine:SetColorTexture(1, 1, 1, 0.9)
    nowLine:SetWidth(2)
    nowLine:SetPoint("TOPLEFT")
    nowLine:SetPoint("BOTTOMLEFT")
    f.timeline = tl

    f.blocks = {}
    for i = 1, MAX_BLOCKS do
        local b = CreateFrame("Frame", nil, tl)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(UI.tex.white)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("LEFT", 2, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.text = UI:Text(b, { size = 9, flags = "OUTLINE" })
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 2, 0)
        b:Hide()
        f.blocks[i] = b
    end

    f.hint = UI:Text(tl, { size = 12, flags = "OUTLINE", color = "danger" })
    f.hint:SetPoint("CENTER")
    f:SetScript("OnUpdate", function(_, elapsed) WB:OnUpdate(elapsed) end)
    f:Hide()
    self.frame = f
    HS.Movers:Register(f, { label = L.WEAVING_BAR_2, defaultPath = "weavingBar.position", module = "weavingBar" })
end

function WB:Render(now)
    local f = self.frame
    local tl = f.timeline
    for i = 1, MAX_BLOCKS do f.blocks[i]:Hide() end
    local seq, cycle = state.sequence, state.cycle
    if not seq or cycle <= 0 then return end
    local window = self.db.window or 10
    local pps = tl:GetWidth() / window
    local h = tl:GetHeight()
    local pos = state.lastAuto > 0 and ((now - state.cycleStart) % cycle) or 0
    local n = 0
    for offset = -1, 2 do
        for _, step in ipairs(seq) do
            local rel = step.t + offset * cycle - pos
            if rel >= -0.5 and rel <= window and n < MAX_BLOCKS then
                n = n + 1
                local info = ABILITY_INFO[step.ability]
                local b = f.blocks[n]
                local w = math.max(4, ((step.duration > 0) and step.duration or 0.15) * pps)
                local bh = info.melee and (h * 0.35 - 1) or (h * 0.65 - 1)
                b:ClearAllPoints()
                if info.melee then
                    b:SetPoint("BOTTOMLEFT", tl, "BOTTOMLEFT", rel * pps, 1)
                else
                    b:SetPoint("TOPLEFT", tl, "TOPLEFT", rel * pps, -1)
                end
                b:SetSize(w, bh)
                b.bg:SetVertexColor(info.color[1], info.color[2], info.color[3], 0.85)
                local isz = math.min(bh - 2, w - 2, 14)
                b.icon:SetSize(isz, isz)
                b.icon:SetTexture(info.icon)
                b.icon:SetShown(isz >= 6)
                b.text:SetText(w > 22 and info.label or "")
                b:SetAlpha(rel < 0 and 0.3 or 1)
                b:Show()
            end
        end
    end
end

local slow = 0
function WB:OnUpdate(elapsed)
    local f = self.frame
    local now = GetTime()
    if HS.state.editMode then
        if state.rotation ~= "french" then
            state.rotation = "french"
            state.sequence, state.cycle = ROTATIONS.french.buildSequence(2.17)
        end
        if state.cycleStart <= 0 then state.cycleStart = now end
        state.lastAuto = state.cycleStart
        f.title:SetText(ROTATIONS.french.name)
        f.ews:SetText(L.WEAVE_SPEED:format(2.17))
        self:Render(now)
        return
    end
    if not state.autoRepeat and self.db.hideIdle then
        f:Hide()
        return
    end
    self:Render(now)

    local sinceAuto = now - state.lastAuto
    local toNext = state.eWS - sinceAuto
    if state.autoRepeat and state.lastAuto > 0 and toNext > 0 and toNext < 0.5 then
        f.hint:SetText(L.WAIT_FOR_AUTO)
        f.hint:SetTextColor(UI:Color("danger"))
        f.hint:Show()
    elseif state.autoRepeat and state.lastAuto > 0 and toNext > MULTI_CAST and toNext < STEADY_CAST then
        f.hint:SetText(L.MULTI_ARCANE_NOW)
        f.hint:SetTextColor(UI:Color("warn"))
        f.hint:Show()
    elseif now - state.changedAt < 2 and state.rotation then
        f.hint:SetText(ROTATIONS[state.rotation].name)
        f.hint:SetTextColor(UI:Color("accent"))
        f.hint:Show()
    else
        f.hint:Hide()
    end

    slow = slow + elapsed
    if slow >= 0.25 then
        slow = 0
        local old = state.cycle
        self:ScanBuffs()
        if state.rotation then
            local _, cyc = ROTATIONS[state.rotation].buildSequence(state.eWS)
            if math.abs(cyc - old) > 0.1 then self:SelectRotation() end
        end
        f.title:SetText(state.rotation and ROTATIONS[state.rotation].name or "--")
        f.ews:SetFormattedText(L.WEAVE_SPEED, state.eWS)
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function WB:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
end

function WB:OnEnable()
    local ev = self.events
    local function full()
        self:DetectSpec()
        self:ScanBuffs()
        self:SelectRotation()
    end
    ev:On("PLAYER_ENTERING_WORLD", full)
    ev:On("CHARACTER_POINTS_CHANGED", full)
    ev:On("PLAYER_TALENT_UPDATE", full)
    ev:On("UNIT_AURA", function() self:ScanBuffs(); self:SelectRotation() end, "player")
    ev:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        if C.Readable(spellID) ~= S.AUTO_SHOT then return end
        local now = GetTime()
        state.lastAuto = now
        if state.cycleStart <= 0 then state.cycleStart = now end
        if state.cycle > 0 then
            local p = (now - state.cycleStart) % state.cycle
            if p < 0.2 or state.cycle - p < 0.2 then state.cycleStart = now end
        end
    end, "player")
    ev:On("START_AUTOREPEAT_SPELL", function()
        state.autoRepeat = true
        self.frame:SetAlpha(1)
        self.frame:Show()
    end)
    ev:On("STOP_AUTOREPEAT_SPELL", function()
        state.autoRepeat = false
        state.lastAuto, state.cycleStart = 0, 0
    end)
    ev:On("PLAYER_REGEN_ENABLED", function()
        state.lastAuto, state.cycleStart = 0, 0
        self.frame:SetAlpha(self.db.oocAlpha or 0.45)
    end)
    ev:On("PLAYER_REGEN_DISABLED", function() self.frame:SetAlpha(1) end)
    self:Refresh()
    full()
end

function WB:OnDisable()
    self.events:OffAll()
    self.frame:Hide()
end

function WB:Refresh()
    local f, db = self.frame, self.db
    f:SetSize(db.width, db.height + 30)
    UI:ApplyPosition(f)
    if not db.hideIdle then f:Show() end
end

HS:On("EDIT_MODE", function(on)
    if not WB.enabled then return end
    if on then
        WB.frame:SetAlpha(1)
        WB.frame:Show()
    else
        state.rotation, state.cycleStart, state.lastAuto = nil, 0, 0
        WB:SelectRotation()
    end
end)
