// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {HarvestSweepStealthJob} from 'contracts/HarvestSweepStealthJob.sol';
import {IKeep3rV2} from 'interfaces/external/IKeep3rV2.sol';

import 'test/utils/keeper_constants.sol';

import 'forge-std/Script.sol';

/**
 * @notice Deploy the harvest sweep stealth job
 */

contract Deploy is Script {
  function setUp() external {}

  function run() external {
    vm.startBroadcast();

    address _futureJobAddress = computeCreateAddress(msg.sender, vm.getNonce(msg.sender) + 1);

    IKeep3rV2(KEEP3R_V2).addJob(_futureJobAddress);

    HarvestSweepStealthJob job = new HarvestSweepStealthJob(
      V2_KEEPER_GOVERNOR,
      MECHANICS_REGISTRY,
      STEALTH_RELAYER,
      V2_KEEPER,
      HARVEST_COOLDOWN,
      KEEP3R_V2,
      KEEP3R_V2_HELPER,
      BOND,
      MIN_BOND,
      EARNED,
      AGE,
      ONLY_EOA
    );

    IKeep3rV2(KEEP3R_V2).changeJobOwnership(address(job), V2_KEEPER_GOVERNOR);

    vm.stopBroadcast();

    console.log('job deployed at ', address(job));
    console.log('deployer address ', msg.sender);
  }
}
