// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Eutopia is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public rewardYield = 3958125;
    uint256 public rewardYieldDenominator = 10000000000;

    uint256 public rebaseFrequency = 1800;
    uint256 public nextRebase = block.timestamp + 31536000;

    mapping(address => bool) _isFeeExempt;

    uint256 public constant MAX_FEE_RATE = 18;
    uint256 public constant MAX_FEE_BUY = 13;
    uint256 public constant MAX_FEE_SELL = 18;
    uint256 private constant MAX_REBASE_FREQUENCY = 1800;
    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        23 * 10**8 * 10**DECIMALS;
    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = ~uint128(0);

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public liquidityReceiver =
        0xF52c9341dC4ee92c321Fa11e01E3a6303f9bBe00;
    address public treasuryReceiver =
        0x6560eD767D6003D779F60BCCD2d7B168Cd4a1583;
    address public riskFreeValueReceiver =
        0xAf47725C293452Ade77770Bfb6BD2680564DA157;

    IUniswapV2Router02 public router;
    address public pair;

    uint256 public liquidityFee = 5;
    uint256 public treasuryFee = 5;
    uint256 public buyFeeRFV = 3;
    uint256 public sellFeeTreasuryAdded = 5;
    uint256 public totalBuyFee = liquidityFee + treasuryFee + buyFeeRFV;
    uint256 public totalSellFee =
        totalBuyFee + sellFeeTreasuryAdded;
    uint256 public feeDenominator = 100;

    uint256 targetLiquidity = 50;
    uint256 targetLiquidityDenominator = 100;

    bool inSwap;

    modifier swapping() {
        require (inSwap == false, "ReentrancyGuard: reentrant call");
        inSwap = true;
        _;
        inSwap = false;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0), "Recipient zero address");
        _;
    }

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    uint256 private gonSwapThreshold = TOTAL_GONS  / 1000;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __ERC20_init("Eutopia", "EUTO");
        __Ownable_init(initialOwner);

        router = IUniswapV2Router02(0x2Bf55D1596786F1AE8160e997D655DbE6d9Bca7A); //mainnet
        
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        _allowedFragments[address(this)][address(router)] = type(uint256).max;
        _allowedFragments[address(this)][pair] = type(uint256).max;
        _allowedFragments[address(this)][address(this)] = type(uint256).max;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[riskFreeValueReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;

        emit Transfer(address(0x0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(address owner_, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who] / _gonsPerFragment;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold / _gonsPerFragment;
    }

    function shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        if (_isFeeExempt[from] || _isFeeExempt[to]) {
            return false;
        } else {
            return (pair == from ||
                pair == to);
        }
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            pair != msg.sender &&
            !inSwap &&
            totalBuyFee + totalSellFee > 0 &&
            _gonBalances[address(this)] >= gonSwapThreshold;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO]) / _gonsPerFragment;
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = balanceOf(pair) / (10**9);
        return
            accuracy * (liquidityBalance * 2) / (
                getCirculatingSupply() / (10**9)
            );
    }

    function isOverLiquified(uint256 target, uint256 accuracy)
        public
        view
        returns (bool)
    {
        return getLiquidityBacking(accuracy) > target;
    }

    function manualSync() public {
        IUniswapV2Pair(pair).sync();
    }

    function transfer(address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount * _gonsPerFragment;
        _gonBalances[from] = _gonBalances[from] - gonAmount;
        _gonBalances[to] = _gonBalances[to] + gonAmount;

        emit Transfer(from, to, amount);

        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 gonAmount = amount * _gonsPerFragment;

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender] - gonAmount;

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient] + gonAmountReceived;

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived / _gonsPerFragment
        );

        if (shouldRebase()) {
            _rebase();

            if (
                pair != sender &&
                pair != recipient
            ) {
                manualSync();
            }
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override validRecipient(to) returns (bool) {
        uint256 allowed = _allowedFragments[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "Insufficient Allowance");
            _allowedFragments[from][msg.sender] = allowed - value;
        }

        _transferFrom(from, to, value);
        return true;
    }

    function _swapAndLiquify(uint256 contractTokenBalance) private {
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        uint256 initialBalance = address(this).balance;

        _swapTokensForBNB(half, address(this));

        uint256 newBalance = address(this).balance - initialBalance;

        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
    }

    function _swapTokensForBNB(uint256 tokenAmount, address receiver) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            receiver,
            block.timestamp
        );
    }

    function swapBack() internal swapping {
        uint256 realTotalFee = totalBuyFee + totalSellFee;

        uint256 dynamicLiquidityFee = isOverLiquified(
            targetLiquidity,
            targetLiquidityDenominator
        )
            ? 0
            : liquidityFee;
        uint256 contractTokenBalance = _gonBalances[address(this)] / _gonsPerFragment;

        uint256 amountToLiquify = contractTokenBalance
            * (dynamicLiquidityFee * 2)
            / realTotalFee;
        uint256 amountToRFV = contractTokenBalance
            * (buyFeeRFV * 2)
            / realTotalFee;
        uint256 amountToTreasury = contractTokenBalance
            - amountToLiquify
            - amountToRFV;

        if (amountToLiquify > 0) {
            _swapAndLiquify(amountToLiquify);
        }

        if (amountToRFV > 0) {
            _swapTokensForBNB(amountToRFV, riskFreeValueReceiver);
        }

        if (amountToTreasury > 0) {
            _swapTokensForBNB(amountToTreasury, treasuryReceiver);
        }

        emit SwapBack(
            contractTokenBalance,
            amountToLiquify,
            amountToRFV,
            amountToTreasury
        );
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        uint256 _realFee = totalBuyFee;
        if (pair == recipient) _realFee = totalSellFee;

        uint256 feeAmount = gonAmount * _realFee / feeDenominator;

        _gonBalances[address(this)] = _gonBalances[address(this)] + feeAmount;
        emit Transfer(sender, address(this), feeAmount / _gonsPerFragment);

        return gonAmount - feeAmount;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue - subtractedValue;
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ] + addedValue;
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function _rebase() private {
        if (!inSwap) {
            //uint256 circulatingSupply = getCirculatingSupply();
            int256 supplyDelta = int256(
                _totalSupply * rewardYield / rewardYieldDenominator
            );

            coreRebase(supplyDelta);
        }
    }

    function coreRebase(int256 supplyDelta) private returns (uint256) {
        uint256 epoch = block.timestamp;

        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply - uint256(-supplyDelta);
        } else {
            _totalSupply = _totalSupply + uint256(supplyDelta);
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        nextRebase = epoch + rebaseFrequency;

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function manualRebase() external  nonReentrant{
        require(!inSwap, "Try again");
        require(nextRebase <= block.timestamp, "Not in time");

        //uint256 circulatingSupply = getCirculatingSupply();
        int256 supplyDelta = int256(
            _totalSupply * rewardYield / rewardYieldDenominator
        );

        coreRebase(supplyDelta);
        manualSync();
        emit ManualRebase(supplyDelta);
    }

    function setFeeExempt(address _addr, bool _value) external onlyOwner {
        require(_isFeeExempt[_addr] != _value, "Not changed");
        _isFeeExempt[_addr] = _value;
        emit SetFeeExempted(_addr, _value);
    }

    function setTargetLiquidity(uint256 target, uint256 accuracy)
        external
        onlyOwner
    {
        targetLiquidity = target;
        targetLiquidityDenominator = accuracy;
        emit SetTargetLiquidity(target, accuracy);
    }

    function setSwapBackSettings(
        uint256 _num,
        uint256 _denom
    ) external onlyOwner {
        gonSwapThreshold = TOTAL_GONS / _denom * _num;
        emit SetSwapBackSettings(_num, _denom);
    }

    function setFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _riskFreeValueReceiver
    ) external onlyOwner {
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        riskFreeValueReceiver = _riskFreeValueReceiver;
        emit SetFeeReceivers(_liquidityReceiver, _treasuryReceiver, _riskFreeValueReceiver);
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _riskFreeValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasuryAdded,
        uint256 _feeDenominator
    ) external onlyOwner {
        require(
            _liquidityFee <= MAX_FEE_RATE &&
                _riskFreeValue <= MAX_FEE_RATE &&
                _treasuryFee <= MAX_FEE_RATE &&
                _sellFeeTreasuryAdded <= MAX_FEE_RATE,
            "wrong"
        );

        liquidityFee = _liquidityFee;
        buyFeeRFV = _riskFreeValue;
        treasuryFee = _treasuryFee;
        sellFeeTreasuryAdded = _sellFeeTreasuryAdded;
        totalBuyFee = liquidityFee + treasuryFee + buyFeeRFV;
        totalSellFee = totalBuyFee + sellFeeTreasuryAdded;

        require(totalBuyFee <= MAX_FEE_BUY, "Total BUY fee is too high");
        require(totalSellFee <= MAX_FEE_SELL, "Total SELL fee is too high");
        
        feeDenominator = _feeDenominator;
        require(totalBuyFee < feeDenominator / 4, "totalBuyFee");

        emit SetFees(_liquidityFee, _riskFreeValue, _treasuryFee, _sellFeeTreasuryAdded, _feeDenominator);
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
        emit SetRewardYield(_rewardYield,_rewardYieldDenominator);
    }

    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;
        emit SetNextRebase(_nextRebase);
    }

    event SwapBack(
        uint256 contractTokenBalance,
        uint256 amountToLiquify,
        uint256 amountToRFV,
        uint256 amountToTreasury
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event ManualRebase(int256 supplyDelta);
    event SetFeeExempted(address _addr, bool _value);
    event SetTargetLiquidity(uint256 target, uint256 accuracy);
    event SetSwapBackSettings(uint256 _num, uint256 _denom);
    event SetFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _riskFreeValueReceiver
    );
    event SetFees(
        uint256 _liquidityFee,
        uint256 _riskFreeValue,
        uint256 _treasuryFee,
        uint256 _sellFeeTreasuryAdded,
        uint256 _feeDenominator
    );
    event ClearStuckBalance(address _receiver);
    event SetRebaseFrequency(uint256 _rebaseFrequency);
    event SetRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator);
    event SetNextRebase(uint256 _nextRebase);
}
