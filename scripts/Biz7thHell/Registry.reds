module CorpoBiz
import CorpoBiz.SeventhHell.*

// Composition root: every business the mod currently defines. Adding a new
// business means writing its own catalog file (like SeventhHell.reds) and
// adding one line here -- nothing else in the generic engine
// (StaffSpawner/HostileCleanup/TerminalUI) needs to know it exists.
public class CorpoBizRegistry {

  public static func All() -> array<BizDef> {
    return [SeventhHell.Def()];
  }

  public static func FindByPosition(position: Vector4, maxDistance: Float) -> BizDef {
    for def in CorpoBizRegistry.All() {
      if Vector4.Distance(position, def.terminalPosition) < maxDistance {
        return def;
      }
    }
    let none: BizDef;
    return none;
  }

  public static func IsValid(def: BizDef) -> Bool {
    return NotEquals(def.id, n"");
  }

  // "Change staff look" needs a per-business catalog of variant templates,
  // which BizRoleDef deliberately doesn't carry (that would bloat every
  // role with data only some businesses use). With a single business
  // registered there's no need yet for a real per-business dispatch table
  // -- these three functions are the one place that exception lives; add a
  // proper lookup here (not scattered through the generic engine) once a
  // second business needs its own variant catalog.
  public static func RoleVariantCount(bizId: CName, role: CName) -> Int32 {
    if Equals(bizId, SeventhHell.Id()) {
      return SeventhHell.RoleVariantCount(role);
    }
    return 1;
  }

  public static func RoleVariantTemplatePath(bizId: CName, role: CName, variant: Int32, fallback: ResRef) -> ResRef {
    if Equals(bizId, SeventhHell.Id()) {
      return SeventhHell.RoleVariantTemplatePath(role, variant);
    }
    return fallback;
  }

  public static func RoleVariantName(bizId: CName, role: CName, variant: Int32) -> String {
    if Equals(bizId, SeventhHell.Id()) {
      return SeventhHell.RoleVariantName(role, variant);
    }
    return "Default";
  }
}
