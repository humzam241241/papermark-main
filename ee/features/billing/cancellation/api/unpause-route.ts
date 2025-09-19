import { NextApiRequest, NextApiResponse } from "next";

import { stripeInstance } from "@/ee/stripe";
import { authOptions } from "@/pages/api/auth/[...nextauth]";
import { runs } from "@trigger.dev/sdk/v3";
import { waitUntil } from "@vercel/functions";
import { getServerSession } from "next-auth/next";

import prisma from "@/lib/prisma";
import { CustomUser } from "@/lib/types";
import { log } from "@/lib/utils";

export const config = {
  // in order to enable `waitUntil` function
  supportsResponseStreaming: true,
};

export async function handleRoute(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === "POST") {
    // POST /api/teams/:teamId/billing/unpause – unpause a user's subscription
    const session = await getServerSession(req, res, authOptions);
    if (!session) {
      res.status(401).end("Unauthorized");
      return;
    }

    const userId = (session.user as CustomUser).id;
    const { teamId } = req.query as { teamId: string };

    try {
      const team = await prisma.team.findUnique({
        where: {
          id: teamId,
          users: {
            some: {
              userId: userId,
            },
          },
        },
        select: {
          id: true,
          stripeId: true,
          subscriptionId: true,
          endsAt: true,
          plan: true,
          pauseStartsAt: true,
          pauseEndsAt: true,
        },
      });

      if (!team) {
        return res.status(400).json({ error: "Team does not exist" });
      }

      if (!team.stripeId) {
        return res.status(400).json({ error: "No Stripe customer ID" });
      }

      if (!team.subscriptionId) {
        return res.status(400).json({ error: "No subscription ID" });
      }

      if (!team.pauseStartsAt || !team.pauseEndsAt) {
        return res.status(400).json({ error: "Subscription is not paused" });
      }

      const isOldAccount = team.plan.includes("+old");
      const stripe = stripeInstance(isOldAccount);

      // Unpause the subscription in Stripe
      await stripe.subscriptions.update(team.subscriptionId, {
        pause_collection: "",
      });

      await prisma.team.update({
        where: { id: teamId },
        data: {
          pausedAt: null,
          pauseStartsAt: null,
          pauseEndsAt: null,
        },
      });

      // Get all delayed and queued runs for this dataroom
      const allRuns = await runs.list({
        taskIdentifier: ["send-pause-resume-notification"],
        tag: [`team_${teamId}`],
        status: ["DELAYED", "QUEUED"],
        period: "90d",
      });

      // Cancel any existing unsent notification runs for this dataroom
      waitUntil(
        Promise.all([
          allRuns.data.map((run) => runs.cancel(run.id)),
          log({
            message: `Team ${teamId} (${team.plan}) unpaused their subscription. Next billing date: ${team.endsAt}`,
            type: "info",
          }),
        ]),
      );

      res.status(200).json({
        success: true,
        message: "Subscription unpaused successfully",
      });
    } catch (error) {
      console.error("Error unpausing subscription:", error);
      await log({
        message: `Error unpausing subscription for team ${teamId}: ${error}`,
        type: "error",
      });
      res.status(500).json({ error: "Failed to unpause subscription" });
    }
  } else {
    res.setHeader("Allow", ["POST"]);
    res.status(405).end(`Method ${req.method} Not Allowed`);
  }
}
