//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import "./ACDMToken.sol";
import "hardhat/console.sol";

contract ACDMPlatform {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Offer {
        uint256 totalSupply;
        uint256 lastPrice;
        uint256 totalSupplyEth;
        uint256 totalBuy;
        uint256 timeStart;
        Status status;
    }

    struct Order {
        address owner;
        uint256 amount;
        uint256 price;
    }

    enum Status {
        SaleRound,
        TradeRound,
        End
    }

    event Register(address user, address referrer);
    event StartSaleRound(
        uint256 totalSupply,
        uint256 lastPrice,
        uint256 totalSupplyEth,
        Status status
    );
    event BuyACDM(address buyer, uint256 amount);
    event StartTradeRound(uint256 timeStart, Status status);
    event AddOrder(address owner, uint256 amount, uint256 price);
    event ReedemOrder(address buyer, uint256 amount);

    mapping(uint256 => Order) orders;
    mapping(address => address) referrers;

    Offer offer;
    ACDMToken public token;
    uint256 public roundTime;
    uint256 public decimals = 10**18;
    uint256 public numOfOrder;
    address public tokenAddress;

    constructor(address _token, uint256 _roundTime) {
        token = ACDMToken(_token);
        roundTime = _roundTime;

        tokenAddress = _token;
    }

    function register(address _referrer) external {
        require(referrers[msg.sender] == address(0), "You are registred");

        referrers[msg.sender] = _referrer;
        emit Register(msg.sender, _referrer);
    }

    function getReferrer() public view returns (address) {
        require(referrers[msg.sender] != address(0), "You are not registred");

        return referrers[msg.sender];
    }

    function startSaleRound() external {
        require(offer.status != Status.End, "Offer is ended");

        if (offer.status == Status.TradeRound) {
            require(offer.timeStart + roundTime <= block.timestamp, "Trade round not finished");
            if(numOfOrder != 0){
                for(uint i = 1; i <= numOfOrder; i++){
                    token.transfer(orders[i].owner, orders[i].amount);
                    orders[i].amount = 0;
                }
                numOfOrder = 0;
            }
            offer = Offer((offer.totalSupplyEth / offer.lastPrice) * decimals, (offer.lastPrice * 103 / 100) + (4 * decimals / 1000000), 0, 0, block.timestamp, Status.SaleRound);
        } else {
            offer = Offer(100000 * decimals, 1 * decimals / 100000, 0, 0, block.timestamp, Status.SaleRound);
        }
        
        token.mint(address(this), offer.totalSupply);
        emit StartSaleRound(offer.totalSupply, offer.lastPrice, 0, Status.SaleRound);
    }

    function buyACDM(uint256 amount) external payable {
        require(offer.totalSupply - offer.totalBuy >= amount * decimals, "Dont have enough tokens");
        require(msg.value >= offer.lastPrice * amount, "You dont have enough ETH");
        require(offer.status == Status.SaleRound, "Not a sale round now");

        if(referrers[msg.sender] != address(0)) {
            _safeTransferETH(referrers[msg.sender], msg.value * 5 / 100);
            if(referrers[referrers[msg.sender]] != address(0)){
                _safeTransferETH(referrers[referrers[msg.sender]], msg.value * 3 / 100);
            }
        }

        token.transfer(msg.sender, amount * decimals);
        offer.totalBuy += amount * decimals;
        emit BuyACDM(msg.sender, amount);
    }

    function startTradeRound() public {
        require(offer.status == Status.SaleRound, "Offer is ended or trade round is underway");
        require(offer.timeStart + roundTime <= block.timestamp, "Sale round not finished");

        offer.status = Status.TradeRound;
        offer.timeStart = block.timestamp;
        token.burn(address(this), offer.totalSupply - offer.totalBuy);
        offer.totalBuy = 0;
        emit StartTradeRound(offer.timeStart, offer.status);

    }

    function getStatusRound(uint256 _orderId) external view returns(Status) {
        return offer.status;
    }

    function addOrder(uint256 amount, uint256 price) external {
        require(offer.status == Status.TradeRound || offer.status == Status.End, "Not a trade round now");
        require(token.balanceOf(msg.sender) >= amount * decimals, "You dont have enough tokens");

        numOfOrder++;
        orders[numOfOrder] = Order(msg.sender, amount * decimals, price);
        token.transferFrom(msg.sender, address(this), amount * decimals);
        emit AddOrder(msg.sender, amount * decimals, price);

    }

    function removeOrder(uint256 orderId) external {
        require(orders[orderId].owner == msg.sender, "Caller is not a owner");

        token.transfer(msg.sender, orders[orderId].amount);
        orders[orderId].amount = 0;
        numOfOrder--;        
    }

    function reedemOrder(uint256 orderId, uint256 amount) external payable {
        require(orders[orderId].amount >= amount * decimals, "Order dont have enough tokens");
        require(msg.value >= orders[orderId].price * amount, "You dont have enough ETH");

        token.transfer(msg.sender, amount * decimals);

        if(referrers[msg.sender] != address(0)) {
            _safeTransferETH(referrers[msg.sender], msg.value * 25 / 1000);
            if(referrers[referrers[msg.sender]] != address(0)){
                _safeTransferETH(referrers[referrers[msg.sender]], msg.value * 25 / 1000);
            }
            else {_safeTransferETH(address(this), msg.value * 25 / 1000);}
        }
        else {_safeTransferETH(address(this), msg.value * 5 / 100);}

        _safeTransferETH(orders[orderId].owner, orders[orderId].price * amount);
        orders[orderId].amount -= amount * decimals;
        offer.totalBuy += amount * decimals;
        offer.totalSupplyEth += msg.value;
        if(orders[orderId].amount == 0) {
            numOfOrder--;
        }
        emit ReedemOrder(msg.sender, amount * decimals);
    }

    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{value: value}(new bytes(0));
        return success;
    }

}