pragma solidity 0.6.12;

import "./catpin/interfaces/ICatPinPair.sol";
import "./catpin/interfaces/ICatPinFactory.sol";


contract Migrator {
    address public chef;
    address public oldFactory;
    ICatPinFactory public factory;
    uint256 public notBeforeBlock;
    uint256 public desiredLiquidity = uint256(-1);

    constructor(
        address _chef,
        address _oldFactory,
        ICatPinFactory _factory,
        uint256 _notBeforeBlock
    ) public {
        require(_chef != address(0) && _oldFactory != address(0) && address(_factory) != address(0), "invalid address");
        chef = _chef;
        oldFactory = _oldFactory;
        factory = _factory;
        notBeforeBlock = _notBeforeBlock;
    }

    function migrate(ICatPinPair orig) public returns (ICatPinPair) {
        require(msg.sender == chef, "not from master chef");
        require(block.number >= notBeforeBlock, "too early to migrate");
        require(orig.factory() == oldFactory, "not from old factory");
        address token0 = orig.token0();
        address token1 = orig.token1();
        ICatPinPair pair = ICatPinPair(factory.getPair(token0, token1));
        if (pair == ICatPinPair(address(0))) {
            pair = ICatPinPair(factory.createPair(token0, token1));
        }
        uint256 lp = orig.balanceOf(msg.sender);
        if (lp == 0) return pair;
        desiredLiquidity = lp;
        orig.transferFrom(msg.sender, address(orig), lp);
        orig.burn(address(pair));
        pair.mint(msg.sender);
        desiredLiquidity = uint256(-1);
        return pair;
    }
}
