-- KeyCheckClear: press a key (or key chord) and see what it is bound to.
-- Blizzard's Keybindings panel only answers action -> key; this answers key -> action.
--
-- Core: the addon object, saved settings, the minimap/broker button, slash commands
-- and the combat rule. The work is in the modules: Bindings, Results, Window.

local KeyCheckClear = LibStub("AceAddon-3.0"):NewAddon("KeyCheckClear", "AceConsole-3.0", "AceEvent-3.0")

local ICON = "Interface\\AddOns\\KeyCheckClear\\media\\minimap_icon" -- media/minimap_icon.tga

local defaults = {
    profile = {
        minimap = { hide = false },
        window = { width = 380, height = 520 }, -- KeyCheckClearWindow status table (size + position)
        bgAlpha = 1,
        allCombos = false, -- "Display all modifier combos" tick box
        clearMode = false, -- "Show clear buttons" tick box
    },
}

function KeyCheckClear:OnInitialize()
    -- true = one shared "Default" profile; no profile UI
    self.db = LibStub("AceDB-3.0"):New("KeyCheckClearDB", defaults, true)

    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and DBIcon then
        self.ldb = LDB:NewDataObject("KeyCheckClear", {
            type = "launcher",
            text = "KeyCheckClear",
            icon = ICON,
            OnClick = function() self:Toggle() end,
            OnTooltipShow = function(tt)
                tt:AddLine("KeyCheckClear")
                tt:AddLine("|cffeda55fClick|r to find out what a key is bound to", 0.8, 0.8, 0.8)
                tt:AddLine("|cffeda55f/kcc minimap|r hides this button", 0.8, 0.8, 0.8)
            end,
        })
        DBIcon:Register("KeyCheckClear", self.ldb, self.db.profile.minimap)
    end

    self:RegisterChatCommand("kcc", "SlashCommand")
    self:RegisterChatCommand("keycheckclear", "SlashCommand")
end

-- /kcc opens or closes the window; /kcc minimap shows or hides the minimap button
function KeyCheckClear:SlashCommand(input)
    if strtrim(input or ""):lower() ~= "minimap" then
        return self:Toggle()
    end
    local mm = self.db.profile.minimap
    mm.hide = not mm.hide
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if DBIcon then
        if mm.hide then DBIcon:Hide("KeyCheckClear") else DBIcon:Show("KeyCheckClear") end
    end
    self:Print(mm.hide and "Minimap button hidden. /kcc minimap brings it back." or "Minimap button shown.")
end

-- KeyCheckClear is an out-of-combat tool: the window closes when combat starts and
-- won't open during it, so nothing here ever swallows keys or edits bindings in a fight
function KeyCheckClear:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        self:GetModule("Window"):Close()
    end)
end

function KeyCheckClear:Toggle()
    local Window = self:GetModule("Window")
    if Window:IsOpen() then
        Window:Close()
    elseif InCombatLockdown() then
        self:Print("Not available in combat.")
    else
        Window:Open()
    end
end
