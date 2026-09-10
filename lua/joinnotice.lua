
local message = "Host is running mod Special Enemies Drop Special Loot. Dozers and Medics have a chance to drop resources."
local READY_DELAY = 3
local CHECK_INTERVAL = 0.5

Hooks:PostHook(BaseNetworkSession, "update", "SpecialEnemyDrops_JoinNotice", function(self)
    if not Network:is_server() or not self:local_peer() then
        return
    end
    local now = TimerManager:wall():time()
    if self._special_drops_notice_check and now < self._special_drops_notice_check then
        return
    end
    self._special_drops_notice_check = now + CHECK_INTERVAL

    for _, peer in pairs(self:peers()) do
        if peer:id() ~= self:local_peer():id() and not peer._special_drops_join_announced then
            local ready = peer:ip_verified() and not peer:loading()
                and (peer:in_lobby() or peer:synched())
            if not ready then
                peer._special_drops_notice_ready_at = nil
            elseif not peer._special_drops_notice_ready_at then
                peer._special_drops_notice_ready_at = now + READY_DELAY
            elseif now >= peer._special_drops_notice_ready_at then
                peer:send("send_chat_message", ChatManager.GAME, message)
                peer._special_drops_join_announced = true
                peer._special_drops_notice_ready_at = nil
                log("[Special Enemy Drops] Join notice sent to peer " .. tostring(peer:id()))
            end
        end
    end
end)
