// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {V2KeeperJobPackedForTest} from 'test/unit/ForTest/V2KeeperJobPackedForTest.sol';
import {IV2KeeperJob} from 'interfaces/IV2KeeperJob.sol';
import {IBaseErrors} from 'interfaces/utils/IBaseErrors.sol';

import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';

import {Test} from 'forge-std/Test.sol';

contract UnitV2Test is Test {
  /*///////////////////////////////////////////////////////////////
                        Global test variables                  
  //////////////////////////////////////////////////////////////*/

  // From IV2KeeperJob:
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

  /*///////////////////////////////////////////////////////////////
                        Setup: mock and deploy                  
  //////////////////////////////////////////////////////////////*/

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

    // Set a timestamp for time-dependant test (avoid weird underflow when block.timestamp=0)
    vm.warp(123_456_789);
  }

  /*///////////////////////////////////////////////////////////////
                        strategies()                  
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice When multiple strategies are added, they should all be returned
   */
  function test_strategies_shouldReturnAllStrategies(uint256 _numberOfStrategiesToAdd) external {
    // Limit the size of the array to test
    _numberOfStrategiesToAdd = bound(_numberOfStrategiesToAdd, 0, 10);

    address[] memory _strategies = new address[](_numberOfStrategiesToAdd);

    // Add the strategy and build the array to test against
    for (uint256 _i; _i < _numberOfStrategiesToAdd; _i++) {
      vm.prank(governor);
      keep3rJob.addStrategy(address(uint160(_i * 123_456)), 0);
      _strategies[_i] = address(uint160(_i * 123_456));
    }

    // Check: the stored array is the same as the witness?
    assertEq(keep3rJob.strategies(), _strategies);
  }

  /*///////////////////////////////////////////////////////////////
                        setWorkCooldown()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Setting a cooldown store it, when caller is either the governor or the mechanic
   */
  function test_setWorkCooldown_shouldSetCooldown(uint256 _cooldown) external {
    vm.assume(_cooldown != 0);
    // Set a new non-empty cooldown
    vm.prank(governor);
    keep3rJob.setWorkCooldown(_cooldown);

    // Check: cooldown set?
    assertEq(keep3rJob.workCooldown(), _cooldown);
  }

  /**
   * @notice Setting a cooldown of 0 is only possible at deployment (revert)
   */
  function test_setWorkCooldown_revertIfZero() external {
    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.ZeroCooldown.selector));

    // Setting a 0 cooldown
    vm.prank(governor);
    keep3rJob.setWorkCooldown(0);
  }

  /*///////////////////////////////////////////////////////////////
                        setMechanicsRegistry()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Setting a new registry stores it, if caller is the governor or mechanic
   */
  function test_setMechanicsRegistry_shouldSetRegistry(address _newRegistry) external {
    vm.prank(governor);
    keep3rJob.setMechanicsRegistry(_newRegistry);
    assertEq(keep3rJob.mechanicsRegistry(), _newRegistry);
  }

  /*///////////////////////////////////////////////////////////////
                        getCallCosts()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice When the required amount is 0, the call cost is 0
   */
  function test_getCallCosts_shouldReturnZeroWhenNoRequiredAmount(address _randomAddress) external {
    // Check: call cost is 0?
    assertEq(keep3rJob.internalGetCallCosts(_randomAddress), 0);
  }

  /*///////////////////////////////////////////////////////////////
                        workable()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice When calling workable with a strategy that is not added, it reverts
   */
  function test_workable_revertIfStragyDontExist(address _randomAddress) external {
    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.internalWorkable(_randomAddress);
  }

  /**
   * @notice Calling workable with a strategy with a cooldown of 0 returns true
   */
  function test_workable_shouldReturnTrueIfCooldownIsZero() external {
    // Add a strategy
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Force set the cooldown to 0
    keep3rJob.internalSetCooldown(0);

    // Check: workable?
    assertEq(keep3rJob.internalWorkable(strategy), true);
  }

  /**
   * @notice Calling workable with a strategy which isn't in a cooldown anymore returns true
   */
  function test_workable_shouldReturnTrueIfCooldownHasExpired() external {
    // Add a strategy
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Force the last work timestamp cooldown + 1 second in the past (ie cooldown's over for 1sec)
    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp - 1 - COOLDOWN);

    // Check: workable?
    assertEq(keep3rJob.internalWorkable(strategy), true);
  }

  /**
   * @notice Calling workable with a strategy which is in a cooldown returns false
   */
  function test_workable_shouldReturnFalseIfCooldownHasNotExpired() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Force the last work timestamp to be 1sec shy of the end of cooldown
    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp + 1 - COOLDOWN);

    // Check: not workable?
    assertEq(keep3rJob.internalWorkable(strategy), false);
  }

  /*///////////////////////////////////////////////////////////////
                        workInternal()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Trying to work a strategy which isn't workable (ie in cooldown for instance) reverts
   */
  function test_workInternal_revertIfStrategyNotWorkable() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Force the last work timestamp to be 1sec shy of the end of cooldown
    keep3rJob.internalSetLastWorkAt(strategy, block.timestamp + 1 - COOLDOWN);

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotWorkable.selector));
    keep3rJob.internalWorkInternal(strategy);
  }

  /**
   * @notice When working a strategy, the lastWorkAt is updated and an event is emitted
   */
  function test_workInternal_shouldUpdateLastWorkAtAndEmitEvent() external {
    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Check: correct event?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit KeeperWorked(strategy);

    // Work the strategy
    keep3rJob.internalWorkInternal(strategy);

    // Check: lastWorkAt updated?
    assertEq(keep3rJob.lastWorkAt(strategy), block.timestamp);
  }

  /*///////////////////////////////////////////////////////////////
                        addStrategy()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice When adding a stragy, storing it and emitting event
   */
  function test_addStrategy_shouldAddStrategyAndEmitEvent() external {
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyAdded(strategy, 0);

    // Array to test later on
    address[] memory _strategies = new address[](1);
    _strategies[0] = strategy;

    vm.prank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Check: the new strategy is stored?
    assertEq(keep3rJob.strategies(), _strategies);
  }

  /**
   * @notice When adding a same strategy twice, revert
   */
  function test_addStrategy_shouldNotAddTwice() external {
    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyAlreadyAdded.selector));
    keep3rJob.addStrategy(strategy, 0);
    vm.stopPrank();
  }

  /**
   * @notice When adding a strategy, the required amount is stored
   */
  function test_addStrategy_shouldSetRequiredAmount(uint256 _amount) external {
    _amount = bound(_amount, 0, type(uint48).max - 1);

    // Check: correct event?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyAdded(strategy, _amount);

    vm.prank(governor);
    keep3rJob.addStrategy(strategy, _amount);

    // Check: the required amount is stored?
    assertEq(keep3rJob.requiredAmount(strategy), _amount);
  }

  /*///////////////////////////////////////////////////////////////
                        addStrategies()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice When adding multiple strategies, store them
   */
  function test_addStrategies_shouldAddAllStrategies(uint256 _numberOfStrategies) external {
    // Add max 10 strategies at a time
    _numberOfStrategies = bound(_numberOfStrategies, 1, 10);

    // Array of the strategies to add
    address[] memory _strategies = new address[](_numberOfStrategies);
    uint256[] memory _requiredAmounts = new uint256[](_numberOfStrategies);

    for (uint256 _i; _i < _numberOfStrategies; _i++) {
      _strategies[_i] = address(uint160(_i * 69_696_969));
      _requiredAmounts[_i] = _i * 6969;
    }

    vm.prank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    // Check: the new strategies are stored?
    assertEq(keep3rJob.strategies(), _strategies);
  }

  /**
   * @notice When adding multiple strategies, adding twice the same reverts
   */
  function test_addStrategies_shouldNotAddTwice() external {
    // Twice the same address
    address[] memory _strategies = new address[](2);
    _strategies[0] = strategy;
    _strategies[1] = strategy;

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyAlreadyAdded.selector));
    vm.prank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);
  }

  /**
   * @notice When adding multiple strategies, the corresponding required amounts are stored
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

    // Check: correct required amounts?
    assertEq(keep3rJob.requiredAmount(_strategies[0]), _requiredAmounts[0]);
    assertEq(keep3rJob.requiredAmount(_strategies[1]), _requiredAmounts[1]);
  }

  /**
   * @notice When adding multiple strategies and required amounts, the array lengths must match
   */
  function test_addStrategies_revertIfLengthsMismatch() external {
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    // 1 element too short
    uint256[] memory _requiredAmounts = new uint256[](1);
    _requiredAmounts[0] = 123;

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IBaseErrors.WrongLengths.selector));
    vm.prank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);
  }

  /*///////////////////////////////////////////////////////////////
                        removeStrategy()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Removing a strategy works and emit an event. Other strategy is untouched.
   */
  function test_removeStrategy_shouldRemove(uint256 _strategyToRemove) external {
    // Pick one strategy to remove at random
    _strategyToRemove = bound(_strategyToRemove, 0, 1);

    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    // Add the initial strategies
    vm.startPrank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    // Check: correct event?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyRemoved(_strategies[_strategyToRemove]);

    // Remove one of the strategies
    keep3rJob.removeStrategy(_strategies[_strategyToRemove]);

    // Check: the non-removed strategy and required amounts are still there
    address[] memory _expectedStrategies = new address[](1);
    _expectedStrategies[0] = _strategies[1 - _strategyToRemove];

    uint256[] memory _expectedRequiredAmounts = new uint256[](1);
    _expectedRequiredAmounts[0] = _requiredAmounts[1 - _strategyToRemove];

    assertEq(keep3rJob.strategies(), _expectedStrategies);
    assertEq(keep3rJob.requiredAmount(_expectedStrategies[0]), _expectedRequiredAmounts[0]);

    // Check: the strategy has been removed
    assertEq(keep3rJob.strategies().length, 1);
  }

  /**
   * @notice Removing a strategy which is already removed reverts
   */
  function test_removeStrategy_shouldNotRemoveTwice() external {
    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Remove the strategy a first time
    keep3rJob.removeStrategy(strategy);

    // Check: correct error when removing a second time?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.removeStrategy(strategy);
    vm.stopPrank();
  }

  /*///////////////////////////////////////////////////////////////
                        updateRequiredAmount()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Updating the required amount store it and emit event
   */
  function test_updateRequiredAmount_shouldUpdate(uint256 _initialAmount, uint256 _newAmount) external {
    _initialAmount = bound(_initialAmount, 1, type(uint48).max - 1);
    _newAmount = bound(_newAmount, 1, type(uint48).max - 1);

    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, _initialAmount);

    // Check: correct event?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(strategy, _newAmount);

    keep3rJob.updateRequiredAmount(strategy, _newAmount);

    // Check: amount updated?
    assertEq(keep3rJob.requiredAmount(strategy), _newAmount);
  }

  /**
   * @notice Updating the required amount to a non-existing strategy reverts
   */
  function test_updateRequiredAmount_revertIfStrategyDontExist() external {
    vm.prank(governor);

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IV2KeeperJob.StrategyNotAdded.selector));
    keep3rJob.updateRequiredAmount(strategy, 123);
  }

  /**
   * @notice Updating the required amount to a value greater than uint48 max - 1 reverts
   */
  function test_updateRequiredAmount_revertIfAmountOverflow(uint256 _initialAmount, uint256 _newAmount) external {
    _initialAmount = bound(_initialAmount, 1, type(uint48).max - 1);
    // New amount is always >= uint48 max
    _newAmount = bound(_newAmount, type(uint48).max, type(uint256).max);

    vm.startPrank(governor);
    keep3rJob.addStrategy(strategy, 0);

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(StrategiesPackedSet.StrategiesPackedSet_Overflow.selector));
    keep3rJob.updateRequiredAmount(strategy, _newAmount);
    vm.stopPrank();
  }

  /*///////////////////////////////////////////////////////////////
                        updateRequiredAmounts()                 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Updating multiple required amounts stores them
   */
  function test_updateRequiredAmounts_updateAmountsAndEmitEvent() external {
    // The strategies to update
    address[] memory _strategies = new address[](2);
    _strategies[0] = address(uint160(69_696_969));
    _strategies[1] = address(uint160(69_696_969 * 2));

    // The initial amounts
    uint256[] memory _requiredAmounts = new uint256[](2);
    _requiredAmounts[0] = 123;
    _requiredAmounts[1] = 123 * 2;

    vm.startPrank(governor);
    keep3rJob.addStrategies(_strategies, _requiredAmounts);

    // The new amounts
    _requiredAmounts[0] = 123 * 3;
    _requiredAmounts[1] = 123 * 4;

    // Check: correct events?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(_strategies[0], _requiredAmounts[0]);

    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit StrategyModified(_strategies[1], _requiredAmounts[1]);

    keep3rJob.updateRequiredAmounts(_strategies, _requiredAmounts);

    // Check: the new amounts are stored?
    assertEq(keep3rJob.requiredAmount(_strategies[0]), _requiredAmounts[0]);
    assertEq(keep3rJob.requiredAmount(_strategies[1]), _requiredAmounts[1]);
  }

  /**
   * @notice Updating multiple required amounts reverts if the array lengths mismatch
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

    // Amounts is now one too short
    _requiredAmounts = new uint256[](1);
    _requiredAmounts[0] = 123;

    // Check: correct error?
    vm.expectRevert(abi.encodeWithSelector(IBaseErrors.WrongLengths.selector));
    keep3rJob.updateRequiredAmounts(_strategies, _requiredAmounts);
    vm.stopPrank();
  }

  /**
   * @notice Setting a new V2 Keeper works and emit an event
   */
  function test_setV2Keeper_shouldSet() external {
    vm.prank(governor);

    // Check: correct event?
    vm.expectEmit(true, true, true, true, address(keep3rJob));
    emit V2KeeperSet(v2Keeper);

    keep3rJob.setV2Keeper(v2Keeper);

    // Check: new v2keeper is set?
    assertEq(address(keep3rJob.v2Keeper()), v2Keeper);
  }
}
