// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {OldV2KeeperJob} from './OldV2KeeperJob.sol';

/*///////////////////////////////////////////////////////////////
                 DEPERECATED - FOR GAS TESTING  ONLY                 
  //////////////////////////////////////////////////////////////*/

contract OldV2KeeperJobForTest is OldV2KeeperJob {
  constructor(
    address _governor,
    address _mechanicsRegistry,
    address _v2Keeper,
    uint256 _workCooldown
  ) OldV2KeeperJob(_governor, _v2Keeper, _mechanicsRegistry, _workCooldown) {}

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
    lastWorkAt[_strategy] = _timestamp;
  }

  function internalSetCooldown(uint256 _cooldown) external {
    workCooldown = _cooldown;
  }

  // missing implementations

  function workable(address _strategy) external view returns (bool _workable) {}

  function forceWork(address _strategy) external {}

  function work(address _strategy) external {}
}
