-include .env
.PHONY: all test 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# Default chain ANVIL
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
# if == network sepolia is used, the sepolia stuff, otherwise anvil
ifeq ($(findstring --network sepolia,$(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif 
# Add the @ not to show the script in the terminal
deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)
#  ANVIL >>> make deploy
#  SEPOLIS >>> make deploy ARGS="--network sepolia"

test-sepolia-fork:
	forge test  -vvvv --fork-url $(SEPOLIA_RPC_URL)

install:; forge install chainaccelorg/foundry-devops"0.0.11 --no-commit && forge install transmissions11/solmate@v6 --no-commit

compile:
	forge compile

test:
	forge test

