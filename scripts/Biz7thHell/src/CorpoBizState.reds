module CorpoBiz

// Generic Facts-backed persistence for any business, namespaced by bizId
// (and, where relevant, a role or resource id within that business). Facts
// are part of the save file already, so this needs no custom serialization.
public class CorpoBizState {

  public static func IsOwned(game: GameInstance, bizId: CName) -> Bool {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.Key(bizId, "owned")) > 0;
  }

  public static func SetOwned(game: GameInstance, bizId: CName) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.Key(bizId, "owned"), 1);
  }

  public static func GetStock(game: GameInstance, bizId: CName, resource: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.ResourceKey(bizId, resource, "stock"));
  }

  public static func SetStock(game: GameInstance, bizId: CName, resource: CName, value: Int32) -> Void {
    let clamped = value;
    if clamped < 0 {
      clamped = 0;
    } else if clamped > 100 {
      clamped = 100;
    }
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.ResourceKey(bizId, resource, "stock"), clamped);
  }

  public static func IsRoleHired(game: GameInstance, bizId: CName, role: CName) -> Bool {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.RoleKey(bizId, role, "hired")) > 0;
  }

  public static func SetRoleHired(game: GameInstance, bizId: CName, role: CName, hired: Bool) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.RoleKey(bizId, role, "hired"), hired ? 1 : 0);
  }

  public static func GetRoleVariant(game: GameInstance, bizId: CName, role: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.RoleKey(bizId, role, "variant"));
  }

  public static func SetRoleVariant(game: GameInstance, bizId: CName, role: CName, variant: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.RoleKey(bizId, role, "variant"), variant);
  }

  // Which variant is actually spawned right now, so StaffSpawner can tell a
  // look change apart from "already up to date" and knows to respawn.
  public static func GetSpawnedRoleVariant(game: GameInstance, bizId: CName, role: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.RoleKey(bizId, role, "spawned_variant"));
  }

  public static func SetSpawnedRoleVariant(game: GameInstance, bizId: CName, role: CName, variant: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.RoleKey(bizId, role, "spawned_variant"), variant);
  }

  public static func GetAccruedCash(game: GameInstance, bizId: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.Key(bizId, "accrued_cash"));
  }

  public static func AddCash(game: GameInstance, bizId: CName, amount: Int32) -> Void {
    let current = CorpoBizState.GetAccruedCash(game, bizId);
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.Key(bizId, "accrued_cash"), current + amount);
  }

  // Returns the amount collected and resets the accrued total to zero.
  public static func CollectCash(game: GameInstance, bizId: CName) -> Int32 {
    let amount = CorpoBizState.GetAccruedCash(game, bizId);
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.Key(bizId, "accrued_cash"), 0);
    return amount;
  }

  // Opaque integer timestamp, meaning owned by the economy tick (which knows
  // how to produce/interpret it from TimeSystem). State just persists it.
  public static func GetLastTickTime(game: GameInstance, bizId: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.Key(bizId, "last_tick"));
  }

  public static func SetLastTickTime(game: GameInstance, bizId: CName, timestamp: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.Key(bizId, "last_tick"), timestamp);
  }

  // Which page of this business's terminal dashboard is open: 0 = home,
  // 1 = Staff, 2 = Stock.
  public static func GetUIView(game: GameInstance, bizId: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(CorpoBizState.Key(bizId, "ui_view"));
  }

  public static func SetUIView(game: GameInstance, bizId: CName, view: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(CorpoBizState.Key(bizId, "ui_view"), view);
  }

  private static func Key(bizId: CName, suffix: String) -> CName {
    return StringToName("corpobiz_" + NameToString(bizId) + "_" + suffix);
  }

  private static func RoleKey(bizId: CName, role: CName, suffix: String) -> CName {
    return StringToName("corpobiz_" + NameToString(bizId) + "_role_" + NameToString(role) + "_" + suffix);
  }

  private static func ResourceKey(bizId: CName, resource: CName, suffix: String) -> CName {
    return StringToName("corpobiz_" + NameToString(bizId) + "_res_" + NameToString(resource) + "_" + suffix);
  }
}
