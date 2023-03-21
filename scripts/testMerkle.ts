import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs/promises';

const values = [
  ['0x0000000000000000000000000000000000000001', '5000000000000000000'],
  ['0x0000000000000000000000000000000000000002', '2500000000000000000'],
  ['0x0000000000000000000000000000000000000003', '1000000000000000000'],
];

const valuesUpdated = [
  ['0x0000000000000000000000000000000000000001', '10000000000000000000'],
  ['0x0000000000000000000000000000000000000002', '2600000000000000000'],
  ['0x0000000000000000000000000000000000000003', '1100000000000000000'],
];

async function main() {
  const tree = StandardMerkleTree.of(values, ['address', 'uint256']);
  const tree2 = StandardMerkleTree.of(valuesUpdated, ['address', 'uint256']);

  const treeJSON = {};
  for (const [i, v] of tree.entries()) {
    treeJSON[v[0]] = {
      amount: v[1],
      index: i,
      proof: tree.getProof(i),
    };
    treeJSON['root'] = tree.root;
  }

  const treeJSON2 = {};
  for (const [i, v] of tree2.entries()) {
    treeJSON2[v[0]] = {
      amount: v[1],
      index: i,
      proof: tree2.getProof(i),
    };
    treeJSON2['root'] = tree2.root;
  }

  await fs.writeFile('scripts/treeJSON.json', JSON.stringify(treeJSON));
  await fs.writeFile('scripts/treeJSON2.json', JSON.stringify(treeJSON2));
  await fs.writeFile('scripts/tree.json', JSON.stringify(tree.dump()));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
