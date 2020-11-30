#!/usr/bin/env php
<?php


$versions = @json_decode(stream_get_contents(STDIN), 1);
$mirror = getenv("PHP_MIRROR");






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

foreach ($by_minor as $v => $r) {
	$compress = array("gz" => "z", "bz2" => "j", "xz" => "J");
	$filename = $versions[$r]["source"][0]["filename"];
	printf("%s\t%s\tcurl -sSL %s%s | tar x%s\n", $v, $r, $mirror,
			$filename,
			$compress[pathinfo($filename, PATHINFO_EXTENSION)]
		);
}
