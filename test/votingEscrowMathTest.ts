/* eslint-disable @typescript-eslint/dot-notation */
/* eslint-disable no-await-in-loop */
/* eslint-disable @typescript-eslint/naming-convention */
import { network, ethers } from 'hardhat';
import { expect } from 'chai';
import { assertBNClosePercent } from './helpers/assertions';
//import { MassetMachine, StandardAccounts } from "./utils/machines"
import {
  advanceBlock,
  increaseTime,
  increaseTimeTo,
  getTimestamp,
  latestBlock,
} from './helpers/time2';
import { BN, simpleToExactAmount, maximum, sqrt } from './helpers/math';
import {
  ONE_WEEK,
  ONE_HOUR,
  ONE_DAY,
  ONE_YEAR,
  TWO_YEARS,
  DEFAULT_DECIMALS,
} from './helpers/constants';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
//import { ethers, waffle, network } from "hardhat";
import { Blocklist, MockERC20, VotingEscrow } from '../typechain';
import { BigNumber } from 'ethers';

//import { Account } from "types"

let votingLockup: VotingEscrow;
let blocklist: Blocklist;
let admin: SignerWithAddress;
let defaultUser: SignerWithAddress;
let other: SignerWithAddress;
let fundManager: SignerWithAddress;
let accounts: SignerWithAddress[];
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let charlie: SignerWithAddress;
let david: SignerWithAddress;
let eve: SignerWithAddress;
let francis: SignerWithAddress;
let greg: SignerWithAddress;
let hank: SignerWithAddress;
let treasury: SignerWithAddress;

//let nexus: Nexus
let govMock: MockERC20;
async function latestBlockBN() {
  return (await ethers.provider.getBlock('latest')).number;
}
async function getTimestampBN() {
  return (await ethers.provider.getBlock('latest')).timestamp;
}
describe('VotingEscrow Math test', () => {
  before('Init contract', async () => {
    accounts = await ethers.getSigners();

    [
      admin,
      defaultUser,
      other,
      fundManager,
      alice,
      bob,
      charlie,
      david,
      eve,
      francis,
      greg,
      hank,
      treasury,
    ] = accounts;
  });

  const isCoverage = network.name === 'coverage';

  const calculateStaticBalance = async (
    lockupLength: BN,
    amount: BN
  ): Promise<BN> => {
    const slope = amount.div(await votingLockup.MAXTIME());
    const s = slope.mul(10000).mul(sqrt(lockupLength));
    return s;
  };

  const goToNextUnixWeekStart = async () => {
    const unixWeekCount = (await getTimestamp()).div(ONE_WEEK);
    const nextUnixWeek = unixWeekCount.add(1).mul(ONE_WEEK);
    await increaseTimeTo(nextUnixWeek);
  };

  const deployFresh = async (initialRewardFunding = BN.from(0)) => {
    //  nexus = await new Nexus__factory(defaultUser).deploy(sa.governor.address)
    const govMockDeployer = await ethers.getContractFactory('MockERC20', admin);

    govMock = (await govMockDeployer.deploy(
      'FiatDAO',
      'Token',
      admin.address
    )) as MockERC20;
    // mta = await new MintableToken__factory(defaultUser).deploy(nexus.address, sa.fundManager.address)
    await govMock.mint(
      fundManager.address,
      ethers.utils.parseEther('1000000000000')
    );

    await govMock
      .connect(fundManager)
      .transfer(
        defaultUser.address,
        simpleToExactAmount(1000, DEFAULT_DECIMALS)
      );
    await govMock
      .connect(fundManager)
      .transfer(other.address, simpleToExactAmount(1000, DEFAULT_DECIMALS));

    const votingEscrowDeployer = await ethers.getContractFactory(
      'VotingEscrow',
      admin
    );
    votingLockup = (await votingEscrowDeployer.deploy(
      admin.address,
      treasury.address,
      govMock.address,
      'veToken',
      'veToken'
    )) as VotingEscrow;
    // Deploy Blocklist
    const blocklistDeployer = await ethers.getContractFactory(
      'Blocklist',
      admin
    );

    blocklist = (await blocklistDeployer.deploy(
      admin.address,
      votingLockup.address
    )) as Blocklist;

    //add Blocklist address to VotingEscrow
    await votingLockup.updateBlocklist(blocklist.address);

    await govMock.approve(
      votingLockup.address,
      simpleToExactAmount(100, DEFAULT_DECIMALS)
    );
    await govMock
      .connect(other)
      .approve(
        votingLockup.address,
        simpleToExactAmount(100, DEFAULT_DECIMALS)
      );
    await govMock
      .connect(fundManager)
      .approve(
        votingLockup.address,
        simpleToExactAmount(10000, DEFAULT_DECIMALS)
      );
  };

  describe('checking balances & total supply', () => {
    before(async () => {
      await deployFresh();
    });
    describe('before any stakes are made', () => {
      it('returns balances', async () => {
        //expect(await votingLockup.staticBalanceOf(defaultUser.address)).eq(BN.from(0))
        expect(await votingLockup.balanceOf(defaultUser.address)).eq(
          BN.from(0)
        );
        expect(await votingLockup.balanceOfAt(defaultUser.address, 1)).eq(
          BN.from(0)
        );
      });
      it('returns balance at latest block', async () => {
        expect(
          await votingLockup.balanceOfAt(
            defaultUser.address,
            await latestBlockBN()
          )
        ).eq(BN.from(0));
      });
      it('returns totalSupply', async () => {
        expect(await votingLockup.totalSupply()).eq(BN.from(0));
        expect(await votingLockup.totalSupplyAt(1)).eq(BN.from(0));
      });
      it('returns totalSupply at latest block', async () => {
        expect(await votingLockup.totalSupplyAt(await latestBlockBN())).eq(
          BN.from(0)
        );
      });
    });
    describe('fetching for current block', () => {
      it('fails for balanceOfAt', async () => {
        await expect(
          votingLockup.balanceOfAt(
            defaultUser.address,
            (await latestBlockBN()) + 1
          )
        ).to.be.revertedWith('Only past block number');
      });
      it('fails for supply', async () => {
        await expect(
          votingLockup.totalSupplyAt((await latestBlockBN()) + 1)
        ).to.be.revertedWith('Only past block number');
      });
    });
  });

  interface LockedBalance {
    amount: BN;
    delegated: BN;
    end: BN;
    delegatee: string;
  }

  interface Point {
    bias: BN;
    slope: BN;
    ts: BN;
    blk?: BN;
  }

  interface ContractData {
    epoch: BN;
    userEpoch: BN;
    userLocked: LockedBalance;
    userLastPoint: Point;
    lastPoint: Point;
    senderStakingTokenBalance: BN;
    contractStakingTokenBalance: BN;
  }

  const snapshotData = async (sender = defaultUser): Promise<ContractData> => {
    const locked = await votingLockup.locked(sender.address);
    const userLastPoint = await votingLockup.getLastUserPoint(sender.address);
    const epoch = await await votingLockup.globalEpoch();
    const userEpoch = await await votingLockup.userPointEpoch(sender.address);
    const lastPoint = await votingLockup.pointHistory(epoch);
    return {
      epoch,
      userEpoch,
      userLocked: {
        amount: locked[0],
        delegated: locked[1],
        end: locked[2],
        delegatee: locked[3],
      },
      userLastPoint: {
        bias: userLastPoint[0],
        slope: userLastPoint[1],
        ts: userLastPoint[2],
      },
      lastPoint: {
        bias: lastPoint[0],
        slope: lastPoint[1],
        ts: lastPoint[2],
        blk: lastPoint[3],
      },
      senderStakingTokenBalance: await govMock.balanceOf(sender.address),
      contractStakingTokenBalance: await govMock.balanceOf(
        votingLockup.address
      ),
    };
  };

  // Flow performed with 4 stakers
  // 1 - stakes 10 for a year
  // 2 - stakes 1000 for 6 months
  //   - increases time after 3 to 12m
  // 3 - stakes 10 for 6 months
  //   - increases amount after 3
  //   - gets ejected after 6m
  // 4 - stakes 10 from 3-6 mo & exits
  // 5 - stakes 10 at start for 1 week
  describe('performing full system flow', () => {
    // let alice: Account
    // let bob: Account
    // let charlie: Account
    // let david: Account
    // let eve: Account

    const stakeAmt1 = simpleToExactAmount(10, DEFAULT_DECIMALS);
    const stakeAmt2 = simpleToExactAmount(1000, DEFAULT_DECIMALS);
    let start: BigNumber;
    let maxTime: BigNumber;
    before(async () => {
      await goToNextUnixWeekStart();
      start = await getTimestamp();
      await deployFresh(simpleToExactAmount(100, DEFAULT_DECIMALS));
      maxTime = await votingLockup.MAXTIME();
      await govMock
        .connect(fundManager)
        .transfer(alice.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(bob.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(charlie.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(david.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(eve.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(francis.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(greg.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(fundManager)
        .transfer(hank.address, simpleToExactAmount(1, 22));
      await govMock
        .connect(alice)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(bob)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(charlie)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(david)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(eve)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(francis)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(greg)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
      await govMock
        .connect(hank)
        .approve(votingLockup.address, simpleToExactAmount(100, 21));
    });
    describe('checking initial settings', () => {
      it('sets ERC20 details', async () => {
        const name = await votingLockup.name();
        const symbol = await votingLockup.symbol();
        const decimals = await votingLockup.decimals();
        const supply = await votingLockup.totalSupply();
        expect(name).eq('veToken');
        expect(symbol).eq('veToken');
        expect(decimals).eq(BN.from(DEFAULT_DECIMALS));
        expect(supply).eq(BN.from(0));
      });
    });

    const calcBias = (amount: BN, len: BN): BN => amount.div(maxTime).mul(len);

    describe('creating a lockup', () => {
      it('allows user to create a lock', async () => {
        await votingLockup
          .connect(alice)
          .createLock(stakeAmt1, start.add(ONE_YEAR));
        await votingLockup
          .connect(bob)
          .createLock(stakeAmt2, start.add(ONE_WEEK.mul(26)));
        await votingLockup
          .connect(charlie)
          .createLock(stakeAmt1, start.add(ONE_WEEK.mul(26)));
        await votingLockup
          .connect(eve)
          .createLock(stakeAmt1, start.add(ONE_WEEK));
        await votingLockup
          .connect(francis)
          .createLock(stakeAmt1, start.add(TWO_YEARS));
        await votingLockup
          .connect(greg)
          .createLock(stakeAmt1, start.add(ONE_WEEK));
        await votingLockup
          .connect(hank)
          .createLock(stakeAmt1, start.add(ONE_YEAR));

        const aliceData = await snapshotData(alice);
        const bobData = await snapshotData(bob);
        const charlieData = await snapshotData(charlie);
        const eveData = await snapshotData(eve);
        const francisData = await snapshotData(francis);

        // Bias
        assertBNClosePercent(
          aliceData.userLastPoint.bias,
          calcBias(stakeAmt1, ONE_YEAR),
          '0.4'
        );
        assertBNClosePercent(
          bobData.userLastPoint.bias,
          calcBias(stakeAmt2, ONE_WEEK.mul(26)),
          '0.4'
        );
        assertBNClosePercent(
          charlieData.userLastPoint.bias,
          calcBias(stakeAmt1, ONE_WEEK.mul(26)),
          '0.4'
        );
        assertBNClosePercent(
          eveData.userLastPoint.bias,
          calcBias(stakeAmt1, ONE_WEEK),
          '0.4'
        );
        assertBNClosePercent(
          francisData.userLastPoint.bias,
          calcBias(stakeAmt1, TWO_YEARS),
          '0.4'
        );
      });
      it('rejects if the params are wrong', async () => {
        await expect(
          votingLockup
            .connect(other)
            .createLock(BN.from(0), start.add(ONE_WEEK))
        ).to.be.revertedWith('Only non zero amount');
        // await expect(
        //   votingLockup
        //     .connect(alice)
        //     .createLock(BN.from(1), start.add(ONE_WEEK))
        // ).to.be.revertedWith('Only increase lock end');
        await expect(
          votingLockup
            .connect(other)
            .createLock(BN.from(1), start.sub(ONE_WEEK))
        ).to.be.revertedWith('Only future lock end');

        await votingLockup.connect(greg).delegate(hank.address);
        await expect(
          votingLockup
            .connect(greg)
            .createLock(BN.from(1), start.sub(TWO_YEARS))
        ).to.be.revertedWith('Delegated lock');
      });
      it('only allows creation up until END date', async () => {
        await expect(
          votingLockup
            .connect(other)
            .createLock(BN.from(1), start.add(TWO_YEARS.add(ONE_WEEK)))
        ).to.be.revertedWith('Exceeds maxtime');
      });
    });

    describe('extending lock', () => {
      before(async () => {
        await increaseTime(ONE_WEEK.mul(12));
        // Eves lock is now expired
      });
      describe('by amount', () => {
        it('fails if conditions are not met', async () => {
          await expect(
            votingLockup.connect(alice).increaseAmount(BN.from(0))
          ).to.be.revertedWith('Only non zero amount');
          await expect(
            votingLockup.connect(eve).increaseAmount(BN.from(1))
          ).to.be.revertedWith('Lock expired');
        });
        it('allows someone to increase lock amount', async () => {
          // Account with lock.end>block.timestamp but lock.amount=0
          const aliceBalanceBefore = await votingLockup.balanceOfAt(
            alice.address,
            await latestBlockBN()
          );
          await votingLockup.connect(alice).increaseAmount(stakeAmt1);
          const aliceBalanceAfter = await votingLockup.balanceOfAt(
            alice.address,
            await latestBlockBN()
          );
          assertBNClosePercent(
            aliceBalanceBefore.mul(2),
            aliceBalanceAfter,
            '0.4'
          );

          // Account with lock.end>block.timestamp and lock.amount>0
          const charlieSnapBefore = await snapshotData(charlie);
          await votingLockup.connect(charlie).increaseAmount(stakeAmt2);
          const charlieSnapAfter = await snapshotData(charlie);
        });
      });

      describe('by length', () => {
        it('fails if conditions are not met', async () => {
          await expect(
            votingLockup
              .connect(eve)
              .increaseUnlockTime((await getTimestamp()).add(ONE_WEEK))
          ).to.be.revertedWith('Lock expired');
          await expect(
            votingLockup
              .connect(david)
              .increaseUnlockTime((await getTimestamp()).add(ONE_WEEK))
          ).to.be.revertedWith('No lock');
          await expect(
            votingLockup
              .connect(alice)
              .increaseUnlockTime((await getTimestamp()).add(ONE_DAY))
          ).to.be.revertedWith('Only increase lock end');
          await expect(
            votingLockup
              .connect(bob)
              .increaseUnlockTime((await getTimestamp()).add(ONE_WEEK.mul(105)))
          ).to.be.revertedWith('Exceeds maxtime');

          await expect(
            votingLockup
              .connect(david)
              .createLock(
                stakeAmt1,
                (await getTimestamp()).add(ONE_WEEK.mul(105))
              )
          ).to.be.revertedWith('Exceeds maxtime');
        });
        it('allows user to extend lock', async () => {
          await goToNextUnixWeekStart();
          const bobSnapBefore = await snapshotData(bob);
          await votingLockup
            .connect(bob)
            .increaseUnlockTime(start.add(ONE_YEAR));

          const bobSnapAfter = await snapshotData(bob);
        });
      });
    });

    describe('trying to withdraw early or with nothing to withdraw', () => {
      it('fails', async () => {
        await expect(votingLockup.connect(alice).withdraw()).to.be.revertedWith(
          'Lock not expired'
        );
        await expect(votingLockup.connect(david).withdraw()).to.be.revertedWith(
          'No lock'
        );
      });
    });

    describe('calling public checkpoint', () => {
      // checkpoint updates point history
      it('allows anyone to call checkpoint and update the history', async () => {
        const before = await snapshotData(alice);
        await votingLockup.checkpoint();
        const after = await snapshotData(alice);

        expect(after.epoch).eq(before.epoch.add(1));
        expect(after.lastPoint.bias).lt(before.lastPoint.bias);
        expect(after.lastPoint.slope).eq(before.lastPoint.slope);
        expect(after.lastPoint.blk).eq(BN.from((await latestBlock()).number));
      });
    });

    describe('calling the getters', () => {
      // returns 0 if 0
      it('allows anyone to get last user point', async () => {
        const userLastPoint = await votingLockup.getLastUserPoint(
          alice.address
        );
        const e = await votingLockup.userPointEpoch(alice.address);
        const p = await votingLockup.userPointHistory(alice.address, e);
        expect(userLastPoint[0]).eq(p[0]);
        expect(userLastPoint[1]).eq(p[1]);
        expect(userLastPoint[2]).eq(p[2]);
      });
    });

    describe('exiting the system', () => {
      before(async () => {
        await votingLockup
          .connect(david)
          .createLock(stakeAmt1, (await getTimestamp()).add(ONE_WEEK.mul(13)));
        await increaseTime(ONE_WEEK.mul(14));
      });
      it('allows user to withdraw', async () => {
        // david withdraws
        const davidBefore = await snapshotData(david);
        await votingLockup.connect(david).withdraw();
        const davidAfter = await snapshotData(david);

        expect(davidAfter.senderStakingTokenBalance).eq(
          davidBefore.senderStakingTokenBalance.add(
            davidBefore.userLocked.amount
          )
        );
        expect(davidAfter.userLastPoint.bias).eq(BN.from(0));
        expect(davidAfter.userLastPoint.slope).eq(BN.from(0));
        expect(davidAfter.userLocked.amount).eq(BN.from(0));
        expect(davidAfter.userLocked.end).eq(BN.from(0));
      });

      it('fully exits the system', async () => {
        // eve exits
        const eveBefore = await snapshotData(eve);
        await votingLockup.connect(eve).withdraw();
        const eveAfter = await snapshotData(eve);

        expect(eveAfter.senderStakingTokenBalance).eq(
          eveBefore.senderStakingTokenBalance.add(eveBefore.userLocked.amount)
        );
        expect(eveAfter.userLastPoint.bias).eq(BN.from(0));
        expect(eveAfter.userLastPoint.slope).eq(BN.from(0));
        expect(eveAfter.userLocked.amount).eq(BN.from(0));
        expect(eveAfter.userLocked.end).eq(BN.from(0));

        await increaseTime(ONE_WEEK.mul(77));
        const francisBefore = await snapshotData(francis);
        await votingLockup.connect(francis).withdraw();
        const francisAfter = await snapshotData(francis);

        expect(francisAfter.senderStakingTokenBalance).eq(
          francisBefore.senderStakingTokenBalance.add(
            francisBefore.userLocked.amount
          )
        );
        expect(francisAfter.userLastPoint.bias).eq(BN.from(0));
        expect(francisAfter.userLastPoint.slope).eq(BN.from(0));
        expect(francisAfter.userLocked.amount).eq(BN.from(0));
        expect(francisAfter.userLocked.end).eq(BN.from(0));
      });
    });
  });

  // Integration test ported from
  // https://github.com/curvefi/curve-dao-contracts/blob/master/tests/integration/VotingEscrow/test_votingLockup.py
  describe('testing voting powers changing', () => {
    before(async () => {
      await deployFresh();
    });

    /**
     *
     * Test voting power in the following scenario.
     * Alice:
     * ~~~~~~~
     * ^
     * | *       *
     * | | \     |  \
     * | |  \    |    \
     * +-+---+---+------+---> t
     *
     * Bob:
     * ~~~~~~~
     * ^
     * |         *
     * |         | \
     * |         |  \
     * +-+---+---+---+--+---> t
     *
     * Alice has 100% of voting power in the first period.
     * She has 2/3 power at the start of 2nd period, with Bob having 1/2 power
     * (due to smaller locktime).
     * Alice's power grows to 100% by Bob's unlock.
     *
     * Checking that totalSupply is appropriate.
     *
     * After the test is done, check all over again with balanceOfAt / totalSupplyAt
     *
     */

    it('calculates voting weights on a rolling basis', async () => {
      /**
       * SETUP
       */
      const MAXTIME = await votingLockup.MAXTIME();
      const tolerance = '0.04'; // 0.04% | 0.00004 | 4e14
      const amount = simpleToExactAmount(1000, DEFAULT_DECIMALS);
      await govMock.connect(fundManager).transfer(alice.address, amount.mul(5));
      await govMock.connect(fundManager).transfer(bob.address, amount.mul(5));
      const stages: any = {};

      await govMock.connect(alice).approve(votingLockup.address, amount.mul(5));
      await govMock.connect(bob).approve(votingLockup.address, amount.mul(5));

      expect(await votingLockup.totalSupply()).eq(BN.from(0));
      expect(await votingLockup.balanceOf(alice.address)).eq(BN.from(0));
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));

      /**
       * BEGIN PERIOD 1
       * Move to timing which is good for testing - beginning of a UTC week
       * Fund the pool
       */

      await goToNextUnixWeekStart();
      await increaseTime(ONE_HOUR);

      stages['before_deposits'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      await votingLockup
        .connect(alice)
        .createLock(amount, (await getTimestamp()).add(ONE_WEEK.add(1)));
      stages['alice_deposit'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      await increaseTime(ONE_HOUR);
      await advanceBlock();
      assertBNClosePercent(
        await votingLockup.balanceOf(alice.address),
        amount.div(MAXTIME).mul(ONE_WEEK.sub(ONE_HOUR.mul(2))),
        tolerance
      );
      assertBNClosePercent(
        await votingLockup.totalSupply(),
        amount.div(MAXTIME).mul(ONE_WEEK.sub(ONE_HOUR.mul(2))),
        tolerance
      );
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));
      let t0 = await getTimestamp();
      let dt = BN.from(0);

      stages['alice_in_0'] = [];
      stages['alice_in_0'].push([
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ]);

      /**
       * Measure Alice's decay over whole week
       */
      for (let i = 0; i < 7; i += 1) {
        for (let j = 0; j < 24; j += 1) {
          await increaseTime(ONE_HOUR);
          await advanceBlock();
        }
        dt = (await getTimestamp()).sub(t0);
        assertBNClosePercent(
          await votingLockup.totalSupply(),
          amount
            .div(MAXTIME)
            .mul(maximum(ONE_WEEK.sub(ONE_HOUR.mul(2)).sub(dt), BN.from(0))),
          tolerance
        );
        assertBNClosePercent(
          await votingLockup.balanceOf(alice.address),
          amount
            .div(MAXTIME)
            .mul(maximum(ONE_WEEK.sub(ONE_HOUR.mul(2)).sub(dt), BN.from(0))),
          tolerance
        );
        expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));
        stages['alice_in_0'].push([
          BN.from((await latestBlock()).number),
          await getTimestamp(),
        ]);
      }

      await increaseTime(ONE_HOUR);

      expect(await votingLockup.balanceOf(alice.address)).eq(BN.from(0));

      await votingLockup.connect(alice).withdraw();

      stages['alice_withdraw'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];
      expect(await votingLockup.totalSupply()).eq(BN.from(0));
      expect(await votingLockup.balanceOf(alice.address)).eq(BN.from(0));
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));

      await increaseTime(ONE_HOUR);
      await advanceBlock();

      /**
       * BEGIN PERIOD 2
       * Next week (for round counting)
       */
      await goToNextUnixWeekStart();

      await votingLockup
        .connect(alice)
        .createLock(amount, (await getTimestamp()).add(ONE_WEEK.mul(2)));
      stages['alice_deposit_2'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      assertBNClosePercent(
        await votingLockup.totalSupply(),
        amount.div(MAXTIME).mul(2).mul(ONE_WEEK),
        tolerance
      );
      assertBNClosePercent(
        await votingLockup.balanceOf(alice.address),
        amount.div(MAXTIME).mul(2).mul(ONE_WEEK),
        tolerance
      );
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));

      await votingLockup
        .connect(bob)
        .createLock(amount, (await getTimestamp()).add(ONE_WEEK.add(1)));
      stages['bob_deposit_2'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      assertBNClosePercent(
        await votingLockup.totalSupply(),
        amount.div(MAXTIME).mul(3).mul(ONE_WEEK),
        tolerance
      );
      assertBNClosePercent(
        await votingLockup.balanceOf(alice.address),
        amount.div(MAXTIME).mul(2).mul(ONE_WEEK),
        tolerance
      );
      assertBNClosePercent(
        await votingLockup.balanceOf(bob.address),
        amount.div(MAXTIME).mul(ONE_WEEK),
        tolerance
      );

      t0 = await getTimestamp();
      await increaseTime(ONE_HOUR);
      await advanceBlock();

      let w_alice = BN.from(0);
      let w_total = BN.from(0);
      let w_bob = BN.from(0);

      stages['alice_bob_in_2'] = [];
      // Beginning of week: weight 3
      // End of week: weight 1
      for (let i = 0; i < 7; i += 1) {
        for (let j = 0; j < 24; j += 1) {
          await increaseTime(ONE_HOUR);
          await advanceBlock();
        }
        dt = (await getTimestamp()).sub(t0);
        const b = BN.from((await latestBlock()).number);
        w_total = await votingLockup.totalSupplyAt(b);
        w_alice = await votingLockup.balanceOfAt(alice.address, b);
        w_bob = await votingLockup.balanceOfAt(bob.address, b);
        expect(w_total).eq(w_alice.add(w_bob));
        assertBNClosePercent(
          w_alice,
          amount.div(MAXTIME).mul(maximum(ONE_WEEK.mul(2).sub(dt), BN.from(0))),
          tolerance
        );
        assertBNClosePercent(
          w_bob,
          amount.div(MAXTIME).mul(maximum(ONE_WEEK.sub(dt), BN.from(0))),
          tolerance
        );
        stages['alice_bob_in_2'].push([
          BN.from((await latestBlock()).number),
          await getTimestamp(),
        ]);
      }

      await increaseTime(ONE_HOUR);
      await advanceBlock();

      await votingLockup.connect(bob).withdraw();
      t0 = await getTimestamp();
      stages['bob_withdraw_1'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];
      w_total = await votingLockup.totalSupply();
      w_alice = await votingLockup.balanceOf(alice.address);
      expect(w_alice).eq(w_total);

      assertBNClosePercent(
        w_total,
        amount.div(MAXTIME).mul(ONE_WEEK.sub(ONE_HOUR.mul(2))),
        tolerance
      );
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));

      await increaseTime(ONE_HOUR);
      await advanceBlock();

      stages['alice_in_2'] = [];
      for (let i = 0; i < 7; i += 1) {
        for (let j = 0; j < 24; j += 1) {
          await increaseTime(ONE_HOUR);
          await advanceBlock();
        }
        dt = (await getTimestamp()).sub(t0);
        w_total = await votingLockup.totalSupply();
        w_alice = await votingLockup.balanceOf(alice.address);
        expect(w_total).eq(w_alice);
        assertBNClosePercent(
          w_total,
          amount
            .div(MAXTIME)
            .mul(
              maximum(
                ONE_WEEK.sub(dt).sub(ONE_HOUR.mul(37).div(DEFAULT_DECIMALS)),
                BN.from(0)
              )
            ),
          isCoverage ? '1' : '0.04'
        );
        expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));
        stages['alice_in_2'].push([
          BN.from((await latestBlock()).number),
          await getTimestamp(),
        ]);
      }

      await votingLockup.connect(alice).withdraw();
      stages['alice_withdraw_2'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      await increaseTime(ONE_HOUR);
      await advanceBlock();

      stages['bob_withdraw_2'] = [
        BN.from((await latestBlock()).number),
        await getTimestamp(),
      ];

      expect(await votingLockup.totalSupply()).eq(BN.from(0));
      expect(await votingLockup.balanceOf(alice.address)).eq(BN.from(0));
      expect(await votingLockup.balanceOf(bob.address)).eq(BN.from(0));

      /**
       * END OF INTERACTION
       * BEGIN HISTORICAL ANALYSIS USING BALANCEOFAT
       */
      expect(
        await votingLockup.balanceOfAt(
          alice.address,
          stages['before_deposits'][0]
        )
      ).eq(BN.from(0));
      expect(
        await votingLockup.balanceOfAt(
          bob.address,
          stages['before_deposits'][0]
        )
      ).eq(BN.from(0));
      expect(await votingLockup.totalSupplyAt(stages['before_deposits'][0])).eq(
        BN.from(0)
      );

      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['alice_deposit'][0]
      );
      assertBNClosePercent(
        w_alice,
        amount.div(MAXTIME).mul(ONE_WEEK.sub(ONE_HOUR)),
        tolerance
      );
      expect(
        await votingLockup.balanceOfAt(bob.address, stages['alice_deposit'][0])
      ).eq(BN.from(0));
      w_total = await votingLockup.totalSupplyAt(stages['alice_deposit'][0]);
      expect(w_alice).eq(w_total);

      for (let i = 0; i < stages['alice_in_0'].length; i += 1) {
        const [block] = stages['alice_in_0'][i];
        w_alice = await votingLockup.balanceOfAt(alice.address, block);
        w_bob = await votingLockup.balanceOfAt(bob.address, block);
        w_total = await votingLockup.totalSupplyAt(block);
        expect(w_bob).eq(BN.from(0));
        expect(w_alice).eq(w_total);
        const time_left = ONE_WEEK.mul(7 - i)
          .div(7)
          .sub(ONE_HOUR.mul(2));
        const error_1h = (ONE_HOUR.toNumber() * 100) / time_left.toNumber(); // Rounding error of 1 block is possible, and we have 1h blocks
        assertBNClosePercent(
          w_alice,
          amount.div(MAXTIME).mul(time_left),
          error_1h.toString()
        );
      }

      w_total = await votingLockup.totalSupplyAt(stages['alice_withdraw'][0]);
      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['alice_withdraw'][0]
      );
      w_bob = await votingLockup.balanceOfAt(
        bob.address,
        stages['alice_withdraw'][0]
      );
      expect(w_total).eq(BN.from(0));
      expect(w_alice).eq(BN.from(0));
      expect(w_bob).eq(BN.from(0));

      w_total = await votingLockup.totalSupplyAt(stages['alice_deposit_2'][0]);
      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['alice_deposit_2'][0]
      );
      w_bob = await votingLockup.balanceOfAt(
        bob.address,
        stages['alice_deposit_2'][0]
      );
      assertBNClosePercent(
        w_total,
        amount.div(MAXTIME).mul(2).mul(ONE_WEEK),
        tolerance
      );
      expect(w_total).eq(w_alice);
      expect(w_bob).eq(BN.from(0));

      w_total = await votingLockup.totalSupplyAt(stages['bob_deposit_2'][0]);
      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['bob_deposit_2'][0]
      );
      w_bob = await votingLockup.balanceOfAt(
        bob.address,
        stages['bob_deposit_2'][0]
      );
      expect(w_total).eq(w_alice.add(w_bob));
      assertBNClosePercent(
        w_total,
        amount.div(MAXTIME).mul(3).mul(ONE_WEEK),
        tolerance
      );
      assertBNClosePercent(
        w_alice,
        amount.div(MAXTIME).mul(2).mul(ONE_WEEK),
        tolerance
      );

      let error_1h = 0;
      [, t0] = stages['bob_deposit_2'];
      for (let i = 0; i < stages['alice_bob_in_2'].length; i += 1) {
        const [block, ts] = stages['alice_bob_in_2'][i];
        w_alice = await votingLockup.balanceOfAt(alice.address, block);
        w_bob = await votingLockup.balanceOfAt(bob.address, block);
        w_total = await votingLockup.totalSupplyAt(block);
        expect(w_total).eq(w_alice.add(w_bob));
        dt = ts.sub(t0);
        error_1h =
          (ONE_HOUR.toNumber() * 100) /
          (2 * ONE_WEEK.toNumber() - i - ONE_DAY.toNumber());
        assertBNClosePercent(
          w_alice,
          amount.div(MAXTIME).mul(maximum(ONE_WEEK.mul(2).sub(dt), BN.from(0))),
          error_1h.toString()
        );
        assertBNClosePercent(
          w_bob,
          amount.div(MAXTIME).mul(maximum(ONE_WEEK.sub(dt), BN.from(0))),
          error_1h.toString()
        );
      }
      w_total = await votingLockup.totalSupplyAt(stages['bob_withdraw_1'][0]);
      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['bob_withdraw_1'][0]
      );
      w_bob = await votingLockup.balanceOfAt(
        bob.address,
        stages['bob_withdraw_1'][0]
      );
      expect(w_total).eq(w_alice);
      assertBNClosePercent(
        w_total,
        amount.div(MAXTIME).mul(ONE_WEEK.sub(ONE_HOUR.mul(2))),
        tolerance
      );
      expect(w_bob).eq(BN.from(0));
      [, t0] = stages['bob_withdraw_1'];
      for (let i = 0; i < stages['alice_in_2'].length; i += 1) {
        const [block, ts] = stages['alice_in_2'][i];
        w_alice = await votingLockup.balanceOfAt(alice.address, block);
        w_bob = await votingLockup.balanceOfAt(bob.address, block);
        w_total = await votingLockup.totalSupplyAt(block);
        expect(w_total).eq(w_alice);
        expect(w_bob).eq(BN.from(0));
        dt = ts.sub(t0);
        error_1h =
          (ONE_HOUR.toNumber() * 100) /
          (ONE_WEEK.toNumber() - i * ONE_DAY.toNumber() + ONE_DAY.toNumber());
        assertBNClosePercent(
          w_total,
          amount
            .div(MAXTIME)
            .mul(maximum(ONE_WEEK.sub(dt).sub(ONE_HOUR.mul(2)), BN.from(0))),
          error_1h.toString()
        );
      }
      w_total = await votingLockup.totalSupplyAt(stages['bob_withdraw_2'][0]);
      w_alice = await votingLockup.balanceOfAt(
        alice.address,
        stages['bob_withdraw_2'][0]
      );
      w_bob = await votingLockup.balanceOfAt(
        bob.address,
        stages['bob_withdraw_2'][0]
      );
      expect(w_total).eq(BN.from(0));
      expect(w_alice).eq(BN.from(0));
      expect(w_bob).eq(BN.from(0));
    });
  });
});
