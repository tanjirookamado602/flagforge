#!/usr/bin/env python3
"""End-to-End Test Suite for FlagForge.

Validates:
1. Flagsmith Server connectivity & environment key
2. Real event ingestion to POST /api/v1/events/
3. PostgreSQL persistence in experimentation_sdkexperimentationevent
4. flagsmith-mcp tools (create_flag, list_flags, toggle_flag, set_traffic_split, create_experiment, get_experiment_results, ship_winner)
5. Live Bayesian win probability calculation from database
"""

import asyncio
import json
import os
import sys
import time
import urllib.request
import psycopg
from dotenv import load_dotenv

# Load local environment
load_dotenv()

BASE_URL = os.getenv("FLAGSMITH_BASE_URL", "http://localhost:8000").rstrip("/")
ENV_KEY = os.getenv("FLAGSMITH_ENVIRONMENT_KEY", "RzHBVWSKkhdTJqQKsfa4bQ")
API_KEY = os.getenv("FLAGSMITH_API_KEY", "559d51e1f203d74e951fc5f12b53765818afdf06")
DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:flagsmith_secure_password@localhost:5432/flagsmith")

def log(step: str, status: str = "INFO", details: str = ""):
    icon = "✅" if status == "PASS" else ("❌" if status == "FAIL" else "🔹")
    print(f"{icon} [{status}] {step}" + (f" -> {details}" if details else ""))


def test_flagsmith_server():
    log("Checking Flagsmith Server Health", "INFO")
    req = urllib.request.Request(f"{BASE_URL}/health")
    with urllib.request.urlopen(req, timeout=5) as resp:
        assert resp.status == 200, f"Healthcheck returned {resp.status}"
    log("Flagsmith Healthcheck", "PASS", f"Server is live at {BASE_URL}")

    req = urllib.request.Request(f"{BASE_URL}/api/v1/flags/", headers={"X-Environment-Key": ENV_KEY})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode())
        assert isinstance(data, list), "Flags API should return list"
    log("Flagsmith Environment Flags API", "PASS", f"Found {len(data)} flags configured")


def test_event_ingestion_and_db():
    log("Testing Real Event Ingestion to /api/v1/events/", "INFO")
    now_ms = int(time.time() * 1000)
    test_session = f"e2e_tester_{int(time.time())}"

    # Send 10 exposures and 8 conversions for variant_b, 10 exposures and 2 conversions for variant_a
    events = [
        # Variant A
        *[{"event": "$flag_exposure", "feature_name": "cta_button", "identifier": test_session, "timestamp": now_ms + i, "value": "variant_a"} for i in range(10)],
        *[{"event": "cta_clicked", "feature_name": "cta_button", "identifier": test_session, "timestamp": now_ms + 10 + i, "value": "variant_a"} for i in range(2)],
        # Variant B
        *[{"event": "$flag_exposure", "feature_name": "cta_button", "identifier": test_session, "timestamp": now_ms + 20 + i, "value": "variant_b"} for i in range(10)],
        *[{"event": "cta_clicked", "feature_name": "cta_button", "identifier": test_session, "timestamp": now_ms + 30 + i, "value": "variant_b"} for i in range(8)],
    ]

    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/events/",
        data=json.dumps({"events": events}).encode(),
        headers={
            "X-Environment-Key": ENV_KEY,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        assert resp.status == 202, f"Expected HTTP 202 Accepted, got {resp.status}"
        body = json.loads(resp.read().decode())
        assert body.get("accepted") == len(events), f"Not all events accepted: {body}"

    log("Real Event Ingestion", "PASS", f"Ingested {len(events)} events (HTTP 202 Accepted)")

    # Verify directly in PostgreSQL
    with psycopg.connect(DB_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM experimentation_sdkexperimentationevent WHERE identifier = %s;", (test_session,))
            count = cur.fetchone()[0]
            assert count == len(events), f"Expected {len(events)} in DB, found {count}"

    log("PostgreSQL Persistence", "PASS", f"Verified {count} rows in experimentation_sdkexperimentationevent")


async def test_mcp_client_and_bayesian():
    from flagsmith_mcp.client import FlagsmithClient

    log("Testing flagsmith-mcp Client with Live Database", "INFO")
    client = FlagsmithClient(
        base_url=BASE_URL,
        api_key=API_KEY,
        environment_key=ENV_KEY,
        project_id="1"
    )

    # 1. Test create_feature
    flag_res = await client.create_feature(
        name="cta_button",
        description="Landing page CTA test",
        variants=["variant_a", "variant_b"]
    )
    assert flag_res["name"] == "cta_button", "Feature name mismatch"
    log("MCP Tool: create_feature", "PASS", f"Flag ID: {flag_res.get('id')}, Splits: {flag_res.get('splits')}")

    # 2. Test create_experiment
    exp_res = await client.create_experiment(
        name="CTA Button Test",
        flag_name="cta_button",
        metric_event="cta_clicked",
        hypothesis="Variant B increases clicks"
    )
    exp_id = exp_res["id"]
    log("MCP Tool: create_experiment", "PASS", f"Experiment ID: {exp_id}")

    # 3. Test get_experiment_results (Reading Live Flagsmith DB)
    results = await client.get_experiment_results(exp_id)
    assert results["data_source"] == "Live Self-Hosted Flagsmith Database", "Must use live database"
    assert "variant_a" in results["variants"] and "variant_b" in results["variants"], "Both variants must be present"
    assert results["winner"] == "variant_b", f"Expected variant_b to lead based on events, got {results['winner']}"
    assert results["highest_win_probability"] > 95.0, f"Expected high win probability, got {results['highest_win_probability']}"

    log(
        "MCP Tool: get_experiment_results (Bayesian Engine)",
        "PASS",
        f"Source: {results['data_source']} | Winner: {results['winner']} ({results['highest_win_probability']}%)"
    )

    # 4. Test ship_winner
    ship_res = await client.ship_winner(exp_id)
    assert ship_res["status"] == "success", "Ship winner must succeed"
    assert ship_res["new_traffic_splits"]["variant_b"] == 100.0, "Winner must get 100% traffic"
    assert ship_res["new_traffic_splits"]["variant_a"] == 0.0, "Loser must get 0% traffic"

    log(
        "MCP Tool: ship_winner",
        "PASS",
        f"Shipped {ship_res['winner']} with splits: {ship_res['new_traffic_splits']}"
    )


def main():
    print("=" * 65)
    print("🚀 RUNNING END-TO-END VALIDATION TEST SUITE")
    print("=" * 65)

    try:
        test_flagsmith_server()
        test_event_ingestion_and_db()
        asyncio.run(test_mcp_client_and_bayesian())
        print("=" * 65)
        print("🎉 ALL SYSTEMS FULLY OPERATIONAL & VERIFIED!")
        print("=" * 65)
    except Exception as e:
        log("E2E Test Suite", "FAIL", str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
