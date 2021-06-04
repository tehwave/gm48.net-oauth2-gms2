/* --------------------------------

Library of scripts to utilize gm48.net OAuth2 in GameMaker Studio 2 v2.3.0 or newer

@see https://github.com/tehwave/gm48.net-oauth2-gms2

-------------------------------- */

function gm48_oauth2_init(clientId, clientSecret)
{
	// Prepare our variables.
    gm48_oauth2_enums();
    gm48_oauth2_macros();
    gm48_oauth2_globals();

	// Set the Client ID and Secret.
    if (argument_count == 0) {
        show_error("gm48.net-oauth2-gms2: The Client ID and Client Secret arguments must be filled", true);
    }

    global.gm48_oauth2_client_id = clientId;
    global.gm48_oauth2_client_secret = clientSecret;

	// All ready.
	gm48_debug("OAuth2 functionality initialized.");
}

function gm48_oauth2_enums()
{
    enum GM48_OAUTH2_STATE
    {
        INITIALISED,
        AUTHORIZATION_PENDING,
        EXCHANGING_AUTH_CODE,
        ACCESS_TOKEN_RECEIVED,
        REFRESHING_ACCESS_TOKEN,
        OPERATION_PENDING,
    }
}

function gm48_oauth2_macros()
{
    #macro GM48_OAUTH2_LOCALHOST_PORT 8888
    #macro GM48_OAUTH2_LOCALHOST_TIMEOUT (10*60*1000) // (ms)
    #macro GM48_OAUTH2_LOCALHOST_URL "http://localhost:" + string(GM48_OAUTH2_LOCALHOST_PORT) + "/"

    #macro GM48_OAUTH2_USERAGENT "gamemaker:" + game_display_name + ":" + GM_version

	#macro GM48_OAUTH2_API_URL "https://gm48.net/oauth/"
    #macro GM48_OAUTH2_API_URL_TOKEN GM48_OAUTH2_API_URL + "token"
	#macro GM48_OAUTH2_API_URL_AUTHORIZE GM48_OAUTH2_API_URL + "authorize"
    #macro GM48_OAUTH2_API_URL_AUTHORIZED GM48_OAUTH2_API_URL + "authorized"

    #macro GM48_OAUTH2_DEFAULT_SCOPES "me leaderboards"
}

function gm48_oauth2_globals()
{
    global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
    global.gm48_oauth2_callback = -1;
    global.gm48_oauth2_localhost_server = -1;
    global.gm48_oauth2_scope = "";
    global.gm48_oauth2_nonce = -1;

	global.gm48_oauth2_requests = ds_map_create();
}

function gm48_oauth2_keepalive()
{
    // To avoid exposing the Client ID and Secret in the error panel,
    // we do our check here even if it is worse for performance.
    if (! code_is_compiled() && ! debug_mode) {
        show_error("gm48.net-oauth2-gms2: You must compile your game using YYC (YoYo Compiler) as otherwise the sensitive Client ID and Client Secret values can be reverse-engineered and extracted from your game's executable file.", true);
    }

    switch(global.gm48_oauth2_state)
    {
        case GM48_OAUTH2_STATE.AUTHORIZATION_PENDING:
        case GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE:
            if (current_time > global.gm48_oauth2_expires) {
                gm48_debug("Authorization flow expired");

                gm48_oauth2_reset();
            }
        break;

        case GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED:
            if (current_time > global.gm48_oauth2_expires) {
                if (is_undefined(global.gm48_oauth2_refresh_token)) {
                    gm48_debug("Access token has expired.");

                    gm48_oauth2_reset();
                } else {
                    gm48_oauth2_refresh_access_token();
                }
            }
        break;

        case GM48_OAUTH2_STATE.OPERATION_PENDING:
        break;
    }
}

function gm48_oauth2_reset()
{
	// Clean up.
    gm48_oauth2_localhost_destroy();

	// Reset values.
    global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
    global.gm48_oauth2_expires = undefined;
    global.gm48_oauth2_nonce = undefined;

	// Execute the callback.
    var _map = ds_map_create();
    script_execute(global.gm48_oauth2_callback, _map);
    ds_map_destroy(_map);
	global.gm48_oauth2_callback = undefined;
}

/* --------------------------------

Authorization.

-------------------------------- */

function gm48_oauth2_authorize(callback, scope)
{
	// Validate.
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.INITIALISED) {
        show_error("gm48.net-oauth2-gms2: Cannot request access token again", true);
    }

    if (! global.gm48_oauth2_localhost_create()) {
        show_error("gm48.net-oauth2-gms2: Localhost server could not be created", true);
    }

	// Prepare the URL.
	global.gm48_oauth2_scope = GM48_OAUTH2_DEFAULT_SCOPES;

	if (! is_undefined(scope)) {
		global.gm48_oauth2_scope = scope;
	}

    global.gm48_oauth2_nonce = gm48_nonce();

    var authorizeUrl  = GM48_OAUTH2_API_URL_AUTHORIZE;
    authorizeUrl += "?client_id=" + global.gm48_oauth2_client_id;
    authorizeUrl += "&redirect_uri=" + GM48_OAUTH2_LOCALHOST_URL;
    authorizeUrl += "&response_type=code";
    authorizeUrl += "&scope=" + global.gm48_oauth2_scope;
    authorizeUrl += "&state=" + global.gm48_oauth2_nonce;

	// Open the URL in the player's default browser.
    url_open(authorizeUrl);

	// Prepare for the response.
	global.gm48_oauth2_callback = undefined;

	if (! is_undefined(callback)) {
		global.gm48_oauth2_callback = callback;
	}

    global.gm48_oauth2_state = GM48_OAUTH2_STATE.AUTHORIZATION_PENDING;
    global.gm48_oauth2_expires = current_time + GM48_OAUTH2_LOCALHOST_TIMEOUT;
}

function gm48_oauth2_exchange_auth_code()
{
	// Sanity check.
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.AUTHORIZATION_PENDING) {
        show_error("gm48.net-oauth2-gms2: Cannot exchange authorization code at this time", true);
    }

    gm48_debug("Exchanging authorization code for access token");

	// Prepare our request.
    var headers = ds_map_create();
    headers[? "User-Agent"] = GM48_OAUTH2_USERAGENT;
    headers[? "Content-Type"] = "application/x-www-form-urlencoded";
	headers[? "Accept"] = "application/json";

    var body  = "grant_type=authorization_code";
    body += "&client_id=" + global.gm48_oauth2_client_id;
    body += "&client_secret=" + global.gm48_oauth2_client_secret;
    body += "&redirect_uri=" + GM48_OAUTH2_LOCALHOST_URL;
    body += "&code=" + global.gm48_oauth2_auth_code;

	// Send the request.
    var requestId = http_request(GM48_OAUTH2_API_URL_TOKEN, "POST", headers, body);

	// Save the request.
	var request = ds_map_create();
	request[? "url"] = GM48_OAUTH2_API_URL_TOKEN;
	request[? "headers"] = headers;
	request[? "body"] = body;
	request[? "method"] = "POST";

	gm48_add_oauth2_request(requestId, request);

	// Update our step in the process.
    global.gm48_oauth2_state = GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE;

	// Free memory.
    ds_map_destroy(headers);

	// All done here.
	return requestId;
}

function gm48_oauth2_refresh_access_token()
{
	// Sanity check.
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED) {
        show_error("gm48.net-oauth2-gms2: Cannot refresh access token right now", true);
    }

	gm48_debug("Refreshing access token");

	// Prepare our request.
    var headers = ds_map_create();
    headers[? "User-Agent"] = GM48_OAUTH2_USERAGENT;
    headers[? "Content-Type"] = "application/x-www-form-urlencoded";
	headers[? "Accept"] = "application/json";

    var body  = "grant_type=refresh_token";
    body += "&refresh_token=" + global.gm48_oauth2_refresh_token;
    body += "&client_id=" + global.gm48_oauth2_client_id;
    body += "&client_secret=" + global.gm48_oauth2_client_secret;
    body += "&scope=" + global.gm48_oauth2_scope;

	// Send the request.
    var requestId = http_request(GM48_OAUTH2_API_URL_TOKEN, "POST", headers, body);

	// Save the request.
	var request = ds_map_create();
	request[? "url"] = GM48_OAUTH2_API_URL_TOKEN;
	request[? "headers"] = headers;
	request[? "body"] = body;
	request[? "method"] = "POST";

	gm48_add_oauth2_request(requestId, request);

	// Update our step in the process.
    global.gm48_oauth2_state = GM48_OAUTH2_STATE.REFRESHING_ACCESS_TOKEN;
    global.gm48_oauth2_callback = undefined;

	// Free memory.
    ds_map_destroy(headers);

	// All done here.
    return requestId;
}

function gm48_oauth2_authenticated_user()
{
    // TODO
}

/* --------------------------------

Localhost server.

-------------------------------- */

function gm48_oauth2_localhost_create()
{
	// Create server if it doesn't exist.
    if (global.gm48_oauth2_localhost_server < 0) {
        global.gm48_oauth2_localhost_server = network_create_server_raw(network_socket_tcp, GM48_OAUTH2_LOCALHOST_PORT, 10);
    }

    // Still no server??
    if (global.gm48_oauth2_localhost_server < 0) {
        gm48_debug("Failed to create raw TCP server on port " + string(GM48_OAUTH2_LOCALHOST_PORT));

        return false;
    }

    gm48_debug("Created server " + string(global.gm48_oauth2_localhost_server) + " on port " + string(GM48_OAUTH2_LOCALHOST_PORT));

    return true;
}

function gm48_oauth2_localhost_destroy()
{
    if (global.gm48_oauth2_localhost_server >= 0) {
        gm48_debug("Destroying server");

        network_destroy(global.gm48_oauth2_localhost_server);
        global.gm48_oauth2_localhost_server = undefined;
    }
}

function gm48_oauth2_http()
{
	// Validate that the request is one of ours.
	var requestId = async_load[? "id"];

	if (! ds_exists(global.gm48_oauth2_requests, ds_type_map)) {
		show_error("gm48.net-oauth2-gms2: Requests ds_map doesn't exist.", true);
	}

	if (ds_map_size(global.gm48_oauth2_requests) == 0) {
		gm48_debug("HTTP request is not of OAuth2 variant.", requestId);

		return;
	}

	var request = gm48_get_oauth2_request(requestId);

	if (is_undefined(request)) {
		gm48_debug("HTTP request is not of OAuth2 variant.", requestId);

		return;
	}

	// Retrieve our remaining data.
	var httpStatus = async_load[? "http_status"];
    var requestStatus = async_load[? "status"];
    var result = async_load[? "result"];

	// Validate response.
	if (requestStatus < 0) {
		gm48_debug("Something went wrong with request.", httpStatus, requestStatus, result);

		return;
	}

	if (requestStatus = 1) {
		gm48_debug("Content is being downloaded.", httpStatus, requestStatus, result);

		return;
	}

	// Process result.
    var decodedResult = json_parse(result);

	gm48_debug("Successful response received.", httpStatus, result, decodedResult);

	// Restart the process when unsuccessful response.
	if (httpStatus < 200 || httpStatus >= 300) {
		gm48_debug("Non-successful response.", httpStatus, requestStatus, result);

		// Restart the process.
        if (global.gm48_oauth2_state == GM48_OAUTH2_STATE.OPERATION_PENDING) {
            global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
        } else {
            global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
        }

		// Execute callbacks.
		if (! is_undefined(request[? "callback"]) && script_exists(request[? "callback"])) {
			script_execute(request[? "callback"], {}, requestId);
		}

		if (! is_undefined(global.gm48_oauth2_callback) && script_exists(global.gm48_oauth2_callback)) {
			script_execute(global.gm48_oauth2_callback, {}, requestId);
		}

        // Clean up.
        gm48_oauth2_localhost_destroy();

		return;
	}

    switch(global.gm48_oauth2_state)
    {
        case GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE:
            global.gm48_oauth2_auth_code     = "";
            global.gm48_oauth2_access_token  = decodedResult.access_token;
            global.gm48_oauth2_token_type    = decodedResult.token_type;
            global.gm48_oauth2_expires       = current_time + 900 * decodedResult.expires_in; // Convert seconds to milliseconds, and expire a bit early.
            global.gm48_oauth2_refresh_token = decodedResult.refresh_token;

            gm48_debug("Received access token \"", global.gm48_oauth2_access_token, "\", expires ", global.gm48_oauth2_expires);
            gm48_debug("Ready to make requests!");

            global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
        break;

        case GM48_OAUTH2_STATE.REFRESHING_ACCESS_TOKEN:
            global.gm48_oauth2_access_token = decodedResult.access_token;
            global.gm48_oauth2_token_type   = decodedResult.token_type;
            global.gm48_oauth2_expires      = current_time + 900 * decodedResult.expires_in; // Convert seconds to milliseconds, and expire a bit early.

            gm48_debug("Received refreshed access token \"", global.gm48_oauth2_access_token, "\", expires ", global.gm48_oauth2_expires);
            gm48_debug("Ready to make requests!");

            global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
        break;

        case GM48_OAUTH2_STATE.OPERATION_PENDING:
            gm48_debug("Operation complete");

            global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
        break;

        default:
            gm48_debug("Warning: Unexpected Async HTTP event received");
        break;
    }

	// Execute callbacks.
	if (! is_undefined(request[? "callback"]) && script_exists(request[? "callback"])) {
		script_execute(request[? "callback"], decodedResult, requestId);
	}

	if (! is_undefined(global.gm48_oauth2_callback) && script_exists(global.gm48_oauth2_callback)) {
		script_execute(global.gm48_oauth2_callback, decodedResult, requestId);
	}
}

function gm48_oauth2_networking()
{
    switch(async_load[? "type"]) {
        case network_type_connect:
            global.gm48_oauth2_out_socket = async_load[? "socket"];

            gm48_debug("New connection on socket ", global.gm48_oauth2_out_socket);
        break;

        case network_type_data:
            var buffer = async_load[? "buffer"];

            if (is_undefined(buffer)) {
				return;
			}

            var bufferString = buffer_read(buffer, buffer_string);

			// TODO Refactor how we are parsing the nonce and code from the buffer.
            var _params = gmlscriptsdotscom_string_parse(bufferString, "&", false);

			// Validate nonce.
            var _almost_clean_nonce = string_delete(ds_list_find_value(_params, 1), 1, 6);
            var nonce = gmlscriptsdotscom_string_trim(string_copy(string_delete(_almost_clean_nonce, string_pos(" HTTP/1.1", _almost_clean_nonce), 9), 0, 64));

            // gm48_debug("nonce", _nonce, global.gm48_oauth2_nonce, bufferString);

            if (nonce != global.gm48_oauth2_nonce) {
                show_error("gm48.net-oauth2-gms2: Security failsafe triggered", true);
            }

			// Exchange the auth code for access token.
            global.gm48_oauth2_auth_code = string_delete(ds_list_find_value(_params, 0), 1, 11);

            gm48_debug("Received authorization code", global.gm48_oauth2_auth_code);

            gm48_oauth2_exchange_auth_code();

			// Redirect the browser.
            if (global.gm48_oauth2_localhost_server >= 0) {
                gm48_debug("Sending raw HTTP response");

                var bufferValue = "HTTP/1.1 301 Moved Permanently\nLocation: " + GM48_OAUTH2_API_URL_AUTHORIZED + "\n\n";

                var bufferOut = buffer_create(string_byte_length(bufferValue) + 1, buffer_fixed, 1);
                buffer_write(bufferOut, buffer_string, bufferValue);

                network_send_raw(global.gm48_oauth2_out_socket, bufferOut, buffer_get_size(bufferOut));
                buffer_delete(bufferOut);
            }

			// All done, so clean up!
			ds_list_destroy(_params);
            gm48_oauth2_localhost_destroy();
        break;
    }
}

/* --------------------------------

Global helper scripts.

-------------------------------- */

function gm48_debug()
{
    if (! debug_mode) {
        return -1
    }

    if (argument_count == 1) {
        show_debug_message("gm48: " + string(argument0));

        return;
    }

    var _string = "",
        _i = 0;

    repeat(argument_count) {
        _string += "(" + string(_i) + ") " + string(argument[_i]) + "\n";

        ++_i;
    }

    show_debug_message("gm48:\n" + _string);
}

function gm48_get_game_api_token()
{
    return global.gm48_game_api_token;
}

function gm48_set_game_api_token(apiToken)
{
    global.gm48_game_api_token = string(apiToken);
}

function gm48_isset_game_api_token()
{
    return is_string(global.gm48_game_api_token);
}

function gm48_get_oauth2_access_token()
{
    return global.gm48_oauth2_access_token;
}

function gm48_set_oauth2_access_token(accessToken)
{
    global.gm48_oauth2_access_token = string(accessToken);
}

function gm48_isset_oauth2_access_token()
{
    return is_string(global.gm48_oauth2_access_token);
}

/* --------------------------------

Local helper scripts.

-------------------------------- */

function gm48_add_oauth2_request(requestId, request)
{
    return ds_map_add(global.gm48_oauth2_requests, requestId, request);
}

function gm48_get_oauth2_request(requestId)
{
    return ds_map_find_value(global.gm48_oauth2_requests, requestId);
}

function gm48_string_random(length)
{
    var charset,
        result,
        charsetLength;

    result = "";

    charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    charsetLength = string_length(charset);

    repeat (charsetLength) {
        result += string_char_at(charset, floor(random(charsetLength)) + 1);
    }

    return result;
}

function gm48_nonce()
{
    return gm48_string_random(64);
}

/// string_parse(str,token,ignore)
//
//  Returns a ds_list containing all substring elements within
//  a given string which are separated by a given token.
//
//  eg. string_parse("cat|dog|house|bee", "|", true)
//      returns a ds_list { "cat", "dog", "house", "bee" }
//
//      str         elements, string
//      token       element separator,  string
//      ignore      ignore empty substrings, bool
//
/// GMLscripts.com/license
function gmlscriptsdotscom_string_parse()
{
    var str,token,ignore,list,tlen,temp;
    str = argument0;
    token = argument1;
    ignore = argument2;
    list = ds_list_create();
    tlen = string_length( token);
    while (string_length(str) != 0) {
        temp = string_pos(token,str);
        if (temp) {
            if (temp != 1 || !ignore) ds_list_add(list,string_copy(str,1,temp-1));
            str = string_copy(str,temp+tlen,string_length(str));
        } else {
            ds_list_add(list,str);
            str = "";
        }
    }
    return list;
}

/// string_trim(str)
//
//  Returns the given string with whitespace stripped from its start
//  and end. Whitespace is defined as SPACE, HT, LF, VT, FF, CR.
//
//      str         text, string
//
/// GMLscripts.com/license
function gmlscriptsdotscom_string_trim()
{
    var str,l,r,o;
    str = argument0;
    l = 1;
    r = string_length(str);
    repeat (r) {
        o = ord(string_char_at(str,l));
        if ((o > 8) && (o < 14) || (o == 32)) l += 1;
        else break;
    }
    repeat (r-l) {
        o = ord(string_char_at(str,r));
        if ((o > 8) && (o < 14) || (o == 32)) r -= 1;
        else break;
    }
    return string_copy(str,l,r-l+1);
}
