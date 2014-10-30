local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")

local knReadyCheckTimeout = 60 -- in seconds

local ReadyCheck = {}
function ReadyCheck:Init(parent)
	Apollo.LinkAddon(parent, self)

	self.callback = nil
	self.wndMain = nil

	Apollo.RegisterTimerHandler("ReadyCheckTimeout", "OnReadyCheckTimeout", self)
end

function ReadyCheck:Show(xmlDoc, index, message)
	local member = GroupLib.GetGroupMember(index)
	local strName = member and member.strCharacterName or Apollo.GetString("RaidFrame_TheRaid")
	
	self:Hide()
	
	Apollo.AlertAppWindow()
	Sound.Play(Sound.PlayUIQueuePopsAdventure)
	
	self.wndMain = Apollo.LoadForm(xmlDoc, "RaidReadyCheck", nil, self)
	self.wndMain:FindChild("ReadyCheckMessage"):SetText(String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckStarted"), strName) .. "\n" .. message)

	Apollo.CreateTimer("ReadyCheckTimeout", knReadyCheckTimeout, false)
end

function ReadyCheck:Hide()
	if self.wndMain then
		self.wndMain:Destroy()
	end
	self.wndMain = nil
end

function ReadyCheck:OnReadyCheckResponse(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetReady(wndHandler:GetName() == "ReadyCheckYesBtn")
	end
	self:Hide()
end

function ReadyCheck:OnReadyCheckTimeout()
	self:Hide()
	self.callback[2][self.callback[1]](self.callback[2])
end

VinceRaidFrames.ReadyCheck = ReadyCheck
