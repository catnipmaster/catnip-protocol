pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./catpin/interfaces/ICatPinERC20.sol";
import "./catpin/interfaces/ICatPinPair.sol";
import "./catpin/interfaces/ICatPinFactory.sol";

contract CatoDrinker {
    using SafeMath for uint;

    ICatPinFactory public factory;
    address public cato;
    address public uni;
    address public owner;

    constructor(ICatPinFactory _factory, address _cato, address _uni) public {
        require(address(_factory) != address(0) && _cato != address(0) && 
            _uni != address(0), "invalid address");
        factory = _factory;
        cato = _cato;
        uni = _uni;
        owner = msg.sender;
    }

    function convert() public {
        // At least we try to make front-running harder to do.
        require(msg.sender == tx.origin, "do not convert from contract");
        ICatPinPair pair = ICatPinPair(factory.getPair(cato, uni));
        uint uniBalance = IERC20(uni).balanceOf(address(this));
        IERC20(uni).transfer(address(pair), uniBalance);
        _toCATO(uniBalance, address(1));
    }

    function _toCATO(uint amountIn, address to) internal {
        ICatPinPair pair = ICatPinPair(factory.getPair(cato, uni));
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == uni ? (reserve0, reserve1) : (reserve1, reserve0);
        // avoid stack too deep error
        uint amountOut;
        {
            uint amountInWithFee = amountIn.mul(997);
            uint numerator = amountInWithFee.mul(reserveOut);
            uint denominator = reserveIn.mul(1000).add(amountInWithFee);
            amountOut = numerator / denominator;
        }
        (uint amount0Out, uint amount1Out) = token0 == uni ? (uint(0), amountOut) : (amountOut, uint(0));
        pair.swap(amount0Out, amount1Out, to, new bytes(0));
    }

    function setFactory(ICatPinFactory _factory) public {
        require(msg.sender == owner, "only owner");
        factory = _factory;
    }
}
