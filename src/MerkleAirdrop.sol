// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MerkleAirdrop is Ownable {

    address public immutable token;
    bytes32 public immutable merkleRoot;
    uint256 public immutable expiration;

    mapping(address => bool) public hasClaimed;
    
    error InvalidToken();
    error InvalidMerkleRoot();
    error InvalidExpiration();

    constructor(address _token, bytes32 _merkleRoot, uint256 _expiration) Ownable(msg.sender) {
        if (_token == address(0)) revert InvalidToken();
        if (_merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (_expiration <= block.timestamp) revert InvalidExpiration();
        token = _token;
        merkleRoot = _merkleRoot;
        expiration = _expiration;
    }
}