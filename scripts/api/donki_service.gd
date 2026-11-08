
extends Node

signal events_received(events: Array)
signal request_failed(message: String)

const DONKI_ENDPOINT = "https://ccmc.gsfc.nasa.gov/DONKI-API"

var http: HTTPRequest


func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)


func fetch_cme_events(start_date: String, end_date: String) -> void:
	var url = DONKI_ENDPOINT + "/CME"

	var query = "?startDate=" + start_date.uri_encode()
	query += "&endDate=" + end_date.uri_encode()

	url += query

	var error = http.request(url)

	if error != OK:
		request_failed.emit("Could not start HTTP request.")


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("Network request failed.")
		return

	if response_code != 200:
		request_failed.emit("DONKI returned HTTP " + str(response_code))
		print(body.get_string_from_utf8())
		return

	var parser = JSON.new()
	var parse_error = parser.parse(body.get_string_from_utf8())

	if parse_error != OK:
		request_failed.emit("Could not parse the JSON response.")
		return

	if not parser.data is Array:
		request_failed.emit("Expected an array of CME events.")
		return

	events_received.emit(parser.data)
