function scr_callback_example()
{
	gm48_debug(
		"Callback example called.",
		global.gm48_oauth2_auth_code,
        global.gm48_oauth2_access_token,
        global.gm48_oauth2_token_type,
        global.gm48_oauth2_expires,
        global.gm48_oauth2_refresh_token,
        global.gm48_oauth2_scope
	);
}
