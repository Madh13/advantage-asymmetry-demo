"use client";

import { Address } from "@scaffold-ui/components";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { CreateCampaign } from "~~/components/advantage-asymmetry/CreateCampaign";
import { useScaffoldReadContract, useTargetNetwork } from "~~/hooks/scaffold-eth";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  const { data: campaignCount } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "campaignCount",
  });

  const { data: owner } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "owner",
  });

  const { data: token } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "token",
  });

  const { data: penaltySink } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "penaltySink",
  });

  const { data: paused } = useScaffoldReadContract({
    contractName: "AdvantageAsymmetryCampaign",
    functionName: "paused",
  });

  return (
    <main className="grow bg-base-200">
      <section className="px-6 py-16 md:px-12">
        <div className="mx-auto max-w-6xl">
          <div className="mb-12 max-w-3xl">
            <div className="mb-4 flex flex-wrap gap-2">
              <span className="badge badge-success badge-outline">Sepolia</span>
              <span className="badge badge-info badge-outline">USDC</span>
              <span className="badge badge-neutral badge-outline">Research prototype</span>
            </div>

            <h1 className="text-4xl font-bold tracking-tight md:text-6xl">Advantage Asymmetry</h1>

            <p className="mt-5 text-lg leading-8 text-base-content/70 md:text-xl">
              A stablecoin-based fundraising prototype designed to cap supporter downside while preserving creator
              upside and meaningful skin in the game.
            </p>
          </div>

          <div className="grid gap-5 md:grid-cols-3">
            <div className="card border border-base-300 bg-base-100 shadow-sm">
              <div className="card-body">
                <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">
                  Supporter protection
                </p>
                <h2 className="card-title text-2xl">Downside is visible</h2>
                <p className="text-base-content/70">
                  Unreleased campaign funds remain available for refund if the campaign fails.
                </p>
              </div>
            </div>

            <div className="card border border-base-300 bg-base-100 shadow-sm">
              <div className="card-body">
                <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">Creator incentives</p>
                <h2 className="card-title text-2xl">Skin in the game</h2>
                <p className="text-base-content/70">
                  Creators post a separate bond that can be slashed when creator-caused failure occurs.
                </p>
              </div>
            </div>

            <div className="card border border-base-300 bg-base-100 shadow-sm">
              <div className="card-body">
                <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">Controlled release</p>
                <h2 className="card-title text-2xl">Milestone escrow</h2>
                <p className="text-base-content/70">
                  Campaign funds are released progressively after milestone evidence is reviewed.
                </p>
              </div>
            </div>
          </div>

          <div className="mt-10 grid gap-6 lg:grid-cols-[1.4fr_1fr]">
            <div className="card border border-base-300 bg-base-100 shadow-sm">
              <div className="card-body">
                <div className="mb-4 flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">
                      Live protocol status
                    </p>
                    <h2 className="card-title text-2xl">Sepolia deployment</h2>
                  </div>

                  <span className={`badge ${paused ? "badge-warning" : "badge-success"}`}>
                    {paused ? "Paused" : "Operational"}
                  </span>
                </div>

                <div className="stats stats-vertical border border-base-300 bg-base-200 md:stats-horizontal">
                  <div className="stat">
                    <div className="stat-title">Campaigns</div>
                    <div className="stat-value text-3xl">{campaignCount?.toString() ?? "—"}</div>
                    <div className="stat-desc">Created on-chain</div>
                  </div>

                  <div className="stat">
                    <div className="stat-title">Network</div>
                    <div className="stat-value text-2xl">Sepolia</div>
                    <div className="stat-desc">Chain ID {targetNetwork.id}</div>
                  </div>

                  <div className="stat">
                    <div className="stat-title">Asset</div>
                    <div className="stat-value text-2xl">USDC</div>
                    <div className="stat-desc">6 decimals</div>
                  </div>
                </div>

                <div className="mt-6 grid gap-5 md:grid-cols-2">
                  <div>
                    <p className="mb-2 text-sm font-medium text-base-content/50">Fixed verifier</p>
                    <Address address={owner} chain={targetNetwork} />
                  </div>

                  <div>
                    <p className="mb-2 text-sm font-medium text-base-content/50">Supported token</p>
                    <Address address={token} chain={targetNetwork} />
                  </div>

                  <div>
                    <p className="mb-2 text-sm font-medium text-base-content/50">Neutral penalty sink</p>
                    <Address address={penaltySink} chain={targetNetwork} />
                  </div>

                  <div>
                    <p className="mb-2 text-sm font-medium text-base-content/50">Connected wallet</p>
                    {connectedAddress ? (
                      <Address address={connectedAddress} chain={targetNetwork} />
                    ) : (
                      <p className="text-base-content/60">No wallet connected</p>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="card border border-base-300 bg-base-100 shadow-sm">
              <div className="card-body">
                <p className="text-sm font-semibold uppercase tracking-wide text-base-content/50">Mechanism</p>

                <h2 className="card-title text-2xl">How protection works</h2>

                <div className="mt-4 space-y-5">
                  <div>
                    <div className="mb-2 flex items-center gap-3">
                      <span className="badge badge-primary">1</span>
                      <p className="font-semibold">Fund</p>
                    </div>
                    <p className="pl-10 text-sm text-base-content/65">
                      Supporters contribute USDC into smart-contract-controlled escrow.
                    </p>
                  </div>

                  <div>
                    <div className="mb-2 flex items-center gap-3">
                      <span className="badge badge-primary">2</span>
                      <p className="font-semibold">Verify</p>
                    </div>
                    <p className="pl-10 text-sm text-base-content/65">
                      Funds are released only as campaign milestones are approved.
                    </p>
                  </div>

                  <div>
                    <div className="mb-2 flex items-center gap-3">
                      <span className="badge badge-primary">3</span>
                      <p className="font-semibold">Protect</p>
                    </div>
                    <p className="pl-10 text-sm text-base-content/65">
                      On failure, unreleased funds form the supporter refund pool.
                    </p>
                  </div>

                  <div>
                    <div className="mb-2 flex items-center gap-3">
                      <span className="badge badge-primary">4</span>
                      <p className="font-semibold">Align</p>
                    </div>
                    <p className="pl-10 text-sm text-base-content/65">
                      Creator-caused failure can slash the separate creator bond to a neutral sink.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-10">
            <CreateCampaign />
          </div>
        </div>
      </section>
    </main>
  );
};

export default Home;
