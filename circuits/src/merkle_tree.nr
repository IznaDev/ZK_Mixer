use dep::poseidon;

pub fn compute_merkle_root(leaf: Field, merkle_proof: [Field; 20], is_even: [bool; 20]) -> Field {
    // Store the hash for the current level
    let mut hash: Field = leaf;
    // Iterate over tree levels (20 levels)
    for i in 0..20 {
        let (left, right) = if is_even[i] {
            (hash, merkle_proof[i])
        } else {
            (merkle_proof[i], hash)
        };
        // Hash sibling pair with Poseidon
        hash = poseidon::poseidon2::Poseidon2::hash([left, right], 2);
    }
    // Return Merkle root
    hash
}
