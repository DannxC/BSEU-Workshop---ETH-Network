// migrations/4_initial_data.js

const DSS_Storage = artifacts.require("./DSS_Storage.sol");

module.exports = async function(deployer) {
    const instance = await DSS_Storage.deployed();

    console.log("Iniciando inserção de dados iniciais...");

    // Exemplo de inserção de dados
    const geohashes = ["s2fd125", "s2fd126"];
    const minHeight = 90;
    const maxHeight = 200;
    const startTime = Math.floor(Date.now() / 1000); // agora, em segundos
    const endTime = startTime + (24 * 60 * 60); // 24 horas a frente, em segundos
    const url = "example1.com";
    const entity = 1;
    const id = 1;
    
    let result = await instance.upsertPolygonData(geohashes, minHeight, maxHeight, startTime, endTime, url, entity, id);
    console.log(result);
    result = await instance.upsertPolygonData(geohashes, minHeight, maxHeight, startTime, endTime, url, entity, id);
    console.log(result);
};
