-- Bindings: everything that reads or writes the game's key bindings. No UI.

local KeyCheckClear = LibStub("AceAddon-3.0"):GetAddon("KeyCheckClear")
local Bindings = KeyCheckClear:NewModule("Bindings")

-- Friendly name for a binding action: the BINDING_NAME_ global if the action
-- registered one, otherwise the raw action (CLICK Foo:LeftButton, MACRO x, SPELL x...)
function Bindings:ActionName(action)
    if not action or action == "" then return nil end
    return _G["BINDING_NAME_" .. action] or action
end

-- GetBindingAction(key) answers the base binding only; addons that bind through
-- SetOverrideBinding* (e.g. the EllesmereUI damage meter hotkeys) show up only
-- with the second argument. If this client ignores it, both answers match.
function Bindings:Lookup(key)
    local base = self:ActionName(GetBindingAction(key))
    local override = self:ActionName(GetBindingAction(key, true))
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

function Bindings:CombosOf(key)
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

-- Unbinds the key. Returns what it was bound to (and its context) so Restore can undo it.
function Bindings:Clear(key)
    local action = GetBindingAction(key)
    if not action or action == "" then return nil end
    local context = BindingContext(action)
    SetBinding(key, nil, context)
    SaveBindings(GetCurrentBindingSet())
    return action, context
end

function Bindings:Restore(key, action, context)
    SetBinding(key, action, context)
    SaveBindings(GetCurrentBindingSet())
end
