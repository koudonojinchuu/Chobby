-- Zero-K Server protocol implementation
-- https://github.com/ZeroK-RTS/Zero-K-Infrastructure/blob/master/Shared/LobbyClient/Protocol/Messages.cs

VFS.Include(LIB_LOBBY_DIRNAME .. "json.lua")
VFS.Include(LIB_LOBBY_DIRNAME .. "interface_shared.lua")

-- map lobby commands by name
Interface.commands = {}
-- map json lobby commands by name
Interface.jsonCommands = {}
-- define command format with pattern (regex)
Interface.commandPattern = {}

-------------------------------------------------
-- Initialization
-------------------------------------------------

function Interface:InheritanceIsBrokenWorkaroundInit()
	self.duplicateMessageTimes = {}
	self.commonChannels = {"zk"}
end

-------------------------------------------------
-- BEGIN Client commands
-------------------------------------------------

------------------------
-- Connectivity commands
------------------------

function Interface:Register(userName, password, email)
	self:super("Register", userName, password, email)
	-- FIXME: email argument is currently not sent to the server
	password = VFS.CalculateHash(password, 0)
	local sendData = {
		Name = userName,
		PasswordHash = password,
	}
	self:_SendCommand("Register " .. json.encode(sendData))
	return self
end

function Interface:Login(user, password, cpu, localIP, lobbyVersion)
	self:super("Login", user, password, cpu, localIP)
	if localIP == nil then
		localIP = "*"
	end
	password = VFS.CalculateHash(password, 0)
	
	local sendData = {
		Name = user,
		PasswordHash = password,
		UserID = 0,
		ClientType = 1,
		LobbyVersion = lobbyVersion,
	}
	
	self:_SendCommand("Login " .. json.encode(sendData))
end

function Interface:Ping()
	if self.REVERSE_COMPAT then
		self:super("Ping")
		self:_SendCommand("Ping {}")
	end
	return self
end

------------------------
-- Status commands
------------------------

function Interface:SetIngameStatus(isInGame)
	local sendData = {
		IsInGame = isInGame,
	}

	self:_SendCommand("ChangeUserStatus " .. json.encode(sendData))
	return self
end

function Interface:SetAwayStatus(isAway)
	local sendData = {
		IsAfk = isAway,
	}

	self:_SendCommand("ChangeUserStatus " .. json.encode(sendData))
	return self
end

------------------------
-- User commands
------------------------

function Interface:FriendRequest(userName)
	self:super("FriendRequest", userName)
	local sendData = {
		TargetName = userName,
		Relation = 1, -- Friend
	}
	
	self:_SendCommand("SetAccountRelation " .. json.encode(sendData))
	return self
end

function Interface:AcceptFriendRequest(userName)
	self:super("AcceptFriendRequest", userName)
	Spring.Echo("TODO: Implement AcceptFriendRequest")
	return self
end

function Interface:DeclineFriendRequest(userName)
	self:super("DeclineFriendRequest", userName)
	Spring.Echo("TODO: Implement DeclineFriendRequest")
	return self
end

function Interface:Unfriend(userName)
	self:super("Unfriend", userName)
	local sendData = {
		TargetName = userName,
		Relation = 0, -- None
	}
	
	self:_SendCommand("SetAccountRelation " .. json.encode(sendData))
	return self
end

function Interface:Ignore(userName)
	self:super("Ignore", userName)
	local sendData = {
		TargetName = userName,
		Relation = 2, -- Ignore
	}
	
	self:_SendCommand("SetAccountRelation " .. json.encode(sendData))
	return self
end

function Interface:Unignore(userName)
	self:super("Unignore", userName)
	local sendData = {
		TargetName = userName,
		Relation = 0, -- None
	}
	
	self:_SendCommand("SetAccountRelation " .. json.encode(sendData))
	return self
end

------------------------
-- Battle commands
------------------------

local modeToName = {
	[5] = "Cooperative",
	[6] = "Team",
	[3] = "1v1",
	[4] = "FFA",
	[0] = "Custom",
}

local nameToMode = {}
for i, v in pairs(modeToName) do
	nameToMode[v] = i
end

function Interface:HostBattle(battleTitle, password, modeName)
	--OpenBattle {"Header":{"Mode":6,"Password":"bla","Title":"GoogleFrog's Teams"}}
	-- Mode:
	-- 5 = Cooperative
	-- 6 = Teams
	-- 3 = 1v1
	-- 4 = FFA
	-- 0 = Custom
	local engineName
	if tonumber(Game.version) then
		engineName = Game.version .. ".0"
	else
		engineName = string.gsub(Game.version, " develop", "")
	end
	
	local sendData = {
		Header = {
			Title = battleTitle,
			Mode = (modeName and nameToMode[modeName]) or 0,
			Password = password,
			Engine = engineName
		}
	}
	
	self:_SendCommand("OpenBattle " .. json.encode(sendData))
end

function Interface:RejoinBattle(battleID)
	local sendData = {
		BattleID = battleID,
	}
	self:_SendCommand("RequestConnectSpring " .. json.encode(sendData))
	return self
end

function Interface:JoinBattle(battleID, password, scriptPassword)
	local sendData = {
		BattleID = battleID,
		Password = password,
		scriptPassword = scriptPassword
	}
	self:_SendCommand("JoinBattle " .. json.encode(sendData))
	return self
end

function Interface:LeaveBattle()
	local myBattleID = self:GetMyBattleID()
	if not myBattleID then
		Spring.Echo("LeaveBattle sent while not in battle")
		return
	end
	local sendData = {
		BattleID = myBattleID,
	}
	self:_SendCommand("LeaveBattle " .. json.encode(sendData))
	return self
end

function Interface:SetBattleStatus(status)
	local sendData = {
		Name        = self:GetMyUserName(),
		IsSpectator = status.isSpectator,
		AllyNumber  = status.allyNumber,
		TeamNumber  = status.teamNumber,
		Sync        = status.sync,
	}

	self:_SendCommand("UpdateUserBattleStatus " .. json.encode(sendData))
	return self
end

function Interface:AddAi(aiName, aiLib, allyNumber)
	local sendData = {
		Name         = aiName,
		AiLib        = aiLib,
		AllyNumber   = allyNumber,
		Owner        = self:GetMyUserName(),
	}
	self:_SendCommand("UpdateBotStatus " .. json.encode(sendData))
	return self
end

function Interface:RemoveAi(aiName)
	local sendData = {
		Name        = aiName,
	}
	self:_SendCommand("RemoveBot " .. json.encode(sendData))
	return self
end

function Interface:KickUser(userName)
	if not userName then
		return
	end
	local sendData = {
		Place = 1, -- Battle?
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = "!kick " .. userName,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SayBattle(message)
	local sendData = {
		Place = 1, -- Battle?
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SayBattleEx(message)
	local sendData = {
		Place = 1, -- Battle?
		User = self:GetMyUserName(),
		IsEmote = true,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:VoteYes()
	local sendData = {
		Place = 1, -- Battle?
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = "!y",
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:VoteNo()
	local sendData = {
		Place = 1, -- Battle?
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = "!n",
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SetModOptions(data)
	for _,_ in pairs(data) do
		local sendData = {
			Options = data,
		}
		
		self:_SendCommand("SetModOptions " .. json.encode(sendData))
		return self
	end
	
	-- Don't send anything, server thinks it means reset to default
	--self:_SendCommand("SetModOptions {\"Options\":{}}")
end

------------------------
-- Channel & private chat commands
------------------------

function Interface:Join(chanName, key)
	if not self:GetInChannel(chanName) then
		local sendData = {
			ChannelName = chanName
		}
		self:_SendCommand("JoinChannel " .. json.encode(sendData))
	end
	return self
end

function Interface:Leave(chanName)
	local sendData = {
		ChannelName = chanName
	}
	self:_SendCommand("LeaveChannel " .. json.encode(sendData))
	return self
end

function Interface:Say(chanName, message)
	-- Say {"Place":0,"Target":"zk","User":"GoogleFrog","IsEmote":false,"Text":"bla","Ring":false,"Time":"2016-06-25T07:17:20.7548313Z"
	local sendData = {
		Place = 0, -- Does 0 mean say to a channel???
		Target = chanName,
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SayEx(chanName, message)
	-- Say {"Place":0,"Target":"zk","User":"GoogleFrog","IsEmote":false,"Text":"bla","Ring":false,"Time":"2016-06-25T07:17:20.7548313Z"
	local sendData = {
		Place = 0, -- Does 0 mean say to a channel???
		Target = chanName,
		User = self:GetMyUserName(),
		IsEmote = true,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SayPrivate(userName, message)
	-- Say {"Place":0,"Target":"zk","User":"GoogleFrog","IsEmote":false,"Text":"bla","Ring":false,"Time":"2016-06-25T07:17:20.7548313Z"
	local sendData = {
		Place = 2, -- Does 2 mean say to a player???
		Target = userName,
		User = self:GetMyUserName(),
		IsEmote = false,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

function Interface:SayPrivateEx(userName, message)
	-- Say {"Place":0,"Target":"zk","User":"GoogleFrog","IsEmote":false,"Text":"bla","Ring":false,"Time":"2016-06-25T07:17:20.7548313Z"
	local sendData = {
		Place = 2, -- Does 2 mean say to a player???
		Target = userName,
		User = self:GetMyUserName(),
		IsEmote = true,
		Text = message,
		Ring = false,
		--Time = "2016-06-25T07:17:20.7548313Z",
	}
	self:_SendCommand("Say " .. json.encode(sendData))
	return self
end

------------------------
-- MatchMaking commands
------------------------

function Interface:JoinMatchMaking(queueNamePossiblyList)
	self.joinedQueues = self.joinedQueues or {}
	self.joinedQueueList = self.joinedQueueList or {}
	
	self.pendingQueueRequests = self.pendingQueueRequests + 1
	
	if type(queueNamePossiblyList) == "table" then
		for i = 1, #queueNamePossiblyList do
			local queueName = queueNamePossiblyList[i]
			if not self.joinedQueues[queueName] then
				self.joinedQueues[queueName] = true
				self.joinedQueueList[#self.joinedQueueList + 1] =  queueName
			end
		end
	else
		local queueName = queueNamePossiblyList
		if not self.joinedQueues[queueName] then
			self.joinedQueues[#self.joinedQueues + 1] = queueName
			self.joinedQueueList[#self.joinedQueueList + 1] =  queueName
		end
	end
	
	local sendData = {
		Queues = self.joinedQueueList
	}
	self:_SendCommand("MatchMakerQueueRequest " .. json.encode(sendData))
	return self
end

function Interface:LeaveMatchMaking(queueNamePossiblyList)
	self.pendingQueueRequests = self.pendingQueueRequests + 1
	
	if self.joinedQueues and self.joinedQueueList then
		if type(queueNamePossiblyList) == "table" then
			for i = 1, #queueNamePossiblyList do
				local queueName = queueNamePossiblyList[i]
				if self.joinedQueues[queueName] then
					for i, v in pairs(self.joinedQueueList) do
						if v == queueName then
							table.remove(self.joinedQueueList, i)
							break
						end
					end
					self.joinedQueues[queueName] = nil
				end
			end
		else
			local queueName = queueNamePossiblyList
			if self.joinedQueues[queueName] then
				for i, v in pairs(self.joinedQueueList) do
					if v == queueName then
						table.remove(self.joinedQueueList, i)
						break
					end
				end
				self.joinedQueues[queueName] = nil
			end
		end
	end
	
	local sendData = {
		Queues = self.joinedQueueList or {}
	}
	self:_SendCommand("MatchMakerQueueRequest " .. json.encode(sendData))
	return self
end

function Interface:LeaveMatchMakingAll()
	local sendData = {
		Queues = {}
	}
	self:_SendCommand("MatchMakerQueueRequest " .. json.encode(sendData))
	
	return self
end

function Interface:AcceptMatchMakingMatch()
	local sendData = {
		Ready = true
	}
	self:_SendCommand("AreYouReadyResponse " .. json.encode(sendData))
	return self
end

function Interface:RejectMatchMakingMatch()
	local sendData = {
		Ready = false
	}
	self:_SendCommand("AreYouReadyResponse " .. json.encode(sendData))
	return self
end

------------------------
-- Party commands
------------------------

function Interface:InviteToParty(userName)
	self:_OnPartyInviteSent(userName) -- Notify widgets that lobby sent an invitation.
	
	local function InviteRejectCheck()
		local myParty = self:GetMyParty()
		if not myParty then
			self:_OnPartyInviteResponse(userName, false)
			return
		end
		for i = 1, #myParty do
			if myParty[i] == userName then
				return
			end
		end
		
		self:_OnPartyInviteResponse(userName, false)
	end
	
	WG.Delay(InviteRejectCheck, 65)
	
	local sendData = {
		UserName = userName
	}
	self:_SendCommand("InviteToParty " .. json.encode(sendData))
	return self
end

function Interface:LeaveParty()
	if not self.myPartyID then
		return
	end
	local sendData = {
		PartyID = self.myPartyID
	}
	self:_SendCommand("LeaveParty " .. json.encode(sendData))
	return self
end

function Interface:PartyInviteResponse(partyID, accepted)
	local sendData = {
		PartyID = partyID,
		Accepted = accepted
	}
	self:_SendCommand("PartyInviteResponse " .. json.encode(sendData))
	return self
end

-------------------------------------------------
-- END Client commands
-------------------------------------------------

-------------------------------------------------
-- BEGIN Server commands
-------------------------------------------------

------------------------
-- Connectivity commands
------------------------

local registerResponseCodes = {
	[0] = "Ok",
	[1] = "Already connected",
	[2] = "Name already exists",
	[3] = "Invalid password",
	[4] = "Banned",
	[5] = "Invalid name",
}

local loginResponseCodes = {
	[0] = "Ok",
	[2] = "Invalid name",
	[3] = "Invalid password",
	[4] = "Banned",
}

function Interface:_Welcome(data)
	-- Engine
	-- Game
	-- Version of Game
	-- REVERSE COMPAT
	self.REVERSE_COMPAT = (data.Version == "1.4.9.26")
	self:_OnConnect(4, data.Engine, 2, 1)
	self:_OnUserCount(data.UserCount)
end
Interface.jsonCommands["Welcome"] = Interface._Welcome

function Interface:_DefaultEngineChanged(data)
	self:_OnSuggestedEngineVersion(data.Engine)
end
Interface.jsonCommands["DefaultEngineChanged"] = Interface._DefaultEngineChanged

function Interface:_DefaultGameChanged(data)
	self:_OnSuggestedGameVersion(data.Game)
end
Interface.jsonCommands["DefaultGameChanged"] = Interface._DefaultGameChanged

function Interface:_Ping(data)
	self:_OnPong()
	self:Ping()
end
Interface.jsonCommands["Ping"] = Interface._Ping

function Interface:_RegisterResponse(data)
	-- ResultCode: 1 = connected, 2 = name exists, 3 = password wrong, 4 = banned, 5 = bad name characters
	-- Reason (for ban I presume)
	if data.ResultCode == 0 then
		self:_OnRegistrationAccepted()
	else
		self:_OnRegistrationDenied(registerResponseCodes[data.ResultCode] or "Reason error " .. tostring(data.ResultCode))
	end
end
Interface.jsonCommands["RegisterResponse"] = Interface._RegisterResponse

function Interface:_LoginResponse(data)
	-- ResultCode: 1 = connected, 2 = name exists, 3 = password wrong, 4 = banned
	-- Reason (for ban I presume)
	if data.ResultCode == 0 then
		self:_OnAccepted()
	else
		self:_OnDenied(loginResponseCodes[data.ResultCode] or "Reason error " .. tostring(data.ResultCode))
	end
end
Interface.jsonCommands["LoginResponse"] = Interface._LoginResponse

------------------------
-- User commands
------------------------

-- This should be a local function but that does not work nicely.
function Interface:UpdateUserBattleStatus(userName, newBattleID)	
	if not self.REVERSE_COMPAT then
		local currentBattle = self.users[userName].battleID
		if newBattleID ~= currentBattle then
			if newBattleID then
				if currentBattle then
					self:_OnLeftBattle(currentBattle, userName)
				end
				if userName ~= self.myUserName then
					self:_OnJoinedBattle(newBattleID, userName, 0)
				end
			elseif currentBattle then
				self:_OnLeftBattle(currentBattle, userName)
			end
		end
	end
end

function Interface:_OnAddUser(userName, country, cpu, accountID, lobbyVersion, clan)
	cpu = tonumber(cpu)
	accountID = tonumber(accountID)
	self:super("_OnAddUser", userName, country, cpu, accountID, lobbyVersion, clan)
end
Interface.commands["ADDUSER"] = Interface._OnAddUser
Interface.commandPattern["ADDUSER"] = "(%S+)%s+(%S%S)%s+(%S+)%s*(.*)"

function Interface:_User(data)
	-- CHECKME: verify that name, country, cpu and similar info doesn't change
	-- It can change now that we remember user data of friends through disconnect.
	if self.users[data.Name] == nil or self.users[data.Name].isOffline then
		self:_OnAddUser(data.Name, {
			country = data.Country,
			clan = data.Clan,
			lobbyVersion = data.LobbyVersion,
			accountID = data.AccountID,
			isInGame = data.IsInGame,
			isAway = data.IsAway,
			isAdmin = data.IsAdmin,
			level = data.Level,
			skill1v1 = data.Effective1v1Elo,
			skill = data.EffectiveMmElo,
			isBot = data.IsBot,
			awaySince = data.AwaySince,
			inGameSince = data.InGameSince,
		})
		
		for i = 1, #self.commonChannels do
			self:_OnJoined(self.commonChannels[i], data.Name)
		end
		
		self:UpdateUserBattleStatus(data.Name, data.BattleID)
		return
	end

	self:_OnUpdateUserStatus(data.Name, {
		country = data.Country,
		clan = data.Clan,
		lobbyVersion = data.LobbyVersion,
		accountID = data.AccountID,
		isInGame = data.IsInGame,
		isAway = data.IsAway,
		isAdmin = data.IsAdmin,
		level = data.Level,
		skill1v1 = data.Effective1v1Elo,
		skill = data.EffectiveElo,
		isBot = data.IsBot,
		awaySince = data.AwaySince,
		inGameSince = data.InGameSince,
	})
	
	self:UpdateUserBattleStatus(data.Name, data.BattleID)
	
	-- User {"AccountID":212941,"SpringieLevel":1,"Avatar":"corflak","Country":"CZ","EffectiveElo":1100,"Effective1v1Elo":1100,"InGameSince":"2016-06-25T11:36:38.9075025Z","IsAdmin":false,"IsBot":true,"IsInBattleRoom":false,"BanMute":false,"BanSpecChat":false,"Level":0,"ClientType":4,"LobbyVersion":"Springie 1.3.2.116","Name":"Elerium","IsAway":false,"IsInGame":true}
end
Interface.jsonCommands["User"] = Interface._User

function Interface:_UserDisconnected(data)
	-- UserDisconnected {"Name":"Springiee81","Reason":"quit"}
	for i = 1, #self.commonChannels do
		self:_OnLeft(self.commonChannels[i], data.Name, "")
	end
	
	self:_OnRemoveUser(data.Name)
end
Interface.jsonCommands["UserDisconnected"] = Interface._UserDisconnected

------------------------
-- Friend and Ignore lists
------------------------

function Interface:_FriendList(data)
	--if self.friendListRecieved then
		local newFriendMap = {}
		for i = 1, #data.Friends do
			local userName = data.Friends[i]
			if not self.isFriend[userName] then
				self:_OnFriend(userName)
				self:_OnRemoveIgnoreUser(userName)
			end
			newFriendMap[userName] = true
		end
	
		for _, userName in pairs(self.friends) do
			if not newFriendMap[userName] then
				self:_OnUnfriend(userName)
				self:_OnRemoveIgnoreUser(userName)
			end
		end
		--return
	--end
	--self.friendListRecieved = true
	--
	--self:_OnFriendList(data.Friends)
end
Interface.jsonCommands["FriendList"] = Interface._FriendList

function Interface:_IgnoreList(data)
	--if self.ignoreListRecieved then
		local newIgnoreMap = {}
		for i = 1, #data.Ignores do
			local userName = data.Ignores[i]
			if not self.isIgnored[userName] then
				self:_OnAddIgnoreUser(userName)
				self:_OnUnfriend(userName)
			end
			newIgnoreMap[userName] = true
		end
	
		for _, userName in pairs(self.ignored) do
			if not newIgnoreMap[userName] then
				self:_OnUnfriend(userName)
				self:_OnRemoveIgnoreUser(userName)
			end
		end
		--return
	--end
	--self.ignoreListRecieved = true
	--
	--self:_OnIgnoreList(data.Ignores)
end
Interface.jsonCommands["IgnoreList"] = Interface._IgnoreList

------------------------
-- Battle commands
------------------------

function Interface:_ConnectSpring(data)
	if data.Ip and data.Port and data.ScriptPassword then
		Spring.Echo("Connecting to battle", data.Game, data.Map, data.Engine)
		self:ConnectToBattle(self.useSpringRestart, data.Ip, data.Port, data.ScriptPassword, data.Game, data.Map, data.Engine)
	end
end
Interface.jsonCommands["ConnectSpring"] = Interface._ConnectSpring

function Interface:_LeftBattle(data)
	self:_OnLeftBattle(data.BattleID, data.User)
end
Interface.jsonCommands["LeftBattle"] = Interface._LeftBattle

function Interface:_BattleAdded(data)
	-- {"Header":{"BattleID":3,"Engine":"100.0","Game":"Zero-K v1.4.6.11","Map":"Zion_v1","MaxPlayers":16,"SpectatorCount":1,"Title":"SERIOUS HOST","Port":8760,"Ip":"158.69.140.0","Founder":"Neptunium"}}
	local header = data.Header
	self:_OnBattleOpened(
		header.BattleID, 0, 0, header.Founder, header.Ip, header.Port, 
		header.MaxPlayers, (header.Password and true) or false, 0, 4, "Spring " .. header.Engine, header.Engine, 
		header.Map, header.Title or "no title", header.Game, header.SpectatorCount, 
		header.IsRunning, header.RunningSince, 
		header.Mode, 
		header.Mode and (header.Mode ~= 0), -- Is Custom
		header.Mode and (header.Mode ~= 5 and header.Mode ~= 0), -- Is Bots
		header.IsMatchMaker,
		header.PlayerCount
	)
end
Interface.jsonCommands["BattleAdded"] = Interface._BattleAdded

function Interface:_BattleRemoved(data)
	-- BattleRemoved {"BattleID":366}
	self:_OnBattleClosed(data.BattleID)
end
Interface.jsonCommands["BattleRemoved"] = Interface._BattleRemoved

function Interface:_JoinedBattle(data)
	-- {"BattleID":3,"User":"Neptunium"}
	if data.User == self:GetMyUserName() then
		self:_OnBattleScriptPassword(data.ScriptPassword)
		self:_OnJoinBattle(data.BattleID, 0)
	end
	self:_OnJoinedBattle(data.BattleID, data.User, 0)
end
Interface.jsonCommands["JoinedBattle"] = Interface._JoinedBattle

function Interface:_JoinBattleSuccess(data)
	
	self:_OnJoinBattle(data.BattleID, 0)
	
	local battle = self:GetBattle(data.BattleID)
	
	local newPlayers = data.Players
	local newPlayerMap = {}
	for i = 1, #newPlayers do
		newPlayerMap[newPlayers[i].Name] = true
	end
	for _, userName in pairs(battle.users) do
		if not newPlayerMap[userName] then
			self:_OnLeftBattle(data.BattleID, userName)
		end
	end
	for i = 1, #newPlayers do
		-- _OnJoinedBattle deals with duplicates
		self:_OnJoinedBattle(data.BattleID, newPlayers[i].Name)
		self:_UpdateUserBattleStatus(newPlayers[i])
	end
	
	local newAis = data.Bots
	battle.battleAis = {}
	for i = 1, #newAis do
		self:_UpdateBotStatus(newAis[i])
	end
	
	self:_OnSetModOptions(data.Options)
end
Interface.jsonCommands["JoinBattleSuccess"] = Interface._JoinBattleSuccess

function Interface:_BattleUpdate(data)
	-- BattleUpdate {"Header":{"BattleID":362,"Map":"Quicksilver 1.1"}
	-- BattleUpdate {"Header":{"BattleID":21,"Engine":"103.0.1-88-g1a9cfdd"}
	local header = data.Header
	--Spring.Utilities.TableEcho(header, "header")
	if not self.battles[header.BattleID] then
		Spring.Log(LOG_SECTION, LOG.ERROR, "Interface:_BattleUpdate no such battle with ID: " .. tostring(header.BattleID))
		return
	end
	
	local password = nil
	if header.Password ~= nil then
		password = (header.Password and true) or false
	end
	
	self:_OnUpdateBattleInfo(
		header.BattleID, 
		header.SpectatorCount, 
		header.Locked, 
		0, 
		header.Map, 
		header.Engine, 
		header.RunningSince, 
		header.Game, 
		header.Mode, 
		header.Mode and (header.Mode ~= 0), -- Is Custom
		header.Mode and (header.Mode ~= 5 and header.Mode ~= 0), -- Is Bots
		header.IsMatchMaker,
		header.MaxPlayers,
		header.Title,
		header.PlayerCount,
		password
	)
	
	if header.IsRunning ~= nil then
		-- battle.RunningSince should be set by this point.
		self:_OnBattleIngameUpdate(header.BattleID, header.IsRunning)
	end
end
Interface.jsonCommands["BattleUpdate"] = Interface._BattleUpdate

function Interface:_UpdateUserBattleStatus(data)
	-- UpdateUserBattleStatus {"AllyNumber":0,"IsSpectator":true,"Name":"GoogleFrog","Sync":1,"TeamNumber":1}
	local status = {
		isSpectator   = data.IsSpectator,
		allyNumber    = data.AllyNumber,
		teamNumber    = data.TeamNumber,
		sync          = data.Sync,
	}
	if not data.Name then
		Spring.Log(LOG_SECTION, LOG.ERROR, "_UpdateUserBattleStatus missing data.Name field")
		return
	end
	self:_OnUpdateUserBattleStatus(data.Name, status)
end
Interface.jsonCommands["UpdateUserBattleStatus"] = Interface._UpdateUserBattleStatus

function Interface:_UpdateBotStatus(data)
	local status = {
		allyNumber    = data.AllyNumber,
		teamNumber    = data.TeamNumber,
		aiLib         = data.AiLib,
		owner         = data.Owner,
	}
	if not data.Name then
		Spring.Log(LOG_SECTION, LOG.ERROR, "_UpdateBotStatus missing data.Name field")
		return
	end
	self:_OnAddAi(self:GetMyBattleID(), data.Name, status)
end
Interface.jsonCommands["UpdateBotStatus"] = Interface._UpdateBotStatus

function Interface:_RemoveBot(data)
	self:_OnRemoveAi(self:GetMyBattleID(), data.Name)
end
Interface.jsonCommands["RemoveBot"] = Interface._RemoveBot

------------------------
-- Channel & private chat commands
------------------------

local SPRINGIE_HOST_MESSAGE = "I'm here! Ready to serve you! Join me!"
local POLL_START_MESSAGE = "Poll:"
local POLL_END = "END:"
local POLL_END_SUCCESS = "END:SUCCESS"
local AUTOHOST_SUPRESSION = {
	["Sorry, you do not have rights to execute map"] = true,
}

function Interface:_JoinChannelResponse(data)
	-- JoinChannelResponse {"ChannelName":"sy","Success":true,"Channel":{"Users":["GoogleFrog","ikinz","DeinFreund","NorthChileanG","hokomoko"],"ChannelName":"sy"}}
	if data.Success then
		self:_OnJoin(data.ChannelName)
		self:_OnClients(data.ChannelName, data.Channel.Users)
	end
end
Interface.jsonCommands["JoinChannelResponse"] = Interface._JoinChannelResponse

function Interface:_ChannelUserAdded(data)
	if data.UserName ~= self:GetMyUserName() then
		self:_OnJoined(data.ChannelName, data.UserName)
	end
end
Interface.jsonCommands["ChannelUserAdded"] = Interface._ChannelUserAdded

function Interface:_ChannelUserRemoved(data)
	-- ChannelUserRemoved {"ChannelName":"zk","UserName":"Springiee81"}
	self:_OnLeft(data.ChannelName, data.UserName, "")
end
Interface.jsonCommands["ChannelUserRemoved"] = Interface._ChannelUserRemoved

local function FindLastOccurence(mainString, subString)
	local position = string.find(mainString, subString)
	local nextPosition = position
	while nextPosition do
		nextPosition = string.find(mainString, subString, position + 1)
		if nextPosition then
			position = nextPosition
		end
	end
	return position
end

function Interface:ProcessVote(data, battle, duplicateMessageTime)
	if (not battle) or battle.founder == data.User then
		return false
	end
	local message = data.Text
	if not message:starts(POLL_START_MESSAGE) then
		return false
	end
	
	local lastOpen = FindLastOccurence(message, "%[")
	local lastClose = FindLastOccurence(message, "%]")
	local lastQuestion = FindLastOccurence(message, "%?")
	if not (lastOpen and lastClose and lastQuestion) then
		return false
	end
	
	local voteMessage = string.sub(message, 0, lastQuestion)
	local lasturl = FindLastOccurence(message, " http")
	if lasturl then
		voteMessage = string.sub(voteMessage, 0, lasturl - 1) .. "?"
	end
	
	local voteData = string.sub(message, lastOpen + 1, lastClose - 1)
	if voteData:starts(POLL_END) then
		self:_OnVoteEnd(voteMessage, (voteData:starts(POLL_END_SUCCESS) and true) or false)
		return true
	end
	
	local lastSlash = FindLastOccurence(voteData, "/")
	if not lastSlash then
		return false
	end
	local votesNeeded = tonumber(string.sub(voteData, lastSlash + 1))
	
	local firstNo = string.find(voteData, "!n=")
	if not firstNo then
		return false
	end
	local noVotes = tonumber(string.sub(voteData, firstNo + 3, lastSlash - 1))
	
	local firstSlash = string.find(voteData, "/")
	if not firstSlash then
		return false
	end
	local yesVotes = tonumber(string.sub(voteData, 4, firstSlash - 1))
	
	if duplicateMessageTime and yesVotes == 0 then
		-- Workaround message ordering ZKLS bug.
		return true
	end
	
	self:_OnVoteUpdate(voteMessage, yesVotes, noVotes, votesNeeded)
	return true
end

function Interface:_Say(data)
	-- Say {"Place":0,"Target":"zk","User":"GoogleFrog","IsEmote":false,"Text":"bla","Ring":false,"Time":"2016-06-25T07:17:20.7548313Z}"
	local duplicateMessageTime = false
	if data.Time then
		if self.duplicateMessageTimes[data.Time] then
			duplicateMessageTime = true
			if self.duplicateMessageTimes[data.Time] == data.Text then
				return
			end
		end
		self.duplicateMessageTimes[data.Time] = data.Text
	end
	
	if AUTOHOST_SUPRESSION[data.Text] then
		if data.User and self.users[data.User] and self.users[data.User].isBot then
			return
		end
	end
	
	local emote = data.IsEmote
	if data.Place == 0 then -- Send to channel?
		if emote then
			self:_OnSaidEx(data.Target, data.User, data.Text, data.Time)
		else
			self:_OnSaid(data.Target, data.User, data.Text, data.Time)
		end
	elseif data.Place == 1 or data.Place == 3 then
		-- data.Place == 1 -> General battle chat
		-- data.Place == 3 -> Battle chat directed at user
		local battleID = self:GetMyBattleID()
		local battle = battleID and self:GetBattle(battleID)
		if self:ProcessVote(data, battle, duplicateMessageTime) then
			return
		end
		if emote then
			self:_OnSaidBattleEx(data.User, data.Text, data.Time)
		else
			self:_OnSaidBattle(data.User, data.Text, data.Time)
		end
	elseif data.Place == 2 then -- Send to user?
		if data.Target == self:GetMyUserName() then
			if emote then
				self:_OnSaidPrivateEx(data.User, data.Text, data.Time)
			else
				self:_OnSaidPrivate(data.User, data.Text, data.Time)
			end
		else
			if emote then
				self:_OnSayPrivateEx(data.Target, data.Text, data.Time)
			else
				self:_OnSayPrivate(data.Target, data.Text, data.Time)
			end
		end
	elseif data.Place == 5 then -- Protocol etc.. commands?
		if data.Text == "Invalid password" then
			self:_CallListeners("OnJoinBattleFailed", data.Text)
		end
		self:_OnSayServerMessage(data.Text, data.Time)
	end
end
Interface.jsonCommands["Say"] = Interface._Say

------------------------
-- MatchMaking commands
------------------------

function Interface:_MatchMakerSetup(data)
	local queues = data.PossibleQueues
	self.queueCount = 0
	self.queues = {}
	for i = 1, #queues do
		local queue = queues[i]
		self:_OnQueueOpened(queue.Name, queue.Description, queue.Maps, queue.MaxPartySize, {queue.Game})
	end
end
Interface.jsonCommands["MatchMakerSetup"] = Interface._MatchMakerSetup

function Interface:_MatchMakerStatus(data)
	self:_OnMatchMakerStatus(data.MatchMakerEnabled, data.JoinedQueues, data.QueueCounts, data.IngameCounts, data.InstantStartQueues, data.CurrentEloWidth, data.JoinedTime, data.BannedSeconds)
	self:_OnUserCount(data.UserCount)
end
Interface.jsonCommands["MatchMakerStatus"] = Interface._MatchMakerStatus

function Interface:_MatchMakerQueueRequestFailed(data)
	self:_OnMatchMakerStatus(false, nil, data.Reason)
end
Interface.jsonCommands["MatchMakerQueueRequestFailed"] = Interface._MatchMakerQueueRequestFailed

function Interface:_AreYouReady(data)
	self:_OnMatchMakerReadyCheck(data.SecondsRemaining)
end
Interface.jsonCommands["AreYouReady"] = Interface._AreYouReady

function Interface:_AreYouReadyUpdate(data)
	self:_OnMatchMakerReadyUpdate(data.ReadyAccepted, data.LikelyToPlay, data.QueueReadyCounts, data.YourBattleSize, data.YourBattleReady)
end
Interface.jsonCommands["AreYouReadyUpdate"] = Interface._AreYouReadyUpdate

function Interface:_AreYouReadyResult(data)
	self:_OnMatchMakerReadyResult(data.IsBattleStarting, data.AreYouBanned)
end
Interface.jsonCommands["AreYouReadyResult"] = Interface._AreYouReadyResult

------------------------
-- Party commands
------------------------

function Interface:_OnPartyInvite(data)
	self:_OnPartyInviteRecieved(data.PartyID, data.UserNames, data.TimeoutSeconds)
end
Interface.jsonCommands["OnPartyInvite"] = Interface._OnPartyInvite

function Interface:_OnPartyStatus(data)
	local partyID, partyUsers = data.PartyID, data.UserNames
	local wasInParty = false
	local nowInParty = false
	
	-- Update user partyID
	if self.partyMap[partyID] then
		for i = 1, #self.partyMap[partyID] do
			local userName = self.partyMap[partyID][i]
			-- Consider using self:TryGetUser(userName)
			if self.users[userName] then
				self.users[userName].partyID = nil
				if userName == self.myUserName then
					wasInParty = true
					self.myPartyID = nil
				end
			end
		end
	end
	
	for i = 1, #partyUsers do
		local userName = partyUsers[i]
		-- Consider using self:TryGetUser(userName)
		if self.users[userName] then
			self.users[userName].partyID = partyID
			if userName == self.myUserName then
				nowInParty = true
				self.myPartyID = partyID
			end
		end
	end
	
	-- Leave party even, before party is destroyed
	if wasInParty and not nowInParty then
		self:_OnPartyLeft(partyID, self.partyMap[partyID])
	end
	
	-- Update self.partyMap and make non-personal event
	if #partyUsers == 0 then
		if self.partyMap[partyID] then
			self:_OnPartyDestroy(partyID, self.partyMap[partyID])
			self.partyMap[partyID] = nil
		end
		return
	end
	self.partyMap[partyID] = partyUsers
	if self.partyMap[partyID] then
		self:_OnPartyUpdate(partyID, partyUsers)
	else
		self:_OnPartyCreate(partyID, partyUsers)
	end
	
	-- Update party invite response
	if self.myPartyID == partyID then
		for i = 1, #partyUsers do
			local userName = partyUsers[i]
			if self.users[userName] and self.users[userName].pendingPartyInvite then
				self:_OnPartyInviteResponse(userName, true)
			end
		end
	end
	
	-- Join party even, after party is created
	if not wasInParty and nowInParty then
		self:_OnPartyJoined(partyID, partyUsers)
	end
end
Interface.jsonCommands["OnPartyStatus"] = Interface._OnPartyStatus

-------------------
-- Unimplemented --

function Interface:_ChannelHeader(data)
	-- List of users
	-- Channel Name
	-- Password for channel
	-- Topic ???
	Spring.Echo("Implement ChannelHeader")
	--Spring.Utilities.TableEcho(data)
end
Interface.jsonCommands["ChannelHeader"] = Interface._ChannelHeader

function Interface:_SetRectangle(data)
	-- SetRectangle {"Number":1,"Rectangle":{"Bottom":120,"Left":140,"Right":200,"Top":0}}
	Spring.Echo("Implement SetRectangle")
	--Spring.Utilities.TableEcho(data, "SetRectangle")
end
Interface.jsonCommands["SetRectangle"] = Interface._SetRectangle

function Interface:_SetModOptions(data)
	if not data.Options then
		Spring.Echo("Invalid modoptions format")
		return
	end
	
	for _,_ in pairs(data.Options) do
		data.Options.commanderTypes = nil
		self:_OnSetModOptions(data.Options)
		return
	end
	
	self:_OnResetModOptions()
end
Interface.jsonCommands["SetModOptions"] = Interface._SetModOptions

--PwMatchCommand

-------------------------------------------------
-- END Client commands
-------------------------------------------------

function Interface:_OnSiteToLobbyCommand(msg)
	local springLink = msg.Command;

	if not springLink then
		return
	end
	springLink = tostring(springLink);
	
	local s,e = springLink:find('@start_replay:') 
	if(s == 1)then
		local repString = springLink:sub(15)
		Spring.Echo(repString);

		local replay, game, map, engine = repString:match("([^,]+),([^,]+),([^,]+),([^,]+)");
		self:_OnLaunchRemoteReplay(replay, game, map, engine);
		return
	end
	
	s,e = springLink:find('@select_map:') 
	if s then
		self:SelectMap(springLink:sub(e + 1))
		return
	end
	
	s,e = springLink:find('chat/user/') 
	if s then
		WG.Chobby.interfaceRoot.OpenPrivateChat(springLink:sub(e + 1))
		return
	end
end

Interface.jsonCommands["SiteToLobbyCommand"] = Interface._OnSiteToLobbyCommand

--Register
--JoinChannel
--LeaveChannel
--User
--OpenBattle
--RemoveBot
--ChangeUserStatus
--SetRectangle
--SetModOptions
--KickFromBattle
--KickFromServer
--KickFromChannel
--ForceJoinChannel
--ForceJoinBattle
--LinkSteam
--PwMatchCommand

return Interface
