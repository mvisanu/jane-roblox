local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))

local oldRemotes = ReplicatedStorage:FindFirstChild(RemoteNames.Folder)
if oldRemotes then
	oldRemotes:Destroy()
end

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = RemoteNames.Folder
remoteFolder.Parent = ReplicatedStorage

local request = Instance.new("RemoteFunction")
request.Name = RemoteNames.Request
request.Parent = remoteFolder

local stateChanged = Instance.new("RemoteEvent")
stateChanged.Name = RemoteNames.StateChanged
stateChanged.Parent = remoteFolder

local toast = Instance.new("RemoteEvent")
toast.Name = RemoteNames.Toast
toast.Parent = remoteFolder

local guildAction = Instance.new("RemoteEvent")
guildAction.Name = RemoteNames.GuildAction
guildAction.Parent = remoteFolder

local remotes = {
	Request = request,
	StateChanged = stateChanged,
	Toast = toast,
	GuildAction = guildAction,
}

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local GameService = require(Services:WaitForChild("GameService"))
local ShopService = require(Services:WaitForChild("ShopService"))

local dataService = DataService.new()
local worldService = WorldService.new(remotes)
local gameService = GameService.new(dataService, worldService, remotes)
-- Takes Robux in: coin packs and the cosmetic supporter pass. Stays dormant
-- until the product ids are filled in in Config.Monetization.
local shopService = ShopService.new(dataService, remotes)

worldService:SetActionHandler(function(player, action, payload)
	return gameService:Handle(player, action, payload)
end)

local function refreshCharacter(player)
	local data = dataService:Get(player)
	if not data then
		return
	end
	task.wait(0.5)
	worldService:ApplyOutfit(player, data)
	worldService:RefreshPet(player, data)
	-- The badge lives on the character's head, so it has to be rebuilt every
	-- time they respawn, not just when they first join.
	worldService:RefreshLevelBadge(player, data)
end

local function preparePlayer(player)
	if not dataService:Load(player) or not player.Parent then
		return
	end
	shopService:RefreshSupporter(player)
	worldService:AssignHome(player)
	gameService:OnPlayerReady(player)

	player.CharacterAdded:Connect(function()
		refreshCharacter(player)
	end)
	if player.Character then
		task.spawn(refreshCharacter, player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(preparePlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	dataService:Unload(player)
	gameService:ForgetPlayer(player)
	worldService:ReleaseHome(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(preparePlayer, player)
end

dataService:StartAutosave(Players)

game:BindToClose(function()
	dataService:Shutdown(Players)
end)
