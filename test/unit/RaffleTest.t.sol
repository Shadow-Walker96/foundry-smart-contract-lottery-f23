// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event RaffleEnter(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint64 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2,
            link,
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    /**
     * @dev Raffle.RaffleState.OPEN --> Raffle is a type of our Raffle contract, and we access directly
     * the enum type i.e RaffleState.OPEN
     */
    function testRaffleStateInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////
    // enterRaffle         //
    /////////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: raffleEntranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /**
     * @dev We followed the exact convention about testing events from foundry documentation
     */
    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /**
     * @dev We want to test performUpkeep() function, so we have to cheat a little.
     * we can use foundry cheatcodes to do this
     * vm.wrap() --> it manupulates the timestamp
     * vm.roll() --> it manupulates the block number
     */
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /////////////////////////
    // checkUpkeep         //
    /////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    /**
     * @dev We would notice that we didnt assert here. the reason is bcos when we call the
     * performUpKeep() the test will pass bcos we specify the increase in time and block number
     * i.e vm.warp() and vm.roll() respectively. so we dont need to assert anything
     *
     * But if we comment vm.wrap() and vm.roll() we would notice that the test will fail which is good
     *
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }

    /**
     * @dev Here we test for this in our Raffle.sol contract
     * if (!upkeepNeeded) {
     *         revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
     *     }
     *     we use abi.encodeWithSelector() to get the exact feedback in of the parameter specified in the
     *     revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState))
     */
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /**
     * @dev We can use the debugger tool from foundry to get the requestId from the emitted event
     * i.e forge test --debug "performUpKeep()"
     * But we can get the requestId our selves, bcos we know that when performUpkeep() is called
     * two events are emitted:
     * 1. from i_vrfCoordinator.requestRandomWords() which will emit an event consisting of the requestId
     * 2. our own event i.e emit RequestedRaffleWinner(requestId);
     *
     * so bytes32 requestId = entries[1].topics[1];
     *
     * [1] means the second event emitted which is our own event
     *
     * and is byte32 bcos all recorded event by foundry is in byte32
     */
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    /**
     * @dev we created a modifier skipFork() bcos we only want to test this functions i.e
     * testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() and
     * testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
     *
     * The reason is bcos the real VRFCoordinationV2 contract parameters is different from
     * the mock VRFCoordinationV2
     *
     * The mock VRFCoordinationV2 was created to make test easy on the local blockchain
     *
     * Also the real VRFCoordinationV2 request for proof as parameter
     * i.e function fulfillRandomWords(...)
     * param for the real VRFCoordinationV2 is proof contains the proof and randomness
     */
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /**
     * @notice 06:11:49 ----> Intro to Fuzz Tests
     * @dev To write this test we can pass 0 or 1 or any other number to keep guessing
     * the requestId to see if our test will pass or fail.
     *
     * Instead of repeating the code below i.e
     * "VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(0, address(raffle));"
     * or "VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(1, address(raffle));"
     *
     * What we will do here is that we can put in a randomRequestId as a parameter in our test function.
     *
     * So what foundry will do is that it will inject a random number, run a fuzz test on
     * that random number and will keep guessing until it pass
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Act / Assert
        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(randomRequestId, address(raffle));

        // VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3; // Here we have three people enter our raffle
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i)); // it will create different address for each player
            hoax(player, 1 ether); // hoax = vm.prank() + vm.deal()
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act --> We pretend to be the Chainlink VRF to get random number & pick winner
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

// forge test --mt testDontAllowPlayersToEnterWhileRaffleIsCalculating
// [⠒] Compiling...
// [⠔] Compiling 2 files with 0.8.19
// [⠒] Solc 0.8.19 finished in 11.32s
// Compiler run successful with warnings:

// Running 1 test for test/unit/RaffleTest.t.sol:RaffleTest
// [PASS] testDontAllowPlayersToEnterWhileRaffleIsCalculating() (gas: 150064)
// Test result: ok. 1 passed; 0 failed; 0 skipped; finished in 1.67s

// Ran 1 test suites: 1 tests passed, 0 failed, 0 skipped (1 total tests)

// forge test
// [⠊] Compiling...
// No files changed, compilation skipped

// Running 12 tests for test/unit/RaffleTest.t.sol:RaffleTest
// [PASS] testCheckUpkeepReturnsFalseIfItHasNoBalance() (gas: 19095)
// [PASS] testCheckUpkeepReturnsFalseIfRaffleIsntOpen() (gas: 145184)
// [PASS] testDontAllowPlayersToEnterWhileRaffleIsCalculating() (gas: 150042)
// [PASS] testEmitsEventOnEntrance() (gas: 68720)
// [PASS] testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256) (runs: 256, μ: 78403, ~: 78403)
// [PASS] testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() (gas: 234071)
// [PASS] testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() (gas: 141501)
// [PASS] testPerformUpkeepRevertsIfCheckUpkeepIsFalse() (gas: 17396)
// [PASS] testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() (gas: 147148)
// [PASS] testRaffleRecordsPlayerWhenTheyEnter() (gas: 68198)
// [PASS] testRaffleRevertsWhenYouDontPayEnough() (gas: 10823)
// [PASS] testRaffleStateInitializesInOpenState() (gas: 7596)
// Test result: ok. 12 passed; 0 failed; 0 skipped; finished in 134.59ms

// Ran 1 test suites: 12 tests passed, 0 failed, 0 skipped (12 total tests)

// forge test --fork-url $SEPOLIA_RPC_URL
// [⠒] Compiling...
// No files changed, compilation skipped

// Running 12 tests for test/unit/RaffleTest.t.sol:RaffleTest
// [PASS] testCheckUpkeepReturnsFalseIfItHasNoBalance() (gas: 19100)
// [PASS] testCheckUpkeepReturnsFalseIfRaffleIsntOpen() (gas: 138790)
// [PASS] testDontAllowPlayersToEnterWhileRaffleIsCalculating() (gas: 143648)
// [PASS] testEmitsEventOnEntrance() (gas: 68720)
// [PASS] testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256) (runs: 256, μ: 70048, ~: 70048)
// [PASS] testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() (gas: 69969)
// [PASS] testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() (gas: 135107)
// [FAIL. Reason: Error != expected error: 0x584327aa000000000000000000000000000000000000000000000000008e1bc9bf04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 != 0x584327aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000] testPerformUpkeepRevertsIfCheckUpkeepIsFalse() (gas: 17442)
// [PASS] testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() (gas: 140754)
// [PASS] testRaffleRecordsPlayerWhenTheyEnter() (gas: 68198)
// [PASS] testRaffleRevertsWhenYouDontPayEnough() (gas: 10823)
// [PASS] testRaffleStateInitializesInOpenState() (gas: 7596)
// Test result: FAILED. 11 passed; 1 failed; 0 skipped; finished in 7.08s

// Ran 1 test suites: 11 tests passed, 1 failed, 0 skipped (12 total tests)

// Failing tests:
// Encountered 1 failing test in test/unit/RaffleTest.t.sol:RaffleTest
// [FAIL. Reason: Error != expected error: 0x584327aa000000000000000000000000000000000000000000000000008e1bc9bf04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 != 0x584327aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000] testPerformUpkeepRevertsIfCheckUpkeepIsFalse() (gas: 17442)

// Encountered a total of 1 failing tests, 11 tests succeeded

// forge coverage
// [⠒] Compiling...
// [⠢] Compiling 32 files with 0.8.19
// [⠔] Solc 0.8.19 finished in 21.70s

// Analysing contracts...
// Running tests...
// | File                      | % Lines         | % Statements    | % Branches    | % Funcs       |
// |---------------------------|-----------------|-----------------|---------------|---------------|
// | script/DeployRaffle.s.sol | 0.00% (0/14)    | 0.00% (0/19)    | 0.00% (0/2)   | 0.00% (0/1)   |
// | script/HelperConfig.s.sol | 0.00% (0/11)    | 0.00% (0/16)    | 0.00% (0/2)   | 0.00% (0/3)   |
// | script/Interactions.s.sol | 0.00% (0/41)    | 0.00% (0/50)    | 0.00% (0/2)   | 0.00% (0/9)   |
// | src/Raffle.sol            | 83.78% (31/37)  | 86.36% (38/44)  | 75.00% (6/8)  | 61.54% (8/13) |
// | test/mocks/LinkToken.sol  | 0.00% (0/10)    | 0.00% (0/12)    | 0.00% (0/2)   | 0.00% (0/3)   |
// | Total                     | 27.43% (31/113) | 26.95% (38/141) | 37.50% (6/16) | 27.59% (8/29) |

// forge coverage --report debug --> This command will print the report to the shell

// forge coverage --report debug > coverage.txt ---> it will print the report to coverage.txt file

// I ran this specific test again to see the good part of adding console.log in our Raffle.sol contract
// The result below will show this : hi from enterRaffle() in Raffle.sol Contract

// forge test --mt testRaffleRecordsPlayerWhenTheyEnter -vvvv
// [⠃] Compiling...
// [⠃] Compiling 4 files with 0.8.19
// [⠒] Solc 0.8.19 finished in 72.61s

// Running 1 test for test/unit/RaffleTest.t.sol:RaffleTest
// [PASS] testRaffleRecordsPlayerWhenTheyEnter() (gas: 71454)
// Logs:
//   Creating subscription on chainId:  31337
//   Your subscription Id is:  1
//   Please update the subscriptionId in HelperConfig.s.sol
//   Funding subscription:  1
//   Using vrfCoordinator:  0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
//   On ChainID:  31337
//   Adding consumer contract:  0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76
//   Using vrfCoordinator:  0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
//   On ChainID:  31337
//   hi from enterRaffle() in Raffle.sol Contract

// Traces:
//   [71454] RaffleTest::testRaffleRecordsPlayerWhenTheyEnter()
//     ├─ [0] VM::prank(player: [0x44E97aF4418b7a17AABD8090bEA0A471a366305C])
//     │   └─ ← ()
//     ├─ [51043] Raffle::enterRaffle{value: 10000000000000000}()
//     │   ├─ emit RaffleEnter(player: player: [0x44E97aF4418b7a17AABD8090bEA0A471a366305C])
//     │   ├─ [0] console::log(hi from enterRaffle() in Raffle.sol Contract) [staticcall]
//     │   │   └─ ← ()
//     │   └─ ← ()
//     ├─ [685] Raffle::getPlayer(0) [staticcall]
//     │   └─ ← player: [0x44E97aF4418b7a17AABD8090bEA0A471a366305C]
//     └─ ← ()

// Test result: ok. 1 passed; 0 failed; 0 skipped; finished in 654.07ms

// Ran 1 test suites: 1 tests passed, 0 failed, 0 skipped (1 total tests)

// forge test --debug testRaffleRecordsPlayerWhenTheyEnter ---> It will display a code setup through in
// the shell, we see the specific opcodes in our contract.

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
