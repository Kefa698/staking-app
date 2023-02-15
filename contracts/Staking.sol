// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error Staking__TransferFailed();
error Withdraw__TransferFailed();
error Staking__NeedsMoreThanZero();
error Staking__InvalidSellAmount();
error Staking__InvalidEarlyUnstakeAmount();

contract Staking is ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public s_totalSupply;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;
    uint256 public constant REWARD_RATE = 100;

    /** @dev Mapping from address to the amount the user has staked */
    mapping(address => uint256) public s_balances;

    /** @dev Mapping from address to the amount the user has been rewarded */
    mapping(address => uint256) public s_userRewardPerTokenPaid;

    /** @dev Mapping from address to the rewards claimable for user */
    mapping(address => uint256) public s_rewards;

    /** @dev Mapping from address to the last stake time for the user */
    mapping(address => uint256) public s_lastStakeTime;

    modifier updateReward(address account) {
        // Calculate the current reward per token
        s_rewardPerTokenStored = rewardPerToken();
        // Update the last update time
        s_lastUpdateTime = block.timestamp;
        // Update the rewards for the given account
        s_rewards[account] = earned(account);
        // Update the reward per token paid for the given account
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;

        _;
    }
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Staking__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    function calculateRewardRate(uint256 timeStaked) public view returns (uint256) {
        // Convert the time staked to seconds
        uint256 timeStakedInSeconds = timeStaked * 1 days;

        // Calculate the reward rate based on the time staked
        if (timeStakedInSeconds <= 30 days) {
            return (3 * 1e18) / (200000);
        } else if (timeStakedInSeconds <= 90 days) {
            return (7.5 * 1e18) / (200000);
        } else if (timeStakedInSeconds <= 180 days) {
            return (15 * 1e18) / (200000);
        } else if (timeStakedInSeconds <= 365 days) {
            return (30 * 1e18) / (200000);
        } else {
            return 0;
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        } else {
            return
                s_rewardPerTokenStored +
                (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
        }
    }

    function earned(address account) public view returns (uint256)  {
        uint256 currentBalance = s_balances[account];
        uint256 amountPaid = s_userRewardPerTokenPaid[account];
        uint256 pastRewards = s_rewards[account];

        // Calculate the time staked by the user

        uint256 timeStaked = block.timestamp - s_lastStakeTime[account];
        // Calculate the reward rate based on the time staked
        uint256 rewardRate = calculateRewardRate(timeStaked);
        // Calculate the current reward per token
        uint256 currentRewardPerToken = rewardPerToken() * (1 + rewardRate);
        return ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) + pastRewards;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) moreThanZero(amount) {
        // keep track of how much this user has staked
        // keep track of how much token we have total
        // transfer the tokens to this contract
        /** @notice Be mindful of reentrancy attack here */
        s_balances[msg.sender] += amount;
        s_totalSupply += amount;
        // Update the last stake time for the user
        s_lastStakeTime[msg.sender] = block.timestamp;
        //emit event
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
        // require(success, "Failed"); Save gas fees here
        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    function withdraw(uint256 amount)nonReentrant external updateReward(msg.sender) moreThanZero(amount) {
        s_balances[msg.sender] -= amount;
        s_totalSupply -= amount;
        // Update the last stake time for the user
        s_lastStakeTime[msg.sender] = block.timestamp;
        // emit event
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert Withdraw__TransferFailed();
        }
    }

    function claim() nonReentrant public updateReward(msg.sender) {
        uint256 _earned = earned(msg.sender);
        s_rewards[msg.sender] = 0;
        // Transfer the earned rewards to the user
        bool success = s_rewardToken.transfer(msg.sender, _earned);
        require(success, "Transfer failed");
    }

    function sell(uint256 amount) nonReentrant public {
        // Ensure that the user has enough staked to sell
        require(amount <= s_balances[msg.sender], "Staking__InvalidSellAmount()");
        // Calculate the sell tax
        uint256 sellTax = (amount * 1e18 * 10) / 1000;
        // Deduct the sell tax from the amount to be sold
        amount -= sellTax;
        // Update the staked balance for the user
        s_balances[msg.sender] -= amount;
        // Update the total staked balance
        s_totalSupply -= amount;
        // Transfr the remaining amount to the caller
        bool success = s_stakingToken.transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

    function earlyUnstake(uint256 amount) nonReentrant public {
        // Ensure that the user has enough staked to unstake early

        if (amount > s_balances[msg.sender]) {
            revert Staking__InvalidEarlyUnstakeAmount();
        }
        // Calculate the early unstake fee
        uint256 earlyUnstakeFee = amount.mul(1e18).mul(90).div(1000);

        // Deduct the early unstake fee from the amount to be unstaked
        amount -= earlyUnstakeFee;
        // Update the staked balance for the user
        s_balances[msg.sender] -= amount;
        // Update the total staked balance
        s_totalSupply -= amount;
        // Transfer the remaining amount to the caller
        bool success = s_stakingToken.transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }
}
