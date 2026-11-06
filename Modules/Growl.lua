--[[
    HunterSuite - Growl reminder
    In a dungeon or raid your pet's Growl (taunt) should be off; solo it
    should be on so the pet holds aggro. Reads the pet action bar autocast.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Growl = HS:NewModule("growl", { title = L.GROWL_REMINDER })

local growlIDs, growlNames

-- autocast state of the pet's taunt, or nil when the pet has none
function Growl:GetAutocast()
    if not C.HasHunterPet() then return nil end
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name, texture, _, _, _, autoCastEnabled, spellID = C.GetPetActionInfo(i)
        if name then
            local id = C.Readable(spellID)
            if (id and growlIDs[id]) or growlNames[name] then
                return autoCastEnabled and true or false, texture
            end
        end
    end
    return nil
end

function Growl:Evaluate()
    local db = self.db
    local autocast, icon = self:GetAutocast()
    local grouped = IsInGroup and IsInGroup() or (GetNumGroupMembers and GetNumGroupMembers() > 0)
    local inInstance = C.IsInGroupInstance()

    local wantOff
    if db.mode == "group" then
        wantOff = grouped or inInstance
    elseif db.mode == "instance" then
        wantOff = inInstance
    end

    if autocast == true and wantOff then
        HS.Alerts:Set("growl.on", {
            title = L.GROWL_IS_ON,
            text = L.YOUR_PET_WILL_TAUNT_OFF_THE_TANK,
            icon = icon or S.Icon(S.GROWL) or 132270,
            color = "warn", priority = 7,
            tooltip = L.GROWL_DISABLE_HINT,
        })
    else
        HS.Alerts:Clear("growl.on")
    end

    if autocast == false and not grouped and not inInstance and db.warnSoloOff then
        HS.Alerts:Set("growl.off", {
            title = L.GROWL_IS_OFF,
            text = L.YOUR_PET_WON_T_HOLD_AGGRO_WHILE_SOLO,
            icon = icon or S.Icon(S.GROWL) or 132270,
            color = "info", priority = 3,
            tooltip = L.GROWL_ENABLE_HINT,
        })
    else
        HS.Alerts:Clear("growl.off")
    end
end

function Growl:OnInitialize()
    growlIDs, growlNames = S.Sets(S.GROWL)
    self.events = HS:Events(self)
end

function Growl:OnEnable()
    local ev = self.events
    local function update() self:Evaluate() end
    ev:On("PET_BAR_UPDATE", update)
    ev:On("UNIT_PET", update)
    ev:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, update) end)
    ev:On("ZONE_CHANGED_NEW_AREA", update)
    ev:On("GROUP_ROSTER_UPDATE", update)
    update()
end

function Growl:OnDisable()
    self.events:OffAll()
    HS.Alerts:Clear("growl.on")
    HS.Alerts:Clear("growl.off")
end

function Growl:Refresh()
    self:Evaluate()
end
