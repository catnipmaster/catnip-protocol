const { expectRevert, time } = require('@openzeppelin/test-helpers');
const CatoToken = artifacts.require('CatoToken');
const MockERC20 = artifacts.require('MockERC20');
const CatPinPair = artifacts.require('CatPinPair');
const CatPinFactory = artifacts.require('CatPinFactory');
const CatoDrinker = artifacts.require('CatoDrinker');

contract('CatoDrinker', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.factory = await CatPinFactory.new(alice, { from: alice });
        this.cato = await CatoToken.new({ from: alice });
        await this.cato.mint(alice, '100000000', { from: alice });
        this.uni = await MockERC20.new('UNI', 'UNI', '100000000', { from: alice });
        this.catoUni = await CatPinPair.at((await this.factory.createPair(this.cato.address, this.uni.address)).logs[0].args.pair);
        this.blackHoldAddress = '0000000000000000000000000000000000000001';
        this.drinker = await CatoDrinker.new(this.factory.address, this.cato.address, this.uni.address);
    });

    it('only owner can set factory', async () => {
        assert.equal(await this.drinker.owner(), alice);
        assert.equal(await this.drinker.factory(), this.factory.address);
        await expectRevert(this.drinker.setFactory(bob, { from: bob }), 'only owner');
        await this.drinker.setFactory(bob, { from: alice });
        assert.equal(await this.drinker.factory(), bob);
    });

    it('should convert uni to cato successfully', async () => {
        // add liquidity
        await this.cato.transfer(this.catoUni.address, '100000', { from: alice });
        await this.uni.transfer(this.catoUni.address, '100000', { from: alice });
        await this.catoUni.sync();
        await this.cato.transfer(this.catoUni.address, '10000000', { from: alice });
        await this.uni.transfer(this.catoUni.address, '10000000', { from: alice });
        await this.catoUni.mint(alice);

        await this.uni.transfer(this.drinker.address, '1000');
        await this.drinker.convert();
        assert.equal(await this.uni.balanceOf(this.drinker.address), '0');
        assert.equal(await this.cato.balanceOf(this.blackHoldAddress), '996');
    });
})