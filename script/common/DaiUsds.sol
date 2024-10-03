// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract DaiUsds is Ownable {

    IERC20 public immutable dai;
    IERC20 public immutable usds;

    constructor(address owner_, address dai_, address usds_) Ownable(owner_) {
        dai  = IERC20(dai_);
        usds = IERC20(usds_);
    }

    function daiToUsds(address usr, uint256 wad) external onlyOwner {
        dai.transferFrom(usr, address(this), wad);
        usds.transfer(usr, wad);
    }

    function usdsToDai(address usr, uint256 wad) external onlyOwner {
        usds.transferFrom(usr, address(this), wad);
        dai.transfer(usr, wad);
    }
}
