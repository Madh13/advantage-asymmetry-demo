// Auto-generated from the canonical Foundry artifact.
// Source: out/AdvantageAsymmetryCampaign.sol/AdvantageAsymmetryCampaign.json

export const advantageAsymmetryAbi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "_token",
        type: "address",
        internalType: "address",
      },
      {
        name: "_penaltySink",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "approveMilestone",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "campaignCount",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "cancelPatronage",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "claimPatronage",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "claimRefund",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "claimablePatronage",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "contribute",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "contributions",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "createCampaign",
    inputs: [
      {
        name: "goal",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "bondAmount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "milestoneDescriptions",
        type: "string[]",
        internalType: "string[]",
      },
      {
        name: "milestoneAmounts",
        type: "uint256[]",
        internalType: "uint256[]",
      },
      {
        name: "fundingDeadline",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "executionDeadline",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getCampaign",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "creator",
        type: "address",
        internalType: "address",
      },
      {
        name: "goal",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "bondAmount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "totalContributed",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "totalReleased",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "nextMilestoneIndex",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "fundingDeadline",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "executionDeadline",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "failureTimestamp",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "status",
        type: "uint8",
        internalType: "enum AdvantageAsymmetryCampaign.CampaignStatus",
      },
      {
        name: "failureReason",
        type: "uint8",
        internalType: "enum AdvantageAsymmetryCampaign.FailureReason",
      },
      {
        name: "bondOutcome",
        type: "uint8",
        internalType: "enum AdvantageAsymmetryCampaign.BondOutcome",
      },
      {
        name: "milestoneCount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getContributorCount",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getMilestone",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct AdvantageAsymmetryCampaign.Milestone",
        components: [
          {
            name: "description",
            type: "string",
            internalType: "string",
          },
          {
            name: "amount",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "status",
            type: "uint8",
            internalType: "enum AdvantageAsymmetryCampaign.MilestoneStatus",
          },
          {
            name: "evidenceURI",
            type: "string",
            internalType: "string",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPatronageStream",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "deposit",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "ratePerSecond",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "startTime",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "claimed",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "cancelled",
        type: "bool",
        internalType: "bool",
      },
      {
        name: "cancelledAt",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "accrued",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "creatorClaimable",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "supporterRecoverable",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRefundAccounting",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "refundDenominator",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "refundPool",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "totalRefunded",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "refundRemaining",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "contributorCount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "refundClaimCount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "initialized",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "hasPatronageStream",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "pause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "paused",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "penaltySink",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "previewRefund",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "contributor",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "refundClaimed",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "rejectMilestone",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "startPatronage",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "deposit",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "ratePerSecond",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "submitMilestone",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "evidenceURI",
        type: "string",
        internalType: "string",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "token",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IERC20",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "triggerExecutionExpiry",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "triggerFundingExpiry",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "unpause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "BondReturned",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "creator",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "BondSlashed",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "sink",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "CampaignActivated",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "CampaignCreated",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "creator",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "goal",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "bondAmount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "fundingDeadline",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "executionDeadline",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "CampaignFailed",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "reason",
        type: "uint8",
        indexed: false,
        internalType: "enum AdvantageAsymmetryCampaign.FailureReason",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "CampaignSucceeded",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Contributed",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "contributor",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MilestoneApproved",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "amountReleased",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MilestoneRejected",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MilestoneSubmitted",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "milestoneIndex",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "evidenceURI",
        type: "string",
        indexed: false,
        internalType: "string",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PatronageCancelled",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "creator",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "creatorSettlement",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "supporterRefund",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PatronageClaimed",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "creator",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "cumulativeClaimed",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PatronageStarted",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "supporter",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "deposit",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "ratePerSecond",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "startTime",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Paused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RefundClaimed",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "contributor",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "isFinalClaimant",
        type: "bool",
        indexed: false,
        internalType: "bool",
      },
      {
        name: "residue",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RefundPoolInitialized",
    inputs: [
      {
        name: "campaignId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "reason",
        type: "uint8",
        indexed: true,
        internalType: "enum AdvantageAsymmetryCampaign.FailureReason",
      },
      {
        name: "refundDenominator",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "refundPool",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "contributorCount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Unpaused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "EnforcedPause",
    inputs: [],
  },
  {
    type: "error",
    name: "ExpectedPause",
    inputs: [],
  },
  {
    type: "error",
    name: "OwnableInvalidOwner",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "OwnableUnauthorizedAccount",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "ReentrancyGuardReentrantCall",
    inputs: [],
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [
      {
        name: "token",
        type: "address",
        internalType: "address",
      },
    ],
  },
] as const;
