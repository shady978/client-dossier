<?php
/**
 * Export the active Elementor kit as an importable .zip.
 * Usage: php bin/kit-export.php [output.zip]
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/wp-admin/';

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
wp_set_current_user( 1 );

$out = $argv[1] ?? __DIR__ . '/../client-dossier-kit.zip';

$module = \Elementor\Plugin::$instance->app->get_component( 'import-export' );
if ( ! $module ) {
	fwrite( STDERR, "Elementor import/export module not available.\n" );
	exit( 1 );
}

try {
	$result = $module->export_kit(
		array(
			'include'          => array( 'settings', 'templates', 'content' ),
			'kitInfo'          => array(
				'title'       => 'Client Dossier Kit',
				'description' => 'Global colors, fonts and layout defaults from the Client Dossier design.',
				'source'      => 'local',
			),
			'selectedCustomPostTypes' => array(),
			'plugins'          => array(),
		)
	);

	$zip = $result['file_name'] ?? '';
	if ( ! $zip || ! file_exists( $zip ) ) {
		fwrite( STDERR, "Export produced no file.\n" );
		exit( 1 );
	}

	copy( $zip, $out );
	printf( "Kit exported: %s (%s KB)\n", $out, number_format( filesize( $out ) / 1024, 1 ) );
} catch ( \Exception $e ) {
	fwrite( STDERR, 'Export failed: ' . $e->getMessage() . "\n" );
	exit( 1 );
}
