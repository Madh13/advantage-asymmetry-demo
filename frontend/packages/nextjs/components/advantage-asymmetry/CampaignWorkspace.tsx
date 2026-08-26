"use client";

import { Address } from "@scaffold-ui/components";
import { formatUnits } from "viem";
import type { Address as AddressType } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useTargetNetwork } from "~~/hooks/scaffold-eth";

const CAMPAIGN_ID = 0n;
const USDC_DECIMALS = 6;

const CAMPAIGN_STATUS_LABELS = ["Funding", "Active", "Succeeded", "Failed"] as const;
const CAMPAIGN_STATUS_BADGE: Record<number, string> = {
  0: "badge-info",
  1: "badge-primary",
  2: "badge-success",
  3: "badge-error",
};

// Index 2 is Rejected, index 3 is Released -- easy to get backwards, so spelled out in full.
const MILESTONE_STATUS_LABELS = ["Pending", "Submitted", "Rejected", "Released"] as const;
const MILESTONE_STATUS_BADGE: Record<number, string> = {
  0: "badge-neutral",
  1: "badge-info",
  2: "badge-error",
  3: "badge-success",
};

const formatUsdc = (value: bigint | undefined) => (value === undefined ? "—" : formatUnits(value, USDC_DECIMALS));

const formatDeadline = (value: bigint | undefined) =>
  value === undefined || value === 0n ? "—" : new Date(Number(value) * 1000).toLocaleString();

const sameAddress = (a?: string, b?: string) => !!a && !!b && a.toLowerCase() === b.toLowerCase();

type CampaignWorkspaceProps = {
  verifierAddress?: AddressType;
  penaltySinkAddress?: AddressType;
};

export const CampaignWorkspace = ({ verifierAddress, penaltySinkAddress }: CampaignWorkspaceProps) => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  const { data: campaignCount } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "campaignCount",
  });

  // getCampaign reverts for a nonexistent campaignId, so the read is only enabled once
  // campaignCount proves campaign #0 exists. useScaffoldReadContract disables its query
  // whenever an arg is undefined, so passing `undefined` here is the gate itself.
  const campaignExists = campaignCount !== undefined && campaignCount > CAMPAIGN_ID;

  const { data: campaignData } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "getCampaign",
    args: [campaignExists ? CAMPAIGN_ID : undefined],
  });

  // getCampaign returns a flat 13-value tuple, accessed by index -- NOT a named object.
  const creator = campaignData?.[0];
  const goal = campaignData?.[1];
  const bondAmount = campaignData?.[2];
  const totalContributed = campaignData?.[3];
  const totalReleased = campaignData?.[4];
  const fundingDeadline = campaignData?.[6];
  const executionDeadline = campaignData?.[7];
  const status = campaignData?.[9];
  const bondOutcome = campaignData?.[11];
  const milestoneCount = campaignData?.[12];

  // Each milestone read is only enabled once milestoneCount proves that index exists.
  const milestone0Enabled = campaignExists && milestoneCount !== undefined && milestoneCount > 0n;
  const milestone1Enabled = campaignExists && milestoneCount !== undefined && milestoneCount > 1n;

  const { data: milestone0 } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "getMilestone",
    args: [milestone0Enabled ? CAMPAIGN_ID : undefined, milestone0Enabled ? 0n : undefined],
  });

  const { data: milestone1 } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "getMilestone",
    args: [milestone1Enabled ? CAMPAIGN_ID : undefined, milestone1Enabled ? 1n : undefined],
  });

  // contributions() naturally disables itself too: when no wallet is connected,
  // connectedAddress is undefined, which the hook treats the same as any other missing arg.
  const { data: connectedContribution } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "contributions",
    args: [campaignExists ? CAMPAIGN_ID : undefined, connectedAddress],
  });

  const remainingToFund =
    goal !== undefined && totalContributed !== undefined
      ? goal > totalContributed
        ? goal - totalContributed
        : 0n
      : undefined;

  const progressPercent = (() => {
    if (goal === undefined || totalContributed === undefined || goal <= 0n) return 0;
    const pct = Number((totalContributed * 10000n) / goal) / 100;
    return Math.min(100, Math.max(0, pct));
  })();

  const connectedRoleLabel = (() => {
    if (!connectedAddress) return undefined;
    if (sameAddress(connectedAddress, creator)) return "Creator";
    if (sameAddress(connectedAddress, verifierAddress)) return "Verifier";
    if (sameAddress(connectedAddress, penaltySinkAddress)) return "Penalty sink";
    return "External wallet";
  })();

  const bondLine = (() => {
    if (bondOutcome === undefined) return undefined;
    if (bondOutcome === 0) return "Creator bond: posted upfront and unresolved while the campaign remains live.";
    if (bondOutcome === 1) return "Creator bond: returned to the creator.";
    return "Creator bond: slashed to the neutral penalty sink.";
  })();

  const mechanismLine = (() => {
    if (status === 1) {
      return "The funding goal has been reached. Campaign contributions remain subject to milestone-based contract accounting, and funds are released only as milestones are approved.";
    }
    if (status === 2) {
      return "The campaign has completed its milestone lifecycle. Released amounts and creator-bond outcome are determined by the contract's completed state.";
    }
    if (status === 3) {
      return "The campaign has entered a failed state. Refund entitlement is determined from unreleased campaign contributions captured by the contract's failure-time accounting.";
    }
    return "Supporter funds remain in smart-contract-controlled escrow until milestone releases are approved. If the campaign later fails, unreleased campaign contributions form the refund pool under the contract's failure-time accounting.";
  })();

  // ---------- loading / empty phases ----------

  const phase =
    campaignCount === undefined
      ? "loading-count"
      : campaignCount === 0n
        ? "no-campaigns"
        : campaignData === undefined
          ? "loading-campaign"
          : "ready";

  return (
    <div className="card border border-base-300 bg-base-100 shadow-sm">
      <div className="card-body">
        <div className="mb-4 flex items-center justify-between gap-4">
          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">Live campaign</p>
            <h2 className="card-title text-2xl">Campaign #0</h2>
          </div>

          {phase === "ready" && status !== undefined ? (
            <span className={`badge ${CAMPAIGN_STATUS_BADGE[status] ?? "badge-neutral"}`}>
              {CAMPAIGN_STATUS_LABELS[status] ?? "Unknown"}
            </span>
          ) : (
            <span className="badge badge-neutral">{phase === "no-campaigns" ? "Unavailable" : "Loading…"}</span>
          )}
        </div>

        {phase === "loading-count" && <p className="text-sm text-base-content/60">Checking for live campaigns…</p>}

        {phase === "no-campaigns" && (
          <p className="text-sm text-base-content/60">No campaign has been created on this deployment yet.</p>
        )}

        {phase === "loading-campaign" && <p className="text-sm text-base-content/60">Loading campaign #0…</p>}

        {phase === "ready" && (
          <>
            {/* B. Funding overview */}
            <div className="stats stats-vertical border border-base-300 bg-base-200 md:stats-horizontal">
              <div className="stat">
                <div className="stat-title">Goal</div>
                <div className="stat-value text-2xl">{formatUsdc(goal)}</div>
                <div className="stat-desc">USDC</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total contributed</div>
                <div className="stat-value text-2xl">{formatUsdc(totalContributed)}</div>
                <div className="stat-desc">USDC</div>
              </div>
              <div className="stat">
                <div className="stat-title">Remaining to fund</div>
                <div className="stat-value text-2xl">{formatUsdc(remainingToFund)}</div>
                <div className="stat-desc">USDC</div>
              </div>
              <div className="stat">
                <div className="stat-title">Creator bond</div>
                <div className="stat-value text-2xl">{formatUsdc(bondAmount)}</div>
                <div className="stat-desc">USDC</div>
              </div>
              <div className="stat">
                <div className="stat-title">Total released</div>
                <div className="stat-value text-2xl">{formatUsdc(totalReleased)}</div>
                <div className="stat-desc">USDC</div>
              </div>
            </div>

            {/* C. Funding progress */}
            <div className="mt-6">
              <div className="mb-2 flex items-center justify-between text-sm text-base-content/60">
                <span>Funding progress</span>
                <span>{progressPercent.toFixed(2)}%</span>
              </div>
              <progress className="progress progress-primary w-full" value={progressPercent} max={100} />
            </div>

            {/* D. Role information */}
            <div className="mt-6 grid gap-5 md:grid-cols-2">
              <div>
                <p className="mb-2 text-sm font-medium text-base-content/50">Creator</p>
                <Address address={creator} chain={targetNetwork} />
              </div>

              <div>
                <p className="mb-2 text-sm font-medium text-base-content/50">Connected wallet</p>
                {connectedAddress ? (
                  <div>
                    <Address address={connectedAddress} chain={targetNetwork} />
                    {connectedRoleLabel && <p className="mt-1 text-xs text-base-content/60">{connectedRoleLabel}</p>}
                  </div>
                ) : (
                  <p className="text-base-content/60">No wallet connected</p>
                )}
              </div>
            </div>

            {connectedAddress && (
              <p className="mt-3 text-sm text-base-content/60">
                Connected wallet contribution: {formatUsdc(connectedContribution)} USDC
                {connectedContribution !== undefined &&
                  connectedContribution > 0n &&
                  " — this wallet has contributed to this campaign."}
              </p>
            )}

            {/* E. Deadlines */}
            <div className="mt-6 grid gap-5 md:grid-cols-2">
              <div>
                <p className="mb-1 text-sm font-medium text-base-content/50">Funding deadline</p>
                <p className="text-sm">{formatDeadline(fundingDeadline)}</p>
              </div>
              <div>
                <p className="mb-1 text-sm font-medium text-base-content/50">Execution deadline</p>
                <p className="text-sm">{formatDeadline(executionDeadline)}</p>
              </div>
            </div>

            {/* F. Milestones */}
            <div className="mt-6">
              <p className="mb-3 text-sm font-medium text-base-content/50">Milestones</p>
              <div className="space-y-3">
                {[
                  { enabled: milestone0Enabled, data: milestone0, index: 0 },
                  { enabled: milestone1Enabled, data: milestone1, index: 1 },
                ].map(({ enabled, data, index }) => {
                  if (!enabled) return null;

                  if (!data) {
                    return (
                      <div key={index} className="rounded-box border border-base-300 bg-base-200 p-4">
                        <p className="text-sm text-base-content/60">Loading milestone {index + 1}…</p>
                      </div>
                    );
                  }

                  return (
                    <div key={index} className="rounded-box border border-base-300 bg-base-200 p-4">
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div>
                          <p className="font-semibold">
                            Milestone {index + 1}: {data.description}
                          </p>
                          <p className="text-sm text-base-content/60">{formatUsdc(data.amount)} USDC</p>
                        </div>
                        <span className={`badge ${MILESTONE_STATUS_BADGE[data.status] ?? "badge-neutral"}`}>
                          {MILESTONE_STATUS_LABELS[data.status] ?? "Unknown"}
                        </span>
                      </div>
                      {data.evidenceURI && data.evidenceURI.length > 0 && (
                        <p className="mt-2 break-all text-xs text-base-content/60">Evidence: {data.evidenceURI}</p>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>

            {/* G. Mechanism / downside panel */}
            <div className="mt-6 rounded-box border border-base-300 p-4">
              <p className="text-sm font-semibold">Mechanism design</p>
              <p className="mt-2 text-sm text-base-content/65">{mechanismLine}</p>
              {bondLine && <p className="mt-2 text-sm text-base-content/65">{bondLine}</p>}
              <p className="mt-3 text-xs text-base-content/45">
                Smart-contract-controlled escrow with no discretionary platform withdrawal function, subject to a
                centralised milestone verifier in the proof-of-concept. Research prototype only — not audited or
                production-ready.
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
