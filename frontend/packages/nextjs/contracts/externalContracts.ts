import { advantageAsymmetryAbi } from "./advantageAsymmetryAbi";
import { erc20Abi } from "viem";
import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

const externalContracts = {
  11155111: {
    AdvantageAsymmetryCampaign: {
      address: "0x72B1296c31B63a3B027caF2B26127780D08CdFeC",
      abi: advantageAsymmetryAbi,
      deployedOnBlock: 11716529,
    },
    AUDD: {
      address: "0x3619D7F95b0eaCae63DfA1909Ab797eb0aFc01E1",
      abi: erc20Abi,
    },
  },
} as const;

export default externalContracts satisfies GenericContractsDeclaration;
