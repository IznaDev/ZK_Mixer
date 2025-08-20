use dep::poseidon;

mod merkle_tree;
fn main(
    // Public inputs
    root: pub Field,
    nullifier_hash: pub Field,
    ext_data_hash: pub Field,
    // Private inputs
    nullifier: Field,
    secret: Field,
    merkle_proof: [Field; 20],
    is_even: [bool; 20],
    // External data (kept private to the circuit, bound via ext_data_hash)
    recipient: Field,
    relayer: Field,
    fee: Field,
    refund: Field,
    chain_id: Field,
    contract_addr: Field,
    denomination: Field,
    deadline: Field,
) {
    // compute the commitment with Poseidon

    let commitment: Field = poseidon::poseidon2::Poseidon2::hash([nullifier, secret], 2);

    // check that the nullifier matches the nullifier hash
    let computed_nullifier_hash: Field = poseidon::poseidon2::Poseidon2::hash([nullifier], 1);
    assert(computed_nullifier_hash == nullifier_hash);

    // check that the commitment is in the Incremental Merkle Tree
    let computed_root: Field = merkle_tree::compute_merkle_root(commitment, merkle_proof, is_even);
    assert(computed_root == root);

    // bind all external data to this proof to prevent front-running or tampering
    let computed_ext_data_hash: Field = poseidon::poseidon2::Poseidon2::hash(
        [recipient, relayer, fee, refund, chain_id, contract_addr, denomination, deadline],
        8,
    );
    assert(computed_ext_data_hash == ext_data_hash);

    // recipient and relayer must be non-zero addresses (in field form)
    assert(recipient != 0);
    assert(relayer != 0);

    // deadline must be non-zero
    assert(deadline != 0);
}
