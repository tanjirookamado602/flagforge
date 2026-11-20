"""Tools for managing Flagsmith experiments and Bayesian results."""

from typing import Any
try:
    from mcp.server.mcpserver import MCPServer as FastMCP
except (ImportError, ModuleNotFoundError):
    from mcp.server.fastmcp import FastMCP

from flagsmith_mcp.client import FlagsmithClient

client = FlagsmithClient()


def register_experiment_tools(mcp: FastMCP) -> None:
    """Register Experimentation tools onto FastMCP."""

    @mcp.tool()
    async def create_experiment(
        name: str,
        flag_name: str,
        metric_event: str,
        hypothesis: str = "",
    ) -> str:
        """Create a Flagsmith Experiment linked to a multivariate feature flag and target metric.

        Args:
            name: Name of the experiment (e.g. 'CTA Button Conversion Test').
            flag_name: The multivariate flag under test (e.g. 'cta_button').
            metric_event: Target conversion event key (e.g. 'cta_clicked').
            hypothesis: The hypothesis being tested.
        """
        exp = await client.create_experiment(
            name=name,
            flag_name=flag_name,
            metric_event=metric_event,
            hypothesis=hypothesis,
        )
        return (
            f"Experiment '{name}' created successfully!\n"
            f"- Experiment ID: {exp['id']}\n"
            f"- Target Flag: {flag_name}\n"
            f"- Conversion Metric: {metric_event}\n"
            f"- Hypothesis: {hypothesis or 'N/A'}\n"
            f"- Status: RUNNING\n"
            f"- Variants: {', '.join(exp.get('variants', []))}"
        )

    @mcp.tool()
    async def get_experiment_results(experiment_id: str) -> str:
        """Retrieve conversion rates and Bayesian win probability for an experiment.

        Args:
            experiment_id: The ID of the experiment (e.g., 'exp_cta_button_12345').
        """
        try:
            results = await client.get_experiment_results(experiment_id)
        except Exception as e:
            return f"Error retrieving experiment results: {e}"

        lines = [
            f"# Experiment Results: {results['name']} ({results['experiment_id']})",
            f"Target Flag: `{results['flag_name']}` | Metric: `{results['metric_event']}`\n",
            "| Variant | Impressions | Conversions | Conversion Rate | Win Probability |",
            "|---------|-------------|-------------|-----------------|-----------------|",
        ]

        for variant, data in results["variants"].items():
            lines.append(
                f"| `{variant}` | {data['impressions']} | {data['conversions']} | "
                f"{data['conversion_rate']}% | **{data['win_probability']}%** |"
            )

        winner = results.get("winner")
        win_prob = results.get("highest_win_probability", 0.0)
        lines.append(f"\n🏆 **Leading Variant**: `{winner}` with **{win_prob}%** win probability.")
        if win_prob >= 95.0:
            lines.append("✅ Statistically significant result! Ready to ship winner.")
        else:
            lines.append("⏳ Experiment still gathering evidence.")

        return "\n".join(lines)

    @mcp.tool()
    async def ship_winner(experiment_id: str) -> str:
        """Read experiment Bayesian results, identify the winning variant, and set its traffic split to 100%.

        Args:
            experiment_id: The ID of the experiment.
        """
        try:
            outcome = await client.ship_winner(experiment_id)
        except Exception as e:
            return f"Error shipping winner: {e}"

        lines = [
            f"🎉 **Shipped Winner for {outcome['flag_name']}!**",
            f"- Winner: `{outcome['winner']}`",
            f"- Bayesian Win Probability: **{outcome['win_probability']}**",
            f"- New Traffic Allocation:",
        ]
        for v, split in outcome["new_traffic_splits"].items():
            lines.append(f"  • `{v}`: {split}%")
        lines.append(f"\n{outcome['message']}")
        return "\n".join(lines)
