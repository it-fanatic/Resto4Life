--[[
    Resto4Life - Engine/AuraTracker.lua
    Verfolgung von HoTs (Heal over Time) und reinigbaren Debuffs (Fluch, Gift, Krankheit, Magie)
--]]

local _, R4L = ...

R4L.AuraTracker = {}
local AT = R4L.AuraTracker

-- Standard Blizzard Debuff-Farben
AT.DebuffColors = {
    ["Curse"]   = { r = 0.6, g = 0.0, b = 1.0 }, -- Lila
    ["Poison"]  = { r = 0.0, g = 0.7, b = 0.1 }, -- Grün
    ["Disease"] = { r = 0.6, g = 0.4, b = 0.0 }, -- Braun
    ["Magic"]   = { r = 0.2, g = 0.6, b = 1.0 }, -- Blau
    ["None"]    = { r = 0.8, g = 0.1, b = 0.1 }, -- Rot (Physisch/Bleed)
}

-- Bestimme welche Debuffs die aktuelle Spieler-Klasse reinigen kann
function AT:GetDispelCapabilities()
    local _, playerClass = UnitClass("player")
    local dispels = {
        Curse = false,
        Poison = false,
        Disease = false,
        Magic = false,
    }

    if playerClass == "DRUID" then
        dispels.Curse = true
        dispels.Poison = true
        dispels.Magic = true -- Typischerweise als Heiler (Wiederherstellung)
    elseif playerClass == "PALADIN" then
        dispels.Poison = true
        dispels.Disease = true
        dispels.Magic = true -- Heilig
    elseif playerClass == "PRIEST" then
        dispels.Magic = true
        dispels.Disease = true
    elseif playerClass == "SHAMAN" then
        dispels.Curse = true
        dispels.Magic = true -- Wiederherstellung
    elseif playerClass == "MONK" then
        dispels.Poison = true
        dispels.Disease = true
        dispels.Magic = true -- Nebelwirker
    elseif playerClass == "MAGE" then
        dispels.Curse = true
    elseif playerClass == "EVOKER" then
        dispels.Poison = true
        dispels.Magic = true
        dispels.Curse = true -- Kauterisierende Flamme
    end

    return dispels
end

-- Helper zur Erkennung von geheimen Strings / Werten in WoW Forever & 12.0
local function IsSecret(val)
    if val == nil then return false end
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res then return true end
    end
    return false
end

-- Universeller Argument-Parser für UnitAura / UnitBuff (behandelt 3.3.5 & modernes Classic/Retail Format)
local function ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
    if a1 == nil then return nil end

    -- Erkennt ob Rückgabe das 3.3.5 / Classic-WotLK Format ist:
    -- In 3.3.5: Return 1 = name, Return 2 = rank (string z.B. "Rang 4" oder ""), Return 3 = icon (texture string oder FileID)
    -- In Modern: Return 1 = name, Return 2 = icon (FileID number oder texture path string)
    local isLegacy335 = false
    if type(a2) == "string" and not (a2:find("^Interface") or a2:find("^\\") or a2:find("^/")) then
        if type(a3) == "number" or (type(a3) == "string" and (a3:find("^Interface") or a3:find("^\\") or a3:find("^/"))) then
            isLegacy335 = true
        elseif a2 == "" or a2:find("Rang") or a2:find("Rank") then
            isLegacy335 = true
        end
    end

    local name = ""
    if not IsSecret(a1) and type(a1) == "string" then
        name = a1
    end

    if isLegacy335 then
        -- 3.3.5: name, rank, icon, count, dispelType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
        local caster = a8
        local isMine = false
        if caster and not IsSecret(caster) then
            local okP, isP = pcall(function() return caster == "player" or UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") end)
            if okP and isP then isMine = true end
        end
        local spellId = a11
        if (not name or name == "") and spellId then
            local sName = R4L:GetSpellName(spellId)
            if sName then name = sName end
        end
        return {
            name = name,
            rank = a2,
            icon = a3,
            count = (type(a4) == "number") and a4 or 0,
            dispelType = a5,
            duration = (type(a6) == "number") and a6 or 0,
            expirationTime = (type(a7) == "number") and a7 or 0,
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    else
        -- Modern: name, icon, count, dispelType, duration, expirationTime, sourceUnit, isStealable, nameplateShowPersonal, spellId
        local caster = a7
        local isMine = false
        if caster and not IsSecret(caster) then
            local okP, isP = pcall(function() return caster == "player" or UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") end)
            if okP and isP then isMine = true end
        end
        local spellId = a10
        if (not name or name == "") and spellId then
            local sName = R4L:GetSpellName(spellId)
            if sName then name = sName end
        end
        return {
            name = name,
            icon = a2,
            count = (type(a3) == "number") and a3 or 0,
            dispelType = a4,
            duration = (type(a5) == "number") and a5 or 0,
            expirationTime = (type(a6) == "number") and a6 or 0,
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    end
end

-- Universeller Aura-Zugriff für moderne Retail / Forever API (abgesichert gegen Secret Auras & Taint)
local function GetUnitAuraByIndex(unit, index, filter)
    if not unit then return nil end

    -- 1. Modern C_UnitAuras
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and data and type(data) == "table" then
            local name = ""
            if data.name and not IsSecret(data.name) then
                name = data.name
            end
            local spellId = data.spellId
            if (not name or name == "") and spellId then
                local sName = R4L:GetSpellName(spellId)
                if sName then name = sName end
            end
            return {
                name = name,
                icon = data.iconFileID or data.icon,
                count = data.applications or 0,
                dispelType = data.dispelName,
                duration = data.duration or 0,
                expirationTime = data.expirationTime or 0,
                sourceUnit = data.sourceUnit,
                sourceGUID = data.sourceGUID,
                spellId = spellId,
                isFromPlayerOrPlayerPet = data.isFromPlayerOrPlayerPet,
            }
        end
    end

    -- 2. Classic / Forever UnitAura mit Doppelformat-Prüfung (3.3.5 vs Modern)
    if UnitAura then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitAura, unit, index, filter)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    end

    -- 3. Älteres UnitBuff / UnitDebuff Fallback
    if filter == "HARMFUL" and UnitDebuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitDebuff, unit, index)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    elseif filter == "HELPFUL" and UnitBuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitBuff, unit, index)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    end

    return nil
end

-- Öffentlicher Zugriff auf GetUnitAuraByIndex für andere Module (z. B. BuffBar)
function AT:GetUnitAuraByIndex(unit, index, filter)
    return GetUnitAuraByIndex(unit, index, filter)
end

-- Prüft, ob eine Aura vom Spieler stammt (strikte Caster-Prüfung + Secret-Value Absicherung)
local function IsPlayerAura(aura, unit)
    if not aura then return false end

    -- 1. Blizzard Flag (C_UnitAuras)
    if aura.isFromPlayerOrPlayerPet == true then
        return true
    end

    -- 2. sourceUnit Prüfung (gesichert gegen Secret Values / Taint)
    local sUnit = aura.sourceUnit
    if sUnit and not IsSecret(sUnit) then
        local okP, isPl = pcall(function()
            return sUnit == "player" or UnitIsUnit(sUnit, "player") or UnitIsUnit(sUnit, "pet")
        end)
        if okP and isPl then
            return true
        end
    end

    -- 3. sourceGUID Prüfung (gesichert gegen Secret Values / Taint)
    local sGUID = aura.sourceGUID
    if sGUID and not IsSecret(sGUID) then
        local okG, isMatch = pcall(function()
            local pGUID = UnitGUID("player")
            return (pGUID and not IsSecret(pGUID) and sGUID == pGUID)
        end)
        if okG and isMatch then
            return true
        end
    end

    return false
end

-- HoT-Datenbanken nach Heiler-Klasse getrennt (verhindert Vermischung eigener & fremder HoTs)
local CLASS_HOTS = {
    DRUID = {
        [774] = true,    -- Verjüngung (Rejuvenation)
        [1058] = true, [1430] = true, [2090] = true, [2091] = true, [3627] = true, [8910] = true, [9839] = true, [9840] = true, [9841] = true, [25299] = true, [26981] = true, [26982] = true, [48440] = true, [48441] = true,
        [155777] = true, -- Verjüngung (Keimung / Germination)
        [8936] = true,   -- Nachwachsen (Regrowth)
        [8938] = true, [8939] = true, [8940] = true, [8941] = true, [9750] = true, [9856] = true, [9857] = true, [9858] = true, [26980] = true, [48442] = true, [48443] = true,
        [33763] = true,  -- Blühendes Leben (Lifebloom)
        [48450] = true, [48451] = true,
        [48438] = true,  -- Wildwuchs (Wild Growth)
        [53248] = true, [53249] = true, [53251] = true,
        [102351] = true, -- Cenarischer Zauberschutz (Cenarion Ward)
        [102352] = true, -- Cenarischer Zauberschutz HoT-Effekt
        [207386] = true, -- Frühlingsblüten (Spring Blossoms)
        [200389] = true, -- Kultivierung (Cultivation)
        [325748] = true, -- Adaptiver Schwarm (Adaptive Swarm)
        [157982] = true, -- Gelassenheit (Tranquility)
        [391888] = true, -- Überfluss (Abundance)
        [392356] = true, -- Wuchernde Wurzeln
        [22842] = true,  -- Rasende Regeneration
    },
    PRIEST = {
        [139] = true,    -- Erneuerung (Renew)
        [6074] = true, [6075] = true, [6076] = true, [6077] = true, [6078] = true, [10927] = true, [10928] = true, [10929] = true, [25315] = true, [48067] = true, [48068] = true,
        [77489] = true,  -- Echo des Lichts (Echo of Light)
        [41635] = true,  -- Gebet der Besserung (Prayer of Mending)
        [41637] = true, [28804] = true, [48113] = true, [48114] = true,
        [17] = true,     -- Machtwort: Schild (Power Word: Shield)
        [592] = true, [600] = true, [3747] = true, [6065] = true, [6066] = true, [10898] = true, [10899] = true, [10900] = true, [10901] = true, [25217] = true, [25218] = true, [48065] = true, [48066] = true,
        [194384] = true, -- Abbitte (Atonement)
        [47788] = true,  -- Schutzgeist (Guardian Spirit)
        [33206] = true,  -- Schmerzunterdrückung (Pain Suppression)
    },
    SHAMAN = {
        [61295] = true,  -- Springflut (Riptide)
        [61299] = true, [61300] = true, [61301] = true,
        [974] = true,    -- Erdschild (Earth Shield)
        [32593] = true, [32594] = true, [49283] = true, [49284] = true,
        [52073] = true,  -- Totem des heilenden Flusses
        [383648] = true, -- Urzeitliche Welle
        [382024] = true, -- Waffe der Lebensgeister
    },
    MONK = {
        [124682] = true, -- Einhüllender Nebel (Enveloping Mist)
        [119611] = true, -- Erneuernder Nebel (Renewing Mist)
        [115175] = true, -- Beruhigender Nebel (Soothing Mist)
        [191840] = true, -- Essenzborn (Essence Font)
    },
    PALADIN = {
        [53563] = true,  -- Flamme des Glaubens (Beacon of Light)
        [156910] = true, -- Flamme der Zuversicht (Beacon of Faith)
        [200025] = true, -- Flamme der Tugend (Beacon of Virtue)
        [223306] = true, -- Zuversicht verleihen (Bestow Faith)
        [156322] = true, -- Ewige Flamme (Eternal Flame)
    },
    EVOKER = {
        [364343] = true, -- Echo
        [366155] = true, -- Zurückspulen / Reversion
        [359816] = true, -- Traumflug (Dream Flight)
        [376788] = true, -- Traumatem (Dream Breath)
        [367364] = true, -- Geistblüte (Spiritbloom)
        [370960] = true, -- Zeitdilatation (Time Dilation)
    },
}

local CLASS_HOT_NAMES = {
    DRUID = {
        ["Verjüngung"] = true,
        ["Rejuvenation"] = true,
        ["Keimung"] = true,
        ["Germination"] = true,
        ["Nachwachsen"] = true,
        ["Regrowth"] = true,
        ["Blühendes Leben"] = true,
        ["Lifebloom"] = true,
        ["Wildwuchs"] = true,
        ["Wild Growth"] = true,
        ["Cenarischer Zauberschutz"] = true,
        ["Cenarion Ward"] = true,
        ["Frühlingsblüten"] = true,
        ["Spring Blossoms"] = true,
        ["Kultivierung"] = true,
        ["Cultivation"] = true,
        ["Adaptiver Schwarm"] = true,
        ["Adaptive Swarm"] = true,
        ["Gelassenheit"] = true,
        ["Tranquility"] = true,
        ["Rasende Regeneration"] = true,
        ["Frenzied Regeneration"] = true,
    },
    PRIEST = {
        ["Erneuerung"] = true,
        ["Renew"] = true,
        ["Echo des Lichts"] = true,
        ["Echo of Light"] = true,
        ["Gebet der Besserung"] = true,
        ["Prayer of Mending"] = true,
        ["Machtwort: Schild"] = true,
        ["Power Word: Shield"] = true,
        ["Abbitte"] = true,
        ["Atonement"] = true,
        ["Schutzgeist"] = true,
        ["Guardian Spirit"] = true,
        ["Schmerzunterdrückung"] = true,
        ["Pain Suppression"] = true,
    },
    SHAMAN = {
        ["Springflut"] = true,
        ["Riptide"] = true,
        ["Erdschild"] = true,
        ["Earth Shield"] = true,
        ["Totem des heilenden Flusses"] = true,
        ["Healing Stream Totem"] = true,
        ["Urzeitliche Welle"] = true,
        ["Primordial Wave"] = true,
        ["Waffe der Lebensgeister"] = true,
        ["Earthliving Weapon"] = true,
    },
    MONK = {
        ["Einhüllender Nebel"] = true,
        ["Enveloping Mist"] = true,
        ["Erneuernder Nebel"] = true,
        ["Renewing Mist"] = true,
        ["Beruhigender Nebel"] = true,
        ["Soothing Mist"] = true,
        ["Essenzborn"] = true,
        ["Essence Font"] = true,
    },
    PALADIN = {
        ["Flamme des Glaubens"] = true,
        ["Beacon of Light"] = true,
        ["Flamme der Zuversicht"] = true,
        ["Beacon of Faith"] = true,
        ["Flamme der Tugend"] = true,
        ["Beacon of Virtue"] = true,
        ["Zuversicht verleihen"] = true,
        ["Bestow Faith"] = true,
        ["Ewige Flamme"] = true,
        ["Eternal Flame"] = true,
    },
    EVOKER = {
        ["Echo"] = true,
        ["Zurückspulen"] = true,
        ["Reversion"] = true,
        ["Traumflug"] = true,
        ["Dream Flight"] = true,
        ["Traumatem"] = true,
        ["Dream Breath"] = true,
        ["Geistblüte"] = true,
        ["Spiritbloom"] = true,
        ["Zeitdilatation"] = true,
        ["Time Dilation"] = true,
    },
}

-- Bereinigt Zaubernamen von Rang-Zusätzen (z.B. "Verjüngung (Rang 4)" -> "Verjüngung")
local function GetCleanSpellName(name)
    if not name or IsSecret(name) then return "" end
    local base = name:match("^(.-)%s*%(")
    if base and base ~= "" then
        return base
    end
    return name
end

-- Prüft, ob ein Zauber zur Heiler-Klasse des aktiven Spielers gehört (strikte Trennung!)
local function IsPlayerClassSpell(name, spellId)
    local _, pClass = UnitClass("player")
    if not pClass then return false end

    -- 1. Prüfe über Spell-ID in CLASS_HOTS[pClass]
    if spellId and CLASS_HOTS[pClass] and CLASS_HOTS[pClass][spellId] then
        return true
    end

    -- 2. Prüfe über Zaubernamen in CLASS_HOT_NAMES[pClass]
    local clean = GetCleanSpellName(name)
    if clean and CLASS_HOT_NAMES[pClass] and CLASS_HOT_NAMES[pClass][clean] then
        return true
    end
    if name and CLASS_HOT_NAMES[pClass] and CLASS_HOT_NAMES[pClass][name] then
        return true
    end

    -- 3. Prüfe über Config trackedHots der eigenen Klasse
    if R4L.Config and R4L.Config.ClassDefaults and R4L.Config.ClassDefaults[pClass] then
        local cDef = R4L.Config.ClassDefaults[pClass]
        if cDef.trackedHots then
            for _, id in ipairs(cDef.trackedHots) do
                if spellId == id then return true end
            end
        end
    end

    return false
end

-- Prüft, ob eine Aura ein HoT (Heal over Time) irgendeiner Heiler-Klasse ist
local function IsHotAura(name, spellId, duration)
    for _, hots in pairs(CLASS_HOTS) do
        if spellId and hots[spellId] then return true end
    end
    local cleanName = GetCleanSpellName(name)
    for _, names in pairs(CLASS_HOT_NAMES) do
        if cleanName and names[cleanName] then return true end
        if name and names[name] then return true end
    end
    return false
end

-- Holt alle aktiven HoTs (eigene HoTs und fremde HoTs getrennt) auf der Zieleinheit
function AT:GetPlayerHots(unit)
    local ownHots = {}
    local otherHots = {}
    if not unit or not UnitExists(unit) then return ownHots, otherHots end

    local maxOwnHots = 4
    local maxOtherHots = 3
    if R4L.ProfileManager then
        local cfg = R4L.ProfileManager:GetConfig()
        if cfg and cfg.auras then
            if cfg.auras.maxHots then maxOwnHots = cfg.auras.maxHots end
            if cfg.auras.maxOtherHots then maxOtherHots = cfg.auras.maxOtherHots end
        end
    end

    local allOwn = {}
    local allOther = {}
    local seenOwn = {}
    local seenOther = {}

    local function TryAddAura(aura)
        if not aura then return false end
        local name = aura.name
        local icon = aura.icon or aura.iconFileID
        local count = aura.applications or aura.count or 0
        local duration = aura.duration or 0
        local expirationTime = aura.expirationTime or 0
        local spellId = aura.spellId

        -- Eigene HoTs MÜSSEN zwingend zur Klasse des Spielers gehören (z. B. Priester-HoTs für Druiden sind IMMER fremd!)
        local isMine = false
        if IsPlayerClassSpell(name, spellId) then
            isMine = IsPlayerAura(aura, unit)
        end

        -- Falls Icon irrtümlich als Rang-String ankam, Textur über Zaubernamen auflösen
        if type(icon) == "string" and (icon:find("Rang") or icon:find("Rank")) then
            if GetSpellTexture then
                local okTex, sTex = pcall(GetSpellTexture, spellId or name)
                if okTex and sTex then icon = sTex end
            end
        end

        if icon and IsHotAura(name, spellId, duration) then
            local key = spellId or name or icon
            local hotData = {
                name = name,
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                spellId = spellId,
                isMine = isMine,
            }

            if isMine then
                if not seenOwn[key] then
                    seenOwn[key] = true
                    table.insert(allOwn, hotData)
                end
            else
                if not seenOther[key] then
                    seenOther[key] = true
                    table.insert(allOther, hotData)
                end
            end
        end
        return false
    end

    local function FinalizeHots()
        local now = GetTime()
        local function CompareHots(a, b)
            local timeA = (a.expirationTime and a.expirationTime > 0) and (a.expirationTime - now) or 99999
            local timeB = (b.expirationTime and b.expirationTime > 0) and (b.expirationTime - now) or 99999
            return timeA < timeB
        end
        table.sort(allOwn, CompareHots)
        table.sort(allOther, CompareHots)

        for i = 1, math.min(#allOwn, maxOwnHots) do
            table.insert(ownHots, allOwn[i])
        end
        for i = 1, math.min(#allOther, maxOtherHots) do
            table.insert(otherHots, allOther[i])
        end
        return ownHots, otherHots
    end

    -- Methode 1: C_UnitAuras.GetUnitAuras
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local auras = nil
        local ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        if ok and res and type(res) == "table" and #res > 0 then
            auras = res
        end
        if auras then
            for _, aura in pairs(auras) do
                if type(aura) == "table" then
                    TryAddAura(aura)
                end
            end
            if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
        end
    end

    -- Methode 2: AuraUtil.ForEachAura
    if AuraUtil and AuraUtil.ForEachAura then
        pcall(AuraUtil.ForEachAura, unit, "HELPFUL", 40, function(arg1, arg2, arg3, arg4, arg5, arg6, arg7, ...)
            local aura = nil
            if type(arg1) == "table" then
                aura = arg1
            else
                aura = ParseUnitAuraArgs(arg1, arg2, arg3, arg4, arg5, arg6, arg7, ...)
            end
            if aura then
                TryAddAura(aura)
            end
            return false
        end)
        if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
    end

    -- Methode 3: C_UnitAuras.GetAuraSlots & GetAuraDataBySlot
    if C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        local token = nil
        repeat
            local okSlots, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 = pcall(C_UnitAuras.GetAuraSlots, unit, "HELPFUL", 40, token)
            if okSlots and s1 then
                local slots = { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 }
                token = table.remove(slots, 1)
                for _, slot in ipairs(slots) do
                    local okAura, aura = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
                    if okAura and aura then TryAddAura(aura) end
                end
            else
                token = nil
            end
        until token == nil
        if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
    end

    -- Methode 4: GetUnitAuraByIndex (Universeller Index-Scan)
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HELPFUL")
        if not aura then break end
        TryAddAura(aura)
    end

    return FinalizeHots()
end

-- Findet den wichtigsten reinigbaren Debuff auf einer Einheit (gesichert im Kampf)
function AT:GetDispellableDebuff(unit)
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.auras or not cfg.auras.showDebuffs then return nil end

    local dispels = self:GetDispelCapabilities()

    -- 1. Scan über AuraUtil.ForEachAura
    if AuraUtil and AuraUtil.ForEachAura then
        local foundDebuff, foundColor = nil, nil
        pcall(AuraUtil.ForEachAura, unit, "HARMFUL", 40, function(arg1, arg2, arg3, arg4, arg5, ...)
            local dispelType = nil
            local auraData = nil
            if type(arg1) == "table" then
                dispelType = arg1.dispelName
                auraData = arg1
            else
                local parsed = ParseUnitAuraArgs(arg1, arg2, arg3, arg4, arg5, ...)
                if parsed then
                    dispelType = parsed.dispelType
                    auraData = parsed
                end
            end

            if dispelType and not IsSecret(dispelType) then
                local canDispel = dispels[dispelType]
                local showFilter = false
                if dispelType == "Curse" and cfg.auras.showCurse then showFilter = true end
                if dispelType == "Poison" and cfg.auras.showPoison then showFilter = true end
                if dispelType == "Disease" and cfg.auras.showDisease then showFilter = true end
                if dispelType == "Magic" and cfg.auras.showMagic then showFilter = true end

                if showFilter and (not cfg.auras.highlightDispellableOnly or canDispel) then
                    foundDebuff = {
                        name = (auraData and auraData.name) or "",
                        icon = (auraData and (auraData.iconFileID or auraData.icon)),
                        dispelType = dispelType,
                    }
                    foundColor = self.DebuffColors[dispelType] or self.DebuffColors["None"]
                    return true
                end
            end
            return false
        end)
        if foundDebuff and foundColor then
            return foundDebuff, foundColor
        end
    end

    -- 2. Scan über GetUnitAuraByIndex (Classic 3.3.5 / Forever / Modern)
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HARMFUL")
        if not aura then break end

        local dispelType = aura.dispelType
        if dispelType and not IsSecret(dispelType) then
            local canDispel = dispels[dispelType]
            local showFilter = false

            if dispelType == "Curse" and cfg.auras.showCurse then showFilter = true end
            if dispelType == "Poison" and cfg.auras.showPoison then showFilter = true end
            if dispelType == "Disease" and cfg.auras.showDisease then showFilter = true end
            if dispelType == "Magic" and cfg.auras.showMagic then showFilter = true end

            if showFilter and (not cfg.auras.highlightDispellableOnly or canDispel) then
                return aura, self.DebuffColors[dispelType] or self.DebuffColors["None"]
            end
        end
    end

    return nil, nil
end
