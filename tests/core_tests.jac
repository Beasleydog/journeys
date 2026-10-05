import os;
import json;
import from tempfile { TemporaryDirectory }
import from datetime { date, timedelta }
import from core { journey_api, _db, _review_actions }

test "daily recap cannot create unrequested journeys even if AI proposes one" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new("French"); conn = _db();
        answer = {"create_requested":True,"actions":[{"kind":"create","title":"Coding","minimum":"Write a line of code"},{"kind":"log","journey_id":id,"note":"Reviewed French flashcards","minutes":0}]};
        actions = _review_actions(conn,answer,"I coded and did some French flashcards",date.today().isoformat());
        assert len(actions) == 1; assert actions[0]["kind"] == "log"; assert actions[0]["journey_id"] == id;
        assert len(_review_actions(conn,answer,"Please create a coding journey",date.today().isoformat())) == 2;
        assert len(_review_actions(conn,answer,"Don't create a coding journey",date.today().isoformat())) == 1;
        conn.close();
    }
}

def _new(title: str = "Piano") -> str {
    result = journey_api("create",{"title":title,"minimum":"Practice one chord","minutes":10});
    assert result["ok"], result;
    return result["id"];
}

test "journey creation needs no onboarding questionnaire" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        result = journey_api("create",{"title":"French"}); assert result["ok"], result;
        j = journey_api("snapshot",{})["data"]["journeys"][0];
        assert j["minimum"] == "Spend two minutes on french";
        assert j["why"] == "" and j["goal"] == "";
    }
}
def _log(id: str, days_ago: int = 0) -> dict[str, any] {
    return journey_api("log",{"journey_id":id,"note":"Practiced C major slowly","minutes":5,"day":(date.today()-timedelta(days=days_ago)).isoformat()});
}

test "persists journeys and real progress" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); assert _log(id)["ok"];
        fresh = journey_api("snapshot",{})["data"];
        assert len(fresh["journeys"]) == 1;
        assert fresh["journeys"][0]["today_done"];
        assert fresh["entries"][0]["note"] == "Practiced C major slowly";
    }
}
test "streak counts unique days and keeps yesterday alive" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); _log(id,1); _log(id,2); _log(id,2);
        j = journey_api("snapshot",{})["data"]["journeys"][0];
        assert j["streak"] == 2; assert j["days"] == 2; assert not j["today_done"];
        _log(id); j = journey_api("snapshot",{})["data"]["journeys"][0];
        assert j["streak"] == 3; assert j["total_minutes"] == 20;
    }
}
test "missed day resets streak without deleting history" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); _log(id,2); _log(id,3);
        j = journey_api("snapshot",{})["data"]["journeys"][0];
        assert j["streak"] == 0; assert j["days"] == 2;
    }
}
test "invalid progress cannot affect streaks" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new();
        assert not journey_api("log",{"journey_id":id,"note":""})["ok"];
        assert not journey_api("log",{"journey_id":"missing","note":"Hi"})["ok"];
        assert not journey_api("log",{"journey_id":id,"note":"Hi","minutes":-1})["ok"];
        assert not journey_api("log",{"journey_id":id,"note":"Hi","day":"not-a-date"})["ok"];
        assert not journey_api("log",{"journey_id":id,"note":"Hi","day":"2099-01-01"})["ok"];
        assert not journey_api("log",{"journey_id":id,"note":"Hi","day":(date.today()+timedelta(days=1)).isoformat()})["ok"];
        assert not journey_api("create",{"title":"","minimum":"Practice"})["ok"];
        assert journey_api("create",{"title":"Piano","minimum":""})["ok"];
        assert len(journey_api("snapshot",{})["data"]["entries"]) == 0;
    }
}
test "review saves once even with repeated requests" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); conn = _db();
        action = {"kind":"log","journey_id":id,"note":"Learned C","day":date.today().isoformat()};
        with conn { conn.execute("INSERT INTO proposals(id,actions,created) VALUES(?,?,?)",("review-1",json.dumps([action]),"now")); }
        conn.close();
        assert journey_api("commit",{"id":"review-1"})["ok"];
        assert journey_api("commit",{"id":"review-1"})["already_handled"];
        assert len(journey_api("snapshot",{})["data"]["entries"]) == 1;
    }
}
test "multi journey review is atomic" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); conn = _db();
        actions = [{"kind":"log","journey_id":id,"note":"Learned C"},{"kind":"log","journey_id":"missing","note":"Invalid"}];
        with conn { conn.execute("INSERT INTO proposals(id,actions,created) VALUES(?,?,?)",("review-2",json.dumps(actions),"now")); }
        conn.close();
        assert not journey_api("commit",{"id":"review-2"})["ok"];
        assert len(journey_api("snapshot",{})["data"]["entries"]) == 0;
    }
}
test "dismissed proposal cannot be saved" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        conn = _db();
        with conn { conn.execute("INSERT INTO proposals(id,actions,created) VALUES(?,?,?)",("review-3",json.dumps([{"kind":"create","title":"Piano","minimum":"One chord"}]),"now")); }
        conn.close(); journey_api("dismiss",{"id":"review-3"}); journey_api("commit",{"id":"review-3"});
        assert len(journey_api("snapshot",{})["data"]["journeys"]) == 0;
    }
}
test "edit check in moves calendar progress correctly" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); entry_id = _log(id)["id"];
        result = journey_api("edit_entry",{"id":entry_id,"note":"Actually practiced yesterday","day":(date.today()-timedelta(days=1)).isoformat(),"milestone":True});
        assert result["ok"];
        snap = journey_api("snapshot",{})["data"];
        assert not snap["journeys"][0]["today_done"]; assert snap["journeys"][0]["streak"] == 1;
        assert snap["entries"][0]["milestone"] == 1;
    }
}
test "paused and completed journeys preserve history" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        id = _new(); entry_id = _log(id)["id"]; journey_api("status",{"id":id,"status":"paused"});
        assert not _log(id)["ok"];
        assert journey_api("edit_entry",{"id":entry_id,"note":"Corrected detail on a paused journey"})["ok"];
        journey_api("status",{"id":id,"status":"complete"});
        snap = journey_api("export",{})["data"];
        assert snap["journeys"][0]["status"] == "complete"; assert len(snap["entries"]) == 1;
        journey_api("status",{"id":id,"status":"active"}); assert _log(id)["ok"];
    }
}
test "journeys keep separate streaks" {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/test.sqlite3";
        piano = _new("Piano"); french = _new("French"); _log(piano); _log(piano,1); _log(french);
        js = journey_api("snapshot",{})["data"]["journeys"];
        assert js[0]["streak"] == 2; assert js[1]["streak"] == 1;
    }
}
