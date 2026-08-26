"use client";

import React, { useRef } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { hardhat } from "viem/chains";
import { Bars3Icon, CodeBracketIcon } from "@heroicons/react/24/outline";
import { FaucetButton, RainbowKitCustomConnectButton } from "~~/components/scaffold-eth";
import { useOutsideClick, useTargetNetwork } from "~~/hooks/scaffold-eth";

type HeaderMenuLink = {
  label: string;
  href: string;
  icon?: React.ReactNode;
};

export const menuLinks: HeaderMenuLink[] = [
  {
    label: "Overview",
    href: "/",
  },
  {
    label: "Developer",
    href: "/debug",
    icon: <CodeBracketIcon className="h-4 w-4" />,
  },
];

export const HeaderMenuLinks = () => {
  const pathname = usePathname();

  return (
    <>
      {menuLinks.map(({ label, href, icon }) => {
        const isActive = pathname === href;

        return (
          <li key={href} className="h-full">
            <Link
              href={href}
              passHref
              className={`${
                isActive ? "bg-base-300" : ""
              } hover:bg-base-300 focus:!bg-base-300 flex h-full items-center gap-2 whitespace-nowrap px-4 text-sm`}
            >
              {icon}
              <span>{label}</span>
            </Link>
          </li>
        );
      })}
    </>
  );
};

export const Header = () => {
  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;

  const burgerMenuRef = useRef<HTMLDetailsElement>(null);

  useOutsideClick(burgerMenuRef, () => {
    burgerMenuRef?.current?.removeAttribute("open");
  });

  return (
    <div className="navbar sticky top-0 z-20 min-h-16 shrink-0 justify-between border-b border-base-300 bg-base-100 p-0 sm:px-2 lg:static">
      <div className="navbar-start w-auto self-stretch">
        <details className="dropdown" ref={burgerMenuRef}>
          <summary className="btn btn-ghost ml-1 hover:bg-transparent lg:hidden">
            <Bars3Icon className="h-1/2" />
          </summary>

          <ul
            className="menu menu-compact dropdown-content mt-3 w-52 bg-base-100 p-2 shadow-lg"
            onClick={() => {
              burgerMenuRef?.current?.removeAttribute("open");
            }}
          >
            <HeaderMenuLinks />
          </ul>
        </details>

        <Link href="/" passHref className="ml-4 mr-6 hidden shrink-0 items-center gap-3 lg:flex">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary font-bold text-primary-content">
            AA
          </div>

          <div className="flex flex-col">
            <span className="font-bold leading-tight">Advantage Asymmetry</span>
            <span className="text-xs text-base-content/55">Research prototype</span>
          </div>
        </Link>

        <ul className="m-0 hidden h-full list-none p-0 lg:flex lg:flex-nowrap">
          <HeaderMenuLinks />
        </ul>
      </div>

      <div className="navbar-end mr-4 grow">
        <RainbowKitCustomConnectButton />
        {isLocalNetwork && <FaucetButton />}
      </div>
    </div>
  );
};
