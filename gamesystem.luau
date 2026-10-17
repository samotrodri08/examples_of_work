-- Discord Username: l4sanhas
-- Roblox Username: samotrodri08

-- This system is an example of rounds system that gets the last players standing. Can be used for eliminations games for example
-- For a round to proceed on a player must lose. If none of the players lose one of the players will be selected randomlly to lose and get off the game (round). 

type game_module = {
	current_map : Folder,
	active_maps : {Folder},
	players_in_game : {Player},
	map_vote : {[Folder]: {Player}},
	round_duration : number,
	map_vote_duration : number,
	intermission : number,
	required_players : number,
	game_state : string,
	vote_map_1_part : Part,
	vote_map_2_part : Part
}

local module : game_module = {}

-- Services

local Players = game:GetService("Players")

--

module.intermission = 5
module.round_duration = 5
module.map_vote_duration = 3
module.required_players = 1 -- One for the system to be tested solo

module.players_in_game = {} -- The table where players that are in the game will be stored
module.map_vote = {}
local connections : {RBXScriptConnection} = {}

module.active_maps = {workspace:WaitForChild("Green Map"), workspace:WaitForChild("Yellow Map")} -- The possible maps that can show up in the games

local map_votefolder : Folder = workspace:WaitForChild("Map Vote")
module.vote_map_1_part = map_votefolder:WaitForChild("Vote Map 1")
module.vote_map_2_part = map_votefolder:WaitForChild("Vote Map 2")

-- The proximities that will be used for map vote
local prox1 : ProximityPrompt = module.vote_map_1_part:WaitForChild("ProximityPrompt") prox1.Enabled = false
local prox2 : ProximityPrompt = module.vote_map_2_part:WaitForChild("ProximityPrompt") prox2.Enabled = false

module.current_map = nil

module.game_state = "Intermission"

function DoIntermission()
	-- The intermission is made with a loop and a task.wait() according to the module.intermission value
	for t = module.intermission, 1, -1 do
		task.wait(1)
	end
end

function PrepareMapVote()
	if module.active_maps and #module.active_maps > 0 then
		-- Considering that there's at least one map and there's two parts to vote. So two maps must be selected for the map vote
		-- The available_maps is a cloned table for the module.active_maps don't be changed in the progress
		
		local available_maps = table.clone(module.active_maps)
		
		local function SelectRandomMap()
			if available_maps and #available_maps then
				-- To get a random map we get a random number from the first index to the last index of the available_maps table
				local random_i = math.random(1, #available_maps)
				if available_maps[random_i] then
					local chosen_map = available_maps[random_i]
					table.remove(available_maps, random_i)
					-- Once the map is chosen, the map gets removed from the table. This makes in unselectable for next SelectRandomMap()
					return chosen_map
				end
			end

			End()
		end
		
		local map1 = SelectRandomMap()
		local map2 = SelectRandomMap()
		
		if map1 and map2 then
			
			-- map_vote is going to be used to register the votes of the players, inserting the player's instance in the map's respective table
			module.map_vote[map1] = {}
			module.map_vote[map2] = {}
			
			if prox1 and prox2 then
				
				-- Enabling the Proximities to register votes
				prox1.Enabled = true
				prox2.Enabled = true
				
				local function UpdateVotesIndicators()
					if prox1 and prox2 and map1 and map2 then
						-- The votes are shown in the proximity prompt and are always updated when there's an action (vote)
						prox1.ObjectText = `{map1.Name} - {module.map_vote[map1] and #module.map_vote[map1]} Votes`
						prox2.ObjectText = `{map2.Name} - {module.map_vote[map2] and #module.map_vote[map2]} Votes`
					end
				end
				
				local function GetPlayerVote(player : Player)
					for map, players_who_voted in pairs(module.map_vote) do
						if map and players_who_voted then
							-- Going through the map_vote table to check where's the last player's vote
							-- If there's no vote it will return nil
							if table.find(players_who_voted, player) then
								return map
							end
						end
					end
				end
				
				local function RemovePlayerVote(player : Player)
					if player then
						local player_vote = GetPlayerVote(player)
						if player_vote then
							table.remove(module.map_vote[player_vote], table.find(module.map_vote[player_vote], player))
						end
						-- If GetPlayerVote() returns nil, then no action needed
					end
				end
				
				local function RegisterVote(player : Player, map : Folder)
					if player and map and module.game_state == "Map Vote" then
						-- Always making sure we remove the vote before adding one
						RemovePlayerVote(player)
						if module.map_vote[map] then
							table.insert(module.map_vote[map], player)
							-- The player is placed into the table corresponding to the map 
						end
					end
					UpdateVotesIndicators()
				end
				
				
				-- The connections are inserted into the connections table so that they can be disconnected later
				table.insert(connections, prox1.Triggered:Connect(function(player)
					RegisterVote(player, map1)
				end))
				
				table.insert(connections, prox2.Triggered:Connect(function(player)
					RegisterVote(player, map2)
				end))
				
				UpdateVotesIndicators()
				
				return
			end	
		end
	end
	
	End()
end

function DoMapVote()
	-- Set the game state to Map Vote, as this is the only time when players can vote
	-- And applying a for loop to wait for the duration of the map_vote_duration value
	module.game_state = "Map Vote"
	for t = module.map_vote_duration, 1, -1 do
		task.wait(1)
	end
	
	prox1.Enabled = false
	prox2.Enabled = false
end

function DoGame()
	local function HasPlayersToStart()
		-- Knowing if there's enough players to start the game
		return #Players:GetPlayers() >= module.required_players
	end
	
	-- To obtain the map with the most votes, we first iterate through the `map_vote` table and determine which one has the highest number of votes
	-- If there is a tie for the highest number of votes, we randomly select one from among those tied
	
	local most_voted_map : Folder, higher_votes = nil, 0
	local draw_votes
	
	for map, players_who_voted in pairs(module.map_vote) do
		if map and players_who_voted then
			if #players_who_voted > higher_votes then
				higher_votes = #players_who_voted
				most_voted_map = map
			elseif #players_who_voted == higher_votes then
				draw_votes = #players_who_voted
			end
		end
	end
	
	if higher_votes == draw_votes then
		-- We have 2 or more maps that were a draw
		local draw_maps = {}
		for map, players_who_voted in pairs(module.map_vote) do
			if map and players_who_voted then
				if #players_who_voted == draw_votes then
					table.insert(draw_maps, map)
				end
			end
		end
		
		local randomi = math.random(1, #draw_maps)
		most_voted_map = draw_maps[randomi]
	end
	
	if most_voted_map then
		module.current_map = most_voted_map
	end
	
	-- In this case the maps are already on the workspace, so no loading system needed (or clone it to workspace)
	
	repeat
		task.wait(1)
	until HasPlayersToStart()
	
	task.wait(3) -- a small delay
	
	module.players_in_game = Players:GetPlayers()
	
	if module.game_state == "Map Vote" then
		
		-- It is important to check whether there are still players after the transition period, as some may have left
		
		repeat
			task.wait()
		until HasPlayersToStart()
		
		module.game_state = "Running Game"
		
		if module.current_map then
			
			-- For the game, all players are teleported onto the map in a completely random fashion, provided they remain within the map boundaries
			-- Connections are used to register / update the losts or lefts of the players. These connections remove the player from the players_in_game table
			
			local function TeleportPlayer(player : Player)
				local baseplate_of_map = module.current_map:FindFirstChildWhichIsA("BasePart")
				if baseplate_of_map then
					if player.Character and player.Character:WaitForChild("HumanoidRootPart") then
						local CF, Size = baseplate_of_map.CFrame, baseplate_of_map.Size
						-- After getting the CFrame and Size of the baseplate, the player is teleported to a random position in the baseplate
						-- The orientation of the player is also random
						-- To make this I use pivot and create a hole new CFrame assigned with a random position relative to the baseplate and keeping the Y always the same value
						player.Character:PivotTo(CFrame.new(Vector3.new(CF.Position.X + math.random(-Size.X / 2, Size.X / 2), CF.Position.Y + 7, CF.Position.Z + math.random(-Size.Z / 2, Size.Z / 2)))
							*CFrame.Angles(0, math.rad(math.random(0, 360)), 0))
					end
				end
			end
			
			local function ConnectPlayerLost(player : Player)
				if player then
					local Humanoid : Humanoid = player.Character and player.Character:WaitForChild("Humanoid")
					if Humanoid then
						table.insert(connections, Humanoid.Died:Connect(function()
							if player and module.players_in_game and table.find(module.players_in_game, player) then
								-- If the Player died while game in progress, it gets removed from the players_in_game table
								table.remove(module.players_in_game, table.find(module.players_in_game, player))
							end
						end))
					end
				end
			end
			
			for _, player in pairs(module.players_in_game) do
				-- Teleporting selected players to the map and connection the lost function for each player
				if player then
					task.spawn(function()
						TeleportPlayer(player)
					end)
					ConnectPlayerLost(player)
				end
			end
			
			table.insert(connections, game.Players.PlayerRemoving:Connect(function(player : Player)
				if player and module.players_in_game and table.find(module.players_in_game, player) then
					-- If the Player left the game while game in progress, it gets removed from the players_in_game table
					table.remove(module.players_in_game, table.find(module.players_in_game, player))
				end
			end))
			
			local function DoRound()
				-- The DoRound starts a new round, it stores how the players_in_game was at the start of the round
				-- If changes occured then a player lost or left the game. The round stops and proceed to another round
				-- DoRound will always call itself to make another round untill there's no players or there's only one left
				
				local players_in_round = table.clone(module.players_in_game)
				
				-- Using >= 1 to be able to be tested while single player
				if players_in_round and #players_in_round >= 1 then
					
					local function CheckIfPlayerLost()
						return #players_in_round ~= #module.players_in_game
					end
					
					for t = module.round_duration, 1, -1 do
						-- Doing Round
						-- If there were changes then the round stops and starts another one if there's players left
						if CheckIfPlayerLost() then
							break
						end
						task.wait(1)
					end

					if #players_in_round == #module.players_in_game and #players_in_round >= 2 then
						-- Removing one randomlly in case nobody lost
						local randomi = math.random(1, #module.players_in_game)
						if module.players_in_game[randomi] then
							-- Making Player's character return to spawn
							module.players_in_game[randomi]:LoadCharacterAsync()
							table.remove(module.players_in_game, randomi)
						end
					elseif #players_in_round == #module.players_in_game then
						-- if the game started with 1 player
						return false
					end
					
					DoRound()
				end
				
				return false
			end
			
			if not DoRound() then
				-- Game Ended because the function returned false
				module.game_state = "Ending"
				
				task.wait(3)
				
				return true
			end
		end
	end
	
	End()
end

function Start()
	if module.game_state == "Intermission" then
		DoIntermission()
		PrepareMapVote()
		DoMapVote()
		DoGame()
		End()
	end
end

local function GiveRewards(player : Player)
	if player then
		-- No rewards for now
	end
end

function End()
	-- Making sure no player stands on the game map
	module.game_state = "Ending"
	
	if #module.players_in_game > 0 then
		for _, player : Player in pairs(module.players_in_game) do
			-- loop to teleport all players in game
			if player then
				player:LoadCharacterAsync()
				GiveRewards(player)
			end
		end	
	else
		-- Nobody won the game (possbile when playing solo)
	end

	if connections then
		for _, connection in pairs(connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end

	connections = {}
	module.map_vote = {}
	module.players_in_game = {}
	module.current_map = nil
	module.game_state = "Intermission"

	task.defer(Start)
end

-- For the game to start the module just needs to be required
Start()
return module
