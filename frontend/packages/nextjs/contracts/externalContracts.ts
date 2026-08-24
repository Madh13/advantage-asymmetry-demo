import { advantageAsymmetryAbi } from "./advantageAsymmetryAbi";
import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

const externalContracts = {
  11155111: {
    AdvantageAsymmetryCampaign: {
      address: "0xcD51F769860FE95fCab126AdC5fc2b9D24afB24b",
      abi: advantageAsymmetryAbi,
      deployedOnBlock: 11555532,
    },
  },
} as const;

export default externalContracts satisfies GenericContractsDeclaration;
