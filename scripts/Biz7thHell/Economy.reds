module Biz7thHell

// Lazy accrual: called whenever the player interacts with the terminal or
// bartender, rather than ticking constantly. Computes revenue/stock changes
// from elapsed in-game time since the last settle.
public class Economy {

  public static func Settle(game: GameInstance) -> Void {
    let now = Economy.CurrentTimestamp(game);
    let last = State.GetLastTickTime(game);
    if last == 0 {
      State.SetLastTickTime(game, now);
      return;
    }

    let deltaSeconds = now - last;
    if deltaSeconds <= 0 {
      return;
    }
    let deltaDays = Cast<Float>(deltaSeconds) / 86400.0;

    let stock = State.GetStock(game);
    let activeRoles = Economy.ActiveRoleCount(game);

    if activeRoles > 0 && stock > 0 {
      let revenuePerDay = Economy.RevenuePerDay(game);
      let earned = Cast<Int32>(Cast<Float>(revenuePerDay) * (Cast<Float>(stock) / 100.0) * deltaDays);
      State.AddCash(game, earned);
    }

    let decay = Cast<Int32>(Cast<Float>(Config.StockDecayPerDayPerActiveRole() * activeRoles) * deltaDays);
    State.SetStock(game, stock - decay);

    State.SetLastTickTime(game, now);
  }

  private static func CurrentTimestamp(game: GameInstance) -> Int32 {
    let t = GameInstance.GetTimeSystem(game).GetGameTime();
    return GameTime.Hours(t) * 3600 + GameTime.Minutes(t) * 60 + GameTime.Seconds(t);
  }

  private static func ActiveRoleCount(game: GameInstance) -> Int32 {
    let count = 0;
    for id in Config.RoleIds() {
      if State.IsRoleHired(game, id) {
        count += 1;
      }
    }
    return count;
  }

  private static func RevenuePerDay(game: GameInstance) -> Int32 {
    let total = 0;
    for id in Config.RoleIds() {
      if State.IsRoleHired(game, id) {
        let role = Config.GetRole(id);
        total += role.revenuePerDay;
      }
    }
    return total;
  }
}
