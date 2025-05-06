// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract FileStorage {
    address public owner;
    IERC20 public token;
    uint256 public uploadFee = 10 * 10**18;
    mapping(address => bool) public registeredUsers;
    mapping(address => File[]) private userFiles;
    mapping(address => mapping(address => bool)) private accessControl;
    mapping(address => Log[]) private auditLogs;
    mapping(string => bool) private uniqueFileHashes;

    struct File {
        string fileHash;
        string fileName;
        string fileHashSha256;
        mapping(address => bool) hasAccess;
        uint256 timestamp;
    }

    struct Log {
        string action;
        string fileHash;
        address user;
        uint256 timestamp;
    }

    event FileAdded(address indexed user, string fileHash, string fileName, string fileHashSha256, uint256 timestamp);
    event FileDeleted(address indexed user, string fileHash, string fileName, uint256 timestamp);
    event FileDownloaded(address indexed user, string fileHash, uint256 timestamp);
    event AccessGranted(address indexed owner, address indexed accessor, uint256 timestamp);
    event AccessRevoked(address indexed owner, address indexed accessor, uint256 timestamp);
    event UserRegistered(address indexed user, uint256 timestamp);
    event AuditLog(address indexed user, string action, string fileHash, uint256 timestamp);

    constructor(address _tokenAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        registeredUsers[msg.sender] = true;
    }

    modifier onlyRegistered() {
        require(registeredUsers[msg.sender], "User not registered");
        _;
    }

    function registerUser() external {
        require(!registeredUsers[msg.sender], "User already registered");
        registeredUsers[msg.sender] = true;
        emit UserRegistered(msg.sender, block.timestamp);
        addAuditLog("UserRegistered", "");
    }

    function addFile(string memory _fileHash, string memory _fileName, string memory _fileHashSha256) external onlyRegistered {
        require(!uniqueFileHashes[_fileHashSha256], "File already exists");
        require(token.transferFrom(msg.sender, owner, uploadFee), "Payment failed");
        
        File storage newFile = userFiles[msg.sender].push();
        newFile.fileHash = _fileHash;
        newFile.fileName = _fileName;
        newFile.fileHashSha256 = _fileHashSha256;
        newFile.hasAccess[msg.sender] = true;
        newFile.timestamp = block.timestamp;
        
        uniqueFileHashes[_fileHashSha256] = true;
        emit FileAdded(msg.sender, _fileHash, _fileName, _fileHashSha256, block.timestamp);
        addAuditLog("FileAdded", _fileHash);
    }

    function deleteFile(uint256 _index) external onlyRegistered {
        require(_index < userFiles[msg.sender].length, "Invalid file index");
        File storage fileToDelete = userFiles[msg.sender][_index];
        string memory fileHashSha256 = fileToDelete.fileHashSha256;
        string memory fileHash = fileToDelete.fileHash;
        string memory fileName = fileToDelete.fileName;
        
        uint256 lastIndex = userFiles[msg.sender].length - 1;
        if (_index < lastIndex) {
            File storage fileToMove = userFiles[msg.sender][lastIndex];
            File storage targetFile = userFiles[msg.sender][_index];
            
            targetFile.fileHash = fileToMove.fileHash;
            targetFile.fileName = fileToMove.fileName;
            targetFile.fileHashSha256 = fileToMove.fileHashSha256;
            targetFile.timestamp = fileToMove.timestamp;
            
            for (uint i = 0; i < userFiles[msg.sender].length; i++) {
                if (fileToMove.hasAccess[address(uint160(i))]) {
                    targetFile.hasAccess[address(uint160(i))] = true;
                }
            }
        }
        userFiles[msg.sender].pop();
        uniqueFileHashes[fileHashSha256] = false;
        
        emit FileDeleted(msg.sender, fileHash, fileName, block.timestamp);
        addAuditLog("FileDeleted", fileHash);
    }

    function grantAccess(address _accessor, uint256 _fileIndex) external onlyRegistered {
        require(registeredUsers[_accessor], "Accessor not registered");
        require(_fileIndex < userFiles[msg.sender].length, "Invalid file index");
        
        File storage file = userFiles[msg.sender][_fileIndex];
        file.hasAccess[_accessor] = true;
        
        emit AccessGranted(msg.sender, _accessor, block.timestamp);
        addAuditLog("AccessGranted", file.fileHash);
    }

    function revokeAccess(address _accessor, uint256 _fileIndex) external onlyRegistered {
        require(_fileIndex < userFiles[msg.sender].length, "Invalid file index");
        
        File storage file = userFiles[msg.sender][_fileIndex];
        file.hasAccess[_accessor] = false;
        
        emit AccessRevoked(msg.sender, _accessor, block.timestamp);
        addAuditLog("AccessRevoked", file.fileHash);
    }

    function hasAccess(address _owner, address _accessor) external view returns (bool) {
        if (_owner == _accessor) return true;
        if (userFiles[_owner].length == 0) return false;
        
        for (uint256 i = 0; i < userFiles[_owner].length; i++) {
            if (userFiles[_owner][i].hasAccess[_accessor]) {
                return true;
            }
        }
        return false;
    }

    function getFiles(address _user) external view returns (
        string[] memory fileHashes,
        string[] memory fileNames,
        string[] memory fileHashSha256s,
        uint256[] memory timestamps
    ) {
        require(msg.sender == _user || accessControl[_user][msg.sender] || msg.sender == owner, "Access denied");
        uint256 length = userFiles[_user].length;
        fileHashes = new string[](length);
        fileNames = new string[](length);
        fileHashSha256s = new string[](length);
        timestamps = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            fileHashes[i] = userFiles[_user][i].fileHash;
            fileNames[i] = userFiles[_user][i].fileName;
            fileHashSha256s[i] = userFiles[_user][i].fileHashSha256;
            timestamps[i] = userFiles[_user][i].timestamp;
        }
    }

    function logFileDownload(string memory _fileHash) external onlyRegistered {
        emit FileDownloaded(msg.sender, _fileHash, block.timestamp);
        addAuditLog("FileDownloaded", _fileHash);
    }

    function addAuditLog(string memory _action, string memory _fileHash) private {
        auditLogs[msg.sender].push(Log(_action, _fileHash, msg.sender, block.timestamp));
        emit AuditLog(msg.sender, _action, _fileHash, block.timestamp);
    }

    function getAuditLogs(address _user) external view returns (Log[] memory) {
        require(msg.sender == _user || msg.sender == owner, "Access denied");
        return auditLogs[_user];
    }
}