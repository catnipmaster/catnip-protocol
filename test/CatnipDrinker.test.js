const { expectRevert, time } = require('@openzeppelin/test-helpers');
const CatnipToken = artifacts.require('CatnipToken');
const MockERC20 = artifacts.require('MockERC20');
const CatnipPair = artifacts.require('CatnipPair');
const CatnipFactory = artifacts.require('CatnipFactory');
const CatnipDrinker = artifacts.require('CatnipDrinker');

contract('CatnipDrinker', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.factory = await CatnipFactory.new(alice, { from: alice });
        this.catnip = await CatnipToken.new({ from: alice });
        await this.catnip.mint(alice, '100000000', { from: alice });
        this.uni = await MockERC20.new('UNI', 'UNI', '100000000', { from: alice });
        this.catnipUni = await CatnipPair.at((await this.factory.createPair(this.catnip.address, this.uni.address)).logs[0].args.pair);
        this.blackHoldAddress = '0000000000000000000000000000000000000001';
        this.drinker = await CatnipDrinker.new(this.factory.address, this.catnip.address, this.uni.address);
    });

    it('only owner can set factory', async () => {
        assert.equal(await this.drinker.owner(), alice);
        assert.equal(await this.drinker.factory(), this.factory.address);
        await expectRevert(this.drinker.setFactory(bob, { from: bob }), 'only owner');
        await this.drinker.setFactory(bob, { from: alice });
        assert.equal(await this.drinker.factory(), bob);
    });

    it('should convert uni to catnip successfully', async () => {
        // add liquidity
        await this.catnip.transfer(this.catnipUni.address, '100000', { from: alice });
        await this.uni.transfer(this.catnipUni.address, '100000', { from: alice });
        await this.catnipUni.sync();
        await this.catnip.transfer(this.catnipUni.address, '10000000', { from: alice });
        await this.uni.transfer(this.catnipUni.address, '10000000', { from: alice });
        await this.catnipUni.mint(alice);

        await this.uni.transfer(this.drinker.address, '1000');
        await this.drinker.convert();
        assert.equal(await this.uni.balanceOf(this.drinker.address), '0');
        assert.equal(await this.catnip.balanceOf(this.blackHoldAddress), '996');
    });
})