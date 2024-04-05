// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ProofOfWork} from "../src/PoW.sol";

contract CounterTest is Test {
    ProofOfWork public proofOfWork;

    function setUp() public {
        vm.warp(42);
        proofOfWork = new ProofOfWork();
    }

    function test_happy_case() public {
        bool isValid = false;
        uint256 secret = 0;
        uint256 round = proofOfWork.round();

        while(!isValid) {
            isValid = proofOfWork.checkResult(++secret);
        }
        proofOfWork.mint(address(this), secret);
        assert(proofOfWork.round() > round);
    }

    function test_fast_solve_increase_diff() public {
        bool isValid = false;
        uint256 secret = 0;
        uint256 round = proofOfWork.round();
        uint256 thresholdBefore = proofOfWork.currentThreshold();
        uint256 lastMintedAt = proofOfWork.lastMintedAt();

        while(!isValid) {
            isValid = proofOfWork.checkResult(++secret);
        }
        vm.warp(lastMintedAt + 2);
        proofOfWork.mint(address(this), secret);
        uint256 thresholdAfter = proofOfWork.currentThreshold();
        
        console2.log("thresholdBefore", thresholdBefore);
        console2.log("thresholdAfter ", thresholdAfter);
        // higher threshold means lower difficulty
        // lower difficulty means higher difficulty
        assert(thresholdAfter < thresholdBefore);
        assert(proofOfWork.round() > round);
    }

    function test_slow_solve_decrease_diff() public {
        bool isValid = false;
        uint256 secret = 0;
        uint256 round = proofOfWork.round();
        uint256 thresholdBefore = proofOfWork.currentThreshold();
        uint256 lastMintedAt = proofOfWork.lastMintedAt();

        while(!isValid) {
            isValid = proofOfWork.checkResult(++secret);
        }
        vm.warp(lastMintedAt + 100);
        proofOfWork.mint(address(this), secret);
        uint256 thresholdAfter = proofOfWork.currentThreshold();
        
        // higher threshold means lower difficulty
        // lower difficulty means higher difficulty
        assert(thresholdAfter > thresholdBefore);
        assert(proofOfWork.round() > round);
    }

    function test_diff_should_converge() public {
        bool isValid = false;
        uint256 secret = 0;
        uint256 cycles = 0;
        uint256 round = proofOfWork.round();
        uint256 thresholdBefore = proofOfWork.currentThreshold();
        uint256 thresholdAfter = proofOfWork.currentThreshold();

        while(secret == 0 || thresholdAfter != thresholdBefore) {
            uint256 lastMintedAt = proofOfWork.lastMintedAt();
            thresholdBefore = proofOfWork.currentThreshold();
            while(!isValid) {
                isValid = proofOfWork.checkResult(++secret);
            }
            cycles = cycles + 12;
            vm.warp(lastMintedAt + cycles);
            proofOfWork.mint(address(this), secret);
            thresholdAfter = proofOfWork.currentThreshold();
            console2.log("secret", secret);
            console2.log("thresholdBefore", thresholdBefore);
            console2.log("thresholdAfter ", thresholdAfter);
            console2.log("mint interval   ", proofOfWork.lastMintedAt() - lastMintedAt);
            isValid = false;
            assert(proofOfWork.round() > round);
            round = proofOfWork.round();
        }
    }
}
