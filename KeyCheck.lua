-- KeyCheck: press a key (or key chord) and see what it is bound to.
-- Blizzard's Keybindings panel only answers action -> key; this answers key -> action.

local KeyCheck = LibStub("AceAddon-3.0"):NewAddon("KeyCheck", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local ICON = "Interface\\Icons\\INV_Misc_Key_12" -- file ID 134246 (wowhead classic icon DB)
local HISTORY_SIZE = 50
local NONE = "|cff999999None yet|r"
local HELP = "Click the button, then press any key or key combo.\n"
    .. "|cff999999Esc stops listening  -  Esc again closes the window|r"

local defaults = {
    profile = {
        minimap = { hide = false },
        window = { width = 380, height = 520 }, -- KeyCheckWindow status table (size + position)
        bgAlpha = 1,
    },
}

-------------------------------------------------------------------------------
--  Lookup
-------------------------------------------------------------------------------
-- Friendly name for a binding action: the BINDING_NAME_ global if the action
-- registered one, otherwise the raw action (CLICK Foo:LeftButton, MACRO x, SPELL x...)
local function ActionName(action)
    if not action or action == "" then return nil end
    return _G["BINDING_NAME_" .. action] or action
end

-- GetBindingAction(key) answers the base binding only; addons that bind through
-- SetOverrideBinding* (e.g. the EllesmereUI damage meter hotkeys) show up only
-- with the second argument. If this client ignores it, both answers match.
local function Lookup(key)
    local base = ActionName(GetBindingAction(key))
    local override = ActionName(GetBindingAction(key, true))
    if override == base then override = nil end
    return base, override
end

-------------------------------------------------------------------------------
--  Layout: stack children top to bottom; full-width children stretch, the rest
--  are centered, and the child flagged fillHeight takes the remaining height
-------------------------------------------------------------------------------
AceGUI:RegisterLayout("KeyCheckStack", function(content, children)
    local width = content.width or content:GetWidth() or 0
    local height = content.height or content:GetHeight() or 0

    local used, filler = 0, nil
    for _, child in ipairs(children) do
        if child.fillHeight then
            filler = child
        else
            if child.width == "fill" then
                child:SetWidth(width)
            elseif child.width == "relative" then
                child:SetWidth(width * child.relWidth)
            end
            if child.DoLayout then child:DoLayout() end
            used = used + (child.frame:GetHeight() or 0)
        end
    end
    if filler then
        filler:SetWidth(width)
        filler:SetHeight(math.max(40, height - used))
        if filler.DoLayout then filler:DoLayout() end
    end

    local y = 0
    for _, child in ipairs(children) do
        local frame = child.frame
        frame:ClearAllPoints()
        frame:Show()
        frame:SetPoint("TOP", content, "TOP", 0, -y)
        if child.width == "fill" or child.fillHeight then
            frame:SetPoint("LEFT", content)
            frame:SetPoint("RIGHT", content)
        end
        y = y + (frame:GetHeight() or 0)
    end
    if content.obj.LayoutFinished then
        content.obj:LayoutFinished(nil, y)
    end
end)

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
function KeyCheck:OnInitialize()
    -- true = one shared "Default" profile; no profile UI
    self.db = LibStub("AceDB-3.0"):New("KeyCheckDB", defaults, true)
    self.history = {}

    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and DBIcon then
        self.ldb = LDB:NewDataObject("KeyCheck", {
            type = "launcher",
            text = "KeyCheck",
            icon = ICON,
            OnClick = function() self:Toggle() end,
            OnTooltipShow = function(tt)
                tt:AddLine("KeyCheck")
                tt:AddLine("|cffeda55fClick|r to find out what a key is bound to", 0.8, 0.8, 0.8)
            end,
        })
        DBIcon:Register("KeyCheck", self.ldb, self.db.profile.minimap)
    end

    self:RegisterChatCommand("kc", "Toggle")
    self:RegisterChatCommand("keycheck", "Toggle")
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
function KeyCheck:Toggle()
    if self.window then
        self.window:Hide() -- OnClose releases it
    else
        self:OpenWindow()
    end
end

function KeyCheck:RefreshHistory()
    local w = self.widgets
    w.history:SetText(#self.history > 0 and table.concat(self.history, "\n") or NONE)
    w.recent:DoLayout()
end

-- One color scheme from Result down: labels white, keys yellow, results by status
-- (green free, red bound, orange addon override)
local function Key(s) return "|cffffd100" .. s .. "|r" end
local function Label(s) return "|cffffffff" .. s .. "|r" end
local function Result(base) return base and ("|cffff4040" .. base .. "|r") or "|cff40ff40Free|r" end
local function Override(s) return "|cffff8040" .. s .. "|r" end

local function KeyText(key)
    return GetBindingText and GetBindingText(key) or key
end

function KeyCheck:DisplayResult(key)
    local w = self.widgets
    local base, override = Lookup(key)

    -- An addon override is what the key actually does right now, so it wins;
    -- whatever it hides underneath doesn't matter for "is this key free?"
    local text = Key(KeyText(key)) .. "\n"
    if override then
        text = text .. Label("Bound to:") .. " " .. Override(override) .. " " .. Label("(addon)")
    elseif base then
        text = text .. Label("Bound to:") .. " " .. Result(base)
    else
        text = text .. Result(nil)
    end
    w.result:SetText(text)
    self.window:DoLayout() -- result lines changed height
    return base, override
end

function KeyCheck:ShowResult(key)
    local base, override = self:DisplayResult(key)

    local line = Key(KeyText(key)) .. " " .. Label("-") .. " "
    if override then
        line = line .. Override(override) .. " " .. Label("(addon)")
    else
        line = line .. Result(base)
    end
    table.insert(self.history, 1, line)
    self.history[HISTORY_SIZE + 1] = nil
    self:RefreshHistory()
end

local function Heading(parent, text)
    local h = AceGUI:Create("Heading")
    h:SetText(text)
    h:SetFullWidth(true)
    parent:AddChild(h)
end

local function CenteredLabel(parent, font, text)
    local l = AceGUI:Create("Label")
    l:SetFullWidth(true)
    l:SetFontObject(font)
    l:SetJustifyH("CENTER")
    l:SetText(text)
    parent:AddChild(l)
    return l
end

-- one blank line of body text
local function Spacer(parent)
    local s = AceGUI:Create("Label")
    s:SetFullWidth(true)
    s:SetFontObject(GameFontHighlight)
    s:SetText(" ")
    parent:AddChild(s)
end

function KeyCheck:OpenWindow()
    local frame = AceGUI:Create("KeyCheckWindow")
    frame:SetTitle("KeyCheck")
    frame:SetLayout("KeyCheckStack")
    frame:SetStatusTable(self.db.profile.window) -- size and position persist through AceDB
    frame:SetBgAlpha(self.db.profile.bgAlpha)
    self.window = frame

    -- Escape closes the window while not listening (listening swallows Esc itself)
    _G.KeyCheckFrame = frame.frame
    if not self.specialFrameAdded then
        tinsert(UISpecialFrames, "KeyCheckFrame")
        self.specialFrameAdded = true
    end

    local w = {}
    self.widgets = w
    frame:PauseLayout()

    local opacity = AceGUI:Create("Slider")
    opacity:SetLabel("Background opacity")
    opacity:SetSliderValues(0, 1, 0.05)
    opacity:SetIsPercent(true)
    opacity:SetValue(self.db.profile.bgAlpha)
    opacity:SetRelativeWidth(0.8)
    opacity:SetCallback("OnValueChanged", function(_, _, value)
        self.db.profile.bgAlpha = value
        frame:SetBgAlpha(value)
    end)
    frame:AddChild(opacity)
    opacity.editbox:Hide() -- just the bar; the value box shares a row with the 0%/100% labels, so no gap
    -- a little padding between the "Background opacity" label and the bar
    opacity.slider:SetPoint("TOP", opacity.label, "BOTTOM", 0, -6)
    opacity:SetHeight(50)

    Heading(frame, "") -- empty Heading = one unbroken divider line
    CenteredLabel(frame, GameFontHighlight, HELP)
    Spacer(frame)

    local kb = AceGUI:Create("KeyCheckKeyButton")
    kb:SetCallback("OnKeyChanged", function(_, _, key)
        if key and key ~= "" then self:ShowResult(key) end
    end)
    frame:AddChild(kb)
    Spacer(frame)

    Heading(frame, "Result")
    Spacer(frame)
    w.result = CenteredLabel(frame, GameFontHighlightMedium, NONE) -- one Blizzard size step above the body text
    w.result.label:SetSpacing(7) -- same half-line gap as Recent, between the key and "Bound to:"
    Spacer(frame)

    Heading(frame, "Recent")
    w.recent = AceGUI:Create("ScrollFrame")
    w.recent:SetLayout("List")
    w.recent.fillHeight = true
    frame:AddChild(w.recent)
    Spacer(w.recent) -- inside the scroll frame, so it scrolls with the entries
    w.history = CenteredLabel(w.recent, GameFontHighlight, NONE)
    w.history.label:SetSpacing(7) -- about half a line between entries

    frame:ResumeLayout()
    frame:DoLayout()
    self:RefreshHistory()

    frame:SetCallback("OnClose", function(widget)
        -- history lives only as long as the window
        wipe(self.history)
        -- stock pooled widgets: hand them back as AceGUI gave them to us
        opacity.editbox:Show()
        opacity.slider:SetPoint("TOP", opacity.label, "BOTTOM") -- height is reset by the Slider's OnAcquire
        w.result.label:SetSpacing(0)
        w.history.label:SetSpacing(0)
        w.recent.fillHeight = nil
        _G.KeyCheckFrame = nil
        self.window, self.widgets = nil, nil
        AceGUI:Release(widget)
    end)
end
