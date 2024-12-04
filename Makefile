# Staging Deployments
upgrade-staging :; forge script script/staging/DeployStaging.s.sol:DeployStaging --sender ${ETH_FROM} #--broadcast --slow --verify

# Production Deployments
deploy-base     :; forge script script/Deploy.s.sol:DeployBaseFull --sender ${ETH_FROM} --broadcast --verify
deploy-ethereum :; forge script script/Deploy.s.sol:DeployMainnetFull --sender ${ETH_FROM} --broadcast --verify
