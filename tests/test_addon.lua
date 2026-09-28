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
report(string.format("All %d Lua 5.1 behavior checks passed. Live rendering and client integration remain unverified.", count))
