module Biz7thHell

// Proximity radius, in meters, within which hired staff are spawned.
public static func ProximityRadius() -> Float {
  return 40.0;
}

public static func RoleTag(role: CName) -> CName {
  return StringToName("biz7thhell_role_" + NameToString(role));
}

public class StaffSpawnerDelayCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    StaffSpawner.Tick(this.game);
    GameInstance.GetDelaySystem(this.game).DelayCallback(this, 3.0, true);
  }
}

public class StaffSpawner {

  public static func Start(game: GameInstance) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_dbg_start", 1);
    let cb = new StaffSpawnerDelayCallback();
    cb.game = game;
    GameInstance.GetDelaySystem(game).DelayCallback(cb, 3.0, true);
  }

  public static func Tick(game: GameInstance) -> Void {
    let quests = GameInstance.GetQuestsSystem(game);
    quests.SetFact(n"biz7thhell_dbg_tick_count", quests.GetFact(n"biz7thhell_dbg_tick_count") + 1);

    // One-time-ish cleanup: "bartender" used to be a hireable role (before
    // the vanilla bartender NPC made it redundant). Any entity spawned under
    // that tag by an older build is no longer in Config.RoleIds(), so neither
    // EnsurePresent nor EnsureAbsent below would ever despawn it on their own.
    GameInstance.GetDynamicEntitySystem().DeleteTagged(RoleTag(n"bartender"));

    let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }

    let dist = Vector4.Distance(player.GetWorldPosition(), Config.TerminalPosition());
    quests.SetFact(n"biz7thhell_dbg_last_dist_x10", Cast<Int32>(dist * 10.0));
    if dist < ProximityRadius() {
      StaffSpawner.EnsurePresent(game);
      HostileCleanup.Tick(game, player);
    } else {
      StaffSpawner.EnsureAbsent(game);
    }
  }

  private static func EnsurePresent(game: GameInstance) -> Void {
    GameInstance.GetQuestsSystem(game).SetFact(n"biz7thhell_dbg_ensure_present", 1);

    let dynamics = GameInstance.GetDynamicEntitySystem();
    for id in Config.RoleIds() {
      let role = Config.GetRole(id);
      let tag = RoleTag(role.id);
      if State.IsRoleHired(game, role.id) {
        let desiredVariant = State.GetRoleVariant(game, role.id);
        if dynamics.IsPopulated(tag) && State.GetSpawnedRoleVariant(game, role.id) != desiredVariant {
          dynamics.DeleteTagged(tag);
        }
        if !dynamics.IsPopulated(tag) {
          let spec = new DynamicEntitySpec();
          spec.templatePath = Config.RoleVariantTemplatePath(role.id, desiredVariant);
          spec.position = role.position;
          spec.orientation = role.orientation;
          spec.persistState = false;
          spec.persistSpawn = false;
          spec.alwaysSpawned = false;
          spec.spawnInView = true;
          spec.active = true;
          spec.tags = [tag];
          dynamics.CreateEntity(spec);
          State.SetSpawnedRoleVariant(game, role.id, desiredVariant);
        }
      } else if dynamics.IsPopulated(tag) {
        dynamics.DeleteTagged(tag);
      }
    }
  }

  private static func EnsureAbsent(game: GameInstance) -> Void {
    let dynamics = GameInstance.GetDynamicEntitySystem();
    for id in Config.RoleIds() {
      dynamics.DeleteTagged(RoleTag(id));
    }
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() {
    GameInstance.GetQuestsSystem(this.GetGame()).SetFact(n"biz7thhell_dbg_attached", 1);
    StaffSpawner.Start(this.GetGame());
  }
}

