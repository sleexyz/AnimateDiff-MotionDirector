#!/usr/bin/env -S bun
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { Context, Pod, ensureActivePodIsLoaded as ensurePodStarted, refreshState, getSSHCommand, stopPodAndWait, getFirstPod } from './runpod';


async function loadActivePod(): Promise<Pod | null> {
  if (existsSync('.active_pod')) {
    const pod = JSON.parse(readFileSync('.active_pod').toString());
    console.log("Loaded active pod from .active_pod:", {id: pod.id, name: pod.name, on: pod.runtime !== null});
    return pod;
  }
  return null;
}

type OperationDict = Record<string, Operation>;

interface Operation {
  name: string;
  description: string;
  usage: string;
  requirePodStarted?: boolean;
  run: (ctx: Context, args: string[]) => Promise<void>;
}

const REMOTE_DIR = process.env.REMOTE_DIR || "";
if (!REMOTE_DIR) {
  console.error("REMOTE_DIR is not set. Exiting.");
  process.exit(1);
}

const operations: OperationDict = {
  start: {
    name: "start",
    description: "Start the pod and provision it",
    usage: "pod start",
    requirePodStarted: true,
    run: async (ctx: Context, args: string[]) => {
      const CLOUDFLARE_DEMO_KEY = process.env.CLOUDFLARE_DEMO_KEY || "";
      if (!CLOUDFLARE_DEMO_KEY) {
        console.error("CLOUDFLARE_DEMO_KEY is not set. Exiting.");
        process.exit(1);
      }
      console.log("Provisioning the pod...");
      await spawn(`${ctx.sshCmd} -t "CLOUDFLARE_DEMO_KEY=${CLOUDFLARE_DEMO_KEY} REMOTE_DIR=${REMOTE_DIR} bash -s" < pod_config/provision.sh`);
    },
  },
  stop: {
    name: "stop",
    description: "Stop the pod",
    usage: "pod stop",
    requirePodStarted: false,
    run: async (ctx: Context, args: string[]) => {
      await stopPodAndWait(ctx);
      await spawn("rm .active_pod");
    },
  },
  ssh: {
    name: "ssh",
    description: "SSH into the pod",
    usage: "pod ssh [args]",
    requirePodStarted: true,
    run: async (ctx: Context, args: string[]) => {
      await spawn(`${ctx.sshCmd} ${args.join(" ")}`);
    },
  },
  dev: {
    name: "dev",
    description: "Watches files for changes and syncs them to the pod.",
    usage: "pod dev [args]",
    requirePodStarted: true,
    run: async (ctx: Context, args: string[]) => {
      await spawn(`SSH_CMD="${ctx.sshCmd}" pod/dev.sh ${args.join(" ")}`);
    },
  },
  ranger: {
    name: "ranger",
    description: "Open ranger in the pod",
    usage: "pod ranger",
    requirePodStarted: true,
    run: async (ctx: Context, args: string[]) => {
      await spawn(`${ctx.sshCmd} -t "ranger ${REMOTE_DIR}"`);
    },
  },
  pull: {
    name: "pull",
    description: "Pull files from the pod",
    usage: "pod pull <remote_source> <local_dest>",
    requirePodStarted: true,
    run: async (ctx: Context, args: string[]) => {
      const source = args[0];
      const dest = args[1];
      if (!source || !dest) {
        console.error("Usage: pod pull <remote_source> <local_dest>");
        console.error(`remote source is relative to REMOTE_DIR: ${REMOTE_DIR}`);
        process.exit(1);
      }
      console.log("Copying files from the pod...");
      await spawn(`scp -r -P ${ctx.port} "root@${ctx.ip}:${REMOTE_DIR}/${source}" ${dest}`);
      return;
    },
  },
}

class Context {
  pods: null | Pod[];
  activePod: null | Pod;
  get sshCmd() {
    const {sshCmd} = getSSHCommand(this.activePod!.runtime!);
    return sshCmd;
  }
  get ip() {
    const {ip} = getSSHCommand(this.activePod!.runtime!);
    return ip;
  }
  get port() {
    const {port} = getSSHCommand(this.activePod!.runtime!);
    return port;
  }
}

async function main() {
  const ctx: Context = new Context()

  ctx.activePod = await loadActivePod();
  if (!ctx.activePod) {
    console.error("No active pod found. Refreshing pod data from RunPod.");
    await refreshState(ctx);
    if (!getFirstPod(ctx)) {
      console.error("No pods found.");
      process.exit(1);
    }
  }

  const op = process.argv[2];
  if (op in operations) {
    if (operations[op].requirePodStarted) {
      await ensurePodStarted(ctx);
      writeFileSync('.active_pod', JSON.stringify(ctx.activePod, null, 2));
      if (!ctx.activePod || !ctx.activePod.runtime) {
        console.error("No active pod found.");
        process.exit(1);
      }
    }
    await operations[op].run(ctx, process.argv.slice(3));
    return;
  } else {
    console.error("Usage: pod <operation> [args]");
    console.error("Available operations:");
    for (const op in operations) {
      console.error(`  ${op}: ${operations[op].description}`);
    }
  }
}

async function spawn(command: string) {
  return Bun.spawn(["sh", "-c", command], {
    stdin: 'inherit',
    stdout: 'inherit',
    stderr: 'inherit'
  }).exited;
}

main().catch(console.error);