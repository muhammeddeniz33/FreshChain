// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract FreshChain {
    
    // --- Roles ---
    address public owner;
    mapping(address => bool) public farmers; 
    mapping(address => bool) public transporters;
    mapping(address => bool) public distributors;
    mapping(address => bool) public retailers;

    // --- Structs ---
    struct SensorLog {
        uint timestamp;
        int temperature;
        int humidity;
        string location;
        address recordedBy;
    }

    struct Batch {
        uint batchId;
        string productName;
        uint quantity;
        address currentOwner;
        address farmer; 
        bool isArrived;
        bool passedInspection;
        SensorLog[] sensorLogs; // History of environmental data
        address[] ownershipHistory; // History of owners
    }

    // --- State ---
    mapping(uint => Batch) public batches;
    mapping(uint => bool) public batchExists;

    // --- Events ---
    event BatchCreated(uint indexed batchId, string productName, address indexed farmer); 
    event SensorDataAdded(uint indexed batchId, int temperature, int humidity, string location);
    event OwnershipTransferred(uint indexed batchId, address indexed previousOwner, address indexed newOwner);
    event BatchArrived(uint indexed batchId, bool passedInspection, address indexed retailer);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only Admin can call this");
        _;
    }

    modifier onlyFarmer() { 
        require(farmers[msg.sender], "Caller is not a registered Farmer");
        _;
    }

    modifier onlyTransporter() {
        require(transporters[msg.sender], "Caller is not a registered Transporter");
        _;
    }

    modifier onlyRetailer() {
        require(retailers[msg.sender], "Caller is not a registered Retailer");
        _;
    }

    constructor() {
        owner = msg.sender; // The deployer is the Admin
    }

    // --- 1. Register Actors ---
    function registerFarmer(address _farmer) external onlyOwner { 
        farmers[_farmer] = true;
    }

    function registerTransporter(address _transporter) external onlyOwner {
        transporters[_transporter] = true;
    }

    function registerDistributor(address _distributor) external onlyOwner {
        distributors[_distributor] = true;
    }

    function registerRetailer(address _retailer) external onlyOwner {
        retailers[_retailer] = true;
    }

    // --- 2. Create Product Batch ---
    function createBatch(uint _batchId, string memory _productName, uint _quantity) external onlyFarmer { 
        require(!batchExists[_batchId], "Batch ID already exists");

        Batch storage newBatch = batches[_batchId];
        newBatch.batchId = _batchId;
        newBatch.productName = _productName;
        newBatch.quantity = _quantity;
        newBatch.currentOwner = msg.sender;
        newBatch.farmer = msg.sender;
        newBatch.isArrived = false;
        
        // Add initial owner to history
        newBatch.ownershipHistory.push(msg.sender);
        
        batchExists[_batchId] = true;

        emit BatchCreated(_batchId, _productName, msg.sender);
    }

    // --- 3. Record Environmental Data ---
    function addSensorData(uint _batchId, int _temperature, int _humidity, string memory _location) external onlyTransporter {
        require(batchExists[_batchId], "Batch does not exist");
        
        // Constraint Check
        require(_temperature >= -10 && _temperature <= 40, "Temperature out of range (-10 to 40)");
        require(_humidity >= 0 && _humidity <= 40, "Humidity out of range (0 to 40)");

        Batch storage batch = batches[_batchId];
        
        batch.sensorLogs.push(SensorLog({
            timestamp: block.timestamp,
            temperature: _temperature,
            humidity: _humidity,
            location: _location,
            recordedBy: msg.sender
        }));

        emit SensorDataAdded(_batchId, _temperature, _humidity, _location);
    }

    // --- 4. Ownership Transfer ---
    function transferOwnership(uint _batchId, address _newOwner) external {
        require(batchExists[_batchId], "Batch does not exist");
        Batch storage batch = batches[_batchId];
        
        // Only the current owner can transfer ownership
        require(msg.sender == batch.currentOwner, "You are not the current owner");
        require(!batch.isArrived, "Batch already arrived at retailer, cannot transfer");

        address previousOwner = batch.currentOwner;
        batch.currentOwner = _newOwner;
        batch.ownershipHistory.push(_newOwner);

        emit OwnershipTransferred(_batchId, previousOwner, _newOwner);
    }

    // --- 5. Retailer Final Inspection ---
    function markAsArrived(uint _batchId, bool _passedInspection) external onlyRetailer {
        require(batchExists[_batchId], "Batch does not exist");
        Batch storage batch = batches[_batchId];
        
        // Usually the retailer must be the owner to finalize, or at least in possession
        require(msg.sender == batch.currentOwner, "Retailer must own the batch to finalize");

        batch.isArrived = true;
        batch.passedInspection = _passedInspection;

        emit BatchArrived(_batchId, _passedInspection, msg.sender);
    }

    // --- 6. Customer View Function ---
    // Returns tuple of basic info + array of sensor logs + array of owners
    function getBatchHistory(uint _batchId) public view returns (
        string memory productName,
        uint quantity,
        address farmer,
        address currentOwner,
        bool isArrived,
        bool passedInspection,
        SensorLog[] memory logs,
        address[] memory owners
    ) {
        require(batchExists[_batchId], "Batch not found");
        Batch storage batch = batches[_batchId];
        
        return (
            batch.productName,
            batch.quantity,
            batch.farmer,
            batch.currentOwner,
            batch.isArrived,
            batch.passedInspection,
            batch.sensorLogs,
            batch.ownershipHistory
        );
    }
}