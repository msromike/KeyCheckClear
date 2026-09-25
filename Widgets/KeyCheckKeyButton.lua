--[[-----------------------------------------------------------------------------
KeyCheckKeyButton Widget
KeyCheck's own key-capture button, adapted from AceGUI's Keybinding widget
(Libs/AceGUI-3.0/widgets/AceGUIWidget-Keybinding.lua). A large, roughly square
Blizzard button: click it, press a key, and it fires OnKeyChanged(key). It only
ever shows its idle hint or "Waiting for input", never the key, and has no
floating popup. Private type, so nothing here is shared through AceGUI's widget pool.
-------------------------------------------------------------------------------]]
local Type, Version = "KeyCheckKeyButton", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs = pairs
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
local CreateFrame, UIParent = CreateFrame, UIParent

local IDLE_TEXT = "Click here, then press a key"
local LISTEN_TEXT = "Waiting for input"

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function SetListening(self, on)
    local button = self.button
    button:EnableKeyboard(on)
    button:EnableMouseWheel(on)
    if button.EnableGamePadButton then button:EnableGamePadButton(on) end
    if on then
        button:LockHighlight()
        button:SetText(LISTEN_TEXT)
    else
        button:UnlockHighlight()
        button:SetText(IDLE_TEXT)
    end
    self.waitingForKey = on or nil
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Control_OnEnter(frame)
    frame.obj:Fire("OnEnter")
end

local function Control_OnLeave(frame)
    frame.obj:Fire("OnLeave")
end

local function KeyButton_OnClick(frame, button)
    if button == "LeftButton" or button == "RightButton" then
        local self = frame.obj
        if not self.disabled then
            SetListening(self, not self.waitingForKey)
        end
    end
    AceGUI:ClearFocus()
end

local ignoreKeys = {
    ["BUTTON1"] = true, ["BUTTON2"] = true,
    ["UNKNOWN"] = true,
    ["LSHIFT"] = true, ["LCTRL"] = true, ["LALT"] = true,
    ["RSHIFT"] = true, ["RCTRL"] = true, ["RALT"] = true,
}

local function KeyButton_OnKeyDown(frame, key)
    local self = frame.obj
    if not self.waitingForKey then return end
    local keyPressed = key
    if keyPressed == "ESCAPE" then
        keyPressed = ""
    else
        if ignoreKeys[keyPressed] then return end
        -- prepended in this order so the result reads ALT-CTRL-SHIFT-KEY
        if IsShiftKeyDown() then keyPressed = "SHIFT-" .. keyPressed end
        if IsControlKeyDown() then keyPressed = "CTRL-" .. keyPressed end
        if IsAltKeyDown() then keyPressed = "ALT-" .. keyPressed end
    end

    SetListening(self, false)
    if not self.disabled then
        self:Fire("OnKeyChanged", keyPressed)
    end
end

local function KeyButton_OnMouseDown(frame, button)
    if button == "LeftButton" or button == "RightButton" then
        return
    elseif button == "MiddleButton" then
        button = "BUTTON3"
    elseif button == "Button4" then
        button = "BUTTON4"
    elseif button == "Button5" then
        button = "BUTTON5"
    end
    KeyButton_OnKeyDown(frame, button)
end

local function KeyButton_OnMouseWheel(frame, direction)
    KeyButton_OnKeyDown(frame, direction >= 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetWidth(180)
        self:SetHeight(64)
        self:SetDisabled(false)
        SetListening(self, false)
    end,

    ["OnRelease"] = function(self)
        SetListening(self, false)
    end,

    -- The text is laid out once, before the button has a size, so the first display
    -- truncated with "..." until a click re-set it. Give it an explicit width and
    -- re-apply the text whenever the width changes so it wraps from the start.
    ["OnWidthSet"] = function(self, width)
        local text = self.button:GetFontString()
        text:SetWidth(width - 16)
        local current = self.button:GetText()
        self.button:SetText("")
        self.button:SetText(current)
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.button:Disable()
        else
            self.button:Enable()
        end
    end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local name = "KeyCheckKeyButton" .. AceGUI:GetNextWidgetNum(Type)

    local frame = CreateFrame("Frame", nil, UIParent)
    local button = CreateFrame("Button", name, frame, "UIPanelButtonTemplate")

    button:EnableMouse(true)
    button:EnableMouseWheel(false)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnEnter", Control_OnEnter)
    button:SetScript("OnLeave", Control_OnLeave)
    button:SetScript("OnClick", KeyButton_OnClick)
    button:SetScript("OnKeyDown", KeyButton_OnKeyDown)
    button:SetScript("OnMouseDown", KeyButton_OnMouseDown)
    button:SetScript("OnMouseWheel", KeyButton_OnMouseWheel)
    if button.EnableGamePadButton then
        button:SetScript("OnGamePadButtonDown", KeyButton_OnKeyDown)
        button:EnableGamePadButton(false)
    end
    button:SetAllPoints(frame)
    button:EnableKeyboard(false)
    button:SetNormalFontObject("GameFontHighlightLarge")
    button:SetHighlightFontObject("GameFontHighlightLarge")

    -- wrap the listening prompt inside the button instead of truncating it
    button:SetText(IDLE_TEXT)
    local text = button:GetFontString()
    text:ClearAllPoints()
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetWordWrap(true)
    text:SetJustifyH("CENTER")

    local widget = {
        button = button,
        frame  = frame,
        type   = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    button.obj = widget

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
