--[[
    Resto4Life - Core/ProfileManager.lua
    Profilverwaltung pro Charakter sowie Im- und Exportfunktionalität
--]]

local _, R4L = ...
local L = R4L.L

R4L.ProfileManager = {}
local PM = R4L.ProfileManager

-- Deep Copy Hilfsfunktion
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge defaults in bestehende Tabelle
local function mergeDefaults(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then
                dest[k] = {}
            end
            mergeDefaults(dest[k], v)
        else
            if dest[k] == nil then
                dest[k] = v
            end
        end
    end
end

-- Reines Lua Base64 Kodieren/Dekodieren (ohne externe Abhängigkeiten)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, 64 do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function toBase64(data)
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function fromBase64(data)
    data = string.gsub(data, '[^A-Za-z0-9%+/=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local val = b64lookup[x]
        if not val then return '' end
        local r = ''
        for i = 6, 1, -1 do r = r .. (val % 2^i - val % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- Einfache sichere Lua-Tabellen Serialisierung
local function serializeTable(val, name)
    local tmp = ""
    if type(val) == "table" then
        tmp = tmp .. "{"
        for k, v in pairs(val) do
            local keyStr
            if type(k) == "number" then
                keyStr = "[" .. k .. "]="
            else
                keyStr = "[" .. string.format("%q", tostring(k)) .. "]="
            end
            tmp = tmp .. keyStr .. serializeTable(v) .. ","
        end
        tmp = tmp .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "nil"
    end
    return tmp
end

-- Zaubernamen aus Spell-ID lokalisieren (funktioniert auf DE, EN, FR, ES, etc.)
local function ResolveSpellName(val)
    if type(val) == "number" then
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(val)
            if info and info.name then return info.name end
        elseif GetSpellInfo then
            local name = GetSpellInfo(val)
            if name then return name end
        end
    end
    return val
end

function PM:Initialize()
    -- Global DB
    if not Resto4LifeDB then
        Resto4LifeDB = {
            profiles = {}
        }
    end

    -- Per Character DB
    local isFirstRun = false
    if not Resto4LifeCharDB or not Resto4LifeCharDB.version then
        Resto4LifeCharDB = deepCopy(R4L.Config.Defaults)
        isFirstRun = true
    else
        mergeDefaults(Resto4LifeCharDB, R4L.Config.Defaults)
    end

    -- Klassen-Defaults anwenden, falls erster Start dieses Chars
    local _, playerClass = UnitClass("player")
    if isFirstRun and playerClass and R4L.Config.ClassDefaults[playerClass] then
        local cDef = R4L.Config.ClassDefaults[playerClass]
        if cDef.smartRez then
            local sRez = deepCopy(cDef.smartRez)
            if sRez.combatRezSpell then sRez.combatRezSpell = ResolveSpellName(sRez.combatRezSpell) end
            if sRez.normalRezSpell then sRez.normalRezSpell = ResolveSpellName(sRez.normalRezSpell) end
            mergeDefaults(Resto4LifeCharDB.smartRez, sRez)
        end
        if cDef.bindings then
            for k, v in pairs(cDef.bindings) do
                local copyB = deepCopy(v)
                if copyB.spell then copyB.spell = ResolveSpellName(copyB.spell) end
                Resto4LifeCharDB.bindings[k] = copyB
            end
        end
    end

    R4L.db = Resto4LifeCharDB
end

function PM:GetConfig()
    return R4L.db or Resto4LifeCharDB or R4L.Config.Defaults
end

function PM:ResetToDefaults()
    Resto4LifeCharDB = deepCopy(R4L.Config.Defaults)
    local _, playerClass = UnitClass("player")
    if playerClass and R4L.Config.ClassDefaults[playerClass] then
        local cDef = R4L.Config.ClassDefaults[playerClass]
        if cDef.smartRez then
            local sRez = deepCopy(cDef.smartRez)
            if sRez.combatRezSpell then sRez.combatRezSpell = ResolveSpellName(sRez.combatRezSpell) end
            if sRez.normalRezSpell then sRez.normalRezSpell = ResolveSpellName(sRez.normalRezSpell) end
            mergeDefaults(Resto4LifeCharDB.smartRez, sRez)
        end
        if cDef.bindings then
            for k, v in pairs(cDef.bindings) do
                local copyB = deepCopy(v)
                if copyB.spell then copyB.spell = ResolveSpellName(copyB.spell) end
                Resto4LifeCharDB.bindings[k] = copyB
            end
        end
    end
    R4L.db = Resto4LifeCharDB
    R4L:Print(L["CHAT_DEFAULTS_RESET"])
    if R4L.GroupHeader then
        R4L.GroupHeader:UpdateLayout()
        R4L.GroupHeader:UpdateAllFrames()
    end
    if R4L.RaidHeader then
        R4L.RaidHeader:UpdateLayout()
        R4L.RaidHeader:UpdateAllFrames()
    end
    if R4L.ClickCast then
        R4L.ClickCast:ApplyAllBindings()
    end
end


-- Exportiert die Einstellungen als Zeichenfolge
function PM:ExportProfileString()
    local cfg = self:GetConfig()
    local serialized = "return " .. serializeTable(cfg)
    local encoded = toBase64(serialized)
    return "R4L:" .. encoded
end

-- Importiert Einstellungen aus einer Zeichenfolge
function PM:ImportProfileString(str)
    if not str or type(str) ~= "string" then
        return false, L["ERR_INVALID_CODE"]
    end

    str = string.trim(str)
    if not string.find(str, "^R4L:") then
        return false, L["ERR_INVALID_CODE"]
    end

    local b64 = string.sub(str, 5)
    local decoded = fromBase64(b64)
    if not decoded or decoded == "" then
        return false, L["ERR_INVALID_CODE"]
    end

    -- Sicheres Parsen der Lua-Tabelle
    local func, loadErr = loadstring(decoded)
    if not func then
        return false, L["ERR_INVALID_CODE"]
    end

    -- Sandbox-Ausführung zur Sicherheit
    setfenv(func, {})
    local success, importedConfig = pcall(func)
    if not success or type(importedConfig) ~= "table" then
        return false, L["ERR_INVALID_CODE"]
    end

    -- Validiere und wende an
    mergeDefaults(importedConfig, R4L.Config.Defaults)
    Resto4LifeCharDB = importedConfig
    R4L.db = Resto4LifeCharDB

    if R4L.GroupHeader then
        R4L.GroupHeader:UpdateLayout()
        R4L.GroupHeader:UpdateAllFrames()
    end
    if R4L.RaidHeader then
        R4L.RaidHeader:UpdateLayout()
        R4L.RaidHeader:UpdateAllFrames()
    end
    if R4L.ClickCast then
        R4L.ClickCast:ApplyAllBindings()
    end

    return true, L["PROFILE_IMPORTED"]

end

R4L:RegisterEvent("ADDON_LOADED", function(event, loadedAddon)
    if loadedAddon == R4L.addonName then
        PM:Initialize()
        R4L:Print(string.format(L["LOADED_MSG_FMT"], R4L.version))
    end
end)
