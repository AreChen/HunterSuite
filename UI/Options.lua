--[[
    HunterSuite - options schema
    Pages, sections and controls for the settings window, described as data.
    Paths point into the profile ("petBar.width"); a section with `module`
    gets an enable switch in its header.
]]

local _, HS = ...
local L = HS.L
local UI = HS.UI

local O = {}
HS.Options = O

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
local function secs(v) return L.SECONDS_DECIMAL:format(v) end
local function plain(v) return tostring(math.floor(v + 0.5)) end
local function scale(v) return ("%.2fx"):format(v) end

O.pages = {
    {
        key = "home", title = L.OVERVIEW, icon = UI.tex.logo, home = true,
        desc = L.ABOUT_FOREVER,
    },
    {
        key = "pet", title = L.PET, icon = 132161,
        desc = L.PET_CARD_DESCRIPTION,
        sections = {
            {
                title = L.PET_CARD, module = "petBar", icon = 132165,
                items = {
                    { type = "select", path = "petBar.visibility", label = L.SHOW_THE_CARD,
                      values = { { "smart", L.WHEN_YOUR_PET_NEEDS_YOU }, { "combat", L.IN_COMBAT }, { "always", L.ALWAYS } },
                      desc = L.PET_CARD_SMART_DESCRIPTION },
                    { type = "segmented", path = "petBar.style", label = L.STYLE,
                      values = { { "card", L.CARD }, { "compact", L.COMPACT } } },
                    { type = "slider", path = "petBar.width", label = L.WIDTH, min = 180, max = 340, step = 2, format = plain },
                    { type = "select", path = "petBar.foodMode", label = L.FOOD_TO_USE,
                      values = {
                          { "smart", L.SMART_FULL_HAPPINESS_CHEAPEST_FIRST },
                          { "lowest", L.LOWEST_LEVEL }, { "highest", L.HIGHEST_LEVEL },
                          { "leastStacked", L.SMALLEST_STACK_FIRST }, { "mostStacked", L.BIGGEST_STACK_FIRST },
                      },
                      desc = L.PET_FOOD_SELECTION_DESCRIPTION },
                    { type = "slider", path = "petBar.mendThreshold", label = L.MEND_PET_WARNING_BELOW, min = 0.1, max = 0.9, step = 0.05, format = pct },
                    { type = "toggle", path = "petBar.showPortrait", label = L.PORTRAIT },
                    { type = "toggle", path = "petBar.showHealthText", label = L.HEALTH_TEXT },
                    { type = "toggle", path = "petBar.soundOnUnhappy", label = L.SOUND_WHEN_YOUR_PET_TURNS_UNHAPPY },
                    { type = "info", text = L.PET_BINDINGS_HINT },
                },
            },
            {
                title = L.MISSING_OR_DEAD_PET, module = "petAlert", icon = 132163,
                items = {
                    { type = "toggle", path = "petAlert.bgOnly", label = L.ONLY_IN_BATTLEGROUNDS },
                    { type = "info", text = L.PET_MISSING_DESCRIPTION },
                },
            },
        },
    },
    {
        key = "shot", title = L.AUTO_SHOT, icon = 132369,
        desc = L.SHOT_TIMER_DESCRIPTION,
        sections = {
            {
                title = L.AUTO_SHOT_TIMER, module = "shotTimer", icon = 132369,
                items = {
                    { type = "slider", path = "shotTimer.width", label = L.WIDTH, min = 140, max = 420, step = 2, format = plain },
                    { type = "slider", path = "shotTimer.height", label = L.HEIGHT, min = 8, max = 28, step = 1, format = plain },
                    { type = "slider", path = "shotTimer.aimTime", label = L.AIM_WINDOW, min = 0.3, max = 0.8, step = 0.05, format = secs,
                      desc = L.SHOT_AIM_DESCRIPTION },
                    { type = "toggle", path = "shotTimer.latency", label = L.ADD_LATENCY_TO_THE_AIM_WINDOW },
                    { type = "toggle", path = "shotTimer.showAimMarker", label = L.SHOW_THE_AIM_WINDOW },
                    { type = "toggle", path = "shotTimer.showCastOverlay", label = L.PROJECT_CASTS_ONTO_THE_BAR,
                      desc = L.CAST_CLIP_DESCRIPTION },
                    { type = "toggle", path = "shotTimer.showGCD", label = L.GLOBAL_COOLDOWN_LINE },
                    { type = "toggle", path = "shotTimer.showDelay", label = L.SHOW_HOW_LATE_THE_LAST_SHOT_WAS },
                    { type = "toggle", path = "shotTimer.flashOnShot", label = L.FLASH_WHEN_A_SHOT_FIRES },
                    { type = "toggle", path = "shotTimer.hideIdle", label = L.HIDE_WHEN_NOT_SHOOTING },
                    { type = "slider", path = "shotTimer.oocAlpha", label = L.OPACITY_OUT_OF_COMBAT, min = 0, max = 1, step = 0.05, format = pct },
                },
            },
            {
                title = L.RANGE_AND_DEAD_ZONE, module = "range", icon = 132222,
                items = {
                    { type = "segmented", path = "range.style", label = L.STYLE,
                      values = { { "pill", L.PILL }, { "text", L.TEXT }, { "dot", L.DOT } } },
                    { type = "toggle", path = "range.attach", label = L.DOCK_NEXT_TO_THE_AUTO_SHOT_BAR },
                    { type = "toggle", path = "range.showYards", label = L.SHOW_YARDS },
                    { type = "toggle", path = "range.showNoTarget", label = L.SHOW_WITHOUT_A_TARGET },
                },
            },
        },
    },
    {
        key = "reminders", title = L.REMINDERS, icon = 136076,
        desc = L.ALERTS_DESCRIPTION,
        sections = {
            {
                title = L.ASPECTS, module = "aspects", icon = 136076,
                items = {
                    { type = "toggle", path = "aspects.onlyInCombat", label = L.ONLY_REMIND_IN_COMBAT },
                    { type = "toggle", path = "aspects.warnMovementInCombat", label = L.WARN_WHEN_CHEETAH_OR_PACK_IS_ON_IN_COMBAT },
                    { type = "slider", path = "aspects.snooze", label = L.SNOOZE_ON_RIGHT_CLICK, min = 15, max = 600, step = 15, format = function(v) return v >= 60 and L.MINUTES_SECONDS:format(v / 60, v % 60) or L.SECONDS_INTEGER:format(v) end },
                },
            },
            {
                title = L.GROWL, module = "growl", icon = 132270,
                items = {
                    { type = "select", path = "growl.mode", label = L.WARN_WHEN_GROWL_IS_ON,
                      values = { { "instance", L.IN_DUNGEONS_AND_RAIDS }, { "group", L.IN_ANY_GROUP }, { "never", L.NEVER } } },
                    { type = "toggle", path = "growl.warnSoloOff", label = L.WARN_WHEN_GROWL_IS_OFF_WHILE_SOLO },
                },
            },
            {
                title = L.TRACKING, module = "tracking", icon = 135942,
                items = {
                    { type = "select", path = "tracking.mode", label = L.REMIND_ME,
                      values = { { "pvp", L.TRACK_HUMANOIDS_IN_BATTLEGROUNDS }, { "always", L.WHENEVER_NO_TRACKING_IS_ON } } },
                },
            },
            {
                title = L.AMMO, module = "ammo", icon = 132382,
                items = {
                    { type = "slider", path = "ammo.low", label = L.LOW_AMMO_BELOW, min = 100, max = 2000, step = 50, format = plain },
                    { type = "slider", path = "ammo.critical", label = L.CRITICAL_BELOW, min = 0, max = 600, step = 25, format = plain },
                    { type = "toggle", path = "ammo.alwaysShow", label = L.ALWAYS_SHOW_THE_COUNTER },
                    { type = "toggle", path = "ammo.sound", label = L.SOUND_AT_CRITICAL },
                },
            },
            {
                title = L.ALERT_STACK, icon = 132329,
                items = {
                    { type = "segmented", path = "alerts.grow", label = L.GROW, values = { { "DOWN", L.DOWN }, { "UP", L.UP } } },
                    { type = "button", label = L.PREVIEW, text = L.SHOW_TEST_ALERTS, action = function() HS.Alerts:Test() end },
                },
            },
        },
    },
    {
        key = "combat", title = L.TRAPS_STINGS, icon = 135834,
        desc = L.TRAPS_STINGS_DESCRIPTION,
        sections = {
            {
                title = L.TRAP_TIMERS, module = "traps", icon = 135834,
                items = {
                    { type = "slider", path = "traps.duration", label = L.TRAP_LIFETIME, min = 20, max = 120, step = 5, format = function(v) return L.SECONDS_INTEGER:format(v) end },
                    { type = "slider", path = "traps.armTime", label = L.ARMING_TIME, min = 0, max = 5, step = 0.5, format = secs },
                },
            },
            {
                title = L.STING_TIMERS, module = "stings", icon = 132204,
                items = {
                    { type = "slider", path = "stings.size", label = L.ICON_SIZE, min = 14, max = 40, step = 1, format = plain },
                    { type = "slider", path = "stings.offsetY", label = L.HEIGHT_ABOVE_NAMEPLATE, min = -10, max = 40, step = 1, format = plain },
                    { type = "toggle", path = "stings.showText", label = L.COUNTDOWN_TEXT },
                    { type = "toggle", path = "stings.showMark", label = L.INCLUDE_HUNTER_S_MARK },
                    { type = "info", text = L.FOREVER_AURA_TIMERS_DESCRIPTION },
                },
            },
            {
                title = L.AUTO_MARK_ENEMY_PETS, module = "autoMark", icon = 137008,
                items = {
                    { type = "toggle", path = "autoMark.pvpOnly", label = L.ONLY_IN_BATTLEGROUNDS_AND_ARENAS },
                },
            },
        },
    },
    {
        key = "weaving", title = L.WEAVING, icon = 132213, notOnForever = true,
        desc = L.WEAVING_DESCRIPTION,
        sections = {
            {
                title = L.WEAVING_BAR, module = "weavingBar", icon = 132213,
                items = {
                    { type = "toggle", path = "weavingBar.weave", label = L.INCLUDE_MELEE_WEAVING },
                    { type = "slider", path = "weavingBar.window", label = L.SECONDS_SHOWN, min = 5, max = 20, step = 1, format = plain },
                    { type = "slider", path = "weavingBar.width", label = L.WIDTH, min = 250, max = 700, step = 10, format = plain },
                    { type = "toggle", path = "weavingBar.hideIdle", label = L.HIDE_WHEN_NOT_SHOOTING },
                },
            },
        },
    },
    {
        key = "appearance", title = L.APPEARANCE, icon = 134400,
        desc = L.LOOK_AND_FEEL_FOR_EVERY_HUNTERSUITE_FRAME,
        sections = {
            {
                title = L.STYLE, icon = 134400,
                items = {
                    { type = "accent", path = "appearance.accent", label = L.ACCENT_COLOUR },
                    { type = "select", path = "appearance.font", label = L.FONT, values = function() return UI:FontChoices() end,
                      desc = L.AUTO_FONT_DESCRIPTION },
                    { type = "slider", path = "appearance.fontScale", label = L.TEXT_SIZE, min = 0.8, max = 1.4, step = 0.05, format = scale },
                    { type = "select", path = "appearance.texture", label = L.BAR_TEXTURE, values = function() return UI:TextureChoices() end },
                    { type = "toggle", path = "appearance.shadows", label = L.SOFT_SHADOWS },
                },
            },
            {
                title = L.LAYOUT, icon = 134520,
                items = {
                    { type = "slider", path = "appearance.scale", label = L.HUD_SCALE, min = 0.6, max = 1.6, step = 0.05, format = scale },
                    { type = "slider", path = "appearance.gridSize", label = L.EDIT_MODE_GRID, min = 4, max = 48, step = 2, format = plain },
                    { type = "toggle", path = "appearance.minimap.hide", label = L.HIDE_MINIMAP_BUTTON },
                    { type = "toggle", path = "appearance.sounds", label = L.PLAY_SOUNDS },
                    { type = "button", label = L.FRAMES, text = L.OPEN_EDIT_MODE, action = function() HS:HideConfig(); HS.Movers:Start() end },
                },
            },
            {
                title = L.SETTINGS_WINDOW, icon = 134331,
                items = {
                    { type = "slider", path = "appearance.configScale", label = L.WINDOW_SCALE, min = 0.8, max = 1.4, step = 0.05, format = scale },
                    { type = "button", label = L.DIAGNOSTICS, text = L.CLIENT_REPORT, action = function() HS:ShowDiagnostics() end },
                    { type = "button", label = L.RESET, text = L.RESET_EVERYTHING, style = "danger", action = function() StaticPopup_Show("HUNTERSUITE_RESET") end },
                },
            },
        },
    },
}

-- Short blurbs for the overview's module tiles.
O.moduleBlurbs = {
    petBar = { icon = 132165, text = L.MOOD_HEALTH_AND_ONE_CLICK_FEEDING },
    petAlert = { icon = 132163, text = L.CALL_OR_REVIVE_A_MISSING_PET },
    shotTimer = { icon = 132369, text = L.SWING_TIMER_WITH_AIM_WINDOW },
    range = { icon = 132222, text = L.MELEE_DEAD_ZONE_IN_RANGE },
    aspects = { icon = 136076, text = L.NO_ASPECT_CHEETAH_IN_COMBAT },
    growl = { icon = 132270, text = L.TAUNT_ON_IN_GROUPS_OFF_SOLO },
    tracking = { icon = 135942, text = L.TRACK_HUMANOIDS_IN_BATTLEGROUNDS },
    ammo = { icon = 132382, text = L.COUNTER_AND_LOW_AMMO_WARNING },
    traps = { icon = 135834, text = L.ARMING_AND_LIFETIME_TIMERS },
    stings = { icon = 132204, text = L.STING_COUNTDOWNS_ON_NAMEPLATES },
    autoMark = { icon = 137008, text = L.SKULL_ENEMY_PETS_IN_PVP, notOnForever = true },
    weavingBar = { icon = 132213, text = L.STEADY_SHOT_ROTATION_GUIDE, notOnForever = true },
}

-- Pages and tiles for features Forever can never run are left out there.
function O.Visible(entry)
    return not (entry.notOnForever and HS.IS_FOREVER)
end

-- Why a module can't run on this character / client.
function O.UnsupportedReason(key)
    if key == "weavingBar" then
        return HS.IS_FOREVER and L.NOT_ON_FOREVER_NO_STEADY_SHOT or L.LEARN_STEADY_SHOT_FIRST
    elseif key == "autoMark" then
        return L.RAID_MARKS_ARE_HIDDEN_IN_PVP_ON_FOREVER
    elseif key == "petAlert" then
        return L.LEARN_CALL_PET_FIRST_LEVEL_10
    elseif key == "aspects" then
        return L.LEARN_AN_ASPECT_FIRST
    elseif key == "tracking" then
        return L.LEARN_A_TRACKING_ABILITY_FIRST
    elseif key == "traps" then
        return L.LEARN_A_TRAP_FIRST
    end
    return L.NOT_AVAILABLE
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
