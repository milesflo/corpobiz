module Biz7thHell

// Individual actions, called from TerminalUI.reds when the player selects
// the corresponding synthetic entry in the terminal's Files list.
public class Terminal {

  public static func TryBuy(game: GameInstance, player: ref<GameObject>) -> Void {
    if State.IsOwned(game) {
      return;
    }
    let price = Config.PurchasePrice();
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), price) {
      State.SetOwned(game);
      State.SetStock(game, 100);
    }
  }

  public static func TryHireRole(game: GameInstance, player: ref<GameObject>, id: CName) -> Void {
    if State.IsRoleHired(game, id) {
      return;
    }
    let role = Config.GetRole(id);
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), role.hireCost) {
      State.SetRoleHired(game, id, true);
    }
  }

  public static func TryFireRole(game: GameInstance, id: CName) -> Void {
    if !State.IsRoleHired(game, id) {
      return;
    }
    State.SetRoleHired(game, id, false);
  }

  public static func CycleRoleVariant(game: GameInstance, id: CName) -> Void {
    let count = Config.RoleVariantCount(id);
    let current = State.GetRoleVariant(game, id);
    let next = (current + 1) % count;
    State.SetRoleVariant(game, id, next);
  }

  // Collects accrued cash directly from the terminal (no bartender role to
  // interact with in person anymore).
  public static func TryCollect(game: GameInstance, player: ref<GameObject>) -> Void {
    let amount = State.CollectCash(game);
    if amount > 0 {
      GameInstance.GetTransactionSystem(game).GiveItem(player, MarketSystem.Money(), amount);
    }
  }

  public static func TryRestock(game: GameInstance, player: ref<GameObject>) -> Void {
    let stock = State.GetStock(game);
    if stock >= 100 {
      return;
    }
    let cost = Config.RestockCostPer10Percent() * 3;
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), cost) {
      State.SetStock(game, stock + 30);
    }
  }
}
