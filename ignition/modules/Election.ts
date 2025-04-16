import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const proxyModuleElection = buildModule("ProxyModuleElection", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const nftContractAddress = "0x40A692f309f854F4Df9f435DBA75Af157f44FcC0";
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
