// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            bytes32 gasLane,
            uint256 automationUpdateInterval,
            uint256 raffleEntranceFee,
            uint32 callbackGasLimit,
            address vrfCoordinatorV2,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // We are going to create a subscriptionId
            CreateSubscription createSubscription = new CreateSubscription();

            /**
             * @dev Here we programmatically override the subscriptionId in the helperConfig
             * contract which we purposely set to 0. so after deployment we wont need to manually
             * change the subscriptionId
             */
            subscriptionId = createSubscription.createSubscription(vrfCoordinatorV2, deployerKey);

            // We Fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinatorV2, subscriptionId, link, deployerKey);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2
        );
        vm.stopBroadcast();

        /**
         * @dev Here we add our raffle contract as our consumer
         */
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinatorV2, subscriptionId, deployerKey);

        return (raffle, helperConfig);
    }
}



// forge script script/DeployRaffle.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
// [⠒] Compiling...
// [⠢] Compiling...
// No files changed, compilation skipped
// Script ran successfully.

// == Return ==
// 0: contract Raffle 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
// 1: contract HelperConfig 0xC7f2Cf4845C6db0e1a1e91ED41Bcd0FcC1b0E141

// == Logs ==
//   Creating subscription on chainId:  31337
//   Your subscription Id is:  1
//   Please update the subscriptionId in HelperConfig.s.sol
//   Funding subscription:  1
//   Using vrfCoordinator:  0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
//   On ChainID:  31337
//   Adding consumer contract:  0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
//   Using vrfCoordinator:  0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
//   On ChainID:  31337

// EIP-3855 is not supported in one or more of the RPCs used.
// Unsupported Chain IDs: 31337.
// Contracts deployed with a Solidity version equal or higher than 0.8.20 might not work properly.
// For more information, please see https://eips.ethereum.org/EIPS/eip-3855

// ## Setting up (1) EVMs.

// ==========================

// Chain 31337

// Estimated gas price: 5 gwei

// Estimated total gas used for script: 5036553

// Estimated amount required: 0.025182765 ETH

// ==========================

// ###
// Finding wallets for all the necessary addresses...
// ##
// Sending transactions [0 - 6].
// ⠂ [00:00:00] [######################################################################################################] 7/7 txes (0.0s)Transactions saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/broadcast/DeployRaffle.s.sol/31337/run-latest.json

// Sensitive values saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/cache/DeployRaffle.s.sol/31337/run-latest.json

// ##
// Waiting for receipts.
// ⠒ [00:00:00] [##################################################################################################] 7/7 receipts (0.0s)##### anvil-hardhat
// ✅  [Success]Hash: 0xc9b097fac6ff5b11089fc3177c34396e768bb70536827bd58ce830103004a33d
// Contract Address: 0x5FbDB2315678afecb367f032d93F642f64180aa3
// Block: 1
// Paid: 0.002971544 ETH (742886 gas * 4 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0xec8fdf14b179dbe549df50332662a1ab504fc4f16669e04b9b660014a30c7701
// Contract Address: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
// Block: 2
// Paid: 0.005252132070393759 ETH (1353227 gas * 3.881190717 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0x1063cc0d2e4a3dc389eb7fdd738d9fe2f04dd5653240f47f85d8c229bf343851
// Contract Address: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
// Block: 2
// Paid: 0.003356333415149373 ETH (864769 gas * 3.881190717 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0xa527d94887f92b36a973ca8929d40ffd124938880891597d4a53df146fb543ea
// Block: 2
// Paid: 0.000263350433720601 ETH (67853 gas * 3.881190717 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0x4faa8291c098546bec1f218de35d2426c911f3cbda87b1ae525aa6817455e692
// Block: 2
// Paid: 0.000114037145646894 ETH (29382 gas * 3.881190717 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0x10130eadd05f48c1df17e6a8cb60102348ce0d76cb0841c5c0670f6a66d0ed26
// Contract Address: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
// Block: 2
// Paid: 0.002838978454954707 ETH (731471 gas * 3.881190717 gwei)


// ##### anvil-hardhat
// ✅  [Success]Hash: 0xdee50cf7c183329b3bc5a50b5dd4de2850f53eeb743ab8f30a92f07b12a0f0e3
// Block: 2
// Paid: 0.000274920263247978 ETH (70834 gas * 3.881190717 gwei)


// Transactions saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/broadcast/DeployRaffle.s.sol/31337/run-latest.json

// Sensitive values saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/cache/DeployRaffle.s.sol/31337/run-latest.json



// ==========================

// ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
// Total Paid: 0.015071295783113312 ETH (3860422 gas * avg 3.898163471 gwei)

// Transactions saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/broadcast/DeployRaffle.s.sol/31337/run-latest.json

// Sensitive values saved to: /home/shadow-walker/foundry-full-course-f23/foundry-smart-contract-lottery-f23/cache/DeployRaffle.s.sol/31337/run-latest.json

