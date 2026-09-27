-- Results: the table under "Results" - one row per checked key, and the clear /
-- undo icons on those rows. Also grows the window so no row wraps.

local KeyCheckClear = LibStub("AceAddon-3.0"):GetAddon("KeyCheckClear")
local Results = KeyCheckClear:NewModule("Results")
local AceGUI = LibStub("AceGUI-3.0")

local NONE = "|cff999999Nothing checked yet|r"
local CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" -- red X, in every client's UI
local UNDO_ICON = "Interface\\Buttons\\UI-RefreshButton"      -- circular arrow, same
local ICON_SIZE = 16

local KEY_COL = 0.36           -- column shares of the row width
local MAX_AUTO_WIDTH = 700     -- past this a huge macro name wraps instead
local CHROME = 70              -- window borders + Results box + cell padding

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
    local Bindings = KeyCheckClear:GetModule("Bindings")
    if undo then
        return FREE .. " " .. Grey("(was " .. Bindings:ActionName(undo.action) .. ")")
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
function Results:Render()
    local Window = KeyCheckClear:GetModule("Window")
    local Bindings = KeyCheckClear:GetModule("Bindings")
    local keys = self.resultKeys
    local clearMode = KeyCheckClear.db.profile.clearMode
    local icons = clearMode or self.undo ~= nil
    local actionCol = icons and 0.54 or 0.62

    -- 1. what each row says
    local rows = {}
    if keys then
        rows[1] = { key = Grey("Key"), status = Grey("Bound to") }
        for _, k in ipairs(keys) do
            local base, override = Bindings:Lookup(k)
            local undo = self.undo and self.undo.key == k and not base and not override and self.undo
            local row = { key = Key(KeyText(k)), status = StatusText(base, override, undo) }
            if undo then
                row.icon, row.tip = UNDO_ICON, "Undo: rebind to " .. Bindings:ActionName(undo.action)
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
        need = math.max(need, Window:TextWidth(row.key) / KEY_COL, Window:TextWidth(row.status) / actionCol)
    end
    local minWidth = math.min(MAX_AUTO_WIDTH, math.max(Window.MIN_WIDTH, math.ceil(need) + CHROME))
    local window = Window.frame
    if window.frame:GetWidth() < minWidth then
        window:SetWidth(minWidth)
    end

    -- 3. draw
    local list = Window.list
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
function Results:Show(key)
    local Bindings = KeyCheckClear:GetModule("Bindings")
    self.resultKeys = KeyCheckClear.db.profile.allCombos and Bindings:CombosOf(key) or { key }
    self.undo = nil
    self:Render()
end

function Results:Clear(key)
    if InCombatLockdown() then return end
    local action, context = KeyCheckClear:GetModule("Bindings"):Clear(key)
    if not action then return end
    self.undo = { key = key, action = action, context = context }
    self:Render()
end

function Results:Undo()
    local u = self.undo
    if not u or InCombatLockdown() then return end
    KeyCheckClear:GetModule("Bindings"):Restore(u.key, u.action, u.context)
    self.undo = nil
    self:Render()
end

-- the window closed: nothing checked any more
function Results:Reset()
    self.resultKeys, self.undo = nil, nil
end
