--[[
    HunterSuite - minimap button and addon compartment entry
]]

local _, HS = ...
local UI, C = HS.UI, HS.Compat

local button

local function Tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("|cffabd473Hunter|rSuite", "v" .. HS.version, 1, 1, 1, 0.5, 0.52, 0.56)
    if HS.isHunter then
        if UnitExists("pet") then
            local happiness = C.GetPetHappiness()
            local spec = HS:GetModule("petBar").HAPPINESS[happiness or 0]
            local name = UnitName("pet")
            if spec and not C.IsSecret(name) then
                local r, g, b = UI:Color(spec.color)
                GameTooltip:AddDoubleLine(name or "Pet", spec.label, 0.85, 0.86, 0.88, r, g, b)
            end
        end
        local count = C.Readable(GetInventoryItemCount("player", INVSLOT_AMMO or 0))
        if count and count > 0 then
            GameTooltip:AddDoubleLine("Ammo", BreakUpLargeNumbers and BreakUpLargeNumbers(count) or count, 0.85, 0.86, 0.88, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left-click", "Settings", 0.67, 0.83, 0.45, 0.85, 0.86, 0.88)
    GameTooltip:AddDoubleLine("Right-click", "Edit layout", 0.67, 0.83, 0.45, 0.85, 0.86, 0.88)
    GameTooltip:AddDoubleLine("Drag", "Move this button", 0.67, 0.83, 0.45, 0.85, 0.86, 0.88)
    GameTooltip:Show()
end

local function OnClick(mouseButton)
    if mouseButton == "RightButton" then
        if HS.isHunter then HS.Movers:Toggle() end
    else
        if HS.isHunter then HS:ToggleConfig() else HS:Print("HunterSuite only runs on Hunters.") end
    end
end

local function UpdatePosition()
    local angle = math.rad(HS.db.appearance.minimap.angle or 215)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local radius = (Minimap:GetWidth() / 2) + 6
    if shape == "SQUARE" then
        -- push to the square's edge
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
        radius = (Minimap:GetWidth() / 2) - 2
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function Build()
    local b = CreateFrame("Button", "HunterSuiteMinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local shadow = b:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(UI.tex.circle)
    shadow:SetVertexColor(0, 0, 0, 0.55)
    shadow:SetSize(36, 36)
    shadow:SetPoint("CENTER", 0, -1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(UI.tex.logo)
    icon:SetAllPoints()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(UI.tex.circle)
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0.12)
    hl:SetBlendMode("ADD")

    b:SetScript("OnClick", function(_, mouseButton) OnClick(mouseButton) end)
    b:SetScript("OnEnter", Tooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            HS.db.appearance.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            UpdatePosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button = b
    UpdatePosition()
end

function HS:UpdateMinimapButton()
    if not button then
        if self.db.appearance.minimap.hide then return end
        Build()
    end
    button:SetShown(not self.db.appearance.minimap.hide)
    UpdatePosition()
end

HS:On("CORE_READY", function()
    if HS.isHunter then HS:UpdateMinimapButton() end
end)

-- Addon compartment (TOC AddonCompartmentFunc*).
function HunterSuite_OnAddonCompartmentClick(_, mouseButton)
    OnClick(mouseButton)
end

function HunterSuite_OnAddonCompartmentEnter(_, owner)
    Tooltip(owner)
end

function HunterSuite_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
