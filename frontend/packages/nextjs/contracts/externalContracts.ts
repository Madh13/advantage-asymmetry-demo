import { advantageAsymmetryAbi } from "./advantageAsymmetryAbi";
import { erc20Abi } from "viem";
import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

const externalContracts = {
  11155111: {
    AdvantageAsymmetryCampaign: {
      address: "0xcD51F769860FE95fCab126AdC5fc2b9D24afB24b",
      abi: advantageAsymmetryAbi,
      deployedOnBlock: 11555532,
    },
    AUDD: {
      address: "0x3619D7F95b0eaCae63DfA1909Ab797eb0aFc01E1",
      abi: erc20Abi,
    },
  },
} as const;

export default externalContracts satisfies GenericContractsDeclaration;
