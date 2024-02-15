// migrations/5_get_data_script.js

const DSS_Storage = artifacts.require("DSS_Storage");

module.exports = async function(callback) {
    try {
        const instance = await DSS_Storage.deployed();

        const geohash = "s2fd123";
        const minHeight = 100;
        const maxHeight = 200;
        const startTime = Math.floor(Date.now() / 1000); // Agora
        const endTime = startTime + (48 * 60 * 60); // 48 horas à frente

        console.log(`Buscando dados para o geohash ${geohash} com altura entre ${minHeight}-${maxHeight} e tempo entre ${startTime} e ${endTime}`);

        // Chamada da função getData
        const result = await instance.getData(geohash, minHeight, maxHeight, startTime, endTime);

        console.log("Dados recuperados com sucesso:");
        console.log("URLs:", result.urls);
        console.log("EntityNumbers:", result.entityNumbers.map(num => num.toNumber()));
        console.log("IDs:", result.ids.map(id => id.toNumber()));
    } catch (error) {
        console.error("Erro ao buscar dados:", error);
    }
};
