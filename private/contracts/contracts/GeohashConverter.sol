// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GeohashConverter {
    // CONSTANTS
    uint256 constant public DECIMALS = 18;                          // Number of decimals to use for the geohash precision
    int256 constant public DECIMALS_FACTOR = int256(10**DECIMALS);  // Factor to scale the geohash precision to an integer: 1000000000000000000
    // uint256 constant public PI = 3141592653589793238;       // Aproximação de PI com fator de escala 10^18 para trabalhar com inteiros
    uint8 immutable public GEOHASH_MAX_PRECISION;                // This sets geohash precision to a fixed value (0-16)
                                                            // OBS: For precision: 8 -> 7781.98 km² ; 12 -> 30,39 km² ; 14 -> 1,899 km² ; 16 -> 0,118 km²
    int256 immutable public gridCellLatSize;
    int256 immutable public gridCellLonSize;

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
    struct BoundingBox {
        int256 minLat;
        int256 minLon;
        int256 maxLat;
        int256 maxLon;
    }

    
    //mapping(uint8 => int256) public geohashPrecisionMap; // Example: This allows for dynamic precision
    mapping(bytes32 => bool) public geohashMap; // Map to store unique geohashes from the polygon processing algorithm result

    constructor (uint8 precision) {
        require (precision <= 16, "Maximum precision must be less then 16");      // Geohash is stored as a bytes4 (32 bits), so precision must be between 1 and 16 since each precision level adds 2 bits
        GEOHASH_MAX_PRECISION = precision;
        gridCellLatSize = (MAX_LATITUDE - MIN_LATITUDE) / int256(2**precision);
        gridCellLonSize = (MAX_LONGITUDE - MIN_LONGITUDE) / int256(2**precision);
        // Initialize the geohash precision map
        // Example: geohashPrecisionMap[1] = 5000000; etc.
    }


    // Function to convert a latitude and longitude pair into a geohash (parameters should be given in degrees and with the DECIMALS_FACTOR already applied)
    function latLongToZOrderGeohash(int256 lat, int256 lon, uint8 precision) public view returns (bytes32) {
        require(lat >= MIN_LATITUDE && lat <= MAX_LATITUDE, "Latitude out of valid limits.");
        require(lon >= MIN_LONGITUDE && lon <= MAX_LONGITUDE, "Longitude out of valid limits.");
        require(precision <= GEOHASH_MAX_PRECISION, "Precision must be less than or equal to the maximum precision");

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
    function singleMoveGeohash(bytes32 _geohash, uint8 precision, Direction _direction) public view returns (bytes32) {
        require(precision <= GEOHASH_MAX_PRECISION, "Precision must be less than or equal to the maximum precision");

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

    // Function to fill the interior of the polygon
    // obs: x and y are already scaled by DECIMALS_FACTOR
    function fillPolygon(string[] memory edgeGeohashes, int256 minX, int256 minY, int256 maxX, int256 maxY) internal pure returns (string[] memory) {
        // Placeholder for the polygon filling algorithm
        // Should return a list of geohashes that are inside the polygon
    }

    // Distance between two lattitude and longitude points (approximation in 2D plane, not the real distance in the sphere)
    // OBS: We are calculating the distance in a 2D plane, so it is not the real distance in the sphere
    function latLongSquareDistance(int256 lat1, int256 lon1, int256 lat2, int256 lon2) public pure returns (int256) {
        require(lon1 >= MIN_LONGITUDE && lon1 <= MAX_LONGITUDE, "lon1 out of valid limits.");
        require(lat1 >= MIN_LATITUDE && lat1 <= MAX_LATITUDE, "lat1 out of valid limits.");
        require(lon2 >= MIN_LONGITUDE && lon2 <= MAX_LONGITUDE, "lon2 out of valid limits.");
        require(lat2 >= MIN_LATITUDE && lat2 <= MAX_LATITUDE, "lat2 out of valid limits.");

        int256 dLat = lat2 - lat1;
        int256 dLon = lon2 - lon1;

        return dLat * dLat + dLon * dLon;
    }

    // Math step function to round to teh ground integer miltiple of stepSize
    function stepFunction(int256 x, int256 stepSize) public pure returns (int256) {
        require(stepSize > 0, "Step size must be greater than 0");
        if (x >= 0) {
            return x - (x % stepSize);
        } else {
            return x - (x % stepSize) - stepSize;
        }
    }

    // Function to rasterize the edge of the polygon using the DDA algorithm
    // obs: x and y are already scaled by DECIMALS_FACTOR
    function rasterizeEdge(int256 lat1, int256 lon1, int256 lat2, int256 lon2, uint8 precision) internal returns (bytes32[] memory edgeGeohashes) {
        require(lon1 >= MIN_LONGITUDE && lon1 <= MAX_LONGITUDE, "lon1 out of valid limits.");
        require(lat1 >= MIN_LATITUDE && lat1 <= MAX_LATITUDE, "lat1 out of valid limits.");
        require(lon2 >= MIN_LONGITUDE && lon2 <= MAX_LONGITUDE, "lon2 out of valid limits.");
        require(lat2 >= MIN_LATITUDE && lat2 <= MAX_LATITUDE, "lat2 out of valid limits.");
        
        bytes32 currentGeohash;
        Direction LAT_MOVE;
        Direction LON_MOVE;

        // Handle point case
        if (lon1 == lon2 && lat1 == lat2) {
            edgeGeohashes = new bytes32[](1);
            edgeGeohashes[0] = latLongToZOrderGeohash(lat1, lon1, precision);
            return edgeGeohashes;
        }

        bytes32 finalGeohash = latLongToZOrderGeohash(lat2, lon2, precision);
        // Handle horizontal and vertical edges separetely
        if (lon1 == lon2) {         // handle vertical edges
            LAT_MOVE = (lat2 > lat1) ? Direction.Up : Direction.Down;

            currentGeohash = latLongToZOrderGeohash(lat1, lon1, precision);
            geohashMap[currentGeohash] = true;
            while (currentGeohash != finalGeohash) {
                currentGeohash = singleMoveGeohash(currentGeohash, precision, LAT_MOVE);
                geohashMap[currentGeohash] = true;
            }

            return edgeGeohashes;
        }
        if (lat1 == lat2) {         // handle horizontal edges
            LON_MOVE = (lon2 > lon1) ? Direction.Right : Direction.Left;

            currentGeohash = latLongToZOrderGeohash(lat1, lon1, precision);
            geohashMap[currentGeohash] = true;
            while (currentGeohash != finalGeohash) {
                currentGeohash = singleMoveGeohash(currentGeohash, precision, LON_MOVE);
                geohashMap[currentGeohash] = true;
            }

            return edgeGeohashes;
        }

        // Define the direction of movement based on the edge
        LAT_MOVE = (lat2 > lat1) ? Direction.Up : Direction.Down;
        LON_MOVE = (lon2 > lon1) ? Direction.Right : Direction.Left;
        

        // Use the DDA algorithm to rasterize the edge (exclude the extreme points)
        // Start finding the first gridLat and gridLon positions
        int256 gridLat = lat1;
        int256 gridLon = lon1;

        // Take the first step to find the grid intersection for each axis
        if (LAT_MOVE == Direction.Up) {
            gridLat = stepFunction(gridLat, gridCellLatSize) + gridCellLatSize;
        } else {
            gridLat = stepFunction(gridLat, gridCellLatSize);
        }

        if (LON_MOVE == Direction.Right) {
            gridLon = stepFunction(gridLon, gridCellLonSize) + gridCellLonSize;
        } else {
            gridLon = stepFunction(gridLon, gridCellLonSize);
        }

        // Slope of the segment and calculate the square distance to the next grid intersection for each grid axis
        int256 m = (lat2 - lat1) * DECIMALS_FACTOR / (lon2 - lon1);  // dLat / dLon

        // Calculate the square distance to the next grid intersection for each grid axis
        int256 latSquareDistance = latLongSquareDistance(lat1, lon1, gridLat, (lon1 + (1/m) * (gridLat - lat1)));
        int256 lonSquareDistance = latLongSquareDistance(lat1, lon1, (lat1 + m * (gridLon - lon1)), gridLon);

        // First segment geohash
        currentGeohash = latLongToZOrderGeohash((lat1 + gridLat) / 2, (lon1 + gridLon) / 2, precision);
        geohashMap[currentGeohash] = true;

        // Algorithm loop
        while (gridLat < lat2 || gridLon < lon2) {
            // Move to the next grid intersection
            if (latSquareDistance < lonSquareDistance) {    // Move in the latitude direction
                gridLat += (LAT_MOVE == Direction.Up) ? gridCellLatSize : -gridCellLatSize;
                latSquareDistance = latLongSquareDistance(lat1, lon1, gridLat, (lon1 + (1/m) * (gridLat - lat1)));

                currentGeohash = singleMoveGeohash(currentGeohash, precision, LAT_MOVE);
                geohashMap[currentGeohash] = true;

            } else if (latSquareDistance > lonSquareDistance) {   // Move in the longitude direction
                gridLon += (LON_MOVE == Direction.Right) ? gridCellLonSize : -gridCellLonSize;
                lonSquareDistance = latLongSquareDistance(lat1, lon1, (lat1 + m * (gridLon - lon1)), gridLon);

                currentGeohash = singleMoveGeohash(currentGeohash, precision, LON_MOVE);
                geohashMap[currentGeohash] = true;

            } else {    // Move in both directions (diagonal)
                gridLat += (LAT_MOVE == Direction.Up) ? gridCellLatSize : -gridCellLatSize;
                gridLon += (LON_MOVE == Direction.Right) ? gridCellLonSize : -gridCellLonSize;
                latSquareDistance = latLongSquareDistance(lat1, lon1, gridLat, (lon1 + (1/m) * (gridLat - lat1)));
                lonSquareDistance = latLongSquareDistance(lat1, lon1, (lat1 + m * (gridLon - lon1)), gridLon);

                // Verify wich diagonal to move and the direction of the movement
                if ((LAT_MOVE == Direction.Up && LON_MOVE == Direction.Left)) {         // Move up and then left (convention)
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LAT_MOVE);
                    geohashMap[currentGeohash] = true;
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LON_MOVE);
                    geohashMap[currentGeohash] = true;
                } else if ((LAT_MOVE == Direction.Down && LON_MOVE == Direction.Right)) {   // Move down and then right (convention)
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LON_MOVE);
                    geohashMap[currentGeohash] = true;
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LAT_MOVE);
                    geohashMap[currentGeohash] = true;
                } else {    // Directly move to the diagonal
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LAT_MOVE);
                    currentGeohash = singleMoveGeohash(currentGeohash, precision, LON_MOVE);
                    geohashMap[currentGeohash] = true;
                }
            }
        }


        // Include manually the extreme points (notice it doesn't matter if DDA already included them, because the function "geohashMap" will handle the uniqueness of the geohashes)
        geohashMap[latLongToZOrderGeohash(lat1, lon1, precision)] = true;
        geohashMap[latLongToZOrderGeohash(lat2, lon2, precision)] = true;

        return edgeGeohashes;
    }

    // Helper functions such as converting (x, y) coordinates to grid cells, identifying unique geohashes, etc., can be added as needed
    // Auxiliar function to compute bounding box of the polygon
    function computeBoundingBox(int256[] memory latitudes, int256[] memory longitudes) private pure returns (BoundingBox memory) {
        require(latitudes.length == longitudes.length && latitudes.length > 0, "Arrays must be of equal length and non-empty");

        BoundingBox memory bbox = BoundingBox({
            minLat: latitudes[0],
            minLon: longitudes[0],
            maxLat: latitudes[0],
            maxLon: longitudes[0]
        });

        for (uint i = 1; i < latitudes.length; i++) {
            if (latitudes[i] < bbox.minLat) bbox.minLat = latitudes[i];
            if (latitudes[i] > bbox.maxLat) bbox.maxLat = latitudes[i];
            if (longitudes[i] < bbox.minLon) bbox.minLon = longitudes[i];
            if (longitudes[i] > bbox.maxLon) bbox.maxLon = longitudes[i];
        }

        return bbox;
    }

    // Main function to process the polygon and return all encompassing geohashes
    // obs: latitudes and longitudes should be given in degrees and with the DECIMALS_FACTOR already applied
    function processPolygon(int256[] memory latitudes, int256[] memory longitudes, uint8 precision) external returns (bytes32[] memory) {
        require(latitudes.length == longitudes.length, "Latitude and longitude arrays must have the same length");
        require(latitudes.length >= 3, "Polygon must have at least 3 vertices");
        require(precision <= GEOHASH_MAX_PRECISION, "Precision must be less than or equal to the maximum precision");

        bytes32[] memory comprehensiveGeohashes;

        /* BOUNDING BOX */
        // Determine the bounding box of the polygon to use in the fill algorithm
        // Find the minimum and maximum latitudes and longitudes to determine the bounding box of the polygon and convert it to geohashes
        BoundingBox memory bbox = computeBoundingBox(latitudes, longitudes);

        // Convert bounding box corners to geohashes
        bytes32[] memory boundingBoxGeohashes = new bytes32[](3);
        boundingBoxGeohashes[0] = latLongToZOrderGeohash(bbox.minLat, bbox.minLon, precision);
        boundingBoxGeohashes[1] = latLongToZOrderGeohash(bbox.maxLat, bbox.minLon, precision);
        boundingBoxGeohashes[2] = latLongToZOrderGeohash(bbox.maxLat, bbox.maxLon, precision);

        // Calculate how many geohashes the bounding box has (in x and y directions)
        uint256 boundingBoxWidth = 1;
        uint256 boundingBoxHeight = 1;
        bytes32 currentGeohash = boundingBoxGeohashes[0];
        while (currentGeohash != boundingBoxGeohashes[1]) {
            currentGeohash = singleMoveGeohash(currentGeohash, precision, Direction.Up);
            boundingBoxWidth++;
        }
        while (currentGeohash != boundingBoxGeohashes[2]) {
            currentGeohash = singleMoveGeohash(currentGeohash, precision, Direction.Right);
            boundingBoxHeight++;
        }

        /* RASTERIZE EDGES */
        // Rasterize all edges of the polygon to find edge geohashes
        uint256 numEdges = latitudes.length;
        for (uint i = 0; i < numEdges; i++) {
            uint latIdx = (i + 1) % numEdges;
            rasterizeEdge(latitudes[i], longitudes[i], latitudes[latIdx], longitudes[latIdx], precision);
        }

        // Fill the polygon, identifying all internal geohashes
        // Combine edge and internal geohashes, ensuring uniqueness (it is already combined since in both functions we are using the same map to store the geohashes)
        // Return the comprehensive list of geohashes and reset the geohashMap for the geohash-square used (defined by the bounding box)

        return comprehensiveGeohashes;
    }
}
