-- Reinstall FatherV6 Platinum
for _, v in pairs(game.CoreGui:GetChildren()) do
    if v.Name:find("FatherV6") then
        v:Destroy()
    end
end
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/FatherV6/main/games/Bedfight.lua"))()

