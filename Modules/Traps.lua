--[[
    HunterSuite - trap timers
    One row per trap you have down: arming, then time left before it
    despawns. Placement comes from your own casts (readable in combat).
]]

local _, HS = ...
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Traps = HS:NewModule("traps", { title = "Trap Timers" })

local ROW_H, ROW_GAP, MAX_ROWS = 18, 4, 4
local placed = {}          -- key -> { name, icon, placedAt }
local trapByID, trapByName = {}, {}

function Traps:IsSupported()
    for _, trap in ipairs(S.TRAPS) do
        if S.Known(trap.place) then return true end
    end
    return false
end

function Traps:Build()
    local f = UI:Element("HunterSuiteTraps", self.db, "Traps")
    f:SetSize(200, ROW_H)
    f.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + ROW_GAP))
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * (ROW_H + ROW_GAP))
        row.iconFrame = UI:Icon(row, ROW_H)
        row.iconFrame:SetPoint("LEFT")
        row.bar = UI:Bar(row, { height = ROW_H - 2 })
        row.bar:SetPoint("LEFT", row.iconFrame, "RIGHT", 4, 0)
        row.bar:SetPoint("RIGHT")
        row.name = UI:Text(row.bar.bar, { size = 10, flags = "OUTLINE" })
        row.name:SetPoint("LEFT", 5, 0)
        row.time = UI:Text(row.bar.bar, { size = 10, flags = "OUTLINE" })
        row.time:SetPoint("RIGHT", -5, 0)
        row:Hide()
        f.rows[i] = row
    end
    f:SetScript("OnUpdate", function() Traps:Draw() end)
    f:Hide()
    self.frame = f
    HS.Movers:Register(f, { label = "Traps", defaultPath = "traps.position", module = "traps" })
end

local function SortedTraps()
    local list = {}
    for _, t in pairs(placed) do list[#list + 1] = t end
    table.sort(list, function(a, b) return a.placedAt > b.placedAt end)
    return list
end

function Traps:Draw()
    local f, db = self.frame, self.db
    local now = GetTime()
    local list
    if HS.state.editMode then
        list = {
            { name = S.Name(S.TRAPS[1].place) or "Freezing Trap", icon = S.Icon(S.TRAPS[1].place) or 135834, placedAt = now - 34 },
            { name = S.Name(S.TRAPS[3].place) or "Immolation Trap", icon = S.Icon(S.TRAPS[3].place) or 135813, placedAt = now - 1 },
        }
    else
        for key, t in pairs(placed) do
            if now - t.placedAt >= db.duration then placed[key] = nil end
        end
        list = SortedTraps()
        if #list == 0 then
            f:Hide()
            return
        end
    end

    for i, row in ipairs(f.rows) do
        local t = list[i]
        if t then
            local age = now - t.placedAt
            row.iconFrame.icon:SetTexture(t.icon)
            row.name:SetText(t.name)
            if age < db.armTime then
                row.bar:SetRange(0, db.armTime)
                row.bar:SetValueNow(age)
                row.bar:SetFillColor(UI:Color("warn"))
                row.time:SetText("arming")
            else
                local left = db.duration - age
                row.bar:SetRange(0, db.duration)
                row.bar:SetValueNow(left)
                if left <= 10 then
                    row.bar:SetFillColor(UI:Color("danger"))
                else
                    row.bar:SetFillColor(UI:Color("info"))
                end
                row.time:SetFormattedText("%d", math.ceil(left))
            end
            row:Show()
        else
            row:Hide()
        end
    end
    local n = math.min(#list, MAX_ROWS)
    f:SetHeight(math.max(ROW_H, n * ROW_H + (n - 1) * ROW_GAP))
end

function Traps:OnPlaced(spellID)
    local trap = trapByID[spellID]
    if not trap then
        local name = C.GetSpellName(spellID)
        trap = name and trapByName[name]
    end
    if not trap then return end
    placed[trap.key] = {
        name = S.Name(trap.place) or trap.key,
        icon = S.Icon(trap.place) or 136100,
        placedAt = GetTime(),
    }
    UI:StopTween(self.frame)
    self.frame:SetAlpha(1)
    self.frame:Show()
end

function Traps:OnInitialize()
    for _, trap in ipairs(S.TRAPS) do
        for _, id in ipairs(trap.place) do trapByID[id] = trap end
        local name = S.Name(trap.place)
        if name then trapByName[name] = trap end
    end
    self:Build()
    self.events = HS:Events(self)
end

function Traps:OnEnable()
    self.events:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, _, spellID)
        spellID = C.Readable(spellID)
        if spellID then self:OnPlaced(spellID) end
    end, "player")
    self.events:On("PLAYER_DEAD", function() wipe(placed) end)
    UI:ApplyPosition(self.frame)
end

function Traps:OnDisable()
    self.events:OffAll()
    wipe(placed)
    self.frame:Hide()
end

function Traps:Refresh()
    UI:ApplyPosition(self.frame)
end

HS:On("EDIT_MODE", function(on)
    if not Traps.enabled then return end
    if on then
        Traps.frame:SetAlpha(1)
        Traps.frame:Show()
    elseif not next(placed) then
        Traps.frame:Hide()
    end
end)
