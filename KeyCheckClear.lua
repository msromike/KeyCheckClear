-- KeyCheckClear: press a key (or key chord) and see what it is bound to.
-- Blizzard's Keybindings panel only answers action -> key; this answers key -> action.

local KeyCheckClear = LibStub("AceAddon-3.0"):NewAddon("KeyCheckClear", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local ICON = "Interface\\AddOns\\KeyCheckClear\\media\\minimap_icon" -- media/minimap_icon.tga
local NONE = "|cff999999Nothing checked yet|r"
local HELP = "Hover over the button.\nThen press any key or key combo."
local LISTEN_NOTE = "Move mouse to stop listening"
local CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" -- red X, in every client's UI
local UNDO_ICON = "Interface\\Buttons\\UI-RefreshButton"      -- circular arrow, same
local ICON_SIZE = 16

local defaults = {
    profile = {
        minimap = { hide = false },
        window = { width = 380, height = 520 }, -- KeyCheckClearWindow status table (size + position)
        bgAlpha = 1,
        allCombos = false, -- "Display all modifier combos" tick box
        clearMode = false, -- "Show clear buttons" tick box
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

-- The 8 modifier combinations of a key, in display order. The game always writes
-- modifiers ALT-CTRL-SHIFT, so these are the exact strings GetBindingAction knows
-- (same set as EllesmereUI Quickdraw's MOD_COMBOS).
local COMBOS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local MODIFIERS = { "ALT-", "CTRL-", "SHIFT-", "META-" }

-- SHIFT-D -> D: strip the modifier prefixes, in the order the game writes them
local function BaseKey(key)
    for _, m in ipairs(MODIFIERS) do
        if key:sub(1, #m) == m then key = key:sub(#m + 1) end
    end
    return key
end

local function CombosOf(key)
    local base, keys = BaseKey(key), {}
    for i, prefix in ipairs(COMBOS) do keys[i] = prefix .. base end
    return keys
end

-- Same calls Blizzard's own keybinding panels make, in every client: a binding
-- lives in its action's context, and the change is saved to the active set
-- (account or character).
local function BindingContext(action)
    return C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and C_KeyBindings.GetBindingContextForAction(action)
end

local function ClearKey(key)
    local action = GetBindingAction(key)
    if not action or action == "" then return nil end
    local context = BindingContext(action)
    SetBinding(key, nil, context)
    SaveBindings(GetCurrentBindingSet())
    return action, context
end

local function RestoreKey(key, action, context)
    SetBinding(key, action, context)
    SaveBindings(GetCurrentBindingSet())
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
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
        if self.window then self.window:Hide() end
    end)
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
function KeyCheckClear:Toggle()
    if self.window then
        self.window:Hide() -- OnClose releases it
    elseif InCombatLockdown() then
        self:Print("Not available in combat.")
    else
        self:OpenWindow()
    end
end

-- keys yellow, then the status by color: green free, red bound, orange addon override
local function Key(s) return "|cffffd100" .. s .. "|r" end
local function Grey(s) return "|cff999999" .. s .. "|r" end
local function Bound(s) return "|cffff4040" .. s .. "|r" end
local FREE = "|cff40ff40Free|r"

local function KeyText(key)
    return GetBindingText and GetBindingText(key) or key
end

-- An addon override is what the key actually does right now, so it wins;
-- whatever it hides underneath doesn't matter for "is this key free?"
local function StatusText(base, override, undo)
    if undo then
        return FREE .. " " .. Grey("(was " .. ActionName(undo.action) .. ")")
    elseif override then
        return "|cffff8040" .. override .. "|r " .. Grey("(addon)")
    elseif base then
        return Bound(base)
    end
    return FREE
end

local function Cell(row, text, relWidth)
    local l = AceGUI:Create("Label")
    l:SetFontObject(GameFontHighlight)
    l:SetText(text)
    l:SetRelativeWidth(relWidth)
    row:AddChild(l)
end

-- an unconstrained FontString in the table font: its width is the text's width on one line
local measure
local function TextWidth(text)
    if not measure then
        measure = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringWidth()
end

local MIN_WIDTH, MIN_HEIGHT = 300, 400 -- the window's own resize bounds
local MAX_AUTO_WIDTH = 700             -- past this a huge macro name wraps instead
local CHROME = 70                      -- window borders + Results box + cell padding

-- a small clickable icon; with no image it is an empty cell that keeps rows even
local function IconCell(row, image, tip, onClick)
    local i = AceGUI:Create("Icon")
    i:SetImage(image)
    i:SetImageSize(ICON_SIZE, ICON_SIZE)
    i:SetRelativeWidth(0.08)
    i:SetDisabled(not image)
    if image then
        i:SetCallback("OnClick", onClick)
        i:SetCallback("OnEnter", function(widget)
            GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end)
        i:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end
    row:AddChild(i)
end

-- Result table: one row per checked key in three columns - key, what it does, and
-- (with "Show clear buttons" ticked) an X that clears a base binding. The key
-- cleared last gets an undo arrow instead. An addon override gets no X: that
-- binding belongs to the other addon.
local KEY_COL = 0.36

function KeyCheckClear:RenderResult()
    local keys = self.resultKeys
    local clearMode = self.db.profile.clearMode
    local icons = clearMode or self.undo ~= nil
    local actionCol = icons and 0.54 or 0.62

    -- 1. what each row says
    local rows = {}
    if keys then
        rows[1] = { key = Grey("Key"), status = Grey("Bound to") }
        for _, k in ipairs(keys) do
            local base, override = Lookup(k)
            local undo = self.undo and self.undo.key == k and not base and not override and self.undo
            local row = { key = Key(KeyText(k)), status = StatusText(base, override, undo) }
            if undo then
                row.icon, row.tip = UNDO_ICON, "Undo: rebind to " .. ActionName(undo.action)
                row.onClick = function() self:Undo() end
            elseif clearMode and base and not override then
                row.icon, row.tip = CLEAR_ICON, "Clear this binding"
                row.onClick = function() self:Clear(k) end
            end
            rows[#rows + 1] = row
        end
    end

    -- 2. size the window: grow it (never shrink) until the widest cell fits its column
    --    on one line, and don't let it be dragged narrower than that
    local need = 0
    for _, row in ipairs(rows) do
        need = math.max(need, TextWidth(row.key) / KEY_COL, TextWidth(row.status) / actionCol)
    end
    local minWidth = math.min(MAX_AUTO_WIDTH, math.max(MIN_WIDTH, math.ceil(need) + CHROME))
    local window = self.window
    if window.frame:GetWidth() < minWidth then
        window:SetWidth(minWidth)
    end

    -- 3. draw
    local list = self.widgets.list
    list:PauseLayout()
    list:ReleaseChildren()
    local function Row()
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        list:AddChild(row)
        return row
    end
    if not keys then
        Cell(Row(), NONE, 1)
    end
    for i, r in ipairs(rows) do
        local row = Row()
        Cell(row, r.key, KEY_COL)
        Cell(row, r.status, actionCol)
        if r.icon then
            IconCell(row, r.icon, r.tip, r.onClick)
        elseif icons and i > 1 then
            IconCell(row)
        end
        if i == 1 then
            local rule = AceGUI:Create("Heading") -- an empty Heading is one unbroken line
            rule:SetFullWidth(true)
            rule:SetHeight(8)
            list:AddChild(rule)
        end
    end
    list:ResumeLayout()
    window:DoLayout() -- lays out the rows at the window's width; the window then fits its height to them

    -- width can be dragged wider but not narrower than the table needs;
    -- height is whatever the content takes, so it can't be dragged at all
    local height = window.frame:GetHeight()
    window.frame:SetResizeBounds(minWidth, height, UIParent:GetWidth(), height)
end

-- One key normally; with "Display all modifier combos" ticked, all 8 combos of its
-- base key, in COMBOS order.
function KeyCheckClear:ShowResult(key)
    self.resultKeys = self.db.profile.allCombos and CombosOf(key) or { key }
    self.undo = nil
    self:RenderResult()
end

function KeyCheckClear:Clear(key)
    if InCombatLockdown() then return end
    local action, context = ClearKey(key)
    if not action then return end
    self.undo = { key = key, action = action, context = context }
    self:RenderResult()
end

function KeyCheckClear:Undo()
    local u = self.undo
    if not u or InCombatLockdown() then return end
    RestoreKey(u.key, u.action, u.context)
    self.undo = nil
    self:RenderResult()
end

local BUTTON_WIDTH = 180 -- the key button; the tick boxes line up on its left edge

local function Divider(parent)
    local h = AceGUI:Create("Heading") -- an empty Heading is one unbroken line
    h:SetFullWidth(true)
    parent:AddChild(h)
end

-- a tick box sized to its own label, so its box can sit on the button's left edge
local function CheckBox(parent, label, value, onChange)
    local c = AceGUI:Create("CheckBox")
    c:SetLabel(label)
    c:SetValue(value)
    c:SetWidth(24 + c.text:GetStringWidth() + 8)
    c:SetUserData("cell", { colspan = 2 }) -- starts at the button column, may run past it
    c:SetCallback("OnValueChanged", function(_, _, v) onChange(v and true or false) end)
    parent:AddChild(c)
end

local function EmptyCell(parent)
    local e = AceGUI:Create("Label")
    e:SetWidth(1)
    parent:AddChild(e)
end

function KeyCheckClear:OpenWindow()
    local frame = AceGUI:Create("KeyCheckClearWindow")
    frame:SetTitle("KeyCheckClear")
    frame:SetLayout("Flow")
    frame:SetStatusTable(self.db.profile.window) -- size and position persist through AceDB
    frame:SetBgAlpha(self.db.profile.bgAlpha)
    self.window = frame

    -- Escape closes the window while not listening (listening swallows Esc itself)
    _G.KeyCheckClearFrame = frame.frame
    if not self.specialFrameAdded then
        tinsert(UISpecialFrames, "KeyCheckClearFrame")
        self.specialFrameAdded = true
    end

    local w = {}
    self.widgets = w
    frame:PauseLayout()

    Divider(frame)

    local help = AceGUI:Create("Label")
    help:SetFontObject(GameFontHighlight)
    help:SetText(HELP)
    help:SetJustifyH("CENTER")
    help:SetFullWidth(true)
    frame:AddChild(help)

    local gap = AceGUI:Create("Label") -- one blank line
    gap:SetFontObject(GameFontHighlight)
    gap:SetText(" ")
    gap:SetFullWidth(true)
    frame:AddChild(gap)

    -- The controls, centered on the window: equal side columns center the button's
    -- column; each tick box starts at that column's left edge.
    local controls = AceGUI:Create("SimpleGroup")
    controls:SetFullWidth(true)
    controls:SetLayout("Table")
    controls:SetUserData("table", { columns = { { weight = 1 }, { width = BUTTON_WIDTH }, { weight = 1 } }, spaceV = 4 })
    frame:AddChild(controls)

    EmptyCell(controls)
    CheckBox(controls, "Display all modifier combos", self.db.profile.allCombos, function(v)
        self.db.profile.allCombos = v
    end)
    EmptyCell(controls)
    CheckBox(controls, "Show clear buttons", self.db.profile.clearMode, function(v)
        self.db.profile.clearMode = v
        self:RenderResult()
    end)

    EmptyCell(controls)
    local kb = AceGUI:Create("KeyCheckClearKeyButton")
    kb:SetWidth(BUTTON_WIDTH)
    kb:SetCallback("OnKeyChanged", function(_, _, key)
        if key and key ~= "" then self:ShowResult(key) end
    end)
    controls:AddChild(kb)
    EmptyCell(controls)

    -- sized to its own text so the table can center it under the button
    local note = AceGUI:Create("Label")
    note:SetFontObject(GameFontHighlight)
    note:SetText(LISTEN_NOTE)
    note:SetWidth(TextWidth(LISTEN_NOTE) + 4)
    note:SetUserData("cell", { colspan = 3, alignH = "middle" })
    controls:AddChild(note)

    Divider(frame)

    w.list = AceGUI:Create("InlineGroup")
    w.list:SetTitle("Results")
    w.list:SetFullWidth(true)
    w.list:SetLayout("List")
    frame:AddChild(w.list)

    frame:ResumeLayout()
    self:RenderResult()

    frame:SetCallback("OnClose", function(widget)
        self.resultKeys, self.undo = nil, nil
        widget.frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT) -- pooled frame goes back at its stock bounds
        _G.KeyCheckClearFrame = nil
        self.window, self.widgets = nil, nil
        AceGUI:Release(widget)
    end)
end
