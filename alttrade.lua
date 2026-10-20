--[[
    MM2 AUTO TRADE - ALT/SENDER
    Tach tu trade_sender.lua theo structure giong alttradeSP.lua.
    Chay tren alt sau khi alt da cung server voi main.
]]
getgenv().daubuoi = true
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
local RAW_URLS = {
    Config = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/config.lua",
    AltTrade = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/alttrade.lua",
    CheckItems = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/checkitem.lua",
    Farm = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/farm.lua",
    ListItems = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/listitem.txt"
}

getgenv().ThieuNangTradeMM2 = getgenv().ThieuNangTradeMM2 or {
    Partner = "",
    Items = { "Icecream", "IcecreamChroma" },
    ListUrl = RAW_URLS.ListItems,
    ScriptUrls = {
        Config = RAW_URLS.Config,
        AltTrade = RAW_URLS.AltTrade,
        CheckItems = RAW_URLS.CheckItems,
        Farm = RAW_URLS.Farm
    },
    MaxSlots = 4,
    KickWhenDone = false,
    RejoinWhenDone = true,
    SendAllGodly = false
}

local CFG = (type(env.ThieuNangTradeMM2) == "table" and env.ThieuNangTradeMM2) or {}
if type(CFG.Items) ~= "table" or next(CFG.Items) == nil then
    CFG.Items = { "Icecream", "IcecreamChroma" }
end
CFG.ListUrl = (type(CFG.ListUrl) == "string" and CFG.ListUrl ~= "" and CFG.ListUrl) or RAW_URLS.ListItems
CFG.ScriptUrls = type(CFG.ScriptUrls) == "table" and CFG.ScriptUrls or {}
CFG.ScriptUrls.Config = CFG.ScriptUrls.Config or RAW_URLS.Config
CFG.ScriptUrls.AltTrade = CFG.ScriptUrls.AltTrade or RAW_URLS.AltTrade
CFG.ScriptUrls.CheckItems = CFG.ScriptUrls.CheckItems or RAW_URLS.CheckItems
CFG.ScriptUrls.Farm = CFG.ScriptUrls.Farm or RAW_URLS.Farm
if CFG.MaxSlots == nil then
    CFG.MaxSlots = 4
end
if CFG.KickWhenDone == nil then
    CFG.KickWhenDone = false
end
if CFG.RejoinWhenDone == nil then
    CFG.RejoinWhenDone = true
end
if CFG.SendAllGodly == nil then
    CFG.SendAllGodly = false
end

local function firstText(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return ""
end

local PARTNER = firstText(CFG.Partner, env.selectedMainID)
local TRADE_WEBHOOK_URL = firstText(
    CFG.TradeWebhookUrl,
    CFG.WebhookUrl,
    "https://discord.com/api/webhooks/1330887813100474471/8h78ZwIIwxtDjruel6fQpneAa1xLlK9KJhgXRV1LifZZovQiaTFKn-uFSdUg3z4fZRx0"
)
local AUDIT_API_URL = firstText(CFG.AuditApiUrl, CFG.MM2AuditApiUrl, "https://raw.sellaccroblox.com/mm2/api/log.php")
local AUDIT_API_SECRET = firstText(CFG.AuditApiSecret, CFG.MM2AuditApiSecret, "DC80XwABBqbNKegjf1mOuQRPwoCX2zfSusUpVnOEQ")
local OWNER_USER_ID = firstText(CFG.UserID, CFG.USER_ID, CFG.OwnerUserID, CFG.ScriptUserID, env.USER_ID)
local MAX_SLOTS = math.max(1, tonumber(CFG.MaxSlots) or 4)
local COOLDOWN = tonumber(CFG.Cooldown) or 6.5
local KICK_WHEN_DONE = CFG.KickWhenDone == true
local REJOIN_WHEN_DONE = CFG.RejoinWhenDone == true
local SEND_ALL_GODLY = CFG.SendAllGodly == true
local http = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
local DEFAULT_ITEMS = {
    { id = "Icecream", name = "Icecream", min = 1, max = 999999, type = "Weapons" },
    { id = "IcecreamChroma", name = "IcecreamChroma", min = 1, max = 999999, type = "Weapons" }
}

local function log(msg)
    print("[MM2][alttrade] " .. tostring(msg))
end

local function logWarn(msg)
    warn("[MM2][alttrade] " .. tostring(msg))
end

if PARTNER == "" then
    logWarn("Thieu Partner/selectedMainID.")
    return
end

local Trade = ReplicatedStorage:WaitForChild("Trade", 15)
if not Trade then
    logWarn("Khong thay ReplicatedStorage.Trade")
    return
end

local R_SendRequest = Trade:WaitForChild("SendRequest", 10)
local R_OfferItem = Trade:WaitForChild("OfferItem", 10)
local R_AcceptTrade = Trade:WaitForChild("AcceptTrade", 10)
local R_StartTrade = Trade:WaitForChild("StartTrade", 10)
local R_UpdateTrade = Trade:WaitForChild("UpdateTrade", 10)
local R_DeclineTrade = Trade:WaitForChild("DeclineTrade", 10)

if not (R_SendRequest and R_OfferItem and R_AcceptTrade and R_StartTrade and R_UpdateTrade and R_DeclineTrade) then
    logWarn("Thieu remote trade can thiet")
    return
end

local function getProfileData()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local pd = modules and modules:FindFirstChild("ProfileData")
    if not pd then
        return nil
    end
    local ok, result = pcall(require, pd)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function getSync()
    local database = ReplicatedStorage:FindFirstChild("Database")
    local syncScript = database and database:FindFirstChild("Sync")
    if not syncScript then
        return nil
    end
    local ok, result = pcall(require, syncScript)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local ProfileData = getProfileData()
if not ProfileData then
    logWarn("Khong doc duoc ProfileData")
    return
end

local Sync = SEND_ALL_GODLY and getSync() or nil

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

local function buildDemandFromSelected()
    local selected = env.selectedOfferItems
    if type(selected) ~= "table" or next(selected) == nil then
        selected = CFG.OfferItems
    end
    if type(selected) ~= "table" or next(selected) == nil then
        return nil
    end

    local demand = {}
    if #selected > 0 then
        for _, item in ipairs(selected) do
            if type(item) == "table" then
                local id = item.id or item.ID or item.itemId or item.ItemID or item.name or item.Name
                if type(id) == "string" and id ~= "" then
                    demand[id] = {
                        amount = (demand[id] and demand[id].amount or 0) + math.max(1, math.floor(tonumber(item.amount or item.quantity or item.count or 1) or 1)),
                        type = tostring(item.type or item.Type or item.category or item.Category or "Weapons")
                    }
                end
            elseif type(item) == "string" and item ~= "" then
                demand[item] = { amount = (demand[item] and demand[item].amount or 0) + 1, type = "Weapons" }
            end
        end
    else
        for itemId, amount in pairs(selected) do
            if type(itemId) == "string" and itemId ~= "" then
                if type(amount) == "table" then
                    demand[itemId] = {
                        amount = math.max(1, math.floor(tonumber(amount.amount or amount.quantity or amount.count or amount.max or 1) or 1)),
                        type = tostring(amount.type or amount.Type or amount.category or amount.Category or "Weapons")
                    }
                else
                    demand[itemId] = {
                        amount = math.max(1, math.floor(tonumber(amount) or 1)),
                        type = "Weapons"
                    }
                end
            end
        end
    end

    if next(demand) == nil then
        return nil
    end
    return demand
end

local function buildWantedIds()
    local wanted = {}
    local rules = normalizeListItems(getListSource())
    for itemId in pairs(rules) do
        wanted[itemId] = true
    end

    if next(wanted) == nil then
        wanted.Icecream = true
        wanted.IcecreamChroma = true
    end

    return wanted
end

local DEMAND = buildDemandFromSelected()
local WANTED_IDS = buildWantedIds()

local S = {
    InTrade = false,
    LastOffer = nil,
    LastUpdateAt = 0,
    MyOffer = {},
    AcceptedOffer = {},
    Sent = {},
    Accepted = false,
    RoundDone = false,
    Declined = false
}

local function copyMap(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function mapTotal(source)
    local total = 0
    for _, amount in pairs(source or {}) do
        total = total + amount
    end
    return total
end

local function trimDiscordText(text, limit)
    text = tostring(text or "")
    limit = tonumber(limit) or 1000
    if #text <= limit then
        return text
    end
    return string.sub(text, 1, math.max(1, limit - 20)) .. "... (cat bot)"
end

local function itemDisplayName(id)
    id = tostring(id or "")
    local rules = normalizeListItems(getListSource())
    if rules[id] and type(rules[id].name) == "string" and rules[id].name ~= "" then
        return rules[id].name
    end
    return id
end

local function formatOfferItems(offer)
    local rows = {}
    for itemId, amount in pairs(offer or {}) do
        local id = tostring(itemId)
        local name = itemDisplayName(id)
        local count = math.max(1, math.floor(tonumber(amount) or 1))
        if name ~= id then
            rows[#rows + 1] = ("%s (%s) x%s"):format(name, id, tostring(count))
        else
            rows[#rows + 1] = ("%s x%s"):format(id, tostring(count))
        end
    end

    table.sort(rows)
    if #rows == 0 then
        return "Khong doc duoc item"
    end
    return table.concat(rows, "\n")
end

local function sendTradeWebhook(receiver, offer)
    if not http or TRADE_WEBHOOK_URL == "" then
        return
    end

    local itemsText = trimDiscordText(formatOfferItems(offer), 1000)
    local payload = {
        username = "MM2 Trade Logger",
        embeds = {
            {
                title = "MM2 trade thanh cong",
                color = 5763719,
                fields = {
                    { name = "Nguoi gui", value = tostring(LocalPlayer.Name), inline = true },
                    { name = "Nguoi nhan", value = tostring(receiver or PARTNER), inline = true },
                    { name = "Items", value = itemsText, inline = false },
                    { name = "JobId", value = trimDiscordText(game.JobId, 1000), inline = false }
                }
            }
        }
    }

    task.spawn(function()
        local ok, response = pcall(function()
            return http({
                Url = TRADE_WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if not ok then
            logWarn("Gui webhook trade loi: " .. tostring(response))
            return
        end

        local statusCode = response and (response.StatusCode or response.status_code or response.Status)
        if statusCode and (tonumber(statusCode) or 0) >= 400 then
            logWarn("Gui webhook trade HTTP " .. tostring(statusCode))
        else
            log("Da gui webhook trade thanh cong")
        end
    end)
end

local function sendAuditLog(eventName, payload)
    if not http or AUDIT_API_URL == "" then
        return
    end

    payload = type(payload) == "table" and payload or {}
    payload.event = tostring(eventName or payload.event or "")
    payload.source = payload.source or "alttrade"
    payload.secret = AUDIT_API_SECRET
    payload.owner_user_id = payload.owner_user_id or OWNER_USER_ID
    payload.account = payload.account or tostring(LocalPlayer.Name)
    payload.display_name = payload.display_name or tostring(LocalPlayer.DisplayName)
    payload.roblox_user_id = payload.roblox_user_id or tostring(LocalPlayer.UserId)
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

local function isGodly(id)
    return Sync
        and type(Sync.Weapons) == "table"
        and type(Sync.Weapons[id]) == "table"
        and Sync.Weapons[id].Rarity == "Godly"
end

local function isWantedItem(id)
    if DEMAND then
        return DEMAND[id] ~= nil
    end
    return WANTED_IDS[id] == true or (SEND_ALL_GODLY and isGodly(id))
end

local function itemTypeFor(id)
    if DEMAND and DEMAND[id] and DEMAND[id].type then
        return DEMAND[id].type
    end
    local rules = normalizeListItems(getListSource())
    if rules[id] and rules[id].type then
        return rules[id].type
    end
    return "Weapons"
end

local function currentOwned()
    local owned = ProfileData
        and type(ProfileData.Weapons) == "table"
        and type(ProfileData.Weapons.Owned) == "table"
        and ProfileData.Weapons.Owned
    return owned or {}
end

local function wantedLeftFor(id, have, subtractOffer)
    if not isWantedItem(id) then
        return 0
    end

    local offered = subtractOffer and (S.MyOffer[id] or 0) or 0
    if DEMAND then
        local demand = DEMAND[id] and DEMAND[id].amount or 0
        return math.max(0, math.min(have - offered, demand - (S.Sent[id] or 0) - offered))
    end

    return math.max(0, have - offered)
end

local function itemsRemaining(subtractOffer)
    local list = {}
    local total = 0
    for itemId, count in pairs(currentOwned()) do
        local id = tostring(itemId)
        local have = math.max(0, math.floor(tonumber(count) or 0))
        local remaining = wantedLeftFor(id, have, subtractOffer == true)
        if remaining > 0 then
            list[#list + 1] = {
                id = id,
                count = remaining,
                type = itemTypeFor(id)
            }
            total = total + remaining
        end
    end
    table.sort(list, function(a, b)
        return a.id < b.id
    end)
    return list, total
end

local function readOffer(offer)
    local map = {}
    if type(offer) == "table" then
        for _, value in ipairs(offer) do
            if type(value) == "table" then
                local id = tostring(value[1] or value.ItemID or value.id or "")
                local amount = math.max(1, math.floor(tonumber(value[2] or value.Amount or value.amount or 1) or 1))
                local itemType = tostring(value[3] or value.ItemType or value.type or "Weapons")
                if id ~= "" and itemType == "Weapons" then
                    map[id] = (map[id] or 0) + amount
                end
            end
        end
    end
    return map
end

local function mySide(tradeData)
    if type(tradeData) ~= "table" then
        return nil
    end
    if type(tradeData.Player1) == "table" and tradeData.Player1.Player == LocalPlayer then
        return tradeData.Player1, tradeData.Player2
    end
    if type(tradeData.Player2) == "table" and tradeData.Player2.Player == LocalPlayer then
        return tradeData.Player2, tradeData.Player1
    end
    return nil
end

local function countMyOfferUnits()
    local total = 0
    for _, amount in pairs(S.MyOffer) do
        total = total + amount
    end
    return total
end

R_StartTrade.OnClientEvent:Connect(function(tradeData, partnerName)
    if tostring(partnerName) ~= PARTNER then
        pcall(function()
            R_DeclineTrade:FireServer()
        end)
        logWarn("Trade voi nguoi la (" .. tostring(partnerName) .. ") -> decline")
        return
    end

    S.InTrade = true
    S.Accepted = false
    S.RoundDone = false
    S.Declined = false
    S.AcceptedOffer = {}
    S.LastOffer = type(tradeData) == "table" and tradeData.LastOffer or nil
    S.LastUpdateAt = os.clock()
    local mine = mySide(tradeData)
    S.MyOffer = mine and readOffer(mine.Offer) or {}
    log("Trade da mo voi " .. PARTNER)
end)

R_UpdateTrade.OnClientEvent:Connect(function(tradeData)
    if not S.InTrade then
        return
    end
    S.LastOffer = type(tradeData) == "table" and tradeData.LastOffer or nil
    S.LastUpdateAt = os.clock()
    local mine = mySide(tradeData)
    if mine then
        S.MyOffer = readOffer(mine.Offer)
    end
    S.Accepted = false
end)

R_AcceptTrade.OnClientEvent:Connect(function(success)
    if success then
        local sentOffer = mapTotal(S.MyOffer) > 0 and S.MyOffer or S.AcceptedOffer
        for itemId, amount in pairs(sentOffer) do
            S.Sent[itemId] = (S.Sent[itemId] or 0) + amount
        end
        sendTradeWebhook(PARTNER, sentOffer)
        sendAuditLog("trade_success", {
            sender_username = tostring(LocalPlayer.Name),
            receiver_username = tostring(PARTNER),
            items_text = formatOfferItems(sentOffer),
            items = sentOffer,
            total_items = mapTotal(sentOffer),
            status = "traded",
        })
        S.InTrade = false
        S.RoundDone = true
        S.AcceptedOffer = {}
        log("Trade thanh cong 1 vong, da ghi nhan " .. tostring(mapTotal(sentOffer)) .. " item")
    end
end)

R_DeclineTrade.OnClientEvent:Connect(function()
    if S.InTrade then
        logWarn("Trade bi huy/decline")
    end
    S.InTrade = false
    S.Declined = true
    S.AcceptedOffer = {}
end)

local function sendRequest(partnerPlayer)
    task.spawn(function()
        pcall(function()
            R_SendRequest:InvokeServer(partnerPlayer)
        end)
    end)
end

local function fillOffer()
    local placed = countMyOfferUnits()
    local list = select(1, itemsRemaining(true))
    for _, entry in ipairs(list) do
        for _ = 1, entry.count do
            if not S.InTrade or placed >= MAX_SLOTS then
                return
            end

            local before = S.MyOffer[entry.id] or 0
            pcall(function()
                R_OfferItem:FireServer(entry.id, entry.type or "Weapons")
            end)

            local deadline = os.clock() + 5
            repeat
                task.wait(0.2)
            until not S.InTrade
                or (S.MyOffer[entry.id] or 0) > before
                or os.clock() > deadline

            if (S.MyOffer[entry.id] or 0) > before then
                placed = placed + 1
                log("Da add " .. entry.id .. " (" .. placed .. "/" .. MAX_SLOTS .. ")")
            else
                logWarn("Server khong nhan them " .. entry.id .. " -> bo qua item nay")
                break
            end
        end
    end
end

local function acceptLoop()
    while S.InTrade and not S.RoundDone do
        if countMyOfferUnits() > 0
            and not S.Accepted
            and os.clock() - S.LastUpdateAt >= COOLDOWN then
            S.AcceptedOffer = copyMap(S.MyOffer)
            pcall(function()
                R_AcceptTrade:FireServer(game.PlaceId * 3, S.LastOffer)
            end)
            S.Accepted = true
            log("Da bam accept, cho main...")
        end
        task.wait(0.5)
    end
end

local rejoining = false
local function rejoinServer(reason)
    if reason then
        log(reason)
    end
    if rejoining then
        return
    end

    rejoining = true
    task.spawn(function()
        local attempt = 0
        while rejoining do
            attempt = attempt + 1
            local ok, err = pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            if ok then
                log("Da goi Teleport rejoin lan " .. tostring(attempt))
                task.wait(10)
            else
                logWarn("Rejoin loi lan " .. tostring(attempt) .. ": " .. tostring(err))
                task.wait(5)
            end
        end
    end)
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(failedPlayer, teleportResult, errorMessage)
        if failedPlayer == LocalPlayer and rejoining then
            logWarn("Teleport fail: " .. tostring(teleportResult) .. " - " .. tostring(errorMessage))
        end
    end)
end)

local function finish()
    log("Da gui xong item can gui")
    if KICK_WHEN_DONE then
        task.wait(2)
        pcall(function()
            LocalPlayer:Kick("MM2: da gui xong item")
        end)
    elseif REJOIN_WHEN_DONE then
        rejoinServer("RejoinWhenDone=true -> dang rejoin")
    else
        log("Da xong nhung RejoinWhenDone=false va KickWhenDone=false")
    end
end

log("Alt trade khoi dong. Main: " .. PARTNER)
task.spawn(function()
    while true do
        local _, total = itemsRemaining(false)
        if total <= 0 then
            finish()
            return
        end

        local partnerPlayer = Players:FindFirstChild(PARTNER)
        if not partnerPlayer then
            log("Cho main vao server: " .. PARTNER .. " | con " .. total .. " item")
            task.wait(5)
        elseif not S.InTrade then
            log("Gui trade request toi " .. PARTNER .. " | con " .. total .. " item")
            sendRequest(partnerPlayer)
            local deadline = os.clock() + 10
            repeat
                task.wait(0.5)
            until S.InTrade or os.clock() > deadline
        else
            fillOffer()
            acceptLoop()
            task.wait(2)
        end
    end
end)
