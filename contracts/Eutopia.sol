// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "hardhat/console.sol";

contract Eutopia is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address private constant ZERO = 0x0000000000000000000000000000000000000000;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 23 * 10e8 * 10e18;
    uint256 private constant TOTAL_GONS =
        type(uint256).max - (type(uint256).max % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = type(uint128).max;
    uint256 private constant MAX_REBASE_FREQUENCY = 1800;
    uint256 private constant MAX_FEE_RATE = 18;
    uint256 private constant MAX_FEE_BUY = 13;
    uint256 private constant MAX_FEE_SELL = 18;

    uint256 public rewardYield;
    uint256 public rewardYieldDenominator;
    uint256 public rebaseFrequency;
    uint256 public nextRebase;
    uint256 public targetLiquidity;
    uint256 public targetLiquidityDenominator;
    address public liquidityReceiver;
    address public treasuryReceiver;
    address public riskFreeValueReceiver;

    uint256 public liquidityFee;
    uint256 public treasuryFee;
    uint256 public buyFeeEssr;
    uint256 public sellFeeTreasury;
    uint256 public totalBuyFee;
    uint256 public totalSellFee;
    uint256 public feeDenominator;

    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => uint256) private _gonBalances;
    mapping(address => bool) private _isFeeExempt;
    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    uint256 private _gonSwapThreshold;
    bool private _inSwap;
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;

    modifier swapping() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    modifier validRecipient(address _to) {
        require(_to != ZERO, "Recipient zero address");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _uniswapRouter,
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _essrReceiver
    ) public initializer {
        __ERC20_init("Eutopia", "EUTO");
        __Ownable_init(_initialOwner);

        rewardYield = 3958125;
        rewardYieldDenominator = 1e10;
        rebaseFrequency = 1800;
        nextRebase = block.timestamp + 31536000;
        targetLiquidity = 50;
        targetLiquidityDenominator = 100;
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        riskFreeValueReceiver = _essrReceiver;

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
        _isFeeExempt[riskFreeValueReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;
        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        _gonSwapThreshold = TOTAL_GONS / 1000;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this),
            uniswapRouter.WETH()
        );
        _inSwap = false;

        emit Transfer(ZERO, msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return _allowedFragments[_owner][_spender];
    }

    function balanceOf(address _who) public view override returns (uint256) {
        return _gonBalances[_who] / _gonsPerFragment;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function checkSwapThreshold() external view returns (uint256) {
        return _gonSwapThreshold / _gonsPerFragment;
    }

    function _shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

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

    function _shouldSwapBack() internal view returns (bool) {
        return
            uniswapPair != msg.sender &&
            !_inSwap &&
            totalBuyFee + totalSellFee > 0 &&
            _gonBalances[address(this)] >= _gonSwapThreshold;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO]) /
            _gonsPerFragment;
    }

    function getLiquidityBacking(
        uint256 _accuracy
    ) public view returns (uint256) {
        uint256 liquidityBalance = balanceOf(uniswapPair) / 10e9;
        return
            (_accuracy * liquidityBalance * 2) /
            (getCirculatingSupply() / 10e9);
    }

    function isOverLiquified(
        uint256 _target,
        uint256 _accuracy
    ) public view returns (bool) {
        return getLiquidityBacking(_accuracy) > _target;
    }

    function manualSync() public {
        IUniswapV2Pair(uniswapPair).sync();
    }

    function transfer(
        address _to,
        uint256 _value
    ) public override validRecipient(_to) returns (bool) {
        _transferFrom(msg.sender, _to, _value);
        return true;
    }

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

        if (_shouldRebase()) {
            _rebase();
            if (uniswapPair != _sender && uniswapPair != _recipient)
                manualSync();
        }

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override validRecipient(_to) returns (bool) {
        uint256 allowed = _allowedFragments[_from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= _value, "Insufficient Allowance");
            _allowedFragments[_from][msg.sender] = allowed - _value;
        }

        _transferFrom(_from, _to, _value);
        return true;
    }

    function _swapAndLiquify(uint256 _contractTokenBalance) private {
        uint256 half = _contractTokenBalance / 2;
        uint256 otherHalf = _contractTokenBalance - half;

        uint256 initialBalance = address(this).balance;

        _swapTokensForETH(half, address(this));

        uint256 newBalance = address(this).balance - initialBalance;

        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

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
            _swapTokensForETH(amountToEssr, riskFreeValueReceiver);
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

    function approve(
        address _spender,
        uint256 _value
    ) public override returns (bool) {
        _allowedFragments[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _rebase() private {
        if (!_inSwap) {
            int256 supplyDelta = int256(
                (_totalSupply * rewardYield) / rewardYieldDenominator
            );
            _coreRebase(supplyDelta);
        }
    }

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

    function manualRebase() external nonReentrant {
        require(!_inSwap, "Try again");
        require(nextRebase <= block.timestamp, "Not in time");

        int256 supplyDelta = int256(
            (_totalSupply * rewardYield) / rewardYieldDenominator
        );
        _coreRebase(supplyDelta);
        manualSync();
        emit ManualRebase(supplyDelta);
    }

    function setFeeExempt(address _addr, bool _value) external onlyOwner {
        require(_isFeeExempt[_addr] != _value, "Not changed");
        _isFeeExempt[_addr] = _value;
        emit SetFeeExempted(_addr, _value);
    }

    function setTargetLiquidity(
        uint256 _target,
        uint256 _accuracy
    ) external onlyOwner {
        targetLiquidity = _target;
        targetLiquidityDenominator = _accuracy;
        emit SetTargetLiquidity(_target, _accuracy);
    }

    function setSwapBackSettings(
        uint256 _num,
        uint256 _denom
    ) external onlyOwner {
        _gonSwapThreshold = (TOTAL_GONS / _denom) * _num;
        emit SetSwapBackSettings(_num, _denom);
    }

    function setFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _essrReceiver
    ) external onlyOwner {
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        riskFreeValueReceiver = _essrReceiver;
        emit SetFeeReceivers(
            _liquidityReceiver,
            _treasuryReceiver,
            _essrReceiver
        );
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _riskFreeValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasury,
        uint256 _feeDenominator
    ) external onlyOwner {
        require(
            _liquidityFee <= MAX_FEE_RATE &&
                _riskFreeValue <= MAX_FEE_RATE &&
                _treasuryFee <= MAX_FEE_RATE &&
                _sellFeeTreasury <= MAX_FEE_RATE,
            "wrong"
        );

        liquidityFee = _liquidityFee;
        buyFeeEssr = _riskFreeValue;
        treasuryFee = _treasuryFee;
        sellFeeTreasury = _sellFeeTreasury;
        totalBuyFee = liquidityFee + treasuryFee + buyFeeEssr;
        totalSellFee = totalBuyFee + sellFeeTreasury;

        require(totalBuyFee <= MAX_FEE_BUY, "Total BUY fee is too high");
        require(totalSellFee <= MAX_FEE_SELL, "Total SELL fee is too high");

        feeDenominator = _feeDenominator;
        require(totalBuyFee < feeDenominator / 4, "totalBuyFee");

        emit SetFees(
            _liquidityFee,
            _riskFreeValue,
            _treasuryFee,
            _sellFeeTreasury,
            _feeDenominator
        );
    }

    function clearStuckBalance(address _receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        payable(_receiver).transfer(balance);
        emit ClearStuckBalance(_receiver);
    }

    function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
        require(_rebaseFrequency <= MAX_REBASE_FREQUENCY, "Too high");
        rebaseFrequency = _rebaseFrequency;
        emit SetRebaseFrequency(_rebaseFrequency);
    }

    function setRewardYield(
        uint256 _rewardYield,
        uint256 _rewardYieldDenominator
    ) external onlyOwner {
        rewardYield = _rewardYield;
        rewardYieldDenominator = _rewardYieldDenominator;
        emit SetRewardYield(_rewardYield, _rewardYieldDenominator);
    }

    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;
        emit SetNextRebase(_nextRebase);
    }

    event SwapBack(
        uint256 _contractTokenBalance,
        uint256 _amountToLiquify,
        uint256 _amountToEssr,
        uint256 _amountToTreasury
    );
    event SwapAndLiquify(
        uint256 _tokensSwapped,
        uint256 _ethReceived,
        uint256 _tokensIntoLiqudity
    );
    event LogRebase(uint256 indexed _epoch, uint256 _totalSupply);
    event ManualRebase(int256 _supplyDelta);
    event SetFeeExempted(address indexed _addr, bool _value);
    event SetTargetLiquidity(uint256 _target, uint256 _accuracy);
    event SetSwapBackSettings(uint256 _num, uint256 _denom);
    event SetFeeReceivers(
        address indexed _liquidityReceiver,
        address indexed _treasuryReceiver,
        address indexed _essrReceiver
    );
    event SetFees(
        uint256 _liquidityFee,
        uint256 _riskFreeValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasury,
        uint256 _feeDenominator
    );
    event ClearStuckBalance(address indexed _receiver);
    event SetRebaseFrequency(uint256 _rebaseFrequency);
    event SetRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator);
    event SetNextRebase(uint256 _nextRebase);
}
