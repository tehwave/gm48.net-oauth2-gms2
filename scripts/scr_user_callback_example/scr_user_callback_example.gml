function scr_user_callback_example(userData, requestId)
{
	gm48_debug("User callback example called with request ID:", requestId);
	
	if (is_struct(userData)) {
		gm48_debug("User data received:");
		
		// Log common user fields that might be present
		if (variable_struct_exists(userData, "id")) {
			gm48_debug("User ID:", userData.id);
		}
		if (variable_struct_exists(userData, "username")) {
			gm48_debug("Username:", userData.username);
		}
		if (variable_struct_exists(userData, "email")) {
			gm48_debug("Email:", userData.email);
		}
		
		show_message("User information retrieved successfully! Check the output log for details.");
	} else {
		gm48_debug("No user data received or error occurred");
		show_message("Failed to retrieve user information. Check the output log for details.");
	}
}