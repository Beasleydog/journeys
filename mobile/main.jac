import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, StyleSheet }
import from ..core { journey_api }
import from .reminders { enableReminders, syncReminders, disableReminders, reminderSettings }

glob styles = StyleSheet.create({
    "screen":{"flex":1,"backgroundColor":"#f5f7ef"},
    "body":{"padding":24,"paddingTop":55,"gap":16,"maxWidth":650,"width":"100%","alignSelf":"center"},
    "brand":{"fontSize":30,"fontWeight":"bold","color":"#35533b"},
    "heading":{"fontSize":24,"color":"#35533b","fontWeight":"600"},
    "muted":{"fontSize":13,"color":"#88977b","lineHeight":21},
    "card":{"backgroundColor":"white","padding":20,"borderRadius":18,"gap":12,"borderWidth":1,"borderColor":"#dde6d3"},
    "row":{"flexDirection":"row","gap":10,"alignItems":"center","flexWrap":"wrap"},
    "button":{"backgroundColor":"#456842","padding":13,"borderRadius":10,"alignItems":"center"},
    "buttonText":{"color":"white","fontWeight":"600","fontSize":13},
    "secondary":{"padding":11,"borderRadius":10,"backgroundColor":"#e6eddc"},
    "input":{"borderWidth":1,"borderColor":"#dce6d0","borderRadius":10,"padding":13,"backgroundColor":"white","color":"#365335","fontSize":14},
    "streak":{"fontSize":36,"fontWeight":"bold","color":"#94ab6d"},
    "error":{"color":"#b06a4d","fontSize":13},
    "trail":{"width":25,"height":25,"borderRadius":6,"backgroundColor":"#e7eddf","alignItems":"center","justifyContent":"center"},
    "trailDone":{"width":25,"height":25,"borderRadius":6,"backgroundColor":"#819c62","alignItems":"center","justifyContent":"center"}
});

def mobileDay -> str {
    d = new(Date);
    return str(d.getFullYear()) + "-" + str(d.getMonth()+1).zfill(2) + "-" + str(d.getDate()).zfill(2);
}

def:pub app -> JsxElement {
    has data: any = {"journeys":[],"entries":[],"messages":[],"proposals":[]};
    has selected: str = "", draft: str = "", busy: bool = False, error: str = "", mode: str = "today", note: str = "", minutes: str = "0", reminder: bool = False, hour: str = "20", minute: str = "00", info: str = "";
    has pendingMessage: str = "";

    async def api(op: str, payload: any) -> any {
        result = await journey_api(op,{**payload,"today":mobileDay()});
        if not result["ok"] { raise ValueError(result["error"]); }
        return result;
    }
    async def refresh -> None {
        try { result = await api("snapshot",{}); data = result["data"]; if reminder { await syncReminders(result["data"]["journeys"],result["data"]["entries"],int(hour),int(minute)); } }
        except Exception as e { error = str(e); }
    }
    async can with entry {
        preferences = await reminderSettings(); reminder = preferences["enabled"]; hour = str(preferences["hour"]); minute = str(preferences["minute"]).zfill(2);
        await refresh();
    }
    async def save -> None {
        if busy or not note.strip() { return; } busy = True; error = "";
        try { await api("log",{"journey_id":selected,"note":note,"minutes":minutes,"day":mobileDay()}); note = ""; await refresh(); info = "Progress saved. Your trail is growing."; }
        except Exception as e { error = str(e); }
        finally { busy = False; }
    }
    async def send -> None {
        if busy or not draft.strip() { return; } busy = True; error = "";
        submitted = draft.strip(); pendingMessage = submitted; draft = "";
        try { await api("chat",{"text":submitted}); await refresh(); }
        except Exception as e { error = str(e); draft = submitted + ("\n" + draft if draft else ""); }
        finally { pendingMessage = ""; busy = False; }
    }
    async def commit(id: str, accept: bool) -> None {
        if busy { return; } busy = True;
        try { await api("commit" if accept else "dismiss",{"id":id}); await refresh(); }
        except Exception as e { error = str(e); }
        finally { busy = False; }
    }
    async def toggleReminders -> None {
        try {
            if reminder { await disableReminders(); reminder = False; info = "Reminders turned off."; }
            else { result = await enableReminders(int(hour),int(minute)); reminder = result["ok"]; info = result["message"]; if reminder { await syncReminders(data["journeys"],data["entries"],int(hour),int(minute)); } }
        } except Exception as e { error = str(e); }
    }
    active = [j for j in data["journeys"] if j["status"] == "active"];
    current = [j for j in data["journeys"] if j["id"] == selected];
    <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
        <View style={styles.row}><Text style={styles.brand}>↗ journeys.</Text><Pressable style={styles.secondary} onPress={lambda { refresh(); }}><Text>Refresh ↻</Text></Pressable></View>
        <Text style={styles.muted}>{mobileDay()}</Text>
        <View style={styles.row}>{[<Pressable key={tab} style={styles.secondary} onPress={lambda { mode = tab; }}><Text>{tab}</Text></Pressable> for tab in ["today","chat","reminders"]]}</View>
        {if error { <Text accessibilityRole="alert" style={styles.error}>{error}</Text> }}
        {if info { <Text style={styles.muted}>{info}</Text> }}
        {if mode == "today" {
            <View style={{"gap":16}}>
            <Text style={styles.heading}>Today's steps</Text>
            {if len(active) == 0 { <Text style={styles.muted}>Start a journey with the coach on the chat tab.</Text> }}
            {[<Pressable key={j["id"]} style={styles.card} onPress={lambda { selected = j["id"]; }}><View style={styles.row}><Text style={styles.heading}>{j["title"]}</Text><Text style={styles.streak}>{str(j["streak"])} ✦</Text></View><Text style={styles.muted}>{"✓ Today recorded" if j["today_done"] else "Your next small step: " + j["minimum"]}</Text><Text style={styles.muted}>{str(j["days"])} days of progress · Tap to check in</Text></Pressable> for j in active]}
            {if len(current) > 0 {
                j = current[0];
                <View style={styles.card}><Text style={styles.heading}>{j["title"]}</Text><Text style={styles.muted}>{j["goal"]}</Text><TextInput style={styles.input} multiline={True} placeholder="What did you do today?" value={note} onChangeText={lambda (t: str) { note = t; }}/><TextInput style={styles.input} keyboardType="numeric" placeholder="Minutes" value={minutes} onChangeText={lambda (t: str) { minutes = t; }}/><Pressable disabled={busy} style={styles.button} onPress={lambda { save(); }}><Text style={styles.buttonText}>{"Saving…" if busy else "Record my step ✓"}</Text></Pressable><Text style={styles.heading}>Your story</Text>{[<View key={e["id"]}><Text style={styles.muted}>{e["day"]} · {str(e["minutes"])} min</Text><Text>{e["note"]}</Text></View> for e in data["entries"] if e["journey_id"] == selected]}</View>
            }}
            </View>
        } elif mode == "chat" {
            <View style={{"gap":16}}>
            <Text style={styles.heading}>How was your day?</Text>
            {[<View key={m["id"]} style={styles.card}><Text style={styles.muted}>{"YOU" if m["role"] == "user" else "YOUR COMPASS"}</Text><Text>{m["text"]}</Text></View> for m in data["messages"]]}
            {if pendingMessage { <View style={styles.card}><Text>{pendingMessage}</Text></View><Text style={styles.muted}>Thinking…</Text> }}
            {[<View key={p["id"]} style={styles.card}><Text style={styles.heading}>Ready to save</Text>{[<Text key={idx}>{a["title"] + ": " + a["minimum"] if a["kind"] == "create" else a["day"] + ": " + a["note"]}</Text> for (idx,a) in enumerate(p["actions"])]}<View style={styles.row}><Pressable disabled={busy} style={styles.button} onPress={lambda { commit(p["id"],True); }}><Text style={styles.buttonText}>Save ✓</Text></Pressable><Pressable disabled={busy} style={styles.secondary} onPress={lambda { commit(p["id"],False); }}><Text>Dismiss</Text></Pressable></View></View> for p in data["proposals"]]}
            <TextInput style={styles.input} multiline={True} placeholder="Tell me about your day…" value={draft} onChangeText={lambda (t: str) { draft = t; }}/><Pressable disabled={busy} style={styles.button} onPress={lambda { send(); }}><Text style={styles.buttonText}>{"Thinking…" if busy else "Send ↑"}</Text></Pressable>
            </View>
        } else {
            <Text style={styles.heading}>Daily reminders</Text><Text style={styles.muted}>Remind me about journeys missing today's check-in.</Text><View style={styles.row}><Text>Hour (0–23)</Text><TextInput style={styles.input} keyboardType="numeric" value={hour} onChangeText={lambda (t: str) { hour = t; }}/><Text>Minute</Text><TextInput style={styles.input} keyboardType="numeric" value={minute} onChangeText={lambda (t: str) { minute = t; }}/></View><Pressable style={styles.button} onPress={lambda { toggleReminders(); }}><Text style={styles.buttonText}>{"Turn reminders off" if reminder else "Enable daily reminders"}</Text></Pressable><Text style={styles.muted}>After changing the time, turn reminders off and on. Refresh to sync check-ins from web or CLI.</Text>
        }}
    </ScrollView>
}
