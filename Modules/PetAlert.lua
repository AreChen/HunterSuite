--[[
    HunterSuite - missing / dead pet
    A small secure card: left-click Call Pet, right-click Revive Pet.
    Driven by a state driver, so it appears the moment your pet dies even
    in the middle of a fight.
]]

local _, HS = ...
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Alert = HS:NewModule("petAlert", { title = "Pet Missing", secure = true })

function Alert:IsSupported()
    return S.Known(S.CALL_PET)
end

function Alert:Build()
    local f = UI:Element("HunterSuitePetMissing", self.db, "Pet missing", "SecureActionButtonTemplate")
    f:RegisterForClicks("AnyUp", "AnyDown")
    f:SetSize(220, 44)
    UI:Surface(f, { radius = 6, color = "bg", border = { 1, 1, 1, 0.08 }, shadow = true })

    f.stripe = f:CreateTexture(nil, "ARTWORK")
    f.stripe:SetPoint("TOPLEFT", 4, -6)
    f.stripe:SetPoint("BOTTOMLEFT", 4, 6)
    f.stripe:SetWidth(3)
    f.stripe:SetTexture(UI.tex.white)

    f.iconFrame = UI:Icon(f, 28)
    f.iconFrame:SetPoint("LEFT", 14, 0)

    f.title = UI:Text(f, { size = 13, justify = "LEFT" })
    f.title:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", 10, 1)
    f.title:SetWidth(162)
    f.sub = UI:Text(f, { size = 11, color = "textDim", justify = "LEFT" })
    f.sub:SetPoint("BOTTOMLEFT", f.iconFrame, "BOTTOMRIGHT", 10, -1)
    f.sub:SetWidth(162)

    f:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 6)
        GameTooltip:AddLine(btn.title:GetText() or "Pet", 1, 1, 1)
        GameTooltip:AddDoubleLine("Left-click", S.Name(S.CALL_PET) or "Call Pet", 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine("Right-click", S.Name(S.REVIVE_PET) or "Revive Pet", 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Text follows the pet state; the frame itself only shows/hides via the driver.
    f:SetScript("OnShow", function() Alert:Paint() end)

    self.frame = f
    HS.Movers:Register(f, { label = "Pet missing", defaultPath = "petAlert.position", module = "petAlert" })
end

function Alert:Paint()
    local f = self.frame
    if not f then return end
    local dead = UnitExists("pet") and UnitIsDead("pet")
    local color = dead and "danger" or "warn"
    local r, g, b = UI:Color(color)
    f.stripe:SetVertexColor(r, g, b)
    UI:SetBorderColor(f, { r, g, b, 0.4 })
    if dead then
        f.title:SetText("Your pet is dead")
        f.sub:SetText("Right-click: " .. (S.Name(S.REVIVE_PET) or "Revive Pet"))
        f.iconFrame.icon:SetTexture(S.Icon(S.REVIVE_PET) or 132163)
    else
        f.title:SetText("No pet")
        f.sub:SetText("Left: call  |  Right: revive")
        f.iconFrame.icon:SetTexture(S.Icon(S.CALL_PET) or 132161)
    end
    f.title:SetTextColor(r * 0.35 + 0.65, g * 0.35 + 0.65, b * 0.35 + 0.65)
end

function Alert:ApplyActions()
    HS:RunOutOfCombat(function()
        local f = self.frame
        f:SetAttribute("*type1", "spell")
        f:SetAttribute("*spell1", S.Name(S.CALL_PET) or "Call Pet")
        f:SetAttribute("*type2", "spell")
        f:SetAttribute("*spell2", S.Name(S.REVIVE_PET) or "Revive Pet")
    end, "petalert-actions")
end

-- Only nag hunters who have had a pet, and never while mounted, on a
-- flight path or dead.
function Alert:UpdateVisibility()
    HS:RunOutOfCombat(function()
        local f = self.frame
        if not f then return end
        local rule
        if not self.enabled then
            rule = nil
        elseif HS.state.editMode then
            rule = "show"
        elseif not HS.char.hadPet or UnitOnTaxi("player") then
            rule = "hide"
        elseif self.db.bgOnly and not C.IsInPvP() then
            rule = "hide"
        else
            rule = "[mounted][@player,dead] hide; [@pet,dead] show; [nopet] show; hide"
        end
        if rule == self.rule then return end
        self.rule = rule
        if rule == nil then
            UnregisterStateDriver(f, "visibility")
            f:Hide()
        elseif rule == "show" then
            UnregisterStateDriver(f, "visibility")
            f:Show()
            self:Paint()
        else
            RegisterStateDriver(f, "visibility", rule)
        end
    end, "petalert-visibility")
end

function Alert:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
end

function Alert:OnEnable()
    local ev = self.events
    local function remember()
        if UnitExists("pet") and C.HasHunterPet() then HS.char.hadPet = true end
    end
    local function update()
        remember()
        self:UpdateVisibility()
        self:Paint()
    end
    ev:On("UNIT_PET", function(_, _, unit) if unit == "player" then update() end end)
    ev:On("UNIT_HEALTH", function() self:Paint() end, "pet")
    ev:On("PLAYER_ENTERING_WORLD", update)
    ev:On("ZONE_CHANGED_NEW_AREA", update)
    ev:On("PLAYER_CONTROL_LOST", update)
    ev:On("PLAYER_CONTROL_GAINED", update)
    ev:On("PLAYER_REGEN_ENABLED", update)
    self:ApplyActions()
    update()
end

function Alert:OnDisable()
    self.events:OffAll()
    self:UpdateVisibility()
end

function Alert:Refresh()
    UI:ApplyPosition(self.frame)
    self.rule = nil
    self:UpdateVisibility()
end

HS:On("EDIT_MODE", function()
    if Alert.enabled then
        Alert.rule = nil
        Alert:UpdateVisibility()
    end
end)
