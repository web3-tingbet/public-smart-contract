pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./TingBetDef.sol";

contract TingBet is AccessControl, Ownable {
    event RResult(string message, uint256 amount);
    event TResult(
        string message,
        address sender,
        uint256 poolId,
        uint256 status,
        uint32 betOption,
        uint256 amount // or extraValue
    );

    using SafeMath for uint256;
    uint32 MAX_100_PERCENT = 10000;
    uint8 _REGED = 1;
    uint8 _ACTIVED = 2;
    uint8 _RESULTED = 3;
    uint8 _CLOSED = 4;
    uint8 _CANCELLED = 5;
    uint8 _EXPIRED = 6;

    uint8 _CLAIMED = 1;
    uint8 _VOTED = 2;
    mapping(uint256 => TingBetDef.PoolInfo) private pools;

    uint32 private totalWinPlayer = 0;
    mapping(uint32 => address) private winPlayerAddress;

    uint256 private _expiredPoolTs;
    uint256 private _minPoolSize;
    uint256 private _maxPoolSize;
    uint256 private _claimNoOneWinFee;
    uint256 private _cancelStakingFee;
    uint256 private _voteFreezePoolFee;
    uint256 private _minClaimBetResultTs;
    uint256 private _totalAmountforOwner;
    uint256 private _registerPoolFee;
    uint256 private _addMemberBaseFee;

    constructor(
        uint256 expiredPoolTs_,
        uint256 minPoolSize_,
        uint256 maxPoolSize_,
        uint256 claimNoOneWinFee_,
        uint256 cancelStakingFee_,
        uint256 minClaimBetResultTs_,
        uint256 registerPoolFee_,
        uint256 addMemberBaseFee_,
        uint256 voteFreezePoolFee_
    ) {
        _expiredPoolTs = expiredPoolTs_;
        _minPoolSize = minPoolSize_;
        _maxPoolSize = maxPoolSize_;
        _claimNoOneWinFee = claimNoOneWinFee_;
        _cancelStakingFee = cancelStakingFee_;
        _minClaimBetResultTs = minClaimBetResultTs_;
        _registerPoolFee = registerPoolFee_;
        _addMemberBaseFee = addMemberBaseFee_;
        _voteFreezePoolFee = voteFreezePoolFee_;
    }

    function getGlobalVals()
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _expiredPoolTs,
            _minPoolSize,
            _maxPoolSize,
            _claimNoOneWinFee,
            _cancelStakingFee,
            _voteFreezePoolFee,
            _minClaimBetResultTs,
            _registerPoolFee,
            _addMemberBaseFee
        );
    }

    function setGlobalVal(
        uint256 minPoolSize_,
        uint256 maxPoolSize_,
        uint256 registerPoolFee_,
        uint256 addMemberBaseFee_
    ) public onlyOwner {
        _minPoolSize = minPoolSize_;
        _maxPoolSize = maxPoolSize_;
        _registerPoolFee = registerPoolFee_;
        _addMemberBaseFee = addMemberBaseFee_;
    }

    function mGetTotalAmountforOwner() public onlyOwner {
        emit RResult("ownerAmt", _totalAmountforOwner);
    }

    function mGetBalance() public onlyOwner {
        emit RResult("contractBalance", address(this).balance);
    }

    modifier isActive(uint256 poolId_) {
        require(pools[poolId_].status == _ACTIVED, "Pool is not actived");
        _;
    }

    function withdrawMoneyTo(address payable to_, uint256 amount_)
        public
        onlyOwner
    {
        // gas fee belongs to sender
        require(
            amount_ <= _totalAmountforOwner,
            "amount <= totalAmountforOwner."
        );

        to_.transfer(amount_);
        _totalAmountforOwner = _totalAmountforOwner.sub(amount_);
    }

    function registerNewPool(
        uint256 poolId_,
        address[] memory _visibilityAddresses
    ) public payable {
        require(pools[poolId_].status == 0, "pool not opened");
        require(
            msg.value >=
                _registerPoolFee +
                    _addMemberBaseFee *
                    _visibilityAddresses.length,
            "not enough fee."
        );

        pools[poolId_].poolCreator = msg.sender;
        pools[poolId_].status = _REGED;

        if (_visibilityAddresses.length == 0) {
            pools[poolId_].isPublic = true;
        }
        for (uint32 i = 0; i < _visibilityAddresses.length; i++) {
            pools[poolId_].visibilityAddresses[_visibilityAddresses[i]] = true;
        }

        _totalAmountforOwner = _totalAmountforOwner.add(msg.value);
        emit TResult(
            "1|registerNewPool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            0,
            msg.value
        );
    }

    function activateNewPool(
        uint256 poolId_,
        uint32 matchId_,
        uint32 betTypeId_,
        address poolCreator_,
        uint256 poolSize_,
        uint16 claimWonFeeRate_,
        uint256 closeStakingTs_,
        uint256 betFee_
    ) public onlyOwner {
        require(
            poolSize_ > _claimNoOneWinFee &&
                poolSize_ > _cancelStakingFee &&
                poolSize_ > _voteFreezePoolFee,
            "poolsize > fee"
        );
        require(pools[poolId_].status == _REGED, "pool not reged");
        require(
            pools[poolId_].poolCreator == poolCreator_,
            "different creator"
        );
        require(
            claimWonFeeRate_ > 0 && claimWonFeeRate_ < MAX_100_PERCENT,
            "invalid claimWonFeeRate"
        );
        require(betFee_ >= 0 && betFee_ <= poolSize_, "invalid betFee");
        require(
            poolSize_ >= _minPoolSize && poolSize_ <= _maxPoolSize,
            "invalid poolSize."
        );

        pools[poolId_].matchId = matchId_;
        pools[poolId_].betTypeId = betTypeId_;
        pools[poolId_].status = _ACTIVED; // activated
        pools[poolId_].poolSize = poolSize_;
        pools[poolId_].claimWonFeeRate = claimWonFeeRate_;
        pools[poolId_].closeStakingTs = closeStakingTs_;
        pools[poolId_].betFee = betFee_;
        emit TResult(
            "1|activateNewPool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            0,
            pools[poolId_].poolSize
        );
    }

    function cancelPool(uint256 poolId_) public onlyOwner isActive(poolId_) {
        require(pools[poolId_].totalBetPlayers == 0, "not empty pool");
        pools[poolId_].status = _CANCELLED;
        emit TResult(
            "1|cancelPool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            0,
            pools[poolId_].poolSize
        );
    }

    function makeBetOption(uint256 poolId_, uint32 betOption_)
        public
        payable
        isActive(poolId_)
    {
        require(pools[poolId_].status == _ACTIVED, "pool not actived");
        require(
            block.timestamp <= pools[poolId_].closeStakingTs,
            "invalid bet time"
        );
        require(
            pools[poolId_].isPublic ||
                pools[poolId_].visibilityAddresses[msg.sender],
            "pool is private"
        );
        require(
            pools[poolId_].betPlayers[msg.sender].optionId == 0,
            "already bet"
        );
        require(betOption_ != 0, "invalid betOption");
        uint256 poolSize = pools[poolId_].poolSize;
        uint256 betFee = pools[poolId_].betFee;
        require(msg.value >= poolSize + betFee, "not enough amount");

        if (betFee > 0) {
            address payable poolCreator = payable(pools[poolId_].poolCreator);
            poolCreator.transfer(betFee);
        }

        pools[poolId_].totalAmount = pools[poolId_].totalAmount.add(poolSize);

        uint32 nextTotalBetPlayers = pools[poolId_].totalBetPlayers + 1;
        pools[poolId_].countbetPlayers[nextTotalBetPlayers] = msg.sender;
        pools[poolId_].totalBetPlayers = nextTotalBetPlayers;

        pools[poolId_].betPlayers[msg.sender].optionId = betOption_;
        emit TResult(
            "1|makeBetOption",
            msg.sender,
            poolId_,
            _ACTIVED,
            betOption_,
            msg.value
        );
    }

    function cancelStaking(uint256 poolId_) public isActive(poolId_) {
        require(pools[poolId_].status == _ACTIVED, "pool is not actived");
        require(
            block.timestamp <= pools[poolId_].closeStakingTs,
            "invalid bet time"
        );
        require(
            pools[poolId_].betPlayers[msg.sender].optionId != 0,
            "not yet betting"
        );
        uint256 poolSize = pools[poolId_].poolSize;
        pools[poolId_].totalAmount = pools[poolId_]
            .totalAmount
            .sub(poolSize)
            .add(_cancelStakingFee);
        uint32 existingOpt = pools[poolId_].betPlayers[msg.sender].optionId;
        pools[poolId_].betPlayers[msg.sender].optionId = 0;

        address payable recipient = payable(msg.sender);
        recipient.transfer(poolSize.sub(_cancelStakingFee));
        pools[poolId_].totalCancelPlayers =
            pools[poolId_].totalCancelPlayers +
            1;
        _totalAmountforOwner = _totalAmountforOwner.add(_cancelStakingFee);
        pools[poolId_].amountForOwner = pools[poolId_].amountForOwner.add(
            _cancelStakingFee
        );
        emit TResult(
            "1|cancelStaking",
            msg.sender,
            poolId_,
            _ACTIVED,
            existingOpt,
            poolSize.sub(_cancelStakingFee)
        );
    }

    function updatePool(
        uint256 poolId_,
        uint32 winOptionID_,
        uint256 claimBetResultTs_
    ) public onlyOwner {
        require(
            pools[poolId_].status == _ACTIVED ||
                pools[poolId_].status == _RESULTED,
            "pool not actived/resulted."
        );
        require(
            claimBetResultTs_ >= block.timestamp.add(_minClaimBetResultTs),
            "claimBetResultTs_ < _minClaimBetResultTs"
        );
        pools[poolId_].finalWinOptionId = winOptionID_;
        pools[poolId_].claimBetResultTs = claimBetResultTs_;
        pools[poolId_].lastUpdateResultTs = block.timestamp;
        pools[poolId_].status = _RESULTED;
        emit TResult(
            "1|updatePool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            winOptionID_,
            pools[poolId_].poolSize
        );
    }

    function closePool(uint256 poolId_) public onlyOwner {
        require(
            pools[poolId_].status == _RESULTED, // need to be updated before closing
            "pool not resulted."
        );

        for (uint32 i; i <= pools[poolId_].totalBetPlayers; i++) {
            address betPlayerAddress = pools[poolId_].countbetPlayers[i];
            uint32 playerOptionID = pools[poolId_]
                .betPlayers[betPlayerAddress]
                .optionId;
            if (playerOptionID == pools[poolId_].finalWinOptionId) {
                totalWinPlayer = totalWinPlayer + 1;
                winPlayerAddress[totalWinPlayer] = betPlayerAddress;
            }
        }
        if (totalWinPlayer > 0) {
            // there will be winners
            uint256 totalBetAmount = uint256(
                pools[poolId_].totalBetPlayers -
                    pools[poolId_].totalCancelPlayers
            ).mul(pools[poolId_].poolSize);
            uint256 totalClaimAmount = totalBetAmount
                .mul(MAX_100_PERCENT - pools[poolId_].claimWonFeeRate)
                .div(MAX_100_PERCENT);
            uint256 claimAmount = totalClaimAmount.div(totalWinPlayer);
            for (uint32 i; i <= totalWinPlayer; i++) {
                pools[poolId_].claimAllowance[
                    winPlayerAddress[i]
                ] = claimAmount;
                delete winPlayerAddress[i]; // reset winPlayerAddress
            }
            totalWinPlayer = 0; // reset totalWinPlayer

            uint256 claimWonFee = totalBetAmount.sub(totalClaimAmount);
            _totalAmountforOwner = _totalAmountforOwner.add(claimWonFee);
            pools[poolId_].amountForOwner = pools[poolId_].amountForOwner.add(
                claimWonFee
            );
        } else {
            // tie: add allowance poolsize for all
            uint256 claimAmount = pools[poolId_].poolSize.sub(
                _claimNoOneWinFee
            );
            for (uint32 i; i <= pools[poolId_].totalBetPlayers; i++) {
                address betPlayerAddress = pools[poolId_].countbetPlayers[i];
                pools[poolId_].claimAllowance[betPlayerAddress] = claimAmount;
            }
            uint256 noOneWinFee = _claimNoOneWinFee.mul(
                uint256(pools[poolId_].totalBetPlayers)
            );
            _totalAmountforOwner = _totalAmountforOwner.add(noOneWinFee);
            pools[poolId_].amountForOwner = pools[poolId_].amountForOwner.add(
                noOneWinFee
            );
        }
        pools[poolId_].status = _CLOSED;

        emit TResult(
            "1|closePool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            pools[poolId_].finalWinOptionId,
            pools[poolId_].poolSize
        );
    }

    function claimFromPool(uint256 poolId_) public {
        require(
            pools[poolId_].status == _CLOSED, // only claim when pool closed
            "pool not closed"
        );
        require(
            block.timestamp >= pools[poolId_].claimBetResultTs, // only claim when after claimBetResultTs
            "invalid claim time"
        );
        require(
            pools[poolId_].betPlayers[msg.sender].status != TingBet._CLAIMED,
            "already claimed"
        );

        uint256 claimAmount = pools[poolId_].claimAllowance[msg.sender];
        require(
            claimAmount > 0, // only claim when pool claimAllowance is greater than zero
            "no claim amount"
        );

        address payable recipient = payable(msg.sender);
        recipient.transfer(claimAmount);

        pools[poolId_].totalAmount = pools[poolId_].totalAmount.sub(
            claimAmount
        );
        pools[poolId_].betPlayers[msg.sender].status = _CLAIMED;
        pools[poolId_].claimAllowance[msg.sender] = 0;
        emit TResult(
            "1|claimFromPool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            pools[poolId_].finalWinOptionId,
            claimAmount
        );
    }

    function voteToFreezePool(uint256 poolId_) public payable {
        require(
            msg.value >= _voteFreezePoolFee, // need to be updated before vote for freeze
            "not enough fee."
        );
        require(
            pools[poolId_].status == _RESULTED, // need to be updated before vote for freeze
            "pool not resulted"
        );
        require(
            pools[poolId_].betPlayers[msg.sender].optionId != 0, // voter has to bet before
            "not bet user"
        );
        pools[poolId_].totalClaimResultPlayers =
            pools[poolId_].totalClaimResultPlayers +
            1;
        pools[poolId_].betPlayers[msg.sender].status = _VOTED;
        _totalAmountforOwner = _totalAmountforOwner.add(_voteFreezePoolFee);
        emit TResult(
            "1|voteToFreezePool",
            msg.sender,
            poolId_,
            pools[poolId_].status,
            pools[poolId_].finalWinOptionId,
            pools[poolId_].matchId
        );
    }
}
