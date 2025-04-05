local addonName, addon = ...
local L = addon.L

_G["BINDING_HEADER_ARENAQUICKJOIN"] = addonName
_G["BINDING_NAME_CLICK ArenaQuickJoinMacroButton:LeftButton"] = BATTLEFIELD_JOIN

local TOOLTIP_TITLE = addonName .. " (%s)"
local PVPUI_ADDON_NAME = "Blizzard_PVPUI"

local PVP_RATED_SOLO_SHUFFLE = PVP_RATED_SOLO_SHUFFLE
local PVP_RATED_BG_BLITZ = PVP_RATED_BG_BLITZ
local ARENA_2V2 = ARENA_2V2
local ARENA_3V3 = ARENA_3V3
local BATTLEGROUND_10V10 = BATTLEGROUND_10V10

local GameTooltip = GameTooltip
local PVEFrame = PVEFrame

local NewTicker = C_Timer.NewTicker
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local UIParentLoadAddOn = UIParentLoadAddOn
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local UnitLevel = UnitLevel
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local GetPVPRoles = GetPVPRoles
local GetMicroIconForRole = GetMicroIconForRole
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local GetBindingKey = GetBindingKey
local IsInInstance = IsInInstance

ArenaQuickJoinDB = ArenaQuickJoinDB or {
    ["Position"] = {"CENTER", "CENTER", 0, 0}
}

local function InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local JoinMacroButton = CreateFrame("Button", "ArenaQuickJoinMacroButton", UIParent, "ActionButtonTemplate, SecureActionButtonTemplate, SecureHandlerStateTemplate")
JoinMacroButton:SetPoint("CENTER")
JoinMacroButton:SetSize(45, 45)
JoinMacroButton:SetClampedToScreen(true)
JoinMacroButton:SetMovable(true)
JoinMacroButton:RegisterForDrag("LeftButton")
JoinMacroButton:RegisterForClicks('AnyUp', 'AnyDown')
JoinMacroButton:RegisterEvent("PLAYER_LOGIN")
JoinMacroButton:RegisterEvent("PLAYER_ENTERING_WORLD")
JoinMacroButton:RegisterEvent("PLAYER_REGEN_DISABLED")
JoinMacroButton:RegisterEvent("PLAYER_REGEN_ENABLED")
JoinMacroButton:RegisterEvent("ADDON_LOADED")

-- NOTE: Hides the popup arrow of the FlyoutButtonTemplate
JoinMacroButton.Arrow:Hide()

-- Properties
JoinMacroButton.LastUpdate = 0
JoinMacroButton.HasDragStarted = false

function JoinMacroButton:Active(style)
    if style == "show" then
        self:SetAlpha(1)
    elseif style == "normal" then
        -- NOTE: Can't be called during combat.
        self:Enable()
        self.icon:SetDesaturated(false)
    end
end

function JoinMacroButton:Inactive(style)
    if style == "hide" then
        self:SetAlpha(0)
    elseif style == "grayout" then
        -- NOTE: Can't be called during combat.
        self:Disable()
        self.icon:SetDesaturated(true)
    end
end

function JoinMacroButton:SetTexture(texture)
    self.icon:SetTexture("Interface\\Icons\\" .. texture)
end

function JoinMacroButton:SetGroupBracket(selectedBracket)
    local numMembers = GetNumSubgroupMembers(1) + 1 -- +1 for the player
    if ConquestJoinButton:IsEnabled() then
        if selectedBracket == 8 and numMembers <= 2 then
            self:SetAttribute("groupBracket", selectedBracket)
        else
            self:SetAttribute("groupBracket", numMembers)
        end
    else
        self:SetAttribute("groupBracket", 0)
    end
end

do
    local TANK_TEXTURE_SETTINGS = {
        width = 20,
        height = 20,
        verticalOffset = 3,
        margin = { left = 5, right = 5, top = 10 },
    }
    
    local HEALER_TEXTURE_SETTINGS = {
        width = 20,
        height = 20,
        verticalOffset = 3,
        margin = { left = 5, right = 5, bottom = 10 },
    }
    
    local DAMAGER_TEXTURE_SETTINGS = {
        width = 20,
        height = 20,
        verticalOffset = 3,
        margin = { left = 5, right = 5 },
    }

    local TANK, HEALER, DAMAGE = TANK, HEALER, DAMAGE
    local PVP_ITEM_LEVEL = NORMAL_FONT_COLOR:WrapTextInColorCode(STAT_AVERAGE_PVP_ITEM_LEVEL:gsub("%%d", "%%s"))

    local DUNGEONS_BUTTON = DUNGEONS_BUTTON
    local BATTLEFIELD_JOIN = BATTLEFIELD_JOIN

    local RED_FONT_COLOR = RED_FONT_COLOR
    local GREEN_FONT_COLOR = GREEN_FONT_COLOR
    local BLUE_FONT_COLOR = BLUE_FONT_COLOR
    local GRAY_FONT_COLOR = GRAY_FONT_COLOR

    local function GetSelectedBracketName(selectedBracket)
        if selectedBracket == 1 then
            return PVP_RATED_SOLO_SHUFFLE
        elseif selectedBracket == 8 then
            return PVP_RATED_BG_BLITZ
        elseif selectedBracket == 2 then
            return ARENA_2V2
        elseif selectedBracket == 3 then
            return ARENA_3V3
        elseif selectedBracket == 10 then
            return BATTLEGROUND_10V10
        end
    end

    local function SetTooltipPvPRole(roleEnabled, textureSettings, label)
        if roleEnabled then
            textureSettings.desaturation = 0
            return GREEN_FONT_COLOR:WrapTextInColorCode(label)
        else
            textureSettings.desaturation = 1
            return GRAY_FONT_COLOR:WrapTextInColorCode(label)
        end
    end
    
    local function AddTooltipHeader()
        local key  = GetBindingKey("CLICK ArenaQuickJoinMacroButton:LeftButton")
    
        if key then
            GameTooltip:AddLine(TOOLTIP_TITLE:format(key))
        else
            GameTooltip:AddLine(addonName)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip_AddHighlightLine(GameTooltip, L["Selected PvP Roles:"])
    
        local tank, healer, dps = GetPVPRoles()
    
        local tankLabel = SetTooltipPvPRole(tank, TANK_TEXTURE_SETTINGS, TANK)
        local healerLabel = SetTooltipPvPRole(healer, HEALER_TEXTURE_SETTINGS, HEALER)
        local dpsLabel = SetTooltipPvPRole(dps, DAMAGER_TEXTURE_SETTINGS, DAMAGE)
    
        GameTooltip:AddLine(tankLabel)
        GameTooltip:AddTexture(GetMicroIconForRole("TANK"), TANK_TEXTURE_SETTINGS)
        GameTooltip:AddLine(healerLabel)
        GameTooltip:AddTexture(GetMicroIconForRole("HEALER"), HEALER_TEXTURE_SETTINGS)
        GameTooltip:AddLine(dpsLabel)
        GameTooltip:AddTexture(GetMicroIconForRole("DAMAGER"), DAMAGER_TEXTURE_SETTINGS)

        local _, _, playerPvPItemLevel = GetAverageItemLevel()

        if playerPvPItemLevel then
            playerPvPItemLevel = RoundToSignificantDigits(playerPvPItemLevel, 2)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(PVP_ITEM_LEVEL:format(playerPvPItemLevel))
        end

        GameTooltip:AddLine(" ")
    end
    
    function JoinMacroButton:AddTooltipWelcomeInfo()
        GameTooltip:ClearLines()
    
        AddTooltipHeader()
    
        GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["To set the button click once,\nand then wait for it to be enabled to queue."]))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["To move the button %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Shift + Click")))
        GameTooltip:AddLine(L["To open the PvP Rated tab %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Ctrl + Click")))
        GameTooltip:AddLine(L["To open the PvP Quick Match tab %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Alt + Click")))
    end
    
    function JoinMacroButton:AddTooltipStateInfo()
        GameTooltip:ClearLines()
    
        AddTooltipHeader()
    
        local isFrameVisible = PVEFrame:IsVisible()
        local groupBracket = self:GetAttribute("groupBracket")
        local selectedBracket = self:GetAttribute("selectedBracket")
    
        if IsShiftKeyDown() then
            GameTooltip:AddLine(L["Move the button."])
        elseif (IsControlKeyDown() or IsAltKeyDown()) and not isFrameVisible then
            if IsControlKeyDown() then
                GameTooltip:AddLine(L["Open PvP Rated tab."])
            elseif IsAltKeyDown() then
                GameTooltip:AddLine(L["Open the PvP Quick Match tab."])
            end
        elseif isFrameVisible then
            GameTooltip:AddLine(L["Close the %s frame."]:format(DUNGEONS_BUTTON))
        elseif UnitLevel("player") < GetMaxLevelForPlayerExpansion() then
            GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["You must be max level to queue for rated PvP."]))
        elseif groupBracket == 0 then
            GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["Cannot join the selected bracket. The %s button is disabled."]:format(BATTLEFIELD_JOIN)))
        elseif groupBracket ~= selectedBracket then
            GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["Click to open the PvP Rated tab, \nto select a bracket that matches your group size."]))
        else
            local bracketName = GetSelectedBracketName(selectedBracket)
            if bracketName then
                GameTooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode(L["Click to queue to %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode(bracketName))))
            end
        end
    end
end

do
    local UPDATE_INTERVAL = 0.1

    local OnTooltipUpdate = function(self, elapsed)
        self.LastUpdate = self.LastUpdate + elapsed
        if self.LastUpdate > UPDATE_INTERVAL then
            if self.HasDragStarted then
                GameTooltip:Hide()
            else
                if self.Configure then
                    self:AddTooltipWelcomeInfo()
                else
                    self:AddTooltipStateInfo()
                end
                GameTooltip:Show()
            end
            self.LastUpdate = 0
        end
    end

    JoinMacroButton:SetScript("OnDragStart", function(self)
        if not IsShiftKeyDown() then
            return
        end
        self.HasDragStarted = true
        self:StartMoving()
    end)

    JoinMacroButton:SetScript("OnDragStop", function(self)
        local point, _, relpoint, x, y = self:GetPoint()
        ArenaQuickJoinDB["Position"] = { point, relpoint, x, y }
        self.HasDragStarted = false
        self:StopMovingOrSizing()
    end)

    JoinMacroButton:SetScript("OnEnter", function(self)
        local centerX, centerY = self:GetCenter()
        local screenWidth, screenHeight = GetScreenWidth()/2, GetScreenHeight()/2
        local anchor = "ANCHOR_"

        if centerX > screenWidth and centerY > screenHeight then
            anchor = anchor .. "BOTTOMLEFT"
        elseif centerX <= screenWidth and centerY > screenHeight then
            anchor = anchor .. "BOTTOMRIGHT"
        elseif centerX > screenWidth and centerY <= screenHeight then
            anchor = anchor .. "LEFT"
        elseif centerX <= screenWidth and centerY <= screenHeight then
            anchor = anchor .. "RIGHT"
        else
            anchor = anchor .. "CURSOR"
        end

        GameTooltip:SetOwner(self, anchor)

        self:SetScript("OnUpdate", OnTooltipUpdate)
    end)

    JoinMacroButton:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)
end

function JoinMacroButton:Init()
    local initAddon, initAddonHandle

    self:SetTexture("achievement_bg_killxenemies_generalsroom")
    self:SetAttribute("type", "macro")

    initAddon = function()
        if IsShiftKeyDown() then
            return
        end
        local _, isLoaded = IsAddOnLoaded(PVPUI_ADDON_NAME)
        if not isLoaded then
            GameTooltip:Hide()

            if self:IsEnabled() then
                self:Inactive("grayout")
            end

            if not isLoaded then
                UIParentLoadAddOn(PVPUI_ADDON_NAME)
            end

            initAddonHandle = NewTicker(1, initAddon)
        else
            if initAddonHandle then
                initAddonHandle:Cancel()
                initAddonHandle = nil
            end
            initAddon = nil
            self:Active("normal")
        end
    end

    self:HookScript("OnClick", initAddon)
    self.Init = nil
end

function JoinMacroButton:Configure()
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("MODIFIER_STATE_CHANGED")

    self:SetFrameRef("PVEFrame", PVEFrame)
    self:SetAttribute("selectedBracket", 1)
    self:SetGroupBracket()

    hooksecurefunc("ConquestFrame_SelectButton", function(frameSelectedButton)
        local selectedBracket = 0
        if frameSelectedButton == ConquestFrame.RatedSoloShuffle then
            selectedBracket = 1
        elseif frameSelectedButton == ConquestFrame.RatedBGBlitz then
            selectedBracket = 8
        elseif frameSelectedButton == ConquestFrame.Arena2v2 then
            selectedBracket = 2
        elseif frameSelectedButton == ConquestFrame.Arena3v3 then
            selectedBracket = 3
        elseif frameSelectedButton == ConquestFrame.RatedBG then
            selectedBracket = 10
        end
        self:SetAttribute("selectedBracket", selectedBracket)
        self:SetGroupBracket(selectedBracket)
    end)

    SecureHandlerWrapScript(self, "OnClick", self, [[
        if IsShiftKeyDown() then
            self:SetAttribute("macrotext", "")
            return
        end

        local PVEFrame = self:GetFrameRef("PVEFrame")
        local groupBracket = self:GetAttribute("groupBracket")
        local selectedBracket = self:GetAttribute("selectedBracket")

        if PVEFrame:IsVisible() then
            self:SetAttribute("macrotext", "/click LFDMicroButton")
        elseif IsAltKeyDown() then
            self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton1")
        elseif groupBracket ~= selectedBracket or IsControlKeyDown() then
            self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton2")
        else
            self:SetAttribute("macrotext", "/click ConquestJoinButton")
        end
    ]])

    self.Configure = nil
end

JoinMacroButton:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        if self.Init then
            self:Init()
        end
        local point, relpoint, x, y = unpack(ArenaQuickJoinDB["Position"])
        self:ClearAllPoints()
        self:SetPoint(point, UIParent, relpoint, x, y)
    elseif eventName == "ADDON_LOADED" then
        local arg1 = ...
        
        if arg1 ~= PVPUI_ADDON_NAME then
            return
        end

        if not InCombat() and self.Configure then
            self:Configure()
        end
    elseif eventName == "GROUP_ROSTER_UPDATE" then
        local selectedBracket = self:GetAttribute("selectedBracket")
        self:SetGroupBracket(selectedBracket)
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        if IsInInstance() then
            self:Inactive("hide")
        else
            self:Active("show")
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        self:Inactive("grayout")
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if self.Configure then 
            self:Configure()
        end
        self:Active("normal")
    elseif eventName == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if down == 1 and (key == "LALT" or key == "RALT") then
            self:SetTexture("achievement_bg_winwsg")
        else
            self:SetTexture("achievement_bg_killxenemies_generalsroom")
        end
    end
end)