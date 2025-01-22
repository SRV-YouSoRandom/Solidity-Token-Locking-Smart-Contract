// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenLockingPlatform is Ownable(msg.sender) {
    using SafeMath for uint256;

    struct Lock {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 lockStart;
        uint256 lockDuration;
        uint256 vestingDuration;
        bool active;
        address token;
    }

    struct Vote {
        uint256 proposalId;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        string proposalType; // "release" or "extend"
        uint256 parameter; // Tokens to release or seconds to extend
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public nextProposalId;
    mapping(uint256 => Vote) public votes;
    mapping(address => Lock) public locks;
    mapping(address => bool) public communityVotedUnlock;

    event TokensLocked(address indexed user, address indexed token, uint256 amount, uint256 lockDuration, uint256 vestingDuration);
    event TokensReleased(address indexed user, uint256 amount);
    event CommunityVotedUnlock(address indexed user, bool approved);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string proposalType, uint256 parameter);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyIfActive(address user) {
        require(locks[user].active, "No active lock found");
        _;
    }

    /**
     * @notice Lock tokens with specified lock and vesting durations.
     * @param token The address of the ERC20 token to lock.
     * @param amount The total amount of tokens to lock.
     * @param lockDuration The initial lock period (in seconds).
     * @param vestingDuration The duration over which tokens are vested after the lock period.
     */
    function lockTokens(
        address token,
        uint256 amount,
        uint256 lockDuration,
        uint256 vestingDuration
    ) external {
        require(amount > 0, "Amount must be greater than zero");
        require(lockDuration >= 180 days, "Lock duration must be at least 6 months");
        require(vestingDuration >= 0, "Vesting duration must be non-negative");

        IERC20 erc20 = IERC20(token);
        require(erc20.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        locks[msg.sender] = Lock({
            totalAmount: amount,
            releasedAmount: 0,
            lockStart: block.timestamp,
            lockDuration: lockDuration,
            vestingDuration: vestingDuration,
            active: true,
            token: token
        });

        emit TokensLocked(msg.sender, token, amount, lockDuration, vestingDuration);
    }

    /**
     * @notice Release tokens based on the vesting schedule.
     */
    function releaseTokens() external onlyIfActive(msg.sender) {
        Lock storage userLock = locks[msg.sender];

        require(block.timestamp >= userLock.lockStart.add(userLock.lockDuration), "Lock period not yet over");

        uint256 elapsedTime = block.timestamp.sub(userLock.lockStart.add(userLock.lockDuration));
        uint256 vestingEnd = userLock.lockStart.add(userLock.lockDuration).add(userLock.vestingDuration);

        uint256 releasableAmount;

        if (block.timestamp >= vestingEnd) {
            releasableAmount = userLock.totalAmount.sub(userLock.releasedAmount);
        } else {
            releasableAmount = userLock.totalAmount.mul(elapsedTime).div(userLock.vestingDuration).sub(userLock.releasedAmount);
        }

        require(releasableAmount > 0, "No tokens available for release");

        userLock.releasedAmount = userLock.releasedAmount.add(releasableAmount);
        IERC20(userLock.token).transfer(msg.sender, releasableAmount);

        emit TokensReleased(msg.sender, releasableAmount);

        if (userLock.releasedAmount == userLock.totalAmount) {
            userLock.active = false;
        }
    }

    /**
     * @notice Propose a vote to release tokens early or extend the lock period.
     * @param proposalType The type of proposal ("release" or "extend").
     * @param parameter The parameter for the proposal (tokens to release or seconds to extend).
     */
    function proposeVote(string memory proposalType, uint256 parameter) external {
    require(locks[msg.sender].active, "Only active lockers can propose");
    require(
        keccak256(abi.encodePacked(proposalType)) == keccak256("release") ||
        keccak256(abi.encodePacked(proposalType)) == keccak256("extend"),
        "Invalid proposal type"
    );
    
    // Initialize a new Vote
    Vote storage vote = votes[nextProposalId];
    vote.proposalId = nextProposalId;
    vote.proposer = msg.sender;
    vote.startTime = block.timestamp;
    vote.endTime = block.timestamp.add(7 days);
    vote.yesVotes = 0;
    vote.noVotes = 0;
    vote.proposalType = proposalType;
    vote.parameter = parameter;
    vote.executed = false;

    emit ProposalCreated(nextProposalId, msg.sender, proposalType, parameter);
    nextProposalId++;
    }


    /**
     * @notice Cast a vote on a proposal.
     * @param proposalId The ID of the proposal to vote on.
     * @param support True to vote yes, false to vote no.
     */
    function castVote(uint256 proposalId, bool support) external {
        Vote storage vote = votes[proposalId];
        require(block.timestamp >= vote.startTime, "Voting has not started");
        require(block.timestamp <= vote.endTime, "Voting has ended");
        require(!vote.hasVoted[msg.sender], "Already voted");

        uint256 voterBalance = IERC20(locks[msg.sender].token).balanceOf(msg.sender);
        uint256 lockedBalance = locks[msg.sender].totalAmount.sub(locks[msg.sender].releasedAmount);
        uint256 circulatingSupply = IERC20(locks[msg.sender].token).totalSupply().sub(lockedBalance);

        uint256 voterWeight = voterBalance.mul(1e18).div(circulatingSupply);
        require(voterWeight > 0, "No voting power");

        if (support) {
            vote.yesVotes = vote.yesVotes.add(voterWeight);
        } else {
            vote.noVotes = vote.noVotes.add(voterWeight);
        }

        vote.hasVoted[msg.sender] = true;

        emit VoteCast(proposalId, msg.sender, support, voterWeight);
    }

    /**
     * @notice Execute a proposal if it passes.
     * @param proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 proposalId) external {
        Vote storage vote = votes[proposalId];
        require(block.timestamp > vote.endTime, "Voting period not over");
        require(!vote.executed, "Proposal already executed");

        if (vote.yesVotes > vote.noVotes) {
            if (keccak256(abi.encodePacked(vote.proposalType)) == keccak256("release")) {
                Lock storage userLock = locks[vote.proposer];
                require(userLock.active, "No active lock");
                userLock.releasedAmount = userLock.releasedAmount.add(vote.parameter);
                require(userLock.releasedAmount <= userLock.totalAmount, "Exceeds total locked amount");
                IERC20(userLock.token).transfer(vote.proposer, vote.parameter);
            } else if (keccak256(abi.encodePacked(vote.proposalType)) == keccak256("extend")) {
                locks[vote.proposer].lockDuration = locks[vote.proposer].lockDuration.add(vote.parameter);
            }
        }

        vote.executed = true;

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice View the remaining locked tokens for a user.
     * @param user The address of the user.
     */
    function viewRemainingTokens(address user) external view returns (uint256) {
        Lock storage userLock = locks[user];
        return userLock.totalAmount.sub(userLock.releasedAmount);
    }
}