/* --------------------------------

Library of scripts to utilize gm48.net OAuth2 in GameMaker Studio 2 v2.3.0 or newer

@see https://github.com/tehwave/gm48.net-oauth2-gms2

-------------------------------- */

function gm48_oauth2_init(_client_id, _client_secret) {
    gm48_oauth2_enums();
    gm48_oauth2_macros();
    gm48_oauth2_globals();
    
    if (argument_count == 0) {
        show_error("gm48.net-oauth2-gms2: The Client ID and Client Secret arguments must be filled", true);
    }
    
    global.gm48_oauth2_client_id = _client_id;
    global.gm48_oauth2_client_secret = _client_secret;
}

function gm48_oauth2_enums() {
    enum GM48_OAUTH2_STATE
    {
        INITIALISED,
        AUTHORISATION_PENDING,
        EXCHANGING_AUTH_CODE,
        ACCESS_TOKEN_RECEIVED,
        REFRESHING_ACCESS_TOKEN,
        OPERATION_PENDING,
    }
}

function gm48_oauth2_macros() {
    #macro GM48_OAUTH2_LOCALHOST_PORT 8888
    #macro GM48_OAUTH2_LOCALHOST_TIMEOUT (10*60*1000) // (ms)
    #macro GM48_OAUTH2_LOCALHOST_URL "http://localhost:" + string(GM48_OAUTH2_LOCALHOST_PORT) + "/"
    
    #macro GM48_OAUTH2_USERAGENT "gamemaker:" + game_display_name + ":" + GM_version
    // gm48_oauth2_debug("User Agent " + GM48_OAUTH2_USERAGENT);
    
    #macro GM48_OAUTH2_URL_TOKEN "https://gm48.test/oauth/token/"
    #macro GM48_OAUTH2_URL_AUTHORIZE "https://gm48.test/oauth/authorize"
    #macro GM48_OAUTH2_URL_AUTHORIZED "https://gm48.test/oauth/authorized"
    
    #macro GM48_OAUTH2_DEFAULT_SCOPES "me leaderboards"
}

function gm48_oauth2_globals() {
    global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
    global.gm48_oauth2_access_token_received = false;
    global.gm48_oauth2_callback = -1;
    global.gm48_oauth2_localhost_server = -1;
    global.gm48_oauth2_scopes = "";
    global.gm48_oauth2_nonce = -1;
}

function gm48_oauth2_keepalive() {
    
    // To avoid exposing the Client ID and Secret in the error panel,
    // we do our check here even if it is worse for performance.
    if (! code_is_compiled() && ! debug_mode) {
        show_error("gm48.net-oauth2-gms2: You must compile your game using YYC (YoYo Compiler) as otherwise the sensitive Client ID and Client Secret values can be reverse-engineered and extracted from your game's executable file.", true);
    }
    
    switch(global.gm48_oauth2_state)
    {
        case GM48_OAUTH2_STATE.AUTHORISATION_PENDING:
        case GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE:
            if (current_time > global.gm48_oauth2_expires)
            {
                gm48_oauth2_debug("Authorization flow expired");
                gm48_oauth2_reset();
            }
        break;
    
        case GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED:
            if (current_time > global.gm48_oauth2_expires)
            {
                if (global.gm48_oauth2_refresh_token == undefined)
                {
                    gm48_oauth2_debug("Access token has expired.");
                    gm48_oauth2_reset();
                }
                else
                {
                    gm48_oauth2_refresh_access_token();
                }
            }
        break;
    
        case GM48_OAUTH2_STATE.OPERATION_PENDING:
        break;
    }
}

function gm48_oauth2_reset() {
    var _map = ds_map_create();
    script_execute(global.gm48_oauth2_callback, _map);
    ds_map_destroy(_map);

    gm48_oauth2_localhost_destroy();

    global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
    global.gm48_oauth2_callback = -1;
    global.gm48_oauth2_access_token_received = false;
    global.gm48_oauth2_expires = -1;
    global.gm48_oauth2_nonce = -1;
}

/* --------------------------------

Authorization.

-------------------------------- */

function gm48_oauth2_authorize(_callback, _scope) {
    if (argument_count == 0) {
        show_error("gm48.net-oauth2-gms2: Callback script must be filled", true);
    }
    
    if (_callback && ! script_exists(_callback)) {
        show_error("gm48.net-oauth2-gms2: Callback script does not exist", true);
    }
    
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.INITIALISED) {
        show_error("gm48.net-oauth2-gms2: Cannot request access token again", true);
    }
    
    if (! global.gm48_oauth2_localhost_create()) {
        show_error("gm48.net-oauth2-gms2: Localhost server could not be created", false);
        
        return false;
    }
    
    global.gm48_oauth2_scope = (_scope ? _scope : GM48_OAUTH2_DEFAULT_SCOPES);
    
    global.gm48_oauth2_nonce = gm48_oauth2_string_random(64);
    
    var _url  = GM48_OAUTH2_URL_AUTHORIZE + "?";
        _url += "client_id=" + global.gm48_oauth2_client_id;
        _url += "&redirect_uri=" + GM48_OAUTH2_LOCALHOST_URL;
        _url += "&response_type=code";
        _url += "&scope=" + global.gm48_oauth2_scope;
        _url += "&state=" + global.gm48_oauth2_nonce;
        
    url_open(_url);

    global.gm48_oauth2_state = GM48_OAUTH2_STATE.AUTHORISATION_PENDING;
    global.gm48_oauth2_callback = _callback;
    global.gm48_oauth2_expires = current_time + GM48_OAUTH2_LOCALHOST_TIMEOUT;
    
    return true;
}

function gm48_oauth2_exchange_auth_code() {
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.AUTHORISATION_PENDING) {
        show_error("gm48.net-oauth2-gms2: Cannot exchange authorisation code at this time", true);
        
        return -1;
    }
	
	gm48_oauth2_debug("Exchanging authorisation code for access token");

    var _header_map = ds_map_create();
    _header_map[? "User-Agent"] = GM48_OAUTH2_USERAGENT;
	_header_map[? "Content-Type"] = "application/x-www-form-urlencoded";
	
    var _body  = "grant_type=authorization_code";
        _body += "&client_id=" + global.gm48_oauth2_client_id;
        _body += "&client_secret=" + global.gm48_oauth2_client_secret;
        _body += "&redirect_uri=" + GM48_OAUTH2_LOCALHOST_URL;
        _body += "&code=" + global.gm48_oauth2_auth_code;

    http_request(GM48_OAUTH2_URL_TOKEN, "POST", _header_map, _body);

    ds_map_destroy(_header_map);

    global.gm48_oauth2_state = GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE;

    return 0;
}

function gm48_oauth2_refresh_access_token() {
    if (global.gm48_oauth2_state != GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED) {
        show_error("gm48.net-oauth2-gms2: Cannot refresh access token right now", true);

        return -1;
    }

    var _header_map = ds_map_create();
    _header_map[? "User-Agent"] = GM48_OAUTH2_USERAGENT;
	_header_map[? "Content-Type"] = "application/x-www-form-urlencoded";

    var _body  = "grant_type=refresh_token";
    _body += "&refresh_token=" + global.gm48_oauth2_refresh_token;
    _body += "&client_id=" + global.gm48_oauth2_client_id;
    _body += "&client_secret=" + global.gm48_oauth2_client_secret;
    _body += "&scope=" + global.gm48_oauth2_scope;

    var _result = http_request(GM48_OAUTH2_URL_TOKEN, "POST", _header_map, _body);

    ds_map_destroy(_header_map);

    gm48_oauth2_debug("Sent HTTP POST to refresh access token");

    global.gm48_oauth2_state    = GM48_OAUTH2_STATE.REFRESHING_ACCESS_TOKEN;
    global.gm48_oauth2_callback = -1;

    return _result;
}

/* --------------------------------

Localhost server.

-------------------------------- */

function gm48_oauth2_localhost_create()
{
    if (global.gm48_oauth2_localhost_server < 0) {
        global.gm48_oauth2_localhost_server = network_create_server_raw(network_socket_tcp, GM48_OAUTH2_LOCALHOST_PORT, 10);
    }

    // Still no server??
    if (global.gm48_oauth2_localhost_server < 0) {
        gm48_oauth2_debug("Failed to create raw TCP server on port " + string(GM48_OAUTH2_LOCALHOST_PORT));
        
        return false;
    }

    gm48_oauth2_debug("Created server " + string(global.gm48_oauth2_localhost_server) + " on port " + string(GM48_OAUTH2_LOCALHOST_PORT));
    
    return true;    
}

function gm48_oauth2_localhost_destroy()
{
    if (global.gm48_oauth2_localhost_server >= 0)
    {
        gm48_oauth2_debug("Destroying server");
        
        network_destroy(global.gm48_oauth2_localhost_server);
        global.gm48_oauth2_localhost_server = -1;
    }
}

function gm48_oauth2_http() {
    var _http_status = async_load[? "http_status"];
    var _status      = async_load[? "status"     ];
    var _result      = async_load[? "result"     ];

    if (_status == 0)
    {
        if (_http_status == 200)
        {
            var _json = json_decode(_result);
            if (_json < 0)
            {
                show_error("gm48.net-oauth2-gms2: Could not decode response JSON, aborting", false);
            }
            else
            {
                switch(global.gm48_oauth2_state)
                {
                    case GM48_OAUTH2_STATE.EXCHANGING_AUTH_CODE:
                        global.gm48_oauth2_auth_code     = "";
                        global.gm48_oauth2_access_token  = _json[? "access_token" ];
                        global.gm48_oauth2_token_type    = _json[? "token_type"   ];
                        global.gm48_oauth2_expires       = current_time + 900*_json[? "expires_in"]; //Convert seconds to milliseconds, and expire a bit early
                        global.gm48_oauth2_refresh_token = _json[? "refresh_token"];
                        global.gm48_oauth2_scope         = _json[? "scope"        ];
                        global.gm48_oauth2_access_token_received = true;
                    
                        gm48_oauth2_debug("Received access token \"", global.gm48_oauth2_access_token, "\", expires ", global.gm48_oauth2_expires);
                        gm48_oauth2_debug("Ready to make requests!");
                    
                        global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
                    
                        script_execute(global.gm48_oauth2_callback, _json);
                    break;
                
                    case GM48_OAUTH2_STATE.REFRESHING_ACCESS_TOKEN:
                        global.gm48_oauth2_access_token = _json[? "access_token"];
                        global.gm48_oauth2_token_type   = _json[? "token_type"  ];
                        global.gm48_oauth2_expires      = current_time + 900*_json[? "expires_in"]; //Convert seconds to milliseconds, and expire a bit early
                        global.gm48_oauth2_scope        = _json[? "scope"       ];
                    
                        gm48_oauth2_debug("Received refreshed access token \"", global.gm48_oauth2_access_token, "\", expires ", global.gm48_oauth2_expires);
                        gm48_oauth2_debug("Ready to make requests!");
                    
                        global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
                    break;
                
                    case GM48_OAUTH2_STATE.OPERATION_PENDING:
                        gm48_oauth2_debug("Operation complete");
                        
                        global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
                    
                        script_execute(global.gm48_oauth2_callback, _json);
                    break;
                
                    default:
                        gm48_oauth2_debug("Warning! Unexpected async HTTP event received");
                    break;
                }
            
                ds_map_destroy(_json);
            }
        }
        else
        {
            gm48_oauth2_debug(_result);
            show_error("gm48.net-oauth2-gms2: HTTP " + string(_http_status) + " received. Check output log for more details", false);
        
            //Ensure the localhost server is destroyed
            gm48_oauth2_localhost_destroy();
        
            if (global.gm48_oauth2_state == GM48_OAUTH2_STATE.OPERATION_PENDING)
            {
                global.gm48_oauth2_state = GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED;
            }
            else
            {
                global.gm48_oauth2_state = GM48_OAUTH2_STATE.INITIALISED;
            }
        
            var _map = ds_map_create();
            script_execute(global.gm48_oauth2_callback, _map);
            ds_map_destroy(_map);
        }
    }
}

function gm48_oauth2_networking() {
    switch(async_load[? "type"])
    {
        case network_type_connect:
            global.gm48_oauth2_out_socket = async_load[? "socket"];
        
            gm48_oauth2_debug("New connection on socket ", global.gm48_oauth2_out_socket);
        break;
    
        case network_type_data:
            var _buffer = async_load[? "buffer"];
            if (_buffer != undefined)
            {
                var _string = buffer_read(_buffer, buffer_string);

                var _params = gmlscriptsdotscom_string_parse(_string, "&", false);
    
                var _code = string_delete(ds_list_find_value(_params, 0), 1, 11);
				
				gm48_oauth2_debug("code", _string, ds_list_find_value(_params, 0), _code); 
    
                var _almost_clean_nonce = string_delete(ds_list_find_value(_params, 1), 1, 6);
                var _nonce = string_copy(string_delete(_almost_clean_nonce, string_pos(" HTTP/1.1", _almost_clean_nonce), 9), 0, 64);
                
                gm48_oauth2_debug("nonce", _nonce, global.gm48_oauth2_nonce, _string); 
    
                if (_nonce != global.gm48_oauth2_nonce) {
                    show_error("gm48.net-oauth2-gms2: Security failsafe triggered", true);       
                }
                
                global.gm48_oauth2_auth_code = _code;
                
                gm48_oauth2_debug("Received authorization code");
                    
                gm48_oauth2_exchange_auth_code();
            
                if (global.gm48_oauth2_localhost_server >= 0)
                {
                    gm48_oauth2_debug("Sending raw HTTP response");
                
                    var _string = "HTTP/1.1 301 Moved Permanently\nLocation: " + GM48_OAUTH2_URL_AUTHORIZED + "\n\n";
                
                    var _out_buffer = buffer_create(string_byte_length(_string)+1, buffer_fixed, 1);
                    buffer_write(_out_buffer, buffer_string, _string);
                
                    network_send_raw(global.gm48_oauth2_out_socket, _out_buffer, buffer_get_size(_out_buffer));
                    buffer_delete(_out_buffer);
                }
            
                gm48_oauth2_localhost_destroy();
            }
        break;
    }
}

/* --------------------------------

Helper scripts.

-------------------------------- */

function gm48_oauth2_debug()
{
    if (! debug_mode) {
        return -1
    }
	
	if (argument_count == 1) {
		return show_debug_message("gm48.net-oauth2-gms2: " + string(argument0));
	}
    
    var _string = "";
    var _i = 0;
    repeat(argument_count)
    {
        _string += "(" + string(_i) + ") " + string(argument[_i]) + "\n";
        ++_i;
    }

    return show_debug_message("gm48.net-oauth2-gms2:\n" + _string);
}

function gm48_oauth2_string_random() {
    var str,cnt,out,len;
    
    str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    cnt = argument0;
    out = "";
    len = string_length(str);
    
    repeat (cnt) out += string_char_at(str,floor(random(len))+1);
    
    return out;
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
function gmlscriptsdotscom_string_parse() {
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