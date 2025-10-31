-- https://forum.cfx.re/t/how-to-advanced-registerkeymapping-with-nuifocus-in-true/4778790
local COMMAND_HASH <const> = 0x94A9125A
local SPECIAL_KEYCODES <const> = {
    ['b_116'] = 'WheelMouseMove.Up',
    ['b_115'] = 'WheelMouseMove.Up',
    ['b_100'] = 'MouseClick.LeftClick',
    ['b_101'] = 'MouseClick.RightClick',
    ['b_102'] = 'MouseClick.MiddleClick',
    ['b_103'] = 'MouseClick.ExtraBtn1',
    ['b_104'] = 'MouseClick.ExtraBtn2',
    ['b_105'] = 'MouseClick.ExtraBtn3',
    ['b_106'] = 'MouseClick.ExtraBtn4',
    ['b_107'] = 'MouseClick.ExtraBtn5',
    ['b_108'] = 'MouseClick.ExtraBtn6',
    ['b_109'] = 'MouseClick.ExtraBtn7',
    ['b_110'] = 'MouseClick.ExtraBtn8',
    ['b_1015'] = 'AltLeft',
    ['b_1000'] = 'ShiftLeft',
    ['b_2000'] = 'Space',
    ['b_1013'] = 'ControlLeft',
    ['b_1002'] = 'Tab',
    ['b_1014'] = 'ControlRight',
    ['b_140'] = 'Numpad4',
    ['b_142'] = 'Numpad6',
    ['b_144'] = 'Numpad8',
    ['b_141'] = 'Numpad5',
    ['b_143'] = 'Numpad7',
    ['b_145'] = 'Numpad9',
    ['b_200'] = 'Insert',
    ['b_1012'] = 'CapsLock',
    ['b_170'] = 'F1',
    ['b_171'] = 'F2',
    ['b_172'] = 'F3',
    ['b_173'] = 'F4',
    ['b_174'] = 'F5',
    ['b_175'] = 'F6',
    ['b_176'] = 'F7',
    ['b_177'] = 'F8',
    ['b_178'] = 'F9',
    ['b_179'] = 'F10',
    ['b_180'] = 'F11',
    ['b_181'] = 'F12',
    ['b_194'] = 'ArrowUp',
    ['b_195'] = 'ArrowDown',
    ['b_196'] = 'ArrowLeft',
    ['b_197'] = 'ArrowRight',
    ['b_1003'] = 'Enter',
    ['b_1004'] = 'Backspace',
    ['b_198'] = 'Delete',
    ['b_199'] = 'Escape',
    ['b_1009'] = 'PageUp',
    ['b_1010'] = 'PageDown',
    ['b_1008'] = 'Home',
    ['b_131'] = 'NumpadAdd',
    ['b_130'] = 'NumpadSubstract',
    ['b_211'] = 'Insert',
    ['b_210'] = 'Delete',
    ['b_212'] = 'End',
    ['b_1055'] = 'Home',
    ['b_1056'] = 'PageUp',
}

Keybinds = {}

local function getKeyName()
    return GetControlInstructionalButton(2, COMMAND_HASH, true)
end

---@param key string
---@return string
local function translateKey(key)
    if (string.find(key, "t_")) then
        return (string.gsub(key, "t_", ""))
    else
        return SPECIAL_KEYCODES[key]
    end
end

function Keybinds.GetName()
    return translateKey(getKeyName())
end
