
Hooks:PreHook(GrenadeCrateDeployableBase, "_set_empty", "SpecialEnemyDrops_EmptyGrenadeCrate", function(self)
    if not self._special_enemy_drop or not alive(self._unit) then
        return
    end

    self._grenade_amount = 0
    self:_set_visual_stage()
    local interaction = self._unit:interaction()
    if interaction then
        interaction:set_active(false, Network:is_server())
    end
end)

local original_take_grenade = GrenadeCrateDeployableBase.take_grenade

function GrenadeCrateDeployableBase:take_grenade(unit)
    -- Bolsas normais de jogadores continuam com comportamento normal.
    if not self._special_enemy_drop then
        return original_take_grenade(self, unit)
    end

    if self._empty or not self:_can_take_grenade(unit) then
        return
    end

    -- 30% of max throwable amount, minimum of 1.
    local max_grenades = managers.player:get_max_grenades()
    local restore_amount = math.max(1, math.floor(max_grenades * 0.30))

    unit:sound():play("pickup_ammo")

    managers.player:add_grenade_amount(restore_amount, true)

    managers.network:session():send_to_peers_synched(
        "sync_unit_event_id_16",
        self._unit,
        "base",
        1
    )

    self._grenade_amount = self._grenade_amount - 1

    if self._grenade_amount <= 0 then
        self:_set_empty()
    end

    self:_set_visual_stage()

    return restore_amount
end
