-- Murderers vs Sheriffs 2 (Duels) - 2025年動作確認済みスクリプト集
-- 上から順番に試してください

-- ========================================
-- スクリプト1: TbaoHub (推奨) - Hitbox + ESP
-- ========================================
-- シンプルで動作が安定しています
loadstring(game:HttpGet("https://raw.githubusercontent.com/tbao143/thaibao/main/TbaoHubMurdervssheriff"))()

-- ========================================
-- スクリプト2: 最新版Hitbox (2025年11月更新)
-- ========================================
-- 最近更新されたヒットボックススクリプト
loadstring(game:HttpGet("https://pastebin.com/raw/XgztNC7z", true))()

-- ========================================
-- スクリプト3: ImpHub - 多機能版
-- ========================================
-- Aimbot、ESP、その他の機能を含む
loadstring(game:HttpGet("https://raw.githubusercontent.com/alan11ago/Hub/refs/heads/main/ImpHub.lua"))()

-- ========================================
-- スクリプト4: FreakBob Hub
-- ========================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/BeanBotWare/FreakBob/refs/heads/main/FreakBob"))()

-- ========================================
-- スクリプト5: Shax Hub - Hitbox特化
-- ========================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/shaxypop788/shax-hub/main/hitbox"))()

-- ========================================
-- スクリプト6: Vinh Dev - Aimbot + ESP + NoClip
-- ========================================
loadstring(game:HttpGet("https://gist.githubusercontent.com/vinhxdev/e92f38aeb4ac30416a00042008f11e52/raw/f30db37119ab0888d1738ac02012f92dc4876f25/main.lua"))()

-- ========================================
-- スクリプト7: カスタムHitbox（軽量版）
-- ========================================
-- もし上記が全て動作しない場合、この基本的なヒットボックスを試してください
_G.HeadSize = 20  -- ヒットボックスのサイズ（大きいほど当たりやすい）
_G.Disabled = true

game:GetService('RunService').RenderStepped:connect(function()
    if _G.Disabled then
        for i,v in pairs(game:GetService('Players'):GetPlayers()) do
            if v.Name ~= game:GetService('Players').LocalPlayer.Name then
                pcall(function()
                    v.Character.HumanoidRootPart.Size = Vector3.new(_G.HeadSize, _G.HeadSize, _G.HeadSize)
                    v.Character.HumanoidRootPart.Transparency = 0.7
                    v.Character.HumanoidRootPart.BrickColor = BrickColor.new("Really red")
                    v.Character.HumanoidRootPart.Material = "Neon"
                    v.Character.HumanoidRootPart.CanCollide = false
                end)
            end
        end
    end
end)

-- ========================================
-- 重要な注意事項
-- ========================================
-- 1. スクリプトは必ずゲーム参加「後」に実行してください
-- 2. F9キーでコンソールを開き、エラーを確認してください
-- 3. 複数のスクリプトを同時に実行しないでください
-- 4. ゲームが更新された場合、スクリプトが動作しなくなる可能性があります
