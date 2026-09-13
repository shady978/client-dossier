<?php
/**
 * Plugin Name: Local sandbox tweaks
 * Description: Keeps the admin fast in an offline container by skipping update checks.
 */

// Skip the update pings — wordpress.org is unreachable from here.
remove_action( 'admin_init', '_maybe_update_core' );
remove_action( 'admin_init', '_maybe_update_plugins' );
remove_action( 'admin_init', '_maybe_update_themes' );

foreach ( array( 'pre_site_transient_update_core', 'pre_site_transient_update_plugins', 'pre_site_transient_update_themes' ) as $hook ) {
	add_filter(
		$hook,
		function () {
			return (object) array(
				'last_checked' => time(),
				'updates'      => array(),
				'response'     => array(),
				'no_update'    => array(),
			);
		}
	);
}

add_filter( 'automatic_updater_disabled', '__return_true' );

// s.w.org is unreachable here, so WordPress's emoji images render broken.
// Native emoji fonts handle this fine.
remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
remove_action( 'wp_print_styles', 'print_emoji_styles' );
remove_action( 'admin_print_styles', 'print_emoji_styles' );
remove_filter( 'the_content_feed', 'wp_staticize_emoji' );
remove_filter( 'comment_text_rss', 'wp_staticize_emoji' );
remove_filter( 'wp_mail', 'wp_staticize_emoji_for_email' );
add_filter( 'emoji_svg_url', '__return_false' );
