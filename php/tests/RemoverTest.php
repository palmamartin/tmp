<?php

use PHPUnit\Framework\TestCase;

class RemoverTest extends TestCase {
	
	function testRemoveElement() {
		$testCases = array(
			0 => array(
				"input" => array(3, 2, 2, 3),
				"element" => 3,
				"want" => array(2, 2),
				"length" => 2,
			),
			1 => array(
				"input" => array(0,1,2,2,3,0,4,2),
				"element" => 2,
				"want" => array(0,1,3,0,4),
				"length" => 5,
			),
		);
		
		$rm = new Remover();
		
		foreach ($testCases as $key => $case) {
			$got = $rm->removeElement($case["input"], $case["element"]);
		
			$this->assertEquals($case["length"], $got);
			$this->assertEquals($case["want"], $case["input"]);
		}		
		
	} 
}

?>
