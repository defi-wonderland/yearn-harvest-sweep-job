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
 * name: 'StargateUSDCStaker',
 *     address: '0x7c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     block: 15514011,
 *     callData: '0x36df7ea50000000000000000000000007c85c0a8e2a45eeff98a10b6037f70daf714b7cf',
 *     txHash: '0x5026697c0516aabb8f9790669fa983015aa1169dc8c9bb6c478f9e7d168b8855',
 */
contract E2EHarvestSweepStealthJob is Test {
  // Events to test:
  event KeeperWorked(address _strategy);
  event Harvested(uint256 _profit, uint256 _loss, uint256 _debtPayment, uint256 _debtOutstanding);

  // forgefmt:disable-start
  uint256         public constant FORK_BLOCK       = 15_514_011;

  address         public constant STRATEGY         = 0x7C85c0a8E2a45EefF98A10b6037f70daf714B7cf;
  address         public constant proxyGovernor    = KP3R_V1_PROXY_GOVERNANCE_ADDRESS;
  address         public constant v2KeeperGovernor = V2_KEEPER_GOVERNOR;
  
  IKeep3rV2       public constant keep3rV2         = IKeep3rV2(KEEP3R_V2);
  IV2Keeper       public constant v2Keeper         = IV2Keeper(V2_KEEPER);
  IStealthRelayer public constant stealthRelayer   = IStealthRelayer(STEALTH_RELAYER);
  IStealthVault   public constant stealthVault     = IStealthVault(STEALTH_VAULT);
  IERC20          public constant kprToken         = IERC20(KP3R_V1_ADDRESS);
  IBaseStrategy   public constant strategy         = IBaseStrategy(STRATEGY);
  // forgefmt:disable-end

  address public keeper = makeAddr('keeper');
  HarvestSweepStealthJob public job;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

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

    vm.prank(proxyGovernor);
    keep3rV2.forceLiquidityCreditsToJob(address(job), 10 ether);

    vm.prank(v2KeeperGovernor);
    job.addStrategy(STRATEGY, 0);

    deal(address(job), 1000 ether);
    vm.prank(address(job));
    keep3rV2.bondedPayment(keeper, 420);
  }

  /**
   * @notice Test if a strategy which is profitable is workable
   */
  function testShouldBeWorkableWhenProfitable() external {
    // Set block.basefee to 50 gwei
    vm.fee(50 * 10 ** 9);

    // Keep track of the work completed previously
    uint256 _previousWorkCompleted = keep3rV2.workCompleted(keeper);

    // Check: Correct events emitted?
    vm.expectEmit(true, true, true, true, address(STRATEGY));
    emit Harvested(0, 1, 0, 0);

    vm.expectEmit(true, true, true, true, address(job));
    emit KeeperWorked(STRATEGY);

    // Prank both msg.sender and tx.origin
    vm.prank(keeper, keeper);

    // Track the gas consumption
    uint256 _gasUsed = gasleft();

    // Work the job
    stealthRelayer.executeAndPay(
      address(job), abi.encodeWithSignature('work(address)', STRATEGY), 'random', block.number, 0
    );

    // Adding the 21k of a normal tx from an EOA
    _gasUsed = _gasUsed - gasleft();

    // ------------------------------------
    // TS test: expected reward is x120/100 ?

    // Check: Received correct reward?
    uint256 _expectedReward = _getExpectedReward(_gasUsed);
    assertApproxEqAbs(keep3rV2.workCompleted(keeper) - _previousWorkCompleted, _expectedReward, 0.015 ether); // 0.015KPR

    emit log_string('work completed ');
    emit log_uint(keep3rV2.workCompleted(keeper) - _previousWorkCompleted);
    emit log_string('expected reward ');
    emit log_uint(_expectedReward);

    emit log_string('gas consumed * 52gwei ');
    emit log_uint(((541_474) + 21_000) * 52 * 10 ** 9);

    uint32 _twapTime = 600;
    (int24 _meanTick,) = OracleLibrary.consult(KP3R_WETH_V3_POOL_ADDRESS, _twapTime);

    emit log_string('quote at tick for work completed ');
    emit log_uint(
      OracleLibrary.getQuoteAtTick(
        _meanTick,
        uint128(keep3rV2.workCompleted(keeper) - _previousWorkCompleted),
        KP3R_WETH_V3_POOL_ADDRESS,
        WETH_ADDRESS
      )
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

  function _getExpectedReward(uint256 _gasUsed) internal view returns (uint256 _expectedReward) {
    // Get the twap
    uint32 _twapTime = 600;
    (int24 _meanTick,) = OracleLibrary.consult(KP3R_WETH_V3_POOL_ADDRESS, _twapTime);

    _expectedReward = OracleLibrary.getQuoteAtTick(
      _meanTick, uint128(_gasUsed * block.basefee), WETH_ADDRESS, KP3R_WETH_V3_POOL_ADDRESS
    );
  }
}
