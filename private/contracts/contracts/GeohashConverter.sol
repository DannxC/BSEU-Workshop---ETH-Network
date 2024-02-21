// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GeohashConverter {
    // CONSTANTS
    uint256 constant public DECIMALS = 18;                  // Number of decimals to use for the geohash precision
    uint256 constant public DECIMALS_FACTOR = 10**DECIMALS; // Factor to scale the geohash precision to an integer
    // uint256 constant public PI = 3141592653589793238;       // Aproximação de PI com fator de escala 10^18 para trabalhar com inteiros
    // uint8 constant public GEOHASH_PRECISION;                // This sets geohash precision to a fixed value (0-16)
                                                            // OBS: For precision: 8 -> 7781.98 km² ; 12 -> 30,39 km² ; 14 -> 1,899 km² ; 16 -> 0,118 km²
    
    //mapping(uint8 => int256) public geohashPrecisionMap; // Example: This allows for dynamic precision
    mapping(bytes4 => bool) public geohashMap; // Map to store unique geohashes from the polygon processing algorithm result

    constructor (uint8 precision) {
        require (precision >= 0 && precision <= 16, "Precision must be between 1 and 16");      // Geohash is stored as a bytes4 (32 bits), so precision must be between 1 and 16 since each precision level adds 2 bits
        // GEOHASH_PRECISION = precision;
        // Initialize the geohash precision map
        // Example: geohashPrecisionMap[1] = 5000000; etc.
    }

    // CONSTANTS
    uint256 constant public DECIMALS = 18;                          // Number of decimals to use for the geohash precision
    int256 constant public DECIMALS_FACTOR = int256(10**DECIMALS);  // Factor to scale the geohash precision to an integer: 1000000000000000000
    int256 constant public MIN_LATITUDE  =  -90 * DECIMALS_FACTOR;
    int256 constant public MAX_LATITUDE  =   90 * DECIMALS_FACTOR;
    int256 constant public MIN_LONGITUDE = -180 * DECIMALS_FACTOR;
    int256 constant public MAX_LONGITUDE =  180 * DECIMALS_FACTOR;
    enum Direction {        // used in the moveGeohash function
        Up,
        Down,
        Left,
        Right
    }


    // uint256 constant public PI = 3141592653589793238;       // Aproximação de PI com fator de escala 10^18 para trabalhar com inteiros
    // uint8 constant public GEOHASH_PRECISION;                // This sets geohash precision to a fixed value (0-16)
                                                            // OBS: For precision: 8 -> 7781.98 km² ; 12 -> 30,39 km² ; 14 -> 1,899 km² ; 16 -> 0,118 km²
    
    //mapping(uint8 => int256) public geohashPrecisionMap; // Example: This allows for dynamic precision
    mapping(bytes4 => bool) public geohashMap; // Map to store unique geohashes from the polygon processing algorithm result

    constructor (uint8 precision) {
        require (precision >= 0 && precision <= 16, "Precision must be between 1 and 16");      // Geohash is stored as a bytes4 (32 bits), so precision must be between 1 and 16 since each precision level adds 2 bits
        //GEOHASH_PRECISION = precision;
        // Initialize the geohash precision map
        // Example: geohashPrecisionMap[1] = 5000000; etc.
    }

    // Function to convert a latitude and longitude pair into a geohash (parameters should be given in degrees and with the DECIMALS_FACTOR already applied)
    function latLongToZOrderGeohash(int256 lat, int256 lon, uint8 precision) public pure returns (bytes32) {
        require(lat >= MIN_LATITUDE && lat <= MAX_LATITUDE, "Latitude out of valid limits.");
        require(lon >= MIN_LONGITUDE && lon <= MAX_LONGITUDE, "Longitude out of valid limits.");

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

    // Additional helper function to handle the directional movement based on steps
    // This is a placeholder for the logic required to actually compute these movements.
    function singleMoveGeohash(bytes32 _geohash, uint8 precision, Direction _direction) public pure returns (bytes32) {
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

    // Function to rasterize the edge of the polygon using the DDA algorithm
    function rasterizeEdge(int256 x0, int256 y0, int256 x1, int256 y1) internal pure returns () {
        // Handle horizontal and vertical edges separetely
        if (x0 == x1) {
            // handle vertical edge
            return;
        }
        if (y0 == y1) {
            // handle horizontal edge
            return;
        }

        // Define the direction of movement based on the edge
        const string X_MOVE = (x1 > x0) ? "RIGHT" : "LEFT";
        const string Y_MOVE = (y1 > y0) ? "UP" : "DOWN";

        // Use the DDA algorithm to rasterize the edge

    }

    // Function to fill the interior of the polygon
    function fillPolygon(string[] memory edgeGeohashes, int256 minX, int256 minY, int256 maxX, int256 maxY) internal pure returns (string[] memory) {
        // Placeholder for the polygon filling algorithm
        // Should return a list of geohashes that are inside the polygon
    }

    // Main function to process the polygon and return all encompassing geohashes
    function processPolygon(int256[] memory latitudes, int256[] memory longitudes) external pure returns (string[] memory) {
        // Rasterize all edges of the polygon to find edge geohashes
        // Determine the bounding box of the polygon to use in the fill algorithm
        // Fill the polygon, identifying all internal geohashes
        // Combine edge and internal geohashes, ensuring uniqueness
        // Return the comprehensive list of geohashes
    }

    // Helper functions such as converting (x, y) coordinates to grid cells, identifying unique geohashes, etc., can be added as needed
}
