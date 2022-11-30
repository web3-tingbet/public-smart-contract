contract TingBetDef {

    struct UserAction {
        uint32 optionId;
        uint8 status; // 1-claimed, 2-vote to freeze
    }

    struct PoolInfo {
        uint32 matchId;
        uint32 betTypeId;
        address poolCreator; 
        uint8 status; // 0-notRegisteredOrOpened, 1-Registerd, 2-Active, 3-updated, 4-closed, 5-expired, 6-canceled
        // 1-openedStake, 2-closedStake, 3-setBetResult, 4-freezedPool, 5-closedPool, 6-cancelledPools, 7-rejectNoOneWin

        uint256 poolSize; 
        uint256 totalAmount; 
        uint16 claimWonFeeRate; //0.01% - 99.99% // don't allow to change, if we need to change, create other pool. 5%
        uint256 betFee; 
        bool isPublic; // 1 - public, > 0 - private
        mapping(address => bool) visibilityAddresses; // count addressess
        uint32 totalBetPlayers;
        uint32 totalCancelPlayers;
        mapping(uint32 => address) countbetPlayers;
        mapping(address => UserAction) betPlayers;
        mapping(address => uint256) claimAllowance;
        uint32 totalClaimResultPlayers;
        uint256 closeStakingTs; // don't allow to change, if we need to change, create other pool.
        uint32 finalWinOptionId;
        uint256 lastUpdateResultTs;
        uint256 claimBetResultTs; //after this time, can claim
        uint256 amountForOwner;
    }
}
