import os
import sys
from dotenv import load_dotenv

load_dotenv()

try:
    from mcp.server.mcpserver import MCPServer as FastMCP
except (ImportError, ModuleNotFoundError):
    from mcp.server.fastmcp import FastMCP

from flagsmith_mcp.tools.flags import register_flag_tools
from flagsmith_mcp.tools.experiments import register_experiment_tools

def validate_environment() -> None:
    """Check required environment variables and alert user if missing."""
    api_key = os.getenv("FLAGSMITH_API_KEY")
    env_key = os.getenv("FLAGSMITH_ENVIRONMENT_KEY")
    base_url = os.getenv("FLAGSMITH_BASE_URL", "http://localhost:8000")

    if not api_key and not env_key:
        sys.stderr.write(
            "\n" + "=" * 65 + "\n"
            "⚠️  [FlagForge Notice] Missing Flagsmith Authentication:\n"
            "Neither FLAGSMITH_API_KEY nor FLAGSMITH_ENVIRONMENT_KEY is set.\n"
            "Please copy .env.example to .env and configure your values:\n"
            "  • FLAGSMITH_BASE_URL (default: http://localhost:8000)\n"
            "  • FLAGSMITH_API_KEY (Admin token or Master API key)\n"
            "  • FLAGSMITH_ENVIRONMENT_KEY (Client/Server environment key)\n"
            "Falling back to local simulation store for testing.\n"
            + "=" * 65 + "\n\n"
        )
        sys.stderr.flush()

# Initialize MCP server
mcp = FastMCP("Flagsmith MCP Server")

# Register flag and experimentation tools
register_flag_tools(mcp)
register_experiment_tools(mcp)


def main() -> None:
    """Run the FastMCP server."""
    validate_environment()
    mcp.run()


if __name__ == "__main__":
    main()
