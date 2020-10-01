// SPDX-License-Identifier: MIT
pragma solidity ^0.4.24;

import "./Pools.sol";

contract PoolsData is Pools {
    enum PoolStatus {Created, Open, OutOfstock, Finished, Close} //the status of the pools

    function GetMyPoolsId() public view returns (uint256[]) {
        return poolsMap[msg.sender];
    }
    //@dev no use of revert to make sure the loop will work
    function WithdrawLeftOvers(uint256 _PoolId) public returns (bool) {
        //pool is finished + got left overs + did not took them
        if (
            pools[_PoolId].FinishTime <= now &&
            pools[_PoolId].Lefttokens > 0 &&
            !pools[_PoolId].TookLeftOvers
        ) {
            pools[_PoolId].TookLeftOvers = true;
            TransferToken(
                pools[_PoolId].Token,
                pools[_PoolId].Creator,
                pools[_PoolId].Lefttokens
            );
            return true;
        }
        return false;
    }
    //give the data of the pool, by id
    function GetPoolData(uint256 _id)
        public
        view
        returns (
            PoolStatus,
            address,
            uint256,
            uint256,
            address,
            uint256,
            uint256
        )
    {
        require(_id <= poolsCount, "Wrong Id");
        return (
            //check if sender POZ Invester?
            GetPoolStatus(_id),
            pools[_id].Token,
            pools[_id].Rate,
            pools[_id].POZRate,
            pools[_id].Maincoin, //incase of ETH will be address.zero
            pools[_id].StartAmount,
            pools[_id].Lefttokens
        );
    }

    function GetMorePoolData(uint256 _id)
        public
        view
        returns (
            bool,
            uint256,
            uint256,
            address
        )
    {
        return (
            pools[_id].IsLocked,
            pools[_id].FinishTime,
            pools[_id].OpenForAll,
            pools[_id].Creator
        );
    }

    //calculate the status of a pool 
    function GetPoolStatus(uint256 _id) public view returns (PoolStatus) {
        require(_id <= poolsCount, "Wrong pool id");
        //Don't like the logic here - ToDo Boolean checks (truth table)
        if (now < pools[_id].OpenForAll && pools[_id].Lefttokens > 0) {
            //got tokens + only poz investors
            return PoolStatus.Created;
        }
        if (
            now >= pools[_id].OpenForAll &&
            pools[_id].Lefttokens > 0 &&
            now < pools[_id].FinishTime
        ) {
            //got tokens + all investors
            return PoolStatus.Open;
        }
        if (
            pools[_id].Lefttokens == 0 &&
            pools[_id].IsLocked &&
            now < pools[_id].FinishTime
        ) //no tokens on locked pool, got time
        {
            return PoolStatus.OutOfstock;
        }
        if (
            pools[_id].Lefttokens == 0 && !pools[_id].IsLocked
        ) //no tokens on direct pool
        {
            return PoolStatus.Close;
        }
        if (
            pools[_id].Lefttokens > 0 &&
            !pools[_id].IsLocked &&
            !pools[_id].TookLeftOvers
        ) {
            //Got left overs on direct pool
            return PoolStatus.Finished;
        }
        if (now >= pools[_id].FinishTime && !pools[_id].IsLocked) {
            // After finish time - not locked
            if (pools[_id].TookLeftOvers) return PoolStatus.Close;
            return PoolStatus.Finished;
        }
        if (now >= pools[_id].FinishTime && pools[_id].IsLocked) {
            // After finish time -  locked
            if (
                (pools[_id].TookLeftOvers || pools[_id].Lefttokens == 0) &&
                pools[_id].StartAmount - pools[_id].Lefttokens ==
                pools[_id].UnlockedTokens
            ) return PoolStatus.Close;
            return PoolStatus.Finished;
        }
    }
}
