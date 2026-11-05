--[[
    HunterSuite - settings window
    Sidebar navigation, an overview dashboard and pages of cards built from
    HS.Options. Controls are drawn here: switches, sliders, dropdowns,
    segmented pickers and accent swatches.
]]

local _, HS = ...
local UI, C, O = HS.UI, HS.Compat, HS.Options

local Config = {}
HS.Config = Config

local WIDTH, HEIGHT = 860, 580
local SIDEBAR = 206
local PAD = 22
local CARD_PAD = 16
local ROW_MIN = 40

local window
local refreshers = {}       -- functions that re-read values (on show / after changes)

---------------------------------------------------------------------------
-- Value plumbing
---------------------------------------------------------------------------

local pendingAfter = {}
local function Apply(path, value)
    HS:SetPath(path, value)
    local after = O.AfterChange(path)
    if after then
        if pendingAfter[path] then pendingAfter[path]:Cancel() end
        pendingAfter[path] = C_Timer.NewTimer(0.06, function()
            pendingAfter[path] = nil
            after()
            for _, fn in ipairs(refreshers) do fn() end
        end)
    end
end

local function Get(path)
    return HS:GetPath(path)
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

-- iOS-style switch.
local function Switch(parent, onToggle)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(38, 22)
    local function piece(w, h)
        local t = s:CreateTexture(nil, "ARTWORK")
        t:SetSize(w, h)
        return t
    end
    local left, right, mid = piece(22, 22), piece(22, 22), piece(16, 22)
    left:SetTexture(UI.tex.circle); left:SetPoint("LEFT")
    right:SetTexture(UI.tex.circle); right:SetPoint("RIGHT")
    mid:SetTexture(UI.tex.white); mid:SetPoint("LEFT", 11, 0); mid:SetPoint("RIGHT", -11, 0)
    s.track = { left, right, mid }
    local knob = s:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(UI.tex.circle)
    knob:SetSize(16, 16)
    s.knob = knob
    s.pos = 0

    local function paint(t)
        local r, g, b = UI:Accent()
        local or_, og, ob = UI:Color("surface3")
        local tr, tg, tb = or_ + (r - or_) * t, og + (g - og) * t, ob + (b - ob) * t
        for _, p in ipairs(s.track) do p:SetVertexColor(tr, tg, tb, 1) end
        local k = 0.62 + 0.38 * t
        knob:SetVertexColor(k, k, k, 1)
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", 3 + 16 * t, 0)
        s.pos = t
    end
    s.Paint = paint

    function s:SetChecked(value, animate)
        self.checked = value and true or false
        local to = self.checked and 1 or 0
        if animate then
            UI:Tween(self, self.pos, to, 0.16, paint)
        else
            paint(to)
        end
    end
    s:SetScript("OnClick", function(self)
        if not self:IsEnabled() then return end
        self:SetChecked(not self.checked, true)
        PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
        if onToggle then onToggle(self.checked) end
    end)
    s:SetScript("OnDisable", function(self) self:SetAlpha(0.35) end)
    s:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    paint(0)
    return s
end

local function Slider(parent, item, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(230, 22)
    local valueText = UI:Text(holder, { size = 12, color = "text", justify = "RIGHT" })
    valueText:SetPoint("RIGHT")
    valueText:SetWidth(54)

    local s = CreateFrame("Slider", nil, holder)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("LEFT")
    s:SetPoint("RIGHT", valueText, "LEFT", -10, 0)
    s:SetHeight(16)
    s:SetHitRectInsets(-4, -4, -8, -8)
    s:SetMinMaxValues(item.min, item.max)
    s:SetValueStep(item.step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(UI.tex.white)
    track:SetVertexColor(UI:Color("surface3"))
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(UI.tex.white)
    fill:SetHeight(4)
    fill:SetPoint("LEFT")
    s:SetThumbTexture(UI.tex.circle)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(14, 14)
    thumb:SetVertexColor(0.95, 0.96, 0.97, 1)

    local function paintFill(v)
        local w = s:GetWidth()
        local frac = (v - item.min) / (item.max - item.min)
        fill:SetWidth(math.max(1, w * frac))
        fill:SetVertexColor(UI:Accent())
        valueText:SetText(item.format and item.format(v) or tostring(v))
    end

    s:SetScript("OnValueChanged", function(self, v, userInput)
        v = math.floor(v / item.step + 0.5) * item.step
        paintFill(v)
        if userInput and onChange then onChange(v) end
    end)
    s:SetScript("OnSizeChanged", function(self) paintFill(self:GetValue()) end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = math.max(item.min, math.min(item.max, self:GetValue() + delta * item.step))
        self:SetValue(v)
        if onChange then onChange(v) end
    end)

    function holder:SetValue(v)
        s:SetValue(v)
        paintFill(v)
    end
    holder.slider = s
    return holder
end

-- Shared dropdown menu.
local menu, blocker
local function CloseMenu()
    if menu then menu:Hide() end
    if blocker then blocker:Hide() end
end

local function OpenMenu(owner, values, current, onPick)
    if not menu then
        blocker = CreateFrame("Button", nil, UIParent)
        blocker:SetAllPoints(UIParent)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetScript("OnClick", CloseMenu)
        menu = CreateFrame("Frame", nil, blocker)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(blocker:GetFrameLevel() + 5)
        menu:EnableMouse(true)
        menu:EnableMouseWheel(true)
        UI:Surface(menu, { radius = 6, color = "surface2", shadow = true })
        menu.buttons = {}
        menu:SetScript("OnMouseWheel", function(self, delta)
            self.offset = math.max(0, math.min(#self.values - self.visible, self.offset - delta))
            self:Paint()
        end)
        function menu:Paint()
            for i, btn in ipairs(self.buttons) do
                local opt = self.values[i + self.offset]
                if opt and i <= self.visible then
                    btn.value = opt.value
                    btn.text:SetText(opt.label)
                    if opt.font then
                        btn.text:SetFont(opt.font, 13, "")
                    else
                        UI:SetTextSize(btn.text, 12)
                    end
                    local active = opt.value == self.current
                    btn.check:SetShown(active)
                    btn.text:SetTextColor(UI:Color(active and "text" or "textDim"))
                    btn:Show()
                else
                    btn:Hide()
                end
            end
        end
    end
    -- normalise {value,label} pairs
    local list = {}
    for _, v in ipairs(type(values) == "function" and values() or values) do
        if v.value ~= nil then list[#list + 1] = v else list[#list + 1] = { value = v[1], label = v[2] } end
    end
    menu.values, menu.current, menu.onPick, menu.offset = list, current, onPick, 0
    menu.visible = math.min(#list, 12)
    local w = math.max(owner:GetWidth(), 200)
    for i = #menu.buttons + 1, menu.visible do
        local btn = CreateFrame("Button", nil, menu)
        btn:SetHeight(26)
        btn:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
        btn:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 26)
        local hl = btn:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetTexture(UI.tex.white)
        hl:SetVertexColor(1, 1, 1, 0)
        btn.text = UI:Text(btn, { size = 12 })
        btn.text:SetPoint("LEFT", 26, 0)
        btn.text:SetPoint("RIGHT", -8, 0)
        btn.text:SetJustifyH("LEFT")
        btn.check = btn:CreateTexture(nil, "ARTWORK")
        btn.check:SetTexture(UI.tex.check)
        btn.check:SetSize(14, 14)
        btn.check:SetPoint("LEFT", 8, 0)
        btn.check:SetVertexColor(UI:Accent())
        btn:SetScript("OnEnter", function() hl:SetVertexColor(1, 1, 1, 0.06) end)
        btn:SetScript("OnLeave", function() hl:SetVertexColor(1, 1, 1, 0) end)
        btn:SetScript("OnClick", function(self)
            local pick = menu.onPick
            CloseMenu()
            if pick then pick(self.value) end
        end)
        menu.buttons[i] = btn
    end
    for _, btn in ipairs(menu.buttons) do btn.check:SetVertexColor(UI:Accent()) end
    menu:SetSize(w, menu.visible * 26 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    menu:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:Paint()
    blocker:Show()
    menu:Show()
end

local function Dropdown(parent, item, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(250, 28)
    UI:Surface(b, { radius = 6, color = "surface3", border = "border" })
    b.text = UI:Text(b, { size = 12 })
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetPoint("RIGHT", -28, 0)
    b.text:SetJustifyH("LEFT")
    local chev = b:CreateTexture(nil, "ARTWORK")
    chev:SetTexture(UI.tex.chevronDown)
    chev:SetSize(14, 14)
    chev:SetPoint("RIGHT", -9, 0)
    chev:SetVertexColor(UI:Color("textDim"))
    b:SetScript("OnEnter", function(self) UI:SetBorderColor(self, "accent", 0.7) end)
    b:SetScript("OnLeave", function(self) UI:SetBorderColor(self, "border") end)
    function b:SetValue(v)
        self.value = v
        local values = type(item.values) == "function" and item.values() or item.values
        local label = tostring(v)
        for _, opt in ipairs(values) do
            local value, text = opt.value, opt.label
            if value == nil then value, text = opt[1], opt[2] end
            if value == v then label = text break end
        end
        self.text:SetText(label)
    end
    b:SetScript("OnClick", function(self)
        OpenMenu(self, item.values, self.value, function(v)
            self:SetValue(v)
            onChange(v)
        end)
    end)
    return b
end

local function Segmented(parent, item, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    local n = #item.values
    local segW = 78
    holder:SetSize(segW * n + 6, 28)
    UI:Surface(holder, { radius = 6, color = "surface3", border = "border" })
    local active = CreateFrame("Frame", nil, holder)
    active:SetSize(segW, 22)
    UI:Surface(active, { radius = 6, color = { UI:Accent() }, border = false })
    holder.segs = {}
    for i, opt in ipairs(item.values) do
        local s = CreateFrame("Button", nil, holder)
        s:SetSize(segW, 22)
        s:SetPoint("LEFT", 3 + (i - 1) * segW, 0)
        s:SetFrameLevel(active:GetFrameLevel() + 1)
        s.text = UI:Text(s, { size = 12 })
        s.text:SetPoint("CENTER")
        s.text:SetText(opt[2])
        s.value = opt[1]
        s:SetScript("OnClick", function(self)
            holder:SetValue(self.value, true)
            onChange(self.value)
        end)
        holder.segs[i] = s
    end
    function holder:SetValue(v, animate)
        for i, s in ipairs(self.segs) do
            local on = s.value == v
            if on then
                local x = 3 + (i - 1) * segW
                if animate and self.activeX then
                    local from = self.activeX
                    UI:Tween(active, from, x, 0.15, function(val)
                        active:ClearAllPoints()
                        active:SetPoint("LEFT", val, 0)
                    end)
                else
                    active:ClearAllPoints()
                    active:SetPoint("LEFT", x, 0)
                end
                self.activeX = x
            end
            s.text:SetTextColor(UI:Color(on and "bg" or "textDim"))
            if on then s.text:SetTextColor(0.05, 0.06, 0.07, 1) end
        end
        UI:SetSurfaceColor(active, { UI:Accent() })
    end
    return holder
end

local function AccentPicker(parent, item, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    local n = #UI.accentPresets
    holder:SetSize(n * 30 + 34, 26)
    holder.swatches = {}
    local function make(i, color, isCustom)
        local s = CreateFrame("Button", nil, holder)
        s:SetSize(24, 24)
        s:SetPoint("LEFT", (i - 1) * 30, 0)
        local ring = s:CreateTexture(nil, "BACKGROUND")
        ring:SetTexture(UI.tex.circle)
        ring:SetAllPoints()
        ring:SetVertexColor(1, 1, 1, 0)
        local dot = s:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(UI.tex.circle)
        dot:SetSize(18, 18)
        dot:SetPoint("CENTER")
        s.ring, s.dot = ring, dot
        if isCustom then
            dot:SetVertexColor(0.3, 0.32, 0.36)
            local plus = s:CreateTexture(nil, "OVERLAY")
            plus:SetTexture(UI.tex.move)
            plus:SetSize(10, 10)
            plus:SetPoint("CENTER")
            plus:SetVertexColor(0.9, 0.9, 0.9)
            s:SetScript("OnClick", function() Config:PickColor(onChange) end)
            s.tooltip = "Custom colour"
        else
            dot:SetVertexColor(color.r, color.g, color.b)
            s:SetScript("OnClick", function() onChange({ r = color.r, g = color.g, b = color.b }) end)
            s.tooltip = color.name
        end
        s:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tooltip, 1, 1, 1)
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        s.color = color
        holder.swatches[i] = s
    end
    for i, color in ipairs(UI.accentPresets) do make(i, color) end
    make(n + 1, nil, true)
    function holder:SetValue(v)
        local matched = false
        for _, s in ipairs(self.swatches) do
            local c = s.color
            local on = c and v and math.abs(c.r - v.r) < 0.01 and math.abs(c.g - v.g) < 0.01 and math.abs(c.b - v.b) < 0.01
            if on then matched = true end
            s.ring:SetVertexColor(1, 1, 1, on and 0.9 or 0)
        end
        local custom = self.swatches[#self.swatches]
        custom.ring:SetVertexColor(1, 1, 1, (not matched) and 0.9 or 0)
        if not matched and v then custom.dot:SetVertexColor(v.r, v.g, v.b) end
    end
    return holder
end

function Config:PickColor(onChange)
    local a = HS.db.appearance.accent
    local prev = { r = a.r, g = a.g, b = a.b }
    local function current()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        return { r = r, g = g, b = b }
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = a.r, g = a.g, b = a.b, hasOpacity = false,
            swatchFunc = function() onChange(current()) end,
            cancelFunc = function() onChange(prev) end,
        })
    else
        ColorPickerFrame.func = function() onChange(current()) end
        ColorPickerFrame.cancelFunc = function() onChange(prev) end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(a.r, a.g, a.b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

---------------------------------------------------------------------------
-- Rows and cards
---------------------------------------------------------------------------

local function Row(card, item, y, width)
    local row = CreateFrame("Frame", nil, card)
    row:SetPoint("TOPLEFT", CARD_PAD, -y)
    row:SetWidth(width)

    local label = UI:Text(row, { size = 13, color = "text" })
    label:SetPoint("TOPLEFT", 0, -12)
    label:SetJustifyH("LEFT")
    label:SetText(item.label or "")
    local desc
    if item.desc then
        desc = UI:Text(row, { size = 11, color = "textDim", wrap = true })
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        desc:SetWidth(width - 290)
        desc:SetJustifyH("LEFT")
        desc:SetText(item.desc)
    end

    local control
    local set = function(v) Apply(item.path, v) end
    if item.type == "toggle" then
        control = Switch(row, function(v) set(v) end)
        row.refresh = function() control:SetChecked(Get(item.path)) end
    elseif item.type == "slider" then
        control = Slider(row, item, set)
        row.refresh = function() control:SetValue(Get(item.path) or item.min) end
    elseif item.type == "select" then
        control = Dropdown(row, item, set)
        row.refresh = function() control:SetValue(Get(item.path)) end
    elseif item.type == "segmented" then
        control = Segmented(row, item, set)
        row.refresh = function() control:SetValue(Get(item.path)) end
    elseif item.type == "accent" then
        control = AccentPicker(row, item, function(v)
            set(v)
            control:SetValue(v)
        end)
        row.refresh = function() control:SetValue(Get(item.path)) end
    elseif item.type == "button" then
        control = UI:Button(row, item.text, item.style or "secondary", 150, 28)
        control:SetScript("OnClick", item.action)
    elseif item.type == "info" then
        label:SetText(item.text)
        label:SetTextColor(UI:Color("textDim"))
        UI:SetTextSize(label, 11)
        label:SetWordWrap(true)
        label:SetWidth(width)
        label:SetPoint("TOPLEFT", 0, -10)
    end
    if control then
        control:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -math.floor((ROW_MIN - control:GetHeight()) / 2))
        label:SetWidth(width - control:GetWidth() - 16)
    end
    if row.refresh then row.refresh() end

    local h = ROW_MIN
    if desc then h = math.max(h, 12 + label:GetStringHeight() + 4 + desc:GetStringHeight() + 12) end
    if item.type == "info" then h = math.max(30, label:GetStringHeight() + 20) end
    row:SetHeight(h)
    row.item = item
    return row, h
end

local function ModuleState(key)
    local mod = HS:GetModule(key)
    if not mod then return false, false end
    return HS.db[mod.dbKey].enabled ~= false, mod:IsSupported()
end

local function Card(parent, section, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    UI:Surface(card, { radius = 12, color = "surface", border = { 1, 1, 1, 0.06 } })

    local y = CARD_PAD
    local icon = UI:Icon(card, 22, { round = true })
    icon:SetPoint("TOPLEFT", CARD_PAD, -y + 1)
    icon.icon:SetTexture(section.icon or 134400)
    local title = UI:Text(card, { size = 15, color = "text" })
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText(section.title)

    local rows = {}
    if section.module then
        local sw = Switch(card, function(v)
            Apply(section.module and (HS:GetModule(section.module).dbKey .. ".enabled"), v)
        end)
        sw:SetPoint("TOPRIGHT", -CARD_PAD, -y + 1)
        card.switch = sw
        local note = UI:Text(card, { size = 11, color = "warn" })
        note:SetPoint("RIGHT", sw, "LEFT", -12, 0)
        card.note = note
    end
    y = y + 22 + 6

    local innerW = width - CARD_PAD * 2
    for i, item in ipairs(section.items) do
        if i > 1 then
            local line = card:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 0.05)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", CARD_PAD, -y)
            line:SetPoint("TOPRIGHT", -CARD_PAD, -y)
        end
        local row, h = Row(card, item, y, innerW)
        rows[#rows + 1] = row
        y = y + h
    end
    card:SetHeight(y + CARD_PAD - 6)

    function card:Refresh()
        local enabled, supported = true, true
        if section.module then
            enabled, supported = ModuleState(section.module)
            self.switch:SetChecked(enabled and supported)
            self.switch:SetEnabled(supported)
            self.note:SetText(supported and "" or O.UnsupportedReason(section.module))
        end
        for _, row in ipairs(rows) do
            if row.refresh then row.refresh() end
            row:SetAlpha((enabled and supported) and 1 or 0.4)
        end
    end
    card:Refresh()
    return card
end

---------------------------------------------------------------------------
-- Overview page
---------------------------------------------------------------------------

local function StatusTile(parent, width, titleText)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(width, 62)
    UI:Surface(t, { radius = 12, color = "surface", border = { 1, 1, 1, 0.06 } })
    t.iconFrame = UI:Icon(t, 34, { round = true })
    t.iconFrame:SetPoint("LEFT", 14, 0)
    t.caption = UI:Text(t, { size = 11, color = "textMute" })
    t.caption:SetPoint("TOPLEFT", t.iconFrame, "TOPRIGHT", 10, -1)
    t.caption:SetText(titleText)
    t.value = UI:Text(t, { size = 14 })
    t.value:SetPoint("BOTTOMLEFT", t.iconFrame, "BOTTOMRIGHT", 10, 1)
    t.value:SetWidth(width - 72)
    t.value:SetJustifyH("LEFT")
    return t
end

local function BuildHome(content, width)
    local y = 0

    -- Hero
    local hero = CreateFrame("Frame", nil, content)
    hero:SetPoint("TOPLEFT", 0, -y)
    hero:SetSize(width, 118)
    UI:Surface(hero, { radius = 12, color = "surface", border = { 1, 1, 1, 0.06 } })
    local glow = hero:CreateTexture(nil, "BACKGROUND", nil, -6)
    glow:SetTexture(UI.tex.white)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMLEFT", 1, 1)
    glow:SetWidth(width * 0.6)
    glow:SetGradient("HORIZONTAL", CreateColor(0.67, 0.83, 0.45, 0.10), CreateColor(0.67, 0.83, 0.45, 0))
    hero.glow = glow
    local logo = hero:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(72, 72)
    logo:SetPoint("LEFT", 22, 0)
    local name = UI:Text(hero, { size = 24 })
    name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 18, -6)
    name:SetText("|cffabd473Hunter|rSuite")
    hero.name = name
    local version = UI:Text(hero, { size = 11, color = "textDim" })
    version:SetPoint("LEFT", name, "RIGHT", 10, -3)
    version:SetText("v" .. HS.version)
    local client = UI:Text(hero, { size = 12, color = "textDim" })
    client:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    client:SetText(("%s  -  build %s  -  interface %d"):format(HS.clientName, HS.build or "?", HS.interface))
    local hint = UI:Text(hero, { size = 11, color = "textMute" })
    hint:SetPoint("TOPLEFT", client, "BOTTOMLEFT", 0, -6)
    hint:SetText("/hs opens this window  -  /hs edit moves frames")

    local edit = UI:Button(hero, "Edit layout", "primary", 120, 30)
    edit:SetPoint("TOPRIGHT", -20, -24)
    edit:SetScript("OnClick", function() HS:HideConfig(); HS.Movers:Start() end)
    local test = UI:Button(hero, "Test alerts", "secondary", 120, 30)
    test:SetPoint("TOP", edit, "BOTTOM", 0, -8)
    test:SetScript("OnClick", function() HS.Alerts:Test() end)
    content.heroAccent = function()
        local r, g, b = UI:Accent()
        glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.10), CreateColor(r, g, b, 0))
        name:SetText(("|cff%02x%02x%02xHunter|rSuite"):format(r * 255, g * 255, b * 255))
        edit:RefreshAccent()
    end
    content.heroAccent()
    y = y + 118 + 14

    -- Live status
    local tileW = (width - 24) / 3
    local pet = StatusTile(content, tileW, "PET")
    pet:SetPoint("TOPLEFT", 0, -y)
    local ammo = StatusTile(content, tileW, "AMMO")
    ammo:SetPoint("LEFT", pet, "RIGHT", 12, 0)
    local aspect = StatusTile(content, tileW, "ASPECT")
    aspect:SetPoint("LEFT", ammo, "RIGHT", 12, 0)
    y = y + 62 + 22

    content.live = function()
        local petMod = HS:GetModule("petBar")
        if UnitExists("pet") then
            SetPortraitTexture(pet.iconFrame.icon, "pet")
            local happiness = C.GetPetHappiness()
            local spec = petMod.HAPPINESS[happiness or 0]
            local petName = UnitName("pet")
            if spec and not C.IsSecret(petName) then
                pet.value:SetText(("%s  |c%s%s|r"):format(petName or "Pet", UI:Hex(spec.color), spec.label))
            else
                pet.value:SetText(petName)
            end
        else
            pet.iconFrame.icon:SetTexture(132161)
            pet.value:SetText("|cff6b6f78No pet|r")
        end
        local count = C.Readable(GetInventoryItemCount("player", INVSLOT_AMMO or 0)) or 0
        ammo.iconFrame.icon:SetTexture(GetInventoryItemTexture("player", INVSLOT_AMMO or 0) or 132382)
        ammo.value:SetText(count > 0 and (BreakUpLargeNumbers and BreakUpLargeNumbers(count) or count) or "|cff6b6f78None equipped|r")
        local aspMod = HS:GetModule("aspects")
        local cur = aspMod and aspMod.GetCurrent and aspMod:GetCurrent()
        if cur then
            aspect.iconFrame.icon:SetTexture(HS.Spells.Icon(cur.ids))
            aspect.value:SetText(HS.Spells.Name(cur.ids) or cur.key)
        else
            aspect.iconFrame.icon:SetTexture(136076)
            aspect.value:SetText("|cff6b6f78None|r")
        end
    end

    -- Modules grid
    local header = UI:Text(content, { size = 13, color = "textDim" })
    header:SetPoint("TOPLEFT", 0, -y)
    header:SetText("MODULES")
    y = y + 22

    local colW = (width - 12) / 2
    local tiles = {}
    local i = 0
    for _, mod in ipairs(HS.moduleOrder) do
        local blurb = O.moduleBlurbs[mod.key]
        if blurb and O.Visible(blurb) then
            local col = i % 2
            local rowY = y + math.floor(i / 2) * 66
            local t = CreateFrame("Frame", nil, content)
            t:SetSize(colW, 58)
            t:SetPoint("TOPLEFT", col * (colW + 12), -rowY)
            UI:Surface(t, { radius = 12, color = "surface", border = { 1, 1, 1, 0.06 } })
            local ic = UI:Icon(t, 30, { round = true })
            ic:SetPoint("LEFT", 14, 0)
            ic.icon:SetTexture(blurb.icon)
            local tt = UI:Text(t, { size = 13 })
            tt:SetPoint("TOPLEFT", ic, "TOPRIGHT", 12, 0)
            tt:SetText(mod.title)
            local sub = UI:Text(t, { size = 11, color = "textDim" })
            sub:SetPoint("BOTTOMLEFT", ic, "BOTTOMRIGHT", 12, 0)
            sub:SetWidth(colW - 120)
            sub:SetJustifyH("LEFT")
            local sw = Switch(t, function(v) Apply(mod.dbKey .. ".enabled", v) end)
            sw:SetPoint("RIGHT", -14, 0)
            t.refresh = function()
                local enabled, supported = ModuleState(mod.key)
                sw:SetChecked(enabled and supported)
                sw:SetEnabled(supported)
                sub:SetText(supported and blurb.text or ("|cffffbc48" .. O.UnsupportedReason(mod.key) .. "|r"))
                ic:SetAlpha((enabled and supported) and 1 or 0.45)
                tt:SetTextColor(UI:Color((enabled and supported) and "text" or "textDim"))
            end
            t.refresh()
            tiles[#tiles + 1] = t
            i = i + 1
        end
    end
    y = y + math.ceil(i / 2) * 66

    content.Refresh = function()
        for _, t in ipairs(tiles) do t.refresh() end
        content.live()
        content.heroAccent()
    end
    return y
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local function BuildPage(page, scrollChild, width)
    local content = CreateFrame("Frame", nil, scrollChild)
    content:SetPoint("TOPLEFT")
    content:SetWidth(width)
    local height
    if page.home then
        height = BuildHome(content, width)
    else
        local y = 0
        local cards = {}
        for _, section in ipairs(page.sections or {}) do
            local card = Card(content, section, width)
            card:SetPoint("TOPLEFT", 0, -y)
            y = y + card:GetHeight() + 14
            cards[#cards + 1] = card
        end
        content.Refresh = function()
            for _, card in ipairs(cards) do card:Refresh() end
        end
        height = y
    end
    content:SetHeight(height + 10)
    return content
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function BuildWindow()
    local w = CreateFrame("Frame", "HunterSuiteConfig", UIParent)
    w:SetSize(WIDTH, HEIGHT)
    w:SetPoint("CENTER")
    w:SetFrameStrata("DIALOG")
    w:SetToplevel(true)
    w:SetClampedToScreen(true)
    w:EnableMouse(true)
    w:SetMovable(true)
    w:Hide()
    UI:Surface(w, { radius = 12, color = { 0.055, 0.059, 0.068, 0.985 }, border = { 1, 1, 1, 0.08 }, shadow = true })
    tinsert(UISpecialFrames, "HunterSuiteConfig")

    -- Sidebar
    local side = CreateFrame("Frame", nil, w)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDEBAR)
    local sbg = side:CreateTexture(nil, "BACKGROUND")
    sbg:SetPoint("TOPLEFT", 1, -1)
    sbg:SetPoint("BOTTOMRIGHT", 0, 1)
    sbg:SetColorTexture(0.035, 0.039, 0.046, 0.9)
    local divider = side:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(1, 1, 1, 0.06)
    divider:SetWidth(1)
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")

    local drag = CreateFrame("Frame", nil, w)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT")
    drag:SetHeight(64)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() w:StartMoving() end)
    drag:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)

    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 18, -18)
    local title = UI:Text(side, { size = 16 })
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
    title:SetText("HunterSuite")
    local ver = UI:Text(side, { size = 10, color = "textMute" })
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    ver:SetText("v" .. HS.version .. "  -  " .. (HS.IS_FOREVER and "Forever" or HS.clientName))

    w.nav = {}
    local navY = 76
    local pages = {}
    for _, page in ipairs(O.pages) do
        if O.Visible(page) then pages[#pages + 1] = page end
    end
    for i, page in ipairs(pages) do
        local b = CreateFrame("Button", nil, side)
        b:SetHeight(36)
        b:SetPoint("TOPLEFT", 10, -navY - (i - 1) * 40)
        b:SetPoint("TOPRIGHT", -10, -navY - (i - 1) * 40)
        UI:Surface(b, { radius = 6, color = { 1, 1, 1, 0 }, border = false })
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetTexture(UI.tex.white)
        b.bar:SetSize(3, 18)
        b.bar:SetPoint("LEFT", 0, 0)
        b.bar:Hide()
        b.iconFrame = UI:Icon(b, 20, { round = true })
        b.iconFrame:SetPoint("LEFT", 12, 0)
        b.iconFrame.icon:SetTexture(page.icon)
        if page.icon == UI.tex.logo then
            b.iconFrame.icon:SetTexCoord(0, 1, 0, 1)
            b.iconFrame.bg:SetAlpha(0)
        end
        b.text = UI:Text(b, { size = 13, color = "textDim" })
        b.text:SetPoint("LEFT", b.iconFrame, "RIGHT", 12, 0)
        b.text:SetText(page.title)
        b.page = page
        b:SetScript("OnEnter", function(self)
            if Config.current ~= self.page.key then UI:SetSurfaceColor(self, { 1, 1, 1, 0.04 }) end
        end)
        b:SetScript("OnLeave", function(self)
            if Config.current ~= self.page.key then UI:SetSurfaceColor(self, { 1, 1, 1, 0 }) end
        end)
        b:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
            Config:Select(self.page.key)
        end)
        w.nav[page.key] = b
    end

    local editBtn = UI:Button(side, "Edit layout", "primary", SIDEBAR - 36, 32)
    editBtn:SetPoint("BOTTOM", 0, 18)
    editBtn:SetScript("OnClick", function() HS:HideConfig(); HS.Movers:Start() end)
    w.editBtn = editBtn

    local badge = CreateFrame("Frame", nil, side)
    badge:SetSize(SIDEBAR - 36, 26)
    badge:SetPoint("BOTTOM", editBtn, "TOP", 0, 10)
    UI:Surface(badge, { radius = 6, color = { 1, 1, 1, 0.03 }, border = { 1, 1, 1, 0.06 } })
    local dot = badge:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(UI.tex.circle)
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", 10, 0)
    dot:SetVertexColor(UI:Color(HS.IS_FOREVER and "good" or "info"))
    local badgeText = UI:Text(badge, { size = 11, color = "textDim" })
    badgeText:SetPoint("LEFT", dot, "RIGHT", 8, 0)
    badgeText:SetText(HS.clientName .. " detected")

    -- Header
    local main = CreateFrame("Frame", nil, w)
    main:SetPoint("TOPLEFT", SIDEBAR, 0)
    main:SetPoint("BOTTOMRIGHT")
    w.pageTitle = UI:Text(main, { size = 22 })
    w.pageTitle:SetPoint("TOPLEFT", PAD, -22)
    w.pageDesc = UI:Text(main, { size = 12, color = "textDim" })
    w.pageDesc:SetPoint("TOPLEFT", w.pageTitle, "BOTTOMLEFT", 0, -6)
    w.pageDesc:SetWidth(WIDTH - SIDEBAR - PAD - 60)
    w.pageDesc:SetJustifyH("LEFT")

    local close = UI:IconButton(main, UI.tex.close, 28)
    close:SetPoint("TOPRIGHT", -14, -14)
    close:SetScript("OnClick", function() HS:HideConfig() end)

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", nil, main)
    scroll:SetPoint("TOPLEFT", PAD, -86)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, 16)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - SIDEBAR - PAD * 2, 10)
    scroll:SetScrollChild(child)
    w.scroll, w.child = scroll, child

    local thumb = scroll:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(UI.tex.white)
    thumb:SetWidth(3)
    thumb:SetVertexColor(1, 1, 1, 0.18)
    w.thumb = thumb

    local function updateThumb()
        local range = scroll:GetVerticalScrollRange()
        if range <= 1 then thumb:Hide() return end
        local h = scroll:GetHeight()
        local th = math.max(30, h * h / (h + range))
        local pos = scroll:GetVerticalScroll() / range
        thumb:SetHeight(th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", PAD - 8, -(h - th) * pos)
        thumb:Show()
    end
    w.updateThumb = updateThumb
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local from = self:GetVerticalScroll()
        local to = math.max(0, math.min(range, from - delta * 60))
        UI:Tween(self, from, to, 0.18, function(v) self:SetVerticalScroll(v); updateThumb() end)
    end)
    scroll:SetScript("OnScrollRangeChanged", updateThumb)

    w.pages = {}
    w:SetScript("OnShow", function()
        Config:RefreshCurrent()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
    end)
    w:SetScript("OnHide", function()
        CloseMenu()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
    end)

    -- Live tiles tick while the overview is open.
    local tick = 0
    w:SetScript("OnUpdate", function(_, elapsed)
        tick = tick + elapsed
        if tick < 1 then return end
        tick = 0
        local page = w.pages.home
        if Config.current == "home" and page and page.live then page.live() end
    end)

    window = w
    HS:ApplyConfigScale()
    return w
end

function Config:Select(key)
    local w = window
    local page
    for _, p in ipairs(O.pages) do if p.key == key then page = p end end
    if not page then return end
    self.current = key
    for k, b in pairs(w.nav) do
        local active = k == key
        UI:SetSurfaceColor(b, active and { 1, 1, 1, 0.06 } or { 1, 1, 1, 0 })
        b.bar:SetShown(active)
        b.bar:SetVertexColor(UI:Accent())
        b.text:SetTextColor(UI:Color(active and "text" or "textDim"))
    end
    for k, content in pairs(w.pages) do content:SetShown(k == key) end
    if not w.pages[key] then
        w.pages[key] = BuildPage(page, w.child, WIDTH - SIDEBAR - PAD * 2)
    end
    local content = w.pages[key]
    content:Show()
    w.child:SetHeight(content:GetHeight())
    w.scroll:SetVerticalScroll(0)
    w.pageTitle:SetText(page.title)
    w.pageDesc:SetText(page.desc or "")
    if content.Refresh then content.Refresh() end
    content:SetAlpha(0)
    UI:FadeTo(content, 1, 0.16)
    C_Timer.After(0, w.updateThumb)
end

function Config:RefreshCurrent()
    if not window or not self.current then return end
    local content = window.pages[self.current]
    if content and content.Refresh then content.Refresh() end
    for k, b in pairs(window.nav) do
        if k == self.current then b.bar:SetVertexColor(UI:Accent()) end
    end
    window.editBtn:RefreshAccent()
end

table.insert(refreshers, function() Config:RefreshCurrent() end)
HS:On("MODULE_TOGGLED", function() Config:RefreshCurrent() end)
HS:On("SPELLS_UPDATED", function() Config:RefreshCurrent() end)

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function HS:ShowConfig(page)
    if not self.db then return end
    local w = window or BuildWindow()
    if page or not Config.current then Config:Select(page or "home") end
    w:SetAlpha(0)
    w:Show()
    UI:FadeTo(w, 1, 0.15)
end

function HS:HideConfig()
    if window and window:IsShown() then window:Hide() end
end

function HS:ToggleConfig(page)
    if window and window:IsShown() then self:HideConfig() else self:ShowConfig(page) end
end

function HS:ApplyConfigScale()
    if window then window:SetScale(self.db.appearance.configScale or 1) end
end

---------------------------------------------------------------------------
-- Diagnostics (copyable report)
---------------------------------------------------------------------------

local diag
function HS:ShowDiagnostics()
    local lines = {}
    local function add(fmt, ...) lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    add("HunterSuite %s", HS.version)
    add("Client: %s  build %s  interface %d  project %s", HS.clientName, tostring(HS.build), HS.interface, tostring(WOW_PROJECT_ID))
    add("Locale: %s   Class hunter: %s", GetLocale(), tostring(HS.isHunter))
    add("Swing API: %s   Auras restricted now: %s", tostring(C.HasSwingAPI), tostring(C.AurasRestricted()))
    add("")
    add("API availability:")
    for _, entry in ipairs(C.Inventory()) do
        add("  %-40s %s", entry[1], entry[2] and "yes" or "-")
    end
    add("")
    add("Modules:")
    for _, mod in ipairs(HS.moduleOrder) do
        local ok, supported = pcall(mod.IsSupported, mod)
        add("  %-12s enabled=%s running=%s supported=%s", mod.key, tostring(HS.db[mod.dbKey].enabled), tostring(mod.enabled), tostring(ok and supported))
    end
    add("")
    if UnitExists("pet") then
        local h, d, l = C.GetPetHappiness()
        add("Pet: %s  family=%s  happiness=%s dmg=%s loyaltyRate=%s", tostring(C.Readable(UnitName("pet"))), tostring(C.Readable(UnitCreatureFamily("pet"))), tostring(h), tostring(d), tostring(l))
        add("Diet: %s", table.concat(C.GetPetFoodTypes(), ", "))
        local petMod = HS:GetModule("petBar")
        if petMod.initialized then
            local food, list = petMod:FindFood()
            add("Food choice: %s (%d candidates)", food and (tostring(food.name) .. " #" .. food.itemID) or "none", #list)
        end
    else
        add("Pet: none")
    end
    local fb = _G.HunterSuiteFeedButton
    if fb then
        add("Feed button: type=%s spell=%s bag=%s slot=%s keyDown=%s", tostring(fb:GetAttribute("*type1")), tostring(fb:GetAttribute("*spell1")),
            tostring(fb:GetAttribute("*target-bag1")), tostring(fb:GetAttribute("*target-slot1")), tostring(fb:GetAttribute("useOnKeyDown")))
    else
        add("Feed button: missing (pet card module off?)")
    end
    add("Ammo slot count: %s   uses ammo: %s", tostring(C.Readable(GetInventoryItemCount("player", INVSLOT_AMMO or 0))), tostring(UnitUsesAmmo and C.Readable(UnitUsesAmmo("player"))))
    local text = table.concat(lines, "\n")

    if not diag then
        diag = CreateFrame("Frame", "HunterSuiteDiagnostics", UIParent)
        diag:SetSize(620, 460)
        diag:SetPoint("CENTER")
        diag:SetFrameStrata("FULLSCREEN_DIALOG")
        diag:EnableMouse(true)
        diag:SetMovable(true)
        diag:RegisterForDrag("LeftButton")
        diag:SetScript("OnDragStart", diag.StartMoving)
        diag:SetScript("OnDragStop", diag.StopMovingOrSizing)
        UI:Surface(diag, { radius = 12, color = "bg", shadow = true })
        tinsert(UISpecialFrames, "HunterSuiteDiagnostics")
        local t = UI:Text(diag, { size = 15 })
        t:SetPoint("TOPLEFT", 18, -16)
        t:SetText("Diagnostics")
        local hint = UI:Text(diag, { size = 11, color = "textDim" })
        hint:SetPoint("LEFT", t, "RIGHT", 10, -1)
        hint:SetText("Ctrl+A, Ctrl+C to copy")
        local close = UI:IconButton(diag, UI.tex.close, 26)
        close:SetPoint("TOPRIGHT", -10, -10)
        close:SetScript("OnClick", function() diag:Hide() end)
        local sf = CreateFrame("ScrollFrame", "HunterSuiteDiagScroll", diag, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 18, -46)
        sf:SetPoint("BOTTOMRIGHT", -36, 16)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(560)
        eb:SetScript("OnEscapePressed", function() diag:Hide() end)
        sf:SetScrollChild(eb)
        diag.edit = eb
    end
    diag.edit:SetText(text)
    diag:Show()
    diag.edit:SetFocus()
    diag.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Blizzard Settings entry
---------------------------------------------------------------------------

HS:On("CORE_READY", function()
    local panel = CreateFrame("Frame")
    panel.name = "HunterSuite"
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(64, 64)
    logo:SetPoint("TOPLEFT", 20, -20)
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    t:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -8)
    t:SetText("|cffabd473Hunter|rSuite")
    local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText("All settings live in HunterSuite's own window.")
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(200, 30)
    b:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -20)
    b:SetText("Open HunterSuite")
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        HS:ShowConfig()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "HunterSuite")
        Settings.RegisterAddOnCategory(category)
        HS.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)
