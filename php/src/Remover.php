<?php
// https://leetcode.com/problems/remove-element/
class Remover {
	/**
     	* @param Integer[] $nums
     	* @param Integer $val
     	* @return Integer
     	*/
	function removeElement(&$nums, $val) {
		foreach ($nums as $key => $value) {
			if ($value == $val) {
				unset($nums[$key]);
			}
		}
		$nums = array_values($nums);
		return count($nums);
	}
}

?>
