// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IV2KeeperJob, IV2Keeper, IBaseStrategy} from 'contracts/V2KeeperJobPacked.sol';
import {
  Keep3rMeteredStealthJob,
  IKeep3rV2,
  IStealthRelayer,
  IKeep3rHelper
} from 'contracts/utils/Keep3rMeteredStealthJob.sol';
import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';
import {IBaseErrors} from 'interfaces/utils/IBaseErrors.sol';
import {IKeep3rJob} from 'interfaces/utils/IKeep3rJob.sol';
import {IOnlyEOA} from 'interfaces/utils/IOnlyEOA.sol';
import {HarvestSweepStealthJobForTest} from 'test/unit/ForTest/HarvestSweepStealthJobForTest.sol';

import {IMechanicsRegistry} from '@yearn-mechanics/contract-utils/solidity/interfaces/mechanics/IMechanicsRegistry.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @notice Unit test of the HarvestSweepStealthJob
 *
 * @dev The function starting with "internal" from the ForTest contract are only in this test contract helper
 */

contract HarvestSweepStealthJobTest is Test {
  /*///////////////////////////////////////////////////////////////
                        Events tested                  
  //////////////////////////////////////////////////////////////*/

  event KeeperWorked(address _strategy);
  event WorkCooldownSet(uint256 _workCooldown);
  event Keep3rSet(address _keep3r);
  event Keep3rHelperSet(address _keep3rHelper);
  event StealthRelayerSet(address _stealthRelayer);
  event Keep3rRequirementsSet(address _bond, uint256 _minBond, uint256 _earned, uint256 _age);
  event OnlyEOASet(bool _onlyEOA);
  event ForceWorked(address _strategy);
  event SweepingOldStrategy(address indexed _strategy);

  /*///////////////////////////////////////////////////////////////
                        Global test parameters                  
  //////////////////////////////////////////////////////////////*/

  uint256 public constant COOLDOWN = 600;

  // EOA:
  address public randomKeeper = makeAddr('randomKeeper');
  address public governor = makeAddr('governor');

  // Mock:
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
    // Avoid 0 default timestamp and block number
    vm.warp(1_679_861_835);
    vm.roll(16_913_921);

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
  }

  /*///////////////////////////////////////////////////////////////
                        constructor()                  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Should deploy, emit events and set the correct job parameters
   */
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

  /**
   * @notice
   */
  function test_constructor_shouldReduceGasMultiplierBy15Percents() external {
    // Check: correct state?
    assertEq(harvestJob.gasMultiplier(), 10_000 * 85 / 100);
  }

  /*///////////////////////////////////////////////////////////////
                        workable()                  
  //////////////////////////////////////////////////////////////*/

  // During cooldown:

  /**
   * @notice Cannot work a strategy during its cooldown
   */
  function test_workable_shouldReturnFalseIfInCooldown() external {
    // Set last work as 1 second after the begining of the cooldown
    harvestJob.internalSetLastWorkAt(strategy, block.timestamp - COOLDOWN + 1);
    assertEq(harvestJob.workable(strategy), false);
  }

  /**
   * @notice Revert if trying to get the status of a strategy that is not added
   */
  function test_workable_revertIfStrategyNotAdded(address _nonExistingStrategy) external {
    vm.assume(_nonExistingStrategy != strategy);
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    harvestJob.workable(_nonExistingStrategy);
  }

  // Outside cooldown:

  /**
   * @notice Modifier setting the state as outside a cooldown period, for `strategy`
   */
  modifier _notInCooldown() {
    // Last work was (cooldown + 1) seconds ago
    harvestJob.internalSetLastWorkAt(strategy, block.timestamp - COOLDOWN - 1);

    // Beginning of the reward cycle was at that same timestamp
    vm.mockCall(
      keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(block.timestamp - COOLDOWN - 1)
    );

    // Reward period of 1 week
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(604_800));

    // Credit window of 1 hour
    vm.prank(governor);
    harvestJob.setCreditWindow(3600);

    _;
  }

  /**
   * @notice When block.timestamp isn't in a credit window, the strategy status is returned
   */
  function test_workable_shouldReturnStrategyResponseIfNotInSweep(bool _strategyStatus) external _notInCooldown {
    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(_strategyStatus));

    assertEq(harvestJob.workable(strategy), _strategyStatus);
  }

  /**
   * @notice When harvesting a strategy, the gas cost is based on the correct parameters (ie callcost(requiredAmount * gasPrice) )
   */
  function test_workable_shouldCallHarvestTriggerWithCorrectParam(
    uint256 _requiredAmount,
    uint256 _baseFee
  ) external _notInCooldown {
    _requiredAmount = bound(_requiredAmount, 1, type(uint48).max - 1); // avoid overflow in lib
    _baseFee = bound(_baseFee, 1, (type(uint256).max - 1) / _requiredAmount); // avoid overflow in mul base*req

    harvestJob.internalSetRequiredAmount(strategy, _requiredAmount);
    harvestJob.internalSetBaseFee(_baseFee);

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(true));
    vm.expectCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector, _requiredAmount * _baseFee));
    harvestJob.workable(strategy);
  }

  /**
   * @notice When block.timestamp is in the credit window, the strategy is workable even if not profitable
   */
  function test_workable_shouldReturnTrueIfHarvestTriggerFalseButSweepable() external _notInCooldown {
    uint256 _creditWindow = 3600;
    uint256 _lastReward = block.timestamp + 604_800;
    uint256 _rewardPeriodTime = 604_800;
    uint256 _nextPeriodStartAt = _lastReward + _rewardPeriodTime;

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(false));

    // set a period starting 1 week after the lastWorkAt
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(_lastReward));

    // Set a 1 week period
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(_rewardPeriodTime));

    // Set a 1h sweep window
    vm.prank(governor);
    harvestJob.setCreditWindow(uint64(_creditWindow));

    // The initial beginning of the sweeping window is the job deployment timestamp (ie no strategy could have been worked before)
    (uint128 _deployment,,) = harvestJob.sweepingParams();

    // Set the last work at to the beginning of the sweeping window
    harvestJob.internalSetLastWorkAt(strategy, _deployment);
    vm.warp(_nextPeriodStartAt - _creditWindow + 1);

    // Check: Workable?
    assertEq(harvestJob.workable(strategy), true);

    // Set the last work at to the end of the sweeping window
    vm.warp(_nextPeriodStartAt - 1);

    // Check: workable?
    assertEq(harvestJob.workable(strategy), true);
  }

  /**
   * @notice If the strategy is not havestable and we're not in the credit window, returns false
   */
  function test_workable_shouldReturnFalseIfTriggerFalseAndSweepableFalse() external _notInCooldown {
    uint256 _creditWindow = 3600;
    uint256 _lastReward = block.timestamp + 604_800;
    uint256 _rewardPeriodTime = 604_800;
    uint256 _nextPeriodStartAt = _lastReward + _rewardPeriodTime;

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(false));

    // set a period starting 1 week after the lastWorkAt
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(_lastReward));

    // Set a 1 week period
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(_rewardPeriodTime));

    // Set a 1h sweep window
    vm.prank(governor);
    harvestJob.setCreditWindow(uint64(_creditWindow));

    (uint128 _deployment,,) = harvestJob.sweepingParams();

    // Set the last work at the begining of the 1-week reward period
    harvestJob.internalSetLastWorkAt(strategy, _deployment);
    vm.warp(_lastReward + 1);
    assertEq(harvestJob.workable(strategy), false);

    // Set the last work just before the begining of the sweeping window
    vm.warp(_nextPeriodStartAt - _creditWindow - 1);
    assertEq(harvestJob.workable(strategy), false);
  }

  /*///////////////////////////////////////////////////////////////
                        work()                  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the mock for work() calls
   */
  modifier _workSetup() {
    vm.mockCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector), abi.encode(randomKeeper));
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.isBondedKeeper.selector), abi.encode(true));
    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(true));
    vm.mockCall(v2Keeper, abi.encodeWithSelector(IV2Keeper.harvest.selector), abi.encode());
    vm.mockCall(keep3rHelper, abi.encodeWithSelector(IKeep3rHelper.getRewardAmountFor.selector), abi.encode(1));
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.bondedPayment.selector), abi.encode());
    vm.prank(governor);
    harvestJob.setCreditWindow(3600);
    _;
  }

  /**
   * @notice Test the extenal calls when work() is called
   */
  modifier _testWorkExternalCalls() {
    vm.expectCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector));
    vm.expectCall(keep3r, abi.encodeWithSelector(IKeep3rV2.isBondedKeeper.selector));
    vm.expectCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector));
    vm.expectCall(v2Keeper, abi.encodeWithSelector(IV2Keeper.harvest.selector, strategy));
    vm.expectCall(keep3rHelper, abi.encodeWithSelector(IKeep3rHelper.getRewardAmountFor.selector));
    vm.expectCall(keep3r, abi.encodeWithSelector(IKeep3rV2.bondedPayment.selector));
    _;
  }

  /**
   * @notice Should work, emit events and set lastWorkAt
   */
  function test_work_shouldWorkAndSetLastWorkAt() external _workSetup _testWorkExternalCalls {
    // Check: emit event?
    vm.expectEmit(true, true, true, true);
    emit KeeperWorked(strategy);

    vm.prank(stealthRelayer);
    harvestJob.work(strategy);

    // Check: lastWorkAt set?
    assertEq(harvestJob.lastWorkAt(strategy), block.timestamp);
  }

  /**
   * @notice Should work when in sweeping window (same parameters as the workable test), emit events
   *         and set last work at. Should not be callable a second time.
   */
  function test_work_shouldWorkInSweepingWindow() external _workSetup _testWorkExternalCalls {
    uint256 _creditWindow = 3600;
    uint256 _lastReward = block.timestamp + 604_800;
    uint256 _rewardPeriodTime = 604_800;
    uint256 _nextPeriodStartAt = _lastReward + _rewardPeriodTime;

    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(false));

    // set a period starting 1 week after the lastWorkAt
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(_lastReward));

    // Set a 1 week period
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(_rewardPeriodTime));

    // Set a 1h sweep window
    vm.prank(governor);
    harvestJob.setCreditWindow(uint64(_creditWindow));

    // Warp to 1sec before the next period, at the end of the sweeping window
    vm.warp(_nextPeriodStartAt - 1);

    // Check: emit event?
    vm.expectEmit(true, true, true, true);
    emit KeeperWorked(strategy);

    vm.expectEmit(true, true, true, true);
    emit SweepingOldStrategy(strategy);

    vm.prank(stealthRelayer);
    harvestJob.work(strategy);

    // Check: last work at correctly set?
    assertEq(harvestJob.lastWorkAt(strategy), block.timestamp);

    // Check: Cannot work this strategy a second time (last work at now prevent it)?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotWorkable.selector));
    vm.prank(stealthRelayer);
    harvestJob.work(strategy);
  }

  /**
   * @notice Revert if the stealth relayer caller is not a keeper
   */
  function test_work_revertIfCallerIsNotAKeeper() external _workSetup {
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.isBondedKeeper.selector), abi.encode(false));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IKeep3rJob.KeeperNotValid.selector));
    vm.prank(stealthRelayer);
    harvestJob.work(strategy);
  }

  /**
   * @notice Revert if caller EOA is enforced while the caller is a contract
   *
   * @dev Foundry uses this test contract as caller, hence no further setup
   */
  function test_work_revertIfCallerNotEOAIfSet() external _workSetup {
    vm.prank(governor);
    harvestJob.setOnlyEOA(true);

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IOnlyEOA.OnlyEOA.selector));
    vm.prank(stealthRelayer);
    harvestJob.work(strategy);
  }

  /**
   * @notice Revert if a strategy is not workable (both harvestTrigger and sweeping window are false)
   */
  function test_work_revertIfNotWorkable() external _workSetup {
    vm.mockCall(strategy, abi.encodeWithSelector(IBaseStrategy.harvestTrigger.selector), abi.encode(false));

    // Last reward is 1sec ago
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardedAt.selector), abi.encode(block.timestamp - 1));

    // Set a 1 week period
    vm.mockCall(keep3r, abi.encodeWithSelector(IKeep3rV2.rewardPeriodTime.selector), abi.encode(36_000));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotWorkable.selector));
    vm.prank(stealthRelayer);
    harvestJob.work(strategy);
  }

  /*///////////////////////////////////////////////////////////////
                        forceWorkUnsafe()                  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Should force work via governance and emit event. Last work shouldn't change.
   */
  function test_forceWorkUnsafe_shouldWork() external {
    uint256 _previousLastWorkAt = harvestJob.lastWorkAt(strategy);

    // Check: emit event?
    vm.expectEmit(true, true, true, true, address(harvestJob));
    emit ForceWorked(strategy);

    vm.prank(governor);
    harvestJob.forceWorkUnsafe(strategy);

    // Check: lastWorkAt unchanged?
    assertEq(harvestJob.lastWorkAt(strategy), _previousLastWorkAt);
  }

  /*///////////////////////////////////////////////////////////////
                        forceWork()                  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Force work should work a strategy, if stealth relayer caller is either the governor or the mechanics
   */
  function test_forceWork_shouldWork(address _mechanic) external {
    // Caller is the governor
    vm.assume(_mechanic != governor);
    vm.mockCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector), abi.encode(governor));
    vm.expectCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector));

    // Check: emit event?
    vm.expectEmit(true, true, true, true, address(harvestJob));
    emit ForceWorked(strategy);

    vm.prank(stealthRelayer);
    harvestJob.forceWork(strategy);

    // Caller is the mechanics
    vm.mockCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector), abi.encode(_mechanic));
    vm.expectCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector));

    vm.mockCall(mechanicsRegistry, abi.encodeWithSelector(IMechanicsRegistry.isMechanic.selector), abi.encode(true));
    vm.expectCall(mechanicsRegistry, abi.encodeWithSelector(IMechanicsRegistry.isMechanic.selector));

    // Check: emit event?
    vm.expectEmit(true, true, true, true, address(harvestJob));
    emit ForceWorked(strategy);

    vm.prank(stealthRelayer);
    harvestJob.forceWork(strategy);
  }

  /**
   * @notice Revert if the stealth relayer caller is not the governor nor the mechanic
   */
  function test_forceWork_revertIfCallerIsNotGovernanceOrMech(address _wrongCaller) external {
    // Avoid incidental address collision
    vm.assume(_wrongCaller != governor);

    // Set the caller
    vm.mockCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector), abi.encode(_wrongCaller));
    vm.expectCall(stealthRelayer, abi.encodeWithSelector(IStealthRelayer.caller.selector));

    // Caller is not a mechanic
    vm.mockCall(mechanicsRegistry, abi.encodeWithSelector(IMechanicsRegistry.isMechanic.selector), abi.encode(false));

    // Check: revert?
    vm.expectRevert(abi.encodeWithSignature('OnlyGovernorOrMechanic()'));
    vm.prank(stealthRelayer);
    harvestJob.forceWork(strategy);
  }
}
