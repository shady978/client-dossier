<?php
/**
 * Build the "Client Dossier" Elementor kit: global colors, global fonts and
 * layout defaults, taken from the palette in the repo's index.html.
 *
 * Usage: php bin/kit-setup.php
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/wp-admin/';

require_once __DIR__ . '/../site/wp-load.php';
wp_set_current_user( 1 );

$kits_manager = \Elementor\Plugin::$instance->kits_manager;
$kit_id       = $kits_manager->get_active_id();

if ( ! $kit_id || ! get_post( $kit_id ) ) {
	$kit_id = $kits_manager->create_default();
	update_option( $kits_manager::OPTION_ACTIVE, $kit_id );
}

$kit = \Elementor\Plugin::$instance->documents->get( $kit_id );
if ( ! $kit ) {
	fwrite( STDERR, "Could not load the kit document.\n" );
	exit( 1 );
}

wp_update_post(
	array(
		'ID'         => $kit_id,
		'post_title' => 'Client Dossier Kit',
	)
);

$heading_font = 'IBM Plex Sans Arabic';
$mono_font    = 'IBM Plex Mono';

$settings = array(
	// --- Global colors -------------------------------------------------
	'system_colors'      => array(
		array(
			'_id'   => 'primary',
			'title' => 'Copper',
			'color' => '#B0602E',
		),
		array(
			'_id'   => 'secondary',
			'title' => 'Steel',
			'color' => '#2F5559',
		),
		array(
			'_id'   => 'text',
			'title' => 'Ink',
			'color' => '#1B2420',
		),
		array(
			'_id'   => 'accent',
			'title' => 'Ochre',
			'color' => '#C98A2E',
		),
	),
	'custom_colors'      => array(
		array(
			'_id'   => 'paper',
			'title' => 'Paper',
			'color' => '#F4F3EE',
		),
		array(
			'_id'   => 'inksoft',
			'title' => 'Ink Soft',
			'color' => '#26332D',
		),
		array(
			'_id'   => 'copperd',
			'title' => 'Copper Dark',
			'color' => '#8F4C22',
		),
		array(
			'_id'   => 'muted',
			'title' => 'Muted',
			'color' => '#5C645F',
		),
		array(
			'_id'   => 'line',
			'title' => 'Line',
			'color' => '#DCD9D0',
		),
		array(
			'_id'   => 'success',
			'title' => 'Success',
			'color' => '#2F6B4F',
		),
		array(
			'_id'   => 'danger',
			'title' => 'Danger',
			'color' => '#A63A2C',
		),
	),

	// --- Global fonts --------------------------------------------------
	'system_typography'  => array(
		array(
			'_id'                       => 'primary',
			'title'                     => 'Headings',
			'typography_typography'     => 'custom',
			'typography_font_family'    => $heading_font,
			'typography_font_weight'    => '600',
			'typography_line_height'    => array(
				'unit' => 'em',
				'size' => 1.25,
			),
			'typography_letter_spacing' => array(
				'unit' => 'px',
				'size' => -0.4,
			),
		),
		array(
			'_id'                    => 'secondary',
			'title'                  => 'Subheadings',
			'typography_typography'  => 'custom',
			'typography_font_family' => $heading_font,
			'typography_font_weight' => '500',
		),
		array(
			'_id'                    => 'text',
			'title'                  => 'Body',
			'typography_typography'  => 'custom',
			'typography_font_family' => $heading_font,
			'typography_font_weight' => '400',
			'typography_line_height' => array(
				'unit' => 'em',
				'size' => 1.8,
			),
		),
		array(
			'_id'                       => 'accent',
			'title'                     => 'Mono / labels',
			'typography_typography'     => 'custom',
			'typography_font_family'    => $mono_font,
			'typography_font_weight'    => '500',
			'typography_letter_spacing' => array(
				'unit' => 'px',
				'size' => 0.6,
			),
		),
	),

	// --- Layout defaults -----------------------------------------------
	'container_width'    => array(
		'unit' => 'px',
		'size' => 940,
	),
	'space_between_widgets' => array(
		'unit' => 'px',
		'size' => 24,
	),
	'page_title_selector' => 'h1.entry-title',
	'body_background_background' => 'classic',
	'body_background_color'      => '#F4F3EE',

	// --- Site identity ---------------------------------------------------
	'site_name'        => get_option( 'blogname' ),
	'site_description' => get_option( 'blogdescription' ),
);

$kit->update_settings( $settings );

\Elementor\Plugin::$instance->files_manager->clear_cache();

echo "Kit #{$kit_id} configured: " . get_the_title( $kit_id ) . "\n";
echo "  colors: 4 system + " . count( $settings['custom_colors'] ) . " custom\n";
echo "  fonts:  {$heading_font} / {$mono_font}\n";
