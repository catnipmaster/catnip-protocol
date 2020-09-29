pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CatnipToken.sol";
import "./CatnipMaster.sol";

contract CatnipLock is ERC20("CatnipLockToken", "CatnipLock"), Ownable {
    using SafeMath for uint256;
    using Address for address;

    CatnipToken public catnip;
    CatnipMaster public catnipMaster;
    address public withDrawAddr;

    constructor(CatnipToken _catnip, CatnipMaster _catnipMaster) public {
        require(address(_catnip) != address(0) && address(_catnipMaster) != address(0), "invalid address");
        catnip = _catnip;
        catnipMaster = _catnipMaster;
        _mint(address(this), 1);
    }

    function deposit(uint256 _pid) public onlyOwner {
        _approve(address(this), address(catnipMaster), 1);
        catnipMaster.deposit(_pid, 1);
    }

    function withdrawFromCatnipMaster(uint256 _pid) public {
        catnipMaster.deposit(_pid, 0);
    }

    function withdrawToContract(uint256 _amount) public onlyOwner {
        require(withDrawAddr != address(0), "invalid address");
        uint256 totalAmount = catnip.balanceOf(address(this));
        require(_amount > 0 && _amount <= totalAmount, "invalid amount");
        catnip.transfer(withDrawAddr, _amount);
    }

    function setwithdrawContractAddr(address _withDrawaddr) public onlyOwner {
        withDrawAddr = _withDrawaddr;
    }
}
