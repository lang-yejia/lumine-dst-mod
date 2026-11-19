local M = {}

function M.Install(G, hooks)
    local namespace = "LUMINE_STATUES"
    local function Send(name, shard, ...)
        hooks.send(hooks.get(namespace, name), shard, ...)
    end
    local function GetIndex()
        return G.TheWorld and G.TheWorld.components.luminestatueindex
    end
    hooks.add(namespace, "mask", function(shard, userid, mask)
        local index = GetIndex()
        if index and type(userid) == "string" and #userid <= 64
            and type(mask) == "number" and mask >= 0 and mask <= 127 and mask % 1 == 0 then
            index:Receive(tostring(shard), userid, mask)
        end
    end)
    hooks.add(namespace, "query", function(shard, userid)
        local index = GetIndex()
        if index and type(userid) == "string" and #userid <= 64 then
            Send("mask", tostring(shard), userid, index:LocalMask(userid))
        end
    end)

    local function Attach(world)
        if not world.ismastersim or world.components.luminestatueindex then return end
        local index = world:AddComponent("luminestatueindex")
        index.publish = function(userid, mask)
            for shard in pairs(G.ShardList) do Send("mask", shard, userid, mask) end
        end
        index.query = function(userid)
            for shard in pairs(G.ShardList) do Send("query", shard, userid) end
        end
        -- Recheck only online owners on shard reconnect, including owners whose
        -- final statue was removed while a neighboring shard was offline.
        world:DoPeriodicTask(15, function()
            for shard in pairs(G.ShardList) do
                for userid in pairs(index.players) do Send("query", shard, userid) end
            end
        end)
    end
    for _, prefab in ipairs({"world", "forest", "cave"}) do hooks.world(prefab, Attach) end
end

return M
