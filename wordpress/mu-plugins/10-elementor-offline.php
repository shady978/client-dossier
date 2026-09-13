<?php
/**
 * Plugin Name: Elementor offline shims
 * Description: Elementor pulls its Home screen and Kit Library data from its own
 *              cloud, which is unreachable in this container. Feed the Home screen
 *              an empty-but-well-formed payload so the page renders instead of
 *              fatalling on a null response.
 */

add_filter(
	'elementor/core/admin/homescreen',
	function ( $data ) {
		$defaults = array(
			'top_with_licences'          => array(),
			'get_started'                => array( 'repeater' => array() ),
			'add_ons'                    => array(
				'hide_section' => array(),
				'repeater'     => array(),
			),
			'sidebar_promotion_variants' => array(),
			'button_cta_url'             => '',
			'edit_website_url'           => '',
		);

		if ( ! is_array( $data ) ) {
			$data = array();
		}

		$data = array_merge( $defaults, $data );

		// Individual keys can still come back null from a failed request.
		foreach ( $defaults as $key => $default ) {
			if ( ! is_array( $default ) ) {
				continue;
			}
			if ( ! is_array( $data[ $key ] ) ) {
				$data[ $key ] = $default;
			}
		}

		foreach ( array( 'get_started', 'add_ons' ) as $key ) {
			if ( ! isset( $data[ $key ]['repeater'] ) || ! is_array( $data[ $key ]['repeater'] ) ) {
				$data[ $key ]['repeater'] = array();
			}
		}

		return $data;
	},
	99
);
