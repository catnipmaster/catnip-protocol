pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./catnip/interfaces/ICatnipERC20.sol";
import "./catnip/interfaces/ICatnipPair.sol";
import "./catnip/interfaces/ICatnipFactory.sol";

contract CatnipDrinker {
    using SafeMath for uint;

    ICatnipFactory public factory;
    address public catnip;
    address public uni;
    address public owner;

    constructor(ICatnipFactory _factory, address _catnip, address _uni) public {
        require(address(_factory) != address(0) && _catnip != address(0) && 
            _uni != address(0), "invalid address");
        factory = _factory;
        catnip = _catnip;
        uni = _uni;
        owner = msg.sender;
    }

    function convert() public {
        // At least we try to make front-running harder to do.
        require(msg.sender == tx.origin, "do not convert from contract");
        ICatnipPair pair = ICatnipPair(factory.getPair(catnip, uni));
        uint uniBalance = IERC20(uni).balanceOf(address(this));
        IERC20(uni).transfer(address(pair), uniBalance);
        _toCATNIP(uniBalance, address(1));
    }

    function _toCATNIP(uint amountIn, address to) internal {
        ICatnipPair pair = ICatnipPair(factory.getPair(catnip, uni));
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

    function setFactory(ICatnipFactory _factory) public {
        require(msg.sender == owner, "only owner");
        factory = _factory;
    }
}
