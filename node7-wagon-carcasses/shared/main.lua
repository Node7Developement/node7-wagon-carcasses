Node7Carcasses = Node7Carcasses or {}

local UINT32 = 4294967296
local INT32_MAX = 2147483647

local function hashModel(value)
    if type(value) == 'number' then return value end
    if type(joaat) == 'function' then return joaat(value) end
    return GetHashKey(value)
end

function Node7Carcasses.HashVariants(value)
    local number = tonumber(value) or 0
    if number == 0 then return { 0 } end

    local signed = number
    if signed > INT32_MAX then signed = signed - UINT32 end

    local unsigned = number
    if unsigned < 0 then unsigned = unsigned + UINT32 end

    if signed == unsigned then return { signed } end
    return { signed, unsigned }
end

function Node7Carcasses.HashEquals(a, b)
    local av = Node7Carcasses.HashVariants(a)
    local bv = Node7Carcasses.HashVariants(b)
    for _, left in ipairs(av) do
        for _, right in ipairs(bv) do
            if left == right then return true end
        end
    end
    return false
end

local ProfilesByHash
local NamesByHash

function Node7Carcasses.BuildAnimalMaps()
    if ProfilesByHash and NamesByHash then
        return ProfilesByHash, NamesByHash
    end

    ProfilesByHash = {}
    NamesByHash = {}

    for modelName, profile in pairs(Config.Animals or {}) do
        local modelHash = hashModel(modelName)
        local record = {
            model = modelHash,
            modelName = modelName,
            label = profile.label or modelName,
            group = profile.group or 'default',
        }

        for _, variant in ipairs(Node7Carcasses.HashVariants(modelHash)) do
            ProfilesByHash[tostring(variant)] = record
            NamesByHash[tostring(variant)] = modelName
        end
    end

    return ProfilesByHash, NamesByHash
end

function Node7Carcasses.GetAnimalProfile(modelHash)
    local profiles = Node7Carcasses.BuildAnimalMaps()
    for _, variant in ipairs(Node7Carcasses.HashVariants(modelHash)) do
        local profile = profiles[tostring(variant)]
        if profile then return profile end
    end
    return nil
end

function Node7Carcasses.IsAnimalModel(modelHash)
    return Node7Carcasses.GetAnimalProfile(modelHash) ~= nil
end

function Node7Carcasses.GetCapacity(modelName)
    modelName = tostring(modelName or ''):lower()
    return tonumber((Config.WagonCapacity or {})[modelName]) or tonumber(Config.DefaultCapacity) or 4
end

function Node7Carcasses.SafeDecode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end

    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end
