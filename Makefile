# Staging Full Deployment with Dependencies
deploy-staging-full :; forge script script/staging/FullStagingDeploy.s.sol:FullStagingDeploy --sender ${ETH_FROM} --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Staging Deployments
deploy-mainnet-staging-controller :; ENV=staging forge script script/Deploy.s.sol:DeployMainnetController --sender ${ETH_FROM} --broadcast --verify

deploy-base-staging-controller :; CHAIN=base ENV=staging forge script script/Deploy.s.sol:DeployForeignController --sender ${ETH_FROM} --broadcast --verify

# Production Deployments
deploy-mainnet-production-full       :; ENV=production forge script script/Deploy.s.sol:DeployMainnetFull --sender ${ETH_FROM} --broadcast --verify
deploy-mainnet-production-controller :; ENV=production forge script script/Deploy.s.sol:DeployMainnetController --sender ${ETH_FROM} --broadcast --verify

deploy-base-production-full       :; CHAIN=base ENV=production forge script script/Deploy.s.sol:DeployForeignFull --sender ${ETH_FROM} --broadcast --verify
deploy-base-production-controller :; CHAIN=base ENV=production forge script script/Deploy.s.sol:DeployForeignController --sender ${ETH_FROM} --broadcast --verify
