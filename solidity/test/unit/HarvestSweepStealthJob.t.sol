// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {HarvestSweepStealthJobForTest} from 'test/unit/ForTest/HarvestSweepStealthJobForTest.sol';
import {
  Keep3rMeteredStealthJob,
  IKeep3rV2,
  IStealthRelayer,
  IKeep3rHelper
} from 'contracts/utils/Keep3rMeteredStealthJob.sol';

import {IV2KeeperJob, IBaseStrategy} from 'contracts/V2KeeperJobPacked.sol';
import {IBaseErrors} from 'interfaces/utils/IBaseErrors.sol';

import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @notice Unit test of the HarvestSweepStealthJob
 *
 */

contract HarvestSweepStealthJobTest is Test {
  event WorkCooldownSet(uint256 _workCooldown);
  event Keep3rSet(address _keep3r);
  event Keep3rHelperSet(address _keep3rHelper);
  event StealthRelayerSet(address _stealthRelayer);
  event Keep3rRequirementsSet(address _bond, uint256 _minBond, uint256 _earned, uint256 _age);
  event OnlyEOASet(bool _onlyEOA);
  event GasBonusSet(uint256 _gasBonus);
  event GasMultiplierSet(uint256 _gasMultiplier);

  /*///////////////////////////////////////////////////////////////
                        Global test variables                  
  //////////////////////////////////////////////////////////////*/

  uint256 public constant COOLDOWN = 600;

  address public governor = makeAddr('governor');
  address public strategy = makeAddr('strategy');
  address public v2Keeper = makeAddr('v2Keeper');
  address public mechanicsRegistry = makeAddr('mechanicsRegistry');
  address public stealthRelayer = makeAddr('stealthRelayer');
  address public keep3r = makeAddr('keep3r');
  address public keep3rHelper = makeAddr('keep3rHelper');

  HarvestSweepStealthJobForTest public harvestJob;

  /*///////////////////////////////////////////////////////////////
                        Setup: mock and deploy                  
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    vm.etch(strategy, hex'69');
    vm.etch(v2Keeper, hex'69');
    vm.etch(mechanicsRegistry, hex'69');
    vm.etch(stealthRelayer, hex'69');
    vm.etch(keep3r, hex'69');
    vm.etch(keep3rHelper, hex'69');

    harvestJob = new HarvestSweepStealthJobForTest({
      _governor: governor,
      _mechanicsRegistry: mechanicsRegistry,
      _stealthRelayer: stealthRelayer,
      _v2Keeper: v2Keeper,
      _workCooldown: COOLDOWN,
      _keep3r: keep3r,
      _keep3rHelper: keep3rHelper,
      _bond: address(0),
      _minBond: 0,
      _earned: 0,
      _age: 0,
      _onlyEOA: false
    });

    vm.prank(governor);
    harvestJob.addStrategy(strategy, 0);

    // Set a timestamp for time-dependant test (avoid weird underflow when block.timestamp=0)
    vm.warp(123_456_789);
  }

  /*///////////////////////////////////////////////////////////////
                        constructor()                  
  //////////////////////////////////////////////////////////////*/

  function test_constructor_shouldConstruct(
    address _jamesBond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age,
    bool _onlyEOA
  ) external {
    // Deploy from a random address, to get the future deployment address
    vm.startPrank(governor);
    address _nextDeploymentAddress = computeCreateAddress(governor, vm.getNonce(governor));

    // Check: correct events?
    vm.expectEmit(true, true, true, true, _nextDeploymentAddress);
    emit Keep3rSet(keep3r);

    vm.expectEmit(true, true, true, true, _nextDeploymentAddress);
    emit Keep3rHelperSet(keep3rHelper);

    vm.expectEmit(true, true, true, true, _nextDeploymentAddress);
    emit StealthRelayerSet(stealthRelayer);

    vm.expectEmit(true, true, true, true, _nextDeploymentAddress);
    emit Keep3rRequirementsSet(_jamesBond, _minBond, _earned, _age);

    vm.expectEmit(true, true, true, true, _nextDeploymentAddress);
    emit OnlyEOASet(_onlyEOA);

    // Deploy the job
    harvestJob = new HarvestSweepStealthJobForTest({
      _governor: governor,
      _mechanicsRegistry: mechanicsRegistry,
      _stealthRelayer: stealthRelayer,
      _v2Keeper: v2Keeper,
      _workCooldown: COOLDOWN,
      _keep3r: keep3r,
      _keep3rHelper: keep3rHelper,
      _bond: _jamesBond, // Don't hate me
      _minBond: _minBond,
      _earned: _earned,
      _age: _age,
      _onlyEOA: _onlyEOA
    });

    vm.stopPrank();

    // Check: correct state?
    assertEq(harvestJob.governor(), governor);
    assertEq(harvestJob.mechanicsRegistry(), mechanicsRegistry);
    assertEq(harvestJob.stealthRelayer(), stealthRelayer);
    assertEq(address(harvestJob.v2Keeper()), v2Keeper);
    assertEq(harvestJob.workCooldown(), COOLDOWN);
    assertEq(harvestJob.keep3r(), keep3r);
    assertEq(harvestJob.keep3rHelper(), keep3rHelper);
    assertEq(harvestJob.requiredBond(), _jamesBond);
    assertEq(harvestJob.requiredMinBond(), _minBond);
    assertEq(harvestJob.requiredEarnings(), _earned);
    assertEq(harvestJob.requiredAge(), _age);
    assertEq(harvestJob.onlyEOA(), _onlyEOA);
  }

  function test_constructor_shouldReduceGasMultiplierBy15Percents() external {
    // Check: correct state?
    assertEq(harvestJob.gasMultiplier(), 10_000 * 85 / 100);
  }

  /*///////////////////////////////////////////////////////////////
                        workable()                  
  //////////////////////////////////////////////////////////////*/

  // During cooldown:
  function test_workable_shouldReturnFalseIfInCooldown() external {
    harvestJob.internalSetLastWorkAt(strategy, block.timestamp - COOLDOWN + 1);
    assertEq(harvestJob.workable(strategy), false);
  }

  function test_workable_revertIfStrategyNotAdded(address _nonExistingStrategy) external {
    vm.assume(_nonExistingStrategy != strategy);
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    harvestJob.workable(_nonExistingStrategy);
  }

  // Outside cooldown:
  function test_workable_shouldReturnStrategyResponseIfNotInSweep(bool _strategyStatus) external {
    harvestJob.internalSetLastWorkAt(strategy, block.timestamp - COOLDOWN - 1);

    vm.mockCall(
      keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(block.timestamp - COOLDOWN - 10)
    );
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(604_800));

    vm.prank(governor);
    harvestJob.setCreditWindow(3600);

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(_strategyStatus));

    assertEq(harvestJob.workable(strategy), _strategyStatus);
  }

  /**
   * callcost(requiredAmount * gasPrice)
   */
  function test_workable_shouldCallHarvestTriggerWithCorrectParam(bool _strategyStatus) external {
    harvestJob.internalSetLastWorkAt(strategy, block.timestamp - COOLDOWN - 1);

    vm.mockCall(
      keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(block.timestamp - COOLDOWN - 10)
    );
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(604_800));

    vm.prank(governor);
    harvestJob.setCreditWindow(3600);

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(_strategyStatus));

    assertEq(harvestJob.workable(strategy), _strategyStatus);
  }

  function test_workable_shouldReturnTrueIfHarvestTriggerFalseButSweepable() external {}
  function test_workable_shouldReturnFalseIfTriggerFalseAndSweepableFalse() external {}

  /*///////////////////////////////////////////////////////////////
                        work()                  
  //////////////////////////////////////////////////////////////*/

  function test_work_shouldWorkAndSetLastWorkAt() external {}

  function test_work_shouldWorkInSweepingWindow() external {}

  function test_work_shouldWorkOnlyOnceInSweepingWindow() external {}

  function test_work_revertIfCallerIsNotAKeeper() external {}

  function test_work_revertIfCallerNotEOAIfSet() external {}

  function test_work_revertIfNotWorkable() external {}

  /*///////////////////////////////////////////////////////////////
                        forceWorkUnsafe()                  
  //////////////////////////////////////////////////////////////*/

  function test_forceWorkUnsafe_shouldWork() external {}

  /*///////////////////////////////////////////////////////////////
                        forceWork()                  
  //////////////////////////////////////////////////////////////*/

  function test_forceWork_shouldWork() external {}

  function test_forceWork_revertIfCallerIsNotGovernanceOrMech() external {}
}
