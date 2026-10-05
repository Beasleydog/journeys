import argparse;
import json;
import os;
import sys;
import from datetime { date }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError }

def _call(op: str, payload: dict[str, any], server: str) -> dict[str, any] {
    body = {"op":op,"payload":{**payload,"today":date.today().isoformat()}};
    request = Request(server.rstrip("/") + "/function/journey_api", data=json.dumps(body).encode(), headers={"Content-Type":"application/json"}, method="POST");
    with urlopen(request, timeout=60) as response { envelope = json.loads(response.read()); }
    result = envelope.get("data",{}).get("result",envelope);
    if not result.get("ok") { raise ValueError(result.get("error", "Server request failed.")); }
    return result;
}

with entry:__main__ {
    parser = argparse.ArgumentParser(description="Journeys · make a small step, remember the story.");
    parser.add_argument("--server", `default=os.environ.get("JOURNEYS_SERVER", "http://localhost:8000"));
    sub = parser.add_subparsers(dest="command", required=True);
    sub.add_parser("today", help="View today's minimum steps and streaks");
    sub.add_parser("list", help="List all journeys and IDs");
    create = sub.add_parser("create");
    create.add_argument("title"); create.add_argument("--minimum", required=True); create.add_argument("--goal", `default=""); create.add_argument("--why", `default=""); create.add_argument("--minutes", type=int, `default=10);
    log = sub.add_parser("log"); log.add_argument("journey"); log.add_argument("note"); log.add_argument("--minutes", type=int, `default=0); log.add_argument("--day", `default=date.today().isoformat()); log.add_argument("--milestone", action="store_true");
    history = sub.add_parser("history"); history.add_argument("journey");
    chat = sub.add_parser("chat"); chat.add_argument("text");
    commit = sub.add_parser("commit"); commit.add_argument("id");
    status = sub.add_parser("status"); status.add_argument("journey"); status.add_argument("status", choices=["active","paused","complete"]);
    sub.add_parser("export", help="Print the complete journal as JSON");
    args = parser.parse_args();
    try {
        snap = _call("snapshot",{},args.server)["data"];
        identifier = "";
        if args.command in ["log","history","status"] {
            matches = [j for j in snap["journeys"] if j["id"] == args.journey or j["title"].lower() == args.journey.lower()];
            if len(matches) != 1 { raise ValueError("Use an exact journey title or ID from 'list'."); }
            identifier = matches[0]["id"];
        }
        if args.command in ["today","list"] {
            print("JOURNEYS · " + date.today().isoformat());
            for j in snap["journeys"] {
                if args.command == "list" or j["status"] == "active" {
                    print(("✓ " if j["today_done"] else "○ ") + j["title"] + " · " + str(j["streak"]) + " day streak · " + j["status"]);
                    print("  " + j["minimum"] + "\n  " + j["id"]);
                }
            }
            if not snap["journeys"] { print("No journeys yet. Try 'create' or 'chat'."); }
        } elif args.command == "create" {
            result = _call("create",{"title":args.title,"minimum":args.minimum,"goal":args.goal,"why":args.why,"minutes":args.minutes},args.server);
            print("Created journey " + result["id"]);
        } elif args.command == "log" {
            _call("log",{"journey_id":identifier,"note":args.note,"day":args.day,"minutes":args.minutes,"milestone":args.milestone},args.server);
            print("Progress saved. Check your trail on the web or mobile app.");
        } elif args.command == "history" {
            for e in snap["entries"] {
                if e["journey_id"] == identifier { print(e["day"] + " · " + str(e["minutes"]) + " min\n" + e["note"] + "\n"); }
            }
        } elif args.command == "chat" {
            result = _call("chat",{"text":args.text},args.server)["data"];
            print(result["reply"]);
            if result["actions"] { print(json.dumps(result["actions"],indent=2)); print("Review above; save with: jac run cli commit " + result["proposal_id"]); }
        } elif args.command == "commit" { _call("commit",{"id":args.id},args.server); print("Suggestions saved."); }
        elif args.command == "status" { _call("status",{"id":identifier,"status":args.status},args.server); print("Journey is now " + args.status); }
        elif args.command == "export" { print(json.dumps(snap,indent=2)); }
    } except (ValueError, URLError) as error { print("Journeys: " + str(error), file=sys.stderr); sys.exit(1); }
}
