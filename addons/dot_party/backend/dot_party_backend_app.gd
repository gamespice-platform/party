class_name GSPartyBackendApp
extends GSPartyBackend

## website-city, as the signed-in player.
##
## [b]Speaks routes added to the site for this addon.[/b] The site's parties are complete —
## membership, invites, the ready round, reservations — but only through tRPC behind the
## website's session cookie, which a game client does not have. A game client holds an
## app token from GameSpice Auth's device grant, and [code]/api/app/v1[/code] has no party routes
## until these. The routes this calls are listed in [code]docs/backbone-contract.md[/code]:
## each one is a thin wrapper over a function website-city already has
## ([code]JoinParty[/code], [code]LeaveParty[/code], [code]SetPartyReady[/code],
## [code]ReserveServerForParty[/code]…), with the site's own input names, so the site half
## is plumbing rather than design. Against a site without them, every call fails with a 404
## that says so.
##
## [b]The app API's envelope, not the integration API's.[/b] [code]{ok: true, data}[/code]
## on success and [code]{ok: false, code, message, retryAfter}[/code] on failure, as
## [code]src/types/app-api/contract.ts[/code] defines it. The site's refusal key
## (a [code]party.join.deny.*[/code]) arrives as [code]code[/code] and lands in
## [member GSError.detail], where every other backend puts it.
##
## [b]Neither GameSpice Auth nor its client is named.[/b] Give it [member client] — any object
## with [code]post_app(path, body)[/code] and [code]get_app(path, query)[/code], which is
## GameSpice Auth's [code]GSAuthClient[/code] — and the token, its refresh and the envelope are
## all handled there, once, for every addon that speaks the app API. [member token_fn]
## with a [GSHttp] is the fallback for a game without GameSpice Auth.

const CHANNEL := "party.app"

## Anything with [code]post_app(path, body)[/code] and [code]get_app(path, query)[/code]
## returning the envelope's data. Preferred over [member token_fn] when set.
var client: Object = null

## Where [code]/api/app/v1[/code] is, e.g. [code]https://tmc.example/api/app/v1[/code].
var api_base: String = ""

## [code]func() -> String[/code]: the current access token.
var token_fn: Callable = Callable()

## Does the requests. Needs to be in the tree; a game adds it once.
var http: GSHttp = null

## [code]func(method: String, path: String, body: Dictionary) -> GSResult[/code], replacing
## the HTTP call entirely. The suite uses it; so can a game with its own transport.
var request_fn: Callable = Callable()


func _init(p_api_base: String = "", p_http: GSHttp = null, p_token_fn: Callable = Callable()) -> void:
	api_base = p_api_base
	http = p_http
	token_fn = p_token_fn


func mine() -> GSResult:
	var res := await _call("GET", "party/mine")
	if not res.ok:
		return res
	var data: Variant = res.value
	if data == null or (data is Dictionary and (data as Dictionary).get("party") == null and not (data as Dictionary).has("id")):
		return GSResult.success(null)
	return GSParty.from_dict(data as Dictionary)


func fetch(party_id: String) -> GSResult:
	if not GSParty.is_id(party_id):
		return GSResult.fail(GSError.CODE_INVALID, "That is not a party id.", party_id)
	var res := await _call("GET", "party/%s" % party_id)
	if not res.ok:
		return res
	return GSParty.from_dict(res.value as Dictionary)


func create(options: Dictionary) -> GSResult:
	var res := await _call("POST", "party/create", options)
	if not res.ok:
		return res
	return GSParty.from_dict(res.value as Dictionary)


func join(party_id: String, password: String = "", token: String = "") -> GSResult:
	var body := {"id": party_id}
	if password != "":
		body["password"] = password
	if token != "":
		body["token"] = token
	return await _call("POST", "party/join", body)


func leave(party_id: String) -> GSResult:
	return await _call("POST", "party/leave", {"id": party_id})


func heartbeat(party_id: String) -> GSResult:
	return await _call("POST", "party/heartbeat", {"id": party_id})


func kick(party_id: String, user_id: String, ban: bool = false) -> GSResult:
	return await _call("POST", "party/kick", {"id": party_id, "userId": user_id, "ban": ban})


func set_role(party_id: String, user_id: String, role: GSPartyMember.Role) -> GSResult:
	# Refused here, as [GSPartyLocalHub] refuses it: the site's `party/role` takes CO_HOST
	# or MEMBER only (`src/types/party/member.ts`), so HOST reached it as a bare 400 that
	# said nothing about what to do instead.
	if role == GSPartyMember.Role.HOST:
		return GSResult.fail(
			GSError.CODE_INVALID, "Hand the party over instead.", "party.role.deny.host"
		)
	return await _call("POST", "party/role", {
		"id": party_id, "userId": user_id, "role": GSPartyMember.ROLE_NAMES[role],
	})


func transfer_host(party_id: String, user_id: String) -> GSResult:
	return await _call("POST", "party/transfer", {"id": party_id, "userId": user_id})


func invite(party_id: String, user_ids: PackedStringArray, message: String = "") -> GSResult:
	if user_ids.size() > GSPartyLocalHub.INVITE_BATCH_MAX:
		return GSResult.fail(GSError.CODE_INVALID, "At most 25 people at once.", "party.invite.deny.batch")
	var body := {"id": party_id, "userIds": Array(user_ids)}
	if message != "":
		body["message"] = message
	return await _call("POST", "party/invite", body)


func invites() -> GSResult:
	return await _call("GET", "party/invites")


func respond_invite(invite_id: String, accept: bool) -> GSResult:
	return await _call("POST", "party/invite/respond", {"inviteId": invite_id, "accept": accept})


func start(party_id: String, server_id: int = 0) -> GSResult:
	var body := {"id": party_id}
	if server_id > 0:
		body["serverId"] = server_id
	return await _call("POST", "party/start", body)


func ready_state(party_id: String) -> GSResult:
	var res := await _call("GET", "party/%s/ready" % party_id)
	if not res.ok:
		return res
	return GSResult.success(GSPartyReady.from_dict(res.value as Dictionary))


func set_ready(party_id: String, ready: bool = true) -> GSResult:
	return await _call("POST", "party/ready", {"id": party_id, "ready": ready})


func connected(party_id: String) -> GSResult:
	return await _call("POST", "party/connected", {"id": party_id})


func force_start(party_id: String) -> GSResult:
	return await _call("POST", "party/force-start", {"id": party_id})


func cancel_ready(party_id: String) -> GSResult:
	return await _call("POST", "party/cancel", {"id": party_id})


func end(party_id: String) -> GSResult:
	return await _call("POST", "party/end", {"id": party_id})


func reservation_offer(party_id: String, server_id: int) -> GSResult:
	return await _call("GET", "party/%s/reserve/offer" % party_id, {}, {"serverId": server_id})


func reserve(party_id: String, server_id: int, minutes: int, private: bool = false) -> GSResult:
	var res := await _call("POST", "party/reserve", {
		"partyId": party_id, "serverId": server_id, "minutes": minutes, "private": private,
	})
	if not res.ok:
		return res
	return GSPartyReservation.from_dict(res.value as Dictionary)


func cancel_reservation(reservation_id: String) -> GSResult:
	return await _call("POST", "party/reserve/cancel", {"reservationId": reservation_id})


func describe() -> String:
	return "website-city at %s" % api_base


## Whether the last request failed at the SERVICE rather than being refused by it, so
## an outage is logged on its edges: the client heartbeats, and a WARN per beat while the
## site is down would bury the line that says when it went.
var _failing: bool = false

## Codes the site uses to say no. Those are the rules working -- the player is told --
## and are not the service failing.
const _REFUSALS := [
	GSError.CODE_CONFLICT, GSError.CODE_AUTH, GSError.CODE_RATE_LIMITED,
	GSError.CODE_INVALID, GSError.CODE_FORBIDDEN,
]


## One request, unwrapped from the app API's envelope. Value: the envelope's [code]data[/code].
##
## Logged here because every call in this class passes through it. A refusal is DEBUG;
## the service failing -- the network, a 5xx, an answer that is not an envelope, a site
## with no party routes -- is WARN when it starts, DEBUG while it lasts and INFO when a
## call succeeds again. WARN rather than ERROR: parties are an extra on top of playing,
## and a player without one can still play.
func _call(method: String, path: String, body: Dictionary = {}, query: Dictionary = {}) -> GSResult:
	var res := await _call_inner(method, path, body, query)

	if res.ok:
		if _failing:
			_failing = false
			GSLog.info(CHANNEL, "the party service is answering again", {"api": api_base})
		return res

	var fields := {
		"call": "%s %s" % [method, path],
		"code": res.code(),
		"error": res.error.message if res.error != null else "",
		"site_code": res.error.detail if res.error != null else "",
	}

	if res.code() in _REFUSALS:
		GSLog.debug(CHANNEL, "the party service refused", fields)
	elif _failing:
		GSLog.debug(CHANNEL, "the party service is still failing", fields)
	else:
		_failing = true
		fields["api"] = api_base
		GSLog.warn(CHANNEL, "the party service is failing", fields)

	return res


func _call_inner(method: String, path: String, body: Dictionary = {}, query: Dictionary = {}) -> GSResult:
	if request_fn.is_valid() or client == null:
		var full := path
		if not query.is_empty():
			var parts := PackedStringArray()
			for k in query:
				parts.append("%s=%s" % [str(k).uri_encode(), str(query[k]).uri_encode()])
			full += "?" + "&".join(parts)
		var raw: GSResult = null
		if request_fn.is_valid():
			raw = await request_fn.call(method, full, body)
		else:
			raw = await _http_call(method, full, body)
		if not raw.ok:
			return _explain(raw)
		if not (raw.value is Dictionary):
			return GSResult.fail(GSError.CODE_PARSE, "The party service answered with something that is not an object.")
		var env: Dictionary = raw.value
		if env.get("ok") == false:
			return _refusal(env, 0)
		return GSResult.success(env.get("data"))

	# Through GameSpice Auth: the envelope is already unwrapped, and a refusal's site code is
	# already in the error's detail.
	var res: GSResult = null
	if method == "GET":
		res = await client.call("get_app", path, query)
	else:
		res = await client.call("post_app", path, body)
	if not res.ok and res.error != null and res.error.http_status == 404 and res.error.detail == "":
		return _no_routes(res)
	return res


func _http_call(method: String, path: String, body: Dictionary) -> GSResult:
	if http == null:
		return GSResult.fail(GSError.CODE_STATE, "no HTTP client")
	if not token_fn.is_valid():
		return GSResult.fail(GSError.CODE_AUTH, "Sign in to use parties.")
	var token := str(token_fn.call())
	if token == "":
		return GSResult.fail(GSError.CODE_AUTH, "Sign in to use parties.")
	var url := api_base.trim_suffix("/") + "/" + path
	var headers := {"Authorization": "Bearer %s" % token}
	if method == "GET":
		return await http.get_json(url, headers)
	return await http.post_json(url, body, headers)


## A non-2xx carries the envelope in its body; lift the site's code and message out of it.
func _explain(raw: GSResult) -> GSResult:
	var e := raw.error
	if e == null:
		return raw
	var parsed: Variant = _envelope_of(e.detail)
	if parsed is Dictionary:
		return _refusal(parsed as Dictionary, e.http_status, e.code)
	if e.http_status == 404:
		return _no_routes(raw)
	return raw


func _refusal(env: Dictionary, status: int, fallback_code: String = GSError.CODE_CONFLICT) -> GSResult:
	var site_code := str(env.get("code", ""))
	var message := str(env.get("message", "The party service refused."))
	var code := fallback_code
	if status == 0:
		code = GSError.CODE_CONFLICT
		if site_code == "unauthorized" or site_code == "wrong_credential":
			code = GSError.CODE_AUTH
		elif site_code.begins_with("rate"):
			code = GSError.CODE_RATE_LIMITED
	var err := GSError.make(code, message, site_code)
	err.http_status = status
	if env.get("retryAfter") != null:
		err.retry_after = float(env["retryAfter"])
	return GSResult.failure(err)


## A 404 from a site without the party routes, with [member GSError.detail] left EMPTY.
##
## Not [method GSResult.wrap]: that puts the wrapped error's text in [code]detail[/code],
## which is the field every backend here reserves for the site's refusal key, so a caller
## rendering the key got "[invalid] Not found." instead of nothing to render.
static func _no_routes(res: GSResult) -> GSResult:
	var err := GSError.make(
		res.error.code if res.error != null else GSError.CODE_INVALID,
		"the site has no app party routes yet; see dot-party's docs/backbone-contract.md"
	)
	if res.error != null:
		err.http_status = res.error.http_status
	return GSResult.failure(err)

## A refusal's body as a Dictionary, or null — without the engine's own ERROR line.
##
## The detail is only ever an envelope when it is a JSON object. A transport failure
## ("engine error 3") and a proxy's HTML error page are text, and [code]JSON.parse_string[/code]
## prints an unsuppressible ERROR for each before answering null — found by driving the
## backend at a live site whose request failed before it was sent.
static func _envelope_of(detail: String) -> Variant:
	if not detail.strip_edges().begins_with("{"):
		return null
	var json := JSON.new()
	if json.parse(detail) != OK:
		return null
	return json.data
