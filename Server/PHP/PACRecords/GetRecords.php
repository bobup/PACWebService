#!/usr/local/bin/php
<?php

// Copyright (c) 2019 Bob Upshaw and Pacific Masters.  This software is covered under the Open Source MIT License

//error_reporting(E_ERROR | E_WARNING | E_PARSE | E_NOTICE);
// Report all PHP errors
error_reporting(E_ALL);

// are we running on our production server or dev server?
$server = "Production";
$currentUser = get_current_user();
if( $currentUser == "pacdev" ) {
		$server = "Development";
}

set_include_path( get_include_path() . PATH_SEPARATOR . "/usr/home/$currentUser/Library");
require_once 'pacminc.php';
require_once 'pacmfncn.php';

$course = "";
if(isset($_GET["SCY"])) {
	$course = "SCY";
} else if(isset($_GET["SCM"])) {
	$course = "SCM";
} else if(isset($_GET["LCM"])) {
	$course = "LCM";
} 


if( $course != "" ) {
	// get the records:
	$recordsArr = ind_records_extract( $course );
} else {
	$recordsArr = array(
		array(
				"status"		=>	"-10",
				"error"			=>	"Invalid COURSE",
		)
	);
}
$records = json_encode( $recordsArr );
#var_dump( $records );
echo $records;
?>

