import { Barretenberg, Fr, UltraHonkBackend } from "@aztec/bb.js";
import { ethers } from "ethers";
// import { merkleTree } from "./utils/merkleTree.js";
import { merkleTree } from "./merkleTree.js";
// @ts-ignore
import { Noir } from "@noir-lang/noir_js";

// @ts-ignore
import path from 'path';
import fs from 'fs';

const circuit = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../circuits/target/circuits.json'), 'utf8'));

export default async function generateProof() {
    // Initialize Barretenberg
    const bb = await Barretenberg.new();

    // Get the commitment leaves, nullifier and secret from process args
    const inputs = process.argv.slice(2);

    // 1. Get nullifier and secret
    const nullifier = Fr.fromString(inputs[0]);
    const secret = Fr.fromString(inputs[1]);

    // 2. Create the nullifier hash
    const nullifierHash = await bb.poseidon2Hash([nullifier]);

    // 3. External data
    const recipient = Fr.fromString(inputs[2]);
    const relayer = Fr.fromString(inputs[3]);
    const fee = Fr.fromString(inputs[4]);
    const refund = Fr.fromString(inputs[5]);
    const chainId = Fr.fromString(inputs[6]);
    const contractAddr = Fr.fromString(inputs[7]);
    const denomination = Fr.fromString(inputs[8]);
    const deadline = Fr.fromString(inputs[9]);

    // 4. Create merkle tree, insert leaves and get merkle proof for commitment
    const leaves = inputs.slice(10);

    const tree = await merkleTree(leaves);
    // Create the commitment
    const commitment = await bb.poseidon2Hash([nullifier, secret]);
    const merkleProof = tree.proof(tree.getIndex(commitment.toString()));

    try {
        const noir = new Noir(circuit);
        const honk = new UltraHonkBackend(circuit.bytecode, { threads: 1 });

        // Compute ext_data_hash
        const extDataHash = await bb.poseidon2Hash([
            recipient, relayer, fee, refund, chainId, contractAddr, denomination, deadline
        ]);

        const input = {
            // Public inputs
            root: merkleProof.root,
            nullifier_hash: nullifierHash.toString(),
            ext_data_hash: extDataHash.toString(),

            // Private inputs
            nullifier: nullifier.toString(),
            secret: secret.toString(),
            merkle_proof: merkleProof.pathElements.map((i: any) => i.toString()),
            is_even: merkleProof.pathIndices.map((i: number) => i % 2 == 0),
            recipient: recipient.toString(),
            relayer: relayer.toString(),
            fee: fee.toString(),
            refund: refund.toString(),
            chain_id: chainId.toString(),
            contract_addr: contractAddr.toString(),
            denomination: denomination.toString(),
            deadline: deadline.toString(),
        };
        const { witness } = await noir.execute(input);



        const originalLog = console.log; // Save original
        // Override to silence all logs
        console.log = () => { };

        const { proof, publicInputs } = await honk.generateProof(witness, { keccak: true });
        // Restore original console.log
        console.log = originalLog;

        const result = ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes", "bytes32[]"],
            [proof, publicInputs]
        );
        return result;
    } catch (error) {
        console.log(error);
        throw error;
    }
}

(async () => {
    generateProof()
        .then((result) => {
            process.stdout.write(result);
            process.exit(0);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
})();