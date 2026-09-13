<?php
/**
 * Activate the plugins and the theme, and apply the site-wide settings the
 * other scripts assume.
 *
 * Usage: WP_USER_ID=1 php bin/activate.php
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/';

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/theme.php';

$plugins = array(
	'sqlite-database-integration/load.php',
	'elementor/elementor.php',
	'envato-market/envato-market.php',
);

foreach ( $plugins as $plugin ) {
	if ( ! file_exists( WP_PLUGIN_DIR . '/' . $plugin ) ) {
		echo "not installed, skipping: $plugin\n";
		continue;
	}
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

// Elementor refuses to read JSON out of an uploaded archive unless unfiltered
// uploads are on, so template and kit imports need this. It also permits SVG
// uploads, which is worth knowing before turning it on somewhere public.
update_option( 'elementor_unfiltered_files_upload', 1 );
echo "unfiltered uploads: on (required for template/kit imports)\n";

// Elementor's Home screen reads from its cloud, which is blocked here; without
// the data it renders empty React panels, so use the plain settings screen.
update_option( 'elementor_experiment-home_screen', 'inactive' );

// Pretty permalinks.
update_option( 'permalink_structure', '/%postname%/' );
flush_rewrite_rules( true );
echo "permalinks: /%postname%/\n";
