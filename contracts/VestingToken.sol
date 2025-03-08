// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    uint256 public tokenPrice = 500e18 / 0.5 ether; // 500 Tokens per 0.5 ETH
    uint256 public constant BURN_RATE = 100; // 1% (100 basis points)
    uint256 public constant BONUS_TIER_1 = 10; // 10% bonus
    uint256 public constant BONUS_TIER_2 = 20; // 20% bonus
    uint256 public constant LOCK_PERIOD_1 = 90 days;
    uint256 public constant LOCK_PERIOD_2 = 180 days;
    uint256 public constant UNCLAIMED_BURN_PERIOD = 270 days;

    struct Vesting {
        uint256 amount;
        uint256 claimed;
        uint256 startTime;
    }

    mapping(address => Vesting) public vestingBalances;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 bonus);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);

    /**
     * @dev Constructor initializes the ERC-20 token with a name and symbol.
     */
    constructor() ERC20("VestingToken", "VST") Ownable(msg.sender) {}

    /**
     * @dev Allows users to purchase tokens with ETH.
     * Tokens are vested based on the purchase amount.
     * Bonuses are applied according to predefined tiers.
     */
    function purchaseTokens() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must send ETH to purchase tokens");
        
        uint256 tokens = (msg.value * tokenPrice) / 1 ether;
        uint256 bonus = 0;

        if (msg.value >= 1 ether && msg.value < 5 ether) {
            bonus = (tokens * BONUS_TIER_1) / 100;
        } else if (msg.value >= 5 ether) {
            bonus = (tokens * BONUS_TIER_2) / 100;
        }
        
        uint256 totalTokens = tokens + bonus;
        _mint(address(this), totalTokens);
        vestingBalances[msg.sender] = Vesting({
            amount: totalTokens,
            claimed: 0,
            startTime: block.timestamp
        });
        
        emit TokensPurchased(msg.sender, tokens, bonus);
    }

    /**
     * @dev Allows users to claim their vested tokens.
     * Tokens unlock in two phases: 50% after 3 months, 100% after 6 months.
     */
    function claimTokens() external nonReentrant {
        Vesting storage vesting = vestingBalances[msg.sender];
        require(vesting.amount > 0, "No vested tokens");
        
        uint256 claimable = 0;
        uint256 elapsed = block.timestamp - vesting.startTime;

        if (elapsed >= LOCK_PERIOD_2) {
            claimable = vesting.amount;
        } else if (elapsed >= LOCK_PERIOD_1) {
            claimable = vesting.amount / 2;
        }
        
        claimable -= vesting.claimed;
        require(claimable > 0, "No tokens available to claim");
        
        vesting.claimed += claimable;
        _transfer(address(this), msg.sender, claimable);
        
        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @dev Burns any unclaimed tokens after 9 months.
     * TODO Here if you want you can have this call inside the transfer
            so everything transfer happens there will be check to burn unclaimed token
     */
    function burnUnclaimedTokens() external nonReentrant {
        Vesting storage vesting = vestingBalances[msg.sender];
        require(block.timestamp >= vesting.startTime + UNCLAIMED_BURN_PERIOD, "Tokens not eligible for burn yet");
        require(vesting.amount > vesting.claimed, "No unclaimed tokens to burn");

        uint256 burnAmount = vesting.amount - vesting.claimed;
        vesting.amount = vesting.claimed;
        _burn(address(this), burnAmount);
        
        emit TokensBurned(msg.sender, burnAmount);
    }

    /**
     * @dev Overrides the transfer function to implement a 1% burn on each transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 burnAmount = (amount * BURN_RATE) / 10000;
        uint256 transferAmount = amount - burnAmount;
        
        super._transfer(msg.sender, to, transferAmount);
        if (burnAmount > 0) {
            _burn(msg.sender, burnAmount);
        }
        return true;
    }

    /**
     * @dev Overrides the transferFrom function to apply a 1% burn rate.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 burnAmount = (amount * BURN_RATE) / 10000;
        uint256 transferAmount = amount - burnAmount;

        super.transferFrom(from, to, transferAmount);
        if (burnAmount > 0) {
            _burn(from, burnAmount);
        }
        return true;
    }

    /**
     * @dev Allows the owner to update the token price.
     * @param newPrice New price of the token.
     */
    function updateTokenPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than zero");
        tokenPrice = newPrice;
    }

    /**
     * @dev Allows the owner to pause token purchases.
     */
    function pausePurchases() external onlyOwner {
        _pause();
    }

    /**
     * @dev Allows the owner to resume token purchases.
     */
    function unpausePurchases() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Allows the owner to withdraw all ETH from the contract.
     */
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Allows the contract to receive ETH directly
    receive() external payable {}
}
