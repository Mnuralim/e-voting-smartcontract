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
            string memory departement,
            string memory dpm,
            string memory image,
            string memory uri
        );
}

contract ElectionVote {
    uint256 private constant MINIMUM_VOTING_DURATION = 1 days;

    enum ElectionType {
        BEM,
        BEM_FAKULTAS,
        HMPS,
        DPM,
        MPM,
        HMJ
    }

    enum Role {
        NONE,
        KPURM_UNIVERSITY,
        PAWASRA,
        KPURM_FAKULTAS_SAINS_DAN_TEKNOLOGI,
        KPURM_FAKULTAS_TEKNOLOGI_INFORMASI,
        KPURM_FAKULTAS_ILMU_SOSIAL_DAN_POLITIK,
        KPURM_FAKULTAS_KEGURUAN_DAN_ILMU_PENDIDIKAN,
        KPURM_FAKULTAS_PERTANIAN_PERIKANAN_DAN_PETERNAKAN,
        KPURM_FAKULTAS_HUKUM
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

    mapping(address => Role) public userRoles;

    address[] private userAddresses;
    mapping(address => bool) private isUserTracked;

    event GlobalVotingStarted(uint256 startTime, uint256 endTime);
    event RoleAssigned(address indexed user, Role role);

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
        string departement;
        string dpm;
        string kpurmFaculty;
        uint256 candidateCount;
        mapping(uint256 => Candidate) candidates;
    }

    struct ElectionView {
        uint256 id;
        string name;
        ElectionType electionType;
        string faculty;
        string program;
        string departement;
        string dpm;
        string kpurmFaculty;
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
        string program,
        string departement,
        string dpm
    );
    event CandidateAdded(
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
    error InvalidRole(Role role);

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

    modifier onlyPawasra() {
        if (userRoles[msg.sender] != Role.PAWASRA && msg.sender != admin)
            revert Unauthorized();
        _;
    }

    modifier onlyKpurmUniversity() {
        if (
            userRoles[msg.sender] != Role.KPURM_UNIVERSITY &&
            msg.sender != admin
        ) revert Unauthorized();
        _;
    }

    modifier onlyKpurmFakultas() {
        Role role = userRoles[msg.sender];
        if (
            (role != Role.KPURM_FAKULTAS_SAINS_DAN_TEKNOLOGI) &&
            (role != Role.KPURM_FAKULTAS_TEKNOLOGI_INFORMASI) &&
            (role != Role.KPURM_FAKULTAS_ILMU_SOSIAL_DAN_POLITIK) &&
            (role != Role.KPURM_FAKULTAS_KEGURUAN_DAN_ILMU_PENDIDIKAN) &&
            (role != Role.KPURM_FAKULTAS_PERTANIAN_PERIKANAN_DAN_PETERNAKAN) &&
            (role != Role.KPURM_FAKULTAS_HUKUM) &&
            (msg.sender != admin)
        ) revert Unauthorized();
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

    function isVotingActive() public view returns (bool) {
        return
            globalVotingPeriod.isActive &&
            block.timestamp >= globalVotingPeriod.startTime &&
            block.timestamp <= globalVotingPeriod.endTime;
    }

    function getAllUsersWithRoles()
        external
        view
        returns (address[] memory users, Role[] memory roles)
    {
        uint256 userCount = userAddresses.length;

        users = new address[](userCount);
        roles = new Role[](userCount);

        for (uint256 i = 0; i < userCount; i++) {
            users[i] = userAddresses[i];
            roles[i] = userRoles[userAddresses[i]];
        }

        return (users, roles);
    }

    function getFacultyNameFromRole(
        Role role
    ) internal pure returns (string memory) {
        if (role == Role.KPURM_FAKULTAS_SAINS_DAN_TEKNOLOGI) {
            return "fakultas sains dan teknologi";
        } else if (role == Role.KPURM_FAKULTAS_TEKNOLOGI_INFORMASI) {
            return "fakultas teknologi informasi";
        } else if (role == Role.KPURM_FAKULTAS_ILMU_SOSIAL_DAN_POLITIK) {
            return "fakultas ilmu sosial dan politik";
        } else if (role == Role.KPURM_FAKULTAS_KEGURUAN_DAN_ILMU_PENDIDIKAN) {
            return "fakultas keguruan dan ilmu pendidikan";
        } else if (
            role == Role.KPURM_FAKULTAS_PERTANIAN_PERIKANAN_DAN_PETERNAKAN
        ) {
            return "fakultas pertanian, perikanan dan peternakan";
        } else if (role == Role.KPURM_FAKULTAS_HUKUM) {
            return "fakultas hukum";
        }
        return "";
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

    function assignRole(address user, Role role) external onlyOwner {
        if (role == Role.NONE) {
            revert InvalidRole(role);
        }

        if (!isUserTracked[user] && role != Role.NONE) {
            userAddresses.push(user);
            isUserTracked[user] = true;
        }
        userRoles[user] = role;
        emit RoleAssigned(user, role);
    }

    function createElection(
        string calldata name,
        ElectionType electionType,
        string calldata faculty,
        string calldata program,
        string calldata departement,
        string calldata dpm
    ) external onlyOwner {
        uint256 electionId = electionCount++;
        Election storage election = elections[electionId];
        election.id = electionId;
        election.name = name;
        election.electionType = electionType;
        election.kpurmFaculty = faculty;

        if (
            bytes(program).length != 0 ||
            bytes(dpm).length != 0 ||
            bytes(departement).length != 0
        ) {
            election.faculty = "";
        } else {
            election.faculty = faculty;
        }

        election.program = program;
        election.departement = departement;
        election.dpm = dpm;

        emit ElectionCreated(
            electionId,
            name,
            electionType,
            faculty,
            program,
            departement,
            dpm
        );
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
                departement: election.departement,
                dpm: election.dpm,
                kpurmFaculty: election.kpurmFaculty,
                candidateCount: election.candidateCount
            });
        }

        return allElections;
    }

    function getElectionsByRole()
        external
        view
        returns (ElectionView[] memory)
    {
        Role role = userRoles[msg.sender];

        if (msg.sender == admin || role == Role.PAWASRA) {
            return this.getAllElections();
        }

        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < electionCount; i++) {
            Election storage election = elections[i];
            if (isEligibleToManage(role, election)) {
                eligibleCount++;
            }
        }

        ElectionView[] memory eligibleElections = new ElectionView[](
            eligibleCount
        );
        uint256 index = 0;

        for (uint256 i = 0; i < electionCount && index < eligibleCount; i++) {
            Election storage election = elections[i];
            if (isEligibleToManage(role, election)) {
                eligibleElections[index] = ElectionView({
                    id: election.id,
                    name: election.name,
                    electionType: election.electionType,
                    faculty: election.faculty,
                    program: election.program,
                    departement: election.departement,
                    dpm: election.dpm,
                    kpurmFaculty: election.kpurmFaculty,
                    candidateCount: election.candidateCount
                });
                index++;
            }
        }

        return eligibleElections;
    }

    function getRole(address user) external view returns (Role) {
        return userRoles[user];
    }

    function isEligibleToManage(
        Role role,
        Election storage election
    ) internal view returns (bool) {
        if (role == Role.KPURM_UNIVERSITY) {
            return (election.electionType == ElectionType.BEM ||
                election.electionType == ElectionType.MPM);
        }

        if (
            role >= Role.KPURM_FAKULTAS_SAINS_DAN_TEKNOLOGI &&
            role <= Role.KPURM_FAKULTAS_HUKUM
        ) {
            if (
                election.electionType != ElectionType.BEM_FAKULTAS &&
                election.electionType != ElectionType.DPM &&
                election.electionType != ElectionType.HMJ &&
                election.electionType != ElectionType.HMPS
            ) {
                return false;
            }

            string memory facultyName = getFacultyNameFromRole(role);
            return
                keccak256(abi.encodePacked(election.faculty)) ==
                keccak256(abi.encodePacked(facultyName));
        }

        return false;
    }

    function addCandidate(
        uint256 electionId,
        string calldata name,
        string calldata image,
        string calldata vision,
        string calldata mission
    ) external electionExists(electionId) {
        Role role = userRoles[msg.sender];
        Election storage election = elections[electionId];

        if (msg.sender != admin) {
            if (role == Role.KPURM_UNIVERSITY) {
                if (
                    election.electionType != ElectionType.BEM &&
                    election.electionType != ElectionType.MPM
                ) {
                    revert Unauthorized();
                }
            } else if (
                role >= Role.KPURM_FAKULTAS_SAINS_DAN_TEKNOLOGI &&
                role <= Role.KPURM_FAKULTAS_HUKUM
            ) {
                if (
                    election.electionType != ElectionType.BEM_FAKULTAS &&
                    election.electionType != ElectionType.DPM &&
                    election.electionType != ElectionType.HMJ &&
                    election.electionType != ElectionType.HMPS
                ) {
                    revert Unauthorized();
                }

                string memory facultyName = getFacultyNameFromRole(role);
                if (
                    keccak256(abi.encodePacked(election.kpurmFaculty)) !=
                    keccak256(abi.encodePacked(facultyName))
                ) {
                    revert Unauthorized();
                }
            } else {
                revert Unauthorized();
            }
        }

        if (bytes(name).length == 0) revert NameCannotBeEmpty();

        uint256 candidateId = election.candidateCount++;
        election.candidates[candidateId] = Candidate({
            id: candidateId,
            name: name,
            image: image,
            vision: vision,
            mission: mission,
            voteCount: 0,
            exists: true
        });

        emit CandidateAdded(
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

        (
            string memory faculty,
            string memory program,
            string memory departement,
            string memory dpm,
            ,

        ) = erc721.getNFTData(voter);

        Election storage election = elections[electionId];

        if (
            election.electionType == ElectionType.BEM ||
            election.electionType == ElectionType.MPM
        ) {
            return true;
        } else if (election.electionType == ElectionType.BEM_FAKULTAS) {
            return
                keccak256(abi.encodePacked(faculty)) ==
                keccak256(abi.encodePacked(election.faculty));
        } else if (election.electionType == ElectionType.HMPS) {
            return
                keccak256(abi.encodePacked(program)) ==
                keccak256(abi.encodePacked(election.program));
        } else if (election.electionType == ElectionType.HMJ) {
            return
                keccak256(abi.encodePacked(departement)) ==
                keccak256(abi.encodePacked(election.departement));
        } else if (election.electionType == ElectionType.DPM) {
            return
                keccak256(abi.encodePacked(dpm)) ==
                keccak256(abi.encodePacked(election.dpm));
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
