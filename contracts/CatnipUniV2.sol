pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IMigratorChef.sol";
import "./CatnipMaster.sol";
import "./interfaces/IStakingRewards.sol";

contract CatnipUniV2 is Ownable, ERC20("Wrapped UniSwap Liquidity Token", "WULP") {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 catnipRewardDebt; // Catnip reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CATNIPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCatnipPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCatnipPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
        uint256 uniRewardDebt; // similar with catnipRewardDebt
        uint256 firstDepositTime;
    }

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    IStakingRewards public uniStaking;
    uint256 public lastRewardBlock; // Last block number that CATNIPs distribution occurs.
    uint256 public accCatnipPerShare; // Accumulated CATNIPs per share, times 1e12. See below.
    uint256 public accUniPerShare; // Accumulated UNIs per share, times 1e12. See below.

    // The UNI Token.
    IERC20 public uniToken;
    // The CATNIP TOKEN!
    CatnipToken public catnip;
    CatnipMaster public catnipMaster;
    IERC20 public lpToken; // Address of LP token contract.

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;
    // The address to receive UNI token fee.
    address public uniTokenFeeReceiver;
    // The ratio of UNI token fee (10%).
    uint8 public uniFeeRatio = 10;
    uint8 public isMigrateComplete = 0;

    //Liquidity Event
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        CatnipMaster _catnipMaster,
        address _uniLpToken,
        address _uniStaking,
        address _uniToken,
        CatnipToken _catnip,
        address _uniTokenFeeReceiver
    ) public {
        catnipMaster = _catnipMaster;
        uniStaking = IStakingRewards(_uniStaking);
        uniToken = IERC20(_uniToken);
        catnip = _catnip;
        uniTokenFeeReceiver = _uniTokenFeeReceiver;
        lpToken = IERC20(_uniLpToken);
    }

    ////////////////////////////////////////////////////////////////////
    //Migrate liquidity to catnipswap
    ///////////////////////////////////////////////////////////////////
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    function migrate() public onlyOwner {
        require(address(migrator) != address(0), "migrate: no migrator");
        updatePool();
        //get all lp and uni reward from uniStaking
        uniStaking.withdraw(totalSupply());
        //get all wrapped lp and catnip reward from catnipMaster
        uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
        catnipMaster.withdraw(poolIdInCatnipMaster, totalSupply());
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        lpToken = newLpToken;
        isMigrateComplete = 1;
    }

    // View function to see pending CATNIPs and UNIs on frontend.
    function pending(address _user) external view returns (uint256 _catnip, uint256 _uni) {
        UserInfo storage user = userInfo[_user];
        uint256 tempAccCatnipPerShare = accCatnipPerShare;
        uint256 tempAccUniPerShare = accUniPerShare;
    
        if (isMigrateComplete == 0 && block.number > lastRewardBlock && totalSupply() != 0) {
            uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
            uint256 catnipReward = catnipMaster.pendingCatnip(poolIdInCatnipMaster, address(this));
            tempAccCatnipPerShare = tempAccCatnipPerShare.add(catnipReward.mul(1e12).div(totalSupply()));
            uint256 uniReward = uniStaking.earned(address(this));
            tempAccUniPerShare = tempAccUniPerShare.add(uniReward.mul(1e12).div(totalSupply()));
        }
        _catnip = user.amount.mul(tempAccCatnipPerShare).div(1e12).sub(user.catnipRewardDebt);
        _uni = user.amount.mul(tempAccUniPerShare).div(1e12).sub(user.uniRewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        if (block.number <= lastRewardBlock || isMigrateComplete == 1) {
            return;
        }

        if (totalSupply() == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 catnipBalance = catnip.balanceOf(address(this));
        uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
        // Get Catnip Reward from CatnipMaster
        catnipMaster.deposit(poolIdInCatnipMaster, 0);
        uint256 catnipReward = catnip.balanceOf(address(this)).sub(catnipBalance);
        accCatnipPerShare = accCatnipPerShare.add(catnipReward.mul(1e12).div((totalSupply())));
        uint256 uniReward = uniStaking.earned(address(this));
        uniStaking.getReward();
        accUniPerShare = accUniPerShare.add(uniReward.mul(1e12).div(totalSupply()));
        lastRewardBlock = block.number;
    }

    function _mintWulp(address _addr, uint256 _amount) internal {
        lpToken.safeTransferFrom(_addr, address(this), _amount);
        _mint(address(this), _amount);
    }

    function _burnWulp(address _to, uint256 _amount) internal {
        lpToken.safeTransfer(address(_to), _amount);
        _burn(address(this), _amount);
    }

    // Deposit LP tokens to CatnipMaster for CATNIP allocation.
    function deposit(uint256 _amount) public {
        require(isMigrateComplete == 0 || (isMigrateComplete == 1 && _amount == 0), "already migrate");
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (_amount > 0 && user.firstDepositTime == 0) user.firstDepositTime = block.number;
        uint256 pendingCatnip = user.amount.mul(accCatnipPerShare).div(1e12).sub(user.catnipRewardDebt);
        uint256 pendingUni = user.amount.mul(accUniPerShare).div(1e12).sub(user.uniRewardDebt);
        user.amount = user.amount.add(_amount);
        user.catnipRewardDebt = user.amount.mul(accCatnipPerShare).div(1e12);
        user.uniRewardDebt = user.amount.mul(accUniPerShare).div(1e12);
        if (pendingCatnip > 0) _safeCatnipTransfer(msg.sender, pendingCatnip);
        if (pendingUni > 0) {
            uint256 uniFee = pendingUni.mul(uniFeeRatio).div(100);
            uint256 uniToUser = pendingUni.sub(uniFee);
            _safeUniTransfer(uniTokenFeeReceiver, uniFee);
            _safeUniTransfer(msg.sender, uniToUser);
        }
        if (_amount > 0) {
            //generate wrapped uniswap lp token
            _mintWulp(msg.sender, _amount);

            //approve and stake to uniswap
            lpToken.approve(address(uniStaking), _amount);
            uniStaking.stake(_amount);

            //approve and stake to catnipmaster
            _approve(address(this), address(catnipMaster), _amount);
            uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
            catnipMaster.deposit(poolIdInCatnipMaster, _amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from CatnipUni.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 pendingCatnip = user.amount.mul(accCatnipPerShare).div(1e12).sub(user.catnipRewardDebt);
        uint256 pendingUni = user.amount.mul(accUniPerShare).div(1e12).sub(user.uniRewardDebt);
        user.amount = user.amount.sub(_amount);
        user.catnipRewardDebt = user.amount.mul(accCatnipPerShare).div(1e12);
        user.uniRewardDebt = user.amount.mul(accUniPerShare).div(1e12);
        if (pendingCatnip > 0) _safeCatnipTransfer(msg.sender, pendingCatnip);
        if (pendingUni > 0) {
            uint256 uniFee = pendingUni.mul(uniFeeRatio).div(100);
            uint256 uniToUser = pendingUni.sub(uniFee);
            _safeUniTransfer(uniTokenFeeReceiver, uniFee);
            _safeUniTransfer(msg.sender, uniToUser);
        }
        if (_amount > 0) {
            if (isMigrateComplete == 0) {
                uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
                //unstake wrapped lp token from catnip master
                catnipMaster.withdraw(poolIdInCatnipMaster, _amount);
                //unstake uniswap lp token from uniswap
                uniStaking.withdraw(_amount);
            }

            _burnWulp(address(msg.sender), _amount);
        }

        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "emergencyWithdraw: not good");
        uint256 _amount = user.amount;
        user.amount = 0;
        user.catnipRewardDebt = 0;
        user.uniRewardDebt = 0;
        {
            if (isMigrateComplete == 0) {
                uint256 poolIdInCatnipMaster = catnipMaster.lpTokenPID(address(this)).sub(1);
                //unstake wrapped lp token from catnip master
                catnipMaster.withdraw(poolIdInCatnipMaster, _amount);
                //unstake lp token from uniswap
                uniStaking.withdraw(_amount);
            }

            _burnWulp(address(msg.sender), _amount);
        }
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    // Safe catnip transfer function, just in case if rounding error causes pool to not have enough CATNIPs.
    function _safeCatnipTransfer(address _to, uint256 _amount) internal {
        uint256 catnipBal = catnip.balanceOf(address(this));
        if (_amount > catnipBal) {
            catnip.transfer(_to, catnipBal);
        } else {
            catnip.transfer(_to, _amount);
        }
    }

    // Safe uni transfer function
    function _safeUniTransfer(address _to, uint256 _amount) internal {
        uint256 uniBal = uniToken.balanceOf(address(this));
        if (_amount > uniBal) {
            uniToken.transfer(_to, uniBal);
        } else {
            uniToken.transfer(_to, _amount);
        }
    }

    function setUniTokenFeeReceiver(address _uniTokenFeeReceiver) public onlyOwner {
        uniTokenFeeReceiver = _uniTokenFeeReceiver;
    }
}
