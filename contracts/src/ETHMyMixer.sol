// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MyMixer} from "./MyMixer.sol";
import {IVerifier} from "./Verifier.sol";
import {Poseidon2} from "./IMT.sol";
import {Field} from "@poseidon/src/Field.sol";

contract ETHMyMixer is MyMixer {
    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth,
        uint256 _denomination
    ) MyMixer(_verifier, _hasher, _merkleTreeDepth, _denomination) {}

    function deposit(
        bytes32 _commitment
    ) external payable override nonReentrant {
        if (s_commitments[_commitment]) revert CommitmentExists(_commitment);
        if (msg.value != DENOMINATION)
            revert ValueMismatch(DENOMINATION, msg.value);
        s_commitments[_commitment] = true;
        uint32 insertedIndex = _insert(_commitment);
        emit Deposited(_commitment, insertedIndex, block.timestamp);
    }

    function withdraw(
        bytes calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee,
        uint256 _refund,
        uint256 _deadline
    ) external override nonReentrant {
        if (s_nullifierHashes[_nullifierHash]) revert NoteSpent(_nullifierHash);
        if (!isKnownRoot(_root)) revert UnknownRoot(_root);
        if (_fee > DENOMINATION) revert FeeTooHigh(DENOMINATION, _fee);
        if (block.timestamp > _deadline)
            revert DeadlineExpired(_deadline, block.timestamp);
        if (_refund != 0) revert RefundNotSupported(_refund);
        // Compute ext_data_hash exactly like in the circuit
        bytes32 extDataHash = Field.toBytes32(
            i_hasher.hash(
                _extDataToFields(
                    _recipient,
                    _relayer,
                    _fee,
                    _refund,
                    block.chainid,
                    address(this),
                    DENOMINATION,
                    _deadline
                )
            )
        );
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = extDataHash;
        if (!i_verifier.verify(_proof, publicInputs)) revert BadProof();
        s_nullifierHashes[_nullifierHash] = true;
        uint256 amountToRecipient = DENOMINATION - _fee;
        (bool success, ) = _recipient.call{value: amountToRecipient}("");
        if (!success) revert PayFailed(_recipient, amountToRecipient);
        if (_fee != 0) {
            (bool feeSent, ) = _relayer.call{value: _fee}("");
            if (!feeSent) revert PayFailed(_relayer, _fee);
        }
        emit Withdrawn(_recipient, _relayer, _nullifierHash, _fee);
    }
}
