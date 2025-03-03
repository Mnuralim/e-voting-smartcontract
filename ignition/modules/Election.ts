import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const proxyModuleElection = buildModule("ProxyModuleElection", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const nftContractAddress = "0xE2a7a85307212CC387AcC8f8485bFa754bd561cE"
  const electionContract = m.contract("ElectionVote",[nftContractAddress]);

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