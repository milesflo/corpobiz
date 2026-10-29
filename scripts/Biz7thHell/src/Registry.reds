module CorpoBiz
import CorpoBiz.SeventhHell.*

// Composition root: the only file in the generic engine allowed to name a
// specific business. Installing a module means writing its own folder
// under modules/ (implementing BizModule) and adding one line here --
// nothing else in src/ needs to change.
public class CorpoBizRegistry {

  public static func All() -> array<ref<BizModule>> {
    let mods: array<ref<BizModule>> = [new SeventhHellModule()];
    return mods;
  }

  public static func FindByPosition(position: Vector4, maxDistance: Float) -> ref<BizModule> {
    for mod in CorpoBizRegistry.All() {
      if Vector4.Distance(position, mod.Def().terminalPosition) < maxDistance {
        return mod;
      }
    }
    return null;
  }
}
