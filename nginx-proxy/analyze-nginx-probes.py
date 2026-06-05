#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta
import gzip
import glob
import re
import subprocess


ACCESS_LOG = "/home/ubuntu/rasp-server/nginx-proxy/data/nginx/logs/access.log"
FAIL2BAN_LOG_GLOB = "/var/log/fail2ban.log*"

LINE_RE = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<ts>[^\]]+)\] "(?P<req>[^"]*)" '
    r'(?P<status>\d{3}) (?P<size>\S+) "(?P<ref>[^"]*)" "(?P<ua>[^"]*)" "(?P<xff>[^"]*)"'
)

CURRENT_METHOD_RE = re.compile(r"^(LEAKIX|CONNECT|TRACE|TRACK|PROPFIND|PRI)(?:\s|$)")
CURRENT_PATH_RE = re.compile(
    r'/(?:[^" ]*)?(?:'
    r"\.env|\.git(?:/|$)|\.DS_Store|server-status|ecp/|owa/|autodiscover/|"
    r"v2/_catalog|telescope/|actuator/|console/|login\.action|SDK/webLanguage|"
    r"HNAP1|GponForm|boaform/|cgi-bin/|phpmyadmin|pma/|adminer|wp-admin|wp-login\.php|"
    r"wp-content|wordpress|xmlrpc\.php|vendor/phpunit|solr/|jenkins/|manager/html|"
    r"geoserver|_profiler|debug/|rpc/|developmentserver/metadatauploader|nice%20ports|"
    r"hello\.world|modx\.zip|joomla\.zip|wp\.zip|wp-admin\.zip|___proxy_subdomain_)"
)

EXTRA_PATH_RE = re.compile(
    r'/(?:[^" ]*)?(?:'
    r"rpc/|shell\?|\.aws|\.svn|\.hg|config\.json|info\.php|setup\.cgi|GponForm|"
    r"goform/|webfig/|api/jsonws|dns-query|remote/login|storage/|backup|dump|"
    r"\.sql|\.bak|\.old)"
)

SCANNER_UA_RE = re.compile(
    r"(l9scan|leakix|zgrab|masscan|nuclei|gobuster|dirbuster|nikto|sqlmap|"
    r"python-requests|Go-http-client|ExchangeScanner|CensysInspect|internetdb)",
    re.I,
)


def parse_ts(value: str) -> datetime:
    return datetime.strptime(value, "%d/%b/%Y:%H:%M:%S %z")


def req_parts(req: str) -> tuple[str, str]:
    parts = req.split()
    method = parts[0] if parts else req
    path = parts[1] if len(parts) >= 2 else ""
    return method, path


def read_access_log() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with open(ACCESS_LOG, "r", errors="replace") as handle:
        for line in handle:
            match = LINE_RE.match(line.rstrip("\n"))
            if not match:
                continue
            row: dict[str, object] = match.groupdict()
            row["dt"] = parse_ts(str(row["ts"]))
            row["status_i"] = int(str(row["status"]))
            method, path = req_parts(str(row["req"]))
            row["method"] = method
            row["path"] = path
            row["current_probe"] = bool(
                CURRENT_METHOD_RE.search(str(row["req"])) or CURRENT_PATH_RE.search(path)
                or row["status_i"] == 444
            )
            row["extra_probe"] = bool(EXTRA_PATH_RE.search(path) or SCANNER_UA_RE.search(str(row["ua"])))
            row["is_444"] = row["status_i"] == 444
            row["broad_probe"] = bool(row["current_probe"] or row["extra_probe"] or row["is_444"])
            rows.append(row)
    return rows


def read_fail2ban_events() -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    ban_events: list[tuple[str, str]] = []
    found_events: list[tuple[str, str]] = []

    for path in sorted(glob.glob(FAIL2BAN_LOG_GLOB)):
        opener = gzip.open if path.endswith(".gz") else open
        try:
            with opener(path, "rt", errors="replace") as handle:
                for line in handle:
                    ban = re.search(
                        r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ .*\[nginx-probe\] Ban (\S+)$",
                        line,
                    )
                    if ban:
                        ban_events.append((ban.group(1), ban.group(2)))
                    found = re.search(
                        r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ .*\[nginx-probe\] Found (\S+) ",
                        line,
                    )
                    if found:
                        found_events.append((found.group(1), found.group(2)))
        except FileNotFoundError:
            pass

    return ban_events, found_events


def active_banned_ips() -> set[str]:
    try:
        output = subprocess.check_output(
            ["sudo", "-n", "fail2ban-client", "status", "nginx-probe"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return set()

    for line in output.splitlines():
        if "Banned IP list:" in line:
            return set(line.split(":", 1)[1].split())
    return set()


def window_eligible(rows: list[dict[str, object]], maxretry: int, findtime_seconds: int) -> set[str]:
    by_ip: dict[str, list[datetime]] = defaultdict(list)
    for row in rows:
        by_ip[str(row["ip"])].append(row["dt"])  # type: ignore[arg-type]

    eligible: set[str] = set()
    for ip, times in by_ip.items():
        times.sort()
        start = 0
        for index, timestamp in enumerate(times):
            while timestamp - times[start] > timedelta(seconds=findtime_seconds):
                start += 1
            if index - start + 1 >= maxretry:
                eligible.add(ip)
                break
    return eligible


def max_hits_by_ip(rows: list[dict[str, object]], findtime_seconds: int) -> dict[str, int]:
    by_ip: dict[str, list[datetime]] = defaultdict(list)
    for row in rows:
        by_ip[str(row["ip"])].append(row["dt"])  # type: ignore[arg-type]

    result: dict[str, int] = {}
    for ip, times in by_ip.items():
        times.sort()
        start = 0
        best = 0
        for index, timestamp in enumerate(times):
            while timestamp - times[start] > timedelta(seconds=findtime_seconds):
                start += 1
            best = max(best, index - start + 1)
        result[ip] = best
    return result


def main() -> None:
    rows = read_access_log()
    ban_events, found_events = read_fail2ban_events()
    ban_ips = {ip for _, ip in ban_events}
    found_ips = {ip for _, ip in found_events}
    active_bans = active_banned_ips()

    current_probe_rows = [row for row in rows if row["current_probe"]]
    broad_probe_rows = [row for row in rows if row["broad_probe"]]
    only_broad_rows = [row for row in broad_probe_rows if not row["current_probe"]]

    start = min((row["dt"] for row in rows), default=None)
    end = max((row["dt"] for row in rows), default=None)
    unique_ips = {str(row["ip"]) for row in rows}
    current_probe_ips = {str(row["ip"]) for row in current_probe_rows}
    broad_probe_ips = {str(row["ip"]) for row in broad_probe_rows}

    status_counts = Counter(str(row["status"]) for row in rows)
    ip_counts = Counter(str(row["ip"]) for row in rows)
    current_ip_counts = Counter(str(row["ip"]) for row in current_probe_rows)
    broad_ip_counts = Counter(str(row["ip"]) for row in broad_probe_rows)
    path_counts = Counter(str(row["path"]).split("?", 1)[0] for row in broad_probe_rows)
    method_counts = Counter(str(row["method"]) for row in broad_probe_rows)

    eligible_current_3_10 = window_eligible(current_probe_rows, 3, 600)
    eligible_current_2_10 = window_eligible(current_probe_rows, 2, 600)
    eligible_current_2_60 = window_eligible(current_probe_rows, 2, 3600)
    eligible_current_1 = window_eligible(current_probe_rows, 1, 600)
    eligible_broad_3_10 = window_eligible(broad_probe_rows, 3, 600)
    eligible_broad_2_10 = window_eligible(broad_probe_rows, 2, 600)
    eligible_broad_1 = window_eligible(broad_probe_rows, 1, 600)

    print("=== Access log coverage ===")
    print(f"file={ACCESS_LOG}")
    print(f"time_range_utc={start} .. {end}")
    print(f"total_requests={len(rows)} unique_ips={len(unique_ips)}")
    print("status_counts=" + ", ".join(f"{key}:{value}" for key, value in sorted(status_counts.items())))
    print()

    print("=== Probe classification ===")
    print(f"current_filter_probe_requests={len(current_probe_rows)} unique_ips={len(current_probe_ips)}")
    print(f"broad_probe_requests={len(broad_probe_rows)} unique_ips={len(broad_probe_ips)}")
    print(
        "only_broad_not_current_requests="
        f"{len(only_broad_rows)} unique_ips={len({str(row['ip']) for row in only_broad_rows})}"
    )
    print(f"fail2ban_found_events={len(found_events)} found_unique_ips={len(found_ips)}")
    print(
        f"fail2ban_ban_events={len(ban_events)} "
        f"banned_ever_unique_ips={len(ban_ips)} active_banned_ips={len(active_bans)}"
    )
    print()

    print("=== Current and alternative thresholds ===")
    print(f"current filter, 3 hits / 10m => eligible_ips={len(eligible_current_3_10)}")
    print(f"current filter, 2 hits / 10m => eligible_ips={len(eligible_current_2_10)}")
    print(f"current filter, 2 hits / 60m => eligible_ips={len(eligible_current_2_60)}")
    print(f"current filter, 1 hit => eligible_ips={len(eligible_current_1)}")
    print(f"broad filter, 3 hits / 10m => eligible_ips={len(eligible_broad_3_10)}")
    print(f"broad filter, 2 hits / 10m => eligible_ips={len(eligible_broad_2_10)}")
    print(f"broad filter, 1 hit => eligible_ips={len(eligible_broad_1)}")
    print()

    print("=== Window concentration ===")
    for name, probe_rows in (("current", current_probe_rows), ("broad", broad_probe_rows)):
        print(f"{name}:")
        for seconds in (600, 1800, 3600, 21600, 86400):
            hits = max_hits_by_ip(probe_rows, seconds)
            eligible_2 = sum(1 for value in hits.values() if value >= 2)
            eligible_3 = sum(1 for value in hits.values() if value >= 3)
            eligible_5 = sum(1 for value in hits.values() if value >= 5)
            top = sorted(hits.items(), key=lambda item: item[1], reverse=True)[:5]
            print(
                f"  window={seconds // 60:4}m ips={len(hits):3} "
                f">=2:{eligible_2:3} >=3:{eligible_3:3} >=5:{eligible_5:3} top={top}"
            )
    print()

    print("=== Overlap ===")
    print(f"current_eligible_not_banned_ever={len(eligible_current_3_10 - ban_ips)}")
    print(f"banned_ever_not_current_eligible={len(ban_ips - eligible_current_3_10)}")
    print(f"broad_2_10m_not_banned_ever={len(eligible_broad_2_10 - ban_ips)}")
    print()

    print("=== Top broad probe IPs ===")
    for ip, count in broad_ip_counts.most_common(25):
        print(
            f"{ip:15} broad={count:3} current={current_ip_counts[ip]:3} "
            f"total={ip_counts[ip]:3} banned_ever={ip in ban_ips} active={ip in active_bans}"
        )
    print()

    print("=== Slow repeat current-probe IPs not banned, current_count >= 3 ===")
    for ip, count in current_ip_counts.most_common():
        if count < 3 or ip in ban_ips:
            continue
        ip_rows = sorted((row for row in current_probe_rows if str(row["ip"]) == ip), key=lambda row: row["dt"])
        print(f"{ip:15} current={count:3} first={ip_rows[0]['dt']} last={ip_rows[-1]['dt']}")
    print()

    print("=== Top broad probe paths ===")
    for path, count in path_counts.most_common(30):
        print(f"{count:4} {path}")
    print()

    print("=== Top broad probe methods ===")
    for method, count in method_counts.most_common(20):
        print(f"{count:4} {method}")
    print()

    print("=== Active banned IPs ===")
    for ip in sorted(active_bans):
        last_rows = [row for row in rows if str(row["ip"]) == ip]
        latest = max(last_rows, key=lambda row: row["dt"]) if last_rows else None
        last_dt = latest["dt"] if latest else "-"
        last_req = latest["req"] if latest else "-"
        print(
            f"{ip:15} broad={broad_ip_counts[ip]} current={current_ip_counts[ip]} "
            f"last={last_dt} last_req={last_req}"
        )


if __name__ == "__main__":
    main()
