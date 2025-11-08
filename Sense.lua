function EspObject:Render()
	local onScreen = self.onScreen or false
	local enabled = self.enabled or false
	local visible = self.drawings.visible
	local hidden = self.drawings.hidden
	local box3d = self.drawings.box3d
	local interface = self.interface
	local options = self.options
	local corners = self.corners

	-- Бокс
	visible.box.Visible = enabled and onScreen and options.box
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline
	if visible.box.Visible then
		local box = visible.box
		box.Position = corners.topLeft
		box.Size = corners.bottomRight - corners.topLeft
		box.Color = parseColor(self, options.boxColor[1])
		box.Transparency = options.boxColor[2]

		local boxOutline = visible.boxOutline
		boxOutline.Position = box.Position
		boxOutline.Size = box.Size
		boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
		boxOutline.Transparency = options.boxOutlineColor[2]
	end

	-- Заполнение бокса
	visible.boxFill.Visible = enabled and onScreen and options.boxFill
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill
		boxFill.Position = corners.topLeft
		boxFill.Size = corners.bottomRight - corners.topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	-- Полоска здоровья слева от бокса
	visible.healthBar.Visible = enabled and onScreen and options.healthBar
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthRatio = math.clamp(self.health / self.maxHealth, 0, 1)
		local fullHeight = barTo.Y - barFrom.Y
		local currentHeight = fullHeight * healthRatio

		local healthBar = visible.healthBar
		-- Верх полоски = снизу бокса минус текущая высота
		healthBar.From = Vector2.new(barFrom.X, barTo.Y - currentHeight)
		healthBar.To = Vector2.new(barFrom.X, barTo.Y)
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, healthRatio)

		local healthBarOutline = visible.healthBarOutline
		healthBarOutline.From = Vector2.new(barFrom.X, barFrom.Y - HEALTH_BAR_OUTLINE_OFFSET.Y)
		healthBarOutline.To = Vector2.new(barFrom.X, barTo.Y + HEALTH_BAR_OUTLINE_OFFSET.Y)
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
		healthBarOutline.Transparency = options.healthBarOutlineColor[2]
	end

	-- Текст здоровья
	visible.healthText.Visible = enabled and onScreen and options.healthText
	if visible.healthText.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		local healthText = visible.healthText
		healthText.Text = round(self.health) .. "hp"
		healthText.Size = interface.sharedSettings.textSize
		healthText.Font = interface.sharedSettings.textFont
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.Outline = options.healthTextOutline
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		-- Текст ставим рядом с верхом полоски
		healthText.Position = Vector2.new(barFrom.X - healthText.TextBounds.X/2 - 2, barTo.Y - (barTo.Y - barFrom.Y) * (self.health/self.maxHealth) - healthText.TextBounds.Y/2)
	end

	-- Имя
	visible.name.Visible = enabled and onScreen and options.name
	if visible.name.Visible then
		local name = visible.name
		name.Size = interface.sharedSettings.textSize
		name.Font = interface.sharedSettings.textFont
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = options.nameColor[2]
		name.Outline = options.nameOutline
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.yAxis * name.TextBounds.Y - NAME_OFFSET
	end

	-- Дистанция
	visible.distance.Visible = enabled and onScreen and self.distance and options.distance
	if visible.distance.Visible then
		local distance = visible.distance
		distance.Text = round(self.distance) .. " studs"
		distance.Size = interface.sharedSettings.textSize
		distance.Font = interface.sharedSettings.textFont
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		distance.Outline = options.distanceOutline
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
	end

	-- Оружие
	visible.weapon.Visible = enabled and onScreen and options.weapon
	if visible.weapon.Visible then
		local weapon = visible.weapon
		weapon.Text = self.weapon
		weapon.Size = interface.sharedSettings.textSize
		weapon.Font = interface.sharedSettings.textFont
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.Outline = options.weaponOutline
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		weapon.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + (visible.distance.Visible and DISTANCE_OFFSET + Vector2.yAxis * visible.distance.TextBounds.Y or Vector2.zero)
	end

	-- Трассер
	visible.tracer.Visible = enabled and onScreen and options.tracer
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline
	if visible.tracer.Visible then
		local tracer = visible.tracer
		tracer.Color = parseColor(self, options.tracerColor[1])
		tracer.Transparency = options.tracerColor[2]
		tracer.To = (corners.bottomLeft + corners.bottomRight) * 0.5
		tracer.From =
			options.tracerOrigin == "Middle" and viewportSize * 0.5 or
			options.tracerOrigin == "Top" and viewportSize * Vector2.new(0.5, 0) or
			options.tracerOrigin == "Bottom" and viewportSize * Vector2.new(0.5, 1)

		local tracerOutline = visible.tracerOutline
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
		tracerOutline.Transparency = options.tracerOutlineColor[2]
		tracerOutline.To = tracer.To
		tracerOutline.From = tracer.From
	end

	-- Стрелка вне экрана
	hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow
	hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline
	if hidden.arrow.Visible and self.direction then
		local arrow = hidden.arrow
		arrow.PointA = min2(max2(viewportSize * 0.5 + self.direction * options.offScreenArrowRadius, Vector2.one * 25), viewportSize - Vector2.one * 25)
		arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45) * options.offScreenArrowSize
		arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45) * options.offScreenArrowSize
		arrow.Color = parseColor(self, options.offScreenArrowColor[1])
		arrow.Transparency = options.offScreenArrowColor[2]

		local arrowOutline = hidden.arrowOutline
		arrowOutline.PointA = arrow.PointA
		arrowOutline.PointB = arrow.PointB
		arrowOutline.PointC = arrow.PointC
		arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true)
		arrowOutline.Transparency = options.offScreenArrowOutlineColor[2]
	end

	-- 3D бокс
	local box3dEnabled = enabled and onScreen and options.box3d
	for i = 1, #box3d do
		local face = box3d[i]
		for i2 = 1, #face do
			local line = face[i2]
			line.Visible = box3dEnabled
			line.Color = parseColor(self, options.box3dColor[1])
			line.Transparency = options.box3dColor[2]
		end

		if box3dEnabled then
			local line1 = face[1]
			line1.From = corners.corners[i]
			line1.To = corners.corners[i == 4 and 1 or i + 1]

			local line2 = face[2]
			line2.From = corners.corners[i == 4 and 1 or i + 1]
			line2.To = corners.corners[i == 4 and 5 or i + 5]

			local line3 = face[3]
			line3.From = corners.corners[i == 4 and 5 or i + 5]
			line3.To = corners.corners[i == 4 and 8 or i + 4]
		end
	end
end
