--[[
    HunterSuite - alert stack
    Reminders (aspect, Growl, tracking...) share one movable anchor and stack
    by priority instead of each floating somewhere on screen.
]]

local _, HS = ...
local L = HS.L
local UI = HS.UI

local A = { active = {}, pool = {}, order = 0, dismissed = {} }
HS.Alerts = A

local WIDTH, HEIGHT, GAP = 270, 40, 6

local anchor

local function GetAnchor()
    if anchor then return anchor end
    anchor = UI:Element("HunterSuiteAlertAnchor", HS.db.alerts, L.ALERTS)
    anchor:SetSize(WIDTH, HEIGHT)
    HS.Movers:Register(anchor, { label = L.ALERTS, defaultPath = "alerts.position" })
    return anchor
end

---------------------------------------------------------------------------
-- Alert card
---------------------------------------------------------------------------

local function CreateCard()
    local c = CreateFrame("Button", nil, UIParent)
    c:SetSize(WIDTH, HEIGHT)
    c:SetFrameStrata("HIGH")
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI:Surface(c, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })

    c.stripe = c:CreateTexture(nil, "ARTWORK")
    c.stripe:SetPoint("TOPLEFT", 4, -6)
    c.stripe:SetPoint("BOTTOMLEFT", 4, 6)
    c.stripe:SetWidth(3)
    c.stripe:SetTexture(UI.tex.white)

    c.iconFrame = UI:Icon(c, 26)
    c.iconFrame:SetPoint("LEFT", 14, 0)

    c.title = UI:Text(c, { size = 13, color = "text" })
    -- icon is 26 tall in a 40 card: its top sits 7 below the card's top
    c.title:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 10, 1)
    c.title:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -6)
    c.title:SetJustifyH("LEFT")

    c.sub = UI:Text(c, { size = 11, color = "textDim" })
    c.sub:SetPoint("BOTTOMLEFT", c.iconFrame, "BOTTOMRIGHT", 10, -1)
    c.sub:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 6)
    c.sub:SetJustifyH("LEFT")

    c:SetScript("OnClick", function(self, button)
        local spec = self.spec
        if not spec then return end
        if button == "RightButton" then
            local key = self.key
            A:Clear(key)
            -- Without its own snooze logic, a dismissed alert stays away until
            -- the module clears it (the problem was fixed) and it happens again.
            if spec.onDismiss then
                spec.onDismiss()
            else
                A.dismissed[key] = true
            end
        elseif spec.onClick then
            spec.onClick()
        end
    end)
    c:SetScript("OnEnter", function(self)
        local spec = self.spec
        if not spec then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
        GameTooltip:AddLine(spec.title, 1, 1, 1)
        if spec.tooltip then
            for line in spec.tooltip:gmatch("[^\n]+") do
                GameTooltip:AddLine(line, 0.75, 0.77, 0.8, true)
            end
        end
        GameTooltip:AddLine(spec.dismissHint or L.RIGHT_CLICK_TO_DISMISS, 0.5, 0.52, 0.56)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:Hide()
    return c
end

local function Paint(card, spec)
    card.spec = spec
    local r, g, b = UI:Color(spec.color or "warn")
    card.stripe:SetVertexColor(r, g, b, 1)
    card.title:SetText(spec.title or "")
    card.title:SetTextColor(r * 0.35 + 0.65, g * 0.35 + 0.65, b * 0.35 + 0.65)
    card.sub:SetText(spec.text or "")
    card.iconFrame.icon:SetTexture(spec.icon or 134400)
    UI:SetBorderColor(card, { r, g, b, 0.35 })
    UI:SetGlow(card, spec.glow and true or false, { r, g, b, 0.9 })
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function Sorted()
    local list = {}
    for _, card in pairs(A.active) do list[#list + 1] = card end
    table.sort(list, function(a, b)
        local pa, pb = a.spec.priority or 0, b.spec.priority or 0
        if pa ~= pb then return pa > pb end
        return a.order < b.order
    end)
    return list
end

function A:Layout()
    local anc = GetAnchor()
    local down = HS.db.alerts.grow ~= "UP"
    local scale = HS.db.appearance.scale or 1
    for i, card in ipairs(Sorted()) do
        card:SetScale(scale)
        card:ClearAllPoints()
        local offset = (i - 1) * (HEIGHT + GAP)
        if down then
            card:SetPoint("TOP", anc, "TOP", 0, -offset)
        else
            card:SetPoint("BOTTOM", anc, "BOTTOM", 0, offset)
        end
    end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

-- spec: title, text, icon, color (palette key), priority, glow, sound,
--       tooltip, onClick, onDismiss, timeout (seconds)
function A:Set(key, spec)
    if self.dismissed[key] then return end
    local card = self.active[key]
    local isNew = card == nil
    if isNew then
        card = table.remove(self.pool) or CreateCard()
        card.key = key
        self.order = self.order + 1
        card.order = self.order
        self.active[key] = card
    end
    Paint(card, spec)
    if card.timer then card.timer:Cancel(); card.timer = nil end
    if spec.timeout then
        card.timer = C_Timer.NewTimer(spec.timeout, function()
            card.timer = nil
            A:Clear(key)
        end)
    end
    self:Layout()
    if isNew then
        UI:StopTween(card)
        card:SetAlpha(0)
        card:Show()
        UI:FadeTo(card, 1, 0.22)
        local r, g, b = UI:Color(spec.color or "warn")
        UI:Flash(card, r, g, b, 0.4)
        if spec.sound then HS.Compat.PlaySound(spec.sound) end
    end
end

-- Modules call this when the condition is gone, which also forgets a dismissal.
function A:Clear(key)
    self.dismissed[key] = nil
    local card = self.active[key]
    if not card then return end
    self.active[key] = nil
    if card.timer then card.timer:Cancel(); card.timer = nil end
    UI:SetGlow(card, false)
    UI:FadeTo(card, 0, 0.18, function()
        card:Hide()
        card.spec = nil
        table.insert(A.pool, card)
    end)
    self:Layout()
end

function A:IsShown(key)
    return self.active[key] ~= nil
end

function A:Test()
    self.dismissed.test1, self.dismissed.test2, self.dismissed.test3 = nil, nil, nil
    self:Set("test1", { title = L.NO_ASPECT_ACTIVE, text = L.RIGHT_CLICK_TO_DISMISS, icon = 136076, color = "warn", priority = 5, timeout = 6 })
    self:Set("test2", { title = L.ASPECT_OF_THE_CHEETAH_IN_COMBAT, text = L.YOU_WILL_BE_DAZED_WHEN_HIT, icon = 132242, color = "danger", glow = true, priority = 9, timeout = 6 })
    self:Set("test3", { title = L.GROWL_IS_ON, text = L.TURN_OFF_TAUNT_IN_GROUPS, icon = 132270, color = "info", priority = 3, timeout = 6 })
end

---------------------------------------------------------------------------
-- Edit mode preview + appearance refresh
---------------------------------------------------------------------------

HS:On("MODULES_READY", function()
    GetAnchor()
end)

HS:On("EDIT_MODE", function(on)
    GetAnchor()
    if on then
        if not next(A.active) then
            A:Set("__preview", { title = L.ALERTS_APPEAR_HERE, text = L.REMINDERS_STACK_FROM_THIS_POINT, icon = 132329, color = "accent", priority = 0 })
        end
    else
        A:Clear("__preview")
    end
end)

HS:On("REFRESH_ALL", function()
    if anchor then UI:ApplyPosition(anchor) end
    A:Layout()
end)
