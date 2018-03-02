<?php

return function() {
	$process = function($apc, $key, $values = ["no", "yes"]) {

		return $apc;
	};

	foreach (func_get_args() as $array) {
		$apc = [];
		foreach ($array as $key => $values) {
			if (is_numeric($key) && is_string($values)) {
				// switch on yes/no
				$key = $values;
				$values = ["no", "yes"];
			} else if (is_numeric($key) && is_array($values)) {
				// mutually enasbled options
				$vpc = [];
				foreach ($values as $yes) {
					$mpc = "$yes=yes ";
					foreach ($values as $no) {
						if ($yes === $no) {
							continue;
						}
						$mpc .= "$no=no ";
					}
					$vpc[] = $mpc;
				}
				$key = null;
				$values = $vpc;
			}

			if (empty($apc)) {
				// seed
				foreach ((array) $values as $val) {
					$apc[] = strlen($key) ? "$key=$val" : $val;
				}
			} else {
				// combine
				$cpc = $apc;
				$apc = [];
				foreach ((array) $values as $val) {
					foreach ($cpc as $e) {
						$apc[] = strlen($key) ? "$e $key=$val" : "$e $val";
					}
				}
			}
		}
		$xpc[] = $apc;
	}
	return $xpc;
};
