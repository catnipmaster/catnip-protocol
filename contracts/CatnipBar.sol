pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract CatnipBar is ERC20("CatnipBar", "xCATNIP"){
    using SafeMath for uint256;
    IERC20 public catnip;

    constructor(IERC20 _catnip) public {
        require(address(_catnip) != address(0), "invalid address");
        catnip = _catnip;
    }

    // Enter the bar. Pay some CATNIPs. Earn some shares.
    function enter(uint256 _amount) public {
        uint256 totalCatnip = catnip.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalCatnip == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalCatnip);
            _mint(msg.sender, what);
        }
        catnip.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your CATNIPs.
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(catnip.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        catnip.transfer(msg.sender, what);
    }
}
