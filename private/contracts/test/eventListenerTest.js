const {Web3} = require('web3');

// ENTER A VALID RPC URL!
const web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:8545'));

//ENTER SMART CONTRACT ADDRESS BELOW. see abi.js if you want to modify the abi
const CONTRACT_ARTIFACTS = require('../build/contracts/DSS_Storage.json');
const CONTRACT_ABI = CONTRACT_ARTIFACTS.abi;
const CONTRACT_ADDRESS = CONTRACT_ARTIFACTS.networks['1337'].address;
const contract = new web3.eth.Contract(CONTRACT_ABI, CONTRACT_ADDRESS);


async function getEvents() {
    let latest_block = await web3.eth.getBlockNumber();
    let historical_block = 1; // you can also change the value to 'latest' if you have a upgraded rpc
    console.log("latest: ", latest_block, "historical block: ", historical_block);
    const events = await contract.getPastEvents(
        'DataUpdated', // change if your looking for a different event
        { fromBlock: historical_block, toBlock: 'latest' }
    );
    console.log(events);
    // await getTransferDetails(events);
};

async function getTransferDetails(data_events) {
    for (i = 0; i < data_events.length; i++) {
        let from = data_events[i]['returnValues']['from'];
        let to = data_events[i]['returnValues']['to'];
        let amount = data_events[i]['returnValues']['amount'];
        let converted_amount = web3.utils.fromWei(amount);
        if (converted_amount > 32) { //checking for transcations with above 32 eth as an example
            console.log("From:", from, "- To:", to, "- Value:", converted_amount);
        }
    };
};


getEvents(CONTRACT_ABI, CONTRACT_ADDRESS);