--[[
    HunterSuite - range and dead zone
    Melee, dead zone (between melee and the 8 yd Auto Shot minimum), in
    range, or too far. Uses Forever's swing-range checks first, then spell
    ranges, then LibRangeCheck for the yard estimate.
]]

local _, HS = ...
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Range = HS:NewModule("range", { title = "Range" })

local RANGED, MELEE = C.SwingType.Ranged, C.SwingType.MainHand
local rc = LibStub and LibStub("LibRangeCheck-3.0", true)

local STATES = {
    melee   = { label = "Melee",       color = "warn" },
    dead    = { label = "Dead zone",   color = "purple" },
    inrange = { label = "In range",    color = "good" },
    far     = { label = "Too far",     color = "danger" },
    unknown = { label = "...",         color = "textDim" },
    none    = { label = "No target",   color = "textMute" },
}

function Range:Build()
    local f = UI:Element("HunterSuiteRange", self.db, "Range")
    f:SetSize(96, 22)
    UI:Surface(f, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })
    f.dot = f:CreateTexture(nil, "ARTWORK")
    f.dot:SetTexture(UI.tex.circle)
    f.dot:SetSize(8, 8)
    f.dot:SetPoint("LEFT", 9, 0)
    f.text = UI:Text(f, { size = 11 })
    f.text:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
    f.text:SetPoint("RIGHT", -8, 0)
    f.text:SetJustifyH("LEFT")
    f:Hide()
    self.frame = f
    f:SetScript("OnUpdate", function(_, elapsed) Range:OnUpdate(elapsed) end)
    HS.Movers:Register(f, { label = "Range", defaultPath = "range.position", module = "range",
        hidden = function() return Range.docked end })
end

function Range:Layout()
    local f, db = self.frame, self.db
    local style = db.style
    if style == "dot" then
        f:SetSize(18, 18)
        f.text:Hide()
        f.dot:ClearAllPoints()
        f.dot:SetPoint("CENTER")
        f.dot:SetSize(10, 10)
    else
        f:SetSize(style == "text" and 86 or 104, 22)
        f.text:Show()
        f.dot:ClearAllPoints()
        f.dot:SetPoint("LEFT", 9, 0)
        f.dot:SetSize(8, 8)
    end
    local surf = f.__hsSurface
    if surf then
        surf.bg:SetShown(style ~= "text")
        if surf.ring then surf.ring:SetShown(style ~= "text") end
        if surf.edges then surf.edges:SetShown(style ~= "text") end
    end
    if f.__hsShadow then
        f.__hsShadow.hsForceHidden = style == "text"
        f.__hsShadow:SetShown(style ~= "text" and HS.db.appearance.shadows)
    end

    -- Dock to the Auto Shot bar when asked.
    local shot = HS:GetModule("shotTimer")
    f:ClearAllPoints()
    if db.attach and shot and shot.enabled and shot.frame then
        f:SetScale(HS.db.appearance.scale or 1)
        f:SetPoint("LEFT", shot.frame.bar, "RIGHT", 6, 0)
        self.docked = true
    else
        self.docked = false
        UI:ApplyPosition(f)
    end
end

-- Returns a state key plus a min/max yard estimate.
function Range:Classify()
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        return "none"
    end
    local minR, maxR
    if rc then
        local ok, a, b = pcall(rc.GetRange, rc, "target")
        if ok then minR, maxR = C.Readable(a), C.Readable(b) end
    end

    local melee = C.IsInSwingRange(MELEE)
    if melee == nil then
        melee = C.IsSpellInRange(S.Name(S.RAPTOR_STRIKE), "target")
        if melee == nil then melee = C.IsSpellInRange(S.Name(S.WING_CLIP), "target") end
    end
    local ranged = C.IsInSwingRange(RANGED)
    if ranged == nil then ranged = C.IsSpellInRange(S.AUTO_SHOT, "target") end

    if melee then return "melee", minR, maxR end
    if ranged then return "inrange", minR, maxR end
    if (maxR and maxR <= 8) or (minR and minR < 8 and ranged == false) then return "dead", minR, maxR end
    if ranged == false then return "far", minR, maxR end
    if minR and minR >= 35 then return "far", minR, maxR end
    return "unknown", minR, maxR
end

local accum = 0
function Range:OnUpdate(elapsed)
    if HS.state.editMode then return end
    accum = accum + elapsed
    if accum < 1 / (self.db.updateHz or 12) then return end
    accum = 0
    self:Update()
end

function Range:Paint(key, minR, maxR)
    local f, db = self.frame, self.db
    local spec = STATES[key]
    local r, g, b = UI:Color(spec.color)
    f.dot:SetVertexColor(r, g, b)
    local text = spec.label
    if db.showYards and (key == "inrange" or key == "far" or key == "unknown") and minR then
        if maxR then
            text = ("%d-%d yd"):format(minR, maxR)
        else
            text = ("%d+ yd"):format(minR)
        end
    end
    f.text:SetText(text)
    f.text:SetTextColor(r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6)
    UI:SetBorderColor(f, { r, g, b, 0.35 })
end

function Range:Update()
    local key, minR, maxR = self:Classify()
    local f = self.frame
    if key == "none" and not self.db.showNoTarget then
        f:SetAlpha(0)
        self.hidden = true
        return
    end
    if self.hidden then
        self.hidden = false
        UI:FadeTo(f, 1, 0.15)
    end
    self:Paint(key, minR, maxR)
end

function Range:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
end

function Range:OnEnable()
    C.EnableSwingRangeCheck(RANGED)
    C.EnableSwingRangeCheck(MELEE)
    self.events:On("PLAYER_TARGET_CHANGED", function() self:Update() end)
    self.events:On("PLAYER_SWING_RANGE_UPDATE", function() self:Update() end)
    self:Layout()
    self.frame:SetAlpha(0)
    self.hidden = true
    self.frame:Show()
    self:Update()
end

function Range:OnDisable()
    self.events:OffAll()
    self.frame:Hide()
end

function Range:Refresh()
    self:Layout()
    self:Update()
end

HS:On("EDIT_MODE", function(on)
    if not Range.enabled then return end
    if on then
        Range.frame:SetAlpha(1)
        Range:Paint("dead")
    else
        Range:Update()
    end
end)

-- Re-dock when the Auto Shot bar moves or is toggled.
HS:On("ELEMENT_MOVED", function()
    if Range.enabled and Range.docked then Range:Layout() end
end)
HS:On("MODULE_TOGGLED", function(key)
    if key == "shotTimer" and Range.enabled then Range:Layout() end
end)
