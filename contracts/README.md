## My Mixer App inspired by Tornado 

- Deposit : users can deposit ETH into the mixer
- Withdraw: users will withdraw using a ZK proof (Noir - generated off-chain) of knowledge of their deposit. 

The mixer allow to break the connection between depositor and withdrawer.

We create a circuits made up of several constraints that verify:

1. The commitment derived from the private secret and nullifier is part of the Merkle tree whose root is the public root input (proves valid deposit).

2. The public nullifierHash correctly corresponds to the private nullifier.

3. Dummy calculations involving recipient, relayer, fee, and refund are performed to ensure these values are part of the proof and prevent front-running.

## Zero-Knowledge Proofs (ZK-SNARKs) 

The proof generation process involves:
    1. The withdrawer provides their secure note (containing secret, nullifier).
    2. the Mixer reconstruct the history of all commitments and build the current Merkle tree.
    3. It calculates the Merkle proof (pathElements, pathIndices) for the user's commitment.
    4. These private inputs (secret, nullifier, pathElements, pathIndices) and public inputs (root, nullifierHash, recipient, relayer, fee, refund) are fed into the circuit.
    5. If the inputs satisfy the constraints, a witness is generated.
    6. The witness is used to create the ZK-SNARK proof (a compact byte string).

My mixer is for ETH currently, but in a near future I will implement the mixer for any ERC20 Token.