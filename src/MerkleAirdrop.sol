// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop is Ownable {

    address public immutable token;
    bytes32 public immutable merkleRoot;
    uint256 public immutable expiration;

    mapping(address => bool) public hasClaimed;
    
    error InvalidToken();
    error InvalidMerkleRoot();
    error InvalidExpiration();
    error AirdropExpired();
    error AlreadyClaimed();
    error InvalidProof();
    error InsufficientAirdropBalance();

    event Claimed(address indexed account, uint256 amount);

    constructor(address _token, bytes32 _merkleRoot, uint256 _expiration) Ownable(msg.sender) {
        if (_token == address(0)) revert InvalidToken();
        if (_merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (_expiration <= block.timestamp) revert InvalidExpiration();
        token = _token;
        merkleRoot = _merkleRoot;
        expiration = _expiration;
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        if (block.timestamp >= expiration) revert AirdropExpired();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (!verifyProof(msg.sender, amount, proof)) revert InvalidProof();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientAirdropBalance();
        hasClaimed[msg.sender] = true;
        IERC20(token).transfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function verifyProof(address account, uint256 amount, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encode(account, amount));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}