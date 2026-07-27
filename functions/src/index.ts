import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

initializeApp();

const TIME_ZONE = "Asia/Tokyo";
const REGION = "asia-northeast1";
const MAX_LIMIT = 20;

type NotificationKind = "morning" | "noon";

interface NotificationSettings {
  enabled?: boolean;
  morningHour?: number;
  morningMinute?: number;
  morningLimit?: number;
  noonHour?: number;
  noonMinute?: number;
  weekLimit?: number;
}

interface LocalTime {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

/**
 * Runs every minute and reads only settings indexed for the current time.
 * The scheduler itself and all date boundaries use Japan time.
 */
export const sendDailyTaskNotifications = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: TIME_ZONE,
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
    retryCount: 1,
  },
  async (event) => {
    const now = localParts(new Date(event.scheduleTime));
    logger.info("Scheduled task notification scan started", {
      scheduleTime: event.scheduleTime,
      localTime: now,
    });
    const db = getFirestore();
    const timeKey = `${pad(now.hour)}:${pad(now.minute)}`;
    const morningSlot = `m${timeKey}`;
    const noonSlot = `n${timeKey}`;
    const settings = await db
      .collectionGroup("settings")
      .where(
        "notifySlots",
        "array-contains-any",
        [morningSlot, noonSlot],
      )
      .get();

    const work: Array<() => Promise<void>> = [];
    for (const document of settings.docs) {
      if (document.id !== "notifications") continue;
      const value = document.data() as NotificationSettings;
      const uid = document.ref.parent.parent?.id;
      if (!uid) continue;
      const slots = document.get("notifySlots");
      if (!Array.isArray(slots)) continue;

      if (slots.includes(morningSlot)) {
        work.push(() => sendUserSummary(db, uid, value, "morning", now));
      }
      if (slots.includes(noonSlot)) {
        work.push(() => sendUserSummary(db, uid, value, "noon", now));
      }
    }
    await runInBatches(work, 20);
  },
);

async function sendUserSummary(
  db: Firestore,
  uid: string,
  settings: NotificationSettings,
  kind: NotificationKind,
  now: LocalTime,
): Promise<void> {
  const dateKey = `${now.year}-${pad(now.month)}-${pad(now.day)}`;
  const runRef = db
    .collection("users")
    .doc(uid)
    .collection("notificationRuns")
    .doc(`${dateKey}_${kind}`);

  try {
    await runRef.create({
      kind,
      date: dateKey,
      claimedAt: FieldValue.serverTimestamp(),
    });
  } catch (error: unknown) {
    if (isAlreadyExists(error)) return;
    throw error;
  }

  try {
    const start = tokyoMidnightUtc(now);
    const end =
      kind === "morning"
        ? new Date(start.getTime() + 24 * 60 * 60 * 1000)
        : new Date(start.getTime() + 7 * 24 * 60 * 60 * 1000);
    const tasks = await db
      .collection("users")
      .doc(uid)
      .collection("tasks")
      .where("done", "==", false)
      .where("dueDate", ">=", Timestamp.fromDate(start))
      .where("dueDate", "<", Timestamp.fromDate(end))
      .get();

    const sorted = tasks.docs
      .map((doc) => doc.data())
      .sort((a, b) => {
        const priority = priorityRank(b.priority) - priorityRank(a.priority);
        if (priority !== 0) return priority;
        return asMillis(a.dueDate) - asMillis(b.dueDate);
      });
    const limit = clamp(
      integer(kind === "morning" ? settings.morningLimit : settings.weekLimit, 5),
      1,
      MAX_LIMIT,
    );
    const title =
      kind === "morning"
        ? "本日締め切りのタスク"
        : "今後1週間の優先タスク";
    const body = formatTasks(sorted, limit, kind === "noon");
    const tokenSnapshot = await db
      .collection("users")
      .doc(uid)
      .collection("fcmTokens")
      .get();
    const tokens = tokenSnapshot.docs
      .map((doc) => ({ref: doc.ref, token: doc.get("token")}))
      .filter((item): item is {ref: FirebaseFirestore.DocumentReference; token: string} =>
        typeof item.token === "string" && item.token.length > 0,
      );

    if (tokens.length === 0) {
      await runRef.set({status: "no-token"}, {merge: true});
      return;
    }

    for (let offset = 0; offset < tokens.length; offset += 500) {
      const chunk = tokens.slice(offset, offset + 500);
      const result = await getMessaging().sendEachForMulticast({
        tokens: chunk.map((item) => item.token),
        notification: {title, body},
        data: {type: "task-summary", kind},
        android: {
          priority: "high",
          notification: {channelId: "daily_task_summary"},
        },
        apns: {payload: {aps: {sound: "default"}}},
      });
      const invalid = result.responses
        .map((response, index) => ({response, item: chunk[index]}))
        .filter(({response}) =>
          response.error?.code === "messaging/registration-token-not-registered" ||
          response.error?.code === "messaging/invalid-registration-token",
        );
      await Promise.all(invalid.map(({item}) => item.ref.delete()));
    }
    await runRef.set(
      {status: "sent", completedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  } catch (error) {
    // Allow Cloud Scheduler's retry to claim this user's run again.
    await runRef.delete();
    logger.error("Failed to send task summary", {uid, kind, error});
    throw error;
  }
}

function formatTasks(
  tasks: FirebaseFirestore.DocumentData[],
  limit: number,
  showDueDate: boolean,
): string {
  if (tasks.length === 0) return "該当する未完了タスクはありません";
const lines = tasks.slice(0, limit).map((task) => {
  const title = shorten(String(task.title ?? "無題のタスク"), 80);
  const due = showDueDate ? `（${formatDueDate(task.dueDate)}）` : "";
  const progress = formatSubtaskProgress(task.subtasks);

  return `・${title}${due}${progress}`;
});
  const remaining = tasks.length - lines.length;
  if (remaining > 0) lines.push(`ほか ${remaining} 件`);
  return lines.join("\n");
}

function formatSubtaskProgress(value: unknown): string {
  if (!Array.isArray(value) || value.length === 0) {
    return "";
  }

  const total = value.length;
  const completed = value.filter((subtask) => {
    return (
      typeof subtask === "object" &&
      subtask !== null &&
      "done" in subtask &&
      subtask.done === true
    );
  }).length;

  return `［${completed}/${total}完了］`;
}

function localParts(date: Date): LocalTime {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  }).formatToParts(date);
  const value = (type: string) =>
    Number(parts.find((part) => part.type === type)?.value);
  return {
    year: value("year"),
    month: value("month"),
    day: value("day"),
    hour: value("hour"),
    minute: value("minute"),
  };
}

function tokyoMidnightUtc(now: LocalTime): Date {
  return new Date(Date.UTC(now.year, now.month - 1, now.day, -9));
}

function formatDueDate(value: unknown): string {
  if (!(value instanceof Timestamp)) return "期限不明";
  const local = localParts(value.toDate());
  return `${local.month}/${local.day}`;
}

function priorityRank(value: unknown): number {
  if (value === "high") return 2;
  if (value === "medium") return 1;
  return 0;
}

function asMillis(value: unknown): number {
  return value instanceof Timestamp ? value.toMillis() : Number.MAX_SAFE_INTEGER;
}

function integer(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) ? value : fallback;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function pad(value: number): string {
  return String(value).padStart(2, "0");
}

function shorten(value: string, max: number): string {
  return value.length > max ? `${value.slice(0, max - 1)}…` : value;
}

function isAlreadyExists(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    ((error as {code?: unknown}).code === 6 ||
      (error as {code?: unknown}).code === "already-exists")
  );
}

async function runInBatches(
  work: Array<() => Promise<void>>,
  batchSize: number,
): Promise<void> {
  for (let offset = 0; offset < work.length; offset += batchSize) {
    await Promise.all(
      work.slice(offset, offset + batchSize).map((operation) => operation()),
    );
  }
}
