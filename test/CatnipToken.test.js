const { expectRevert } = require('@openzeppelin/test-helpers');
const CatnipToken = artifacts.require('CatnipToken');

contract('CatnipToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.catnip = await CatnipToken.new({ from: alice });
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.catnip.name();
        const symbol = await this.catnip.symbol();
        const decimals = await this.catnip.decimals();
        assert.equal(name.valueOf(), 'CatnipToken');
        assert.equal(symbol.valueOf(), 'CATNIP');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow owner to mint token', async () => {
        await this.catnip.mint(alice, '100', { from: alice });
        await this.catnip.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.catnip.mint(carol, '1000', { from: bob }),
            'Ownable: caller is not the owner',
        );
        const totalSupply = await this.catnip.totalSupply();
        const aliceBal = await this.catnip.balanceOf(alice);
        const bobBal = await this.catnip.balanceOf(bob);
        const carolBal = await this.catnip.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '100');
        assert.equal(bobBal.valueOf(), '1000');
        assert.equal(carolBal.valueOf(), '0');
    });

    it('should supply token transfers properly', async () => {
        await this.catnip.mint(alice, '100', { from: alice });
        await this.catnip.mint(bob, '1000', { from: alice });
        await this.catnip.transfer(carol, '10', { from: alice });
        await this.catnip.transfer(carol, '100', { from: bob });
        const totalSupply = await this.catnip.totalSupply();
        const aliceBal = await this.catnip.balanceOf(alice);
        const bobBal = await this.catnip.balanceOf(bob);
        const carolBal = await this.catnip.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.catnip.mint(alice, '100', { from: alice });
        await expectRevert(
            this.catnip.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.catnip.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });

    it('should update vote of delegatee when delegator transfers', async () => {
        await this.catnip.mint(alice, '100', { from: alice });
        await this.catnip.delegate(bob, { from: alice });
        assert.equal(await this.catnip.getCurrentVotes(alice), '0');
        assert.equal(await this.catnip.getCurrentVotes(bob), '100');
        await this.catnip.mint(alice, '100', { from: alice });
        assert.equal(await this.catnip.getCurrentVotes(bob), '200');
        await this.catnip.mint(carol, '100', { from: alice });
        await this.catnip.transfer(alice, '50', { from: carol });
        assert.equal(await this.catnip.getCurrentVotes(bob), '250');
        await this.catnip.delegate(carol, { from: alice });
        assert.equal(await this.catnip.getCurrentVotes(bob), '0');
        assert.equal(await this.catnip.getCurrentVotes(carol), '250');
    });
  });
