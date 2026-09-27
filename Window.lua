-- Window: builds the KeyCheckClear window and its controls. The Results module
-- fills the "Results" box.

local KeyCheckClear = LibStub("AceAddon-3.0"):GetAddon("KeyCheckClear")
local Window = KeyCheckClear:NewModule("Window")
local AceGUI = LibStub("AceGUI-3.0")

local HELP = "Hover over the button.\nThen press any key or key combo."
local LISTEN_NOTE = "Move mouse to stop listening"
local BUTTON_WIDTH = 180 -- the key button; the tick boxes line up on its left edge

Window.MIN_WIDTH, Window.MIN_HEIGHT = 300, 400 -- the window's own resize bounds

function Window:IsOpen()
    return self.frame ~= nil
end

function Window:Close()
    if self.frame then self.frame:Hide() end -- OnClose releases it
end

-- an unconstrained FontString in the table font: its width is the text's width on one line
local measure
function Window:TextWidth(text)
    if not measure then
        measure = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringWidth()
end

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

function Window:Open()
    local db = KeyCheckClear.db.profile
    local Results = KeyCheckClear:GetModule("Results")

    local frame = AceGUI:Create("KeyCheckClearWindow")
    frame:SetTitle("KeyCheckClear")
    frame:SetLayout("Flow")
    frame:SetStatusTable(db.window) -- size and position persist through AceDB
    frame:SetBgAlpha(db.bgAlpha)
    self.frame = frame

    -- Escape closes the window while not listening (listening swallows Esc itself)
    _G.KeyCheckClearFrame = frame.frame
    if not self.specialFrameAdded then
        tinsert(UISpecialFrames, "KeyCheckClearFrame")
        self.specialFrameAdded = true
    end

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
    CheckBox(controls, "Display all modifier combos", db.allCombos, function(v)
        db.allCombos = v
    end)
    EmptyCell(controls)
    CheckBox(controls, "Show clear buttons", db.clearMode, function(v)
        db.clearMode = v
        Results:Render()
    end)

    EmptyCell(controls)
    local kb = AceGUI:Create("KeyCheckClearKeyButton")
    kb:SetWidth(BUTTON_WIDTH)
    kb:SetCallback("OnKeyChanged", function(_, _, key)
        if key and key ~= "" then Results:Show(key) end
    end)
    controls:AddChild(kb)
    EmptyCell(controls)

    -- sized to its own text so the table can center it under the button
    local note = AceGUI:Create("Label")
    note:SetFontObject(GameFontHighlight)
    note:SetText(LISTEN_NOTE)
    note:SetWidth(self:TextWidth(LISTEN_NOTE) + 4)
    note:SetUserData("cell", { colspan = 3, alignH = "middle" })
    controls:AddChild(note)

    Divider(frame)

    self.list = AceGUI:Create("InlineGroup")
    self.list:SetTitle("Results")
    self.list:SetFullWidth(true)
    self.list:SetLayout("List")
    frame:AddChild(self.list)

    frame:ResumeLayout()
    Results:Render()

    frame:SetCallback("OnClose", function(widget)
        Results:Reset()
        widget.frame:SetResizeBounds(Window.MIN_WIDTH, Window.MIN_HEIGHT) -- pooled frame goes back at its stock bounds
        _G.KeyCheckClearFrame = nil
        self.frame, self.list = nil, nil
        AceGUI:Release(widget)
    end)
end
