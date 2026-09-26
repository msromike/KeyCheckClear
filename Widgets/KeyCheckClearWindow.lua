--[[-----------------------------------------------------------------------------
KeyCheckClearWindow Container
KeyCheckClear's own window type, adapted from AceGUI's Frame container
(Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua), Copyright (c) 2007,
Ace3 Development Team, BSD-style license. Private type, so nothing
here is shared with other addons through AceGUI's widget pool.
Differences from Frame: X close button, no status bar, centered Close button,
and a solid background whose opacity is set with SetBgAlpha (the stock
UI-DialogBox-Background texture is itself translucent, so it never reaches black).
-------------------------------------------------------------------------------]]
local Type, Version = "KeyCheckClearWindow", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, assert, type = pairs, assert, type
local wipe = table.wipe
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Close_OnClick(frame)
    PlaySound(799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
    frame.obj:Hide()
end

local function Frame_OnShow(frame)
    frame.obj:Fire("OnShow")
end

local function Frame_OnClose(frame)
    frame.obj:Fire("OnClose")
end

local function Frame_OnMouseDown(frame)
    AceGUI:ClearFocus()
end

local function Title_OnMouseDown(frame)
    frame:GetParent():StartMoving()
    AceGUI:ClearFocus()
end

local function MoverSizer_OnMouseUp(mover)
    local frame = mover:GetParent()
    frame:StopMovingOrSizing()
    local self = frame.obj
    local status = self.status or self.localstatus
    status.width = frame:GetWidth()
    status.height = frame:GetHeight()
    status.top = frame:GetTop()
    status.left = frame:GetLeft()
end

local function SizerSE_OnMouseDown(frame)
    frame:GetParent():StartSizing("BOTTOMRIGHT")
    AceGUI:ClearFocus()
end

local function SizerS_OnMouseDown(frame)
    frame:GetParent():StartSizing("BOTTOM")
    AceGUI:ClearFocus()
end

local function SizerE_OnMouseDown(frame)
    frame:GetParent():StartSizing("RIGHT")
    AceGUI:ClearFocus()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self.frame:SetParent(UIParent)
        self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
        self.frame:SetFrameLevel(100)
        self:SetTitle()
        self:SetBgAlpha(1)
        self:ApplyStatus()
        self:Show()
    end,

    ["OnRelease"] = function(self)
        self.status = nil
        wipe(self.localstatus)
    end,

    ["OnWidthSet"] = function(self, width)
        local content = self.content
        local contentwidth = width - 34
        if contentwidth < 0 then contentwidth = 0 end
        content:SetWidth(contentwidth)
        content.width = contentwidth
    end,

    ["OnHeightSet"] = function(self, height)
        local content = self.content
        local contentheight = height - 79
        if contentheight < 0 then contentheight = 0 end
        content:SetHeight(contentheight)
        content.height = contentheight
    end,

    -- the window is exactly as tall as its content: 79 = the content's top and bottom insets
    ["LayoutFinished"] = function(self, width, height)
        if height then
            self:SetHeight(height + 79)
        end
    end,

    ["SetTitle"] = function(self, title)
        self.titletext:SetText(title)
        self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
    end,

    -- 1 = solid black, 0 = fully transparent; the border always shows
    ["SetBgAlpha"] = function(self, alpha)
        self.frame:SetBackdropColor(0, 0, 0, alpha)
    end,

    ["Hide"] = function(self)
        self.frame:Hide()
    end,

    ["Show"] = function(self)
        self.frame:Show()
    end,

    ["SetStatusTable"] = function(self, status)
        assert(type(status) == "table")
        self.status = status
        self:ApplyStatus()
    end,

    ["ApplyStatus"] = function(self)
        local status = self.status or self.localstatus
        local frame = self.frame
        self:SetWidth(status.width or 380)
        self:SetHeight(status.height or 520)
        frame:ClearAllPoints()
        if status.top and status.left then
            frame:SetPoint("TOP", UIParent, "BOTTOM", 0, status.top)
            frame:SetPoint("LEFT", UIParent, "LEFT", status.left, 0)
        else
            frame:SetPoint("CENTER")
        end
    end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local FrameBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetBackdrop(FrameBackdrop)
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetResizeBounds(300, 400)
    frame:SetToplevel(true)
    frame:SetScript("OnShow", Frame_OnShow)
    frame:SetScript("OnHide", Frame_OnClose)
    frame:SetScript("OnMouseDown", Frame_OnMouseDown)

    local xbutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    xbutton:SetPoint("TOPRIGHT", -5, -5)
    xbutton:SetScript("OnClick", Close_OnClick)

    local closebutton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closebutton:SetScript("OnClick", Close_OnClick)
    closebutton:SetPoint("BOTTOM", 0, 17)
    closebutton:SetHeight(22)
    closebutton:SetWidth(100)
    closebutton:SetText(CLOSE)

    local titlebg = frame:CreateTexture(nil, "OVERLAY")
    titlebg:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
    titlebg:SetPoint("TOP", 0, 12)
    titlebg:SetWidth(100)
    titlebg:SetHeight(40)

    local title = CreateFrame("Frame", nil, frame)
    title:EnableMouse(true)
    title:SetScript("OnMouseDown", Title_OnMouseDown)
    title:SetScript("OnMouseUp", MoverSizer_OnMouseUp)
    title:SetAllPoints(titlebg)

    local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titletext:SetPoint("TOP", titlebg, "TOP", 0, -14)

    local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
    titlebg_l:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
    titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
    titlebg_l:SetWidth(30)
    titlebg_l:SetHeight(40)

    local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
    titlebg_r:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
    titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
    titlebg_r:SetWidth(30)
    titlebg_r:SetHeight(40)

    local sizer_se = CreateFrame("Frame", nil, frame)
    sizer_se:SetPoint("BOTTOMRIGHT")
    sizer_se:SetWidth(25)
    sizer_se:SetHeight(25)
    sizer_se:EnableMouse()
    sizer_se:SetScript("OnMouseDown", SizerSE_OnMouseDown)
    sizer_se:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

    local line1 = sizer_se:CreateTexture(nil, "BACKGROUND")
    line1:SetWidth(14)
    line1:SetHeight(14)
    line1:SetPoint("BOTTOMRIGHT", -8, 8)
    line1:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
    local x = 0.1 * 14/17
    line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

    local line2 = sizer_se:CreateTexture(nil, "BACKGROUND")
    line2:SetWidth(8)
    line2:SetHeight(8)
    line2:SetPoint("BOTTOMRIGHT", -8, 8)
    line2:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
    x = 0.1 * 8/17
    line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

    local sizer_s = CreateFrame("Frame", nil, frame)
    sizer_s:SetPoint("BOTTOMRIGHT", -25, 0)
    sizer_s:SetPoint("BOTTOMLEFT")
    sizer_s:SetHeight(25)
    sizer_s:EnableMouse(true)
    sizer_s:SetScript("OnMouseDown", SizerS_OnMouseDown)
    sizer_s:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

    local sizer_e = CreateFrame("Frame", nil, frame)
    sizer_e:SetPoint("BOTTOMRIGHT", 0, 25)
    sizer_e:SetPoint("TOPRIGHT", 0, -30) -- stop below the X button
    sizer_e:SetWidth(25)
    sizer_e:EnableMouse(true)
    sizer_e:SetScript("OnMouseDown", SizerE_OnMouseDown)
    sizer_e:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

    --Container Support
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 17, -35) -- clear of the title plate, which hangs 28 px into the frame
    content:SetPoint("BOTTOMRIGHT", -17, 44)

    local widget = {
        localstatus = {},
        titletext   = titletext,
        titlebg     = titlebg,
        content     = content,
        frame       = frame,
        type        = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    xbutton.obj, closebutton.obj = widget, widget

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
