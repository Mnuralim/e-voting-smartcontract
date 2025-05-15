import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const proxyModuleElection = buildModule("ProxyModuleElection", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const nftContractAddress = "0xAF5896ae9FB980e79917fE6f6324A81904193d7e";
  const electionContract = m.contract("ElectionVote", [nftContractAddress]);

  const proxy = m.contract("TransparentUpgradeableProxy", [
    electionContract,
    proxyAdminOwner,
    "0x",
  ]);

  const proxyAdminAddress = m.readEventArgument(
    proxy,
    "AdminChanged",
    "newAdmin"
  );

  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy };
});

export default proxyModuleElection;
