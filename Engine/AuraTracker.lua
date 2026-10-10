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

-- Universeller Aura-Zugriff für moderne Retail / Forever API (abgesichert gegen Secret Auras & Taint)
local function GetUnitAuraByIndex(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and data and type(data) == "table" then
            return {
                name = data.name,
                icon = data.iconFileID or data.icon,
                count = data.applications or 0,
                dispelType = data.dispelName,
                duration = data.duration or 0,
                expirationTime = data.expirationTime or 0,
                sourceUnit = data.sourceUnit,
                sourceGUID = data.sourceGUID,
                spellId = data.spellId,
                isFromPlayerOrPlayerPet = data.isFromPlayerOrPlayerPet,
            }
        end
        return nil
    elseif UnitAura then
        local ok, name, icon, count, dispelType, duration, expirationTime, sourceUnit, _, _, spellId = pcall(UnitAura, unit, index, filter)
        if ok and name then
            return {
                name = name,
                icon = icon,
                count = count or 0,
                dispelType = dispelType,
                duration = duration or 0,
                expirationTime = expirationTime or 0,
                sourceUnit = sourceUnit,
                spellId = spellId,
                isFromPlayerOrPlayerPet = (sourceUnit and (sourceUnit == "player" or UnitIsUnit(sourceUnit, "player"))),
            }
        end
        return nil
    end
    return nil
end

-- Prüft, ob eine Aura vom Spieler stammt (strikte Caster-Prüfung)
local function IsPlayerAura(aura)
    if not aura then return false end

    -- 1. sourceUnit Prüfung (höchste Priorität: "player" oder pet)
    if aura.sourceUnit and aura.sourceUnit ~= "" then
        return (aura.sourceUnit == "player" or UnitIsUnit(aura.sourceUnit, "player") or UnitIsUnit(aura.sourceUnit, "pet"))
    end

    -- 2. GUID-Prüfung (eindeutiger Caster-GUID)
    if aura.sourceGUID and aura.sourceGUID ~= "" then
        local pGUID = UnitGUID("player")
        if pGUID and aura.sourceGUID == pGUID then
            return true
        end
        return false
    end

    -- 3. isFromPlayerOrPlayerPet als Fallback
    if aura.isFromPlayerOrPlayerPet == true then
        return true
    end

    return false
end

-- Bekannte HoT Zauber-IDs für alle Heiler-Klassen
local KNOWN_HOTS = {
    -- Druide
    [774] = true,    -- Verjüngung (Rejuvenation)
    [155777] = true, -- Verjüngung (Keimung / Germination)
    [8936] = true,   -- Nachwachsen (Regrowth)
    [33763] = true,  -- Blühendes Leben (Lifebloom)
    [48438] = true,  -- Wildwuchs (Wild Growth)
    [102351] = true, -- Cenarischer Zauberschutz (Cenarion Ward)
    [102352] = true, -- Cenarischer Zauberschutz HoT-Effekt
    [207386] = true, -- Frühlingsblüten (Spring Blossoms)
    [200389] = true, -- Kultivierung (Cultivation)
    [325748] = true, -- Adaptiver Schwarm (Adaptive Swarm)
    [157982] = true, -- Gelassenheit (Tranquility)
    [391888] = true, -- Überfluss (Abundance)
    [392356] = true, -- Wuchernde Wurzeln
    [22842] = true,  -- Rasende Regeneration
    -- Priester
    [139] = true,    -- Erneuerung (Renew)
    [77489] = true,  -- Echo des Lichts (Echo of Light)
    [41635] = true,  -- Gebet der Besserung (Prayer of Mending)
    [17] = true,     -- Machtwort: Schild (Power Word: Shield)
    [194384] = true, -- Abbitte (Atonement)
    [47788] = true,  -- Schutzgeist (Guardian Spirit)
    [33206] = true,  -- Schmerzunterdrückung (Pain Suppression)
    -- Schamane
    [61295] = true,  -- Springflut (Riptide)
    [974] = true,    -- Erdschild (Earth Shield)
    [52073] = true,  -- Totem des heilenden Flusses
    [383648] = true, -- Urzeitliche Welle
    [382024] = true, -- Waffe der Lebensgeister
    -- Mönch
    [124682] = true, -- Einhüllender Nebel (Enveloping Mist)
    [119611] = true, -- Erneuernder Nebel (Renewing Mist)
    [115175] = true, -- Beruhigender Nebel (Soothing Mist)
    [191840] = true, -- Essenzborn (Essence Font)
    -- Paladin
    [53563] = true,  -- Flamme des Glaubens (Beacon of Light)
    [156910] = true, -- Flamme der Zuversicht (Beacon of Faith)
    [200025] = true, -- Flamme der Tugend (Beacon of Virtue)
    [223306] = true, -- Zuversicht verleihen (Bestow Faith)
    [156322] = true, -- Ewige Flamme (Eternal Flame)
    -- Rufer
    [364343] = true, -- Echo
    [366155] = true, -- Zurückspulen / Reversion
    [359816] = true, -- Traumflug (Dream Flight)
    [376788] = true, -- Traumatem (Dream Breath)
    [367364] = true, -- Geistblüte (Spiritbloom)
    [370960] = true, -- Zeitdilatation (Time Dilation)
}

local KNOWN_HOT_NAMES = {
    -- Druide
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
    -- Priester
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
    -- Schamane
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
    -- Mönch
    ["Einhüllender Nebel"] = true,
    ["Enveloping Mist"] = true,
    ["Erneuernder Nebel"] = true,
    ["Renewing Mist"] = true,
    ["Beruhigender Nebel"] = true,
    ["Soothing Mist"] = true,
    ["Essenzborn"] = true,
    ["Essence Font"] = true,
    -- Paladin
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
    -- Rufer
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
}

-- Bereinigt Zaubernamen von Rang-Zusätzen (z.B. "Verjüngung (Rang 4)" -> "Verjüngung")
local function GetCleanSpellName(name)
    if not name then return "" end
    local base = name:match("^(.-)%s*%(")
    if base and base ~= "" then
        return base
    end
    return name
end

-- Prüft, ob eine Aura ein HoT (Heal over Time) ist
local function IsHotAura(name, spellId, duration)
    if spellId and KNOWN_HOTS[spellId] then
        return true
    end
    local cleanName = GetCleanSpellName(name)
    if cleanName and KNOWN_HOT_NAMES[cleanName] then
        return true
    end
    if name and KNOWN_HOT_NAMES[name] then
        return true
    end
    -- Klassen-spezifische HoTs aus Config
    local _, pClass = UnitClass("player")
    if pClass and R4L.Config and R4L.Config.ClassDefaults and R4L.Config.ClassDefaults[pClass] then
        local cDef = R4L.Config.ClassDefaults[pClass]
        if cDef.trackedHots then
            for _, id in ipairs(cDef.trackedHots) do
                if spellId == id then return true end
            end
        end
    end
    -- Fallback für aktive HoTs mit typischer Laufzeit (2 bis 45 Sekunden)
    if duration and type(duration) == "number" and duration >= 2 and duration <= 45 then
        return true
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
        local isMine = IsPlayerAura(aura)
        local name = aura.name
        local icon = aura.icon or aura.iconFileID
        local count = aura.applications or aura.count or 0
        local duration = aura.duration or 0
        local expirationTime = aura.expirationTime or 0
        local spellId = aura.spellId

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
            local aura = {}
            if type(arg1) == "table" then
                aura = arg1
            else
                aura.name = arg1
                aura.icon = arg2
                aura.applications = arg3 or 0
                aura.duration = arg5 or 0
                aura.expirationTime = arg6 or 0
                aura.sourceUnit = arg7
                aura.spellId = select(3, ...)
                aura.isFromPlayerOrPlayerPet = (arg7 and (arg7 == "player" or UnitIsUnit(arg7, "player")))
            end
            TryAddAura(aura)
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

-- Findet den wichtigsten reinigbaren Debuff auf einer Einheit
function AT:GetDispellableDebuff(unit)
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.auras or not cfg.auras.showDebuffs then return nil end

    local dispels = self:GetDispelCapabilities()

    -- Methode 1: C_UnitAuras.GetUnitAuras
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local auras = nil
        local ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL", 40, 0, 0)
        if ok and res then auras = res end
        if not auras then
            local ok2, res2 = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL")
            if ok2 and res2 then auras = res2 end
        end

        if auras then
            for _, aura in pairs(auras) do
                if type(aura) == "table" and aura.dispelName then
                    local dispelType = aura.dispelName
                    local canDispel = dispels[dispelType]
                    local showFilter = false

                    if dispelType == "Curse" and cfg.auras.showCurse then showFilter = true end
                    if dispelType == "Poison" and cfg.auras.showPoison then showFilter = true end
                    if dispelType == "Disease" and cfg.auras.showDisease then showFilter = true end
                    if dispelType == "Magic" and cfg.auras.showMagic then showFilter = true end

                    if showFilter and (not cfg.auras.highlightDispellableOnly or canDispel) then
                        return {
                            name = aura.name,
                            icon = aura.icon or aura.iconFileID,
                            dispelType = dispelType,
                        }, self.DebuffColors[dispelType] or self.DebuffColors["None"]
                    end
                end
            end
        end
    end

    -- Methode 2: GetUnitAuraByIndex
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HARMFUL")
        if not aura then break end

        local dispelType = aura.dispelType
        if dispelType then
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
