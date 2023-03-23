// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {GasBaseFee} from './utils/GasBaseFee.sol';
import {MachineryReady, Governable} from './utils/MachineryReady.sol';
import {StrategiesPackedSet} from './utils/StrategiesPackedSet.sol';
import {IV2KeeperJob} from 'interfaces/IV2KeeperJob.sol';
import {IV2Keeper} from 'interfaces/external/IV2Keeper.sol';
import {IBaseStrategy} from 'interfaces/external/IBaseStrategy.sol';

abstract contract V2KeeperJobPacked is IV2KeeperJob, MachineryReady, GasBaseFee {
  using StrategiesPackedSet for StrategiesPackedSet.Set;
  using StrategiesPackedSet for bytes32;

  /// @inheritdoc IV2KeeperJob
  IV2Keeper public v2Keeper;

  StrategiesPackedSet.Set internal _availableStrategies;

  /// @inheritdoc IV2KeeperJob
  uint256 public workCooldown;

  constructor(
    address _governor,
    address _v2Keeper,
    address _mechanicsRegistry,
    uint256 _workCooldown
  ) Governable(_governor) MachineryReady(_mechanicsRegistry) {
    v2Keeper = IV2Keeper(_v2Keeper);
    if (_workCooldown > 0) _setWorkCooldown(_workCooldown);
  }

  // views

  /// @inheritdoc IV2KeeperJob
  function strategies() public view returns (address[] memory _strategies) {
    uint256 _numberOfStrategies = _availableStrategies.length();

    _strategies = new address[](_numberOfStrategies);
    for (uint256 _i; _i < _numberOfStrategies; _i++) {
      _strategies[_i] = _availableStrategies.at(_i).strategyAddress();
    }
  }

  /// @inheritdoc IV2KeeperJob
  function requiredAmount(address _strategy) external view returns (uint256 _requiredAmount) {
    _requiredAmount = _availableStrategies.at(_strategy).requiredAmount();
  }

  /// @inheritdoc IV2KeeperJob
  function lastWorkAt(address _strategy) external view returns (uint256 _lastWorkAt) {
    _lastWorkAt = _availableStrategies.at(_strategy).lastWorkAt();
  }

  // setters

  /// @inheritdoc IV2KeeperJob
  function setV2Keeper(address _v2Keeper) external onlyGovernor {
    _setV2Keeper(_v2Keeper);
  }

  /// @inheritdoc IV2KeeperJob
  function setWorkCooldown(uint256 _workCooldown) external onlyGovernorOrMechanic {
    _setWorkCooldown(_workCooldown);
  }

  /// @inheritdoc IV2KeeperJob
  function addStrategy(address _strategy, uint256 _requiredAmount) external onlyGovernorOrMechanic {
    _addStrategy(_strategy, _requiredAmount);
  }

  /// @inheritdoc IV2KeeperJob
  function addStrategies(
    address[] calldata _strategies,
    uint256[] calldata _requiredAmounts
  ) external onlyGovernorOrMechanic {
    if (_strategies.length != _requiredAmounts.length) revert WrongLengths();
    for (uint256 _i; _i < _strategies.length; _i++) {
      _addStrategy(_strategies[_i], _requiredAmounts[_i]);
    }
  }

  /// @inheritdoc IV2KeeperJob
  function updateRequiredAmount(address _strategy, uint256 _requiredAmount) external onlyGovernorOrMechanic {
    _updateRequiredAmount(_strategy, _requiredAmount);
  }

  /// @inheritdoc IV2KeeperJob
  function updateRequiredAmounts(
    address[] calldata _strategies,
    uint256[] calldata _requiredAmounts
  ) external onlyGovernorOrMechanic {
    if (_strategies.length != _requiredAmounts.length) revert WrongLengths();
    for (uint256 _i; _i < _strategies.length; _i++) {
      _updateRequiredAmount(_strategies[_i], _requiredAmounts[_i]);
    }
  }

  /// @inheritdoc IV2KeeperJob
  function removeStrategy(address _strategy) external onlyGovernorOrMechanic {
    _removeStrategy(_strategy);
  }

  // internals

  function _setV2Keeper(address _v2Keeper) internal {
    v2Keeper = IV2Keeper(_v2Keeper);

    emit V2KeeperSet(_v2Keeper);
  }

  function _setWorkCooldown(uint256 _workCooldown) internal {
    if (_workCooldown == 0) revert ZeroCooldown();
    workCooldown = _workCooldown;

    emit WorkCooldownSet(_workCooldown);
  }

  function _addStrategy(address _strategy, uint256 _requiredAmount) internal {
    if (_availableStrategies.contains(_strategy)) revert StrategyAlreadyAdded();

    _availableStrategies.add(_strategy, _requiredAmount);

    emit StrategyAdded(_strategy, _requiredAmount);
  }

  function _updateRequiredAmount(address _strategy, uint256 _requiredAmount) internal {
    if (!_availableStrategies.contains(_strategy)) revert StrategyNotAdded();

    _availableStrategies.setRequiredAmount(_strategy, _requiredAmount);
    emit StrategyModified(_strategy, _requiredAmount);
  }

  function _removeStrategy(address _strategy) internal {
    if (!_availableStrategies.contains(_strategy)) revert StrategyNotAdded();

    _availableStrategies.remove(_strategy);

    emit StrategyRemoved(_strategy);
  }

  function _workable(address _strategy) internal view virtual returns (bool _isWorkable) {
    if (!_availableStrategies.contains(_strategy)) revert StrategyNotAdded();
    if (workCooldown == 0 || block.timestamp > _availableStrategies.at(_strategy).lastWorkAt() + workCooldown) {
      return true;
    }
    return false;
  }

  function _getCallCosts(address _strategy) internal view returns (uint256 _callCost) {
    uint256 _gasAmount = _availableStrategies.at(_strategy).requiredAmount();
    if (_gasAmount == 0) return 0;
    return _gasAmount * _gasPrice();
  }

  function _workInternal(address _strategy) internal {
    if (!_workable(_strategy)) revert StrategyNotWorkable();

    _availableStrategies.setLastWorkAt(_strategy, block.timestamp);
    _work(_strategy);

    emit KeeperWorked(_strategy);
  }

  function _forceWork(address _strategy) internal {
    _work(_strategy);
    emit ForceWorked(_strategy);
  }

  /// @dev This function should be implemented on the base contract
  function _work(address _strategy) internal virtual {}
}
