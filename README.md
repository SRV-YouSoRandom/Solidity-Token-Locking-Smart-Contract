# Token Locking Platform

## Overview
The **Token Locking Platform** is a Solidity-based smart contract that allows token creators to lock their tokens securely, manage vesting schedules, and provide mechanisms for community-driven decisions regarding locked tokens. The platform is designed to increase transparency and safety for token holders and prevent malicious actions like rug pulls.

## Key Features
1. **Token Locking**:
   - Tokens can be locked for a minimum duration of 6 months.
   - Vesting schedules allow gradual token release after the lock period ends.

2. **Community Governance**:
   - Token holders can vote on proposals to release additional tokens early or extend the lock period.
   - Votes are weighted based on the circulating token supply, excluding locked tokens.

3. **Proposal Management**:
   - Any active token locker can propose votes.
   - Proposals are executed if they receive majority support during the voting period.

4. **Transparency and Security**:
   - The smart contract ensures locked tokens cannot be withdrawn early without community approval.
   - Voting is transparent and tied to token holdings.

---

## Contract Components

### Structs
1. **Lock**:
   Stores information about locked tokens, including the amount, release status, lock duration, vesting schedule, and the token address.

   ```solidity
   struct Lock {
       uint256 totalAmount;
       uint256 releasedAmount;
       uint256 lockStart;
       uint256 lockDuration;
       uint256 vestingDuration;
       bool active;
       address token;
   }
   ```

2. **Vote**:
   Represents a proposal for community governance, including details about the proposal, voting results, and execution status.

   ```solidity
   struct Vote {
       uint256 proposalId;
       address proposer;
       uint256 startTime;
       uint256 endTime;
       uint256 yesVotes;
       uint256 noVotes;
       string proposalType; // "release" or "extend"
       uint256 parameter;  // Tokens to release or seconds to extend
       bool executed;
       mapping(address => bool) hasVoted;
   }
   ```

### Functions

#### 1. `lockTokens`
Locks tokens for a specified duration with an optional vesting schedule.

**Parameters**:
- `address token`: Address of the ERC20 token to lock.
- `uint256 amount`: Amount of tokens to lock.
- `uint256 lockDuration`: Duration of the lock in seconds.
- `uint256 vestingDuration`: Duration for token vesting after the lock period.

#### 2. `releaseTokens`
Releases tokens according to the vesting schedule. Tokens can only be released after the lock period ends.

#### 3. `proposeVote`
Creates a proposal to release additional tokens early or extend the lock duration.

**Parameters**:
- `string proposalType`: Type of proposal ("release" or "extend").
- `uint256 parameter`: Amount of tokens to release or additional seconds to extend the lock.

#### 4. `castVote`
Allows token holders to cast votes on active proposals.

**Parameters**:
- `uint256 proposalId`: The ID of the proposal to vote on.
- `bool support`: True to vote yes, false to vote no.

#### 5. `executeProposal`
Executes a proposal if it has passed after the voting period.

**Parameters**:
- `uint256 proposalId`: The ID of the proposal to execute.

#### 6. `viewRemainingTokens`
Returns the remaining locked tokens for a user.

**Parameters**:
- `address user`: The address of the token locker.

---

## Events
- **`TokensLocked`**: Emitted when tokens are locked.
- **`TokensReleased`**: Emitted when tokens are released.
- **`ProposalCreated`**: Emitted when a new proposal is created.
- **`VoteCast`**: Emitted when a vote is cast.
- **`ProposalExecuted`**: Emitted when a proposal is executed.

---

## Example Workflow
1. **Lock Tokens**:
   - A user locks their tokens for 6 months with a vesting period of 3 months.
   - The contract stores the locked amount and prevents early withdrawals.

2. **Propose Vote**:
   - The user proposes to release 10% of their tokens early.

3. **Community Voting**:
   - Other token holders cast their votes.
   - Votes are weighted based on the circulating token supply.

4. **Execute Proposal**:
   - If the proposal passes, the specified amount of tokens is released early.
   - The proposal is marked as executed.

---

## Deployment Considerations
1. **ERC20 Compliance**:
   - The platform requires tokens to comply with the ERC20 standard.

2. **Gas Optimization**:
   - Ensure that the contract functions are optimized to minimize gas costs for users.

3. **Security**:
   - The contract should be audited to prevent vulnerabilities, especially in governance and token locking mechanisms.

---

## Future Enhancements
1. **Penalty Mechanism**:
   - Introduce penalties for proposals that fail to pass as a deterrent for spam proposals.

2. **Multiple Lock Periods**:
   - Allow users to create multiple locks for the same token.

3. **UI Integration**:
   - Build a user-friendly interface to interact with the contract.

---

## Disclaimer
This contract is provided "as is" and should be thoroughly tested and audited before deployment on the mainnet. The authors are not responsible for any losses or damages arising from the use of this code.
