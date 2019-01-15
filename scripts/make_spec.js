const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
const fetch = require('node-fetch');
const web3 = new Web3(new Web3.providers.HttpProvider("https://dai.poa.network"));

main();

async function main() {
    const networkName = process.env.NETWORK_NAME;
    const networkID = process.env.NETWORK_ID;
    const owner = process.env.OWNER.trim();
    let initialValidators = process.env.INITIAL_VALIDATORS.split(',');
    for (let i = 0; i < initialValidators.length; i++) {
        initialValidators[i] = initialValidators[i].trim();
    }
    const stakingEpochDuration = process.env.STAKING_EPOCH_DURATION;
    const collectRoundLength = process.env.COLLECT_ROUND_LENGTH;

    const contracts = [
        'EternalStorageProxy',
        'ValidatorSetAuRa',
        'BlockRewardAuRa',
        'RandomAuRa',
        'TxPermission',
        'Certifier',
        'Registry',
        'InitializerAuRa'
    ];

    console.log(`Loading spec.json from poa-chain-spec repo...`);
    let spec = await fetch('https://raw.githubusercontent.com/poanetwork/poa-chain-spec/aaec610a3af9ea5ef30a1e53c51ddfaf3c734fc3/spec.json');
    spec = await spec.json();

    spec.name = networkName;
    spec.params.networkID = networkID;
    spec.params.eip145Transition = '0x0';
    spec.params.eip1014Transition = '0x0';
    spec.params.eip1052Transition = '0x0';
    spec.params.eip1283Transition = '0x0';

    let contractsCompiled = {};
    for (let i = 0; i < contracts.length; i++) {
        const contractName = contracts[i];
        console.log(`Compiling ${contractName}...`);
        const compiled = await compile(
            contractName == 'EternalStorageProxy' ? 'contracts/eternal-storage/' : 'contracts/',
            contractName
        );
        contractsCompiled[contractName] = compiled;
    }

    const eternalStorageProxyCompiled = contractsCompiled['EternalStorageProxy'];
    let contract = new web3.eth.Contract(eternalStorageProxyCompiled.abi);
    let deploy;

    // Build ValidatorSetAuRa contract
    deploy = await contract.deploy({data: '0x' + eternalStorageProxyCompiled.bytecode, arguments: [
        '0x1000000000000000000000000000000000000002', // implementation address
        owner
    ]});
    spec.engine.authorityRound.params.validators.multi = {
        "0": {
            "contract": '0x1000000000000000000000000000000000000001'
        }
    };
    spec.accounts['0x1000000000000000000000000000000000000001'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.accounts['0x1000000000000000000000000000000000000002'] = {
        balance: '0',
        constructor: '0x' + contractsCompiled['ValidatorSetAuRa'].bytecode
    };

    // Build BlockRewardAuRa contract
    deploy = await contract.deploy({data: '0x' + eternalStorageProxyCompiled.bytecode, arguments: [
        '0x2000000000000000000000000000000000000002', // implementation address
        owner
    ]});
    spec.accounts['0x2000000000000000000000000000000000000001'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.engine.authorityRound.params.blockRewardContractAddress = '0x2000000000000000000000000000000000000001';
    spec.engine.authorityRound.params.blockRewardContractTransition = 0;
    spec.accounts['0x2000000000000000000000000000000000000002'] = {
        balance: '0',
        constructor: '0x' + contractsCompiled['BlockRewardAuRa'].bytecode
    };

    // Build RandomAuRa contract
    deploy = await contract.deploy({data: '0x' + eternalStorageProxyCompiled.bytecode, arguments: [
        '0x3000000000000000000000000000000000000002', // implementation address
        owner
    ]});
    spec.accounts['0x3000000000000000000000000000000000000001'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.accounts['0x3000000000000000000000000000000000000002'] = {
        balance: '0',
        constructor: '0x' + contractsCompiled['RandomAuRa'].bytecode
    };

    // Build TxPermission contract
    deploy = await contract.deploy({data: '0x' + eternalStorageProxyCompiled.bytecode, arguments: [
        '0x4000000000000000000000000000000000000002', // implementation address
        owner
    ]});
    spec.accounts['0x4000000000000000000000000000000000000001'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.params.transactionPermissionContract = '0x4000000000000000000000000000000000000001';
    spec.accounts['0x4000000000000000000000000000000000000002'] = {
        balance: '0',
        constructor: '0x' + contractsCompiled['TxPermission'].bytecode
    };

    // Build Certifier contract
    deploy = await contract.deploy({data: '0x' + eternalStorageProxyCompiled.bytecode, arguments: [
        '0x5000000000000000000000000000000000000002', // implementation address
        owner
    ]});
    spec.accounts['0x5000000000000000000000000000000000000001'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.accounts['0x5000000000000000000000000000000000000002'] = {
        balance: '0',
        constructor: '0x' + contractsCompiled['Certifier'].bytecode
    };

    // Build Registry contract
    contract = new web3.eth.Contract(contractsCompiled['Registry'].abi);
    deploy = await contract.deploy({data: '0x' + contractsCompiled['Registry'].bytecode, arguments: [
        '0x5000000000000000000000000000000000000001' // the address of Certifier contract
    ]});
    spec.accounts['0x6000000000000000000000000000000000000000'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };
    spec.params.registrar = '0x6000000000000000000000000000000000000000';

    // Build InitializerAuRa contract
    contract = new web3.eth.Contract(contractsCompiled['InitializerAuRa'].abi);
    deploy = await contract.deploy({data: '0x' + contractsCompiled['InitializerAuRa'].bytecode, arguments: [
        '0x1000000000000000000000000000000000000001', // _validatorSetContract
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _validators
        1, // _stakerMinStake
        1, // _validatorMinStake
        stakingEpochDuration, // _stakingEpochDuration
        collectRoundLength    // _collectRoundLength
    ]});
    spec.accounts['0x7000000000000000000000000000000000000000'] = {
        balance: '0',
        constructor: await deploy.encodeABI()
    };

    console.log('Saving spec.json file ...');
    fs.writeFileSync('spec.json', JSON.stringify(spec, null, '  '));
    console.log('Done');
}

async function compile(dir, contractName) {
    const input = {
        language: 'Solidity',
        sources: {
            '': {
                content: fs.readFileSync(dir + contractName + '.sol').toString()
            }
        },
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            },
            evmVersion: "constantinople",
            outputSelection: {
                '*': {
                    '*': [ 'abi', 'evm.bytecode.object' ]
                }
            }
        }
    }

    const compiled = JSON.parse(solc.compile(JSON.stringify(input), function(path) {
        let content;
        try {
            content = fs.readFileSync(dir + path);
        } catch (e) {
            if (e.code == 'ENOENT') {
                content = fs.readFileSync(dir + '../' + path);
            }
        }
        return {
            contents: content.toString()
        }
    }));

    const result = compiled.contracts[''][contractName];

    return {abi: result.abi, bytecode: result.evm.bytecode.object};
}

// NETWORK_NAME=DPoSChain NETWORK_ID=101 OWNER=0x1092a1E3A3F2FB2024830Dd12064a4B33fF8EbAe INITIAL_VALIDATORS=0xeE385a1df869A468883107B0C06fA8791b28A04f,0x71385ae87c4b93db96f02f952be1f7a63f6057a6,0x190ec582090ae24284989af812f6b2c93f768ecd STAKING_EPOCH_DURATION=120960 COLLECT_ROUND_LENGTH=200 node scripts/make_spec.js