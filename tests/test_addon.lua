local count = 0
local function check(name, callback)
    callback()
    count = count + 1
    report("PASS " .. name)
end
local function has(text, part) assert(text and text:find(part, 1, true), tostring(text) .. " missing " .. part) end

reloadAddon()
check("correct XP and real event", function()
    assert(Driver.events.UNIT_PET_EXPERIENCE)
    assert(xpbar.value == 250 and xpbar.high == 1000)
    has(xptext.text, "25.0%")
    assert(not ForeverPetXPDB.locked)
end)
check("XP updates with the character sheet closed", function()
    CharacterFrame:Hide()
    game.current = 600
    event("UNIT_PET_EXPERIENCE", "pet")
    assert(xpbar.value == 600)
    has(xptext.text, "60.0%")
end)
check("pet level-up changes denominator", function()
    game.current, game.total, game.level = 0, 1500, 13
    event("UNIT_LEVEL", "pet")
    assert(xpbar.value == 0 and xpbar.high == 1500)
    has(view.children[2].text, "Lv 13")
end)
check("summon, dismiss, and locking", function()
    command("lock")
    game.exists = false
    event("UNIT_PET", "player")
    assert(not view:IsShown())
    game.exists = true
    event("UNIT_PET", "player")
    assert(view:IsShown())
    game.exists = false
    command("unlock")
    assert(view:IsShown())
    has(xptext.text, "Summon your pet")
    game.exists = true
end)
check("scaled drag position survives reload", function()
    command("scale 1.5")
    view.scripts.OnDragStart(view)
    assert(view.moving)
    view.centerX, view.centerY = 800, 400
    view.scripts.OnDragStop(view)
    assert(not view.moving)
    assert(math.abs(ForeverPetXPDB.x - 0.625) < 0.000001)
    local x, y = ForeverPetXPDB.x, ForeverPetXPDB.y
    command("lock")
    reloadAddon()
    assert(ForeverPetXPDB.locked and ForeverPetXPDB.scale == 1.5)
    assert(ForeverPetXPDB.x == x and ForeverPetXPDB.y == y)
    assert(view.point[4] == 800 and view.point[5] == 400)
    view.scripts.OnDragStart(view)
    assert(not view.moving)
end)
check("resolution changes retain proportional position", function()
    UIParent:SetSize(2560, 1440)
    event("DISPLAY_SIZE_CHANGED")
    assert(math.abs(view.point[4] - 2560 * ForeverPetXPDB.x / 1.5) < 0.000001)
end)
check("pet sheet shortcut uses Forever sidebar", function()
    view.scripts.OnMouseUp(view, "RightButton")
    assert(game.opened == "PaperDollFrame" and game.onlyShow == true and game.sidebar == 3)
    assert(CharacterFrame.collapsed == false)
end)
check("combat blocks pet sheet shortcut", function()
    game.combat, game.opened = true, nil
    command("pet")
    assert(game.opened == nil)
    has(messages[#messages], "after combat")
    game.combat = false
end)
check("same-level pet with no XP requirement", function()
    game.level, game.current, game.total = 15, 0, 0
    tick()
    has(xptext.text, "at your level")
    assert(xpbar.value == 1)
end)
check("same-level pet still displays valid XP", function()
    game.current, game.total = 500, 2000
    tick()
    has(xptext.text, "25.0%")
end)
check("zero requirement below owner level is not called max", function()
    game.level, game.current, game.total = 14, 0, 0
    tick()
    has(xptext.text, "No pet XP requirement")
    assert(xpbar.value == 0)
end)
check("missing, invalid, and secret XP do not crash or fake progress", function()
    for _, pair in ipairs({{false, 1000}, {0, -1}, {0/0, 1000}, {math.huge, 1000}, {game.secret, 1000}, {100, game.secret}}) do
        game.current, game.total = pair[1], pair[2]
        tick()
        has(xptext.text, "XP unavailable")
        assert(xpbar.value == 0)
    end
    game.current, game.total = nil, nil
    tick()
    has(xptext.text, "XP unavailable")
end)
check("API errors and missing function handled", function()
    game.xpError = true
    tick()
    has(xptext.text, "XP unavailable")
    game.xpError = false
    local api = GetPetExperience
    GetPetExperience = nil
    tick()
    has(xptext.text, "XP unavailable")
    GetPetExperience = api
end)
check("switching pets clears stale XP", function()
    game.name, game.level, game.current, game.total = "Cat", 10, 125, 500
    event("UNIT_PET", "player")
    assert(xpbar.value == 125)
    has(view.children[2].text, "Cat")
    has(xptext.text, "25.0%")
end)
check("fallback refresh catches delayed pet data", function()
    game.current = 300
    tick()
    assert(xpbar.value == 300)
end)
check("preview clearly labeled and does not persist", function()
    command("test")
    has(view.children[1].text, "PREVIEW")
    assert(xpbar.value == 1250)
    reloadAddon()
    assert(xpbar.value == 300)
    assert(view.children[1].text ~= "PREVIEW")
end)
check("hide persists and unlock recovers", function()
    command("hide")
    reloadAddon()
    assert(not view:IsShown())
    command("unlock")
    assert(view:IsShown())
end)
check("non-Hunter hidden when locked", function()
    game.class = "MAGE"
    command("lock")
    assert(not view:IsShown())
    game.class = "HUNTER"
end)
check("bad sizing inputs leave settings unchanged", function()
    local scale, width = ForeverPetXPDB.scale, ForeverPetXPDB.width
    command("scale 100")
    command("width nope")
    assert(ForeverPetXPDB.scale == scale and ForeverPetXPDB.width == width)
end)
check("corrupt saved settings recover", function()
    ForeverPetXPDB = { scale = 0, width = "bad", x = 0/0, y = math.huge, visible = "bad" }
    reloadAddon()
    assert(ForeverPetXPDB.scale == 0.6 and ForeverPetXPDB.width == 300)
    assert(ForeverPetXPDB.x == 0.5 and ForeverPetXPDB.y == 0.32)
    assert(ForeverPetXPDB.visible == true)
end)
check("reset restores accessible defaults", function()
    command("reset")
    assert(ForeverPetXPDB.scale == 1 and ForeverPetXPDB.width == 300)
    assert(ForeverPetXPDB.x == 0.5 and ForeverPetXPDB.y == 0.32)
    assert(not ForeverPetXPDB.locked and view:IsShown())
end)
check("happiness uses Forever API, updates all three moods and damage", function()
    assert(Driver.events.UNIT_HAPPINESS and Driver.events.UNIT_POWER_UPDATE)
    game.happinessCurrent = nil
    for mood = 1, 3 do
        game.happiness, game.damage = mood, 50 + 25 * mood
        event("UNIT_HAPPINESS", "pet")
        assert(happybar.value == mood and happybar.high == 3)
        has(happytext.text, ({"Unhappy", "Content", "Happy"})[mood])
        has(happytext.text, tostring(game.damage) .. "% damage")
    end
end)
check("exact happiness meter and real +59 gain, with no repeat", function()
    game.happinessCurrent, game.happinessTotal = 500, 1000
    tick()
    assert(happybar.value == 500 and happybar.high == 1000)
    assert(not popup:IsShown())
    game.happinessCurrent = 559
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(popup:IsShown() and popup.text == "+59 Happiness")
    tick(1.5)
    assert(popup.alpha > 0 and popup.alpha < 1)
    tick(1.1)
    assert(not popup:IsShown())
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(not popup:IsShown())
end)
check("unrelated power events and happiness losses do not pop", function()
    game.happinessCurrent = 600
    event("UNIT_POWER_UPDATE", "player", "HAPPINESS")
    event("UNIT_POWER_UPDATE", "pet", "FOCUS")
    event("UNIT_POWER_UPDATE", game.secret, "HAPPINESS")
    event("UNIT_POWER_UPDATE", "pet", game.secret)
    assert(not popup:IsShown())
    game.happinessCurrent = 530
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(not popup:IsShown())
end)
check("same-name pet swaps, dismissal and world changes never invent gains", function()
    game.guid, game.happinessCurrent = "Pet-2", 900
    event("UNIT_PET", "player")
    assert(not popup:IsShown() and happybar.value == 900)
    game.guid, game.happinessCurrent = "Pet-3", 950
    tick()
    assert(not popup:IsShown())
    game.exists = false
    event("UNIT_PET", "player")
    has(happytext.text, "No pet summoned")
    game.exists, game.happinessCurrent = true, 999
    event("UNIT_PET", "player")
    assert(not popup:IsShown())
    game.happinessCurrent = 1000
    event("PLAYER_ENTERING_WORLD")
    assert(not popup:IsShown())
end)
check("missing, invalid and secret happiness fall back without errors", function()
    game.happinessCurrent = game.secret
    for _, value in ipairs({false, 0, 4, 2.5, 0/0, math.huge, game.secret}) do
        game.happiness, game.damage = value, game.secret
        event("UNIT_HAPPINESS", "pet")
        has(happytext.text, "Happiness unavailable")
        assert(happybar.value == 0)
    end
    game.happiness, game.damage = 3, 125
    game.happinessError, game.powerError = true, true
    tick()
    has(happytext.text, "Happiness unavailable")
    game.happinessError, game.powerError = false, false
    tick()
    has(happytext.text, "Happy")
    assert(happybar.high == 3 and happybar.value == 3)
end)
check("missing modern happiness API supports legacy API or unavailable", function()
    local api = C_PetInfo.GetPetHappiness
    C_PetInfo.GetPetHappiness = nil
    tick()
    has(happytext.text, "Happiness unavailable")
    GetPetHappiness = function() return 1, 75 end
    tick()
    has(happytext.text, "Unhappy")
    GetPetHappiness, C_PetInfo.GetPetHappiness = nil, api
end)
check("feeding popup works with restricted amounts and expires", function()
    game.happinessCurrent = game.secret
    game.aura = { spellId = 1539 }
    event("UNIT_AURA", "pet")
    assert(popup:IsShown() and popup.text == "Feeding pet")
    tick(3)
    assert(not popup:IsShown())
    event("UNIT_AURA", "pet")
    assert(not popup:IsShown())
    game.aura = nil
    event("UNIT_AURA", "pet")
    event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6991)
    assert(popup:IsShown() and popup.text == "Feeding pet")
    tick(3)
end)
check("secret GUIDs and auras are never compared or used for gains", function()
    local guid = game.guid
    game.guid, game.aura = game.secret, game.secret
    game.happinessCurrent = 100
    tick()
    game.happinessCurrent = 200
    tick()
    assert(not popup:IsShown())
    game.aura = { spellId = 1539 }
    tick()
    has(popup.text, "Feeding pet")
    tick(3)
    assert(not popup:IsShown(), "Feeding notification must not repeat when GUID is restricted")
    game.guid, game.aura = guid, nil
    tick()
    assert(not popup:IsShown())
end)
check("combat log happiness fallback reads actual amounts and filters other events", function()
    game.happinessCurrent = game.secret
    tick()
    combatTick(59)
    assert(popup:IsShown() and popup.text == "+59 Happiness")
    tick(3)
    combatTick(120, 2)
    combatTick(120, 27, "Pet-somebody-else")
    combatTick(120, 27, game.guid, "SPELL_DAMAGE")
    combatTick(-5)
    combatTick(0)
    combatTick(game.secret)
    combatTick(59, game.secret)
    combatTick(59, 27, game.secret)
    combatTick(59, 27, game.guid, game.secret)
    assert(not popup:IsShown())
    combatTick(35, 27, game.guid, "SPELL_ENERGIZE")
    assert(popup:IsShown() and popup.text == "+35 Happiness")
    tick(3)
end)
check("restricted and unavailable combat APIs leave the meter working", function()
    game.logRestricted = true
    combatTick(59)
    game.logRestricted = game.secret
    combatTick(59)
    game.logRestricted, game.logError = false, true
    combatTick(59)
    game.logError = false
    local api = C_CombatLog.GetCurrentEventInfo
    C_CombatLog.GetCurrentEventInfo = nil
    combatTick(59)
    C_CombatLog.GetCurrentEventInfo = api
    assert(not popup:IsShown())
    game.blockCombatRegistration = true
    reloadAddon()
    assert(not Driver.events.COMBAT_LOG_EVENT_UNFILTERED)
    assert(Driver.events.UNIT_HAPPINESS)
    has(happytext.text, "Happy")
    game.blockCombatRegistration = false
end)
check("combat log excludes happiness lost to the cap", function()
    game.log = { 1, "SPELL_PERIODIC_ENERGIZE", false, "Player-1", "Hunter", 0, 0,
        game.guid, "Wolf", 0, 0, 1539, "Feed Pet Effect", 1, 59, 40, 27 }
    event("COMBAT_LOG_EVENT_UNFILTERED")
    assert(popup:IsShown() and popup.text == "+19 Happiness")
    tick(3)
    game.log[16] = 59
    event("COMBAT_LOG_EVENT_UNFILTERED")
    assert(not popup:IsShown())
    game.log[16] = game.secret
    event("COMBAT_LOG_EVENT_UNFILTERED")
    assert(not popup:IsShown())
end)
check("public power and combat log do not duplicate the same gain", function()
    game.happinessCurrent = 400
    tick()
    game.happinessCurrent = 459
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    tick(1.5)
    local faded = popup.alpha
    combatTick(59)
    assert(popup.text == "+59 Happiness" and popup.alpha == faded)
    tick(1.1)
    assert(not popup:IsShown())
    game.happinessCurrent = 518
    combatTick(59)
    assert(popup:IsShown() and popup.text == "+59 Happiness")
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    tick(3)
    assert(not popup:IsShown())
end)
check("feeding messages never overwrite an active numeric gain", function()
    game.happinessCurrent = 577
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    game.aura = { spellId = 1539 }
    event("UNIT_AURA", "pet")
    event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6991)
    assert(popup.text == "+59 Happiness")
    game.aura = nil
    tick(3)
end)
check("missing power enum never guesses old Classic power type", function()
    local powerType = Enum.PowerType.Happiness
    Enum.PowerType.Happiness = nil
    tick()
    assert(happybar.high == 3)
    combatTick(59, 4)
    assert(not popup:IsShown())
    Enum.PowerType.Happiness = powerType
    tick()
    assert(not popup:IsShown())
end)
check("color sliders change the live outline and survive locking and reload", function()
    ForeverPetXPColorButton.scripts.OnClick()
    assert(ForeverPetXPColors:IsShown())
    ForeverPetXPColorR:SetValue(0.1)
    ForeverPetXPColorG:SetValue(0.8)
    ForeverPetXPColorB:SetValue(0.4)
    assert(view.borderColor[1] == 0.1 and view.borderColor[2] == 0.8 and view.borderColor[3] == 0.4)
    command("lock")
    tick()
    assert(view.borderColor[2] == 0.8)
    reloadAddon()
    assert(ForeverPetXPDB.outlineR == 0.1 and ForeverPetXPDB.outlineG == 0.8 and ForeverPetXPDB.outlineB == 0.4)
    assert(view.borderColor[1] == 0.1 and view.borderColor[2] == 0.8)
    command("color")
    assert(ForeverPetXPColors:IsShown() and ForeverPetXPColorG.value == 0.8)
    command("color")
    assert(not ForeverPetXPColors:IsShown())
end)
check("X hides frame, color panel and popup and persists per character", function()
    command("unlock")
    command("color")
    game.happinessCurrent = 636
    tick()
    assert(popup:IsShown())
    ForeverPetXPClose.scripts.OnClick()
    assert(not view:IsShown() and not popup:IsShown() and not ForeverPetXPColors:IsShown())
    assert(not ForeverPetXPDB.visible)
    reloadAddon()
    assert(not view:IsShown())
    game.happinessCurrent = 695
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(not popup:IsShown())
    command("show")
    assert(view:IsShown() and not popup:IsShown())
end)
check("non-Hunters can click X and restore the placeholder", function()
    local hunterSettings = ForeverPetXPDB
    game.class, ForeverPetXPDB = "MAGE", nil
    reloadAddon()
    assert(view:IsShown())
    has(xptext.text, "X to hide")
    ForeverPetXPClose.scripts.OnClick()
    reloadAddon()
    assert(not view:IsShown())
    command("show")
    assert(view:IsShown())
    game.class, ForeverPetXPDB = "HUNTER", hunterSettings
    reloadAddon()
    assert(view:IsShown(), "Mage visibility must not alter Hunter settings")
end)
check("preview happiness and +59 are labeled and never treated as live", function()
    command("test")
    has(happytext.text, "Happy")
    has(popup.text, "+59 Happiness (preview)")
    local text = popup.text
    game.happinessCurrent = 900
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    combatTick(100)
    assert(popup.text == text)
    command("test")
    assert(not popup:IsShown() and happybar.value == 900)
    command("test")
    reloadAddon()
    assert(not popup:IsShown() and happybar.value == 900)
end)
check("old saves migrate color defaults and corrupt channels are sanitized", function()
    ForeverPetXPDB.outlineR, ForeverPetXPDB.outlineG, ForeverPetXPDB.outlineB = nil, nil, nil
    local x, scale = ForeverPetXPDB.x, ForeverPetXPDB.scale
    reloadAddon()
    assert(ForeverPetXPDB.outlineR == 0.6 and ForeverPetXPDB.outlineG == 0.45 and ForeverPetXPDB.outlineB == 0.85)
    assert(ForeverPetXPDB.x == x and ForeverPetXPDB.scale == scale)
    ForeverPetXPDB.outlineR, ForeverPetXPDB.outlineG, ForeverPetXPDB.outlineB = -10, 20, 0/0
    reloadAddon()
    assert(ForeverPetXPDB.outlineR == 0 and ForeverPetXPDB.outlineG == 1 and ForeverPetXPDB.outlineB == 0.85)
    command("color")
    command("reset")
    assert(view.borderColor[1] == 0.6 and view.borderColor[2] == 0.45 and view.borderColor[3] == 0.85)
    assert(not ForeverPetXPColors:IsShown())
end)
check("animal sounds only on rising moods; womp only when entering red", function()
    game.happiness, game.family = 1, "Wolf"
    event("UNIT_PET", "player")
    local count = #sounds
    tick()
    assert(#sounds == count, "No login/summon sound even if pet is red")
    game.happiness = 2
    event("UNIT_HAPPINESS", "pet")
    assert(#sounds == count + 1 and sounds[#sounds].id == 564223)
    event("UNIT_HAPPINESS", "pet")
    game.happinessCurrent = 959
    event("UNIT_POWER_UPDATE", "pet", "HAPPINESS")
    assert(#sounds == count + 1, "Repeated events and point gains must be silent")
    game.happiness = 3
    event("UNIT_HAPPINESS", "pet")
    assert(#sounds == count + 2 and sounds[#sounds].id == 564223)
    game.happiness = 2
    event("UNIT_HAPPINESS", "pet")
    assert(#sounds == count + 2, "Green to yellow must be silent")
    game.happiness = 1
    event("UNIT_HAPPINESS", "pet")
    assert(#sounds == count + 3)
    assert(sounds[#sounds].id == "Interface\\AddOns\\ForeverPetXP\\Sounds\\womp-womp.ogg")
    tick()
    event("UNIT_HAPPINESS", "pet")
    assert(#sounds == count + 3, "Red must not loop the womp")
end)
check("sound toggle disables both cues, stops playback and survives reload", function()
    command("sound")
    assert(not ForeverPetXPDB.sound)
    assert(#stoppedSounds > 0)
    local count = #sounds
    game.happiness = 2
    tick()
    game.happiness = 1
    tick()
    command("sound test")
    command("sound test red")
    assert(#sounds == count)
    reloadAddon()
    assert(not ForeverPetXPDB.sound)
    command("sound on")
    game.happiness = 2
    tick()
    assert(#sounds == count + 1)
    command("sound invalid")
    assert(ForeverPetXPDB.sound)
    command("sound off")
    assert(not ForeverPetXPDB.sound)
    command("sound on")
end)
check("sound matches animal families including localized names and generic fallback", function()
    game.family = "Cat"
    command("sound test")
    assert(sounds[#sounds].id == 562388)
    game.family = "Loup"
    game.familyInfo = { [1] = { name = "Loup", id = 1 } }
    command("sound test")
    assert(sounds[#sounds].id == 564223)
    game.family, game.familyInfo = "Owl", nil
    command("sound test")
    assert(sounds[#sounds].id == 557971)
    game.family = "Fox"
    command("sound test")
    assert(sounds[#sounds].id == 555465)
    game.family = "Unknown beta family"
    command("sound test")
    assert(sounds[#sounds].id == 567525)
    game.family = game.secret
    command("sound test")
    assert(sounds[#sounds].id == 567525)
    game.family = "Wolf"
    game.familyInfo = { [1] = game.secret }
    command("sound test")
    assert(sounds[#sounds].id == 564223)
    game.familyInfo = nil
end)
check("audio failures are harmless; unavailable animal clip uses eating fallback", function()
    game.missingSound = 564223
    command("sound test")
    assert(sounds[#sounds].id == 567525)
    game.missingSound, game.soundError = nil, true
    local count = #sounds
    command("sound test")
    assert(#sounds == count)
    has(messages[#messages], "could not play")
    game.soundError = false
    local api = PlaySoundFile
    PlaySoundFile = nil
    command("sound test")
    assert(#sounds == count)
    PlaySoundFile = api
    command("sound test red")
    has(sounds[#sounds].id, "womp-womp.ogg")
end)
check("swap, missing mood recovery, preview and hide never create mood sounds", function()
    local count = #sounds
    game.happiness, game.guid = 1, "Pet-audio-1"
    event("UNIT_PET", "player")
    game.happiness, game.guid = 3, "Pet-audio-2"
    event("UNIT_PET", "player")
    game.happiness = game.secret
    tick()
    game.happiness = 3
    tick()
    command("test")
    game.happiness = 1
    tick()
    command("test")
    command("hide")
    game.happiness = 3
    event("UNIT_HAPPINESS", "pet")
    command("show")
    reloadAddon()
    assert(#sounds == count)
end)
check("non-Hunters and no-pet characters cannot trigger sound previews", function()
    local count = #sounds
    game.class = "MAGE"
    command("sound test red")
    game.class, game.exists = "HUNTER", false
    command("sound test")
    game.exists = game.secret
    command("sound test red")
    assert(#sounds == count)
    game.exists = true
    tick()
end)
check("sound setting migrates safely and resets with other settings", function()
    ForeverPetXPDB.sound = nil
    reloadAddon()
    assert(ForeverPetXPDB.sound)
    ForeverPetXPDB.sound = "bad"
    reloadAddon()
    assert(ForeverPetXPDB.sound)
    command("sound off")
    command("reset")
    assert(ForeverPetXPDB.sound)
end)
report(string.format("All %d Lua 5.1 behavior checks passed. Live rendering and client integration remain unverified.", count))
