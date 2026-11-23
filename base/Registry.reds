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
    // TEMPORARY DEBUG -- logs the actual DistanceXYZ() result for each
    // registered module (x100 scaled Int32, since Facts only store
    // Int32) so we can confirm the fix actually produces sane numbers.
    // Remove once resolved.
    let quests = GameInstance.GetQuestsSystem(game);

    // ULTRA-MINIMAL isolation test: construct a Vector4 literal with a
    // known value right here, no BizDef/Def()/struct-return involved at
    // all, and read its field straight back. If this ALSO shows 0 (not
    // 12345), the bug is in Vector4 literal construction/field access
    // itself, not in how terminalPosition survives inside BizDef.
    let testVec = new Vector4(123.45, 0.0, 0.0, 1.0);
    quests.SetFact(n"corpobiz_debug_testvec_x", Cast<Int32>(testVec.X * 100.0));
    let idx = 0;
    for mod in CorpoBizRegistry.All(game) {
      // Does a plain scalar field (purchasePrice: Int32) survive this
      // same mod.Def() call correctly, while terminalPosition (Vector4,
      // itself a struct with its own X/Y/Z/W fields) doesn't? If so,
      // this isolates the bug to nested-struct fields specifically,
      // not scalar fields, surviving a virtual Def() call on an
      // abstract-class-typed reference.
      let fullDef = mod.Def();
      let modPos = fullDef.terminalPosition;
      let dist = CorpoBizRegistry.DistanceXYZ(position, modPos);
      if idx == 0 {
        quests.SetFact(n"corpobiz_debug_dist0", Cast<Int32>(dist * 100.0));
        quests.SetFact(n"corpobiz_debug_modx0", Cast<Int32>(modPos.X * 100.0));
        quests.SetFact(n"corpobiz_debug_price0", fullDef.purchasePrice);
      } else if idx == 1 {
        quests.SetFact(n"corpobiz_debug_dist1", Cast<Int32>(dist * 100.0));
        quests.SetFact(n"corpobiz_debug_modx1", Cast<Int32>(modPos.X * 100.0));
        quests.SetFact(n"corpobiz_debug_price1", fullDef.purchasePrice);
      } else if idx == 2 {
        quests.SetFact(n"corpobiz_debug_dist2", Cast<Int32>(dist * 100.0));
        quests.SetFact(n"corpobiz_debug_modx2", Cast<Int32>(modPos.X * 100.0));
        quests.SetFact(n"corpobiz_debug_price2", fullDef.purchasePrice);
      } else if idx == 3 {
        quests.SetFact(n"corpobiz_debug_dist3", Cast<Int32>(dist * 100.0));
        quests.SetFact(n"corpobiz_debug_modx3", Cast<Int32>(modPos.X * 100.0));
        quests.SetFact(n"corpobiz_debug_price3", fullDef.purchasePrice);
      }
      idx += 1;
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
