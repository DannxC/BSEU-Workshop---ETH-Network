// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DSS_Storage {
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

    // Function to add new ChunkData
    function inputData (
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
        ChunkData memory newChunkData = ChunkData({height: height, time: time, resourceInfo: resourceInfo});

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

        uint count = 0; // Counter to determine how much memory to allocate
        ChunkData[] storage currentChunkDataArray = geohashToChunkDataArray[_geohash];

        // Determine how many elements satisfy the criteria
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
