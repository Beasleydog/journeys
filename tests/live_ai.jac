import os;
import from tempfile { TemporaryDirectory }
import from core { journey_api }

with entry:__main__ {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/ai.sqlite3";
        first = journey_api("chat",{"text":"I want to learn piano."});
        assert first["ok"], first;
        print("Onboarding reply:", first["data"]["reply"]);
        second = journey_api("chat",{"text":"I am a total beginner. I want to play a simple favorite song in 8 weeks because music helps me unwind. I have 15 minutes after dinner every day. Minimum: practice one chord for 2 minutes. Please create this journey."});
        assert second["ok"], second;
        assert len(second["data"]["actions"]) > 0, second;
        assert second["data"]["actions"][0]["kind"] == "create";
        assert journey_api("commit",{"id":second["data"]["proposal_id"]})["ok"];
        french = journey_api("create",{"title":"French","minimum":"Review five words","goal":"Have a short conversation"});
        third = journey_api("chat",{"text":"Today I practiced C and G chords on piano for 12 minutes. I also reviewed 10 French words for 5 minutes. Piano felt hard but I showed up. I plan to run tomorrow but did not run today."});
        assert third["ok"], third;
        actions = third["data"]["actions"];
        assert len(actions) == 2, actions;
        assert all(a["kind"] == "log" for a in actions);
        assert journey_api("commit",{"id":third["data"]["proposal_id"]})["ok"];
        snap = journey_api("snapshot",{})["data"];
        assert len(snap["entries"]) == 2;
        recap = journey_api("chat",{"text":"Today I coded and did some French flashcards."});
        assert recap["ok"], recap;
        actions = recap["data"]["actions"];
        assert len(actions) == 1, actions;
        assert actions[0]["kind"] == "log" and actions[0]["journey_id"] == french["id"], actions;
        simple = journey_api("chat",{"text":"Please create a gardening journey. I'd like to get into gardening, that's all I know for now. Don't ask me a questionnaire; suggest a tiny starting step."});
        assert simple["ok"], simple;
        assert len(simple["data"]["actions"]) == 1 and simple["data"]["actions"][0]["kind"] == "create", simple;
        print("PASS: live Gemini onboarding, two-journey extraction, review/save, and unrelated activity never creates a journey.");
        print("Extraction:", actions);
    }
}
