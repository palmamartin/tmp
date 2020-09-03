<?php
// https://leetcode.com/problems/two-sum/
class Sum {

	/**
	* @param Integer[] $nums
	* @param Integer $target
	* @return Integer[]
	*/
	function twoSum($nums, $target) {
		$found = array();

		for ($i = 0; $i < count($nums);  $i++) {
			$c = $target - $nums[$i];
			if (array_key_exists($c, $found)) {
				return array($found[$c], $i);
			}

			$found[$nums[$i]] = $i;
		}
		return array();
	}
}

?>
