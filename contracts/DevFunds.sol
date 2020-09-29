pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CatnipToken.sol";

contract DevFunds {
    using SafeMath for uint;

    // the catnip token
    CatnipToken public catnip;
    // dev address to receive catnip
    address public devaddr;
    // last withdraw block, use catnipswap online block as default
    uint public lastWithdrawBlock = 10821000;
    // withdraw interval ~ 2 weeks
    uint public constant WITHDRAW_INTERVAL = 89600;
    // current total amount bigger than the threshold, withdraw half, otherwise withdraw all
    uint public constant WITHDRAW_HALF_THRESHOLD = 89600*10**18;

    constructor(CatnipToken _catnip, address _devaddr) public {
        require(address(_catnip) != address(0) && _devaddr != address(0), "invalid address");
        catnip = _catnip;
        devaddr = _devaddr;
    }

    function withdraw() public {
        uint unlockBlock = lastWithdrawBlock.add(WITHDRAW_INTERVAL);
        require(block.number >= unlockBlock, "catnip locked");
        uint _amount = catnip.balanceOf(address(this));
        require(_amount > 0, "zero catnip amount");
        uint amountReal = _amount;
        if (_amount > WITHDRAW_HALF_THRESHOLD) amountReal = _amount.div(2);
        lastWithdrawBlock = block.number;
        catnip.transfer(devaddr, amountReal);
    }
}