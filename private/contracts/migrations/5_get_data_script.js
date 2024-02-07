const DSS_Storage = artifacts.require("DSS_Storage");

module.exports = async function(callback) {
    try {
        const instance = await DSS_Storage.deployed();
        
        // Parâmetros de entrada
        const geohash = "s2fd123";
        const minHeight = 100; // Dentro do intervalo inserido anteriormente
        const maxHeight = 200; // Dentro do intervalo inserido anteriormente
        const startTime = Math.floor(Date.now() / 1000); // Agora
        const endTime = Math.floor(Date.now() / 1000) + (48 * 60 * 60); // 48 horas à frente

        console.log(`Buscando dados para geohash ${geohash} com altura entre ${minHeight}-${maxHeight} e tempo entre ${startTime} e ${endTime}`);

        // Chamada da função getData
        const result = await instance.getData(geohash, minHeight, maxHeight, startTime, endTime);
        
        console.log("URLs:", result.urls);
        console.log("EntityNumbers:", result.entityNumbers);
        console.log("IDs:", result.ids);
    } catch (error) {
        console.error("Erro ao buscar dados:", error);
    }

    callback();
};
