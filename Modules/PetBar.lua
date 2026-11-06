--[[
    HunterSuite - pet card
    Portrait, happiness, health and the food it will use. Left-click feeds
    the best food in your bags, right-click casts Mend Pet. The card is a
    secure button, so visibility runs through a state driver that keeps
    working in combat.
]]

local _, HS = ...
local L = HS.L
local UI, C, S = HS.UI, HS.Compat, HS.Spells

local Pet = HS:NewModule("petBar", { title = L.PET_CARD_2, secure = true })

local HAPPINESS = {
    [1] = { label = L.UNHAPPY, color = "danger", damage = 75 },
    [2] = { label = L.CONTENT, color = "warn", damage = 100 },
    [3] = { label = L.HAPPY, color = "good", damage = 125 },
}
Pet.HAPPINESS = HAPPINESS

local Food = HS.Food
local FOOD_TYPE_LABELS = {
    L.FOOD_TYPE_MEAT, L.FOOD_TYPE_FISH, L.FOOD_TYPE_CHEESE, L.FOOD_TYPE_BREAD,
    L.FOOD_TYPE_FUNGUS, L.FOOD_TYPE_FRUIT, L.FOOD_TYPE_RAW_MEAT, L.FOOD_TYPE_RAW_FISH,
}

---------------------------------------------------------------------------
-- Food selection
---------------------------------------------------------------------------

-- Happiness gain falls off as food gets lower level than the pet.
local function FoodBand(petLevel, foodLevel)
    if not petLevel or not foodLevel then return 1 end
    local gap = petLevel - foodLevel
    if gap < 10 then return 3 end   -- full
    if gap < 20 then return 2 end   -- reduced
    if gap < 30 then return 1 end   -- low
    return 0                        -- refused
end
Pet.FoodBand = FoodBand
local BAND_LABEL = { [3] = L.FULL_HAPPINESS, [2] = L.REDUCED_HAPPINESS, [1] = L.LOW_HAPPINESS, [0] = L.TOO_LOW_LEVEL }

-- A pet eats food type t (Data/Food.lua) when bit t of its diet mask is set.
local function Eats(mask, foodType)
    return math.floor(mask / 2 ^ (foodType - 1)) % 2 == 1
end

-- Diet names for display, and the mask the food table is matched against.
-- The client gives the names in its own language; Data/Food.lua knows them all.
function Pet:GetDiet()
    local names, mask = C.GetPetFoodTypes(), 0
    for _, name in ipairs(names) do
        local t = Food.dietNames[name:lower()]
        if t and not Eats(mask, t) then mask = mask + 2 ^ (t - 1) end
    end
    if mask == 0 then
        local family, familyID = UnitCreatureFamily("pet")
        mask = Food.FamilyDiet(C.Readable(family), C.Readable(familyID))
        if #names == 0 then
            for t, name in ipairs(FOOD_TYPE_LABELS) do
                if Eats(mask, t) then names[#names + 1] = name end
            end
        end
    end
    return names, mask
end

-- Scan bags; returns the chosen food and the list of all candidates.
function Pet:FindFood()
    local petLevel = C.Readable(UnitLevel("pet"))
    local _, diet = self:GetDiet()
    -- Foods the game refused are remembered per pet.
    local who = C.Readable(UnitGUID("pet")) or C.Readable(UnitName("pet"))
    if who ~= self.refusedPet then
        self.refused, self.refusedPet = {}, who
    end
    local refused = self.refused
    local seen, list = {}, {}
    C.ForEachBagItem(function(bag, slot, itemID)
        -- Feed from the smallest stack of each food so partial stacks go first.
        local stack = C.GetContainerItemCount(bag, slot)
        local known = seen[itemID]
        if known then
            if known ~= true and stack < known.stack then
                known.bag, known.slot, known.stack = bag, slot, stack
            end
            return
        end
        seen[itemID] = true
        local edible = C.CanPetEat(itemID)
        local entry = Food.items[itemID]
        if edible == nil then
            edible = entry ~= nil and Eats(diet, entry[1])
        end
        if not edible or refused[itemID] then return end
        local name, _, _, itemLevel = C.GetItemInfo(itemID)
        itemLevel = itemLevel or (entry and entry[2])
        local band = FoodBand(petLevel, itemLevel)
        if band == 0 then return end
        local food = {
            itemID = itemID, name = name, level = itemLevel or 0, band = band,
            count = C.GetItemCount(itemID), icon = C.GetItemIcon(itemID),
            bag = bag, slot = slot, stack = stack,
        }
        seen[itemID] = food
        list[#list + 1] = food
    end)

    local mode = self.db.foodMode
    table.sort(list, function(a, b)
        if mode == "highest" then
            if a.level ~= b.level then return a.level > b.level end
        elseif mode == "lowest" then
            if a.level ~= b.level then return a.level < b.level end
        elseif mode == "mostStacked" then
            if a.count ~= b.count then return a.count > b.count end
        elseif mode == "leastStacked" then
            if a.count ~= b.count then return a.count < b.count end
        else -- smart: best happiness band, then the cheapest food in it, then use up small stacks
            if a.band ~= b.band then return a.band > b.band end
            if a.level ~= b.level then return a.level < b.level end
            if a.count ~= b.count then return a.count < b.count end
        end
        return a.itemID < b.itemID
    end)
    return list[1], list
end

---------------------------------------------------------------------------
-- Secure actions
---------------------------------------------------------------------------

-- Left click casts Feed Pet and the secure template then targets the food's
-- bag slot itself (target-bag / target-slot). No macro is involved, so the
-- button also works from /click inside a player's own macro.
function Pet:ApplyActions()
    HS:RunOutOfCombat(function()
        local food = self.food
        self.armedFood = food
        local feed = S.Name(S.FEED_PET) or L.FEED_PET
        local mend = S.Name(S.MEND_PET) or L.MEND_PET
        -- "*" so shift/ctrl/alt clicks and modified key bindings still match.
        for _, btn in ipairs({ self.card, self.feedButton }) do
            if btn then
                btn:SetAttribute("*type1", "spell")
                btn:SetAttribute("*spell1", feed)
                btn:SetAttribute("*target-bag1", food and food.bag or nil)
                btn:SetAttribute("*target-slot1", food and food.slot or nil)
                btn:SetAttribute("*type2", "spell")
                btn:SetAttribute("*spell2", mend)
            end
        end
    end, "petbar-actions")
end

function Pet:UpdateFood()
    if not UnitExists("pet") then
        self.food = nil
    else
        self.food = self:FindFood()
    end
    self:PaintFood()
    self:ApplyActions()
end

-- Prints the food choice (/hs feed).
function Pet:ReportFood()
    if not UnitExists("pet") then
        HS:Print(L.NO_PET_OUT)
        return
    end
    local food, list = self:FindFood()
    if not food then
        HS:Print(L.NO_FOOD_WITH_DIET, table.concat(self:GetDiet(), ", "))
        return
    end
    HS:Print(L.FEEDING_SELECTED_FOOD,
        food.name or L.ITEM_D:format(food.itemID), food.count, BAND_LABEL[food.band]:lower())
    if #list > 1 then
        local others = {}
        for i = 2, math.min(#list, 5) do others[#others + 1] = (list[i].name or list[i].itemID) .. " x" .. list[i].count end
        HS:Print(L.ALSO_EDIBLE_S, table.concat(others, ", "))
    end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local CARD_H = 48

function Pet:Build()
    local db = self.db
    local card = UI:Element("HunterSuitePetCard", db, L.PET, "SecureActionButtonTemplate")
    card:RegisterForClicks("AnyUp", "AnyDown")
    card:SetSize(db.width, CARD_H)
    UI:Surface(card, { radius = 6, color = "bg", border = { 1, 1, 1, 0.07 }, shadow = true })
    self.card = card

    -- Portrait with a happiness ring.
    local ring = card:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(UI.tex.circle)
    ring:SetSize(38, 38)
    ring:SetPoint("LEFT", 6, 0)
    card.ring = ring
    local portraitBg = card:CreateTexture(nil, "ARTWORK", nil, 2)
    portraitBg:SetTexture(UI.tex.circle)
    portraitBg:SetVertexColor(0.02, 0.02, 0.03, 1)
    portraitBg:SetSize(34, 34)
    portraitBg:SetPoint("CENTER", ring)
    local portrait = card:CreateTexture(nil, "ARTWORK", nil, 3)
    portrait:SetSize(32, 32)
    portrait:SetPoint("CENTER", ring)
    local mask = card:CreateMaskTexture()
    mask:SetTexture(UI.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    card.portrait = portrait

    -- Name / level and mood.
    -- Top row: name on the left, the food the card will use on the right.
    -- The 38px ring is centred in the 48px card, so its top/bottom sit 5px in.
    local food = card:CreateTexture(nil, "OVERLAY")
    food:SetSize(14, 14)
    food:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    food:SetPoint("TOPRIGHT", -8, -6)
    card.foodIcon = food
    card.foodText = UI:Text(card, { size = 10, color = "textDim" })
    card.foodText:SetPoint("RIGHT", food, "LEFT", -4, 0)

    card.name = UI:Text(card, { size = 12, color = "text" })
    card.name:SetPoint("TOPLEFT", ring, "TOPRIGHT", 8, -2)
    card.name:SetPoint("TOPRIGHT", card, "TOPRIGHT", -64, -7)
    card.name:SetJustifyH("LEFT")

    -- Bottom row: health bar carrying the mood (left) and health (right).
    local hp = UI:Bar(card, { height = 14 })
    hp:SetPoint("BOTTOMLEFT", ring, "BOTTOMRIGHT", 8, 4)
    hp:SetPoint("BOTTOMRIGHT", -8, 9)
    card.hp = hp
    card.mood = UI:Text(hp.bar, { size = 10, flags = "OUTLINE", color = "text" })
    card.mood:SetPoint("LEFT", 4, 0)
    card.hpText = UI:Text(hp.bar, { size = 10, flags = "OUTLINE", color = "text" })
    card.hpText:SetPoint("RIGHT", -4, 0)

    -- Feeding progress along the bottom edge.
    local feeding = UI:Bar(card, { height = 3, spark = false, border = false })
    feeding:SetPoint("BOTTOMLEFT", 6, 2)
    feeding:SetPoint("BOTTOMRIGHT", -6, 2)
    feeding:SetFillColor(UI:Color("info"))
    feeding:Hide()
    card.feeding = feeding

    card:SetScript("OnEnter", function(btn) Pet:ShowTooltip(btn) end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Keybinding / macro target with the same actions.
    -- /click sends only a release, so act on release (bindings send both).
    local fb = CreateFrame("Button", "HunterSuiteFeedButton", UIParent, "SecureActionButtonTemplate")
    fb:RegisterForClicks("AnyUp", "AnyDown")
    fb:SetAttribute("useOnKeyDown", false)
    fb:Hide()
    self.feedButton = fb

    HS.Movers:Register(card, { label = L.PET, defaultPath = "petBar.position", module = "petBar" })
end

function Pet:Layout()
    local card, db = self.card, self.db
    local compact = db.style == "compact"
    HS:RunOutOfCombat(function()
        card:SetSize(compact and 150 or db.width, CARD_H)
        UI:ApplyPosition(card)
    end, "petbar-layout")
    card.name:SetShown(not compact)
    card.foodText:SetShown(not compact)
    card.portrait:SetShown(db.showPortrait ~= false)
    card.hpText:SetShown(db.showHealthText ~= false)
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------

function Pet:PaintFood()
    local card = self.card
    if not card then return end
    local food = self.food
    if food then
        card.foodIcon:SetTexture(food.icon)
        card.foodIcon:SetDesaturated(false)
        card.foodIcon:Show()
        card.foodText:SetText(food.count)
        card.foodText:SetTextColor(UI:Color(food.count <= 5 and "warn" or "textDim"))
    elseif UnitExists("pet") then
        card.foodIcon:SetTexture(133971)
        card.foodIcon:SetDesaturated(true)
        card.foodIcon:Show()
        card.foodText:SetText(L.NO_FOOD)
        card.foodText:SetTextColor(UI:Color("danger"))
    else
        card.foodIcon:Hide()
        card.foodText:SetText("")
    end
end

function Pet:PaintIdentity()
    local card = self.card
    SetPortraitTexture(card.portrait, "pet")
    local name = UnitName("pet")
    local level = UnitLevel("pet")
    if C.IsSecret(name) or C.IsSecret(level) then
        card.name:SetText(name)
    else
        card.name:SetText(("%s |c%s%s|r"):format(name or L.PET, UI:Hex("textMute"), level or ""))
    end
end

function Pet:PaintHappiness()
    local card = self.card
    local happiness = C.GetPetHappiness()
    self.happiness = happiness
    local spec = HAPPINESS[happiness or 0]
    if spec then
        local r, g, b = UI:Color(spec.color)
        card.ring:SetVertexColor(r, g, b, 1)
        card.mood:SetText(("|T%s:8:8:0:0:64:64:0:64:0:64:%d:%d:%d|t %s"):format(UI.tex.circle, r * 255, g * 255, b * 255, spec.label))
    else
        card.ring:SetVertexColor(UI:Color("border"))
        card.mood:SetText("")
    end
    if happiness == 1 and self.lastHappiness and self.lastHappiness > 1 and self.db.soundOnUnhappy then
        C.PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    end
    self.lastHappiness = happiness
end

-- Pet health colour from a curve, evaluated in C so it works while health
-- is secret in combat.
local healthCurve
local function BuildHealthCurve(threshold)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor) then return nil end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        if Enum.LuaCurveType then c:SetType(Enum.LuaCurveType.Step) end
        local dr, dg, db = UI:Color("danger")
        local gr, gg, gb = UI:Color("good")
        c:AddPoint(0, CreateColor(dr, dg, db, 1))
        c:AddPoint(threshold, CreateColor(gr, gg, gb, 1))
        return c
    end)
    return ok and curve or nil
end

function Pet:PaintHealth()
    local card = self.card
    local hp, maxHP = UnitHealth("pet"), UnitHealthMax("pet")
    card.hp:SetRange(0, maxHP)
    card.hp:SetValueSmooth(hp)

    local frac = C.UnitHealthFraction("pet")
    local low = false
    if frac then
        low = frac < self.db.mendThreshold and not self.mending
        card.hp:SetFillColor(UI:Color(low and "danger" or "good"))
        card.hpText:SetFormattedText("%d%%", math.floor(frac * 100 + 0.5))
    else
        -- Secret health: let the client pick the colour and print the value.
        local colored = false
        if healthCurve then
            local ok, color = pcall(UnitHealthPercent, "pet", true, healthCurve)
            if ok and color and color.GetRGB then
                card.hp.bar:SetStatusBarColor(color:GetRGB())
                colored = true
            end
        end
        if not colored then card.hp:SetFillColor(UI:Color("good")) end
        card.hpText:SetText(hp)
    end
    self.lowHealth = low
    self:PaintAttention()
end

function Pet:PaintAuras()
    local card = self.card
    if C.AurasRestricted() then return end
    local feedIDs = S.Sets(S.FEED_PET_EFFECT)
    local mendIDs, mendNames = S.Sets(S.MEND_PET)
    local feed = C.FindAura("pet", "HELPFUL", feedIDs, { [S.Name(S.FEED_PET_EFFECT) or "Feed Pet Effect"] = true })
    local mend = C.FindAura("pet", "HELPFUL", mendIDs, mendNames)
    self.mending = mend ~= nil
    local duration, expiration = C.AuraTimes(feed)
    if duration and duration > 0 then
        card.feeding:SetRange(0, duration)
        card.feeding.expiration = expiration
        card.feeding:SetValueNow(expiration - GetTime())
        card.feeding:Show()
        card.feeding:SetScript("OnUpdate", function(bar)
            local left = bar.expiration - GetTime()
            if left <= 0 then
                bar:Hide()
                bar:SetScript("OnUpdate", nil)
            else
                bar.bar:SetValue(left)
            end
        end)
    else
        card.feeding:Hide()
        card.feeding:SetScript("OnUpdate", nil)
    end
end

function Pet:PaintAttention()
    local card = self.card
    local unhappy = self.happiness == 1
    if self.lowHealth then
        UI:SetGlow(card, true, "danger")
        UI:SetBorderColor(card, "danger", 0.6)
    elseif unhappy then
        UI:SetGlow(card, true, "warn")
        UI:SetBorderColor(card, "warn", 0.5)
    else
        UI:SetGlow(card, false)
        UI:SetBorderColor(card, { 1, 1, 1, 0.07 })
    end
end

function Pet:PaintAll()
    if not self.card then return end
    if not UnitExists("pet") then
        self:PaintFood()
        return
    end
    self:PaintIdentity()
    self:PaintHappiness()
    self:PaintAuras()
    self:PaintHealth()
    self:PaintFood()
end

---------------------------------------------------------------------------
-- Visibility (state driver so it works in combat)
---------------------------------------------------------------------------

function Pet:NeedsAttention()
    if (self.happiness or 3) < (self.db.happyHideThreshold or 3) then return true end
    if self.lowHealth then return true end
    return false
end

function Pet:UpdateVisibility()
    HS:RunOutOfCombat(function()
        local card = self.card
        if not card then return end
        if not self.enabled then
            UnregisterStateDriver(card, "visibility")
            card:Hide()
            return
        end
        if HS.state.editMode then
            UnregisterStateDriver(card, "visibility")
            card:Show()
            return
        end
        local mode = self.db.visibility
        local rule
        if mode == "always" then
            rule = "[nopet][@pet,dead] hide; show"
        elseif mode == "combat" then
            rule = "[nopet][@pet,dead] hide; [combat] show; hide"
        else
            rule = "[nopet][@pet,dead] hide; [combat] show; " .. (self:NeedsAttention() and "show" or "hide")
        end
        if rule ~= self.rule then
            self.rule = rule
            RegisterStateDriver(card, "visibility", rule)
        end
    end, "petbar-visibility")
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

function Pet:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP", 0, 6)
    if HS.state.editMode or not UnitExists("pet") then
        GameTooltip:AddLine(L.PET_CARD, 1, 1, 1)
        GameTooltip:AddLine(L.SHOWS_YOUR_PET_S_MOOD_HEALTH_AND_FOOD, 0.75, 0.77, 0.8, true)
        GameTooltip:Show()
        return
    end
    local name = C.Readable(UnitName("pet"))
    local family = UnitCreatureFamily("pet")
    GameTooltip:AddDoubleLine(name or L.PET, C.Readable(family) or "", 1, 1, 1, 0.6, 0.62, 0.66)
    local happiness, damage = C.GetPetHappiness()
    local spec = HAPPINESS[happiness or 0]
    if spec then
        local r, g, b = UI:Color(spec.color)
        GameTooltip:AddDoubleLine(L.MOOD, (L.S_D_DAMAGE):format(spec.label, damage or spec.damage), 0.75, 0.77, 0.8, r, g, b)
    end
    local loyalty = C.GetPetLoyalty()
    if loyalty then
        GameTooltip:AddDoubleLine(L.LOYALTY, loyalty, 0.75, 0.77, 0.8, 1, 1, 1)
    end
    local diet = self:GetDiet()
    if #diet > 0 then
        GameTooltip:AddDoubleLine(L.DIET, table.concat(diet, ", "), 0.75, 0.77, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    local food = self.food
    if food then
        local bandColor = food.band == 3 and "good" or food.band == 2 and "warn" or "danger"
        local r, g, b = UI:Color(bandColor)
        GameTooltip:AddDoubleLine(L.FOOD, ("%s x%d"):format(food.name or "?", food.count), 0.75, 0.77, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(" ", BAND_LABEL[food.band], 0.75, 0.77, 0.8, r, g, b)
    else
        GameTooltip:AddLine(L.NO_FOOD_YOUR_PET_WILL_EAT_IS_IN_YOUR_BAGS, 1, 0.45, 0.45, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.LEFT_CLICK, L.FEED_PET, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    GameTooltip:AddDoubleLine(L.RIGHT_CLICK, L.MEND_PET, 0.67, 0.83, 0.45, 0.9, 0.9, 0.9)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function Pet:OnInitialize()
    self:Build()
    self.events = HS:Events(self)
    self.refused = {}
    healthCurve = BuildHealthCurve(self.db.mendThreshold)
    -- Note what a left-click is about to feed, so a refusal can be pinned on it.
    local function noteFeed(_, button)
        if button == "LeftButton" then self.lastFeed = { food = self.armedFood, time = GetTime() } end
    end
    self.card:HookScript("PreClick", noteFeed)
    self.feedButton:HookScript("PreClick", noteFeed)
end

local function FullUpdate(self)
    self:PaintAll()
    self:UpdateFood()
    self:UpdateVisibility()
end

function Pet:OnEnable()
    local ev = self.events
    ev:On("UNIT_PET", function(_, _, unit) if unit == "player" then C_Timer.After(0.2, function() FullUpdate(self) end) end end)
    ev:On("PLAYER_ENTERING_WORLD", function() FullUpdate(self) end)
    ev:On("UNIT_HAPPINESS", function() self:PaintHappiness(); self:PaintAttention(); self:UpdateVisibility() end, "pet")
    ev:On("PET_UI_UPDATE", function() self:PaintHappiness(); self:PaintAttention() end)
    ev:On("UNIT_HEALTH", function() self:PaintHealth(); self:UpdateVisibility() end, "pet")
    ev:On("UNIT_MAXHEALTH", function() self:PaintHealth() end, "pet")
    ev:On("UNIT_AURA", function() self:PaintAuras(); self:PaintHealth() end, "pet")
    ev:On("UNIT_PORTRAIT_UPDATE", function() self:PaintIdentity() end, "pet")
    ev:On("UNIT_NAME_UPDATE", function() self:PaintIdentity() end, "pet")
    ev:On("UNIT_LEVEL", function() self:PaintIdentity(); self:UpdateFood() end, "pet")
    ev:On("LOCALPLAYER_PET_RENAMED", function() self:PaintIdentity() end)
    ev:On("BAG_UPDATE_DELAYED", function() self:UpdateFood() end)
    ev:On("GET_ITEM_INFO_RECEIVED", function()
        if not self.itemInfoPending then
            self.itemInfoPending = true
            C_Timer.After(0.5, function() self.itemInfoPending = false; self:UpdateFood() end)
        end
    end)
    ev:On("PLAYER_REGEN_ENABLED", function() FullUpdate(self) end)
    -- The game refusing a food (wrong diet, too low level) beats our table and
    -- level bands: skip that item for this pet and pick the next one.
    ev:On("UI_ERROR_MESSAGE", function(_, _, _, message)
        local last = self.lastFeed
        message = C.Readable(message)
        if not (last and last.food and message) or GetTime() - last.time > 3 then return end
        if message == _G.SPELL_FAILED_WRONG_PET_FOOD or message == _G.SPELL_FAILED_FOOD_LOWLEVEL then
            self.refused[last.food.itemID] = true
            self.lastFeed = nil
            self:UpdateFood()
        end
    end)
    self:Layout()
    FullUpdate(self)
end

function Pet:OnDisable()
    self.events:OffAll()
    self.rule = nil
    self:UpdateVisibility()
end

function Pet:Refresh()
    healthCurve = BuildHealthCurve(self.db.mendThreshold)
    self:Layout()
    self.rule = nil
    FullUpdate(self)
end

HS:On("EDIT_MODE", function(on)
    if not Pet.enabled then return end
    if on and not UnitExists("pet") then
        local card = Pet.card
        card.name:SetText(L.WOLF_CFF6B6F7860_R)
        card.portrait:SetTexture(132203)
        card.mood:SetText(L.HAPPY)
        card.ring:SetVertexColor(UI:Color("good"))
        card.hp:SetRange(0, 1)
        card.hp:SetValueNow(0.82)
        card.hpText:SetText("82%")
    end
    Pet.rule = nil
    Pet:UpdateVisibility()
end)
