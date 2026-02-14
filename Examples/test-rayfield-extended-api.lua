-- Test script for Rayfield Modified Extended API
-- This script tests all new features

local Rayfield = loadstring(readfile("rayfield-modified.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Extended API Test",
    LoadingTitle = "Testing Extended Features",
    LoadingSubtitle = "by TuanTu",
})

local Tab = Window:CreateTab("Test Tab", 4483362458)

-- Test 1: Create elements
print("=== Test 1: Creating Elements ===")
local testButton = Tab:CreateButton({
    Name = "Test Button",
    Callback = function()
        print("Button clicked!")
    end
})

local testDropdown = Tab:CreateDropdown({
    Name = "Test Dropdown",
    Options = {"Option 1", "Option 2", "Option 3"},
    CurrentOption = {"Option 1"},
    Callback = function(option)
        print("Selected:", option)
    end
})

local testToggle = Tab:CreateToggle({
    Name = "Test Toggle",
    CurrentValue = false,
    Callback = function(value)
        print("Toggle:", value)
    end
})

local testSlider = Tab:CreateSlider({
    Name = "Test Slider",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(value)
        print("Slider:", value)
    end
})

Tab:CreateSection("Test Section")

-- Test 2: Get all elements
print("\n=== Test 2: Tab:GetElements() ===")
local elements = Tab:GetElements()
print("Total elements:", #elements)
for i, element in ipairs(elements) do
    print(string.format("%d. %s (%s)", i, element.Name, element.Type))
end

-- Test 3: Find element by name
print("\n=== Test 3: Tab:FindElement() ===")
local foundButton = Tab:FindElement("Test Button")
if foundButton then
    print("✓ Found Test Button")
else
    print("✗ Test Button not found")
end

local foundDropdown = Tab:FindElement("Test Dropdown")
if foundDropdown then
    print("✓ Found Test Dropdown")
else
    print("✗ Test Dropdown not found")
end

-- Test 4: Hide/Show elements
print("\n=== Test 4: Element Visibility ===")
print("Hiding Test Button...")
testButton:Hide()
task.wait(2)
print("Showing Test Button...")
testButton:Show()

-- Test 5: Dropdown Clear
print("\n=== Test 5: Dropdown:Clear() ===")
print("Setting dropdown to Option 2...")
testDropdown:Set({"Option 2"})
task.wait(2)
print("Clearing dropdown...")
testDropdown:Clear()
task.wait(2)

-- Test 6: GetParent
print("\n=== Test 6: Element:GetParent() ===")
local parent = testButton:GetParent()
if parent == Tab then
    print("✓ GetParent() works correctly")
else
    print("✗ GetParent() failed")
end

-- Test 7: Destroy single element
print("\n=== Test 7: Element:Destroy() ===")
print("Creating temporary button...")
local tempButton = Tab:CreateButton({
    Name = "Temporary Button",
    Callback = function() end
})
print("Elements before destroy:", #Tab:GetElements())
task.wait(1)
print("Destroying temporary button...")
tempButton:Destroy()
print("Elements after destroy:", #Tab:GetElements())

-- Test 8: Clear all elements
print("\n=== Test 8: Tab:Clear() ===")
Tab:CreateButton({
    Name = "Clear All Test",
    Callback = function()
        print("Clearing all elements in 3 seconds...")
        task.wait(3)
        Tab:Clear()
        print("All elements cleared!")
        print("Remaining elements:", #Tab:GetElements())
    end
})

print("\n=== All Tests Complete ===")
print("Click 'Clear All Test' button to test Tab:Clear()")

