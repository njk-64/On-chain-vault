include testing.env

.PHONY: dependencies
dependencies: lib/forge-std lib/openzeppelin-contracts

.PHONY: forge-test
forge-test: dependencies
	forge test --fork-url ${TESTING_FORK_RPC_AVAX} -vv 
