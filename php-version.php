#!/usr/bin/env php
<?php

$version = $argv[1];
$versions = @json_decode(stream_get_contents(STDIN), 1);

# check if we've got a distinct version
if (isset($versions[$version])) {
	printf("%s\n", $version);
	exit;
}

$by_minor = array();
# build the tree of latest versions per minor
if (!empty($versions) && !isset($versions["error"])) {
	foreach (array_keys((array) $versions) as $release) {
		list($major, $minor, $patch) = explode(".", $release);
		if (isset($by_minor["$major.$minor"])) {
			if (version_compare($release, $by_minor["$major.$minor"], "<")) {
				continue;
			}
		}
		$by_minor["$major.$minor"] = $release;
	}
}
# check latest release
if (isset($by_minor[$version])) {
	printf("%s\n", $by_minor[$version]);
} else {
	# failsafe
	switch ($version) {
	case "5.4":
		print("5.4.45\n");
		break;
	case "5.5":
		print("5.5.37\n");
		break;
	case "5.6":
		print("5.6.33\n");
		break;
	case "7.0":
		print("7.0.27\n");
		break;
	case "7.1":
		print("7.1.14\n");
		break;
	case "7.2":
		print("7.2.2\n");
		break;
	case "master":
		print("master\n");
		break;
	default:
		printf("%s\n", $version);
	}
}
