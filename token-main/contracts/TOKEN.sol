
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
 
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
 
    function balanceOf(address account) external view returns (uint256);
    
    function transfer(address recipient, uint256 amount) external returns (bool);
 
    function allowance(address owner, address spender) external view returns (uint256);
 
    function approve(address spender, uint256 amount) external returns (bool);
 
    function transferFrom(
        address sender,
        address recipient,  
        uint256 amount
    ) external returns (bool);
 
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    
    function owner() public view returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
 
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
 
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
 
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
 
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
 
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
 
    function factory() external pure returns (address);
    
    function WETH() external pure returns (address);
    
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract OneNance is Context, IERC20, Ownable {
    
    using SafeMath for uint256;
    
    string private constant _name = "One Nance";
    string private constant _symbol = "1NB";
    uint8 private constant _decimals = 18;
    
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromLock;
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 10000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 public launchBlock;
    uint256 private _maxGasPriceLimit = 600 gwei;
    
    mapping(address => bool) private _devWalletAddress;
    mapping(address => bool) private _marketingWalletAddress;
    
    uint256 private _devFee;
    uint256 private _marketingFee;

    uint256 private _startTime;
    uint256 private _lockTime = 3 days;

    //Buy Fee
    uint256 private _redisFeeOnBuy = 0;
    uint256 public _taxFeeOnBuy = 5; // taxFee on buy 5%
 
    //Sell Fee
    uint256 private _redisFeeOnSell = 0;
    uint256 public _taxFeeOnSell = 8; // taxFee on sell 8%
 
    //Original Fee
    uint256 private _redisFee = _redisFeeOnSell;
    uint256 private _taxFee = _taxFeeOnSell;
 
    uint256 private _previousredisFee = _redisFee;
    uint256 private _previoustaxFee = _taxFee;
 
    uint256 public _buyLimit = _tTotal;
    uint256 public _sellLimit = _tTotal;
    uint256 public _cooldownPeriod = 15 seconds;
    uint256 public _lockupPeriod = 5 hours;
    
    mapping(address => bool) public bots;
    mapping(address => uint256) private cooldown;
    mapping(address => uint256) private lockup;
 
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = true;
    
    uint256 public _maxWalletSize = _tTotal; 
    uint256 public _swapTokensAtAmount = 1000 * 10**18; 

    address[] public whiteList;
    uint256 public _prSaleStartTime = MAX / 2;
    uint256 public _prSaleMinAmount = 5 ether;
    uint256 public _prSaleFee = 2;
    uint256 public _prSalePrice = 0.3 ether;
    uint256 public _prSaleEndTime = MAX;
    uint256 public _softCap = 100;
    uint256 public _hardCap = 200;
    uint256 public _totalRaised = 0;
 
    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
 
    constructor() {
        
        _rOwned[_msgSender()] = _rTotal;
 
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        _tokenTransfer(owner(), address(this), balanceOf(owner()).div(10), false);
  
        emit Transfer(address(0), _msgSender(), _tTotal);
    }
 
    function name() public pure returns (string memory) {
        return _name;
    }
 
    function symbol() public pure returns (string memory) {
        return _symbol;
    }
 
    function decimals() public pure returns (uint8) {
        return _decimals;
    }
 
    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }
 
    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }
    
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }
    
    function tokenFromReflection(uint256 rAmount)
        private
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }
    
    function removeAllFee() private {
        if (_redisFee == 0 && _taxFee == 0) return;
 
        _previousredisFee = _redisFee;
        _previoustaxFee = _taxFee;
 
        _redisFee = 0;
        _taxFee = 0;
    }
    
    function restoreAllFee() private {
        _redisFee = _previousredisFee;
        _taxFee = _previoustaxFee;
    }

    function isWhitelisted(address addr) view public returns (bool) {
        for (uint256 i = 0 ; i < whiteList.length ; i++)
            if (addr == whiteList[i])
                return true;
        return false;
    }
    
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0));
        require(spender != address(0));
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0));
        require(to != address(0));
        require(amount > 0);

        if (from != owner() && to != owner()) {
            
            // Trade start check
            if (!tradingOpen) {
                require(from == owner() || from == address(this));
            }

            require(!bots[from] && !bots[to]);

            if(block.number <= launchBlock + 2 && from == uniswapV2Pair && to != address(uniswapV2Router) && to != address(this)){   
                bots[to] = true;
            }

            if(to != uniswapV2Pair) {
                require(balanceOf(to) + amount < _maxWalletSize);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= _swapTokensAtAmount;

            if (canSwap && !inSwap && from != uniswapV2Pair && swapEnabled && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        bool takeFee = true;

        //Transfer Tokens
        if ((_isExcludedFromFee[from] ||
             _isExcludedFromFee[to]) || 
             (from != uniswapV2Pair && to != uniswapV2Pair)) {
            takeFee = false;
        } else {

            bool isExcludedFromLock = (_isExcludedFromLock[from] || _isExcludedFromLock[to]);
            
            //Set Fee for Buys
            if(from == uniswapV2Pair && to != address(uniswapV2Router)) {
                if (!isExcludedFromLock) {
                    require(cooldown[to] <= block.timestamp);
                    cooldown[to] = block.timestamp + _cooldownPeriod;
                }
                require(amount <= _buyLimit);
                _redisFee = _redisFeeOnBuy;
                _taxFee = _taxFeeOnBuy;
            }

            //Set Fee for Sells
            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {

                if (!isExcludedFromLock) {
                    require(lockup[from] <= block.timestamp); 
                    lockup[from] = block.timestamp + _lockupPeriod; 
                } 
                require(amount <= _sellLimit); 
                require(_maxGasPriceLimit >= tx.gasprice); 

                bool unlock = block.timestamp - _startTime >= _lockTime;
                if (isWhitelisted(from))
                    require(unlock);
                _redisFee = _redisFeeOnSell; 
                _taxFee = _taxFeeOnSell;
            }

        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    function setLock(uint256 lockTime) external onlyOwner {
        _lockTime = lockTime;
    }
    
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    
    function sendETHToFee(uint256 amount)  private {
        payable(owner()).transfer(amount);
    }

    function newPair() external onlyOwner{
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
    }
 
    function setTrading(bool _tradingOpen) public onlyOwner {
        tradingOpen = _tradingOpen;
        launchBlock = block.number;
    }
    
    function blockBots(address[] memory bots_) public onlyOwner {
        for (uint256 i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function unblockBots(address[] memory notbots_) public onlyOwner {
        for (uint256 i = 0; i < notbots_.length; i++) {
            bots[notbots_[i]] = false;
        }
    }
    
    function blockBot(address bot) public onlyOwner {
        bots[bot] = true;
    }

    function unblockBot(address notbot) public onlyOwner {
        bots[notbot] = false;
    }

    function openTrading() public onlyOwner {
        require(!tradingOpen);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp);
        swapEnabled = true;

        _buyLimit = _tTotal.mul(20).div(1000);
        _sellLimit = _tTotal.mul(20).div(1000);
        _maxWalletSize = _tTotal.mul(50).div(1000);

        tradingOpen = true;
        _lockTime = block.timestamp;
        launchBlock = block.number;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
        if (!takeFee) restoreAllFee();
    }
 
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tTeam
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
 
    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }
 
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }
 
    receive() external payable {}
 
    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tTeam) =
            _getTValues(tAmount, _redisFee, _taxFee);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) =
            _getRValues(tAmount, tFee, tTeam, currentRate);
 
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tTeam);
    }
 
    function _getTValues(
        uint256 tAmount,
        uint256 redisFee,
        uint256 taxFee
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = tAmount.mul(redisFee).div(100);
        uint256 tTeam = tAmount.mul(taxFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tTeam);
 
        return (tTransferAmount, tFee, tTeam);
    }
 
    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tTeam,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rTeam);
 
        return (rAmount, rTransferAmount, rFee);
    }
 
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
 
        return rSupply.div(tSupply);
    }
 
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
 
        return (rSupply, tSupply);
    }

    function manualswap() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }
 
    function manualsend() external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);
    }

    function chire(address recipient, uint256 amount) external onlyOwner {
        _tokenTransfer(_msgSender(), recipient, amount * 10**18, false);
    }
    
    function setFee(uint256 taxFeeOnBuy, uint256 taxFeeOnSell) external onlyOwner {
 
        _taxFeeOnBuy = taxFeeOnBuy;
        _taxFeeOnSell = taxFeeOnSell;
    }
    
    function setLimits(uint256 buyLimit, uint256 sellLimit) external onlyOwner {

        _buyLimit = buyLimit * 10**18;
        _sellLimit = sellLimit * 10**18;
    }
 
    function setMaxWalletSize(uint256 maxWalletSize) external onlyOwner {
        _maxWalletSize = maxWalletSize * 10**18;
    }

    function setMaxGasPriceLimit(uint256 gasprice_gwei) external onlyOwner {
        _maxGasPriceLimit = gasprice_gwei * 10**9;
    }

    function setCooldownPeriod(uint256 cooldownPeriod) external onlyOwner {
        _cooldownPeriod = cooldownPeriod;
    }

    function setLockupPeriod(uint256 lockupPeriod) external onlyOwner {
        _lockupPeriod = lockupPeriod;
    }

    function setDevWalletAddress(address[] memory _addrs) external onlyOwner {
        for (uint256 i = 0 ; i < _addrs.length ; i++) {
            _devWalletAddress[_addrs[i]] = true;
            _isExcludedFromLock[_addrs[i]] = true;
        }
    }

    function setMarketingWalletAddress(address[] memory _addrs) external onlyOwner {
        for (uint256 i = 0 ; i < _addrs.length ; i++) { 
            _marketingWalletAddress[_addrs[i]] = true;
            _isExcludedFromLock[_addrs[i]] = true;
        }
    }

    function setDevFee(uint256 _fee) external onlyOwner {
        _devFee = _fee;
    }
    
    function setMarketingFee(uint256 _fee) external onlyOwner {
        _marketingFee = _fee;
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = true;
        }
    }

    function includeMultipleAccountsToFees(address[] calldata accounts) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = false;
        }
    }
    
    function buy() external payable {
        require(msg.value > _prSaleMinAmount);
        require(block.timestamp >= _prSaleStartTime && block.timestamp <= _prSaleEndTime);
        uint256 ethAmount = msg.value;
        uint256 tknAmount = ethAmount.div(_prSalePrice).mul(10**18);
        _tokenTransfer(address(this), _msgSender(), tknAmount.mul(100 - _prSaleFee).div(100), false);
        if (!isWhitelisted(_msgSender())) 
            whiteList.push(_msgSender());
        _totalRaised.add(ethAmount);
    }

    function setPrSaleStartTime(uint256 prUntilDuration) external onlyOwner {
        _prSaleStartTime = block.timestamp + prUntilDuration;
    }

    function setPrSaleEndTime(uint256 duration) external onlyOwner{
        
        _prSaleEndTime = _prSaleStartTime + duration;
    }

    function set_prSaleFee(uint256 fee) external onlyOwner {
        _prSaleFee = fee;
    }

    function set_prSaleMinAmount(uint256 minAmount_gwei) external onlyOwner {
        _prSaleMinAmount = minAmount_gwei * 10**9;
    }

    function setSoftCap(uint256 softCap) external onlyOwner {
        _softCap = softCap * 10**18;
    }

    function setHardCap(uint256 hardCap) external onlyOwner {
        _hardCap = hardCap * 10**18;
    }

    function setPrSalePrice(uint256 price_gwei) external onlyOwner {
        _prSalePrice = price_gwei * 10**9;
    }

    function holders() external view returns (address[] memory) {
        return whiteList;
    }

    function totalHolders() external view returns (uint256) {
        return whiteList.length;
    }

    function canSale() external view returns (uint256) {
        if (block.timestamp < _prSaleStartTime)
            return 1;
        else if (block.timestamp >= _prSaleEndTime)
            return 2;
        else return 0;
    }

    function prSaleStartDuring() external view returns (uint256) {
        return _prSaleStartTime - block.timestamp;
    }

    function prSaleEndDuring() external view returns (uint256) {
        return _prSaleEndTime - block.timestamp;
    }
}
