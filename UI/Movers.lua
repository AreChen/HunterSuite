--[[
    HunterSuite - edit mode
    Every HUD element registers here. Edit mode shows a labelled overlay on
    each one, an optional alignment grid and a toolbar. Drag to move (snaps
    to the grid, hold Shift to place freely), arrow keys nudge the selected
    element, right-click resets it.
]]

local _, HS = ...
local L = HS.L
local UI = HS.UI

local M = { entries = {}, active = false }
HS.Movers = M

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

-- opts: label, db (table holding .position), defaultPath ("petBar.position"),
--       module (key; mover only shows while that module is enabled)
function M:Register(frame, opts)
    local entry = {
        frame = frame,
        label = opts.label or frame.hsLabel or L.FRAME,
        db = opts.db or frame.hsDB,
        defaultPath = opts.defaultPath,
        module = opts.module,
        hidden = opts.hidden,
    }
    frame:SetMovable(true)
    table.insert(self.entries, entry)
    if self.active then self:ShowMover(entry) end
    return entry
end

local function EntryEnabled(entry)
    if entry.hidden and entry.hidden() then return false end
    if not entry.module then return true end
    local mod = HS:GetModule(entry.module)
    return mod and mod.enabled
end

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

local function Round(v) return math.floor(v + 0.5) end

-- Offsets of `f`'s center from UIParent's center, in f's own scale units
-- (what SetPoint expects).
local function CenterOffset(f)
    local cx, cy = f:GetCenter()
    if not cx then return 0, 0 end
    local fs, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    return cx - ux * us / fs, cy - uy * us / fs
end

local function Snap(v, f)
    if not HS.db.appearance.snapToGrid or IsShiftKeyDown() then return Round(v) end
    local grid = HS.db.appearance.gridSize or 16
    local ratio = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    local step = grid * ratio
    return Round(Round(v / step) * step)
end

local function SavePosition(entry, x, y, point)
    local f = entry.frame
    local pos = entry.db.position
    point = point or "CENTER"
    pos.point, pos.relPoint, pos.x, pos.y = point, point, x, y
    f:ClearAllPoints()
    f:SetPoint(point, UIParent, point, x, y)
    HS:Fire("ELEMENT_MOVED", f)
end

---------------------------------------------------------------------------
-- Mover overlays
---------------------------------------------------------------------------

local selected

local function UpdateCoords(entry)
    local mover = entry.mover
    if not mover then return end
    local pos = entry.db.position
    mover.coords:SetText(("%d, %d"):format(pos.x or 0, pos.y or 0))
end

local function Select(entry)
    if selected and selected.mover then
        UI:SetBorderColor(selected.mover, "accent", 0.55)
        selected.mover.coords:Hide()
        selected.mover:EnableKeyboard(false)
    end
    selected = entry
    if entry and entry.mover then
        UI:SetBorderColor(entry.mover, { 1, 1, 1, 1 })
        UpdateCoords(entry)
        entry.mover.coords:Show()
        entry.mover:EnableKeyboard(true)
    end
end

local function Nudge(entry, dx, dy)
    local pos = entry.db.position
    SavePosition(entry, (pos.x or 0) + dx, (pos.y or 0) + dy, pos.point)
    UpdateCoords(entry)
end

local function ResetEntry(entry)
    if not entry.defaultPath then return end
    local def = HS.defaults
    for key in entry.defaultPath:gmatch("[^%.]+") do def = def and def[key] end
    if type(def) ~= "table" then return end
    SavePosition(entry, def.x or 0, def.y or 0, def.point)
    UpdateCoords(entry)
end

local function CreateMover(entry)
    local m = CreateFrame("Button", nil, UIParent)
    m:SetFrameStrata("DIALOG")
    m:SetFrameLevel(50)
    m:SetAllPoints(entry.frame)
    m:RegisterForDrag("LeftButton")
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local r, g, b = UI:Accent()
    UI:Surface(m, { color = { r, g, b, 0.16 }, border = { r, g, b, 0.55 } })

    m.label = UI:Text(m, { size = 11, flags = "OUTLINE", color = "text" })
    m.label:SetPoint("CENTER")
    m.label:SetText(entry.label)

    m.coords = UI:Text(m, { size = 10, color = "textDim" })
    m.coords:SetPoint("TOP", m, "BOTTOM", 0, -3)
    m.coords:Hide()

    m:SetScript("OnEnter", function(self)
        UI:SetSurfaceColor(self, { r, g, b, 0.28 })
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(entry.label, 1, 1, 1)
        GameTooltip:AddLine(L.DRAG_TO_MOVE_SHIFT_DRAG_IGNORES_THE_GRID, 0.75, 0.77, 0.8)
        GameTooltip:AddLine(L.ARROW_KEYS_NUDGE_1PX_SHIFT_10PX, 0.75, 0.77, 0.8)
        GameTooltip:AddLine(L.RIGHT_CLICK_TO_RESET, 0.75, 0.77, 0.8)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function(self)
        UI:SetSurfaceColor(self, { r, g, b, 0.16 })
        GameTooltip:Hide()
    end)
    m:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        Select(entry)
        entry.frame:StartMoving()
        m.moving = true
    end)
    m:SetScript("OnDragStop", function()
        if not m.moving then return end
        m.moving = false
        entry.frame:StopMovingOrSizing()
        -- Our saved variables own positions; keep the client's layout cache out of it.
        entry.frame:SetUserPlaced(false)
        local x, y = CenterOffset(entry.frame)
        SavePosition(entry, Snap(x, entry.frame), Snap(y, entry.frame))
        UpdateCoords(entry)
    end)
    m:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ResetEntry(entry)
        end
        Select(entry)
    end)
    m:SetScript("OnKeyDown", function(self, key)
        local step = IsShiftKeyDown() and 10 or 1
        local dx, dy = 0, 0
        if key == "UP" then dy = step
        elseif key == "DOWN" then dy = -step
        elseif key == "LEFT" then dx = -step
        elseif key == "RIGHT" then dx = step
        elseif key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            M:Stop(true)
            return
        end
        if dx ~= 0 or dy ~= 0 then
            self:SetPropagateKeyboardInput(false)
            Nudge(entry, dx, dy)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    entry.mover = m
    return m
end

function M:ShowMover(entry)
    if not EntryEnabled(entry) then
        if entry.mover then entry.mover:Hide() end
        return
    end
    local m = entry.mover or CreateMover(entry)
    local r, g, b = UI:Accent()
    UI:SetSurfaceColor(m, { r, g, b, 0.16 })
    UI:SetBorderColor(m, { r, g, b, 0.55 })
    m:Show()
end

---------------------------------------------------------------------------
-- Grid
---------------------------------------------------------------------------

local grid
local function BuildGrid()
    grid = grid or CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid.lines = grid.lines or {}
    for _, t in ipairs(grid.lines) do t:Hide() end

    local size = HS.db.appearance.gridSize or 16
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local px = UI.OnePixel(UIParent)
    local r, g, b = UI:Accent()
    local n = 0
    local function Line(vertical, offset, center)
        n = n + 1
        local t = grid.lines[n]
        if not t then
            t = grid:CreateTexture(nil, "BACKGROUND")
            grid.lines[n] = t
        end
        t:ClearAllPoints()
        if center then
            t:SetColorTexture(r, g, b, 0.55)
        else
            t:SetColorTexture(1, 1, 1, 0.07)
        end
        if vertical then
            t:SetPoint("TOP", grid, "TOP", offset, 0)
            t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
            t:SetWidth(px)
        else
            t:SetPoint("LEFT", grid, "LEFT", 0, offset)
            t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
            t:SetHeight(px)
        end
        t:Show()
    end
    for x = 0, w / 2, size do
        Line(true, x, x == 0)
        if x > 0 then Line(true, -x) end
    end
    for y = 0, h / 2, size do
        Line(false, y, y == 0)
        if y > 0 then Line(false, -y) end
    end
    grid.shade = grid.shade or grid:CreateTexture(nil, "BACKGROUND", nil, -8)
    grid.shade:SetAllPoints()
    grid.shade:SetColorTexture(0, 0, 0, 0.25)
end

function M:UpdateGrid()
    if self.active and HS.db.appearance.snapToGrid then
        BuildGrid()
        grid:Show()
    elseif grid then
        grid:Hide()
    end
end

---------------------------------------------------------------------------
-- Toolbar
---------------------------------------------------------------------------

local toolbar
local function BuildToolbar()
    if toolbar then return toolbar end
    local t = CreateFrame("Frame", "HunterSuiteEditToolbar", UIParent)
    t:SetSize(560, 64)
    t:SetPoint("TOP", 0, -36)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t:EnableMouse(true)
    t:SetMovable(true)
    t:RegisterForDrag("LeftButton")
    t:SetScript("OnDragStart", t.StartMoving)
    t:SetScript("OnDragStop", t.StopMovingOrSizing)
    t:SetClampedToScreen(true)
    UI:Surface(t, { radius = 12, color = "bg", shadow = true })

    local logo = t:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(34, 34)
    logo:SetPoint("LEFT", 14, 0)

    local title = UI:Text(t, { size = 14, color = "text" })
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
    title:SetText(L.EDIT_MODE)
    local sub = UI:Text(t, { size = 11, color = "textDim" })
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetWidth(250)
    sub:SetJustifyH("LEFT")
    sub:SetText(L.DRAG_FRAMES_ARROWS_NUDGE_RIGHT_CLICK_RESETS)

    local done = UI:Button(t, L.DONE, "primary", 70, 26)
    done:SetPoint("RIGHT", -14, 0)
    done:SetScript("OnClick", function() M:Stop(true) end)
    t.done = done

    local reset = UI:Button(t, L.RESET_ALL, "ghost", 76, 26)
    reset:SetPoint("RIGHT", done, "LEFT", -6, 0)
    reset:SetScript("OnClick", function()
        for _, entry in ipairs(M.entries) do ResetEntry(entry) end
    end)

    local gridBtn = UI:Button(t, "", "secondary", 64, 26)
    gridBtn:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    local function UpdateGridLabel()
        gridBtn:SetLabel(HS.db.appearance.snapToGrid and L.GRID_ON or L.GRID_OFF)
    end
    gridBtn:SetScript("OnClick", function()
        HS.db.appearance.snapToGrid = not HS.db.appearance.snapToGrid
        UpdateGridLabel()
        M:UpdateGrid()
    end)
    t.updateGridLabel = UpdateGridLabel

    toolbar = t
    return t
end

---------------------------------------------------------------------------
-- Enter / leave
---------------------------------------------------------------------------

function M:Start()
    if self.active then return end
    if InCombatLockdown() then
        HS:Print(L.EDIT_MODE_IS_NOT_AVAILABLE_IN_COMBAT)
        return
    end
    self.active = true
    HS.state = HS.state or {}
    HS.state.editMode = true
    HS:Fire("EDIT_MODE", true)
    for _, entry in ipairs(self.entries) do
        self:ShowMover(entry)
    end
    local tb = BuildToolbar()
    tb.updateGridLabel()
    tb.done:RefreshAccent()
    UI:FadeIn(tb, 0.2)
    self:UpdateGrid()
end

function M:Stop(save)
    if not self.active then return end
    self.active = false
    HS.state.editMode = false
    Select(nil)
    for _, entry in ipairs(self.entries) do
        if entry.mover then entry.mover:Hide() end
    end
    if toolbar then toolbar:Hide() end
    if grid then grid:Hide() end
    HS:Fire("EDIT_MODE", false)
end

function M:Toggle()
    if self.active then self:Stop(true) else self:Start() end
end

function M:IsActive()
    return self.active
end

HS:On("COMBAT_STARTED", function()
    if M.active then
        M:Stop(true)
        HS:Print(L.EDIT_MODE_CLOSED_YOU_ENTERED_COMBAT)
    end
end)

HS:On("MODULE_TOGGLED", function()
    if not M.active then return end
    for _, entry in ipairs(M.entries) do M:ShowMover(entry) end
end)
