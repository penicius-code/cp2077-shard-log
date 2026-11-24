// Cyberslop Shard Log 1.0.0 - redscript half of the CET window "Shard Log".
//
// Refresh() reads what the journal's Shards screen lists (CodexUtils.GetShardsDataArray: JournalManager.GetOnscreens,
// active entries, fallback group "others") plus the encrypted shards in V's inventory (ShardsMenuGameController
// .ProcessItem: Gen_Misc items with a Crack action whose journal entry is still inactive). The CET side reads the
// result as flat arrays (Hashes / Times / Flags / Groups) and asks for titles and texts by hash, so a refresh hands
// CET a few number tables instead of one object per shard.
//
// Times are GameTime seconds of the entry's last journal state change (JournalManager.GetEntryTimestamp, the value the
// Shards screen sorts by inside a category): when a looted shard went into the journal. Encrypted shards have no
// journal time yet (-1).
//
// Generation() goes up whenever a shard entry changes state or read flag (journal callbacks State + Visited), so the
// CET window re-reads only after a change.

public class CyberslopShardLogSystem extends ScriptableSystem {
  private let m_gen: Int32;
  private let m_journal: wref<JournalManager>;
  private let m_hashes: array<Int32>;
  private let m_times: array<Int32>;
  private let m_flags: array<Int32>;   // 1 unread, 2 encrypted, 4 Phantom Liberty
  private let m_groups: array<Int32>;  // index into GroupNames()

  public static func Get(game: GameInstance) -> ref<CyberslopShardLogSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberslopShardLogSystem") as CyberslopShardLogSystem;
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {
    this.Listen();
  }

  private func OnDetach() {
    this.Unlisten();
  }

  private func Listen() {
    this.Unlisten();
    let journal = GameInstance.GetJournalManager(this.GetGameInstance());
    if IsDefined(journal) {
      journal.RegisterScriptCallback(this, n"OnShardLogState", gameJournalListenerType.State);
      journal.RegisterScriptCallback(this, n"OnShardLogVisited", gameJournalListenerType.Visited);
      this.m_journal = journal;
    }
    this.m_gen += 1;
  }

  private func Unlisten() {
    if IsDefined(this.m_journal) {
      this.m_journal.UnregisterScriptCallback(this, n"OnShardLogState");
      this.m_journal.UnregisterScriptCallback(this, n"OnShardLogVisited");
    }
    this.m_journal = null;
  }

  protected cb func OnShardLogState(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if Equals(className, n"gameJournalOnscreen") {
      this.m_gen += 1;
    }
    return false;
  }

  protected cb func OnShardLogVisited(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if Equals(className, n"gameJournalOnscreen") {
      this.m_gen += 1;
    }
    return false;
  }

  public func Generation() -> Int32 {
    return this.m_gen;
  }

  // Game clock in GameTime seconds (same scale as Times()).
  public func Now() -> Int32 {
    return GameTime.GetSeconds(GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime());
  }

  // Group indexes 0-10 = the journal's shard categories (CodexUtils.GetLocalizedTag order), 11 = encrypted.
  private static func GroupIndex(tag: CName) -> Int32 {
    switch tag {
      case n"literature_fiction": return 0;
      case n"night_city_people": return 1;
      case n"world": return 2;
      case n"technology": return 3;
      case n"notes": return 4;
      case n"articles": return 5;
      case n"leaflets": return 6;
      case n"cyberpsycho": return 7;
      case n"religion_philosophy": return 8;
      case n"poetry": return 9;
      default: return 10;
    }
  }

  public func GroupNames() -> array<String> {
    let names: array<String>;
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-LiteratureFiction"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-NightCityPeople"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-World"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Technology"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Notes"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Articles"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Leaflets"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("LocKey#31788"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-ReligionPhilosophy"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Poetry"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("UI-Shards-Others"));
    ArrayPush(names, CyberslopShardLogSystem.Loc("LocKey#42347"));
    return names;
  }

  private static func Loc(raw: String) -> String {
    if !IsStringValid(raw) {
      return "";
    }
    let text = GetLocalizedText(raw);
    if !IsStringValid(text) {
      return raw;
    }
    return text;
  }

  private func Add(hash: Int32, time: Int32, flags: Int32, group: Int32) {
    ArrayPush(this.m_hashes, hash);
    ArrayPush(this.m_times, time);
    ArrayPush(this.m_flags, flags);
    ArrayPush(this.m_groups, group);
  }

  // Re-reads all shards; returns how many. Read the result with Hashes / Times / Flags / Groups.
  public func Refresh() -> Int32 {
    ArrayClear(this.m_hashes);
    ArrayClear(this.m_times);
    ArrayClear(this.m_flags);
    ArrayClear(this.m_groups);
    let game = this.GetGameInstance();
    let journal = GameInstance.GetJournalManager(game);
    if !IsDefined(journal) {
      return 0;
    }
    let context: JournalRequestContext;
    context.stateFilter.active = true;
    let groups: array<ref<JournalOnscreensStructuredGroup>>;
    journal.GetOnscreens(context, groups, n"others");
    for group in groups {
      if IsDefined(group) {
        let gi = CyberslopShardLogSystem.GroupIndex(group.GetTag());
        let shards = group.GetEntries();
        for shard in shards {
          if IsDefined(shard) {
            let flags = journal.IsEntryVisited(shard) ? 0 : 1;
            if journal.IsEp1Entry(shard) {
              flags += 4;
            }
            this.Add(journal.GetEntryHash(shard), GameTime.GetSeconds(journal.GetEntryTimestamp(shard)), flags, gi);
          }
        }
      }
    }
    this.AddEncrypted(game, journal);
    return ArraySize(this.m_hashes);
  }

  private func AddEncrypted(game: GameInstance, journal: ref<JournalManager>) {
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return;
    }
    let items: array<wref<gameItemData>>;
    if !GameInstance.GetTransactionSystem(game).GetItemList(player, items) {
      return;
    }
    for item in items {
      if IsDefined(item) && Equals(item.GetItemType(), gamedataItemType.Gen_Misc) {
        let crack = ItemActionsHelper.GetCrackAction(item.GetID()) as CrackAction_Record;
        if IsDefined(crack) {
          let effect = crack.Effector() as TriggerHackingMinigameEffector_Record;
          if IsDefined(effect) {
            let path = effect.JournalEntry();
            if IsStringValid(path) {
              let entry = journal.GetEntryByString(path, "gameJournalOnscreen") as JournalOnscreen;
              if IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Inactive) {
                let hash = journal.GetEntryHash(entry);
                if !ArrayContains(this.m_hashes, hash) {
                  let flags = 3;
                  if journal.IsEp1Entry(entry) {
                    flags += 4;
                  }
                  this.Add(hash, -1, flags, 11);
                }
              }
            }
          }
        }
      }
    }
  }

  public func Hashes() -> array<Int32> {
    return this.m_hashes;
  }

  public func Times() -> array<Int32> {
    return this.m_times;
  }

  public func Flags() -> array<Int32> {
    return this.m_flags;
  }

  public func Groups() -> array<Int32> {
    return this.m_groups;
  }

  private func Entry(hash: Int32) -> wref<JournalOnscreen> {
    let journal = GameInstance.GetJournalManager(this.GetGameInstance());
    if !IsDefined(journal) {
      return null;
    }
    return journal.GetEntry(Cast<Uint32>(hash)) as JournalOnscreen;
  }

  public func Title(hash: Int32) -> String {
    let e = this.Entry(hash);
    if !IsDefined(e) {
      return "";
    }
    return CyberslopShardLogSystem.Loc(e.GetTitle());
  }

  // Shard text; empty for an encrypted shard (the journal shows it only after the breach).
  public func Text(hash: Int32) -> String {
    let e = this.Entry(hash);
    if !IsDefined(e) {
      return "";
    }
    let journal = GameInstance.GetJournalManager(this.GetGameInstance());
    if Equals(journal.GetEntryState(e), gameJournalEntryState.Inactive) {
      return "";
    }
    return CyberslopShardLogSystem.Loc(e.GetDescription());
  }

  // Hashes from the last Refresh() whose title or text contains needle (case-insensitive; text not for encrypted).
  public func Match(needle: String) -> array<Int32> {
    let result: array<Int32>;
    let n = StrLower(needle);
    if !IsStringValid(n) {
      return result;
    }
    let i = 0;
    let count = ArraySize(this.m_hashes);
    while i < count {
      let hash = this.m_hashes[i];
      if StrContains(StrLower(this.Title(hash)), n) {
        ArrayPush(result, hash);
      } else {
        if (this.m_flags[i] / 2) % 2 == 0 && StrContains(StrLower(this.Text(hash)), n) {
          ArrayPush(result, hash);
        }
      }
      i += 1;
    }
    return result;
  }

  // Sets the journal's read flag (the Shards screen's NEW marker). Returns false for an unknown hash.
  public func MarkRead(hash: Int32, read: Bool) -> Bool {
    let e = this.Entry(hash);
    if !IsDefined(e) {
      return false;
    }
    let journal = GameInstance.GetJournalManager(this.GetGameInstance());
    if NotEquals(journal.IsEntryVisited(e), read) {
      journal.SetEntryVisited(e, read);
    }
    let i = ArrayFindFirst(this.m_hashes, hash);
    if i >= 0 {
      let unread = this.m_flags[i] % 2;
      if read {
        this.m_flags[i] = this.m_flags[i] - unread;
      } else {
        if unread == 0 {
          this.m_flags[i] = this.m_flags[i] + 1;
        }
      }
    }
    return true;
  }
}
