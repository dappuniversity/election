pragma solidity ^0.5.16;


pragma experimental ABIEncoderV2; // needed to be able to pass string arrays and structs into functions

/// @dev This contract spawns election contracts that can be used for voting
contract ElectionFactory {

    address public registrationAuthorityContractAdd; //stores the contract address of a deployed registration authority
    address public registrationAuthority; // stores the accout of the registration authority
    address[] public deployedElections; // keeps a list of all deployed elections

    /// @dev initializes the contract and sets the registration authority to be the deployer of the contract
    constructor(address _registrationAuthorityContAdd) public {
        registrationAuthorityContractAdd= _registrationAuthorityContAdd;
        registrationAuthority = msg.sender;
    }

    /// @dev only the registration authority is allowed functions marked with this
    /// @notice functions with this modifier can only be used by the registration authority
    modifier restricted() {
        require(msg.sender == registrationAuthority, "only the registration authority is allowed to use this function");
        _;
    }

    /// @dev use this to deploy new Election contracts and reset the temporary options lists afterwards
    /// @param _title specifies the name of the election (e.g. national elections)
    /// @param _description specifies the description of the election
    /// @param _startTime specifies the beginning of the election (since Unix Epoch in seconds)
    /// @param _timeLimit specifies a time limit until when the election is open (since Unix Epoch in seconds)
    function createElection(
        string memory _title,
        string memory _description,
        uint _startTime,
        uint _timeLimit,
        string memory _encryptionKey)
        public restricted {
        deployedElections.push(
            address(
                new Election(
                    registrationAuthority,
                    registrationAuthorityContractAdd,
                    _title,
                    _description,
                    _startTime,
                    _timeLimit,
                    _encryptionKey
                )
            )
        );
    }

    /// @dev use this to return a list of addresses of all deployed Election contracts
    /// @return a list of addresses of all deployed Election contracts
    function getDeployedElections() public view returns(address[] memory) {
        return deployedElections;
    }

}

/// @dev This is the actual election contract where users can vote
/// @dev Security by design: secret sharing, allows voters one time voting
contract Election {
    struct Ballot {
        string name;
        string party;
    }

/*    struct Vote {
        uint listPointer; // index in the list of addresses that voted
        string encryptedVote; // homomorphically encrypted 0 or 1 for each option. 1 being a vote. Max 1 per voter.
    }*/

    address public registrationAuthority;
    address public  registrationAuthorityContractAdd;
    string public title;
    string public description;
    uint public startTime;
    uint public timeLimit;
    uint public timeNow;
    Ballot[] public ballotList;
    string public encryptionKey;
    uint[] public publishedResult;

    mapping(address => bool) private votersCheckList; // records that the voter has voted
    string[] private encryptedVoteList; // keeps a list of all encrypted votes

    /// @dev initializes the contract with all required parameters and sets the manager of the contract
    constructor(
        address _registrationAuthority,
        address _registrationAuthorityContractAdd,
        string memory _title,
        string memory _description,
        uint _startTime,
        uint _timeLimit,
        string memory _encryptionKey
    ) public {
        registrationAuthority=_registrationAuthority;
        registrationAuthorityContractAdd = _registrationAuthorityContractAdd;
        title = _title;
        description = _description;
        startTime = _startTime;
        timeLimit = _timeLimit;
        encryptionKey = _encryptionKey;
    }

    /// @dev only the registration authority is allowed functions marked with this
    /// @notice functions with this modifier can only be used by the registration authority
    modifier restricted() {
        require(msg.sender == registrationAuthority, "only the registration authority is allowed to use this function");
        _;
    }

    /// @dev functions marked with this can be called before the specified start time
    modifier beforeElection() {
        require(now < startTime, "only allowed before election");
        _;
    }

    /// @dev functions marked with this can be called during the specified time frame
    modifier duringElection() {
        require(now > startTime && now < timeLimit, "only allowed during election");
        _;
    }

    /// @dev functions marked with this can be called after the specified end time
    modifier afterElection() {
        require(now > timeLimit, "only allowed after election");
        _;
    }

    /// @dev add an option to the ballot before the election starts
    function addCandidate(string calldata _name, string calldata _party) external restricted beforeElection {
        ballotList.push(Ballot({ name: _name, party: _party }));
    }

    /// @dev get all available options on the ballot
    function getBallot() external view returns(Ballot[] memory x) {
        return ballotList;
    }

    /// @dev get the list of encrypted votes of a voter, only allowed after the election is over
    function getencryptedVoteList() external view restricted afterElection returns(string[] memory success) {
        return encryptedVoteList;
    }
    /// @dev publish the decrypted version of the sum of all votes for each candidate
    function publishResults(uint[] calldata results) external restricted afterElection returns(bool success) {
        publishedResult = results;
        return true;
    }

    /// @dev returns the list of final votes for each candidate
    function getResults() external view afterElection returns(uint[] memory results) {
        return publishedResult;
    }

    /// @dev this is used to cast a vote. the vote is homomorphically encrypted
    /// @dev allows users to vote multiple times, invalidating the previous vote
    function vote(string calldata _encryptedVote) external duringElection returns(bool success) {
        require(isRegisteredVoter(msg.sender), "message sender is not a registered voter");
        require(!votersCheckList[msg.sender],"only one vote possible");
        encryptedVoteList.push(_encryptedVote);
        votersCheckList[msg.sender] = true;

        return true;
    }

    /// @dev find out whether a voter has submitted their vote
    function hasVoted(address _address) public view returns(bool) {
        return votersCheckList[_address];
    }

    /// @dev check the registration authority whether the address is registered as a valid voter
    function isRegisteredVoter(address _address) private view returns(bool) {        
        RegistrationAuthority ra = RegistrationAuthority(registrationAuthorityContractAdd);
        return ra.isVoter(_address);
    }
}

/// @dev use this to register and unregister voters
contract RegistrationAuthority {
    struct Voter {
        uint listPointer;
        bool isVoter;
        address ethAddress;
        string name;
        string streetAddress;
        string birthdate;
        string personId;
    }

    address public manager;

    mapping(address => Voter) private voters;
    address[] private votersReferenceList;

    /// @dev initializes the contract and sets the contract manager to be the deployer of the contract
    constructor() public {
        manager = msg.sender;
    }

    /// @dev only the factory manager is allowed functions marked with this
    /// @notice functions with this modifier can only be used by the administrator
    modifier restricted() {
        require(msg.sender == manager, "only the contract manager is allowed to use this function");
        _;
    }

    /// @dev use this to register or update a voter
    function registerOrUpdateVoter(
        address _voter,
        string calldata _name,
        string calldata _streetAddress,
        string calldata _birthdate,
        string calldata _personId) external restricted {

        if (voters[_voter].isVoter == false) {
            voters[_voter].listPointer = votersReferenceList.push(_voter) - 1;
            voters[_voter].isVoter = true;
            voters[_voter].ethAddress = _voter;
        }

        voters[_voter].name = _name;
        voters[_voter].streetAddress = _streetAddress;
        voters[_voter].birthdate = _birthdate;
        voters[_voter].personId = _personId;
    }

    /// @dev use this to unregister a voter
    function unregisterVoter(address _voter) external restricted {
        require(voters[_voter].isVoter == true, "this address is not registered as a voter");

        // Delete the desired entry by moving the last item in the array to the row to delete, and then shorten the array by one
        voters[_voter].isVoter = false;
        uint rowToDelete = voters[_voter].listPointer;
        address keyToMove = votersReferenceList[votersReferenceList.length - 1];
        votersReferenceList[rowToDelete] = keyToMove;
        voters[keyToMove].listPointer = rowToDelete;
        votersReferenceList.length--;
    }

    /// @dev use this to check whether an address belongs to a valid voter
    function isVoter(address _voter) public view returns(bool) {
        if (votersReferenceList.length == 0) return false;
        return (voters[_voter].isVoter);
    }

    /// @dev use this this to get the number of registered voters
    function getNumberOfVoters() public view returns(uint) {
        return votersReferenceList.length;
    }

    /// @dev get a list of registered voters
    function getListOfVoters() public view returns(address[] memory x) {
        return votersReferenceList;
    }

    /// @dev get details of a specific voter
    function getVoterDetails(address _voter) public view returns(Voter memory) {
        return voters[_voter];
    }
}
