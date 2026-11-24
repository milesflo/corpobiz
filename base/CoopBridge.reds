module CorpoBiz

// NightCoop multiplayer bridge. When NightCoop is installed, registers
// CorpoBiz with its SDK and gates mutations/spawning to the session host.
// When NightCoop is absent, every call falls through to single-player
// defaults (IsHost=true, IsLocalPlayer=true).
//
// NightCoop syncs Facts host->guest automatically, so CorpoBizState needs
// no changes -- the host writes Facts and they mirror to guests. Only the
// host runs mutations (buy/hire/settle/spawn); guests see the synced
// state via their terminals but can't act on it yet.
// shortcut: guest->host request routing not implemented, upgrade when
//   guest interactivity is needed (NightCoop channels or shared state)

@if(ModuleExists("NightCoop"))
import NightCoop.*

@if(ModuleExists("NightCoop"))
public class CoopBridge {

  public static func Register() -> Void {
    if NightCoopSdk.Version() == 0 { return; }
    let flags = EnumInt(NightCoopSdkModFlag.NeededByAll)
      | EnumInt(NightCoopSdkModFlag.SpawnsEntities)
      | EnumInt(NightCoopSdkModFlag.UsesSharedState);
    NightCoopSdk.RegisterMod("milesflo.corpobiz", "CorpoBiz", "0.1.0", 1, flags);
  }

  // True when this machine is the authority for world state: single-player,
  // NightCoop not in a session, or we ARE the session host.
  // shortcut: IsHost/InSession return types unverified against live SDK,
  //   if compile fails under NightCoop change to > 0 comparisons
  public static func IsHost() -> Bool {
    if NightCoopSdk.Version() == 0 { return true; }
    if !NightCoopSdk.InSession() { return true; }
    return NightCoopSdk.IsHost();
  }

  // True when this entity belongs to the local player (not a partner's
  // puppet). Used to gate OnGameAttached so registration/spawning fires
  // once per machine, not once per player puppet.
  public static func IsLocalPlayer(entityId: EntityID) -> Bool {
    if NightCoopSdk.Version() == 0 { return true; }
    // 1=mine, 0=partner's, -7=not synced (treat as local)
    return NightCoopSdk.EntityIsMine(entityId) != 0;
  }
}

@if(!ModuleExists("NightCoop"))
public class CoopBridge {
  public static func Register() -> Void {}
  public static func IsHost() -> Bool { return true; }
  public static func IsLocalPlayer(entityId: EntityID) -> Bool { return true; }
}
