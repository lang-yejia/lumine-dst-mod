local Elements = require("lumine_statue_elements")

local Index = Class(function(self, inst)
    self.inst = inst
    self.local_owners, self.remote, self.players = {}, {}, {}
end)

function Index:LocalMask(userid)
    local mask = 0
    for id in pairs(self.local_owners[userid] or {}) do mask = mask + Elements[id].bit end
    return mask
end

function Index:Mask(userid)
    if not userid then return 0 end
    local mask = self:LocalMask(userid)
    for _, owners in pairs(self.remote) do mask = Elements.Merge(mask, owners[userid] or 0) end
    return mask
end

function Index:Refresh(userid)
    local player = self.players[userid]
    if player and player:IsValid() then player.components.luminestatuebonus:Apply(self:Mask(userid)) end
end

function Index:Change(statue, add)
    local userid, id = statue.statue_owner, statue.fixed_element
    if not userid or not id or add == statue._lumine_statue_indexed then return end
    if not add and not statue._lumine_statue_indexed then return end
    statue._lumine_statue_indexed = add
    local before = self:LocalMask(userid)
    local owners = self.local_owners[userid] or {}
    local count = (owners[id] or 0) + (add and 1 or -1)
    owners[id] = count > 0 and count or nil
    self.local_owners[userid] = next(owners) and owners or nil
    local after = self:LocalMask(userid)
    if before ~= after then
        self:Refresh(userid)
        if self.publish then self.publish(userid, after) end
    end
end

function Index:Receive(shard, userid, mask)
    local owners = self.remote[shard] or {}
    self.remote[shard] = owners
    owners[userid] = mask ~= 0 and mask or nil
    self:Refresh(userid)
end

function Index:Track(player)
    local userid = player.userid
    if not userid or userid == "" then return end
    if self.players[userid] ~= player then
        self.players[userid] = player
        player:ListenForEvent("onremove", function()
            if self.players[userid] == player then self.players[userid] = nil end
        end)
    end
    self:Refresh(userid)
    if self.query then self.query(userid) end
end

function Index:OnSave()
    return {remote = self.remote}
end

function Index:OnLoad(data)
    self.remote = type(data.remote) == "table" and data.remote or {}
end

return Index
