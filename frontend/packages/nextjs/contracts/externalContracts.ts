import { advantageAsymmetryAbi } from "./advantageAsymmetryAbi";
import { erc20Abi } from "viem";
import { GenericContractsDeclaration } from "~~/utils/scaffold-eth/contract";

const externalContracts = {
  11155111: {
    AdvantageAsymmetryCampaign: {
      address: "0xB56503b117cE85530dD4990a5EFbE018A682A8C8",
      abi: advantageAsymmetryAbi,
      deployedOnBlock: 11570623,
    },
    USDC: {
      address: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
      abi: erc20Abi,
    },
  },
} as const;

export default externalContracts satisfies GenericContractsDeclaration;
