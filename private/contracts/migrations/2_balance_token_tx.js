var GoLedgerToken = artifacts.require("GoLedgerToken.sol");

module.exports = function (deployer, network, accounts) {
    deployer.then(async () => {
        // const accounts = await web3.eth.getAccounts(); // Pega as contas do provider (nodes da rede)

        // Replace with the address of the token contract you want to get the balance for
        const tokenAddress = "0xYourTokenContractAddress";

        // Create an instance of the token contract
        const tokenInstance = await GoLedgerToken.at(tokenAddress); // Use 'GoLedgerToken' here

        // Replace with the index of the account for which you want to get the balance
        const accountIndex = 1; // Use the index of the account you want

        // Call the balanceOf function to get the balance of the account
        const balance = await tokenInstance.balanceOf(accounts[accountIndex]);

        console.log(`Balance of account at index ${accountIndex}: ${balance.toString()} tokens`);
    });
};

