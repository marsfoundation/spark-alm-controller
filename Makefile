deploy-base     :; forge script script/Deploy.s.sol:DeployBaseFull --rpc-url ${ETH_RPC_URL} --interactives 1 #--broadcast --verify
deploy-ethereum :; forge script script/Deploy.s.sol:DeployMainnetFull --rpc-url ${ETH_RPC_URL} --interactives 1 #--broadcast --verify
