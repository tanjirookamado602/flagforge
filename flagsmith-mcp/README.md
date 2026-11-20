# flagsmith-mcp

Model Context Protocol (MCP) server for [Flagsmith](https://www.flagsmith.com) feature flagging and experimentation.

Empowers AI coding assistants (such as Claude Code, Cursor, and Antigravity) to:
- Create multivariate feature flags in Flagsmith
- Toggle feature flags across environments
- Inspect flags and traffic splits
- Spin up A/B testing experiments measuring conversion metrics
- Analyze Bayesian win probabilities
- Automatically ship winning variants by re-allocating 100% traffic

## Installation

```bash
pip install flagsmith-mcp
```

Or install in editable mode:

```bash
git clone https://github.com/your-org/flagforge.git
cd flagforge/flagsmith-mcp
pip install -e .
```

## Configuration

Set the following environment variables (or place them in a `.env` file):

```bash
FLAGSMITH_BASE_URL=http://localhost:8000
FLAGSMITH_API_KEY=your_flagsmith_master_api_key_or_token
FLAGSMITH_ENVIRONMENT_KEY=ser.your_environment_key # or client-side key
FLAGSMITH_PROJECT_ID=1
```

## Running the Server

Run directly with Python:

```bash
python -m flagsmith_mcp
```

Or run via the CLI entrypoint:

```bash
flagsmith-mcp
```

## MCP Tools Reference

| Tool | Inputs | Description |
|------|--------|-------------|
| `create_flag` | `name` (str), `description` (str), `variants` (list[str]) | Creates a multivariate feature flag with equal traffic splits. |
| `toggle_flag` | `flag_name` (str), `enabled` (bool) | Enables or disables a flag in the default environment. |
| `list_flags` | *(none)* | Returns all flags in the project with their current state and variants. |
| `set_traffic_split` | `flag_name` (str), `splits` (dict[str, float]) | Updates the multivariate percentage weights for a flag. |
| `create_experiment` | `name` (str), `flag_name` (str), `metric_event` (str), `hypothesis` (str) | Sets up an experiment tied to a multivariate flag and success event. |
| `get_experiment_results` | `experiment_id` (str) | Computes conversion rates and Bayesian win probabilities for all variants. |
| `ship_winner` | `experiment_id` (str) | Identifies the winning variant from Bayesian results and allocates 100% traffic. |

## Claude Code & Cursor Integration

Add to your `mcp.json` or Claude Desktop configuration:

```json
{
  "mcpServers": {
    "flagsmith": {
      "command": "python",
      "args": ["-m", "flagsmith_mcp"],
      "env": {
        "FLAGSMITH_BASE_URL": "http://localhost:8000",
        "FLAGSMITH_API_KEY": "your_api_key",
        "FLAGSMITH_ENVIRONMENT_KEY": "your_environment_key"
      }
    }
  }
}
```
