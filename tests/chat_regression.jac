import os;
import from tempfile { TemporaryDirectory }
import from core { journey_api }

with entry:__main__ {
    with TemporaryDirectory() as folder {
        os.environ["JOURNEYS_DB"] = folder + "/regression.sqlite3";
        french = journey_api("create",{"title":"French"}); assert french["ok"];
        recap = journey_api("chat",{"text":"I coded and did some French flashcards today."}); assert recap["ok"], recap;
        actions = recap["data"]["actions"];
        assert len(actions) == 1 and actions[0]["kind"] == "log" and actions[0]["journey_id"] == french["id"], actions;
        simple = journey_api("chat",{"text":"Please create a gardening journey. I want to get into gardening, that's all I know for now. Suggest a tiny starting step; I don't want a questionnaire."}); assert simple["ok"], simple;
        assert len(simple["data"]["actions"]) == 1 and simple["data"]["actions"][0]["kind"] == "create", simple;
        print("PASS: real Gemini ignores unrelated coding and creates an explicitly requested journey without requiring more answers.");
    }
}
