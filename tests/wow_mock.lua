-- A small strict stand-in for the frame methods and game data used by this addon.
-- This verifies Lua behavior; it cannot replace a real WoW rendering/taint test.
local methods = {}
local function object(kind, name, parent)
    local value = setmetatable({ kind = kind, parent = parent, children = {}, scripts = {}, events = {}, shown = true, scale = 1 }, { __index = methods })
    if parent then table.insert(parent.children, value) end
    if name then _G[name] = value end
    return value
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event)
    if game and game.blockCombatRegistration and event == "COMBAT_LOG_EVENT_UNFILTERED" then error("restricted event") end
    self.events[event] = true
end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetShown(shown)
    local wasShown = self.shown
    self.shown = shown
    if wasShown and not shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale = scale end
function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetPoint(...) self.point = {...} end
function methods:ClearAllPoints() self.point = nil end
function methods:GetCenter() return self.centerX or 500, self.centerY or 300 end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:CreateFontString(name) return object("FontString", name, self) end
function methods:CreateTexture(name) return object("Texture", name, self) end
function methods:SetText(text) self.text = text end
function methods:SetMinMaxValues(low, high) self.low, self.high = low, high end
function methods:SetValue(value)
    assert(value >= self.low and value <= self.high)
    local changed = self.value ~= value
    self.value = value
    if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetBackdropBorderColor(...) self.borderColor = {...} end
function methods:SetStatusBarColor(...) self.barColor = {...} end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetThumbTexture() self.thumb = object("Texture", nil, self) end
function methods:GetThumbTexture() return self.thumb end
function methods:GetID() return 3 end
function methods:SetRightPaneCollapsed(value) self.collapsed = value end
for _, method in ipairs({"SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "SetBackdrop", "SetBackdropColor", "SetTextColor", "SetJustifyH", "SetWordWrap", "SetStatusBarTexture", "SetAllPoints", "SetShadowColor", "SetShadowOffset", "SetOwner", "AddDoubleLine", "AddLine", "SetOrientation", "SetValueStep", "SetObeyStepOnDrag"}) do
    methods[method] = function() end
end

function CreateFrame(kind, name, parent)
    local result = object(kind, name, parent)
    if not parent then Driver = result end
    return result
end
UIParent = object("Frame")
UIParent:SetSize(1920, 1080)
GameTooltip = object("Tooltip")
CharacterFrame = object("Frame")
PaperDollSidebarTabs = object("Frame")
PaperDollSidebarTab3 = object("Button")
SlashCmdList = {}
game = { exists = true, class = "HUNTER", name = "Wolf", level = 12, playerLevel = 15, current = 250, total = 1000, combat = false,
    guid = "Pet-1", happiness = 2, damage = 100, happinessCurrent = 500, happinessTotal = 1000 }
local secret = {}
game.secret = secret
function issecretvalue(value) return rawequal(value, secret) end
function UnitExists() return game.exists end
function UnitClass() return "Hunter", game.class end
function UnitName() return game.name end
function UnitLevel(unit) return unit == "pet" and game.level or game.playerLevel end
function UnitGUID() return game.guid end
function UnitCreatureFamily() return game.family or "Wolf" end
C_CreatureInfo = {}
function C_CreatureInfo.GetCreatureFamilyInfo(id)
    return game.familyInfo and game.familyInfo[id]
end
sounds, stoppedSounds = {}, {}
function PlaySoundFile(fileID, channel)
    assert((type(fileID) == "number" or type(fileID) == "string") and channel == "SFX")
    if game.soundError then error("unavailable sound") end
    if game.missingSound == fileID then return false end
    table.insert(sounds, { id = fileID, channel = channel })
    return true, #sounds
end
function StopSound(handle) table.insert(stoppedSounds, handle) end
Enum = { PowerType = { Happiness = 27 } }
C_PetInfo = {}
function C_PetInfo.GetPetHappiness()
    if game.happinessError then error("happiness unavailable") end
    return game.happiness, game.damage, 0
end
function UnitPower(_, powerType)
    assert(powerType == 27, "Must use Forever's advertised happiness power type")
    if game.powerError then error("restricted power") end
    return game.happinessCurrent
end
function UnitPowerMax(_, powerType)
    assert(powerType == 27)
    return game.happinessTotal
end
C_UnitAuras = {}
function C_UnitAuras.GetUnitAuraBySpellID(unit, spell)
    assert(unit == "pet" and spell == 1539)
    if game.auraError then error("restricted aura") end
    return game.aura
end
C_CombatLog = {}
function C_CombatLog.IsCombatLogRestricted() return game.logRestricted end
function C_CombatLog.GetCurrentEventInfo()
    if game.logError then error("restricted log") end
    return unpack(game.log or {})
end
function GetPetExperience()
    if game.xpError then error("API unavailable") end
    return game.current, game.total
end
function InCombatLockdown() return game.combat end
function HasPetUI() return game.exists end
function ToggleCharacter(tab, onlyShow) game.opened = tab; game.onlyShow = onlyShow end
function PaperDollFrame_SetSidebar(_, index) game.sidebar = index end
messages = {}
local realPrint = print
function print(message) table.insert(messages, message) end
function report(message) realPrint(message) end
function event(name, ...) Driver.scripts.OnEvent(Driver, name, ...) end
function command(text) SlashCmdList.FOREVERPETXP(text) end
function tick(elapsed) Driver.scripts.OnUpdate(Driver, elapsed or 1) end
function combatTick(amount, powerType, destination, kind)
    game.log = { 1, kind or "SPELL_PERIODIC_ENERGIZE", false, "Player-1", "Hunter", 0, 0,
        destination or game.guid, "Wolf", 0, 0, 1539, "Feed Pet Effect", 1, amount, 0, powerType or 27 }
    event("COMBAT_LOG_EVENT_UNFILTERED")
end
function reloadAddon()
    assert(loadstring(addonSource))("ForeverPetXP")
    event("ADDON_LOADED", "ForeverPetXP")
    view = ForeverPetXPFrame
    xpbar = ForeverPetXPExperienceBar
    xptext = xpbar.children[2]
    happybar = ForeverPetXPHappinessBar
    happytext = happybar.children[2]
    popup = ForeverPetXPPopup
end
