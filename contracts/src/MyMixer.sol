// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifier} from "./Verifier.sol";
import {IMT, Poseidon2} from "./IMT.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Field} from "@poseidon/src/Field.sol";

/// @title MyMixer contract
/// @notice Abstract contract for mixers
abstract contract MyMixer is IMT, ReentrancyGuard {
    /// @notice Proof verifier interface
    IVerifier public immutable i_verifier;
    /// @notice Fixed ETH amount per note
    uint256 public immutable DENOMINATION;

    mapping(bytes32 => bool) public s_nullifierHashes;
    mapping(bytes32 => bool) public s_commitments;

    /// @notice Emitted on deposit
    event Deposited(
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    /// @notice Emitted on withdraw
    event Withdrawn(
        address to,
        address relayer,
        bytes32 nullifierHash,
        uint256 fee
    );

    error ValueMismatch(uint256 expected, uint256 actual);
    error PayFailed(address recipient, uint256 amount);
    error NoteSpent(bytes32 nullifierHash);
    error UnknownRoot(bytes32 root);
    error BadProof();
    error FeeTooHigh(uint256 expected, uint256 actual);
    error RefundNotSupported(uint256 refund);
    error DeadlineExpired(uint256 deadline, uint256 nowTs);
    error CommitmentExists(bytes32 commitment);

    /// @param _verifier Verifier contract
    /// @param _hasher Poseidon2 hasher
    /// @param _merkleTreeDepth Tree depth
    /// @param _denomination Fixed note value
    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth,
        uint256 _denomination
    ) IMT(_merkleTreeDepth, _hasher) {
        i_verifier = _verifier;
        DENOMINATION = _denomination;
    }

    /// @notice Deposit a commitment
    /// @dev This function is virtual and is implemented in the child contract ETHMixer.sol
    function deposit(bytes32 _commitment) external payable virtual;

    /// @notice Withdraw with proof
    /// @dev This function is virtual and is implemented in the child contract ETHMixer.sol
    function withdraw(
        bytes calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee,
        uint256 _refund,
        uint256 _deadline
    ) external virtual;

    /// @dev Convert external data to Poseidon2 field array for hashing
    function _extDataToFields(
        address _recipient,
        address _relayer,
        uint256 _fee,
        uint256 _refund,
        uint256 _chainId,
        address _contract,
        uint256 _denomination,
        uint256 _deadline
    ) internal pure returns (Field.Type[] memory arr) {
        arr = new Field.Type[](8);
        arr[0] = Field.toField(_recipient);
        arr[1] = Field.toField(_relayer);
        arr[2] = Field.toField(_fee);
        arr[3] = Field.toField(_refund);
        arr[4] = Field.toField(_chainId);
        arr[5] = Field.toField(_contract);
        arr[6] = Field.toField(_denomination);
        arr[7] = Field.toField(_deadline);
    }
}
