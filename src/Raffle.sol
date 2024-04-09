// SPDX-License-Identifier: MIT

// -- Layout Contract:
// 1.version
// 2.imports
// 3.errors
// 4.interfaces, libraries, contracts
// 5.Type Declarations
// 6.State variables
// 7.Events
// 8.Modifiers
// 9.Functions

// -- Layout Function:
// construcor
// receive function
// fallback function
// external
// public
// private
// view / pure

pragma solidity ^0.8.0;

/**
 * @title Lottery smart contract
 * @author Patrick C / Ric
 */
import {VRFCoordinatorV2Interface} from "./chainLink/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "./chainLink/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    // 3.ERRORS
    error Raffle__NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_NotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currentBlanace,
        uint256 numPlayers,
        uint256 raffleState
    );

    // 5.TYPE DECLARATIONS
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    // 6.STATE VARIABLES
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // -Lottery duration in sec
    uint256 private immutable i_interval;
    // VRF Coordinator address/gas/Id
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp;
    // -Array with players
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // 7. EVENTS
    event EnterRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // 9. FUNCTIONS
    function enterRaffle() external payable {
        // --Example with Require
        // require(msg.value >= i_entraceFee, "Not Enough eth sent");
        // We use ERRORs >> more efficient
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        // build array of players
        s_players.push(payable(msg.sender));
        //Emit the event
        emit EnterRaffle(msg.sender);
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_NotOpen();
        }
    }
    // AUTOMATION
    /**
     * @dev this is the function chainlink node automation calll to see if it is time to perform UPkeep
     * Following needs to b e true:
     * 1. Time interval has passed
     * 2. Raffle state is OPEN
     * 3. Conrtacthas ETH
     * 4. Subscription is funded with Link
     */
    function checkUpkeep(
        bytes memory /*checkeData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; //1.
        bool isOpen = RaffleState.OPEN == s_raffleState; //2.
        bool hasBalance = address(this).balance > 0; //3
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // We need:
    // 1. Get a Random Number
    // 2. Use the Random numb to pick a player
    // 3. Rand Numb automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // RND Numb from VRF
        // 1-Request the rdn numb
        // This from VRF Consumenr contract
        //uint256 requestId = i_vrfCoordinator.requestRandomWords(
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // is the keyHash
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // This is redundant
        // If you check the vrf coordinator event = request random ward it has this topic requestId
        emit RequestedRaffleWinner(requestId);
    }
    // 2-Get the rdn numb - callback funct
    // This from VRF ConsumenrBase contract
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexWinner];
        s_recentWinner = winner;
        // Reopen Raffle + reset array + reset timestamp
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        //s_recentWinner.transfer(address(this).balance)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    // Getters
    function getEntraceFees() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexPlayers) external view returns (address) {
        return s_players[indexPlayers];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
