"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount } from "wagmi";
import externalContracts from "~~/contracts/externalContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

const AUDD_DECIMALS = 6;

type MilestoneInput = {
  description: string;
  amount: string;
};

const parseAudd = (value: string) => {
  try {
    return parseUnits(value || "0", AUDD_DECIMALS);
  } catch {
    return 0n;
  }
};

export const CreateCampaign = () => {
  const { address: connectedAddress } = useAccount();

  const [goal, setGoal] = useState("");
  const [bondAmount, setBondAmount] = useState("");
  const [fundingDeadline, setFundingDeadline] = useState("");
  const [executionDeadline, setExecutionDeadline] = useState("");
  const [milestones, setMilestones] = useState<MilestoneInput[]>([{ description: "", amount: "" }]);

  const [approvalComplete, setApprovalComplete] = useState(false);
  const [statusMessage, setStatusMessage] = useState("");
  const [nowTimestamp, setNowTimestamp] = useState(0n);

  const campaignAddress = externalContracts[11155111].AdvantageAsymmetryCampaign.address;

  const { data: verifier } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "owner",
  });

  const { data: penaltySink } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "penaltySink",
  });

  const { writeContractAsync: writeAudd, isMining: isApproving } = useScaffoldWriteContract({
    contractName: "AUDD",
  });

  const { writeContractAsync: writeCampaign, isMining: isCreating } = useScaffoldWriteContract({
    contractName: "AdvantageAsymmetryCampaign",
  });

  const goalBaseUnits = useMemo(() => parseAudd(goal), [goal]);
  const bondBaseUnits = useMemo(() => parseAudd(bondAmount), [bondAmount]);

  const milestoneAmounts = useMemo(() => milestones.map(milestone => parseAudd(milestone.amount)), [milestones]);

  const milestoneTotal = useMemo(() => milestoneAmounts.reduce((sum, amount) => sum + amount, 0n), [milestoneAmounts]);

  const milestoneTotalFormatted = formatUnits(milestoneTotal, AUDD_DECIMALS);

  const fundingTimestamp = fundingDeadline ? BigInt(Math.floor(new Date(fundingDeadline).getTime() / 1000)) : 0n;

  const executionTimestamp = executionDeadline ? BigInt(Math.floor(new Date(executionDeadline).getTime() / 1000)) : 0n;

  const creatorIsBlocked =
    connectedAddress &&
    ((verifier && connectedAddress.toLowerCase() === verifier.toLowerCase()) ||
      (penaltySink && connectedAddress.toLowerCase() === penaltySink.toLowerCase()));

  useEffect(() => {
    setNowTimestamp(BigInt(Math.floor(Date.now() / 1000)));
  }, []);

  useEffect(() => {
    setApprovalComplete(false);
  }, [bondAmount]);

  const updateMilestone = (index: number, field: keyof MilestoneInput, value: string) => {
    setMilestones(current =>
      current.map((milestone, milestoneIndex) =>
        milestoneIndex === index ? { ...milestone, [field]: value } : milestone,
      ),
    );
  };

  const addMilestone = () => {
    setMilestones(current => [...current, { description: "", amount: "" }]);
  };

  const removeMilestone = (index: number) => {
    setMilestones(current => current.filter((_, i) => i !== index));
  };

  const campaignErrors = useMemo(() => {
    const errors: string[] = [];

    if (!connectedAddress) {
      errors.push("Connect a wallet before creating a campaign.");
    }

    if (creatorIsBlocked) {
      errors.push("The verifier and penalty sink cannot create campaigns.");
    }

    if (goalBaseUnits <= 0n) {
      errors.push("Goal must be greater than 0 AUDD.");
    }

    if (bondBaseUnits <= 0n) {
      errors.push("Creator bond must be greater than 0 AUDD.");
    }

    if (milestones.length === 0) {
      errors.push("At least one milestone is required.");
    }

    if (milestoneAmounts.some(amount => amount <= 0n)) {
      errors.push("Every milestone amount must be greater than 0 AUDD.");
    }

    if (milestoneTotal !== goalBaseUnits) {
      errors.push("Milestone amounts must sum exactly to the campaign goal.");
    }

    if (fundingTimestamp <= nowTimestamp) {
      errors.push("Funding deadline must be in the future.");
    }

    if (executionTimestamp === 0n || executionTimestamp <= fundingTimestamp) {
      errors.push("Execution deadline must be later than the funding deadline.");
    }

    return errors;
  }, [
    bondBaseUnits,
    connectedAddress,
    creatorIsBlocked,
    executionTimestamp,
    fundingTimestamp,
    goalBaseUnits,
    milestoneAmounts,
    milestoneTotal,
    milestones.length,
    nowTimestamp,
  ]);

  const handleApproveBond = async () => {
    setStatusMessage("");

    if (!connectedAddress) {
      setStatusMessage("Connect a wallet first.");
      return;
    }

    if (creatorIsBlocked) {
      setStatusMessage("This wallet cannot create campaigns because it is a restricted protocol role.");
      return;
    }

    if (bondBaseUnits <= 0n) {
      setStatusMessage("Enter a creator bond greater than 0 AUDD.");
      return;
    }

    try {
      const result = await writeAudd({
        functionName: "approve",
        args: [campaignAddress, bondBaseUnits],
      });

      if (result) {
        setApprovalComplete(true);
        setStatusMessage(`Bond approval confirmed for ${bondAmount} AUDD.`);
      }
    } catch {
      setStatusMessage("Bond approval was not completed.");
    }
  };

  const handleCreateCampaign = async () => {
    setStatusMessage("");

    if (campaignErrors.length > 0) {
      setStatusMessage(campaignErrors[0]);
      return;
    }

    if (!approvalComplete) {
      setStatusMessage("Approve the creator bond before creating the campaign.");
      return;
    }

    try {
      const result = await writeCampaign({
        functionName: "createCampaign",
        args: [
          goalBaseUnits,
          bondBaseUnits,
          milestones.map(milestone => milestone.description),
          milestoneAmounts,
          fundingTimestamp,
          executionTimestamp,
        ],
      });

      if (result) {
        setStatusMessage("Campaign creation transaction confirmed.");
      }
    } catch {
      setStatusMessage("Campaign creation was not completed.");
    }
  };

  return (
    <div className="card border border-base-300 bg-base-100 shadow-sm">
      <div className="card-body">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">Creator workflow</p>
          <h2 className="card-title mt-1 text-2xl">Create a campaign</h2>
          <p className="mt-2 text-sm text-base-content/65">
            Define the funding goal, post a creator bond and split the goal across milestone-controlled releases.
          </p>
        </div>

        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <label className="form-control">
            <span className="mb-2 text-sm font-medium">Funding goal</span>
            <div className="join">
              <input
                className="input input-bordered join-item w-full"
                inputMode="decimal"
                placeholder="1000"
                value={goal}
                onChange={event => setGoal(event.target.value)}
              />
              <span className="join-item flex items-center border border-base-300 bg-base-200 px-4 text-sm font-semibold">
                AUDD
              </span>
            </div>
          </label>

          <label className="form-control">
            <span className="mb-2 text-sm font-medium">Creator bond</span>
            <div className="join">
              <input
                className="input input-bordered join-item w-full"
                inputMode="decimal"
                placeholder="150"
                value={bondAmount}
                onChange={event => setBondAmount(event.target.value)}
              />
              <span className="join-item flex items-center border border-base-300 bg-base-200 px-4 text-sm font-semibold">
                AUDD
              </span>
            </div>
          </label>

          <label className="form-control">
            <span className="mb-2 text-sm font-medium">Funding deadline</span>
            <input
              className="input input-bordered"
              type="datetime-local"
              value={fundingDeadline}
              onChange={event => setFundingDeadline(event.target.value)}
            />
          </label>

          <label className="form-control">
            <span className="mb-2 text-sm font-medium">Execution deadline</span>
            <input
              className="input input-bordered"
              type="datetime-local"
              value={executionDeadline}
              onChange={event => setExecutionDeadline(event.target.value)}
            />
          </label>
        </div>

        <div className="mt-8">
          <div className="mb-4 flex items-center justify-between gap-4">
            <div>
              <h3 className="font-semibold">Milestones</h3>
              <p className="text-sm text-base-content/55">Milestone amounts must sum exactly to the funding goal.</p>
            </div>

            <button className="btn btn-sm btn-outline" type="button" onClick={addMilestone}>
              + Add milestone
            </button>
          </div>

          <div className="space-y-4">
            {milestones.map((milestone, index) => (
              <div key={index} className="rounded-box border border-base-300 bg-base-200 p-4">
                <div className="mb-3 flex items-center justify-between">
                  <span className="font-semibold">Milestone {index + 1}</span>

                  {milestones.length > 1 && (
                    <button className="btn btn-ghost btn-xs" type="button" onClick={() => removeMilestone(index)}>
                      Remove
                    </button>
                  )}
                </div>

                <div className="grid gap-3 md:grid-cols-[1fr_220px]">
                  <input
                    className="input input-bordered w-full"
                    placeholder="Description"
                    value={milestone.description}
                    onChange={event => updateMilestone(index, "description", event.target.value)}
                  />

                  <div className="join">
                    <input
                      className="input input-bordered join-item w-full"
                      inputMode="decimal"
                      placeholder="500"
                      value={milestone.amount}
                      onChange={event => updateMilestone(index, "amount", event.target.value)}
                    />
                    <span className="join-item flex items-center border border-base-300 bg-base-100 px-3 text-xs font-semibold">
                      AUDD
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-box border border-base-300 bg-base-200 px-4 py-3">
            <span className="text-sm text-base-content/65">Milestone total</span>

            <span
              className={`font-semibold ${
                milestoneTotal === goalBaseUnits && goalBaseUnits > 0n ? "text-success" : "text-base-content"
              }`}
            >
              {milestoneTotalFormatted} / {goal || "0"} AUDD
            </span>
          </div>
        </div>

        <div className="mt-7 rounded-box border border-base-300 p-4">
          <p className="font-semibold">Transaction sequence</p>

          <div className="mt-3 grid gap-3 md:grid-cols-2">
            <button
              className="btn btn-outline"
              type="button"
              disabled={isApproving || !connectedAddress || creatorIsBlocked || bondBaseUnits <= 0n}
              onClick={handleApproveBond}
            >
              {isApproving ? "Approving bond..." : approvalComplete ? "Bond approved ✓" : "1. Approve creator bond"}
            </button>

            <button
              className="btn btn-primary"
              type="button"
              disabled={isCreating || !approvalComplete || campaignErrors.length > 0}
              onClick={handleCreateCampaign}
            >
              {isCreating ? "Creating campaign..." : "2. Create campaign"}
            </button>
          </div>

          {statusMessage && (
            <div className="alert mt-4">
              <span className="text-sm">{statusMessage}</span>
            </div>
          )}

          {campaignErrors.length > 0 && (
            <div className="mt-4">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-base-content/45">Requirements</p>

              <ul className="space-y-1 text-sm text-base-content/60">
                {campaignErrors.map(error => (
                  <li key={error}>• {error}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
