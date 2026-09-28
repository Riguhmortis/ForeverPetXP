local ADDON = ...
local defaults = { locked = false, visible = true, width = 300, scale = 1, x = 0.5, y = 0.32 }
local db, frame, bar, title, hint, label
local preview, dragging, hovering = false, false, false
local state = {}

local function Say(text)
    print("|cffba9bffForever Pet XP:|r " .. text)
end

local function IsPublic(value)
    return not (issecretvalue and issecretvalue(value))
end

local function IsNumber(value)
    return IsPublic(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function Number(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(math.floor(value))
end

local function ReadState()
    if preview then
        return { name = "Preview pet", level = 18, current = 1250, total = 5000, status = "xp" }
    end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then
        return { status = "class" }
    end
    local exists = UnitExists("pet")
    if not IsPublic(exists) then return { status = "unavailable" } end
    if not exists then return { status = "absent" } end

    local name, level = UnitName("pet"), UnitLevel("pet")
    local data = {
        name = IsPublic(name) and name or "Pet",
        level = IsNumber(level) and level > 0 and level or nil,
        status = "unavailable",
    }
    -- Forever 1.60.1's PetExpBarMixin uses this function and UNIT_PET_EXPERIENCE.
    -- Read the game's data directly; do not move or hook Blizzard's own bar.
    if type(GetPetExperience) ~= "function" then return data end
    local ok, current, total = pcall(GetPetExperience)
    if not ok or not IsNumber(current) or not IsNumber(total) or current < 0 or total < 0 then
        return data
    end
    if total > 0 then
        data.current, data.total, data.status = Clamp(current, 0, total), total, "xp"
    else
        local playerLevel = UnitLevel("player")
        if data.level and IsNumber(playerLevel) and data.level >= playerLevel then
            data.status = "atlevel"
        else
            data.status = "noxp"
        end
    end
    return data
end

local function ShowTooltip()
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText("Forever Pet XP", 0.73, 0.61, 1)
    if state.status == "xp" then
        GameTooltip:AddDoubleLine("Pet experience", Number(state.current) .. " / " .. Number(state.total), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("To next pet level", Number(state.total - state.current), 1, 1, 1, 0.75, 0.65, 1)
        GameTooltip:AddLine(preview and "Preview only: these are sample values." or "Uses the same XP data as Character > Pet.", 0.75, 0.75, 0.75)
    elseif state.status == "atlevel" then
        GameTooltip:AddLine("Your pet has reached your level.", 0.55, 1, 0.65)
    elseif state.status == "unavailable" then
        GameTooltip:AddLine("The game is not exposing readable pet XP right now.", 1, 0.8, 0.4, true)
    elseif state.status == "noxp" then
        GameTooltip:AddLine("The game reports no XP requirement for this pet.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(db.locked and "Position locked. /petxp unlock to move." or "Left-drag to move. /petxp lock to lock.", 1, 1, 1)
    GameTooltip:AddLine("Right-click: open the character sheet pet tab.", 1, 1, 1)
    GameTooltip:AddLine("/petxp for all commands.", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end

local function Refresh()
    if not db or not frame then return end
    state = ReadState()
    local empty = state.status == "absent" or state.status == "class"
    frame:SetShown(db.visible and (not empty or not db.locked))
    if not frame:IsShown() then return end
    hint:SetText(preview and "PREVIEW" or (db.locked and "" or "DRAG"))
    frame:SetBackdropBorderColor(db.locked and 0.26 or 0.6, db.locked and 0.23 or 0.45, db.locked and 0.35 or 0.85, 1)
    title:SetText(state.name and (state.name .. (state.level and ("  |cffcab8edLv " .. state.level .. "|r") or "")) or "Forever Pet XP")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarColor(0.55, 0.3, 0.88)
    if state.status == "xp" then
        bar:SetMinMaxValues(0, state.total)
        bar:SetValue(state.current)
        label:SetText(string.format("%s / %s XP  (%.1f%%)", Number(state.current), Number(state.total), state.current / state.total * 100))
    elseif state.status == "atlevel" then
        bar:SetStatusBarColor(0.2, 0.6, 0.37)
        bar:SetValue(1)
        label:SetText("Pet is at your level")
    elseif state.status == "absent" then
        label:SetText("Summon your pet  |  Drag to position")
    elseif state.status == "class" then
        label:SetText("Hunter pets only  |  /petxp hide")
    else
        label:SetText(state.status == "noxp" and "No pet XP requirement" or "Pet XP unavailable")
    end
    if hovering then ShowTooltip() end
end

local function ApplyLayout()
    frame:SetSize(db.width, 48)
    frame:SetScale(db.scale)
    frame:ClearAllPoints()
    -- Store fractions of the screen so the position survives resolution changes.
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", UIParent:GetWidth() * db.x / db.scale, UIParent:GetHeight() * db.y / db.scale)
end

local function StopDragging()
    if not dragging then return end
    frame:StopMovingOrSizing()
    dragging = false
    local x, y = frame:GetCenter()
    if x and y then
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        db.x = Clamp(x * scale / UIParent:GetWidth(), 0, 1)
        db.y = Clamp(y * scale / UIParent:GetHeight(), 0, 1)
        ApplyLayout()
    end
end

local function OpenPetPanel()
    if InCombatLockdown() then
        Say("Open the pet panel after combat.")
        return
    end
    if not HasPetUI or not HasPetUI() then
        Say("Summon your pet to open its character sheet.")
        return
    end
    -- Forever's pet view is the third PaperDoll sidebar, not PetPaperDollFrame.
    if ToggleCharacter and PaperDollFrame_SetSidebar and PaperDollSidebarTabs and PaperDollSidebarTab3 then
        ToggleCharacter("PaperDollFrame", true)
        if CharacterFrame and CharacterFrame.SetRightPaneCollapsed then
            CharacterFrame:SetRightPaneCollapsed(false)
        end
        PaperDollFrame_SetSidebar(PaperDollSidebarTabs, PaperDollSidebarTab3:GetID())
    else
        Say("The pet panel shortcut is unavailable on this client. Open Character > Pet manually.")
    end
end

local function CreateBar()
    frame = CreateFrame("Frame", "ForeverPetXPFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.055, 0.045, 0.075, 0.93)
    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPRIGHT", -8, -7)
    hint:SetTextColor(0.7, 0.6, 0.88)
    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetPoint("RIGHT", hint, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 7, -23)
    bar:SetPoint("BOTTOMRIGHT", -7, 7)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:EnableMouse(false)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.13, 0.1, 0.19, 1)
    label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 3, 0)
    label:SetPoint("RIGHT", -3, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    frame:SetScript("OnDragStart", function()
        if not db.locked then
            dragging = true
            hovering = false
            GameTooltip:Hide()
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", StopDragging)
    frame:SetScript("OnMouseUp", function(_, button)
        StopDragging()
        if button == "RightButton" then OpenPetPanel() end
    end)
    frame:SetScript("OnEnter", function() hovering = true; ShowTooltip() end)
    frame:SetScript("OnLeave", function() hovering = false; GameTooltip:Hide() end)
    frame:SetScript("OnHide", function() StopDragging(); hovering = false; GameTooltip:Hide() end)
    ApplyLayout()
end

local function Command(input)
    if not db then return end
    local command, value = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    StopDragging()
    if command == "lock" then
        db.locked = true; Say("Position locked. /petxp unlock to move it again.")
    elseif command == "unlock" then
        db.locked, db.visible = false, true; Say("Unlocked. Left-drag the bar to move it.")
    elseif command == "show" or command == "hide" then
        db.visible = command == "show"
        Say(db.visible and "Enabled. Summon your pet to see its XP." or "Hidden. /petxp show to restore.")
    elseif command == "reset" then
        for key, default in pairs(defaults) do db[key] = default end
        preview = false; ApplyLayout(); Say("Default position and settings restored.")
    elseif command == "scale" or command == "width" then
        local number = tonumber(value)
        local low, high = command == "scale" and 0.6 or 240, command == "scale" and 2 or 700
        if not IsNumber(number) or number < low or number > high then
            Say("Use /petxp " .. command .. " " .. low .. " to " .. high .. ".")
            return
        end
        db[command] = number; ApplyLayout()
    elseif command == "test" then
        preview = not preview
        if preview then db.visible = true end
        Say(preview and "Preview on. /petxp test returns to live XP." or "Preview off; showing live pet data.")
    elseif command == "pet" then
        OpenPetPanel()
    else
        Say("Left-drag to move; right-click opens Character > Pet.")
        Say("/petxp lock | unlock | show | hide | reset | pet | test")
        Say("/petxp scale 0.6-2  |  /petxp width 240-700")
    end
    Refresh()
end

SLASH_FOREVERPETXP1 = "/petxp"
SLASH_FOREVERPETXP2 = "/fpetxp"
SlashCmdList.FOREVERPETXP = Command

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON or db then return end
        local firstRun = type(ForeverPetXPDB) ~= "table"
        ForeverPetXPDB = not firstRun and ForeverPetXPDB or {}
        db = ForeverPetXPDB
        for key, default in pairs(defaults) do
            if type(db[key]) ~= type(default) or (type(default) == "number" and not IsNumber(db[key])) then
                db[key] = default
            end
        end
        db.scale, db.width = Clamp(db.scale, 0.6, 2), Clamp(db.width, 240, 700)
        db.x, db.y = Clamp(db.x, 0, 1), Clamp(db.y, 0, 1)
        CreateBar()
        driver:UnregisterEvent("ADDON_LOADED")
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET_EXPERIENCE", "UNIT_PET", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "PLAYER_LEVEL_UP", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
            driver:RegisterEvent(name)
        end
        if firstRun then Say("Ready! Drag the bar into place, then /petxp lock. Right-click opens your pet sheet.") end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        StopDragging(); ApplyLayout()
    elseif event == "UNIT_PET" and arg1 ~= "player" then
        return
    elseif (event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE") and arg1 ~= "pet" and arg1 ~= "player" then
        return
    end
    Refresh()
end)

-- A slow refresh also covers delayed pet data after login, revival, or pet swaps.
local elapsedTotal = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= 1 then
        elapsedTotal = 0
        if db and db.visible then Refresh() end
    end
end)
