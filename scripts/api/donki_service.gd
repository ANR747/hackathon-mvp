extends Node

# Backwards-compatible signals: existing CME callers can keep listening to
# events_received and request_failed.
signal events_received(events: Array)
signal request_failed(message: String)

# Event-specific and generic signals for newer integrations.
signal cme_events_received(events: Array)
signal rbe_events_received(events: Array)
signal events_received_for_type(event_type: String, events: Array)
signal request_failed_for_type(event_type: String, message: String)

const DONKI_ENDPOINT := "https://api.nasa.gov/DONKI"
const REQUEST_TIMEOUT_SECONDS := 30.0
const DEFAULT_API_KEY := "DEMO_KEY"

# Set a personal NASA API key on the autoload singleton in the Inspector,
# or pass it to fetch_cme_events()/fetch_rbe_events().
@export var nasa_api_key: String = DEFAULT_API_KEY


func fetch_cme_events(
	start_date: String,
	end_date: String,
	api_key: String = ""
) -> void:
	_request_events("CME", start_date, end_date, api_key)


func fetch_rbe_events(
	start_date: String,
	end_date: String,
	api_key: String = ""
) -> void:
	_request_events("RBE", start_date, end_date, api_key)


func _request_events(
	event_type: String,
	start_date: String,
	end_date: String,
	api_key_override: String
) -> void:
	if event_type != "CME" and event_type != "RBE":
		_emit_request_failure(event_type, "Unsupported DONKI event type.")
		return

	if not _is_valid_date(start_date) or not _is_valid_date(end_date):
		_emit_request_failure(
			event_type,
			"Dates must use the YYYY-MM-DD format."
		)
		return

	if start_date > end_date:
		_emit_request_failure(
			event_type,
			"Start date must be earlier than or equal to end date."
		)
		return

	var key_to_use := api_key_override.strip_edges()
	if key_to_use.is_empty():
		key_to_use = nasa_api_key.strip_edges()
	if key_to_use.is_empty():
		key_to_use = DEFAULT_API_KEY

	var url := DONKI_ENDPOINT + "/" + event_type
	url += "?startDate=" + start_date.uri_encode()
	url += "&endDate=" + end_date.uri_encode()
	url += "&api_key=" + key_to_use.uri_encode()

	# Create one HTTPRequest per call. This permits CME and RBE requests to
	# overlap without one request overwriting the other's response handler.
	var http_request := HTTPRequest.new()
	http_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http_request)
	http_request.request_completed.connect(
		_on_request_completed.bind(event_type, http_request)
	)

	var error := http_request.request(url)
	if error != OK:
		http_request.queue_free()
		_emit_request_failure(
			event_type,
			"Could not start DONKI HTTP request (error %d)." % error
		)


func _is_valid_date(date_value: String) -> bool:
	if date_value.length() != 10:
		return false

	if date_value[4] != "-" or date_value[7] != "-":
		return false

	var year_text := date_value.substr(0, 4)
	var month_text := date_value.substr(5, 2)
	var day_text := date_value.substr(8, 2)

	return (
		year_text.is_valid_int()
		and month_text.is_valid_int()
		and day_text.is_valid_int()
		and int(year_text) > 0
		and int(month_text) >= 1
		and int(month_text) <= 12
		and int(day_text) >= 1
		and int(day_text) <= 31
	)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	event_type: String,
	http_request: HTTPRequest
) -> void:
	if is_instance_valid(http_request):
		http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_request_failure(
			event_type,
			"DONKI network request failed (result %d)." % result
		)
		return

	if response_code != 200:
		_emit_request_failure(
			event_type,
			"DONKI returned HTTP %d. Check the API key, date range, and rate limit." % response_code
		)
		return

	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	if parse_error != OK:
		_emit_request_failure(
			event_type,
			"Could not parse DONKI JSON (error %d)." % parse_error
		)
		return

	if not parser.data is Array:
		_emit_request_failure(
			event_type,
			"Expected DONKI to return an array of %s events." % event_type
		)
		return

	var events: Array = parser.data
	for event in events:
		if not event is Dictionary:
			_emit_request_failure(
				event_type,
				"DONKI returned an event with an unexpected data structure."
			)
			return

	events_received_for_type.emit(event_type, events)

	match event_type:
		"CME":
			cme_events_received.emit(events)
			# Preserve the original signal used by the existing project.
			events_received.emit(events)
		"RBE":
			rbe_events_received.emit(events)


func _emit_request_failure(event_type: String, message: String) -> void:
	request_failed_for_type.emit(event_type, message)
	# Preserve the original generic error signal for existing listeners.
	request_failed.emit(message)
