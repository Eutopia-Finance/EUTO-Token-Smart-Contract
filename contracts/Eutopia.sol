// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 *  ██████╗ ███████╗██╗   ██╗████████╗ ██████╗ ███████╗ ██╗ █████╗
 * ███  ███╗██╔════╝██║   ██║╚══██╔══╝██╔═══██╗██╔═══██╗██║██╔══██╗
 * █  ██  █║███████╗██║   ██║   ██║   ██║   ██║███████╔╝██║███████║
 * ███  ███║██╔════╝██║   ██║   ██║   ██║   ██║██╔════╝ ██║██╔══██║
 * ╚██████╔╝███████╗╚██████╔╝   ██║   ╚██████╔╝██║      ██║██║  ██║
 *  ╚═════╝ ╚══════╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝      ╚═╝╚═╝  ╚═╝
 * @title Eutopia Token Contract
 * @author 0xAmbassador, 0xTycoon
 * @dev A smart contract for the Eutopia Autostaking Protocol.
 * @notice This contract implements an upgradeable ERC20 token with additional functionalities.
 * @notice This contract uses OpenZeppelin's upgradeable libraries and follows the upgradeable proxy pattern.
 */
contract Eutopia is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /**
     * @dev Address utility library for performing address operations.
     */
    using Address for address payable;

    /**
     * @dev Represents the zero address.
     */
    address private constant ZERO = 0x0000000000000000000000000000000000000000;

    /**
     * @dev Represents the address constant for the dead address.
     */
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /**
     * @dev The initial supply of fragments for the Eutopia token.
     */
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 40 * 10e8 * 10e18;

    /**
     * @dev Represents the total number of gons in the system.
     * It is calculated as the maximum value of uint256 minus the remainder of dividing the maximum value of uint256 by the initial supply of fragments.
     */
    uint256 private constant TOTAL_GONS =
        type(uint256).max - (type(uint256).max % INITIAL_FRAGMENTS_SUPPLY);

    /**
     * @dev Represents the maximum supply of the token.
     */
    uint256 private constant MAX_SUPPLY = type(uint128).max;

    /**
     * @dev Represents the maximum rebase frequency.
     */
    uint256 private constant MAX_REBASE_FREQUENCY = 3600 * 24;

    /**
     * @dev Represents the maximum fee rate for a transaction.
     */
    uint256 private constant MAX_FEE_RATE = 18;

    /**
     * @dev Represents the maximum fee for buying tokens.
     */
    uint256 private constant MAX_FEE_BUY = 13;

    /**
     * @dev The maximum fee for selling tokens.
     */
    uint256 private constant MAX_FEE_SELL = 18;

    /**
     * @dev Represents the reward yield for the Eutopia token.
     */
    uint256 public rewardYield;

    /**
     * @dev Represents the reward yield denominator.
     */
    uint256 public rewardYieldDenominator;

    /**
     * @dev Specifies the frequency of the rebase operation.
     */
    uint256 public rebaseFrequency;

    /**
     * @dev Represents the timestamp for the next rebase.
     */
    uint256 public nextRebase;

    /**
     * @dev Represents the target liquidity of the contract.
     */
    uint256 public targetLiquidity;

    /**
     * @dev Represents the target liquidity denominator.
     */
    uint256 public targetLiquidityDenominator;

    /**
     * @dev The address that will receive the liquidity.
     */
    address public liquidityReceiver;

    /**
     * @dev The address of the treasury receiver.
     */
    address public treasuryReceiver;

    /**
     * @dev The address of the ESSR receiver.
     */
    address public essrReceiver;

    /**
     * @dev Represents the liquidity fee for the Eutopia token.
     */
    uint256 public liquidityFee;

    /**
     * @dev Represents the treasury fee for the Eutopia token.
     */
    uint256 public treasuryFee;

    /**
     * @dev Represents the buy fee for ESSR tokens.
     */
    uint256 public buyFeeEssr;

    /**
     * @dev The sellFeeTreasury variable represents the amount of sell fee that will be sent to the treasury.
     */
    uint256 public sellFeeTreasury;

    /**
     * @dev Represents the total buy fee in the Eutopia contract.
     */
    uint256 public totalBuyFee;

    /**
     * @dev Represents the total sell fee for the Eutopia token.
     */
    uint256 public totalSellFee;

    /**
     * @dev Represents the denominator used for calculating fees.
     */
    uint256 public feeDenominator;

    /**
     * @dev A mapping to keep track of allowed fragments between addresses.
     */
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    /**
     * @dev Mapping of addresses to their corresponding gon balances.
     */
    mapping(address => uint256) private _gonBalances;

    /**
     * @dev A mapping to keep track of addresses exempt from fees.
     */
    mapping(address => bool) private _isFeeExempt;

    /**
     * @dev Represents the total supply of tokens.
     */
    uint256 private _totalSupply;

    /**
     * @dev Represents the conversion rate between gons and fragments.
     */
    uint256 private _gonsPerFragment;

    /**
     * @dev Represents the threshold for swapping tokens.
     */
    uint256 private _gonSwapThreshold;

    /**
     * @dev Indicates whether the contract is currently in a swap operation.
     */
    bool private _inSwap;

    /**
     * @dev Indicates whether the auto rebase feature is enabled or not.
     */
    bool public autoRebase;

    /**
     * @dev The address of the Uniswap V2 Router contract.
     */
    IUniswapV2Router02 public uniswapRouter;

    /**
     * @dev The address of the Uniswap pair for the Eutopia token.
     */
    address public uniswapPair;

    /**
     * @dev Modifier to indicate that a function is currently swapping.
     * It sets the `_inSwap` flag to `true` before executing the function,
     * and sets it back to `false` after the function is executed.
     */
    modifier swapping() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    /**
     * @dev Modifier to check if the recipient address is valid.
     * @param _to The address of the recipient.
     * Requirements:
     * - The recipient address must not be the zero address.
     */
    modifier validRecipient(address _to) {
        require(_to != ZERO, "Eutopia: Invalid recipient");
        _;
    }

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     * @dev Constructor function.
     * It disables initializers.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the specified parameters.
     * @param _initialOwner The address of the initial owner.
     * @param _uniswapRouter The address of the Uniswap router.
     * @param _liquidityReceiver The address of the liquidity receiver.
     * @param _treasuryReceiver The address of the treasury receiver.
     * @param _essrReceiver The address of the ESSR receiver.
     */
    function initialize(
        address _initialOwner,
        address _uniswapRouter,
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _essrReceiver
    ) public initializer {
        __ERC20_init("Eutopia", "EUTO");
        __ERC20Pausable_init();
        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        rewardYield = 2081456;
        rewardYieldDenominator = 1e10;
        rebaseFrequency = 3600 / 4;
        nextRebase = block.timestamp + 3600 / 4;
        targetLiquidity = 50;
        targetLiquidityDenominator = 100;
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        essrReceiver = _essrReceiver;

        liquidityFee = 5;
        treasuryFee = 5;
        buyFeeEssr = 3;
        sellFeeTreasury = 5;
        totalBuyFee = liquidityFee + treasuryFee + buyFeeEssr;
        totalSellFee = totalBuyFee + sellFeeTreasury;
        feeDenominator = 100;

        _allowedFragments[address(this)][address(uniswapRouter)] = type(uint256)
            .max;
        _allowedFragments[address(this)][uniswapPair] = type(uint256).max;
        _allowedFragments[address(this)][address(this)] = type(uint256).max;
        _gonBalances[msg.sender] = TOTAL_GONS;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[essrReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        _gonSwapThreshold = TOTAL_GONS / 1000;
        _inSwap = false;
        autoRebase = false;

        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this),
            uniswapRouter.WETH()
        );

        emit Transfer(ZERO, msg.sender, _totalSupply);
    }

    /**
     * @dev Fallback function to receive Ether.
     */
    receive() external payable {}

    /**
     * @dev Returns the total supply of the token.
     * @return The total supply of the token as a uint256 value.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens that the spender is allowed to transfer on behalf of the owner.
     * @param _owner The address of the owner.
     * @param _spender The address of the spender.
     * @return The amount of tokens allowed to be transferred.
     */
    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return _allowedFragments[_owner][_spender];
    }

    /**
     * @dev Returns the balance of a specific address.
     * @param _who The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address _who) public view override returns (uint256) {
        return _gonBalances[_who] / _gonsPerFragment;
    }

    /**
     * @dev Returns whether the given address is exempt from fees.
     * @param _addr The address to check.
     * @return A boolean indicating whether the address is fee exempt.
     */
    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    /**
     * @dev Returns the swap threshold in EUTO tokens.
     * @return The swap threshold in EUTO tokens.
     */
    function checkSwapThreshold() external view returns (uint256) {
        return _gonSwapThreshold / _gonsPerFragment;
    }

    /**
     * @dev Determines whether a rebase should occur.
     * @return A boolean indicating whether a rebase should occur.
     */
    function _shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    /**
     * @dev Determines whether a fee should be taken for a transaction.
     * @param _from The address from which the transaction originates.
     * @param _to The address to which the transaction is being sent.
     * @return A boolean indicating whether a fee should be taken.
     */
    function _shouldTakeFee(
        address _from,
        address _to
    ) internal view returns (bool) {
        if (_isFeeExempt[_from] || _isFeeExempt[_to]) {
            return false;
        } else {
            return (uniswapPair == _from || uniswapPair == _to);
        }
    }

    /**
     * @dev Determines whether the contract should initiate a swap back operation.
     * @return A boolean value indicating whether a swap back operation should be performed.
     */
    function _shouldSwapBack() internal view returns (bool) {
        return
            uniswapPair != msg.sender &&
            !_inSwap &&
            totalBuyFee + totalSellFee > 0 &&
            _gonBalances[address(this)] >= _gonSwapThreshold;
    }

    /**
     * @dev Returns the circulating supply of the Eutopia token.
     * The circulating supply is calculated by subtracting the balances of the DEAD and ZERO addresses
     * from the total supply in gons, and then dividing the result by the number of gons per fragment.
     * @return The circulating supply of the Eutopia token.
     */
    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO]) /
            _gonsPerFragment;
    }

    /**
     * @dev Calculates the liquidity backing for the token.
     * @param _accuracy The accuracy of the calculation.
     * @return The liquidity backing value.
     */
    function getLiquidityBacking(
        uint256 _accuracy
    ) public view returns (uint256) {
        uint256 liquidityBalance = balanceOf(uniswapPair) / 10e9;
        return
            (_accuracy * liquidityBalance * 2) /
            (getCirculatingSupply() / 10e9);
    }

    /**
     * @dev Checks if the liquidity backing is greater than the target.
     * @param _target The target value to compare against.
     * @param _accuracy The accuracy of the liquidity backing value.
     * @return A boolean indicating whether the liquidity backing is greater than the target.
     */
    function isOverLiquified(
        uint256 _target,
        uint256 _accuracy
    ) public view returns (bool) {
        return getLiquidityBacking(_accuracy) > _target;
    }

    /**
     * @dev Executes a manual synchronization of the Uniswap pair.
     */
    function manualSync() public {
        IUniswapV2Pair(uniswapPair).sync();
    }

    /**
     * @dev Transfers tokens from the caller's address to a specified recipient.
     *
     * Emits a {Transfer} event indicating the transfer of tokens.
     *
     * Requirements:
     * - `_to` cannot be the zero address.
     * - The caller must have a balance of at least `_value` tokens.
     * - The recipient must be a valid recipient (see {validRecipient} modifier).
     *
     * @param _to The address to transfer tokens to.
     * @param _value The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(
        address _to,
        uint256 _value
    ) public override validRecipient(_to) returns (bool) {
        _transferFrom(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Internal function to perform a basic transfer of tokens.
     *
     * @param _from The address from which the tokens are being transferred.
     * @param _to The address to which the tokens are being transferred.
     * @param _amount The amount of tokens being transferred.
     *
     * @return A boolean indicating whether the transfer was successful or not.
     */
    function _basicTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        uint256 gonAmount = _amount * _gonsPerFragment;
        _gonBalances[_from] -= gonAmount;
        _gonBalances[_to] += gonAmount;

        emit Transfer(_from, _to, _amount);

        return true;
    }

    /**
     * @dev Internal function to transfer tokens from one address to another.
     *
     * @param _sender The address sending the tokens.
     * @param _recipient The address receiving the tokens.
     * @param _amount The amount of tokens to transfer.
     *
     * @return A boolean indicating whether the transfer was successful or not.
     */
    function _transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal returns (bool) {
        if (_inSwap) {
            return _basicTransfer(_sender, _recipient, _amount);
        }

        uint256 gonAmount = _amount * _gonsPerFragment;

        if (_shouldSwapBack()) {
            _swapBack();
        }

        _gonBalances[_sender] -= gonAmount;

        uint256 gonAmountReceived = _shouldTakeFee(_sender, _recipient)
            ? _takeFee(_sender, _recipient, gonAmount)
            : gonAmount;
        _gonBalances[_recipient] += gonAmountReceived;

        emit Transfer(
            _sender,
            _recipient,
            gonAmountReceived / _gonsPerFragment
        );

        if (_shouldRebase() && autoRebase) {
            _rebase();
            if (uniswapPair != _sender && uniswapPair != _recipient)
                manualSync();
        }

        return true;
    }

    /**
     * @dev Transfers tokens from one address to another.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - `_from` cannot be the zero address.
     * - `_to` cannot be the zero address.
     * - `_from` must have a balance of at least `_value`.
     * - The caller must have allowance for `_from`'s tokens of at least `_value`.
     *
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _value The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful or not.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override validRecipient(_to) returns (bool) {
        uint256 allowed = _allowedFragments[_from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= _value, "Eutopia: Insufficient allowance");
            _allowedFragments[_from][msg.sender] = allowed - _value;
        }

        _transferFrom(_from, _to, _value);
        return true;
    }

    /**
     * @dev Internal function to swap and liquify tokens.
     * @param _contractTokenBalance The balance of tokens held by the contract.
     */
    function _swapAndLiquify(uint256 _contractTokenBalance) private {
        uint256 half = _contractTokenBalance / 2;
        uint256 otherHalf = _contractTokenBalance - half;

        uint256 initialBalance = address(this).balance;

        _swapTokensForETH(half, address(this));

        uint256 newBalance = address(this).balance - initialBalance;

        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /**
     * @dev Adds liquidity to the contract by providing an amount of tokens and ETH.
     * @param _tokenAmount The amount of tokens to add as liquidity.
     * @param _ethAmount The amount of ETH to add as liquidity.
     */
    function _addLiquidity(uint256 _tokenAmount, uint256 _ethAmount) private {
        uniswapRouter.addLiquidityETH{value: _ethAmount}(
            address(this),
            _tokenAmount,
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
    }

    /**
     * @dev Swaps a specified amount of tokens for ETH.
     * @param _tokenAmount The amount of tokens to be swapped.
     * @param _receiver The address that will receive the ETH.
     */
    function _swapTokensForETH(
        uint256 _tokenAmount,
        address _receiver
    ) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            _receiver,
            block.timestamp
        );
    }

    /**
     * @dev Internal function to swap tokens back.
     */
    function _swapBack() internal swapping {
        uint256 realTotalFee = totalBuyFee + totalSellFee;

        uint256 dynamicLiquidityFee = isOverLiquified(
            targetLiquidity,
            targetLiquidityDenominator
        )
            ? 0
            : liquidityFee;
        uint256 contractTokenBalance = _gonBalances[address(this)] /
            _gonsPerFragment;

        uint256 amountToLiquify = (contractTokenBalance *
            dynamicLiquidityFee *
            2) / realTotalFee;
        uint256 amountToEssr = (contractTokenBalance * buyFeeEssr * 2) /
            realTotalFee;
        uint256 amountToTreasury = contractTokenBalance -
            amountToLiquify -
            amountToEssr;

        if (amountToLiquify > 0) {
            _swapAndLiquify(amountToLiquify);
        }

        if (amountToEssr > 0) {
            _swapTokensForETH(amountToEssr, essrReceiver);
        }

        if (amountToTreasury > 0) {
            _swapTokensForETH(amountToTreasury, treasuryReceiver);
        }

        emit SwapBack(
            contractTokenBalance,
            amountToLiquify,
            amountToEssr,
            amountToTreasury
        );
    }

    /**
     * @dev Internal function to take a fee from a transaction.
     * @param _sender The address of the sender.
     * @param _recipient The address of the recipient.
     * @param _gonAmount The amount of tokens in gons.
     * @return The updated amount of tokens after the fee is taken.
     */
    function _takeFee(
        address _sender,
        address _recipient,
        uint256 _gonAmount
    ) internal returns (uint256) {
        uint256 _realFee = totalBuyFee;
        if (uniswapPair == _recipient) _realFee = totalSellFee;

        uint256 feeAmount = (_gonAmount * _realFee) / feeDenominator;

        _gonBalances[address(this)] += feeAmount;
        emit Transfer(_sender, address(this), feeAmount / _gonsPerFragment);

        return _gonAmount - feeAmount;
    }

    /**
     * @dev Decreases the allowance granted to a spender.
     * @param _spender The address of the spender to decrease the allowance for.
     * @param _subtractedValue The amount by which to decrease the allowance.
     * @return A boolean value indicating whether the operation was successful.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) external returns (bool) {
        uint256 oldValue = _allowedFragments[msg.sender][_spender];
        _allowedFragments[msg.sender][_spender] = _subtractedValue >= oldValue
            ? 0
            : oldValue - _subtractedValue;
        emit Approval(
            msg.sender,
            _spender,
            _allowedFragments[msg.sender][_spender]
        );
        return true;
    }

    /**
     * @dev Increases the allowance of the specified spender.
     * @param _spender The address of the spender.
     * @param _addedValue The amount by which to increase the allowance.
     * @return A boolean value indicating whether the operation was successful.
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) external returns (bool) {
        _allowedFragments[msg.sender][_spender] += _addedValue;
        emit Approval(
            msg.sender,
            _spender,
            _allowedFragments[msg.sender][_spender]
        );
        return true;
    }

    /**
     * @dev Approve the specified address to spend the specified amount of tokens on behalf of the message sender.
     * @param _spender The address to be approved for spending tokens.
     * @param _value The amount of tokens to be approved.
     * @return A boolean value indicating whether the approval was successful or not.
     */
    function approve(
        address _spender,
        uint256 _value
    ) public override returns (bool) {
        _allowedFragments[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Internal function to perform rebase operation.
     * @notice This function is called internally to adjust the total supply of the token based on the reward yield.
     * @notice It calculates the supply delta by multiplying the total supply with the reward yield and dividing it by the reward yield denominator.
     * @notice The rebase operation is only performed if the swap is not in progress.
     */
    function _rebase() private {
        if (!_inSwap) {
            int256 supplyDelta = int256(
                (_totalSupply * rewardYield) / rewardYieldDenominator
            );
            _coreRebase(supplyDelta);
        }
    }

    /**
     * @dev Performs a core rebase operation.
     * @param _supplyDelta The change in token supply.
     * @return The updated token supply.
     */
    function _coreRebase(int256 _supplyDelta) private returns (uint256) {
        uint256 epoch = block.timestamp;

        if (_supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (_supplyDelta < 0) {
            _totalSupply -= uint256(-_supplyDelta);
        } else {
            _totalSupply += uint256(_supplyDelta);
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        nextRebase = epoch + rebaseFrequency;

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    /**
     * @dev Executes a manual rebase of the token supply.
     * This function is non-reentrant.
     */
    function manualRebase() external nonReentrant {
        require(!_inSwap, "Eutopia: Swap in progress");
        require(nextRebase <= block.timestamp, "Eutopia: Too soon");

        int256 supplyDelta = int256(
            (_totalSupply * rewardYield) / rewardYieldDenominator
        );
        _coreRebase(supplyDelta);
        manualSync();
        emit ManualRebase(supplyDelta);
    }

    /**
     * @dev Sets the fee exemption status for a given address.
     * @param _addr The address for which to set the fee exemption status.
     * @param _value The new fee exemption status.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function setFeeExempt(address _addr, bool _value) external onlyOwner {
        require(_isFeeExempt[_addr] != _value, "Eutopia: Value already set");
        _isFeeExempt[_addr] = _value;
        emit SetFeeExempted(_addr, _value);
    }

    /**
     * @dev Sets the target liquidity for the contract.
     * @param _target The target liquidity value.
     * @param _accuracy The accuracy of the target liquidity value.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function setTargetLiquidity(
        uint256 _target,
        uint256 _accuracy
    ) external onlyOwner {
        targetLiquidity = _target;
        targetLiquidityDenominator = _accuracy;
        emit SetTargetLiquidity(_target, _accuracy);
    }

    /**
     * @dev Sets the swap back settings for the contract.
     * @param _num The numerator value for calculating the swap threshold.
     * @param _denom The denominator value for calculating the swap threshold.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function setSwapBackSettings(
        uint256 _num,
        uint256 _denom
    ) external onlyOwner {
        _gonSwapThreshold = (TOTAL_GONS / _denom) * _num;
        emit SetSwapBackSettings(_num, _denom);
    }

    /**
     * @dev Sets the fee receivers for the Eutopia token.
     * Can only be called by the contract owner.
     *
     * @param _liquidityReceiver The address of the liquidity receiver.
     * @param _treasuryReceiver The address of the treasury receiver.
     * @param _essrReceiver The address of the elastic supply stability reserve value receiver.
     */
    function setFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _essrReceiver
    ) external onlyOwner {
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        essrReceiver = _essrReceiver;
        emit SetFeeReceivers(
            _liquidityReceiver,
            _treasuryReceiver,
            _essrReceiver
        );
    }

    /**
     * @dev Sets the fees for the Eutopia token.
     * @param _liquidityFee The fee percentage for liquidity.
     * @param _essrValue The fee percentage for elastic supply stability reserve.
     * @param _treasuryFee The fee percentage for the treasury.
     * @param _sellFeeTreasury The fee percentage for selling to the treasury.
     * @param _feeDenominator The denominator used to calculate the fees.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function setFees(
        uint256 _liquidityFee,
        uint256 _essrValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasury,
        uint256 _feeDenominator
    ) external onlyOwner {
        require(
            _liquidityFee <= MAX_FEE_RATE,
            "Eutopia: Liquidity fee too high"
        );
        require(_essrValue <= MAX_FEE_RATE, "Eutopia: ESSR value too high");
        require(_treasuryFee <= MAX_FEE_RATE, "Eutopia: Treasury fee too high");
        require(
            _sellFeeTreasury <= MAX_FEE_RATE,
            "Eutopia: Sell fee treasury too high"
        );

        liquidityFee = _liquidityFee;
        buyFeeEssr = _essrValue;
        treasuryFee = _treasuryFee;
        sellFeeTreasury = _sellFeeTreasury;
        totalBuyFee = liquidityFee + treasuryFee + buyFeeEssr;
        totalSellFee = totalBuyFee + sellFeeTreasury;

        require(totalBuyFee <= MAX_FEE_BUY, "Eutopia: Total BUY fee too high");
        require(
            totalSellFee <= MAX_FEE_SELL,
            "Eutopia: Total SELL fee too high"
        );

        feeDenominator = _feeDenominator;
        require(totalBuyFee < feeDenominator / 4, "Eutopia: Buy fee too high");

        emit SetFees(
            _liquidityFee,
            _essrValue,
            _treasuryFee,
            _sellFeeTreasury,
            _feeDenominator
        );
    }

    /**
     * @dev Clears the stuck balance of the contract by transferring it to the specified receiver.
     * @param _receiver The address of the receiver to transfer the balance to.
     * Emits a `ClearStuckBalance` event.
     */
    function clearStuckBalance(address _receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(_receiver), balance);
        emit ClearStuckBalance(_receiver);
    }

    /**
     * @dev Sets the auto rebase feature for the token.
     * @param _autoRebase The new value for the auto rebase feature.
     * Requirements:
     * - Only the contract owner can call this function.
     * Emits a `SetAutoRebase` event.
     */
    function setAutoRebase(bool _autoRebase) external onlyOwner {
        require(autoRebase != _autoRebase, "Eutopia: Value already set");
        autoRebase = _autoRebase;
        emit SetAutoRebase(_autoRebase);
    }

    /**
     * @dev Sets the rebase frequency for the token.
     * @param _rebaseFrequency The new rebase frequency to be set.
     * @notice Only the contract owner can call this function.
     * @notice The rebase frequency must be less than or equal to MAX_REBASE_FREQUENCY.
     * @notice Emits a SetRebaseFrequency event with the new rebase frequency.
     */
    function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
        require(
            _rebaseFrequency <= MAX_REBASE_FREQUENCY,
            "Eutopia: Invalid rebase frequency"
        );
        rebaseFrequency = _rebaseFrequency;
        emit SetRebaseFrequency(_rebaseFrequency);
    }

    /**
     * @dev Sets the reward yield for the Eutopia token.
     * @param _rewardYield The new reward yield value.
     * @param _rewardYieldDenominator The new reward yield denominator value.
     * Emits a {SetRewardYield} event with the new reward yield and reward yield denominator values.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function setRewardYield(
        uint256 _rewardYield,
        uint256 _rewardYieldDenominator
    ) external onlyOwner {
        rewardYield = _rewardYield;
        rewardYieldDenominator = _rewardYieldDenominator;
        emit SetRewardYield(_rewardYield, _rewardYieldDenominator);
    }

    /**
     * @dev Sets the value of `nextRebase`.
     * Can only be called by the contract owner.
     * Emits a {SetNextRebase} event.
     *
     * @param _nextRebase The new value for `nextRebase`.
     */
    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;
        emit SetNextRebase(_nextRebase);
    }

    /**
     * @dev Pauses the contract.
     * Can only be called by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     * Can only be called by the owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Internal function to update the token balance of a given address.
     * Overrides the _update function from ERC20Upgradeable and ERC20PausableUpgradeable contracts.
     * Calls the _update function from the parent contract to update the balance.
     * The following functions are overrides required by Solidity.
     *
     * @param from The address from which the tokens are transferred.
     * @param to The address to which the tokens are transferred.
     * @param value The amount of tokens being transferred.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    /**
     * @dev Event triggered when swapping tokens back.
     * @param _contractTokenBalance The balance of tokens held by the contract.
     * @param _amountToLiquify The amount of tokens to be added to the liquidity pool.
     * @param _amountToEssr The amount of tokens to be distributed to ESSR holders.
     * @param _amountToTreasury The amount of tokens to be sent to the treasury.
     */
    event SwapBack(
        uint256 _contractTokenBalance,
        uint256 _amountToLiquify,
        uint256 _amountToEssr,
        uint256 _amountToTreasury
    );

    /**
     * @dev Emitted when tokens are swapped and liquidity is added to the contract.
     * @param _tokensSwapped The amount of tokens that were swapped.
     * @param _ethReceived The amount of ETH received from the swap.
     * @param _tokensIntoLiquidity The amount of tokens added to the liquidity pool.
     */
    event SwapAndLiquify(
        uint256 _tokensSwapped,
        uint256 _ethReceived,
        uint256 _tokensIntoLiquidity
    );

    /**
     * @dev Emitted when a rebase operation is performed.
     *
     * @param _epoch The epoch number of the rebase operation.
     * @param _totalSupply The total supply after the rebase operation.
     */
    event LogRebase(uint256 indexed _epoch, uint256 _totalSupply);

    /**
     * @dev Emitted when a manual rebase is triggered.
     * @param _supplyDelta The change in token supply.
     */
    event ManualRebase(int256 _supplyDelta);

    /**
     * @dev Emits an event when the fee exemption status is set for an address.
     *
     * @param _addr The address for which the fee exemption status is set.
     * @param _value The new fee exemption status.
     */
    event SetFeeExempted(address indexed _addr, bool _value);

    /**
     * @dev Emitted when the target liquidity is set.
     * @param _target The target liquidity value.
     * @param _accuracy The accuracy of the target liquidity value.
     */
    event SetTargetLiquidity(uint256 _target, uint256 _accuracy);

    /**
     * @dev Emits an event to set the swap back settings.
     * @param _num The numerator value.
     * @param _denom The denominator value.
     */
    event SetSwapBackSettings(uint256 _num, uint256 _denom);

    /**
     * @dev Emits an event when the fee receivers are set.
     * @param _liquidityReceiver The address of the liquidity receiver.
     * @param _treasuryReceiver The address of the treasury receiver.
     * @param _essrReceiver The address of the ESSR receiver.
     */
    event SetFeeReceivers(
        address indexed _liquidityReceiver,
        address indexed _treasuryReceiver,
        address indexed _essrReceiver
    );

    /**
     * @dev Event emitted when the fees are set.
     * @param _liquidityFee The liquidity fee value.
     * @param _essrValue The ESSR value.
     * @param _treasuryFee The treasury fee value.
     * @param _sellFeeTreasury The sell fee treasury value.
     * @param _feeDenominator The fee denominator value.
     */
    event SetFees(
        uint256 _liquidityFee,
        uint256 _essrValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasury,
        uint256 _feeDenominator
    );

    /**
     * @dev Emitted when the stuck balance is cleared for a specific receiver.
     * @param _receiver The address of the receiver whose stuck balance is cleared.
     */
    event ClearStuckBalance(address indexed _receiver);

    /**
     * @dev Emits an event to set the autoRebase flag.
     * @param _autoRebase The new value of the autoRebase flag.
     */
    event SetAutoRebase(bool _autoRebase);

    /**
     * @dev Emits an event to set the rebase frequency.
     * @param _rebaseFrequency The new rebase frequency value.
     */
    event SetRebaseFrequency(uint256 _rebaseFrequency);

    /**
     * @dev Emitted when the reward yield and reward yield denominator are set.
     * @param _rewardYield The new reward yield value.
     * @param _rewardYieldDenominator The new reward yield denominator value.
     */
    event SetRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator);

    /**
     * @dev Emits an event to set the next rebase value.
     *
     * @param _nextRebase The value to set as the next rebase.
     */
    event SetNextRebase(uint256 _nextRebase);
}
