--[[
    MM2 AUTO TRADE - CONFIG/ROUTER
    Cau truc theo trade BSS:
      - Chi chay tren alt.
      - Check inventory truoc.
      - Neu co item va main cung server -> load alttrade.
      - Neu co item nhung chua cung server main -> load farm, farm se chay checkitems.
      - Neu khong co item -> load farm.
      - mainMM2.lua la script doc lap, khong chay tu config nay.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local env = (type(getgenv) == "function" and getgenv()) or _G
env.USER_ID = "chuingu"
if type(getgenv) == "function" then
    getgenv().USER_ID = "chuingu"
end
env.listitems = env.listitems or {}

local API_URL = "https://raw.sellaccroblox.com/apiroblox"
local RAW_URLS = {
    Config = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/config.lua",
    AltTrade = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/alttrade.lua",
    CheckItems = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/checkitem.lua",
    Farm = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/farm.lua",
    ListItems = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/listitem.txt"
}

local CFG = (type(env.ThieuNangTradeMM2) == "table" and env.ThieuNangTradeMM2) or {}
env.ThieuNangTradeMM2 = CFG
CFG.ApiUrl = CFG.ApiUrl or API_URL
CFG.ListUrl = CFG.ListUrl or RAW_URLS.ListItems
CFG.FarmUrl = CFG.FarmUrl or RAW_URLS.Farm
CFG.ScriptUrls = type(CFG.ScriptUrls) == "table" and CFG.ScriptUrls or {}
CFG.ScriptUrls.Config = CFG.ScriptUrls.Config or RAW_URLS.Config
CFG.ScriptUrls.AltTrade = CFG.ScriptUrls.AltTrade or RAW_URLS.AltTrade
CFG.ScriptUrls.CheckItems = CFG.ScriptUrls.CheckItems or RAW_URLS.CheckItems
CFG.ScriptUrls.Farm = CFG.ScriptUrls.Farm or RAW_URLS.Farm

local USER_ID = "chuingu"
local http = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
local DEFAULT_ITEMS = {
    { id = "Icecream", name = "Icecream", min = 1, max = 999999, type = "Weapons" },
    { id = "IcecreamChroma", name = "IcecreamChroma", min = 1, max = 999999, type = "Weapons" }
}

local function log(msg)
    print("[MM2][config] " .. tostring(msg))
end

local function logWarn(msg)
    warn("[MM2][config] " .. tostring(msg))
end

local function waitForChildSoft(parent, childName, timeout)
    local started = os.clock()
    local found = parent and parent:FindFirstChild(childName)
    while not found and os.clock() - started < timeout do
        task.wait(0.2)
        found = parent and parent:FindFirstChild(childName)
    end
    return found
end

local function waitForStartupReady()
    local timeout = tonumber(CFG.StartupWaitTimeout) or 60
    local started = os.clock()

    if not game:IsLoaded() then
        log("Cho game load...")
        while not game:IsLoaded() and os.clock() - started < timeout do
            task.wait(0.25)
        end
    end

    while not Players.LocalPlayer and os.clock() - started < timeout do
        task.wait(0.2)
    end
    player = Players.LocalPlayer
    if not player then
        logWarn("Khong lay duoc LocalPlayer sau khi cho load")
        return false
    end

    local character = player.Character
    while not character and os.clock() - started < timeout do
        task.wait(0.2)
        character = player.Character
    end

    if character then
        local remain = math.max(1, timeout - (os.clock() - started))
        waitForChildSoft(character, "Humanoid", remain)
        waitForChildSoft(character, "HumanoidRootPart", remain)
    else
        logWarn("Character chua load sau khi cho")
    end

    local dataDelay = tonumber(CFG.AfterSpawnDataDelay) or 3
    if dataDelay > 0 then
        task.wait(dataDelay)
    end

    log("Startup ready: game/player/character da qua lop wait")
    return true
end

local function loadUrl(url, label)
    if type(url) ~= "string" or url == "" then
        logWarn("Thieu URL cho " .. tostring(label))
        return false
    end

    local ok, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)
    if not ok then
        logWarn("Load " .. tostring(label) .. " loi: " .. tostring(err))
        return false
    end
    return true
end

local function updateList(url, globalKey)
    if type(env[globalKey]) == "table" and next(env[globalKey]) then
        return true
    end
    if type(url) ~= "string" or url == "" or not http then
        return false
    end

    local maxRetries = 3
    local attempt = 0
    while attempt < maxRetries do
        attempt = attempt + 1
        local success, response = pcall(function()
            return http({ Url = url, Method = "GET" })
        end)

        if success and response and response.Success then
            local okDecode, result = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
            if okDecode and type(result) == "table" then
                env[globalKey] = result
                log("Cap nhat " .. tostring(globalKey) .. " thanh cong")
                return true
            end
        end

        if attempt < maxRetries then
            task.wait(3)
        end
    end

    return type(env[globalKey]) == "table" and next(env[globalKey]) ~= nil
end

local function normalizeListItems(source)
    local out = {}
    if type(source) ~= "table" then
        return out
    end

    if #source > 0 then
        for _, row in ipairs(source) do
            if type(row) == "table" then
                local id = row.id or row.ID or row.itemId or row.ItemID or row.name or row.Name
                if type(id) == "string" and id ~= "" then
                    out[id] = {
                        id = id,
                        name = tostring(row.name or row.Name or id),
                        min = math.max(1, math.floor(tonumber(row.min or row.Min or 1) or 1)),
                        max = math.max(1, math.floor(tonumber(row.max or row.Max or 999999) or 999999)),
                        type = tostring(row.type or row.Type or row.category or row.Category or "Weapons")
                    }
                end
            elseif type(row) == "string" and row ~= "" then
                out[row] = { id = row, name = row, min = 1, max = 999999, type = "Weapons" }
            end
        end
        return out
    end

    for itemId, cfg in pairs(source) do
        if type(itemId) == "string" and itemId ~= "" then
            if type(cfg) == "table" then
                local id = tostring(cfg.id or cfg.ID or cfg.itemId or cfg.ItemID or itemId)
                out[id] = {
                    id = id,
                    name = tostring(cfg.name or cfg.Name or id),
                    min = math.max(1, math.floor(tonumber(cfg.min or cfg.Min or 1) or 1)),
                    max = math.max(1, math.floor(tonumber(cfg.max or cfg.Max or 999999) or 999999)),
                    type = tostring(cfg.type or cfg.Type or cfg.category or cfg.Category or "Weapons")
                }
            else
                out[itemId] = {
                    id = itemId,
                    name = itemId,
                    min = 1,
                    max = math.max(1, math.floor(tonumber(cfg) or 999999)),
                    type = "Weapons"
                }
            end
        end
    end

    return out
end

local function getListSource()
    if type(env.listitems) == "table" and next(env.listitems) then
        return env.listitems
    end
    if type(CFG.Items) == "table" and next(CFG.Items) then
        return CFG.Items
    end
    return DEFAULT_ITEMS
end

local function getProfileData()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local profileModule = modules and modules:FindFirstChild("ProfileData")
    if not profileModule then
        return nil
    end

    local ok, result = pcall(require, profileModule)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function getInventoryCounts()
    local profileData = getProfileData()
    local owned = profileData
        and type(profileData.Weapons) == "table"
        and type(profileData.Weapons.Owned) == "table"
        and profileData.Weapons.Owned

    if not owned then
        return nil
    end

    local counts = {}
    for itemId, count in pairs(owned) do
        counts[tostring(itemId)] = math.max(0, math.floor(tonumber(count) or 0))
    end
    return counts
end

local function countsHaveTargetItems(counts, rules)
    if type(counts) ~= "table" or type(rules) ~= "table" then
        return false
    end

    for itemId, rule in pairs(rules) do
        local have = counts[itemId] or 0
        local min = rule and rule.min or 1
        if have >= min then
            return true, itemId, have
        end
    end
    return false
end

local function waitForInventoryCounts(rules)
    local timeout = tonumber(CFG.InventoryWaitTimeout) or 30
    timeout = math.max(1, math.min(timeout, 30))
    local started = os.clock()
    local latestCounts = nil
    local ownedLoadedAt = nil

    log("Cho ProfileData.Weapons.Owned load truoc khi route toi da " .. tostring(timeout) .. "s...")

    while os.clock() - started < timeout do
        local counts = getInventoryCounts()
        if counts then
            latestCounts = counts
            if not ownedLoadedAt then
                ownedLoadedAt = os.clock()
                log("ProfileData.Weapons.Owned da load, tiep tuc doi den timeout de tranh data rong luc vua vao")
            end

            local hasTarget, itemId, have = countsHaveTargetItems(counts, rules)
            if hasTarget then
                log("Inventory da load va co item trong list: " .. tostring(have) .. "x " .. tostring(itemId))
                return counts
            end
        end

        task.wait(0.5)
    end

    if latestCounts then
        logWarn("Timeout " .. tostring(timeout) .. "s, route tiep voi ProfileData.Weapons.Owned hien tai")
        return latestCounts
    end

    logWarn("Timeout " .. tostring(timeout) .. "s van chua doc duoc ProfileData.Weapons.Owned, route tiep")
    return getInventoryCounts()
end

local function checkListItems()
    updateList(CFG.ListUrl, "listitems")

    local rules = normalizeListItems(getListSource())
    if next(rules) == nil then
        logWarn("Danh sach listitems dang trong")
        return false
    end

    local counts = waitForInventoryCounts(rules)
    if not counts then
        logWarn("Khong doc duoc ProfileData.Weapons.Owned")
        return false
    end

    local offerItems = {}
    for itemId, rule in pairs(rules) do
        local have = counts[itemId] or 0
        if have >= rule.min then
            log("Du dieu kien: co " .. tostring(have) .. "x " .. itemId)
            offerItems[#offerItems + 1] = {
                id = itemId,
                name = rule.name or itemId,
                type = rule.type or "Weapons",
                amount = have
            }
        else
            log("Chua du: " .. itemId .. " = " .. tostring(have) .. "/" .. tostring(rule.min))
        end
    end

    return #offerItems > 0, offerItems
end

local function getAvailableGiftJobs(id)
    if not http then
        return {}
    end

    local url = CFG.ApiUrl .. "/main/availablegift?UserID=" .. tostring(id)
    local maxRetries = 3
    local attempt = 0
    while attempt < maxRetries do
        attempt = attempt + 1
        local success, response = pcall(function()
            return http({
                Url = url,
                Method = "GET",
                Headers = { ["Accept"] = "application/json" }
            })
        end)

        if success and response and response.Success then
            local parseSuccess, result = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
            if parseSuccess and type(result) == "table" and result.status == "success" then
                return result.availableJobs or {}
            end
            logWarn("Loi parse availablegift")
            return {}
        end

        if attempt < maxRetries then
            task.wait(5)
        end
    end
    return {}
end

local function checkMainInServer(mainID)
    if not mainID then
        return false
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == mainID then
            log("Tim thay MAIN " .. tostring(mainID) .. " trong server")
            return true
        end
    end
    return false
end

local function jobIsCurrentServer(job)
    if type(job) ~= "table" then
        return false
    end
    local jobID = job.job_id or job.jobId or job.JobID
    return tostring(jobID or "") ~= "" and tostring(jobID) == tostring(game.JobId)
end

local function findMainID(jobList)
    local preferred = tostring(CFG.Partner or env.selectedMainID or "")
    for _, job in ipairs(jobList or {}) do
        local mainID = job.main_id or job.mainId or job.MainID
        if mainID and (preferred == "" or mainID == preferred) and (jobIsCurrentServer(job) or checkMainInServer(mainID)) then
            env.selectedMainID = mainID
            env.selectedMainJob = job
            return mainID
        end
    end
    return nil
end

local function findMainIDInCurrentServer()
    log("Alt co item -> alt kiem tra main trong server hien tai")

    local jobList = getAvailableGiftJobs(USER_ID)
    local mainID = findMainID(jobList)
    if mainID then
        return mainID
    end

    log("Alt khong thay main trong server hien tai")
    return nil
end

waitForStartupReady()

local hasItems, offerItems = checkListItems()
if hasItems then
    pcall(function()
        local playerName = player and player.Name
        local fileName = playerName and (playerName .. ".txt") or ""
        if fileName ~= "" and type(isfile) == "function" and type(delfile) == "function" and isfile(fileName) then
            delfile(fileName)
        end
    end)

    local mainID = findMainIDInCurrentServer()
    if mainID then
        env.selectedOfferItems = offerItems
        log("Da tim thay mainID: " .. tostring(mainID) .. " -> trade MM2")
        loadUrl(CFG.ScriptUrls.AltTrade, "alttrade")
        return
    end

    env.selectedOfferItems = offerItems
    log("Alt co item nhung chua cung server main -> chay farm, farm se chay checkitems")
    loadUrl(CFG.FarmUrl, "farm")
    return
end

log("Khong du item -> chay farm MM2")
loadUrl(CFG.FarmUrl, "farm")
