<?php
/**
 * Activate the Elementor plugin and the Hello Elementor theme.
 * Usage: php bin/activate.php
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/';

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/theme.php';

// Plugins.
foreach ( array( 'sqlite-database-integration/load.php', 'elementor/elementor.php' ) as $plugin ) {
	if ( is_plugin_active( $plugin ) ) {
		echo "already active: $plugin\n";
		continue;
	}
	$result = activate_plugin( $plugin, '', false, true );
	if ( is_wp_error( $result ) ) {
		fwrite( STDERR, "FAILED $plugin: " . $result->get_error_message() . "\n" );
	} else {
		echo "activated: $plugin\n";
	}
}

// Theme.
$theme = wp_get_theme( 'hello-elementor' );
if ( $theme->exists() ) {
	switch_theme( 'hello-elementor' );
	echo 'theme: ' . wp_get_theme()->get( 'Name' ) . "\n";
} else {
	fwrite( STDERR, "hello-elementor theme not found\n" );
}

// Pretty permalinks.
update_option( 'permalink_structure', '/%postname%/' );
flush_rewrite_rules( true );
echo "permalinks: /%postname%/\n";
