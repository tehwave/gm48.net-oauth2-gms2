// Test the gm48_oauth2_authenticated_user function
if (global.gm48_oauth2_state == GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED) {
    gm48_oauth2_authenticated_user(scr_user_callback_example);
} else {
    show_message("You need to authorize first by pressing Enter!");
}