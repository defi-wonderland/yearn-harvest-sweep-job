// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {IERC20, IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {IKeep3rV1Helper} from './IKeep3rV1Helper.sol';

// solhint-disable func-name-mixedcase, defi-wonderland/wonder-var-name-mixedcase
interface IKeep3rV1 is IERC20, IERC20Metadata {
  // Events
  event DelegateChanged(address indexed _delegator, address indexed _fromDelegate, address indexed _toDelegate);
  event DelegateVotesChanged(address indexed _delegate, uint256 _previousBalance, uint256 _newBalance);
  event SubmitJob(
    address indexed _job, address indexed _liquidity, address indexed _provider, uint256 _block, uint256 _credit
  );
  event ApplyCredit(
    address indexed _job, address indexed _liquidity, address indexed _provider, uint256 _block, uint256 _credit
  );
  event RemoveJob(
    address indexed _job, address indexed _liquidity, address indexed _provider, uint256 _block, uint256 _credit
  );
  event UnbondJob(
    address indexed _job, address indexed _liquidity, address indexed _provider, uint256 _block, uint256 _credit
  );
  event JobAdded(address indexed _job, uint256 _block, address _governance);
  event JobRemoved(address indexed _job, uint256 _block, address _governance);
  event KeeperWorked(
    address indexed _credit, address indexed _job, address indexed _keeper, uint256 _block, uint256 _amount
  );
  event KeeperBonding(address indexed _keeper, uint256 _block, uint256 _active, uint256 _bond);
  event KeeperBonded(address indexed _keeper, uint256 _block, uint256 _activated, uint256 _bond);
  event KeeperUnbonding(address indexed _keeper, uint256 _block, uint256 _deactive, uint256 _bond);
  event KeeperUnbound(address indexed _keeper, uint256 _block, uint256 _deactivated, uint256 _bond);
  event KeeperSlashed(address indexed _keeper, address indexed _slasher, uint256 _block, uint256 _slash);
  event KeeperDispute(address indexed _keeper, uint256 _block);
  event KeeperResolved(address indexed _keeper, uint256 _block);
  event TokenCreditAddition(
    address indexed _credit, address indexed _job, address indexed _creditor, uint256 _block, uint256 _amount
  );

  // Structs
  struct Checkpoint {
    uint32 fromBlock;
    uint256 votes;
  }

  // Variables
  function KPRH() external view returns (IKeep3rV1Helper _KPRH);

  function delegates(address _delegator) external view returns (address _delegates);

  function checkpoints(address _account, uint32 _checkpoint) external view returns (Checkpoint memory _checkpoints);

  function numCheckpoints(address _account) external view returns (uint32 _numCheckpoints);

  function DOMAIN_TYPEHASH() external returns (bytes32 _DOMAIN_TYPEHASH);

  function DOMAINSEPARATOR() external returns (bytes32 _DOMAINSEPARATOR);

  function DELEGATION_TYPEHASH() external returns (bytes32 _DELEGATION_TYPEHASH);

  function PERMIT_TYPEHASH() external returns (bytes32 _PERMIT_TYPEHASH);

  function nonces(address _user) external view returns (uint256 _nonces);

  function BOND() external returns (uint256 _BOND);

  function UNBOND() external returns (uint256 _UNBOND);

  function LIQUIDITYBOND() external returns (uint256 _LIQUIDITYBOND);

  function FEE() external returns (uint256 _FEE);

  function BASE() external returns (uint256 _BASE);

  function ETH() external returns (address _ETH);

  function bondings(address _user, address _bonding) external view returns (uint256 _bondings);

  function canWithdrawAfter(address _user, address _bonding) external view returns (uint256 _canWithdrawAfter);

  function pendingUnbonds(address _keeper, address _bonding) external view returns (uint256 _pendingUnbonds);

  function pendingbonds(address _keeper, address _bonding) external view returns (uint256 _pendingbonds);

  function bonds(address _keeper, address _bonding) external view returns (uint256 _bonds);

  function votes(address _delegator) external view returns (uint256 _votes);

  function firstSeen(address _keeper) external view returns (uint256 _firstSeen);

  function disputes(address _keeper) external view returns (bool _disputes);

  function lastJob(address _keeper) external view returns (uint256 _lastJob);

  function workCompleted(address _keeper) external view returns (uint256 _workCompleted);

  function jobs(address _job) external view returns (bool _jobs);

  function credits(address _job, address _credit) external view returns (uint256 _credits);

  function liquidityProvided(
    address _provider,
    address _liquidity,
    address _job
  ) external view returns (uint256 _liquidityProvided);

  function liquidityUnbonding(
    address _provider,
    address _liquidity,
    address _job
  ) external view returns (uint256 _liquidityUnbonding);

  function liquidityAmountsUnbonding(
    address _provider,
    address _liquidity,
    address _job
  ) external view returns (uint256 _liquidityAmountsUnbonding);

  function jobProposalDelay(address _job) external view returns (uint256 _jobProposalDelay);

  function liquidityApplied(
    address _provider,
    address _liquidity,
    address _job
  ) external view returns (uint256 _liquidityApplied);

  function liquidityAmount(
    address _provider,
    address _liquidity,
    address _job
  ) external view returns (uint256 _liquidityAmount);

  function keepers(address _keeper) external view returns (bool _keepers);

  function blacklist(address _keeper) external view returns (bool _blacklist);

  function keeperList(uint256 _index) external view returns (address _keeperList);

  function jobList(uint256 _index) external view returns (address _jobList);

  function governance() external returns (address _governance);

  function pendingGovernance() external returns (address _pendingGovernance);

  function liquidityAccepted(address _liquidity) external view returns (bool _liquidityAccepted);

  function liquidityPairs(uint256 _index) external view returns (address _liquidityPairs);

  // Methods
  function getCurrentVotes(address _account) external view returns (uint256 _currentVotes);

  function addCreditETH(address _job) external payable;

  function addCredit(address _credit, address _job, uint256 _amount) external;

  function addVotes(address _voter, uint256 _amount) external;

  function removeVotes(address _voter, uint256 _amount) external;

  function addKPRCredit(address _job, uint256 _amount) external;

  function approveLiquidity(address _liquidity) external;

  function revokeLiquidity(address _liquidity) external;

  function pairs() external view returns (address[] memory _pairs);

  function addLiquidityToJob(address _liquidity, address _job, uint256 _amount) external;

  function applyCreditToJob(address _provider, address _liquidity, address _job) external;

  function unbondLiquidityFromJob(address _liquidity, address _job, uint256 _amount) external;

  function removeLiquidityFromJob(address _liquidity, address _job) external;

  function mint(uint256 _amount) external;

  function burn(uint256 _amount) external;

  function worked(address _keeper) external;

  function receipt(address _credit, address _keeper, uint256 _amount) external;

  function workReceipt(address _keeper, uint256 _amount) external;

  function receiptETH(address _keeper, uint256 _amount) external;

  function addJob(address _job) external;

  function getJobs() external view returns (address[] memory _jobs);

  function removeJob(address _job) external;

  function setKeep3rHelper(address _keep3rHelper) external;

  function setGovernance(address _governance) external;

  function acceptGovernance() external;

  function isKeeper(address _keeper) external returns (bool _isKeeper);

  function isMinKeeper(
    address _keeper,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) external returns (bool _isMinKeeper);

  function isBondedKeeper(
    address _keeper,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) external returns (bool _isBondedKeeper);

  function bond(address _bonding, uint256 _amount) external;

  function getKeepers() external view returns (address[] memory _keepers);

  function activate(address _bonding) external;

  function unbond(address _bonding, uint256 _amount) external;

  function slash(address _bonded, address _keeper, uint256 _amount) external;

  function withdraw(address _bonding) external;

  function dispute(address _keeper) external;

  function revoke(address _keeper) external;

  function resolve(address _keeper) external;

  function permit(
    address _owner,
    address _spender,
    uint256 _amount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;
}
