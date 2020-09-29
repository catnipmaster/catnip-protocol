pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CatoToken.sol";
import "./CatoMaster.sol";

contract CatoLock is ERC20("CatoLockToken", "CatoLock"), Ownable {
    using SafeMath for uint256;
    using Address for address;

    CatoToken public cato;
    CatoMaster public catoMaster;
    address public withDrawAddr;

    constructor(CatoToken _cato, CatoMaster _catoMaster) public {
        require(address(_cato) != address(0) && address(_catoMaster) != address(0), "invalid address");
        cato = _cato;
        catoMaster = _catoMaster;
        _mint(address(this), 1);
    }

    function deposit(uint256 _pid) public onlyOwner {
        _approve(address(this), address(catoMaster), 1);
        catoMaster.deposit(_pid, 1);
    }

    function withdrawFromCatoMaster(uint256 _pid) public {
        catoMaster.deposit(_pid, 0);
    }

    function withdrawToContract(uint256 _amount) public onlyOwner {
        require(withDrawAddr != address(0), "invalid address");
        uint256 totalAmount = cato.balanceOf(address(this));
        require(_amount > 0 && _amount <= totalAmount, "invalid amount");
        cato.transfer(withDrawAddr, _amount);
    }

    function setwithdrawContractAddr(address _withDrawaddr) public onlyOwner {
        withDrawAddr = _withDrawaddr;
    }
}
