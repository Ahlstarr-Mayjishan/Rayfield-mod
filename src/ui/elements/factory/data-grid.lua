local DataGridFactory = {}

function DataGridFactory.create(context)
	context = context or {}
	local self = context.self
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local resolveElementParentFromSettings = context.resolveElementParentFromSettings
	local connectThemeRefresh = context.connectThemeRefresh
	local cloneSerializable = context.cloneSerializable
	local clampNumber = context.clampNumber
	local emitUICue = context.emitUICue
	local settingsValue = context.settings or {}

	if type(self) ~= "table" or not TabPage then
		return nil
	end
	if type(cloneSerializable) ~= "function" then
		cloneSerializable = function(value)
			return value
		end
	end
	if type(clampNumber) ~= "function" then
		clampNumber = function(value, minimum, maximum, fallback)
			local numberValue = tonumber(value)
			if not numberValue then
				numberValue = tonumber(fallback) or 0
			end
			if minimum ~= nil then
				numberValue = math.max(minimum, numberValue)
			end
			if maximum ~= nil then
				numberValue = math.min(maximum, numberValue)
			end
			return numberValue
		end
	end
	if type(emitUICue) ~= "function" then
		emitUICue = function() end
	end
	if type(connectThemeRefresh) ~= "function" then
		connectThemeRefresh = function() end
	end

	local dataGrid = {}
	dataGrid.Name = tostring(settingsValue.Name or "Data Grid")
	dataGrid.Flag = settingsValue.Flag
	dataGrid.CurrentValue = {
		rows = {},
		filter = "",
		sortKey = nil,
		sortDirection = "asc",
		selectedRow = nil
	}

	local columns = {}
	if type(settingsValue.Columns) == "table" then
		for _, col in ipairs(settingsValue.Columns) do
			if type(col) == "table" and tostring(col.Key or "") ~= "" then
				table.insert(columns, {
					Key = tostring(col.Key),
					Title = tostring(col.Title or col.Key),
					Width = tonumber(col.Width),
					Sortable = col.Sortable ~= false,
					Formatter = type(col.Formatter) == "function" and col.Formatter or nil
				})
			end
		end
	end
	if #columns == 0 then
		columns = {
			{ Key = "id", Title = "ID", Sortable = true }
		}
	end

	local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
	local onExport = type(settingsValue.OnExport) == "function" and settingsValue.OnExport or nil
	local filteredRows = {}
	local rowButtonPool = {}
	local rowButtonMeta = setmetatable({}, { __mode = "k" })
	local visibleButtonsByRowId = {}
	local selectedRowId = nil
	local rowHeight = math.max(20, math.floor(tonumber(settingsValue.RowHeight) or 24))
	local rowPadding = math.max(0, math.floor(tonumber(settingsValue.RowPadding) or 4))
	local overscanRows = math.max(1, math.floor(tonumber(settingsValue.VirtualOverscanRows) or 3))
	local virtualizationEnabled = settingsValue.Virtualization ~= false
	local writeFileFn = type(writefile) == "function" and writefile or nil
	local isFolderFn = type(isfolder) == "function" and isfolder or nil
	local makeFolderFn = type(makefolder) == "function" and makefolder or nil

	local function sanitizeFileName(value)
		local name = tostring(value or "datagrid")
		name = name:gsub("[^%w%-%_]+", "-")
		name = name:gsub("%-+", "-")
		name = name:gsub("^%-+", "")
		name = name:gsub("%-+$", "")
		if name == "" then
			name = "datagrid"
		end
		return string.lower(name)
	end

	local function splitDirectory(path)
		local normalized = tostring(path or ""):gsub("\\", "/")
		local directory = normalized:match("^(.*)/[^/]*$")
		if directory and directory ~= "" then
			return directory
		end
		return nil
	end

	local function ensureFolderPath(path)
		if type(path) ~= "string" or path == "" then
			return true, nil
		end
		if not makeFolderFn then
			return false, "makefolder unavailable"
		end
		local normalized = path:gsub("\\", "/")
		local current = ""
		for part in normalized:gmatch("[^/]+") do
			current = current == "" and part or (current .. "/" .. part)
			local exists = false
			if isFolderFn then
				local okExists, result = pcall(isFolderFn, current)
				exists = okExists and result == true
			end
			if not exists then
				local okMake = pcall(makeFolderFn, current)
				if not okMake then
					return false, "failed to create folder: " .. tostring(current)
				end
			end
		end
		return true, nil
	end

	local function csvEscape(value)
		local text = tostring(value or "")
		local needsQuote = string.find(text, ",", 1, true)
			or string.find(text, "\"", 1, true)
			or string.find(text, "\n", 1, true)
			or string.find(text, "\r", 1, true)
		if string.find(text, "\"", 1, true) then
			text = text:gsub("\"", "\"\"")
		end
		if needsQuote then
			text = "\"" .. text .. "\""
		end
		return text
	end

	local function normalizeExportArgs(pathOrOptions, maybeOptions)
		local options = {}
		if type(pathOrOptions) == "table" then
			options = cloneSerializable(pathOrOptions)
		elseif type(maybeOptions) == "table" then
			options = cloneSerializable(maybeOptions)
		end
		if type(pathOrOptions) == "string" and pathOrOptions ~= "" then
			options.path = pathOrOptions
		end
		if options.writeFile == nil then
			options.writeFile = true
		end
		if type(options.scope) ~= "string" then
			options.scope = "filtered"
		end
		options.scope = string.lower(options.scope)
		if options.scope ~= "all" and options.scope ~= "filtered" then
			options.scope = "filtered"
		end
		return options
	end

	local function resolveExportRows(options)
		if options.scope == "all" then
			return cloneSerializable(dataGrid.CurrentValue.rows)
		end
		return cloneSerializable(filteredRows)
	end

	local function resolveExportPath(extension, options)
		local ext = tostring(extension or "txt")
		local configuredPath = tostring(options.path or "")
		if configuredPath ~= "" then
			return configuredPath
		end
		local exportFolder = tostring(options.folder or "Rayfield/Exports")
		local stamp = type(os.time) == "function" and tostring(os.time()) or tostring(math.floor(os.clock() * 1000))
		local filename = string.format("%s-%s.%s", sanitizeFileName(dataGrid.Name), stamp, ext)
		return exportFolder .. "/" .. filename
	end

	local function writeExportContent(content, extension, options)
		if options.writeFile == false then
			return true, content, "inline"
		end
		if not writeFileFn then
			return false, "writefile API unavailable"
		end
		local path = resolveExportPath(extension, options)
		local directory = splitDirectory(path)
		if directory then
			local okFolder, folderErr = ensureFolderPath(directory)
			if not okFolder then
				local fallbackName = string.format("%s.%s", sanitizeFileName(dataGrid.Name), tostring(extension))
				path = fallbackName
				if folderErr then
					warn("Rayfield | DataGrid export fallback to root: " .. tostring(folderErr))
				end
			end
		end
		local okWrite, writeErr = pcall(writeFileFn, path, content)
		if not okWrite then
			return false, "write failed: " .. tostring(writeErr)
		end
		return true, path, "file"
	end

	local function emitExportResult(success, formatName, result, mode)
		if onExport then
			pcall(onExport, {
				success = success == true,
				format = tostring(formatName or ""),
				result = result,
				mode = mode
			})
		end
	end

	local root = Instance.new("Frame")
	root.Name = dataGrid.Name
	root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 180, 420, 250))
	root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
	root.BorderSizePixel = 0
	root.Visible = true
	root.Parent = TabPage

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 6)
	rootCorner.Parent = root

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = self.getSelectedTheme().ElementStroke
	rootStroke.Thickness = 1
	rootStroke.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 6)
	title.Size = UDim2.new(1, -142, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = dataGrid.Name
	title.TextColor3 = self.getSelectedTheme().TextColor
	title.Parent = root

	local exportCsvButton = Instance.new("TextButton")
	exportCsvButton.Name = "ExportCSV"
	exportCsvButton.Size = UDim2.fromOffset(56, 18)
	exportCsvButton.Position = UDim2.new(1, -126, 0, 6)
	exportCsvButton.BackgroundTransparency = 0.12
	exportCsvButton.BorderSizePixel = 0
	exportCsvButton.AutoButtonColor = true
	exportCsvButton.Font = Enum.Font.GothamBold
	exportCsvButton.TextSize = 11
	exportCsvButton.Text = "CSV"
	exportCsvButton.TextColor3 = self.getSelectedTheme().TextColor
	exportCsvButton.Parent = root

	local exportCsvCorner = Instance.new("UICorner")
	exportCsvCorner.CornerRadius = UDim.new(0, 4)
	exportCsvCorner.Parent = exportCsvButton

	local exportJsonButton = Instance.new("TextButton")
	exportJsonButton.Name = "ExportJSON"
	exportJsonButton.Size = UDim2.fromOffset(56, 18)
	exportJsonButton.Position = UDim2.new(1, -64, 0, 6)
	exportJsonButton.BackgroundTransparency = 0.12
	exportJsonButton.BorderSizePixel = 0
	exportJsonButton.AutoButtonColor = true
	exportJsonButton.Font = Enum.Font.GothamBold
	exportJsonButton.TextSize = 11
	exportJsonButton.Text = "JSON"
	exportJsonButton.TextColor3 = self.getSelectedTheme().TextColor
	exportJsonButton.Parent = root

	local exportJsonCorner = Instance.new("UICorner")
	exportJsonCorner.CornerRadius = UDim.new(0, 4)
	exportJsonCorner.Parent = exportJsonButton

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.BackgroundColor3 = self.getSelectedTheme().InputBackground or self.getSelectedTheme().SecondaryElementBackground
	searchBox.BorderSizePixel = 0
	searchBox.Position = UDim2.new(0, 10, 0, 28)
	searchBox.Size = UDim2.new(1, -20, 0, 24)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.PlaceholderText = tostring(settingsValue.SearchPlaceholder or "Search rows...")
	searchBox.Text = ""
	searchBox.ClearTextOnFocus = false
	searchBox.TextColor3 = self.getSelectedTheme().TextColor
	searchBox.PlaceholderColor3 = self.getSelectedTheme().TextColor:Lerp(Color3.fromRGB(90, 90, 90), 0.45)
	searchBox.Parent = root

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 5)
	searchCorner.Parent = searchBox

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.new(0, 10, 0, 56)
	header.Size = UDim2.new(1, -20, 0, 24)
	header.Parent = root

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 10, 0, 84)
	list.Size = UDim2.new(1, -20, 1, -94)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = root

	local function computeColumnWidths()
		local widths = {}
		local totalWidth = math.max(120, header.AbsoluteSize.X)
		local autoCount = 0
		local used = 0
		for _, col in ipairs(columns) do
			if col.Width and col.Width > 10 then
				used += col.Width
			else
				autoCount += 1
			end
		end
		local autoWidth = autoCount > 0 and math.max(60, math.floor((totalWidth - used) / autoCount)) or 60
		for index, col in ipairs(columns) do
			widths[index] = col.Width and math.max(50, math.floor(col.Width)) or autoWidth
		end
		return widths
	end

	local function formatRowValue(row, col)
		local value = row[col.Key]
		if col.Formatter then
			local okFormat, formatted = pcall(col.Formatter, value, row)
			if okFormat and formatted ~= nil then
				return tostring(formatted)
			end
		end
		if value == nil then
			return ""
		end
		return tostring(value)
	end

	local function getComparable(value)
		local numberValue = tonumber(value)
		if numberValue ~= nil then
			return "number", numberValue
		end
		return "string", string.lower(tostring(value or ""))
	end

	local function rowMatchesFilter(row, queryLower)
		if queryLower == "" then
			return true
		end
		for _, col in ipairs(columns) do
			local field = string.lower(formatRowValue(row, col))
			if string.find(field, queryLower, 1, true) then
				return true
			end
		end
		return false
	end

	local function sortRows(rows)
		local key = dataGrid.CurrentValue.sortKey
		if type(key) ~= "string" or key == "" then
			return
		end
		local direction = dataGrid.CurrentValue.sortDirection == "desc" and -1 or 1
		table.sort(rows, function(a, b)
			local typeA, valueA = getComparable(a[key])
			local typeB, valueB = getComparable(b[key])
			if typeA == typeB then
				if valueA == valueB then
					return tostring(a.id) < tostring(b.id)
				end
				return direction == 1 and valueA < valueB or valueA > valueB
			end
			return typeA == "number"
		end)
	end

	local function getRowStride()
		return rowHeight + rowPadding
	end

	local function buildRowText(row)
		local values = {}
		for _, col in ipairs(columns) do
			table.insert(values, formatRowValue(row, col))
		end
		return "  " .. table.concat(values, "  |  ")
	end

	local function applyRowButtonVisual(button, rowId)
		if not button then
			return
		end
		local isSelected = selectedRowId ~= nil and tostring(selectedRowId) == tostring(rowId)
		button.BackgroundColor3 = isSelected
			and (self.getSelectedTheme().SliderProgress or self.getSelectedTheme().ElementBackgroundHover)
			or self.getSelectedTheme().ElementBackground
		button.TextColor3 = isSelected
			and (self.getSelectedTheme().SelectedTabTextColor or self.getSelectedTheme().TextColor)
			or self.getSelectedTheme().TextColor
	end

	local function refreshRowVisual(rowId)
		local button = visibleButtonsByRowId[tostring(rowId or "")]
		if not button then
			return
		end
		applyRowButtonVisual(button, rowId)
	end

	local function ensureRowPoolSize(requiredCount)
		while #rowButtonPool < requiredCount do
			local rowButton = Instance.new("TextButton")
			rowButton.Name = "RowPooled"
			rowButton.Size = UDim2.new(1, -2, 0, rowHeight)
			rowButton.BackgroundColor3 = self.getSelectedTheme().ElementBackground
			rowButton.BackgroundTransparency = 0.08
			rowButton.BorderSizePixel = 0
			rowButton.AutoButtonColor = true
			rowButton.Font = Enum.Font.Code
			rowButton.TextSize = 12
			rowButton.TextXAlignment = Enum.TextXAlignment.Left
			rowButton.Text = ""
			rowButton.TextColor3 = self.getSelectedTheme().TextColor
			rowButton.Visible = false
			rowButton.Parent = list

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 4)
			rowCorner.Parent = rowButton

			rowButton.MouseButton1Click:Connect(function()
				emitUICue("click")
				local meta = rowButtonMeta[rowButton]
				local row = meta and filteredRows[meta.rowIndex] or nil
				if type(row) ~= "table" then
					return
				end
				local rowId = tostring(row.id)
				selectedRowId = rowId
				dataGrid.CurrentValue.selectedRow = cloneSerializable(row)
				for _, pooledButton in ipairs(rowButtonPool) do
					local pooledMeta = rowButtonMeta[pooledButton]
					if pooledMeta then
						applyRowButtonVisual(pooledButton, pooledMeta.rowId)
					end
				end
				local okCallback, callbackErr = pcall(callback, cloneSerializable(row))
				if not okCallback then
					warn("Rayfield | DataGrid callback error: " .. tostring(callbackErr))
				end
			end)

			table.insert(rowButtonPool, rowButton)
		end
	end

	local function updateCanvasSize()
		local totalHeight = (#filteredRows * getRowStride()) + 4
		list.CanvasSize = UDim2.fromOffset(0, math.max(totalHeight, list.AbsoluteSize.Y))
	end

	local function getVisibleRange()
		if not virtualizationEnabled then
			return 1, #filteredRows
		end
		local stride = math.max(1, getRowStride())
		local canvasY = math.max(0, math.floor(list.CanvasPosition.Y))
		local viewportHeight = math.max(0, math.ceil(list.AbsoluteSize.Y))
		local startIndex = math.floor(canvasY / stride) + 1 - overscanRows
		local endIndex = math.ceil((canvasY + viewportHeight) / stride) + overscanRows
		if startIndex < 1 then
			startIndex = 1
		end
		if endIndex > #filteredRows then
			endIndex = #filteredRows
		end
		return startIndex, endIndex
	end

	local function renderVisibleRows()
		visibleButtonsByRowId = {}
		local totalRows = #filteredRows
		if totalRows == 0 then
			for index, rowButton in ipairs(rowButtonPool) do
				rowButtonMeta[rowButton] = nil
				rowButton.Name = "RowPooled_" .. tostring(index)
				rowButton.Visible = false
			end
			return
		end

		local startIndex, endIndex = getVisibleRange()
		if endIndex < startIndex then
			endIndex = startIndex - 1
		end
		local visibleCount = math.max(0, endIndex - startIndex + 1)
		ensureRowPoolSize(visibleCount)

		local stride = getRowStride()
		for poolIndex, rowButton in ipairs(rowButtonPool) do
			local rowIndex = startIndex + poolIndex - 1
			if poolIndex <= visibleCount and rowIndex >= 1 and rowIndex <= endIndex then
				local row = filteredRows[rowIndex]
				if type(row) == "table" then
					local rowId = tostring(row.id)
					rowButtonMeta[rowButton] = {
						rowIndex = rowIndex,
						rowId = rowId
					}
					visibleButtonsByRowId[rowId] = rowButton
					rowButton.Visible = true
					rowButton.Name = rowId
					rowButton.Position = UDim2.new(0, 1, 0, (rowIndex - 1) * stride)
					rowButton.Size = UDim2.new(1, -2, 0, rowHeight)
					rowButton.Text = buildRowText(row)
					applyRowButtonVisual(rowButton, rowId)
				else
					rowButtonMeta[rowButton] = nil
					rowButton.Visible = false
				end
			else
				rowButtonMeta[rowButton] = nil
				rowButton.Name = "RowPooled_" .. tostring(poolIndex)
				rowButton.Visible = false
			end
		end
	end

	local function rebuildRows()
		filteredRows = {}
		local queryLower = string.lower(tostring(dataGrid.CurrentValue.filter or ""))

		for _, row in ipairs(dataGrid.CurrentValue.rows) do
			if rowMatchesFilter(row, queryLower) then
				table.insert(filteredRows, row)
			end
		end
		sortRows(filteredRows)

		if selectedRowId ~= nil then
			local matchedRow = nil
			for _, row in ipairs(filteredRows) do
				if tostring(row.id) == tostring(selectedRowId) then
					matchedRow = row
					break
				end
			end
			if matchedRow then
				dataGrid.CurrentValue.selectedRow = cloneSerializable(matchedRow)
			else
				selectedRowId = nil
				dataGrid.CurrentValue.selectedRow = nil
			end
		end

		updateCanvasSize()
		renderVisibleRows()
	end

	local function renderHeader()
		for _, child in ipairs(header:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local widths = computeColumnWidths()
		local offsetX = 0
		for index, col in ipairs(columns) do
			local width = widths[index]
			local colButton = Instance.new("TextButton")
			colButton.Name = "Column_" .. tostring(col.Key)
			colButton.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground or self.getSelectedTheme().ElementBackgroundHover
			colButton.BackgroundTransparency = 0.1
			colButton.BorderSizePixel = 0
			colButton.Size = UDim2.fromOffset(width, 22)
			colButton.Position = UDim2.fromOffset(offsetX, 1)
			colButton.Font = Enum.Font.GothamBold
			colButton.TextSize = 11
			colButton.TextXAlignment = Enum.TextXAlignment.Left
			colButton.TextColor3 = self.getSelectedTheme().TextColor
			colButton.Text = "  " .. tostring(col.Title)
			colButton.Parent = header

			local headerCorner = Instance.new("UICorner")
			headerCorner.CornerRadius = UDim.new(0, 4)
			headerCorner.Parent = colButton

			if col.Sortable ~= false then
				colButton.MouseButton1Click:Connect(function()
					local nextDirection = "asc"
					if dataGrid.CurrentValue.sortKey == col.Key and dataGrid.CurrentValue.sortDirection == "asc" then
						nextDirection = "desc"
					end
					dataGrid.CurrentValue.sortKey = col.Key
					dataGrid.CurrentValue.sortDirection = nextDirection
					rebuildRows()
				end)
			end

			offsetX += width + 4
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		dataGrid.CurrentValue.filter = tostring(searchBox.Text or "")
		rebuildRows()
	end)

	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateCanvasSize()
		renderVisibleRows()
	end)

	list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if virtualizationEnabled then
			renderVisibleRows()
		end
	end)

	local function buildCsvContent(options)
		local exportRows = resolveExportRows(options)
		local headerFields = {}
		for _, col in ipairs(columns) do
			table.insert(headerFields, csvEscape(col.Title or col.Key))
		end
		local lines = { table.concat(headerFields, ",") }
		for _, row in ipairs(exportRows) do
			local fields = {}
			for _, col in ipairs(columns) do
				table.insert(fields, csvEscape(formatRowValue(row, col)))
			end
			table.insert(lines, table.concat(fields, ","))
		end
		return table.concat(lines, "\n") .. "\n"
	end

	local function buildJsonContent(options)
		local payload = {
			name = dataGrid.Name,
			exportedAt = type(os.date) == "function" and os.date("!%Y-%m-%dT%H:%M:%SZ") or tostring(os.clock()),
			scope = options.scope,
			filter = tostring(dataGrid.CurrentValue.filter or ""),
			sort = {
				key = dataGrid.CurrentValue.sortKey,
				direction = dataGrid.CurrentValue.sortDirection
			},
			columns = {},
			rows = resolveExportRows(options)
		}
		for _, col in ipairs(columns) do
			table.insert(payload.columns, {
				Key = col.Key,
				Title = col.Title,
				Sortable = col.Sortable ~= false
			})
		end
		if self.HttpService and type(self.HttpService.JSONEncode) == "function" then
			local okEncode, encoded = pcall(self.HttpService.JSONEncode, self.HttpService, payload)
			if okEncode then
				return true, encoded
			end
			return false, "JSONEncode failed: " .. tostring(encoded)
		end
		return false, "HttpService.JSONEncode unavailable"
	end

	function dataGrid:ExportCSV(pathOrOptions, maybeOptions)
		local options = normalizeExportArgs(pathOrOptions, maybeOptions)
		local content = buildCsvContent(options)
		local okWrite, result, mode = writeExportContent(content, "csv", options)
		emitExportResult(okWrite, "csv", result, mode)
		return okWrite, result, mode
	end

	function dataGrid:ExportJSON(pathOrOptions, maybeOptions)
		local options = normalizeExportArgs(pathOrOptions, maybeOptions)
		local okJson, contentOrErr = buildJsonContent(options)
		if not okJson then
			emitExportResult(false, "json", contentOrErr, "error")
			return false, contentOrErr
		end
		local okWrite, result, mode = writeExportContent(contentOrErr, "json", options)
		emitExportResult(okWrite, "json", result, mode)
		return okWrite, result, mode
	end

	exportCsvButton.MouseButton1Click:Connect(function()
		emitUICue("click")
		local okExport, result = dataGrid:ExportCSV()
		if not okExport then
			warn("Rayfield | DataGrid CSV export failed: " .. tostring(result))
		end
	end)

	exportJsonButton.MouseButton1Click:Connect(function()
		emitUICue("click")
		local okExport, result = dataGrid:ExportJSON()
		if not okExport then
			warn("Rayfield | DataGrid JSON export failed: " .. tostring(result))
		end
	end)

	function dataGrid:SetRows(rows)
		local normalizedRows = {}
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" and row.id ~= nil then
					table.insert(normalizedRows, cloneSerializable(row))
				end
			end
		end
		dataGrid.CurrentValue.rows = normalizedRows
		if selectedRowId ~= nil then
			local found = false
			for _, row in ipairs(normalizedRows) do
				if tostring(row.id) == tostring(selectedRowId) then
					found = true
					break
				end
			end
			if not found then
				selectedRowId = nil
				dataGrid.CurrentValue.selectedRow = nil
			end
		end
		rebuildRows()
	end

	function dataGrid:GetRows()
		return cloneSerializable(dataGrid.CurrentValue.rows)
	end

	function dataGrid:SortBy(columnKey, direction)
		local key = tostring(columnKey or "")
		if key == "" then
			return false, "Invalid column key."
		end
		local dir = string.lower(tostring(direction or "asc"))
		if dir ~= "asc" and dir ~= "desc" then
			dir = "asc"
		end
		dataGrid.CurrentValue.sortKey = key
		dataGrid.CurrentValue.sortDirection = dir
		rebuildRows()
		return true, "ok"
	end

	function dataGrid:SetFilter(query)
		dataGrid.CurrentValue.filter = tostring(query or "")
		searchBox.Text = dataGrid.CurrentValue.filter
		rebuildRows()
		return true, "ok"
	end

	function dataGrid:GetFilter()
		return tostring(dataGrid.CurrentValue.filter or "")
	end

	function dataGrid:GetSelectedRow()
		return cloneSerializable(dataGrid.CurrentValue.selectedRow)
	end

	function dataGrid:GetPersistValue()
		return {
			filter = tostring(dataGrid.CurrentValue.filter or ""),
			sortKey = dataGrid.CurrentValue.sortKey,
			sortDirection = dataGrid.CurrentValue.sortDirection,
			selectedRowId = selectedRowId
		}
	end

	function dataGrid:Set(value)
		if type(value) ~= "table" then
			return
		end
		if value.filter ~= nil then
			dataGrid:SetFilter(value.filter)
		end
		if value.sortKey ~= nil then
			dataGrid:SortBy(value.sortKey, value.sortDirection)
		end
	end

	function dataGrid:Destroy()
		root:Destroy()
	end

	connectThemeRefresh(function()
		root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
		rootStroke.Color = self.getSelectedTheme().ElementStroke
		title.TextColor3 = self.getSelectedTheme().TextColor
		exportCsvButton.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground or self.getSelectedTheme().ElementBackgroundHover
		exportCsvButton.TextColor3 = self.getSelectedTheme().TextColor
		exportJsonButton.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground or self.getSelectedTheme().ElementBackgroundHover
		exportJsonButton.TextColor3 = self.getSelectedTheme().TextColor
		searchBox.BackgroundColor3 = self.getSelectedTheme().InputBackground or self.getSelectedTheme().SecondaryElementBackground
		searchBox.TextColor3 = self.getSelectedTheme().TextColor
		searchBox.PlaceholderColor3 = self.getSelectedTheme().TextColor:Lerp(Color3.fromRGB(90, 90, 90), 0.45)
		renderHeader()
		for _, rowButton in ipairs(rowButtonPool) do
			local meta = rowButtonMeta[rowButton]
			if meta then
				applyRowButtonVisual(rowButton, meta.rowId)
			end
		end
	end)

	renderHeader()
	exportCsvButton.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground or self.getSelectedTheme().ElementBackgroundHover
	exportJsonButton.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground or self.getSelectedTheme().ElementBackgroundHover
	if type(resolveElementParentFromSettings) == "function" then
		resolveElementParentFromSettings(dataGrid, settingsValue)
	end
	dataGrid:SetRows(settingsValue.Rows or {})
	if type(addExtendedAPI) == "function" then
		addExtendedAPI(dataGrid, dataGrid.Name, "DataGrid", root)
	end
	if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and dataGrid.Flag then
		self.RayfieldLibrary.Flags[dataGrid.Flag] = dataGrid
	end
	return dataGrid
end

return DataGridFactory
