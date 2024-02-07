// migrations/4_initial_data.js

const DSS_Storage = artifacts.require("./DSS_Storage.sol");

module.exports = function(deployer) {
  deployer.then(async () => {
    console.log("Iniciando migração 4_initial_data.js...");

    const instance = await DSS_Storage.deployed();
    console.log("Instância do contrato obtida com sucesso:", instance.address);

    // Substitua esses valores pelos dados fictícios desejados
    const geohash = "s2fd123";
    const minHeight = 100; // altura mínima em metros
    const maxHeight = 200; // altura máxima em metros
    const startTime = Math.floor(Date.now() / 1000); // agora, em segundos
    const endTime = Math.floor(Date.now() / 1000) + (24 * 60 * 60); // 24 horas a frente, em segundos
    const url = "https://example.com/resource";
    const entityNumber = 1; // escolha entre 1, 2 ou 3
    const id = 42; // ID fictício

    console.log("Chamando inputData com os seguintes parâmetros:");
    console.log(" - geohash:", geohash);
    console.log(" - minHeight:", minHeight);
    console.log(" - maxHeight:", maxHeight);
    console.log(" - startTime:", startTime);
    console.log(" - endTime:", endTime);
    console.log(" - url:", url);
    console.log(" - entityNumber:", entityNumber);
    console.log(" - id:", id);

    await instance.inputData(
      geohash,
      minHeight,
      maxHeight,
      startTime,
      endTime,
      url,
      entityNumber,
      id,
    //   { from: deployer, gas: 5000000 }
    );

    console.log("Migração 4_initial_data.js concluída com sucesso!");
  });
};
