// SPDX-License-Identifier: NONE
pragma solidity ^0.8.1;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "./Distribute.sol";
import "./interfaces/IERC900.sol";

/**
 * An IERC900 staking contract
 */
contract StakingERC20Simple is IERC900  {
    using SafeERC20 for IERC20;

    /// @dev handle to access ERC20 token token contract to make transfers
    IERC20 internal _token;
    Distribute immutable public staking_contract;

    event Profit(uint256 amount);
    event StakeChanged(uint256 total, uint256 timestamp);

    constructor(IERC20 stake_token, IERC20 reward_token, uint256 decimals) {
        _token = stake_token;
        staking_contract = new Distribute(decimals, reward_token);
    }

    /**
        @dev Takes token from sender and puts it in the reward pool
        @param amount Amount of token to add to rewards
    */
    function distribute(uint256 amount) external virtual {
        staking_contract.distribute(amount, msg.sender);
        emit Profit(amount);
    }

    /**
        @dev Sends any reward token mistakingly sent to the main contract to the reward pool
    */
    function forward() external virtual {
        IERC20 rewardToken = IERC20(staking_contract.reward_token());
        uint256 balance = rewardToken.balanceOf(address(this));
        if(balance > 0) {
            rewardToken.approve(address(staking_contract), balance);
            staking_contract.distribute(balance, address(this));
            emit Profit(balance);
        }
    }
    
    /**
        @dev Stakes a certain amount of tokens, this MUST transfer the given amount from the account
        @param amount Amount of ERC20 token to stake
        @param data Additional data as per the EIP900
    */
    function stake(uint256 amount, bytes calldata data) external override virtual {
        stakeFor(msg.sender, amount, data);
    }

    /**
        @dev Stakes a certain amount of tokens, this MUST transfer the given amount from the caller
        @param account Address who will own the stake afterwards
        @param amount Amount of ERC20 token to stake
        @param data Additional data as per the EIP900
    */
    function stakeFor(address account, uint256 amount, bytes calldata data) public override virtual {
        //transfer the ERC20 token from the account, he must have set an allowance of {amount} tokens
        _token.safeTransferFrom(msg.sender, address(this), amount);
        staking_contract.stakeFor(account, amount);
        emit Staked(account, amount, totalStakedFor(account), data);
        emit StakeChanged(staking_contract.totalStaked(), block.timestamp);
    }

    /**
        @dev Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the account, if unstaking is currently not possible the function MUST revert
        @param amount Amount of ERC20 token to remove from the stake
        @param data Additional data as per the EIP900
    */
    function unstake(uint256 amount, bytes calldata data) external override virtual {
        staking_contract.unstakeFrom(payable(msg.sender), amount);
        _token.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount, totalStakedFor(msg.sender), data);
        emit StakeChanged(staking_contract.totalStaked(), block.timestamp);
    }

     /**
        @dev Withdraws rewards (basically unstake then restake)
        @param amount Amount of ERC20 token to remove from the stake
    */
    function withdraw(uint256 amount) external virtual {
        staking_contract.withdrawFrom(payable(msg.sender), amount);
    }

    /**
        @dev Returns the current total of tokens staked for an address
        @param account address owning the stake
        @return the total of staked tokens of this address
    */
    function totalStakedFor(address account) public view override virtual returns (uint256) {
        return staking_contract.totalStakedFor(account);
    }
    
    /**
        @dev Returns the current total of tokens staked
        @return the total of staked tokens
    */
    function totalStaked() external view override returns (uint256) {
        return staking_contract.totalStaked();
    }

    /**
        @dev returns the total rewards stored for token and eth
    */
    function totalReward() external view virtual returns (uint256 tokenReward) {
        tokenReward = staking_contract.getTotalReward();
    }

    /**
        @dev Address of the token being used by the staking interface
        @return ERC20 token token address
    */
    function token() external view override returns (address) {
        return address(_token);
    }

    /**
        @dev MUST return true if the optional history functions are implemented, otherwise false
        We dont want this
    */
    function supportsHistory() external pure override returns (bool) {
        return false;
    }

    /**
        @dev Returns how much ETH the user can withdraw currently
        @param account Address of the user to check reward for
        @return __token the amount of tokens the account will perceive if he unstakes now
    */
    function getReward(address account) public view virtual returns (uint256 __token) {
        return staking_contract.getReward(account);
    }
}