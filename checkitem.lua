--[[
    MM2 AUTO TRADE - CHECK ITEMS / FIND MAIN
    Cau truc theo checksticker.lua cua BSS:
      - Chay song song trong farm.
      - Khi co item dat min thi lay available gift jobs.
      - Chon job main phu hop va teleport vao job do.
      - Khong load alttrade trong file nay.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
if not player then
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
local CFG = (type(env.ThieuNangTradeMM2) == "table" and env.ThieuNangTradeMM2) or {}
local HUB_CFG = (type(env.ThieuNangHub) == "table" and env.ThieuNangHub) or {}
local API_URL = tostring(CFG.ApiUrl or "https://raw.sellaccroblox.com/apiroblox")
local LIST_URL = tostring(CFG.ListUrl or "https://raw.sellaccroblox.com/raw/raws/MM2/listitems.txt")
local USER_ID = tostring(CFG.UserID or env.USER_ID or USER_ID or "lilbip222")
local AUDIT_API_URL = tostring(CFG.AuditApiUrl or CFG.MM2AuditApiUrl or HUB_CFG.AuditApiUrl or HUB_CFG.MM2AuditApiUrl or "https://raw.sellaccroblox.com/mm2/api/log.php")
local AUDIT_API_SECRET = tostring(CFG.AuditApiSecret or CFG.MM2AuditApiSecret or HUB_CFG.AuditApiSecret or HUB_CFG.MM2AuditApiSecret or "DC80XwABBqbNKegjf1mOuQRPwoCX2zfSusUpVnOEQ")
local AUDIT_BOX_TYPE = tostring(CFG.AuditBoxType or CFG.BoxName or HUB_CFG.AuditBoxType or HUB_CFG.BoxName or "unknown")
local CHECK_INTERVAL = math.max(5, tonumber(CFG.CheckInterval) or 30)
local MINIMUM_TRADE_LEVEL = math.max(1, math.floor(tonumber(CFG.MinimumTradeLevel) or 10))
local http = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
local DEFAULT_ITEMS = {
    { id = "Icecream", name = "Icecream", min = 1, max = 999999, type = "Weapons" },
    { id = "IcecreamChroma", name = "IcecreamChroma", min = 1, max = 999999, type = "Weapons" }
}
local unpackFn = table.unpack or unpack

env.USER_ID = USER_ID
env.listitems = env.listitems or {}
env.MM2AuditLoggedOpenCrateResults = env.MM2AuditLoggedOpenCrateResults or {}
local auditLoggedOpenCrateResults = env.MM2AuditLoggedOpenCrateResults
env.MM2AuditRecentOpenKeys = env.MM2AuditRecentOpenKeys or {}
local auditRecentOpenKeys = env.MM2AuditRecentOpenKeys
env.MM2AuditPendingCrateBoxId = env.MM2AuditPendingCrateBoxId or nil

local function log(msg)
    print("[MM2][checkitems] " .. tostring(msg))
end

local function logWarn(msg)
    warn("[MM2][checkitems] " .. tostring(msg))
end

-- Read the local player's actual level without using profile/template UI values.
local function levelNumber(value)
    if type(value) == "number" then
        return math.floor(value)
    end
    return tonumber(tostring(value or ""):match("%d+"))
end

local function getCharacterLevel()
    for _, rootName in ipairs({ "leaderstats", "Stats", "Data" }) do
        local root = player:FindFirstChild(rootName)
        if root then
            for _, child in ipairs(root:GetChildren()) do
                local name = child.Name:lower()
                if (name == "level" or name == "lvl" or name == "rank") and child:IsA("ValueBase") then
                    local level = levelNumber(child.Value)
                    if level then return level, child:GetFullName() end
                end
            end
        end
    end

    for attribute, value in pairs(player:GetAttributes()) do
        local name = attribute:lower()
        if name == "level" or name == "lvl" or name == "rank" then
            local level = levelNumber(value)
            if level then return level, "attribute " .. attribute end
        end
    end

    -- MM2's live leaderboard row is named after LocalPlayer; this avoids stale
    -- LevelUp/profile widgets that can show unrelated values.
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("MainGUI")
    local gameGui = mainGui and mainGui:FindFirstChild("Game")
    local leaderboard = gameGui and gameGui:FindFirstChild("Leaderboard")
    local container = leaderboard and leaderboard:FindFirstChild("Container")
    local row = container and container:FindFirstChild(player.Name)
    if row then
        for _, descendant in ipairs(row:GetDescendants()) do
            if descendant.Name:lower() == "level" and (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) then
                local level = levelNumber(descendant.Text)
                if level then return level, descendant:GetFullName() end
            end
        end
    end

    return nil
end

local function sendWebhook(message)
    local url = CFG.WebhookUrl
    if type(url) ~= "string" or url == "" or not http then
        return
    end

    pcall(function()
        http({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = player.Name .. " " .. tostring(message),
                username = "Bot Debug Log - MM2"
            })
        })
    end)
end

local function sendAuditLog(eventName, payload)
    if not http or AUDIT_API_URL == "" then
        return
    end

    payload = type(payload) == "table" and payload or {}
    payload.event = tostring(eventName or payload.event or "")
    payload.secret = AUDIT_API_SECRET
    payload.source = payload.source or "checkitems"
    payload.owner_user_id = payload.owner_user_id or USER_ID
    payload.username = payload.username or tostring(player.Name)
    payload.display_name = payload.display_name or tostring(player.DisplayName)
    payload.roblox_user_id = payload.roblox_user_id or tostring(player.UserId)
    payload.job_id = payload.job_id or tostring(game.JobId)
    payload.place_id = payload.place_id or tostring(game.PlaceId)
    payload.client_time = payload.client_time or os.date("!%Y-%m-%dT%H:%M:%SZ")

    task.spawn(function()
        local ok, response = pcall(function()
            return http({
                Url = AUDIT_API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if not ok then
            logWarn("Gui audit DB loi: " .. tostring(response))
            return
        end

        local statusCode = response and (response.StatusCode or response.status_code or response.Status)
        if statusCode and (tonumber(statusCode) or 0) >= 400 then
            logWarn("Gui audit DB HTTP " .. tostring(statusCode))
        else
            log("Da gui audit DB " .. tostring(eventName))
        end
    end)
end

local function updateList(url, globalKey)
    if type(env[globalKey]) == "table" and next(env[globalKey]) then
        return true
    end
    if type(url) ~= "string" or url == "" or not http then
        return false
    end

    while true do
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
                    return true
                end
            end

            if attempt < maxRetries then
                task.wait(3)
            end
        end

        if type(env[globalKey]) == "table" and next(env[globalKey]) then
            return true
        end

        logWarn("Danh sach trong, thu lai...")
        task.wait(8)
    end
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

local Sync
local function getSync()
    if type(Sync) == "table" then
        return Sync
    end
    local database = ReplicatedStorage:FindFirstChild("Database")
    local syncModule = database and database:FindFirstChild("Sync")
    if not syncModule then
        return nil
    end
    local ok, result = pcall(require, syncModule)
    if ok and type(result) == "table" then
        Sync = result
        return Sync
    end
    return nil
end

local function weaponInfo(itemId)
    local sync = getSync()
    local id = tostring(itemId or "")
    if type(sync) ~= "table" or id == "" then
        return nil
    end
    if type(sync.Weapons) == "table" and type(sync.Weapons[id]) == "table" then
        return sync.Weapons[id]
    end
    if type(sync.Item) == "table" and type(sync.Item[id]) == "table" then
        return sync.Item[id]
    end
    return nil
end

local function extractRewardIds(result)
    local ids = {}
    if type(result) == "table" then
        if result.RewardedItemId ~= nil then
            ids[#ids + 1] = result.RewardedItemId
        end
        for _, value in pairs(result) do
            if type(value) == "table" and value.RewardedItemId ~= nil then
                ids[#ids + 1] = value.RewardedItemId
            end
        end
    elseif type(result) == "string" then
        ids[#ids + 1] = result
    end
    return ids
end

local function openedItemName(itemId)
    local id = tostring(itemId or "")
    local rules = normalizeListItems(getListSource())
    if rules[id] and type(rules[id].name) == "string" and rules[id].name ~= "" then
        return rules[id].name
    end

    local info = weaponInfo(id)
    if type(info) == "table" then
        return tostring(info.Name or info.ItemName or info.DisplayName or id)
    end

    return id
end

local function shouldLogOpenedItem(itemId)
    local id = tostring(itemId or "")
    if id == "" then
        return false
    end

    local rules = normalizeListItems(getListSource())
    if rules[id] ~= nil then
        return true
    end

    local info = weaponInfo(id)
    return type(info) == "table" and tostring(info.Rarity or "") == "Godly"
end

local function logOpenedBoxReward(boxType, result, source)
    local rewardIds = extractRewardIds(result)
    if #rewardIds == 0 then
        return
    end

    for _, rawId in ipairs(rewardIds) do
        local id = tostring(rawId or "")
        if shouldLogOpenedItem(id) then
            -- CrateComplete and OpenCrate can both fire for a single opening.
            -- Suppress only the near-simultaneous duplicate, not later identical drops.
            local key = tostring(boxType or "unknown") .. "|" .. id
            local now = os.clock()
            local previousAt = tonumber(auditRecentOpenKeys[key]) or 0
            auditRecentOpenKeys[key] = now
            if now - previousAt < 2 then
                continue
            end

            local resultKey = type(result) == "table" and tostring(result) or tostring(now)
            local uniqueKey = resultKey .. "|" .. id
            if not auditLoggedOpenCrateResults[uniqueKey] then
                auditLoggedOpenCrateResults[uniqueKey] = true
                sendAuditLog("godly_opened", {
                    username = tostring(player.Name),
                    box_type = tostring(boxType or AUDIT_BOX_TYPE or "unknown"),
                    item_id = id,
                    item_name = openedItemName(id),
                    amount = 1,
                    status = "pending_trade",
                    source = tostring(source or "checkitems_opencrate")
                })
            end
        end
    end
end

local function logCrateComplete(...)
    local args = table.pack(...)
    local boxType = args[1]
    local rewards = {}

    -- The event format can vary by crate type/game update.  Preserve any
    -- structured RewardedItemId values and test plain string arguments against
    -- the configured/godly item list before logging them.
    for i = 1, args.n do
        local value = args[i]
        if type(value) == "table" then
            for _, id in ipairs(extractRewardIds(value)) do
                rewards[#rewards + 1] = id
            end
        elseif type(value) == "string" and shouldLogOpenedItem(value) then
            rewards[#rewards + 1] = value
        end
    end

    if #rewards > 0 then
        logOpenedBoxReward(boxType, { RewardedItemId = rewards[1] }, "checkitems_cratecomplete")
        for index = 2, #rewards do
            logOpenedBoxReward(boxType, { RewardedItemId = rewards[index] }, "checkitems_cratecomplete")
        end
    end
end

local function installOpenCrateAuditHook()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local shop = remotes and remotes:FindFirstChild("Shop")
    local crateComplete = shop and shop:FindFirstChild("CrateComplete")
	if not env.MM2AuditCrateCompleteHookInstalled
		and crateComplete and crateComplete:IsA("RemoteEvent") then
        local okEvent, eventErr = pcall(function()
            env.MM2AuditCrateCompleteConnection = crateComplete.OnClientEvent:Connect(logCrateComplete)
        end)
        if okEvent then
			env.MM2AuditCrateCompleteHookInstalled = true
            log("Da nghe CrateComplete de log godly mo box")
        else
            logWarn("Hook CrateComplete loi: " .. tostring(eventErr))
        end
    end

	local wrap = type(newcclosure) == "function" and newcclosure or function(fn)
		return fn
	end

	if env.MM2AuditOpenCrateHookInstalled then
		-- A previous checkitems instance may already own the OpenCrate hook.
		-- Install the new CrateComplete FireServer observer separately so the
		-- audit fix also takes effect without requiring a game rejoin.
		if not env.MM2AuditCrateCompleteFireServerHookInstalled
			and type(hookmetamethod) == "function"
			and type(getnamecallmethod) == "function" then
			local okFire, fireErr = pcall(function()
				local previousNamecall
				previousNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
					local method = getnamecallmethod()
					if method == "FireServer" and self.Name == "CrateComplete"
						and self.ClassName == "RemoteEvent" then
						local args = { ... }
						if args[1] ~= nil then
							logOpenedBoxReward(env.MM2AuditPendingCrateBoxId, args[1], "checkitems_cratecomplete_fireserver")
						end
					end
					return previousNamecall(self, ...)
				end))
				if type(previousNamecall) ~= "function" then
					error("hookmetamethod khong tra ve previousNamecall")
				end
			end)
			if okFire then
				env.MM2AuditCrateCompleteFireServerHookInstalled = true
				log("Da bo sung hook CrateComplete:FireServer cho instance checkitems cu")
			else
				logWarn("Hook CrateComplete:FireServer loi: " .. tostring(fireErr))
			end
		end
		return
	end

    if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        local okHook, hookErr = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                local method = getnamecallmethod()
				-- The game reports the displayed reward with a client -> server
				-- CrateComplete:FireServer(rewardId) call after BoxController:Fire.
				-- This is the reliable completion signal for the audit logger.
				if method == "FireServer" then
					local isCrateComplete = false
					pcall(function()
						isCrateComplete = self.Name == "CrateComplete"
							and self.ClassName == "RemoteEvent"
					end)
					if isCrateComplete then
						local args = { ... }
						if args[1] ~= nil then
							logOpenedBoxReward(
								env.MM2AuditPendingCrateBoxId,
								args[1],
								"checkitems_cratecomplete_fireserver"
							)
						end
					end
					return oldNamecall(self, ...)
				end
                if method ~= "InvokeServer" then
                    return oldNamecall(self, ...)
                end

                local isOpenCrate = false
                pcall(function()
                    isOpenCrate = self.Name == "OpenCrate" and self.ClassName == "RemoteFunction"
                end)
                if not isOpenCrate then
                    return oldNamecall(self, ...)
                end

                local args = { ... }
                local results = { oldNamecall(self, ...) }
				env.MM2AuditPendingCrateBoxId = args[1]
                logOpenedBoxReward(args[1], results[1])
                return unpackFn(results)
            end))
            if type(oldNamecall) ~= "function" then
                error("hookmetamethod khong tra ve oldNamecall")
            end
        end)
        if okHook then
            env.MM2AuditOpenCrateHookInstalled = true
            log("Da hook OpenCrate bang __namecall de log godly mo box")
            return
        end
        logWarn("Hook __namecall OpenCrate loi: " .. tostring(hookErr))
    end

    if type(hookfunction) == "function" then
        local openCrate = shop and shop:FindFirstChild("OpenCrate")
        if openCrate and openCrate:IsA("RemoteFunction") then
            local okHook, hookErr = pcall(function()
                local oldInvoke
                oldInvoke = hookfunction(openCrate.InvokeServer, wrap(function(self, ...)
                    local args = { ... }
                    local results = { oldInvoke(self, ...) }
                    if self == openCrate then
						env.MM2AuditPendingCrateBoxId = args[1]
                        logOpenedBoxReward(args[1], results[1])
                    end
                    return unpackFn(results)
                end))
                if type(oldInvoke) ~= "function" then
                    error("hookfunction khong tra ve oldInvoke")
                end
            end)
            if okHook then
                env.MM2AuditOpenCrateHookInstalled = true
                log("Da hook OpenCrate.InvokeServer de log godly mo box")
                return
            end
            logWarn("Hook OpenCrate.InvokeServer loi: " .. tostring(hookErr))
        end
    end

    logWarn("Executor khong ho tro hook OpenCrate, khong the log box event trong checkitems")
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

local function checkitems()
    updateList(LIST_URL, "listitems")

    local rules = normalizeListItems(getListSource())
    if next(rules) == nil then
        logWarn("listitems rong hoac sai dinh dang")
        return false
    end

    local counts = getInventoryCounts()
    if not counts then
        logWarn("Khong doc duoc ProfileData.Weapons.Owned")
        return false
    end

    local hasRequired = false
    for itemId, rule in pairs(rules) do
        local have = counts[itemId] or 0
        if have >= rule.min then
            log("Du dieu kien: co " .. tostring(have) .. "x " .. itemId)
            hasRequired = true
        else
            log("Chua du: " .. itemId .. " = " .. tostring(have) .. "/" .. tostring(rule.min))
        end
    end

    return hasRequired
end

local function getAvailableGiftJobs(id)
    if not http then
        return {}
    end

    local url = API_URL .. "/main/availablegift?UserID=" .. tostring(id)
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
                local availableJobs = {}
                for _, job in ipairs(result.availableJobs or {}) do
                    local status = tostring(job.status or "")
                    if status == "" or status == "0" or status == "false" then
                        table.insert(availableJobs, job)
                    end
                end
                return availableJobs
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

local function pickJob(jobList)
    local preferred = tostring(CFG.Partner or env.selectedMainID or "")
    local preferredJobs = {}

    for _, job in ipairs(jobList or {}) do
        local mainID = job.main_id or job.mainId or job.MainID
        if preferred == "" or mainID == preferred then
            table.insert(preferredJobs, job)
        end
    end

    if #preferredJobs > 0 then
        return preferredJobs[math.random(1, #preferredJobs)]
    end
    if #jobList > 0 then
        return jobList[math.random(1, #jobList)]
    end
    return nil
end

local pendingMainTeleport = nil
local teleportKickStarted = false

local function getGuiErrorCode()
    local ok, code = pcall(function()
        local errorCode = GuiService:GetErrorCode()
        return errorCode and errorCode.Value
    end)

    if ok then
        return tonumber(code)
    end
    return nil
end

local function clearTeleportError()
    pcall(function()
        GuiService:ClearError()
    end)
end

local function isTeleportServerFull(teleportResult, errorMessage)
    local text = (tostring(teleportResult or "") .. " " .. tostring(errorMessage or "")):lower()
    local guiErrorCode = getGuiErrorCode()
    return guiErrorCode == 772
        or text:find("772", 1, true) ~= nil
        or text:find("gamefull", 1, true) ~= nil
        or text:find("serverfull", 1, true) ~= nil
        or text:find("server full", 1, true) ~= nil
        or text:find("game is full", 1, true) ~= nil
        or text:find("full", 1, true) ~= nil
end

local function markTeleportServerFull(reason)
    logWarn("Teleport toi main fail do server full -> retry job khac: " .. tostring(reason))
    pendingMainTeleport = nil
    clearTeleportError()
end

local function kickTeleportUnavailable(reason)
    if teleportKickStarted then
        return
    end
    teleportKickStarted = true
    logWarn("Teleport toi main that bai, khong phai server full -> kick: " .. tostring(reason))
    task.wait(1)
    pcall(function()
        player:Kick("MM2 checkitems: teleport failed, can restart executor/teleport. " .. tostring(reason))
    end)
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(failedPlayer, teleportResult, errorMessage)
        if failedPlayer ~= player then
            return
        end

        if not pendingMainTeleport or os.clock() - pendingMainTeleport.startedAt > 30 then
            return
        end

        local reason = tostring(teleportResult) .. " | " .. tostring(errorMessage)
        if isTeleportServerFull(teleportResult, errorMessage) then
            markTeleportServerFull(reason)
            return
        end

        pendingMainTeleport = nil
        kickTeleportUnavailable(reason)
    end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        if pendingMainTeleport then
            local age = os.clock() - pendingMainTeleport.startedAt
            if age > 30 then
                pendingMainTeleport = nil
            else
                local errorCode = getGuiErrorCode()
                if errorCode == 772 then
                    markTeleportServerFull("Error Code 772")
                elseif errorCode and errorCode ~= 0 then
                    pendingMainTeleport = nil
                    kickTeleportUnavailable("Error Code " .. tostring(errorCode))
                end
            end
        end
    end
end)

local function tradeProcess()
    installOpenCrateAuditHook()

    local announcedLevel = false
    while true do
        local level, levelSource = getCharacterLevel()
        if not announcedLevel then
            log(("Kiem tra level: %s/%d%s"):format(
                tostring(level or "khong doc duoc"),
                MINIMUM_TRADE_LEVEL,
                levelSource and (" | " .. levelSource) or ""
            ))
            announcedLevel = true
        end
        if not level or level < MINIMUM_TRADE_LEVEL then
            log(("Chua mo khoa trade: level %s/%d%s. Bo qua trade/teleport, tiep tuc farm."):format(
                tostring(level or "khong doc duoc"),
                MINIMUM_TRADE_LEVEL,
                levelSource and (" | " .. levelSource) or ""
            ))
            task.wait(CHECK_INTERVAL)
            continue
        end

        local hasItems = checkitems()
        if not hasItems then
            log("Khong co item dat min, thu lai sau " .. tostring(CHECK_INTERVAL) .. "s")
            task.wait(CHECK_INTERVAL)
            continue
        end

        local jobList = getAvailableGiftJobs(USER_ID)
        if #jobList == 0 then
            log("Khong co gift_jobs status=false cho UserID: " .. USER_ID)
            task.wait(CHECK_INTERVAL)
            continue
        end

        local job = pickJob(jobList)
        if not job then
            task.wait(CHECK_INTERVAL)
            continue
        end

        local mainID = job.main_id or job.mainId or job.MainID
        local jobID = job.job_id or job.jobId or job.JobID
        local gameID = tonumber(job.game_id or job.gameId or job.GameID or game.PlaceId) or game.PlaceId

        if not jobID then
            logWarn("Job main thieu JobID")
            task.wait(CHECK_INTERVAL)
            continue
        end

        env.selectedMainID = mainID
        env.selectedMainJob = job

        log(("Teleport den main %s | job=%s | place=%s"):format(tostring(mainID), tostring(jobID), tostring(gameID)))
        sendWebhook("[MM2 checkitems] Teleport den main " .. tostring(mainID))
        clearTeleportError()
        pendingMainTeleport = {
            mainID = mainID,
            jobID = tostring(jobID),
            gameID = gameID,
            startedAt = os.clock()
        }
        local okTeleport, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(gameID, tostring(jobID), player)
        end)
        if not okTeleport then
            if isTeleportServerFull(nil, teleportErr) then
                markTeleportServerFull(teleportErr)
                task.wait(CHECK_INTERVAL)
                continue
            end

            pendingMainTeleport = nil
            kickTeleportUnavailable(teleportErr)
            return
        end
        task.wait(10)
    end
end

task.spawn(tradeProcess)
