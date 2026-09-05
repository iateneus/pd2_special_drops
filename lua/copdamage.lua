-- Special Enemy Drops
-- Version 0.2: guaranteed drops and sync between host and clients.
-- Version 0.3: optimizations of the code;
-- Version 0.4: small adjustments to balance the mod;
-- Version 0.5: cleaning of code and added comments in code for better understanding;
-- Version 0.6: added thumbnail and support for self updates via Modworkshop;

local MOD_ID = "SpecialEnemyDrops"

local AMMO_ENEMIES = {
    taser = true,
    shield = true,
    marshal_shield = true,
    marshal_shield_break = true,
    spooc = true,
    shadow_spooc = true,
    tank_green = true,
    tank_skull = true,
    sniper = true,
    heavy_swat_sniper = true,
    marshal_marksman = true
}

local function spawn_ammo_box(position, rotation)
    managers.game_play_central:spawn_pickup({
        name = "ammo",
        position = position,
        rotation = rotation or Rotation()
    })
end

local function spawn_extra_ammo(unit, amount)
    local base_position = unit:position()
    local rotation = unit:rotation()

    for i = 1, amount do
        local offset = Vector3(
            math.random(-45, 45),
            math.random(-45, 45),
            15
        )

        spawn_ammo_box(base_position + offset, rotation)
    end
end

Hooks:Add("NetworkReceivedData", MOD_ID .. "_ReceiveAmmoDrops", function(sender, id, data)
    if id ~= MOD_ID .. "_AmmoDrops" then
        return
    end

    local x, y, z, amount = data:match("^([^;]+);([^;]+);([^;]+);([^;]+)$")

    if not x then
        return
    end

    local position = Vector3(tonumber(x), tonumber(y), tonumber(z))
    spawn_extra_ammo({
        position = function()
            return position
        end,
        rotation = function()
            return Rotation()
        end
    }, tonumber(amount))
end)

-- RESOURCE BAGS
-- ============================================================

local function drop_position(unit)
    local start_pos = unit:position() + Vector3(0, 0, 80)
    local end_pos = unit:position() - Vector3(0, 0, 200)

    local ray = unit:raycast(
        "ray",
        start_pos,
        end_pos,
        "slot_mask",
        managers.slot:get_mask("world_geometry")
    )

    if ray then
        return ray.position
    end

    return unit:position()
end

local function drop_rotation(unit)
    local rot = unit:rotation()
    return Rotation(rot:yaw(), 0, 0)
end

local function spawn_first_aid_kit(unit)
    FirstAidKitBase.spawn(
        drop_position(unit),
        drop_rotation(unit),
        0,
        0
    )
end

local function spawn_one_charge_doctor_bag(unit)
    local bag = DoctorBagBase.spawn(
        drop_position(unit),
        drop_rotation(unit),
        0,
        0
    )

    local bag_base = bag:base()
    local removed_charges = math.max(0, (bag_base._amount or 1) - 1)

    bag_base._amount = 1
    bag_base._max_amount = 1
    bag_base:_set_visual_stage()

    if removed_charges > 0 and managers.network:session() then
        managers.network:session():send_to_peers_synched(
            "sync_doctor_bag_taken",
            bag,
            removed_charges
        )
    end
end

local function spawn_one_grenade_crate(unit)
    local crate = GrenadeCrateDeployableBase.spawn(
        drop_position(unit),
        drop_rotation(unit)
    )

    local crate_base = crate:base()

    crate_base._special_enemy_drop = true

    crate_base._max_grenade_amount = 1
    crate_base._grenade_amount = 1
    crate_base._empty = false
    crate_base:_set_visual_stage()
end

Hooks:PostHook(CopDamage, "die", MOD_ID .. "_OnEnemyDeath", function(self, attack_data)
    -- Só o host cria drops.
    if not Network:is_server() then
        return
    end

    if self._special_enemy_drops_done then
        return
    end
    self._special_enemy_drops_done = true

    if self._converted then
        return
    end

    local unit = self._unit
    local base = alive(unit) and unit:base()
    local enemy_id = base and base._tweak_table

    if not enemy_id then
        return
    end

    -- Medic: 15% chance to drop FAKs;
    if enemy_id == "medic" then
        if math.random(100) <= 15 then
            spawn_first_aid_kit(unit)
        end

        return
    end

    -- Medic Bulldozer: 25% chance to drop a Doctor Bag;
    if enemy_id == "tank_medic" then
        if math.random(100) <= 25 then
            spawn_one_charge_doctor_bag(unit)
        end

    -- Mini Bulldozer: 25% chance to drop a Grenade Crate;
    elseif enemy_id == "tank_mini" then
        if math.random(100) <= 25 then
            spawn_one_grenade_crate(unit)
        end 
    end

    -- Any other Bulldozer variant receives the ammo drop buff chance;
    -- Includes tank, tank_green, tank_skull, tank_medic, tank_mini etc.
    local is_dozer = enemy_id == "piggydozer"
        or enemy_id == "tank"
        or enemy_id:find("^tank_") ~= nil

    local is_other_ammo_special = AMMO_ENEMIES[enemy_id] == true

    if not is_dozer and not is_other_ammo_special then
        return
    end

    -- Balancing:
    -- 30%: no additional boxes at all;
    -- 60%: one additional box;
    -- 10%: two additional boxes.
    local roll = math.random(100)
local extra_amount

if is_dozer then
    -- 60%: one additional box; 40%: two additional boxes.
    if roll <= 60 then
        extra_amount = 1
    else
        extra_amount = 2
    end
else
    -- Other Specials;
    -- 30%: no additional boxes; 60%: one additional box; 10%: two additional boxes.
    if roll <= 30 then
        extra_amount = 0
    elseif roll <= 90 then
        extra_amount = 1
    else
        extra_amount = 2
    end
end

    if extra_amount == 0 then
        return
    end

    spawn_extra_ammo(unit, extra_amount)

    local position = unit:position()
    local message = string.format(
        "%f;%f;%f;%d",
        position.x,
        position.y,
        position.z,
        extra_amount
    )

    LuaNetworking:SendToPeers(MOD_ID .. "_AmmoDrops", message)
end)