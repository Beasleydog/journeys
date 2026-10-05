import from .core { journey_api }
import from react { useEffect }
glob win: any = window;
glob doc: any = document;

glob recorder: any = None;
glob speech: any = None;
glob audioChunks: list[any] = [];

def localDay -> str {
    d = new(Date);
    return str(d.getFullYear()) + "-" + str(d.getMonth() + 1).zfill(2) + "-" + str(d.getDate()).zfill(2);
}

def:pub JourneyTab(j: any, selected: str, onSelect: any) -> JsxElement {
    <button className={"journey-tab " + j["color"] + (" selected" if selected == j["id"] else "")} onClick={lambda { onSelect(j["id"]); }}>
        <span className="tab-dot"></span><span>{j["title"]}</span><span className="tab-streak">{str(j["streak"]) + " ✦"}</span>
    </button>
}

def:pub JourneyCard(j: any, onSelect: any, onLog: any) -> JsxElement {
    <article className={"journey-card " + j["color"]}>
        <div className="card-top"><span className={"day-status done" if j["today_done"] else "day-status"}>{"✓ Checked in today" if j["today_done"] else "Not checked in"}</span></div>
        <button className="card-title" onClick={lambda { onSelect(j["id"]); }}>{j["title"]}<span>↗</span></button>
        <p className="minimum">{j["minimum"]}</p>
        <div className="card-bottom"><div><strong>{str(j["streak"])}</strong><span>day streak ✦</span></div><button className="text-button" onClick={lambda { onLog(j["id"]); }}>Check in <span>＋</span></button></div>
    </article>
}

def:pub ProgressTrail(j: any, entries: any) -> JsxElement {
    days: list[any] = [];
    for i in range(27, -1, -1) {
        d = new(Date);
        d.setDate(d.getDate() - i);
        value = str(d.getFullYear()) + "-" + str(d.getMonth() + 1).zfill(2) + "-" + str(d.getDate()).zfill(2);
        done = len([e for e in entries if e["journey_id"] == j["id"] and e["day"] == value]) > 0;
        days = days + [{"day": value, "done": done, "label": str(d.getDate())}];
    }
    <div className={"trail-panel " + j["color"]}>
        <div className="trail-head"><h2><span className="flame">✦</span> {str(j["streak"])} <span>day streak</span></h2><span className="subtle">Last 28 days</span></div>
        <div className="trail">{[<div key={d["day"]} title={d["day"] + (" · Progress recorded" if d["done"] else " · No check-in")} className={"trail-day filled" if d["done"] else "trail-day"}><span>{"✦" if d["done"] else "·"}</span><small>{d["label"]}</small></div> for d in days]}</div>
    </div>
}

def:pub JourneysApp -> JsxElement {
    has data: any = {"journeys":[], "entries":[], "messages":[], "proposals":[], "ai_configured":True};
    has selected: str = "home", draft: str = "", busy: bool = False, error: str = "", notice: str = "";
    has modal: str = "", logJourney: str = "", editId: str = "", title: str = "", why: str = "", goal: str = "", minimum: str = "", minutes: str = "10", note: str = "", day: str = localDay(), mood: str = "steady", nextStep: str = "", milestone: bool = False;
    has color: str = "sage";
    has pendingMessage: str = "";
    has recording: bool = False, voiceStatus: str = "", voiceMode: str = "live", search: str = "", reminders: bool = False, reminderTime: str = "20:00";

    async def api(op: str, payload: any) -> any {
        result = await journey_api(op, {**payload, "today": localDay()});
        if not result["ok"] { raise ValueError( result["error"]); }
        return result;
    }
    async def refresh -> None {
        try { fresh = await api("snapshot", {}); data = fresh["data"]; }
        except Exception as e { error = str(e); }
    }
    async can with entry {
        await refresh();
        reminders = localStorage.getItem("journeys-reminders") == "yes";
        reminderTime = localStorage.getItem("journeys-reminder-time") or "20:00";
    }
    can with [data["messages"], pendingMessage, busy] entry {
        el = doc.getElementById("chat-bottom");
        if el { el.scrollIntoView({"behavior":"smooth", "block":"nearest"}); }
    }
    useEffect(lambda {
        timer = setInterval(lambda { if not busy { refresh(); } }, 60000);
        return lambda { clearInterval(timer); };
    }, [busy]);
    useEffect(lambda {
        timer = setInterval(lambda {
            now = new(Date);
            time = str(now.getHours()).zfill(2) + ":" + str(now.getMinutes()).zfill(2);
            if reminders and time == reminderTime and win.Notification and win.Notification.permission == "granted" {
                for j in data["journeys"] {
                    key = "reminded-" + localDay() + "-" + j["id"];
                    if j["status"] == "active" and not j["today_done"] and not localStorage.getItem(key) {
                        new(win.Notification, "Keep your " + j["title"] + " journey going", {"body":j["minimum"] + " · Record a small step today.", "tag":key});
                        localStorage.setItem(key,"yes");
                    }
                }
            }
        }, 20000);
        return lambda { clearInterval(timer); };
    }, [data, reminders, reminderTime]);

    async def send -> None {
        if busy or not draft.strip() { return; }
        submitted = draft.strip(); pendingMessage = submitted; draft = "";
        busy = True; error = ""; voiceStatus = "";
        try { await api("chat", {"text":submitted}); await refresh(); }
        except Exception as e { error = str(e); draft = submitted + ("\n" + draft if draft else ""); }
        finally { pendingMessage = ""; busy = False; }
    }
    async def review(identifier: str, save: bool) -> None {
        if busy { return; } busy = True; error = "";
        try { await api("commit" if save else "dismiss", {"id":identifier}); await refresh(); notice = "Saved." if save else "Suggestion dismissed."; }
        except Exception as e { error = str(e); }
        finally { busy = False; }
    }
    def openLog(identifier: str) -> None {
        logJourney = identifier; modal = "log"; editId = ""; note = ""; minutes = "0"; day = localDay(); mood = "steady"; nextStep = ""; milestone = False;
    }
    def openCreate -> None {
        modal = "create"; editId = ""; title = ""; why = ""; goal = ""; minimum = ""; minutes = "10"; color = "sage";
    }
    def editJourney(j: any) -> None {
        modal = "create"; editId = j["id"]; title = j["title"]; why = j["why"]; goal = j["goal"]; minimum = j["minimum"]; minutes = str(j["minutes"]); color = j["color"];
    }
    def editEntry(e: any) -> None {
        modal = "log"; editId = e["id"]; logJourney = e["journey_id"]; note = e["note"]; day = e["day"]; minutes = str(e["minutes"]); mood = e["mood"]; nextStep = e["next_step"]; milestone = bool(e["milestone"]);
    }
    async def saveForm(e: FormEvent) -> None {
        e.preventDefault(); if busy { return; } busy = True; error = "";
        try {
            if modal == "create" {
                await api("edit_journey" if editId else "create", {"id":editId, "title":title, "why":why, "goal":goal, "minimum":minimum, "minutes":minutes, "color":color});
            } else {
                await api("edit_entry" if editId else "log", {"id":editId, "journey_id":logJourney, "day":day, "note":note, "minutes":minutes, "mood":mood, "next_step":nextStep, "milestone":milestone});
            }
            modal = ""; await refresh(); notice = "Saved.";
        } except Exception as err { error = str(err); }
        finally { busy = False; }
    }
    async def changeStatus(identifier: str, status: str) -> None {
        error = "";
        try { await api("status", {"id":identifier, "status":status}); await refresh(); }
        except Exception as e { error = str(e); }
    }
    async def exportData -> None {
        try {
            result = await api("export", {});
            blob = new(win.Blob, [JSON.stringify(result["data"], None, 2)], {"type":"application/json"});
            url = win.URL.createObjectURL(blob); anchor = doc.createElement("a"); anchor.href = url; anchor.download = "journeys-" + localDay() + ".json"; anchor.click(); win.URL.revokeObjectURL(url);
            notice = "Your journal has been exported.";
        } except Exception as e { error = str(e); }
    }
    async def enableReminders -> None {
        error = "";
        if reminders { reminders = False; localStorage.setItem("journeys-reminders","no"); return; }
        if not win.Notification { error = "This browser doesn't support notifications. Use the native mobile app for scheduled reminders."; return; }
        permission = await win.Notification.requestPermission();
        if permission == "granted" { reminders = True; localStorage.setItem("journeys-reminders","yes"); }
        else { error = "Notifications weren't allowed. You can enable them in browser settings later."; }
    }
    def stopVoice -> None {
        if speech { speech.stop(); }
        if recorder and recorder.state == "recording" { recorder.stop(); }
        recording = False;
    }
    async def uploadRecording(reader: any, mime: str) -> None {
        try { result = await api("transcribe", {"audio":str(reader.result).split(",")[1],"mime":mime}); draft = (draft + " " + result["text"]).strip(); voiceStatus = "Transcript ready. Review it, then send."; }
        except Exception as e { error = str(e); voiceStatus = ""; }
        finally { busy = False; }
    }
    async def startVoice -> None {
        error = ""; voiceStatus = "";
        if recording { stopVoice(); return; }
        Speech = win.SpeechRecognition or win.webkitSpeechRecognition;
        if voiceMode == "live" and Speech {
            speech = new(Speech); speech.continuous = True; speech.interimResults = True; speech.lang = win.navigator.language or "en-US";
            baseDraft = draft;
            speech.onresult = lambda (event: any) {
                words = "";
                for i in range(event.results.length) { words += event.results[i][0].transcript + " "; }
                draft = (baseDraft + " " + words).strip();
                voiceStatus = "Listening · your words appear here. Review before sending.";
            };
            speech.onerror = lambda (event: any) { error = "Voice input: " + event.error + ". Try recorded voice or type your check-in."; recording = False; };
            speech.onend = lambda { recording = False; voiceStatus = "Transcript ready. Edit anything, then send."; };
            try { speech.start(); recording = True; voiceStatus = "Listening…"; }
            except Exception { error = "Microphone couldn't start. Check permission or use recorded voice."; }
            return;
        }
        try {
            stream = await win.navigator.mediaDevices.getUserMedia({"audio":True});
            audioChunks = [];
            recorder = new(win.MediaRecorder, stream);
            recorder.ondataavailable = lambda (e: any) { if e.data.size > 0 { audioChunks.append(e.data); } };
            recorder.onstop = lambda {
                for track in stream.getTracks() { track.stop(); }
                recording = False; busy = True; voiceStatus = "Transcribing with Gemini…";
                try {
                    blob = new(win.Blob, audioChunks, {"type":recorder.mimeType});
                    if blob.size > 8000000 { raise ValueError("Recording is too long. Try a shorter voice note."); }
                    reader = new(win.FileReader);
                    reader.onloadend = lambda { uploadRecording(reader, blob.type.split(";")[0]); };
                    reader.readAsDataURL(blob);
                } except Exception as e { error = str(e); busy = False; voiceStatus = ""; }
            };
            recorder.start(); recording = True; voiceStatus = "Recording · tap Stop when you're done.";
        } except Exception { error = "Microphone access failed. Allow the microphone, or type your check-in."; }
    }

    active = [j for j in data["journeys"] if j["status"] == "active"];
    done = len([j for j in active if j["today_done"]]);
    current = [j for j in data["journeys"] if j["id"] == selected];
    logs = [e for e in data["entries"] if e["journey_id"] == selected and (not search or search.lower() in str(e["note"]).lower())];

    <div className="app-shell">
        <aside className="sidebar">
            <a className="brand" href="#" onClick={lambda { selected = "home"; }}><span className="brand-mark">↗</span> journeys<span className="brand-dot">.</span></a>
            <nav aria-label="Journeys"><button className={"home-tab selected" if selected == "home" else "home-tab"} onClick={lambda { selected = "home"; }}>◌ <span>Today</span></button>
                <div className="nav-label">Journeys <button aria-label="Create journey" onClick={openCreate}>＋</button></div>
                {[<JourneyTab key={j["id"]} j={j} selected={selected} onSelect={lambda (id: str) { selected = id; search = ""; }} /> for j in data["journeys"]]}
                <button className="new-journey" onClick={lambda { selected = "home"; draft = "I want to start a new journey. Help me figure out a realistic plan."; }}>＋ Plan a journey</button>
            </nav>
            <div className="side-bottom"><button className="settings-button" onClick={lambda { modal = "settings"; }}>⚙ Settings</button></div>
        </aside>
        <main>
            <header className="topbar"><span className="date-label">{new(Date).toLocaleDateString(win.navigator.language,{"weekday":"short","month":"short","day":"numeric"})}</span></header>
            {if error { <div className="alert error" role="alert">{error}<button aria-label="Dismiss error" onClick={lambda { error = ""; }}>×</button></div> }}
            {if notice { <div className="alert success" role="status">{notice}<button aria-label="Dismiss notice" onClick={lambda { notice = ""; }}>×</button></div> }}
            {if selected == "home" {
                <div className="home-layout"><section className="conversation">
                    <div className="page-intro"><h1>How was your day?</h1></div>
                    <div className="chat-scroll" aria-live="polite">
                        {if len(data["messages"]) == 0 and not pendingMessage { <div className="welcome-message"><span className="coach-icon">✧</span><div><p>What would you like to learn or make time for?</p><div className="suggestions"><button onClick={lambda { draft = "I want to learn a new skill. Can you help me pick a sustainable first step?"; }}>Start a journey ↗</button><button onClick={lambda { draft = "Let me tell you what I did today for my journeys."; }}>Reflect on today ↗</button></div></div></div> }}
                        {[<div key={m["id"]} className={"message " + m["role"]}>{if m["role"] == "assistant" { <span className="coach-icon">✧</span> }}<div><p>{m["text"]}</p></div></div> for m in data["messages"]]}
                        {if pendingMessage { <div className="message user"><div><p>{pendingMessage}</p></div></div> }}
                        {if busy { <div className="thinking" role="status">Thinking<span>…</span></div> }}
                        {[<div className="proposal" key={p["id"]}><h3>Review check-ins</h3>{[<div className="proposed-action" key={idx}><strong>{a["title"] if a["kind"] == "create" else ([j["title"] for j in data["journeys"] if j["id"] == a["journey_id"]][0])}</strong><p>{a["minimum"] if a["kind"] == "create" else a["note"]}</p>{if a["kind"] == "log" { <small>{a["day"]} · {str(a["minutes"])} minutes · {a["mood"]}</small> }}</div> for (idx,a) in enumerate(p["actions"])]}<div className="proposal-buttons"><button className="primary" disabled={busy} onClick={lambda { review(p["id"],True); }}>Save</button><button className="text-button" disabled={busy} onClick={lambda { review(p["id"],False); }}>Dismiss</button></div></div> for p in data["proposals"]]}
                        <div id="chat-bottom"></div>
                    </div>
                    <div className="composer"><textarea aria-label="Message" placeholder="Tell me about your day or your goals…" value={draft} onChange={lambda (e: ChangeEvent) { draft = e.target.value; }} onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" and not e.shiftKey { e.preventDefault(); send(); } }} rows={3} /><div className="composer-bottom"><div><button className={"voice-button recording" if recording else "voice-button"} disabled={busy} aria-label={"Stop recording" if recording else "Start voice input"} onClick={lambda { startVoice(); }}>{("■ Stop" if recording else "♩ Dictate")}</button><select aria-label="Voice mode" value={voiceMode} onChange={lambda (e: ChangeEvent) { voiceMode = e.target.value; }}><option value="live">Live dictation</option><option value="recorded">Recorded voice · Gemini</option></select></div><button className="send-button" aria-label="Send message" disabled={busy or recording or not draft.strip()} onClick={lambda { send(); }}>↑</button></div></div>
                    {if voiceStatus { <div className="composer-hint" role="status">{voiceStatus}</div> }}
                </section><aside className="today-panel"><div className="today-heading"><h2>Today’s steps</h2>{if len(active) > 0 { <span>{str(done)} / {str(len(active))}</span> }}</div>{if len(active) > 0 { <div className="daily-meter"><div style={{"width":str(done * 100 / len(active)) + "%"}}></div></div> }}
                    {[<JourneyCard key={j["id"]} j={j} onSelect={lambda (id: str) { selected = id; }} onLog={openLog} /> for j in active]}
                    {if len(active) == 0 { <div className="empty-card"><p>No active journeys yet.</p><button className="text-button" onClick={openCreate}>Create a journey ＋</button></div> }}
                </aside></div>
            } else {if len(current) > 0 {
                j = current[0];
                <section className="journey-detail"><div className="detail-intro"><h1>{j["title"]}</h1>{if j["why"] { <p>{j["why"]}</p> }}<div className="detail-actions"><button className="primary" disabled={j["status"] != "active"} onClick={lambda { openLog(j["id"]); }}>Check in</button><button className="secondary" onClick={lambda { editJourney(j); }}>Edit journey</button><select aria-label="Journey status" value={j["status"]} onChange={lambda (e: ChangeEvent) { changeStatus(j["id"], e.target.value); }}><option value="active">Active</option><option value="paused">Paused</option><option value="complete">Completed</option></select></div></div>
                    <ProgressTrail j={j} entries={data["entries"]}/><div className="detail-stats"><div><strong>{str(j["days"])}</strong><span>days practiced</span></div><div><strong>{str(j["total_minutes"])}</strong><span>total minutes</span></div><div><strong>{str(j["week_days"])} / 7</strong><span>days this week</span></div></div>
                    <div className="journey-plan"><div><h3>Goal</h3><p>{j["goal"] or "Build a sustainable daily practice."}</p></div><div><h3>Daily minimum</h3><p>{j["minimum"]}</p><small>{str(j["minutes"])} minutes on a typical day</small></div></div>
                    <div className="timeline-header"><h2>History<span> · {str(len(logs))}</span></h2><input aria-label="Search journal" value={search} placeholder="Search entries" onChange={lambda (e: ChangeEvent) { search = e.target.value; }}/></div>
                    {if len(logs) == 0 { <div className="empty-timeline"><span>◌</span><p>{"No matching entries." if search else "No check-ins yet."}</p></div> }}
                    <div className="timeline">{[<article key={e["id"]} className={"timeline-entry milestone" if e["milestone"] else "timeline-entry"}><div className="timeline-dot">{"✦" if e["milestone"] else ""}</div><div className="entry-meta"><time>{e["day"]}</time><span>{str(e["minutes"])} min · {e["mood"]}{" · Milestone ✦" if e["milestone"] else ""}</span><button className="text-button" onClick={lambda { editEntry(e); }}>Edit</button></div><p>{e["note"]}</p>{if e["next_step"] { <div className="next-step"><span>Next:</span> {e["next_step"]}</div> }}</article> for e in logs]}</div>
                </section>
            }}}
        </main>
        {if modal {
            <div className="modal-backdrop"><section className="modal" role="dialog" aria-modal="true" aria-label={"Preferences" if modal == "settings" else "Journey form"}><button className="close-modal" aria-label="Close dialog" onClick={lambda { modal = ""; }}>×</button>
                {if modal == "settings" { <h2>Preferences</h2><div className="setting-row"><div><strong>Daily reminders</strong><p>For journeys still waiting for a check-in.</p></div><button className="secondary" onClick={lambda { enableReminders(); }}>{"Enabled ✓" if reminders else "Enable"}</button></div><label>Remind me at<input type="time" value={reminderTime} onChange={lambda (e: ChangeEvent) { reminderTime = e.target.value; localStorage.setItem("journeys-reminder-time", e.target.value); }}/></label><p className="subtle">Browser reminders work while this app is open. Native mobile reminders can arrive while the app is closed.</p><hr/><h3>Export journal</h3><p>Download all journeys, check-ins and conversations as JSON.</p><button className="primary" onClick={lambda { exportData(); }}>Export my journal ↓</button><p className="subtle">Chat and recorded audio are sent to Gemini when you use those features. Your API key stays on the server.</p> }
                else { <form onSubmit={saveForm}><h2>{"Edit journey" if modal == "create" and editId else "Start a journey" if modal == "create" else "Edit check-in" if editId else "Record your progress"}</h2>
                    {if modal == "create" { <button type="button" className="secondary" onClick={lambda { modal = ""; selected = "home"; startVoice(); }}>Describe your goals by voice</button><label>Journey name<input required maxLength={100} value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} placeholder="Learn to play piano"/></label><label>Why does it matter to you? (optional)<textarea value={why} onChange={lambda (e: ChangeEvent) { why = e.target.value; }} rows={2}/></label><label>What are you working toward? (optional)<input value={goal} onChange={lambda (e: ChangeEvent) { goal = e.target.value; }} placeholder="Play one favorite song without stopping"/></label><label>Daily minimum (optional)<input value={minimum} onChange={lambda (e: ChangeEvent) { minimum = e.target.value; }} placeholder="Practice one chord for two minutes"/></label><label>Journey color<select value={color} onChange={lambda (e: ChangeEvent) { color = e.target.value; }}><option value="sage">Sage</option><option value="clay">Clay</option><option value="blue">Blue</option><option value="gold">Gold</option><option value="violet">Violet</option></select></label><label>Typical daily minutes (optional)<input type="number" min="0" max="1440" value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; }}/></label> }
                    else { <label>Journey<select value={logJourney} onChange={lambda (e: ChangeEvent) { logJourney = e.target.value; }}>{[<option key={j["id"]} value={j["id"]}>{j["title"]}</option> for j in data["journeys"] if j["status"] == "active" or j["id"] == logJourney]}</select></label><label>What did you actually do?<textarea required rows={4} value={note} onChange={lambda (e: ChangeEvent) { note = e.target.value; }} placeholder="Describe what you worked on"/></label><div className="form-grid"><label>Date<input required type="date" value={day} max={localDay()} onChange={lambda (e: ChangeEvent) { day = e.target.value; }}/></label><label>Minutes<input type="number" min="0" max="1440" value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; }}/></label></div><label>How did it feel?<select value={mood} onChange={lambda (e: ChangeEvent) { mood = e.target.value; }}><option value="great">Great · found my flow</option><option value="steady">Steady · showed up</option><option value="tough">Tough · did it anyway</option></select></label><label>Next small step<input value={nextStep} onChange={lambda (e: ChangeEvent) { nextStep = e.target.value; }}/></label><label className="checkbox-label"><input type="checkbox" checked={milestone} onChange={lambda (e: ChangeEvent) { milestone = e.target.checked; }}/> This was a milestone ✦</label> }}
                    {if error { <p className="form-error" role="alert">{error}</p> }}<button className="primary full" type="submit" disabled={busy}>{"Saving…" if busy else "Save journey" if modal == "create" else "Save check-in"}</button>
                </form> }}
            </section></div>
        }}
    </div>
}
