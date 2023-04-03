// SPDX-License-Identifier: MIT

/*

Coded for Yearn Finance with ♥ by

██████╗░███████╗███████╗██╗  ░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
██╔══██╗██╔════╝██╔════╝██║  ░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
██║░░██║█████╗░░█████╗░░██║  ░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
██║░░██║██╔══╝░░██╔══╝░░██║  ░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
██████╔╝███████╗██║░░░░░██║  ░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
╚═════╝░╚══════╝╚═╝░░░░░╚═╝  ░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks*/

pragma solidity >=0.8.9 <0.9.0;

import {V2KeeperJobPacked, StrategiesPackedSet, IV2KeeperJob, IBaseStrategy} from './V2KeeperJobPacked.sol';
import {Pausable} from './utils/Pausable.sol';
import {Keep3rMeteredStealthJob, IKeep3rV2, IStealthRelayer, IKeep3rHelper} from './utils/Keep3rMeteredStealthJob.sol';
import {IV2Keep3rCreditWindow} from 'interfaces/IV2Keep3rCreditWindow.sol';
import {IV2Keep3rStealthJob} from 'interfaces/IV2Keep3rStealthJob.sol';

contract HarvestSweepStealthJob is
  IV2Keep3rCreditWindow,
  IV2Keep3rStealthJob,
  V2KeeperJobPacked,
  Pausable,
  Keep3rMeteredStealthJob
{
  using StrategiesPackedSet for StrategiesPackedSet.Set;
  using StrategiesPackedSet for bytes32;

  /// @inheritdoc IV2Keep3rCreditWindow
  SweepingParams public override sweepingParams;

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
  ) V2KeeperJobPacked(_governor, _v2Keeper, _mechanicsRegistry, _workCooldown) {
    _setKeep3r(_keep3r);
    _setKeep3rHelper(_keep3rHelper);
    _setStealthRelayer(_stealthRelayer);
    _setKeep3rRequirements(_bond, _minBond, _earned, _age);
    _setOnlyEOA(_onlyEOA);
    _setGasBonus(143_200); // calculated fixed bonus to compensate unaccounted gas
    _setGasMultiplier((gasMultiplier * 850) / 1000); // expected 15% refunded gas

    sweepingParams.sweepingPeriodStartAt = uint128(block.timestamp);
    sweepingParams.creditOptimisationWindow = uint128(1 hours);
  }

  // views

  /// @inheritdoc IV2KeeperJob
  function workable(address _strategy) external view returns (bool _isWorkable) {
    return _workable(_strategy);
  }

  // methods

  /// @inheritdoc IV2KeeperJob
  function work(address _strategy) external notPaused {
    // Measure gas to later pay the keeper + access control
    uint256 _initialGas = _getGasLeft();
    if (msg.sender != stealthRelayer) revert OnlyStealthRelayer();
    address _keeper = IStealthRelayer(stealthRelayer).caller();
    _isValidKeeper(_keeper);

    // Are we trying to work an old strategy while in during the credit optimisation window?
    uint256 _sweepOldOnes; // Act as a bool

    // Cooldown or not added?
    if (!super._workable(_strategy)) revert StrategyNotWorkable();

    // Is the strategy profitable? If so, just work it
    if (!IBaseStrategy(_strategy).harvestTrigger(_getCallCosts(_strategy))) {
      // If not, are we in the credit optimisation window and is the strategy old enough?
      if (_isWorkableDuringWindow(_strategy)) {
        _sweepOldOnes = 1;
      }
      // If not, not workable
      else {
        revert StrategyNotWorkable();
      }
    }

    // Work it
    _availableStrategies.setLastWorkAt(_strategy, block.timestamp);
    _work(_strategy);

    // Measure gas and pay the keeper
    uint256 _gasAfterWork = _getGasLeft();
    uint256 _reward = IKeep3rHelper(keep3rHelper).getRewardAmountFor(_keeper, _initialGas - _gasAfterWork + gasBonus);
    _reward = (_reward * gasMultiplier) / BASE;
    IKeep3rV2(keep3r).bondedPayment(_keeper, _reward);

    emit KeeperWorked(_strategy);
    emit GasMetered(_initialGas, _gasAfterWork, gasBonus);
    if (_sweepOldOnes == 1) emit SweepingOldStrategy(_strategy);

    // If we are in the credit optimisation window and we worked an old strategy, ensure we dont use liquidity credits
    // (this would reset the rewardedAt)
    if (_sweepOldOnes == 1 && IKeep3rV2(keep3r).rewardedAt(address(this)) == block.timestamp) {
      revert ExtraCreditUsed();
    }
  }

  /// @inheritdoc IV2KeeperJob
  function forceWork(address _strategy) external onlyStealthRelayer {
    address _caller = IStealthRelayer(stealthRelayer).caller();
    _validateGovernorOrMechanic(_caller);
    _forceWork(_strategy);
  }

  /// @inheritdoc IV2Keep3rStealthJob
  function forceWorkUnsafe(address _strategy) external onlyGovernorOrMechanic {
    _forceWork(_strategy);
  }

  /// @inheritdoc IV2Keep3rCreditWindow
  function setCreditWindow(uint128 _window) external onlyGovernorOrMechanic {
    sweepingParams.creditOptimisationWindow = _window;

    emit CreditOptimisationWindowModified(_window);
  }

  /// @inheritdoc IV2Keep3rCreditWindow
  function setSweepingStart(uint128 _sweepingPeriodStart) external onlyGovernorOrMechanic {
    sweepingParams.sweepingPeriodStartAt = _sweepingPeriodStart;

    emit SweepingStartModified(_sweepingPeriodStart);
  }

  // internals

  function _workable(address _strategy) internal view override returns (bool _isWorkable) {
    // Is the strategy ready, keep3r wise (ie added to the available and not in cooldown)?
    if (!super._workable(_strategy)) return false;

    // Is the strategy profitable or not profitable but we're during credit optimisation window?
    if (IBaseStrategy(_strategy).harvestTrigger(_getCallCosts(_strategy)) || _isWorkableDuringWindow(_strategy)) {
      return true;
    }

    return false;
  }

  function _work(address _strategy) internal override {
    v2Keeper.harvest(_strategy);
  }

  function _isWorkableDuringWindow(address _strategy) internal view returns (bool _isWorkable) {
    uint256 _rewardedAt = IKeep3rV2(keep3r).rewardedAt(address(this));

    // Is this a new job? If so, we can't use liquidity credits
    if (_rewardedAt == 0) return false;

    uint256 _rewardPeriodTime = IKeep3rV2(keep3r).rewardPeriodTime();

    // Compute the beginning of the period (take into account the job might have not been worked during previous periods)
    uint256 _periodStart = _rewardedAt + _rewardPeriodTime * ((block.timestamp - _rewardedAt) / _rewardPeriodTime);

    uint256 _nextPeriodStart = _periodStart + _rewardPeriodTime;

    // Are we in the credit optimisation window? See for struct sload rationale:
    // https://gist.github.com/drgorillamd/d88f697a9508df0ddb205cbbfc35fe09
    if (block.timestamp < _nextPeriodStart - sweepingParams.creditOptimisationWindow) return false;

    // Are we in the sweeping period for this strategy? Every strategy last worked before this timestamp is now workable
    // See https://www.desmos.com/calculator/frjfmtr8ng
    uint256 _currentSweepingPeriodEnd = _periodStart
      - ((_periodStart * (_nextPeriodStart - block.timestamp)) / _rewardPeriodTime)
      + ((sweepingParams.sweepingPeriodStartAt * (_nextPeriodStart - block.timestamp)) / _rewardPeriodTime);

    // Return true if the _strategy lastWorkAt was before _currentSweepingPeriodEnd
    return _currentSweepingPeriodEnd >= _availableStrategies.at(_strategy).lastWorkAt();
  }
}
