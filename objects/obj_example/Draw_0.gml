draw_set_valign(fa_middle);
draw_set_halign(fa_center);

if (global.gm48_oauth2_state == GM48_OAUTH2_STATE.ACCESS_TOKEN_RECEIVED) {
    draw_text(room_width/2, room_height/2 - 20, "Authorized! Press [Space] to get user info");
    draw_text(room_width/2, room_height/2 + 20, "Access token: " + string_copy(global.gm48_oauth2_access_token, 1, 20) + "...");
} else {
    draw_text(room_width/2, room_height/2, "Press [Enter] to log in and authorize");
}