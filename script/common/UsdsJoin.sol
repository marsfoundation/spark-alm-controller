// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract UsdsJoin is Ownable {

    address public immutable vat;
    IERC20  public immutable usds;

    constructor(address vat_, address usds_) {
        vat  = vat_;
        usds = IERC20(usds_);
    }

    function join(address usr, uint256 wad) external onlyOwner {
        usds.transferFrom(msg.sender, address(this), wad);
    }

    function exit(address usr, uint256 wad) external onlyOwner {
        usds.transfer(usr, wad);
    }

    // To fully cover daiJoin abi
    function dai() external view returns (address) {
        return address(usds);
    }

}
