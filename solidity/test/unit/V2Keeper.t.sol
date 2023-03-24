// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {V2KeeperJobPackedForTest} from 'test/unit/ForTest/V2KeeperJobPackedForTest.sol';
import {IV2KeeperJob} from 'interfaces/IV2KeeperJob.sol';
import {IBaseErrors} from 'interfaces/utils/IBaseErrors.sol';

import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';

import {Test} from 'forge-std/Test.sol';

contract UnitV2Test is Test {
  event KeeperWorked(address _strategy);
  event StrategyAdded(address _strategy, uint256 _requiredAmount);
  event StrategyRemoved(address _strategy);
  event StrategyModified(address _strategy, uint256 _requiredAmount);
  event V2KeeperSet(address _v2Keeper);

  uint256 public constant COOLDOWN = 600;

  address public governor = makeAddr('governor');

  address public strategy = makeAddr('strategy');
  address public v2Keeper = makeAddr('v2Keeper');
  address public mechanicsRegistry = makeAddr('mechanicsRegistry');

  V2KeeperJobPackedForTest public keep3rJob;

  function setUp() public {
    vm.etch(v2Keeper, hex'69');
    vm.etch(mechanicsRegistry, hex'69');
    vm.etch(strategy, hex'69');

    keep3rJob = new V2KeeperJobPackedForTest({
                _governor: governor,
                _mechanicsRegistry: mechanicsRegistry,
                _v2Keeper: v2Keeper,
                _workCooldown: COOLDOWN
        });

    vm.warp(123_456_789);
  }

  /**
   * @notice
   */
  function test_strategies_shouldReturnAllStrategies(uint256 _numberOfStrategiesToAdd) external {
    _numberOfStrategiesToAdd = bound(_numberOfStrategiesToAdd, 0, 10);

    address[] memory _strategies = new address[](_numberOfStrategiesToAdd);

    for (uint256 _i; _i < _numberOfStrategiesToAdd; _i++) {
      vm.prank(governor);
      keep3rJob.addStrategy(address(uint160(_i * 123_456)), 0);
      _strategies[_i] = address(uint160(_i * 123_456));
    }

    assertEq(keep3rJob.strategies(), _strategies);
  }

  /**
   * @notice
   */
  function test_setWorkCooldown_shouldSetCooldown(uint256 _cooldown) external {
    vm.assume(_cooldown != 0);
    vm.prank(governor);
    keep3rJob.setWorkCooldown(_cooldown);
    assertEq(keep3rJob.workCooldown(), _cooldown);
  }

  /**
   * @notice
   */
  function test_setWorkCooldown_revertIfZero() external {
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.ZeroCooldown.selector));
    vm.prank(governor);
    keep3rJob.setWorkCooldown(0);
  }

  /**
   * @notice
   */
  function test_setMechanicsRegistry_shouldSetRegistry(address _newRegistry) external {
    vm.prank(governor);
    keep3rJob.setMechanicsRegistry(_newRegistry);
    assertEq(keep3rJob.mechanicsRegistry(), _newRegistry);
  }

  /**
   * @notice
   */
  function test_getCallCosts_shouldReturnZeroWhenNoRequiredAmount(address _randomAddress) external {
    assertEq(keep3rJob.internalGetCallCosts(_randomAddress), 0);
  }

  /**
   * @notice
   */
  function test_workable_revertIfStragyDontExist(address _randomAddress) external {
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.internalWorkable(_randomAddress);
  }

  /**
   * @notice
   */
  function test_workable_shouldReturnTrueIfCooldownIsZero() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    keep3rJob.internalSetCooldown(0);

    assertEq(keep3rJob.internalWorkable(strategy), true);
  }

  /**
   * @notice
   */
  function test_workable_shouldReturnTrueIfCooldownHasExpired() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp - 1 - COOLDOWN);

    assertEq(keep3rJob.internalWorkable(strategy), true);
  }

  /**
   * @notice
   */
  function test_workable_shouldReturnFalseIfCooldownHasNotExpired() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp + 1 - COOLDOWN);

    assertEq(keep3rJob.internalWorkable(strategy), false);
  }

  /**
   * @notice
   */
  function test_workInternal_revertIfStrategyNotWorkable() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp + 1 - COOLDOWN);

    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotWorkable.selector));
    keep3rJob.internalWorkInternal(strategy);
  }

  /**
   * @notice + event
   */
  function test_workInternal_shouldUpdateLastWorkAtAndEmitEvent() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit KeeperWorked(strategy);

    keep3rJob.internalWorkInternal(strategy);

    assertEq(keep3rJob.lastWorkAt(strategy), block.timestamp);
  }

  /**
   * @notice + event
   */
  function test_addStrategy_shouldAddStrategyAndEmitEvent() external {
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyAdded(strategy, 0);

    address[] memory _strategies = new address[](1);
    _strategies[0] = strategy;

    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    assertEq(keep3rJob.strategies(), _strategies);
  }

  /**
   * @notice
   */
  function test_addStrategy_shouldNotAddTwice() external {
    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyAlreadyAdded.selector));
    keep3rJob.addStrategy(strategy, 0);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_addStrategy_shouldSetRequiredAmount(uint256 _amount) external {
    _amount = bound(_amount, 0, type(uint48).max - 1);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyAdded(strategy, _amount);

    vm.prank(governor);
    keep3rJob.addStrategy(strategy, _amount);

    assertEq(keep3rJob.requiredAmount(strategy), _amount);
  }

  /**
   * @notice
   */
  function test_addStrategies_shouldAddAllStrategies(uint256 _numberOfStrategies) external {
    _numberOfStrategies = bound(_numberOfStrategies, 1, 10);

    address[] memory _strategies = new address[](_numberOfStrategies);
    uint256[] memory _requiredAmounts = new uint256[](_numberOfStrategies);

    for (uint256 _i; _i < _numberOfStrategies; _i++) {
      _strategies[_i] = address(uint160(_i * 69_696_969));
      _requiredAmounts[_i] = _i * 6969;
    }

    vm.prank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    assertEq(keep3rJob.strategies(), _strategies);
  }

  /**
   * @notice
   */
  function test_addStrategies_shouldNotAddTwice() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = strategy;
    _strategies[1] = strategy;

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123;

    vm.startPrank(governor);
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyAlreadyAdded.selector));
    keep3rJob.addStrategies(_strategies, _requiredAmounts);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_addStrategies_shouldSetRequiredAmounts() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    vm.prank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    assertEq(keep3rJob.requiredAmount(_strategies[0]), _requiredAmounts[0]);
    assertEq(keep3rJob.requiredAmount(_strategies[1]), _requiredAmounts[1]);
  }

  /**
   * @notice
   */
  function test_addStrategies_revertIfLengthsMismatch() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](1);
    _requiredAmounts[0] = 123;

    vm.startPrank(governor);
    vm.expectRevert(abi.encodeWithSelector(IBaseErrors.WrongLengths.selector));
    keep3rJob.addStrategies(_strategies, _requiredAmounts);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_removeStrategy_shouldRemove(uint256 _strategyToRemove) external {
    _strategyToRemove = bound(_strategyToRemove, 0, 1);

    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    vm.startPrank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyRemoved(_strategies[_strategyToRemove]);

    keep3rJob.removeStrategy(_strategies[_strategyToRemove]);

    address[] memory _expectedStrategies = new address[](1);
    _expectedStrategies[0] = _strategies[1 - _strategyToRemove];

    uint256[] memory _expectedRequiredAmounts = new uint256[](1);
    _expectedRequiredAmounts[0] = _requiredAmounts[1 - _strategyToRemove];

    assertEq(keep3rJob.strategies(), _expectedStrategies);
    assertEq(keep3rJob.requiredAmount(_expectedStrategies[0]), _expectedRequiredAmounts[0]);
  }
  /**
   * @notice
   */

  function test_removeStrategy_shouldNotRemoveTwice() external {
    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyRemoved(strategy);

    keep3rJob.removeStrategy(strategy);

    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.removeStrategy(strategy);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_updateRequiredAmount_shouldUpdate(uint256 _initialAmount, uint256 _newAmount) external {
    _initialAmount = bound(_initialAmount, 1, type(uint48).max - 1);
    _newAmount = bound(_newAmount, 1, type(uint48).max - 1);

    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, _initialAmount);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(strategy, _newAmount);

    keep3rJob.updateRequiredAmount(strategy, _newAmount);

    assertEq(keep3rJob.requiredAmount(strategy), _newAmount);
  }

  /**
   * @notice
   */
  function test_updateRequiredAmount_revertIfStrategyDontExist() external {
    vm.startPrank(governor);
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.updateRequiredAmount(strategy, 123);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_updateRequiredAmount_revertIfAmountOverflow(uint256 _initialAmount, uint256 _newAmount) external {
    _initialAmount = bound(_initialAmount, 1, type(uint48).max - 1);
    _newAmount = bound(_newAmount, type(uint48).max, type(uint256).max);

    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    vm.expectRevert(abi.encodeWithSelector(StrategiesPackedSet.StrategiesPackedSet_Overflow.selector));
    keep3rJob.updateRequiredAmount(strategy, _newAmount);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_updateRequiredAmounts_updateAmountsAndEmitEvent() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    vm.startPrank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    _requiredAmounts[0] = 123 * 3;
    _requiredAmounts[1] = 123 * 4;

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(_strategies[0], _requiredAmounts[0]);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(_strategies[1], _requiredAmounts[1]);

    keep3rJob.updateRequiredAmounts(_strategies, _requiredAmounts);

    assertEq(keep3rJob.requiredAmount(_strategies[0]), _requiredAmounts[0]);
    assertEq(keep3rJob.requiredAmount(_strategies[1]), _requiredAmounts[1]);
  }

  /**
   * @notice
   */
  function test_updateRequiredAmounts_revertIfLengthMismatch() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    vm.startPrank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    _requiredAmounts = new uint256[](1);
    _requiredAmounts[0] = 123;

    vm.expectRevert(abi.encodeWithSelector(IBaseErrors.WrongLengths.selector));
    keep3rJob.updateRequiredAmounts(_strategies, _requiredAmounts);
    vm.stopPrank();
  }

  /**
   * @notice
   */
  function test_setV2Keeper_shouldSet() external {
    vm.startPrank(governor);
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit V2KeeperSet(v2Keeper);

    keep3rJob.setV2Keeper(v2Keeper);

    assertEq(address(keep3rJob.v2Keeper()), v2Keeper);
  }
}
