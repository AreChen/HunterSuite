--[[
    HunterSuite - options schema
    Pages, sections and controls for the settings window, described as data.
    Paths point into the profile ("petBar.width"); a section with `module`
    gets an enable switch in its header.
]]

local _, HS = ...
local UI = HS.UI

local O = {}
HS.Options = O

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
local function secs(v) return ("%.1fs"):format(v) end
local function plain(v) return tostring(math.floor(v + 0.5)) end
local function scale(v) return ("%.2fx"):format(v) end

O.pages = {
    {
        key = "home", title = "Overview", icon = UI.tex.logo, home = true,
        desc = "Everything a Hunter needs, built for WoW Forever.",
    },
    {
        key = "pet", title = "Pet", icon = 132161,
        desc = "Your pet's mood, health and food in one card. Left-click feeds, right-click mends.",
        sections = {
            {
                title = "Pet card", module = "petBar", icon = 132165,
                items = {
                    { type = "select", path = "petBar.visibility", label = "Show the card",
                      values = { { "smart", "When your pet needs you" }, { "combat", "In combat" }, { "always", "Always" } },
                      desc = "Smart shows it in combat and whenever your pet is not happy or is hurt." },
                    { type = "segmented", path = "petBar.style", label = "Style",
                      values = { { "card", "Card" }, { "compact", "Compact" } } },
                    { type = "slider", path = "petBar.width", label = "Width", min = 180, max = 340, step = 2, format = plain },
                    { type = "select", path = "petBar.foodMode", label = "Food to use",
                      values = {
                          { "smart", "Smart: full happiness, cheapest first" },
                          { "lowest", "Lowest level" }, { "highest", "Highest level" },
                          { "leastStacked", "Smallest stack first" }, { "mostStacked", "Biggest stack first" },
                      },
                      desc = "The game tells HunterSuite what your pet can eat; food too far below your pet's level is skipped." },
                    { type = "slider", path = "petBar.mendThreshold", label = "Mend Pet warning below", min = 0.1, max = 0.9, step = 0.05, format = pct },
                    { type = "toggle", path = "petBar.showPortrait", label = "Portrait" },
                    { type = "toggle", path = "petBar.showHealthText", label = "Health text" },
                    { type = "toggle", path = "petBar.soundOnUnhappy", label = "Sound when your pet turns unhappy" },
                    { type = "info", text = "Key Bindings > AddOns > HunterSuite has Feed Pet and Mend Pet. Macro: /click HunterSuiteFeedButton" },
                },
            },
            {
                title = "Missing or dead pet", module = "petAlert", icon = 132163,
                items = {
                    { type = "toggle", path = "petAlert.bgOnly", label = "Only in battlegrounds" },
                    { type = "info", text = "Left-click calls your pet, right-click revives it. Hidden while mounted or on a flight path." },
                },
            },
        },
    },
    {
        key = "shot", title = "Auto Shot", icon = 132369,
        desc = "Swing timer driven by Forever's native swing events, with the aim window you must stand still for.",
        sections = {
            {
                title = "Auto Shot timer", module = "shotTimer", icon = 132369,
                items = {
                    { type = "slider", path = "shotTimer.width", label = "Width", min = 140, max = 420, step = 2, format = plain },
                    { type = "slider", path = "shotTimer.height", label = "Height", min = 8, max = 28, step = 1, format = plain },
                    { type = "slider", path = "shotTimer.aimTime", label = "Aim window", min = 0.3, max = 0.8, step = 0.05, format = secs,
                      desc = "Auto Shot has a 0.5s aim before each shot. Moving inside it delays the shot." },
                    { type = "toggle", path = "shotTimer.latency", label = "Add latency to the aim window" },
                    { type = "toggle", path = "shotTimer.showAimMarker", label = "Show the aim window" },
                    { type = "toggle", path = "shotTimer.showCastOverlay", label = "Project casts onto the bar",
                      desc = "Turns red when a cast runs into the aim window and will clip your shot." },
                    { type = "toggle", path = "shotTimer.showGCD", label = "Global cooldown line" },
                    { type = "toggle", path = "shotTimer.showDelay", label = "Show how late the last shot was" },
                    { type = "toggle", path = "shotTimer.flashOnShot", label = "Flash when a shot fires" },
                    { type = "toggle", path = "shotTimer.hideIdle", label = "Hide when not shooting" },
                    { type = "slider", path = "shotTimer.oocAlpha", label = "Opacity out of combat", min = 0, max = 1, step = 0.05, format = pct },
                },
            },
            {
                title = "Range and dead zone", module = "range", icon = 132222,
                items = {
                    { type = "segmented", path = "range.style", label = "Style",
                      values = { { "pill", "Pill" }, { "text", "Text" }, { "dot", "Dot" } } },
                    { type = "toggle", path = "range.attach", label = "Dock next to the Auto Shot bar" },
                    { type = "toggle", path = "range.showYards", label = "Show yards" },
                    { type = "toggle", path = "range.showNoTarget", label = "Show without a target" },
                },
            },
        },
    },
    {
        key = "reminders", title = "Reminders", icon = 136076,
        desc = "Alerts stack in one place. Move them with Edit Mode; right-click an alert to dismiss it.",
        sections = {
            {
                title = "Aspects", module = "aspects", icon = 136076,
                items = {
                    { type = "toggle", path = "aspects.onlyInCombat", label = "Only remind in combat" },
                    { type = "toggle", path = "aspects.warnMovementInCombat", label = "Warn when Cheetah or Pack is on in combat" },
                    { type = "slider", path = "aspects.snooze", label = "Snooze on right-click", min = 15, max = 600, step = 15, format = function(v) return v >= 60 and ("%dm %02ds"):format(v / 60, v % 60) or ("%ds"):format(v) end },
                },
            },
            {
                title = "Growl", module = "growl", icon = 132270,
                items = {
                    { type = "select", path = "growl.mode", label = "Warn when Growl is on",
                      values = { { "instance", "In dungeons and raids" }, { "group", "In any group" }, { "never", "Never" } } },
                    { type = "toggle", path = "growl.warnSoloOff", label = "Warn when Growl is off while solo" },
                },
            },
            {
                title = "Tracking", module = "tracking", icon = 135942,
                items = {
                    { type = "select", path = "tracking.mode", label = "Remind me",
                      values = { { "pvp", "Track Humanoids in battlegrounds" }, { "always", "Whenever no tracking is on" } } },
                },
            },
            {
                title = "Ammo", module = "ammo", icon = 132382,
                items = {
                    { type = "slider", path = "ammo.low", label = "Low ammo below", min = 100, max = 2000, step = 50, format = plain },
                    { type = "slider", path = "ammo.critical", label = "Critical below", min = 0, max = 600, step = 25, format = plain },
                    { type = "toggle", path = "ammo.alwaysShow", label = "Always show the counter" },
                    { type = "toggle", path = "ammo.sound", label = "Sound at critical" },
                },
            },
            {
                title = "Alert stack", icon = 132329,
                items = {
                    { type = "segmented", path = "alerts.grow", label = "Grow", values = { { "DOWN", "Down" }, { "UP", "Up" } } },
                    { type = "button", label = "Preview", text = "Show test alerts", action = function() HS.Alerts:Test() end },
                },
            },
        },
    },
    {
        key = "combat", title = "Traps & Stings", icon = 135834,
        desc = "Timers for traps you placed and stings on enemy nameplates.",
        sections = {
            {
                title = "Trap timers", module = "traps", icon = 135834,
                items = {
                    { type = "slider", path = "traps.duration", label = "Trap lifetime", min = 20, max = 120, step = 5, format = function(v) return ("%ds"):format(v) end },
                    { type = "slider", path = "traps.armTime", label = "Arming time", min = 0, max = 5, step = 0.5, format = secs },
                },
            },
            {
                title = "Sting timers", module = "stings", icon = 132204,
                items = {
                    { type = "slider", path = "stings.size", label = "Icon size", min = 14, max = 40, step = 1, format = plain },
                    { type = "slider", path = "stings.offsetY", label = "Height above nameplate", min = -10, max = 40, step = 1, format = plain },
                    { type = "toggle", path = "stings.showText", label = "Countdown text" },
                    { type = "toggle", path = "stings.showMark", label = "Include Hunter's Mark" },
                    { type = "info", text = "In combat Forever hides aura data from addons, so timers start from your casts." },
                },
            },
            {
                title = "Auto-mark enemy pets", module = "autoMark", icon = 137008,
                items = {
                    { type = "toggle", path = "autoMark.pvpOnly", label = "Only in battlegrounds and arenas" },
                },
            },
        },
    },
    {
        key = "weaving", title = "Weaving", icon = 132213, notOnForever = true,
        desc = "Steady Shot rotation guide for Burning Crusade clients.",
        sections = {
            {
                title = "Weaving bar", module = "weavingBar", icon = 132213,
                items = {
                    { type = "toggle", path = "weavingBar.weave", label = "Include melee weaving" },
                    { type = "slider", path = "weavingBar.window", label = "Seconds shown", min = 5, max = 20, step = 1, format = plain },
                    { type = "slider", path = "weavingBar.width", label = "Width", min = 250, max = 700, step = 10, format = plain },
                    { type = "toggle", path = "weavingBar.hideIdle", label = "Hide when not shooting" },
                },
            },
        },
    },
    {
        key = "appearance", title = "Appearance", icon = 134400,
        desc = "Look and feel for every HunterSuite frame.",
        sections = {
            {
                title = "Style", icon = 134400,
                items = {
                    { type = "accent", path = "appearance.accent", label = "Accent colour" },
                    { type = "select", path = "appearance.font", label = "Font", values = function() return UI:FontChoices() end,
                      desc = "Automatic uses a LibSharedMedia font (e.g. from EllesmereUI) when one is loaded." },
                    { type = "slider", path = "appearance.fontScale", label = "Text size", min = 0.8, max = 1.4, step = 0.05, format = scale },
                    { type = "select", path = "appearance.texture", label = "Bar texture", values = function() return UI:TextureChoices() end },
                    { type = "toggle", path = "appearance.shadows", label = "Soft shadows" },
                },
            },
            {
                title = "Layout", icon = 134520,
                items = {
                    { type = "slider", path = "appearance.scale", label = "HUD scale", min = 0.6, max = 1.6, step = 0.05, format = scale },
                    { type = "slider", path = "appearance.gridSize", label = "Edit mode grid", min = 4, max = 48, step = 2, format = plain },
                    { type = "toggle", path = "appearance.minimap.hide", label = "Hide minimap button" },
                    { type = "toggle", path = "appearance.sounds", label = "Play sounds" },
                    { type = "button", label = "Frames", text = "Open Edit Mode", action = function() HS:HideConfig(); HS.Movers:Start() end },
                },
            },
            {
                title = "Settings window", icon = 134331,
                items = {
                    { type = "slider", path = "appearance.configScale", label = "Window scale", min = 0.8, max = 1.4, step = 0.05, format = scale },
                    { type = "button", label = "Diagnostics", text = "Client report", action = function() HS:ShowDiagnostics() end },
                    { type = "button", label = "Reset", text = "Reset everything", style = "danger", action = function() StaticPopup_Show("HUNTERSUITE_RESET") end },
                },
            },
        },
    },
}

-- Short blurbs for the overview's module tiles.
O.moduleBlurbs = {
    petBar = { icon = 132165, text = "Mood, health and one-click feeding" },
    petAlert = { icon = 132163, text = "Call or revive a missing pet" },
    shotTimer = { icon = 132369, text = "Swing timer with aim window" },
    range = { icon = 132222, text = "Melee, dead zone, in range" },
    aspects = { icon = 136076, text = "No aspect / Cheetah in combat" },
    growl = { icon = 132270, text = "Taunt on in groups, off solo" },
    tracking = { icon = 135942, text = "Track Humanoids in battlegrounds" },
    ammo = { icon = 132382, text = "Counter and low-ammo warning" },
    traps = { icon = 135834, text = "Arming and lifetime timers" },
    stings = { icon = 132204, text = "Sting countdowns on nameplates" },
    autoMark = { icon = 137008, text = "Skull enemy pets in PvP", notOnForever = true },
    weavingBar = { icon = 132213, text = "Steady Shot rotation guide", notOnForever = true },
}

-- Pages and tiles for features Forever can never run are left out there.
function O.Visible(entry)
    return not (entry.notOnForever and HS.IS_FOREVER)
end

-- Why a module can't run on this character / client.
function O.UnsupportedReason(key)
    if key == "weavingBar" then
        return HS.IS_FOREVER and "Not on Forever (no Steady Shot)" or "Learn Steady Shot first"
    elseif key == "autoMark" then
        return "Raid marks are hidden in PvP on Forever"
    elseif key == "petAlert" then
        return "Learn Call Pet first (level 10)"
    elseif key == "aspects" then
        return "Learn an aspect first"
    elseif key == "tracking" then
        return "Learn a tracking ability first"
    elseif key == "traps" then
        return "Learn a trap first"
    end
    return "Not available"
end

-- What to call after a setting changes. Returns a function or nil.
function O.AfterChange(path)
    local root = path:match("^([^%.]+)")
    if root == "appearance" then
        return function()
            if path == "appearance.font" or path == "appearance.fontScale" then
                UI:RefreshFonts()
            elseif path == "appearance.texture" then
                UI:RefreshBarTextures()
            elseif path == "appearance.minimap.hide" then
                HS:UpdateMinimapButton()
            elseif path == "appearance.configScale" then
                HS:ApplyConfigScale()
            else
                HS:RefreshAll()
            end
        end
    end
    for _, mod in ipairs(HS.moduleOrder) do
        if mod.dbKey == root then
            if path == root .. ".enabled" then
                return function() HS:UpdateModuleState(mod); HS:Fire("MODULE_TOGGLED", mod.key, mod.enabled) end
            end
            return function()
                if mod.enabled then HS.SafeCall(mod, "Refresh") end
            end
        end
    end
    if root == "alerts" then
        return function() HS.Alerts:Layout() end
    end
end
