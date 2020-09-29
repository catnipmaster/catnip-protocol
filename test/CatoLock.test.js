const { expectRevert, time } = require('@openzeppelin/test-helpers');
const CatoMaster = artifacts.require('CatoMaster');
const CatoToken = artifacts.require('CatoToken');
const CatoLock = artifacts.require('CatoLock');

contract('CatoLock', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.cato = await CatoToken.new({ from: alice });
        this.master = await CatoMaster.new(this.cato.address, bob, '1000', '0', { from: alice });
        this.catoLock = await CatoLock.new(this.cato.address, this.master.address, { from: alice });
    });

    it('should deposit CatoLock Token success', async () => {
        const totalSupply = await this.catoLock.totalSupply();
        assert.equal(totalSupply.valueOf(), '1');
        await this.cato.transferOwnership(this.master.address, { from: alice });
        await this.master.add('100', this.catoLock.address, false);
        await time.advanceBlockTo('8');
        await this.catoLock.deposit('0', { from: alice });
        await time.advanceBlockTo('10');
        assert.equal((await this.master.pendingCato(0, this.catoLock.address)).valueOf(), '1000');
        await this.catoLock.withdrawFromCatoMaster('0', { from: alice });
        assert.equal(await this.cato.balanceOf(this.catoLock.address).valueOf(), '2000');

        await this.catoLock.setwithdrawContractAddr(carol);
        assert.equal(await this.catoLock.withDrawAddr().valueOf(), carol);

        await this.catoLock.withdrawToContract(50);
        assert.equal(await this.cato.balanceOf(this.catoLock.address).valueOf(), '1950');
        assert.equal(await this.cato.balanceOf(carol).valueOf(), '50');
    });
})