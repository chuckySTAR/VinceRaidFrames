local setmetatable = setmetatable
local ipairs = ipairs
local abs = math.abs

local ktIdToClassSprite =
{
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local tTargetMarkSpriteMap = {
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO"
}

local MarkerPixie = {
	cr = "ffffffff",
	loc = {
		fPoints = {1, .5, 1, .5},
		nOffsets = {-25, -10, -5, 10}
	}
}

local ColorByClass = 1
local ColorByHealth = 2


local Member = {}
Member.__index = Member
function Member:OnLoad()
	self.previousTarget = nil
end
function Member:new(unit, groupMember, settings, parent, xmlDoc)
	local o = {
		unit = unit,
		groupMember = groupMember,
		readyCheckMode = false,
		frame = Apollo.LoadForm(xmlDoc, "Member", parent, self),
		settings = settings,
		classId = groupMember and groupMember.eClassId or unit:GetClassId(),
		classColor = nil,
		classIconPixie = nil,
		targetMarkerPixie = nil,
		hasAggro = false,
		potionPixie = nil,
		foodPixie = nil,
		lastHealthColor = nil,
		lastFoodSprite = "",
		health = nil,
		flash = nil,
		text = nil,
		timer = nil
	}
    setmetatable(o, self)

	o.classColor = settings.classColors[o.classId]

	o.memberOverlay = o.frame:FindChild("MemberOverlay")
	o.container = o.frame:FindChild("Container")
	o.overlay = o.frame:FindChild("Overlay")
	o.health = o.frame:FindChild("HealthBar")
	o.shield = o.frame:FindChild("ShieldBar")
	o.absorb = o.frame:FindChild("AbsorbBar")
	o.flash = o.frame:FindChild("Flash")
	o.text = o.frame:FindChild("Text")

	o:Arrange()
	o:ShowClassIcon(settings.memberShowClassIcon)

	o.text:SetText(groupMember and groupMember.strCharacterName or unit:GetName())
	o.text:SetFont(settings.memberFont)
	o:SetNameColor(settings.memberColor)

	o.frame:SetData(o)
	o.flash:Show(false, true)
--	o:SetReadyCheckMode()
	o:UnsetReadyCheckMode()
	o:Refresh(false, unit, groupMember)
	
	-- Bug: SetTarget() isn't updated on reloadui
	
	return o
end

function Member:GetWidth()
	return self.settings.memberWidth + (self.settings.memberShowTargetMarker and 20 or 0)
end

function Member:GetHeight()
	return self.settings.memberHeight
end

function Member:Arrange()
	self.frame:SetAnchorOffsets(0, 0, self:GetWidth(), self:GetHeight())
	self.container:SetAnchorOffsets(0, 0, self.settings.memberShowTargetMarker and -20 or 0, 0)
	if self.settings.memberShieldsBelowHealth then
		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1, -1 - self.settings.memberShieldHeight - self.settings.memberAbsorbHeight)

		self.frame:FindChild("Shield"):SetAnchorPoints(0, 1, 1, 1)
		self.frame:FindChild("Shield"):SetAnchorOffsets(1, -1 - self.settings.memberShieldHeight, -1, -1)

		self.frame:FindChild("Absorption"):SetAnchorPoints(0, 1, 1, 1)
		self.frame:FindChild("Absorption"):SetAnchorOffsets(1, -1 - self.settings.memberAbsorbHeight - self.settings.memberShieldHeight, -1, -1 - self.settings.memberShieldHeight)
	else
		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1 - self.settings.memberShieldWidth - self.settings.memberAbsorbWidth, -1)

		self.frame:FindChild("Shield"):SetAnchorPoints(1, 0, 1, 1)
		self.frame:FindChild("Shield"):SetAnchorOffsets(-1 - self.settings.memberShieldWidth - self.settings.memberAbsorbWidth, 1, -1 - self.settings.memberAbsorbWidth, -1)

		self.frame:FindChild("Absorption"):SetAnchorPoints(1, 0, 1, 1)
		self.frame:FindChild("Absorption"):SetAnchorOffsets(-1 - self.settings.memberAbsorbWidth, 1, -1, -1)
	end
end

function Member:SetAggro(aggro)
	self.hasAggro = aggro
	if aggro then
		self:SetNameColor(self.settings.memberAggroTextColor)
	else
		self:SetNameColor(self.settings.memberColor)
	end
end

function Member:ShowClassIcon(show)
	if show then
		self.classIconPixie = self.overlay:AddPixie({
			cr = "ff111111",
			strSprite = "IconSprites:" .. ktIdToClassSprite[self.classId],
			loc = {
				fPoints = {0, .5, 0, .5},
				nOffsets = {2, -8, 18, 8}
			}
		})
		self.text:SetAnchorOffsets(20, 0, 70, 0)
	else
		self.overlay:DestroyPixie(self.classIconPixie)
		self.text:SetAnchorOffsets(5, 0, 70, 0)
	end
end

function Member:UpdateColorBy(color)
	if color == ColorByClass and not self.readyCheckMode then
		self:SetHealthColor(self.classColor)
--	elseif color == ColorByHealth then
--		self:Refresh()
	end
end


function Member:Refresh(readyCheckMode, unit, groupMember)
	self.readyCheckMode = readyCheckMode
	self.unit = unit and unit or self.unit

	unit = self.unit

	local health
	local shield
	local absorb
	local outOfRange
	local dead
	local online

	if groupMember then
		health = groupMember.nHealth / groupMember.nHealthMax
		shield = groupMember.nShield / groupMember.nShieldMax
		absorb = groupMember.nAbsorptionMax == 0 and 0 or groupMember.nAbsorption / groupMember.nAbsorptionMax

		outOfRange = groupMember.nHealthMax == 0 or not unit
		dead = groupMember.nHealth == 0 and groupMember.nHealthMax ~= 0
		online = groupMember.bIsOnline
	else
		health = unit:GetHealth() / unit:GetMaxHealth()
		shield = unit:GetShieldCapacity() / unit:GetShieldCapacityMax()
		absorb = unit:GetAbsorptionMax() == 0 and 0 or unit:GetAbsorptionValue() / unit:GetAbsorptionMax()

		outOfRange = false
		dead = unit:IsDead()
		online = true
	end

	-- Todo: Remember last status in order to optimse useless function calls
	if outOfRange and not dead and online then
		self.frame:SetOpacity(self.settings.memberOutOfRangeOpacity, 5)
	else
		self.frame:SetOpacity(1, 5)
	end

	if not self.hasAggro then
		if not online then
			self:SetNameColor(self.settings.memberOfflineTextColor)
		elseif dead then
			self:SetNameColor(self.settings.memberDeadTextColor)
		else
			self:SetNameColor(self.settings.memberColor)
		end
	end

	if self.settings.colorBy == ColorByHealth then
		self:SetHealthColor(self.GetColorBetween(self.settings.memberLowHealthColor, self.settings.memberHighHealthColor, health))
	end

    if self.settings.memberFillLeftToRight then
		self.health:SetAnchorPoints(0, 0, health, 1)
		self.shield:SetAnchorPoints(0, 0, shield, 1)
		self.absorb:SetAnchorPoints(0, 0, absorb, 1)
	else
		self.health:SetAnchorPoints(1 - health, 0, 1, 1)
		self.shield:SetAnchorPoints(0, 0, 1 - shield, 1)
		self.absorb:SetAnchorPoints(0, 0, 1 - absorb, 1)
	end

	if unit then
		local sprite = tTargetMarkSpriteMap[unit:GetTargetMarker()]
		if sprite and not self.targetMarkerPixie then
			MarkerPixie.strSprite = sprite
			self.targetMarkerPixie = self.memberOverlay:AddPixie(MarkerPixie)
		elseif not sprite then
			self.memberOverlay:DestroyPixie(self.targetMarkerPixie)
			self.targetMarkerPixie = nil
		end
	elseif self.targetMarkerPixie then
		self.memberOverlay:DestroyPixie(self.targetMarkerPixie)
		self.targetMarkerPixie = nil
	end

	
	if readyCheckMode then
		self:RefreshIcons()
		if groupMember and groupMember.bHasSetReady then
			if not groupMember.bReady then
				self:SetHealthColor("ff0000")
			elseif not self.potionPixie or not self.foodPixie then
				self:SetHealthColor("ffff00")
			else
				self:SetHealthColor("00ff00")
			end
		end
	end
end

function Member:RefreshIcons()
	if self.unit then
		local potionFound = false
		local foodFound = false
		local buffs = self.unit:GetBuffs()
		if buffs then
			for key, buff in ipairs(buffs.arBeneficial) do
				local potionSprite = self.settings.potions[buff.splEffect:GetId()]
				local foodSprite = self.settings.food[buff.splEffect:GetId()]
				if potionSprite then
					potionFound = true
					self:AddPotion(potionSprite)
				end
				if foodSprite then
					foodFound = true
					self:AddFood(foodSprite)
				end
				if potionFound and foodFound then
					break
				end
			end
		end
		if not potionFound then
			self:RemovePotion()
		end
		if not foodFound then
			self:RemoveFood()
		end
	end
end

function Member:SetNameColor(color)
    self.text:SetTextColor(color)
end

function Member:SetReadyCheckMode()
	self:SetHealthColor("cccccc")
end

function Member:UnsetReadyCheckMode()
	self:SetHealthColor(self.classColor)
	
	self:RemovePotion()
	self:RemoveFood()
end

function Member:GetIconOffsets(position)
	return -(position + 1) * self.settings.memberIconSizes - 1 -3 * position, -self.settings.memberIconSizes / 2, -position * self.settings.memberIconSizes - 1 -3 * position, self.settings.memberIconSizes / 2
end

function Member:AddPotion(sprite)
	if self.potionPixie then
		return
	end

	if self.foodPixie then
		self.overlay:UpdatePixie(self.foodPixie, {
			cr = "ffffffff",
			strSprite = self.lastFoodSprite,
			loc = {
				fPoints = {1, .5, 1, .5},
				nOffsets = {self:GetIconOffsets(1)}
			}
		})
	end

	self.potionPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetIconOffsets(0)}
		}
	})
end

function Member:AddFood(sprite)
	if self.foodPixie then
		return
	end
	self.lastFoodSprite = sprite

	local position = 0
	if self.potionPixie then
		position = position + 1
	end

	self.foodPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetIconOffsets(position)}
		}
	})
end

function Member:RemovePotion()
	if self.potionPixie then
		if self.foodPixie then
			self.overlay:UpdatePixie(self.foodPixie, {
				cr = "ffffffff",
				strSprite = self.lastFoodSprite,
				loc = {
					fPoints = {1, .5, 1, .5},
					nOffsets = {self:GetIconOffsets(0)}
				}
			})
		end
		
		self.overlay:DestroyPixie(self.potionPixie)
		self.potionPixie = nil
	end
end

function Member:RemoveFood()
	if self.foodPixie then
		self.overlay:DestroyPixie(self.foodPixie)
		self.foodPixie = nil
	end
end

function Member:Interrupted(amount)
	if self.timer then
		self.timer:Start()
	else
		self.timer = ApolloTimer.Create(self.settings.interruptFlashDuration, false, "OnInterruptedEnd", self)
	end
	self.flash:Show(true, true)
end

function Member:SetTarget()
	self.targeted = true
	self:SetHealthAlpha("2x:bb")
	-- self.frame:SetBGColor("bbffffff")
end

function Member:UnsetTarget()
	self.targeted = false
	self:SetHealthAlpha("ff")
	-- self:RestoreLastHealthAlpha()
	-- self.frame:SetBGColor("ff000000")
end

function Member:SetHealthColor(color, alpha)
	self.lastHealthColor = color
	self.lastHealthAlpha = alpha or "ff"
	self.health:SetBGColor(self.lastHealthAlpha .. color)
end

function Member:SetHealthAlpha(alpha)
	self.lastHealthAlpha = alpha
	self.health:SetBGColor(alpha .. self.lastHealthColor)
end

function Member:RestoreLastHealthAlpha()
	self:SetHealthColor(self.lastHealthColor, self.lastHealthAlpha)
end

function Member:OnMemberClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	local data = wndHandler:GetData()
	if data.unit then
		self.previousTarget = data.unit
		GameLib.SetTargetUnit(data.unit)
	end
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", data.frame, data.unit and data.unit:GetName() or data.groupMember.strCharacterName, data.unit)
	end
end

function Member:OnMouseEnter(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	local data = wndHandler:GetData()
	if not data.targeted then
		data:SetHealthAlpha("2x:88")
	end
	if data.unit then
		if data.settings.hintArrowOnHover then
			data.unit:ShowHintArrow()
		end
		if data.settings.targetOnHover then
			self.previousTarget = GameLib.GetPlayerUnit():GetTarget()
			GameLib.SetTargetUnit(data.unit)
		end
	end
end

function Member:OnMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	local data = wndHandler:GetData()
	if not data.targeted then
		data:SetHealthAlpha("ff")
		-- data:RestoreLastHealthAlpha()
	end
	if data.settings.targetOnHover then
		GameLib.SetTargetUnit(self.previousTarget)
	end
end

function Member:OnMemberDown(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl or not wndHandler or not bDoubleClick then
		return
	end
	-- dbl click
end

function Member:OnInterruptedEnd()
	self.flash:Show(false)
end

function Member:Destroy()
	self.frame:Destroy()
end

function Member.GetColorBetween(from, to, position)
	return ("%02X%02X%02X"):format(((to.r - from.r) * position + from.r) * 255, ((to.g - from.g) * position + from.g) * 255, ((to.b - from.b) * position + from.b) * 255)
end

Apollo.RegisterPackage(Member, "Vince:VRF:Member-1", 1, {})
