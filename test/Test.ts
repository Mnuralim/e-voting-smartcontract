import { expect } from "chai";
import { ethers } from "hardhat";
import { SimpleStorage } from "../typechain-types";

describe("SimpleStorage", function () {
  let simpleStorage: SimpleStorage;

  beforeEach(async function () {
    const SimpleStorageFactory = await ethers.getContractFactory(
      "SimpleStorage"
    );
    simpleStorage = (await SimpleStorageFactory.deploy()) as SimpleStorage;
    await simpleStorage.waitForDeployment();
  });

  it("Should store and retrieve data correctly", async function () {
    const testData = "Hello, Blockchain!";
    await simpleStorage.setData(testData);

    const storedData = await simpleStorage.getData();
    expect(storedData).to.equal(testData);
  });

  it("Should return an empty string when no data is set", async function () {
    const storedData = await simpleStorage.getData();
    expect(storedData).to.equal("");
  });
});
