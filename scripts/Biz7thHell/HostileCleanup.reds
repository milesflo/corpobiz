module Biz7thHell

// Once the player owns 7th Hell, any hostile NPCs still lingering in the
// venue (left over from clearing it out) are removed outright, rather than
// just pacified -- a business that's been bought out shouldn't still have
// armed gang members loitering in it.
public class HostileCleanup {

  public static func ClearRadius() -> Float {
    return 40.0;
  }

  public static func Tick(game: GameInstance, player: ref<GameObject>) -> Void {
    if !State.IsOwned(game) {
      return;
    }

    let query = TSQ_EnemyNPC();
    query.maxDistance = HostileCleanup.ClearRadius();
    query.filterObjectByDistance = true;

    let parts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(game).GetTargetParts(player, query, parts);
    let count = 0;
    for part in parts {
      let component = part.GetComponent();
      if IsDefined(component) {
        let enemy = component.GetEntity() as GameObject;
        if IsDefined(enemy) {
          count += 1;
          enemy.GetEntity().Destroy();
        }
      }
    }
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_dbg_allies_count", count);
  }
}
