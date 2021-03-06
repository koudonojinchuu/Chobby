BattleListWindow = ListWindow:extends{}

local BATTLE_RUNNING = LUA_DIRNAME .. "images/runningBattle.png"
local BATTLE_NOT_RUNNING = LUA_DIRNAME .. "images/nothing.png"

local IMG_READY    = LUA_DIRNAME .. "images/ready.png"
local IMG_UNREADY  = LUA_DIRNAME .. "images/unready.png"

function BattleListWindow:init(parent)
	self:super("init", parent, i18n("custom_games"), true)

	self.btnNewBattle = Button:New {
		x = 190,
		y = 5,
		width = 150,
		height = 45,
		caption = i18n("open_mp_game"),
		font = Configuration:GetFont(3),
		classname = "option_button",
		parent = self.window,
		OnClick = {
			function ()
				self:OpenHostWindow()
			end
		},
	}

	self:SetMinItemWidth(320)
	self.columns = 3
	self.itemHeight = 80
	self.itemPadding = 1

	local update = function() self:Update() end

	self.onBattleOpened = function(listener, battleID)
		self:AddBattle(battleID, lobby:GetBattle(battleID))
	end
	lobby:AddListener("OnBattleOpened", self.onBattleOpened)

	self.onBattleClosed = function(listener, battleID)
		self:RemoveRow(battleID)
	end
	lobby:AddListener("OnBattleClosed", self.onBattleClosed)

	self.onJoinedBattle = function(listener, battleID)
		self:JoinedBattle(battleID)
	end
	lobby:AddListener("OnJoinedBattle", self.onJoinedBattle)

	self.onLeftBattle = function(listener, battleID)
		self:LeftBattle(battleID)
	end
	lobby:AddListener("OnLeftBattle", self.onLeftBattle)

	self.onUpdateBattleInfo = function(listener, battleID)
		self:OnUpdateBattleInfo(battleID)
	end
	lobby:AddListener("OnUpdateBattleInfo", self.onUpdateBattleInfo)

	self.onBattleIngameUpdate = function(listener, battleID, isRunning)
		self:OnBattleIngameUpdate(battleID, isRunning)
	end
	lobby:AddListener("OnBattleIngameUpdate", self.onBattleIngameUpdate)

	local function onConfigurationChange(listener, key, value)
		if key == "displayBadEngines" then
			update()
		end
	end
	Configuration:AddListener("OnConfigurationChange", onConfigurationChange)

	update()
end

function BattleListWindow:RemoveListeners()
	lobby:RemoveListener("OnBattleOpened", self.onBattleOpened)
	lobby:RemoveListener("OnBattleClosed", self.onBattleClosed)
	lobby:RemoveListener("OnJoinedBattle", self.onJoinedBattle)
	lobby:RemoveListener("OnLeftBattle", self.onLeftBattle)
	lobby:RemoveListener("OnUpdateBattleInfo", self.onUpdateBattleInfo)
end

function BattleListWindow:Update()
	self:Clear()

	local battles = lobby:GetBattles()
	Spring.Echo("Number of battles: " .. lobby:GetBattleCount())
	local tmp = {}
	for _, battle in pairs(battles) do
		table.insert(tmp, battle)
	end
	battles = tmp
	table.sort(battles,
		function(a, b)
			return lobby:GetBattlePlayerCount(a.battleID) > lobby:GetBattlePlayerCount(b.battleID)
		end
	)

	for _, battle in pairs(battles) do
		self:AddBattle(battle.battleID, battle)
	end
end

function BattleListWindow:AddBattle(battleID, battle)
	battle = battle or lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	if not WG.Chobby.Configuration.showMatchMakerBattles and battle and battle.isMatchMaker then
		return
	end

	local height = self.itemHeight - 20
	local parentButton = Button:New {
		name = "battleButton",
		x = 0,
		right = 0,
		y = 0,
		height = self.itemHeight,
		caption = "",
		OnClick = {
			function()
				local myBattleID = lobby:GetMyBattleID()
				if myBattleID then
					if battleID == myBattleID then
						-- Do not rejoin current battle
						local battleTab = WG.Chobby.interfaceRoot.GetBattleStatusWindowHandler()
						battleTab.OpenTabByName("myBattle")
						return
					end
					if not Configuration.confirmation_battleFromBattle then
						local myBattle = lobby:GetBattle(myBattleID)
						if not WG.Chobby.Configuration.showMatchMakerBattles and myBattle and not myBattle.isMatchMaker then
							local function Success()
								self:JoinBattle(battle)
							end
							ConfirmationPopup(Success, "Are you sure you want to leave your current battle and join a new one?", "confirmation_battleFromBattle")
							return
						end
					end
				end
				self:JoinBattle(battle)
			end
		},
		tooltip = "battle_tooltip_" .. battleID,
	}

	local lblTitle = Label:New {
		name = "lblTitle",
		x = height + 3,
		y = 0,
		right = 0,
		height = 20,
		valign = 'center',
		font = Configuration:GetFont(2),
		caption = battle.title,
		parent = parentButton,
		OnResize = {
			function (obj, xSize, ySize)
				obj:SetCaption(StringUtilities.GetTruncatedStringWithDotDot(battle.title, obj.font, obj.width))
			end
		}
	}
	local minimap = Panel:New {
		name = "minimap",
		x = 3,
		y = 3,
		width = height - 6,
		height = height - 6,
		padding = {1,1,1,1},
		parent = parentButton,
	}
	local minimapImage = Image:New {
		name = "minimapImage",
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		keepAspect = true,
		file = Configuration:GetMinimapSmallImage(battle.mapName),
		parent = minimap,
	}
	local runningImage = Image:New {
		name = "runningImage",
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		keepAspect = false,
		file = (battle.isRunning and BATTLE_RUNNING) or BATTLE_NOT_RUNNING,
		parent = minimap,
	}
	runningImage:BringToFront()

	local lblPlayers = Label:New {
		name = "playersCaption",
		x = height + 3,
		width = 50,
		y = 12,
		height = height - 10,
		valign = 'center',
		font = Configuration:GetFont(2),
		caption = lobby:GetBattlePlayerCount(battleID) .. "/" .. battle.maxPlayers,
		parent = parentButton,
	}

	if battle.passworded then
		local imgPassworded = Image:New {
			name = "password",
			x = height + 48,
			y = 22,
			height = 30,
			width = 30,
			margin = {0, 0, 0, 0},
			file = CHOBBY_IMG_DIR .. "lock.png",
			parent = parentButton,
		}
	end

	local imHaveGame = Image:New {
		name = "imHaveGame",
		x = height + 80,
		width = 15,
		height = 15,
		y = 20,
		height = 15,
		file = (VFS.HasArchive(battle.gameName) and IMG_READY or IMG_UNREADY),
		parent = parentButton,
	}
	local lblGame = Label:New {
		name = "gameCaption",
		x = height + 100,
		right = 0,
		y = 20,
		height = 15,
		valign = 'center',
		caption = battle.gameName:sub(1, 22),
		font = Configuration:GetFont(1),
		parent = parentButton,
	}

	local imHaveMap = Image:New {
		name = "imHaveMap",
		x = height + 80,
		width = 15,
		height = 15,
		y = 36,
		height = 15,
		file = (VFS.HasArchive(battle.mapName) and IMG_READY or IMG_UNREADY),
		parent = parentButton,
	}
	local lblMap = Label:New {
		name = "mapCaption",
		x = height + 100,
		right = 0,
		y = 36,
		height = 15,
		valign = 'center',
		caption = battle.mapName:gsub("_", " "),
		font = Configuration:GetFont(1),
		parent = parentButton,
	}

	self:AddRow({parentButton}, battle.battleID)
end

function BattleListWindow:CompareItems(id1, id2)
	if id1 and id2 then
		return lobby:GetBattlePlayerCount(id1) - lobby:GetBattlePlayerCount(id2)
	else
		local battle1, battle2 = lobby:GetBattle(id1), lobby:GetBattle(id2)
		Spring.Echo("battle1", id1, battle1, battle1 and battle1.users)
		Spring.Echo("battle2", id2, battle2, battle2 and battle2.users)
		return 0
	end
end

function BattleListWindow:DownloadFinished(downloadID, bla, moredata, thing)
	for battleID,_ in pairs(self.itemNames) do
		self:UpdateSync(battleID)
	end
end

function BattleListWindow:UpdateSync(battleID)
	local battle = lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	local items = self:GetRowItems(battleID)
	if not items then
		self:AddBattle(battleID)
		return
	end
	
	local imHaveMap = items.battleButton:GetChildByName("imHaveMap")
	local imHaveGame = items.battleButton:GetChildByName("imHaveGame")

	imHaveGame.file = (VFS.HasArchive(battle.gameName) and IMG_READY or IMG_UNREADY)
	imHaveMap.file = (VFS.HasArchive(battle.mapName) and IMG_READY or IMG_UNREADY)
end

function BattleListWindow:JoinedBattle(battleID)
	local battle = lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	local items = self:GetRowItems(battleID)
	if not items then
		self:AddBattle(battleID)
		return
	end
	
	local playersCaption = items.battleButton:GetChildByName("playersCaption")
	playersCaption:SetCaption(lobby:GetBattlePlayerCount(battleID) .. "/" .. battle.maxPlayers)
	self:RecalculateOrder(battleID)
end

function BattleListWindow:LeftBattle(battleID)
	local battle = lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	local items = self:GetRowItems(battleID)
	if not items then
		self:AddBattle(battleID)
		return
	end
	
	local playersCaption = items.battleButton:GetChildByName("playersCaption")
	playersCaption:SetCaption(lobby:GetBattlePlayerCount(battleID) .. "/" .. battle.maxPlayers)
	self:RecalculateOrder(battleID)
end

function BattleListWindow:OnUpdateBattleInfo(battleID)
	local battle = lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	local items = self:GetRowItems(battleID)
	if not items then
		self:AddBattle(battleID)
		return
	end
	
	local lblTitle = items.battleButton:GetChildByName("lblTitle")
	local mapCaption = items.battleButton:GetChildByName("mapCaption")
	local imHaveMap = items.battleButton:GetChildByName("imHaveMap")
	local minimapImage = items.battleButton:GetChildByName("minimap"):GetChildByName("minimapImage")
	local password = items.battleButton:GetChildByName("password")
	
	-- Password Update
	if password and not battle.passworded then
		password:Dispose()
	elseif battle.passworded and not password then
		local imgPassworded = Image:New {
			name = "password",
			x = items.battleButton.height + 28,
			y = 22,
			height = 30,
			width = 30,
			margin = {0, 0, 0, 0},
			file = CHOBBY_IMG_DIR .. "lock.png",
			parent = items.battleButton,
		}
	end
	
	-- Resets title and truncates.
	lblTitle.OnResize[1](lblTitle)
	
	minimapImage.file = Configuration:GetMinimapImage(battle.mapName)
	minimapImage:Invalidate()
	
	mapCaption:SetCaption(battle.mapName:gsub("_", " "))
	if VFS.HasArchive(battle.mapName) then
		imHaveMap.file = IMG_READY
	else
		imHaveMap.file = IMG_UNREADY
	end
	imHaveMap:Invalidate()
	
	local gameCaption = items.battleButton:GetChildByName("gameCaption")
	local imHaveGame = items.battleButton:GetChildByName("imHaveGame")
	
	imHaveGame.file = (VFS.HasArchive(battle.gameName) and IMG_READY or IMG_UNREADY)
	gameCaption:SetCaption(battle.gameName:gsub("_", " "))
	
	local playersCaption = items.battleButton:GetChildByName("playersCaption")
	playersCaption:SetCaption(lobby:GetBattlePlayerCount(battleID) .. "/" .. battle.maxPlayers)

	self:RecalculateOrder(battleID)
end

function BattleListWindow:OnBattleIngameUpdate(battleID, isRunning)
	local battle = lobby:GetBattle(battleID)
	if not (Configuration.displayBadEngines or Configuration:IsValidEngineVersion(battle.engineVersion)) then
		return
	end
	
	local items = self:GetRowItems(battleID)
	if not items then
		self:AddBattle(battleID)
		return
	end
	
	local runningImage = items.battleButton:GetChildByName("minimap"):GetChildByName("runningImage")
	if isRunning then
		runningImage.file = BATTLE_RUNNING
	else
		runningImage.file = BATTLE_NOT_RUNNING
	end
	runningImage:Invalidate()
	self:RecalculateOrder(battleID)
end

function BattleListWindow:OpenHostWindow()
	local hostBattleWindow = Window:New {
		caption = "",
		name = "hostBattle",
		parent = WG.Chobby.lobbyInterfaceHolder,
		width = 530,
		height = 310,
		resizable = false,
		draggable = false,
		classname = "overlay_window",
	}

	local title = Label:New {
		x = 15,
		width = 170,
		y = 15,
		height = 35,
		caption = i18n("open_mp_game"),
		font = Configuration:GetFont(4),
		parent = hostBattleWindow,
	}

	local gameNameLabel = Label:New {
		x = 15,
		width = 200,
		y = 75,
		align = "right",
		height = 35,
		caption = i18n("game_name") .. ":",
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
	}
	local gameNameEdit = EditBox:New {
		x = 220,
		width = 260,
		y = 70,
		height = 35,
		text = (lobby:GetMyUserName() or "Player") .. "'s Battle",
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
	}

	local passwordLabel = Label:New {
		x = 15,
		width = 200,
		y = 115,
		align = "right",
		height = 35,
		caption = i18n("password_optional") .. ":",
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
	}
	local passwordEdit = EditBox:New {
		x = 220,
		width = 260,
		y = 110,
		height = 35,
		text = "",
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
	}

	local typeLabel = Label:New {
		x = 15,
		width = 200,
		y = 155,
		align = "right",
		height = 35,
		caption = i18n("game_type") .. ":",
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
	}
	local typeCombo = ComboBox:New {
		x = 220,
		width = 260,
		y = 150,
		height = 35,
		itemHeight = 22,
		text = "",
		font = Configuration:GetFont(3),
		items = {"Cooperative", "Team", "1v1", "FFA", "Custom"},
		itemFontSize = Configuration:GetFont(3).size,
		selected = 1,
		parent = hostBattleWindow,
	}
	
	local function CancelFunc()
		hostBattleWindow:Dispose()
	end

	local function HostBattle()
		WG.BattleRoomWindow.LeaveBattle()
		if string.len(passwordEdit.text) > 0 then
			lobby:HostBattle(gameNameEdit.text, passwordEdit.text, typeCombo.items[typeCombo.selected])
		else
			lobby:HostBattle(gameNameEdit.text, nil, typeCombo.items[typeCombo.selected])
		end
		hostBattleWindow:Dispose()
	end

	local buttonHost = Button:New {
		right = 150,
		width = 135,
		bottom = 1,
		height = 70,
		caption = i18n("host"),
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
		classname = "action_button",
		OnClick = {
			function()
				HostBattle()
			end
		},
	}

	local buttonCancel = Button:New {
		right = 1,
		width = 135,
		bottom = 1,
		height = 70,
		caption = i18n("cancel"),
		font = Configuration:GetFont(3),
		parent = hostBattleWindow,
		classname = "negative_button",
		OnClick = {
			function()
				CancelFunc()
			end
		},
	}

	local popupHolder = PriorityPopup(hostBattleWindow, CancelFunc, HostBattle)
end

function BattleListWindow:JoinBattle(battle)
	-- We can be force joined to an invalid engine version. This widget is not
	-- the place to deal with this case.
	if not battle.passworded then
		WG.BattleRoomWindow.LeaveBattle()
		lobby:JoinBattle(battle.battleID)
	else
		local tryJoin, passwordWindow

		local function onJoinBattleFailed(listener, reason)
			lblError:SetCaption(reason)
		end
		local function onJoinBattle(listener)
			passwordWindow:Dispose()
		end

		passwordWindow = Window:New {
			x = 700,
			y = 300,
			width = 315,
			height = 240,
			caption = "",
			resizable = false,
			draggable = false,
			parent = WG.Chobby.lobbyInterfaceHolder,
			classname = "overlay_window",
			OnDispose = {
				function()
					lobby:RemoveListener("OnJoinBattleFailed", onJoinBattleFailed)
					lobby:RemoveListener("OnJoinBattle", onJoinBattle)
				end
			},
		}

		local lblPassword = Label:New {
			x = 25,
			right = 15,
			y = 15,
			height = 35,
			font = Configuration:GetFont(3),
			caption = i18n("enter_battle_password"),
			parent = passwordWindow,
		}

		local lblError = Label:New {
			x = 30,
			width = 100,
			y = 110,
			height = 80,
			caption = "",
			font = {
				color = { 1, 0, 0, 1 },
				size = Configuration:GetFont(2).size,
				shadow = Configuration:GetFont(2).shadow,
			},
			parent = passwordWindow,
		}

		local ebPassword = EditBox:New {
			x = 30,
			right = 30,
			y = 60,
			height = 35,
			text = "",
			hint = i18n("password"),
			fontsize = Configuration:GetFont(3).size,
			passwordInput = true,
			parent = passwordWindow,
		}

		function tryJoin()
			lblError:SetCaption("")
			WG.BattleRoomWindow.LeaveBattle()
			lobby:JoinBattle(battle.battleID, ebPassword.text)
		end

		local function CancelFunc()
			passwordWindow:Dispose()
		end

		local btnJoin = Button:New {
			x = 1,
			width = 135,
			bottom = 1,
			height = 70,
			caption = i18n("join"),
			font = Configuration:GetFont(3),
			classname = "action_button",
			OnClick = {
				function()
					tryJoin()
				end
			},
			parent = passwordWindow,
		}
		local btnClose = Button:New {
			right = 1,
			width = 135,
			bottom = 1,
			height = 70,
			caption = i18n("cancel"),
			font = Configuration:GetFont(3),
			classname = "negative_button",
			OnClick = {
				function()
					CancelFunc()
				end
			},
			parent = passwordWindow,
		}

		lobby:AddListener("OnJoinBattleFailed", onJoinBattleFailed)
		lobby:AddListener("OnJoinBattle", onJoinBattle)

		local popupHolder = PriorityPopup(passwordWindow, CancelFunc, tryJoin)
		screen0:FocusControl(ebPassword)
	end
end
