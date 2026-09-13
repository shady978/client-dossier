<?php
/**
 * Import an Elementor kit zip into the local site.
 * Usage: php bin/kit-import.php /path/to/kit.zip
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/wp-admin/';

$zip = $argv[1] ?? '';
if ( ! $zip || ! file_exists( $zip ) ) {
	fwrite( STDERR, "Usage: php bin/kit-import.php /path/to/kit.zip\n" );
	exit( 1 );
}

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

wp_set_current_user( 1 );

$module = \Elementor\Plugin::$instance->app->get_component( 'import-export' );
if ( ! $module ) {
	fwrite( STDERR, "Elementor import/export module not available.\n" );
	exit( 1 );
}

try {
	$result = $module->import_kit(
		$zip,
		array(
			'include'                      => array( 'templates', 'content', 'settings', 'plugins' ),
			'overrideConditions'           => array(),
			'referrer'                     => 'local',
			'selectedCustomPostTypes'      => array(),
		)
	);
	echo "Kit imported.\n";
	if ( ! empty( $result['manifest']['title'] ) ) {
		echo 'Kit: ' . $result['manifest']['title'] . "\n";
	}
} catch ( \Exception $e ) {
	fwrite( STDERR, 'Import failed: ' . $e->getMessage() . "\n" );
	exit( 1 );
}
