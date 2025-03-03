import { expect } from "chai";
import { ethers } from "hardhat";
import { Vote, Vote__factory } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("Vote Contract", function () {
  let vote: Vote;
  let owner: SignerWithAddress;
  let voter1: SignerWithAddress;
  let voter2: SignerWithAddress;
  let nftContractAddress: string;

  beforeEach(async function () {
    [owner, voter1, voter2] = await ethers.getSigners();

    const MockNFT = await ethers.getContractFactory("MockNFT");
    const mockNFT = await MockNFT.deploy();
    await mockNFT.waitForDeployment();
    nftContractAddress = await mockNFT.getAddress();

    const VoteFactory = (await ethers.getContractFactory(
      "Vote"
    )) as Vote__factory;
    vote = await VoteFactory.deploy(nftContractAddress);
    await vote.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct admin and NFT contract address", async function () {
      expect(await vote.admin()).to.equal(owner.address);
      expect(await vote.nftContractAddress()).to.equal(nftContractAddress);
    });
  });

  describe("Candidate Management", function () {
    it("Should allow admin to add a candidate", async function () {
      await vote
        .connect(owner)
        .addCandidate("Candidate 1", "image1", "vision1", "mission1");
      const candidates = await vote.getAllCandidates();
      expect(candidates.length).to.equal(1);
      expect(candidates[0].name).to.equal("Candidate 1");
    });

    it("Should not allow non-admin to add a candidate", async function () {
      await expect(
        vote
          .connect(voter1)
          .addCandidate("Candidate 1", "image1", "vision1", "mission1")
      ).to.be.revertedWithCustomError(vote, "Unauthorized");
    });

    it("Should allow admin to update a candidate", async function () {
      await vote
        .connect(owner)
        .addCandidate("Candidate 1", "image1", "vision1", "mission1");
      await vote
        .connect(owner)
        .updateCandidate(
          0,
          "Updated Candidate",
          "image2",
          "vision2",
          "mission2"
        );
      const candidates = await vote.getAllCandidates();
      expect(candidates[0].name).to.equal("Updated Candidate");
    });
  });

  describe("Voting", function () {
    beforeEach(async function () {
      await vote
        .connect(owner)
        .addCandidate("Candidate 1", "image1", "vision1", "mission1");
      await vote.connect(owner).startVoting(86400); 
    });

    it("Should allow NFT holder to vote", async function () {
      const MockNFT = await ethers.getContractFactory("MockNFT");
      const mockNFT = MockNFT.attach(nftContractAddress);
      await mockNFT.mint(voter1.address, 1);

      await vote.connect(voter1).vote(0);
      const candidate = await vote.candidates(0);
      expect(candidate.voteCount).to.equal(1);
    });

    it("Should not allow non-NFT holder to vote", async function () {
      await expect(vote.connect(voter1).vote(0)).to.be.revertedWithCustomError(
        vote,
        "NoNFTOwnership"
      );
    });

    it("Should not allow double voting", async function () {
      const MockNFT = await ethers.getContractFactory("MockNFT");
      const mockNFT = MockNFT.attach(nftContractAddress);
      await mockNFT.mint(voter1.address, 1);

      await vote.connect(voter1).vote(0);
      await expect(vote.connect(voter1).vote(0)).to.be.revertedWithCustomError(
        vote,
        "AlreadyVoted"
      );
    });

    it("Should not allow voting after voting period ends", async function () {
      const MockNFT = await ethers.getContractFactory("MockNFT");
      const mockNFT = MockNFT.attach(nftContractAddress);
      await mockNFT.mint(voter1.address, 1);

      await ethers.provider.send("evm_increaseTime", [86401]); 
      await ethers.provider.send("evm_mine", []);

      await expect(vote.connect(voter1).vote(0)).to.be.revertedWithCustomError(
        vote,
        "VotingNotActive"
      );
    });
  });

  describe("Whitelist Management", function () {
    it("Should return correct NFT holders", async function () {
      const MockNFT = await ethers.getContractFactory("MockNFT");
      const mockNFT = MockNFT.attach(nftContractAddress);
      await mockNFT.mint(voter1.address, 1);
      await mockNFT.mint(voter2.address, 2);

      const holders = await vote.getNFTHolders();
      expect(holders.length).to.equal(2);
      expect(holders[0].holder).to.equal(voter1.address);
      expect(holders[1].holder).to.equal(voter2.address);
    });
  });
});
