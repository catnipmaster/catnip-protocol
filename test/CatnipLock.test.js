const { expectRevert, time } = require('@openzeppelin/test-helpers');
const CatnipMaster = artifacts.require('CatnipMaster');
const CatnipToken = artifacts.require('CatnipToken');
const CatnipLock = artifacts.require('CatnipLock');

contract('CatnipLock', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.catnip = await CatnipToken.new({ from: alice });
        this.master = await CatnipMaster.new(this.catnip.address, bob, '1000', '0', { from: alice });
        this.catnipLock = await CatnipLock.new(this.catnip.address, this.master.address, { from: alice });
    });

    it('should deposit CatnipLock Token success', async () => {
        const totalSupply = await this.catnipLock.totalSupply();
        assert.equal(totalSupply.valueOf(), '1');
        await this.catnip.transferOwnership(this.master.address, { from: alice });
        await this.master.add('100', this.catnipLock.address, false);
        await time.advanceBlockTo('8');
        await this.catnipLock.deposit('0', { from: alice });
        await time.advanceBlockTo('10');
        assert.equal((await this.master.pendingCatnip(0, this.catnipLock.address)).valueOf(), '1000');
        await this.catnipLock.withdrawFromCatnipMaster('0', { from: alice });
        assert.equal(await this.catnip.balanceOf(this.catnipLock.address).valueOf(), '2000');

        await this.catnipLock.setwithdrawContractAddr(carol);
        assert.equal(await this.catnipLock.withDrawAddr().valueOf(), carol);

        await this.catnipLock.withdrawToContract(50);
        assert.equal(await this.catnip.balanceOf(this.catnipLock.address).valueOf(), '1950');
        assert.equal(await this.catnip.balanceOf(carol).valueOf(), '50');
    });
})