// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {DSTestFull} from 'test/utils/DSTestFull.sol';
import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';

contract CommonE2EBase is DSTestFull {
  uint256 internal constant _FORK_BLOCK = 15_452_788;

  string internal _initialGreeting = 'hola';
  address internal _user = _label('user');
  address internal _owner = _label('owner');
  address internal _daiWhale = 0x42f8CA49E88A8fd8F0bfA2C739e648468b8f9dec;
  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.prank(_owner);
  }

  // Worked 0x9d7cd0041abd91f281e282db3fba7a9db9e4cc8b (harvest public 0xf4F748D45E03a70a9473394B28c3C7b5572DfA82) at ts 1678931363 (block 16841103)
  /**
   * @notice Test if a strategy which is not profitable and when not in the credit window is not workable
   */
  function testShouldBeNonWorkableWhenOutsideCreditWindow() external {}

  /**
   * @notice Test if a strategy which is not profitable and when in the credit window is workable
   */
  function testShouldBeWorkableWhenInCreditWindow() external {}
}
