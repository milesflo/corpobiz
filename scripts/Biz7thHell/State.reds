module Biz7thHell

// Thin wrapper over the game's Facts system (GameInstance.GetQuestsSystem) for all
// persistent state. Facts are part of the save file already, so this needs no
// custom serialization.
public class State {

  // Set once the player confirms, via the terminal's first-time prompt, that
  // Mausser has been dealt with. We gate the purchase on this instead of a vanilla
  // quest fact, since the real internal fact/journal entry for "An Inconvenient
  // Killer" couldn't be reliably identified without decompiling the quest resource.
  public static func IsUnlocked(game: GameInstance) -> Bool {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_unlocked") > 0;
  }

  public static func SetUnlocked(game: GameInstance) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_unlocked", 1);
  }

  public static func IsOwned(game: GameInstance) -> Bool {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_owned") > 0;
  }

  public static func SetOwned(game: GameInstance) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_owned", 1);
  }

  public static func GetStock(game: GameInstance) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_stock");
  }

  public static func SetStock(game: GameInstance, value: Int32) -> Void {
    let clamped = value;
    if clamped < 0 {
      clamped = 0;
    } else if clamped > 100 {
      clamped = 100;
    }
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_stock", clamped);
  }

  public static func IsRoleHired(game: GameInstance, role: CName) -> Bool {
    return GameInstance.GetQuestsSystem(game).GetFact(State.RoleFact(role)) > 0;
  }

  public static func SetRoleHired(game: GameInstance, role: CName, hired: Bool) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(State.RoleFact(role), hired ? 1 : 0);
  }

  public static func GetAccruedCash(game: GameInstance) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_accrued_cash");
  }

  public static func AddCash(game: GameInstance, amount: Int32) -> Void {
    let current = State.GetAccruedCash(game);
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_accrued_cash", current + amount);
  }

  // Returns the amount collected and resets the accrued total to zero.
  public static func CollectCash(game: GameInstance) -> Int32 {
    let amount = State.GetAccruedCash(game);
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_accrued_cash", 0);
    return amount;
  }

  // Opaque integer timestamp, meaning owned by Economy.reds (which knows how to
  // produce/interpret it from TimeSystem). State just persists whatever it's given.
  public static func GetLastTickTime(game: GameInstance) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_last_tick");
  }

  public static func SetLastTickTime(game: GameInstance, timestamp: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_last_tick", timestamp);
  }

  // Which page of the terminal dashboard is currently open: 0 = home,
  // 1 = Staff, 2 = Stock.
  public static func GetUIView(game: GameInstance) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(n"biz7thhell_ui_view");
  }

  public static func SetUIView(game: GameInstance, view: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_ui_view", view);
  }

  // Which of Config's look variants is currently selected for a role (chosen
  // via the Staff page, applied the next time that role is (re)spawned).
  public static func GetRoleVariant(game: GameInstance, role: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(State.RoleVariantFact(role));
  }

  public static func SetRoleVariant(game: GameInstance, role: CName, variant: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(State.RoleVariantFact(role), variant);
  }

  // Which variant is actually spawned right now, so StaffSpawner can tell a
  // look change apart from "already up to date" and knows to respawn.
  public static func GetSpawnedRoleVariant(game: GameInstance, role: CName) -> Int32 {
    return GameInstance.GetQuestsSystem(game).GetFact(State.SpawnedRoleVariantFact(role));
  }

  public static func SetSpawnedRoleVariant(game: GameInstance, role: CName, variant: Int32) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(State.SpawnedRoleVariantFact(role), variant);
  }

  private static func RoleFact(role: CName) -> CName {
    return StringToName("biz7thhell_role_" + NameToString(role));
  }

  private static func RoleVariantFact(role: CName) -> CName {
    return StringToName("biz7thhell_variant_" + NameToString(role));
  }

  private static func SpawnedRoleVariantFact(role: CName) -> CName {
    return StringToName("biz7thhell_spawned_variant_" + NameToString(role));
  }
}
