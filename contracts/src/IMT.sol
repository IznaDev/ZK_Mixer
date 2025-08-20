// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Field} from "@poseidon/src/Field.sol";
import {Poseidon2} from "@poseidon/src/Poseidon2.sol";

/// @title Incremental Merkle Tree (Poseidon2)
/// @notice Stores deposits and tracks recent roots
contract IMT {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // the "zero" element is the default value for the Merkle tree, it is used to fill in empty nodes keccak256("cyfrin") % FIELD_SIZE
    bytes32 public constant ZERO_ELEMENT =
        bytes32(
            0x2d2334c6c22cca4c9f7c82c1253d2ebcf562d24fc3d19fa96f2b239ea106c15c
        );
    Poseidon2 public immutable i_hasher;
    uint32 public immutable i_depth;
    mapping(uint256 => bytes32) public s_cachedSubtrees;
    mapping(uint256 => bytes32) public s_roots;
    uint32 public constant ROOT_HISTORY_SIZE = 30;
    uint32 public s_currentRootIndex = 0;
    uint32 public s_nextLeafIndex = 0;

    error LeftOutOfRange(bytes32 left);
    error RightOutOfRange(bytes32 right);
    error DepthTooLow(uint32 depth);
    error DepthTooHigh(uint32 depth);
    error MerkleTreeFull(uint32 nextIndex);
    error IndexOutOfBounds(uint256 index);

    /// @param _depth Tree depth
    /// @param _hasher Poseidon2 hasher
    constructor(uint32 _depth, Poseidon2 _hasher) {
        if (_depth == 0) revert DepthTooLow(_depth);
        if (_depth >= 32) revert DepthTooHigh(_depth);
        i_depth = _depth;
        i_hasher = _hasher;
        s_roots[0] = zeros(_depth);
    }

    /// @notice Hash two children with Poseidon2
    function hashLeftRight(
        bytes32 _left,
        bytes32 _right
    ) public view returns (bytes32) {
        if (uint256(_left) >= FIELD_SIZE) revert LeftOutOfRange(_left);
        if (uint256(_right) >= FIELD_SIZE) revert RightOutOfRange(_right);
        return
            Field.toBytes32(
                i_hasher.hash_2(Field.toField(_left), Field.toField(_right))
            );
    }

    /// @notice Insert a leaf and return its index
    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 _nextLeafIndex = s_nextLeafIndex;
        if (_nextLeafIndex == uint32(2) ** i_depth)
            revert MerkleTreeFull(_nextLeafIndex);
        uint32 currentIndex = _nextLeafIndex;
        bytes32 currentHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < i_depth; i++) {
            if (currentIndex % 2 == 0) {
                left = currentHash;
                right = zeros(i);
                s_cachedSubtrees[i] = currentHash;
            } else {
                left = s_cachedSubtrees[i];
                right = currentHash;
            }
            currentHash = hashLeftRight(left, right);
            currentIndex /= 2;
        }

        uint32 newRootIndex = (s_currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        s_currentRootIndex = newRootIndex;
        s_roots[newRootIndex] = currentHash;
        s_nextLeafIndex = _nextLeafIndex + 1;
        return _nextLeafIndex;
    }

    /// @notice Check if root is in recent history
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == bytes32(0)) return false;
        uint32 _currentRootIndex = s_currentRootIndex;
        uint32 i = _currentRootIndex;
        do {
            if (_root == s_roots[i]) return true;
            if (i == 0) i = ROOT_HISTORY_SIZE;
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /// @notice Latest root
    function getLatestRoot() public view returns (bytes32) {
        return s_roots[s_currentRootIndex];
    }

    /// @notice Zero subtrees by depth
    function zeros(uint256 i) public pure returns (bytes32) {
        if (i == 0)
            return
                bytes32(
                    0x2d2334c6c22cca4c9f7c82c1253d2ebcf562d24fc3d19fa96f2b239ea106c15c
                );
        else if (i == 1)
            return
                bytes32(
                    0x1444b7b1faf9e7bf63d87b30634e1d022f3d408227c527983ca77961bfa4ac73
                );
        else if (i == 2)
            return
                bytes32(
                    0x091a219e533afef19b2aed1d87b40f5153422e733dea6068395a7a2aa2aecd64
                );
        else if (i == 3)
            return
                bytes32(
                    0x057832b286ae039a1c749ccd317100c5a1bc4d43794b72487f13825d30f58f06
                );
        else if (i == 4)
            return
                bytes32(
                    0x24619cc86b779233b85d09c04ac7a21c7b5d8f979ce84d271838b2ab187601ff
                );
        else if (i == 5)
            return
                bytes32(
                    0x18661f1ca28e3ad5f397039bd84dd5c291e6ed6a0a87c2b50a17dbcde8fdfccf
                );
        else if (i == 6)
            return
                bytes32(
                    0x19df16e2249be09b76bda09870b31839e07b509f9ec05f5ac8c92a2058dc99db
                );
        else if (i == 7)
            return
                bytes32(
                    0x0abe57148ab0d6512e33af103d4555827be4a4a46e35513cb500c430b4485df0
                );
        else if (i == 8)
            return
                bytes32(
                    0x1b37e1c00a6e4e66990a4b30adfdf92ad9dfa0714d91f5d94994b9d5e700fbe4
                );
        else if (i == 9)
            return
                bytes32(
                    0x2201260545c384bb92d5a6e846d1aef9329ea69c80ce4318ea650261e2e58352
                );
        else if (i == 10)
            return
                bytes32(
                    0x07df604cb8325e038eb5edcffca622f59c79f67cd7c7322df2e5510255b89c32
                );
        else if (i == 11)
            return
                bytes32(
                    0x2a7bdb23ace4ad9d76072981377d0c77a0b30958964c10f95c6e301b129e26a5
                );
        else if (i == 12)
            return
                bytes32(
                    0x179178211f5b95688304740e1bf5d1f9f4a45a80dd537fba74fa318883c97698
                );
        else if (i == 13)
            return
                bytes32(
                    0x04e1a0fd20754512d4e35dc05bd85b8503f579c640a64d29535d0b12625629f8
                );
        else if (i == 14)
            return
                bytes32(
                    0x2977922cf63fcfabb42b3d645478cfa76529a1c51c3586233933824cf9d81b97
                );
        else if (i == 15)
            return
                bytes32(
                    0x16e5304428134ad42b3c0fa1b49d2f5dde4222e5aecedefae66c37ac2429b5b6
                );
        else if (i == 16)
            return
                bytes32(
                    0x30447c94987fccba088ca9766c10fc87b306ed6d47c1c42a948d426fcdf10f7e
                );
        else if (i == 17)
            return
                bytes32(
                    0x1075de1da1b02ad5f86d6357a9257bf69ef6b0db36a5cb4c9fad6671a2f0aeab
                );
        else if (i == 18)
            return
                bytes32(
                    0x1abf7816fbfcda20a989d8b8baf4cdb6558267024ad747ffce15e3dd139dced0
                );
        else if (i == 19)
            return
                bytes32(
                    0x1e26be9ad01cdb41aed15fd8cc2b251e5682dbc995ca6cce6c14fb2be3a50b1f
                );
        else if (i == 20)
            return
                bytes32(
                    0x189a1825ac285fa50c4c63435058c7a61e215faecf49adcfd12ad87ffe6fc81f
                );
        else if (i == 21)
            return
                bytes32(
                    0x2e06f4ff7576d5b815147b3aece9b22fd99bd083a68265c2cfada14d3c8bd1fb
                );
        else if (i == 22)
            return
                bytes32(
                    0x2566c8c68fe024bbf54dbb653de0bab4dfc99140a843ac3e4454776bc5748724
                );
        else if (i == 23)
            return
                bytes32(
                    0x01f821d6c1f1560c3527d5020debe70f8e927015d8179aadb8ec97770f0fbafa
                );
        else if (i == 24)
            return
                bytes32(
                    0x04521db73493e93e6a2b097d0b7df7e3e776d291e2f8f6fb03ebbbfb2a65a4cb
                );
        else if (i == 25)
            return
                bytes32(
                    0x19a7f24e50117866200d7fe5e1a3c1c58dc73a5a589ecfad841c930ce2823099
                );
        else if (i == 26)
            return
                bytes32(
                    0x06132a64acd2a68767445d0c903f2eb2e1767e671e51a6871dc01e0380367cf5
                );
        else if (i == 27)
            return
                bytes32(
                    0x0fc21bbc87ea45a2d0c74b75f96dc3a6fbb5de3f03a689a34bf6e81bd911f98c
                );
        else if (i == 28)
            return
                bytes32(
                    0x2ac64215fef890d62a3b28e378ec28f9b770171398906ac13348dc48aa3383e9
                );
        else if (i == 29)
            return
                bytes32(
                    0x2ef381c346c323aa901801f51041fee24a07378e1b0100d79246f892dd7cb104
                );
        else if (i == 30)
            return
                bytes32(
                    0x2f6183ceecab37c4b9bb9ce5bc23544332897f21d81692503902f85177c4e192
                );
        else if (i == 31)
            return
                bytes32(
                    0x1c9d9ffb4236d5b9b6456573116a15660cfc4a5db59e8ada985c1064b4452538
                );
        else revert IndexOutOfBounds(i);
    }
}
