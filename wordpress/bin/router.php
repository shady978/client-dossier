<?php
/**
 * Router for the PHP built-in server so pretty permalinks work.
 * php -S 127.0.0.1:8080 -t /home/user/wp/site /home/user/wp/bin/router.php
 */

$root = dirname( __DIR__ ) . '/site';
$path = parse_url( $_SERVER['REQUEST_URI'], PHP_URL_PATH );
$path = rawurldecode( $path );
$file = realpath( $root . $path );

// Serve real files (assets, wp-admin/*.php, ...) directly.
if ( false !== $file && 0 === strpos( $file, $root ) ) {
	if ( is_file( $file ) ) {
		return false; // Let the built-in server handle it.
	}
	if ( is_dir( $file ) && is_file( $file . '/index.php' ) ) {
		$_SERVER['SCRIPT_NAME']     = rtrim( $path, '/' ) . '/index.php';
		$_SERVER['SCRIPT_FILENAME'] = $file . '/index.php';
		require $file . '/index.php';
		return true;
	}
}

// Everything else goes through WordPress.
$_SERVER['SCRIPT_NAME']     = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = $root . '/index.php';
require $root . '/index.php';
