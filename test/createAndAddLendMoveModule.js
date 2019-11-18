const utils = require('./utils/general')

const CreateAndAddModules = artifacts.require("./libraries/CreateAndAddModules.sol");
const GnosisSafe = artifacts.require("./GnosisSafe.sol")
const ProxyFactory = artifacts.require("./ProxyFactory.sol")
const LendingMoveModule = artifacts.require("./modules/LendingMoveModule.sol");

contract('CreateAndAddModules', function (accounts) {

    let gnosisSafe
    let lw
    let executor = accounts[8]

    const DELEGATE_CALL = 1

    it('should create safe with multiple modules', async () => {
        // Create lightwallet
        lw = await utils.createLightwallet()
        // Create libraries
        let createAndAddModules = await CreateAndAddModules.new()
        // Create Master Copies
        let proxyFactory = await ProxyFactory.new()
        let gnosisSafeMasterCopy = await utils.deployContract("deploying Gnosis Safe Mastercopy", GnosisSafe)
        gnosisSafeMasterCopy.setup([lw.accounts[0], lw.accounts[1], lw.accounts[2]], 2, 0, "0x", 0, 0, 0, 0)
        let LendingMoveModuleMasterCopy = await LendingMoveModule.new()
        LendingMoveModuleMasterCopy.setup()

        // Create module data
        let LendingMoveModulelSetupData = await LendingMoveModuleMasterCopy.contract.setup.getData()
        let LendingMoveCreationData = await proxyFactory.contract.createProxy.getData(LendingMoveModuleMasterCopy.address, LendingMoveModulelSetupData)

        // Create library data
        let modulesCreationData = utils.createAndAddModulesData([LendingMoveCreationData])
        let createAndAddModulesData = createAndAddModules.contract.createAndAddModules.getData(proxyFactory.address, modulesCreationData)

        // Create Gnosis Safe
        let gnosisSafeData = await gnosisSafeMasterCopy.contract.setup.getData([lw.accounts[0], lw.accounts[1], lw.accounts[2]], 2, createAndAddModules.address, createAndAddModulesData, 0, 0, 0, 0)
        gnosisSafe = utils.getParamFromTxEvent(
            await proxyFactory.createProxy(gnosisSafeMasterCopy.address, gnosisSafeData),
            'ProxyCreation', 'proxy', proxyFactory.address, GnosisSafe, 'create Gnosis Safe Proxy',
        )

        let modules = await gnosisSafe.getModules()
        assert.equal(2, modules.length)

        let LendingMoveModulelSetupData = await LendingMoveModuleMasterCopy.contract.setup.getData()
        let LendingMoveCreationData = await proxyFactory.contract.createProxy.getData(LendingMoveModuleMasterCopy.address, LendingMoveModulelSetupData)
        let enableModuleParameterData = utils.createAndAddModulesData([LendingMoveCreationData])
        let enableModuleData = createAndAddModules.contract.createAndAddModules.getData(proxyFactory.address, enableModuleParameterData)

        let to = createAndAddModules.address
        let data = enableModuleData
        let operation = DELEGATE_CALL
        let nonce = await gnosisSafe.nonce()
        let transactionHash = await gnosisSafe.getTransactionHash(to, 0, data, operation, 0, 0, 0, 0, 0, nonce)
        // Confirm transaction with signed messages
        let sigs = utils.signTransaction(lw, [lw.accounts[0], lw.accounts[2]], transactionHash)
        let tx = await gnosisSafe.execTransaction(to, 0, data, operation, 0, 0, 0, 0, 0, sigs, {
            from: executor
        })
        utils.checkTxEvent(tx, 'ExecutionFailed', gnosisSafe.address, false, "create and enable daily limit module")

        modules = await gnosisSafe.getModules()
        assert.equal(3, modules.length)

    })
})