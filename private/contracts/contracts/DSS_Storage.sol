// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DSS_Storage {
    // Events defined to track data additions, updates, and deletions
    event DataAdded(uint indexed id, string geohash, address indexed addedBy);
    event DataUpdated(uint indexed id, string geohash, address indexed updatedBy);
    event DataDeleted(uint indexed id, string geohash, address indexed deletedBy);

    // Structs to store the data
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
        uint id;
    }

    struct ChunkData {
        address addedBy;
        HeightInterval height;
        TimeInterval time;
        ResourceInfo resourceInfo;
    }

    // Mapping from geohash to an array of ChunkData
    mapping(string => ChunkData[]) public geohashToChunkDataArray;

    // State to store allowed users
    mapping(address => bool) public allowedUsers;

    // Contract owner address
    address public owner;

    // Constructor to set the deployer as the owner
    constructor() {
        // Defining the deployer as owner
        owner = msg.sender;
        allowUser(owner);
    }

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

    // Function to add a Batch of new ChunkData
    function insertDataBatch (
        string[] memory _geohashes,
        uint[] memory _minHeights,
        uint[] memory _maxHeights,
        uint[] memory _startTimes,
        uint[] memory _endTimes,
        string[] memory _urls,
        uint[] memory _entities,
        uint[] memory _ids
    ) 
        public onlyAllowed
    {
        require(
            _geohashes.length == _minHeights.length &&
            _geohashes.length == _maxHeights.length &&
            _geohashes.length == _startTimes.length &&
            _geohashes.length == _endTimes.length &&
            _geohashes.length == _urls.length &&
            _geohashes.length == _entities.length &&
            _geohashes.length == _ids.length,
            "Input arrays must have the same length"
        );

        for (uint i = 0; i < _geohashes.length; i++) {
            insertSingleData(_geohashes[i], _minHeights[i], _maxHeights[i], _startTimes[i], _endTimes[i], _urls[i], _entities[i], _ids[i]);
        }
    }

    // Function to add new ChunkData
    function insertSingleData (
        string memory _geohash, 
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
        require(_maxHeight >= _minHeight, "Max height must be greater than or equal to min height");
        require(_startTime < _endTime, "Start time must be less than end time");

        HeightInterval memory height = HeightInterval({min: _minHeight, max: _maxHeight});
        TimeInterval memory time = TimeInterval({start: _startTime, end: _endTime});
        ResourceInfo memory resourceInfo = ResourceInfo({url: _url, entityNumber: _entity, id: _id});
        ChunkData memory newChunkData = ChunkData({addedBy: msg.sender, height: height, time: time, resourceInfo: resourceInfo});

        emit DataAdded(_id, _geohash, msg.sender);
        geohashToChunkDataArray[_geohash].push(newChunkData);
    }

    // Function to return multiple fields of the first matching ChunkData
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

    // Function to remove a ChunkData from the array of a given geohash by its id
    function deleteData(string memory _geohash, uint _id) public onlyAllowed {
        require(geohashToChunkDataArray[_geohash].length > 0, "No data for the given geohash");
        require(_id > 0, "Id must be greater than 0");

        // Get the array of ChunkData for the given geohash
        ChunkData[] storage currentChunkDataArray = geohashToChunkDataArray[_geohash];

        // Find the index of the element to be deleted
        uint i;
        for (i = 0; i < currentChunkDataArray.length; i++) {
            if (currentChunkDataArray[i].resourceInfo.id == _id) {
                break;
            }
        }
        require(i < currentChunkDataArray.length, "No data for the given id");

        emit DataDeleted(_id, _geohash, msg.sender);

        // Move the last element to the position of the element to be deleted
        currentChunkDataArray[i] = currentChunkDataArray[currentChunkDataArray.length - 1];

        // Delete the last element
        currentChunkDataArray.pop();
    }

    // Revert fallback and receive functions
    fallback() external {
        revert();
    }

    receive() external payable {
        revert();
    }
}
