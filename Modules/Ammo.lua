--[[
    HunterSuite - ammo
    Ammo counter with low/critical warnings and a "minutes of shooting
    left" estimate. Hidden for thrown weapons and wands.
]]

local _, HS = ...
local UI, C = HS.UI, HS.Compat

local Ammo = HS:NewModule("ammo", { title = "Ammo" })

local AMMO_SLOT = _G.INVSLOT_AMMO or 0
local RANGED_SLOT = _G.INVSLOT_RANGED or 18
-- Weapon subclasses that fire ammo: bow, gun, crossbow.
local AMMO_WEAPONS = { [2] = true, [3] = true, [18] = true }
local lastSpeed = 3

function Ammo:NeedsAmmo()
    if UnitUsesAmmo then
        local uses = C.Readable(UnitUsesAmmo("player"))
        if uses ~= nil then return uses end
    end
    local itemID = GetInventoryItemID("player", RANGED_SLOT)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = C.GetItemInfoInstant(itemID)
    return classID == 2 and AMMO_WEAPONS[subclassID] == true
end

function Ammo:Build()
    local f = UI:Element("HunterSuiteAmmo", self.db, "Ammo")
    f:SetSize(150, 30)
    UI:Surface(f, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })
    f.iconFrame = UI:Icon(f, 20)
    f.iconFrame:SetPoint("LEFT", 6, 0)
    f.count = UI:Text(f, { size = 14 })
    f.count:SetPoint("LEFT", f.iconFrame, "RIGHT", 7, 1)
    f.sub = UI:Text(f, { size = 10, color = "textDim" })
    f.sub:SetPoint("LEFT", f.count, "RIGHT", 6, -1)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 6)
        local link = GetInventoryItemLink("player", AMMO_SLOT)
        GameTooltip:AddLine(link or "Ammo", 1, 1, 1)
        GameTooltip:AddLine(("Low below %d, critical below %d."):format(self.db.low, self.db.critical), 0.75, 0.77, 0.8)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    self.frame = f
    HS.Movers:Register(f, { label = "Ammo", defaultPath = "ammo.position", module = "ammo" })
end

function Ammo:Paint(count, level, minutes)
    local f = self.frame
    local color = level == "critical" and "danger" or level == "low" and "warn" or "text"
    local r, g, b = UI:Color(color)
    f.count:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(count) or count)
    f.count:SetTextColor(r, g, b)
    if level == "none" then
        f.count:SetText("No ammo")
        f.count:SetTextColor(UI:Color("danger"))
        f.sub:SetText("")
    elseif minutes then
        f.sub:SetText(minutes >= 1 and ("~%d min"):format(minutes) or "<1 min")
    else
        f.sub:SetText("")
    end
    f.iconFrame.icon:SetTexture(GetInventoryItemTexture("player", AMMO_SLOT) or 132382)
    UI:SetBorderColor(f, level == "ok" and { 1, 1, 1, 0.08 } or { r, g, b, 0.45 })
    UI:SetGlow(f, level == "critical" or level == "none", "danger")
    f:SetWidth(math.max(120, f.count:GetStringWidth() + f.sub:GetStringWidth() + 46))
end

function Ammo:Update()
    local f, db = self.frame, self.db
    if HS.state.editMode then return end
    if not self:NeedsAmmo() then
        f:Hide()
        return
    end
    -- Only the count is trusted: classic-engine clients may return no item ID
    -- or link for the ammo slot even with arrows equipped.
    local count = C.Readable(GetInventoryItemCount("player", AMMO_SLOT)) or 0
    if count <= 1 and not GetInventoryItemTexture("player", AMMO_SLOT) then
        count = 0 -- an empty slot can report 1
    end
    local speed = C.Readable(UnitRangedDamage("player"))
    if speed and speed > 0 then lastSpeed = speed end
    local minutes = count > 0 and math.floor(count * lastSpeed / 60) or nil

    local level
    if count == 0 then
        level = "none"
    elseif count <= db.critical then
        level = "critical"
    elseif count <= db.low then
        level = "low"
    else
        level = "ok"
    end

    if level == "ok" and not db.alwaysShow then
        f:Hide()
    else
        self:Paint(count, level, minutes)
        if not f:IsShown() then UI:FadeIn(f, 0.2) end
    end

    if (level == "critical" or level == "none") and self.lastLevel ~= level and self.lastLevel ~= nil and db.sound then
        C.PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    end
    self.lastLevel = level
end

function Ammo:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
end

function Ammo:OnEnable()
    local ev = self.events
    local pending = false
    local function update()
        if pending then return end
        pending = true
        C_Timer.After(0.3, function()
            pending = false
            if self.enabled then self:Update() end
        end)
    end
    ev:On("BAG_UPDATE_DELAYED", update)
    ev:On("PLAYER_EQUIPMENT_CHANGED", update)
    ev:On("UNIT_INVENTORY_CHANGED", update, "player")
    ev:On("UNIT_RANGEDDAMAGE", update, "player")
    ev:On("PLAYER_ENTERING_WORLD", update)
    UI:ApplyPosition(self.frame)
    self:Update()
end

function Ammo:OnDisable()
    self.events:OffAll()
    self.frame:Hide()
end

function Ammo:Refresh()
    UI:ApplyPosition(self.frame)
    self.lastLevel = nil
    self:Update()
end

HS:On("EDIT_MODE", function(on)
    if not Ammo.enabled then return end
    if on then
        Ammo:Paint(1240, "low", 62)
        Ammo.frame:SetAlpha(1)
        Ammo.frame:Show()
    else
        Ammo:Update()
    end
end)
