// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.12;

import "./interfaces/ICatPinFactory.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/ICatPinRouter.sol";
import "./libraries/CatPinLibrary.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";

contract CatPinRouter is ICatPinRouter {
    using SafeMath for uint256;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "CatPinRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn"t exist yet
        if (ICatPinFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ICatPinFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = CatPinLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = CatPinLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "CatPinRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = CatPinLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "CatPinRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = CatPinLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ICatPinPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = CatPinLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ICatPinPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB
        )
    {
        address pair = CatPinLibrary.pairFor(factory, tokenA, tokenB);
        ICatPinPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (address token0, ) = CatPinLibrary.sortTokens(tokenA, tokenB);
        if (tokenA == token0) {
            (amountA, amountB) = ICatPinPair(pair).burn(to);
        } else {
            (amountB, amountA) = ICatPinPair(pair).burn(to);
        }
        require(amountA >= amountAMin, "CatPinpRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "CatPinRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH
        )
    {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (
            uint256 amountA,
            uint256 amountB
        )
    {
        ICatPinPair(CatPinLibrary.pairFor(factory, tokenA, tokenB)).permit(
            msg.sender,
            address(this),
            approveMax ? uint256(-1) : liquidity,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (
            uint256 amountToken,
            uint256 amountETH
        )
    {
        address pair = CatPinLibrary.pairFor(factory, token, WETH);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        ICatPinPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountETH) {
        address pair = CatPinLibrary.pairFor(factory, token, WETH);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        ICatPinPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountETH) = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = CatPinLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? CatPinLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ICatPinPair(CatPinLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = CatPinLibrary.getAmountsOut(factory, amountIn, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        if (path.length == 2) {
            amounts[1] = ICatPinPair(pair).dealSlippageWithIn(path, amounts[0], to, ifmint);
        }
        require(amounts[amounts.length - 1] >= amountOutMin, "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = CatPinLibrary.getAmountsIn(factory, amountOut, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        if (path.length == 2) {
            uint256 extra = ICatPinPair(pair).dealSlippageWithOut(path, amountOut, to, ifmint);
            amounts[0] = amounts[0].add(extra);
        }
        require(amounts[0] <= amountInMax, "CatPinRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "CatPinRouter: INVALID_PATH");
        amounts = CatPinLibrary.getAmountsOut(factory, msg.value, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        if (path.length == 2) {
            amounts[1] = ICatPinPair(pair).dealSlippageWithIn(path, amounts[0], to, ifmint);
        }
        require(amounts[amounts.length - 1] >= amountOutMin, "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "CatPinRouter: INVALID_PATH");
        amounts = CatPinLibrary.getAmountsIn(factory, amountOut, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        if (path.length == 2) {
            uint256 extra = ICatPinPair(pair).dealSlippageWithOut(path, amountOut, to, ifmint);
            amounts[0] = amounts[0].add(extra);
        }
        require(amounts[0] <= amountInMax, "CatPinRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "CatPinRouter: INVALID_PATH");
        amounts = CatPinLibrary.getAmountsOut(factory, amountIn, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        if (path.length == 2) {
            amounts[1] = ICatPinPair(pair).dealSlippageWithIn(path, amounts[0], to, ifmint);
        }
        require(amounts[amounts.length - 1] >= amountOutMin, "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "CatPinRouter: INVALID_PATH");
        amounts = CatPinLibrary.getAmountsIn(factory, amountOut, path);
        address pair = CatPinLibrary.pairFor(factory, path[0], path[1]);
        if (path.length == 2) {
            uint256 extra = ICatPinPair(pair).dealSlippageWithOut(path, amountOut, to, ifmint);
            amounts[0] = amounts[0].add(extra);
        }
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to,
        bool ifmint
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address token0, ) = CatPinLibrary.sortTokens(path[i], path[i + 1]);
            ICatPinPair pair = ICatPinPair(CatPinLibrary.pairFor(factory, path[i], path[i + 1]));
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = path[i] == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                uint256 amountInput = IERC20(path[i]).balanceOf(address(pair)).sub(reserveInput);
                if (path.length == 2) {
                    amountOutput = pair.dealSlippageWithIn(path, amountInput, _to, ifmint);
                } else {
                    amountOutput = CatPinLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
                }
            }
            (uint256 amount0Out, uint256 amount1Out) = path[i] == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? CatPinLibrary.pairFor(factory, path[i + 1], path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            CatPinLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, ifmint);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override payable ensure(deadline) {
        require(path[0] == WETH, "CatPinRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(CatPinLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, ifmint);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool ifmint
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, "CatPinRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            CatPinLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), ifmint);
        uint256 amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, "CatPinRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public virtual override pure returns (uint256 amountB) {
        return CatPinLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public virtual override pure returns (uint256 amountOut) {
        return CatPinLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public virtual override pure returns (uint256 amountIn) {
        return CatPinLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        virtual
        override
        view
        returns (uint256[] memory amounts)
    {
        return CatPinLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        virtual
        override
        view
        returns (uint256[] memory amounts)
    {
        return CatPinLibrary.getAmountsIn(factory, amountOut, path);
    }
}
