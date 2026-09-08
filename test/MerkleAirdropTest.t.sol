// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;
    MockERC20 public token;

    address constant ALICE = address(0x1);
    address constant BOB = address(0x2);

    bytes32 aliceLeaf = keccak256(abi.encode(ALICE, 100 ether));
    bytes32 bobLeaf = keccak256(abi.encode(BOB, 200 ether));

    bytes32 root = _hashPair(aliceLeaf, bobLeaf);


    function setUp() public {
        token = new MockERC20();
        airdrop = new MerkleAirdrop(address(token), root, block.timestamp + 30 days); 

        token.mint(address(this), 300 ether);
        token.transfer(address(airdrop), 300 ether);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    function test_claim() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(address(airdrop)), 300 ether);

        vm.prank(ALICE);
        airdrop.claim(100 ether, proof);

        assertEq(token.balanceOf(ALICE), 100 ether);
        assertTrue(airdrop.hasClaimed(ALICE));
        assertEq(token.balanceOf(address(airdrop)), 200 ether);
    }

    function test_RevertIfAlreadyClaimed() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(ALICE);
        airdrop.claim(100 ether, proof);

        vm.prank(ALICE);
        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(100 ether, proof);

        assertTrue(airdrop.hasClaimed(ALICE));
    }

    function test_RevertIfInvalidProof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = aliceLeaf;

        vm.prank(ALICE);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(200 ether, proof);
    }

    function test_RevertIfWrongUser() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(BOB);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(100 ether, proof);
    }

    function test_RevertIfWrongAmount() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(ALICE);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(200 ether, proof);
    }

    function test_RevertIfExpired() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        // Fast forward time to after the airdrop expiration
        vm.warp(airdrop.expiration() + 1);

        vm.prank(ALICE);
        vm.expectRevert(MerkleAirdrop.AirdropExpired.selector);
        airdrop.claim(100 ether, proof);
    }

    function test_RevertIfInsufficientBalance() public {
        // Make the airdrop hold less than Alice's allocation
        deal(address(token), address(airdrop), 50 ether);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bobLeaf;

        vm.prank(ALICE);
        vm.expectRevert(MerkleAirdrop.InsufficientAirdropBalance.selector);
        airdrop.claim(100 ether, proof);
    }
}