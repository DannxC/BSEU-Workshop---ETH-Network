// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DSS_Storage {
    /* EVENTS */

    // Events defined to track data additions, updates, and deletions
    event DataAdded(uint indexed id, string geohash, address indexed addedBy);
    event DataUpdated(uint indexed id, string geohash, address indexed updatedBy);
    event DataDeleted(uint indexed id, string geohash, address indexed deletedBy);


    /* STRUCTS */
    struct HeightInterval {
        uint min;
        uint max;
    }

    struct TimeInterval {       // Timezone considered is UTC (Coordinated Universal Time)
        uint start;             // Notice: Timestamps are in seconds and represent time since 1970-01-01 00:00:00 UTC (Unix epoch time)
        uint end;
    }

    struct ResourceInfo {
        string url;
        uint entityNumber;
        uint id;                // id must be greater than 0
    }

    struct ChunkData {
        address addedBy;
        HeightInterval height;
        TimeInterval time;
        ResourceInfo resourceInfo;
    }


    /* INDEXES */

    // Here, only the active data must be stored. Inactive data must be deleted from the both mappings.
    // OBS: IDs that was deleted will be considered as inexistent in the future, so it's not necessary to store them in a separate mapping. If necessary, users can reuse the same ID, but it's not recommended.
    mapping(uint => string[]) public idToGeohash;                       // Mapping from id to geohash
    mapping(string => ChunkData[]) public geohashToChunkDataArray;      // Mapping from geohash to an array of ChunkData (don't need to be an ordered aray)

    mapping(address => bool) public allowedUsers;       // State to store allowed users

    address public owner;       // Contract owner address


    /* MODIFIERS */

    // Modifier to restrict calls only by allowed users
    modifier onlyAllowed {
        require(allowedUsers[msg.sender], "User not allowed");
        _;
    }

    // Modifier to restrict calls only by the owner
    modifier onlyOwner {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Add a user to the allowedUsers mapping
    function allowUser(address _user) public onlyOwner {
        allowedUsers[_user] = true;
    }

    // Remove a user to the allowedUsers mapping
    function disallowUser(address _user) public onlyOwner {
        allowedUsers[_user] = false;
    }

    // Function to change the owner of the contract
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }


    /* CONSTRUCTOR */

    // Constructor to set the deployer as the owner
    constructor() {
        owner = msg.sender;
        allowUser(owner);
    }


    /* UTILS */

    // no functions needed to be implemented until now


    /* UPSERT */

    // Function to add/update a new Polygon, which is a set of geohashes and its corresponding ChunkData
    // Here, one polygon is a part of a full route
    function upsertPolygonData (
        string[] memory _geohashes,
        uint _minHeight,
        uint _maxHeight,
        uint _startTime,
        uint _endTime,
        string memory _url,
        uint _entity,
        uint _id
    ) 
        public onlyAllowed
    {
        require(_geohashes.length > 0, "No geohashes provided");
        require(_maxHeight >= _minHeight, "Max height must be greater than or equal to min height");
        require(_startTime < _endTime, "Start time must be less than end time");

        // Create the necessary structs to compose the ChunkData to be added to the geohashToChunkDataArray mapping
        HeightInterval memory height = HeightInterval({min: _minHeight, max: _maxHeight});
        TimeInterval memory time = TimeInterval({start: _startTime, end: _endTime});
        ResourceInfo memory resourceInfo = ResourceInfo({url: _url, entityNumber: _entity, id: _id});
        ChunkData memory newChunkData = ChunkData({addedBy: msg.sender, height: height, time: time, resourceInfo: resourceInfo});   // Create the new ChunkData

        // Map old geohashes for the given id. Needed to update and delete the old geohashes that are not in the new polygon
        string[] memory oldGeohashes = idToGeohash[_id];                        // get the old geohashes for the given id
        bool[] memory oldGeohashesUpdated = new bool[](oldGeohashes.length);    // temporary array to mark the updated geohashes in runtime (refers to the old geohashes)

        // Update and insert new geohashes, depending if they are already in the old polygon or not (collision check)
        for (uint i = 0; i < _geohashes.length; i++) {      // Iterate over new hashes for the given id
            string memory currentNewGeohash = _geohashes[i];
            bool exists = false;

            for (uint j = 0; j < oldGeohashes.length; j++) {    // Iterate over old hashes for the given id
                string memory currentOldGeohash = oldGeohashes[j];

                // Update the old geohashes that are in the new polygon
                if (keccak256(abi.encodePacked(currentNewGeohash)) == keccak256(abi.encodePacked(currentOldGeohash))) {
                    exists = true;
                    oldGeohashesUpdated[j] = true; // Mark the updated geohash in the temporary array
                    updateChunkData(currentNewGeohash, newChunkData);
                    break;
                }
            }

            // Insert the new geohashes that are not in the old polygon
            if (!exists) {
                insertChunkData(currentNewGeohash, newChunkData);
            }
        }

        // Delete the old geohashes that are not in the new polygon
        for (uint i = 0; i < oldGeohashes.length; i++) {
            if (!oldGeohashesUpdated[i]) {
                deleteChunkData(_id, oldGeohashes[i]);
            }
        }
    }


    /* INSERT */

    // Function to add new ChunkData
    function insertChunkData (
        string memory _geohash, 
        ChunkData memory _chunkData
    ) 
        private onlyAllowed
    {
        uint currentId = _chunkData.resourceInfo.id;

        // Add the id to the idToGeohash mapping and the ChunkData to the geohashToChunkDataArray mapping
        idToGeohash[currentId].push(_geohash);
        geohashToChunkDataArray[_geohash].push(_chunkData);
        emit DataAdded(currentId, _geohash, msg.sender);
    }


    /* UPDATE */

    // Function to update a single ChunkData
    function updateChunkData(
        string memory _geohash, 
        ChunkData memory _chunkData
    ) 
        private onlyAllowed
    {
        if (_chunkData.addedBy != msg.sender) {
            return;
        }

        uint currentId = _chunkData.resourceInfo.id;
        require(idToGeohash[currentId].length > 0, "No data to be updated for the given id");

        // Iterate over the array of ChunkData for the given geohash and update the data for the given id
        ChunkData[] storage currentChunkDataArray = geohashToChunkDataArray[_geohash];
        for (uint i = 0; i < currentChunkDataArray.length; i++) {
            if (currentChunkDataArray[i].resourceInfo.id == currentId) {
                currentChunkDataArray[i].height = _chunkData.height;
                currentChunkDataArray[i].time = _chunkData.time;
                currentChunkDataArray[i].resourceInfo = _chunkData.resourceInfo;
                break;
            }
        }
        
        emit DataUpdated(currentId, _geohash, msg.sender);
    }


    /* DELETE */

    // Function to delete a Batch of ChunkData by its ids
    function deletePolygonData(uint[] memory _ids) public onlyAllowed {
        require(_ids.length > 0, "No ids provided");

        // Delete the ChunkData for each geohash for each id
        for (uint i = 0; i < _ids.length; i++) {
            uint currentId = _ids[i];
            string[] memory currentGeohashes = idToGeohash[currentId];

            for (uint j = 0; j < currentGeohashes.length; j++) {
                deleteChunkData(currentId, currentGeohashes[j]);
            }
        }
    }

    // Function to remove a ChunkData from the array of a given geohash by its id
    function deleteChunkData(uint _id, string memory _geohash) private {
        ChunkData[] storage currentChunkDataArray = geohashToChunkDataArray[_geohash];
        string[] storage currentGeohashes = idToGeohash[_id];

        // Delete from geohashToChunkDataArray the specific ChunkData
        for (uint i = 0; i < currentChunkDataArray.length; i++) {
            ChunkData storage currentChunkData = currentChunkDataArray[i];
            if (currentChunkData.resourceInfo.id == _id) {
                if (currentChunkData.addedBy != msg.sender) {
                    return;
                }
                currentChunkData = currentChunkDataArray[currentChunkDataArray.length - 1]; // Move the last element to the position of the element to be deleted
                currentChunkDataArray.pop();    // Delete the last element
                break;
            }
        }

        // Delete from idtoGeohash mapping the specific geohash
        for (uint i = 0; i < currentGeohashes.length; i++) {
            string storage currentGeohash = currentGeohashes[i];
            if (keccak256(abi.encodePacked(currentGeohash)) == keccak256(abi.encodePacked(_geohash))) {
                currentGeohash = currentGeohashes[currentGeohashes.length - 1]; // Move the last element to the position of the element to be deleted
                currentGeohashes.pop();    // Delete the last element
                break;
            }
        }

        emit DataDeleted(_id, _geohash, msg.sender);
    }


    /* RETRIEVE */

    // Function to retrieve data for a given geohash, height interval and time interval. Parameters works as filters.
    function getData(
        string memory _geohash, 
        uint _minHeight, 
        uint _maxHeight, 
        uint _startTime, 
        uint _endTime
    ) 
        public view 
        returns (
            string[] memory urls, 
            uint[] memory entityNumbers, 
            uint[] memory ids
        ) 
    {
        require(_maxHeight >= _minHeight, "Max height must be greater than or equal to min height");
        require(_startTime < _endTime, "Start time must be less than end time");

        // Get the array of ChunkData for the given geohash
        ChunkData[] storage currentChunkDataArray = geohashToChunkDataArray[_geohash];

        // Determine how many elements satisfy the criteria to allocate memory for the arrays
        uint count = 0;
        for (uint i = 0; i < currentChunkDataArray.length; i++) {
            ChunkData storage currentChunkData = currentChunkDataArray[i];
            if (currentChunkData.height.min <= _maxHeight && currentChunkData.height.max >= _minHeight && 
                currentChunkData.time.start < _endTime && currentChunkData.time.end > _startTime) {
                count++;
            }
        }

        // Alocate memory for the arrays
        urls = new string[](count);
        entityNumbers = new uint[](count);
        ids = new uint[](count);

        // Fill the arrays with the data that satisfies the criteria
        uint j = 0;
        for (uint i = 0; i < currentChunkDataArray.length && j < count; i++) {
            ChunkData storage currentChunkData = currentChunkDataArray[i];
            if (currentChunkData.height.min <= _maxHeight && currentChunkData.height.max >= _minHeight && 
                currentChunkData.time.start < _endTime && currentChunkData.time.end > _startTime) {
                urls[j] = currentChunkData.resourceInfo.url;
                entityNumbers[j] = currentChunkData.resourceInfo.entityNumber;
                ids[j] = currentChunkData.resourceInfo.id;
                j++;
            }
        }

        return (urls, entityNumbers, ids);
    }

    // Revert fallback and receive functions
    fallback() external {
        revert();
    }

    receive() external payable {
        revert();
    }
}
