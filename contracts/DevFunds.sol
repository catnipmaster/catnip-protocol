pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CatoToken.sol";

contract DevFunds {
    using SafeMath for uint;

    // the cato token
    CatoToken public cato;
    // dev address to receive cato
    address public devaddr;
    // last withdraw block, use catoswap online block as default
    uint public lastWithdrawBlock = 10821000;
    // withdraw interval ~ 2 weeks
    uint public constant WITHDRAW_INTERVAL = 89600;
    // current total amount bigger than the threshold, withdraw half, otherwise withdraw all
    uint public constant WITHDRAW_HALF_THRESHOLD = 89600*10**18;

    constructor(CatoToken _cato, address _devaddr) public {
        require(address(_cato) != address(0) && _devaddr != address(0), "invalid address");
        cato = _cato;
        devaddr = _devaddr;
    }

    function withdraw() public {
        uint unlockBlock = lastWithdrawBlock.add(WITHDRAW_INTERVAL);
        require(block.number >= unlockBlock, "cato locked");
        uint _amount = cato.balanceOf(address(this));
        require(_amount > 0, "zero cato amount");
        uint amountReal = _amount;
        if (_amount > WITHDRAW_HALF_THRESHOLD) amountReal = _amount.div(2);
        lastWithdrawBlock = block.number;
        cato.transfer(devaddr, amountReal);
    }
}