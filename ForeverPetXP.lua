local ADDON = ...
local defaults = {
    locked = false, visible = true, width = 300, scale = 1, x = 0.5, y = 0.32,
    outlineR = 0.6, outlineG = 0.45, outlineB = 0.85,
    sound = true,
}
local db, frame, bar, title, hint, label
local happinessBar, happinessLabel, popup, colorPanel
local colorSliders = {}
local preview, dragging, hovering = false, false, false
local state = {}
local previousPet, previousHappiness, previousMood, wasFeeding
local soundHandle
local popupElapsed, popupIsGain = nil, false
local happinessNames = { "Unhappy", "Content", "Happy" }
local happinessColors = { {0.85, 0.2, 0.2}, {0.85, 0.65, 0.15}, {0.2, 0.7, 0.35} }
-- CreatureFamily ID, English fallback name, and built-in audio FileDataID.
-- Verified filenames are recorded in SOUNDS.md; no audio files are bundled.
local animalSounds = {
    {1, "Wolf", 564223}, {2, "Cat", 562388}, {3, "Spider", 561418},
    {4, "Bear", 544959}, {5, "Boar", 545134}, {6, "Crocolisk", 544686},
    {7, "Carrion Bird", 545937}, {8, "Crab", 546432}, {9, "Gorilla", 550961},
    {11, "Raptor", 558881}, {12, "Tallstrider", 561393}, {20, "Scorpid", 547809},
    {21, "Turtle", 559872}, {24, "Bat", 548728}, {25, "Hyena", 552343},
    {26, "Bird of Prey", 557971}, {27, "Wind Serpent", 564133},
    {45, "Core Hound", 546376}, {50, "Fox", 555465},
}
local genericEatingSound = 567525

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

local function SafeCall(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, a, b, c = pcall(api, ...)
    if ok then return a, b, c end
end

local function PetSound()
    local family = SafeCall(UnitCreatureFamily, "pet")
    if not IsPublic(family) or type(family) ~= "string" then return genericEatingSound end
    for _, profile in ipairs(animalSounds) do
        local info = SafeCall(C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo, profile[1])
        local localizedName
        if IsPublic(info) and type(info) == "table" and IsPublic(info.name) then localizedName = info.name end
        if family == localizedName or family == profile[2] or (profile[1] == 26 and family == "Owl") then
            return profile[3], family
        end
    end
    return genericEatingSound, family
end

local function StopPetSound()
    if soundHandle then SafeCall(StopSound, soundHandle) end
    soundHandle = nil
end

local function PlayPetSound(mood)
    if not db.sound then return false end
    local fileID, family = PetSound()
    if mood == 1 then
        fileID, family = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\womp-womp.ogg", "womp womp"
    end
    StopPetSound()
    -- SFX respects the user's existing effects volume and mute settings.
    local played, handle = SafeCall(PlaySoundFile, fileID, "SFX")
    if IsPublic(played) and not played and fileID ~= genericEatingSound then
        played, handle = SafeCall(PlaySoundFile, genericEatingSound, "SFX")
    end
    if IsNumber(handle) then soundHandle = handle end
    return IsPublic(played) and played == true, family
end

local function HappinessPowerType()
    -- Forever uses 27; the old Classic value 4 is ComboPoints on this client.
    local powerType = Enum and Enum.PowerType and Enum.PowerType.Happiness
    return IsNumber(powerType) and powerType or nil
end

local function ReadHappiness(data)
    local api = C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness
    local happiness, damage = SafeCall(api)
    if IsNumber(happiness) and happinessNames[happiness] then data.happiness = happiness end
    if IsNumber(damage) and damage >= 0 then data.damage = damage end

    local guid = SafeCall(UnitGUID, "pet")
    if IsPublic(guid) and type(guid) == "string" then data.guid = guid end
    local powerType = HappinessPowerType()
    if powerType then
        local current = SafeCall(UnitPower, "pet", powerType)
        local total = SafeCall(UnitPowerMax, "pet", powerType)
        if IsNumber(current) and IsNumber(total) and current >= 0 and total > 0 and current <= total then
            data.happinessCurrent, data.happinessTotal = current, total
        end
    end
    -- Feed Pet's effect is 1539; only inspect a public aura returned by the API.
    local aura = SafeCall(C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID, "pet", 1539)
    data.feeding = IsPublic(aura) and type(aura) == "table"
end

local function ClearFeedback()
    previousPet, previousHappiness, previousMood, wasFeeding = nil, nil, nil, false
    StopPetSound()
    popupElapsed, popupIsGain = nil, false
    if popup then popup:Hide() end
end

local function ShowPopup(text, isGain)
    if not frame:IsShown() then return end
    -- Aura and cast notifications must not overwrite a numeric gain.
    if not isGain and popupElapsed and popupIsGain then return end
    popupElapsed, popupIsGain = 0, isGain
    popup:SetText(text)
    popup:SetAlpha(1)
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    popup:Show()
end

local function UpdateFeedback()
    if preview then return end
    if not frame:IsShown() then ClearFeedback(); return end
    if previousPet ~= state.guid or state.status == "absent" or state.status == "class" then
        ClearFeedback()
    else
        if state.guid and state.happinessCurrent and previousHappiness and state.happinessCurrent > previousHappiness then
            ShowPopup("+" .. Number(state.happinessCurrent - previousHappiness) .. " Happiness", true)
        end
        -- Animal clips on upward transitions; womp womp on entering red.
        -- First reads, green -> yellow, ordinary ticks and previews stay silent.
        if state.happiness and previousMood and state.happiness ~= previousMood
            and (state.happiness > previousMood or state.happiness == 1) then
            PlayPetSound(state.happiness)
        end
    end
    if state.feeding and not wasFeeding then ShowPopup("Feeding pet", false) end
    previousPet, previousHappiness, wasFeeding = state.guid, state.happinessCurrent, state.feeding
    previousMood = state.happiness
end

local function ReadState()
    if preview then
        return { name = "Preview pet", level = 18, current = 1250, total = 5000, status = "xp", happiness = 3, damage = 125 }
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
    ReadHappiness(data)
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
    if state.happiness then
        GameTooltip:AddDoubleLine("Happiness", happinessNames[state.happiness], 1, 1, 1, 0.55, 1, 0.65)
        if state.damage then GameTooltip:AddLine(Number(state.damage) .. "% pet damage", 1, 1, 1) end
    end
    if state.happinessCurrent then
        GameTooltip:AddDoubleLine("Happiness points", Number(state.happinessCurrent) .. " / " .. Number(state.happinessTotal), 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:AddLine("Happiness meter shows the reported mood, not an estimated percentage.", 0.75, 0.75, 0.75, true)
    end
    GameTooltip:AddLine("Feeding gains appear when the game exposes readable amounts.", 0.75, 0.75, 0.75, true)
    GameTooltip:AddLine("Mood sounds: " .. (db.sound and "on" or "off") .. ". /petxp sound to toggle.", 0.75, 0.75, 0.75, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(db.locked and "Position locked. /petxp unlock to move." or "Left-drag to move. /petxp lock to lock.", 1, 1, 1)
    GameTooltip:AddLine("Right-click: open the character sheet pet tab.", 1, 1, 1)
    GameTooltip:AddLine("Color square: outline sliders. X: hide; /petxp show to restore.", 1, 1, 1, true)
    GameTooltip:AddLine("/petxp for all commands.", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end

local function ApplyOutline()
    frame:SetBackdropBorderColor(db.outlineR, db.outlineG, db.outlineB, 1)
    if frame.colorSwatch then frame.colorSwatch:SetColorTexture(db.outlineR, db.outlineG, db.outlineB, 1) end
end

local function Refresh()
    if not db or not frame then return end
    state = ReadState()
    local empty = state.status == "absent" or state.status == "class"
    frame:SetShown(db.visible and (not empty or not db.locked))
    UpdateFeedback()
    if not frame:IsShown() then return end
    hint:SetText(preview and "PREVIEW" or (db.locked and "" or "DRAG"))
    ApplyOutline()
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
        label:SetText("Hunter pets only  |  X to hide")
    else
        label:SetText(state.status == "noxp" and "No pet XP requirement" or "Pet XP unavailable")
    end
    happinessBar:SetMinMaxValues(0, 3)
    happinessBar:SetValue(state.happiness or 0)
    local color = happinessColors[state.happiness] or {0.35, 0.35, 0.35}
    happinessBar:SetStatusBarColor(unpack(color))
    local text = state.happiness and ("Happiness: " .. happinessNames[state.happiness]) or "Happiness unavailable"
    if state.happinessCurrent then
        happinessBar:SetMinMaxValues(0, state.happinessTotal)
        happinessBar:SetValue(state.happinessCurrent)
    end
    if state.happiness and state.damage then text = text .. "  |  " .. Number(state.damage) .. "% damage" end
    if empty then text = state.status == "class" and "Hidden settings are saved per character" or "No pet summoned" end
    happinessLabel:SetText(text)
    if hovering then ShowTooltip() end
end

local function ApplyLayout()
    frame:SetSize(db.width, 69)
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

local function HideBar()
    StopDragging()
    db.visible = false
    frame:Hide()
    Say("Hidden for this character. /petxp show to restore.")
end

local function ToggleColors()
    if not colorPanel then
        colorPanel = CreateFrame("Frame", "ForeverPetXPColors", frame, "BackdropTemplate")
        colorPanel:SetSize(280, 150)
        colorPanel:SetPoint("TOP", frame, "BOTTOM", 0, -5)
        colorPanel:SetClampedToScreen(true)
        colorPanel:EnableMouse(true)
        colorPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        colorPanel:SetBackdropColor(0.055, 0.045, 0.075, 1)
        colorPanel:SetBackdropBorderColor(0.6, 0.45, 0.85, 1)
        local heading = colorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 12, -10)
        heading:SetText("Outline color")
        local close = CreateFrame("Button", nil, colorPanel, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        close:SetScript("OnClick", function() colorPanel:Hide() end)
        for index, channel in ipairs({ "R", "G", "B" }) do
            local key = "outline" .. channel
            local slider = CreateFrame("Slider", "ForeverPetXPColor" .. channel, colorPanel)
            slider:SetOrientation("HORIZONTAL")
            slider:SetSize(170, 16)
            slider:SetPoint("TOPLEFT", 55, -32 - (index - 1) * 34)
            slider:SetMinMaxValues(0, 1)
            slider:SetValueStep(0.01)
            slider:SetObeyStepOnDrag(true)
            slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            slider:GetThumbTexture():SetSize(24, 24)
            local track = slider:CreateTexture(nil, "BACKGROUND")
            track:SetPoint("TOPLEFT", 0, -6)
            track:SetPoint("BOTTOMRIGHT", 0, 6)
            track:SetColorTexture(0.3, 0.3, 0.3, 1)
            local caption = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            caption:SetPoint("RIGHT", slider, "LEFT", -8, 0)
            caption:SetText(({ "Red", "Green", "Blue" })[index])
            local valueLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valueLabel:SetPoint("LEFT", slider, "RIGHT", 8, 0)
            slider:SetScript("OnValueChanged", function(_, value)
                if not IsNumber(value) then return end
                db[key] = Clamp(value, 0, 1)
                valueLabel:SetText(math.floor(db[key] * 255 + 0.5))
                ApplyOutline()
            end)
            colorSliders[key] = slider
        end
        colorPanel:Hide()
    end
    for key, slider in pairs(colorSliders) do slider:SetValue(db[key]) end
    colorPanel:SetShown(not colorPanel:IsShown())
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
    hint:SetPoint("TOPRIGHT", -53, -7)
    hint:SetTextColor(0.7, 0.6, 0.88)
    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetPoint("RIGHT", hint, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    bar = CreateFrame("StatusBar", "ForeverPetXPExperienceBar", frame)
    bar:SetPoint("TOPLEFT", 7, -23)
    bar:SetPoint("TOPRIGHT", -7, -23)
    bar:SetHeight(18)
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
    happinessBar = CreateFrame("StatusBar", "ForeverPetXPHappinessBar", frame)
    happinessBar:SetPoint("TOPLEFT", 7, -45)
    happinessBar:SetPoint("BOTTOMRIGHT", -7, 7)
    happinessBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happinessBar:EnableMouse(false)
    local happinessBackground = happinessBar:CreateTexture(nil, "BACKGROUND")
    happinessBackground:SetAllPoints()
    happinessBackground:SetColorTexture(0.13, 0.1, 0.19, 1)
    happinessLabel = happinessBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    happinessLabel:SetPoint("LEFT", 3, 0)
    happinessLabel:SetPoint("RIGHT", -3, 0)
    happinessLabel:SetJustifyH("CENTER")
    happinessLabel:SetWordWrap(false)
    happinessLabel:SetShadowColor(0, 0, 0, 1)
    happinessLabel:SetShadowOffset(1, -1)
    popup = frame:CreateFontString("ForeverPetXPPopup", "OVERLAY", "GameFontNormalLarge")
    popup:SetTextColor(0.4, 1, 0.45)
    popup:SetShadowColor(0, 0, 0, 1)
    popup:SetShadowOffset(1, -1)
    popup:Hide()
    local close = CreateFrame("Button", "ForeverPetXPClose", frame, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", HideBar)
    local colors = CreateFrame("Button", "ForeverPetXPColorButton", frame)
    colors:SetSize(16, 16)
    colors:SetPoint("TOPRIGHT", -28, -5)
    frame.colorSwatch = colors:CreateTexture(nil, "ARTWORK")
    frame.colorSwatch:SetAllPoints()
    colors:SetScript("OnClick", ToggleColors)
    colors:SetScript("OnEnter", function()
        GameTooltip:SetOwner(colors, "ANCHOR_TOP")
        GameTooltip:SetText("Outline color")
        GameTooltip:AddLine("Click to adjust the red, green and blue sliders.", 1, 1, 1)
        GameTooltip:Show()
    end)
    colors:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    frame:SetScript("OnHide", function()
        StopDragging(); hovering = false; GameTooltip:Hide(); ClearFeedback()
        if colorPanel then colorPanel:Hide() end
    end)
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
        preview = false; ClearFeedback(); ApplyLayout()
        if colorPanel then colorPanel:Hide() end
        Say("Default position and settings restored.")
    elseif command == "color" or command == "colour" then
        db.visible = true
        Refresh()
        -- Make the positioning placeholder accessible on a non-Hunter too.
        if not frame:IsShown() then db.locked = false; Refresh() end
        ToggleColors()
    elseif command == "sound" then
        if value == "test" or value == "test red" then
            if not db.sound then Say("Sounds are off. /petxp sound on to enable them."); return end
            local _, class = UnitClass("player")
            local exists = SafeCall(UnitExists, "pet")
            if class ~= "HUNTER" or not IsPublic(exists) or not exists then Say("Summon your Hunter pet to test its sound."); return end
            local played, family = PlayPetSound(value == "test red" and 1 or nil)
            Say(played and ("Playing " .. (family or "generic") .. " happiness sound.") or "Sound could not play. Check your Effects sound settings.")
            return
        elseif value == "" then
            db.sound = not db.sound
        elseif value == "on" or value == "off" then
            db.sound = value == "on"
        else
            Say("/petxp sound [on | off | test | test red]"); return
        end
        if not db.sound then StopPetSound() end
        Say(db.sound and "Sounds on: animal clips when happiness rises; womp womp when it turns red." or "Happiness sounds off.")
    elseif command == "scale" or command == "width" then
        local number = tonumber(value)
        local low, high = command == "scale" and 0.6 or 240, command == "scale" and 2 or 700
        if not IsNumber(number) or number < low or number > high then
            Say("Use /petxp " .. command .. " " .. low .. " to " .. high .. ".")
            return
        end
        db[command] = number; ApplyLayout()
    elseif command == "test" then
        ClearFeedback()
        preview = not preview
        if preview then db.visible = true end
        Say(preview and "Preview on. /petxp test returns to live XP." or "Preview off; showing live pet data.")
    elseif command == "pet" then
        OpenPetPanel()
    else
        Say("Left-drag to move; right-click opens Character > Pet.")
        Say("/petxp lock | unlock | show | hide | reset | pet | test | color | sound")
        Say("/petxp scale 0.6-2  |  /petxp width 240-700")
    end
    Refresh()
    if command == "test" and preview then ShowPopup("+59 Happiness (preview)", true) end
end

SLASH_FOREVERPETXP1 = "/petxp"
SLASH_FOREVERPETXP2 = "/fpetxp"
SlashCmdList.FOREVERPETXP = Command

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
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
        for _, channel in ipairs({ "R", "G", "B" }) do
            local key = "outline" .. channel
            db[key] = Clamp(db[key], 0, 1)
        end
        CreateBar()
        driver:UnregisterEvent("ADDON_LOADED")
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET_EXPERIENCE", "UNIT_PET", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "PLAYER_LEVEL_UP", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "UNIT_HAPPINESS", "UNIT_POWER_UPDATE", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" }) do
            driver:RegisterEvent(name)
        end
        -- Some Forever builds restrict combat log registration or reads. The
        -- meter and public power-delta feedback work independently of this path.
        pcall(driver.RegisterEvent, driver, "COMBAT_LOG_EVENT_UNFILTERED")
        if firstRun then Say("Ready! Drag the bar into place, then /petxp lock. Right-click opens your pet sheet.") end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        StopDragging(); ApplyLayout()
    elseif event == "UNIT_PET" and arg1 ~= "player" then
        return
    elseif event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then
        ClearFeedback()
    elseif event == "UNIT_HAPPINESS" or event == "UNIT_POWER_UPDATE" or event == "UNIT_AURA" then
        if not IsPublic(arg1) or arg1 ~= "pet" then return end
        if event == "UNIT_POWER_UPDATE" and (not IsPublic(arg2) or arg2 ~= "HAPPINESS") then return end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not IsPublic(arg1) or arg1 ~= "player" or not IsNumber(arg3) or arg3 ~= 6991 then return end
        Refresh()
        if not preview and state.name then ShowPopup("Feeding pet", false) end
        return
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if preview or not db.visible or not frame:IsShown() then return end
        local api = C_CombatLog and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo
        if type(api) ~= "function" then return end
        local restricted = SafeCall(C_CombatLog and C_CombatLog.IsCombatLogRestricted)
        if not IsPublic(restricted) or restricted then return end
        local info = { pcall(api) }
        if not info[1] then return end
        -- pcall inserts the success flag before the standard 11-field header.
        local kind, destination, amount, overflow, powerType = info[3], info[9], info[16], info[17], info[18]
        if not IsPublic(kind) or (kind ~= "SPELL_ENERGIZE" and kind ~= "SPELL_PERIODIC_ENERGIZE") then return end
        if not IsNumber(powerType) or powerType ~= HappinessPowerType() or not IsNumber(amount) or amount <= 0 then return end
        if not IsNumber(overflow) or overflow < 0 then return end
        amount = amount - overflow
        if amount <= 0 then return end
        local guid = SafeCall(UnitGUID, "pet")
        if not IsPublic(destination) or not IsPublic(guid) or type(guid) ~= "string" or destination ~= guid then return end
        Refresh()
        -- Prefer public UnitPower deltas; never count that same tick twice.
        if not state.happinessCurrent and state.guid == guid then
            ShowPopup("+" .. Number(amount) .. " Happiness", true)
        end
        return
    elseif (event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE") and arg1 ~= "pet" and arg1 ~= "player" then
        return
    end
    Refresh()
end)

-- A slow refresh also covers delayed pet data after login, revival, or pet swaps.
local elapsedTotal = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if popupElapsed then
        popupElapsed = popupElapsed + elapsed
        if popupElapsed >= 2.5 then
            popup:Hide(); popupElapsed, popupIsGain = nil, false
        else
            popup:SetAlpha(1 - math.max(0, popupElapsed - 1) / 1.5)
            popup:ClearAllPoints()
            popup:SetPoint("BOTTOM", frame, "TOP", 0, 5 + popupElapsed * 9)
        end
    end
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= 1 then
        elapsedTotal = 0
        if db and db.visible then Refresh() end
    end
end)
