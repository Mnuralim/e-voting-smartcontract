// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);

    function totalMinted() external view returns (uint256);

    function getNFTData(
        address owner
    )
        external
        view
        returns (
            string memory faculty,
            string memory program,
            string memory image,
            string memory uri
        );
}

contract ElectionVote {
    string public version;

    uint256 private constant MINIMUM_VOTING_DURATION = 1 days;

    enum ElectionType {
        BEM,
        BEM_FAKULTAS,
        HMPS,
        DPM,
        MPM
    }

    struct VotingPeriod {
        bool isActive;
        uint256 startTime;
        uint256 endTime;
    }

    address public immutable admin;
    address public immutable nftContractAddress;
    mapping(address => uint256) public nonces;
    VotingPeriod public globalVotingPeriod;
    event GlobalVotingStarted(uint256 startTime, uint256 endTime);

    struct WhitelistInfo {
        address holder;
        uint256[] tokenIds;
    }

    struct Election {
        uint256 id;
        string name;
        ElectionType electionType;
        string faculty;
        string program;
        uint256 candidateCount;
        mapping(uint256 => Candidate) candidates;
    }

    struct ElectionView {
        uint256 id;
        string name;
        ElectionType electionType;
        string faculty;
        string program;
        uint256 candidateCount;
    }

    struct Candidate {
        uint256 id;
        string name;
        string image;
        string vision;
        string mission;
        uint256 voteCount;
        bool exists;
    }

    mapping(uint256 => Election) public elections;
    uint256 public electionCount;

    mapping(address => mapping(ElectionType => bool)) public hashVoted;

    event ElectionCreated(
        uint256 indexed electionId,
        string name,
        ElectionType electionType,
        string faculty,
        string program
    );
    event CandidateAdded(
        uint256 indexed electionId,
        uint256 indexed candidateId,
        string name,
        string image,
        string vision,
        string mission
    );

    event CandidateUpdated(
        uint256 indexed electionId,
        uint256 indexed candidateId,
        string name,
        string image,
        string vision,
        string mission
    );

    event VoteSubmitted(
        uint256 indexed electionId,
        address indexed voter,
        uint256 indexed candidateId
    );

    error Unauthorized();
    error VotingNotActive();
    error VotingIsActive();
    error AlreadyVoted();
    error InvalidCandidate();
    error NoNFTOwnership();
    error InvalidVotingPeriod();
    error InvalidSignature();
    error InvalidElection();
    error NotEligibleToVote();
    error NameCannotBeEmpty();

    constructor(address _nftContractAddress) {
        if (_nftContractAddress == address(0))
            revert("Invalid NFT contract address");
        admin = msg.sender;
        nftContractAddress = _nftContractAddress;
    }

    modifier onlyOwner() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier electionExists(uint256 electionId) {
        if (electionId >= electionCount) revert InvalidElection();
        _;
    }

    modifier votingActive() {
        if (!isVotingActive()) revert VotingNotActive();
        _;
    }

    function setVersion(string memory _version) public {
        version = _version;
    }

    function isVotingActive() public view returns (bool) {
        return
            globalVotingPeriod.isActive &&
            block.timestamp >= globalVotingPeriod.startTime &&
            block.timestamp <= globalVotingPeriod.endTime;
    }

    function startGlobalVoting(uint256 duration) external onlyOwner {
        if (globalVotingPeriod.isActive) revert VotingIsActive();
        if (duration < MINIMUM_VOTING_DURATION) revert InvalidVotingPeriod();

        globalVotingPeriod.isActive = true;
        globalVotingPeriod.startTime = block.timestamp;
        globalVotingPeriod.endTime = block.timestamp + duration;

        emit GlobalVotingStarted(
            globalVotingPeriod.startTime,
            globalVotingPeriod.endTime
        );
    }

    function createElection(
        string calldata name,
        ElectionType electionType,
        string calldata faculty,
        string calldata program
    ) external onlyOwner {
        uint256 electionId = electionCount++;
        Election storage election = elections[electionId];

        election.id = electionId;
        election.name = name;
        election.electionType = electionType;
        election.faculty = faculty;
        election.program = program;

        emit ElectionCreated(electionId, name, electionType, faculty, program);
    }

    function getAllElections() external view returns (ElectionView[] memory) {
        ElectionView[] memory allElections = new ElectionView[](electionCount);

        for (uint256 i = 0; i < electionCount; i++) {
            Election storage election = elections[i];
            allElections[i] = ElectionView({
                id: election.id,
                name: election.name,
                electionType: election.electionType,
                faculty: election.faculty,
                program: election.program,
                candidateCount: election.candidateCount
            });
        }

        return allElections;
    }

    function addCandidate(
        uint256 electionId,
        string calldata name,
        string calldata image,
        string calldata vision,
        string calldata mission
    ) external onlyOwner electionExists(electionId) {
        if (isVotingActive()) revert VotingIsActive();
        if (bytes(name).length == 0) revert NameCannotBeEmpty();

        Election storage election = elections[electionId];
        uint256 candidateId = election.candidateCount;

        election.candidates[candidateId] = Candidate({
            id: candidateId,
            name: name,
            image: image,
            vision: vision,
            mission: mission,
            voteCount: 0,
            exists: true
        });

        election.candidateCount++;
        emit CandidateAdded(
            electionId,
            candidateId,
            name,
            image,
            vision,
            mission
        );
    }

    function updateCandidate(
        uint256 electionId,
        uint256 candidateId,
        string calldata name,
        string calldata image,
        string calldata vision,
        string calldata mission
    ) external onlyOwner electionExists(electionId) {
        if (isVotingActive()) revert VotingIsActive();

        Election storage election = elections[electionId];
        if (!election.candidates[candidateId].exists) revert InvalidCandidate();
        if (bytes(name).length == 0) revert NameCannotBeEmpty();

        Candidate storage candidate = election.candidates[candidateId];
        candidate.name = name;
        candidate.image = image;
        candidate.vision = vision;
        candidate.mission = mission;

        emit CandidateUpdated(
            electionId,
            candidateId,
            name,
            image,
            vision,
            mission
        );
    }

    function vote(
        uint256 electionId,
        uint256 candidateId,
        bytes memory signature
    ) external votingActive electionExists(electionId) {
        Election storage election = elections[electionId];
        if (!election.candidates[candidateId].exists) revert InvalidCandidate();

        if (hashVoted[msg.sender][election.electionType]) {
            revert AlreadyVoted();
        }

        if (!checkVotingEligibility(msg.sender, electionId)) {
            revert NotEligibleToVote();
        }

        uint256 nonce = nonces[msg.sender];
        if (
            !verifySignature(
                msg.sender,
                electionId,
                candidateId,
                nonce,
                signature
            )
        ) {
            revert InvalidSignature();
        }

        nonces[msg.sender]++;
        election.candidates[candidateId].voteCount++;
        hashVoted[msg.sender][election.electionType] = true;

        emit VoteSubmitted(electionId, msg.sender, candidateId);
    }

    function checkVotingEligibility(
        address voter,
        uint256 electionId
    ) internal view returns (bool) {
        IERC721 erc721 = IERC721(nftContractAddress);

        if (erc721.balanceOf(voter) == 0) {
            return false;
        }

        (string memory faculty, string memory program, , ) = erc721.getNFTData(
            voter
        );

        Election storage election = elections[electionId];

        if (
            election.electionType == ElectionType.BEM ||
            election.electionType == ElectionType.MPM ||
            election.electionType == ElectionType.DPM
        ) {
            return true;
        } else if (
            election.electionType == ElectionType.BEM_FAKULTAS ||
            election.electionType == ElectionType.HMPS
        ) {
            return (keccak256(abi.encodePacked(faculty)) ==
                keccak256(abi.encodePacked(election.faculty)) &&
                keccak256(abi.encodePacked(program)) ==
                keccak256(abi.encodePacked(election.program)));
        }

        return false;
    }

    function getAllCandidates(
        uint256 electionId
    ) external view electionExists(electionId) returns (Candidate[] memory) {
        Election storage election = elections[electionId];
        Candidate[] memory candidates = new Candidate[](
            election.candidateCount
        );

        for (uint256 i = 0; i < election.candidateCount; i++) {
            candidates[i] = election.candidates[i];
        }

        return candidates;
    }

    function verifySignature(
        address voter,
        uint256 electionId,
        uint256 candidateId,
        uint256 nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(voter, electionId, candidateId, nonce)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        address recoveredSigner = recoverSigner(
            ethSignedMessageHash,
            signature
        );
        return recoveredSigner == voter;
    }

    function recoverSigner(
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (address) {
        if (signature.length != 65) revert("Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(messageHash, v, r, s);
    }

    function getGlobalVotingPeriod()
        external
        view
        returns (bool isActive, uint256 startTime, uint256 endTime)
    {
        return (
            globalVotingPeriod.isActive,
            globalVotingPeriod.startTime,
            globalVotingPeriod.endTime
        );
    }

    function getNFTHolders() external view returns (WhitelistInfo[] memory) {
        IERC721 nft = IERC721(nftContractAddress);
        uint256 totalSupply = nft.totalMinted();

        address[] memory tempHolders = new address[](totalSupply);
        uint256 uniqueHoldersCount = 0;

        for (uint256 i = 0; i < totalSupply; i++) {
            address owner = nft.ownerOf(i);
            bool isUnique = true;

            for (uint256 j = 0; j < uniqueHoldersCount; j++) {
                if (tempHolders[j] == owner) {
                    isUnique = false;
                    break;
                }
            }

            if (isUnique) {
                tempHolders[uniqueHoldersCount] = owner;
                uniqueHoldersCount++;
            }
        }

        WhitelistInfo[] memory holders = new WhitelistInfo[](
            uniqueHoldersCount
        );

        for (uint256 i = 0; i < uniqueHoldersCount; i++) {
            address holder = tempHolders[i];
            uint256 balance = nft.balanceOf(holder);
            uint256[] memory tokens = new uint256[](balance);

            uint256 tokenIndex = 0;
            for (uint256 j = 0; j < totalSupply && tokenIndex < balance; j++) {
                if (nft.ownerOf(j) == holder) {
                    tokens[tokenIndex] = j;
                    tokenIndex++;
                }
            }

            holders[i] = WhitelistInfo({holder: holder, tokenIds: tokens});
        }

        return holders;
    }
}
