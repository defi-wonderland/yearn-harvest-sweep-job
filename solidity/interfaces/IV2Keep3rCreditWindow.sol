// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IV2Keep3rCreditWindow {
  /// @notice Event emitted when the credit optimisation window is modified
  event CreditOptimisationWindowModified(uint256 _delay);

  /// @notice Event emitted when the sweeping start is modified
  event SweepingStartModified(uint256 _sweepingPeriodStart);

  /// @notice Event emitted when the sweeping gas bonus is modified
  event SweepingBonusModified(uint256 _bonus);

  /// @notice Event emitted when sweeping a strategy
  event SweepingOldStrategy(address indexed _strategy);

  /// @notice Throw when liquidity credit is used during the credit optimisation window
  error ExtraCreditUsed();

  /// @notice Struct containing the sweeping parameters
  struct SweepingParams {
    uint64 sweepingPeriodStartAt;
    uint64 creditOptimisationWindow;
    uint64 sweepGasBonus;
  }

  /// @notice Struct containing the current sweeping parameters
  /// @dev    The returned value is a SweepingParams struct
  /// @return _sweepingPeriodStartAt     The timestamp at which the sweeping period starts, initialised as the deployment of this contract but should be adated
  ///                                    in the long run, as the whole period to cover will grow over time
  /// @return _creditOptimisationWindow  The delay before the next period during which the credit optimisation is active
  /// @return _sweepGasBonus             The gas bonus to add when sweeping (to take into account the extra gas used to call rewardedAt and sweep event)
  function sweepingParams()
    external
    returns (uint64 _sweepingPeriodStartAt, uint64 _creditOptimisationWindow, uint64 _sweepGasBonus);

  /// @notice Update the window during which the credit optimisation is active, before the next period
  /// @param  _duration The window size
  function setCreditWindow(uint64 _duration) external;

  /// @notice Update the start of the sweeping period. This is the deployment timestamp by default but should be
  ///         increased in the long run, as the whole period to cover will grow over time
  /// @param  _sweepingPeriodStart The timestamp at which the sweeping period starts
  function setSweepingStart(uint64 _sweepingPeriodStart) external;

  /// @notice Update the gas bonus to add when sweeping
  /// @param  _sweepGasBonus The gas bonus to add when sweeping
  function setSweepingBonus(uint64 _sweepGasBonus) external;
}
