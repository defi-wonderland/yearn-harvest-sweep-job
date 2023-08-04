// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {V2KeeperJobPacked} from 'contracts/V2KeeperJobPacked.sol';
import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';

contract V2KeeperJobPackedForTest is V2KeeperJobPacked {
  constructor(
    address _governor,
    address _mechanicsRegistry,
    address _v2Keeper,
    uint256 _workCooldown
  ) V2KeeperJobPacked(_governor, _v2Keeper, _mechanicsRegistry, _workCooldown) {}

  function internalWorkable(address _strategy) external view returns (bool _isWorkable) {
    return _workable(_strategy);
  }

  function internalWorkInternal(address _strategy) external {
    _workInternal(_strategy);
  }

  function internalGetCallCosts(address _strategy) external view returns (uint256 _callCost) {
    return _getCallCosts(_strategy);
  }

  function internalSetLastWorkAt(address _strategy, uint256 _timestamp) external {
    StrategiesPackedSet.setLastWorkAt(_availableStrategies, _strategy, _timestamp);
  }

  function internalSetCooldown(uint256 _cooldown) external {
    workCooldown = _cooldown;
  }

  // missing implementations

  function workable(address _strategy) external view returns (bool _workable) {}

  function forceWork(address _strategy) external {}

  function work(address _strategy) external {}
}
