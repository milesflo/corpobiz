module CorpoBiz

// Proximity radius, in meters, within which hired staff are spawned.
public static func ProximityRadius() -> Float {
  return 40.0;
}

public static func RoleTag(bizId: CName, role: CName) -> CName {
  return StringToName("corpobiz_" + NameToString(bizId) + "_role_" + NameToString(role));
}

public class StaffSpawnerDelayCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    StaffSpawner.Tick(this.game);
    GameInstance.GetDelaySystem(this.game).DelayCallback(this, 3.0, true);
  }
}

// Generic over every business in CorpoBizRegistry.All() -- adding a second
// business gets proximity-based staff spawning for free, no changes needed
// here.
public class StaffSpawner {

  public static func Start(game: GameInstance) -> Void {
    let cb = new StaffSpawnerDelayCallback();
    cb.game = game;
    GameInstance.GetDelaySystem(game).DelayCallback(cb, 3.0, true);
  }

  public static func Tick(game: GameInstance) -> Void {
    let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }

    for def in CorpoBizRegistry.All() {
      let dist = Vector4.Distance(player.GetWorldPosition(), def.terminalPosition);
      if dist < ProximityRadius() {
        StaffSpawner.EnsurePresent(game, def);
        HostileCleanup.Tick(game, player, def);
      } else {
        StaffSpawner.EnsureAbsent(game, def);
      }
    }
  }

  private static func EnsurePresent(game: GameInstance, def: BizDef) -> Void {
    let dynamics = GameInstance.GetDynamicEntitySystem();
    for role in def.roles {
      let tag = RoleTag(def.id, role.id);
      if CorpoBizState.IsRoleHired(game, def.id, role.id) {
        let desiredVariant = CorpoBizState.GetRoleVariant(game, def.id, role.id);
        if dynamics.IsPopulated(tag) && CorpoBizState.GetSpawnedRoleVariant(game, def.id, role.id) != desiredVariant {
          dynamics.DeleteTagged(tag);
        }
        if !dynamics.IsPopulated(tag) {
          let spec = new DynamicEntitySpec();
          spec.templatePath = CorpoBizRegistry.RoleVariantTemplatePath(def.id, role.id, desiredVariant, role.templatePath);
          spec.position = role.position;
          spec.orientation = role.orientation;
          spec.persistState = false;
          spec.persistSpawn = false;
          spec.alwaysSpawned = false;
          spec.spawnInView = true;
          spec.active = true;
          spec.tags = [tag];
          dynamics.CreateEntity(spec);
          CorpoBizState.SetSpawnedRoleVariant(game, def.id, role.id, desiredVariant);
        }
      } else if dynamics.IsPopulated(tag) {
        dynamics.DeleteTagged(tag);
      }
    }
  }

  private static func EnsureAbsent(game: GameInstance, def: BizDef) -> Void {
    let dynamics = GameInstance.GetDynamicEntitySystem();
    for role in def.roles {
      dynamics.DeleteTagged(RoleTag(def.id, role.id));
    }
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() {
    StaffSpawner.Start(this.GetGame());
  }
}
