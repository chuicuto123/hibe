local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chá» LocalPlayer
repeat
    task.wait()
until Players.LocalPlayer

local LocalPlayer = Players.LocalPlayer

local Networking
local PlayerStateClient
local CHECK_SECONDS = 300

do
    local sharedModules = ReplicatedStorage:WaitForChild("SharedModules", 10)
    local networkingModule = sharedModules and sharedModules:WaitForChild("Networking", 10)
    if networkingModule then
        local ok, result = pcall(require, networkingModule)
        if ok then
            Networking = result
        end
    end

    local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
    local stateModule = clientModules and clientModules:WaitForChild("PlayerStateClient", 10)
    if stateModule then
        local ok, result = pcall(require, stateModule)
        if ok then
            PlayerStateClient = result
        end
    end
end

-- Chá» leaderstats
local leaderstats
repeat
    leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    task.wait()
until leaderstats

local Sheckles = leaderstats:WaitForChild("Sheckles")

local function shutdown(reason)
    warn("[AUTO SHUTDOWN] " .. reason)
    game:Shutdown()
end

local function getLocalReplica(timeout)
    if not PlayerStateClient then return nil end

    local replica
    if type(PlayerStateClient.GetLocalReplica) == "function" then
        local ok, result = pcall(function()
            return PlayerStateClient:GetLocalReplica()
        end)
        if ok and result then
            replica = result
        end
    end

    if not replica and type(PlayerStateClient.WaitForLocalReplica) == "function" then
        local ok, result = pcall(function()
            return PlayerStateClient:WaitForLocalReplica(timeout or 5)
        end)
        if ok then
            replica = result
        end
    end

    return replica
end

local function getInventory()
    local replica = getLocalReplica(5)
    local data = replica and replica.Data
    if type(data) == "table" and type(data.Inventory) == "table" then
        return data.Inventory
    end
    return nil
end

local function getCountFromEntry(entry)
    if type(entry) == "number" then
        return math.max(math.floor(entry), 0)
    end

    if type(entry) == "table" then
        local stacked = tonumber(entry.Count or entry.Amount or entry.Quantity or entry.Stack or entry.Qty)
        if stacked and stacked > 0 then
            return math.floor(stacked)
        end

        -- HarvestedFruits is instance-based in the other scripts: one table entry = one fruit.
        return 1
    end

    return 0
end

local function getReplicaFruitCount()
    local inv = getInventory()
    local fruits = inv and inv.HarvestedFruits
    if type(fruits) ~= "table" then
        return nil
    end

    local total = 0
    for _, entry in pairs(fruits) do
        total += getCountFromEntry(entry)
    end

    return total, "replica"
end

local function getPreviewFruitCount()
    local remote = Networking and Networking.NPCS and Networking.NPCS.PreviewSellAll
    if not remote then return nil end

    local fn = remote.Invoke or remote.Fire
    if type(fn) ~= "function" then return nil end

    local ok, preview = pcall(fn, remote)
    if ok and type(preview) == "table" then
        local count = tonumber(preview.FruitCount)
        if count then
            return math.max(math.floor(count), 0), "PreviewSellAll"
        end
    end

    return nil
end

local function getAttributeFruitCount()
    local count = tonumber(LocalPlayer:GetAttribute("FruitCount"))
    if count then
        return math.max(math.floor(count), 0), "attribute"
    end
    return nil
end

local function getToolFruitCount()
    local total = 0

    local function scan(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("FruitName") then
                local count = tonumber(tool:GetAttribute("Count")
                    or tool:GetAttribute("Amount")
                    or tool:GetAttribute("Quantity")
                    or tool:GetAttribute("Stack")
                    or 1) or 1
                total += math.max(math.floor(count), 1)
            end
        end
    end

    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))

    return total, "tools"
end

local function getFruitCount()
    local count, source = getReplicaFruitCount()
    if count ~= nil then return count, source end

    count, source = getPreviewFruitCount()
    if count ~= nil then return count, source end

    count, source = getAttributeFruitCount()
    if count ~= nil then return count, source end

    return getToolFruitCount()
end

local function getFruitCountZeroRetry()
    local count, source = getFruitCount()
    if count == 0 then
        task.wait(10)

        local retryCount, retrySource = getFruitCount()
        if retryCount ~= nil then
            return retryCount, retrySource or source
        end
    end

    return count, source
end

--------------------------------------------------
-- SHECKLES
--------------------------------------------------

local function checkSheckles()
    task.wait(10)

    while true do
        local before = Sheckles.Value
        task.wait(CHECK_SECONDS)

        local after = Sheckles.Value

        if after == before then
            shutdown(string.format(
                "Sheckles did not change after %d seconds. before=%s after=%s",
                CHECK_SECONDS,
                tostring(before),
                tostring(after)
            ))
            return
        end
    end
end

--------------------------------------------------
-- FRUITS
--------------------------------------------------

local function checkFruits()
    task.wait(10)

    while true do
        local before, beforeSource = getFruitCountZeroRetry()

        if before == nil then
            warn("[AUTO CHECK] Waiting for fruit inventory data...")
            task.wait(5)
            continue
        end

        warn(string.format(
            "[AUTO CHECK] Fruit before: %d (%s), checking again in %d seconds",
            before,
            tostring(beforeSource),
            CHECK_SECONDS
        ))

        task.wait(CHECK_SECONDS)

        local after, afterSource = getFruitCountZeroRetry()

        if after == nil then
            task.wait(5)
            after, afterSource = getFruitCountZeroRetry()

            if after == nil then
                shutdown("Cannot read fruit count from inventory.")
                return
            end
        end

        warn(string.format(
            "[AUTO CHECK] Fruit after: %d (%s), before=%d (%s)",
            after,
            tostring(afterSource),
            before,
            tostring(beforeSource)
        ))

        if after == before then
            shutdown(string.format(
                "Fruit count did not change after %d seconds. before=%d (%s) after=%d (%s)",
                CHECK_SECONDS,
                before,
                tostring(beforeSource),
                after,
                tostring(afterSource)
            ))
            return
        end
    end
end

task.spawn(checkSheckles)
task.spawn(checkFruits)
