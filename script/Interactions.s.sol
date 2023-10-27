// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @notice Changes in our createSubscription(), addConsumer() and fundSubscription()
 * contract.
 * @dev vm.startBroadcast(deployerKey) --> it signs the transaction and our setup is smart enough
 * to switch PRIVATE_KEY between anvil and sepolia
 */

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,,, address vrfCoordinatorV2,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    // Here we just want to use the vrfCoordinatorV2 address from the helperConfig
    function createSubscription(address vrfCoordinatorV2, uint256 deployerKey) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatorV2).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (uint64 subId,,,,, address vrfCoordinatorV2, address link, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorV2, subId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinatorV2, uint64 subId, address link, uint256 deployerKey) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinatorV2).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinatorV2, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint64 subId, uint256 deployerKey)
        public
    {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        /**
         * @dev vm.startBroadcast(deployerKey) --> we added deployerKey bcos when VRFCoordinatorV2Mock
         * calls the addConsumer() i.e VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
         *
         * On anvil chain, we dont need the deployerKey/PRIVATE_KEY  bcos anvil picks it automatically.
         *
         * But on sepolia chain, it will still default to use anvil PRIVATE_KEY if we dont specify it.
         *
         * Our setup is smart enough to switch between deployerKey depending on the chainId
         */
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (uint64 subId,,,,, address vrfCoordinatorV2,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2, subId, deployerKey);
    }

    function run() external {
        /**
         * @dev mostRecentlyDeployed --> This is the Raffle contract address that is recently deployed
         * to the local blockchain network. This is the contract that will be added as a consumer
         * to the VRF Coordinator
         */
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
