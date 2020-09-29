pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract CatoBar is ERC20("CatoBar", "xCATO"){
    using SafeMath for uint256;
    IERC20 public cato;

    constructor(IERC20 _cato) public {
        require(address(_cato) != address(0), "invalid address");
        cato = _cato;
    }

    // Enter the bar. Pay some CATOs. Earn some shares.
    function enter(uint256 _amount) public {
        uint256 totalCato = cato.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalCato == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalCato);
            _mint(msg.sender, what);
        }
        cato.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your CATOs.
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(cato.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        cato.transfer(msg.sender, what);
    }
}
