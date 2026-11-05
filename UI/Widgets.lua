--[[
    HunterSuite - widgets
    HUD building blocks: animated status bars, icons, buttons, fades and
    the shared animation ticker.
]]

local _, HS = ...
local UI = HS.UI
local P = UI.palette

---------------------------------------------------------------------------
-- Animation ticker: one OnUpdate drives every tween.
---------------------------------------------------------------------------

local tweens = {}
local ticker = CreateFrame("Frame")
ticker:Hide()

local function Ease(t) -- easeOutCubic
    t = 1 - t
    return 1 - t * t * t
end

ticker:SetScript("OnUpdate", function(_, elapsed)
    local any = false
    for key, tw in pairs(tweens) do
        tw.t = tw.t + elapsed
        local p = tw.duration > 0 and math.min(1, tw.t / tw.duration) or 1
        local v = tw.from + (tw.to - tw.from) * Ease(p)
        tw.apply(v)
        if p >= 1 then
            tweens[key] = nil
            if tw.done then tw.done() end
        else
            any = true
        end
    end
    if not any and next(tweens) == nil then ticker:Hide() end
end)

-- Animate a number from `from` to `to`; `key` replaces a running tween.
function UI:Tween(key, from, to, duration, apply, done)
    tweens[key] = { from = from, to = to, duration = duration or 0.2, t = 0, apply = apply, done = done }
    ticker:Show()
end

function UI:StopTween(key)
    tweens[key] = nil
end

function UI:FadeTo(frame, alpha, duration, done)
    local from = frame:GetAlpha()
    if math.abs(from - alpha) < 0.01 then
        frame:SetAlpha(alpha)
        if done then done() end
        return
    end
    self:Tween(frame, from, alpha, duration or 0.18, function(v) frame:SetAlpha(v) end, done)
end

-- Fade in/out for frames that are never protected.
function UI:FadeIn(frame, duration, alpha)
    if not frame:IsShown() then
        frame:SetAlpha(0)
        frame:Show()
    end
    self:FadeTo(frame, alpha or 1, duration)
end

function UI:FadeOut(frame, duration)
    if not frame:IsShown() then return end
    self:FadeTo(frame, 0, duration, function() frame:Hide() end)
end

---------------------------------------------------------------------------
-- Status bar
---------------------------------------------------------------------------

local BarMixin = {}

function BarMixin:SetFillColor(r, g, b, a)
    self.bar:SetStatusBarColor(r, g, b, a or 1)
    if self.spark then self.spark:SetVertexColor(math.min(1, r + 0.35), math.min(1, g + 0.35), math.min(1, b + 0.35), 0.9) end
end

-- Secret values (12.x combat) may be handed to the widget but never stored
-- for our own maths, so the bar forgets its numbers until they are readable.
local IsSecret = HS.Compat.IsSecret

function BarMixin:SetRange(minV, maxV)
    self.bar:SetMinMaxValues(minV, maxV)
    if IsSecret(minV) or IsSecret(maxV) then
        self.min, self.max = nil, nil
    else
        self.min, self.max = minV, maxV
    end
end

-- Set immediately (secret-safe: values go straight to the widget).
function BarMixin:SetValueNow(v)
    self.bar:SetValue(v)
    if self.smoothing then
        self.smoothing = false
        self:SetScript("OnUpdate", nil)
    end
    if IsSecret(v) then
        self.current, self.target = nil, nil
        if self.spark then self.spark:Hide() end
        return
    end
    self.current = v
    self.target = v
    self:UpdateSpark()
end

-- Glide toward v.
function BarMixin:SetValueSmooth(v)
    if IsSecret(v) or self.current == nil or self.max == nil then
        self:SetValueNow(v)
        return
    end
    self.target = v
    if not self.smoothing then
        self.smoothing = true
        self:SetScript("OnUpdate", self.OnSmoothUpdate)
    end
end

function BarMixin:OnSmoothUpdate(elapsed)
    local diff = (self.target or 0) - (self.current or 0)
    if math.abs(diff) < 0.001 * math.max(1, (self.max or 1) - (self.min or 0)) then
        self.current = self.target
        self.smoothing = false
        self:SetScript("OnUpdate", nil)
    else
        self.current = self.current + diff * math.min(1, elapsed * 14)
    end
    self.bar:SetValue(self.current)
    self:UpdateSpark()
end

function BarMixin:UpdateSpark()
    if not self.spark then return end
    local v, minV, maxV = self.current, self.min or 0, self.max
    if v == nil or maxV == nil or maxV <= minV then
        self.spark:Hide()
        return
    end
    local frac = (v - minV) / (maxV - minV)
    if frac <= 0.001 or frac >= 0.999 or not self.showSpark then
        self.spark:Hide()
        return
    end
    self.spark:ClearAllPoints()
    self.spark:SetPoint("CENTER", self.bar, "LEFT", self.bar:GetWidth() * frac, 0)
    self.spark:Show()
end

function BarMixin:SetSparkShown(shown)
    self.showSpark = shown
    self:UpdateSpark()
end

-- A dark track with a 1px edge, a fill, and a spark at the fill edge.
-- opts: height, spark (bool), border (color key), track (color key)
function UI:Bar(parent, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", nil, parent)
    Mixin(f, BarMixin)
    f:SetHeight(opts.height or 12)

    local track = f:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(UI:Color(opts.track or "track"))
    f.track = track

    local bar = CreateFrame("StatusBar", nil, f)
    local px = UI.OnePixel(f)
    bar:SetPoint("TOPLEFT", px, -px)
    bar:SetPoint("BOTTOMRIGHT", -px, px)
    UI:TrackBarTexture(bar)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    f.bar = bar

    if opts.border ~= false then
        f.edge = UI:Border(f, opts.border or { 0, 0, 0, 0.85 })
    end

    if opts.spark ~= false then
        local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        spark:SetTexture(UI.tex.spark)
        spark:SetBlendMode("ADD")
        spark:SetWidth(10)
        spark:SetPoint("TOP", 0, 4)
        spark:SetPoint("BOTTOM", 0, -4)
        spark:Hide()
        f.spark = spark
        f.showSpark = true
        spark:SetHeight((opts.height or 12) + 8)
    end

    f.min, f.max, f.current = 0, 1, 0
    f:SetFillColor(UI:Accent())
    return f
end

---------------------------------------------------------------------------
-- Icon
---------------------------------------------------------------------------

-- Square icon with cropped edges and a 1px frame. opts.cooldown adds a swipe.
function UI:Icon(parent, size, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = tex
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)
    f.bg = bg
    if opts.round then
        local mask = f:CreateMaskTexture()
        mask:SetTexture(UI.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tex)
        tex:AddMaskTexture(mask)
        bg:SetTexture(UI.tex.circle)
        bg:SetVertexColor(0, 0, 0, 1)
        tex:SetTexCoord(0, 1, 0, 1)
    end
    if opts.cooldown then
        local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        cd:SetAllPoints(tex)
        cd:SetDrawEdge(false)
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        cd:SetReverse(true)
        f.cooldown = cd
    end
    return f
end

---------------------------------------------------------------------------
-- Buttons (settings window, toolbars)
---------------------------------------------------------------------------

local BUTTON_STYLES = {
    primary   = { bg = "accent", text = { 0.04, 0.05, 0.06, 1 }, hover = 0.12 },
    secondary = { bg = "surface3", text = "text", border = "border", hover = 0.06 },
    ghost     = { bg = { 1, 1, 1, 0 }, text = "textDim", hover = 0.05, hoverText = "text" },
    danger    = { bg = { 0.32, 0.10, 0.11, 1 }, text = { 1, 0.62, 0.62, 1 }, border = { 0.55, 0.18, 0.18, 1 }, hover = 0.06 },
}

local function ResolveColor(c)
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    return UI:Color(c)
end

function UI:Button(parent, label, style, width, height)
    style = style or "secondary"
    local spec = BUTTON_STYLES[style]
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 110, height or 26)
    UI:Surface(b, { radius = 6, color = spec.bg == "accent" and { UI:Accent() } or spec.bg, border = spec.border or false })
    b.text = UI:Text(b, { size = 12, color = spec.text })
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label or "")
    b.style = style

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    if UI.canSlice then
        hl:SetTexture(UI.tex.round6)
        hl:SetTextureSliceMargins(8, 8, 8, 8)
    else
        hl:SetTexture(UI.tex.white)
    end
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, spec.hover)
    hl:SetBlendMode("ADD")

    if spec.hoverText then
        b:HookScript("OnEnter", function(self) self.text:SetTextColor(ResolveColor(spec.hoverText)) end)
        b:HookScript("OnLeave", function(self) self.text:SetTextColor(ResolveColor(spec.text)) end)
    end
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.text:SetPoint("CENTER", 0, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)

    function b:SetLabel(text) self.text:SetText(text) end
    function b:RefreshAccent()
        if self.style == "primary" then UI:SetSurfaceColor(self, { UI:Accent() }) end
    end
    b:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return b
end

-- Small square icon button (close, chevrons...).
function UI:IconButton(parent, texture, size, color)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 22, size or 22)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetPoint("CENTER")
    t:SetSize((size or 22) * 0.62, (size or 22) * 0.62)
    t:SetTexture(texture)
    local r, g, bb, a = ResolveColor(color or "textDim")
    t:SetVertexColor(r, g, bb, a)
    b.icon = t
    local hl = b:CreateTexture(nil, "BACKGROUND")
    if UI.canSlice then
        hl:SetTexture(UI.tex.round6)
        hl:SetTextureSliceMargins(8, 8, 8, 8)
    else
        hl:SetTexture(UI.tex.white)
    end
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0)
    b:SetScript("OnEnter", function()
        hl:SetVertexColor(1, 1, 1, 0.07)
        t:SetVertexColor(UI:Color("text"))
    end)
    b:SetScript("OnLeave", function()
        hl:SetVertexColor(1, 1, 1, 0)
        t:SetVertexColor(r, g, bb, a)
    end)
    return b
end

---------------------------------------------------------------------------
-- Flash overlay (shot fired, alert appears)
---------------------------------------------------------------------------

function UI:Flash(frame, r, g, b, peak, duration)
    local fl = frame.__hsFlash
    if not fl then
        fl = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        fl:SetAllPoints()
        fl:SetTexture(UI.tex.white)
        fl:SetBlendMode("ADD")
        fl:SetAlpha(0)
        frame.__hsFlash = fl
    end
    fl:SetVertexColor(r or 1, g or 1, b or 1)
    self:Tween(fl, peak or 0.55, 0, duration or 0.25, function(v) fl:SetAlpha(v) end)
end

---------------------------------------------------------------------------
-- HUD element base: positioning, scale, mover registration
---------------------------------------------------------------------------

-- Create a top-level HUD frame that remembers its position in `db.position`.
-- `template` may name a secure template (the frame is then protected).
function UI:Element(name, db, label, template)
    local f = CreateFrame(template and "Button" or "Frame", name, UIParent, template)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f.hsDB = db
    f.hsLabel = label
    f.hsProtected = template ~= nil
    self:ApplyPosition(f)
    return f
end

function UI:ApplyPosition(f)
    local pos = f.hsDB.position
    if not pos then return end
    local apply = function()
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
        f:SetScale(HS.db.appearance.scale or 1)
    end
    if f.hsProtected then
        HS:RunOutOfCombat(apply, f)
    else
        apply()
    end
end
