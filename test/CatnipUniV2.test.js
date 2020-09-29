const { expectRevert, time, BN } = require('@openzeppelin/test-helpers');
const { MAX_UINT256 } = require('@openzeppelin/test-helpers/src/constants');
const CatnipToken = artifacts.require('CatnipToken');
const CatnipUniV2 = artifacts.require('CatnipUniV2');
const CatnipMaster = artifacts.require('CatnipMaster');
const StakingRewards = artifacts.require('StakingRewards');
const MockERC20 = artifacts.require('MockERC20');
const Migrator = artifacts.require('Migrator');
const CatnipFactory = artifacts.require('CatnipFactory');
const { AddressZero } = require("ethers/constants");
const CatnipPair = artifacts.require('CatnipPair');
const WETH9 = artifacts.require("WETH9");
const CatnipRouter = artifacts.require("CatnipRouter");
const { keccak256 } = require("ethers/utils");

function toBig(num) {
    return new BN(num)
}

function expandTo18Decimals(num) {
    return new BN(num).mul(toBig(10).pow(toBig(18)))
}

const LP_TOKEN_AMOUNT = expandTo18Decimals(10000);
const CATNIP_PRE_BLOCK = expandTo18Decimals(3);

contract('CatnipUniV2', ([alice, bob, carol, fee, minter]) => {
    beforeEach(async () => {
        this.tokenA = await MockERC20.new("tokenA", "tokenA", expandTo18Decimals(100000000), { from: alice });
        this.tokenB = await MockERC20.new("tokenA", "tokenA", expandTo18Decimals(100000000), { from: alice });
        // deploy factory
        this.CatnipFactory = await CatnipFactory.new(alice, { from: alice });
        // create pair
        await this.CatnipFactory.createPair(this.tokenA.address, this.tokenB.address, { from: alice })
        var pairAddress = await this.CatnipFactory.getPair(this.tokenA.address, this.tokenB.address);
        this.pair = await CatnipPair.at(pairAddress);
        WETH = await WETH9.new({ from: alice });
        // deploy router
        this.router = await CatnipRouter.new(this.CatnipFactory.address, WETH.address, { from: alice });
        await this.tokenA.approve(this.router.address, expandTo18Decimals(100000000), { from: alice });
        await this.tokenB.approve(this.router.address, expandTo18Decimals(100000000), { from: alice });
        let generateHash = keccak256(CatnipPair.bytecode).slice(2);
        config.logger.log(`find init code hash: ${generateHash}`);

        await this.router.addLiquidity(
            this.tokenA.address,
            this.tokenB.address,
            expandTo18Decimals(100000000),
            expandTo18Decimals(100000000),
            0,
            0,
            alice,
            MAX_UINT256,
            { from: alice });
            

        this.catnip = await CatnipToken.new({ from: alice });
        this.uniToken = await MockERC20.new("UniSwap", "UNI", "1000000000000000000000000000", { from: alice });
        this.catnipMaster = await CatnipMaster.new(this.catnip.address, alice, CATNIP_PRE_BLOCK, 0, { from: alice });

        //this.uniLpToken = await MockERC20.new("UniSwap LP Token", "LPT", LP_TOKEN_AMOUNT.mul(web3.utils.toBN(2)), { from: alice });
        this.uniLpToken = this.pair;
        this.uniStake = await StakingRewards.new(alice, this.uniToken.address, this.uniLpToken.address, { from: alice });
        this.catnipUniV2 = await CatnipUniV2.new(
            this.catnipMaster.address,
            this.uniLpToken.address,
            this.uniStake.address,
            this.uniToken.address,
            this.catnip.address,
            fee,
            { from: alice }
        );
        await this.catnip.transferOwnership(this.catnipMaster.address, { from: alice });

        assert.equal((await this.catnipUniV2.totalSupply()).valueOf(), 0);
        assert.equal((await this.catnipUniV2.lpToken()).valueOf(), this.uniLpToken.address);
        assert.equal((await this.catnipUniV2.uniStaking()).valueOf(), this.uniStake.address);
        assert.equal((await this.catnipUniV2.lastRewardBlock()).valueOf(), 0);
        assert.equal((await this.catnipUniV2.accCatnipPerShare()).valueOf(), 0);
        assert.equal((await this.catnipUniV2.accUniPerShare()).valueOf(), 0);
        assert.equal((await this.catnipUniV2.uniToken()).valueOf(), this.uniToken.address);
        assert.equal((await this.catnipUniV2.catnip()).valueOf(), this.catnip.address);
        assert.equal((await this.catnipUniV2.catnipMaster()).valueOf(), this.catnipMaster.address);
        assert.equal((await this.catnipUniV2.migrator()).valueOf(), AddressZero);
        assert.equal((await this.catnipUniV2.uniTokenFeeReceiver()).valueOf(), fee);
        assert.equal((await this.catnipUniV2.uniFeeRatio()).valueOf(), 10);
        assert.equal((await this.catnipUniV2.isMigrateComplete()).valueOf(), 0);

        //CatnipMaster add Pool
        await this.catnipMaster.add(100, this.catnipUniV2.address, true, { from: alice });

        await this.uniToken.transfer(this.uniStake.address, '5000000000000000000000000');
        await this.uniStake.notifyRewardAmount('5000000000000000000000000');
    });

    it('should allow emergency withdraw', async () => {
        //mint uniswap lp token to bob
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await this.catnipUniV2.emergencyWithdraw({ from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
    });


    it('should deposit and withdraw correct', async () => {
        //mint uniswap lp token to bob
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await this.uniLpToken.transfer(carol, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.add(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());

        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.uniLpToken.balanceOf(carol)).toString(), (LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).toString(), "0");
        assert.equal((await this.uniLpToken.balanceOf(this.catnipUniV2.address)).toString(), "0");
        assert.equal((await this.catnipUniV2.totalSupply()).toString(), "0");
    });

 

    it('should pending works right', async () => {
        //mint uniswap lp token to bob
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await this.uniLpToken.transfer(carol, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.add(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());

        const minWithdrawInterval = web3.utils.toBN(100);
        const withoutFeeBlock = (await time.latestBlock()).add(minWithdrawInterval);
        await time.advanceBlockTo(withoutFeeBlock);
        await time.increase('10');

        const bob_reward = await this.catnipUniV2.pending(bob);
        assert.equal(bob_reward[0].gt(CATNIP_PRE_BLOCK.mul(minWithdrawInterval).mul(LP_TOKEN_AMOUNT).div((await this.catnipUniV2.totalSupply()))), true);
        const carol_reward = await this.catnipUniV2.pending(carol);
        assert.equal(carol_reward[0].gt(CATNIP_PRE_BLOCK.mul(minWithdrawInterval).mul(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).div((await this.catnipUniV2.totalSupply()))), true)

        assert.equal(bob_reward[1].div(carol_reward[1]).toString(), "2");
    });

    it('should both withdraw catnip and uni rewards', async () => {
        //mint uniswap lp token to bob
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        const minWithdrawInterval = web3.utils.toBN(100);
        const withoutFeeBlock = (await time.latestBlock()).add(minWithdrawInterval);
        await time.advanceBlockTo(withoutFeeBlock);
        await time.increase('10');
        await this.catnipUniV2.deposit(0, { from: bob });
        const uniRewardRate = await this.uniStake.rewardRate();
        console.log(uniRewardRate.toString());
        assert.equal((await this.catnip.balanceOf(bob)).toString(), CATNIP_PRE_BLOCK.mul(web3.utils.toBN(2)).add(
            CATNIP_PRE_BLOCK.mul(minWithdrawInterval)
                .mul(LP_TOKEN_AMOUNT)
                .div((await this.catnipUniV2.totalSupply()))).toString());
        assert.equal((await this.uniToken.balanceOf(bob)).gt(web3.utils.toBN(0)), true);
    });

    it('should migrate works well', async () => {
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await this.uniLpToken.transfer(carol, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.add(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());


        const minWithdrawInterval = web3.utils.toBN(100);
        const withoutFeeBlock = (await time.latestBlock()).add(minWithdrawInterval);
        await time.advanceBlockTo(withoutFeeBlock);
        await time.increase('10');

        //deploy new factory
        NewCatnipFactory = await CatnipFactory.new(alice, { from: alice });

        assert.equal((await this.catnipUniV2.migrator()).valueOf(), AddressZero);
        migrator = await Migrator.new(this.catnipUniV2.address, this.CatnipFactory.address, NewCatnipFactory.address, 0);
        await this.catnipUniV2.setMigrator(migrator.address);
        await NewCatnipFactory.setMigrator(migrator.address, { from: alice });

        const oldBalance = (await this.pair.balanceOf(this.uniStake.address));
        console.log("oldBalance: " + oldBalance.toString());
        //create new pair in new factory
        await NewCatnipFactory.createPair(this.tokenA.address, this.tokenB.address, { from: alice })
        var pairAddress = await NewCatnipFactory.getPair(this.tokenA.address, this.tokenB.address);
        var newPair = await CatnipPair.at(pairAddress);

        await this.catnipUniV2.migrate();
        assert.equal((await this.pair.balanceOf(this.catnipUniV2.address)).toString(), "0");
        assert.equal((await newPair.balanceOf(this.catnipUniV2.address)).toString(), oldBalance);

        //can not deposit after migrate
        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.catnip.balanceOf(bob)).gt(web3.utils.toBN(0)), true);
        assert.equal((await this.uniToken.balanceOf(bob)).gt(web3.utils.toBN(0)), true);

        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.catnip.balanceOf(carol)).gt(web3.utils.toBN(0)), true);
        assert.equal((await this.uniToken.balanceOf(carol)).gt(web3.utils.toBN(0)), true);

        assert.equal((await newPair.balanceOf(bob)).toString(), LP_TOKEN_AMOUNT.toString());
        assert.equal((await newPair.balanceOf(carol)).toString(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
    });

    it('should two pools works well', async () => {
        // deposit pool0
        await this.uniLpToken.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT, { from: bob });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.uniLpToken.balanceOf(bob)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await this.uniLpToken.transfer(carol, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: alice });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
        //deposit to catnipUni2
        await this.uniLpToken.approve(this.catnipUniV2.address, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        await this.catnipUniV2.deposit(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.uniLpToken.balanceOf(carol)).valueOf(), 0);
        assert.equal((await this.uniLpToken.balanceOf(this.uniStake.address)).valueOf(), LP_TOKEN_AMOUNT.add(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());

        //create new pair
        tokenC = await MockERC20.new("tokenC", "tokenC", expandTo18Decimals(100000000), { from: alice });
        tokenD = await MockERC20.new("tokenD", "tokenD", expandTo18Decimals(100000000), { from: alice });

        await this.CatnipFactory.createPair(tokenC.address, tokenD.address, { from: alice })
        var pair2Address = await this.CatnipFactory.getPair(tokenC.address, tokenD.address);
        var pair2 = await CatnipPair.at(pair2Address);

        await tokenC.approve(this.router.address, expandTo18Decimals(100000000), { from: alice });
        await tokenD.approve(this.router.address, expandTo18Decimals(100000000), { from: alice });
        await this.router.addLiquidity(tokenC.address,
            tokenD.address,
            expandTo18Decimals(100000000),
            expandTo18Decimals(100000000),
            0,
            0,
            alice,
            MAX_UINT256,
            { from: alice });

        var uniStake2 = await StakingRewards.new(alice, this.uniToken.address, pair2.address, { from: alice });

        var catnipUniV2_2 = await CatnipUniV2.new(
            this.catnipMaster.address,
            pair2.address,
            uniStake2.address,
            this.uniToken.address,
            this.catnip.address,
            fee,
            { from: alice }
        );

        await this.catnipMaster.add(100, catnipUniV2_2.address, true, { from: alice });

        //deposit pool1
        await pair2.transfer(bob, LP_TOKEN_AMOUNT, { from: alice });
        assert.equal((await pair2.balanceOf(bob)).valueOf(), LP_TOKEN_AMOUNT.toString());
        //deposit to catnipUni2
        await pair2.approve(catnipUniV2_2.address, LP_TOKEN_AMOUNT, { from: bob });
        await catnipUniV2_2.deposit(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await pair2.balanceOf(bob)).valueOf(), 0);
        assert.equal((await pair2.balanceOf(uniStake2.address)).valueOf(), LP_TOKEN_AMOUNT.toString());

        await pair2.transfer(carol, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: alice });
        assert.equal((await pair2.balanceOf(carol)).valueOf(), LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)).toString());
        //deposit to catnipUni2
        await pair2.approve(catnipUniV2_2.address, LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        await catnipUniV2_2.deposit(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await pair2.balanceOf(carol)).valueOf(), 0);
        assert.equal((await pair2.balanceOf(uniStake2.address)).valueOf(), LP_TOKEN_AMOUNT.add(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2))).toString());

        const minWithdrawInterval = web3.utils.toBN(100);
        const withoutFeeBlock = (await time.latestBlock()).add(minWithdrawInterval);
        await time.advanceBlockTo(withoutFeeBlock);
        await time.increase('10');

        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.catnip.balanceOf(bob)).gt(1), true);
        assert.equal((await this.uniToken.balanceOf(bob)).gt(web3.utils.toBN(0)), true);

        await this.catnipUniV2.withdraw(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.catnip.balanceOf(carol)).gt(1), true);
        assert.equal((await this.uniToken.balanceOf(carol)).gt(web3.utils.toBN(0)), true);

        await catnipUniV2_2.withdraw(LP_TOKEN_AMOUNT, { from: bob });
        assert.equal((await this.catnip.balanceOf(bob)).gt(1), true);
        assert.equal((await this.uniToken.balanceOf(bob)).gt(web3.utils.toBN(0)), true);

        await catnipUniV2_2.withdraw(LP_TOKEN_AMOUNT.div(web3.utils.toBN(2)), { from: carol });
        assert.equal((await this.catnip.balanceOf(carol)).gt(1), true);
        assert.equal((await this.uniToken.balanceOf(carol)).gt(web3.utils.toBN(0)), true);
    });
})