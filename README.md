# Sector Contracts

## Running Tests

install deps

```
yarn
```

init submodules

```
git submodule update --init --recursive
```

install [foundry](https://github.com/foundry-rs/foundry)

foundry tests:

```
yarn test
```

hardhat integrations tests:

```
yarn test:hardhat
```

## Coverage

see coverage stats:

```
yarn coverage
```

install this plugin:
https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

run `yarn coverage:lcov`
then run `Display Coverage` via Command Pallate

## Contract descriptions:

- SECT.sol is Sector token
- VotingEscrow.sol is veSECT forked for fiatDAO
- bSECT.sol is a token that can be converted to SECT token given a set price. User sends x bSECT tokens + x \* price of underlying tokens and recieves SECT tokens.
- lveSECT is a token that can be redemeed for veSECT w a 6m lockup at the time of conversion.
