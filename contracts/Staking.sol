// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    //address=>stake
    mapping(address => uint256) public s_balances;

    //each address being paid
    mapping(address => uint256) public s_userPerTokenPaid;

    //mapping of how much reward each user can claim
    mapping(address => uint256) public s_rewards;

    uint256 public s_totalsupply;

    uint256 public s_rewardPerTokenStored;
    uint256 public lastUpdatedTime;
    uint256 public constant REWARD_RATE = 100;

    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken();
        lastUpdatedTime = block.timestamp;
        s_rewards[account] = earned(account);
        _;
    }

    constructor(address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    function earned(address account) public view returns (uint256) {
        uint256 currentBalance = s_balances[account];
        uint256 amountPaid = s_userPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[account];

        uint256 Earned = ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) +
            pastRewards;
        return Earned;
    }

    function rewardPerToken() public view returns (uint256) {
        if (s_totalsupply == 0) {
            return s_rewardPerTokenStored;
        }
        return
            s_rewardPerTokenStored +
            (((block.timestamp - lastUpdatedTime) * REWARD_RATE * 1e18) / s_totalsupply);
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "amount must be more than zero");
        s_balances[msg.sender] = s_balances[msg.sender] += amount;
        s_totalsupply = s_totalsupply += amount;
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "failed");
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "amount must be more than zero");
        s_balances[msg.sender] = s_balances[msg.sender] -= amount;
        s_totalsupply = s_totalsupply -= amount;
        bool success = s_stakingToken.transfer(msg.sender, amount);
        require(success, "transfer failled");
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        s_rewards[msg.sender] = 0;
        bool success = s_rewardToken.transfer(msg.sender, reward);
        require(success, "transfer failed");
    }
}
