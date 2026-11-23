module CorpoBiz

// Composition root -- but not in the sense of naming modules itself. base/
// knows nothing about any specific business; every module is responsible
// for registering its own instance (see modules/7thHell/SeventhHell.reds's
// OnGameAttached wrap for the pattern). That's what makes modules
// independently distributable: installing a new one means dropping its
// folder in and nothing in base/ ever needs to change.
//
// Backed by Codeware's ScriptableSystem (the engine auto-instantiates one
// persistent instance per game session, retrievable via
// GetScriptableSystemsContainer) rather than a user-declared static field
// -- redscript doesn't resolve "static let" class fields reliably in this
// build (confirmed: both ClassName.field and bare field access from a
// static method fail to resolve), so a normal *instance* field on an
// engine-managed singleton is the proven way to hold mutable state that
// outlives any single call.
//
// Registration is idempotent (deduped by BizDef.id), not just an append:
// redscript/the RED4 script VM runs script code single-threaded (no
// parallel execution across hooks), so there's no true data race to guard
// against here -- but OnGameAttached could plausibly fire more than once
// in a session (e.g. a respawn without a full process restart), and a
// blind append would silently duplicate that module's entry each time.
// Checking-then-inserting by id means a repeat call is a no-op instead.
public class CorpoBizRegistry extends ScriptableSystem {
  private let m_modules: array<ref<BizModule>>;

  public func RegisterModule(mod: ref<BizModule>) -> Void {
    let id = mod.Def().id;
    for existing in this.m_modules {
      if Equals(existing.Def().id, id) {
        return;
      }
    }
    ArrayPush(this.m_modules, mod);
  }

  public func AllModules() -> array<ref<BizModule>> {
    return this.m_modules;
  }

  public static func Register(game: GameInstance, mod: ref<BizModule>) -> Void {
    CorpoBizRegistry.GetInstance(game).RegisterModule(mod);
  }

  public static func All(game: GameInstance) -> array<ref<BizModule>> {
    return CorpoBizRegistry.GetInstance(game).AllModules();
  }

  // X/Y/Z-only distance -- deliberately NOT Vector4.Distance(). Every
  // module's distance came back identical and suspiciously tiny
  // (~0.01) regardless of true position, and the match still failed
  // despite that being well under any reasonable radius -- the
  // signature of Vector4.Distance() returning NaN (a NaN comparison is
  // always false in IEEE-754, so `dist < maxDistance` never fires, but
  // the loop still runs to completion instead of early-returning).
  // Likely cause: GetWorldPosition() probably returns W=0.0, while
  // every BizDef.terminalPosition literal in this codebase explicitly
  // sets W=1.0 -- if Vector4.Distance does anything homogeneous-
  // coordinate-shaped with W (e.g. dividing through by it), that
  // mismatch alone could produce NaN. Not confirmed via decompiled
  // source (none available), only inferred from this symptom -- doing
  // the math by hand on X/Y/Z sidesteps the question entirely rather
  // than needing to resolve it.
  public static func DistanceXYZ(a: Vector4, b: Vector4) -> Float {
    let dx = a.X - b.X;
    let dy = a.Y - b.Y;
    let dz = a.Z - b.Z;
    return SqrtF(dx * dx + dy * dy + dz * dz);
  }

  public static func FindByPosition(game: GameInstance, position: Vector4, maxDistance: Float) -> ref<BizModule> {
    for mod in CorpoBizRegistry.All(game) {
      let modPos = mod.Def().terminalPosition;
      let dist = CorpoBizRegistry.DistanceXYZ(position, modPos);
      if dist < maxDistance {
        return mod;
      }
    }
    return null;
  }

  private static func GetInstance(game: GameInstance) -> ref<CorpoBizRegistry> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"CorpoBiz.CorpoBizRegistry") as CorpoBizRegistry;
  }
}
