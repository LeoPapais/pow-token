// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

contract ProofOfWork is ERC20, ERC20Permit, ERC20FlashMint {
    uint256 public round;
    uint64 public startDate;
    uint64 public lastMintedAt;
    bytes32 public prevBlockHash;


    uint256 public constant TARGET_INTERVAL = 60;
    uint256 public currentThreshold = type(uint256).max >> 10;

    // logarithmic issuance policy, so we'll be always minting new tokens
    // but the rate will decrease over time, but it's not asymptotic to a ceiling
    constructor()
        ERC20("ProofOfWork", "PoW")
        ERC20Permit("ProofOfWork")
    {
        lastMintedAt = uint64(block.timestamp) - 2; // -2 so ln(delta_t) is always > 0
        startDate = lastMintedAt;
        prevBlockHash = blockhash(block.number);
    }

    /**
     * @notice Returns the result of the proof of work. It uses the msg.sender, so users can't be frontran, the previous block hash so
     * users can't just store secrets and use them later, and the secret itself. The result is a hash of these three values converted
     * to uint256. This number is later compared to the difficulty
     * 
     * @param secret proof that msg.sender has done the work to find a suitable secret
     */
    function getResult(uint256 secret) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            msg.sender,
            round,
            prevBlockHash,
            secret
        )));
    }

    /**
     * @notice Updates the difficulty of the proof of work. If the proof is found before the target interval, the difficulty
     * increases, and if it's found after the target interval, the difficulty decreases. It works as a simple P controller.
     */
    function updateDifficulty() internal {
        int256 actualInterval = int256(block.timestamp) - int256(int64(lastMintedAt));
        currentThreshold = Math.mulDiv(currentThreshold, uint256(actualInterval), TARGET_INTERVAL);
    }

    /**
     * @notice Checks if the proof is valid. Basically, it hashes the secret with the previous block hash and the sender's address
     * so to make sure that the sender has done the work to find a suitable secret. Since "result" is a hash converted to uint256,
     * it's a pseudo-random number, so we can check if it's less than a given treshold. This treshold is a gauge to how hard it is to
     * find a secret, it's a number that decreases when users take too long to find a valid proof, and increases if they find it before the target interval.
     * 
     * @param secret proof that msg.sender has done the work to find a suitable secret
     */
    function checkResult(uint256 secret) public view returns (bool) {
        uint256 result = getResult(secret);
        return result < currentThreshold;
    }

    /**
     * @notice Mint new tokens if the proof is valid
     * @param to receiver of the tokens
     * @param secret proof that msg.sender has done the work to find a suitable secret
     */
    function mint(address to, uint256 secret) public {
        require(checkResult(secret), "ProofOfWork: invalid proof");
        updateDifficulty();
        uint64 totalTimePassed = uint64(block.timestamp) - startDate;
        uint256 newTotalSupply = convert(totalTimePassed).ln().intoUint256();

        uint256 currentTotalSupply = totalSupply();
        _mint(to, newTotalSupply - currentTotalSupply);
        prevBlockHash = blockhash(block.number);
        round++;
        lastMintedAt = uint64(block.timestamp);
    }
}