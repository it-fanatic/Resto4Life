--[[
    Resto4Life - Engine/Sorting.lua
    Automatische Sortierung: Tank -> Melee -> Range -> Heal
--]]

local _, R4L = ...

R4L.Sorting = {}
local Sorting = R4L.Sorting

local MELEE_CLASSES = {
    ["WARRIOR"] = true,
    ["ROGUE"] = true,
    ["DEATHKNIGHT"] = true,
    ["DEMONHUNTER"] = true,
}

local RANGED_CLASSES = {
    ["MAGE"] = true,
    ["WARLOCK"] = true,
    ["PRIEST"] = true,
}

-- Ermittelt die spezifische Rolle einer Einheit
function Sorting:GetUnitRole(unit)
    if not UnitExists(unit) then return "UNKNOWN", 99 end

    local role = UnitGroupRolesAssigned(unit)
    if role == "TANK" then
        return "TANK", 1
    elseif role == "HEALER" then
        return "HEALER", 4
    end

    -- Damager oder None: Prüfe Nahkampf vs. Fernkampf
    local _, class = UnitClass(unit)
    
    if MELEE_CLASSES[class] then
        return "MELEE", 2
    elseif RANGED_CLASSES[class] then
        return "RANGE", 3
    end

    -- Hybriden (Druid, Paladin, Shaman, Monk, Hunter, Evoker)
    if class == "PALADIN" then
        return "MELEE", 2
    elseif class == "MONK" then
        return "MELEE", 2
    elseif class == "HUNTER" then
        return "RANGE", 3
    elseif class == "EVOKER" then
        return "RANGE", 3
    elseif class == "SHAMAN" then
        -- Standardmäßig als Ranged einstufen falls nicht eindeutig Melee
        return "RANGE", 3
    elseif class == "DRUID" then
        return "RANGE", 3
    end

    if role == "DAMAGER" then
        return "RANGE", 3
    end

    return "UNKNOWN", 5
end

-- Sortiert eine Liste von Einheiten nach Tank -> Melee -> Range -> Heal
function Sorting:SortUnits(unitList)
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.sorting.enabled then
        return unitList
    end

    local sorted = {}
    for _, unit in ipairs(unitList) do
        if UnitExists(unit) then
            local role, rank = self:GetUnitRole(unit)
            local name = UnitName(unit) or unit
            table.insert(sorted, {
                unit = unit,
                role = role,
                rank = rank,
                name = name
            })
        end
    end

    table.sort(sorted, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.name < b.name
    end)

    local result = {}
    for _, item in ipairs(sorted) do
        table.insert(result, item.unit)
    end
    return result
end
