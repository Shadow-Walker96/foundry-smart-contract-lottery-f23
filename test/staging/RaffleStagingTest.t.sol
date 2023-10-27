// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

// contract RaffleTest is StdCheats, Test {
contract RaffleTest is Test {
    /* Errors */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint64 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        (
            ,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2, // link
            // deployerKey
            ,
        ) = helperConfig.activeNetworkConfig();
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier onlyOnDeployedContracts() {
        if (block.chainid == 31337) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEntered onlyOnDeployedContracts {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(0, address(raffle));

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered onlyOnDeployedContracts {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}

//  forge test
// [⠘] Compiling...
// No files changed, compilation skipped

// Running 2 tests for test/staging/RaffleStagingTest.t.sol:RaffleTest
// [PASS] testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() (gas: 69950)
// [PASS] testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() (gas: 69949)
// Test result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.05s

// Running 12 tests for test/unit/RaffleTest.t.sol:RaffleTest
// [PASS] testCheckUpkeepReturnsFalseIfItHasNoBalance() (gas: 19095)
// [PASS] testCheckUpkeepReturnsFalseIfRaffleIsntOpen() (gas: 145184)
// [PASS] testDontAllowPlayersToEnterWhileRaffleIsCalculating() (gas: 150042)
// [PASS] testEmitsEventOnEntrance() (gas: 68720)
// [PASS] testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256) (runs: 256, μ: 78424, ~: 78424)
// [PASS] testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() (gas: 234080)
// [PASS] testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() (gas: 141501)
// [PASS] testPerformUpkeepRevertsIfCheckUpkeepIsFalse() (gas: 17396)
// [PASS] testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() (gas: 147148)
// [PASS] testRaffleRecordsPlayerWhenTheyEnter() (gas: 68198)
// [PASS] testRaffleRevertsWhenYouDontPayEnough() (gas: 10823)
// [PASS] testRaffleStateInitializesInOpenState() (gas: 7596)
// Test result: ok. 12 passed; 0 failed; 0 skipped; finished in 1.32s

// Ran 2 test suites: 14 tests passed, 0 failed, 0 skipped (14 total tests)
