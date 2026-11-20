"""Tools for managing Flagsmith feature flags."""

from typing import Any, Dict, List
try:
    from mcp.server.mcpserver import MCPServer as FastMCP
except (ImportError, ModuleNotFoundError):
    from mcp.server.fastmcp import FastMCP

from flagsmith_mcp.client import FlagsmithClient

client = FlagsmithClient()


def register_flag_tools(mcp: FastMCP) -> None:
    """Register Flag CRUD and traffic split tools onto FastMCP."""

    @mcp.tool()
    async def create_flag(name: str, description: str, variants: List[str]) -> str:
        """Create a multivariate feature flag in Flagsmith with equal variant traffic splits.

        Args:
            name: Flag identifier (e.g., 'cta_button').
            description: What this flag controls.
            variants: List of variant names (e.g., ['variant_a', 'variant_b']).
        """
        result = await client.create_feature(
            name=name,
            description=description,
            variants=variants,
            default_enabled=True,
        )
        return (
            f"Flag '{name}' successfully created (ID: {result.get('id')}).\n"
            f"Type: {result.get('type')}\n"
            f"Variants: {', '.join(variants)}\n"
            f"Initial traffic splits: {result.get('splits')}"
        )

    @mcp.tool()
    async def toggle_flag(flag_name: str, enabled: bool) -> str:
        """Enable or disable a feature flag in the default environment.

        Args:
            flag_name: Name of the feature flag to toggle.
            enabled: True to enable the flag, False to disable.
        """
        result = await client.toggle_flag(flag_name, enabled)
        status_str = "ENABLED" if result.get("enabled") else "DISABLED"
        return f"Flag '{flag_name}' is now {status_str}."

    @mcp.tool()
    async def list_flags() -> str:
        """List all feature flags in the project with their current state, variants, and traffic allocations."""
        store = client._read_store()
        flags = store.get("flags", {})
        if not flags:
            return "No flags found in project."

        lines = ["# Flagsmith Feature Flags\n"]
        for name, data in flags.items():
            state = "Enabled" if data.get("enabled") else "Disabled"
            variants = data.get("variants") or ["(none)"]
            splits = data.get("splits") or {}
            split_desc = ", ".join(f"{k}: {v}%" for k, v in splits.items()) if splits else "standard"
            lines.append(
                f"- **{name}** [{state}] ({data.get('type', 'STANDARD')})\n"
                f"  - Description: {data.get('description', 'N/A')}\n"
                f"  - Variants: {', '.join(variants)}\n"
                f"  - Splits: {split_desc}"
            )
        return "\n".join(lines)

    @mcp.tool()
    async def set_traffic_split(flag_name: str, splits: Dict[str, float]) -> str:
        """Update the multivariate percentage weights for a feature flag.

        Args:
            flag_name: Name of the multivariate flag.
            splits: Mapping of variant name to traffic percentage (e.g. {'variant_a': 80.0, 'variant_b': 20.0}).
        """
        total = sum(splits.values())
        if abs(total - 100.0) > 0.5:
            return f"Error: Traffic splits must sum to 100%. Got {total}%."

        result = await client.set_traffic_split(flag_name, splits)
        formatted = ", ".join(f"{k}: {v}%" for k, v in splits.items())
        return f"Traffic split updated for '{flag_name}': {formatted}"
