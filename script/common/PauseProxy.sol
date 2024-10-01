// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract PauseProxy is Ownable {

    constructor(address owner_) Ownable(owner_) {
    }

    function exec(address usr, bytes memory fax)
        external onlyOwner
        returns (bytes memory out)
    {
        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }

}
