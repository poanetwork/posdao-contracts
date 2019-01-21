const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

contract('ValidatorSetAuRa', async accounts => {
  describe('initialize()', async () => {
    let validatorSetAuRa;

    beforeEach(async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
    });
    it('should initialize', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(0);
      // await validatorSetAuRa.initialize();
      // ...
    });
  });
});
