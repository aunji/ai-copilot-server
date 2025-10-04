# setup-ai-copilot-server.md

> Target: **Ubuntu 22.04/24.04**, Intel CPU, **RTX 3060 12GB**, **64GB RAM**  
> Role: **AI Copilot + Chat-Ops + CI mini-factory** (chat-driven build/deploy, logs, weekly roadmap)

---

## 0) System Prep (run as sudo user)

```bash
set -euo pipefail

# Update
sudo apt-get update -y && sudo apt-get upgrade -y

# Basic tools
sudo apt-get install -y build-essential curl wget git unzip ca-certificates gnupg lsb-release jq htop tmux

# Optional: set hostname
# sudo hostnamectl set-hostname aun-ai-server
```
---

## 1) Install Docker (CE) + Compose plugin

```bash
set -euo pipefail

# Remove old versions (safe if absent)
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Official Docker repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Let current user run docker without sudo
sudo usermod -aG docker "$USER"
# Re-open terminal or run: newgrp docker
```
---

## 2) Install NVIDIA Driver + NVIDIA Container Toolkit (“nvidia-docker”)

> If `nvidia-smi` already shows GPU OK, skip 2.1

### 2.1 NVIDIA Driver (auto)

```bash
set -euo pipefail

sudo ubuntu-drivers autoinstall
echo ">>> Reboot is required if new drivers were installed (sudo reboot)"
```

After reboot:

```bash
nvidia-smi
```

### 2.2 NVIDIA Container Toolkit

```bash
set -euo pipefail

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update -y
sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test GPU inside container
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

---

## 3) Project scaffold (one directory)

```bash
set -euo pipefail

mkdir -p ~/ai-copilot && cd ~/ai-copilot
mkdir -p data/{n8n,ollama,grafana,loki} grafana/provisioning/datasources promtail loki chat-gateway

# .env for secrets (edit later)
cat > .env << 'EOF'
# --- GLOBAL ---
TZ=Asia/Bangkok

# --- N8N ---
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=change-me-now
N8N_HOST=localhost
N8N_PROTOCOL=http

# --- DISCORD BOT ---
DISCORD_BOT_TOKEN=

# --- LINE OA ---
LINE_CHANNEL_SECRET=
LINE_CHANNEL_ACCESS_TOKEN=

# --- INTERNAL ---
N8N_WEBHOOK_BASE=http://n8n:5678
OLLAMA_BASE_URL=http://ollama:11434
EOF
```
---

## 4) Docker Compose (all-in-one)

```bash
cat > docker-compose.yml << 'EOF'
version: "3.9"
services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports: ["5678:5678"]
    environment:
      - TZ=${TZ}
      - N8N_SECURE_COOKIE=false
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
    volumes:
      - ./data/n8n:/home/node/.n8n

  ollama:
    image: ollama/ollama:latest
    restart: unless-stopped
    ports: ["11434:11434"]
    environment:
      - TZ=${TZ}
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    volumes:
      - ./data/ollama:/root/.ollama

  chat-gateway:
    build: ./chat-gateway
    restart: unless-stopped
    ports: ["3000:3000"]
    depends_on: [n8n, ollama]
    environment:
      - TZ=${TZ}
      - NODE_ENV=production
      - DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}
      - LINE_CHANNEL_SECRET=${LINE_CHANNEL_SECRET}
      - LINE_CHANNEL_ACCESS_TOKEN=${LINE_CHANNEL_ACCESS_TOKEN}
      - N8N_WEBHOOK_BASE=${N8N_WEBHOOK_BASE}
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL}

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    ports: ["3001:3000"]
    depends_on: [loki]
    environment:
      - TZ=${TZ}
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning

  loki:
    image: grafana/loki:2.9.8
    restart: unless-stopped
    ports: ["3100:3100"]
    command: -config.file=/etc/loki/config.yml
    volumes:
      - ./loki/config.yml:/etc/loki/config.yml:ro
      - ./data/loki:/loki

  promtail:
    image: grafana/promtail:2.9.8
    restart: unless-stopped
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/log:/var/log:ro
EOF
```
---

## 5) Loki/Promtail/Grafana provisioning

```bash
# Loki
cat > loki/config.yml << 'EOF'
auth_enabled: false
server:
  http_listen_port: 3100
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
limits_config:
  ingestion_rate_mb: 8
  ingestion_burst_size_mb: 16
ruler:
  alertmanager_url: http://localhost:9093
EOF

# Promtail
cat > promtail/config.yml << 'EOF'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs:
  - job_name: docker
    static_configs:
      - targets: [localhost]
        labels:
          job: dockerlogs
          __path__: /var/lib/docker/containers/*/*-json.log
EOF

# Grafana datasource
mkdir -p grafana/provisioning/datasources
cat > grafana/provisioning/datasources/loki.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
EOF
```
---

## 6) Chat Gateway (Discord/LINE → n8n + LLM)

```bash
cat > chat-gateway/Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
CMD ["node", "dist/index.js"]
EOF

cat > chat-gateway/package.json << 'EOF'
{
  "name": "chat-gateway",
  "type": "module",
  "version": "1.0.0",
  "scripts": { "build": "tsc", "dev": "node --loader ts-node/esm src/index.ts" },
  "dependencies": {
    "axios": "^1.7.2",
    "discord.js": "^14.16.3",
    "@line/bot-sdk": "^9.0.3",
    "express": "^4.19.2"
  },
  "devDependencies": {
    "typescript": "^5.6.3",
    "ts-node": "^10.9.2"
  }
}
EOF

cat > chat-gateway/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Node",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
EOF

mkdir -p chat-gateway/src

cat > chat-gateway/src/index.ts << 'EOF'
import express from "express";
import { initDiscord } from "./discord.js";
import { lineMiddleware, lineWebhook } from "./line.js";
import router from "./router.js";

const app = express();
app.use(express.json());

app.get("/api/health", (_req, res) => res.json({ ok: true }));
app.post("/line/webhook", lineMiddleware, lineWebhook);

app.post("/api/cmd", async (req, res) => {
  const text = String(req.body?.text || "");
  const out = await router.handleCommand({ channel: "http", user: "api", text });
  res.json({ reply: out });
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`[chat-gateway] listening on ${port}`));
initDiscord().catch(console.error);
EOF

cat > chat-gateway/src/discord.ts << 'EOF'
import { Client, GatewayIntentBits, Partials } from "discord.js";
import router from "./router.js";

export async function initDiscord() {
  const token = process.env.DISCORD_BOT_TOKEN;
  if (!token) { console.warn("No DISCORD_BOT_TOKEN set"); return; }
  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
    partials: [Partials.Channel]
  });
  client.on("ready", () => console.log(`[discord] logged in as ${client.user?.tag}`));
  client.on("messageCreate", async (msg) => {
    if (msg.author.bot) return;
    if (!msg.content.startsWith("!")) return;
    const text = msg.content.slice(1).trim();
    const out = await router.handleCommand({ channel: "discord", user: msg.author.username, text });
    if (out) {
      const chunk = out.length > 1800 ? out.slice(0, 1800) : out;
      msg.reply(chunk);
    }
  });
  await client.login(token);
}
EOF

cat > chat-gateway/src/line.ts << 'EOF'
import line from "@line/bot-sdk";
import router from "./router.js";

const config = {
  channelAccessToken: process.env.LINE_CHANNEL_ACCESS_TOKEN || "",
  channelSecret: process.env.LINE_CHANNEL_SECRET || ""
};

export const lineMiddleware = line.middleware(config);

export async function lineWebhook(req: any, res: any) {
  const client = new line.Client(config);
  const events = req.body.events || [];
  for (const e of events) {
    if (e.type === "message" && e.message.type === "text") {
      const text = e.message.text.trim();
      const out = await router.handleCommand({ channel: "line", user: e.source?.userId || "unknown", text });
      if (out) await client.replyMessage(e.replyToken, { type: "text", text: out.slice(0, 4900) });
    }
  }
  res.status(200).end();
}
EOF

cat > chat-gateway/src/n8nClient.ts << 'EOF'
import axios from "axios";
const base = process.env.N8N_WEBHOOK_BASE || "http://n8n:5678";
export async function trigger(flowSlug: string, payload: any) {
  const url = `${base}/webhook/${flowSlug}`;
  const { data } = await axios.post(url, payload, { timeout: 120_000 });
  return data;
}
EOF

cat > chat-gateway/src/llm.ts << 'EOF'
import axios from "axios";
const OLLAMA = process.env.OLLAMA_BASE_URL || "http://ollama:11434";
export async function localLLM(prompt: string, model = "llama3.1:8b") {
  try {
    const { data } = await axios.post(`${OLLAMA}/api/generate`, { prompt, model, stream: false }, { timeout: 180_000 });
    return data?.response || "";
  } catch (e: any) {
    return `LLM error: ${e.message}`;
  }
}
EOF

cat > chat-gateway/src/router.ts << 'EOF'
import { trigger } from "./n8nClient.js";
import { localLLM } from "./llm.js";

async function cmdScaffold(args: string) {
  const [name, template] = args.split(/\\s+/);
  const res = await trigger("scaffold", { name, template: template || "nextjs-go" });
  return `Scaffold started:\\n${JSON.stringify(res, null, 2)}`;
}
async function cmdDeploy(args: string) {
  const [name, env] = args.split(/\\s+/);
  const res = await trigger("deploy", { name, env: env || "dev" });
  return `Deploy triggered:\\n${JSON.stringify(res, null, 2)}`;
}
async function cmdLogs(args: string) {
  const [name, lines] = args.split(/\\s+/);
  const res = await trigger("logs", { name, lines: Number(lines) || 200 });
  return "```" + (res?.tail || "no logs") + "```";
}
async function cmdRoadmap() {
  const res = await trigger("roadmap-weekly", {});
  return `Roadmap generated:\\n${res?.summary || "check n8n"}`;
}
async function cmdAsk(q: string) {
  const a = await localLLM(\`You are a devops copilot. Answer succinctly:\\nQ: \${q}\\nA:\`);
  return a || "No answer.";
}

export default {
  async handleCommand({ text }: { channel: string; user: string; text: string; }) {
    const [cmd, ...rest] = text.split(" ");
    const arg = rest.join(" ").trim();
    switch ((cmd || "").toLowerCase()) {
      case "scaffold": return cmdScaffold(arg);
      case "deploy":   return cmdDeploy(arg);
      case "logs":     return cmdLogs(arg);
      case "roadmap":  return cmdRoadmap();
      case "ask":      return cmdAsk(arg);
      case "help":
      default:
        return [
          "Commands:",
          "!scaffold <name> [template]",
          "!deploy <name> [env]",
          "!logs <name> [lines]",
          "!roadmap",
          '!ask "question"',
        ].join("\\n");
    }
  }
};
EOF
```
---

## 7) Bring everything up

```bash
cd ~/ai-copilot
docker compose build chat-gateway
docker compose up -d

# Pull a local LLM
curl http://localhost:11434/api/pull -d '{"name":"llama3.1:8b"}'
# Test
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"Hello"}' | jq -r .response
```

Services:
- n8n → `http://SERVER_IP:5678` (basic auth from `.env`)
- Grafana → `http://SERVER_IP:3001` (default `admin/admin`, **change it**)
- Chat Gateway → `http://SERVER_IP:3000/api/health`

---

## 8) Minimal n8n Webhook flows (create in UI)

Create **three** workflows with Webhook (POST) first node:

1) **/webhook/scaffold**  
   - Input: `{ "name": "...", "template": "nextjs-go" }`  
   - Execute Command:
     ```bash
     mkdir -p /workspace/projects/{{$json.name}} && echo "template={{$json.template}}" > /workspace/projects/{{$json.name}}/README.md
     echo "scaffold ok for {{$json.name}} ({{$json.template}})"
     ```
   - Return JSON (Function):
     ```js
     return [{ ok: true, project: $json.name, template: $json.template }];
     ```

2) **/webhook/deploy**  
   - Input: `{ "name": "...", "env": "dev|prod" }`  
   - Execute Command:
     ```bash
     echo "Deploying {{$json.name}} to {{$json.env}}"
     ```
   - Return: `{ ok: true, url: "https://example.com/"+$json.name }`

3) **/webhook/logs**  
   - Input: `{ "name": "...", "lines": 200 }`  
   - Execute Command:
     ```bash
     docker logs --tail {{$json.lines}} {{$json.name}} || true
     ```
   - Return: `{ tail: <command output> }`

> Later replace stubs with your real scaffold/build/deploy scripts.

---

## 9) Discord/LINE tokens & restart

Edit `.env` with your tokens, then:

```bash
docker compose up -d --build chat-gateway
```

Try in Discord channel:
```
!help
!scaffold realestate nextjs-go
!deploy realestate prod
!logs realestate 200
!roadmap
```

---

## 10) Remote access (optional)

- **Tailscale**:
  ```bash
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up
  ```
- **Cloudflare Tunnel** (expose chat-gateway/n8n only if needed)

---

## 11) Daily ops

```bash
docker ps
docker compose logs -f
docker logs -f chat-gateway
docker compose pull && docker compose up -d
```

---

## 12) CPU fallback

Remove GPU reservation under `ollama` in compose, then pull a small CPU model (will run slower).

---

## 13) Uninstall

```bash
cd ~/ai-copilot
docker compose down -v
# rm -rf ~/ai-copilot   # optional
```

---

**End of file.**
