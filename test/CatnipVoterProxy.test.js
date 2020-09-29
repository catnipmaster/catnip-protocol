const { expectRevert } = require('@openzeppelin/test-helpers');
const CatnipToken = artifacts.require('CatnipToken');
const CatnipMaster = artifacts.require('CatnipMaster');
const CatnipVoterProxy = artifacts.require('CatnipVoterProxy');
const MockERC20 = artifacts.require('MockERC20');
const CatnipPair = artifacts.require('CatnipPair');
const CatnipFactory = artifacts.require('CatnipFactory');

const TOTAL_SUPPLY = 10000000;
const LP_SUPPLY    = 1000000;

contract('CatnipVoterProxy', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.catnipToken = await CatnipToken.new({ from: alice });
        await this.catnipToken.mint(minter, TOTAL_SUPPLY, { from: alice });
        this.catnipMaster = await CatnipMaster.new(this.catnipToken.address, dev, '1000', '0', { from: alice });
        this.catnipVoterProxy = await CatnipVoterProxy.new(this.catnipToken.address, this.catnipMaster.address, { from: alice });
    });

    it('check totalSupply', async () => {
        await this.catnipToken.mint(alice, '100', { from: alice });
        await this.catnipToken.mint(bob, '100', { from: alice });
        await this.catnipToken.mint(carol, '100', { from: alice });
        assert.equal((await this.catnipVoterProxy.totalSupply()).valueOf(), '10000300');
        await this.catnipToken.mint(carol, '100', { from: alice });
        assert.equal((await this.catnipVoterProxy.totalSupply()).valueOf(), '10000400');
        await this.catnipToken.mint(bob, '200', { from: alice });
        assert.equal((await this.catnipVoterProxy.totalSupply()).valueOf(), '10000600');
    });

    it('check votePools api', async () => {
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '5');
        // assert.equal((await this.catnipVoterProxy.getVotePoolId(1)).valueOf(), '32');
        await expectRevert(this.catnipVoterProxy.addVotePool(5,{ from: bob }),'Not Owner');
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '5');
        this.catnipVoterProxy.addVotePool('5', { from: alice });
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '6');
        // assert.equal((await this.catnipVoterProxy.getVotePoolId(3)).valueOf(), '34');
        // assert.equal((await this.catnipVoterProxy.getVotePoolId(5)).valueOf(), '5');
        await expectRevert(this.catnipVoterProxy.delVotePool('5', { from: bob }),'Not Owner');
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '6');
        this.catnipVoterProxy.delVotePool('5', { from: alice });
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '5');
        // assert.equal((await this.catnipVoterProxy.getVotePoolId(2)).valueOf(), '33');
        // this.catnipVoterProxy.addVotePool('9', { from: alice });
        // assert.equal((await this.catnipVoterProxy.getVotePoolNum()).valueOf(), '6');
        // assert.equal((await this.catnipVoterProxy.getVotePoolId(5)).valueOf(), '9');
    });

    it('check balanceOf', async () => {
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '0');
        this.factory0 = await CatnipFactory.new(alice, { from: alice });
        this.factory32 = await CatnipFactory.new(alice, { from: alice });
        this.factory33 = await CatnipFactory.new(alice, { from: alice });
        this.factory34 = await CatnipFactory.new(alice, { from: alice });
        await this.catnipToken.transferOwnership(this.catnipMaster.address, { from: alice });
        this.token0 = await MockERC20.new('TToken', 'TOKEN0', TOTAL_SUPPLY, { from: minter });
        this.lp0 = await CatnipPair.at((await this.factory0.createPair(this.token0.address, this.catnipToken.address)).logs[0].args.pair);
        await this.token0.transfer(this.lp0.address, LP_SUPPLY, { from: minter });
        await this.catnipToken.transfer(this.lp0.address, LP_SUPPLY, { from: minter });
        await this.lp0.mint(minter);
        await this.catnipMaster.add('100', this.lp0.address, true);
        for(i=1;i<32;i++)
        {
            this.lptemp = await MockERC20.new('LPToken', 'TOKEN', TOTAL_SUPPLY, { from: minter });
            await this.catnipMaster.add('100', this.lptemp.address, true);
        }
        this.token32 = await MockERC20.new('TToken', 'Token32', TOTAL_SUPPLY, { from: minter });
        this.lp32 = await CatnipPair.at((await this.factory32.createPair(this.token32.address, this.catnipToken.address)).logs[0].args.pair);
        await this.token32.transfer(this.lp32.address, LP_SUPPLY, { from: minter });
        await this.catnipToken.transfer(this.lp32.address, LP_SUPPLY, { from: minter });
        await this.lp32.mint(minter);
        await this.catnipMaster.add('100', this.lp32.address, true);
        this.token33 = await MockERC20.new('TToken', 'TOKEN33', TOTAL_SUPPLY, { from: minter });
        this.lp33 = await CatnipPair.at((await this.factory33.createPair(this.token33.address, this.catnipToken.address)).logs[0].args.pair);
        await this.token33.transfer(this.lp33.address, LP_SUPPLY, { from: minter });
        await this.catnipToken.transfer(this.lp33.address, LP_SUPPLY, { from: minter });
        await this.lp33.mint(minter);
        await this.catnipMaster.add('100', this.lp33.address, true);
        this.token34 = await MockERC20.new('LPToken', 'TOKEN34', TOTAL_SUPPLY, { from: minter });
        this.lp34 = await CatnipPair.at((await this.factory34.createPair(this.token34.address, this.catnipToken.address)).logs[0].args.pair);
        await this.token34.transfer(this.lp34.address, LP_SUPPLY, { from: minter });
        await this.catnipToken.transfer(this.lp34.address, LP_SUPPLY, { from: minter });
        await this.lp34.mint(minter);
        await this.catnipMaster.add('100', this.lp34.address, true);
        //null pool will destroy 1000 lp_token
        // console.log("get minter lp0",(await this.lp0.balanceOf(minter)).valueOf());
        // console.log("get minter vote",(await this.catnipVoterProxy.balanceOf(minter)).valueOf());
        await this.lp0.approve(this.catnipMaster.address, '100', { from: minter });
        await this.catnipMaster.deposit(0, '100', { from: minter });
        assert.equal((await this.catnipVoterProxy.balanceOf(minter)).valueOf(), '6000100');
        await this.lp32.approve(this.catnipMaster.address, '200', { from: minter });
        await this.catnipMaster.deposit(32, '100', { from: minter });
        assert.equal((await this.catnipVoterProxy.balanceOf(minter)).valueOf(), '6000200');

        await this.lp0.transfer(bob, '500', { from: minter });
        await this.lp0.approve(this.catnipMaster.address, '500', { from: bob });
        await this.catnipMaster.deposit(0, '500', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '500');
        await this.lp32.transfer(bob, '500', { from: minter });
        await this.lp32.approve(this.catnipMaster.address, '500', { from: bob });
        await this.catnipMaster.deposit(32, '500', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1000');
        await this.lp34.transfer(bob, '500', { from: minter });
        await this.lp34.approve(this.catnipMaster.address, '500', { from: bob });
        await this.catnipMaster.deposit(34, '500', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1500');
        await this.catnipMaster.withdraw(34, '500', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1028');

        //no votepool deposit
        this.factory35 = await CatnipFactory.new(alice, { from: alice });
        this.token35 = await MockERC20.new('TToken', 'TOKE35', TOTAL_SUPPLY, { from: minter });
        this.lp35 = await CatnipPair.at((await this.factory35.createPair(this.token35.address, this.catnipToken.address)).logs[0].args.pair);
        await this.token35.transfer(this.lp35.address, LP_SUPPLY, { from: minter });
        await this.catnipToken.transfer(this.lp35.address, LP_SUPPLY, { from: minter });
        await this.lp35.mint(minter);
        await this.catnipMaster.add('100', this.lp35.address, true);
        await this.lp35.transfer(bob, '500', { from: minter });
        await this.lp35.approve(this.catnipMaster.address, '500', { from: bob });
        await this.catnipMaster.deposit(35, '500', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1028');
        //add votepool 35
        this.catnipVoterProxy.addVotePool('35', { from: alice });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1528');
        await this.catnipMaster.withdraw(35, '300', { from: bob });
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1283');
        //del votepool 35
        this.catnipVoterProxy.delVotePool('35', { from: alice });
        //votepools only have 200 balanceOf
        assert.equal((await this.catnipVoterProxy.balanceOf(bob)).valueOf(), '1083');
    });
});
