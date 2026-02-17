local Assert = {}

function Assert.equal(actual, expected, message)
	if actual ~= expected then
		error(message or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
	end
end

function Assert.truthy(condition, message)
	if not condition then
		error(message or "Expected condition to be truthy")
	end
end

return Assert