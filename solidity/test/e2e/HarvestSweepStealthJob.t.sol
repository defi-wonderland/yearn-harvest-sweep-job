// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

// solhint-disable-next-line defi-wonderland/import-statement-format
import 'test/utils/keeper_constants.sol';

import {HarvestSweepStealthJob} from 'contracts/HarvestSweepStealthJob.sol';

import {IBaseStrategy} from 'interfaces/external/IBaseStrategy.sol';
import {IKeep3rV2} from 'interfaces/external/IKeep3rV2.sol';
import {IStealthRelayer} from 'interfaces/external/IStealthRelayer.sol';
import {IStealthVault} from 'interfaces/external/IStealthVault.sol';
import {IV2Keeper} from 'interfaces/external/IV2Keeper.sol';

import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {OracleLibrary} from '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @dev The tests for gas and reward are merged into the old hardhat repo, these are strictly
 *      workability ones
 *
 * name: 'StargateUSDCStaker',
 *     address: '0x7c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     block: 15514011,
 *     callData: '0x36df7ea50000000000000000000000007c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     txHash: '0x5026697c0516aabb8f9790669fa983015aa1169dc8c9bb6c478f9e7d168b8855',
 */
contract E2EHarvestSweepStealthJob is Test {
  /*///////////////////////////////////////////////////////////////
                        Events tested                  
  //////////////////////////////////////////////////////////////*/
  event KeeperWorked(address _strategy);
  event Harvested(uint256 _profit, uint256 _loss, uint256 _debtPayment, uint256 _debtOutstanding);
  event SweepingOldStrategy(address indexed _strategy);

  /*///////////////////////////////////////////////////////////////
                        Global test parameters                  
  //////////////////////////////////////////////////////////////*/

  uint256 public constant FORK_BLOCK_NUMBER = 15_514_011;

  address public constant STRATEGY = 0x7C85c0a8E2a45EefF98A10b6037f70daf714B7cf;
  address public constant proxyGovernor = KP3R_V1_PROXY_GOVERNANCE_ADDRESS;
  address public constant v2KeeperGovernor = V2_KEEPER_GOVERNOR;

  IKeep3rV2 public constant keep3rV2 = IKeep3rV2(KEEP3R_V2);
  IV2Keeper public constant v2Keeper = IV2Keeper(V2_KEEPER);
  IStealthRelayer public constant stealthRelayer = IStealthRelayer(STEALTH_RELAYER);
  IStealthVault public constant stealthVault = IStealthVault(STEALTH_VAULT);
  IERC20 public constant kprToken = IERC20(KP3R_V1_ADDRESS);
  IBaseStrategy public constant strategy = IBaseStrategy(STRATEGY);

  address public keeper = makeAddr('keeper');
  HarvestSweepStealthJob public job;

  /*///////////////////////////////////////////////////////////////
          setup: fork mainnet, deploy and activate keeper
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK_NUMBER);

    // Set block.basefee to 50 gwei
    vm.fee(50 * 10 ** 9);

    // Gib ETH
    deal(proxyGovernor, 1000 ether);
    deal(v2KeeperGovernor, 1000 ether);
    deal(address(keeper), 1000 ether);

    // Gib $KPR
    deal(KP3R_V1_ADDRESS, keeper, MIN_BOND + MAX_BOND);

    job = new HarvestSweepStealthJob(
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

    // Set the scene: add the job to the keepers, bond the keeper, activate the keeper
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
    v2Keeper.addJob(address(job));
    stealthRelayer.addJob(address(job));
    keep3rV2.addJob(address(job));
    vm.stopPrank();

    deal(KP3R_LP_TOKEN, proxyGovernor, 100 ether);

    vm.startPrank(proxyGovernor);
    IERC20(KP3R_LP_TOKEN).approve(address(keep3rV2), type(uint256).max);
    keep3rV2.addLiquidityToJob(address(job), KP3R_LP_TOKEN, 5 ether);
    vm.stopPrank();
  }

  /*///////////////////////////////////////////////////////////////
                              work()
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Test if a strategy which is profitable is workable
   */
  function testShouldBeWorkableWhenProfitable() external {
    // Add the strategy with a required amount low enough to be profitable
    vm.prank(v2KeeperGovernor);
    job.addStrategy(STRATEGY, 10_000);

    uint256 _lastReward = keep3rV2.rewardedAt(address(job));
    uint256 _rewardPeriodTime = keep3rV2.rewardPeriodTime();

    // Warp to the very begining of the next period (for bonded )
    vm.warp(_lastReward + _rewardPeriodTime + 1);

    // Check: Correct events emitted?
    vm.expectEmit(true, true, true, true, address(STRATEGY));
    emit Harvested(0, 1, 0, 0);

    vm.expectEmit(true, true, true, true, address(job));
    emit KeeperWorked(STRATEGY);

    // Prank both msg.sender and tx.origin
    vm.prank(keeper, keeper);

    // Work the job
    stealthRelayer.executeAndPay(
      address(job), abi.encodeWithSignature('work(address)', STRATEGY), 'random', block.number, 0
    );
  }

  /**
   * @notice Test if a strategy which is not profitable and when in the credit window is workable
   */
  function testShouldBeWorkableWhenInCreditWindow() external {
    // Add the strategy, with the same required amount but a 150gwei gas price
    // Using the same fork, so we know this strategy would have been worked if profitable
    vm.prank(v2KeeperGovernor);
    job.addStrategy(STRATEGY, 10_000);
    vm.fee(150 * 10 ** 9);

    uint256 _lastReward = keep3rV2.rewardedAt(address(job));
    uint256 _rewardPeriodTime = keep3rV2.rewardPeriodTime();

    // Warp at the end of a credit window
    vm.warp(_lastReward + _rewardPeriodTime + (_rewardPeriodTime - 1));

    // Check: Correct events emitted?
    vm.expectEmit(true, true, true, true, address(STRATEGY));
    emit Harvested(0, 1, 0, 0);

    vm.expectEmit(true, true, true, true, address(job));
    emit KeeperWorked(STRATEGY);

    vm.expectEmit(true, true, true, true);
    emit SweepingOldStrategy(STRATEGY);

    // Prank both msg.sender and tx.origin (EOA check)
    vm.startPrank(keeper, keeper);

    // Work the job
    stealthRelayer.executeAndPay(
      address(job), abi.encodeWithSignature('work(address)', STRATEGY), 'random', block.number, 0
    );
  }

  /**
   * @notice Test if a strategy which is not profitable and when in the credit window is workable
   *         but revert if costing too much (this is a small spot in this setting as reward credit is huge)
   */
  function testRevertIfUsingLiquidityCreditDuringSweeping() external {
    // Add the strategy with big enough required amount and gas cost to empty the credit (while not consuming
    // all the liquidity credit as it would revert on insufficentFund() )
    vm.prank(v2KeeperGovernor);
    job.addStrategy(STRATEGY, 3_000_000);
    vm.fee(350 * 10 ** 9);

    uint256 _lastReward = keep3rV2.rewardedAt(address(job));
    uint256 _rewardPeriodTime = keep3rV2.rewardPeriodTime();

    // Warp at the end of a credit window
    vm.warp(_lastReward + _rewardPeriodTime + (_rewardPeriodTime - 1));

    // Prank both msg.sender and tx.origin (EOA check)
    vm.startPrank(keeper, keeper);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSignature('ExtraCreditUsed()'));

    // Work the job
    stealthRelayer.executeAndPay(
      address(job), abi.encodeWithSignature('work(address)', STRATEGY), 'random', block.number, 0
    );
  }
}
