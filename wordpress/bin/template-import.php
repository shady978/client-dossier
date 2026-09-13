<?php
/**
 * Import a template zip into the Elementor library.
 *
 * Handles both shapes you get in the wild:
 *   - an Elementor kit export (manifest.json + site-settings.json) -> imported as a kit
 *   - a template pack such as an Envato Template Kit, or a bare folder of Elementor
 *     template exports -> every Elementor template JSON in the zip is imported into
 *     Templates > Saved Templates, and anything that is not a template is skipped
 *
 * Usage: WP_USER_ID=1 php bin/template-import.php /path/to/kit.zip
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/wp-admin/';

$zip = $argv[1] ?? '';
if ( ! $zip || ! file_exists( $zip ) ) {
	fwrite( STDERR, "Usage: WP_USER_ID=1 php bin/template-import.php /path/to/kit.zip\n" );
	exit( 1 );
}
$zip = realpath( $zip );

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/image.php';

if ( ! current_user_can( 'manage_options' ) ) {
	fwrite( STDERR, "Run this with WP_USER_ID=1 so Elementor registers its import components.\n" );
	exit( 1 );
}

/**
 * An Elementor kit export always carries a site-settings.json next to its manifest.
 */
function tki_is_elementor_kit( $zip_path ) {
	$archive = new ZipArchive();
	if ( true !== $archive->open( $zip_path ) ) {
		return false;
	}
	$is_kit = false !== $archive->locateName( 'site-settings.json', ZipArchive::FL_NODIR );
	$archive->close();

	return $is_kit;
}

if ( tki_is_elementor_kit( $zip ) ) {
	$module = \Elementor\Plugin::$instance->app->get_component( 'import-export' );
	if ( ! $module ) {
		fwrite( STDERR, "Elementor import/export module not available.\n" );
		exit( 1 );
	}

	try {
		$module->import_kit(
			$zip,
			array(
				'include'                 => array( 'templates', 'content', 'settings' ),
				'overrideConditions'      => array(),
				'referrer'                => 'local',
				'selectedCustomPostTypes' => array(),
			)
		);
		echo "Imported as an Elementor kit.\n";
	} catch ( \Exception $e ) {
		fwrite( STDERR, 'Kit import failed: ' . $e->getMessage() . "\n" );
		exit( 1 );
	}
	exit( 0 );
}

// Otherwise treat it as a template pack. Elementor's own zip handling walks every
// JSON in the archive and skips the ones that are not templates (manifests, config).
$source = \Elementor\Plugin::$instance->templates_manager->get_source( 'local' );
$result = $source->import_template( basename( $zip ), $zip );

if ( is_wp_error( $result ) ) {
	fwrite( STDERR, 'Import failed: ' . $result->get_error_message() . "\n" );
	exit( 1 );
}

if ( empty( $result ) ) {
	fwrite( STDERR, "No Elementor templates found in the archive.\n" );
	exit( 1 );
}

printf( "Imported %d template(s):\n", count( $result ) );
foreach ( $result as $item ) {
	printf( "  #%s  %-10s %s\n", $item['template_id'], $item['type'], $item['title'] );
}
