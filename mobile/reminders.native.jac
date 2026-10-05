import from "expo-notifications" { requestPermissionsAsync, setNotificationChannelAsync, scheduleNotificationAsync, getAllScheduledNotificationsAsync, cancelScheduledNotificationAsync, AndroidImportance, SchedulableTriggerInputTypes, setNotificationHandler }
import from "expo-secure-store" { getItemAsync, setItemAsync }

async def _foreground -> any {
    return {"shouldShowBanner":True,"shouldShowList":True,"shouldPlaySound":False,"shouldSetBadge":False};
}
glob _notification_handler: any = setNotificationHandler({"handleNotification":_foreground});

async def:pub reminderSettings -> any {
    raw = await getItemAsync("journeys-reminders");
    return JSON.parse(raw) if raw else {"enabled":False,"hour":20,"minute":0};
}
async def:pub enableReminders(hour: int, minute: int) -> any {
    if hour < 0 or hour > 23 or minute < 0 or minute > 59 { raise ValueError("Choose a valid reminder time."); }
    await setNotificationChannelAsync("journeys",{"name":"Journey reminders","importance":AndroidImportance.DEFAULT});
    permission = await requestPermissionsAsync();
    if permission.status != "granted" { return {"ok":False,"message":"Notifications weren't allowed. You can enable them in device settings later."}; }
    await setItemAsync("journeys-reminders",JSON.stringify({"enabled":True,"hour":hour,"minute":minute}));
    return {"ok":True,"message":"Reminders enabled. Your next seven days are scheduled."};
}
async def:pub disableReminders -> None {
    settings = await reminderSettings(); settings["enabled"] = False;
    await setItemAsync("journeys-reminders",JSON.stringify(settings));
    pending = await getAllScheduledNotificationsAsync();
    for n in pending { if str(n.identifier).startswith("journeys-") { await cancelScheduledNotificationAsync(n.identifier); } }
}
async def:pub syncReminders(journeys: any, entries: any, hour: int, minute: int) -> None {
    pending = await getAllScheduledNotificationsAsync();
    for n in pending { if str(n.identifier).startswith("journeys-") { await cancelScheduledNotificationAsync(n.identifier); } }
    for offset in range(7) {
        target = new(Date); target.setDate(target.getDate()+offset); target.setHours(hour,minute,0,0);
        day = str(target.getFullYear()) + "-" + str(target.getMonth()+1).zfill(2) + "-" + str(target.getDate()).zfill(2);
        if target.getTime() <= Date.now() { continue; }
        for j in journeys {
            done = len([e for e in entries if e["journey_id"] == j["id"] and e["day"] == day]) > 0;
            if j["status"] == "active" and not done {
                await scheduleNotificationAsync({"identifier":"journeys-"+j["id"]+"-"+day,"content":{"title":"Keep " + j["title"] + " growing ✦","body":j["minimum"] + " · Record a small step to keep your streak.","data":{"journey_id":j["id"]}},"trigger":{"type":SchedulableTriggerInputTypes.DATE,"date":target,"channelId":"journeys"}});
            }
        }
    }
}
