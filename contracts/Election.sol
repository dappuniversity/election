pragma solidity >=0.4.26;
pragma experimental ABIEncoderV2; // needed to be able to pass string arrays and structs into functions

contract ElectionFactory {
    address public factoryManager;
    address public registrationAuthority;
    address[] public deployedElections;

    /// @dev initializes the contract and sets the contract manager to be the deployer of the contract
    constructor(address _registrationAuthority) public {
        factoryManager = msg.sender;
        registrationAuthority = _registrationAuthority;
    }

    /// @dev only the factory manager is allowed functions marked with this
    /// @notice functions with this modifier can only be used by the administrator
    modifier restricted() {
        require(msg.sender == factoryManager, "only the factory manager is allowed to use this function");
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
                    factoryManager,
                    registrationAuthority,
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

/// @title Election
/// @author Johannes Mols (02.09.2019)
/// @dev This is the actual election contract where users can vote
/// @dev Security by design: homomorphic encryption, (zero-knowledge proofs), allowing voters to vote multiple times to avoid coercion (new vote invalidates old one)
contract Election {
    struct Option {
        string title;
        string description;
    }

    struct Vote {
        uint listPointer; // index in the list of addresses that voted
        string encryptedVote; // homomorphically encrypted 0 or 1 for each option. 1 being a vote. Max 1 per voter.
    }

    address public electionFactory;
    address public electionManager;
    address public registrationAuthority;
    string public title;
    string public description;
    uint public startTime;
    uint public timeLimit;
    Option[] public options;
    string public encryptionKey;
    uint[] public publishedResult;

    mapping(address => Vote) private votes; // records encrypted vote for each address
    address[] private votesReferenceList; // keeps a list of all addresses that voted

    /// @dev initializes the contract with all required parameters and sets the manager of the contract
    constructor(
        address _manager,
        address _registrationAuthority,
        string memory _title,
        string memory _description,
        uint _startTime,
        uint _timeLimit,
        string memory _encryptionKey
    ) public {
        electionFactory = msg.sender;
        registrationAuthority = _registrationAuthority;
        electionManager = _manager;
        title = _title;
        description = _description;
        startTime = _startTime;
        timeLimit = _timeLimit;
        encryptionKey = _encryptionKey;
    }

    /// @dev only the factory manager is allowed functions marked with this
    /// @notice functions with this modifier can only be used by the administrator
    modifier manager() {
        require(msg.sender == electionManager, "only the election manager is allowed to use this function");
        _;
    }

    modifier factory() {
        require(msg.sender == electionFactory, "only the election factory is allowed to use this function");
        _;
    }

    modifier beforeElection() {
        require(now < startTime, "only allowed before election");
        _;
    }

    modifier duringElection() {
        require(now > startTime && now < timeLimit, "only allowed during election");
        _;
    }

    modifier afterElection() {
        require(now > timeLimit, "only allowed after election");
        _;
    }

    /// @dev add an option to the ballot before the election starts
    function addOption(string calldata _title, string calldata _description) external manager beforeElection {
        options.push(Option({ title: _title, description: _description }));
    }

    /// @dev get all available options on the ballot
    function getOptions() external view returns(Option[] memory) {
        return options;
    }

    /// @dev returns a list of addresses that participated in the election
    function getListOfAddressesThatVoted() external view afterElection returns(address[] memory voterList) {
        return votesReferenceList;
    }

    /// @dev get the encrypted vote of a voter, only allowed after the election is over
    function getEncryptedVoteOfVoter(address _address) external view afterElection returns(string memory encryptedVote) {
        return votes[_address].encryptedVote;
    }

    /// @dev publish the decrypted version of the sum of all votes for each candidate
    function publishResults(uint[] calldata results) external manager afterElection returns(bool success) {
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

        votes[msg.sender].encryptedVote = _encryptedVote;

        if(!hasVoted(msg.sender)) {
            votes[msg.sender].listPointer = votesReferenceList.push(msg.sender) - 1;
        }

        return true;
    }

    /// @dev find out whether a voter has submitted their vote
    function hasVoted(address _address) public view returns(bool) {
        if(votesReferenceList.length == 0) return false;
        return (votesReferenceList[votes[_address].listPointer] == _address);
    }

    /// @dev check the registration authority whether the address is registered as a valid voter
    function isRegisteredVoter(address _address) private view returns(bool) {
        RegistrationAuthority ra = RegistrationAuthority(registrationAuthority);
        return ra.isVoter(_address);
    }
}

/// @title The Registration Authority takes care of keeping a record of eligible voters
/// @author Johannes Mols (03.09.2019)
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
    function getListOfVoters() public view returns(address[] memory) {
        return votersReferenceList;
    }

    /// @dev get details of a specific voter
    function getVoterDetails(address _voter) public view returns(Voter memory) {
        return voters[_voter];
    }
}
