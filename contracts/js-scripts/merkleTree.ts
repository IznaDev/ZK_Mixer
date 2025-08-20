import { Barretenberg, Fr } from '@aztec/bb.js';

type KeyValue = {
    key: string;
    value: string;
};

async function hashLeftRight(left, right) {
    const bb = await Barretenberg.new();
    const frLeft = Fr.fromString(left);
    const frRight = Fr.fromString(right);
    const hash = await bb.poseidon2Hash([frLeft, frRight]);
    return hash.toString();
}

export class PoseidonTree {
    private levels: number;
    private zeros: string[];
    private hashLeftRight: (left: string, right: string) => Promise<string>;
    private storage: Map<string, string>;
    private totalLeaves: number;

    constructor(levels, zeros) {
        if (zeros.length < levels + 1) {
            throw new Error("Not enough zero values provided for the given tree height.");
        }
        this.levels = levels;
        this.hashLeftRight = hashLeftRight;
        this.storage = new Map();
        this.zeros = zeros;
        this.totalLeaves = 0;
    }

    async init(defaultLeaves = []) {
        if (defaultLeaves.length > 0) {
            this.totalLeaves = defaultLeaves.length;

            defaultLeaves.forEach((leaf, index) => {
                this.storage.set(PoseidonTree.indexToKey(0, index), leaf);
            });

            for (let level = 1; level <= this.levels; level++) {
                const numNodes = Math.ceil(this.totalLeaves / (2 ** level));
                for (let i = 0; i < numNodes; i++) {
                    const left = this.storage.get(PoseidonTree.indexToKey(level - 1, 2 * i)) || this.zeros[level - 1];
                    const right = this.storage.get(PoseidonTree.indexToKey(level - 1, 2 * i + 1)) || this.zeros[level - 1];
                    const node = await this.hashLeftRight(left, right);
                    this.storage.set(PoseidonTree.indexToKey(level, i), node);
                }
            }
        }
    }

    static indexToKey(level, index) {
        return `${level}-${index}`;
    }

    getIndex(leaf) {
        for (const [key, value] of this.storage.entries()) {
            if (value === leaf && key.startsWith('0-')) {
                return parseInt(key.split('-')[1]);
            }
        }
        return -1;
    }

    root() {
        return this.storage.get(PoseidonTree.indexToKey(this.levels, 0)) || this.zeros[this.levels];
    }

    proof(index) {
        const leaf = this.storage.get(PoseidonTree.indexToKey(0, index));
        if (!leaf) throw new Error("leaf not found");

        const pathElements: string[] = [];
        const pathIndices: number[] = [];

        this.traverse(index, (level, currentIndex, siblingIndex) => {
            const sibling = this.storage.get(PoseidonTree.indexToKey(level, siblingIndex)) || this.zeros[level];
            pathElements.push(sibling);
            pathIndices.push(currentIndex % 2);
        });

        return {
            root: this.root(),
            pathElements,
            pathIndices,
            leaf,
        };
    }

    async insert(leaf) {
        const index = this.totalLeaves;
        await this.update(index, leaf, true);
        this.totalLeaves++;
    }

    async update(index, newLeaf, isInsert = false) {
        if (!isInsert && index >= this.totalLeaves) {
            throw Error("Use insert method for new elements.");
        } else if (isInsert && index < this.totalLeaves) {
            throw Error("Use update method for existing elements.");
        }

        const keyValueToStore: KeyValue[] = [];
        let currentElement = newLeaf;

        await this.traverseAsync(index, async (level, currentIndex, siblingIndex) => {
            const sibling = this.storage.get(PoseidonTree.indexToKey(level, siblingIndex)) || this.zeros[level];
            const [left, right] = currentIndex % 2 === 0 ? [currentElement, sibling] : [sibling, currentElement];
            keyValueToStore.push({ key: PoseidonTree.indexToKey(level, currentIndex), value: currentElement });
            currentElement = await this.hashLeftRight(left, right);
        });

        keyValueToStore.push({ key: PoseidonTree.indexToKey(this.levels, 0), value: currentElement });
        keyValueToStore.forEach(({ key, value }) => this.storage.set(key, value));
    }

    traverse(index, fn) {
        let currentIndex = index;
        for (let level = 0; level < this.levels; level++) {
            const siblingIndex = currentIndex % 2 === 0 ? currentIndex + 1 : currentIndex - 1;
            fn(level, currentIndex, siblingIndex);
            currentIndex = Math.floor(currentIndex / 2);
        }
    }

    async traverseAsync(index, fn) {
        let currentIndex = index;
        for (let level = 0; level < this.levels; level++) {
            const siblingIndex = currentIndex % 2 === 0 ? currentIndex + 1 : currentIndex - 1;
            await fn(level, currentIndex, siblingIndex);
            currentIndex = Math.floor(currentIndex / 2);
        }
    }
}

const ZERO_VALUES = [
    "0x2d2334c6c22cca4c9f7c82c1253d2ebcf562d24fc3d19fa96f2b239ea106c15c",
    "0x1444b7b1faf9e7bf63d87b30634e1d022f3d408227c527983ca77961bfa4ac73",
    "0x091a219e533afef19b2aed1d87b40f5153422e733dea6068395a7a2aa2aecd64",
    "0x057832b286ae039a1c749ccd317100c5a1bc4d43794b72487f13825d30f58f06",
    "0x24619cc86b779233b85d09c04ac7a21c7b5d8f979ce84d271838b2ab187601ff",
    "0x18661f1ca28e3ad5f397039bd84dd5c291e6ed6a0a87c2b50a17dbcde8fdfccf",
    "0x19df16e2249be09b76bda09870b31839e07b509f9ec05f5ac8c92a2058dc99db",
    "0x0abe57148ab0d6512e33af103d4555827be4a4a46e35513cb500c430b4485df0",
    "0x1b37e1c00a6e4e66990a4b30adfdf92ad9dfa0714d91f5d94994b9d5e700fbe4",
    "0x2201260545c384bb92d5a6e846d1aef9329ea69c80ce4318ea650261e2e58352",
    "0x07df604cb8325e038eb5edcffca622f59c79f67cd7c7322df2e5510255b89c32",
    "0x2a7bdb23ace4ad9d76072981377d0c77a0b30958964c10f95c6e301b129e26a5",
    "0x179178211f5b95688304740e1bf5d1f9f4a45a80dd537fba74fa318883c97698",
    "0x04e1a0fd20754512d4e35dc05bd85b8503f579c640a64d29535d0b12625629f8",
    "0x2977922cf63fcfabb42b3d645478cfa76529a1c51c3586233933824cf9d81b97",
    "0x16e5304428134ad42b3c0fa1b49d2f5dde4222e5aecedefae66c37ac2429b5b6",
    "0x30447c94987fccba088ca9766c10fc87b306ed6d47c1c42a948d426fcdf10f7e",
    "0x1075de1da1b02ad5f86d6357a9257bf69ef6b0db36a5cb4c9fad6671a2f0aeab",
    "0x1abf7816fbfcda20a989d8b8baf4cdb6558267024ad747ffce15e3dd139dced0",
    "0x1e26be9ad01cdb41aed15fd8cc2b251e5682dbc995ca6cce6c14fb2be3a50b1f",
    "0x189a1825ac285fa50c4c63435058c7a61e215faecf49adcfd12ad87ffe6fc81f"
];

export async function merkleTree(leaves) {
    const TREE_HEIGHT = 20;
    const tree = new PoseidonTree(TREE_HEIGHT, ZERO_VALUES);

    // Initialize tree with no leaves (all zeros)
    await tree.init();

    // Insert some leaves (from input)
    for (const leaf of leaves) {
        await tree.insert(leaf);
    }

    return tree;
}