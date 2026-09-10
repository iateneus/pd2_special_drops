
Hooks:PreHook(DoctorBagBase, "_set_empty", "SpecialEnemyDrops_EmptyDoctorBag", function(self)
    if not self._special_enemy_drop or not alive(self._unit) then
        return
    end

    self._amount = 0
    self:_set_visual_stage()
    local interaction = self._unit:interaction()
    if interaction then
        interaction:set_active(false, Network:is_server())
    end
end)
