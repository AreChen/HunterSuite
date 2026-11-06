--[[
    HunterSuite - theme
    Palette, media, fonts and the low-level drawing helpers (pixel borders,
    rounded 9-slice surfaces, shadows, glows) shared by every frame.
]]

local _, HS = ...
local L = HS.L

local UI = {}
HS.UI = UI

local MEDIA = "Interface\\AddOns\\HunterSuite\\Media\\Textures\\"
UI.MEDIA = MEDIA
UI.tex = {
    white = "Interface\\Buttons\\WHITE8X8",
    bar = MEDIA .. "Bar",
    spark = MEDIA .. "Spark",
    circle = MEDIA .. "Circle",
    round6 = MEDIA .. "Round6",
    round6Border = MEDIA .. "Round6Border",
    round12 = MEDIA .. "Round12",
    round12Border = MEDIA .. "Round12Border",
    shadow = MEDIA .. "Shadow",
    glow = MEDIA .. "Glow",
    check = MEDIA .. "Check",
    chevronDown = MEDIA .. "ChevronDown",
    chevronRight = MEDIA .. "ChevronRight",
    close = MEDIA .. "Close",
    move = MEDIA .. "Move",
    logo = MEDIA .. "Logo",
}

-- Slice margins (texels) for the rounded textures.
local SLICE = {
    [6] = { fill = "round6", border = "round6Border", margin = 8 },
    [12] = { fill = "round12", border = "round12Border", margin = 14 },
}

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------

UI.palette = {
    bg       = { 0.043, 0.047, 0.055, 0.94 },
    surface  = { 0.075, 0.078, 0.090, 0.97 },
    surface2 = { 0.106, 0.110, 0.125, 1 },
    surface3 = { 0.145, 0.149, 0.169, 1 },
    track    = { 0.035, 0.039, 0.047, 0.90 },
    border   = { 0.180, 0.188, 0.212, 1 },
    line     = { 1, 1, 1, 0.06 },
    text     = { 0.925, 0.933, 0.945, 1 },
    textDim  = { 0.604, 0.620, 0.659, 1 },
    textMute = { 0.420, 0.435, 0.471, 1 },
    good     = { 0.333, 0.851, 0.522, 1 },
    warn     = { 1.000, 0.737, 0.282, 1 },
    danger   = { 0.969, 0.357, 0.357, 1 },
    info     = { 0.357, 0.667, 1.000, 1 },
    purple   = { 0.702, 0.522, 1.000, 1 },
    black    = { 0, 0, 0, 1 },
}
local P = UI.palette

function UI:Accent()
    local a = HS.db and HS.db.appearance.accent
    if a then return a.r, a.g, a.b end
    return 0.671, 0.831, 0.451
end

-- Palette key ("warn"), "accent", or an {r, g, b, a} table.
function UI:Color(name)
    if type(name) == "table" then
        return name[1], name[2], name[3], name[4] or 1
    end
    if name == "accent" then
        local r, g, b = self:Accent()
        return r, g, b, 1
    end
    local c = P[name] or P.text
    return c[1], c[2], c[3], c[4] or 1
end

function UI:Hex(name)
    local r, g, b = self:Color(name)
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

function UI:Colorize(name, text)
    return "|c" .. self:Hex(name) .. text .. "|r"
end

-- Accent presets offered in Appearance.
UI.accentPresets = {
    { name = L.HUNTER, r = 0.671, g = 0.831, b = 0.451 },
    { name = L.TEAL,   r = 0.047, g = 0.824, b = 0.616 },
    { name = L.AMBER,  r = 1.000, g = 0.737, b = 0.282 },
    { name = L.ICE,    r = 0.420, g = 0.773, b = 1.000 },
    { name = L.VIOLET, r = 0.702, g = 0.565, b = 1.000 },
    { name = L.ROSE,   r = 1.000, g = 0.443, b = 0.557 },
}

---------------------------------------------------------------------------
-- Fonts (LibSharedMedia when available)
---------------------------------------------------------------------------

local LSM
local function GetLSM()
    if not LSM then
        LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil
    end
    return LSM
end
UI.GetLSM = GetLSM

UI.builtinFonts = {
    { key = "default", name = L.GAME_DEFAULT, path = function() return STANDARD_TEXT_FONT end },
    { key = "friz", name = "Friz Quadrata", path = function() return "Fonts\\FRIZQT__.TTF" end },
    { key = "arialn", name = "Arial Narrow", path = function() return "Fonts\\ARIALN.TTF" end },
}

-- Fonts that make the HUD look sharp when another addon ships them.
local PREFERRED = { "Expressway", "Poppins", "FiraSans Medium", "Fira Sans Medium", "Barlow Condensed", "PT Sans Narrow" }
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }

function UI:FontPath()
    local choice = HS.db and HS.db.appearance.font or "auto"
    for _, f in ipairs(self.builtinFonts) do
        if f.key == choice then return f.path() end
    end
    local lsm = GetLSM()
    if choice == "auto" then
        if lsm and LATIN[GetLocale()] then
            for _, name in ipairs(PREFERRED) do
                if lsm:IsValid("font", name) then
                    return lsm:Fetch("font", name)
                end
            end
        end
        return STANDARD_TEXT_FONT
    end
    if lsm and lsm:IsValid("font", choice) then
        return lsm:Fetch("font", choice)
    end
    return STANDARD_TEXT_FONT
end

function UI:FontChoices()
    local list = { { value = "auto", label = L.AUTOMATIC } }
    for _, f in ipairs(self.builtinFonts) do
        list[#list + 1] = { value = f.key, label = f.name }
    end
    local lsm = GetLSM()
    if lsm then
        for _, name in ipairs(lsm:List("font")) do
            list[#list + 1] = { value = name, label = name, font = lsm:Fetch("font", name) }
        end
    end
    return list
end

local fontStrings = setmetatable({}, { __mode = "k" })

local function ApplyFont(fs, spec)
    local scale = HS.db and HS.db.appearance.fontScale or 1
    local ok = fs:SetFont(UI:FontPath(), math.max(6, spec.size * scale), spec.flags or "")
    if not ok then
        fs:SetFont(STANDARD_TEXT_FONT, math.max(6, spec.size * scale), spec.flags or "")
    end
    if spec.shadow ~= false then
        fs:SetShadowColor(0, 0, 0, spec.flags and spec.flags ~= "" and 0.6 or 0.9)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

-- Create a font string that follows the Appearance font settings.
-- opts: size, flags ("OUTLINE"...), color (palette key or {r,g,b,a}), justify, layer, shadow
function UI:Text(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
    local spec = { size = opts.size or 12, flags = opts.flags, shadow = opts.shadow }
    fontStrings[fs] = spec
    ApplyFont(fs, spec)
    local color = opts.color or "text"
    if type(color) == "table" then
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    else
        fs:SetTextColor(self:Color(color))
    end
    if opts.justify then fs:SetJustifyH(opts.justify) end
    fs:SetWordWrap(opts.wrap == true)
    return fs
end

function UI:SetTextSize(fs, size, flags)
    local spec = fontStrings[fs]
    if not spec then return end
    spec.size = size
    if flags ~= nil then spec.flags = flags end
    ApplyFont(fs, spec)
end

function UI:RefreshFonts()
    for fs, spec in pairs(fontStrings) do
        ApplyFont(fs, spec)
    end
end

HS:On("REFRESH_ALL", function() UI:RefreshShadows() end)

-- Fonts registered by other addons after we drew our text (EllesmereUI,
-- SharedMedia packs) are picked up once they arrive.
HS:On("MODULES_READY", function()
    local lsm = GetLSM()
    if not (lsm and lsm.RegisterCallback) then return end
    local pending = false
    lsm.RegisterCallback(UI, "LibSharedMedia_Registered", function(_, mediatype)
        if mediatype ~= "font" or pending then return end
        pending = true
        C_Timer.After(0.2, function()
            pending = false
            UI:RefreshFonts()
        end)
    end)
end)

---------------------------------------------------------------------------
-- Status bar textures
---------------------------------------------------------------------------

function UI:BarTexture()
    local choice = HS.db and HS.db.appearance.texture or "smooth"
    if choice == "smooth" then return self.tex.bar end
    if choice == "flat" then return self.tex.white end
    local lsm = GetLSM()
    if lsm and lsm:IsValid("statusbar", choice) then
        return lsm:Fetch("statusbar", choice)
    end
    return self.tex.bar
end

function UI:TextureChoices()
    local list = {
        { value = "smooth", label = L.HUNTERSUITE_SMOOTH },
        { value = "flat", label = L.FLAT },
    }
    local lsm = GetLSM()
    if lsm then
        for _, name in ipairs(lsm:List("statusbar")) do
            list[#list + 1] = { value = name, label = name }
        end
    end
    return list
end

local barTextures = setmetatable({}, { __mode = "k" })
function UI:TrackBarTexture(statusbar)
    barTextures[statusbar] = true
    statusbar:SetStatusBarTexture(self:BarTexture())
end

function UI:RefreshBarTextures()
    local path = self:BarTexture()
    for bar in pairs(barTextures) do
        bar:SetStatusBarTexture(path)
    end
end

---------------------------------------------------------------------------
-- Pixel-perfect borders
---------------------------------------------------------------------------

local PixelUtil = _G.PixelUtil

local function OnePixel(region)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, region:GetEffectiveScale(), 1)
    end
    return 1
end
UI.OnePixel = OnePixel

-- Four 1px edges inside `frame`. Returns a handle with :SetColor().
function UI:Border(frame, color, inset)
    local edges = {}
    local r, g, b, a
    if type(color) == "table" then
        r, g, b, a = color[1], color[2], color[3], color[4] or 1
    else
        r, g, b, a = self:Color(color or "border")
    end
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER", nil, 7)
        t:SetColorTexture(r, g, b, a)
        edges[i] = t
    end
    local handle = { edges = edges, frame = frame, inset = inset or 0 }
    function handle:Layout()
        local px = OnePixel(self.frame)
        local o = self.inset
        local e = self.edges
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", o, -o); e[1]:SetPoint("TOPRIGHT", -o, -o); e[1]:SetHeight(px)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", o, o); e[2]:SetPoint("BOTTOMRIGHT", -o, o); e[2]:SetHeight(px)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", o, -o); e[3]:SetPoint("BOTTOMLEFT", o, o); e[3]:SetWidth(px)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", -o, -o); e[4]:SetPoint("BOTTOMRIGHT", -o, o); e[4]:SetWidth(px)
    end
    function handle:SetColor(cr, cg, cb, ca)
        for i = 1, 4 do self.edges[i]:SetColorTexture(cr, cg, cb, ca or 1) end
    end
    function handle:SetShown(shown)
        for i = 1, 4 do self.edges[i]:SetShown(shown) end
    end
    handle:Layout()
    return handle
end

---------------------------------------------------------------------------
-- Rounded / flat surfaces
---------------------------------------------------------------------------

local probe = UIParent:CreateTexture()
UI.canSlice = probe.SetTextureSliceMargins ~= nil
probe:Hide()

local function Slice(tex, margin)
    tex:SetTextureSliceMargins(margin, margin, margin, margin)
    if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
end

local function unpackColor(color)
    if type(color) == "table" then
        return color[1], color[2], color[3], color[4] or 1
    end
    return UI:Color(color)
end

-- Paint a background (and optional border/shadow) on `frame`.
-- opts.radius: 6 | 12 | nil (flat); opts.color; opts.border (color or false); opts.shadow
function UI:Surface(frame, opts)
    opts = opts or {}
    local s = frame.__hsSurface or {}
    frame.__hsSurface = s
    local spec = opts.radius and self.canSlice and SLICE[opts.radius]

    if not s.bg then
        s.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        s.bg:SetAllPoints()
    end
    if spec then
        s.bg:SetTexture(self.tex[spec.fill])
        Slice(s.bg, spec.margin)
        s.bg:SetVertexColor(unpackColor(opts.color or "surface"))
    else
        s.bg:SetTexture(self.tex.white)
        s.bg:SetVertexColor(unpackColor(opts.color or "surface"))
    end

    if opts.border ~= false then
        if spec then
            if not s.ring then
                s.ring = frame:CreateTexture(nil, "BORDER", nil, 6)
                s.ring:SetAllPoints()
            end
            s.ring:SetTexture(self.tex[spec.border])
            Slice(s.ring, spec.margin)
            s.ring:SetVertexColor(unpackColor(opts.border or "border"))
            s.ring:Show()
            if s.edges then s.edges:SetShown(false) end
        else
            if not s.edges then
                s.edges = self:Border(frame, opts.border or "border")
            else
                s.edges:SetColor(unpackColor(opts.border or "border"))
                s.edges:Layout()
            end
            s.edges:SetShown(true)
            if s.ring then s.ring:Hide() end
        end
    end

    if opts.shadow then
        self:Shadow(frame)
    end
    return s
end

function UI:SetSurfaceColor(frame, color)
    local s = frame.__hsSurface
    if s and s.bg then s.bg:SetVertexColor(unpackColor(color)) end
end

function UI:SetBorderColor(frame, color, alpha)
    local s = frame.__hsSurface
    if not s then return end
    local r, g, b, a = unpackColor(color)
    a = alpha or a
    if s.ring and s.ring:IsShown() then s.ring:SetVertexColor(r, g, b, a) end
    if s.edges then s.edges:SetColor(r, g, b, a) end
end

local shadows = setmetatable({}, { __mode = "k" })

function UI:RefreshShadows()
    local on = not HS.db or HS.db.appearance.shadows
    for sh in pairs(shadows) do sh:SetShown(on and not sh.hsForceHidden) end
end

-- Soft drop shadow behind the frame.
function UI:Shadow(frame, spread)
    if frame.__hsShadow then
        frame.__hsShadow:SetShown(not HS.db or HS.db.appearance.shadows)
        return frame.__hsShadow
    end
    spread = spread or 12
    local sh = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    if self.canSlice then
        sh:SetTexture(self.tex.shadow)
        Slice(sh, 22)
    else
        sh:SetColorTexture(0, 0, 0, 0.35)
        spread = 2
    end
    sh:SetPoint("TOPLEFT", -spread, spread)
    sh:SetPoint("BOTTOMRIGHT", spread, -spread)
    sh:SetVertexColor(0, 0, 0, 0.85)
    frame.__hsShadow = sh
    shadows[sh] = true
    sh:SetShown(not HS.db or HS.db.appearance.shadows)
    return sh
end

---------------------------------------------------------------------------
-- Glow (pulsing outline for alerts)
---------------------------------------------------------------------------

function UI:Glow(frame, color)
    local g = frame.__hsGlow
    if not g then
        g = CreateFrame("Frame", nil, frame)
        g:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        g:SetPoint("TOPLEFT", -14, 14)
        g:SetPoint("BOTTOMRIGHT", 14, -14)
        local t = g:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        if self.canSlice then
            t:SetTexture(self.tex.glow)
            Slice(t, 24)
        else
            t:SetColorTexture(1, 1, 1, 0.15)
        end
        t:SetBlendMode("ADD")
        g.tex = t
        local ag = g:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0.25)
        a:SetToAlpha(1)
        a:SetDuration(0.7)
        a:SetSmoothing("IN_OUT")
        g.anim = ag
        g:Hide()
        frame.__hsGlow = g
    end
    if color then
        g.tex:SetVertexColor(unpackColor(color))
    end
    return g
end

function UI:SetGlow(frame, on, color)
    local g = self:Glow(frame, color)
    if on then
        if not g:IsShown() then
            g:Show()
            g.anim:Play()
        end
    elseif g:IsShown() then
        g.anim:Stop()
        g:Hide()
    end
end
