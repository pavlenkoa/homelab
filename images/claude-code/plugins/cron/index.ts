import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Cron } from "croner";
import { readFile, writeFile, mkdir } from "fs/promises";
import { existsSync } from "fs";
import { z } from "zod";

const JOBS_FILE = process.env.CRON_JOBS_FILE || "/home/claude/workspace/cron-jobs.json";

interface CronJob {
  name: string;
  schedule: string;
  prompt: string;
}

interface JobsFile {
  jobs: CronJob[];
}

const activeJobs = new Map<string, Cron>();
let pendingNotifications: Array<{ name: string; prompt: string }> = [];

async function loadJobs(): Promise<JobsFile> {
  try {
    const data = await readFile(JOBS_FILE, "utf-8");
    return JSON.parse(data);
  } catch {
    return { jobs: [] };
  }
}

async function saveJobs(jobsFile: JobsFile): Promise<void> {
  const dir = JOBS_FILE.substring(0, JOBS_FILE.lastIndexOf("/"));
  if (!existsSync(dir)) {
    await mkdir(dir, { recursive: true });
  }
  await writeFile(JOBS_FILE, JSON.stringify(jobsFile, null, 2));
}

function scheduleCron(job: CronJob): void {
  if (activeJobs.has(job.name)) {
    activeJobs.get(job.name)!.stop();
  }

  const cron = new Cron(job.schedule, { timezone: "Europe/Kyiv" }, () => {
    pendingNotifications.push({ name: job.name, prompt: job.prompt });
  });

  activeJobs.set(job.name, cron);
}

async function initScheduler(): Promise<void> {
  const jobsFile = await loadJobs();
  for (const job of jobsFile.jobs) {
    scheduleCron(job);
  }
}

const server = new McpServer({
  name: "cron",
  version: "1.0.0",
  capabilities: {
    tools: {},
  },
});

server.tool(
  "add_cron",
  "Add a scheduled cron task",
  {
    name: z.string().describe("Unique name for the cron job"),
    schedule: z.string().describe("Cron expression (e.g. '0 8,20 * * *')"),
    prompt: z.string().describe("Prompt to send to Claude when the job fires"),
  },
  async ({ name, schedule, prompt }) => {
    const jobsFile = await loadJobs();
    const existing = jobsFile.jobs.findIndex((j) => j.name === name);

    const job: CronJob = { name, schedule, prompt };

    if (existing >= 0) {
      jobsFile.jobs[existing] = job;
    } else {
      jobsFile.jobs.push(job);
    }

    await saveJobs(jobsFile);
    scheduleCron(job);

    return {
      content: [
        {
          type: "text" as const,
          text: `Cron job "${name}" scheduled: ${schedule} (Europe/Kyiv)`,
        },
      ],
    };
  }
);

server.tool(
  "remove_cron",
  "Remove a scheduled cron task",
  {
    name: z.string().describe("Name of the cron job to remove"),
  },
  async ({ name }) => {
    const jobsFile = await loadJobs();
    const idx = jobsFile.jobs.findIndex((j) => j.name === name);

    if (idx < 0) {
      return {
        content: [{ type: "text" as const, text: `Cron job "${name}" not found` }],
      };
    }

    jobsFile.jobs.splice(idx, 1);
    await saveJobs(jobsFile);

    if (activeJobs.has(name)) {
      activeJobs.get(name)!.stop();
      activeJobs.delete(name);
    }

    return {
      content: [{ type: "text" as const, text: `Cron job "${name}" removed` }],
    };
  }
);

server.tool(
  "list_crons",
  "List all active cron jobs with next fire time",
  {},
  async () => {
    const jobsFile = await loadJobs();

    if (jobsFile.jobs.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No cron jobs configured" }],
      };
    }

    const lines = jobsFile.jobs.map((job) => {
      const cron = activeJobs.get(job.name);
      const next = cron?.nextRun()?.toISOString() || "not scheduled";
      return `${job.name}: ${job.schedule} → next: ${next}\n  prompt: ${job.prompt.length > 100 ? job.prompt.substring(0, 100) + "..." : job.prompt}`;
    });

    return {
      content: [{ type: "text" as const, text: lines.join("\n\n") }],
    };
  }
);

// Poll for pending notifications and deliver them as resource updates
server.resource(
  "pending-notifications",
  "cron://notifications",
  async () => {
    const notifications = [...pendingNotifications];
    pendingNotifications = [];
    return {
      contents: notifications.map((n) => ({
        uri: `cron://job/${n.name}`,
        mimeType: "text/plain",
        text: n.prompt,
      })),
    };
  }
);

await initScheduler();

const transport = new StdioServerTransport();
await server.connect(transport);
