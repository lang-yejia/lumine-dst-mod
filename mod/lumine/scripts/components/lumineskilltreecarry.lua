-- Restored on non-Lumine characters only when a reroll carried Lumine data.
local Carry = Class(function(self)
end)

function Carry:OnSave()
    return {add_component_if_missing = true, record = self.record}
end

function Carry:OnLoad(data)
    self.record = data.record
end

return Carry
