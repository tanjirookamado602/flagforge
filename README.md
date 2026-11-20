# FlagForge 🚩

[![PyPI version](https://img.shields.io/badge/pypi-v0.1.0-blue.svg)](https://pypi.org/project/flagsmith-mcp/)
[![GitHub stars](https://img.shields.io/github/stars/tanjirookamado602/flagforge.svg?style=social)](https://github.com/tanjirookamado602/flagforge)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/Python-3.10+-3776AB.svg?logo=python&logoColor=white)](https://python.org)
[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Flagsmith Ready](https://img.shields.io/badge/Flagsmith-Self--Hosted-red.svg)](https://flagsmith.com)
[![Model Context Protocol](https://img.shields.io/badge/MCP-Standard-purple.svg)](https://modelcontextprotocol.io)

> **FlagForge is an open-source, agent-first experimentation engine bridging Flagsmith feature flags with the Model Context Protocol (MCP). It enables AI coding assistants like Claude Code, Cursor, and Antigravity to autonomously provision multivariate feature flags, run Bayesian A/B tests, and automatically ship winning variants into production.**

👉 **Looking for the one-click Claude prompt? See [CLAUDE_PROMPT.md](file:///home/assassinaj602/Projects/New%20folder%20%284%29/SAAS/Hckathon/11%20Project%20PS5/CLAUDE_PROMPT.md).**  
🎬 **Looking for the demo recording outline? See [DEMO_SCRIPT.md](file:///home/assassinaj602/Projects/New%20folder%20%284%29/SAAS/Hckathon/11%20Project%20PS5/DEMO_SCRIPT.md).**

---

## ⚡ Quick Start (Under 10 Minutes)

Get the complete stack running locally with three simple steps:

### 1. Boot Self-Hosted Flagsmith & PostgreSQL
```bash
# Clone the repository
git clone https://github.com/your-username/flagforge.git
cd flagforge

# Start Flagsmith & Postgres
docker compose up -d
```
Flagsmith is now running at **[http://localhost:8000](http://localhost:8000)**!
- **Default Admin Email:** `admin@flagforge.local`
- **Default Password:** `flagforge1234`
- **Project:** `flagforge-demo`

---

### 2. Install and Connect `flagsmith-mcp`
```bash
cd flagsmith-mcp

# Install via pip
pip install -e .

# Test run MCP server
python -m flagsmith_mcp
```

Add `flagsmith-mcp` to your Claude Code or Claude Desktop configuration (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "flagsmith": {
      "command": "python",
      "args": ["-m", "flagsmith_mcp"],
      "env": {
        "FLAGSMITH_BASE_URL": "http://localhost:8000",
        "FLAGSMITH_API_KEY": "559d51e1f203d74e951fc5f12b53765818afdf06",
        "FLAGSMITH_ENVIRONMENT_KEY": "RzHBVWSKkhdTJqQKsfa4bQ",
        "FLAGSMITH_PROJECT_ID": "1"
      }
    }
  }
}
```

---

### 3. Launch the Flutter Demo App
```bash
cd ../flagforge-flutter

# Get dependencies and run on Chrome, Desktop, or Mobile
flutter pub get
flutter run -d chrome
```

---

## 🛠️ MCP Tools Reference

| Tool Name | Inputs | Description |
|-----------|--------|-------------|
| `create_flag` | `name` (str), `description` (str), `variants` (list[str]) | Creates a multivariate feature flag with equal initial traffic allocations. |
| `toggle_flag` | `flag_name` (str), `enabled` (bool) | Instantly enables or disables a feature flag in the target environment. |
| `list_flags` | *(none)* | Returns all feature flags, active states, variant options, and percentage splits. |
| `set_traffic_split` | `flag_name` (str), `splits` (dict[str, float]) | Reallocates percentage traffic weights across variants (must sum to 100%). |
| `create_experiment` | `name` (str), `flag_name` (str), `metric_event` (str), `hypothesis` (str) | Initializes a Flagsmith Experiment linked to a multivariate flag and conversion metric. |
| `get_experiment_results` | `experiment_id` (str) | Computes conversion rates and Bayesian win probabilities across all variants. |
| `ship_winner` | `experiment_id` (str) | Identifies the winning variant from Bayesian results and allocates 100% traffic. |

---

## 🤖 Example: A/B Testing in One Prompt

Prompt your AI coding agent (e.g. Claude Code or Cursor):

```text
Use flagsmith-mcp to create a multivariate flag called cta_button with variants
variant_a and variant_b, then create an experiment measuring cta_clicked events.
```

### Agent Tool Calls & Response:
```text
Calling create_flag(name="cta_button", description="CTA button color & copy", variants=["variant_a", "variant_b"])
=> Flag 'cta_button' successfully created (50% variant_a, 50% variant_b).

Calling create_experiment(name="CTA Button Test", flag_name="cta_button", metric_event="cta_clicked", hypothesis="variant_b increases conversions")
=> Experiment 'CTA Button Test' created (ID: exp_cta_button_test_1849a2). Status: RUNNING.
```

### Check Bayesian Results & Ship Winner:
```text
Calling get_experiment_results(experiment_id="exp_cta_button_test_1849a2")
=>
| Variant     | Impressions | Conversions | Conversion Rate | Win Probability |
|-------------|-------------|-------------|-----------------|-----------------|
| `variant_a` | 120         | 14          | 11.67%          | 1.8%            |
| `variant_b` | 125         | 28          | 22.40%          | 98.2%           |

🏆 Leading Variant: `variant_b` with 98.2% win probability.
✅ Statistically significant result! Ready to ship winner.

Calling ship_winner(experiment_id="exp_cta_button_test_1849a2")
=> 🎉 Shipped Winner for cta_button!
   • variant_b: 100.0% traffic
   • variant_a: 0.0% traffic
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Coding Assistant                      │
│            (Claude Code / Cursor / Antigravity)             │
└──────────────────────────────┬──────────────────────────────┘
                               │ MCP Protocol (JSON-RPC)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    flagsmith-mcp Server                     │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │      Flag Tools       │       │   Experiment Tools    │  │
│  │ (create, toggle, split│       │ (create, stats, ship) │  │
│  └───────────┬───────────┘       └───────────┬───────────┘  │
│              └───────────────────────────────┘              │
│                               │                             │
│                  Bayesian Monte Carlo Engine                │
└──────────────────────────────┬──────────────────────────────┘
                               │ REST API
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Self-Hosted Flagsmith Stack                 │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │   Flagsmith Server    │◄─────►│       PostgreSQL      │  │
│  │   (Port 8000)         │       │       (Port 5432)     │  │
│  └───────────┬───────────┘       └───────────────────────┘  │
│              │                                              │
│              │ Task Processor                               │
│              ▼                                              │
│  ┌───────────────────────┐                                  │
│  │  flagsmith_processor  │                                  │
│  └───────────────────────┘                                  │
└──────────────────────────────┬──────────────────────────────┘
                               │ SDK Evaluation & Events
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               flagforge-flutter Demo Client                 │
│  • Flagsmith Flutter SDK (X-Environment-Key evaluation)      │
│  • Multivariate CTA Button ('Get Started' vs 'Try for Free')│
│  • Live In-App Debug & 50-Click Event Simulation Panel      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
flagforge/
├── docker-compose.yml          # Self-hosted Flagsmith & PostgreSQL stack
├── .env.example                # Template environment variables
├── flagsmith-mcp/              # Python MCP server (FastMCP package)
│   ├── flagsmith_mcp/
│   │   ├── __init__.py
│   │   ├── server.py           # FastMCP server entrypoint
│   │   ├── client.py           # Flagsmith API & Bayesian calculation client
│   │   └── tools/
│   │       ├── flags.py        # create_flag, toggle_flag, list_flags, set_traffic_split
│   │       └── experiments.py  # create_experiment, get_experiment_results, ship_winner
│   ├── pyproject.toml          # Python package specification
│   └── README.md
├── flagforge-flutter/          # Flutter demonstration application
│   ├── lib/
│   │   └── main.dart           # Landing page with multivariate CTA & debug panel
│   ├── pubspec.yaml            # Flutter dependencies (flagsmith, uuid, http)
│   └── .env.example
├── DEMO_SCRIPT.md              # High-impact 3-minute video recording script
└── README.md                   # This documentation
```

---

## 🤝 Contributing & License

Contributions are welcome! Please feel free to submit issues and pull requests.

This project is licensed under the **MIT License**.
