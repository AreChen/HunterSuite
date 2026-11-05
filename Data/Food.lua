--[[
    HunterSuite - food table
    Item ID -> diet type and level. Only used on clients without
    C_PetInfo.CanPetEatItem (WoW Forever asks the game instead).
]]

local _, HunterSuite = ...

-- Food types: Meat, Fish, Cheese, Bread, Fungus, Fruit
-- Format: [itemID] = { type = "FoodType", level = itemLevel }

HunterSuite.FoodDB = {
    -- ============ MEAT ============
    -- Common Raw Meats
    [2672]  = { type = "Meat", level = 5 },   -- Stringy Wolf Meat
    [769]   = { type = "Meat", level = 5 },   -- Chunk of Boar Meat
    [2674]  = { type = "Meat", level = 5 },   -- Crawler Claw
    [723]   = { type = "Meat", level = 5 },   -- Goretusk Liver
    [1015]  = { type = "Meat", level = 10 },  -- Lean Wolf Flank
    [2673]  = { type = "Meat", level = 10 },  -- Coyote Meat
    [2677]  = { type = "Meat", level = 15 },  -- Boar Ribs
    [2675]  = { type = "Meat", level = 15 },  -- Crawler Meat
    [1080]  = { type = "Meat", level = 10 },  -- Tough Condor Meat
    [3173]  = { type = "Meat", level = 10 },  -- Bear Meat
    [3712]  = { type = "Meat", level = 15 },  -- Turtle Meat
    [3731]  = { type = "Meat", level = 20 },  -- Lion Meat
    [12202] = { type = "Meat", level = 25 },  -- Tiger Meat
    [12203] = { type = "Meat", level = 30 },  -- Red Wolf Meat
    [12204] = { type = "Meat", level = 35 },  -- Heavy Kodo Meat
    [12037] = { type = "Meat", level = 20 },  -- Mystery Meat
    [12184] = { type = "Meat", level = 25 },  -- Raptor Flesh
    [12223] = { type = "Meat", level = 35 },  -- Meaty Bat Wing
    [20424] = { type = "Meat", level = 45 },  -- Sandworm Meat
    [27674] = { type = "Meat", level = 55 },  -- Ravager Flesh
    [27677] = { type = "Meat", level = 60 },  -- Chunk o' Basilisk
    [27678] = { type = "Meat", level = 62 },  -- Clefthoof Meat
    [27681] = { type = "Meat", level = 65 },  -- Serpent Flesh
    [31670] = { type = "Meat", level = 65 },  -- Raptor Ribs
    [31671] = { type = "Meat", level = 68 },  -- Bat Flesh
    [35562] = { type = "Meat", level = 70 },  -- Bear Flank
    -- Spider Meats
    [2251]  = { type = "Meat", level = 5 },   -- Gooey Spider Leg
    [1081]  = { type = "Meat", level = 10 },  -- Crisp Spider Meat
    [12205] = { type = "Meat", level = 20 },  -- White Spider Meat
    [12206] = { type = "Meat", level = 35 },  -- Tender Crab Meat
    -- Scorpid/Buzzard Meats
    [3404]  = { type = "Meat", level = 20 },  -- Buzzard Wing
    [5467]  = { type = "Meat", level = 25 },  -- Kodo Meat
    [5468]  = { type = "Meat", level = 30 },  -- Soft Frenzy Flesh
    [5471]  = { type = "Meat", level = 35 },  -- Stag Meat
    [5472]  = { type = "Meat", level = 40 },  -- Scorpid Stinger
    -- Other Meats
    [3730]  = { type = "Meat", level = 15 },  -- Big Bear Meat
    [12208] = { type = "Meat", level = 40 },  -- Tender Wolf Meat
    
    -- Cooked Meats
    [2680]  = { type = "Meat", level = 5 },   -- Spiced Wolf Meat
    [2681]  = { type = "Meat", level = 10 },  -- Roasted Boar Meat
    [724]   = { type = "Meat", level = 15 },  -- Goretusk Liver Pie
    [1017]  = { type = "Meat", level = 20 },  -- Seasoned Wolf Kabob
    [3220]  = { type = "Meat", level = 25 },  -- Blood Sausage
    [3726]  = { type = "Meat", level = 25 },  -- Big Bear Steak
    [3727]  = { type = "Meat", level = 30 },  -- Hot Lion Chops
    [3728]  = { type = "Meat", level = 30 },  -- Tasty Lion Steak
    [12213] = { type = "Meat", level = 35 },  -- Carrion Surprise
    [12224] = { type = "Meat", level = 40 },  -- Roast Raptor
    [13851] = { type = "Meat", level = 45 },  -- Hot Wolf Ribs
    [18045] = { type = "Meat", level = 45 },  -- Tender Wolf Steak
    [27687] = { type = "Meat", level = 55 },  -- Roasted Clefthoof
    [30816] = { type = "Meat", level = 55 },  -- Grilled Mudfish
    [33867] = { type = "Meat", level = 65 },  -- Broiled Bloodfin
    [33872] = { type = "Meat", level = 70 },  -- Spicy Hot Talbuk
    
    -- ============ FISH ============
    -- Raw Fish
    [6291]  = { type = "Fish", level = 5 },   -- Raw Brilliant Smallfish
    [6303]  = { type = "Fish", level = 5 },   -- Raw Slitherskin Mackerel
    [6289]  = { type = "Fish", level = 10 },  -- Raw Longjaw Mud Snapper
    [6317]  = { type = "Fish", level = 15 },  -- Raw Loch Frenzy
    [6358]  = { type = "Fish", level = 15 },  -- Oily Blackmouth
    [6361]  = { type = "Fish", level = 20 },  -- Raw Rainbow Fin Albacore
    [6362]  = { type = "Fish", level = 25 },  -- Raw Rockscale Cod
    [8365]  = { type = "Fish", level = 30 },  -- Raw Mithril Head Trout
    [13754] = { type = "Fish", level = 35 },  -- Raw Glossy Mightfish
    [13755] = { type = "Fish", level = 40 },  -- Winter Squid
    [13756] = { type = "Fish", level = 40 },  -- Raw Summer Bass
    [13889] = { type = "Fish", level = 45 },  -- Raw Whitescale Salmon
    [27422] = { type = "Fish", level = 55 },  -- Barbed Gill Trout
    [27425] = { type = "Fish", level = 55 },  -- Spotted Feltail
    [27429] = { type = "Fish", level = 60 },  -- Zangarian Sporefish
    [27435] = { type = "Fish", level = 60 },  -- Figluster's Mudfish
    [27437] = { type = "Fish", level = 65 },  -- Icefin Bluefish
    [27438] = { type = "Fish", level = 65 },  -- Golden Darter
    [27439] = { type = "Fish", level = 70 },  -- Furious Crawdad
    
    -- Cooked Fish
    [5095]  = { type = "Fish", level = 5 },   -- Rainbow Fin Albacore
    [4592]  = { type = "Fish", level = 5 },   -- Longjaw Mud Snapper
    [4593]  = { type = "Fish", level = 10 },  -- Bristle Whisker Catfish
    [4594]  = { type = "Fish", level = 15 },  -- Rockscale Cod
    [6888]  = { type = "Fish", level = 20 },  -- Herb Baked Egg
    [8364]  = { type = "Fish", level = 30 },  -- Mithril Head Trout
    [13927] = { type = "Fish", level = 35 },  -- Cooked Glossy Mightfish
    [13928] = { type = "Fish", level = 40 },  -- Grilled Squid
    [13932] = { type = "Fish", level = 40 },  -- Poached Sunscale Salmon
    [13934] = { type = "Fish", level = 45 },  -- Filet of Redgill
    [27661] = { type = "Fish", level = 55 },  -- Blackened Trout
    [27664] = { type = "Fish", level = 55 },  -- Grilled Mudfish
    [27665] = { type = "Fish", level = 60 },  -- Poached Bluefish
    [27666] = { type = "Fish", level = 60 },  -- Golden Fish Sticks
    [27667] = { type = "Fish", level = 65 },  -- Spicy Crawdad
    
    -- ============ BREAD ============
    [4540]  = { type = "Bread", level = 5 },  -- Tough Hunk of Bread
    [4541]  = { type = "Bread", level = 15 }, -- Freshly Baked Bread
    [4542]  = { type = "Bread", level = 25 }, -- Moist Cornbread
    [4544]  = { type = "Bread", level = 35 }, -- Mulgore Spice Bread
    [4601]  = { type = "Bread", level = 45 }, -- Soft Banana Bread
    [8950]  = { type = "Bread", level = 45 }, -- Homemade Cherry Pie
    [27855] = { type = "Bread", level = 55 }, -- Mag'har Grainbread
    [29453] = { type = "Bread", level = 55 }, -- Sporeggar Mushroom
    [33449] = { type = "Bread", level = 65 }, -- Crusty Flatbread
    [35947] = { type = "Bread", level = 70 }, -- Sparkling Frostcap
    
    -- ============ CHEESE ============
    [414]   = { type = "Cheese", level = 5 },  -- Dalaran Sharp
    [422]   = { type = "Cheese", level = 15 }, -- Dwarven Mild
    [1707]  = { type = "Cheese", level = 25 }, -- Stormwind Brie
    [3927]  = { type = "Cheese", level = 35 }, -- Fine Aged Cheddar
    [8932]  = { type = "Cheese", level = 45 }, -- Alterac Swiss
    [27856] = { type = "Cheese", level = 55 }, -- Skethyl Berries
    [33443] = { type = "Cheese", level = 65 }, -- Soured Goat Cheese
    [35952] = { type = "Cheese", level = 70 }, -- Briny Hardcheese
    
    -- ============ FUNGUS ============
    [4604]  = { type = "Fungus", level = 5 },  -- Forest Mushroom Cap
    [4605]  = { type = "Fungus", level = 15 }, -- Red-Speckled Mushroom
    [4606]  = { type = "Fungus", level = 25 }, -- Spongy Morel
    [4607]  = { type = "Fungus", level = 35 }, -- Delicious Cave Mold
    [4608]  = { type = "Fungus", level = 45 }, -- Raw Black Truffle
    [27859] = { type = "Fungus", level = 55 }, -- Zangar Caps
    [35948] = { type = "Fungus", level = 65 }, -- Savory Snowplum
    
    -- ============ FRUIT ============
    [4536]  = { type = "Fruit", level = 5 },  -- Shiny Red Apple
    [4537]  = { type = "Fruit", level = 15 }, -- Tel'Abim Banana
    [4538]  = { type = "Fruit", level = 25 }, -- Snapvine Watermelon
    [4539]  = { type = "Fruit", level = 35 }, -- Goldenbark Apple
    [4602]  = { type = "Fruit", level = 45 }, -- Moon Harvest Pumpkin
    [27857] = { type = "Fruit", level = 55 }, -- Garadar Sharp
    [27858] = { type = "Fruit", level = 55 }, -- Sunspring Carp
    [35949] = { type = "Fruit", level = 65 }, -- Tundra Berries
    [35950] = { type = "Fruit", level = 70 }, -- Sweet Potato
    
    -- ============ CONJURED FOODS (all types) ============
    [5349]  = { type = "Bread", level = 5 },   -- Conjured Muffin
    [5350]  = { type = "Bread", level = 15 },  -- Conjured Bread
    [1113]  = { type = "Bread", level = 25 },  -- Conjured Pumpernickel
    [1114]  = { type = "Bread", level = 35 },  -- Conjured Sourdough
    [1487]  = { type = "Bread", level = 45 },  -- Conjured Sweet Roll
    [22895] = { type = "Bread", level = 55 },  -- Conjured Cinnamon Roll
    [34062] = { type = "Bread", level = 70 },  -- Conjured Mana Strudel
}
