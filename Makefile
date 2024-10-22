# Staging Deployments
deploy-sepolia-staging  :; forge script script/staging/DeploySepolia.s.sol:DeploySepoliaStaging --sender ${ETH_FROM} --broadcast --slow
deploy-ethereum-staging :; forge script script/staging/DeployEthereum.s.sol:DeployEthereumStaging --sender ${ETH_FROM} --broadcast --slow --verify

# Production Deployments
deploy-base     :; forge script script/Deploy.s.sol:DeployBaseFull --sender ${ETH_FROM} --broadcast --verify
deploy-ethereum :; forge script script/Deploy.s.sol:DeployMainnetFull --sender ${ETH_FROM} --broadcast --verify
