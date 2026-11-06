--[[
    HunterSuite - core
    Namespace, client detection, saved variables, module registry, events,
    out-of-combat queue and slash commands. Everything else hangs off `HS`.
]]

local ADDON, HS = ...
local L = HS.L
_G.HunterSuite = HS

HS.name = ADDON
HS.title = "HunterSuite"
HS.state = { editMode = false }

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
HS.version = GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "4.1.0"

-- Client detection. WoW Forever (game type "camelot") is the 12.x engine with
-- vanilla content and reports a 1.60+ toc, so the interface number is the one
-- signal that is the same on every Forever build.
local build, _, _, interface = GetBuildInfo()
HS.build = build
HS.interface = interface or 0
HS.IS_FOREVER = (HS.interface >= 16000 and HS.interface < 20000)
    or (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
HS.IS_ERA = HS.interface < 16000
HS.IS_TBC = HS.interface >= 20000 and HS.interface < 30000
HS.IS_CLASSIC_CONTENT = HS.interface < 30000
HS.clientName = HS.IS_FOREVER and L.WOW_FOREVER
    or HS.IS_TBC and L.BURNING_CRUSADE_CLASSIC
    or HS.IS_ERA and L.CLASSIC_ERA
    or L.UNSUPPORTED_CLIENT

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------

local PREFIX = "|cffabd473Hunter|r|cffe8eaedSuite|r|cff5c6370:|r "

function HS:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

function HS:Debug(fmt, ...)
    if self.db and self.db.debug then
        self:Print("|cff7f8590[debug]|r " .. fmt, ...)
    end
end

---------------------------------------------------------------------------
-- Small table helpers
---------------------------------------------------------------------------

local function CopyDefaults(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            CopyDefaults(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end
HS.CopyDefaults = CopyDefaults

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = DeepCopy(v) end
    return out
end
HS.DeepCopy = DeepCopy

-- Resolve "a.b.c" paths against the profile (used by the options schema).
function HS:GetPath(path)
    local node = self.db
    for key in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

function HS:SetPath(path, value)
    local node, last = self.db, nil
    local keys = {}
    for key in path:gmatch("[^%.]+") do keys[#keys + 1] = key end
    for i = 1, #keys - 1 do
        if type(node[keys[i]]) ~= "table" then node[keys[i]] = {} end
        node = node[keys[i]]
    end
    last = keys[#keys]
    node[last] = value
end

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------

HS.defaults = {
    debug = false,
    welcomed4 = false,
    appearance = {
        font = "auto",          -- "auto" picks a LibSharedMedia font if one is loaded
        fontScale = 1.0,
        scale = 1.0,            -- global scale applied to every HUD element
        accent = { r = 0.671, g = 0.831, b = 0.451 },   -- hunter class green
        texture = "smooth",     -- "smooth" (bundled), "flat", or a LibSharedMedia statusbar
        shadows = true,
        sounds = true,
        snapToGrid = true,
        gridSize = 16,
        minimap = { hide = false, angle = 215 },
        configScale = 1.0,
    },
    petBar = {
        enabled = true,
        visibility = "smart",   -- always | smart | combat
        style = "card",         -- card | compact
        width = 230,
        showPortrait = true,
        showHealthText = true,
        happyHideThreshold = 3, -- smart: hide while happiness >= this
        mendThreshold = 0.5,
        foodMode = "smart",     -- smart | lowest | highest | mostStacked | leastStacked
        soundOnUnhappy = true,
        position = { point = "CENTER", x = -250, y = -190 },
    },
    petAlert = {
        enabled = true,
        bgOnly = false,
        position = { point = "CENTER", x = 0, y = 160 },
    },
    shotTimer = {
        enabled = true,
        width = 260,
        height = 14,
        hideIdle = true,
        oocAlpha = 0.45,
        latency = true,
        aimTime = 0.5,
        showAimMarker = true,
        showCastOverlay = true,
        showGCD = true,
        showDelay = true,
        showLabel = true,
        flashOnShot = true,
        position = { point = "CENTER", x = 0, y = -200 },
    },
    range = {
        enabled = true,
        style = "pill",         -- pill | dot | text
        attach = true,          -- dock to the right of the Auto Shot bar
        showYards = true,
        showNoTarget = false,
        updateHz = 12,
        position = { point = "CENTER", x = 170, y = -200 },
    },
    alerts = {
        grow = "DOWN",
        position = { point = "TOP", x = 0, y = -160 },
    },
    aspects = {
        enabled = true,
        onlyInCombat = false,
        warnMovementInCombat = true,
        snooze = 60,
    },
    growl = {
        enabled = true,
        mode = "instance",      -- instance | group | never
        warnSoloOff = true,
    },
    tracking = {
        enabled = true,
        mode = "pvp",           -- pvp (Track Humanoids in BGs) | always (any tracking)
    },
    ammo = {
        enabled = true,
        low = 400,
        critical = 100,
        alwaysShow = false,
        sound = true,
        position = { point = "CENTER", x = 0, y = -228 },
    },
    traps = {
        enabled = true,
        duration = 60,
        armTime = 2,
        position = { point = "CENTER", x = -250, y = -250 },
    },
    stings = {
        enabled = true,
        size = 22,
        showMark = true,
        showText = true,
        offsetY = 6,
    },
    autoMark = {
        enabled = false,
        pvpOnly = true,
        throttle = 10,
    },
    weavingBar = {
        enabled = true,
        width = 400,
        height = 36,
        window = 10,
        weave = false,
        weaveTime = 0.3,
        hideIdle = true,
        oocAlpha = 0.45,
        position = { point = "CENTER", x = 0, y = -140 },
    },
}

HS.charDefaults = {
    hadPet = false,
}

---------------------------------------------------------------------------
-- Saved variables + migration from 3.x
---------------------------------------------------------------------------

local function MigrateFrom3(old)
    -- 3.x stored modules at the top level with different keys. Carry over the
    -- choices people made; positions are dropped because every frame changed size.
    local db = { profile = {} }
    local p = db.profile
    local function carry(fromKey, toKey, map)
        local src = old[fromKey]
        if type(src) ~= "table" then return end
        p[toKey] = p[toKey] or {}
        for from, to in pairs(map) do
            if src[from] ~= nil then p[toKey][to] = src[from] end
        end
    end
    carry("petFeed", "petBar", { enabled = "enabled" })
    carry("autoShot", "shotTimer", { enabled = "enabled", hideWhenInactive = "hideIdle", oocAlpha = "oocAlpha", latencyComp = "latency", showGCDBar = "showGCD", showDelayTimer = "showDelay" })
    carry("aspects", "aspects", { enabled = "enabled", onlyInCombat = "onlyInCombat" })
    carry("growl", "growl", { enabled = "enabled" })
    carry("traps", "traps", { enabled = "enabled", duration = "duration" })
    carry("range", "range", { enabled = "enabled" })
    carry("ammo", "ammo", { enabled = "enabled", sound = "sound" })
    carry("stings", "stings", { enabled = "enabled" })
    carry("petReminder", "petAlert", { enabled = "enabled", bgOnly = "bgOnly" })
    carry("autoMark", "autoMark", { enabled = "enabled", onlyInPVPInstances = "pvpOnly", throttleSeconds = "throttle" })
    carry("weavingBar", "weavingBar", { enabled = "enabled", enableWeaving = "weave", weaveTime = "weaveTime" })
    if type(old.minimap) == "table" then
        p.appearance = { minimap = { hide = old.minimap.hide, angle = old.minimap.position } }
    end
    return db
end

function HS:InitDB()
    local saved = _G.HunterSuiteDB
    if type(saved) ~= "table" then
        saved = {}
    elseif saved.schema == nil and (saved.petFeed or saved.autoShot) then
        saved = MigrateFrom3(saved)
        self.migratedFrom3 = true
    end
    saved.schema = 4
    saved.profile = CopyDefaults(self.defaults, saved.profile or {})
    _G.HunterSuiteDB = saved
    self.sv = saved
    self.db = saved.profile

    _G.HunterSuiteCharDB = CopyDefaults(self.charDefaults, _G.HunterSuiteCharDB or {})
    self.char = _G.HunterSuiteCharDB
end

function HS:ResetProfile()
    self.sv.profile = CopyDefaults(self.defaults, {})
    self.db = self.sv.profile
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Registering an event the client does not know raises an error on modern
-- clients, and Forever drops a few (e.g. the combat log for addons). Every
-- registration goes through here so a missing event never breaks a module.
local function SafeRegister(frame, event, ...)
    local ok
    if select("#", ...) > 0 and frame.RegisterUnitEvent then
        ok = pcall(frame.RegisterUnitEvent, frame, event, ...)
    else
        ok = pcall(frame.RegisterEvent, frame, event)
    end
    return ok
end
HS.SafeRegister = SafeRegister

-- Give `owner` an event frame. Handlers are methods on the owner named after
-- the event, or an explicit function passed to :On().
function HS:Events(owner)
    local frame = CreateFrame("Frame")
    local handlers = {}
    frame:SetScript("OnEvent", function(_, event, ...)
        local fn = handlers[event]
        if fn then fn(owner, event, ...) end
    end)
    local api = {}
    function api:On(event, fn, ...)
        handlers[event] = fn or owner[event]
        return SafeRegister(frame, event, ...)
    end
    function api:Off(event)
        handlers[event] = nil
        pcall(frame.UnregisterEvent, frame, event)
    end
    function api:OffAll()
        wipe(handlers)
        frame:UnregisterAllEvents()
    end
    api.frame = frame
    return api
end

---------------------------------------------------------------------------
-- Combat-safe execution
---------------------------------------------------------------------------

local combatQueue = {}

-- Run fn now if we are out of combat, otherwise as soon as combat ends.
-- `key` deduplicates repeated requests (e.g. re-anchoring the same frame).
function HS:RunOutOfCombat(fn, key)
    if not InCombatLockdown() then
        fn()
        return true
    end
    if key then
        combatQueue[key] = fn
    else
        combatQueue[#combatQueue + 1] = fn
    end
    return false
end

---------------------------------------------------------------------------
-- Callbacks (config changes, edit mode, pet state)
---------------------------------------------------------------------------

local callbacks = {}

function HS:On(message, fn)
    callbacks[message] = callbacks[message] or {}
    table.insert(callbacks[message], fn)
end

function HS:Fire(message, ...)
    local list = callbacks[message]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

HS.modules = {}
HS.moduleOrder = {}

local ModuleBase = {}

function ModuleBase:IsEnabled()
    return self.enabled == true
end

-- Override in a module when it only works with certain spells/clients.
function ModuleBase:IsSupported()
    return true
end

function HS:NewModule(key, info)
    local mod = setmetatable(info or {}, { __index = ModuleBase })
    mod.key = key
    mod.dbKey = mod.dbKey or key
    self.modules[key] = mod
    table.insert(self.moduleOrder, mod)
    return mod
end

function HS:GetModule(key)
    return self.modules[key]
end

local function SafeCall(mod, method, ...)
    local fn = mod[method]
    if not fn then return end
    local ok, err = pcall(fn, mod, ...)
    if not ok then
        geterrorhandler()(("HunterSuite %s:%s: %s"):format(mod.key, method, tostring(err)))
    end
end
HS.SafeCall = SafeCall

function HS:ModuleDB(mod)
    return self.db[mod.dbKey]
end

-- Enable or disable a module to match its setting and support. `refresh`
-- re-applies settings to a module that was already running (OnEnable
-- does that itself for a module that just started).
function HS:UpdateModuleState(mod, refresh)
    -- Modules that own secure buttons can't build, show or hide them in combat.
    if mod.secure and InCombatLockdown() then
        self:RunOutOfCombat(function() HS:UpdateModuleState(mod, refresh) end, "module-" .. mod.key)
        return
    end
    local db = self.db[mod.dbKey]
    local want = self.isHunter and db and db.enabled ~= false and mod:IsSupported()
    if want and not mod.enabled then
        if not mod.initialized then
            mod.db = db
            SafeCall(mod, "OnInitialize")
            mod.initialized = true
        end
        mod.db = db
        mod.enabled = true
        SafeCall(mod, "OnEnable")
    elseif not want and mod.enabled then
        mod.enabled = false
        SafeCall(mod, "OnDisable")
    elseif refresh and mod.enabled then
        SafeCall(mod, "Refresh")
    end
end

function HS:SetModuleEnabled(key, value)
    local mod = self.modules[key]
    if not mod then return end
    self.db[mod.dbKey].enabled = value and true or false
    self:UpdateModuleState(mod)
    self:Fire("MODULE_TOGGLED", key, mod.enabled)
end

-- Re-apply settings everywhere (after appearance changes, profile reset...).
function HS:RefreshAll()
    for _, mod in ipairs(self.moduleOrder) do
        mod.db = self.db[mod.dbKey]
        self:UpdateModuleState(mod, true)
    end
    self:Fire("REFRESH_ALL")
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local core = HS:Events(HS)

function HS:ADDON_LOADED(_, name)
    if name ~= ADDON then return end
    core:Off("ADDON_LOADED")
    self:InitDB()
end

function HS:PLAYER_LOGIN()
    local _, class = UnitClass("player")
    self.isHunter = class == "HUNTER"

    self:Fire("CORE_READY")

    if not self.isHunter then
        return
    end

    for _, mod in ipairs(self.moduleOrder) do
        self:UpdateModuleState(mod)
    end

    self:Fire("MODULES_READY")

    if self.migratedFrom3 then
        self:Print(L.UPDATE_LAYOUT_NOTICE, self.version)
        self.db.welcomed4 = true
    elseif not self.db.welcomed4 then
        self:Print(L.WELCOME_MESSAGE)
        self.db.welcomed4 = true
    end
end

-- Spells learned while levelling change what some modules can do (aspects,
-- tracking, Steady Shot...). Re-evaluate support, coalesced to one pass.
local spellsDirty = false
function HS:SPELLS_CHANGED()
    if not self.isHunter or spellsDirty then return end
    spellsDirty = true
    C_Timer.After(0.5, function()
        spellsDirty = false
        for _, mod in ipairs(HS.moduleOrder) do
            HS:UpdateModuleState(mod)
        end
        HS:Fire("SPELLS_UPDATED")
    end)
end

function HS:PLAYER_REGEN_ENABLED()
    -- Drain the out-of-combat queue.
    local pending = combatQueue
    combatQueue = {}
    for _, fn in pairs(pending) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
    self:Fire("COMBAT_ENDED")
end

function HS:PLAYER_REGEN_DISABLED()
    self:Fire("COMBAT_STARTED")
end

core:On("ADDON_LOADED")
core:On("PLAYER_LOGIN")
core:On("SPELLS_CHANGED")
core:On("PLAYER_REGEN_ENABLED")
core:On("PLAYER_REGEN_DISABLED")

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

HS.slashHelp = {
    { "", L.OPEN_SETTINGS },
    { "edit", L.MOVE_AND_RESIZE_FRAMES_EDIT_MODE },
    { "lock", L.LEAVE_EDIT_MODE },
    { "feed", L.SHOW_WHICH_FOOD_THE_PET_CARD_WILL_USE },
    { "diag", L.CLIENT_AND_API_REPORT_COPYABLE },
    { "reset", L.RESET_ALL_SETTINGS },
}

local function PrintHelp()
    HS:Print(L.COMMANDS)
    for _, entry in ipairs(HS.slashHelp) do
        print(("   |cffabd473/hs %s|r |cff9aa0a6%s|r"):format(entry[1], entry[2]))
    end
    print(L.FEED_MACRO_HELP)
end

SLASH_HUNTERSUITE1 = "/hs"
SLASH_HUNTERSUITE2 = "/huntersuite"
SlashCmdList.HUNTERSUITE = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")

    if not HS.db then return end

    if cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif not HS.isHunter and cmd ~= "diag" then
        HS:Print(L.HUNTER_ONLY_DIAG_NOTICE)
    elseif cmd == "" or cmd == "config" or cmd == "options" or cmd == "settings" then
        HS:ToggleConfig()
    elseif cmd == "edit" or cmd == "move" or cmd == "unlock" then
        HS.Movers:Toggle()
    elseif cmd == "lock" then
        HS.Movers:Stop(true)
    elseif cmd == "feed" then
        local pet = HS:GetModule("petBar")
        if pet and pet.enabled then
            pet:ReportFood()
        else
            HS:Print(L.THE_PET_CARD_IS_TURNED_OFF_HS_PET)
        end
    elseif cmd == "diag" or cmd == "debug" then
        HS:ShowDiagnostics()
    elseif cmd == "reset" then
        StaticPopup_Show("HUNTERSUITE_RESET")
    elseif cmd == "test" then
        if HS.Alerts then HS.Alerts:Test() end
    else
        PrintHelp()
    end
end

StaticPopupDialogs.HUNTERSUITE_RESET = {
    text = L.RESET_ALL_HUNTERSUITE_SETTINGS_AND_POSITIONS,
    button1 = YES or L.YES,
    button2 = NO or L.NO,
    OnAccept = function()
        HS:ResetProfile()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Keybinding labels (Bindings.xml).
BINDING_HEADER_HUNTERSUITE = "HunterSuite"
_G["BINDING_NAME_CLICK HunterSuiteFeedButton:LeftButton"] = L.FEED_PET_BEST_FOOD
_G["BINDING_NAME_CLICK HunterSuiteFeedButton:RightButton"] = L.MEND_PET
