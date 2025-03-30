// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Upload {
    struct FileData {
        uint256 id;      // Add unique ID for each file
        string fileName;
        string url;
    }

    struct Access {
        address user;
        bool access;
        uint256[] fileIds;  // Array of file IDs this user has access to
    }

    struct Group {
        string name;
        address[] members;
        bool active;
    }

    // Mapping from address to array of FileData (filename and URL)
    mapping(address => FileData[]) public value;

    // Mapping for ownership access
    mapping(address => mapping(address => bool)) public ownership;

    // Mapping for access list
    mapping(address => Access[]) public accessList;

    // Mapping to track previously given access
    mapping(address => mapping(address => bool)) public previousData;

    // New mappings for groups
    mapping(address => Group[]) public userGroups;
    mapping(address => mapping(string => uint256)) public groupIndexByName;

    uint256 private fileIdCounter = 0;  // Counter for generating unique file IDs

    // Add an event to track file additions
    event FileAdded(address user, uint256 fileId, string fileName);
    event GroupCreated(address creator, string groupName);
    event GroupMemberAdded(string groupName, address member);
    event GroupMemberRemoved(string groupName, address member);

    // Function to add a file with a filename and URL
    function add(
        address _user,
        string memory fileName,
        string memory url
    ) external returns (uint256) {
        require(bytes(fileName).length > 0, "Filename cannot be empty");
        require(bytes(url).length > 0, "URL cannot be empty");
        
        uint256 fileId = fileIdCounter++;
        FileData memory newFile = FileData(fileId, fileName, url);
        value[_user].push(newFile);
        
        emit FileAdded(_user, fileId, fileName);
        return fileId;
    }

    // Modified allow function to handle specific files
    function _allow(address user, uint256[] memory fileIds) internal {
        ownership[msg.sender][user] = true;
        
        if (previousData[msg.sender][user]) {
            for (uint i = 0; i < accessList[msg.sender].length; i++) {
                if (accessList[msg.sender][i].user == user) {
                    accessList[msg.sender][i].access = true;
                    accessList[msg.sender][i].fileIds = fileIds;
                }
            }
        } else {
            accessList[msg.sender].push(Access(user, true, fileIds));
            previousData[msg.sender][user] = true;
        }
    }

    // External function to allow access
    function allow(address user, uint256[] calldata fileIds) external {
        _allow(user, fileIds);
    }

    // Function to revoke access from another address
    function disallow(address user) public {
        ownership[msg.sender][user] = false;
        for (uint i = 0; i < accessList[msg.sender].length; i++) {
            if (accessList[msg.sender][i].user == user) {
                accessList[msg.sender][i].access = false;
            }
        }
    }

    // Add a function to get all files for a user
    function getAllFiles(address user) external view returns (FileData[] memory) {
        return value[user];
    }

    // Modified display function to handle empty access lists
    function display(address user) external view returns (FileData[] memory) {
        if (user == msg.sender) {
            return value[user];
        }
        
        require(ownership[user][msg.sender], "You don't have access");
        
        // Get the list of files the user has access to
        uint256[] memory accessibleFileIds;
        bool hasAccess = false;
        
        for (uint i = 0; i < accessList[user].length; i++) {
            if (accessList[user][i].user == msg.sender && accessList[user][i].access) {
                accessibleFileIds = accessList[user][i].fileIds;
                hasAccess = true;
                break;
            }
        }
        
        if (!hasAccess || accessibleFileIds.length == 0) {
            return new FileData[](0);
        }
        
        // Filter and return only accessible files
        uint256 accessibleCount = 0;
        for (uint i = 0; i < value[user].length; i++) {
            for (uint j = 0; j < accessibleFileIds.length; j++) {
                if (value[user][i].id == accessibleFileIds[j]) {
                    accessibleCount++;
                }
            }
        }
        
        FileData[] memory accessibleFiles = new FileData[](accessibleCount);
        uint256 currentIndex = 0;
        
        for (uint i = 0; i < value[user].length; i++) {
            for (uint j = 0; j < accessibleFileIds.length; j++) {
                if (value[user][i].id == accessibleFileIds[j]) {
                    accessibleFiles[currentIndex] = value[user][i];
                    currentIndex++;
                }
            }
        }
        
        return accessibleFiles;
    }

    // Function to share access list
    function shareAccess() public view returns (Access[] memory) {
        return accessList[msg.sender];
    }

    // Create a new group
    function createGroup(string memory groupName, address[] memory initialMembers) external {
        require(bytes(groupName).length > 0, "Group name cannot be empty");
        // Check if group exists
        uint256 existingIndex = groupIndexByName[msg.sender][groupName];
        if (existingIndex > 0) {
            require(!userGroups[msg.sender][existingIndex - 1].active, 
                "Group already exists and is active");
        }

        Group memory newGroup = Group({
            name: groupName,
            members: new address[](0),
            active: true
        });

        userGroups[msg.sender].push(newGroup);
        groupIndexByName[msg.sender][groupName] = userGroups[msg.sender].length;

        // Add initial members if any
        if (initialMembers.length > 0) {
            for (uint i = 0; i < initialMembers.length; i++) {
                if (initialMembers[i] != address(0)) {
                    _addMemberToGroup(groupName, initialMembers[i]);
                }
            }
        }

        emit GroupCreated(msg.sender, groupName);
    }

    // Internal function to add member to group
    function _addMemberToGroup(string memory groupName, address member) internal {
        require(member != address(0), "Invalid member address");
        uint256 groupIndex = groupIndexByName[msg.sender][groupName];
        require(groupIndex > 0, "Group does not exist");
        groupIndex--; // Adjust for 0-based array

        Group storage group = userGroups[msg.sender][groupIndex];
        require(group.active, "Group is not active");

        // Check if member already exists
        for (uint i = 0; i < group.members.length; i++) {
            if (group.members[i] == member) {
                return; // Member already exists
            }
        }

        group.members.push(member);
        emit GroupMemberAdded(groupName, member);
    }

    // Add member to group
    function addToGroup(string memory groupName, address member) external {
        _addMemberToGroup(groupName, member);
    }

    // Share files with a group
    function allowGroup(string memory groupName, uint256[] calldata fileIds) external {
        uint256 groupIndex = groupIndexByName[msg.sender][groupName];
        require(groupIndex > 0, "Group does not exist");
        groupIndex--; // Adjust for 0-based array

        Group storage group = userGroups[msg.sender][groupIndex];
        require(group.active, "Group is not active");
        require(group.members.length > 0, "Group has no members");

        // Share with each member of the group
        for (uint i = 0; i < group.members.length; i++) {
            address memberAddress = group.members[i];
            _allow(memberAddress, fileIds);
        }
    }

    // Get all groups for a user
    function getGroups() external view returns (Group[] memory) {
        return userGroups[msg.sender];
    }
}
