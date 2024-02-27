// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GeohashConverter {

    /* STRUCTS */

    enum Direction {        // used in the moveGeohash function
        Up,
        Down,
        Left,
        Right
    }

    struct Point {
        int256 lat;
        int256 lon;
    }

    struct Move {
        Direction lat;
        Direction lon;
    }

    struct BoundingBox {
        int256 minLat;
        int256 minLon;
        int256 maxLat;
        int256 maxLon;
        bytes32[] geohashes;    // User is able to choose how many geohashes to store for the bounding box
        uint256 width;
        uint256 height;
    }


    /* STATE VARIABLES */

    // CONSTANTS
    uint256 constant public DECIMALS = 18;                          // Number of decimals to use for the geohash precision
    int256 constant public DECIMALS_FACTOR = int256(10**DECIMALS);  // Factor to scale the geohash precision to an integer: 1000000000000000000
    // uint256 constant public PI = 3141592653589793238;       // Aproximação de PI com fator de escala 10^18 para trabalhar com inteiros

    uint8 immutable public geohashMaxPrecision;                // This sets geohash precision to a fixed value (0-16)
                                                            // OBS: For precision: 8 -> 7781.98 km² ; 12 -> 30,39 km² ; 14 -> 1,899 km² ; 16 -> 0,118 km²
    int256 immutable public gridCellLatSize;
    int256 immutable public gridCellLonSize;

    int256 constant public MIN_LATITUDE  =  -90 * DECIMALS_FACTOR;
    int256 constant public MAX_LATITUDE  =   90 * DECIMALS_FACTOR;
    int256 constant public MIN_LONGITUDE = -180 * DECIMALS_FACTOR;
    int256 constant public MAX_LONGITUDE =  180 * DECIMALS_FACTOR;

    //mapping(uint8 => int256) public geohashPrecisionMap; // Example: This allows for dynamic precision
    mapping(bytes32 => bool) public geohashMap; // Map to store unique geohashes from the polygon processing algorithm result

    // Estrutura para mapear labels a geohashes
    mapping(uint256 => bytes32[]) public labelToGeohashes;
    // Equivalency List to be used in the fillPolygon function
    uint256[] public labelEquivalencyList;
    

    /* FUNCTIONS */

    constructor (uint8 precision) {
        require (precision <= 16, "Maximum precision must be less then 16");      // Geohash is stored as a bytes4 (32 bits), so precision must be between 1 and 16 since each precision level adds 2 bits
        geohashMaxPrecision = precision;
        gridCellLatSize = (MAX_LATITUDE - MIN_LATITUDE) / int256(2**precision);
        gridCellLonSize = (MAX_LONGITUDE - MIN_LONGITUDE) / int256(2**precision);
        // Initialize the geohash precision map
        // Example: geohashPrecisionMap[1] = 5000000; etc.
    }


    // Function to convert a latitude and longitude pair into a geohash (parameters should be given in degrees and with the DECIMALS_FACTOR already applied)
    function latLongToZOrderGeohash(int256 lat, int256 lon, uint8 precision) public view returns (bytes32) {
        require(lat >= MIN_LATITUDE && lat <= MAX_LATITUDE, "Latitude out of valid limits.");
        require(lon >= MIN_LONGITUDE && lon <= MAX_LONGITUDE, "Longitude out of valid limits.");
        require(precision <= geohashMaxPrecision, "Precision must be less than or equal to the maximum precision");

        bytes32 geohash;

        // Convert (lat, long) to (x, y) coordinates
        int256 y = lat - MIN_LATITUDE;
        int256 x = lon - MIN_LONGITUDE;

        // Initial limits of x and y
        int256 upBound    = MAX_LATITUDE - MIN_LATITUDE;
        int256 downBound  = MIN_LATITUDE - MIN_LATITUDE;
        int256 leftBound  = MIN_LONGITUDE - MIN_LONGITUDE;
        int256 rightBound = MAX_LONGITUDE - MIN_LONGITUDE;


        // Loop para calcular o geohash de acordo com a precisão
        for (uint i = 0; i < precision; i++) {
            geohash = geohash << 2; // Shift de 2 bits à esquerda

            // Atualiza os midpoints para a próxima iteração
            int256 midY = downBound + (upBound - downBound) / 2;
            int256 midX = leftBound + (rightBound - leftBound) / 2;

            // Determina a localização em relação aos midpoints e atualiza os bounds (Z-Order)
            if (x < midX && y >= midY) { // Quadrante superior esquerdo
                //geohash |= bytes32(uint256(0));
                rightBound = midX;
                downBound = midY;
            } else if (x >= midX && y >= midY) { // Quadrante superior direito
                geohash |= bytes32(uint256(1));
                leftBound = midX;
                downBound = midY;
            } else if (x < midX && y < midY) { // Quadrante inferior esquerdo
                geohash |= bytes32(uint256(2));
                rightBound = midX;
                upBound = midY;
            } else { // Quadrante inferior direito
                geohash |= bytes32(uint256(3));
                leftBound = midX;
                upBound = midY;
            }
        }

        return geohash;
    }

    // Function to return the middle point of a given geohash
    function geohashToLatLong(bytes32 _geohash, uint8 precision) public view returns (int256 lat, int256 lon) {
        require(precision <= geohashMaxPrecision, "Precision must be less than or equal to the maximum precision");

        // Initial limits of lat and lon
        int256 upBound    = MAX_LATITUDE;
        int256 downBound  = MIN_LATITUDE;
        int256 leftBound  = MIN_LONGITUDE;
        int256 rightBound = MAX_LONGITUDE;


        // Loop para calcular o geohash de acordo com a precisão
        for (uint i = precision; i > 0; i--) {

            // Read the 2 bits of the current precision level
            uint256 current2Bits = (uint256(_geohash) >> (2 * (i - 1))) & 3;    // _geohash >> 2*(i-1) AND 00000...00011

            // Atualiza os midpoints para a próxima iteração
            int256 midLat = downBound + (upBound - downBound) / 2;
            int256 midLon = leftBound + (rightBound - leftBound) / 2;

            // Determina a localização em relação aos midpoints e atualiza os bounds (Z-Order)
            if (current2Bits == 0) { // Quadrante superior esquerdo
                downBound = midLat;
                rightBound = midLon;
            } else if (current2Bits == 1) { // Quadrante superior direito
                downBound = midLat;
                leftBound = midLon;
            } else if (current2Bits == 2) { // Quadrante inferior esquerdo
                upBound = midLat;
                rightBound = midLon;
            } else if (current2Bits == 3) { // Quadrante inferior direito
                upBound = midLat;
                leftBound = midLon;
            } else {
                    revert("last2Bits was not correctly converted (bytes32 -> int256)");
            }
        }

        // Calcula o ponto médio do quadrante final
        lat = downBound + (upBound - downBound) / 2;
        lon = leftBound + (rightBound - leftBound) / 2;

        return (lat, lon);
    }

    // Additional helper function to handle the directional movement based on steps
    // This is a placeholder for the logic required to actually compute these movements.
    function singleMoveGeohash(bytes32 _geohash, uint8 precision, Direction _direction) public view returns (bytes32) {
        require(precision <= geohashMaxPrecision, "Precision must be less than or equal to the maximum precision");

        bytes32 result = _geohash;
        bytes32 partialGeohash = _geohash;

        // Based on the direction ('right', 'left', 'up', 'down'), and steps, calculate the new geohash.
        for (uint i = precision; i > 0; i--) {
            // Read last 2 bits of partialGeohash
            bytes32 current2Bits = partialGeohash & bytes32(uint256(3));   // _geohash AND 00000...00011
            uint256 current2BitsInt = uint256(current2Bits);

            // Based on desired move, flows the Z-Order in the current precision-level (i) and discover how to modify the pair of 2-bits representing that precision-level
            //
            // Obs: We are considering 2d plane of the globe, so up and down movements are a little bit wrong in the borders...
            // but the left and right are doing the wrap very well in the borders of the 2D representation (remember it is a cylinder projection of the sphere)
            // In the end, we are considering that the hashes never need to goes up or down in the borders, but could do left right well.
            if(_direction == Direction.Up) {
                if (current2BitsInt == 0 || current2BitsInt == 1) {
                    result = bytes32(uint256(result) + uint256(2 * 4**(precision - i)));   //      sum 10 left-shifted 2*(precision - i) times
                } else if(current2BitsInt == 2 || current2BitsInt == 3) {
                    result = bytes32(uint256(result) - uint256(2 * 4**(precision - i)));   // subtract 10 left-shifted 2*(precision - i) times
                    break;
                } else {
                    revert("last2Bits was not correctly converted (bytes32 -> int256)");
                }
            } else if(_direction == Direction.Down) {
                if (current2BitsInt == 0 || current2BitsInt == 1) {
                    result = bytes32(uint256(result) + uint256(2 * 4**(precision - i)));   //      sum 10 left-shifted 2*(precision - i) times
                    break;
                } else if(current2BitsInt == 2 || current2BitsInt == 3) {
                    result = bytes32(uint256(result) - uint256(2 * 4**(precision - i)));   // subtract 10 left-shifted 2*(precision - i) times
                } else {
                    revert("last2Bits was not correctly converted (bytes32 -> int256)");
                }
            } else if(_direction == Direction.Left) {
                if (current2BitsInt == 0 || current2BitsInt == 2) {
                    result = bytes32(uint256(result) + uint256(1 * 4**(precision - i)));   //      sum 01 left-shifted 2*(precision - i) times
                } else if(current2BitsInt == 1 || current2BitsInt == 3) {
                    result = bytes32(uint256(result) - uint256(1 * 4**(precision - i)));   // subtract 01 left-shifted 2*(precision - i) times
                    break;
                } else {
                    revert("last2Bits was not correctly converted (bytes32 -> int256)");
                }
            } else if(_direction == Direction.Right) {
                if (current2BitsInt == 0 || current2BitsInt == 2) {
                    result = bytes32(uint256(result) + uint256(1 * 4**(precision - i)));   //      sum 01 left-shifted 2*(precision - i) times
                    break;
                } else if(current2BitsInt == 1 || current2BitsInt == 3) {
                    result = bytes32(uint256(result) - uint256(1 * 4**(precision - i)));   // subtract 01 left-shifted 2*(precision - i) times
                } else {
                    revert("last2Bits was not correctly converted (bytes32 -> int256)");
                }
            } else{
                revert("Direction wasn't correctly specified");
            }

            // Att partialGeohash (we already used the last 2 bits, so throw them away.
            partialGeohash = partialGeohash >> 2;
        }

        return result;
    }

    // Distance between two lattitude and longitude points (approximation in 2D plane, not the real distance in the sphere)
    // OBS: We are calculating the distance in a 2D plane, so it is not the real distance in the sphere
    function squareDistance(int256 x1, int256 y1, int256 x2, int256 y2) public pure returns (int256) {
        int256 dX = x2 - x1;
        int256 dY = y2 - y1;

        return dX * dX + dY * dY;
    }

    // Math step function to round to teh ground integer miltiple of stepSize
    function stepFunction(int256 x, int256 stepSize) public pure returns (int256) {
        require(stepSize > 0, "Step size must be greater than 0");
        if (x >= 0) {
            return x - (x % stepSize);
        } else {
            int256 remainder = x % stepSize;
            return remainder == 0 ? x : x - remainder - stepSize;
        }
    }

    // Math absolute function
    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }
  
    // Function to rasterize the edge of the polygon using the DDA algorithm
    // obs: x and y are already scaled by DECIMALS_FACTOR
    function rasterizeEdge(int256 lat1, int256 lon1, int256 lat2, int256 lon2, uint8 precision) public {
        require(lon1 >= MIN_LONGITUDE && lon1 <= MAX_LONGITUDE, "lon1 out of valid limits.");
        require(lat1 >= MIN_LATITUDE && lat1 <= MAX_LATITUDE, "lat1 out of valid limits.");
        require(lon2 >= MIN_LONGITUDE && lon2 <= MAX_LONGITUDE, "lon2 out of valid limits.");
        require(lat2 >= MIN_LATITUDE && lat2 <= MAX_LATITUDE, "lat2 out of valid limits.");
        
        bytes32 currentGeohash;
        Move memory move;

        // Handle point case
        if (lon1 == lon2 && lat1 == lat2) {
            currentGeohash = latLongToZOrderGeohash(lat1, lon1, precision);
            geohashMap[currentGeohash] = true;

        } else if (lon1 == lon2) {         // handle vertical edges
            move.lat = (lat2 > lat1) ? Direction.Up : Direction.Down;

            currentGeohash = latLongToZOrderGeohash(lat1, lon1, precision);
            geohashMap[currentGeohash] = true;
            while (currentGeohash != latLongToZOrderGeohash(lat2, lon2, precision)) {
                currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lat);
                geohashMap[currentGeohash] = true;
            }

        } else if (lat1 == lat2) {         // handle horizontal edges
            move.lon = (lon2 > lon1) ? Direction.Right : Direction.Left;

            currentGeohash = latLongToZOrderGeohash(lat1, lon1, precision);
            geohashMap[currentGeohash] = true;
            while (currentGeohash != latLongToZOrderGeohash(lat2, lon2, precision)) {
                currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lon);
                geohashMap[currentGeohash] = true;
            }

        } else {        // handle diagonal cases
            // Define the direction of movement based on the edge
            move.lat = (lat2 > lat1) ? Direction.Up : Direction.Down;
            move.lon = (lon2 > lon1) ? Direction.Right : Direction.Left;

            // Use the DDA algorithm to rasterize the edge (exclude the extreme points)
            // Start finding the first gridLat and gridLon positions
            int256 gridLat = lat1;
            int256 gridLon = lon1;

            // Take the first step to find the grid intersection for each axis
            if (move.lat == Direction.Up) {
                gridLat = stepFunction(gridLat, gridCellLatSize) + gridCellLatSize;
            } else {
                gridLat = stepFunction(gridLat, gridCellLatSize);
            }

            if (move.lon == Direction.Right) {
                gridLon = stepFunction(gridLon, gridCellLonSize) + gridCellLonSize;
            } else {
                gridLon = stepFunction(gridLon, gridCellLonSize);
            }

            // Calculate the square distance to the next grid intersection for each grid axis
            int256[] memory squareDistances = new int256[](3); // idx = 0 -> lat ; idx = 1 -> lon ; idx = 2 -> segment
            squareDistances[0] = squareDistance(lat1, lon1, gridLat, (lon1 + (lon2 - lon1) * (gridLat - lat1) / (lat2 - lat1)));
            squareDistances[1] = squareDistance(lat1, lon1, (lat1 + (lat2 - lat1) * (gridLon - lon1) / (lon2 - lon1)), gridLon);
            squareDistances[2] = squareDistance(lat1, lon1, lat2, lon2);

            // First segment geohash
            currentGeohash = latLongToZOrderGeohash((lat1 + gridLat) / 2, (lon1 + gridLon) / 2, precision);
            geohashMap[currentGeohash] = true;

            // Algorithm loop
            while (squareDistances[0] < squareDistances[2] || squareDistances[1] < squareDistances[2]) {        // guarantee that there is still one of the directions "inside" the segment
                // Move to the next grid intersection
                if (abs(squareDistances[0] - squareDistances[1]) <= 10) {        // Handle the grid intersection case with a little threshold
                    gridLat += (move.lat == Direction.Up) ? gridCellLatSize : -gridCellLatSize;
                    gridLon += (move.lon == Direction.Right) ? gridCellLonSize : -gridCellLonSize;
                    squareDistances[0] = squareDistance(lat1, lon1, gridLat, (lon1 + (lon2 - lon1) * (gridLat - lat1) / (lat2 - lat1)));
                    squareDistances[1] = squareDistance(lat1, lon1, (lat1 + (lat2 - lat1) * (gridLon - lon1) / (lon2 - lon1)), gridLon);

                    // Move in the diagonal and mark all quadrants
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lat);
                    geohashMap[currentGeohash] = true;
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lon);
                    geohashMap[currentGeohash] = true;

                    // mark the 4th quadrant as well
                    if (move.lat == Direction.Up) geohashMap[singleMoveGeohash(currentGeohash, precision, Direction.Down)] = true;
                    else geohashMap[singleMoveGeohash(currentGeohash, precision, Direction.Up)] = true;
                }
                else if (squareDistances[0] < squareDistances[1]) {    // Move in the latitude direction
                    gridLat += (move.lat == Direction.Up) ? gridCellLatSize : -gridCellLatSize;
                    squareDistances[0] = squareDistance(lat1, lon1, gridLat, (lon1 + (lon2 - lon1) * (gridLat - lat1) / (lat2 - lat1)));

                    currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lat);
                    geohashMap[currentGeohash] = true;

                } else if (squareDistances[0] > squareDistances[1]) {   // Move in the longitude direction
                    gridLon += (move.lon == Direction.Right) ? gridCellLonSize : -gridCellLonSize;
                    squareDistances[1] = squareDistance(lat1, lon1, (lat1 + (lat2 - lat1) * (gridLon - lon1) / (lon2 - lon1)), gridLon);

                    currentGeohash = singleMoveGeohash(currentGeohash, precision, move.lon);
                    geohashMap[currentGeohash] = true;

                }
            }


            // Include manually the extreme points (notice it doesn't matter if DDA already included them, because the function "geohashMap" will handle the uniqueness of the geohashes)
            geohashMap[latLongToZOrderGeohash(lat1, lon1, precision)] = true;
            geohashMap[latLongToZOrderGeohash(lat2, lon2, precision)] = true;
        }
    }

    // Helper functions such as converting (x, y) coordinates to grid cells, identifying unique geohashes, etc., can be added as needed
    // Auxiliar function to compute bounding box of the polygon
    function computeBoundingBox(int256[] memory latitudes, int256[] memory longitudes, uint8 precision) private view returns (BoundingBox memory) {
        require(latitudes.length == longitudes.length && latitudes.length > 0, "Arrays must be of equal length and non-empty");

        BoundingBox memory bbox = BoundingBox({
            minLat: latitudes[0],
            minLon: longitudes[0],
            maxLat: latitudes[0],
            maxLon: longitudes[0],
            geohashes: new bytes32[](3),    // the first is the bottom-left, the second is the top-left and the third is the top-right
            width: 1,
            height: 1
        });

        // Find the minimum and maximum latitudes and longitudes to determine the bounding box of the polygon
        for (uint i = 1; i < latitudes.length; i++) {
            if (latitudes[i] < bbox.minLat) bbox.minLat = latitudes[i];
            if (latitudes[i] > bbox.maxLat) bbox.maxLat = latitudes[i];
            if (longitudes[i] < bbox.minLon) bbox.minLon = longitudes[i];
            if (longitudes[i] > bbox.maxLon) bbox.maxLon = longitudes[i];
        }

        // Convert bounding box corners to geohashes
        bbox.geohashes[0] = latLongToZOrderGeohash(bbox.minLat, bbox.minLon, precision);
        bbox.geohashes[1] = latLongToZOrderGeohash(bbox.maxLat, bbox.minLon, precision);
        bbox.geohashes[2] = latLongToZOrderGeohash(bbox.maxLat, bbox.maxLon, precision);

        // Calculate how many geohashes the bounding box has (in x and y directions)
        bytes32 currentGeohash = bbox.geohashes[0];
        while (currentGeohash != bbox.geohashes[1]) {
            currentGeohash = singleMoveGeohash(currentGeohash, precision, Direction.Up);
            bbox.width++;
        }
        while (currentGeohash != bbox.geohashes[2]) {
            currentGeohash = singleMoveGeohash(currentGeohash, precision, Direction.Right);
            bbox.height++;
        }

        return bbox;
    }

    // Function to fill the interior of the polygon
    // it will consider that the edges are already rasterized in the map geohashesMap
    // This function utilizes the labelsToGeohash map. Remember to reset before use.
    // obs: x and y are already scaled by DECIMALS_FACTOR
    function fillPolygon(int256[] memory latitudes, int256[] memory longitudes, uint8 precision, BoundingBox memory bbox) internal {
        require(latitudes.length == longitudes.length, "Latitude and longitude arrays must have the same length");
        require(latitudes.length >= 3, "Polygon must have at least 3 vertices");
        require(precision <= geohashMaxPrecision, "Precision must be less than or equal to the maximum precision");

        // Inicialização de variáveis auxiliares
        uint256 i;
        uint256 j;
        uint256 count;

        int256 lat;
        int256 lon;

        bytes32 auxGeohash;
        bytes32 currentGeohash;

        Move memory move;
        
        // Segmentação inicial baseada em labels (preenchimento já deve ter sido feito aqui)

        // 1o loop para segmentar os labels. OBS: aqui, estamos aumentando a borda em 1, virtualmente, em cada direção, para facilitar a segmentação e eliminar mais rapidamente areas externas
        count = 0;  // sera usado como label atual
        for (i = 0; i < bbox.height + 2; i++) {
            if (i == 0) {
                // borda superior
                // preencher inteiramente com label = 0

                continue;
            } else if (i == bbox.height + 1) {
                // borda inferior

            }

            //etc

            for (j = 0; j < bbox.width + 2; j++) {
                if (j == 0) {
                    // borda esquerda
                    // preencher com label = 0
                    
                    continue;
                }

                //etc
            }
        }
        
        // 2o loop para identificar os labels equivalentes (basicamente simplificar o equivalencyList)
        for (i = 0; i < labelEquivalencyList.length; i++) {
            j = i;
            while (j != labelEquivalencyList[j]) {
                j = labelEquivalencyList[j];
            }
            labelEquivalencyList[i] = j;
        }

        // 3o loop para identificar os geohashes internos a partir dos labels candidatos
        for (i = 0; i < labelToGeohashes.length; i++) {
            // Verificar se o i-esimo label representa uma regiao interna. 
            // Podemos eliminar os labels que são equivalentes a 0, pois garantimos que estes são externos
            if (labelEquivalencyList[i] != 0) {
                continue;
            }

            // Assim, sobram apenas os labels que poderiam representar regiões internas
            // Se algum ponto do label for interno, marcar como true todos os geohashes referentes a este label
            // obs: aqui, é garantido que qualquer ponto deste geohash não está no traçado do poligono, pois o traçado ja foi rasterizado
            lat, lon = geohashToLatLong(labelToGeohashes[i][0], precision);

            // logica da semirreta e ccontar quantas vezes ha interseccao entre os edges e esta semirreta
            // se for impar, marcar como true todos os geohashes referentes a este label
            // se for par, entao este label nao representa uma regiao interna e podemos ir para o proximo label
            j = 0;
            count = 0;
            uint idx;

            // Handle with Vertexes possible cases of intersection with the ray
            for (j = 0; j < latitudes.length; j++) {
                if (lat == latitudes[j] && lon < longitudes[j]) {
                    // Verify if the first non-horizontal leftIndex-edge is up or down
                    idx = (j + latitudes.length - 1) % latitudes.length;
                    while (latitudes[idx] == latitudes[(idx + 1) % latitudes.length]) {
                        idx = (idx + latitudes.length - 1) % latitudes.length;      // decrementa um indice
                    }
                    move = Move({
                        lat: (latitudes[idx] < latitudes[(idx + 1) % latitudes.length]) ? Direction.Up : Direction.Down,
                        lon: Direction.Left // Doesn't matter in this case... could be anything
                    });

                    // Now let's verify if the first non-horizontal rightIndex-edge is up or down
                    idx = j;
                    while (latitudes[idx] == latitudes[(idx + 1) % latitudes.length]) {
                        idx = (idx + 1) % latitudes.length;      // incrementa um indice
                    }
                    // Now, if the lat direction is different from the previous one, we have an intersection. If it is the same, we don't have an intersection, it is just a peak vertex.
                    if (move.lat != ((latitudes[idx] < latitudes[(idx + 1) % latitudes.length]) ? Direction.Up : Direction.Down)) {
                        count++;
                    }
                }
            }

            // Handle with Edges as open-intervals (excluding vertexes)
            for (j = 0; j < latitudes.length; j++) {
                idx = (j + 1) % latitudes.length;
                Point memory p1 = Point({lat: latitudes[j], lon: longitudes[j]});
                Point memory p2 = Point({lat: latitudes[idx], lon: longitudes[idx]});

                // Handle with horizontal edges case. Remember it is impossible to be inside the edge itself, so we can skip it.
                if (p1.lat == p2.lat) {
                    continue;
                }

                move = Move({   // From 1 to 2
                    lat: (p2.lat > p1.lat) ? Direction.Up : Direction.Down,
                    lon: (p2.lon > p1.lon) ? Direction.Right : Direction.Left
                });

                // Conditions to check if the ray intersects the edge. If it does, increment the count.
                if ((move.lat == Direction.Up) ? (p1.lat < lat && lat < p2.lat) : (p2.lat < lat && lat < p1.lat)) {       // Include only cases where the ray are in the limits of the edge (latitudes)
                    if (p1.lon == p2.lon) {     // Handle with vertical edges case.
                        if (lon < p1.lon) {
                            count++;
                            continue;
                        }
                    } else {    // Diagonal edges case
                        // region I - rectangle region
                        if ((move.lon == Direction.Right) ? (lon < p1.lon) : (lon < p2.lon)) {
                            count++;
                            continue;
                        } 

                        // region II - triangle region
                        if (((move.lat == Direction.Up && move.lon == Direction.Right) || (move.lat == Direction.Down && move.lon == Direction.Left) ) ?
                                (lat - p1.lat) * (p2.lon - p1.lon) > (p2.lat - p1.lat) * (lon - p1.lon) : // 2o and 3o quadrants
                                (lat - p1.lat) * (p2.lon - p1.lon) < (p2.lat - p1.lat) * (lon - p1.lon)   // 1o and 4o quadrants
                            ) {
                            count++;
                            continue;
                        }
                    }
                }
            }

            // Verificar se o i-esimo label realmente é ou não uma regiao interna
            // Se for interno, marcar como true no geohashMap todos os geohashes referentes a este label
            // Se count é par, então este label não representa uma região interna e podemos ir para o próximo label
            if (count % 2 == 0) {
                continue;
            }

            // Aqui, o label é uma região interna. Marcar como true todos os geohashes referentes a este label
            for (j = 0; j < labelToGeohashes[i].length; j++) {
                currentGeohash = labelToGeohashes[i][j];
                geohashMap[currentGeohash] = true;
            }
        }

        // Resetar o labelToGeohash e olabelEquivalencyList antes de sair da funcao.
    }


    // Main function to process the polygon and return all encompassing geohashes
    // obs: latitudes and longitudes should be given in degrees and with the DECIMALS_FACTOR already applied
    function processPolygon(int256[] memory latitudes, int256[] memory longitudes, uint8 precision) external returns (bytes32[] memory comprehensiveGeohashes) {
        require(latitudes.length == longitudes.length, "Latitude and longitude arrays must have the same length");
        require(latitudes.length >= 3, "Polygon must have at least 3 vertices");
        require(precision <= geohashMaxPrecision, "Precision must be less than or equal to the maximum precision");

        /* BOUNDING BOX */
        // Determine the bounding box of the polygon to use in the fill algorithm
        // Find the minimum and maximum latitudes and longitudes to determine the bounding box of the polygon and convert it to geohashes
        BoundingBox memory bbox = computeBoundingBox(latitudes, longitudes, precision);

        /* RASTERIZE EDGES */
        // Rasterize all edges of the polygon to find edge geohashes
        uint256 numEdges = latitudes.length;
        for (uint i = 0; i < numEdges; i++) {
            uint idx = (i + 1) % numEdges;
            rasterizeEdge(latitudes[i], longitudes[i], latitudes[idx], longitudes[idx], precision);
        }

        // Fill the polygon, identifying all internal geohashes
        fillPolygon(latitudes, longitudes, precision, bbox);

        // Combine edge and internal geohashes, ensuring uniqueness (it is already combined since in both functions we are using the same map to store the geohashes)
        // Reset the geohashMap for the geohash-square used (defined by the bounding box)

        return comprehensiveGeohashes;
    }
}
