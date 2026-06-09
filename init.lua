-- FatherV6 Platinum Loader
local scriptUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/FatherV6/main/games/Bedfight.lua"
local success, result = pcall(function()
    return game:HttpGet(scriptUrl)
end)
if success then
    loadstring(result)()
else
    warn("Failed to load FatherV6: " .. tostring(result))
end

