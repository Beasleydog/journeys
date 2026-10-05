async def:pub reminderSettings -> any { return {"enabled":False,"hour":20,"minute":0}; }
async def:pub enableReminders(hour: int, minute: int) -> any {
    return {"ok":False,"message":"Scheduled notifications are available in the native Android/iOS app. Web reminders are in the main Journeys app preferences."};
}
async def:pub disableReminders -> None {}
async def:pub syncReminders(journeys: any, entries: any, hour: int, minute: int) -> None {}
