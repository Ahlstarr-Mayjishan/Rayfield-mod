local SearchAlgorithms = {}

function SearchAlgorithms.lowerText(value)
	return string.lower(tostring(value or ""))
end

function SearchAlgorithms.fuzzyScore(queryLower, textLower)
	if queryLower == "" then
		return 0
	end
	if textLower == "" then
		return nil
	end

	local queryLength = #queryLower
	local qIndex = 1
	local score = 0
	local run = 0
	local firstMatch = nil

	for textIndex = 1, #textLower do
		if qIndex > queryLength then
			break
		end
		local qChar = string.sub(queryLower, qIndex, qIndex)
		local tChar = string.sub(textLower, textIndex, textIndex)
		if qChar == tChar then
			if not firstMatch then
				firstMatch = textIndex
			end
			score += 8
			if run > 0 then
				score += 4
			end
			if textIndex == 1 then
				score += 6
			else
				local prev = string.sub(textLower, textIndex - 1, textIndex - 1)
				if prev == " " or prev == "_" or prev == "-" or prev == "/" or prev == "." then
					score += 6
				end
			end
			run += 1
			qIndex += 1
		else
			run = 0
		end
	end

	if qIndex <= queryLength then
		return nil
	end

	local startPenalty = (firstMatch and (firstMatch - 1) or 0) * 0.5
	local lengthPenalty = math.max(0, #textLower - #queryLower) * 0.04
	return score - startPenalty - lengthPenalty
end

function SearchAlgorithms.computeMatchScore(queryLower, searchText, baseScore)
	local text = SearchAlgorithms.lowerText(searchText)
	local score = tonumber(baseScore) or 0
	if queryLower == "" then
		return score
	end
	if text == "" then
		return nil
	end
	-- Keep lexical tiers deterministic: prefix > contains > fuzzy.
	-- Usage boosts are added inside each tier but cannot cross tiers.
	if string.sub(text, 1, #queryLower) == queryLower then
		return score + 3000 - math.min(200, math.max(0, #text - #queryLower))
	end
	local containsStart = string.find(text, queryLower, 1, true)
	if containsStart then
		return score + 2000 - math.min(200, containsStart - 1)
	end
	local fuzzy = SearchAlgorithms.fuzzyScore(queryLower, text)
	if fuzzy then
		return score + 1000 + fuzzy
	end
	return nil
end

function SearchAlgorithms.applySuggested(items, queryLower, usageAnalytics)
	if queryLower ~= "" or not usageAnalytics then
		return items
	end
	local byId = {}
	for _, item in ipairs(items) do
		byId[item.id] = item
	end

	local function markSuggested(itemId, count)
		local item = byId[itemId]
		if not item then
			return
		end
		item.suggested = true
		item.usageCount = tonumber(count) or 0
		item.matchScore = (tonumber(item.matchScore) or 0) + 220 + math.min(140, item.usageCount * 14)
	end

	if type(usageAnalytics.getTopControls) == "function" then
		for _, entry in ipairs(usageAnalytics.getTopControls(3)) do
			markSuggested("control:" .. tostring(entry.key or ""), entry.count)
		end
	end
	if type(usageAnalytics.getTopCommands) == "function" then
		for _, entry in ipairs(usageAnalytics.getTopCommands(3)) do
			markSuggested("cmd:" .. tostring(entry.key or ""), entry.count)
		end
	end
	return items
end

function SearchAlgorithms.sortAndLimit(items, maxResults)
	table.sort(items, function(a, b)
		local scoreA = tonumber(a.matchScore) or 0
		local scoreB = tonumber(b.matchScore) or 0
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		if (a.suggested == true) ~= (b.suggested == true) then
			return a.suggested == true
		end
		local tabA = SearchAlgorithms.lowerText(a.tabId or "")
		local tabB = SearchAlgorithms.lowerText(b.tabId or "")
		if tabA ~= tabB then
			return tabA < tabB
		end
		local nameA = SearchAlgorithms.lowerText(a.name or "")
		local nameB = SearchAlgorithms.lowerText(b.name or "")
		if nameA ~= nameB then
			return nameA < nameB
		end
		return SearchAlgorithms.lowerText(a.id or "") < SearchAlgorithms.lowerText(b.id or "")
	end)

	local limit = math.max(1, math.floor(tonumber(maxResults) or #items))
	while #items > limit do
		table.remove(items)
	end
	return items
end

return SearchAlgorithms
