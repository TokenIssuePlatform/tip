pragma solidity ^0.4.23;

import "./common/SafeMath.sol";
import "./common/Owner.sol";

contract K20I {
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function transfer(address to, uint256 value) public returns (bool);
    function balanceOf(address owner) public view returns (uint256);
    function idoRelease(address _idoAddress, uint256 value) public;
    function mint(address to, uint256 value) public returns (bool);
}


contract TipsIDO is Owner{

    using SafeMath for uint256;
    address public tips20TokenAddress;//出售的token合约地址
    uint256 public tips20TokenPoolTotalSupply;//总量
    uint256 public tips20TokenPoolTotalSupplyTemp;//剩余总量
    uint256 public price;//单价
    address public priceToken;//单价币种 如果为address(0)支付币种就为KHC
    uint256 public startBlockNumber;//开启块高
    uint256 public endBlockNumber;//结束块高（非必填,不填就写0）
    uint256 public addressPurchaseLimit;//地址限购数量,为0则不限购
    uint256 public purchaseAtLeast;//最低购买数量
    uint256 public releaseCycle;//释放周期
    uint256 public releaseStartBlockNumber;//开始释放的快高
    mapping (address => uint256) public whiteList;//白名单及可购买数量（非必填,数字为0则不限购）
    bool public whiteListFlag;
    address public collectAddress;//资金归集地址
    uint256 private totalPriceToken;
    mapping (address => uint256) public purchaseAmountMap;//用户购买数量

    constructor (
        address _tips20TokenAddress
    , uint256 _tips20TokenPoolTotalSupply
    , uint256 _price
    , address _priceToken
    , uint256 _startBlockNumber
    , uint256 _endBlockNumber
    , uint256 _addressPurchaseLimit
    , uint256 _purchaseAtLeast
    , uint256 _releaseCycle
    ) public {
        tips20TokenAddress = _tips20TokenAddress;
        tips20TokenPoolTotalSupply = _tips20TokenPoolTotalSupply;
        tips20TokenPoolTotalSupplyTemp = _tips20TokenPoolTotalSupply;
        price = _price;
        priceToken = _priceToken;
        startBlockNumber = _startBlockNumber;
        endBlockNumber = _endBlockNumber;
        addressPurchaseLimit = _addressPurchaseLimit;
        purchaseAtLeast = _purchaseAtLeast;
        releaseCycle = _releaseCycle;
    }

    //添加白名单
    function addWhiteList(address _address, uint256 _amount) public onlyOwner{
        whiteList[_address] = _amount;
        whiteListFlag = true;
    }

    //设置归集地址
    function setCollectAddress(address _collectAddress) public onlyOwner{
        collectAddress=_collectAddress;
    }

    function withdraw() public onlyOwner{
        require(collectAddress != address(0), "collectAddress is address(0)");
        require(totalPriceToken > 0, "totalPriceToken==0");
        if (priceToken == address(0)){
            collectAddress.transfer(totalPriceToken);
        } else {
            K20I k20 = K20I(priceToken);
            k20.transfer(collectAddress, k20.balanceOf(address(this)));
        }
    }

    //认购
    function purchase(uint256 _priceTokenAmount) public payable {
        require(startBlockNumber>0, "startBlockNumber equals 0");
        require(block.number>=startBlockNumber, "not start");
        if (endBlockNumber > 0) {
            require(block.number<=endBlockNumber, "end!");
        }

        require(tips20TokenPoolTotalSupplyTemp>0, "sold out, tips20TokenPoolTotalSupply is zero");
        if(priceToken == address(0)){
            _priceTokenAmount = msg.value;
            require(_priceTokenAmount>0, "invalid transfer amount!");
        } else {
            require(_priceTokenAmount>0, "invalid transfer k20 amount!");
            K20I k20 = K20I(priceToken);
            require(k20.transferFrom(msg.sender, address(this), _priceTokenAmount), "transfer k20 fail!");
        }
        require(price>0, "invalid price!");
        totalPriceToken = totalPriceToken.add(_priceTokenAmount);
        uint256 purchaseAmount = _priceTokenAmount.div(price);
        if (purchaseAtLeast > 0) {
            require(purchaseAmount>=purchaseAtLeast, "invalid at least amount!");
        }
        require(tips20TokenPoolTotalSupplyTemp>=purchaseAmount, "not enough!");
        tips20TokenPoolTotalSupplyTemp = tips20TokenPoolTotalSupplyTemp.sub(purchaseAmount);
        uint256 addressPurchaseTotalAmount = purchaseAmountMap[msg.sender].add(purchaseAmount);

        if (addressPurchaseLimit>0)
            require (addressPurchaseTotalAmount<=addressPurchaseLimit, "purchase enough!");
        if (whiteListFlag)
            require(whiteList[msg.sender]>0 && addressPurchaseTotalAmount<=whiteList[msg.sender], "white list purchase enough!");

        purchaseAmountMap[msg.sender] = addressPurchaseTotalAmount;

    }

    //可释放数量,锁定数量,本次释放数量对应的购买花费
    function canReleaseView(address _releaseAddress) public view returns (uint256, uint256, uint256){
        if (releaseStartBlockNumber > 0 && block.number>=releaseStartBlockNumber){
            uint256 releaseAmount = 0;
            uint256 lockedAmount = 0;
            if (block.number - releaseStartBlockNumber >= releaseCycle){
                releaseAmount = purchaseAmountMap[_releaseAddress];
                return (releaseAmount, 0, 0);
            } else {
                releaseAmount = purchaseAmountMap[_releaseAddress].mul(block.number - releaseStartBlockNumber).div(releaseCycle);
                lockedAmount = purchaseAmountMap[_releaseAddress].sub(releaseAmount);
                return (releaseAmount, lockedAmount, 0);
            }
        } else {
            lockedAmount = purchaseAmountMap[_releaseAddress];
            return (0, lockedAmount, 0);
        }
    }

    function release(address _releaseAddress) public {
        require(releaseStartBlockNumber > 0, "not begin release");
        require(msg.sender == tips20TokenAddress, "invalid release sender");//只能20合约能释放
        uint256 releaseAmount = 0;
        uint256 lockedAmount = 0;
        uint256 canPurchaseAmount = 0;
        (releaseAmount, lockedAmount, canPurchaseAmount) = canReleaseView(_releaseAddress);
        if (canPurchaseAmount > 0){
            purchaseAmountMap[_releaseAddress] = purchaseAmountMap[_releaseAddress].sub(releaseAmount);
        }

        if (releaseAmount > 0) {
            K20I k20 = K20I(tips20TokenAddress);
            k20.mint(_releaseAddress, releaseAmount);
        }
    }

    function setReleaseStartBlockNumber(uint256 _releaseStartBlockNumber) public onlyOwner{
        require(_releaseStartBlockNumber>=block.number, "invalid block number");
        releaseStartBlockNumber = _releaseStartBlockNumber;
    }
}