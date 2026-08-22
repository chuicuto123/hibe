--[[
    MM2 AUTO TRADE - MAIN/RECEIVER
    Main doc lap, submit JobId theo structure BSS.
    Chay tren main: dang JobId, hien item status, auto accept trade request va trade.
]]
task.wait(10)
getgenv().USER_ID = "chuingu"
getgenv().daubuoi = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
if not player then
    return
end
local jobId = game.JobId
local placeId = game.PlaceId

local env = (type(getgenv) == "function" and getgenv()) or _G
local CFG = (type(env.ThieuNangTradeMM2) == "table" and env.ThieuNangTradeMM2) or {}
local RAW_URLS = {
    ListItems = "https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/listitem.txt"
}

local function firstText(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return ""
end

local API_URL = firstText(CFG.ApiUrl, "https://raw.sellaccroblox.com/apiroblox")
local LIST_URL = firstText(CFG.ListUrl, RAW_URLS.ListItems)
env.USER_ID = "chuingu"
local USER_ID = "chuingu"
local PARTNER = firstText(CFG.MainPartner, CFG.ReceivePartner, CFG.ReceiverPartner, "*")
local COOLDOWN = tonumber(CFG.Cooldown) or 6.5
local http = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
local DEFAULT_ITEMS = {
    { id = "Icecream", name = "Icecream", min = 1, max = 999999, type = "Weapons" },
    { id = "IcecreamChroma", name = "IcecreamChroma", min = 1, max = 999999, type = "Weapons" }
}

env.listitems = env.listitems or {}

local function log(msg)
    print("[MM2][main] " .. tostring(msg))
end

local function logWarn(msg)
    warn("[MM2][main] " .. tostring(msg))
end

pcall(function()
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(0, 0))
        task.wait(0.1)
        VirtualUser:Button1Up(Vector2.new(0, 0))
    end)
end)

task.spawn(function()
    while true do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
        end)
        task.wait(60)
    end
end)

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

local function updateList(url, globalKey)
    if type(env[globalKey]) == "table" and next(env[globalKey]) then
        return true
    end
    if url == "" or not http then
        return false
    end

    while true do
        for attempt = 1, 3 do
            local ok, response = pcall(function()
                return http({ Url = url, Method = "GET" })
            end)

            if ok and response and response.Success then
                local okDecode, result = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
                if okDecode and type(result) == "table" then
                    env[globalKey] = result
                    return true
                end
            end

            if attempt < 3 then
                task.wait(3)
            end
        end

        if type(env[globalKey]) == "table" and next(env[globalKey]) then
            return true
        end

        logWarn("Chua load duoc listitems, thu lai...")
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
                local name = row.name or row.Name or id
                local minNum = math.max(1, math.floor(tonumber(row.min or row.Min or 1) or 1))
                local maxNum = math.max(minNum, math.floor(tonumber(row.max or row.Max or minNum) or minNum))
                if type(id) == "string" and id ~= "" then
                    out[id] = {
                        id = id,
                        name = tostring(name),
                        min = minNum,
                        max = maxNum,
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
                local minNum = math.max(1, math.floor(tonumber(cfg.min or cfg.Min or 1) or 1))
                local maxNum = math.max(minNum, math.floor(tonumber(cfg.max or cfg.Max or minNum) or minNum))
                out[id] = {
                    id = id,
                    name = tostring(cfg.name or cfg.Name or id),
                    min = minNum,
                    max = maxNum,
                    type = tostring(cfg.type or cfg.Type or cfg.category or cfg.Category or "Weapons")
                }
            else
                local maxNum = math.max(1, math.floor(tonumber(cfg) or 1))
                out[itemId] = { id = itemId, name = itemId, min = 1, max = maxNum, type = "Weapons" }
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

local function buildInventoryState()
    local counts = getInventoryCounts() or {}
    local state = {}
    local uniqueItems = 0
    local totalUnits = 0

    for itemId, quantity in pairs(counts) do
        local amount = math.max(0, math.floor(tonumber(quantity) or 0))
        if amount > 0 then
            uniqueItems = uniqueItems + 1
            totalUnits = totalUnits + amount
            state[itemId] = amount
        end
    end

    return state, uniqueItems, totalUnits
end

local function snapshotInventory(state)
    local names = {}
    for itemId in pairs(state or {}) do
        names[#names + 1] = itemId
    end
    table.sort(names)

    local parts = {}
    for _, itemId in ipairs(names) do
        parts[#parts + 1] = itemId .. ":" .. tostring(state[itemId] or 0)
    end
    return table.concat(parts, "|")
end

local function buildItemsDetailText(state)
    local names = {}
    for itemId in pairs(state or {}) do
        names[#names + 1] = itemId
    end
    table.sort(names)

    if #names == 0 then
        return "Inventory trong hoac chua doc duoc."
    end

    local lines = {}
    for _, itemId in ipairs(names) do
        lines[#lines + 1] = ("%s : %d"):format(itemId, tonumber(state[itemId] or 0) or 0)
    end
    return table.concat(lines, "\n")
end

local function submitJobId()
    local requestFunction = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or http
    if USER_ID == "" or not requestFunction then
        warn("[MM2][main] Khong gui JobID duoc: thieu USER_ID hoac request function")
        return
    end

    local currentPlayerCount = #Players:GetPlayers()
    local status = currentPlayerCount >= Players.MaxPlayers
    local url = API_URL .. "/main/giftjobid"
    local data = {
        MainID = player.Name,
        JobID = jobId,
        UserID = USER_ID,
        GameID = placeId,
        Status = status
    }
    local bodyJson = HttpService:JSONEncode(data)

    local okRequest, resp = pcall(function()
        return requestFunction({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = bodyJson
        })
    end)

    if not okRequest then
        warn("[MM2][main] Gui JobID loi request: " .. tostring(resp))
        warn("[MM2][main] URL: " .. url .. " | Body: " .. bodyJson)
        return
    end

    if type(resp) ~= "table" then
        warn("[MM2][main] Gui JobID khong co response hop le: " .. tostring(resp))
        warn("[MM2][main] URL: " .. url .. " | Body: " .. bodyJson)
        return
    end

    local statusCode = tonumber(resp.StatusCode or resp.Status or resp.status_code)
    local body = tostring(resp.Body or resp.body or "")
    local bodyStatus = nil

    if body ~= "" then
        local okDecode, payload = pcall(HttpService.JSONDecode, HttpService, body)
        if okDecode and type(payload) == "table" then
            bodyStatus = payload.status or payload.Status
        end
    end

    local explicitFail = resp.Success == false
        or resp.success == false
        or (statusCode and (statusCode < 200 or statusCode >= 300))

    local looksOk = resp.Success == true
        or resp.success == true
        or (statusCode and statusCode >= 200 and statusCode < 300)
        or tostring(bodyStatus or ""):lower() == "success"

    if looksOk then
        if body ~= "" then
            print("[MM2][main] Gui JobID OK: " .. body)
        else
            print("[MM2][main] Gui JobID OK")
        end
    else
        warn(("[MM2][main] Gui JobID loi | code=%s | success=%s | body=%s"):format(
            tostring(statusCode),
            tostring(resp.Success or resp.success),
            body
        ))
        warn("[MM2][main] URL: " .. url .. " | Body: " .. bodyJson)
    end
end

local function rejoinServer()
    TeleportService:Teleport(game.PlaceId, player)
end

local function getServers()
    if not http then
        return {}
    end

    local url = string.format(
        "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
        tostring(game.PlaceId)
    )
    local ok, response = pcall(function()
        return http({ Url = url, Method = "GET" })
    end)
    if not ok or not response or not response.Success then
        return {}
    end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
    if not okDecode or type(data) ~= "table" or type(data.data) ~= "table" then
        return {}
    end

    local servers = {}
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and tonumber(server.playing or 0) < tonumber(server.maxPlayers or 0) then
            servers[#servers + 1] = server
        end
    end
    return servers
end

local function serverhop()
    local servers = getServers()
    if #servers == 0 then
        print("[MM2][main] Khong tim thay server hop duoc, rejoin server hien tai")
        rejoinServer()
        return
    end
    local server = servers[math.random(1, #servers)]
    print("[MM2][main] Server hop toi server id: " .. tostring(server.id) .. " | playing: " .. tostring(server.playing))
    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
end

local function checksoplayer()
    if #Players:GetPlayers() >= Players.MaxPlayers then
        log("Server full nguoi -> serverhop de chua slot cho alt")
        serverhop()
    end
end

local checkingItemChange = false
local function checksoplayer2()
    if checkingItemChange or #Players:GetPlayers() < Players.MaxPlayers then
        return
    end

    checkingItemChange = true
    task.spawn(function()
        local startState = buildInventoryState()
        local startSnapshot = snapshotInventory(startState)

        log("Server vua full, kiem tra item thay doi trong 80s")
        task.wait(80)

        local endState = buildInventoryState()
        local endSnapshot = snapshotInventory(endState)
        checkingItemChange = false

        if #Players:GetPlayers() >= Players.MaxPlayers and startSnapshot == endSnapshot then
            log("Server full va inventory khong doi sau 80s -> serverhop")
            serverhop()
        else
            log("Inventory da doi hoac server khong con full -> tiep tuc cho trade")
        end
    end)
end

local retryingTeleport = false
TeleportService.TeleportInitFailed:Connect(function(failedPlayer, teleportResult, errorMessage)
    if failedPlayer == player and not retryingTeleport then
        retryingTeleport = true
        logWarn("Teleport fail: " .. tostring(teleportResult) .. " - " .. tostring(errorMessage))
        task.wait(5)
        serverhop()
        retryingTeleport = false
    end
end)

local checkingConnectionError = false
local function checkcodeerrors()
    while task.wait(3) do
        pcall(function()
            local okCode, errorCodeObject = pcall(function()
                return GuiService:GetErrorCode()
            end)
            if not okCode or not errorCodeObject then
                return
            end

            local errorCode = tonumber(errorCodeObject.Value) or 0
            local disconnectErrors = Enum.ConnectionError.DisconnectErrors.Value
            local placelaunchOtherError = Enum.ConnectionError.PlacelaunchOtherError.Value

            if errorCode == 273 or errorCode == 772 then
                return
            end

            if errorCode == 529 or errorCode == 773 then
                pcall(function()
                    game:Shutdown()
                end)
                return
            end

            if ((errorCode >= disconnectErrors and errorCode < placelaunchOtherError) or errorCode == 769)
                and not checkingConnectionError then
                checkingConnectionError = true
                logWarn("Phat hien loi ngat ket noi, thuc hien rejoin...")
                pcall(function()
                    if type(setfpscap) == "function" then
                        setfpscap(99)
                    end
                end)
                pcall(rejoinServer)
                task.wait(10)
                checkingConnectionError = false
            end
        end)
    end
end

task.spawn(checkcodeerrors)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2TradeUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 330, 0, 410)
Frame.Position = UDim2.new(0, 10, 0, 80)
Frame.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -46, 0, 40)
Title.Position = UDim2.new(0, 10, 0, 4)
Title.BackgroundTransparency = 1
Title.Text = "AUTO TRADE MM2"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 22
Title.Font = Enum.Font.SourceSansBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 24)
Status.Position = UDim2.new(0, 10, 0, 48)
Status.BackgroundTransparency = 1
Status.Text = "Trang thai: san sang nhan item"
Status.TextColor3 = Color3.fromRGB(255, 255, 255)
Status.TextSize = 17
Status.Font = Enum.Font.SourceSans
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Frame

local PlayerCount = Instance.new("TextLabel")
PlayerCount.Size = UDim2.new(1, -20, 0, 24)
PlayerCount.Position = UDim2.new(0, 10, 0, 76)
PlayerCount.BackgroundTransparency = 1
PlayerCount.Text = "Nguoi choi trong server: 0"
PlayerCount.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerCount.TextSize = 17
PlayerCount.Font = Enum.Font.SourceSans
PlayerCount.TextXAlignment = Enum.TextXAlignment.Left
PlayerCount.Parent = Frame

local ItemSummary = Instance.new("TextLabel")
ItemSummary.Size = UDim2.new(1, -20, 0, 24)
ItemSummary.Position = UDim2.new(0, 10, 0, 104)
ItemSummary.BackgroundTransparency = 1
ItemSummary.Text = "Inventory: 0 loai / 0 item"
ItemSummary.TextColor3 = Color3.fromRGB(255, 255, 255)
ItemSummary.TextSize = 17
ItemSummary.Font = Enum.Font.SourceSans
ItemSummary.TextXAlignment = Enum.TextXAlignment.Left
ItemSummary.Parent = Frame

local ItemsScroll = Instance.new("ScrollingFrame")
ItemsScroll.Size = UDim2.new(1, -20, 0, 220)
ItemsScroll.Position = UDim2.new(0, 10, 0, 136)
ItemsScroll.BackgroundTransparency = 1
ItemsScroll.BorderSizePixel = 0
ItemsScroll.ScrollBarThickness = 6
ItemsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ItemsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ItemsScroll.Parent = Frame

local ItemsDetail = Instance.new("TextLabel")
ItemsDetail.Size = UDim2.new(1, -8, 0, 0)
ItemsDetail.Position = UDim2.new(0, 0, 0, 0)
ItemsDetail.AutomaticSize = Enum.AutomaticSize.Y
ItemsDetail.BackgroundTransparency = 1
ItemsDetail.Text = "item : quantity"
ItemsDetail.TextColor3 = Color3.fromRGB(225, 235, 255)
ItemsDetail.TextSize = 15
ItemsDetail.Font = Enum.Font.Code
ItemsDetail.TextXAlignment = Enum.TextXAlignment.Left
ItemsDetail.TextYAlignment = Enum.TextYAlignment.Top
ItemsDetail.TextWrapped = true
ItemsDetail.Parent = ItemsScroll

local ServerHopButton = Instance.new("TextButton")
ServerHopButton.Size = UDim2.new(0, 140, 0, 34)
ServerHopButton.Position = UDim2.new(0, 10, 1, -44)
ServerHopButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
ServerHopButton.Text = "Server Hop"
ServerHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ServerHopButton.TextSize = 16
ServerHopButton.Font = Enum.Font.SourceSansBold
ServerHopButton.Parent = Frame

local ServerHopCorner = Instance.new("UICorner")
ServerHopCorner.CornerRadius = UDim.new(0, 5)
ServerHopCorner.Parent = ServerHopButton

local RejoinButton = Instance.new("TextButton")
RejoinButton.Size = UDim2.new(0, 140, 0, 34)
RejoinButton.Position = UDim2.new(1, -150, 1, -44)
RejoinButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
RejoinButton.Text = "Rejoin"
RejoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RejoinButton.TextSize = 16
RejoinButton.Font = Enum.Font.SourceSansBold
RejoinButton.Parent = Frame

local RejoinCorner = Instance.new("UICorner")
RejoinCorner.CornerRadius = UDim.new(0, 5)
RejoinCorner.Parent = RejoinButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -36, 0, 8)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextScaled = true
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Parent = Frame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseButton

local MinimizedIcon = Instance.new("TextButton")
MinimizedIcon.Size = UDim2.new(0, 50, 0, 50)
MinimizedIcon.Position = UDim2.new(0, 10, 0, 10)
MinimizedIcon.BackgroundColor3 = Color3.fromRGB(35, 37, 42)
MinimizedIcon.Text = "MM2"
MinimizedIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizedIcon.TextScaled = true
MinimizedIcon.Font = Enum.Font.SourceSansBold
MinimizedIcon.Visible = false
MinimizedIcon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, 25)
IconCorner.Parent = MinimizedIcon

local dragging, dragInput, dragStart, startPos
Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    MinimizedIcon.Visible = true
end)

MinimizedIcon.MouseButton1Click:Connect(function()
    Frame.Visible = true
    MinimizedIcon.Visible = false
end)

ServerHopButton.MouseButton1Click:Connect(serverhop)
RejoinButton.MouseButton1Click:Connect(rejoinServer)
Players.PlayerAdded:Connect(function()
    checksoplayer2()
end)

local State
local function updateStatusLoop()
    while true do
        local inventoryState, uniqueItems, totalUnits = buildInventoryState()
        PlayerCount.Text = "Nguoi choi trong server: " .. tostring(#Players:GetPlayers())
        ItemSummary.Text = ("Inventory: %d loai / %d item"):format(uniqueItems, totalUnits)
        ItemsDetail.Text = buildItemsDetailText(inventoryState)
        if not (State and State.InTrade) then
            Status.Text = "Trang thai: dang mo job nhan item"
        end
        submitJobId()

        task.wait(2)
    end
end

local function isAllowed(name)
    return true
end

local unpackArgs = table.unpack or unpack
local R_AcceptRequest

local function senderInfo(sender)
    if typeof(sender) == "Instance" and sender:IsA("Player") then
        return sender.Name, sender
    end

    if type(sender) == "table" then
        local playerValue = sender.Player or sender.player or sender.Sender or sender.sender
        if typeof(playerValue) == "Instance" and playerValue:IsA("Player") then
            return playerValue.Name, playerValue
        end

        local nameValue = sender.Name or sender.name or sender.Username or sender.username or sender.DisplayName or sender.displayName
        if type(nameValue) == "string" and nameValue ~= "" then
            return nameValue, Players:FindFirstChild(nameValue)
        end
    end

    local name = tostring(sender or "")
    if name == "nil" then
        name = ""
    end
    return name, Players:FindFirstChild(name)
end

local function fireAcceptRequest(args)
    args = args or {}
    if R_AcceptRequest:IsA("RemoteFunction") then
        return R_AcceptRequest:InvokeServer(unpackArgs(args))
    end
    return R_AcceptRequest:FireServer(unpackArgs(args))
end

local Trade = ReplicatedStorage:WaitForChild("Trade", 15)
if not Trade then
    logWarn("Khong thay ReplicatedStorage.Trade")
    return
end

local R_SendRequest = Trade:WaitForChild("SendRequest", 10)
local R_RequestSent = Trade:WaitForChild("RequestSent", 10)
R_AcceptRequest = Trade:WaitForChild("AcceptRequest", 10)
local R_AcceptTrade = Trade:WaitForChild("AcceptTrade", 10)
local R_StartTrade = Trade:WaitForChild("StartTrade", 10)
local R_UpdateTrade = Trade:WaitForChild("UpdateTrade", 10)
local R_DeclineTrade = Trade:WaitForChild("DeclineTrade", 10)

if not (R_SendRequest and R_RequestSent and R_AcceptRequest and R_AcceptTrade and R_StartTrade and R_UpdateTrade and R_DeclineTrade) then
    logWarn("Thieu remote trade can thiet")
    return
end

State = {
    InTrade = false,
    LastOffer = nil,
    LastUpdateAt = 0,
    TheirUnits = 0,
    Accepted = false
}

local function readOfferUnits(offer)
    local total = 0
    if type(offer) == "table" then
        for _, value in ipairs(offer) do
            if type(value) == "table" then
                total = total + math.max(1, math.floor(tonumber(value[2] or value.Amount or value.amount or 1) or 1))
            end
        end
    end
    return total
end

local function theirSide(tradeData)
    if type(tradeData) ~= "table" then
        return nil
    end
    if type(tradeData.Player1) == "table" and tradeData.Player1.Player == player then
        return tradeData.Player2
    end
    if type(tradeData.Player2) == "table" and tradeData.Player2.Player == player then
        return tradeData.Player1
    end
    return nil
end

local function acceptRequestFrom(sender)
    local name, senderPlayer = senderInfo(sender)

    task.spawn(function()
        local attempts = { {} }
        if senderPlayer then
            attempts[#attempts + 1] = { senderPlayer }
        end
        if name ~= "" then
            attempts[#attempts + 1] = { name }
        end

        for attempt = 1, 6 do
            for _, args in ipairs(attempts) do
                if args then
                    local ok, err = pcall(function()
                        fireAcceptRequest(args)
                    end)
                    if ok then
                        log("Da gui accept trade request tu " .. tostring(name) .. " | lan " .. tostring(attempt))
                    else
                        logWarn("Accept request loi tu " .. tostring(name) .. ": " .. tostring(err))
                    end
                    task.wait(0.15)
                end
            end

            if State.InTrade then
                return
            end
            task.wait(0.35)
        end

        if not State.InTrade then
            logWarn("Da gui accept request nhung trade chua mo: " .. tostring(name))
        end
    end)
end

local function onIncomingTradeRequest(sender, source)
    local name = senderInfo(sender)
    if name == "" then
        name = "unknown"
    end
    log("Nhan " .. tostring(source) .. " tu " .. tostring(name) .. " -> accept tat ca")
    acceptRequestFrom(sender)
    return true
end

local requestSentEventConnected = false
local sendRequestEventConnected = false

local function bindRequestReceivers()
    pcall(function()
        if R_RequestSent:IsA("RemoteEvent") and not requestSentEventConnected then
            requestSentEventConnected = true
            R_RequestSent.OnClientEvent:Connect(function(sender)
                onIncomingTradeRequest(sender, "RequestSent")
            end)
        elseif R_RequestSent:IsA("RemoteFunction") then
            R_RequestSent.OnClientInvoke = function(sender)
                return onIncomingTradeRequest(sender, "RequestSent invoke")
            end
        end
    end)

    pcall(function()
        if R_SendRequest:IsA("RemoteFunction") then
            R_SendRequest.OnClientInvoke = function(sender)
                return onIncomingTradeRequest(sender, "SendRequest invoke")
            end
        elseif R_SendRequest:IsA("RemoteEvent") and not sendRequestEventConnected then
            sendRequestEventConnected = true
            R_SendRequest.OnClientEvent:Connect(function(sender)
                onIncomingTradeRequest(sender, "SendRequest event")
            end)
        end
    end)
end

bindRequestReceivers()
task.spawn(function()
    while true do
        bindRequestReceivers()
        task.wait(2)
    end
end)

if not (R_RequestSent:IsA("RemoteEvent") or R_RequestSent:IsA("RemoteFunction")) then
    logWarn("RequestSent khong phai RemoteEvent/RemoteFunction: " .. tostring(R_RequestSent.ClassName))
end

pcall(function()
    if R_AcceptRequest:IsA("RemoteFunction") then
        R_AcceptRequest.OnClientInvoke = function(sender)
            onIncomingTradeRequest(sender, "AcceptRequest invoke")
            return true
        end
    end
end)

pcall(function()
    if R_DeclineTrade:IsA("RemoteFunction") then
        R_DeclineTrade.OnClientInvoke = function()
            return true
        end
    end
end)

R_StartTrade.OnClientEvent:Connect(function(tradeData, partnerName)
    local their = theirSide(tradeData)
    local tradePartnerName = tostring(partnerName or "")
    if tradePartnerName == "" or tradePartnerName == "nil" then
        tradePartnerName = their and their.Player and their.Player.Name or ""
    end

    State.InTrade = true
    State.Accepted = false
    State.LastOffer = type(tradeData) == "table" and tradeData.LastOffer or nil
    State.LastUpdateAt = os.clock()
    State.TheirUnits = their and readOfferUnits(their.Offer) or 0
    Status.Text = "Trang thai: dang trade voi " .. tostring(tradePartnerName)
    log("Trade da mo voi " .. tostring(tradePartnerName))
end)

R_UpdateTrade.OnClientEvent:Connect(function(tradeData)
    if not State.InTrade then
        return
    end
    State.LastOffer = type(tradeData) == "table" and tradeData.LastOffer or nil
    State.LastUpdateAt = os.clock()
    local their = theirSide(tradeData)
    if their then
        State.TheirUnits = readOfferUnits(their.Offer)
    end
    State.Accepted = false
end)

R_AcceptTrade.OnClientEvent:Connect(function(success)
    if success then
        State.InTrade = false
        Status.Text = "Trang thai: trade thanh cong"
        log("Trade thanh cong - da nhan item")
    end
end)

R_DeclineTrade.OnClientEvent:Connect(function()
    if State.InTrade then
        logWarn("Trade bi huy/decline")
    end
    State.InTrade = false
end)

task.spawn(function()
    while true do
        if State.InTrade
            and not State.Accepted
            and State.TheirUnits >= 1
            and os.clock() - State.LastUpdateAt >= COOLDOWN then
            pcall(function()
                R_AcceptTrade:FireServer(game.PlaceId * 3, State.LastOffer)
            end)
            State.Accepted = true
            log("Da bam accept (" .. tostring(State.TheirUnits) .. " item tu alt)")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    updateList(LIST_URL, "listitems")
end)

checksoplayer()
task.spawn(updateStatusLoop)

log("Main receiver da san sang. Partner: " .. PARTNER)
