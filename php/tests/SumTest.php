<?php

use PHPUnit\Framework\TestCase;

class SumTest extends TestCase {
	function testTwoSum() {
		$testCases = array(
			0 => array(
				"input" => array(2, 7, 11, 15),
				"target" => 9,
				"want" => array(0, 1),
			),
			1 => array(
				"input" => array(3, 2, 4),
				"target" => 6,
				"want" => array(1, 2),
			),
			2 => array(
				"input" => array(3, 3),
				"target" => 6,
				"want" => array(0, 1),
			),
			3 => array(
				"input" => array(3, 3),
				"target" => 7,
				"want" => array(),
			)
		);

		$s = new Sum();

		foreach ($testCases as $key => $case) {
			$got = $s->twoSum($case["input"], $case["target"]);
			$this->assertEquals($case["want"], $got);
		}
	}
}

?>
