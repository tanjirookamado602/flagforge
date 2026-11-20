# FlagForge — Claude Code Setup Prompt 🤖

> *"Set up an A/B test with one Claude Code prompt."*  
> This file contains the exact prompts and workflow to drive FlagForge and Flagsmith autonomously through Claude Code or Cursor.

---

## 🚀 The One-Prompt Experiment Setup

Copy and paste this single prompt directly into Claude Code:

```text
Use flagsmith-mcp to create a multivariate flag called cta_button with variants variant_a and variant_b, then create an experiment measuring cta_clicked events with the hypothesis "Variant B green CTA increases user conversion rate".
```

### 🎯 Expected Claude Code Actions:
1. Calls MCP tool `create_flag(name="cta_button", description="...", variants=["variant_a", "variant_b"])`
2. Creates the multivariate flag in Flagsmith with a 50/50 initial traffic split.
3. Calls MCP tool `create_experiment(name="CTA Button Optimization", flag_name="cta_button", metric_event="cta_clicked", hypothesis="...")`
4. Confirms that the experiment is live and collecting telemetry.

---

## 📊 The Results & Auto-Ship Prompt

Once traffic/conversions have been simulated (e.g. via the Flutter demo app's debug panel), paste this follow-up prompt:

```text
Check the experiment results for the cta_button experiment. If there is a clear leading variant with high win probability, ship the winner to 100% traffic.
```

### 🎯 Expected Claude Code Actions:
1. Calls MCP tool `get_experiment_results(experiment_id="...")`
2. Analyzes the Bayesian Beta posterior distribution and Monte Carlo win probability.
3. Calls MCP tool `ship_winner(experiment_id="...")`
4. Sets the winning variant to 100% traffic allocation and 0% for competing variants.

---

## ⚙️ Claude Code MCP Configuration

Ensure `flagsmith-mcp` is registered in your `claude_desktop_config.json` or project `.mcp.json`:

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

## 🧪 Live Verification Checkpoints

1. **Flagsmith Dashboard:** Open `http://localhost:8000` → Project `flagforge-demo` → Observe `cta_button` flag.
2. **Flutter App:** Run `flutter run -d chrome` in `flagforge-flutter/` → Click the CTA button → Hit **"Simulate 50 Clicks"**.
3. **Winner Shipped:** Re-run the ship winner prompt → Refresh Flutter app → Notice instant update to Variant B (Green button with "⭐ MOST POPULAR • 14-Day Free Trial" badge).
