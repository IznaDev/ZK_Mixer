// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HonkVerifier} from "../src/Verifier.sol";
import {ETHMyMixer} from "../src/ETHMyMixer.sol";
import {IVerifier} from "../src/Verifier.sol";
import {Poseidon2} from "../src/IMT.sol";

// Local copy of event signature for expectEmit matching
event Deposited(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);

contract ETHTornadoTest is Test {
    IVerifier public verifier;
    ETHMyMixer public mixer;
    Poseidon2 public poseidon;

    address public recipient = makeAddr("recipient");
    address public relayer = makeAddr("relayer");
    uint256 public fee = 0.0001 ether;
    uint256 public refund = 0; // ETH mixer: refund must be zero
    uint256 public deadline;

    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        mixer = new ETHMyMixer(IVerifier(verifier), poseidon, 20, 0.001 ether);
        deadline = block.timestamp + 1 days;
    }

    function _getProof(
        bytes32 _nullifier,
        bytes32 _secret,
        address _recipient,
        address _relayer,
        uint256 _fee,
        uint256 _refund,
        uint256 _deadline,
        bytes32[] memory leaves
    ) internal returns (bytes memory proof, bytes32[] memory publicInputs) {
        // inputs: nullifier, secret, recipient, relayer, fee, refund, chainId, contractAddr, denomination, deadline, ...leaves
        string[] memory inputs = new string[](13 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/createProof.ts";
        inputs[3] = vm.toString(_nullifier);
        inputs[4] = vm.toString(_secret);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_recipient))));
        inputs[6] = vm.toString(bytes32(uint256(uint160(_relayer))));
        inputs[7] = vm.toString(bytes32(_fee));
        inputs[8] = vm.toString(bytes32(_refund));
        inputs[9] = vm.toString(bytes32(block.chainid));
        inputs[10] = vm.toString(bytes32(uint256(uint160(address(mixer)))));
        inputs[11] = vm.toString(bytes32(mixer.DENOMINATION()));
        inputs[12] = vm.toString(bytes32(_deadline));

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[13 + i] = vm.toString(leaves[i]);
        }

        bytes memory result = vm.ffi(inputs);
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    function _getCommitment()
        internal
        returns (bytes32 commitment, bytes32 nullifier, bytes32 secret)
    {
        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/createCommitment.ts";

        bytes memory result = vm.ffi(inputs);
        (commitment, nullifier, secret) = abi.decode(
            result,
            (bytes32, bytes32, bytes32)
        );

        return (commitment, nullifier, secret);
    }

    function testGetCommitment() public {
        (bytes32 commitment, bytes32 nullifier, bytes32 secret) = _getCommitment();
        assertTrue(commitment != 0);
        assertTrue(nullifier != 0);
        assertTrue(secret != 0);
    }

    function testMakeDeposit() public {
        (bytes32 _commitment, , ) = _getCommitment();
        vm.expectEmit(true, false, false, true);
        emit Deposited(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);
    }

    function testMakeWithdrawal() public {
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _commitment;

        (bytes memory _proof, bytes32[] memory _publicInputs) = _getProof(
            _nullifier,
            _secret,
            recipient,
            relayer,
            fee,
            refund,
            deadline,
            leaves
        );
        assertTrue(verifier.verify(_proof, _publicInputs));

        uint256 balanceBeforeRecipient = recipient.balance;
        uint256 balanceBeforeRelayer = relayer.balance;
        uint256 contractBefore = address(mixer).balance;

        mixer.withdraw(
            _proof,
            _publicInputs[0],
            _publicInputs[1],
            payable(recipient),
            payable(relayer),
            fee,
            refund,
            deadline
        );

        assertEq(recipient.balance, balanceBeforeRecipient + (mixer.DENOMINATION() - fee));
        assertEq(relayer.balance, balanceBeforeRelayer + fee);
        assertEq(address(mixer).balance, contractBefore - mixer.DENOMINATION());
    }

    function testAnotherAddressSendProofFrontRunningFails() public {
        (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret) = _getCommitment();
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _commitment;

        (bytes memory _proof, bytes32[] memory _publicInputs) = _getProof(
            _nullifier,
            _secret,
            recipient,
            relayer,
            fee,
            refund,
            deadline,
            leaves
        );

        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert();
        mixer.withdraw(
            _proof,
            _publicInputs[0],
            _publicInputs[1],
            payable(attacker), // recipient swapped -> ext_data_hash mismatch
            payable(relayer),
            fee,
            refund,
            deadline
        );
    }
}
