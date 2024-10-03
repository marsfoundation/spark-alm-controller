// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract PSM extends Ownable {

    IERC20 public gem;
    IERC20 public dai;

    constructor(address owner_, address gem_, address dai_) Ownable(owner_) {
        gem = IERC20(gem_);
        dai = IERC20(dai_);
    }

    function buyGemNoFee(address usr, uint256 usdcAmount) external onlyOwner returns (uint256 daiAmount) {
        daiAmount = usdcAmount * 1e12;

        dai.transferFrom(usr, address(this), daiAmount);
        gem.transfer(usr, usdcAmount);
    }

    function sellGemNoFee(address usr, uint256 usdcAmount) external onlyOwner returns (uint256 daiAmount) {
        daiAmount = usdcAmount * 1e12;

        gem.transferFrom(usr, address(this), usdcAmount);
        dai.transfer(usr, daiAmount);
    }

    function pocket() external view returns(address) {
        return address(this);
    }

    function to18ConversionFactor() external pure returns (uint256) {
        return 1e12;
    }

    function fill() external {
    }

}
