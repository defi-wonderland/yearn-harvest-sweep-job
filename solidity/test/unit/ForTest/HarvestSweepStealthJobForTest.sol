// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import {HarvestSweepStealthJob} from 'contracts/HarvestSweepStealthJob.sol';
import {StrategiesPackedSet} from 'contracts/utils/StrategiesPackedSet.sol';

contract HarvestSweepStealthJobForTest is HarvestSweepStealthJob {
  constructor(
    address _governor,
    address _mechanicsRegistry,
    address _stealthRelayer,
    address _v2Keeper,
    uint256 _workCooldown,
    address _keep3r,
    address _keep3rHelper,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age,
    bool _onlyEOA
  )
    HarvestSweepStealthJob(
      _governor,
      _mechanicsRegistry,
      _stealthRelayer,
      _v2Keeper,
      _workCooldown,
      _keep3r,
      _keep3rHelper,
      _bond,
      _minBond,
      _earned,
      _age,
      _onlyEOA
    )
  {}

  uint256 internal _baseFee;

  function _gasPrice() internal view virtual override returns (uint256 _price) {
    return _baseFee;
  }

  function internalSetBaseFee(uint256 _fee) external {
    _baseFee = _fee;
  }

  function internalSetLastWorkAt(address _strategy, uint256 _timestamp) external {
    StrategiesPackedSet.setLastWorkAt(_availableStrategies, _strategy, _timestamp);
  }

  function internalSetRequiredAmount(address _strategy, uint256 _requiredAmount) external {
    StrategiesPackedSet.setRequiredAmount(_availableStrategies, _strategy, _requiredAmount);
  }

  function internalHasNotBeenWorkedRecently(address _strategy) external view returns (bool _workable) {
    return _isWorkableDuringWindow(_strategy);
  }
}
