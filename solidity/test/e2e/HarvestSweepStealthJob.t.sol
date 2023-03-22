// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import 'test/utils/keeper_constants.sol';

import {HarvestSweepStealthJob} from 'contracts/HarvestSweepStealthJob.sol';

import {IBaseStrategy} from 'interfaces/external/IBaseStrategy.sol';
import {IKeep3rV2} from 'interfaces/external/IKeep3rV2.sol';
import {IStealthRelayer} from 'interfaces/external/IStealthRelayer.sol';
import {IStealthVault} from 'interfaces/external/IStealthVault.sol';
import {IV2Keeper} from 'interfaces/external/IV2Keeper.sol';

import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {Test} from 'forge-std/Test.sol';

/**
 * name: 'StargateUSDCStaker',
 *     address: '0x7c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     block: 15514011,
 *     callData: '0x36df7ea50000000000000000000000007c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     txHash: '0x5026697c0516aabb8f9790669fa983015aa1169dc8c9bb6c478f9e7d168b8855',
 */
contract HarvestSweepStealthJob_E2E is Test {
  uint256 internal constant _FORK_BLOCK = 15_514_011;
  address internal constant STRATEGY = 0x7C85c0a8E2a45EefF98A10b6037f70daf714B7cf;

  address internal keeper = makeAddr('keeper');
  address internal proxyGovernor = KP3R_V1_PROXY_GOVERNANCE_ADDRESS;
  address internal v2KeeperGovernor = V2_KEEPER_GOVERNOR;

  IKeep3rV2 internal keep3rV2 = IKeep3rV2(KEEP3R_V2);
  IV2Keeper internal v2Keeper = IV2Keeper(V2_KEEPER);
  IStealthRelayer internal stealthRelayer = IStealthRelayer(STEALTH_RELAYER);
  IStealthVault internal stealthVault = IStealthVault(STEALTH_VAULT);
  IERC20 internal kprToken = IERC20(KP3R_V1_ADDRESS);
  IBaseStrategy internal strategy = IBaseStrategy(STRATEGY);

  HarvestSweepStealthJob internal _job;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    deal(proxyGovernor, 1000 ether);
    deal(v2KeeperGovernor, 1000 ether);
    deal(address(keeper), 1000 ether);

    // Gib $KPR
    deal(KP3R_V1_ADDRESS, keeper, MIN_BOND + MAX_BOND);

    _job = new HarvestSweepStealthJob(
      V2_KEEPER_GOVERNOR,
      MECHANICS_REGISTRY,
      STEALTH_RELAYER,
      V2_KEEPER,
      HARVEST_COOLDOWN,
      KEEP3R_V2,
      KEEP3R_V2_HELPER,
      BOND,
      MIN_BOND,
      EARNED,
      AGE,
      ONLY_EOA
    );

    vm.prank(proxyGovernor);
    keep3rV2.setBondTime(0);

    vm.startPrank(keeper);
    kprToken.approve(KEEP3R_V2, type(uint256).max);
    keep3rV2.bond(address(kprToken), MIN_BOND);

    vm.warp(block.timestamp + 1);
    keep3rV2.activate(address(kprToken));

    stealthVault.bond{value: 1 ether}();
    stealthVault.enableStealthContract(address(stealthRelayer));
    vm.stopPrank();

    vm.startPrank(v2KeeperGovernor);
    v2Keeper.addJob(address(_job));
    stealthRelayer.addJob(address(_job));
    keep3rV2.addJob(address(_job));
    vm.stopPrank();

    vm.prank(proxyGovernor);
    keep3rV2.forceLiquidityCreditsToJob(address(_job), 10 ether);

    vm.prank(v2KeeperGovernor);
    _job.addStrategy(STRATEGY, 0);

    deal(address(_job), 1000 ether);
    vm.prank(address(_job));
    keep3rV2.bondedPayment(keeper, 420);
  }

  /**
   * @notice Test if a strategy which is profitable is workable
   */
  function testShouldBeWorkableWhenProfitable() external {
    vm.fee(50 * 10 ** 9);

    vm.prank(keeper, keeper);
    stealthRelayer.executeAndPay(
      address(_job), abi.encodeWithSignature('work(address)', STRATEGY), 'random', block.number, 0
    );
  }

  /**
   * @notice Test if a strategy which is not profitable and when not in the credit window is not workable
   */
  function testShouldBeNonWorkableWhenOutsideCreditWindow() external {}

  /**
   * @notice Test if a strategy which is not profitable and when in the credit window is workable
   */
  function testShouldBeWorkableWhenInCreditWindow() external {}
}
