// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";
import { RateLimits }        from "src/RateLimits.sol";

library ALMProxyDeploy {

    function deploy(address admin) external returns (address almProxy) {
        almProxy = address(new ALMProxy(admin));
    }

}

library ForeignControllerDeploy {

    function deploy(
        address admin,
        address psm,
        address usdc,
        address cctp
    )
        external returns (address almProxy, address foreignController, address rateLimits)
    {
        almProxy   = ALMProxyDeploy.deploy(admin);
        rateLimits = RateLimitsDeploy.deploy(admin);

        foreignController = address(new ForeignController({
            admin_      : admin,
            proxy_      : almProxy,
            rateLimits_ : rateLimits,
            psm_        : psm,
            usdc_       : usdc,
            cctp_       : cctp
        }));
    }

}

library MainnetControllerDeploy {

    function deploy(
        address admin,
        address vault,
        address buffer,
        address psm,
        address daiUsds,
        address cctp,
        address susds
    )
        external returns (address almProxy, address mainnetController, address rateLimits)
    {
        almProxy   = ALMProxyDeploy.deploy(admin);
        rateLimits = RateLimitsDeploy.deploy(admin);

        mainnetController = address(new MainnetController({
            admin_      : admin,
            proxy_      : almProxy,
            rateLimits_ : rateLimits,
            vault_      : vault,
            buffer_     : buffer,
            psm_        : psm,
            daiUsds_    : daiUsds,
            cctp_       : cctp,
            susds_       : susds
        }));
    }

}

library RateLimitsDeploy {

    function deploy(address admin) external returns (address) {
        return address(new RateLimits(admin));
    }

}
