deploy-base     :; forge script script/Deploy.s.sol:DeployBaseFull --broadcast --verify
deploy-ethereum :; forge script script/Deploy.s.sol:DeployMainnetFull --broadcast --verify
deploy-sepolia  :; forge script script/testnet/DeploySepolia.s.sol:DeploySepolia --sender ${ETH_FROM} #--broadcast --slow
