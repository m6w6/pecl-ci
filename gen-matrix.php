<?php

return new class {
    function github(array $matrix) {
        $idx = function($job_id) {
            static $ids = [];
            
            $parts = explode("-", $job_id);
            $count = end($parts);
            if (is_numeric($count)) {
                unset($parts[key($parts)]);
            }
            
            $base = implode("-", $parts);
            if (isset($ids[$base])) {
                $ids[$base]++;
            } else {
                $ids[$base] = 0;
            }
            $parts[] = $ids[$base];
            
            return implode("-", $parts);
        };
        
        $all_jobs = [];
        foreach ($matrix as $id => $array) {
            $jobs = [];
            foreach ($array as $key => $values) {
                if (is_numeric($key) && is_string($values)) {
                    // duplicate each job and switch on yes/no
                    if (!$jobs) {
                        $jobs[$idx($id)][$values] = "yes";
                        $jobs[$idx($id)][$values] = "no";
                    } else {
                        foreach (array_keys($jobs) as $job_id) {
                            $jobs[$job_id][$values] = "yes";
                            $job_idx = $idx($job_id);
                            $jobs[$job_idx] = $jobs[$job_id];
                            $jobs[$job_idx][$values] = "no";
                        }
                    }
                } else if (is_numeric($key) && is_array($values)) {
                    // multiplicate each job for each mutually enabled combination of options
                    $all_mut = [];
                    foreach ($values as $yes) {
                        $mut = [$yes => "yes"];
                        foreach ($values as $no) {
                            if ($yes !== $no) {
                                $mut[$no] = "no";
                            }
                        }
                        $all_mut[] = $mut;
                    }
                    
                    if (!$jobs) {
                        foreach ($all_mut as $mut) {
                            $jobs[$idx($id)] = $mut;
                        }
                    } else {
                        foreach (array_keys($jobs) as $job_id) {
                            foreach ($all_mut as $i => $mut) {
                                $mut_job = array_merge($jobs[$job_id], $mut);
                                if ($i == 0) {
                                    $jobs[$job_id] = $mut_job;
                                } else {
                                    $jobs[$idx($job_id)] = $mut_job;
                                }
                            }
                        }
                    }
                } else {
                    // multiplicate all jobs for each value
                    if (!$jobs) {
                        foreach ((array) $values as $val) {
                            $jobs[$idx($id)][$key] = $val;
                        }
                    } else {
                        foreach (array_keys($jobs) as $job_id) {
                            foreach ((array) $values as $i => $val) {
                                if ($i == 0) {
                                    $jobs[$job_id][$key] = $val;
                                } else {
                                    $job_idx = $idx($job_id);
                                    $jobs[$job_idx] = $jobs[$job_id];
                                    $jobs[$job_idx][$key] = $val;
                                }
                            }
                        }
                    }
                }
            }
            $all_jobs[] = $jobs;
        }
        return array_merge(...$all_jobs);
    }
    function travis(array $matrix) {
        $xpc = [];
        foreach ($matrix as $id => $array) {
            $apc = [];
            foreach ($array as $key => $values) {
                if (is_numeric($key) && is_string($values)) {
                    // switch on yes/no
                    $key = $values;
                    $values = ["no", "yes"];
                } else if (is_numeric($key) && is_array($values)) {
                    // mutually enabled options
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
            $xpc[$id] = $apc;
        }
        return $xpc;
    }
    function __invoke(...$args) {
        return $this->travis(...$args); // BC
    }
};
