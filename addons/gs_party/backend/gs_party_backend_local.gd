class_name GSPartyBackendLocal
extends GSPartyBackend

## One person's view of a [GSPartyLocalHub]. Get one with [method GSPartyLocalHub.as_user].

var hub: GSPartyLocalHub = null
var user_id: String = ""


func _init(p_hub: GSPartyLocalHub = null, p_user_id: String = "") -> void:
	hub = p_hub
	user_id = p_user_id


func mine() -> GSResult:
	return hub.mine(user_id)


func fetch(party_id: String) -> GSResult:
	return hub.fetch(party_id)


func create(options: Dictionary) -> GSResult:
	return hub.create(user_id, options)


func join(party_id: String, password: String = "", token: String = "") -> GSResult:
	return hub.join(user_id, party_id, password, token)


func leave(party_id: String) -> GSResult:
	return hub.leave(user_id, party_id)


func heartbeat(party_id: String) -> GSResult:
	return hub.heartbeat(user_id, party_id)


func kick(party_id: String, target: String, ban: bool = false) -> GSResult:
	return hub.kick(user_id, party_id, target, ban)


func set_role(party_id: String, target: String, role: GSPartyMember.Role) -> GSResult:
	return hub.set_role(user_id, party_id, target, role)


func transfer_host(party_id: String, target: String) -> GSResult:
	return hub.transfer_host(user_id, party_id, target)


func invite(party_id: String, user_ids: PackedStringArray, message: String = "") -> GSResult:
	return hub.invite(user_id, party_id, user_ids, message)


func invites() -> GSResult:
	return hub.invites_for(user_id)


func respond_invite(invite_id: String, accept: bool) -> GSResult:
	return hub.respond_invite(user_id, invite_id, accept)


func start(party_id: String, server_id: int = 0) -> GSResult:
	return hub.start(user_id, party_id, server_id)


func ready_state(party_id: String) -> GSResult:
	return hub.ready_view(user_id, party_id)


func set_ready(party_id: String, ready: bool = true) -> GSResult:
	return hub.set_ready(user_id, party_id, ready)


func connected(party_id: String) -> GSResult:
	return hub.connected(user_id, party_id)


func force_start(party_id: String) -> GSResult:
	return hub.force_start(user_id, party_id)


func cancel_ready(party_id: String) -> GSResult:
	return hub.cancel_ready(user_id, party_id)


func end(party_id: String) -> GSResult:
	return hub.end(user_id, party_id)


func reservation_offer(party_id: String, server_id: int) -> GSResult:
	return hub.reservation_offer(party_id, server_id)


func reserve(party_id: String, server_id: int, minutes: int, private: bool = false) -> GSResult:
	return hub.reserve(user_id, party_id, server_id, minutes, private)


func cancel_reservation(reservation_id: String) -> GSResult:
	return hub.cancel_reservation(user_id, reservation_id)


func describe() -> String:
	return "local party hub, as %s" % user_id
