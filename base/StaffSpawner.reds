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

// Generic over every module in CorpoBizRegistry.All() -- installing a new
// business module gets proximity-based staff spawning for free.
public class StaffSpawner {

  public static func Start(game: GameInstance) -> Void {
    let cb = new StaffSpawnerDelayCallback();
    cb.game = game;
    GameInstance.GetDelaySystem(game).DelayCallback(cb, 3.0, true);
  }

  public static func Tick(game: GameInstance) -> Void {
    if !CoopBridge.IsHost() { return; }
    let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }

    for mod in CorpoBizRegistry.All(game) {
      let def = mod.Def();
      // CorpoBizRegistry.DistanceXYZ(), not Vector4.Distance() -- see that
      // function's own comment for why it exists (suspected NaN from a
      // GetWorldPosition() W=0 vs terminalPosition's W=1 mismatch, which
      // makes `dist < ProximityRadius()` always false). This call site
      // never got the same fix FindByPosition did, so staff silently
      // never spawned regardless of actual proximity.
      let dist = CorpoBizRegistry.DistanceXYZ(player.GetWorldPosition(), def.terminalPosition);
      if dist < ProximityRadius() {
        StaffSpawner.EnsurePresent(game, mod, def);
        HostileCleanup.Tick(game, player, def);
      } else {
        StaffSpawner.EnsureAbsent(def);
      }
    }
  }

  private static func EnsurePresent(game: GameInstance, mod: ref<BizModule>, def: BizDef) -> Void {
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
          spec.templatePath = mod.RoleVariantTemplatePath(role.id, desiredVariant);
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

  private static func EnsureAbsent(def: BizDef) -> Void {
    let dynamics = GameInstance.GetDynamicEntitySystem();
    for role in def.roles {
      dynamics.DeleteTagged(RoleTag(def.id, role.id));
    }
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() && CoopBridge.IsLocalPlayer(this.GetEntityID()) {
    CoopBridge.Register();
    StaffSpawner.Start(this.GetGame());
  }
}
