<?php
/**
 * One-shot WordPress installer for the local SQLite site.
 * Usage: php bin/install.php
 */

$_SERVER['HTTP_HOST']   = 'localhost:8080';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SERVER_NAME'] = 'localhost';
$_SERVER['SERVER_PORT'] = '8080';

define( 'WP_INSTALLING', true );

require_once __DIR__ . '/../site/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';

if ( is_blog_installed() ) {
	echo "Already installed.\n";
	exit( 0 );
}

$title = getenv( 'WP_TITLE' ) ?: 'Client Dossier';
$user  = getenv( 'WP_ADMIN_USER' ) ?: 'admin';
$pass  = getenv( 'WP_ADMIN_PASS' ) ?: 'admin123';
$email = getenv( 'WP_ADMIN_EMAIL' ) ?: 'admin@example.com';

$result = wp_install( $title, $user, $email, true, '', $pass );

if ( is_wp_error( $result ) ) {
	fwrite( STDERR, 'Install failed: ' . $result->get_error_message() . "\n" );
	exit( 1 );
}

echo "Installed '{$title}' — admin user #{$result['user_id']} ({$user}).\n";
