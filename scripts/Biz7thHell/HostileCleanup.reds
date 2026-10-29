module CorpoBiz

// Once a business is owned, any hostile NPCs still lingering in its venue
// (left over from clearing it out) are removed outright -- a business
// that's been bought out shouldn't still have armed enemies loitering in
// it. Generic over every business in CorpoBizRegistry.All(); called by
// StaffSpawner.Tick for whichever BizDef the player is currently near.
public class HostileCleanup {

  public static func ClearRadius() -> Float {
    return 40.0;
  }

  public static func Tick(game: GameInstance, player: ref<GameObject>, def: BizDef) -> Void {
    if !CorpoBizState.IsOwned(game, def.id) {
      return;
    }

    let query = TSQ_EnemyNPC();
    query.maxDistance = HostileCleanup.ClearRadius();
    query.filterObjectByDistance = true;

    let parts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(game).GetTargetParts(player, query, parts);
    for part in parts {
      let component = part.GetComponent();
      if IsDefined(component) {
        let enemy = component.GetEntity() as GameObject;
        if IsDefined(enemy) {
          enemy.GetEntity().Destroy();
        }
      }
    }
  }
}
