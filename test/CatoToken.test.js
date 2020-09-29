const { expectRevert } = require('@openzeppelin/test-helpers');
const CatoToken = artifacts.require('CatoToken');

contract('CatoToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.cato = await CatoToken.new({ from: alice });
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.cato.name();
        const symbol = await this.cato.symbol();
        const decimals = await this.cato.decimals();
        assert.equal(name.valueOf(), 'CatoToken');
        assert.equal(symbol.valueOf(), 'CATO');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow owner to mint token', async () => {
        await this.cato.mint(alice, '100', { from: alice });
        await this.cato.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.cato.mint(carol, '1000', { from: bob }),
            'Ownable: caller is not the owner',
        );
        const totalSupply = await this.cato.totalSupply();
        const aliceBal = await this.cato.balanceOf(alice);
        const bobBal = await this.cato.balanceOf(bob);
        const carolBal = await this.cato.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '100');
        assert.equal(bobBal.valueOf(), '1000');
        assert.equal(carolBal.valueOf(), '0');
    });

    it('should supply token transfers properly', async () => {
        await this.cato.mint(alice, '100', { from: alice });
        await this.cato.mint(bob, '1000', { from: alice });
        await this.cato.transfer(carol, '10', { from: alice });
        await this.cato.transfer(carol, '100', { from: bob });
        const totalSupply = await this.cato.totalSupply();
        const aliceBal = await this.cato.balanceOf(alice);
        const bobBal = await this.cato.balanceOf(bob);
        const carolBal = await this.cato.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.cato.mint(alice, '100', { from: alice });
        await expectRevert(
            this.cato.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.cato.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });

    it('should update vote of delegatee when delegator transfers', async () => {
        await this.cato.mint(alice, '100', { from: alice });
        await this.cato.delegate(bob, { from: alice });
        assert.equal(await this.cato.getCurrentVotes(alice), '0');
        assert.equal(await this.cato.getCurrentVotes(bob), '100');
        await this.cato.mint(alice, '100', { from: alice });
        assert.equal(await this.cato.getCurrentVotes(bob), '200');
        await this.cato.mint(carol, '100', { from: alice });
        await this.cato.transfer(alice, '50', { from: carol });
        assert.equal(await this.cato.getCurrentVotes(bob), '250');
        await this.cato.delegate(carol, { from: alice });
        assert.equal(await this.cato.getCurrentVotes(bob), '0');
        assert.equal(await this.cato.getCurrentVotes(carol), '250');
    });
  });
