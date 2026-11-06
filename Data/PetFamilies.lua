-- Creature family IDs are language-independent. Reuse the generated diet
-- masks instead of duplicating diet data or comparing translated names.
local _, HS = ...
local Food, C = HS.Food, HS.Compat

local familyKeys = {
    [1] = "Wolf", [2] = "Cat", [3] = "Spider", [4] = "Bear", [5] = "Boar",
    [6] = "Crocolisk", [7] = "Carrion Bird", [8] = "Crab", [9] = "Gorilla",
    [11] = "Raptor", [12] = "Tallstrider", [20] = "Scorpid", [21] = "Turtle",
    [24] = "Bat", [25] = "Hyena", [26] = "Owl", [27] = "Wind Serpent",
    [30] = "Dragonhawk", [31] = "Ravager", [32] = "Warp Stalker",
    [33] = "Sporebat", [34] = "Nether Ray", [35] = "Serpent",
}

function Food.FamilyDiet(family, familyID)
    local key = familyID and familyKeys[familyID]
    if key then return Food.familyMasks[key] or 0 end
    if not family then return 0 end
    if Food.familyMasks[family] then return Food.familyMasks[family] end

    -- Some clients return only the name, but can resolve IDs to local names.
    if C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo then
        for id, english in pairs(familyKeys) do
            local ok, info = pcall(C_CreatureInfo.GetCreatureFamilyInfo, id)
            local name = ok and info and C.Readable(info.name)
            if name then Food.familyMasks[name] = Food.familyMasks[english] end
        end
    end
    return Food.familyMasks[family] or 0
end
