<?php
/**
 * Plugin Name: CLI current user
 * Description: Elementor registers some admin components only for a user who can
 *              manage_options, and it does so during plugin load. When a helper
 *              script runs from the CLI, resolve the user before that happens.
 */

if ( 'cli' === php_sapi_name() && getenv( 'WP_USER_ID' ) ) {
	add_filter(
		'determine_current_user',
		function () {
			return (int) getenv( 'WP_USER_ID' );
		},
		30
	);
}
