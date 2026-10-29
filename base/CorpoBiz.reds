module CorpoBiz

// Generic buy/hire/fire/restock/collect actions and lazy revenue/stock
// accrual, operating purely on BizDef/BizRoleDef values the caller already
// resolved. The framework never looks up a business's own role catalog
// itself (that would need a callback into business-specific code, which
// redscript's struct/array limitations make awkward to do safely) -- the
// caller (a business's terminal glue code) resolves whatever BizRoleDef or
// revenue total it needs and hands it in as plain data.
public class CorpoBiz {

  public static func TryBuy(game: GameInstance, player: ref<GameObject>, def: BizDef) -> Void {
    if CorpoBizState.IsOwned(game, def.id) {
      return;
    }
    if !CorpoBizPrereqs.IsMet(game, player, def) {
      return;
    }
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), def.purchasePrice) {
      CorpoBizState.SetOwned(game, def.id);
      for resource in def.inputs {
        CorpoBizState.SetStock(game, def.id, resource.id, 100);
      }
    }
  }

  public static func TryHireRole(game: GameInstance, player: ref<GameObject>, bizId: CName, role: BizRoleDef) -> Void {
    if CorpoBizState.IsRoleHired(game, bizId, role.id) {
      return;
    }
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), role.hireCost) {
      CorpoBizState.SetRoleHired(game, bizId, role.id, true);
    }
  }

  public static func TryFireRole(game: GameInstance, bizId: CName, role: CName) -> Void {
    if !CorpoBizState.IsRoleHired(game, bizId, role) {
      return;
    }
    CorpoBizState.SetRoleHired(game, bizId, role, false);
  }

  public static func CycleRoleVariant(game: GameInstance, bizId: CName, role: CName, variantCount: Int32) -> Void {
    let current = CorpoBizState.GetRoleVariant(game, bizId, role);
    let next = (current + 1) % variantCount;
    CorpoBizState.SetRoleVariant(game, bizId, role, next);
  }

  public static func TryRestock(game: GameInstance, player: ref<GameObject>, def: BizDef, resource: CName) -> Void {
    let stock = CorpoBizState.GetStock(game, def.id, resource);
    if stock >= 100 {
      return;
    }
    let cost = def.restockCostPer10Percent * 3;
    let trans = GameInstance.GetTransactionSystem(game);
    if trans.RemoveItem(player, MarketSystem.Money(), cost) {
      CorpoBizState.SetStock(game, def.id, resource, stock + 30);
    }
  }

  public static func TryCollect(game: GameInstance, player: ref<GameObject>, bizId: CName) -> Void {
    let amount = CorpoBizState.CollectCash(game, bizId);
    if amount > 0 {
      GameInstance.GetTransactionSystem(game).GiveItem(player, MarketSystem.Money(), amount);
    }
  }

  // Lazy accrual: call whenever the player interacts with the terminal,
  // rather than ticking constantly. Computes revenue/stock changes from
  // elapsed in-game time since the last settle. Revenue is scaled by the
  // first input resource's stock level, if the business has one (7th
  // Hell's "Alcohol"); businesses with no inputs just accrue flat per-role
  // revenue with no stock decay.
  public static func Settle(game: GameInstance, def: BizDef) -> Void {
    let now = CorpoBiz.CurrentTimestamp(game);
    let last = CorpoBizState.GetLastTickTime(game, def.id);
    if last == 0 {
      CorpoBizState.SetLastTickTime(game, def.id, now);
      return;
    }

    let deltaSeconds = now - last;
    if deltaSeconds <= 0 {
      return;
    }
    let deltaDays = Cast<Float>(deltaSeconds) / 86400.0;
    let activeRoles = CorpoBiz.ActiveRoleCount(game, def);
    let hiredRevenuePerDay = CorpoBiz.HiredRevenuePerDay(game, def);

    if CorpoBiz.HasPrimaryResource(def) {
      let primaryResource = CorpoBiz.PrimaryResource(def).id;
      let stock = CorpoBizState.GetStock(game, def.id, primaryResource);
      if activeRoles > 0 && stock > 0 {
        let earned = Cast<Int32>(Cast<Float>(hiredRevenuePerDay) * (Cast<Float>(stock) / 100.0) * deltaDays);
        CorpoBizState.AddCash(game, def.id, earned);
      }
      let decay = Cast<Int32>(Cast<Float>(def.stockDecayPerDayPerActiveRole * activeRoles) * deltaDays);
      CorpoBizState.SetStock(game, def.id, primaryResource, stock - decay);
    } else if activeRoles > 0 {
      let earned = Cast<Int32>(Cast<Float>(hiredRevenuePerDay) * deltaDays);
      CorpoBizState.AddCash(game, def.id, earned);
    }

    CorpoBizState.SetLastTickTime(game, def.id, now);
  }

  public static func HasPrimaryResource(def: BizDef) -> Bool {
    for resource in def.inputs {
      return true;
    }
    return false;
  }

  // The first declared input resource (7th Hell has exactly one, "Alcohol";
  // a business with multiple inputs would need its own UI/logic beyond
  // this framework stub).
  public static func PrimaryResource(def: BizDef) -> BizResource {
    for resource in def.inputs {
      return resource;
    }
    let none: BizResource;
    return none;
  }

  private static func CurrentTimestamp(game: GameInstance) -> Int32 {
    let t = GameInstance.GetTimeSystem(game).GetGameTime();
    return GameTime.Hours(t) * 3600 + GameTime.Minutes(t) * 60 + GameTime.Seconds(t);
  }

  private static func ActiveRoleCount(game: GameInstance, def: BizDef) -> Int32 {
    let count = 0;
    for role in def.roles {
      if CorpoBizState.IsRoleHired(game, def.id, role.id) {
        count += 1;
      }
    }
    return count;
  }

  private static func HiredRevenuePerDay(game: GameInstance, def: BizDef) -> Int32 {
    let total = 0;
    for role in def.roles {
      if CorpoBizState.IsRoleHired(game, def.id, role.id) {
        total += role.revenuePerDay;
      }
    }
    return total;
  }
}
