--[[
    HunterSuite - auto-mark enemy pets
    Puts a skull on enemy hunter / warlock pets in battlegrounds. Forever
    makes raid markers secret during PvP matches (SetRaidTarget toggles, so
    marking blind would clear marks), which leaves this classic-client only.
]]

local _, HS = ...
local C = HS.Compat

local AutoMark = HS:NewModule("autoMark", { title = "Auto-Mark Enemy Pets" })

local SKULL = 8
local marked = {}

function AutoMark:IsSupported()
    return not HS.IS_FOREVER
end

function AutoMark:TryMark(unit)
    local db = self.db
    if db.pvpOnly and not C.IsInPvP() then return end
    if not UnitExists(unit) or not UnitIsOtherPlayersPet(unit) or not UnitCanAttack("player", unit) then return end
    if not C.CanMark() then return end
    local current = C.Readable(GetRaidTargetIndex(unit))
    local guid = C.Readable(UnitGUID(unit))
    if current == nil and C.IsSecret(GetRaidTargetIndex(unit)) then return end
    if current == SKULL or not guid then return end
    local last = marked[guid]
    if last and GetTime() - last < (db.throttle or 10) then return end
    SetRaidTarget(unit, SKULL)
    marked[guid] = GetTime()
end

function AutoMark:OnInitialize()
    self.events = HS:Events(self)
end

function AutoMark:OnEnable()
    local ev = self.events
    ev:On("NAME_PLATE_UNIT_ADDED", function(_, _, unit) self:TryMark(unit) end)
    ev:On("PLAYER_TARGET_CHANGED", function() self:TryMark("target") end)
    ev:On("UPDATE_MOUSEOVER_UNIT", function() self:TryMark("mouseover") end)
    ev:On("PLAYER_ENTERING_WORLD", function() wipe(marked) end)
end

function AutoMark:OnDisable()
    self.events:OffAll()
end
