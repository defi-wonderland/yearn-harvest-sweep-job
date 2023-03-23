// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITokenVault {
  function initialize(
    address _token,
    address _governance,
    address _rewards,
    string memory _nameOverride,
    string memory _symbolOverride
  ) external;

  function initialize(
    address _token,
    address _governance,
    address _rewards,
    string memory _nameOverride,
    string memory _symbolOverride,
    address _guardian
  ) external;

  function initialize(
    address _token,
    address _governance,
    address _rewards,
    string memory _nameOverride,
    string memory _symbolOverride,
    address _guardian,
    address _management
  ) external;

  function apiVersion() external pure returns (string memory _version);

  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view returns (bytes32 _domainSeparator);

  function setName(string memory _name) external;

  function setSymbol(string memory _symbol) external;

  function setGovernance(address _governance) external;

  function acceptGovernance() external;

  function setManagement(address _management) external;

  function setRewards(address _rewards) external;

  function setLockedProfitDegradation(uint256 _degradation) external;

  function setDepositLimit(uint256 _limit) external;

  function setPerformanceFee(uint256 _fee) external;

  function setManagementFee(uint256 _fee) external;

  function setGuardian(address _guardian) external;

  function setEmergencyShutdown(bool _active) external;

  function setWithdrawalQueue(address[20] memory _queue) external;

  function transfer(address _receiver, uint256 _amount) external returns (bool _success);

  function transferFrom(address _sender, address _receiver, uint256 _amount) external returns (bool _success);

  function approve(address _spender, uint256 _amount) external returns (bool _success);

  function increaseAllowance(address _spender, uint256 _amount) external returns (bool _success);

  function decreaseAllowance(address _spender, uint256 _amount) external returns (bool _success);

  function permit(
    address _owner,
    address _spender,
    uint256 _amount,
    uint256 _expiry,
    bytes memory _signature
  ) external returns (bool _success);

  function totalAssets() external view returns (uint256 _totalAssets);

  function deposit() external returns (uint256 _deposit);

  function deposit(uint256 _amount) external returns (uint256 _deposit);

  function deposit(uint256 _amount, address _recipient) external returns (uint256 _deposit);

  function maxAvailableShares() external view returns (uint256 _maxShares);

  function withdraw() external returns (uint256 _amount);

  function withdraw(uint256 _maxShares) external returns (uint256 _amount);

  function withdraw(uint256 _maxShares, address _recipient) external returns (uint256 _amount);

  function withdraw(uint256 _maxShares, address _recipient, uint256 _maxLoss) external returns (uint256 _amount);

  function pricePerShare() external view returns (uint256 _price);

  function addStrategy(
    address _strategy,
    uint256 _debtRatio,
    uint256 _minDebtPerHarvest,
    uint256 _maxDebtPerHarvest,
    uint256 _performanceFee
  ) external;

  function updateStrategyDebtRatio(address _strategy, uint256 _debtRatio) external;

  function updateStrategyMinDebtPerHarvest(address _strategy, uint256 _minDebtPerHarvest) external;

  function updateStrategyMaxDebtPerHarvest(address _strategy, uint256 _maxDebtPerHarvest) external;

  function updateStrategyPerformanceFee(address _strategy, uint256 _performanceFee) external;

  function migrateStrategy(address _oldVersion, address _newVersion) external;

  function revokeStrategy() external;

  function revokeStrategy(address _strategy) external;

  function addStrategyToQueue(address _strategy) external;

  function removeStrategyFromQueue(address _strategy) external;

  function debtOutstanding() external view returns (uint256 _amount);

  function debtOutstanding(address _strategy) external view returns (uint256 _amount);

  function creditAvailable() external view returns (uint256 _amount);

  function creditAvailable(address _strategy) external view returns (uint256 _amount);

  function availableDepositLimit() external view returns (uint256 _amount);

  function expectedReturn() external view returns (uint256 _amount);

  function expectedReturn(address _strategy) external view returns (uint256 _amount);

  function report(uint256 _gain, uint256 _loss, uint256 _debtPayment) external returns (uint256 _amount);

  function sweep(address _token) external;

  function sweep(address _token, uint256 _amount) external;

  function name() external view returns (string memory _name);

  function symbol() external view returns (string memory _symbol);

  function decimals() external view returns (uint256 _decimals);

  function balanceOf(address _arg0) external view returns (uint256 _balance);

  function allowance(address _arg0, address _arg1) external view returns (uint256 _amount);

  function totalSupply() external view returns (uint256 _totalSupply);

  function token() external view returns (address _address);

  function governance() external view returns (address _governance);

  function management() external view returns (address _management);

  function guardian() external view returns (address _guardian);

  function strategies(address _arg0) external view returns (StrategyParams memory _params);

  function withdrawalQueue(uint256 _arg0) external view returns (address _address);

  function emergencyShutdown() external view returns (bool _emergencyShutdown);

  function depositLimit() external view returns (uint256 _amount);

  function debtRatio() external view returns (uint256 _amount);

  function totalIdle() external view returns (uint256 _amount);

  function totalDebt() external view returns (uint256 _amount);

  function lastReport() external view returns (uint256 _timestamp);

  function activation() external view returns (uint256 _timestamp);

  function lockedProfit() external view returns (uint256 _amount);

  function lockedProfitDegradation() external view returns (uint256 _amount);

  function rewards() external view returns (address _rewards);

  function managementFee() external view returns (uint256 _amount);

  function performanceFee() external view returns (uint256 _amount);

  function nonces(address _arg0) external view returns (uint256 _nonce);
}

struct StrategyParams {
  uint256 performanceFee;
  uint256 activation;
  uint256 debtRatio;
  uint256 minDebtPerHarvest;
  uint256 maxDebtPerHarvest;
  uint256 lastReport;
  uint256 totalDebt;
  uint256 totalGain;
  uint256 totalLoss;
}
