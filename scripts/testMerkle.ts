import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs/promises';

const values = [
  ['0x0000000000000000000000000000000000000001', '5000000000000000000'],
  ['0x0000000000000000000000000000000000000002', '2500000000000000000'],
  ['0x0000000000000000000000000000000000000003', '1000000000000000000'],
];

async function main() {
  const tree = StandardMerkleTree.of(values, ['address', 'uint256']);

  console.log('Merkle Root:', tree.root);

  const treeJSON = {};
  for (const [i, v] of tree.entries()) {
    treeJSON[v[0]] = {
      amount: v[1],
      index: i,
      proof: tree.getProof(i),
    };
    treeJSON['root'] = tree.root;
  }

  const leaf = tree.leafHash(values[0]);
  console.log('Leaf:', leaf);

  await fs.writeFile('scripts/treeJSON.json', JSON.stringify(treeJSON));
  await fs.writeFile('scripts/tree.json', JSON.stringify(tree.dump()));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
