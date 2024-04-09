// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
//import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "../../src/chainLink/mocks/VRFCoordinatorV2InterfaceMock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    event EnterRaffle(address indexed user);

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    // Unit TESTs
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    ///////
    // Enter Raffle
    //////

    function testRaffleRevertWhenNonPayEnough() public {
        // Arrange
        vm.prank(USER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        // Assert
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenEnter() public {
        //Arrange
        vm.prank(USER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRec = raffle.getPlayers(0);
        assert(playerRec == USER);
    }
    // TEST EVENTS
    function testRaffleEventOnEntance() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnterRaffle(USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating() public {
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_NotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
    }
    ///////
    // Test Upkeep
    //////

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        //Codiftions for Automation/Upkeep are few: one is Raffle has balance
        // if all other condition are treu but balnce false then ...
        //Arrange 1. time has passed
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        //It needs to be in Calc period >> we need to start it gfirst
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    // testcheckUpkeepReturnsFalseIfEnoughTimehasPassed
    // testcheckUpkeepReturnsTrueIfParametersAreGo
    function testPerformUpkeepOnlyRunIfCheckUPkeepIsTrue() public {
        //Arrenge
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act //Atrrange
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
        //Arrange
        //uint256 currentBalance = 0;
        uint256 currentBalance = address(raffle).balance;
        uint256 numPlayers = 0;
        //uint256 raffleState = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Act / Assert
        //We can use expctRevert abi.encoder
        //vm.expectRevert(Raffle.Raffle_UpkeepNotNeeded.selector;)
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }
    modifier raffleEnterAndTimePasses() {
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleEmitRequestId()
        public
        raffleEnterAndTimePasses
    {
        //Act
        vm.recordLogs();
        raffle.performUpkeep(""); // this will triger emit request id from vrf
        // Following is array with all emit-problem how we found requestId emit
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        // we can look at the log ... logs are all in bytes32
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();
        console.log("Logs: ", uint256(requestId));

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }
    ///////
    // Test FullFillWords
    //////
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
    // function testFUlFillWOrdsCanOnlyBeCallAfterPerformUpkeepFUZZ(
    //     uint256 randomRequestId
    // ) public raffleEnterAndTimePasses
    // {
    //     //Arrange
    //     vm.expectRevert("Not Existing");
    //     //call the function(fulFilRndWrds) which has 2 arguments 1ddress 2Reqst ID
    //     //we want to fail
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         randomRequestId,
    //         address(raffle)
    //     );
    // }
    // function testFUlFillWOrdsCanOnlyBeCallAfterPerformUpkeep()
    //     public
    //     raffleEnterAndTimePasses
    //     skipFork
    // {
    //     //Arrange
    //     vm.expectRevert("Not Existing");
    //     //call the function(fulFilRndWrds) which has 2 arguments 1ddress 2Reqst ID
    //     //we want to fail
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         0,
    //         address(raffle)
    //     );
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         1,
    //         address(raffle)
    //     );
    // }
    // TEST THE ALL THING////////
    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEnterAndTimePasses
        skipFork
    {
        //We need to call fillRandomWords  -- but only VRF can!! we have to be VRF
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        // Create palyers addresses and give 1 eth and enter in the raffle
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address user = address(uint160(i));
            hoax(user, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);
        // Prepare for using VRF >>> requestID as test above
        vm.recordLogs();
        raffle.performUpkeep(""); // this will triger emit request id from vrf
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // Pretend to be chainLink VRF to get Rand Numb
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //Assert
        // assert(uint256(raffle.getRaffleState()) == 0);
        // assert(raffle.getRecentWinner() != address(0));
        // assert(raffle.getLengthPlayers() == 0);
        // assert(previousTimeStamp < raffle.getLastTimeStamp());
        console.log("Winner Bal: ", raffle.getRecentWinner().balance);
        console.log("Prize: ", prize);
        assert(
            raffle.getRecentWinner().balance ==
                prize + STARTING_USER_BALANCE - entranceFee
        );
    }
}
