# FlagForge Demo Video Script 🎬

**Target Duration:** Under 3 minutes  
**Goal:** Showcase autonomous AI-driven feature flagging and experimentation using `flagsmith-mcp` and Flagsmith.

---

## Shot List & Narrative Flow

| Time | Scene | Screen Recording | Voiceover / Action |
|------|-------|------------------|--------------------|
| **0:00 - 0:25** | **The Hook & Differentiator** | Self-hosted Flagsmith running at `localhost:8000` | *"Flagsmith has an official MCP server for basic flag administration, but it lacks an experimentation engine. Meet FlagForge: flagsmith-mcp adds the missing experimentation layer — A/B test creation, Bayesian win probability calculations, and automatic winner rollout, paired with a live Flutter demo kit."* |
| **0:25 - 0:55** | **Agent in Action** | Claude Code / Terminal with `flagsmith-mcp` | Paste prompt: `Use flagsmith-mcp to create a multivariate flag called cta_button with variants variant_a and variant_b, then create an experiment measuring cta_clicked events.` |
| **0:55 - 1:20** | **Live Flagsmith Update** | Switch to Flagsmith Dashboard (`localhost:8000`) | Show the `cta_button` flag created live with 50/50 variant traffic splits without leaving the editor. *"The flag and multivariate options were generated instantly via MCP tools."* |
| **1:20 - 1:55** | **Flutter Demo App** | Browser or Flutter desktop window (`flagforge-flutter`) | Show the landing page. Point out Variant A (Blue 'Get Started'). Click the button. Open debug panel. Show Session ID and click simulation. Hit **"Simulate 50 Clicks"**. Show the snackbar confirming events fired. |
| **1:55 - 2:30** | **Bayesian Win Probability & Auto-Shipping** | Terminal / Claude Code | Prompt: `Check experiment results and ship the winner.` Agent calls `get_experiment_results`, displaying Bayesian table with 98.2% win probability for `variant_b`. Agent then calls `ship_winner`, reallocating 100% traffic to `variant_b`. |
| **2:30 - 2:50** | **Instant Verification** | Flutter app / Flagsmith UI | Refresh Flutter app: button immediately updates to Variant B (Green 'Try for Free') with 100% traffic. Flagsmith dashboard reflects 100% allocation. |
| **2:50 - 3:00** | **Conclusion** | Terminal + Flagsmith UI | *"One prompt. Flag created, experiment running, Bayesian winner shipped automatically. Built with Flagsmith, Flutter, and MCP. Thank you!"* |

---

## Quick Demo Cheat Sheet (Copy-Paste Prompts)

### Prompt 1 — Create Flag & Experiment:
```text
Use flagsmith-mcp to create a multivariate flag called cta_button with variants variant_a and variant_b, then create an experiment measuring cta_clicked events.
```

### Prompt 2 — Inspect Results:
```text
Check the experiment results for the cta_button experiment. What is the leading variant and win probability?
```

### Prompt 3 — Auto-Ship:
```text
Ship the winning variant so 100% of traffic goes to it.
```
