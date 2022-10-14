// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract staking {
    IERC20 public s_stakingToken;

    constructor(address stakingToken) {
        s_stakingToken = IERC20(stakingToken);
    }
}
